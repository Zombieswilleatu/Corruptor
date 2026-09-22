#!/usr/bin/env python3
"""Native lane-sandbox batches, resumable jobs, and observational contribution reports."""
import argparse
from collections import Counter, defaultdict
from concurrent.futures import ThreadPoolExecutor, wait, FIRST_COMPLETED
import csv
from datetime import datetime, timezone
import gzip
import hashlib
import html
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import threading
import time
import zipfile

ROOT = Path(__file__).resolve().parents[2]
SCHEMA = 'U13_LANE_BALANCE_REPORT_V1'
ORDINARY = {'Penitent', 'Butcher', 'Vulture', 'Wright'}
NOTES = '''These are native, continuous lane battles: normal random commitments on both sides, 15 protected staging slots, Auto releases, goal advance enabled, survivors and fortifications carried forward, and one reflected run per seed. No hand-picked formations or forced monster spawns. The cutoff is a measurement horizon, not a full-game victory condition. A goal lead is not a monster win rate.
HP damage is actual health removed after Armor, capped at remaining HP; overkill is reported separately. Armor damage is reconstructed from the engine's deterministic packet modifiers and recorded block/evasion/ward outcomes. An unaccounted packet is an audit error, not silently counted. Enemy and friendly damage are separate. Damage per deployed body includes damage dealt after death, such as poison. Seconds use the lane runner's 200 ticks = 15 seconds at 1x; activity is sampled after each tick.
Healing, repair, block/evasion counts, banishments and field exposure are separate forms of contribution. No arbitrary combined power score is calculated. Fyra's charmed-body damage and Dotra's exposure bonus are secondary credits already included in the actual attacker's damage: do not add them again. Pool exposure uses the nearest overlapping pool once per body/tick. Portal-zone time may overlap between portals and is exposure, not proven delay. Taunt-target time uses the production targeting helper; it is not a counterfactual damage-prevention estimate.
Wall and Tower are separate rows. Tower damage belongs to the Tower; repairs belong to the Wright doing them. To inspect the whole fortification package, read Wright, Wall and Tower together. Varn body counts count individual swarm members; summon groups group monster/name/birth-owner/birth-round. Rare monsters are not artificially made common. Fewer than 30 deployed bodies is flagged as low coverage, not proof of a balanced or weak unit.
Alive/staged at cutoff are censored observations, not failures. Edge-stationary time includes legitimate fighting, guarding and ranged holds; it is a diagnostic, not a confirmed bug. This harness measures lane combat, not Lord powers, guard slots, castle economics or whole-game doctrine. Reversed seats control orientation, but the two runs may diverge naturally. Counts are descriptive; presence in a winning lane does not establish causation.'''


def dump(path, data):
    path = Path(path)
    tmp = path.with_suffix(path.suffix + '.tmp')
    tmp.write_text(json.dumps(data, indent=2) + '\n', encoding='utf-8')
    os.replace(tmp, path)


def fingerprint():
    files = sorted(p for p in (ROOT/'Scripts/Sim').rglob('*') if p.suffix in {'.gd', '.py', '.sh'} and '__pycache__' not in p.parts)
    hashes = {p.relative_to(ROOT).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest() for p in files}
    digest = hashlib.sha256(json.dumps(hashes, sort_keys=True).encode()).hexdigest()
    return digest, hashes


def read_job(path, rounds):
    opener = gzip.open if path.suffix == '.gz' else open
    with opener(path, 'rt', encoding='utf-8') as stream:
        rows = [json.loads(line) for line in stream if line.strip()]
    if not rows or rows[0].get('kind') != 'meta' or rows[-1].get('kind') != 'finished':
        raise ValueError(f'Incomplete job: {path}')
    history = [r for r in rows if r['kind'] == 'round']
    if [r['round'] for r in history] != list(range(1, rounds + 1)) or rows[-1]['ticks'] != 200 * rounds:
        raise ValueError(f'Missing rounds or ticks: {path}')
    if any(u['counts'].get('unaccounted_packets', 0) for u in rows[-1]['units']):
        raise ValueError(f'Unaccounted damage packet; inspect {path}')
    return dict(meta=rows[0], result=rows[-1], history=history)


