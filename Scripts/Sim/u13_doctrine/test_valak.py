"""Valak tactical decisions and bounded search; no balance campaign."""
import unittest
from unittest.mock import patch

from u13_pysim.copying import copy_data
from u13_pysim.power_rules import declaration
from .common import CommonSmartCore
from .coordination import context, evaluate
from .facts import Facts
from .lords.valak import proposals
from .observation import observe, Preview
from .test_common import planning
from .test_lane_support import unit
from .test_recipes_veil import hand
from .valak_tactics import orb_targets, orb_value, projection_value


def view(essence=3):
    v = observe(planning('Valak'), 0)
    v['players'][0]['resources']['life_essence'] = essence
    return v


def target(x, y=300, lane='Castle'):
    return dict(lane=lane, field_position=dict(x_fp=x, y_fp=y))


def guard(v, name, owner=1, value=2, lane='Castle', slot=0, suit='Butcher'):
    r = dict(id=name, kind='card', owner=owner, attributes=dict(role='guard', value=value, lane=lane, slot=slot, suit=suit))
    v['board'].append(r)
    return r


def shot(v, owner=1, spend=2, order=None):
    f = Facts(v); t = dict(kind='guard_zone', zone='Castle', player_id=owner)
    p = dict(powers=[declaration(0, v['round'], 'Projection', t, parameters=dict(spend=spend))], order=order or {})
    return projection_value(f, t, spend, p, context(f, p))


