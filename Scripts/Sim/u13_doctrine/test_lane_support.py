"""Directed authority checks for public Rout pressure and Humbaba support."""
import copy
import json
from pathlib import Path
import unittest

from u13_pysim import economy, full_match_inputs, power_components, recruitment, monsters
from u13_pysim.copying import copy_data
from u13_pysim.power_rules import declaration
from u13_pysim.power_match import PowerMatch
from .common import CommonSmartCore
from .coordination import evaluate
from .facts import Facts
from .diagnostics import fingerprint
from .lords.deimos import rout_value
from .lords.humbaba import BREATH, MUSTER, breath_value, muster_value
from .observation import observe, Preview
from .planner_probe import PlannerObserver
from .budget import Limits
from .test_common import planning
from .test_recipes_veil import hand


def unit(view, identity, seat=0, lane='Castle', **attributes):
    a = recruitment.profile('Butcher', lane, seat, 0, 1); a.update(attributes)
    row = dict(id=identity, kind='marcher', owner=seat, attributes=a)
    view['board'].append(row)
    return row


def through_pulse(game, plans):
    result = game.apply(dict(kind='submit', plans=plans))
    if result['action'] == 'invalid': raise AssertionError(result)
    while game.clock.hook != 'post_resolution_hazards':
        result = game.apply(full_match_inputs.next_operation(game))
        if result['action'] == 'invalid': raise AssertionError(result)


