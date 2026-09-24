"""Embolden contracts: percentages, lifecycle, precision and real combat."""
import copy
import unittest
from . import embolden, recruitment, marching, field_fortifications
from .marching_spatial import speed
from .primitives import Entities
from u13_doctrine.test_common import planning


def world(percent=5):
    game=planning();w=copy.deepcopy(game._state['world'])
    w['data']['embolden_experiment']=percent
    w['entities']['entities']=[r for r in w['entities']['entities'] if r['kind']!='card']
    for pid in (0,1):
        for lane in ('Lord','Castle'):
            recruitment.create(w,f'embolden-test-{pid}-{lane}',0,pid,recruitment.profile('Penitent',lane,pid,1,1))
    return w


class EmboldenTests(unittest.TestCase):
    def test_zero_bonus_still_enables_fractional_damage_precision(self):
        a=recruitment.profile('Wright','Lord',0,1,1)
        before=copy.deepcopy(a)
        embolden.apply(a,0)
        self.assertEqual(dict(before,_embolden_percent=0),a)
        # Mathematically lethal packets previously left a positive float crumb.
        hp=2.1
        for damage in (1.2,0.9):hp=max(0,embolden.clean_damage(hp-damage,a))
        self.assertEqual(0,hp)
        self.assertGreater(embolden.clean_damage(0.00000001,a),0)

    def test_column_damage_retires_fractional_remainder_at_hit_time(self):
        from .marching_columns import Columns
        w=world(20);embolden.refresh(w)
        s=Columns(w['entities'],keep_background=True);i=s.active()[0]
        s.hp[i]=2.1;s.armor[i]=0
        marching.attack(s,i,1.2,True)
        marching.attack(s,i,0.9,True)
        self.assertEqual(0,s.hp[i])

    def test_bonus_is_opposing_lane_slots_and_never_guard_value(self):
        w=world(10)
        for i in range(2):
            w['entities']['entities'].append(dict(id=f'guard{i}',kind='card',owner=1,
                attributes=dict(role='guard',lane='Lord',slot=i,value=1)))
        p=embolden.pressures(w)
        self.assertEqual(10,p[0,'Lord']);self.assertEqual(30,p[0,'Castle'])
        self.assertEqual(30,p[1,'Lord']);self.assertEqual(30,p[1,'Castle'])
        for r in w['entities']['entities']:
            if r['kind']=='card':r['attributes']['value']=5
        self.assertEqual(p,embolden.pressures(w))
        w['entities']['entities'][-1]['attributes']['role']='card'
        self.assertEqual(20,embolden.pressures(w)[0,'Lord'])

    def test_all_percentages_keep_fractional_attack_and_exact_average_speed(self):
        for per_slot in (5,10,15,20):
            w=world(per_slot);embolden.refresh(w)
            row=next(r for r in w['entities']['entities'] if r['kind']=='marcher');a=row['attributes']
            factor=1+3*per_slot/100
            self.assertAlmostEqual(factor,a['attack'])
            self.assertAlmostEqual(5*factor,a['hp']);self.assertAlmostEqual(3*factor,a['armor'])
            self.assertEqual(round(300*factor),sum(speed(3,0,False,t,boost=3*per_slot) for t in range(100)))
            self.assertTrue(marching.valid(w))

    def test_repeated_refresh_does_not_heal_or_compound_and_removal_preserves_wounds(self):
        a=recruitment.profile('Penitent','Lord',0,1,1)
        embolden.apply(a,60);a['hp']=4;a['armor']=0
        before=copy.deepcopy(a)
        for _ in range(100):embolden.apply(a,60)
        self.assertEqual(before,a)
        embolden.apply(a,0)
        self.assertEqual(2.5,a['hp']);self.assertEqual(5,a['max_hp']);self.assertEqual(0,a['armor'])
        embolden.apply(a,60)
        self.assertEqual(4,a['hp']);self.assertEqual(0,a['armor'])

    def test_zero_armor_does_not_gain_armor_and_zero_speed_stays_stationary(self):
        a=recruitment.profile('Vulture','Lord',0,1,1);a.update(armor=0,step_fp=0)
        embolden.apply(a,60)
        self.assertEqual(0,a['armor']);self.assertEqual(0,speed(a['step_fp'],0,False,30,boost=60))
        self.assertEqual(0,a['step_fp'])

    def test_zero_control_is_exact_noop_and_fractional_survivors_are_valid_only_in_experiment(self):
        w=world(0);before=copy.deepcopy(w);embolden.refresh(w);self.assertEqual(before,w)
        row=next(r for r in w['entities']['entities'] if r['kind']=='marcher');row['attributes']['hp']=0.25
        self.assertFalse(marching.valid(w))
        w['data']['embolden_experiment']=5
        self.assertTrue(marching.valid(w))
        row['attributes']['hp']=float('nan');self.assertFalse(marching.valid(w))

    def test_sooge_transform_gets_one_bonus_and_owner_change_recomputes_lane(self):
        a=dict(attack=3,armor=6,max_armor=6,_embolden_percent=60)
        embolden.transform(a,('attack','armor','max_armor'))
        self.assertEqual(4.8,a['attack']);self.assertEqual(9.6,a['armor'])
        w=world(20)
        for i in range(3):w['entities']['entities'].append(dict(kind='card',id=f'g{i}',owner=1,
            attributes=dict(role='guard',lane='Lord',slot=i)))
        embolden.refresh(w)
        row=next(r for r in w['entities']['entities'] if r['kind']=='marcher' and r['owner']==0 and r['attributes']['lane']=='Lord')
        self.assertEqual(1,row['attributes']['attack'])
        row['owner']=1;embolden.refresh(w);self.assertEqual(1.6,row['attributes']['attack'])

    def test_fractional_structure_wounds_cannot_overrepair(self):
        from types import SimpleNamespace
        a=recruitment.profile('Wright','Lord',0,1,1)
        unit=dict(id='repairer',owner=0,attributes=a)
        wall=dict(id='wall',owner=0,kind='fortification',attributes=dict(
            structure='Wall',lane='Lord',x_fp=0,y_fp=300,hp=15.4,max_hp=16))
        w=dict(data=dict(field_structures=[wall],embolden_experiment=20))
        entities=SimpleNamespace(rows=lambda:[unit],update=lambda *args:None)
        events=field_fortifications.repair_nearby(w,entities,1,0)
        self.assertEqual(16,wall['attributes']['hp'])
        self.assertEqual(16,events[0]['event']['data']['hp_after'])



if __name__=='__main__':unittest.main()
