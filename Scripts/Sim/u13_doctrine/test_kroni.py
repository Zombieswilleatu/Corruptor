"""Meal priorities, hard attack-lane separation, and uncertain route timing."""
import unittest
from unittest.mock import patch

from u13_pysim import kroni_actors, power_components
from u13_pysim.copying import copy_data
from .common import CommonSmartCore
from .coordination import context
from .facts import Facts
from .kroni_tactics import consume_targets, consume_value, ravenous_targets, ravenous_value
from .observation import observe, Preview
from .selection import PlanSelector, SelectionSettings
from .test_common import planning
from .test_coordination import guard, prepared, attack_source
from .test_lane_support import unit
from .test_recipes_veil import hand


class KroniTests(unittest.TestCase):
    def test_consume_pair_then_value_and_broken_pair_loses_priority(self):
        view = observe(planning('Kroni'), 0)
        guard(view, 'pair-low', 1, 0, suit='Penitent')
        guard(view, 'pair-high', 2, 1, suit='Penitent')
        guard(view, 'expensive', 8, 2)
        guard(view, 'opposite-low', 3, 0, 'Lord')
        guard(view, 'opposite-high', 5, 1, 'Lord')
        view['data']['guard_work']['pairs'] = [dict(active=True, player_id=1, lane='Castle', suit='Penitent', ids=['pair-low','pair-high'], slots=[0,1])]
        self.assertEqual({'pair-high', 'opposite-high'}, {r['id'] for r in consume_targets(Facts(view))})
        view['board'] = [r for r in view['board'] if r['id'] != 'pair-low']
        self.assertEqual({'expensive', 'opposite-high'}, {r['id'] for r in consume_targets(Facts(view))})

    def test_every_preview_respects_opposite_lane_even_under_softmax(self):
        game, _, attack = prepared('Kroni')
        world = game._state['world']
        from u13_pysim import economy
        card = next(r for r in world['entities']['entities'] if r['kind']=='card' and r['attributes'].get('role') != 'guard' and r['id'] not in economy.zones(world)['hands'][0])
        power_components.prepare(game, [dict(kind='fixture_guard', card_id=card['id'], player_id=1, lane='Lord', slot=0)])
        before = game.snapshot(); observed = []
        authority = Preview(game, 0)
        def preview(plan):
            observed.append(copy_data(plan)); return authority(plan)
        for seed in ('lane-a', 'lane-b', 'lane-c'):
            policy = CommonSmartCore(selector=PlanSelector(SelectionSettings(20, 100, seed)))
            with patch('u13_doctrine.common.ordinary', attack_source(attack)):
                result = policy.decide(observe(game, 0), preview)
            self.assertEqual([], result['rejected_previews'])
            self.assertLessEqual(result['budget']['used']['complete_plans'], 32)
            self.assertLessEqual(result['budget']['used']['previews'], 8)
        seen = 0; f = Facts(observe(game, 0))
        for p in observed:
            if p['order'].get('action') not in ('Hunt','Siege'): continue
            for shot in p['powers']:
                if shot['power_id'] == 'Consume':
                    seen += 1
                    self.assertNotEqual(p['order']['lane'], f.by_id[shot['target']['entity_id']]['attributes']['lane'])
        self.assertGreater(seen, 0)
        self.assertEqual(before, game.snapshot())

    def test_feeding_milestone_is_conditional_and_ward_pays_hunger_first(self):
        view = observe(planning('Kroni'), 0); guard(view, 'meal', 3)
        f = Facts(view); f.lord[0]['attributes']['hunger'] = 2
        attack = dict(powers=[], order=dict(action='Hunt', lane='Lord'))
        target = dict(entity_id='meal')
        milestone = consume_value(f, target, attack)
        self.assertEqual(30, milestone['feed_score'])
        self.assertEqual('next_round_start', milestone['timing'])
        f.lord[0]['attributes']['hunger_milestone'] = True
        self.assertEqual(14, consume_value(f, target, attack)['feed_score'])
        self.assertEqual(3, consume_value(f, target, dict(powers=[], order=dict(action='Ward')))['feed_score'])

    def test_ravenous_holds_empty_board_and_prices_both_lanes_and_recruits(self):
        view = observe(planning('Kroni'), 0)
        target = dict(lane='Lord', field_position=dict(x_fp=0, y_fp=450))
        self.assertEqual([], list(ravenous_targets(Facts(view))))
        self.assertLess(ravenous_value(Facts(view), target)['score'], 0)
        for i in range(8): unit(view, 'enemy:'+str(i), 1, 'Castle', x_fp=900+i*30, y_fp=100+i*40)
        clean = ravenous_value(Facts(view), target)
        self.assertGreater(clean['score'], 0)
        self.assertGreater(clean['qualifying_samples'], 0)
        self.assertGreater(len({r['enemies'] for r in clean['routes']}), 1)
        # Same-plan birth-round bodies stay at their spawn area and can be eaten.
        hand(view, [('Butcher', 8)]); f = Facts(view)
        plan = dict(powers=[], order=dict(action='Ward', lane='Lord', card_ids=['ingredient:0']))
        exposed = ravenous_value(f, target, context(f, plan), plan)
        self.assertEqual(4, exposed['friendly_recruits'])
        self.assertLess(exposed['score'], clean['score'])
        self.assertTrue(any(r['allies'] > 0 for r in exposed['routes']))
        self.assertEqual(exposed, ravenous_value(f, target, context(f, plan), plan))

    def test_fear_credit_needs_gate_pressure_or_nearby_support(self):
        view = observe(planning('Kroni'), 0)
        for i in range(3): unit(view, 'enemy:'+str(i), 1, 'Lord', x_fp=1100+i*50, y_fp=250+i*30)
        target = dict(lane='Lord', field_position=dict(x_fp=0,y_fp=300))
        unsupported = ravenous_value(Facts(view), target)
        unit(view, 'support', 0, 'Lord', suit='Vulture', x_fp=1100, y_fp=300)
        supported = ravenous_value(Facts(view), target)
        self.assertGreater(sum(r['control'] for r in supported['routes']), sum(r['control'] for r in unsupported['routes']))

    def test_qualified_launches_keep_variance_fallback_and_mirroring(self):
        view = observe(planning('Kroni'), 0)
        units = [unit(view, 'enemy:'+str(i), 1, 'Lord', x_fp=800+i*200, y_fp=100+i*50) for i in range(2)]
        base = kroni_actors.create('variance',0,1,0)
        routes = kroni_actors.favored(base, units); seen = set()
        for i in range(32):
            actor = kroni_actors.create('variance',0,1,0,seed=str(i),units=units)
            self.assertEqual('favored', actor['launch_mode'])
            self.assertIn(actor['vy_fp'], routes); seen.add(actor['vy_fp'])
        self.assertGreater(len(seen), 4)
        single = kroni_actors.create('variance',0,1,0,units=units[:1])
        self.assertEqual('fallback', single['launch_mode'])
        mirrored = copy_data(units)
        for row in mirrored: row['owner']=0; row['attributes']['x_fp']=2400-row['attributes']['x_fp']
        self.assertEqual(routes, kroni_actors.favored(kroni_actors.create('variance',1,1,0),mirrored))


if __name__ == '__main__': unittest.main()
