"""Decision contrasts and experiment controls, with no rule changes."""
import copy
import unittest

from u13_pysim import economy, opening, power_components
from u13_pysim.power_rules import declaration
from .budget import Limits
from .common import CommonSmartCore, Weights
from .facts import Facts
from .lords.deimos import ArtilleryPlans
from .observation import observe, Preview
from .planner_probe import PlannerObserver
from .rout_comparison import cases, LOADOUTS, aggregate
from .rout_delay import RoutDelay
from .test_common import planning
from .test_deimos import prepared, plan
from .test_lane_support import unit


def assessment(view, choice):
    f = Facts(view)
    return RoutDelay(f, ArtilleryPlans(f, Weights())).evaluate(choice, dict(winner=-1))


class RoutDelayTests(unittest.TestCase):
    def test_small_wave_is_held_but_large_gate_wave_is_delayed_without_engines(self):
        game = planning('Deimos')
        for row in game._state['world']['entities']['entities']:
            if row['kind'] == 'castle' and row['owner'] == 0:
                row['attributes']['combat_profile'] = 'plain_integrity'
        power_components.prepare(game, [dict(kind='fixture_marcher', player_id=1, lane='Lord',
            origin='pressure', ordinal=0, attributes=dict(x_fp=100, y_fp=300))])
        # No known recruitment/recovery goal in this small-wave contrast.
        view = observe(game, 0); view['hand'] = []
        old = CommonSmartCore().decide(view, Preview(game, 0))
        new = CommonSmartCore(rout_mode='new').decide(view, Preview(game, 0))
        self.assertIn('Rout', [s['power_id'] for s in old['plan']['powers']])
        self.assertNotIn('Rout', [s['power_id'] for s in new['plan']['powers']])
        power_components.prepare(game, [dict(kind='fixture_marcher', player_id=1, lane='Lord',
            origin='pressure', ordinal=i, attributes=dict(x_fp=100, y_fp=150+100*i)) for i in (1, 2, 3)])
        new = CommonSmartCore(rout_mode='new').decide(observe(game, 0), Preview(game, 0))
        self.assertIn('Rout', [s['power_id'] for s in new['plan']['powers']])
        self.assertEqual('legal', Preview(game, 0)(new['plan'])['action'])
        observer = PlannerObserver(dict(name='new_rout_logging', setup=dict(lords=['Deimos', 'Gremory'])))
        observer.accepted(game.clock.round, 0, new)
        self.assertEqual(1, observer.report()['power_coordination']['selected:Rout:conditional_delay_goals'])

    def test_no_rout_keeps_war_machine_and_other_lords_plans(self):
        game, engine, _, _ = prepared(hp=10)
        power_components.prepare(game, [dict(kind='fixture_marcher', player_id=1, lane='Castle',
            origin='gate', ordinal=i, attributes=dict(x_fp=100, y_fp=100+60*i)) for i in range(8)])
        choice = CommonSmartCore(rout_mode='none').decide(observe(game, 0), Preview(game, 0))
        powers = [s['power_id'] for s in choice['plan']['powers']]
        self.assertNotIn('Rout', powers); self.assertIn('WarMachine', powers)
        self.assertEqual('disabled_for_rout_ablation', next(a for a in choice['assessments'] if a['term'] == 'Rout')['reason'])
        for lord in opening.LORDS:
            if lord == 'Deimos': continue
            game = planning(lord); view = observe(game, 0)
            old = CommonSmartCore().decide(view, Preview(game, 0))
            for mode in ('new', 'none'):
                actual = CommonSmartCore(rout_mode=mode).decide(view, Preview(game, 0))
                actual['policy'] = old['policy']
                self.assertEqual(old, actual)

    def test_next_volley_credit_excludes_current_volley_and_current_siege_kills(self):
        game, engine, victim, _ = prepared(hp=3)
        view = observe(game, 0); unit(view, 'enemy', 1, x_fp=100)
        choice = plan(game, engine)
        choice['powers'].append(declaration(0, 1, 'Rout', dict(lane='Castle'), index=1))
        self.assertEqual([], assessment(view, choice)['next_volley_finish_targets'])
        # Six Integrity survives the four current-round artillery damage but
        # falls to next round's known lock, conditional on engine survival.
        next(r for r in view['board'] if r['id'] == victim)['attributes']['integrity'] = 6
        self.assertEqual([victim], assessment(view, choice)['next_volley_finish_targets'])
        self.assertEqual(18, assessment(view, choice)['finish_credit'])
        choice['order'] = dict(action='Siege', lane='Castle', target_id=victim,
                              card_ids=[r['id'] for r in view['hand']])
        self.assertEqual([], assessment(view, choice)['next_volley_finish_targets'])

    def test_unknown_acquisitions_and_no_pressure_earn_no_finish_credit(self):
        game, engine, victim, _ = prepared(hp=6)
        view = observe(game, 0); choice = plan(game, engine)
        choice['powers'].append(declaration(0, 1, 'Rout', dict(lane='Castle'), index=1))
        self.assertEqual(0, assessment(view, choice)['finish_credit'])
        unit(view, 'enemy', 1, x_fp=100)
        next(r for r in view['board'] if r['id'] == engine)['attributes']['artillery_target'] = ''
        self.assertEqual(0, assessment(view, choice)['finish_credit'])

    def test_private_state_invariance_and_small_budget(self):
        game = planning('Deimos')
        power_components.prepare(game, [dict(kind='fixture_marcher', player_id=1, lane='Castle',
            origin='gate', ordinal=i, attributes=dict(x_fp=100, y_fp=100+60*i)) for i in range(4)])
        for mode in ('new', 'none'):
            policy = CommonSmartCore(rout_mode=mode, limits=Limits(4, 2, 8, 2))
            before = game.snapshot(); view = observe(game, 0)
            original = policy.decide(view, Preview(game, 0))
            self.assertEqual(before, game.snapshot())
            view['board'].reverse(); view['hand'].reverse()
            self.assertEqual(original, policy.decide(view, Preview(game, 0)))
            altered = copy.deepcopy(game)
            altered._state['seed'] = 'unseen replacement seed'
            altered._state['world']['data']['card_zones']['deck'].reverse()
            altered._state['submissions'][1] = [dict(secret='sealed order')]
            self.assertEqual(original, policy.decide(observe(altered, 0), Preview(altered, 0)))
            for key, count in original['budget']['used'].items():
                limit = 4 if key.startswith('generated:') else 2 if key.startswith('retained:') else 8 if key == 'complete_plans' else 2
                self.assertLessEqual(count, limit)

    def test_cohort_matches_all_three_modes_without_prescribing_lord_loadouts(self):
        specs = list(cases()); self.assertEqual(162, len(specs))
        self.assertEqual(144, sum(not s['mirror'] for s in specs))
        for start in range(0, len(specs), 3):
            triple = specs[start:start+3]
            self.assertEqual(['old', 'new', 'none'], [s['mode'] for s in triple])
            self.assertEqual(triple[0]['setup'], triple[1]['setup'])
            self.assertEqual(triple[0]['setup'], triple[2]['setup'])
            self.assertEqual(triple[0]['setup']['castles'][0], triple[0]['setup']['castles'][1])
        for engines, castles in enumerate(LOADOUTS.values()):
            world = opening.world('legal loadout', ['Deimos', 'Gremory'], [castles, castles])
            self.assertEqual(engines, sum(r['owner'] == 0 and r['kind'] == 'castle'
                and r['attributes']['combat_profile'] == 'siege_engine'
                and r['attributes']['construction_state'] == 'active' for r in world['entities']['entities']))

    def test_paired_gain_loss_denominators_and_mirror_separation(self):
        records = []
        for spec in list(cases())[:3]:
            semantic = dict(outcome=dict(winner=0 if spec['mode'] == 'new' else 1),
                rounds=1, operations=1, final_state_sha256='x', decisions_sha256='y',
                diagnostics=dict(groups=[], maximum_work={}, rejected_previews=[]))
            records.append(dict(spec=spec, status='complete', error=None, semantic=semantic, trace=[]))
        summary = aggregate(records)
        comparison = summary['contrasts']['nonmirror_all']['new_vs_old']
        self.assertEqual((1, 1, 0), (comparison['pairs'], comparison['gains'], comparison['losses']))
        self.assertEqual(0, summary['groups']['mirror']['all']['new']['games'])
        self.assertFalse(summary['candidate_meets_preregistered_cohort_screen'])


if __name__ == '__main__': unittest.main()
