"""Compare directed native Veil probes to independently executed Python rules.

Input contexts are explicit fixtures; expected output never feeds the next probe.
Run after U13VeilBreachesTestRunner exports its optional JSON evidence path.
"""
import json
import sys
from . import veil, wishmaster
from .copying import copy_data
from .lord_hooks import LordRoundRules
from .verify import same


def verify(path):
    data=json.load(open(path,encoding='utf-8'))
    for i,row in enumerate(data['sequence']):
        world=copy_data(row['world'])
        admitted=veil.begin(world,row['round'],row['seed'])
        same(row['admitted'],admitted,f'arrivals[{i}]')
        same(row['after'],world,f'arrival_world[{i}]')
    for i,row in enumerate(data['probes']):
        c=copy_data(row['context'])
        b=LordRoundRules(c['world'],c['round'],c['seed'],c['player_order'],c['hook'],c['persistent_effects'])
        if row.get('kind')=='price':
            deferred,events=wishmaster.price(b,copy_data(row['price']))
            result=dict(action='resolved',world=b.w,events=events)
            if deferred:result['deferred']=True
        else:
            events=veil.begin_effects(b) if row.get('kind')=='erosion' else b.run(c['combat_orders'])
            result=dict(action='resolved',world=b.w,events=events)
        same(row['result'],result,f'probe[{i}].{c["hook"]}')
    return dict(arrival_checks=len(data['sequence']),effect_checks=len(data['probes']))


if __name__=='__main__':
    print(json.dumps(verify(sys.argv[1])))
