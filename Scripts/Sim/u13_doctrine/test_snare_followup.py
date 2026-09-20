"""Threat threshold, actual Conduit accounting, and competing card commitments."""
import unittest

from u13_pysim.battle import Battle, operational
from u13_pysim.copying import copy_data
from .facts import Facts
from .snare_followup import alternatives
from .test_orias import view, snare
from .test_recipes_veil import hand


def fixture(threat=1, count=3):
    v = view(); hand(v, [('Butcher', 4)]*count)
    v['board'] = [r for r in v['board'] if r['attributes'].get('castle_type') != 'SummoningCircle']
    Facts(v).lord[0]['attributes']['threat'] = threat
    return v


def circle(v, integrity):
    row = copy_data(Facts(v).castles(0)[0]); row['id'] = 'forecast_circle'
    row['attributes'].update(castle_type='SummoningCircle', integrity=integrity,
                             status='standing', construction_state='active')
    v['board'].append(row)
    return row


class SnareFollowupTests(unittest.TestCase):
    def test_opportunistic_at_two_selective_above_two(self):
        for threat in (0, 1, 2):
            with self.subTest(threat=threat):
                result = snare(fixture(threat))
                self.assertFalse(result['competitive'])
                self.assertEqual(threat+1, result['cost']['threat_after'])
                if threat < 2:
                    self.assertGreater(result['score'], 0)
                    self.assertEqual('low_threat_opportunistic_setup', result['reason'])
                else:
                    self.assertLess(result['score'], 0)
                    self.assertEqual('high_threat_better_competing_plan', result['reason'])

    def test_selective_does_not_mean_never_cast(self):
        result = snare(fixture(2, 5))
        self.assertTrue(result['cost']['selective'])
        self.assertTrue(result['competitive'])
        self.assertGreater(result['score'], 0)
        self.assertTrue(all(s['attack_margin'] >= 0 for s in result['follow_up']['scenarios']))

    def test_circle_restores_low_threat_aggression_but_charges_integrity(self):
        v = fixture(2); held = snare(v)
        row = circle(v, 10); supported = snare(v)
        self.assertLess(held['score'], 0)
        self.assertEqual(2, supported['cost']['threat_after'])
        self.assertFalse(supported['cost']['selective'])
        self.assertGreater(supported['score'], 0)
        row['attributes']['integrity'] = 9
        damaged = snare(v)
        self.assertTrue(damaged['cost']['circle_loses_operation'])
        self.assertEqual(6, damaged['cost']['circle_integrity_after'])
        self.assertLess(damaged['score'], 0)

    def test_circle_cost_matches_battle_authority_across_thresholds(self):
        for threat in range(6):
            for integrity in (6, 7, 9, 10):
                with self.subTest(threat=threat, integrity=integrity):
                    v = fixture(threat); circle(v, integrity)
                    before = copy_data(v); predicted = snare(v)['cost']
                    f = Facts(copy_data(v)); c = f.by_id['forecast_circle']
                    actual, events = Battle(f.world, v['round'], 'cost-test', [0, 1], 'power').conduit(f.lord[0], 1)
                    self.assertEqual(actual, predicted['threat_after'])
                    self.assertEqual(integrity-c['attributes']['integrity'], predicted['circle_integrity_cost'])
                    self.assertEqual(bool(events) and not operational(c), predicted['circle_loses_operation'])
                    self.assertEqual(before, v)

    def test_lord_ward_does_not_erase_immediate_selectivity_or_circle_damage(self):
        v = fixture(2)
        ward = dict(action='Ward', lane='Lord', card_ids=[])
        result = snare(v, ward)
        self.assertTrue(result['cost']['selective'])
        self.assertLess(result['score'], 0)
        circle(v, 9)
        self.assertEqual(snare(v)['cost'], snare(v, ward)['cost'])

    def test_competing_guard_and_ward_use_disjoint_cards(self):
        f = Facts(fixture())
        result = alternatives(f)
        self.assertEqual('Ward', result['action'])
        self.assertEqual(2, len(result['guard_card_ids']))
        self.assertEqual(1, len(result['card_ids']))
        self.assertFalse(set(result['card_ids']).intersection(result['guard_card_ids']))
        self.assertEqual(set(r['id'] for r in f.hand), set(result['card_ids']+result['guard_card_ids']))

    def test_competing_recipe_recruitment_is_counted(self):
        v = fixture(); hand(v, [('Penitent', 4)]*4)
        result = snare(v)
        self.assertEqual('Lemek', result['competing_plan']['monster'])
        self.assertFalse(result['competitive'])
        self.assertGreater(result['score'], 0)


if __name__ == '__main__': unittest.main()
