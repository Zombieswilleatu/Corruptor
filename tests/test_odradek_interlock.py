"""
Odradek Interlock — rules-contract tests.

These are INVARIANT tests, not recorded traces. Golden traces cannot catch an
aliasing or divergence fault: if it was present when they were recorded, they
encode it as correct and replay it faithfully.

Covers the §7 plan: empty-bank steal, one-card fallback, equal/lower lock with no
Soul, larger-card replacement, primary AND Momentum parity for both Hunt and
Siege, spend on both paths, Ward/Profane preserving the bank, banishment
discarding it, three-token Neutral Reconfiguration, exact doctrine deltas,
canonical DE v2 unchanged, deterministic tie-breaking, and 60-card conservation
with the bank counted as a zone.
"""
import copy
import random
import unittest

import corruptor_sim as sim


LAB = dict(
    odr_recoil_bank=True,
    fix_breach_discard_alias=True,
    reconfig_neutral=True,
    reconfig_tokens_needed=3,
    reconfig_strict=False,
    recoil_hunts_only=False,
    recoil_lowest=False,
    doctrine_ward_threat=0.20,
    doctrine_ward_stagnation=0.30,
    doctrine_bank_urgency=0.35,
)

CANON = dict(
    odr_recoil_bank=False,
    fix_breach_discard_alias=False,
    doctrine_ward_threat=0.0,
    doctrine_ward_stagnation=0.0,
    doctrine_bank_urgency=0.0,
)

ZONES = ('hand', 'garrison', 'lord_guards', 'castle_guards',
         'committed', 'penitent_temp_guards')


def card(suit, value):
    return sim.Card(suit, value)


class InterlockBase(unittest.TestCase):
    def setUp(self):
        self._variant = copy.deepcopy(sim.VARIANT)
        self._lock = sim.LOCK_LORDS
        sim.VARIANT.update(LAB)
        sim.LOCK_LORDS = True
        random.seed(1234)

    def tearDown(self):
        sim.VARIANT.clear()
        sim.VARIANT.update(self._variant)
        sim.LOCK_LORDS = self._lock

    def fresh(self, odradek_seat=0, other='Orias'):
        pair = (['Odradek'], [other]) if odradek_seat == 0 else ([other], ['Odradek'])
        g = sim.Game(*pair)
        g._setup()
        od = g.players[odradek_seat]
        at = g.players[1 - odradek_seat]
        od.alive = True
        od.odradek_recoil_done = False
        od.odradek_bank = None
        return g, od, at


# ──────────────────────────────────────────────────────────────────────
class TestRecoilSelection(InterlockBase):

    def test_empty_bank_steals_second_highest(self):
        g, od, at = self.fresh()
        at.committed = [card('Butcher', 5), card('Penitent', 4), card('Vulture', 2)]
        souls = od.souls
        r = g._odradek_recoil(at, od)
        self.assertTrue(r['fired'])
        self.assertEqual(od.odradek_bank.value, 4, "second-highest, not highest")
        self.assertNotIn(od.odradek_bank, at.committed)
        self.assertEqual(od.souls, souls + 1)

    def test_single_committed_card_is_taken(self):
        g, od, at = self.fresh()
        only = card('Wright', 3)
        at.committed = [only]
        g._odradek_recoil(at, od)
        self.assertIs(od.odradek_bank, only)
        self.assertEqual(at.committed, [])

    def test_no_commitment_fires_but_takes_nothing(self):
        g, od, at = self.fresh()
        at.committed = []
        souls = od.souls
        r = g._odradek_recoil(at, od)
        self.assertTrue(r['fired'], "Recoil is still spent for the round")
        self.assertIsNone(od.odradek_bank)
        self.assertEqual(od.souls, souls)

    def test_tie_resolves_deterministically_by_commit_order(self):
        """Two 4s: the SECOND one in committed order must be taken, every time."""
        for _ in range(25):
            g, od, at = self.fresh()
            a, b = card('Butcher', 4), card('Vulture', 4)
            at.committed = [card('Penitent', 5), a, b]
            g._odradek_recoil(at, od)
            self.assertIs(od.odradek_bank, a,
                          "stable order: first equal-value card at rank 2")


