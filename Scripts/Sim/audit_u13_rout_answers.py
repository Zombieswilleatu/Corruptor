#!/usr/bin/env python3
"""Select and replay plan-aware Rout contrasts on frozen current-engine games.

Selection never consults the game outcome. Public-view screening uses a permissive
admission callback; the selected positions are then reconstructed and admitted by
the real engine. Interventions change Rout alone and resume frozen V12 thereafter.
"""
import argparse
import hashlib
import importlib
import importlib.util
import json
from pathlib import Path
import sys

from audit_u13_rout_timing import continue_one, run_pool
from summarize_u13_rout_timing import run as summarize
from u13_doctrine.comparison import freeze_baseline
from u13_doctrine.diagnostics import fingerprint
from u13_doctrine.facts import Facts, LANES
from u13_doctrine.observation import observe, Preview
from u13_doctrine.survey import atomic_json, read_record
from u13_pysim.power_match import PowerMatch
from u13_pysim.verify import source_identity


def candidate_module(directory):
    name = 'u13_frozen_rout_answer_candidate'
    spec = importlib.util.spec_from_file_location(name, directory/'__init__.py',
        submodule_search_locations=[str(directory)])
    module = importlib.util.module_from_spec(spec); sys.modules[name] = module
    spec.loader.exec_module(module)
    return importlib.import_module(name+'.common')


def without_rout(plan):
    return dict(order=plan['order'], powers=[{k:v for k,v in s.items()
        if k not in ('queue_index', 'declaration_id')} for s in plan['powers'] if s['power_id'] != 'Rout'])


def assess(root, directory, revision):
    manifest = json.loads((directory/'manifest.json').read_text())
    if source_identity(root)[1] != manifest['engine_source_sha256']:
        raise ValueError('Source games use another engine')
    frozen = freeze_baseline(root, revision, directory/'answer-candidate')
    candidate = candidate_module(directory/'answer-candidate')
    prefix = candidate.__package__
    deimos = importlib.import_module(prefix+'.lords.deimos')
    answers = importlib.import_module(prefix+'.rout_answers')
    coordination = importlib.import_module(prefix+'.coordination')
    policy = candidate.CommonSmartCore()
    rows, sources = [], {}
    for spec in manifest['specs']:
        record = read_record(directory/'games'/(spec['name']+'.json.gz'), manifest, spec)
        if record['status'] != 'complete': raise ValueError('Incomplete source game')
        sources[spec['name']] = record
        for item in record['trace']:
            view, old = item['view'], item['decision']; f = Facts(view)
            if f.kind != 'Deimos' or not f.available('Rout')[0]: continue
            new = policy.decide(view, lambda plan: dict(action='legal'))
            old_rout = next((s for s in old['plan']['powers'] if s['power_id'] == 'Rout'), None)
            new_rout = next((s for s in new['plan']['powers'] if s['power_id'] == 'Rout'), None)
            values = {lane:deimos.rout_value(f, lane) for lane in LANES}
            lane = (old_rout or new_rout or dict(target=dict(lane=max(LANES, key=lambda k: values[k]['score']))))['target']['lane']
            answer = answers.evaluate(f, lane, coordination.context(f, new['plan']), values[lane])
            group = ''
            same = without_rout(old['plan']) == without_rout(new['plan'])
            if old_rout and not new_rout and same:
                group = 'conserve_existing_answer'
            elif old_rout and new_rout and old_rout['target'] == new_rout['target'] and same and view['round'] >= 4 and answer['threat_bodies'] >= 4 and answer['own_force'] < answer['enemy_force']:
                group = 'delay_unanswered_wave'
            elif not old_rout and not new_rout and same and view['round'] == 2 and any(v['distant'] for v in values.values()):
                group = 'preserve_early_hold'
                lane = max(LANES, key=lambda k: len(values[k]['distant']))
            rows.append(dict(source=spec['name'], seat=f.pid, round=view['round'], lane=lane,
                name=f"{spec['name']}__answer_r{view['round']}_p{f.pid}", group=group,
                original='fired' if old_rout else 'held', candidate_cast=bool(new_rout),
                same_non_rout_plan=same, public_values=values, answer=answer,
                view_sha256=fingerprint(view), plan_sha256=fingerprint(old['plan']),
                candidate_plan_sha256=fingerprint(new['plan'])))
    selected = []
    # Two examples of each contrast; deterministic source order, earliest first,
    # with distinct source/seat per group. No winner is read during selection.
    for group in ('conserve_existing_answer', 'delay_unanswered_wave', 'preserve_early_hold'):
        seen = set()
        for row in sorted((r for r in rows if r['group'] == group),
                          key=lambda r:(r['round'], r['source'], r['seat'])):
            key = row['source'], row['seat']
            if key in seen: continue
            seen.add(key); selected.append(row)
            if len(seen) == 2: break
    for row in selected:
        source = sources[row['source']]; game = PowerMatch(source['spec']['setup'])
        for operation in source['operations']:
            if operation['kind'] == 'submit' and game.clock.round == row['round']:
                view = observe(game, row['seat'])
                if fingerprint(view) != row['view_sha256']: raise ValueError('View did not replay')
                decision = policy.decide(view, Preview(game, row['seat']))
                if decision['rejected_previews'] or fingerprint(decision['plan']) != row['candidate_plan_sha256']:
                    raise ValueError('Real admission changed candidate')
                row['candidate_admitted'] = True
                break
            result = game.apply(operation)
            if result['action'] == 'invalid': raise ValueError(result)
        else: raise ValueError('Missing selected position')
    report = dict(parent_manifest_sha256=fingerprint(manifest), candidate=frozen,
        selected=selected, assessments=rows,
        runner_sha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
        selection='Earliest two per group with distinct source/seat; groups determined by public decisions, force estimates and unchanged non-Rout choices, never outcomes.',
        scope='Only selected positions have engine admission checked; remaining assessments are public-view screening, not game results.')
    path = directory/'positions-answer.json'
    if path.exists() and json.loads(path.read_text()) != report:
        raise ValueError('Different answer audit already exists')
    atomic_json(path, report)
    print(f'ASSESSED {len(rows)} ready decisions; {len(selected)} selected and legally admitted', flush=True)
    return report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('phase', choices=('assess', 'replay', 'summary'))
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--candidate', default='HEAD')
    parser.add_argument('--workers', type=int, default=4)
    args = parser.parse_args()
    if args.workers < 1: parser.error('Workers must be positive')
    root = Path(__file__).resolve().parents[2]
    directory = args.output.resolve()
    manifest = json.loads((directory/'manifest.json').read_text())
    if source_identity(root)[1] != manifest['engine_source_sha256']:
        raise ValueError('Different engine')
    if args.phase == 'assess':
        assess(root, directory, args.candidate)
    elif args.phase == 'replay':
        selection = json.loads((directory/'positions-answer.json').read_text())
        if selection['parent_manifest_sha256'] != fingerprint(manifest):
            raise ValueError('Different source manifest')
        specs = [dict(s, cast=cast) for s in selection['selected'] for cast in (False, True)]
        results = run_pool(continue_one, specs, manifest, directory, args.workers)
        atomic_json(directory/'replay-summary-answer.json', dict(results=results))
    else:
        summarize(directory, selection_name='positions-answer.json', output_name='analysis-answer.json')


if __name__ == '__main__': main()
