"""One independent decision module per Lord; no simulator authority here."""
from . import gremory, deimos, humbaba, kalligan, orias, odradek, kroni, valak, kanifous

MODULES = {m.LORD: m for m in (gremory, deimos, humbaba, kalligan, orias, odradek, kroni, valak, kanifous)}


def proposals(facts):
    yield from MODULES[facts.kind].proposals(facts)
    from u13_pysim import veil
    if veil.affects(facts.world,"Kanifous",facts.pid):
        for proposal in kanifous.breach_proposals(facts):
            proposal.term = "Breach" + proposal.term
            proposal.value -= 5
            yield proposal
