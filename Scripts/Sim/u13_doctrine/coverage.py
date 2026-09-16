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
REFERENCE = "docs/U13_PYSIM_FULL_MATCH_2026-09-15.md"


def report():
    return dict(
        ready_for_full_roster_tuning=False,
        evidence=REFERENCE,
        evidence_scope="two ordinary games; no declared powers, paid Rites or Resummon",
        lords=[dict(lord=lord, ordinary_full_match=lord in ORDINARY_FULL_MATCH_LORDS,
                    declared_powers=[dict(power=power, full_match="unsupported") for power in powers])
               for lord, powers in POWERS.items()],
        paid_rites="unsupported", resummon="unsupported",
        gate="exact reference cases and full games exercising all nine Lords and their mechanics")


def require_full_roster_tuning():
    raise ValueError("Full-roster tuning is blocked: declared powers, paid Rites, Resummon "
                     "and five Lord integrations lack full-match parity")
