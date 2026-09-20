"""Deterministic work limits; elapsed time never controls a policy decision."""

from collections import Counter
from dataclasses import asdict, dataclass

CATEGORIES = ("powers", "guards", "work", "combat", "monsters", "rites", "resummon", "stockpile", "slaver", "artillery", "support", "rout", "orias", "gremory", "kanifous")


@dataclass(frozen=True)
class Limits:
    # Targets/payments count as proposals too. Callers must stop generating on
    # the first refusal, rather than enumerate a universe and truncate it later.
    generated_per_category: int = 16
    retained_per_category: int = 4
    complete_plans: int = 32
    previews: int = 8

    def __post_init__(self):
        if any(type(value) is not int or value <= 0 for value in asdict(self).values()):
            raise ValueError("work limits must be positive integers")
        if self.retained_per_category > self.generated_per_category:
            raise ValueError("retained proposals exceed generation limit")


class Budget:
    """One instance per decision. A refused reservation consumes no work slot."""

    def __init__(self, limits=None):
        self.limits = limits or Limits()
        self._used = Counter()
        self._refused = Counter()

    def take(self, kind, category=None):
        if kind in ("generated", "retained"):
            if category not in CATEGORIES:
                raise ValueError("unknown decision category")
            limit = getattr(self.limits, kind + "_per_category")
            key = kind + ":" + category
        elif kind in ("complete_plans", "previews") and category is None:
            limit, key = getattr(self.limits, kind), kind
        else:
            raise ValueError("unknown budget operation")
        if self._used[key] >= limit:
            self._refused[key] += 1
            return False
        self._used[key] += 1
        return True

    def report(self):
        return dict(limits=asdict(self.limits), used=dict(sorted(self._used.items())),
                    refused=dict(sorted(self._refused.items())),
                    stopping_rule="deterministic work reservations; no wall-clock cutoff")
