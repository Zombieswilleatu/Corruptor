#!/usr/bin/env python3
"""Nine four-round games; optional exact native replay inputs, not balance evidence."""
import argparse
from collections import Counter
from contextlib import contextmanager
import json
from pathlib import Path
import time
import tempfile

from u13_doctrine.common import CommonSmartCore
from u13_doctrine.observation import observe, Preview
from u13_pysim import codec, full_match_inputs
from u13_pysim.power_match import LORDS, PowerMatch
from u13_pysim.power_rules import RULES

SCHEMA = 'U13_INTEGRATION_SMOKE_V1'
ROUNDS = 4


@contextmanager
def trace_output(path):
    if path is None:
        yield None
        return
    # Never publish a partial trace under the final path.
    with tempfile.NamedTemporaryFile(mode='w', encoding='utf-8', dir=path.parent,
                                     prefix=path.name + '.', suffix='.partial', delete=False) as output:
        temporary = Path(output.name)
        try:
            yield output
            output.close()
            temporary.replace(path)
        finally:
            output.close()
            temporary.unlink(missing_ok=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--trace', type=Path, help='Write exact inputs/results for U13IntegrationReplayTestRunner.gd')
    args = parser.parse_args()
    policy = CommonSmartCore()
    reports = []
    started = time.monotonic()
    with trace_output(args.trace) as output:
        def emit(record):
            if output:
                output.write(codec.dumps(record) + '\n')

        emit(dict(kind='header', schema=SCHEMA, policy=policy.policy_id, cases=len(LORDS), round_limit=ROUNDS, rules=RULES))
        for index, lord in enumerate(LORDS):
            lords = [lord, LORDS[(index + 1) % len(LORDS)]]
            setup = dict(full_match_inputs.load()['cases'][0]['setup'], lords=lords,
                         seed='integration-v26-smoke:' + ':'.join(lords))
            game = PowerMatch(setup)
            decisions = operations = 0
            powers, actions, cap_hits, holds = Counter(), Counter(), Counter(), Counter()
            emit(dict(kind='opening', index=index, setup=setup, state=game.snapshot()))
            while game.outcome()['winner'] == -1:
                if game.clock.round == ROUNDS and game.clock.completed:
                    break
                if game.clock.round > ROUNDS or operations >= 200:
                    raise AssertionError('Smoke work cap exceeded')
                hook = game.clock.hook
                if hook == 'submission_lock' and game._state['submissions'] == [None, None]:
                    choices = [policy.decide(observe(game, seat), Preview(game, seat)) for seat in (0, 1)]
                    for seat, choice in enumerate(choices):
                        assert not choice['rejected_previews'], choice['rejected_previews']
                        for name, count in choice['budget']['used'].items():
                            cap = (16 if name.startswith('generated:') else 4 if name.startswith('retained:')
                                   else 32 if name == 'complete_plans' else 8)
                            assert count <= cap, (name, count)
                            if count == cap:
                                cap_hits[name] += 1
                        if choice['closing']['resilient_plans']:
                            assert choice['closing']['selected']['status'] == 'resilient', choice['closing']
                        powers.update(lords[seat] + ':' + p['power_id'] for p in choice['plan']['powers'])
                        actions[lords[seat] + ':' + choice['plan']['order'].get('action', 'Pass')] += 1
                        holds.update(a['term'] + ':' + a['reason'] for a in choice['assessments']
                                     if a['category'] == 'powers' and not a['selected'] and a['opportunity'])
                    decisions += 2
                    op = dict(kind='submit', plans=[c['plan'] for c in choices])
                elif hook == 'present_public_state' and game._state['world']['data']['game_economy']['stockpile_pending']:
                    seat = game._state['world']['data']['game_economy']['stockpile_pending']['player_id']
                    op = policy.choose_card(observe(game, seat), 'stockpile')['operation']
                elif hook == 'present_public_state' and game._state['world']['data']['game_market']['seat'] != 2:
                    seat = game._state['world']['data']['game_market']['seat']
                    op = policy.choose_card(observe(game, seat), 'slaver')['operation']
                else:
                    op = full_match_inputs.next_operation(game)
                result = game.apply(op)
                operations += 1
                assert result['action'] != 'invalid', (lords, game.clock.round, hook, result)
                record = dict(kind='operation', index=operations, operation=op, result=result)
                if game.clock.completed:
                    record.update(state=game.snapshot(), outcome=game.outcome())
                emit(record)
            report = dict(lords=lords, rounds=game.clock.round, decisions=decisions, operations=operations,
                          powers=dict(powers), actions=dict(actions), cap_hits=dict(cap_hits),
                          unselected_power_reasons=dict(holds))
            reports.append(report)
            emit(dict(kind='case_end', index=index, operations=operations, rounds=game.clock.round))
            print(json.dumps(report), flush=True)
        emit(dict(kind='finished', cases=len(reports)))
    print(json.dumps(dict(policy=policy.policy_id, cases=len(reports),
                          decisions=sum(r['decisions'] for r in reports),
                          operations=sum(r['operations'] for r in reports),
                          elapsed_seconds=round(time.monotonic() - started, 2),
                          balance_evidence=False, native_decision_parity=False)), flush=True)


if __name__ == '__main__':
    main()
