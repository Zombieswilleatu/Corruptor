"""Exact native/Python setup-to-planning gate for the adopted free opening."""
import argparse
from collections import Counter
from copy import deepcopy
import json
from pathlib import Path

from . import codec, opening
from .power_match import PowerMatch
from .verify import same, shape, source_identity, trace_identity

SCHEMA = 'U13_FREE_OPENING_SUITE_V1'
MODES = [['Keep','Stockpile','SummoningCircle','SiegeEngine','Bastion'],
         ['Keep','Bastion','SiegeEngine','SummoningCircle','Stockpile']]


def setup(index):
    return dict(seed=f'u13-free-opening:{index}',
        lords=[opening.LORDS[index],opening.LORDS[(index+1)%9]], castles=deepcopy(MODES))


def verify(suite, revision, source, diagnostic=False):
    shape(suite, {'schema','traces'}, 'suite')
    same(SCHEMA,suite['schema'],'schema')
    same(9,len(suite['traces']),'nine_lords')
    snapshots, operations = 0, 0
    for index, trace in enumerate(suite['traces']):
        path = f'traces[{index}]'
        trace_identity(trace,revision,source,diagnostic,path)
        same(setup(index),trace['setup'],path+'.setup')
        game = PowerMatch(trace['setup'])
        same(game.snapshot(),trace['opening'],path+'.opening'); snapshots += 1
        kinds = Counter()
        for ordinal, record in enumerate(trace['records']):
            before=game.snapshot(); op=record['operation']; result=game.apply(op)
            if result['action']=='invalid':
                raise ValueError(path+'.rejected_operation: '+str(result))
            actual=dict(index=ordinal,round=before['runtime']['round'],hook_before=before['runtime'],
                operation=op,result=result,state=game.snapshot(),outcome=game.outcome())
            same(actual,record,path+f'.records[{ordinal}]')
            kinds[op['kind']]+=1; operations+=1; snapshots+=1
        same({'step':4,'stockpile':1,'market':2},dict(kinds),path+'.choices')
        same('submission_lock',game.clock.hook,path+'.last_hook')
        same([6,5],[len(h) for h in game._state['world']['data']['card_zones']['hands']],path+'.hands')
    return dict(schema=SCHEMA,opening_version=opening.ECONOMY,source_revision=revision,
        source_sha256=source,diagnostic_only=diagnostic,complete_openings_matched=9,
        snapshots_matched=snapshots,operations_matched=operations,failures=0,
        runtime=suite['traces'][0]['identity']['runtime'],
        scope='exact opening, first draws, Stockpile/Slaver, event privacy and planning boundary; no full-game parity claim')


def verify_rejections(suite, revision, source, diagnostic=False):
    def bad_circle(candidate):
        rows=candidate['traces'][0]['opening']['world']['entities']['entities']
        next(r for r in rows if r['kind']=='castle' and r['attributes']['castle_type']=='SummoningCircle')['attributes']['integrity']-=3
    def bad_hand(candidate):
        z=candidate['traces'][0]['opening']['world']['data']['card_zones']
        z['hands'][0].append(z['deck'][-1])
    mutations=[
        lambda x:x['traces'][0]['identity'].update(source_revision='wrong'),
        lambda x:x['traces'][0]['opening']['world']['data']['game_economy']['opening']['summons'][0].update(cost=1),
        bad_circle,bad_hand,
        lambda x:x['traces'][0]['records'][0]['operation'].update(hook='aftermath'),
        lambda x:x['traces'][0]['records'][-1]['state']['world']['data']['card_zones']['hands'][0].pop(),
    ]
    for index, change in enumerate(mutations):
        candidate=deepcopy(suite);change(candidate)
        try: verify(candidate,revision,source,diagnostic)
        except ValueError: continue
        raise ValueError(f'corruption {index} was accepted')
    return len(mutations)


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('trace',type=Path)
    parser.add_argument('--report',type=Path,required=True)
    parser.add_argument('--diagnostic',action='store_true')
    args=parser.parse_args()
    revision,source=source_identity(Path(__file__).resolve().parents[3])
    suite=codec.loads(args.trace.read_text(encoding='utf-8'))
    result=verify(suite,revision,source,args.diagnostic)
    result['deliberate_mismatches_rejected']=verify_rejections(suite,revision,source,args.diagnostic)
    args.report.write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')
    print(json.dumps(result,sort_keys=True))
    print('U13 free opening Python failures: 0')


if __name__=='__main__': main()
