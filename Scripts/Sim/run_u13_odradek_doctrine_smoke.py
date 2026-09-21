#!/usr/bin/env python3
"""Two four-round Odradek smoke games. Legality/performance check, not win evidence."""
import json
import time
from collections import Counter

from u13_doctrine.common import CommonSmartCore
from u13_doctrine.observation import observe, Preview
from u13_pysim import full_match_inputs
from u13_pysim.power_match import PowerMatch


def main():
    policy = CommonSmartCore(); reports = []; started = time.monotonic()
    for lords in (['Odradek', 'Kroni'], ['Valak', 'Odradek']):
        setup = dict(full_match_inputs.load()['cases'][0]['setup'], lords=lords, seed='odradek-v26-smoke:'+':'.join(lords))
        game = PowerMatch(setup); decisions = operations = 0; powers = Counter()
        while game.outcome()['winner'] == -1:
            if game.clock.round == 4 and game.clock.completed: break
            if game.clock.round > 4: raise AssertionError('Smoke round cap exceeded')
            hook = game.clock.hook
            if hook == 'submission_lock' and game._state['submissions'] == [None, None]:
                choices = [policy.decide(observe(game, seat), Preview(game, seat)) for seat in (0, 1)]
                for choice in choices:
                    assert not choice['rejected_previews'], choice['rejected_previews']
                    for name, count in choice['budget']['used'].items():
                        cap = 16 if name.startswith('generated:') else 4 if name.startswith('retained:') else 32 if name == 'complete_plans' else 8
                        assert count <= cap, (name, count)
                    powers.update(s['power_id'] for s in choice['plan']['powers'])
                decisions += len(choices)
                op = dict(kind='submit', plans=[c['plan'] for c in choices])
            elif hook == 'present_public_state' and game._state['world']['data']['game_economy']['stockpile_pending']:
                seat = game._state['world']['data']['game_economy']['stockpile_pending']['player_id']
                op = policy.choose_card(observe(game, seat), 'stockpile')['operation']
            elif hook == 'present_public_state' and game._state['world']['data']['game_market']['seat'] != 2:
                seat = game._state['world']['data']['game_market']['seat']
                op = policy.choose_card(observe(game, seat), 'slaver')['operation']
            else: op = full_match_inputs.next_operation(game)
            result = game.apply(op); operations += 1
            assert result['action'] != 'invalid', (lords, game.clock.round, hook, result)
        reports.append(dict(lords=lords, rounds=game.clock.round, decisions=decisions, operations=operations, powers=dict(powers)))
    print(json.dumps(dict(policy=policy.policy_id, cases=reports, elapsed_seconds=round(time.monotonic()-started, 2), balance_evidence=False), indent=2))


if __name__ == '__main__': main()
