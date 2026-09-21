"""Saving decisions, own-plan conflicts and real Reconfiguration lifecycle."""
import unittest
from unittest.mock import patch

from u13_pysim import economy, full_match_inputs, power_components
from u13_pysim.copying import copy_data
from u13_pysim.power_rules import declaration
from .common import CommonSmartCore
from .coordination import context, evaluate
from .facts import Facts, Proposal
from .lords.odradek import ResourceHorizon, SAVING_GOALS, proposals
from .observation import observe, Preview
from .planner_probe import PlannerObserver
from .test_common import planning
from .test_recipes_veil import hand


def prepared(points=3, guards=3, units=1, spacing=30):
    game = planning('Odradek'); world = game._state['world']
    cards = sorted((r for r in world['entities']['entities'] if r['kind'] == 'card'
                    and r['attributes']['value'] == 3 and r['id'] not in economy.zones(world)['hands'][0]),
                   key=lambda r: r['id'])[:guards]
    changes = [dict(kind='fixture_resources', player_id=0, resources=dict(reconfiguration=points))]
    changes += [dict(kind='fixture_guard', card_id=r['id'], player_id=1, lane='Castle', slot=i)
                for i, r in enumerate(cards)]
    changes += [dict(kind='fixture_marcher', player_id=1, lane='Lord', origin='horizon', ordinal=i,
                     attributes=dict(x_fp=800+spacing*i, y_fp=200)) for i in range(units)]
    power_components.prepare(game, changes)
    return game, [r['id'] for r in cards]


def only_pass(f, category, weights):
    if category == 'combat': yield Proposal('combat', 'Pass', {}, 0, 'directed_pass')


def decision(game):
    with patch('u13_doctrine.common.ordinary', only_pass), \
            patch('u13_doctrine.common.Recipes.proposals', return_value=iter(())):
        return CommonSmartCore().decide(observe(game, 0), Preview(game, 0))


def next_planning(game, choice):
    result = game.apply(dict(kind='submit', plans=[choice, dict(powers=[], order={})]))
    if result['action'] == 'invalid': raise AssertionError(result)
    while game.clock.hook != 'submission_lock' or game._state['submissions'] != [None, None]:
        result = game.apply(full_match_inputs.next_operation(game))
        if result['action'] == 'invalid': raise AssertionError(result)


def horizon(view, plan, winner=-1):
    f = Facts(view)
    options = [dict(power=p.term, target=p.payload['target']) for p in proposals(f) if p.term in SAVING_GOALS]
    return ResourceHorizon(f, options).evaluate(plan, context(f, plan), dict(winner=winner))


