"""Exercise passive diagnostics on the two existing complete reference games.

This adapter observes accepted selections and named effects. It cannot measure
the reference policy's alternative generation or opportunity scoring: those
fields stay unknown. Declared-power support is explicitly unavailable.
"""

from collections import Counter
import hashlib
import json
from pathlib import Path
import time

from u13_pysim import full_match_inputs as inputs
from u13_pysim.benchmark_full_match import digest
from u13_pysim.benchmark_full_match_copying import BASELINE, BASELINE_SOURCE, INPUTS_SHA256
from u13_pysim.full_match import FullMatch
from u13_pysim.verify import same, source_identity

from . import VERSION, coverage
from .budget import Limits
from .diagnostics import Recorder, fingerprint
from dataclasses import asdict

EVIDENCE = "docs/evidence/U13_PYSIM_FULL_MATCH_d059b95.json"
COMBAT = ("Pass", "Ward", "Hunt", "Siege", "Profane")


class ReferenceObserver:
    """Receives accepted operation data and events; never supplied to policy."""

    def __init__(self, spec):
        self.recorder = Recorder(spec["name"], spec["setup"]["lords"], [inputs.POLICY] * 2)
        self.selected, self.finished, self.work_targets = {}, set(), {}
        self.activation_targets = {}
        self.event_counts = Counter()
        self.mechanic_checks = {}

    def accepted_submission(self, number, plans):
        for seat, plan in enumerate(plans):
            if plan["powers"] or plan["order"].get("rites") or plan["order"].get("summon"):
                raise ValueError("reference observer does not support powers, paid Rites or Resummon")
            order = plan["order"]
            actual = order.get("action", "Pass")
            if actual not in COMBAT:
                raise ValueError("unrecognized combat action")
            choices = [("combat", term, actual == term) for term in COMBAT]
            choices += [("guards", "Deploy", bool(order.get("guard_moves")))]
            work = order.get("castle_action", {})
            choices += [("work", term, work.get("action") == term) for term in ("Work", "Activate")]
            for category, term, selected in choices:
                identity = self.recorder.assess(number, seat, category, term,
                    selected=selected, legal=True if selected else None,
                    affordable=True if selected else None,
                    reason="reference_selected" if selected else "not_selected_alternatives_unobserved")
                if identity:
                    self.selected[(number, seat, category, term)] = identity
                    if category == "work" and term == "Work":
                        self.work_targets[(seat, work["target_id"])] = identity
                    elif category == "work" and term == "Activate":
                        self.activation_targets[(number, seat)] = work["target_id"]
            for power in coverage.POWERS[self.recorder.lords[seat]]:
                self.recorder.assess(number, seat, "powers", power, supported=False,
                                     reason="full_match_power_unsupported")
            for term in ("Supplicants", "Invocation", "ProfaneRuins"):
                self.recorder.assess(number, seat, "rites", term, supported=False,
                                     reason="reference_observer_paid_rites_unimplemented")
            self.recorder.assess(number, seat, "resummon", "Resummon", supported=False,
                                 reason="reference_observer_resummon_unimplemented")

    def _attach(self, identity, event_id, number, metrics=None, outcome="resolved"):
        if not identity:
            raise ValueError("mapped effect has no observed selection")
        if metrics:
            self.recorder.effect(identity, event_id, number, metrics)
        if identity not in self.finished:
            self.recorder.outcome(identity, event_id, number, outcome)
            self.finished.add(identity)

    def event(self, index, event, current_round):
        kind, data = event["type"], event["data"]
        self.event_counts[kind] += 1
        number, seat = data.get("round", current_round), data.get("player_id")
        event_id = "semantic-row:" + str(index)
        metrics, key, identity, outcome = None, None, None, "resolved"
        if kind == "GUARD_DEPLOYED":
            key, metrics = ("guards", "Deploy"), dict(guards_deployed=1)
        elif kind == "WORK_RESOLVED":
            identity = self.work_targets.get((seat, data["castle_id"]))
            if not identity:
                raise ValueError("Work event has no originating Work selection")
            metrics = dict(applied_work=data["after"]-data["before"],
                           work_contributed=data["work"], passive_contributed=data["passive"])
        elif kind in ("CASTLE_ACTIVATED", "COMMISSION_FIZZLED"):
            # Automatic activation by accumulated Work is not an Activate order.
            key = ("work", "Activate")
            if (number, seat, *key) not in self.selected or self.activation_targets.get((number, seat)) != data.get("castle_id"):
                return
            metrics = dict(castles_activated=int(kind == "CASTLE_ACTIVATED"))
            outcome = "fizzled" if kind == "COMMISSION_FIZZLED" else "resolved"
        elif kind == "SIGIL_CREATED":
            key, metrics = ("combat", "Ward"), dict(sigils_created=1)
        elif kind in ("HUNT_RESOLVED", "SIEGE_RESOLVED", "PROFANE_RESOLVED"):
            action = dict(HUNT_RESOLVED="Hunt", SIEGE_RESOLVED="Siege", PROFANE_RESOLVED="Profane")[kind]
            key = ("combat", action)
            # Preserve raw named facts only. Resolution alone does not mean the
            # action was beneficial, and no later kills are attributed by guess.
            metrics = {name: int(data[name]) for name in (
                "damage", "banished", "destroyed", "profaned", "pillage_success", "sigil_broken") if name in data}
            if "guards_defeated" in data:
                metrics["guards_defeated"] = int(data["guards_defeated"])
        elif kind == "COMBAT_ORDER_FIZZLED":
            identity = next((identity for (n, p, cat, _), identity in self.selected.items()
                             if (n, p, cat) == (number, seat, "combat")), None)
            if not identity:
                raise ValueError("combat fizzle has no observed selection")
            outcome = "fizzled"
        elif kind == "ENDURANCE_CHECKED":
            counts = self.mechanic_checks.setdefault(str(seat) + ":Endurance", Counter())
            counts["checks"] += 1
            counts["threshold_met"] += int(data["threshold_met"])
            counts["lord_alive"] += int(data["lord_alive"])
            counts["threshold_met_and_lord_alive"] += int(data["threshold_met"] and data["lord_alive"])
        if key:
            identity = self.selected.get((number, seat, *key))
        if identity or key:
            self._attach(identity, event_id, number, metrics, outcome)

    def hook_completed(self, hook, number):
        if hook == "combat_resolution":
            for seat in (0, 1):
                identity = self.selected.get((number, seat, "combat", "Pass"))
                if identity:
                    self._attach(identity, "completed-combat-pass:" + str(number), number)

    def report(self):
        result = self.recorder.report()
        result.update(event_counts=dict(sorted(self.event_counts.items())),
                      mechanics_checks={key: dict(value) for key, value in sorted(self.mechanic_checks.items())},
                      alternative_search="unobserved", power_measurements="unsupported",
                      stockpile_slaver="semantic event totals only; decision diagnostics not yet adapted")
        return result


