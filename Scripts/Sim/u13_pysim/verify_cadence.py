"""Create native cadence projects and replay representative complete phases."""
import argparse
import json
from pathlib import Path
from . import cadence_balance as cadence, codec
from . import verify_monster_pair_balance as native


def export(directory, variant):
    directory.mkdir(parents=True,exist_ok=False)
    candidates=[s for s in cadence.specs(1)+cadence.tank_followup_specs(1) if s['variant']==variant]
    selected={}
    for s in candidates:
        # Cover different roles, both seats and contact/spawn geometry.
        key=(s['category'],s['layout'],s['seat'])
        if key not in selected:selected[key]=s
    records=[]
    for spec in selected.values():cadence.pairs.run(spec,export=records)
    with (directory/'inputs.jsonl').open('w') as inp,(directory/'expected.jsonl').open('w') as out:
        for r in records:
            inp.write(json.dumps({k:r[k] for k in ('world','seed','round')})+'\n')
            out.write(codec.dumps(r['result'])+'\n')
    print(json.dumps(dict(variant=variant,battles=len(selected),phases=len(records))))


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('action',choices=['project','export','compare','boundaries'])
    p.add_argument('path',type=Path)
    p.add_argument('variant',nargs='?')
    a=p.parse_args()
    if a.action=='project':print(native.native_project(a.path,a.variant))
    elif a.action=='export':export(a.path,a.variant)
    elif a.action=='compare':native.compare(a.path)
    else:
        from .verify_monsters import verify
        cadence.pairs.install(a.variant)
        print(json.dumps(verify(a.path),indent=2))


if __name__=='__main__':main()
