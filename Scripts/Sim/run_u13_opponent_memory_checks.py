#!/usr/bin/env python3
"""Focused memory checks; optional native projection parity with a Godot path."""
import argparse
from pathlib import Path
import subprocess
import tempfile
import unittest
from u13_pysim.codec import dumps
from u13_doctrine.opponent_memory import project
from u13_doctrine.test_opponent_memory import reveal


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot')
    args=parser.parse_args()
    suite=unittest.defaultTestLoader.loadTestsFromName('u13_doctrine.test_opponent_memory')
    if not unittest.TextTestRunner(verbosity=2).run(suite).wasSuccessful(): return 1
    if args.godot:
        rows=[reveal(n) for n in range(1,10)]+[reveal(9,'Ward',strength=7)]
        private=reveal(9);private['views']=[None,None];rows.append(private)
        cases=[dict(name=f'projection-{seat}-{n}', rows=rows, seat=seat, round=n,
                    expected=project(rows,seat,n)) for seat in (0,1) for n in (1,2,7,9,10,12)]
        with tempfile.TemporaryDirectory(prefix='corruptor-memory-') as folder:
            path=Path(folder)/'parity.json';path.write_text(dumps(cases))
            return subprocess.run([args.godot,'--headless','--path',str(Path(__file__).resolve().parents[2]),
                '--script','Scripts/Sim/U13OpponentMemoryTestRunner.gd','--',str(path)],check=False).returncode
    return 0


if __name__=='__main__':raise SystemExit(main())