class LaneSupportTests(unittest.TestCase):
    def test_rout_prefers_near_gate_to_larger_distant_column_and_holds_empty_pressure(self):
        game = planning('Deimos')
        changes = [dict(kind='fixture_marcher', player_id=1, lane='Castle', origin='distant', ordinal=i,
                        attributes=dict(x_fp=2300, y_fp=100+60*i)) for i in range(6)]
        changes.append(dict(kind='fixture_marcher', player_id=1, lane='Lord', origin='near', ordinal=0,
                            attributes=dict(x_fp=100, y_fp=300)))
        power_components.prepare(game, changes)
        before = game.snapshot(); view = observe(game, 0); f = Facts(view)
        self.assertEqual(0, rout_value(f,'Castle')['score'])
        self.assertEqual(14, rout_value(f,'Lord')['score'])
        decision = CommonSmartCore().decide(view,Preview(game,0))
        self.assertEqual(before,game.snapshot())
        rout = next(s for s in decision['plan']['powers'] if s['power_id']=='Rout')
        self.assertEqual('Lord',rout['target']['lane'])
        through_pulse(game,[decision['plan'],dict(powers=[],order={})])
        routed = next(r['event']['data'] for r in game._state['events']['rows'] if r['event']['type']=='ROUT_APPLIED')
        self.assertEqual(1,len(routed['affected_ids']))
        self.assertEqual('Lord',routed['lane'])
        view['board'] = [r for r in view['board'] if r['kind']!='marcher' or r['attributes']['lane']!='Lord']
        held = CommonSmartCore().decide(view,lambda p:dict(action='legal'))
        self.assertNotIn('Rout',[s['power_id'] for s in held['plan']['powers']])

    def test_rout_pressure_mirrors_seats_and_does_not_claim_to_silence_turrets(self):
        view=observe(planning('Deimos'),0)
        unit(view,'own',0,x_fp=900)
        unit(view,'closing',1,x_fp=1800)
        f=Facts(view);self.assertEqual(8,rout_value(f,'Castle')['score'])
        view['board'].reverse();self.assertEqual(rout_value(f,'Castle'),rout_value(Facts(view),'Castle'))
        other=copy_data(view);other['player_id']=1
        for row in other['board']:
            row['owner']=1-row['owner'] if row['owner'] in (0,1) else row['owner']
            if row['kind']=='marcher':row['attributes']['x_fp']=2400-row['attributes']['x_fp']
        self.assertEqual(rout_value(f,'Castle'),rout_value(Facts(other),'Castle'))
        turret=next(r for r in view['board'] if r['id']=='closing')
        turret['attributes']=monsters.profile('Sooge','Castle',1,0,1,True)
        turret['attributes']['x_fp']=920
        self.assertEqual(0,rout_value(Facts(view),'Castle')['score'])

    def test_breath_caps_both_heals_and_excludes_waiting_from_all_benefits(self):
        view=observe(planning('Humbaba'),0)
        unit(view,'deep',hp=1,step_fp=0)
        unit(view,'scratch',hp=4,step_fp=0)
        unit(view,'waiting',hp=1,waiting=True)
        unit(view,'rooted',hp=4,step_fp=0,sprite_form='turret')
        row=breath_value(Facts(view),'Castle')
        self.assertEqual((3,1,0,1),(row['immediate_healing'],row['next_regen_bonus'],row['movement_windows'],row['waiting_excluded']))
        self.assertEqual(16,row['score'])

    def test_breath_movement_respects_readiness_contact_and_ranged_stopping(self):
        view=observe(planning('Humbaba'),0)
        unit(view,'next',movement_ready_round=2,x_fp=0,y_fp=0)
        unit(view,'too_late',movement_ready_round=3,x_fp=0,y_fp=0)
        unit(view,'contact',x_fp=1000)
        unit(view,'ranged',suit='Vulture',x_fp=800)
        unit(view,'enemy',1,x_fp=1030)
        self.assertEqual(1,breath_value(Facts(view),'Castle')['movement_windows'])

    def test_breath_counts_same_plan_recruits_at_their_actual_readiness(self):
        view=observe(planning('Humbaba'),0);hand(view,[('Butcher',4)])
        f=Facts(view)
        plan=dict(powers=[declaration(0,1,MUSTER,dict(lane='Castle')),
            declaration(0,1,BREATH,dict(lane='Castle'),index=1)],
            order=dict(action='Ward',lane='Castle',card_ids=['ingredient:0']))
        row=evaluate(f,plan)['powers'][0]
        self.assertEqual((0,8,2,3),(row['immediate_healing'],row['movement_windows'],row['ordinary_recruits'],row['muster_recruits']))
        self.assertEqual((0,0,8),(row['score'],row['pressure_movement_windows'],row['unpressured_movement_windows']))
        plan['powers'][1]['target']['lane']='Lord'
        self.assertEqual(0,evaluate(f,plan)['powers'][0]['score'])

    def test_healthy_distant_column_holds_breath_but_gate_approach_has_value(self):
        view=observe(planning('Humbaba'),0)
        row=unit(view,'column',x_fp=0)
        value=breath_value(Facts(view),'Castle')
        self.assertEqual((2,0,0),(value['movement_windows'],value['pressure_movement_windows'],value['score']))
        row['attributes']['x_fp']=800
        value=breath_value(Facts(view),'Castle')
        self.assertEqual((0,2,6),(value['immediate_healing'],value['pressure_movement_windows'],value['score']))
        # Public geometry and the opposing gate must mirror both seats.
        other=copy_data(view);other['player_id']=1
        for r in other['board']:
            if r['owner'] in (0,1):r['owner']=1-r['owner']
            if r['kind']=='marcher':r['attributes']['x_fp']=2400-r['attributes']['x_fp']
        self.assertEqual(value,breath_value(Facts(other),'Castle'))

    def test_breath_movement_needs_reachable_visible_pressure(self):
        view=observe(planning('Humbaba'),0)
        unit(view,'ally',x_fp=0,movement_ready_round=2)
        enemy=unit(view,'enemy',1,x_fp=1200,step_fp=0)
        self.assertEqual(0,breath_value(Facts(view),'Castle')['pressure_movement_windows'])
        enemy['attributes']['x_fp']=1000
        self.assertEqual(1,breath_value(Facts(view),'Castle')['pressure_movement_windows'])
        enemy['attributes']['hidden']=True
        self.assertEqual(0,breath_value(Facts(view),'Castle')['pressure_movement_windows'])
        enemy['attributes']['hidden']=False;enemy['attributes']['x_fp']=1800;enemy['attributes']['step_fp']=4
        self.assertEqual(1,breath_value(Facts(view),'Castle')['pressure_movement_windows'])

    def test_planned_recruit_pressure_uses_public_suit_speed_and_readiness(self):
        view=observe(planning('Humbaba'),0);hand(view,[('Penitent',4),('Butcher',4)])
        unit(view,'rooted_enemy',1,x_fp=950,step_fp=0)
        f=Facts(view)
        plan=dict(powers=[declaration(0,1,BREATH,dict(lane='Castle'))],
                  order=dict(action='Ward',lane='Castle',card_ids=['ingredient:0']))
        slow=evaluate(f,plan)['powers'][0]
        self.assertEqual((2,0),(slow['movement_windows'],slow['pressure_movement_windows']))
        plan['order']['card_ids']=['ingredient:1']
        fast=evaluate(f,plan)['powers'][0]
        self.assertEqual((2,2),(fast['movement_windows'],fast['pressure_movement_windows']))

    def test_empty_opening_holds_breath_without_blocking_muster(self):
        game=planning('Humbaba');before=game.snapshot()
        decision=CommonSmartCore().decide(observe(game,0),Preview(game,0))
        self.assertEqual([MUSTER],[p['power_id'] for p in decision['plan']['powers']])
        self.assertEqual([],decision['rejected_previews']);self.assertEqual(before,game.snapshot())

    def test_supplicant_spends_do_not_leave_phantom_breath_recipients(self):
        view=observe(planning('Humbaba'),0);hand(view,[('Butcher',4)])
        unit(view,'spent',waiting=True,hp=1)
        f=Facts(view)
        plan=dict(powers=[declaration(0,1,BREATH,dict(lane='Castle'))],order=dict(action='Siege',lane='Castle',
            target_id=f.castles(1)[0]['id'],card_ids=['ingredient:0']))
        row=evaluate(f,plan)['powers'][0]
        self.assertEqual(1,row['consumed_excluded']);self.assertEqual(0,row['immediate_healing'])
        self.assertEqual(1,row['movement_windows']) # One full-health recruit, next round only.

    def test_visible_pressure_can_pair_muster_breath_and_recruits_within_budget(self):
        game=planning('Humbaba')
        power_components.prepare(game,[dict(kind='fixture_marcher',player_id=1,lane='Castle',origin='pressure',ordinal=0,
                                           attributes=dict(x_fp=950,step_fp=0))])
        before=game.snapshot();view=observe(game,0)
        decision=CommonSmartCore().decide(view,Preview(game,0))
        powers={s['power_id']:s for s in decision['plan']['powers']}
        self.assertEqual({MUSTER,BREATH},set(powers))
        self.assertEqual(powers[MUSTER]['target'],powers[BREATH]['target'])
        self.assertEqual(decision['plan']['order']['lane'],powers[BREATH]['target']['lane'])
        self.assertTrue(decision['support']['selected']);self.assertEqual(before,game.snapshot())
        for name,count in decision['budget']['used'].items():
            limit=16 if name.startswith('generated:') else 4 if name.startswith('retained:') else 32 if name=='complete_plans' else 8
            self.assertLessEqual(count,limit)
        through_pulse(game,[decision['plan'],dict(powers=[],order={})])
        events=[r['event'] for r in game._state['events']['rows']]
        pulse=next(e['data'] for e in events if e['type']=='BREATH_PULSED')
        self.assertEqual(0,pulse['healing'])
        spawned=[r for r in game._state['world']['entities']['entities'] if r['kind']=='marcher' and r['attributes'].get('source_effect_id')]
        self.assertEqual(3,len(spawned));self.assertTrue(all(r['attributes']['movement_ready_round']==1 for r in spawned))

    def test_muster_prefers_lane_with_remaining_active_breath_when_pressure_ties(self):
        view=observe(planning('Humbaba'),0);view['round']=2
        view['persistent']=[dict(declaration=dict(player_id=0,power_id=BREATH),target=dict(lane='Lord'),activated_round=1)]
        f=Facts(view);self.assertEqual(9,muster_value(f,'Lord')-muster_value(f,'Castle'))

    def test_support_reads_no_sealed_orders_seed_or_opponent_hand(self):
        game=planning('Humbaba');view=observe(game,0)
        first=CommonSmartCore().decide(view,Preview(game,0))
        game._state['seed']='private unrelated seed';game._state['submissions'][1]=[dict(secret='orders')]
        game._state['world']['data']['card_zones']['deck'].reverse()
        for key in economy.zones(game._state['world'])['hands'][1]:
            economy.entity(game._state['world'],key)['attributes']['value']=1
        self.assertEqual(view,observe(game,0))
        view['board'].reverse();view['hand'].reverse()
        self.assertEqual(first,CommonSmartCore().decide(view,Preview(game,0)))

    def test_actual_pulse_healing_is_measured_separately_from_predicted_movement(self):
        game=planning('Humbaba')
        power_components.prepare(game,[dict(kind='fixture_marcher',player_id=0,lane='Castle',origin='heal',ordinal=0,
            attributes=dict(hp=3,step_fp=0))])
        decision=CommonSmartCore().decide(observe(game,0),Preview(game,0))
        observer=PlannerObserver(dict(name='pulse',setup=dict(lords=['Humbaba','Gremory'])))
        observer.accepted(1,0,decision)
        start=len(game._state['events']['rows'])
        through_pulse(game,[decision['plan'],dict(powers=[],order={})])
        for i,row in enumerate(game._state['events']['rows'][start:],start):observer.event(i,row['event'],1)
        records=observer.recorder.report()['groups']
        row=next(r for r in records if r['term']==BREATH and r['category']=='powers' and r['lord']=='Humbaba')
        self.assertEqual(1,row['metrics']['immediate_hp_restored'])
        self.assertEqual(1,row['metrics']['activation_pulses'])
        self.assertNotIn('movement_windows',row['metrics'])

    def test_small_support_budgets_remain_legal_and_deterministic(self):
        game=planning('Humbaba');limits=Limits(4,2,8,2)
        first=CommonSmartCore(limits=limits).decide(observe(game,0),Preview(game,0))
        self.assertEqual(first,CommonSmartCore(limits=limits).decide(observe(game,0),Preview(game,0)))
        self.assertEqual([],first['rejected_previews'])
        for name,count in first['budget']['used'].items():
            limit=4 if name.startswith('generated:') else 2 if name.startswith('retained:') else 8 if name=='complete_plans' else 2
            self.assertLessEqual(count,limit)

    def test_natural_holds_retargets_pairings_and_heal_against_recorded_opponents(self):
        data=json.loads(Path(__file__).with_name('lane_support_cases.json').read_text())
        for case in data['cases']:
            with self.subTest(case=case['name']):
                game=PowerMatch(case['setup'])
                for op in case['prior_operations']:
                    self.assertNotEqual('invalid',game.apply(op)['action'])
                seat=case['seat'];view=observe(game,seat);before=game.snapshot()
                self.assertEqual(case['view_sha256'],fingerprint(view))
                choice=CommonSmartCore().decide(view,Preview(game,seat))
                # Keep historical policy fingerprints while separately pinning
                # reviewed plans under the current marcher rules.
                expected=case.get('current_replay_plan_sha256',case.get('v12_plan_sha256',case['revised_plan_sha256']))
                self.assertEqual(expected,fingerprint(choice['plan']))
                self.assertEqual(before,game.snapshot());self.assertEqual([],choice['rejected_previews'])
                powers={s['power_id']:s for s in choice['plan']['powers']}
                if case['kind']=='hold':self.assertNotIn('Rout',powers)
                elif case['kind']=='retarget':self.assertEqual(case.get('expected_rout_lane','Castle'),powers['Rout']['target']['lane'])
                elif case['kind']=='pair':
                    self.assertIn(MUSTER,powers);self.assertNotIn(BREATH,powers)
                elif case['kind'] in ('recruit_support','existing_support'):
                    self.assertEqual(case.get('expected_breath_lane','Lord'),powers[BREATH]['target']['lane'])
                    support=choice['coordination']['selected']['powers'][0]
                    self.assertGreater(support['pressure_movement_windows'],0)
                    if case['kind']=='recruit_support':
                        self.assertGreater(support['ordinary_recruits'],0)
                    else:
                        self.assertEqual(0,support['ordinary_recruits'])
                # Only after deciding do we supply the recorded opposing order.
                for revised in (False,True):
                    replay=copy.deepcopy(game);plans=copy_data(case['original_plans'])
                    if revised:plans[seat]=choice['plan']
                    start=len(replay._state['events']['rows']);through_pulse(replay,plans)
                    if revised:
                        events=[r['event'] for r in replay._state['events']['rows'][start:]]
                        if case['kind']=='pair':
                            self.assertFalse(any(e['type']=='BREATH_PULSED' and e['data']['player_id']==seat for e in events))
                        elif case['kind'] in ('heal','recruit_support','existing_support'):
                            pulses=[e['data'] for e in events if e['type']=='BREATH_PULSED' and e['data']['player_id']==seat]
                            self.assertEqual(1,len(pulses))
                            self.assertEqual(case.get('expected_healing',2) if case['kind']=='heal' else 0,pulses[0]['healing'])
                        elif case['kind']=='retarget':
                            rout=next(e['data'] for e in events if e['type']=='ROUT_APPLIED' and e['data']['player_id']==seat)
                            self.assertEqual(case.get('expected_rout_lane','Castle'),rout['lane']);self.assertGreater(len(rout['affected_ids']),0)
