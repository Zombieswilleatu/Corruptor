"""Focused contracts for conversion and delayed public Guard vacancy history."""
import copy
import unittest
from . import embolden, ward_conversion, recruitment, monsters, split_ward, game_staging
from .test_embolden import world
from u13_doctrine import test_split_ward as fixtures
from u13_doctrine import test_ward_recipes as recipe_fixtures


def guard(w,pid=1,lane='Lord',slot=0):
    r=dict(id=f'guard-{pid}-{lane}-{slot}',kind='card',owner=pid,
           attributes=dict(role='guard',lane=lane,slot=slot))
    w['entities']['entities'].append(r)
    return r


class DelayedTests(unittest.TestCase):
    def setup_world(self):
        w=world(20);w['data']['embolden_ramp_experiment']=True
        return w

    def test_initial_empty_round_then_10_15_20_and_cap(self):
        w=self.setup_world()
        for n,expected in enumerate((0,30,45,60,60),1):
            embolden.observe_guards(w,n)
            self.assertEqual(expected,embolden.pressures(w)[0,'Lord'])
            before=copy.deepcopy(w)
            for _ in range(5):embolden.observe_guards(w,n)
            self.assertEqual(before,w)

    def test_death_in_round_four_has_whole_round_five_grace(self):
        w=self.setup_world();r=guard(w)
        for n in range(1,5):embolden.observe_guards(w,n)
        w['entities']['entities'].remove(r);embolden.observe_guards(w,4)
        self.assertEqual(0,w['data']['embolden_guard_history']['slots'][1]['Lord'][0]['age'])
        embolden.observe_guards(w,5)
        self.assertEqual(0,w['data']['embolden_guard_history']['slots'][1]['Lord'][0]['age'])
        embolden.observe_guards(w,6)
        self.assertEqual(1,w['data']['embolden_guard_history']['slots'][1]['Lord'][0]['age'])

    def test_refilling_resets_only_that_slot_and_no_full_heal(self):
        w=self.setup_world()
        for n in range(1,5):embolden.observe_guards(w,n)
        embolden.refresh(w)
        unit=next(r for r in w['entities']['entities'] if r['kind']=='marcher' and r['owner']==0 and r['attributes']['lane']=='Lord')
        unit['attributes'].update(hp=4,armor=0)
        guard(w);embolden.observe_guards(w,4);embolden.refresh(w)
        p=embolden.pressures(w)
        self.assertEqual(40,p[0,'Lord']);self.assertEqual(60,p[0,'Castle']);self.assertEqual(60,p[1,'Lord'])
        self.assertEqual(3.5,unit['attributes']['hp']);self.assertEqual(0,unit['attributes']['armor'])

    def test_brief_occupation_and_snapshot_restore(self):
        w=self.setup_world();embolden.observe_guards(w,1)
        r=guard(w);embolden.observe_guards(w,1);w['entities']['entities'].remove(r)
        embolden.observe_guards(w,1)
        resumed=copy.deepcopy(w)
        for state in (w,resumed):embolden.observe_guards(state,2);embolden.refresh(state)
        self.assertEqual(w,resumed)
        self.assertEqual(20,embolden.pressures(w)[0,'Lord'])

    def test_off_is_noop(self):
        w=world(0);before=copy.deepcopy(w);embolden.observe_guards(w,1)
        self.assertEqual(before,w)


