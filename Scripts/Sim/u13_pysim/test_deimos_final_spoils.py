import unittest
from u13_doctrine.test_common import planning
from u13_doctrine import test_split_ward as split_fixtures
from . import economy as e
from .battle import Battle
from .copying import copy_data


def fixture(pid=0, spare=False, alive=True):
    g=planning('Deimos');w=g._state['world']
    w['players'][pid]['lord_id']='Deimos'
    lord=e.entity(w,w['players'][pid]['lord_entity_id']);lord['attributes'].update(lord_id='Deimos',alive=alive,threat=0)
    castles=[r for r in w['entities']['entities'] if r['kind']=='castle' and r['owner']==1-pid]
    for i,c in enumerate(castles):
        c['attributes'].update(construction_state='active' if i<3 else 'unbuilt',status='standing' if i==0 or (spare and i==1) else 'ruined' if i<3 else 'defunct',integrity=1 if i==0 or (spare and i==1) else 0)
    b=Battle(w,1,'last-castle-test',[0,1],'combat_resolution')
    return b,castles


def ruin(b,c,pid=0,tag='test'):
    return b.apply_fact(dict(kind='ruin_castle',command_id=tag,target_id=c['id'],player_id=pid))

class FinalSpoilsTests(unittest.TestCase):
    def test_last_castle_adds_one_to_normal_spoils_both_seats(self):
        for pid in (0,1):
            b,cs=fixture(pid);before=b.w['players'][pid]['resources']['personal_tears']
            ev=ruin(b,cs[0],pid)
            self.assertEqual(before+2,b.w['players'][pid]['resources']['personal_tears'])
            self.assertEqual(1,sum(x['event']['type']=='DEIMOS_ALL_CASTLES_RUINED' for x in ev))
            self.assertTrue(b.w['data']['deimos_all_castles_ruined'][pid])

    def test_defunct_castle_still_blocks_bonus(self):
        b,cs=fixture(spare=True);cs[1]['attributes']['status']='defunct'
        ev=ruin(b,cs[0]);self.assertFalse(any(x['event']['type']=='DEIMOS_ALL_CASTLES_RUINED' for x in ev))
        ev=ruin(b,cs[1],tag='last');self.assertTrue(any(x['event']['type']=='DEIMOS_ALL_CASTLES_RUINED' for x in ev))
        self.assertEqual(2,b.w['data']['deimos_spoils'][0])

    def test_repeated_event_and_reconstruction_do_not_repeat_reward(self):
        b,cs=fixture();ev=ruin(b,cs[0]);fact=next(x['event'] for x in ev if x['event']['type']=='CASTLE_DESTROYED')
        before=b.w['players'][0]['resources']['personal_tears'];self.assertEqual([],b.react(fact))
        restored=Battle(copy_data(b.w),2,b.seed,b.order,b.hook)
        c=e.entity(restored.w,cs[0]['id']);c['attributes'].update(status='standing',integrity=7)
        ev=ruin(restored,c,tag='rebuilt')
        self.assertFalse(any(x['event']['type']=='DEIMOS_ALL_CASTLES_RUINED' for x in ev))
        self.assertEqual(before,restored.w['players'][0]['resources']['personal_tears'])

    def test_banished_or_other_lord_gets_no_deimos_reward(self):
        for mode in ('banished','other'):
            b,cs=fixture(alive=mode!='banished')
            if mode=='other':b.lord(0)['attributes']['lord_id']='Kalligan';b.w['players'][0]['lord_id']='Kalligan'
            ev=ruin(b,cs[0]);self.assertFalse(any(x['event']['type']=='DEIMOS_ALL_CASTLES_RUINED' for x in ev))
            self.assertNotIn('deimos_all_castles_ruined',b.w['data'])

    def test_pillage_returns_guard_before_combat_and_stops_when_banished(self):
        for alive in (True,False):
            rules,attack=split_fixtures.SplitWardTests().battle(1,guard=True)
            lord=rules.lord(0);lord['attributes'].update(lord_id='Deimos',alive=alive,threat=0)
            rules.w['players'][0]['lord_id']='Deimos'
            guard=e.entity(rules.w,'fixture-guard');guard['attributes'].update(lane='Castle',value=5)
            attack.update(action='Siege',lane='Castle',target_id='castle_zone:1');rules.orders=[attack,{}]
            before=rules.w['players'][0]['resources']['souls'];ev=rules.siege(0,attack)
            kinds=[x['event']['type'] for x in ev]
            if alive:
                aura=next(x['event']['data'] for x in ev if x['event']['type']=='FEAR_AURA')
                self.assertEqual(['fixture-guard'],aura['returned_ids'])
                self.assertIn('fixture-guard',e.zones(rules.w)['hands'][1])
                self.assertLess(kinds.index('FEAR_AURA'),kinds.index('SIEGE_RESOLVED'))
            else:self.assertNotIn('FEAR_AURA',kinds)
            self.assertEqual(before+int(alive),rules.w['players'][0]['resources']['souls'])
            self.assertEqual(0,ev[-1]['event']['data']['guards_defeated'])

if __name__=='__main__':unittest.main()