def run_case(spec, expected):
    observer, game = ReferenceObserver(spec), FullMatch(spec["setup"])
    policy_ns, event_cursor = 0, 0
    operation_hash = hashlib.sha256()
    for index, expected_operation in enumerate(spec["operations"]):
        start = time.perf_counter_ns()
        operation = inputs.next_operation(game)
        policy_ns += time.perf_counter_ns() - start
        same(expected_operation, operation, f"{spec['name']}.decision[{index}]")
        operation_hash.update(fingerprint(operation).encode())
        number = game.clock.round
        result = game.apply(operation)
        if result["action"] == "invalid":
            raise ValueError(f"{spec['name']}: observed operation rejected: {result}")
        if operation["kind"] == "submit":
            observer.accepted_submission(number, operation["plans"])
        # This is an observer-side access, not a policy API. Read only the new
        # event rows and extract scalars; never snapshot the world each hook.
        rows = game._state["events"]["rows"]
        for event_index in range(event_cursor, len(rows)):
            observer.event(event_index, rows[event_index]["event"], number)
        event_cursor = len(rows)
        if operation["kind"] == "step":
            observer.hook_completed(operation["hook"], number)
    final_digest = digest(game)
    same(expected["final_state_sha256"], final_digest, spec["name"] + ".final_state")
    same(expected["outcome"], game.outcome(), spec["name"] + ".outcome")
    same(expected["event_coverage"], dict(observer.event_counts), spec["name"] + ".event_coverage")
    if not game.clock.completed or game.outcome()["winner"] == -1 or game._state_exposed:
        raise ValueError("observer changed completion or exposed live world")
    result = observer.report()
    result.update(setup=spec["setup"], operations_matched=len(spec["operations"]),
                  decisions_sha256=operation_hash.hexdigest(), final_state_sha256=final_digest,
                  rounds=game.clock.round, outcome=game.outcome())
    return result, dict(reference_driver_wall_ms=policy_ns / 1e6,
                       note="includes choice-driver/observation work; not new planner or throughput timing")


def harness_hash(root):
    sim = Path(root) / "Scripts/Sim"
    paths = list((sim / "u13_doctrine").rglob("*.py"))
    paths += list((sim / "u13_doctrine").rglob("*.json"))
    paths += [sim / "run_u13_doctrine_diagnostics.py", sim / "run_u13_doctrine_diagnostics.sh"]
    return fingerprint({p.relative_to(root).as_posix(): hashlib.sha256(
        p.read_bytes().replace(b"\r\n", b"\n")).hexdigest() for p in sorted(paths)})


def run(root):
    root = Path(root)
    evidence_bytes = (root / EVIDENCE).read_bytes().replace(b"\r\n", b"\n")
    evidence = json.loads(evidence_bytes)
    same(True, evidence["gate_passed"], "reference.accepted")
    same(BASELINE, evidence["source_revision"], "reference.revision")
    same(BASELINE_SOURCE, evidence["source_sha256"], "reference.source")
    same(INPUTS_SHA256, inputs.input_hash(), "reference.inputs")
    source_revision, source_hash = source_identity(root)
    games, timings = [], {}
    expected = evidence["python_summary"]["games"]
    specs = inputs.load()["cases"]
    same([s["name"] for s in specs], [e["name"] for e in expected], "reference.games")
    for spec, oracle in zip(specs, expected):
        game, timing = run_case(spec, oracle)
        games.append(game)
        timings[spec["name"]] = timing
    semantic = dict(schema=VERSION, coverage=coverage.report(),
        proposed_new_planner_limits=asdict(Limits()), limits_enforced_on_reference_policy=False,
        policy=dict(id=inputs.POLICY, config=dict(guard_cards=2, ward_period=4),
                    config_sha256=fingerprint(dict(guard_cards=2, ward_period=4)),
                    code_sha256=hashlib.sha256(Path(inputs.__file__).read_bytes().replace(b"\r\n", b"\n")).hexdigest(),
                    policy_rng="none; deterministic reference choices; engine RNG untouched"),
        games=games, all_operations_and_final_digests_matched=True,
        gate_scope="diagnostic observer and reference-policy decisions; not nine-Lord doctrine acceptance",
        failures=0)
    return dict(source_revision=source_revision, engine_source_sha256=source_hash,
                harness_source_sha256=harness_hash(root), inputs_sha256=inputs.input_hash(),
                reference_revision=BASELINE, reference_evidence_sha256=hashlib.sha256(evidence_bytes).hexdigest(),
                semantic_report_sha256=fingerprint(semantic), semantic=semantic, timings=timings)
