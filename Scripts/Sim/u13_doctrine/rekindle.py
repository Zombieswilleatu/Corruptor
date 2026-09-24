"""Public, episode-gated repair payoff for Kalligan."""
from u13_pysim.battle import targetable, defunct

def eligible(f, row):
    a=row['attributes']
    return (f.kind=='Kalligan' and f.lord[f.pid]['attributes']['alive'] and targetable(row)
        and row['owner']==f.pid and a['integrity']<a['max_integrity']
        and a.get('repair_lock_until_round',0)<f.v['round']
        and (row['id'] in f.v['data']['rekindle_defunct_ids'] or defunct(row)))

def payoff(f, world):
    score=0
    tears=f.resources['personal_tears']
    enemy=f.world['players'][f.enemy]['resources']['personal_tears']
    for row in f.castles(f.pid):
        if not eligible(f,row): continue
        after=next(r for r in world['entities']['entities'] if r['id']==row['id'])['attributes']
        before=row['attributes'];missing=before['max_integrity']-before['integrity']
        gain=max(0,after['integrity']-before['integrity'])
        score+=30*gain//missing
        if gain>=missing:
            score+=60
            if tears+1>=5 and tears+1>enemy: score+=100
    return score
