"""Explicit current full-match capability inventory, not a rules dispatcher.

Isolated spatial fixtures do not imply complete-game support. Update this
inventory only alongside the relevant authority/parity evidence.
"""

POWERS = {
    "Gremory": ("PredatorOfRuin", "InevitableRuin"),
    "Deimos": ("WarMachine", "Rout"),
    "Humbaba": ("MusterTheFaithful", "BreathOfLife"),
    "Kalligan": ("Pyroclasm", "Inferno"),
    "Orias": ("Web", "Snare"),
    "Odradek": ("AllegianceShift", "Redirect", "Inversion", "FalseOrders"),
    "Kroni": ("Consume", "Ravenous"),
    "Valak": ("GravityOrb", "Projection"),
    "Kanifous": ("WishLongevity", "WishDeath", "WishPower", "WishResurrection", "WishWealth"),
}
ORDINARY_FULL_MATCH_LORDS = ("Gremory", "Deimos", "Humbaba", "Kalligan")
REFERENCE = "docs/U13_PYSIM_NINE_LORDS_2026-09-16.md"


def report():
    return dict(
        ready_for_full_roster_tuning=False,
        evidence=REFERENCE,
        evidence_scope="PowerMatch: accepted Windows 4.7.2 / CPython / PyPy at 5fb53e7; five exact games / 81 rounds; all 23 powers in directed components",
        nine_lord_adapter="u13_pysim.power_match.PowerMatch",
        reference_observer_scope="unchanged four-Lord FullMatch observer; declared powers and paid-choice diagnostics are not yet measured",
        lords=[dict(lord=lord, ordinary_full_match=lord in ORDINARY_FULL_MATCH_LORDS,
                    power_match="accepted focused Windows gate at 5fb53e7",
                    declared_powers=[dict(power=power, full_match="PowerMatch accepted Windows focused parity at 5fb53e7") for power in powers])
               for lord, powers in POWERS.items()],
        paid_rites="accepted Windows 4.7.2 / CPython / PyPy at 24792a6",
        resummon="accepted Windows 4.7.2 / CPython / PyPy at 24792a6",
        paid_development_checkpoint="docs/U13_PYSIM_PAID_DEVELOPMENT_2026-09-16.md",
        gate="bounded planner behavior, dual-runtime decisions and expanded exact campaign before balance claims")


def require_full_roster_tuning():
    raise ValueError("Full-roster tuning is blocked: planner behavior diagnostics and "
                     "expanded exact campaign coverage remain required")
