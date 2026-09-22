#!/usr/bin/env python3
"""Focused release gate; refuses script errors even when Godot exits zero."""
import argparse
from pathlib import Path
import subprocess
import sys

ROOT=Path(__file__).resolve().parents[2]
RUNNERS=('U13WardRecipeTestRunner','U13PlayableBoardTestRunner','U13GameStagingTestRunner',
         'U13ActionForecastTestRunner','U13VeilWheelTestRunner','U13SigilsTestRunner','U13VictoryTestRunner')

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot',required=True)
    args=parser.parse_args()
    for runner in RUNNERS:
        result=subprocess.run([args.godot,'--headless','--path',str(ROOT),'--script',
            f'Scripts/Sim/{runner}.gd'],capture_output=True,text=True,timeout=180,cwd=ROOT)
        output=result.stdout+result.stderr
        if result.returncode or 'SCRIPT ERROR' in output or '\nFAIL ' in output:
            print(output);raise SystemExit(f'{runner} failed')
        print(f'PASS {runner}',flush=True)
    subprocess.run([sys.executable,str(ROOT/'Scripts/Sim/verify_u13_playable_tempo.py'),
                    '--godot',args.godot],cwd=ROOT,check=True)

if __name__=='__main__':main()
