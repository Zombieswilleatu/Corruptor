#!/usr/bin/env python3
"""Replay only terminal tie candidates using the campaign's frozen engine."""
import argparse
import json
from pathlib import Path
import sys


def audit(output):
    sys.path.insert(0, str(output/'source/Scripts/Sim'))
    from run_u13_lord_balance import verify_frozen
    from u13_doctrine.survey import read_record, atomic_json
    from u13_pysim.power_match import PowerMatch
    from u13_pysim.benchmark_full_match import digest
    from u13_pysim.lifecycle import alive
    verify_frozen(output)
    identity=json.loads((output/'manifest.json').read_text())
    config=json.loads((output/'split-config.json').read_text())
    rows=[]
    for spec in config['cases']:
        record=read_record(output/'games'/(spec['name']+'.json.gz'),identity,spec)
        finish=record['semantic']['diagnostics']['victory_race']
        ritual_candidate=finish['win_by']=='Ritual' and min(finish['souls'])>=12
        limit_tie=finish['win_by']=='RoundLimit' and len(set(finish['souls']))==1
        if not (ritual_candidate or limit_tie): continue
        match=PowerMatch(spec['setup'])
        for operation in record['operations']:
            result=match.apply(operation)
            if result['action']=='invalid': raise ValueError(result)
        assert digest(match)==record['semantic']['final_state_sha256']
        living=[alive(match._state['world'],pid) for pid in (0,1)]
        rows.append(dict(name=spec['name'],finish=finish,alive=living,
            simultaneous_ritual=ritual_candidate and all(living), round_limit_soul_tie=limit_tie))
    result=dict(scope='Recorded-operation replays, no new policy games; checks terminal preference only, not earlier Reflex effects.',
        replayed=len(rows), simultaneous_rituals=sum(r['simultaneous_ritual'] for r in rows),
        round_limit_soul_ties=sum(r['round_limit_soul_tie'] for r in rows), games=rows)
    atomic_json(output/'seat-terminal-audit.json',result)
    print(json.dumps(result,indent=2))


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('output',type=Path)
    audit(parser.parse_args().output.resolve())
