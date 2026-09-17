"""Replay directed native monster phases and compare every tick/event exactly."""
import json
import sys
from collections import Counter
from . import codec, marching_game
from .lifecycle import RoundRules
from .verify import same


def verify(path):
    counts=Counter();phases=0
    with open(path,encoding='utf-8') as stream:
        for line in stream:
            record=codec.loads(line)
            actual=marching_game.resolve(record['context'],RoundRules.march_reaction,capture_ticks=True)
            same(record['result'],actual,record['name'])
            counts.update(r['event']['type'] for r in actual['events']);phases+=1
    return dict(phases=phases,events=sum(counts.values()),ticks=counts['MARCHING_TICK'],event_types=dict(sorted(counts.items())))


def verify_games(inputs,path):
    from .power_match import PowerMatch
    results=[]
    with open(inputs,encoding='utf-8') as f:specs=json.load(f)
    with open(path,encoding='utf-8') as f:
        for spec,line in zip(specs,f,strict=True):
            expected=codec.loads(line);game=PowerMatch(spec['setup'])
            for i,op in enumerate(spec['operations']):
                result=game.apply(op)
                if result['action']=='invalid':raise ValueError((spec['name'],i,result))
            same(expected,dict(name=spec['name'],state=game.snapshot()),spec['name'])
            counts=Counter(r['event']['data']['monster_id'] for r in game._state['events']['rows'] if r['event']['type']=='MONSTER_SUMMONED')
            results.append(dict(name=spec['name'],round=game.clock.round,outcome=game.outcome(),summons=dict(counts),operations=len(spec['operations'])))
    return results


def verify_resurrections(path):
    from types import SimpleNamespace
    from .copying import copy_data
    from .wishmaster import wish
    checks = 0
    with open(path, encoding='utf-8') as stream:
        for line in stream:
            record = codec.loads(line)
            c = record['context']
            world = copy_data(c['world'])
            events = wish(SimpleNamespace(w=world, number=c['round'], seed=c['seed']), record['source'])
            same(record['result'], dict(action='resolved', world=world, events=events), record['name'])
            checks += 1
    if checks != 8:
        raise ValueError('Expected eight normal/Breach mobile/turret resurrection records')
    return dict(resurrection_checks=checks, complete_world_and_events_match=True)


if __name__=='__main__':
    if sys.argv[1]=='--games': result=verify_games(sys.argv[2],sys.argv[3])
    elif sys.argv[1]=='--resurrections': result=verify_resurrections(sys.argv[2])
    else: result=verify(sys.argv[1])
    print(json.dumps(result,indent=2))