class ValakTests(unittest.TestCase):
    def test_orb_distinguishes_core_from_slow_outer_damage(self):
        v = view(); unit(v, 'stationary', 1, x_fp=1200, y_fp=300, movement_ready_round=9, hp=20)
        core = orb_value(Facts(v), target(1200))
        outer = orb_value(Facts(v), target(1400))
        self.assertTrue(core['bodies'][0]['core'])
        self.assertFalse(outer['bodies'][0]['core'])
        self.assertGreater(core['damage_score'], outer['damage_score'])
        self.assertLessEqual(outer['damage_score'], 15)

    def test_orb_pull_can_delay_or_accelerate_instead_of_freezing_all_units(self):
        v = view(); unit(v, 'enemy', 1, x_fp=250, y_fp=300, hp=20)
        behind = orb_value(Facts(v), target(400, 440))
        ahead = orb_value(Facts(v), target(80, 440))
        self.assertGreater(behind['bodies'][0]['delay_fp'], 0)
        self.assertLess(ahead['bodies'][0]['delay_fp'], 0)
        self.assertGreater(behind['control_score'], ahead['control_score'])

    def test_orb_accounts_for_second_phase_arrivals_and_lane(self):
        v = view(); unit(v, 'late', 1, x_fp=2200, y_fp=300)
        value = orb_value(Facts(v), target(950))
        self.assertEqual(2, value['phases'])
        self.assertTrue(value['bodies'][0]['entry_next_round'])
        self.assertEqual([], orb_value(Facts(v), target(950, lane='Lord'))['bodies'])
        v['board'][-1]['attributes']['movement_ready_round'] = 3
        self.assertEqual([], orb_value(Facts(v), target(950))['bodies'])

    def test_orb_penalizes_own_core_and_planned_spawn_exposure(self):
        v = view(); unit(v, 'enemy', 1, x_fp=150, y_fp=300)
        f = Facts(v); base = orb_value(f, target(60))
        unit(v, 'friend', 0, x_fp=60, y_fp=300)
        self.assertLess(orb_value(Facts(v), target(60))['score'], base['score'])
        v['board'] = [r for r in v['board'] if r['id'] != 'friend']
        hand(v, [('Vulture', 4)]); f = Facts(v)
        p = dict(powers=[declaration(0, 1, 'GravityOrb', target(60))],
                 order=dict(action='Ward', lane='Castle', card_ids=['ingredient:0']))
        result = evaluate(f, p)['powers'][0]
        self.assertEqual(2, result['planned_recruits'])
        self.assertGreater(result['friendly_cost'], 0)
        self.assertLess(result['score_delta'], 0)

    def test_orb_support_concentration_and_spent_supplicants(self):
        v = view(); unit(v, 'enemy', 1, x_fp=1100, y_fp=300, hp=30)
        unit(v, 'shooter', 0, x_fp=750, y_fp=300, suit='Vulture', waiting=True, movement_ready_round=3)
        f = Facts(v); t = target(1000, 500)
        value = orb_value(f, t)
        self.assertGreater(value['bodies'][0]['support_score'], 0)
        ctx = context(f, dict(powers=[], order=dict(rites=dict(waiter_spends=[dict(lane='Castle', marcher_ids=['shooter'])]))))
        after = orb_value(f, t, ctx)
        self.assertEqual(0, after['bodies'][0]['support_score'])

    def test_projection_holds_reserve_and_uses_only_unspent_follow_up_cards(self):
        v = view(5); guard(v, 'victim', value=3); hand(v, [('Butcher', 5)]*2)
        before = shot(v, spend=3)
        v['players'][0]['resources']['life_essence'] = 3
        self.assertLess(shot(v, spend=3)['score'], before['score'])
        f = Facts(v)
        spent = shot(v, spend=3, order=dict(action='Ward', lane='Castle', card_ids=[r['id'] for r in f.hand]))
        self.assertEqual(0, spent['follow_up_score'])
        self.assertGreater(before['follow_up_score'], spent['follow_up_score'])
        self.assertEqual('post_resolution_direct', before['timing'])

    def test_sacrifice_requires_net_gain_and_concrete_charge_threshold(self):
        v = view(1); guard(v, 'cheap', owner=0, value=1); guard(v, 'enemy', value=2)
        result = shot(v, owner=0, spend=1)
        self.assertEqual(1, result['net_essence'])
        self.assertGreater(result['score'], 0)
        v['players'][0]['resources']['life_essence'] = 5
        self.assertLess(shot(v, owner=0, spend=1)['score'], 0)
        v['players'][0]['resources']['life_essence'] = 1
        v['board'] = [r for r in v['board'] if r['id'] != 'enemy']
        self.assertLess(shot(v, owner=0, spend=1)['score'], 0)

    def test_sacrifice_preserves_pair_and_dangerous_lane(self):
        v = view(1); guard(v, 'cheap', owner=0, value=1, suit='Penitent')
        guard(v, 'partner', owner=0, value=2, slot=1, suit='Penitent'); guard(v, 'enemy', value=2)
        v['data']['guard_work']['pairs'] = [dict(player_id=0, lane='Castle', suit='Penitent', ids=['cheap', 'partner'], slots=[0, 1], active=True)]
        self.assertLess(shot(v, owner=0, spend=1)['score'], 0)
        v['data']['guard_work']['pairs'] = []
        unit(v, 'incoming', 1, x_fp=150)
        self.assertLess(shot(v, owner=0, spend=1)['score'], 0)

    def test_sacrifice_rechecks_new_deployments_and_tie_order(self):
        v = view(1); guard(v, 'old', owner=0, value=1, slot=2); guard(v, 'enemy', value=2)
        hand(v, [('Penitent', 1), ('Penitent', 1)])
        order = dict(guard_moves=[dict(card_id='ingredient:'+str(i), lane='Castle', slot=i) for i in range(2)])
        changed = shot(v, owner=0, spend=1, order=order)
        self.assertEqual('ingredient:0', changed['victim_id'])
        self.assertEqual(12, changed['pair_cost'])
        self.assertLess(changed['score'], 0)

    def test_orb_and_projection_generation_and_search_stay_bounded(self):
        v = view(5)
        for lane in ('Lord', 'Castle'):
            for i in range(30): unit(v, lane+str(i), 1, lane=lane, x_fp=500+i*50, y_fp=300)
            for owner in (0, 1): guard(v, lane+str(owner), owner, 1, lane)
        f = Facts(v)
        self.assertLessEqual(len(list(orb_targets(f, 'Castle'))), 6)
        self.assertLessEqual(len(list(proposals(f))), 16)
        before = copy_data(v)
        d = CommonSmartCore().decide(v, lambda p: dict(action='legal'))
        self.assertTrue(d['valak']['enabled']); self.assertEqual(before, v)
        for name, used in d['budget']['used'].items():
            limit = 16 if name.startswith('generated:') else 4 if name.startswith('retained:') else 32 if name == 'complete_plans' else 8
            self.assertLessEqual(used, limit)
        v['board'].reverse(); v['hand'].reverse()
        self.assertEqual(d, CommonSmartCore().decide(v, lambda p: dict(action='legal')))

    def test_complete_plan_selects_useful_sacrifice_and_holds_at_cap(self):
        v = view(1); hand(v, [])
        guard(v, 'cheap', owner=0, value=1); guard(v, 'enemy', value=2)
        policy = CommonSmartCore()
        result = policy.decide(v, lambda p: dict(action='legal'))
        shot = next(s for s in result['plan']['powers'] if s['power_id'] == 'Projection')
        self.assertEqual(0, shot['target']['player_id'])
        self.assertEqual(1, shot['parameters']['spend'])
        v['players'][0]['resources']['life_essence'] = 5
        result = policy.decide(v, lambda p: dict(action='legal'))
        self.assertFalse(any(s['power_id'] == 'Projection' and s['target']['player_id'] == 0 for s in result['plan']['powers']))

    def test_orb_mirrors_player_seats(self):
        v = view(); unit(v, 'enemy', 1, x_fp=650, y_fp=300)
        expected = orb_value(Facts(v), target(800, 440))
        other = copy_data(v); other['player_id'] = 1; other['players'].reverse()
        for r in other['board']+other['hand']:
            if r['owner'] in (0, 1): r['owner'] = 1-r['owner']
            if r['kind'] == 'marcher': r['attributes']['x_fp'] = 2400-r['attributes']['x_fp']
        self.assertEqual(expected, orb_value(Facts(other), target(1600, 440)))


if __name__ == '__main__': unittest.main()