def aggregate(jobs, roster):
    buckets = {name: Counter() for name in roster + ['Wall', 'Tower']}
    units = []
    games = []
    for job in jobs:
        meta, result = job['meta'], job['result']
        summons = set()
        for u in result['units']:
            c = buckets.setdefault(u['name'], Counter())
            c.update(u['counts'])
            c['alive_at_cutoff'] += int(u['alive_at_cutoff'])
            c['staged_at_cutoff'] += int(u['staged_at_cutoff'])
            if u['kind'] == 'marcher' and u['name'] not in ORDINARY:
                summons.add((u['name'], u['birth_owner'], u['birth_round']))
            units.append(dict(seed=meta['seed'], swapped=meta['swapped'], **u))
        for name, _, _ in summons: buckets[name]['summon_groups'] += 1
        totals = result['totals']
        a, b = [t['reached_goal'] for t in totals]
        games.append(dict(seed=meta['seed'], swapped=meta['swapped'], rounds=result['rounds'], home_goals=a, away_goals=b,
                          goal_lead='home' if a > b else 'away' if b > a else 'tied',
                          home_spawned=totals[0]['spawned'], away_spawned=totals[1]['spawned'],
                          home_deaths=totals[0].get('defeated',0), away_deaths=totals[1].get('defeated',0),
                          home_banished=totals[0].get('banished',0), away_banished=totals[1].get('banished',0),
                          active_at_cutoff=job['history'][-1]['active'], staged_at_cutoff=job['history'][-1]['staged']))
    rows = []
    for name, c in buckets.items():
        bodies, deployed = c['bodies'], c['deployed']
        seconds = c['active_ticks'] * .075
        if name in ('Wall', 'Tower'): seconds = c['field_ticks'] * .075
        def per(value, denominator): return round(value / denominator, 4) if denominator else None
        rows.append(dict(name=name, **dict(c), spawned=bodies, deployed_bodies=deployed, active_seconds=round(seconds, 3),
                         hp_per_deployed=per(c['enemy_hp_damage'], deployed), armor_per_deployed=per(c['enemy_armor_damage'], deployed),
                         hp_per_active_second=per(c['enemy_hp_damage'], seconds),
                         goals_per_deployed=per(c['goal_crossings'], deployed),
                         coverage='structure' if name in ('Wall', 'Tower') else 'NOT SEEN' if not bodies else 'LOW' if deployed < 30 else 'sampled'))
    return rows, games, units


def csv_file(path, rows, columns):
    with open(path, 'w', newline='', encoding='utf-8-sig') as f:
        writer = csv.DictWriter(f, fieldnames=columns, extrasaction='ignore')
        writer.writeheader()
        writer.writerows(rows)


def table(rows, columns):
    def cell(value): return '—' if value is None else str(round(value, 3)) if isinstance(value, float) else str(value)
    head = '| ' + ' | '.join(label for _, label in columns) + ' |\n'
    head += '| ' + ' | '.join('---' for _ in columns) + ' |\n'
    return head + ''.join('| ' + ' | '.join(cell(r.get(k, 0)) for k, _ in columns) + ' |\n' for r in rows)


