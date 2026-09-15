import copy
import math
import unittest

from . import codec, opening, primitives


class FoundationTests(unittest.TestCase):
    def test_known_rng_vectors_and_independence(self):
        for args, expected in [(("seed", "effect", "PRICE_DELAY", 0, 6), 5),
                               (("seed", "effect", "PRICE_TYPE", 0, 17), 6),
                               (("s:é", "龍", "target", 42, 4294967296), 3876510453),
                               (("seed", "effect", "PRICE_TARGET", 3, 2147483649), 169728365)]:
            self.assertEqual(primitives.draw(*args), expected)
        for i in range(30):
            primitives.draw("seed", "unrelated", "OTHER", i, 100)
        self.assertEqual(primitives.draw("seed", "effect", "PRICE_DELAY", 0, 6), 5)
        for index, bound in [(-1, 6), (False, 6), (0, 0), (0, 4294967297)]:
            with self.assertRaises(ValueError):
                primitives.draw("seed", "effect", "purpose", index, bound)

    def test_identity_unicode_uses_characters(self):
        self.assertEqual(primitives.entity_id("marcher", "龍:é:🕷", 12), "u13_entity_marcher:5:龍:é:🕷:2:12")
        self.assertNotEqual(primitives.entity_id("card", "deck", 0), primitives.entity_id("card", "deck", 1))
        self.assertNotEqual(primitives.instance_id("pending", "a:b", "c"), primitives.instance_id("pending", "a", "b:c"))

    def test_retirement_restore_and_atomic_rejection(self):
        ids = primitives.Entities()
        first = ids.create("castle", "old", 0, 0)
        ids.retire(first)
        second = ids.create("castle", "rebuild", 0, 0)
        restored = primitives.Entities()
        restored.restore(ids.snapshot())
        with self.assertRaises(ValueError):
            restored.create("castle", "old", 0, 0)
        before = restored.snapshot()
        broken = copy.deepcopy(before)
        broken["entities"][0]["id"] = "forged"
        with self.assertRaises(ValueError):
            restored.restore(broken)
        self.assertEqual(before, restored.snapshot())
        attrs = {"x_fp": 12.0, "nested": {"value": 1.0}}
        restored.update(second, 1, attrs)
        attrs["nested"]["value"] = 999
        self.assertEqual(restored.rows[second]["attributes"], {"x_fp": 12, "nested": {"value": 1}})
        with self.assertRaises(ValueError):
            restored.update(second, 1, {"x_fp": 1.5})

    def test_transport_boundaries_and_malformed_input(self):
        value = {"": [None, False, 0, 1.0, -0.0, 0.1, math.nextafter(0.0, 1.0),
                       -(1 << 63), (1 << 63) - 1, "龍🕷", {"f": "literal"}]}
        self.assertIsNone(codec.first_difference(value, codec.loads(codec.dumps(value))))
        for node in [["i", "01"], ["i", "-0"], ["i", str(1 << 63)], ["f", "000000000000f07f"],
                     ["f", "000000000000f87f"], ["b", 1], ["unknown", 0],
                     ["d", [["x", ["n"]], ["x", ["n"]]]], ["n", None]]:
            with self.assertRaises(ValueError):
                codec.unpack(node)
        with self.assertRaises(ValueError):
            codec.loads('{"codec":"U13_EXACT_DATA_V1","codec":"U13_EXACT_DATA_V1","payload":["n"]}')
        for value in [float("nan"), float("inf"), 1 << 64, {1: "bad key"}, object()]:
            with self.assertRaises(ValueError):
                codec.dumps(value)

    def test_comparison_locates_real_changes(self):
        expected = {"phase": {"guards": [{"id": "a", "slot": 0}, {"id": "b", "slot": 1}], "x": 0.1}}
        for mutate, field in [
            (lambda x: x["phase"].pop("guards"), "guards"),
            (lambda x: x["phase"].update(extra=0), "extra"),
            (lambda x: x["phase"]["guards"].reverse(), "guards"),
            (lambda x: x["phase"]["guards"][0].update(id="forged"), "id"),
            (lambda x: x["phase"]["guards"][0].update(slot=2), "slot"),
            (lambda x: x["phase"].update(x=math.nextafter(0.1, 1.0)), "x")]:
            changed = copy.deepcopy(expected)
            mutate(changed)
            self.assertIn(field, codec.first_difference(expected, changed))
        self.assertIsNotNone(codec.first_difference(True, 1))
        self.assertIsNotNone(codec.first_difference(1, 1.0))
        self.assertIsNotNone(codec.first_difference(0.0, -0.0))

    def test_opening_input_boundaries(self):
        for lords, castles in [(["unknown", "Deimos"], [opening.CASTLES] * 2),
                               (["Gremory", "Deimos"], [["Keep"] * 5, opening.CASTLES]),
                               (["Gremory"], [opening.CASTLES] * 2)]:
            with self.assertRaises(ValueError):
                opening.world("test", lords, castles)


if __name__ == "__main__":
    unittest.main()