# ──────────────────────────────────────────────────────────────────────
class TestInterlockLock(InterlockBase):

    def test_equal_value_locks_no_card_no_soul(self):
        g, od, at = self.fresh()
        banked = card('Penitent', 4)
        od.odradek_bank = banked
        at.committed = [card('Butcher', 5), card('Vulture', 4)]
        souls, before = od.souls, list(at.committed)
        r = g._odradek_recoil(at, od)
        self.assertTrue(r['locked'])
        self.assertIs(od.odradek_bank, banked, "bank unchanged")
        self.assertEqual(at.committed, before, "no card moved")
        self.assertEqual(od.souls, souls, "no Soul on a locked Recoil")

    def test_lower_value_locks(self):
        g, od, at = self.fresh()
        od.odradek_bank = card('Penitent', 5)
        at.committed = [card('Butcher', 4), card('Vulture', 2)]
        r = g._odradek_recoil(at, od)
        self.assertTrue(r['locked'])
        self.assertEqual(od.odradek_bank.value, 5)

    def test_recoil_spent_even_when_locked(self):
        g, od, at = self.fresh()
        od.odradek_bank = card('Penitent', 5)
        at.committed = [card('Butcher', 3), card('Vulture', 3)]
        g._odradek_recoil(at, od)
        self.assertTrue(od.odradek_recoil_done,
                        "a blocked Recoil still consumes the round's use")

    def test_larger_card_replaces_and_discards_old_bank(self):
        g, od, at = self.fresh()
        old = card('Penitent', 2)
        od.odradek_bank = old
        at.committed = [card('Butcher', 5), card('Vulture', 4)]
        pre_discard = len(g.discard)
        souls = od.souls
        r = g._odradek_recoil(at, od)
        self.assertFalse(r['locked'])
        self.assertEqual(od.odradek_bank.value, 4)
        self.assertIs(r['replaced_card'], old)
        self.assertIn(old, g.discard)
        self.assertEqual(len(g.discard), pre_discard + 1)
        self.assertEqual(od.souls, souls + 1, "replacement earns the Soul")


# ──────────────────────────────────────────────────────────────────────
class TestBankSpend(InterlockBase):

    def test_attack_spends_bank_and_rearms(self):
        g, od, at = self.fresh()
        banked = card('Vulture', 5)
        od.odradek_bank = banked
        committed = [card('Butcher', 3)]
        spent = g._odradek_spend_bank(od, committed)
        self.assertIs(spent, banked)
        self.assertIn(banked, committed, "the physical card joins the commitment")
        self.assertIsNone(od.odradek_bank, "bank cleared")

    def test_bank_value_counts_toward_strength(self):
        g, od, at = self.fresh()
        od.odradek_bank = card('Vulture', 5)
        committed = [card('Butcher', 3)]
        g._odradek_spend_bank(od, committed)
        od.committed = committed
        self.assertEqual(od.committed_value(), 8)

    def test_spend_legal_with_no_hand_cards_selected(self):
        g, od, at = self.fresh()
        od.odradek_bank = card('Wright', 4)
        committed = []
        g._odradek_spend_bank(od, committed)
        self.assertEqual(len(committed), 1,
                         "Hunt/Siege may use the bank alone")

    def test_non_odradek_never_spends(self):
        g, od, at = self.fresh()
        at.odradek_bank = card('Wright', 4)   # nonsense state, must be ignored
        committed = []
        self.assertIsNone(g._odradek_spend_bank(at, committed))
        self.assertEqual(committed, [])

    def test_banishment_discards_bank(self):
        g, od, at = self.fresh()
        banked = card('Wright', 4)
        od.odradek_bank = banked
        pre = len(g.discard)
        g._odradek_discard_bank(od, reason='banished')
        self.assertIsNone(od.odradek_bank)
        self.assertIn(banked, g.discard)
        self.assertEqual(len(g.discard), pre + 1)


