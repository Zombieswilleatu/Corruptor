"""Paired attack-rate experiments on the live Wright-repair rules.

Rates are maximum ordinary attacks during 200 ticks of continuous contact;
cooldowns carry between rounds. Abilities, healing and movement keep their rules.
"""
import argparse
import concurrent.futures
import hashlib
import itertools
import json
import subprocess
import time
from pathlib import Path

from . import monster_pair_balance as pairs

RATES = {'live': (8,32), 'm8r4': (25,50), 'm6r4': (34,50), 'm5r4': (40,50), 'm6r3': (34,67)}
BASES = {'plain': {}, 'b2': {'butcher_attack':2}, 'lead': {'penitent_lead':90},
         'k10': {'kurchin_hp':10,'mitigation':1},
         'k20': {'kurchin_hp':20,'mitigation':1},
         'k30': {'kurchin_hp':30,'mitigation':1},
         'k40': {'kurchin_hp':40,'mitigation':1},
         'k10b2': {'kurchin_hp':10,'mitigation':1,'butcher_attack':2},
         'k10mit2': {'kurchin_hp':10,'mitigation':2},
         'k15mit2': {'kurchin_hp':15,'mitigation':2},
         'k20mit2': {'kurchin_hp':20,'mitigation':2},
         'tumler': {'hp_multiplier':2,'always':True},
         'lemek': {'hp_multiplier':2,'lemek_attack':4}}
for rate,(melee,ranged) in RATES.items():
    for base,tuning in BASES.items():
        key = rate+'_'+base
        pairs.TUNING[key] = dict(tuning,melee_interval=melee,ranged_interval=ranged)
        pairs.audit.VARIANTS[key] = dict(armor=0,pursuit='current')


def specs(samples):
    result=[]
    def add(category,label,teams,variants,layout='spawn',mode='cadence',focus=None):
        for sample in range(samples):
            for seat in (0,1):
                for variant in variants:
                    result.append(dict(mode=mode,focus=focus or teams[0][-1],opponent=label,teams=teams,
                        variant=variant,sample=sample,seat=seat,layout=layout,category=category,cadence_metrics=True))
    plain=[r+'_plain' for r in RATES]
    basic_variants=plain+['m6r4_b2']
    for a,b in itertools.combinations_with_replacement(pairs.audit.recruitment.SUITS,2):
        for layout in ('spawn','contact'):
            add('basic_duel',a+'_vs_'+b,[[a],[b]],basic_variants,layout)
    armies={
        'balanced_mirror':[['Butcher','Penitent','Vulture','Wright','Butcher']]*2,
        'melee_mirror':[['Penitent','Penitent','Butcher','Butcher','Butcher']]*2,
        'melee_vs_vultures':[['Penitent','Penitent','Butcher','Butcher','Butcher'],['Vulture']*5],
        'balanced_vs_vultures':[['Butcher','Penitent','Vulture','Wright','Butcher'],['Vulture']*5],
        'wrights_vs_vultures':[['Penitent','Penitent','Wright','Wright','Butcher'],['Vulture']*5],
        'mixed_vs_screened':[['Penitent','Penitent','Butcher','Butcher','Vulture'],['Butcher','Penitent','Vulture','Vulture','Vulture']],
    }
    for label,teams in armies.items():
        add('basic_squad',label,teams,basic_variants+['m6r4_lead'])
    for name in pairs.audit.monsters.NAMES:
        for count in (1,2):
            add('monster',name+f'_vs_{count}Butcher',[[name],['Butcher']*count],basic_variants,focus=name)
        add('monster_squad',name+'_balanced',pairs.audit.formation(dict(mode='squad',focus=name,opponent='balanced')),['live_plain','m6r4_plain','m6r4_b2'],focus=name)
    for name,base in [('Tumler','tumler'),('Lemek','lemek')]:
        add('candidate',name+'_vs_2Butcher',[[name],['Butcher']*2],[r+'_'+base for r in RATES],focus=name)
    tanks=[r+'_k10' for r in RATES]+['m6r4_k20','m6r4_k30','m6r4_k40','m6r4_k10b2','live_plain','m6r4_plain']
    for layout in ('spawn','contact'):
        add('tank','three_butchers',[['Kurchin'],['Butcher']*3],tanks,layout,mode='tank',focus='Kurchin')
    for label,teams in [('vulture_escort',[['Vulture','Vulture','Kurchin'],['Butcher']*3]),('butcher_escort',[['Butcher','Butcher','Kurchin'],['Butcher']*3])]:
        add('escort',label,teams,tanks,mode='escort',focus='Kurchin')
    return result


def tank_followup_specs(samples):
    result=[]
    originals=[s for s in specs(samples) if s['category'] in ('tank','escort') and s['variant']=='m6r4_k10']
    for spec in originals:
        for variant in ('m6r4_k10mit2','m6r4_k15mit2','m6r4_k20mit2'):
            result.append(dict(spec,variant=variant))
    return result


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--output',required=True,type=Path)
    p.add_argument('--samples',type=int,default=32)
    p.add_argument('--workers',type=int,default=6)
    p.add_argument('--pilot',action='store_true')
    p.add_argument('--tank-followup',action='store_true')
    p.add_argument('--variants',nargs='+',choices=list(pairs.TUNING))
    args=p.parse_args()
    jobs=tank_followup_specs(args.samples) if args.tank_followup else specs(args.samples)
    if args.variants: jobs=[spec for spec in jobs if spec['variant'] in args.variants]
    if args.pilot: jobs=jobs[::max(1,len(jobs)//30)]
    args.output.mkdir(parents=True,exist_ok=False)
    manifest=dict(schema='U13_CADENCE_AUDIT_V1',trials=len(jobs),samples=args.samples,selected_variants=args.variants,tank_followup=args.tank_followup,rates=RATES,bases=BASES,
        live_base='8591fae49ce13b216f50554d92e9b1506589131e',
        revision=subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),
        source_sha256={f.name:hashlib.sha256(f.read_bytes()).hexdigest() for f in sorted(Path(__file__).parent.glob('*.py'))})
    (args.output/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
    started=time.monotonic()
    with (args.output/'battles.jsonl').open('w') as out,concurrent.futures.ProcessPoolExecutor(max_workers=args.workers) as pool:
        futures=[pool.submit(pairs.run,spec) for spec in jobs]
        for i,future in enumerate(concurrent.futures.as_completed(futures),1):
            out.write(json.dumps(future.result(),separators=(',',':'))+'\n');out.flush()
            if i%250==0 or i==len(jobs):print(f'{i}/{len(jobs)} trials in {time.monotonic()-started:.1f}s',flush=True)
    print('Completed',args.output,flush=True)


if __name__=='__main__':main()
