#!/usr/bin/env python3
"""810-game unified V42 baseline; rerun the same command to resume its frozen source."""
import argparse,ctypes,json,os
from pathlib import Path
import subprocess,sys

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--output',type=Path,default=Path.home()/'Downloads/Corruptor/Balance/u13-unified-v42-overnight')
    p.add_argument('--workers',type=int,default=3)
    p.add_argument('--prepare-only',action='store_true')
    args=p.parse_args()
    if args.workers<1:p.error('workers must be positive')
    root=Path(__file__).resolve().parents[2];output=args.output.resolve()
    resume=output.exists()
    if resume:
        config=json.loads((output/'balance-config.json').read_text())
        if config['repeats']!=10 or config['namespace']!='u13-unified-v41-overnight-2026-09-27':raise SystemExit('Existing output is not the 810-game run. Choose a different --output.')
        frozen=output/'source/Scripts/Sim/u13_pysim/muster_endurance.py'
        if not frozen.exists() or 'THRESHOLD = 25' not in frozen.read_text():
            raise SystemExit('Existing output is a different baseline. Choose a different --output.')
    else:
        from u13_doctrine.common import VERSION
        if VERSION != "U13_COMMON_SMART_CORE_ALPHA_V42_DEIMOS_FINAL_SPOILS":raise SystemExit("This runner expects the combined V42 doctrine.")
        from u13_pysim.muster_endurance import THRESHOLD
        if THRESHOLD!=25:raise SystemExit('This runner expects Muster Endurance 25.')
    command=[sys.executable,'-u',str(root/'Scripts/Sim/run_u13_lord_balance.py'),
             '--resume' if resume else '--output',str(output),'--repeats','10',
             '--workers',str(args.workers),'--worker-batch-size','6']
    if args.prepare_only:command+=['--prepare-only']
    print(('RESUMING' if resume else 'STARTING')+' 810 games; '+str(args.workers)+' workers; recycling every 6 games.',flush=True)
    print('Run this same command again after interruption. Completed games are retained.',flush=True)
    awake=False
    if os.name=='nt' and not args.prepare_only:
        awake=bool(ctypes.windll.kernel32.SetThreadExecutionState(0x80000001))
        print('Idle sleep prevention '+('enabled; keep the laptop plugged in and lid open.' if awake else 'unavailable; disable idle sleep manually.'),flush=True)
    try:return subprocess.call(command,cwd=root)
    except KeyboardInterrupt:return 130
    finally:
        if awake:ctypes.windll.kernel32.SetThreadExecutionState(0x80000000)

if __name__=='__main__':raise SystemExit(main())
