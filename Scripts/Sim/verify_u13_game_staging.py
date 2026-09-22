#!/usr/bin/env python3
"""Replay the native full-game staging fixture with the independent Python engine."""
import json
import sys
from pathlib import Path
from u13_pysim import codec
from u13_pysim.power_match import PowerMatch
from u13_pysim.verify import same


def verify(path):
    case = codec.loads(Path(path).read_text(encoding='utf-8'))
    game = PowerMatch(case['setup'])
    for index, op in enumerate(case['operations']):
        result = game.apply(op)
        if result['action'] == 'invalid':
            raise ValueError((index, op, result))
    expected, actual = case['state'], game.snapshot()
    # The Linux diagnostic engine and the historical Python opening pin have
    # different roster hashes. Keep/report both; compare all other snapshot
    # fields, including every world, event, reserve, order, and runtime clock.
    hashes = dict(native=expected.pop('rules_hash'), python=actual.pop('rules_hash'))
    same(expected, actual, 'full-game-staging')
    return dict(rounds=game.clock.round, operations=len(case['operations']),
                exact_world_events_and_clocks=True, rules_hashes=hashes,
                rules_hash_equal=hashes['native'] == hashes['python'])


if __name__ == '__main__':
    print(json.dumps(verify(sys.argv[1]), indent=2))
