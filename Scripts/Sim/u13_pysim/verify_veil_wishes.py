"""Focused exact Godot/Python admission, Wish, Price and replay comparison."""
import json
import sys
from . import codec, power_components
from .power_match import PowerMatch
from .verify import same


def verify(inputs, path):
    specs=json.load(open(inputs,encoding='utf-8'));count=0
    with open(path,encoding='utf-8') as stream:
        def take():return codec.loads(next(stream))
        for spec in specs:
            game=PowerMatch(spec['setup'])
            same(dict(kind='component_opening',name=spec['name'],setup=spec['setup'],state=game.snapshot()),take(),spec['name']+'.opening')
            prefix=0
            for i,entry in enumerate(spec['operations']):
                result=power_components.apply(game,entry['operation']);state=game.snapshot();events=state.pop('events')
                same(entry['rejected'],result['action']=='invalid',spec['name']+f'.{i}.rejection')
                row=dict(kind='component_transition',name=spec['name'],index=i,operation=entry['operation'],result=result,state=state,event_prefix=prefix,events=dict(events,rows=events['rows'][prefix:]))
                same(row,take(),spec['name']+f'.{i}')
                prefix=len(events['rows']);count+=1
        if stream.read().strip():raise ValueError('Unexpected trailing records')
    return dict(cases=len(specs),transitions=count)


if __name__=='__main__':print(json.dumps(verify(*sys.argv[1:])))
