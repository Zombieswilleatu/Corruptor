"""Passive per-decision measurements with explicit unknown denominators.

Policy adapters submit facts, not live worlds. Resolution adapters attach actual
effects using stable selection IDs, including in later rounds. This recorder
does not infer good opportunities, legality, useful effects, or hidden orders.
"""

from collections import Counter
from copy import deepcopy
import hashlib
import json
import math

from . import VERSION
from .budget import CATEGORIES

FLAGS = ("opportunity", "legal", "affordable", "selected")
COUNTS = ("generated", "retained")
OUTCOMES = ("resolved", "fizzled", "cancelled")


def fingerprint(value):
    return hashlib.sha256(json.dumps(value, sort_keys=True, separators=(",", ":"),
                                     ensure_ascii=False, allow_nan=False).encode()).hexdigest()


class Recorder:
    def __init__(self, match_id, lords, policy_ids, sample_limit=12):
        if not isinstance(match_id, str) or not match_id or len(lords) != 2 or len(policy_ids) != 2:
            raise ValueError("match identity requires two Lords and two policy IDs")
        if any(not isinstance(value, str) or not value for value in (*lords, *policy_ids)):
            raise ValueError("Lord and policy IDs must be nonempty strings")
        if type(sample_limit) is not int or sample_limit < 0:
            raise ValueError("invalid diagnostic sample limit")
        self.match_id, self.lords, self.policy_ids = match_id, tuple(lords), tuple(policy_ids)
        self.sample_limit = sample_limit
        self._groups, self._assessments, self._selections, self._events = {}, {}, {}, {}
        self._samples = []

    def assess(self, round_number, seat, category, term, *, supported=True,
               opportunity=None, legal=None, affordable=None, generated=None,
               retained=None, selected=None, reason):
        """One assessment per term/seat/decision round, not one per target.

        None means unmeasured. Unsupported terms have no measured counters.
        Selection is recorded after admission; rejected plans fail the driver.
        """
        if type(round_number) is not int or round_number < 1 or type(seat) is not int or seat not in (0, 1):
            raise ValueError("invalid decision round or seat")
        if category not in CATEGORIES or not isinstance(term, str) or not term or not isinstance(reason, str) or not reason:
            raise ValueError("assessment requires a category, term and reason")
        if type(supported) is not bool:
            raise ValueError("supported must be a boolean")
        flags = dict(opportunity=opportunity, legal=legal, affordable=affordable, selected=selected)
        counts = dict(generated=generated, retained=retained)
        if any(value is not None and type(value) is not bool for value in flags.values()):
            raise ValueError("assessment flags must be booleans or unknown")
        if any(value is not None and (type(value) is not int or value < 0) for value in counts.values()):
            raise ValueError("candidate counts must be nonnegative integers or unknown")
        if not supported and any(value is not None for value in (*flags.values(), *counts.values())):
            raise ValueError("unsupported is not a measured zero")
        if generated is not None and retained is not None and retained > generated:
            raise ValueError("retained candidates exceed generated candidates")
        if selected is True and (legal is not True or affordable is not True or generated == 0 or retained == 0):
            raise ValueError("selected choice must be admitted and cannot have zero candidates")
        identity = (round_number, seat, category, term)
        if identity in self._assessments:
            raise ValueError("duplicate decision assessment")
        key = (seat, category, term, supported)
        if key not in self._groups:
            self._groups[key] = dict(
                seat=seat, lord=self.lords[seat], opponent=self.lords[1-seat],
                policy_id=self.policy_ids[seat], category=category, term=term,
                support="supported" if supported else "unsupported", decisions=0,
                flags={name: Counter() for name in FLAGS} if supported else None,
                candidates={name: dict(measured_decisions=0, total=0) for name in COUNTS} if supported else None,
                reasons=Counter(), outcomes=Counter(), metrics=Counter(), effect_records=0,
                nonzero_effect_records=0)
        group = self._groups[key]
        group["decisions"] += 1
        group["reasons"][reason] += 1
        if supported:
            for name, value in flags.items():
                group["flags"][name]["unknown" if value is None else "true" if value else "false"] += 1
            for name, value in counts.items():
                if value is not None:
                    group["candidates"][name]["measured_decisions"] += 1
                    group["candidates"][name]["total"] += value
        self._assessments[identity] = key
        selection_id = fingerprint([self.match_id, *identity]) if selected else None
        if selection_id:
            self._selections[selection_id] = dict(key=key, round=round_number, outcome=None)
        if len(self._samples) < self.sample_limit:
            self._samples.append(dict(round=round_number, seat=seat, category=category, term=term,
                supported=supported, **flags, **counts, reason=reason, selection_id=selection_id))
        return selection_id

    def _new_event(self, kind, selection_id, event_id, round_number, payload):
        selection = self._selections.get(selection_id)
        if selection is None:
            raise ValueError("effect/outcome has no selected decision")
        if type(round_number) is not int or round_number < selection["round"]:
            raise ValueError("effect predates selection")
        if not isinstance(event_id, str) or not event_id:
            raise ValueError("stable source event ID required")
        identity = (kind, selection_id, event_id)
        digest = fingerprint([round_number, payload])
        if identity in self._events:
            if self._events[identity] != digest:
                raise ValueError("conflicting duplicate source event")
            return None
        return identity, digest, selection

    def outcome(self, selection_id, event_id, round_number, status):
        if status not in OUTCOMES:
            raise ValueError("invalid resolution outcome")
        fresh = self._new_event("outcome", selection_id, event_id, round_number, status)
        if fresh is None:
            return False
        identity, digest, selection = fresh
        if selection["outcome"] is not None:
            raise ValueError("selection already has a terminal outcome")
        self._events[identity] = digest
        selection["outcome"] = status
        self._groups[selection["key"]]["outcomes"][status] += 1
        return True

    def effect(self, selection_id, event_id, round_number, metrics):
        if type(metrics) is not dict or not metrics or any(
                not isinstance(key, str) or not key or type(value) not in (int, float)
                or not math.isfinite(value) for key, value in metrics.items()):
            raise ValueError("effects require finite named numeric measurements")
        fresh = self._new_event("effect", selection_id, event_id, round_number, metrics)
        if fresh is None:
            return False
        identity, digest, selection = fresh
        self._events[identity] = digest
        group = self._groups[selection["key"]]
        group["metrics"].update(metrics)
        group["effect_records"] += 1
        group["nonzero_effect_records"] += int(any(value != 0 for value in metrics.values()))
        return True

    def report(self):
        groups = []
        for key in sorted(self._groups):
            group = deepcopy(self._groups[key])
            if group["flags"] is not None:
                group["flags"] = {name: {value: counts[value] for value in ("true", "false", "unknown")}
                                  for name, counts in group["flags"].items()}
            group["outcome_unobserved"] = sum(s["key"] == key and s["outcome"] is None
                                              for s in self._selections.values())
            if group["support"] == "unsupported":
                for field in ("outcomes", "metrics", "effect_records", "nonzero_effect_records", "outcome_unobserved"):
                    group[field] = None
            groups.append(group)
        return dict(schema=VERSION, match_id=self.match_id, groups=groups,
                    assessment_count=len(self._assessments), selected_count=len(self._selections),
                    sample_limit=self.sample_limit, samples=deepcopy(self._samples),
                    metric_semantics="observed effects, not counterfactual benefit or scoring utility")
