"""Compare focused native Breath records with independently executed Python."""
import hashlib
import json
from pathlib import Path
from . import codec, power_components, breath_cases
from .power_match import PowerMatch
from .verify import same, source_identity


def export_inputs(path):
    Path(path).write_text(json.dumps(breath_cases.generate(),indent=2,sort_keys=True)+'\n',encoding='utf-8')


def verify(path,inputs_path,root):
    path,inputs_path=Path(path),Path(inputs_path)
    manifest=json.loads(inputs_path.read_text(encoding='utf-8'))
    same(breath_cases.generate(),manifest,'current_directed_inputs')
    revision,source_hash=source_identity(root)
    count=ops=0;states=[]
    with path.open(encoding='utf-8') as stream:
        def take():
            nonlocal count
            line=stream.readline()
            if not line:raise ValueError('Truncated Breath evidence')
            count+=1
            return codec.loads(line)
        header=take()
        same('U13_BREATH_PULSE_EXACT_V1',header['schema'],'schema')
        same(revision,header['source_revision'],'source_revision')
        same(source_hash,header['source_sha256'],'source_sha256')
        same(hashlib.sha256(inputs_path.read_bytes().replace(b'\r\n',b'\n')).hexdigest(),header['inputs_sha256'],'inputs_sha256')
        for spec in manifest['cases']:
            g=PowerMatch(spec['setup']);prefix=0
            same(dict(kind='component_opening',name=spec['name'],setup=spec['setup'],state=g.snapshot()),take(),spec['name']+'.opening')
            for i,entry in enumerate(spec['operations']):
                result=power_components.apply(g,entry['operation']);state=g.snapshot();events=state.pop('events')
                expected=dict(kind='component_transition',name=spec['name'],index=i,operation=entry['operation'],result=result,state=state,event_prefix=prefix,events=dict(events,rows=events['rows'][prefix:]))
                same(expected,take(),spec['name']+'.'+str(i));prefix=len(events['rows']);ops+=1
            states.append(dict(name=spec['name'],operations=len(spec['operations']),final_state_sha256=hashlib.sha256(codec.dumps(g.snapshot()).encode()).hexdigest()))
        if stream.read().strip():raise ValueError('Unexpected extra Breath evidence')
    return dict(cases=len(states),operations=ops,records=count,native_runtime=header['runtime'],native_platform=header['platform'],source_revision=revision,source_sha256=source_hash,inputs_sha256=header['inputs_sha256'],states=states)
