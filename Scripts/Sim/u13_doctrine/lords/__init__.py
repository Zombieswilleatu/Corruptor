"""One independent decision module per Lord; no simulator authority here."""
from . import gremory, deimos, humbaba, kalligan, orias, odradek, kroni, valak, kanifous

MODULES = {m.LORD: m for m in (gremory, deimos, humbaba, kalligan, orias, odradek, kroni, valak, kanifous)}


def proposals(facts):
    return MODULES[facts.kind].proposals(facts)
