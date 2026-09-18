"""Real Development/combat replays and bounded public defense contracts."""
import copy
import json
from pathlib import Path
import unittest

from u13_pysim import economy, full_match_inputs, power_components
from u13_pysim.power_match import PowerMatch
from u13_pysim.power_rules import declaration
from .budget import Limits
from .common import CommonSmartCore, Weights, ordinary
from .defensive_plans import Defense, development, exposure, CARD_PRESSURES
from .diagnostics import fingerprint
from .facts import Facts
from .observation import observe, Preview
from .test_common import planning
from .test_recipes_veil import hand


def castle(view, kind='Keep'):
    return next(r for r in view['board'] if r['kind'] == 'castle' and
                r['owner'] == view['player_id'] and r['attributes']['castle_type'] == kind)


def work_plan(target, moves=(), action='Work'):
    return dict(powers=[], order=dict(guard_moves=list(moves), castle_action=dict(
        action=action, target_id=target, card_ids=[], use_repair_token=False)))


def through(game, hook):
    while game.clock.hook != hook:
        result = game.apply(full_match_inputs.next_operation(game))
        if result['action'] == 'invalid': raise AssertionError(result)


class DefensivePlansTests(unittest.TestCase):
    def test_fresh_wright_repair_matches_real_development_without_mutating_authority(self):
        game = planning('Humbaba'); view = observe(game, 0)
        keep = castle(view)['id']
        cards = [r for r in game._state['world']['entities']['entities'] if r['kind'] == 'card'
                 and r['attributes']['suit'] == 'Wright'][:2]
        power_components.prepare(game, [dict(kind='fixture_give', player_id=0, card_id=r['id']) for r in cards]+
            [dict(kind='fixture_patch', entity_id=keep, attributes=dict(integrity=9))])
        plan = work_plan(keep, [dict(card_id=r['id'], lane='Lord', slot=i) for i,r in enumerate(cards)])
        before = game.snapshot()
        projected, details = development(Facts(observe(game, 0)), plan)
        self.assertEqual(before, game.snapshot())
        self.assertEqual((5, 5), (details['guard_work'], details['gain']))
        self.assertEqual('legal', Preview(game, 0)(plan)['action'])
        self.assertNotEqual('invalid', game.apply(dict(kind='submit', plans=[plan, dict(powers=[], order={})]))['action'])
        through(game, 'post_repair_artillery')
        self.assertEqual(economy.entity(projected, keep)['attributes'], economy.entity(game._state['world'], keep)['attributes'])

    def test_repair_lock_cap_and_old_wright_do_not_invent_work(self):
        view = observe(planning(), 0); hand(view, [('Wright', 2)])
        target = castle(view); target['attributes']['integrity'] = 16
        view['board'].append(dict(id='old', kind='card', owner=0, attributes=dict(
            role='guard', lane='Lord', slot=0, suit='Wright', value=3)))
        p = work_plan(target['id'], [dict(card_id='ingredient:0', lane='Lord', slot=1)])
        _, details = development(Facts(view), p)
        self.assertEqual((1,1), (details['guard_work'], details['gain']))
        target['attributes']['repair_lock_until_round'] = view['round']
        _, details = development(Facts(view), p)
        self.assertEqual(0, details['gain']); self.assertTrue(details['locked'])
        target['attributes'].pop('repair_lock_until_round')
        target['attributes']['integrity'] = 17
        self.assertEqual(0, development(Facts(view), p)[1]['gain'])

    def test_activation_keeps_previous_work_target_and_automatic_completion(self):
        view = observe(planning(), 0); hand(view, [('Wright', 2)]*2)
        keep, bastion = castle(view), castle(view, 'Bastion')
        keep['attributes']['integrity'] = 9
        bastion['attributes'].update(integrity=7, construction_state='building', status='standing')
        view['data']['guard_work']['targets'][0] = keep['id']
        moves = [dict(card_id=r['id'], lane='Castle', slot=i) for i,r in enumerate(view['hand'])]
        world, details = development(Facts(view), work_plan(bastion['id'], moves, 'Activate'))
        self.assertEqual(keep['id'], details['target_id'])
        self.assertEqual(14, economy.entity(world, keep['id'])['attributes']['integrity'])
        self.assertEqual([bastion['id']], details['activated'])
        bastion['attributes']['integrity'] = 15
        _, details = development(Facts(view), work_plan(bastion['id'], moves))
        self.assertEqual(2, details['gain']); self.assertEqual([bastion['id']], details['activated'])

    def test_previous_passive_work_is_not_credited_twice(self):
        view = observe(planning(), 0); target = castle(view, 'Bastion')
        view['data']['guard_work']['targets'][0] = target['id']
        f = Facts(view); model = Defense(f, Weights())
        empty = model.evaluate(dict(powers=[], order={}), [], dict(winner=-1))
        proposal = next(p for p in ordinary(f, 'work', Weights()) if p.payload['castle_action']['target_id'] == target['id'])
        explicit = model.evaluate(dict(powers=[], order=proposal.payload), [proposal], dict(winner=-1))
        self.assertEqual(0, empty['score_delta'])
        self.assertEqual(empty['score_delta'], proposal.value+explicit['score_delta'])

    def test_keep_strict_guard_screen_and_ward_half_lane(self):
        view = observe(planning(), 0); hand(view, [('Penitent', 3)]*2)
        castle(view)['attributes']['integrity'] = 7
        view['data']['sigils'][0] = dict(Lord='', Castle='')
        f = Facts(view); empty = dict(powers=[], order={})
        self.assertFalse(exposure(f, f.world, empty, 'Lord', 9)['castles_lost'])
        self.assertEqual(1, exposure(f, f.world, empty, 'Lord', 10)['castles_lost'])
        p = dict(powers=[], order=dict(action='Ward', lane='Castle', card_ids=['ingredient:0','ingredient:1']))
        self.assertEqual(0, exposure(f, f.world, p, 'Lord', 12)['castles_lost'])
        self.assertEqual(1, exposure(f, f.world, p, 'Lord', 13)['castles_lost'])
        p['order'] = dict(guard_moves=[dict(card_id='ingredient:'+str(i), lane='Lord', slot=i) for i in range(2)])
        world,_ = development(f,p)
        self.assertEqual(0, exposure(f, world, p, 'Lord', 18)['castles_lost'])
        self.assertEqual(1, exposure(f, world, p, 'Lord', 19)['castles_lost'])

    def test_bastion_intercepts_and_projection_spend_removes_essence_screen(self):
        view = observe(planning('Valak'), 0)
        bastion = castle(view,'Bastion'); bastion['attributes'].update(integrity=8, construction_state='active', status='standing')
        castle(view,'Stockpile')['attributes']['integrity'] = 7
        view['data']['sigils'][0] = dict(Lord='', Castle='')
        f = Facts(view); empty = dict(powers=[],order={})
        self.assertEqual(1, exposure(f,f.world,empty,'Castle',14)['castles_lost'])
        self.assertEqual(2, exposure(f,f.world,empty,'Castle',15)['castles_lost'])
        castle(view)['attributes']['integrity'] = 7
        view['players'][0]['resources']['life_essence'] = 5
        f = Facts(view)
        paid = dict(powers=[declaration(0,1,'Projection',dict(kind='guard_zone',zone='Castle',player_id=1),parameters=dict(spend=5))],order={})
        self.assertEqual(0, exposure(f,f.world,empty,'Lord',10)['castles_lost'])
        self.assertEqual(1, exposure(f,f.world,paid,'Lord',10)['castles_lost'])

    def test_no_defense_credit_for_terminal_or_unmodeled_sacrifice_and_summon(self):
        model = Defense(Facts(observe(planning(),0)), Weights())
        for order, winner in [({},0), ({'summon':{'card_ids':[]}},-1), ({'action':'Profane'},-1)]:
            result = model.evaluate(dict(powers=[],order=order),[],dict(winner=winner))
            self.assertFalse(result['enabled']); self.assertEqual(0,result['score_delta'])

    def test_registry_order_and_small_work_limits_remain_deterministic(self):
        game = planning(); view = observe(game,0); before = game.snapshot()
        policy = CommonSmartCore(limits=Limits(generated_per_category=6,retained_per_category=2,complete_plans=8,previews=2))
        first = policy.decide(view,Preview(game,0)); view['board'].reverse(); view['hand'].reverse()
        self.assertEqual(first,policy.decide(view,Preview(game,0)))
        self.assertEqual(before,game.snapshot())
        self.assertLessEqual(first['budget']['used']['complete_plans'],8)
        self.assertEqual(list(CARD_PRESSURES),first['defense']['card_pressures'])

    def test_natural_repair_and_guard_choices_preserve_keeps_in_real_combat(self):
        source=json.loads(Path(__file__).with_name('early_defense_cases.json').read_text())
        for case in source['cases']:
            with self.subTest(case=case['name']):
                game=PowerMatch(case['setup'])
                for op in case['prefix']: self.assertNotEqual('invalid',game.apply(op)['action'])
                view=observe(game,case['seat']); self.assertEqual(case['view_sha256'],fingerprint(view))
                before=game.snapshot()
                choice=CommonSmartCore().decide(view,Preview(game,case['seat']))
                self.assertEqual(before,game.snapshot())
                # The candidate has already selected before the recorded enemy
                # plan enters either replay. These are diagnostics, not foresight.
                for candidate in (False,True):
                    replay=copy.deepcopy(game);plans=copy.deepcopy(case['original_plans'])
                    if candidate: plans[case['seat']]=choice['plan']
                    self.assertNotEqual('invalid',replay.apply(dict(kind='submit',plans=plans))['action'])
                    through(replay,'post_resolution_spawns')
                    keep=economy.entity(replay._state['world'],case['protected_castle'])
                    self.assertEqual(candidate,keep['attributes']['integrity']>0)
                self.assertTrue(choice['plan']['order'].get('monster_choice'))


if __name__ == '__main__': unittest.main()
