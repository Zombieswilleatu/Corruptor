"""Summarize Armor sweep evidence with matched Penitent squad controls."""
import argparse
from collections import Counter, defaultdict
import gzip
import hashlib
import json
from pathlib import Path
from statistics import mean, median


def summarize(rows):
    focal = [next(u for u in r['units'] if u['focal']) for r in rows]
    durations = [r['defense']['combat_survival_rounds'] for r in rows if r['defense']['combat_survival_rounds'] is not None]
    armed = sum(u['incoming'].get('armored_attempts', 0) for u in focal)
    evaded = sum(u['incoming'].get('deflections', 0) for u in focal)
    result = dict(trials=len(rows), outcomes=dict(Counter(r['outcome'] for r in rows)),
        focal_deaths=sum(u['deaths'] for u in focal), focal_survivors=sum(r['defense']['alive'] for r in rows),
        focal_exposed=sum(r['defense']['exposed'] for r in rows),
        mean_survival_rounds_when_dead=mean(durations) if durations else None,
        median_survival_rounds_when_dead=median(durations) if durations else None,
        deaths_before_one_combat_round=sum(x < 1 for x in durations),
        armored_attacks_faced=armed, deflected_attacks=evaded,
        observed_armored_deflection_rate=evaded/armed if armed else None,
        mean_ally_deaths=mean(r['defense']['ally_deaths'] for r in rows),
        ally_deaths=sum(r['defense']['ally_deaths'] for r in rows),
        ally_bodies=sum(r['defense']['ally_bodies'] for r in rows),
        mean_ally_hp_taken=mean(r['defense']['ally_hp_taken'] for r in rows),
        mean_ally_kills=mean(r['defense']['ally_kills'] for r in rows),
        focal_took_first_attack_share=mean(r['defense']['took_first_own_hit'] for r in rows),
        mean_rounds_to_fight_cutoff=mean(r['rounds'] for r in rows),
        mean_goals_by_original_side=[mean(sum(u['goals'] for u in r['units'] if u['group']==i) for r in rows) for i in (0,1)],
        unresolved_with_both_sides_active=sum(r['outcome']=='unresolved' and
            all(any(u['group']==g and u['survivors'] for u in r['units']) for g in (0,1)) for r in rows))
    for field in ('hp_damage', 'armor_damage', 'hp_taken', 'armor_absorbed', 'evaded_damage', 'kills', 'regeneration', 'goals'):
        result['mean_focal_'+field] = mean(u[field] for u in focal)
    return result


def build(directories, output, verification=None):
    rows=[]; manifests={}
    for directory in directories:
        manifest=json.loads((directory/'manifest.json').read_text())
        batch=[json.loads(line) for line in (directory/'battles.jsonl').open()]
        assert len(batch)==manifest['trials'], ('incomplete batch', directory, len(batch), manifest['trials'])
        rows.extend(batch); manifests[directory.name]=manifest
    assert len({json.dumps(r['spec'], sort_keys=True) for r in rows})==len(rows)
    groups=defaultdict(list); pools=defaultdict(list)
    for r in rows:
        s=r['spec']; groups[(s['category'],s['opponent'],s['variant'])].append(r)
        pools[(s['category'],s['variant'])].append(r)
    controls={(r['spec']['opponent'],r['spec']['sample'],r['spec']['seat']):r
              for r in rows if r['spec']['variant']=='penitent_control'}
    paired={}
    for (category,variant), rs in pools.items():
        if category!='squad' or variant=='penitent_control':continue
        comparisons=[(r,controls[(r['spec']['opponent'],r['spec']['sample'],r['spec']['seat'])]) for r in rs]
        paired[variant]=dict(trials=len(comparisons),
            mean_ally_deaths_avoided=mean(c['defense']['ally_deaths']-r['defense']['ally_deaths'] for r,c in comparisons),
            win_rate_change=mean(int(r['outcome']=='win')-int(c['outcome']=='win') for r,c in comparisons),
            candidate_only_wins=sum(r['outcome']=='win' and c['outcome']!='win' for r,c in comparisons),
            control_only_wins=sum(c['outcome']=='win' and r['outcome']!='win' for r,c in comparisons))
    def pack(mapping, names):return [dict(zip(names,key),**summarize(rs)) for key,rs in sorted(mapping.items())]
    result=dict(schema='U13_KURCHIN_ARMOR_REPORT_V1',trials=len(rows),unique_fixtures=len(rows),manifests=manifests,
        matchups=pack(groups,['category','opponent','variant']),pooled=pack(pools,['category','variant']),paired_squad_controls=paired,
        definitions=dict(survival='Time from first incoming hostile attack attempt, including misses, to death / 200. Conditional on death; survivors counted separately.',
            controls='Same seed, seat and nonfocal allies; replace the final Penitent with Kurchin. Body-matched, not an economy or summoning-cost comparison.',
            cutoff='First decisive phase or ten phases. Goal counts stop at that cutoff. No Lords, economy or reinforcements.',
            chance='Independent roll per direct incoming attack, only while Armor > 0 before that attack. Misses consume neither HP nor Armor. Landed overflow applies normally. Poison/banishment unchanged.'),
        verification=json.loads(verification.read_text()) if verification else None)
    output.parent.mkdir(parents=True,exist_ok=True)
    archive=output.with_suffix('.jsonl.gz')
    with archive.open('wb') as stream,gzip.GzipFile(filename='',mode='wb',fileobj=stream,mtime=0) as zipped:
        for r in sorted(rows,key=lambda x:json.dumps(x['spec'],sort_keys=True)):
            zipped.write((json.dumps(r,separators=(',',':'))+'\n').encode())
    result['raw_archive']=dict(path=archive.name,bytes=archive.stat().st_size,sha256=hashlib.sha256(archive.read_bytes()).hexdigest())
    output.write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps(dict(trials=len(rows),raw_archive=result['raw_archive'])))


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('directories',nargs='+',type=Path)
    parser.add_argument('--output',required=True,type=Path)
    parser.add_argument('--verification',type=Path)
    args=parser.parse_args();build(args.directories,args.output,args.verification)