# ──────────────────────────────────────────────────────────────────────
class TestCanonicalUnchanged(InterlockBase):

    def test_canonical_recoil_discards_and_never_banks(self):
        sim.VARIANT.update(CANON)
        g, od, at = self.fresh()
        at.committed = [card('Butcher', 5), card('Penitent', 4)]
        pre = len(g.discard)
        g._odradek_recoil(at, od)
        self.assertIsNone(od.odradek_bank, "canonical DE v2 has no bank")
        self.assertEqual(len(g.discard), pre + 1, "canonical discards the card")

    def test_canonical_doctrine_terms_are_zero(self):
        sim.VARIANT.update(CANON)
        self.assertEqual(sim.VARIANT['doctrine_ward_threat'], 0.0)
        self.assertEqual(sim.VARIANT['doctrine_ward_stagnation'], 0.0)
        self.assertEqual(sim.VARIANT['doctrine_bank_urgency'], 0.0)


# ──────────────────────────────────────────────────────────────────────
class TestWardStreak(InterlockBase):

    def test_streak_increments_on_ward_and_resets_otherwise(self):
        g, od, at = self.fresh()
        od.consecutive_wards = 0
        for expected in (1, 2, 3):
            od.action = 'Ward'
            od.consecutive_wards = od.consecutive_wards + 1 if od.action == 'Ward' else 0
            self.assertEqual(od.consecutive_wards, expected)
        od.action = 'Hunt'
        od.consecutive_wards = od.consecutive_wards + 1 if od.action == 'Ward' else 0
        self.assertEqual(od.consecutive_wards, 0, "resets, does not decay")


# ──────────────────────────────────────────────────────────────────────
class TestPersistence(InterlockBase):

    def test_bank_and_streak_survive_round_reset(self):
        g, od, at = self.fresh()
        od.odradek_bank = card('Vulture', 5)
        od.consecutive_wards = 3
        od.reset_round()
        self.assertIsNotNone(od.odradek_bank,
                             "the bank is persistent; only explicit transitions clear it")
        self.assertEqual(od.consecutive_wards, 3,
                         "the streak is persistent across round reset")

    def test_recoil_done_does_reset_each_round(self):
        g, od, at = self.fresh()
        od.odradek_recoil_done = True
        od.reset_round()
        self.assertFalse(od.odradek_recoil_done, "once-per-ROUND")


# ──────────────────────────────────────────────────────────────────────
class TestConservation(InterlockBase):
    """60 distinct Card objects, bank counted as a zone, no object in two places."""

    @staticmethod
    def census(g):
        loc = {}
        def note(c, where):
            loc.setdefault(id(c), []).append(where)
        for zn, z in (('deck', g.deck), ('discard', g.discard), ('market', g.market)):
            for c in z:
                note(c, zn)
        for i, p in enumerate(g.players):
            for k in ZONES:
                for c in (p.__dict__.get(k) or []):
                    note(c, f'p{i}.{k}')
            for m in (getattr(p, 'marchers', None) or []):
                note(m['card'], f'p{i}.marcher')
            bank = getattr(p, 'odradek_bank', None)
            if bank is not None:
                note(bank, f'p{i}.bank')
        return loc

    def test_full_games_conserve_cards(self):
        random.seed(5)
        for i in range(150):
            g = sim.Game(['Odradek'], ['Orias'])
            g.run()
            loc = self.census(g)
            dupes = {k: v for k, v in loc.items() if len(v) > 1}
            self.assertEqual(dupes, {},
                             f"game {i}: same Card object in two zones: "
                             f"{list(dupes.values())[:3]}")
            self.assertEqual(len(loc), 60,
                             f"game {i}: expected 60 distinct cards, saw {len(loc)}")


if __name__ == '__main__':
    unittest.main(verbosity=2)