class ConversionTests(unittest.TestCase):
    def cohort(self,w,mode='all'):
        w['data']['ward_conversion_experiment']=mode
        game_staging.configure(w)
        ids=[]
        for i,name in enumerate(('Butcher','Lemek')):
            a=monsters.profile(name,'Lord',0,1,2) if name=='Lemek' else recruitment.profile(name,'Lord',0,1,2)
            r=recruitment.create(w,'conversion-test',i,0,a)
            r['attributes']['staged_round']=1;ids.append(r['id'])
            w['entities']['entities'].remove(r)
            w['data']['game_staging']['lanes']['Lord']['units'].append(r)
        w['data']['ward_conversion_cohorts']=[dict(round=1,lane='Lord',unit_ids=ids),{}]
        return ids

    def test_real_ward_save_converts_and_launches_only_current_attack(self):
        rules,attack=fixtures.SplitWardTests().battle()
        ids=self.cohort(rules.w)
        old=recruitment.create(rules.w,'old-unit',0,0,recruitment.profile('Butcher','Lord',0,0,1))
        events=split_ward.resolve_attack(rules,0,attack)
        converted=next(r['event']['data'] for r in events if r['event']['type']=='WARD_RECRUITS_CONVERTED')
        self.assertEqual((1,1),(converted['regular_count'],converted['monster_count']))
        self.assertEqual(set(ids),{u['id'] for u in converted['units']})
        self.assertFalse(game_staging.rows(rules.w))
        for u in converted['units']:
            self.assertEqual(1,u['owner']);self.assertEqual(-1,u['attributes']['direction'])
            self.assertGreaterEqual(u['attributes']['x_fp'],2279)
            self.assertEqual(1,u['attributes']['movement_ready_round'])
        self.assertEqual(0,old['owner'])
        self.assertEqual([],ward_conversion.convert(rules.w,0,attack,1,'again'))

    def test_regular_only_leaves_monster_with_attacker(self):
        rules,attack=fixtures.SplitWardTests().battle();ids=self.cohort(rules.w,'regular')
        events=split_ward.resolve_attack(rules,0,attack)
        c=next(r['event']['data'] for r in events if r['event']['type']=='WARD_RECRUITS_CONVERTED')
        self.assertEqual(1,c['regular_count']);self.assertEqual(0,c['monster_count'])
        remaining=game_staging.rows(rules.w);self.assertEqual(1,len(remaining))
        self.assertEqual('Lemek',remaining[0]['attributes']['monster_id']);self.assertEqual(0,remaining[0]['owner'])

    def test_wrong_lane_overpowered_ward_and_guard_only_stop_never_convert(self):
        for strength,lane,g in ((6,'Castle',False),(12,'Lord',False),(3,'Lord',False),(6,'Lord',True)):
            rules,attack=fixtures.SplitWardTests().battle(strength,lane,g);ids=self.cohort(rules.w)
            events=split_ward.resolve_attack(rules,0,attack)
            self.assertFalse(any(r['event']['type']=='WARD_RECRUITS_CONVERTED' for r in events))
            self.assertEqual(set(ids),{r['id'] for r in game_staging.rows(rules.w)})

    def test_dead_recruit_not_restored_and_stale_cohort_not_converted(self):
        rules,attack=fixtures.SplitWardTests().battle();ids=self.cohort(rules.w)
        tray=rules.w['data']['game_staging']['lanes']['Lord'];tray['units'].pop()
        events=ward_conversion.convert(rules.w,0,attack,1,'seed')
        self.assertEqual(1,len(events[0]['event']['data']['units']))
        rules,attack=fixtures.SplitWardTests().battle();self.cohort(rules.w)
        self.assertEqual([],ward_conversion.convert(rules.w,0,attack,2,'seed'))

    def test_reveal_records_attack_monster_but_excludes_separate_ward(self):
        game,order=fixtures.SplitWardTests().fixture()
        game._state['world']['data']['ward_conversion_experiment']='all'
        events=recipe_fixtures.WardRecipeTests().reveal(game,order)
        cohort=game._state['world']['data']['ward_conversion_cohorts'][0]
        spawn={r['data']['id']:r['data'] for r in events if r['type']=='MARCHER_SPAWNED'}
        self.assertTrue(any('monster_id' in spawn[k]['attributes'] for k in cohort['unit_ids']))
        self.assertTrue(set(spawn)-set(cohort['unit_ids']))
        self.assertTrue(all(spawn[k]['attributes']['lane']==order['lane'] for k in cohort['unit_ids']))

    def test_disabled_records_nothing(self):
        w=world(0);before=copy.deepcopy(w)
        ward_conversion.record(w,0,dict(action='Hunt',lane='Lord'),1,[])
        self.assertEqual([],ward_conversion.convert(w,0,dict(lane='Lord'),1,'seed'))
        self.assertEqual(before,w)


if __name__=='__main__':unittest.main()
