"""Public history, bounded adaptation, legal decisions, and actual combat."""
import copy
import json
import unittest

from u13_pysim import economy, power_components
from .common import CommonSmartCore
from .observation import observe, Preview
from .opponent_memory import project, profile
from .test_common import planning
from .test_defensive_plans import through


def history(lane='Lord', number=7):
    return [dict(round=n, action='Hunt' if lane=='Lord' else 'Siege', lane=lane,
                 cards=5, strength=18, ward_strength=0) for n in range(max(1,number-6), number)]


def reveal(number, action='Hunt', seat=1, strength=18):
    return economy.event('COMBAT_ORDER_REVEALED', dict(round=number, player_id=seat,
        order=dict(action=action, lane='Lord' if action in ('Hunt','Ward') else 'Castle'),
        cards=[dict(attributes=dict(value=strength))]))


class OpponentMemoryTests(unittest.TestCase):
    def test_visible_projection_ignores_private_current_future_and_own_actions(self):
        rows = [reveal(1), reveal(2), reveal(2,'Ward',strength=7), reveal(3,seat=0),
                reveal(4), reveal(5)]
        rows.insert(2, dict(event=reveal(2)['event'],views=[None,None]))
        before = copy.deepcopy(rows)
        actual = project(rows,0,4)
        self.assertEqual([1,2,3],[r['round'] for r in actual])
        self.assertEqual(7,actual[1]['ward_strength'])
        self.assertEqual('Hunt',actual[1]['action'])
        self.assertEqual('Pass',actual[2]['action'])
        self.assertEqual(before,rows)
        actual[0]['strength']=999
        self.assertEqual(18,project(rows,0,4)[0]['strength'])

    def test_window_is_bounded_and_pass_rounds_decay_aggression(self):
        self.assertEqual(6,len(project([reveal(n) for n in range(1,12)],0,12)))
        original = dict(round=7,opponent_history=history())
        p=profile(original)
        self.assertEqual(100,p['aggression'])
        self.assertGreater(p['lane_weights']['Lord'],p['lane_weights']['Castle'])
        # No new attacks; recent quiet rounds carry more weight than old rushes.
        quiet = history()+[dict(round=n,action='Pass',lane='',cards=0,strength=0,ward_strength=0) for n in (7,8,9)]
        self.assertEqual(0,profile(dict(round=10,opponent_history=quiet))['aggression'])
        self.assertEqual(0,profile(dict(round=2,opponent_history=history(number=2)))['aggression'])
        small=history()
        for row in small: row.update(cards=2,strength=7)
        self.assertEqual(0,profile(dict(round=7,opponent_history=small))['aggression'])

    def test_observation_rebuilds_after_save_load_and_sealed_orders_do_not_change_memory(self):
        game=planning();game.clock.round=7
        game._state['events']['rows'].extend(reveal(n) for n in range(1,7))
        before=observe(game,0)
        restored=copy.deepcopy(game)
        restored._state=json.loads(json.dumps(game.snapshot()))
        self.assertEqual(before,observe(restored,0))
        restored._state['submissions'][1]=dict(secret='new attack')
        restored._state['combat_orders'][1]=dict(action='Hunt',strength=99)
        self.assertEqual(before,observe(restored,0))
        self.assertEqual({'round','action','lane','cards','strength','ward_strength'},set(before['opponent_history'][0]))

    def test_repeated_hunts_change_an_actual_legal_plan_and_prevent_banishment(self):
        game=planning('Gremory');world=game._state['world'];world['data']['ward_experiment']='U13_SPLIT_WARD_V1'
        # Give a normal five-card hand, remove old fixtures' hand cards.
        wanted=[('Penitent',4),('Penitent',4),('Vulture',3),('Butcher',4),('Wright',3)]
        available=[r for r in world['entities']['entities'] if r['kind']=='card']
        chosen=[]
        for suit,value in wanted:
            row=next(r for r in available if r not in chosen and r['attributes']['suit']==suit and r['attributes']['value']==value)
            chosen.append(row)
        power_components.prepare(game,[dict(kind='fixture_give',player_id=0,card_id=r['id']) for r in chosen])
        world=game._state['world'];available=world['entities']['entities']
        world['data']['card_zones']['hands'][0]=[r['id'] for r in chosen]
        for row in world['entities']['entities']:
            if row['kind']=='castle':row['attributes'].update(integrity=0,status='ruined')
        view=observe(game,0);view['round']=7;view['opponent_history']=history()
        cold=CommonSmartCore(lord_modules=False,opponent_memory_enabled=False).decide(view,Preview(game,0))
        hot=CommonSmartCore(lord_modules=False).decide(view,Preview(game,0))
        self.assertIn(cold['plan']['order']['action'], ('Hunt','Siege'))
        self.assertEqual('Ward',hot['plan']['order']['action'])
        self.assertEqual('Lord',hot['plan']['order']['lane'])
        self.assertLessEqual(hot['budget']['used']['complete_plans'],32)
        # Resolve both admitted choices against the same 18-strength attack.
        enemy_cards=world['data']['card_zones']['hands'][1]
        enemy=next(r for r in available if r['id'] in enemy_cards)
        enemy['attributes'].update(suit='Butcher',value=18)
        target=world['players'][0]['lord_entity_id']
        enemy_plan=dict(powers=[],order=dict(action='Hunt',lane='Lord',target_id=target,card_ids=[enemy['id']]))
        for expected,choice in ((False,cold),(True,hot)):
            replay=copy.deepcopy(game)
            result=replay.apply(dict(kind='submit',plans=[choice['plan'],enemy_plan]))
            self.assertNotEqual('invalid',result['action'],result)
            through(replay,'post_resolution_spawns')
            self.assertEqual(expected,economy.entity(replay._state['world'],target)['attributes']['alive'])

    def test_no_history_ablation_and_registry_order_are_stable(self):
        game=planning();v=observe(game,0)
        a=CommonSmartCore(lord_modules=False).decide(v,Preview(game,0))
        b=CommonSmartCore(lord_modules=False,opponent_memory_enabled=False).decide(v,Preview(game,0))
        self.assertEqual(a['plan'],b['plan'])
        v['round']=7;v['opponent_history']=history();before=copy.deepcopy(v)
        a=CommonSmartCore(lord_modules=False).decide(v,Preview(game,0))
        v['board'].reverse();v['hand'].reverse()
        b=CommonSmartCore(lord_modules=False).decide(v,Preview(game,0))
        self.assertEqual(a,b)
        v['board'].reverse();v['hand'].reverse();self.assertEqual(before,v)


if __name__=='__main__':unittest.main()
