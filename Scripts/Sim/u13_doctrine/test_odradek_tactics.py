"""Public target value, both-side relocation and actual allegiance hooks."""
import unittest
from u13_pysim import economy, monsters, power_components, full_match_inputs
from u13_pysim.copying import copy_data
from u13_pysim.power_rules import declaration
from .common import CommonSmartCore
from .coordination import context, evaluate
from .facts import Facts
from .lords.odradek import field_after_redirects
from .odradek_tactics import field, strength, targets, shift_value, redirect_value, capture
from .observation import observe, Preview
from .test_common import planning
from .test_lane_support import unit
from .test_recipes_veil import hand


def target(lane='Lord',x=900,y=300):return dict(lane=lane,field_position=dict(x_fp=x,y_fp=y))


class OdradekFieldTests(unittest.TestCase):
    def test_healthy_specialist_beats_larger_wounded_group(self):
        view=observe(planning('Odradek'),0)
        for i in range(2):unit(view,'weak:'+str(i),1,'Lord',x_fp=600+i*20,y_fp=300,hp=1,armor=0)
        specialist=unit(view,'specialist',1,'Lord')
        specialist['attributes'].update(monsters.profile('Sooge','Lord',1,0,1))
        specialist['attributes'].update(x_fp=1900,y_fp=300,sprite_form='turret')
        best=list(targets(Facts(view),'Lord','AllegianceShift'))[0]
        self.assertEqual(['specialist'],best[1]['eligible_after'])
        self.assertGreater(strength(specialist),strength(next(r for r in view['board'] if r['id']=='weak:0')))

    def test_limited_duplicate_and_charm_owner_block_capture(self):
        view=observe(planning('Odradek'),0)
        foe=unit(view,'foe',1,'Lord',monster_id='Sooge',x_fp=900,y_fp=300)
        own=unit(view,'own',0,'Castle',monster_id='Sooge',x_fp=900,y_fp=300)
        result=shift_value(Facts(view),target())
        self.assertEqual((0,[],['foe']),(result['score'],result['eligible_after'],result['blocked_limited']))
        own['owner']=1;own['attributes']['charm_owner']=0
        self.assertEqual(['foe'],shift_value(Facts(view),target())['blocked_limited'])
        own['attributes'].pop('charm_owner')
        self.assertEqual(['foe'],shift_value(Facts(view),target())['eligible_after'])

    def test_same_plan_limited_monster_also_blocks_capture(self):
        view=observe(planning('Odradek'),0);hand(view,[('Butcher',3)])
        unit(view,'enemy_sooge',1,'Lord',monster_id='Sooge',x_fp=900,y_fp=300)
        f=Facts(view);plan=dict(powers=[],order=dict(action='Ward',lane='Castle',card_ids=['ingredient:0'],monster_choice='Sooge'))
        result=shift_value(f,target(),field(f,context(f,plan)))
        self.assertEqual(['enemy_sooge'],result['blocked_limited'])

    def test_redirect_into_nearby_support_relieves_threat_but_distant_support_does_not(self):
        view=observe(planning('Odradek'),0)
        unit(view,'foe',1,'Lord',x_fp=100,y_fp=300)
        support=unit(view,'own',0,'Castle',x_fp=100,y_fp=300,hp=15,armor=6)
        useful=redirect_value(Facts(view),target(x=100))
        self.assertGreater(useful['score'],0)
        support['attributes']['x_fp']=2200
        self.assertEqual(0,redirect_value(Facts(view),target(x=100))['score'])

    def test_redirect_moving_friendly_defender_away_is_harmful(self):
        view=observe(planning('Odradek'),0)
        unit(view,'own',0,'Lord',x_fp=100,y_fp=10,hp=15,armor=6)
        unit(view,'foe',1,'Lord',x_fp=100,y_fp=600)
        result=redirect_value(Facts(view),target(x=100,y=10))
        self.assertLess(result['score'],0)
        self.assertEqual(['own'],result['eligible_after'])

    def test_recruits_can_make_redirect_useful_and_supplicants_are_excluded(self):
        view=observe(planning('Odradek'),0);hand(view,[('Butcher',6)])
        unit(view,'foe',1,'Lord',x_fp=100,y_fp=300)
        waiter=unit(view,'spent',0,'Castle',x_fp=100,y_fp=300,waiting=True)
        f=Facts(view);plan=dict(powers=[],order=dict(action='Ward',lane='Castle',card_ids=['ingredient:0'],rites=dict(waiter_spends=[dict(lane='Castle',marcher_ids=['spent'])])))
        rows=field(f,context(f,plan))
        self.assertNotIn('spent',[r['id'] for r in rows])
        self.assertEqual(3,sum(bool(r.get('planned')) for r in rows))
        self.assertGreater(redirect_value(f,target(x=100),rows)['score'],0)

    def test_actual_hook_order_matches_retargeted_shift_and_clears_waiting(self):
        game=planning('Odradek')
        power_components.prepare(game,[dict(kind='fixture_resources',player_id=0,resources=dict(reconfiguration=4))]+[
            dict(kind='fixture_marcher',player_id=pid,lane='Lord',origin='field-hooks',ordinal=pid,attributes=dict(x_fp=900,y_fp=300)) for pid in (0,1)])
        f=Facts(observe(game,0));plan=dict(powers=[declaration(0,1,'AllegianceShift',target('Castle')),declaration(0,1,'Redirect',target(),index=1)],order={})
        ctx=context(f,plan);rows=field_after_redirects(f,plan,ctx);expected=shift_value(f,target('Castle'),rows)['eligible_after']
        self.assertEqual(1,len(expected))
        self.assertEqual(expected,next(r['eligible_after'] for r in evaluate(f,plan)['powers'] if r['power']=='AllegianceShift'))
        self.assertNotEqual('invalid',game.apply(dict(kind='submit',plans=[plan,dict(powers=[],order={})]))['action'])
        while game.clock.hook!='post_resolution_movement_state':
            self.assertNotEqual('invalid',game.apply(full_match_inputs.next_operation(game))['action'])
        events=[r['event'] for r in game._state['events']['rows']]
        actual=next(e['data']['affected_ids'] for e in events if e['type']=='ALLEGIANCE_SHIFT_RESOLVED')
        self.assertEqual(expected,actual)
        for key in expected:
            r=economy.entity(game._state['world'],key)
            self.assertEqual((0,'Castle',False,1),(r['owner'],r['attributes']['lane'],r['attributes']['waiting'],r['attributes']['direction']))
        self.assertEqual(2,len(next(e['data']['changes'] for e in events if e['type']=='REDIRECT_RESOLVED')))

    def test_capture_cannot_credit_same_body_twice(self):
        view=observe(planning('Odradek'),0);unit(view,'foe',1,'Lord',x_fp=900,y_fp=300,waiting=True)
        f=Facts(view);rows=field(f);ids,_=capture(f,rows,target())
        self.assertEqual(['foe'],ids);self.assertEqual(0,shift_value(f,target(),rows)['score'])
        row=next(r for r in rows if r['id']=='foe');self.assertFalse(row['attributes']['waiting'])

    def test_both_seats_and_registry_order_produce_mirrored_values(self):
        view=observe(planning('Odradek'),0);unit(view,'foe',1,'Lord',x_fp=850,y_fp=300)
        unit(view,'support',0,'Castle',x_fp=850,y_fp=300)
        original=[fn(Facts(view),target(x=850))['score'] for fn in (shift_value,redirect_value)]
        mirror=copy_data(view);mirror['player_id']=1
        for r in mirror['board']:
            r['owner']=1-r['owner'] if r['owner'] in (0,1) else r['owner']
            if r['kind']=='marcher':r['attributes']['x_fp']=2400-r['attributes']['x_fp']
        mirror['board'].reverse()
        self.assertEqual(original,[fn(Facts(mirror),target(x=1550))['score'] for fn in (shift_value,redirect_value)])

    def test_target_samples_and_complete_plans_stay_bounded_on_large_board(self):
        game=planning('Odradek')
        power_components.prepare(game,[dict(kind='fixture_resources',player_id=0,resources=dict(reconfiguration=4))]+[
            dict(kind='fixture_marcher',player_id=i%2,lane='Lord' if i%3 else 'Castle',origin='bounded-field',ordinal=i,attributes=dict(x_fp=100+(i*131)%2200,y_fp=50+(i*37)%500)) for i in range(40)])
        before=game.snapshot();view=observe(game,0);f=Facts(view)
        for lane in ('Lord','Castle'):
            for name in ('Redirect','AllegianceShift'):self.assertLessEqual(len(list(targets(f,lane,name))),2)
        one=CommonSmartCore().decide(view,Preview(game,0));view['board'].reverse()
        self.assertEqual(one,CommonSmartCore().decide(view,Preview(game,0)))
        self.assertEqual([],one['rejected_previews']);self.assertEqual(before,game.snapshot())
        self.assertLessEqual(one['budget']['used']['complete_plans'],32);self.assertLessEqual(one['budget']['used']['previews'],8)
        self.assertLessEqual(one['budget']['used']['generated:powers'],16)


if __name__=='__main__':unittest.main()
