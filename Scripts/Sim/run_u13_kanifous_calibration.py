#!/usr/bin/env python3
"""Compare V20, Power-only, Wealth-only, Resurrection-only and combined V21."""
import argparse
from pathlib import Path
from u13_doctrine.kanifous_calibration import run

if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--output',type=Path,required=True)
    p.add_argument('--workers',type=int,default=4)
    p.add_argument('--control-zip',type=Path)
    p.add_argument('--prepare-only',action='store_true')
    a=p.parse_args()
    if a.workers<1:p.error('--workers must be positive')
    run(Path(__file__).resolve().parents[2],a.output,a.workers,a.control_zip,a.prepare_only)
