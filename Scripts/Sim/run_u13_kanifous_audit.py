#!/usr/bin/env python3
"""Fixed V19/V20 Kanifous diagnostic audit; see u13_doctrine.kanifous_audit."""
import argparse
from pathlib import Path
from u13_doctrine.kanifous_audit import run

if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output',required=True,type=Path)
    parser.add_argument('--workers',type=int,default=2)
    args=parser.parse_args()
    if args.workers<1:parser.error('--workers must be positive')
    run(Path(__file__).resolve().parents[2],args.output,args.workers)
