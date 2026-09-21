"""The memory optimization must retain every exact transport bit."""
import hashlib
import unittest

from . import codec


class StreamDigestTests(unittest.TestCase):
    def test_matches_original_bytes_across_chunks_and_nested_types(self):
        values = [None, True, False, -(1 << 63), (1 << 63)-1, 0.0, -0.0,
                  5e-324, 1.7976931348623157e308, '\"\\\n雪🦉', [], {},
                  {'z': [True, 1, 1.0], 'a': {'雪': 'x'*100000}},
                  [{'id': i, 'position': [i/7, -0.0]} for i in range(3000)]]
        for value in values:
            with self.subTest(type=type(value)):
                self.assertEqual(hashlib.sha256(codec.dumps(value).encode()).hexdigest(), codec.sha256(value))

    def test_rejects_same_invalid_data(self):
        for value in [float('nan'), float('inf'), 1 << 63, (1,), {1: 'x'}, '\ud800', {'\ud800': 1}]:
            with self.subTest(value=repr(value)):
                with self.assertRaises(ValueError): codec.dumps(value).encode()
                with self.assertRaises(ValueError): codec.sha256(value)
        nested = None
        for _ in range(128): nested = [nested]
        self.assertEqual(hashlib.sha256(codec.dumps(nested).encode()).hexdigest(), codec.sha256(nested))
        with self.assertRaises(ValueError): codec.sha256([nested])


if __name__ == '__main__': unittest.main()
