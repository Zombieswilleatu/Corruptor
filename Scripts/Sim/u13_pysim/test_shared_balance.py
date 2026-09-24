"""Exercise printed commitments through real combat and policy payments."""
import unittest
from u13_doctrine import test_split_ward as fixtures
from u13_doctrine.facts import Facts
from . import economy, split_ward
from .copying import copy_data

SUITS = ('Butcher', 'Penitent', 'Vulture', 'Wright')


class SharedBalanceTests(unittest.TestCase):
    def test_every_suit_and_value_in_attack_ward_and_payment(self):
        for action in ('Hunt', 'Siege'):
            for i, suit in enumerate(SUITS):
                for value in range(1, 6):
                    with self.subTest(action=action, suit=suit, value=value):
                        rules, attack = fixtures.SplitWardTests().battle(value)
                        ward = rules.orders[1]
                        attacker = economy.entity(rules.w, attack['card_ids'][0])
                        defender = economy.entity(rules.w, ward['card_ids'][0])
                        attacker['attributes'].update(suit=suit, value=value)
                        defender['attributes'].update(suit=SUITS[(i+1)%4], value=6-value)
                        if action == 'Siege':
                            attack.update(action='Siege', lane='Castle', target_id='castle_zone:1')
                            ward['lane'] = 'Castle'
                        facts = Facts(dict(player_id=0, round=rules.number, players=rules.w['players'], data=rules.w['data'],
                            board=[r for r in rules.w['entities']['entities'] if r['kind']=='lord'], hand=[attacker]))
                        self.assertEqual(value, facts.strength(attack['card_ids'], action))
                        for exempt in (None, 'Butcher', 'Penitent'):
                            self.assertEqual(attack['card_ids'], facts.payment(value, exempt))
                            self.assertEqual([], facts.payment(value+1, exempt))
                        events = split_ward.resolve_attack(rules, 0, attack)
                        resolved = next(r['event']['data'] for r in events
                                        if r['event']['type']==action.upper()+'_RESOLVED')
                        self.assertEqual(value, resolved['strength'])
                        self.assertEqual(6-value, resolved['ward_screen'])

    def test_lord_runner_enables_tested_profile_without_changing_legacy_cases(self):
        from run_u13_lord_balance import balance_cases
        from u13_doctrine.survey import cases
        from .power_match import PowerMatch
        current = balance_cases(1, 'shared-baseline-test')
        legacy = list(cases(1, 'shared-baseline-test'))
        self.assertEqual(81, len(current))
        for new, old in zip(current, legacy):
            self.assertEqual(old['name'], new['name'])
            self.assertEqual(old['setup']['seed'], new['setup']['seed'])
            self.assertEqual(split_ward.VERSION, new['setup']['ward_experiment'])
            self.assertEqual(split_ward.TEMPO, new['setup']['tempo_experiment'])
            self.assertNotIn('tempo_experiment', old['setup'])
        game = PowerMatch(current[0]['setup'])
        self.assertTrue(split_ward.enabled(game._state['world']))
        self.assertTrue(split_ward.tempo_enabled(game._state['world']))

    def test_same_suit_pair_has_no_commitment_bonus(self):
        for suit in SUITS:
            rules, attack = fixtures.SplitWardTests().battle(3)
            row = economy.entity(rules.w, attack['card_ids'][0])
            row['attributes'].update(suit=suit, value=3)
            extra = copy_data(row); extra['id']='extra-printed-card'
            rules.w['entities']['entities'].append(extra)
            for exempt in ('Butcher', 'Penitent'):
                self.assertEqual(6, rules.strength([row['id'], extra['id']], exempt))


if __name__ == '__main__': unittest.main()
