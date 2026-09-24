import unittest
from .test_deimos import prepared
from .test_common import planning
from .common import CommonSmartCore
from .observation import observe, Preview
from .facts import Facts
from .lords.deimos import engine_progress
from u13_pysim import economy, power_components

class EngineFirstTests(unittest.TestCase):
    def test_first_work_is_engine(self):
        game=planning('Deimos'); view=observe(game,0)
        choice=CommonSmartCore().decide(view,Preview(game,0))
        row=Facts(view).by_id[choice['plan']['order']['castle_action']['target_id']]
        self.assertEqual('siege_engine',row['attributes']['combat_profile'])
        self.assertEqual('legal',Preview(game,0)(choice['plan'])['action'])

    def test_every_preview_contains_free_shot_even_when_redundant(self):
        for hp in (1,2,3,17):
            game,engine,_,_=prepared(hp=hp,last=True)
            seen=[]; actual=Preview(game,0)
            def preview(plan):
                seen.append(plan)
                self.assertEqual(1,sum(p['power_id']=='WarMachine' for p in plan['powers']))
                return actual(plan)
            choice=CommonSmartCore().decide(observe(game,0),preview)
            self.assertTrue(seen)
            self.assertIn('WarMachine',[p['power_id'] for p in choice['plan']['powers']])
            self.assertEqual([],choice['rejected_previews'])

    def test_defunct_engine_cannot_cast_and_locked_work_earns_nothing(self):
        game,engine,_,_=prepared()
        economy.entity(game._state['world'],engine)['attributes'].update(integrity=4,repair_lock_until_round=100)
        view=observe(game,0)
        plan=dict(powers=[],order=dict(castle_action=dict(action='Work',target_id=engine,card_ids=[],use_repair_token=False)))
        self.assertEqual(0,engine_progress(Facts(view),plan))
        choice=CommonSmartCore().decide(view,Preview(game,0))
        self.assertNotIn('WarMachine',[p['power_id'] for p in choice['plan']['powers']])

    def test_commission_engine_and_wright_progress(self):
        game,engine,_,_=prepared()
        row=economy.entity(game._state['world'],engine)
        row['attributes'].update(construction_state='building',integrity=7)
        view=observe(game,0)
        choice=CommonSmartCore().decide(view,Preview(game,0))
        self.assertEqual(dict(action='Activate',target_id=engine,card_ids=[],use_repair_token=False),
                         choice['plan']['order']['castle_action'])
        self.assertNotIn('WarMachine',[p['power_id'] for p in choice['plan']['powers']])
        row['attributes'].update(construction_state='unbuilt',integrity=0)
        cards=[r for r in game._state['world']['entities']['entities']
               if r['kind']=='card' and r['attributes']['suit']=='Wright'][:2]
        power_components.prepare(game,[dict(kind='fixture_give',player_id=0,card_id=r['id']) for r in cards])
        f=Facts(observe(game,0))
        plain=dict(powers=[],order=dict(castle_action=dict(action='Work',target_id=engine,card_ids=[],use_repair_token=False)))
        import copy
        wrights=copy.deepcopy(plain)
        wrights['order']['guard_moves']=[dict(card_id=r['id'],lane='Castle',slot=i) for i,r in enumerate(cards)]
        self.assertGreater(engine_progress(f,wrights),engine_progress(f,plain))

if __name__=='__main__': unittest.main()
