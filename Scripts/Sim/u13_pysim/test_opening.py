"""Free initial Lords and ordinary draw boundaries; later returns stay paid."""
import hashlib
import json
import unittest

from . import economy as e, opening, paid_development as paid
from .full_match_inputs import next_operation
from .power_match import PowerMatch
from .power_rules import RULES
from .verify_free_opening import setup


class FreeOpeningTests(unittest.TestCase):
    def test_saved_rules_identity_matches_current_declared_power_roster(self):
        # This roster has no floating-point values; its canonical JSON matches
        # native U13Match.snapshot. Native replay separately compares content.
        encoded = json.dumps(RULES, sort_keys=True, separators=(',', ':'), ensure_ascii=False)
        self.assertEqual(opening.RULES_HASH, hashlib.sha256(encoded.encode('utf-8')).hexdigest())

    def test_every_lord_starts_free_without_setup_cards_or_circle_damage(self):
        for index in range(9):
            world=PowerMatch(setup(index))._state['world']
            self.assertEqual([[],[]],e.zones(world)['hands'])
            self.assertEqual([],e.zones(world)['discard'])
            self.assertEqual(57,len(e.zones(world)['deck']))
            self.assertTrue(e.cards_valid(world))
            self.assertEqual([1,1],world['data']['summon_counts'])
            self.assertEqual(0,world['data']['neutral_tears'])
            for record in world['data']['game_economy']['opening']['summons']:
                self.assertEqual((0,0,0,[],[],0,''),tuple(record[k] for k in
                    ('cost','paid_value','shortfall','card_ids','card_values','circle_exerted','circle_id')))
            for row in world['entities']['entities']:
                if row['kind']=='lord':
                    self.assertTrue(row['attributes']['alive'])
                    self.assertEqual(0,row['attributes'].get('threat',0))
                elif row['kind']=='castle':
                    self.assertEqual(17 if row['attributes']['castle_slot']<3 else 0,row['attributes']['integrity'])

    def test_first_planning_hand_is_normal_draw_plus_one_stockpile_card(self):
        for index in range(9):
            game=PowerMatch(setup(index))
            while game.clock.hook!='submission_lock':
                self.assertNotEqual('invalid',game.apply(next_operation(game))['action'])
            self.assertEqual([6,5],[len(h) for h in e.zones(game._state['world'])['hands']])
            before=game.snapshot()
            self.assertEqual('invalid',game.apply(dict(kind='step',hook='round_start_automatic'))['action'])
            self.assertEqual(before,game.snapshot())

    def test_round_two_and_later_resummon_keep_ordinary_costs(self):
        world=PowerMatch(setup(0))._state['world']
        # Seat one has neither an active Stockpile nor Circle.
        e.start_draw(world,'unit-round-draw',1)
        pending=world['data']['game_economy']['stockpile_pending']
        e.choose_stockpile(world,0,{'keep_id':pending['card_ids'][0]},'unit-round-draw',1,'present_public_state')
        self.assertEqual([6,5],[len(h) for h in e.zones(world)['hands']])
        for pid in (0,1): e.discard(world,pid,e.zones(world)['hands'][pid][:])
        e.start_draw(world,'unit-round-draw',2)
        pending=world['data']['game_economy']['stockpile_pending']
        e.choose_stockpile(world,0,{'keep_id':pending['card_ids'][0]},'unit-round-draw',2,'present_public_state')
        self.assertEqual([6,5],[len(h) for h in e.zones(world)['hands']])
        for pid in (0,1):
            e.entity(world,world['players'][pid]['lord_entity_id'])['attributes']['alive']=False
            q=paid.summon_quote(world,pid,[])
            self.assertEqual(opening.COSTS[world['players'][pid]['lord_id']]-(3 if pid==0 else 0),q['cost'])
        self.assertEqual(17,e.entity(world,opening.castle_id(0,2))['attributes']['integrity'])


if __name__=='__main__': unittest.main()