def reports(out, manifest, jobs):
    roster = jobs[0]['meta']['roster'] if jobs else ['Penitent', 'Butcher', 'Vulture', 'Wright', 'Lemek', 'Varn', 'Fyra', 'Kopita', 'Tumler', 'Kurchin', 'Muno', 'Dotra', 'Sooge', 'Sinodek']
    rows, games, units = aggregate(jobs, roster)
    expected = manifest['seeds'] * 2
    status = f'{len(jobs)}/{expected} runs complete · {manifest["rounds"]} rounds per run'
    main = [('name','Unit'),('spawned','Spawned'),('deployed_bodies','Deployed'),('enemy_hp_damage','Enemy HP'),('enemy_armor_damage','Enemy Armor'),('hp_per_deployed','HP/deployed'),('hp_per_active_second','HP/sec'),('enemy_kills','Kills'),('goal_crossings','Goals'),('enemy_hp_taken','HP taken'),('coverage','Coverage')]
    support = [('name','Unit'),('heal_hp','HP healed'),('repair_hp','HP repaired'),('blocked_hits','Blocks'),('evaded_hits','Evades'),('ward_absorbed_hits','Ward blocks'),('armor_absorbed','Armor used'),('charms','Charms'),('charmed_body_hp_damage','Charmed HP'),('exposure_bonus_hp','Exposure HP'),('enemy_banishments','Enemy banishes'),('ally_banishments','Ally banishes')]
    time_rows = []
    for r in rows:
        time_rows.append(dict(r, **{key.replace('_ticks', '_seconds'): round(r.get(key, 0)*.075, 3) for key in ['enemy_slow_ticks','ally_slow_ticks','taunt_target_ticks','enemy_portal_zone_ticks','ally_portal_zone_ticks','hidden_ticks','edge_stationary_ticks']}))
    control = [('name','Unit'),('enemy_slow_seconds','Enemy pool sec'),('ally_slow_seconds','Ally pool sec'),('taunt_target_seconds','Taunt target sec'),('enemy_portal_zone_seconds','Enemy portal-zone sec'),('ally_portal_zone_seconds','Ally portal-zone sec'),('edge_stationary_seconds','Edge stationary sec')]
    friendly = sum(r.get('friendly_hp_damage', 0) for r in rows)
    gate_leads = Counter(g['goal_lead'] for g in games)
    text = f'# Corruptor — random-wave lane balance\n\n{status}\n\n{manifest.get("lane_label", "Current checkout")}. Godot {manifest["godot_version"]}. Source fingerprint: `{manifest["fingerprint"][:16]}`.\n\n'
    if len(jobs) != expected: text += '**PARTIAL REPORT: unfinished runs are excluded; reflected pairs may be incomplete.**\n\n'
    text += f'Goal leads at cutoff: home {gate_leads["home"]}, away {gate_leads["away"]}, tied {gate_leads["tied"]}. Friendly HP damage: {friendly}.\n\n'
    by_name={r['name']:r for r in rows}
    w,tower,wall=(by_name.get(n,{}) for n in ['Wright','Tower','Wall'])
    text += f'Wright package: {w.get("enemy_hp_damage",0)} direct enemy HP damage + {tower.get("enemy_hp_damage",0)} tower HP damage; {w.get("repair_hp",0)} HP repaired; {wall.get("enemy_hp_taken",0)+tower.get("enemy_hp_taken",0)} enemy HP damage absorbed by structures. These are breakouts of the rows below.\n\n'
    for title, values, columns in [('Damage and activity', rows, main), ('Support and defense', rows, support), ('Control exposure and diagnostics', time_rows, control)]:
        text += f'## {title}\n\n' + table(values, columns) + '\n'
    text += '## How to read this\n\n' + '\n\n'.join(NOTES.splitlines()) + '\n'
    (out/'report.md').write_text(text, encoding='utf-8')
    columns = ['name'] + sorted(set().union(*(r.keys() for r in time_rows)) - {'name'})
    csv_file(out/'units-summary.csv', [{k:r.get(k,0) for k in columns} for r in time_rows], columns)
    csv_file(out/'games.csv', games, list(games[0]) if games else ['seed','swapped','rounds','home_goals','away_goals'])
    flat = [dict(seed=u['seed'], swapped=u['swapped'], id=u['id'], name=u['name'], birth_owner=u['birth_owner'], birth_round=u['birth_round'], alive_at_cutoff=u['alive_at_cutoff'], staged_at_cutoff=u['staged_at_cutoff'], builder_id=u['builder_id'], **u['counts']) for u in units]
    csv_file(out/'individual-units.csv', flat, sorted(set().union(*(r.keys() for r in flat))) if flat else ['id','name'])
    dump(out/'summary.json', dict(schema=SCHEMA, completed_runs=len(jobs), expected_runs=expected, units=time_rows, games=games, definitions=NOTES))
    sections = ''
    for title, values, cols in [('Damage and activity', rows, main), ('Support and defense', rows, support), ('Control exposure and diagnostics', time_rows, control)]:
        sections += '<h2>'+html.escape(title)+'</h2><div class="scroll"><table><thead><tr>'+''.join('<th>'+html.escape(label)+'</th>' for _, label in cols)+'</tr></thead><tbody>'
        for r in values:
            sections += '<tr>'+''.join('<td>'+html.escape(str(r.get(k,0)) if r.get(k,0) is not None else '—')+'</td>' for k,_ in cols)+'</tr>'
        sections += '</tbody></table></div>'
    page = '''<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width"><title>Corruptor lane balance</title><style>body{font:15px system-ui;margin:32px;background:#171719;color:#eee}h1,h2{color:#e7bd78}p{max-width:1100px;line-height:1.6}.scroll{overflow:auto}table{border-collapse:collapse;min-width:100%;margin-bottom:26px}td,th{text-align:right;padding:9px;border-bottom:1px solid #444;white-space:nowrap}td:first-child,th:first-child{text-align:left}th{background:#303034;cursor:pointer}tr:hover{background:#29292c}input{padding:10px;width:280px;background:#303034;color:#fff;border:1px solid #666}</style><h1>Corruptor · random-wave lane balance</h1>'''
    page += '<p>'+html.escape(status)+'. Click a column to sort. Totals and secondary support credits should not be added into one score.</p><input id="filter" placeholder="Filter units…">'+sections
    page += '<h2>Definitions and limits</h2>'+''.join('<p>'+html.escape(n)+'</p>' for n in NOTES.splitlines())
    page += '''<script>document.querySelectorAll('th').forEach(th=>th.onclick=()=>{const t=th.closest('table'),i=th.cellIndex,b=t.tBodies[0],asc=th.dataset.asc!=='true';th.dataset.asc=asc;Array.from(b.rows).sort((a,c)=>{const x=a.cells[i].textContent,y=c.cells[i].textContent;return (asc?1:-1)*(x!==''&&y!==''&&Number.isFinite(+x)&&Number.isFinite(+y)?+x-+y:x.localeCompare(y))}).forEach(r=>b.append(r))});document.querySelector('#filter').oninput=e=>document.querySelectorAll('tbody tr').forEach(r=>r.hidden=!r.cells[0].textContent.toLowerCase().includes(e.target.value.toLowerCase()));</script></html>'''
    (out/'report.html').write_text(page, encoding='utf-8')


