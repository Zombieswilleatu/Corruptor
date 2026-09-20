"""Gravity well boundaries, pulse timing, movement and friendly Projection."""
import unittest
from . import marching_fixtures as fixtures, powers, economy
from .marching_columns import Columns
from .marching_spatial import gravity, swept
from .primitives import Entities
from .recruitment import profile
from .copying import copy_data
from .power_rules import declaration
from . import test_powers


def scene(x=1265, armor=0, hp=5, owner=0, lane='Lord', ready=3):
    ids=Entities();a=profile('Butcher',lane,owner,0,ready);a.update(x_fp=x,y_fp=300,armor=armor,hp=hp)
    ids.create('marcher','well-test',0,owner,a)
    s=Columns(ids.snapshot())
    orb=dict(id='orb',owner=0,target=dict(lane='Lord',field_position=dict(x_fp=1200,y_fp=300)),round=1,consumed=0,rewarded=False)
    return s,[orb]


def step(s,orbs,tick,number=1,before=None):
    events=[]
    before=before or [(s.ids[i],s.x_fp[i],s.y_fp[i],s.lane[i],s.movement_ready_round[i]) for i in s.active()]
    tears=gravity(s,orbs,before,number,tick,False,lambda kind,data:events.append(dict(type=kind,data=copy_data(data))))
    return events,tears


