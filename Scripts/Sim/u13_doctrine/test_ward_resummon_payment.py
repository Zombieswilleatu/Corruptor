"""A split Ward must not make the global card ledger invalid during resummon."""
import unittest
from .test_split_ward import SplitWardTests
from .observation import Preview
from u13_pysim import economy as e
from u13_pysim.copying import copy_data

class WardResummonPaymentTests(unittest.TestCase):
    def fixture(self):
        game, order = SplitWardTests().fixture()
        w=game._state['world']; lord=e.entity(w,w['players'][0]['lord_entity_id'])
        lord['attributes']['alive']=False
        cards=e.zones(w)['hands'][0][:]
        order.pop('monster_choice',None)
        order['card_ids']=cards[:1]
        order['ward']['card_ids']=cards[1:2]
        order['summon']=dict(card_ids=cards[2:])
        return game,dict(powers=[],order=order)

    def test_distinct_ward_attack_and_resummon_payments_are_legal(self):
        game,plan=self.fixture();before=game.snapshot()
        self.assertEqual('legal',Preview(game,0)(plan)['action'])
        self.assertEqual(before,game.snapshot())
        result=game.apply(dict(kind='submit_one',player_id=0,plan=plan))
        self.assertNotEqual('invalid',result['action'],result)
        self.assertTrue(e.cards_valid(game._state['world']))

    def test_ward_card_cannot_pay_resummon_too(self):
        game,plan=self.fixture()
        plan['order']['summon']['card_ids']+=plan['order']['ward']['card_ids']
        before=game.snapshot()
        result=game.apply(dict(kind='submit_one',player_id=0,plan=plan))
        self.assertEqual('invalid',result['action'])
        self.assertEqual(before,game.snapshot())
