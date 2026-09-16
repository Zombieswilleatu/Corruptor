"""Exact nine-Lord games and directed power boundaries; no reference-state feedback."""
import hashlib
import json
from collections import Counter
from . import power_inputs, power_components, codec
from .power_match import PowerMatch, VERSION, LORDS
from .power_rules import RULES
from .verify import same, shape
from .verify_full_match import verify as full_verify, verify_rejections as full_rejections

SCHEMA='U13_PYSIM_NINE_LORD_STREAM_V1'


def options():
    manifest=json.loads(power_inputs.PATH.read_text(encoding='utf-8'))
    return dict(input_manifest=manifest,inputs_hash=hashlib.sha256(power_inputs.PATH.read_bytes().replace(b'\r\n',b'\n')).hexdigest(),
                stream_schema=SCHEMA,match_factory=PowerMatch,scope_lords=LORDS,mirror_version=VERSION,
                scope_description='existing nine Lords, 23 declared powers, paid Rites and Resummon; explicit coverage decisions, not tuned doctrine or balance evidence')


def components(take,manifest):
    totals=Counter();resolved=Counter();phase_counts=Counter();phases=0;rows=ops=rejected=0;cases=[]
    same(list(RULES),[c['name'].removeprefix('power_') for c in manifest['components'] if c['name'].startswith('power_')], 'power_component_manifest')
    same(power_components.PHASE_NAMES+power_components.BOUNDARY_NAMES,[c['name'] for c in manifest['components'] if not c['name'].startswith('power_')], 'phase_component_manifest')
    for spec in manifest['components']:
        row=take('component_opening');g=PowerMatch(spec['setup']);prefix=0;history=[];counts=Counter()
        same(dict(kind='component_opening',name=spec['name'],setup=spec['setup'],state=g.snapshot()),row,spec['name']+'.opening')
        for i,entry in enumerate(spec['operations']):
            loc=f"{spec['name']}.operations[{i}].round={g.clock.round}.hook={g.clock.hook}"
            row=take('component_transition');before=g.snapshot();result=power_components.apply(g,entry['operation']);state=g.snapshot();events=state.pop('events')
            same(entry['rejected'],result['action']=='invalid',loc+'.expected_rejection')
            if entry['rejected']:same(before,g.snapshot(),loc+'.atomic_rejection');rejected+=1
            same(history,events['rows'][:prefix],loc+'.immutable_history')
            new=events['rows'][prefix:];history=events['rows']
            expected=dict(kind='component_transition',name=spec['name'],index=i,operation=entry['operation'],result=result,state=state,event_prefix=prefix,events=dict(events,rows=new))
            same(expected,row,loc);prefix=len(history);ops+=1
            if entry['operation']['kind']=='phase_probe':
                phases+=1
                phase_counts.update(r['event']['type'] for r in result['events'])
                same(200,sum(r['event']['type']=='MARCHING_TICK' for r in result['events']),loc+'.tick_count')
            for event in new:
                fact=event['event'];counts[fact['type']]+=1
                if fact['type']=='POWER_RESOLVED':resolved[fact['data']['power_id']]+=1
        cases.append(dict(name=spec['name'],operations=len(spec['operations']),final_state_sha256=hashlib.sha256(codec.dumps(g.snapshot()).encode()).hexdigest(),event_coverage=dict(sorted(counts.items()))))
        rows+=prefix;totals.update(counts)
    same(set(RULES),set(resolved),'all_23_powers_resolved')
    for kind in ('WISHMASTER_LAMP_CLAIMED','WISHMASTER_WRIGHT_CREATED','WISHMASTER_VULTURE_BYPASS',
                 'WISHMASTER_REJECTED','PSYCHIC_INTERLOCK','MARCHER_DEVOURED','KRONI_FLEE_STARTED','GRAVITY_ORB_CONSUMED'):
        same(True,phase_counts[kind]>0,'phase_coverage.'+kind)
    return dict(power_components_matched=len(cases),power_component_operations_matched=ops,
                power_component_rejections_matched=rejected,power_components=cases,
                directed_tick_phases_matched=phases,directed_tick_frames_compared=phase_counts["MARCHING_TICK"],
                directed_phase_event_coverage=dict(sorted(phase_counts.items())),
                declared_power_coverage=dict(sorted(resolved.items())),power_component_event_coverage=dict(sorted(totals.items())))


def verify(path,revision,source_hash,diagnostic=False,record_filter=None):
    args=options();manifest=args['input_manifest']
    args['trailer']=lambda take:components(take,manifest)
    return full_verify(path,revision,source_hash,diagnostic,record_filter,**args)


def verify_rejections(path,revision,source_hash,diagnostic=False):
    args=options();manifest=args['input_manifest'];args['trailer']=lambda take:components(take,manifest)
    count=full_rejections(path,revision,source_hash,diagnostic,**args)
    # Exercise newly populated registries and power records, not only outcomes.
    probes=[
        ('pending',lambda r:r.get('kind')=='transition' and r['state']['pending']['pending'],lambda r:r['state']['pending']['pending'][0].update(fire_round=999)),
        ('cooldowns',lambda r:r.get('kind')=='transition' and r['state']['cooldowns']['locks'],lambda r:r['state']['cooldowns']['locks'][0].update(ready_round=999)),
        ('persistent',lambda r:r.get('kind')=='transition' and r['state']['persistent']['active'],lambda r:r['state']['persistent']['active'][0].update(stage_index=99)),
    ]
    for marker,predicate,mutate in probes:
        changed=False
        def corrupt(row):
            nonlocal changed
            if not changed and predicate(row):mutate(row);changed=True
            return row
        try:verify(path,revision,source_hash,diagnostic,corrupt)
        except ValueError as err:
            if not changed or marker not in str(err):raise ValueError(f'Wrong power corruption diagnostic {marker}: {err}') from err
        else:raise ValueError('Corrupted power evidence accepted: '+marker)
    return count+len(probes)
