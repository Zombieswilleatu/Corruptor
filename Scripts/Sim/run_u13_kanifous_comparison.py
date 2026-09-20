#!/usr/bin/env python3
"""Run the fixed 72-game Kanifous V19/V20 paired screen."""
import argparse
from pathlib import Path
from u13_doctrine.kanifous_comparison import run

if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output',type=Path,required=True)
    parser.add_argument('--workers',type=int,default=4)
    parser.add_argument('--prepare-only',action='store_true',help='Freeze policies and write the manifest without running games')
    args=parser.parse_args()
    if args.workers<1:parser.error('--workers must be positive')
    run(Path(__file__).resolve().parents[2],args.output,args.workers,args.prepare_only)
