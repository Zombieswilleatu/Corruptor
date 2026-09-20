#!/usr/bin/env python3
"""Four real rounds in each seat: admission/Price smoke check, not a win-rate test."""
from collections import Counter
import json
import time

from u13_pysim import full_match_inputs
from u13_pysim.power_match import PowerMatch
from u13_doctrine.common import CommonSmartCore
from u13_doctrine.diagnostics import fingerprint
from u13_doctrine.observation import observe, Preview
from u13_doctrine.survey import LOADOUT


def run():
    start=time.perf_counter();rows=[]
    for focal in (0,1):
        lords=['Gremory','Gremory'];lords[focal]='Kanifous'
        setup=dict(seed='u13-kanifous-power-default-short-2026-09-20',lords=lords,
                   castles=[LOADOUT[:],LOADOUT[:]])
        match=PowerMatch(setup);policy=CommonSmartCore();operations=[];choices=Counter()
        assert policy.wish_profile=='power'
        while match.outcome()['winner']==-1 and match.clock.round<=4:
            hook=match.clock.hook
            if hook=='submission_lock' and match._state['submissions']==[None,None]:
                decisions=[policy.decide(observe(match,seat),Preview(match,seat)) for seat in (0,1)]
                assert all(not d['rejected_previews'] for d in decisions)
                assert decisions[focal]['kanifous']['profile']=='power'
                # Verify that the ordinary entry point routes to the selected profile.
                if match.clock.round==1:
                    explicit=CommonSmartCore(wish_profile='power').decide(observe(match,focal),Preview(match,focal))
                    assert explicit==decisions[focal]
                choices.update(p['power_id'] for p in decisions[focal]['plan']['powers'])
                operation=dict(kind='submit',plans=[d['plan'] for d in decisions])
            elif hook=='present_public_state' and match._state['world']['data']['game_economy']['stockpile_pending']:
                seat=match._state['world']['data']['game_economy']['stockpile_pending']['player_id']
                operation=policy.choose_card(observe(match,seat),'stockpile')['operation']
            elif hook=='present_public_state' and match._state['world']['data']['game_market']['seat']!=2:
                seat=match._state['world']['data']['game_market']['seat']
                operation=policy.choose_card(observe(match,seat),'slaver')['operation']
            else:operation=full_match_inputs.next_operation(match)
            result=match.apply(operation)
            assert result['action']!='invalid',(focal,match.clock.round,hook,result)
            operations.append(operation)
        events=[row['event'] for row in match._state['events']['rows']]
        wishes=[e['data'] for e in events if e['type']=='KANIFOUS_WISH_RESOLVED' and e['data']['player_id']==focal]
        prices=[e['data'] for e in events if e['type']=='KANIFOUS_PRICE_RESOLVED' and e['data']['player_id']==focal]
        assert choices['WishPower']>0 and wishes and prices
        rows.append(dict(focal_seat=focal,completed_rounds=match.clock.round-1,operations=len(operations),
                         operations_sha256=fingerprint(operations),selected=dict(choices),
                         power_bodies=[w['count'] for w in wishes if w['power']=='WishPower'],
                         prices_resolved=len(prices),rejected_previews=0))
        print(json.dumps(rows[-1]),flush=True)
    print(json.dumps(dict(policy=policy.policy_id,scope='two four-round smoke checks; no win-rate evidence',
                         checks=rows,wall_seconds=time.perf_counter()-start)),flush=True)


if __name__=='__main__':run()
