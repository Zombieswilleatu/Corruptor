#!/usr/bin/env python3
"""Small native/Python planner contracts; no balance games or altered doctrine."""
import argparse
from pathlib import Path

from run_u13_integration_smoke import trace_output
from u13_doctrine.common import CommonSmartCore
from u13_doctrine.observation import observe, Preview
from u13_doctrine.test_closing import closing_game
from u13_pysim import codec, full_match_inputs
from u13_pysim.copying import copy_data
from u13_pysim.power_match import LORDS, PowerMatch


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('output', type=Path)
    parser.add_argument('--prior-smoke', type=Path, help='Optional completed integration trace for natural midgame cases')
    args = parser.parse_args()
    policy = CommonSmartCore()
    count = 0
    with trace_output(args.output) as output:
        def emit(game, seat, name, mode='plan'):
            nonlocal count
            view = observe(game, seat)
            decision = (policy.decide(view, Preview(game, seat)) if mode == 'plan'
                        else policy.choose_card(view, mode))
            output.write(codec.dumps(dict(name=name, state=game.snapshot(), seat=seat,
                                           mode=mode, view=view, decision=decision)) + '\n')
            count += 1

        for index, lord in enumerate(LORDS):
            setup = dict(full_match_inputs.load()['cases'][0]['setup'],
                         lords=[lord, LORDS[(index + 1) % 9]], seed='playable-v26:' + lord)
            game = PowerMatch(setup)
            while game.clock.hook != 'submission_lock':
                data = game._state['world']['data']
                if game.clock.hook == 'present_public_state' and data['game_economy']['stockpile_pending']:
                    seat = data['game_economy']['stockpile_pending']['player_id']
                    mode = 'stockpile'
                elif game.clock.hook == 'present_public_state' and data['game_market']['seat'] != 2:
                    seat, mode = data['game_market']['seat'], 'slaver'
                else:
                    assert game.apply(full_match_inputs.next_operation(game))['action'] != 'invalid'
                    continue
                if index == 0:
                    emit(game, seat, mode + ':' + str(seat), mode)
                operation = policy.choose_card(observe(game, seat), mode)['operation']
                assert game.apply(operation)['action'] != 'invalid'
            for seat in (0, 1):
                emit(game, seat, 'opening:' + game._state['world']['players'][seat]['lord_id'] + ':' + str(seat))
        emit(closing_game(), 0, 'closing:resilient_invocation')
        if args.prior_smoke:
            last = None
            for line in args.prior_smoke.open(encoding='utf-8'):
                row = codec.loads(line)
                if row['kind'] == 'opening':
                    setup = row['setup']
                if (row['kind'] == 'operation' and 'state' in row and row['state']['runtime']['round'] == 3
                        and setup['lords'][0] in ('Kalligan', 'Orias', 'Kroni', 'Valak')):
                    game = PowerMatch(setup)
                    game.state = copy_data(row['state'])
                    runtime = game.state['runtime']
                    game.clock.round, game.clock.index = runtime['round'], runtime['next_hook_index']
                    game.clock.completed, game.clock.log = runtime['completed'], copy_data(runtime['execution_log'])
                    assert game.apply(dict(kind='next_round'))['action'] != 'invalid'
                    while game.clock.hook != 'submission_lock':
                        assert game.apply(full_match_inputs.next_operation(game))['action'] != 'invalid'
                    for seat in (0, 1):
                        emit(game, seat, 'midgame:' + ':'.join(setup['lords']) + ':' + str(seat))
                last = row
            assert last == dict(kind='finished', cases=9), 'Prior smoke trace is incomplete'
        output.write(codec.dumps(dict(finished=True, cases=count, policy=policy.policy_id)) + '\n')
    print(f'Exported {count} public-observation/decision contracts to {args.output}')


if __name__ == '__main__':
    main()
