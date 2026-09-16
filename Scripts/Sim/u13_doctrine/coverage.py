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
REFERENCE = "docs/U13_PYSIM_PAID_DEVELOPMENT_2026-09-16.md"


def report():
    return dict(
        ready_for_full_roster_tuning=False,
        evidence=REFERENCE,
        evidence_scope="four exact games with paid Rites/Resummon at 24792a6; no declared powers; nine-Lord return components",
        lords=[dict(lord=lord, ordinary_full_match=lord in ORDINARY_FULL_MATCH_LORDS,
                    declared_powers=[dict(power=power, full_match="unsupported") for power in powers])
               for lord, powers in POWERS.items()],
        paid_rites="accepted Windows 4.7.2 / CPython / PyPy at 24792a6",
        resummon="accepted Windows 4.7.2 / CPython / PyPy at 24792a6",
        paid_development_checkpoint="docs/U13_PYSIM_PAID_DEVELOPMENT_2026-09-16.md",
        gate="exact reference cases and full games exercising all nine Lords and their mechanics")


def require_full_roster_tuning():
    raise ValueError("Full-roster tuning is blocked: declared powers and five Lord integrations "
                     "lack full-match parity")