def bundle(out):
    target = out/'balance-results.zip'
    tmp = out/'balance-results.zip.tmp'
    with zipfile.ZipFile(tmp, 'w', zipfile.ZIP_DEFLATED) as z:
        for pattern in ['report.*','*.csv','summary.json','manifest.json','completed/*.json','raw/*.jsonl.gz','logs/*.log']:
            for path in sorted(out.glob(pattern)): z.write(path, path.relative_to(out).as_posix())
    os.replace(tmp, target)


def run_job(godot, out, manifest, index, swapped, stop):
    stem = f'{index:03d}-{int(swapped)}'
    final = out/'completed'/(stem+'.json')
    if final.exists(): return json.loads(final.read_text(encoding='utf-8'))
    if fingerprint()[0] != manifest['fingerprint']: raise ValueError('Source changed during run; start a new output folder.')
    config = dict(seed=manifest['seed_prefix']+str(index), swapped=swapped, rounds=manifest['rounds'], capture=index < 2)
    config_path=out/'jobs'/(stem+'.json'); dump(config_path, config)
    raw=out/'raw'/(stem+'.jsonl'); log_path=out/'logs'/(stem+'.log')
    if stop.is_set(): raise RuntimeError('Stopped')
    started=time.monotonic()
    with log_path.open('w', encoding='utf-8') as log:
        proc=subprocess.Popen([str(godot),'--headless','--path',str(ROOT),'--script','res://Scripts/Sim/U13LaneBattleBatchRunner.gd','--',str(config_path),str(raw)], stdout=log, stderr=subprocess.STDOUT)
        try:
            while proc.poll() is None:
                if stop.wait(1): raise RuntimeError('Stopped; completed runs are saved.')
                if time.monotonic()-started > manifest['timeout']: raise TimeoutError(f'Job {stem} exceeded timeout; see {log_path}')
                recent=log_path.read_text(encoding='utf-8', errors='replace')[-12000:]
                if 'SCRIPT ERROR' in recent or 'ERROR:' in recent: raise RuntimeError(f'Godot error in {log_path}')
            if proc.returncode: raise RuntimeError(f'Godot exited {proc.returncode}: {log_path}')
        finally:
            if proc.poll() is None:
                proc.terminate()
                try: proc.wait(timeout=10)
                except subprocess.TimeoutExpired: proc.kill(); proc.wait()
    text=log_path.read_text(encoding='utf-8', errors='replace')
    if 'SCRIPT ERROR' in text or 'ERROR:' in text: raise RuntimeError(f'Godot error in {log_path}')
    job=read_job(raw,manifest['rounds'])
    if fingerprint()[0] != manifest['fingerprint']: raise ValueError('Source changed during job; results not accepted.')
    job['elapsed_seconds']=round(time.monotonic()-started,3)
    with raw.open('rb') as src, gzip.open(raw.with_suffix('.jsonl.gz'),'wb') as dst:
        import shutil
        shutil.copyfileobj(src,dst)
    raw.unlink()
    dump(final,job)
    return job


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--godot',required=True,type=Path)
    p.add_argument('--seeds',type=int);p.add_argument('--rounds',type=int);p.add_argument('--workers',type=int,default=2)
    p.add_argument('--seed-prefix');p.add_argument('--output',type=Path);p.add_argument('--resume',type=Path)
    p.add_argument('--quick',action='store_true',help='One seed, both seats, twelve rounds (smoke check).')
    p.add_argument('--timeout',type=int,default=3600,help='Maximum seconds per native run.')
    args=p.parse_args()
    if args.workers<1 or args.timeout<1:p.error('workers and timeout must be positive')
    godot=args.godot.expanduser().resolve()
    version=subprocess.check_output([str(godot),'--version'],text=True,timeout=30).strip()
    if not version.startswith('4.'):p.error('Godot 4 is required')
    digest, hashes=fingerprint()
    if args.resume:
        out=args.resume.expanduser().resolve();manifest=json.loads((out/'manifest.json').read_text(encoding='utf-8'))
        if manifest['schema']!=SCHEMA or manifest['fingerprint']!=digest or manifest['godot_version']!=version:
            p.error('Resume requires the same source and Godot version. Use a new output folder for changed code.')
        for key in ['seeds','rounds','seed_prefix']:
            if getattr(args,key) is not None and getattr(args,key)!=manifest[key]:p.error('Resume settings must match the manifest')
        if args.quick or args.output:p.error('Do not combine --resume with --quick or --output')
        manifest['timeout']=args.timeout
    else:
        seeds=args.seeds if args.seeds is not None else (1 if args.quick else 32)
        rounds=args.rounds if args.rounds is not None else (12 if args.quick else 40)
        if seeds<1 or rounds<1:p.error('seeds and rounds must be positive')
        out=(args.output or Path.home()/'Downloads/Corruptor/Balance'/('lane-balance-'+datetime.now().strftime('%Y-%m-%d_%H-%M-%S'))).expanduser().resolve()
        if out.exists() and any(out.iterdir()):p.error('Output folder is not empty. Use --resume to continue it.')
        out.mkdir(parents=True,exist_ok=True)
        lane_source=(ROOT/'Prototype/U13/U13LaneSandbox.gd').read_text(encoding='utf-8')
        lane_match=re.search(r'monster tuning V[0-9.]+',lane_source)
        manifest=dict(lane_label=lane_match.group(0) if lane_match else 'Current checkout',schema=SCHEMA,seeds=seeds,rounds=rounds,seed_prefix=args.seed_prefix or 'lane-contribution:',fingerprint=digest,source_hashes=hashes,godot_version=version,timeout=args.timeout,created_utc=datetime.now(timezone.utc).isoformat(),root=str(ROOT),python=sys.version,definitions=NOTES)
        dump(out/'manifest.json',manifest)
    for name in ['jobs','raw','logs','completed']:(out/name).mkdir(exist_ok=True)
    jobs={}
    for index in range(manifest['seeds']):
        for swapped in (False,True):
            path=out/'completed'/f'{index:03d}-{int(swapped)}.json'
            if path.exists():jobs[(index,swapped)]=json.loads(path.read_text(encoding='utf-8'))
    reports(out,manifest,list(jobs.values()))
    print(f'{manifest["seeds"]*2} native lane runs × {manifest["rounds"]} rounds; {args.workers} workers.\nResults: {out}\nOpen report.html while running; refresh after a run finishes. Ctrl+C stops safely; resume with --resume "{out}".',flush=True)
    stop=threading.Event();started=time.monotonic();error=None
    pool=ThreadPoolExecutor(max_workers=args.workers)
    pending={pool.submit(run_job,godot,out,manifest,i,s,stop):(i,s) for i in range(manifest['seeds']) for s in (False,True) if (i,s) not in jobs}
    try:
        while pending:
            done,_=wait(pending,timeout=10,return_when=FIRST_COMPLETED)
            for future in done:
                key=pending.pop(future);jobs[key]=future.result()
                reports(out,manifest,[jobs[k] for k in sorted(jobs)])
                t=jobs[key]['result']['totals']
                print(f'DONE {len(jobs)}/{manifest["seeds"]*2}: seed {key[0]}, {"swapped" if key[1] else "normal"}, goals {t[0]["reached_goal"]}:{t[1]["reached_goal"]}',flush=True)
            if not done:
                active=[]
                for future,(i,s) in pending.items():
                    if not future.running():continue
                    path=out/'logs'/f'{i:03d}-{int(s)}.log'
                    lines=path.read_text(encoding='utf-8',errors='replace').splitlines() if path.exists() else []
                    progress=next((line for line in reversed(lines) if line.startswith('ROUND ')),'starting')
                    active.append(f'{i}/{"swap" if s else "normal"}: {progress}')
                print(f'{len(jobs)}/{manifest["seeds"]*2} complete · {time.monotonic()-started:.0f}s · '+ ' | '.join(active),flush=True)
    except (KeyboardInterrupt,Exception) as exc:
        error=exc;stop.set()
        for future in pending:future.cancel()
    finally:
        stop.set();pool.shutdown(wait=True,cancel_futures=True)
        # Include jobs that finished while interruption was being processed.
        jobs={}
        for path in sorted((out/'completed').glob('*.json')):jobs[path.stem]=json.loads(path.read_text(encoding='utf-8'))
        reports(out,manifest,list(jobs.values()));bundle(out)
    print(f'Report: {out/"report.html"}\nSend back: {out/"balance-results.zip"}',flush=True)
    if error:
        print(f'Run stopped: {error or "keyboard interrupt"}. Completed runs are saved; unfinished runs restart on resume.',file=sys.stderr)
        return 130 if isinstance(error,KeyboardInterrupt) else 1
    return 0

if __name__=='__main__':sys.exit(main())