class GravityWellTests(unittest.TestCase):
    def test_only_tiny_core_executes_both_sides_and_sweep_cannot_tunnel(self):
        for owner in (0,1):
            for x,alive in ((1220,False),(1221,True),(1265,True)):
                s,orbs=scene(x=x,owner=owner);step(s,orbs,0)
                self.assertEqual(alive,bool(s.active()))
        s,orbs=scene(x=1200,lane='Castle');step(s,orbs,66);self.assertTrue(s.active())
        self.assertTrue(swept(1000,300,1400,300,1200,300))
        self.assertFalse(swept(1000,321,1400,321,1200,300))

    def test_pull_adds_to_normal_movement_and_allows_escape(self):
        s,orbs=scene(x=1400,ready=1);i=0
        before=[(s.ids[i],1400,300,'Lord',1)]
        s.x_fp[i]=1404
        step(s,orbs,0,before=before)
        self.assertEqual(1402,s.x_fp[i]) # Outward movement still exceeds the weak pull.
        s,orbs=scene(x=1400,ready=1);step(s,orbs,0);self.assertEqual(1398,s.x_fp[0])

    def test_pulse_is_delayed_armor_first_and_continues_across_rounds(self):
        s,orbs=scene(armor=1)
        for tick in (0,65):self.assertEqual([],step(s,orbs,tick)[0])
        events,_=step(s,orbs,66);self.assertEqual((0,5),(s.armor[0],s.hp[0]))
        self.assertEqual(1,events[0]['data']['armor_absorbed'])
        step(s,orbs,133);self.assertEqual(4,s.hp[0])
        self.assertEqual([],step(s,orbs,199)[0])
        step(s,orbs,0,number=2);self.assertEqual(3,s.hp[0]) # 201st tick, third pulse.

    def test_outer_damage_is_lane_radius_limited_and_does_not_stack(self):
        for owner in (0,1):
            s,orbs=scene(x=1448,owner=owner);other=copy_data(orbs[0]);other.update(id='second',owner=1)
            events,_=step(s,orbs+[other],66);self.assertEqual(4,s.hp[0]);self.assertEqual(1,len(events))
            s,orbs=scene(x=1449,owner=owner);self.assertEqual([],step(s,orbs,66)[0])

    def test_pulse_kill_is_not_consumption_or_a_neutral_tear(self):
        s,orbs=scene(hp=1);events,tears=step(s,orbs,66)
        self.assertEqual(['GRAVITY_ORB_DAMAGED','MARCHER_DEFEATED'],[e['type'] for e in events])
        self.assertFalse(s.active());self.assertEqual(0,tears);self.assertEqual(0,orbs[0]['consumed'])
        self.assertEqual('gravity',events[1]['data']['cause'])
        from .wishmaster import record_losses
        w=dict(data=dict(kanifous_losses=[]));record_losses(w,events)
        self.assertEqual(1,len(w['data']['kanifous_losses']))

    def test_projection_only_friendly_kills_generate_essence(self):
        helpers=test_powers.PowerTests()
        for owner in (0,1):
            g=helpers.before_lock('Valak');w=g._state['world'];w['players'][0]['resources']['life_essence']=3
            ids=Entities();ids.restore(w['entities']);card_id=economy.zones(w)['hands'][owner].pop(0)
            row=ids.rows[card_id];row['attributes'].update(role='guard',lane='Lord',slot=0,value=2)
            w['entities']=ids.snapshot();g._state['presentation_world']=copy_data(w)
            source=declaration(0,1,'Projection',dict(kind='guard_zone',zone='Lord',player_id=owner),parameters=dict(spend=2))
            self.assertEqual('',powers.validate(source,w,'declaration',[]))
            self.assertNotEqual('invalid',helpers.submit(g,[source])['action'])
            helpers.drive(g,'post_resolution_direct',1)
            self.assertNotEqual('invalid',g.apply(dict(kind='step',hook='post_resolution_direct'))['action'])
            rows=[e['event'] for e in g._state['events']['rows']]
            shot=next(e['data'] for e in rows if e['type']=='VALAK_PROJECTION_RESOLVED')
            self.assertEqual(card_id,shot['victim']['id']);self.assertFalse(shot['whiff'])
            self.assertEqual(3 if owner==0 else 1,g._state['world']['players'][0]['resources']['life_essence'])
            self.assertEqual(owner==0,any(e['type']=='VALAK_ESSENCE_GAINED' for e in rows))


    def test_sacrifice_gain_cap_whiff_banishment_and_replay(self):
        helpers=test_powers.PowerTests()
        from copy import deepcopy
        for pool, value, spend, alive, expected in ((1,1,1,True,2),(5,1,1,True,5),(3,2,2,True,3),(3,3,1,True,2),(3,1,1,False,2)):
            with self.subTest(pool=pool,value=value,spend=spend,alive=alive):
                g=helpers.before_lock('Valak');w=g._state['world'];w['players'][0]['resources']['life_essence']=pool
                ids=Entities();ids.restore(w['entities']);card_id=economy.zones(w)['hands'][0].pop(0)
                ids.rows[card_id]['attributes'].update(role='guard',lane='Lord',slot=0,value=value)
                w['entities']=ids.snapshot();g._state['presentation_world']=copy_data(w)
                source=declaration(0,1,'Projection',dict(kind='guard_zone',zone='Lord',player_id=0),parameters=dict(spend=spend))
                self.assertNotEqual('invalid',helpers.submit(g,[source])['action'])
                helpers.drive(g,'post_resolution_direct',1)
                if not alive:
                    lord=economy.entity(g._state['world'],g._state['world']['players'][0]['lord_entity_id'])
                    lord['attributes']['alive']=False
                restored=deepcopy(g)
                op=dict(kind='step',hook='post_resolution_direct')
                self.assertNotEqual('invalid',g.apply(op)['action'])
                self.assertNotEqual('invalid',restored.apply(op)['action'])
                self.assertEqual(g.snapshot(),restored.snapshot())
                self.assertEqual(expected,g._state['world']['players'][0]['resources']['life_essence'])
                gains=[r['event']['data'] for r in g._state['events']['rows'] if r['event']['type']=='VALAK_ESSENCE_GAINED']
                self.assertEqual(int(alive and value<=spend),len(gains))
                after=g.snapshot();self.assertEqual('invalid',g.apply(op)['action']);self.assertEqual(after,g.snapshot())


if __name__=='__main__':unittest.main()
