#!/usr/bin/env python3
"""Offline matched Wright ablations; never changes production tuning or source files."""
import argparse
from collections import Counter
from concurrent.futures import ProcessPoolExecutor
from pathlib import Path
import time
import audit_u13_monsters as audit
from u13_pysim import field_fortifications as fort, codec
from u13_pysim.copying import copy_data

ORIGINAL_STEP = fort.step
ORIGINAL_METRICS = audit.Metrics
ORIGINAL_REPAIR_TARGET = fort.repair_target
ORIGINAL_REPAIR_NEARBY = fort.repair_nearby
VARIANT = 'full'
SUBJECT_OWNER = 0


def ablated_step(world, entities, number, tick, fleeing=()):
    if VARIANT == 'no_build':
        return []
    events = ORIGINAL_STEP(world, entities, number, tick, fleeing)
    if VARIANT == 'silent_tower':
        for row in fort.rows(world):
            if row['owner'] == SUBJECT_OWNER and row['attributes']['structure'] == 'Tower':
                row['attributes']['ranged_next_tick'] = 1000000
    return events


class WrightMetrics(ORIGINAL_METRICS):
    def events(self, events):
        super().events(events)
        counts = self.metrics['WrightAudit']
        for event in events:
            kind, d = event['type'], event['data']
            if kind in ('WRIGHT_STRUCTURE_BUILT', 'WRIGHT_STRUCTURE_REPAIRED', 'WRIGHT_STRUCTURE_DESTROYED'):
                row = d['structure']
                if row['owner'] != SUBJECT_OWNER:
                    continue
                label = row['attributes']['structure'].lower()
                if kind == 'WRIGHT_STRUCTURE_BUILT':
                    counts[label+'_built'] += 1
                elif kind == 'WRIGHT_STRUCTURE_REPAIRED':
                    counts[label+'_repair_hp'] += d['hp_after']-d['hp_before']
                    counts['repair_hp'] += d['hp_after']-d['hp_before']
                else:
                    counts[label+'_destroyed'] += 1
            elif kind in ('MARCHER_MELEE_ATTACK','MARCHER_RANGED_ATTACK','MONSTER_ATTACK'):
                source, target = d['attacker'], d['target']
                if source['owner'] == SUBJECT_OWNER and source['kind'] == 'fortification':
                    counts['tower_shots'] += 1
                    counts['tower_recorded_hp_damage'] += d.get('damage_dealt',0)
                if target['owner'] == SUBJECT_OWNER and target['kind'] == 'fortification':
                    label = target['attributes']['structure'].lower()
                    counts[label+'_attacks_taken'] += 1
                    counts[label+'_recorded_hp_damage_taken'] += d.get('damage_dealt',0)
            elif kind == 'MARCHER_DEFEATED' and d.get('attacker',{}).get('kind') == 'fortification' and d['attacker']['owner'] == SUBJECT_OWNER:
                counts['tower_kills'] += 1


def trial(task):
    global VARIANT, SUBJECT_OWNER
    original, VARIANT = task
    record = copy_data(original)
    SUBJECT_OWNER = int(record['reflected'])
    record['capture'] = VARIANT == 'full'
    if VARIANT == 'no_wrights':
        record['world']['entities']['entities'] = [r for r in record['world']['entities']['entities']
            if not (r['owner'] == SUBJECT_OWNER and r['attributes'].get('suit') == 'Wright')]
    fort.step = ablated_step
    fort.repair_nearby = (lambda *args: []) if VARIANT == "no_repairs" else ORIGINAL_REPAIR_NEARBY
    fort.repair_target = (lambda *args: {}) if VARIANT == 'no_takeover' else ORIGINAL_REPAIR_TARGET
    audit.Metrics = WrightMetrics
    result = audit.controlled((record,16))
    result['ablation'] = VARIANT
    return result


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--initials',type=Path,required=True)
    parser.add_argument('--output',type=Path,required=True)
    parser.add_argument('--samples',type=Path,required=True)
    parser.add_argument('--variants',nargs='+',default=['full','no_wrights','no_build','no_repairs','silent_tower'])
    parser.add_argument('--workers',type=int,default=4)
    args=parser.parse_args()
    records=list(audit.read_rows(args.initials))
    tasks=[(r,v) for r in records for v in args.variants
           if not r['reflected'] or (v=='full' and r['seed_index']<2)]
    results=[]; start=time.monotonic()
    with args.samples.open('w') as samples, ProcessPoolExecutor(max_workers=args.workers) as pool:
        for result in pool.map(trial,tasks,chunksize=5):
            for sample in result.pop('parity'):
                samples.write(codec.dumps(sample)+'\n')
            results.append(result)
            if len(results)%30==0:print('WRIGHT',len(results),'/',len(tasks),f'{time.monotonic()-start:.1f}s',flush=True)
    summary={}
    for case in sorted({r['case'] for r in results}):
        summary[case]={}
        for variant in args.variants:
            rr=[r for r in results if r['case']==case and r['ablation']==variant and not r['reflected']]
            counts=Counter()
            for r in rr:counts.update(r['metrics'].get('WrightAudit',{}))
            summary[case][variant]=dict(fights=len(rr),wins=sum(r['winner']==0 for r in rr),draws=sum(r['winner'] is None for r in rr),caps=sum(r['round_cap'] for r in rr),rounds=sum(r['rounds'] for r in rr),goals=sum(r['goals'][0] for r in rr),mechanics=dict(counts))
    audit.dump(args.output,dict(rules_version=audit.monsters.VERSION,summary=summary,battles=results,
        note='Eight seeds per formation. Normal-seat ablations; first two seeds reflected for production full only. No-Wright removal preserves all other IDs/positions; no-build keeps Wright bodies but disables construction/guarding; no-repairs preserves all other mechanics; silent-tower preserves tower body but disables shots. These counterfactuals are analysis-only.'))
    print('Saved',len(results),'fights',flush=True)


if __name__=='__main__':main()
