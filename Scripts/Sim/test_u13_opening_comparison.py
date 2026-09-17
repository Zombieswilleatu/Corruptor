"""Check the experiment's setup isolation and ordinary first-round economy."""
import unittest

from compare_u13_openings import make_match, undealt_deck, EXPERIMENT
from u13_doctrine.common import CommonSmartCore
from u13_doctrine.observation import observe
from u13_doctrine.survey import cases
from u13_pysim import economy, full_match_inputs, opening
from u13_pysim.power_match import PowerMatch


@unittest.skipUnless(opening.ECONOMY == "U13_GAME_ECONOMY_V4",
    "Historical A/B requires ad53086; current setup is covered by test_opening.")
class OpeningComparisonTests(unittest.TestCase):
    def test_control_is_unchanged_and_experiment_is_detached(self):
        setup = next(cases(1))['setup']
        original = PowerMatch(setup).snapshot()
        control = make_match(setup, 'control')
        alternative = make_match(setup, 'normal_draw')
        self.assertEqual(original, control.snapshot())
        self.assertEqual(original, PowerMatch(setup).snapshot())
        self.assertIn(EXPERIMENT, alternative._state['policy_id'])
        self.assertNotEqual(original['rules_hash'], alternative._state['rules_hash'])
        with self.assertRaisesRegex(ValueError, 'unknown opening'):
            make_match(setup, 'typo')

    def test_free_start_restores_complete_deck_and_full_circle(self):
        for spec in list(cases(1))[::9]:
            setup = spec['setup']; match = make_match(setup, 'normal_draw')
            w = match._state['world']; z = economy.zones(w)
            deck, market = undealt_deck(setup['seed'])
            self.assertEqual((deck,market), (z['deck'],z['market']))
            self.assertEqual([[],[]], z['hands']); self.assertEqual([],z['discard'])
            self.assertEqual(60,len(deck)+len(market)); self.assertTrue(economy.cards_valid(w))
            for record in w['data']['game_economy']['opening']['summons']:
                self.assertEqual((0,0,0,[]),(record['cost'],record['paid_value'],record['circle_exerted'],record['card_ids']))
            for row in w['entities']['entities']:
                if row['kind']=='lord': self.assertTrue(row['attributes']['alive'])
                if row['kind']=='castle' and row['attributes']['construction_state']=='active':
                    self.assertEqual(17,row['attributes']['integrity'])

    def test_first_round_uses_normal_draw_stockpile_and_market(self):
        match = make_match(next(cases(1))['setup'],'normal_draw')
        policy = CommonSmartCore()
        for _ in range(20):
            if match.clock.hook=='submission_lock': break
            data = match._state['world']['data']
            if match.clock.hook=='present_public_state' and data['game_economy']['stockpile_pending']:
                seat=data['game_economy']['stockpile_pending']['player_id']
                op=policy.choose_card(observe(match,seat),'stockpile')['operation']
            elif match.clock.hook=='present_public_state' and data['game_market']['seat']!=2:
                seat=data['game_market']['seat']
                op=policy.choose_card(observe(match,seat),'slaver')['operation']
            else: op=full_match_inputs.next_operation(match)
            self.assertNotEqual('invalid',match.apply(op)['action'])
        self.assertEqual('submission_lock',match.clock.hook)
        self.assertEqual([6,6],[len(observe(match,p)['hand']) for p in (0,1)])
        self.assertTrue(economy.cards_valid(match._state['world']))


if __name__=='__main__': unittest.main()
