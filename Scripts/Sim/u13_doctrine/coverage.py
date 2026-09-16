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
        evidence_scope="PowerMatch: five exact local diagnostic games across nine Lords; 23 declared powers in directed components; Windows 4.7.2 dual-runtime acceptance pending",
        nine_lord_adapter="u13_pysim.power_match.PowerMatch",
        reference_observer_scope="unchanged four-Lord FullMatch observer; declared powers and paid-choice diagnostics are not yet measured",
        lords=[dict(lord=lord, ordinary_full_match=lord in ORDINARY_FULL_MATCH_LORDS,
                    power_match="implemented; Windows acceptance pending",
                    declared_powers=[dict(power=power, full_match="PowerMatch implemented; directed local parity; Windows acceptance pending") for power in powers])
               for lord, powers in POWERS.items()],
        paid_rites="accepted Windows 4.7.2 / CPython / PyPy at 24792a6",
        resummon="accepted Windows 4.7.2 / CPython / PyPy at 24792a6",
        paid_development_checkpoint="docs/U13_PYSIM_PAID_DEVELOPMENT_2026-09-16.md",
        gate="Windows 4.7.2 / CPython / PyPy nine-Lord gate, then bounded planner and expanded exact campaign before balance claims")


def require_full_roster_tuning():
    raise ValueError("Full-roster tuning is blocked: PowerMatch needs Windows dual-runtime "
                     "acceptance, planner diagnostics and expanded exact campaign coverage")
