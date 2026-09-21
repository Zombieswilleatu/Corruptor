"""Directed decisions and independent authoritative Scorch packet checks."""
import unittest
from u13_pysim import power_components, powers
from u13_pysim.battle import Battle
from u13_pysim.copying import copy_data
from .facts import Facts
from .kalligan_tactics import forecast, inferno_value, pyro_value, packet
from .observation import observe, Preview
from .common import CommonSmartCore
from .test_common import planning
from .test_kalligan import view_with_scorch
from .test_lane_support import unit


class KalliganTacticsTests(unittest.TestCase):
    def test_equal_counts_distinguish_armor_hp_kills_and_friendly_losses(self):
        view=observe(planning('Kalligan'),0)
        victim=unit(view,'victim',1,'Lord',hp=1,armor=0,step_fp=0)
        target=dict(kind='lane',lane='Lord')
        lethal=forecast(Facts(view),target,[(0,1)])
        self.assertEqual((16,1),(lethal['score'],lethal['enemy_kills']))
        victim['attributes'].update(hp=10,armor=10)
        tank=forecast(Facts(view),target,[(0,1)])
        self.assertEqual((2,0),(tank['score'],tank['enemy_kills']))
        unit(view,'fragile_friend',0,'Lord',hp=1,armor=0)
        self.assertLess(forecast(Facts(view),target,[(0,1)])['score'],0)

    def test_pyro_does_not_buy_kills_automatic_pulse_already_gets(self):
        view=view_with_scorch(); victim=unit(view,'victim',1,hp=1,armor=0)
        self.assertEqual(0,pyro_value(Facts(view))['score'])
        victim['attributes']['hp']=2
        result=pyro_value(Facts(view))
        self.assertEqual(16,result['score'])
        self.assertEqual(4,result['automatic_score'])
        self.assertEqual(20,result['combined_score'])

    def test_castle_auto_already_fired_but_current_attack_can_remove_target(self):
        view=view_with_scorch('castle'); target=view['persistent'][0]['target']
        Facts(view).by_id[target['entity_id']]['attributes'].update(integrity=1,construction_state='active')
        self.assertEqual(26,pyro_value(Facts(view))['score'])
        self.assertEqual(0,pyro_value(Facts(view),dict(castle_hits={target['entity_id']:1}))['score'])

    def test_placement_values_all_three_stages_and_caps_total_castle_damage(self):
        view=observe(planning('Kalligan'),0); f=Facts(view); castle=f.castles(1)[0]
        castle['attributes'].update(integrity=20,construction_state='active')
        target=dict(kind='castle',entity_id=castle['id'])
        result=inferno_value(f,target)
        self.assertEqual([1,2,1],result['remaining_intensities'])
        self.assertEqual(18,result['score'])
        castle['attributes']['integrity']=1
        self.assertEqual(19,inferno_value(f,target)['score'])  # first hit destroys, no later damage credit
        castle['attributes']['integrity']=3
        unprotected=inferno_value(f,target)['score']
        f.lord[1]['attributes']['lord_id']='Kalligan'
        self.assertLess(inferno_value(f,target)['score'],unprotected)  # Forge repairs between future stages

    def test_relocation_preserves_lifetime_and_compares_leaving_fire(self):
        view=view_with_scorch(); active=view['persistent'][0]
        active['stages']=[dict(intensity=i) for i in (1,2,1)]
        f=Facts(view); castle=f.castles(1)[0]; castle['attributes'].update(integrity=20,construction_state='active')
        target=dict(kind='castle',entity_id=castle['id'])
        self.assertEqual([2,1],inferno_value(f,target)['remaining_intensities'])
        self.assertEqual(16,inferno_value(f,target)['score'])
        for i in range(5):unit(view,'foe:'+str(i),1,hp=20,armor=0,step_fp=0)
        self.assertLess(inferno_value(Facts(view),target)['score'],0)
        self.assertEqual(0,inferno_value(Facts(view),active['target'])['score'])
        active['stage_index']=2
        self.assertEqual([],inferno_value(Facts(view),target)['remaining_intensities'])
        self.assertEqual(0,inferno_value(Facts(view),target)['score'])

    def test_current_lane_fire_is_applied_before_future_relocation_value(self):
        view=view_with_scorch(); active=view['persistent'][0]; active['stages']=[dict(intensity=i) for i in (1,2,1)]
        unit(view,'already_doomed',1,hp=1,armor=0,step_fp=0)
        target=dict(kind='lane',lane='Lord')
        self.assertEqual(0,inferno_value(Facts(view),target)['keep_score'])

    def test_low_stage_can_hold_for_stronger_next_stage_and_current_kill_can_win(self):
        view=view_with_scorch(); active=view['persistent'][0]; active['stages']=[dict(intensity=i) for i in (1,2,1)]
        row=unit(view,'foe',1,hp=10,armor=0,step_fp=0)
        result=pyro_value(Facts(view))
        self.assertEqual((4,6,-2),(result['immediate_gain'],result['next_stage_gain'],result['score']))
        row['attributes']['hp']=2
        self.assertGreater(pyro_value(Facts(view))['score'],0)

    def test_future_mobile_occupancy_is_discounted_but_not_assumed_gone(self):
        view=observe(planning('Kalligan'),0); r=unit(view,'near_gate',1,'Lord',x_fp=10,hp=20,armor=0)
        target=dict(kind='lane',lane='Lord')
        moving=forecast(Facts(view),target,[(1,2)])['score']
        r['attributes']['step_fp']=0
        stationary=forecast(Facts(view),target,[(1,2)])['score']
        self.assertGreater(moving,0);self.assertLess(moving,stationary)

    def test_packet_matches_authority_for_armor_hp_flyers_and_exposure(self):
        game=planning('Kalligan')
        specs=[dict(hp=1,armor=0),dict(hp=5,armor=3),dict(hp=4,armor=1),dict(hp=3,armor=0,dotra_exposed_from_tick=200,dotra_exposed_until_tick=400),dict(hp=2,armor=0,flying=True)]
        power_components.prepare(game,[dict(kind='fixture_marcher',player_id=i%2,lane='Lord',origin='fire-packet',ordinal=i,attributes=a) for i,a in enumerate(specs)])
        world=copy_data(game._state['world'])
        before={r['id']:copy_data(r) for r in world['entities']['entities'] if r['kind']=='marcher'}
        active=dict(declaration=dict(player_id=0,power_id='Inferno'),target=dict(kind='lane',lane='Lord'),effect_id='packet-check',stages=[dict(intensity=2)],stage_index=0)
        events=powers.pulse(Battle(world,1,'packet-test',[0,1],'post_resolution_direct'),active,'packet-check')
        events=[e.get('event',e) for e in events]
        hits={e['data']['entity_id']:e['data'] for e in events if e['type']=='HAZARD_HIT'}
        for identity,row in before.items():
            if row['attributes'].get('flying'):
                self.assertNotIn(identity,hits);continue
            expected=packet(copy_data(row['attributes']),2,200)
            actual=next(e['data'] for e in events if e['type'] in ('MARCHER_DAMAGED','MARCHER_DEFEATED') and e['data']['victim']['id']==identity)
            self.assertEqual(expected['armor'],hits[identity]['armor_absorbed'])
            self.assertEqual(expected['hp'],actual['hp_before']-actual['hp_after'])

    def test_planner_does_not_mutate_observation_and_preserves_caps(self):
        game=planning('Kalligan'); before=game.snapshot();view=observe(game,0)
        one=CommonSmartCore().decide(view,Preview(game,0));view['board'].reverse()
        self.assertEqual(one,CommonSmartCore().decide(view,Preview(game,0)))
        self.assertEqual(before,game.snapshot());self.assertEqual([],one['rejected_previews'])
        self.assertLessEqual(one['budget']['used']['complete_plans'],32)
        self.assertLessEqual(one['budget']['used']['previews'],8)


if __name__=='__main__':unittest.main()
