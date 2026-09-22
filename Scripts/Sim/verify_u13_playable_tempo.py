#!/usr/bin/env python3
"""Two-worker exact Python/Godot check of the promoted playable rules.

Fresh independent openings, identical legal inputs, complete worlds and all
semantic events after every operation. No expected state is fed to authority.
"""
import argparse
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
import subprocess
import tempfile
from u13_pysim import codec, full_match_inputs, split_ward
from u13_pysim.power_match import PowerMatch
from u13_pysim.copying import copy_data
from u13_pysim import lifecycle
from u13_doctrine.test_split_ward import SplitWardTests
from u13_doctrine.common import CommonSmartCore
from u13_doctrine.observation import observe, Preview

ROOT = Path(__file__).resolve().parents[2]

def verify_case(godot, directory, index):
    path = directory / f'case-{index}.jsonl'
    setup = dict(full_match_inputs.load()['cases'][0]['setup'],
        seed=f'playable-tempo-parity-{index // 2}',
        lords=['Gremory', 'Kanifous'] if index % 2 == 0 else ['Kanifous', 'Gremory'],
        ward_experiment=split_ward.VERSION, tempo_experiment=split_ward.TEMPO)
    game = PowerMatch(setup)
    count = prefix = 0
    with path.open('w') as stream:
        stream.write(codec.dumps(dict(setup=setup, world=game.snapshot()['world']))+'\n')
        if index == 0:
            for component in components(): stream.write(codec.dumps(component)+'\n')
        while not (game.clock.round == 2 and game.clock.completed):
            op = full_match_inputs.next_operation(game)
            if op['kind'] == 'submit':
                plans = []
                for pid in (0, 1):
                    if game.clock.round == 1:
                        hand = game._state['world']['data']['card_zones']['hands'][pid]
                        order = dict(action='Hunt', lane='Lord',
                            target_id=game._state['world']['players'][1-pid]['lord_entity_id'],
                            card_ids=hand[:-1], ward=dict(action='Ward', lane='Lord', card_ids=hand[-1:]))
                        plans.append(dict(powers=[], order=order))
                    else:
                        plans.append(CommonSmartCore().decide(observe(game,pid), Preview(game,pid))['plan'])
                op['plans'] = plans
            result = game.apply(op)
            assert result['action'] != 'invalid', result
            state = game.snapshot()
            stream.write(codec.dumps(dict(operation=op, world=state['world'],
                events=state['events']['rows'][prefix:]))+'\n')
            prefix = len(state['events']['rows']); count += 1
    result = subprocess.run([godot, '--headless', '--path', str(ROOT), '--script',
        'Scripts/Sim/U13PlayableTempoParityRunner.gd', '--', str(path)],
        capture_output=True, text=True, timeout=180)
    (directory / f'case-{index}.log').write_text(result.stdout+result.stderr)
    assert result.returncode == 0 and 'SCRIPT ERROR' not in result.stderr, result.stdout+result.stderr
    return dict(case=index, operations=count, events=prefix)

def components():
    # Directed authority boundaries supplement fresh setup-to-round replay.
    fixture = SplitWardTests()
    for strength, lane, guard, veil in ((3,'Lord',False,0),(6,'Lord',False,0),(12,'Lord',False,0),
                                  (6,'Castle',False,0),(6,'Lord',True,0),
                                  *((6,'Lord',False,v) for v in (12,13,16,17,20,21))):
        rules, attack = fixture.battle(strength,lane,guard,False)
        if guard:
            rows=rules.w['entities']['entities']
            replacement=next(r for r in rows if r['kind']=='card' and r['id'] not in attack['card_ids']+rules.orders[1]['card_ids'] and r['id']!='fixture-guard')
            next(r for r in rows if r['id']=='fixture-guard').update({key:replacement[key] for key in ('id','origin','ordinal')})
            rows.remove(replacement)
            rows.sort(key=lambda row:row["id"])
        rules.w['data']['plunder']['resolved_round'] = 0
        if veil:
            rules.w['data']['tempo_experiment']=split_ward.TEMPO
            rules.w['data']['neutral_tears']=veil-sum(p['resources']['personal_tears'] for p in rules.w['players'])
        initial = copy_data(rules.w)
        rules.kroni_orders = rules.orders
        prior = rules.w['data']['kroni_action_round']
        events = rules.combat()
        rules.w['data']['kroni_action_round'] = prior # Core Combat excludes the Kroni wrapper.
        yield dict(component='combat', context=dict(world=initial, round=1, seed=rules.seed,
            player_order=[0,1], hook='combat_resolution', combat_orders=rules.orders,
            persistent_effects=[]), world=rules.w, events=events)
    for number in (19,20):
        for attack_type, success, pillage in (('Hunt',True,False),('Hunt',False,False),
            ('Siege',True,False),('Siege',False,False),('Siege',True,True)):
            rules, attack=fixture.battle(6,'Castle',False,False)
            rules.number=number; rules.w['data']['tempo_experiment']=split_ward.TEMPO
            events=[dict(event=dict(type=attack_type.upper()+'_RESOLVED', text='', data=dict(
                target_id=attack['target_id'], banished=success, destroyed=success, pillage=pillage)),views=[])]
            initial=copy_data(rules.w); original=copy_data(events)
            split_ward.reward_breakthrough(rules,0,events)
            yield dict(component='bonus', world_before=initial, events_before=original,
                round=number, world=rules.w, events=events)
    for number, veil, souls, tears in ((24,26,[0,0],[0,0]),(25,26,[4,5],[0,0]),
        (25,26,[5,5],[0,0]),(25,12,[0,0],[5,0]),(25,26,[12,13],[0,0])):
        world=copy_data(fixture.fixture()[0]._state['world'])
        world['data']['tempo_experiment']=split_ward.TEMPO
        world['data']['neutral_tears']=veil-sum(tears)
        for pid in (0,1):
            world['players'][pid]['resources'].update(souls=souls[pid],personal_tears=tears[pid])
        yield dict(component='victory', world_before=world, round=number, expected=lifecycle.evaluate(world,number))

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', required=True)
    args=parser.parse_args()
    with tempfile.TemporaryDirectory(prefix='u13-playable-tempo-') as directory:
        with ThreadPoolExecutor(max_workers=2) as workers:
            results=list(workers.map(lambda i: verify_case(args.godot,Path(directory),i),range(4)))
        print(results)
        print('PASS exact paired Python/Godot worlds, events, and native snapshot restoration (two workers)')

if __name__=='__main__': main()
