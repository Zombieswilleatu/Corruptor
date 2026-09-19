"""Summarize deaths and contact-relative duration without hiding survivors."""
import argparse
import gzip
import hashlib
import json
import statistics
from collections import Counter,defaultdict
from pathlib import Path


def summary(rows):
    outcomes=Counter(r['outcome'] for r in rows)
    bodies=sum(len(r['units']) for r in rows)
    deaths=sum(u['deaths'] for r in rows for u in r['units'])
    early=0; fights_early=0; first_delays=[]; engaged=0; engaged_early=0; active_unresolved=0
    for r in rows:
        t=r['combat_timing']; starts=t['first_engaged']; engaged+=len(starts)
        first=min(starts.values(),default=None)
        times=[d['tick']-first for d in t['deaths'] if first is not None and d['tick']>=first]
        early+=sum(x<200 for x in times)
        if times:
            first_delays.append(min(times)/200)
            fights_early+=int(min(times)<200)
        engaged_early+=sum(d['id'] in starts and 0<=d['tick']-starts[d['id']]<200 for d in t['deaths'])
        active_unresolved+=int(r['outcome']=='unresolved' and all(any(u['group']==g and u['survivors'] for u in r['units']) for g in (0,1)))
    totals=Counter()
    for r in rows:
        for u in r['units']:
            for key in ('hp_damage','hp_taken','armor_absorbed','regeneration','healing','kills','goals','attacks'):
                totals[key]+=u[key]
    focal=[u for r in rows for u in r['units'] if u['focal']]
    result=dict(trials=len(rows),outcomes=dict(outcomes),starting_bodies=bodies,total_deaths=deaths,
        death_share=deaths/bodies,deaths_in_first_combat_round=early,first_combat_round_death_share=early/bodies,
        fights_with_death_in_first_combat_round=fights_early,fights_without_deaths=len(rows)-len(first_delays),
        engaged_bodies=engaged,engaged_bodies_dying_within_one_round=engaged_early,
        engaged_death_share_within_one_round=engaged_early/engaged if engaged else None,
        median_rounds_to_first_death=statistics.median(first_delays) if first_delays else None,
        unresolved_with_both_original_sides_active=active_unresolved,
        mean_per_trial={k:v/len(rows) for k,v in totals.items()},
        focal_mean_hp_damage=sum(u['hp_damage'] for u in focal)/len(rows),
        focal_mean_kills=sum(u['kills'] for u in focal)/len(rows),
        focal_mean_enemy_banishments=sum(u['enemy_banishments'] for u in focal)/len(rows),
        focal_mean_friendly_banishments=sum(u['friendly_banishments'] for u in focal)/len(rows),
        focal_mean_healing=sum(u['healing'] for u in focal)/len(rows))
    if rows[0]['spec']['category'] in ('tank','escort'):
        durations=[r['tank']['ticks_to_death']/200 for r in rows if r['tank']['ticks_to_death'] is not None]
        result['tank']=dict(alive=sum(r['tank']['alive'] for r in rows),
            mean_survival_rounds_when_dead=statistics.mean(durations) if durations else None,
            median_survival_rounds_when_dead=statistics.median(durations) if durations else None,
            deaths_before_one_round=sum(d<1 for d in durations),
            ally_deaths=sum(r['tank']['ally_deaths'] for r in rows),
            mean_prevented=sum(r['tank'].get('damage_prevented',0) for r in rows)/len(rows),
            mean_armor_absorbed=sum(u['armor_absorbed'] for u in focal)/len(rows),
            mean_hp_taken=sum(u['hp_taken'] for u in focal)/len(rows))
    return result


def build(directories,output,verification):
    rows=[];manifests={}
    for directory in directories:
        batch=[json.loads(line) for line in (directory/'battles.jsonl').open()]
        manifest=json.loads((directory/'manifest.json').read_text())
        assert len(batch)==manifest['trials'],('incomplete batch',len(batch),manifest['trials'])
        rows.extend(batch);manifests[directory.name]=manifest
    groups=defaultdict(list);pooled=defaultdict(list)
    for row in rows:
        s=row['spec'];groups[(s['category'],s['opponent'],s['layout'],s['variant'])].append(row)
        pooled[(s['category'],s['layout'],s['variant'])].append(row)
    def pack(mapping,labels):return [dict(zip(labels,key),**summary(group)) for key,group in sorted(mapping.items())]
    archive=output.with_suffix('.jsonl.gz')
    output.parent.mkdir(parents=True,exist_ok=True)
    with archive.open('wb') as raw,gzip.GzipFile(filename='',mode='wb',fileobj=raw,mtime=0) as zipped:
        for row in sorted(rows,key=lambda r:json.dumps(r['spec'],sort_keys=True)):
            zipped.write((json.dumps(row,separators=(',',':'))+'\n').encode())
    result=dict(schema='U13_CADENCE_REPORT_V1',manifests=manifests,trials=len(rows),
        unique_fixtures=len({json.dumps(r['spec'],sort_keys=True) for r in rows}),
        definitions=dict(first_combat_round='200 ticks after the first hostile attack involving an original unit. Walking before contact is excluded.',
            first_combat_round_death_share='All deaths in that window divided by every starting body, including winners and untouched backline survivors.',
            engaged_death_share='Dead within 200 ticks of that individual first attacking or being attacked, divided by all engaged bodies, including survivors.',
            tank_duration='Death tick minus first landed hostile hit, divided by 200; conditional on death. Survivors are counted separately.',
            cutoff='First decisive phase or ten phases; goal counts stop there. Escapes can leave unresolved outcomes without an ongoing fight.'),
        pooled=pack(pooled,['category','layout','variant']),
        matchups=pack(groups,['category','opponent','layout','variant']),
        verification=json.loads(verification.read_text()),
        final_source_sha256={f.name:hashlib.sha256(f.read_bytes()).hexdigest() for f in sorted(Path(__file__).parent.glob('*.py'))},
        raw_archive=dict(path=archive.name,bytes=archive.stat().st_size,sha256=hashlib.sha256(archive.read_bytes()).hexdigest()))
    output.write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps({k:result[k] for k in ('trials','unique_fixtures','raw_archive')}))


if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('directories',nargs='+',type=Path);p.add_argument('--output',required=True,type=Path);p.add_argument('--verification',required=True,type=Path)
    a=p.parse_args();build(a.directories,a.output,a.verification)