class OdradekTests(unittest.TestCase):
    def test_save_fourth_point_then_cast_inversion_and_resolve_real_guard_transfers(self):
        game, targets = prepared(); before = game.snapshot()
        saved = decision(game)
        self.assertEqual([], saved['plan']['powers'])
        self.assertEqual('Inversion', saved['resource_horizon']['selected']['goal']['power'])
        self.assertEqual(1, saved['resource_horizon']['selected']['goal']['income_ticks'])
        self.assertGreater(saved['resource_horizon']['omission_plans'], 0)
        self.assertEqual(before, game.snapshot())
        next_planning(game, saved['plan'])
        self.assertEqual(4, game._state['world']['players'][0]['resources']['reconfiguration'])
        cast = decision(game)
        self.assertEqual(['Inversion'], [p['power_id'] for p in cast['plan']['powers']])
        self.assertEqual(0, cast['resource_horizon']['selected']['remaining'])
        next_planning(game, cast['plan'])
        self.assertEqual(1, game._state['world']['players'][0]['resources']['reconfiguration'])
        self.assertEqual([0]*3, [economy.entity(game._state['world'], k)['owner'] for k in targets])
        events = [r['event'] for r in game._state['events']['rows']]
        changes = [e['data']['moved'] for e in events if e['type'] == 'RECONFIGURATION_RESOLVED'
                   and e['data']['power'] == 'Inversion']
        self.assertEqual([3], changes)

    def test_large_immediate_shift_outweighs_saving_for_inversion(self):
        game, _ = prepared(units=3)
        result = decision(game)
        self.assertEqual(['AllegianceShift'], [p['power_id'] for p in result['plan']['powers']])

    def test_valuable_redirect_is_not_vetoed_while_below_three(self):
        game, _ = prepared(points=1, guards=0, units=7, spacing=220)
        result = decision(game)
        self.assertEqual(['Redirect'], [p['power_id'] for p in result['plan']['powers']])
        self.assertFalse(result['resource_horizon']['hard_veto'])

    def test_inversion_current_and_saved_value_account_for_own_deployments(self):
        game, _ = prepared(points=4, units=0)
        view = observe(game, 0); hand(view, [('Butcher', 1)]*3)
        p = dict(powers=[declaration(0, 1, 'Inversion', dict(owner_id=1, lane='Castle'))],
                 order=dict(guard_moves=[dict(card_id=r['id'], lane='Castle', slot=i) for i, r in enumerate(view['hand'])]))
        adjusted = evaluate(Facts(view), p)
        self.assertEqual(-60, adjusted['score_delta'])
        p['powers'] = []
        self.assertEqual(0, horizon(view, p)['score'])
        p['order']['guard_moves'].pop()
        self.assertEqual(1, len(horizon(view, p)['goal']['target_ids']))

    def test_own_attack_removes_future_inversion_targets_and_false_orders_target(self):
        game, targets = prepared(points=4, guards=1, units=0)
        view = observe(game, 0); hand(view, [('Butcher', 5)])
        f = Facts(view)
        p = dict(powers=[], order=dict(action='Siege', lane='Castle', target_id=f.castles(1)[0]['id'], card_ids=['ingredient:0']))
        self.assertEqual(0, horizon(view, p)['score'])
        p['powers'] = [declaration(0, 1, 'FalseOrders', dict(entity_id=targets[0], owner_id=1, lane='Lord'))]
        self.assertLess(evaluate(f, p)['score_delta'], 0)

    def test_redirect_then_shift_does_not_receive_double_material_credit(self):
        game, _ = prepared(points=4, guards=0, units=3)
        f = Facts(observe(game, 0)); target, _ = f.cluster('Lord', 180, friendly_penalty=0)
        p = dict(powers=[declaration(0, 1, 'AllegianceShift', target), declaration(0, 1, 'Redirect', target, index=1)], order={})
        # Hook order moves units first even when Shift was queued first.
        rows = evaluate(f, p)['powers']
        shifted=next(r for r in rows if r['power']=='AllegianceShift')
        self.assertEqual([],shifted['eligible_after'])
        self.assertEqual(0,shifted['score'])
        self.assertLess(shifted['score_delta'],0)
        result = decision(game)
        self.assertEqual(['AllegianceShift'], [s['power_id'] for s in result['plan']['powers']])

    def test_redirecting_whole_crowd_is_not_credited_as_pressure_relief(self):
        game, _ = prepared(points=1, guards=0, units=3)
        f = Facts(observe(game, 0)); target, _ = f.cluster('Lord', 300)
        p = dict(powers=[declaration(0, 1, 'Redirect', target)], order={})
        result = evaluate(f, p)['powers'][0]
        self.assertEqual(result['pressure_before'], result['pressure_after'])
        self.assertEqual('redirect_only_relocates_pressure', result['reason'])
        self.assertEqual([], decision(game)['plan']['powers'])

    def test_false_orders_future_goal_uses_new_lane(self):
        game, targets = prepared(points=4, guards=2, units=0)
        view = observe(game, 0)
        p = dict(powers=[declaration(0, 1, 'FalseOrders', dict(entity_id=targets[0], owner_id=1, lane='Lord'))], order={})
        result = horizon(view, p)
        self.assertEqual([targets[1]], result['goal']['target_ids'])

    def test_no_target_banished_source_and_terminal_scenario_give_no_future_credit(self):
        blank, _ = prepared(points=4, guards=0, units=0)
        p = dict(powers=[], order={})
        self.assertEqual(0, horizon(observe(blank, 0), p)['score'])
        game, _ = prepared(); view = observe(game, 0)
        for row in view['board']:
            if row['kind'] == 'lord' and row['owner'] == 0: row['attributes']['alive'] = False
        self.assertEqual(0, horizon(view, p)['score'])
        for winner in (0, 1):
            self.assertEqual(0, horizon(observe(game, 0), p, winner)['score'])

    def test_horizon_stops_at_two_missing_incomes_and_counts_one_best_goal(self):
        game, _ = prepared(points=1, units=0); view = observe(game, 0)
        p = dict(powers=[], order={})
        self.assertEqual(0, horizon(view, p)['score'])
        view['players'][0]['resources']['reconfiguration'] = 2
        result = horizon(view, p)
        self.assertEqual(2, result['goal']['income_ticks'])
        self.assertEqual(3, len(result['goal']['target_ids']))

    def test_resource_choices_are_bounded_deterministic_and_do_not_change_authority(self):
        game, _ = prepared(); before = game.snapshot(); view = observe(game, 0)
        first = CommonSmartCore().decide(view, Preview(game, 0))
        shuffled = copy_data(view); shuffled['board'].reverse(); shuffled['hand'].reverse()
        self.assertEqual(first, CommonSmartCore().decide(shuffled, Preview(game, 0)))
        self.assertEqual(before, game.snapshot())
        self.assertEqual([], first['rejected_previews'])
        for key, count in first['budget']['used'].items():
            limit = 16 if key.startswith('generated:') else 4 if key.startswith('retained:') else 32 if key == 'complete_plans' else 8
            self.assertLessEqual(count, limit)

    def test_observer_records_saving_separately_from_actual_casts(self):
        game, _ = prepared(); result = decision(game)
        observer = PlannerObserver(dict(name='odradek-saving', setup=dict(lords=['Odradek', 'Gremory'])))
        observer.accepted(1, 0, result)
        self.assertEqual(1, observer.report()['resource_horizon']['saved_for:Inversion'])
        self.assertFalse(any(a['term'] == 'Inversion' and a['selected'] for a in result['assessments']))


if __name__ == '__main__': unittest.main()
