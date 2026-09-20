"""Public Wish/Price scenarios; no future rolls, hidden hand or Marching rollout."""
from u13_pysim import monsters, recruitment, field_fortifications as fort, marching_spatial
from u13_pysim.battle import operational, targetable
from u13_pysim.copying import copy_data
from u13_pysim.power_rules import LONGEVITY_INTEGRITY
from .defensive_plans import development
from .diagnostics import fingerprint
from .facts import LANES, power
from .lane_support import travel

WISHES = ('WishWealth', 'WishLongevity', 'WishDeath', 'WishResurrection', 'WishPower')
HAND_LIMIT = 10  # Ordinary U13 opening/card-zone contract.
PRICE_WEIGHTS = dict(Cards=30, Blood=30, Guards=15, Stone=15, Soul=5, Ruin=4, Wishmaster=1)


def material(row, restored=False):
    a = row['attributes']
    if restored:
        name = a.get('monster_id')
        a = (monsters.profile(name, a['lane'], row['owner'], 0, 1, a.get('sprite_form')=='turret')
             if name else recruitment.profile(a['suit'], a['lane'], row['owner'], 0, 1))
    return 2*max(2, 2*a['attack']+a['armor']+a['hp'])


def projected(f, plan, ctx):
    key = fingerprint(plan['order'])
    if not hasattr(f, '_wish_projection'): f._wish_projection = {}
    if key in f._wish_projection: return f._wish_projection[key]
    hand_ids={r['id'] for r in f.hand}
    def spent(value):
        if isinstance(value, dict): return set().union(*(spent(v) for v in value.values()))
        if isinstance(value, list): return set().union(*(spent(v) for v in value))
        return {value} if isinstance(value, str) and value in hand_ids else set()
    used = spent(plan['order'])
    world, work = development(f, plan)
    owned = [r for r in world['entities']['entities'] if r['owner']==f.pid]
    result = dict(hand=[r for r in f.hand if r['id'] not in used],
        castles=[r for r in owned if r['kind']=='castle'], guards=[r for r in owned if r['kind']=='card'],
        units=[r for lane in LANES for r in f.units(f.pid,lane) if r['id'] not in ctx['consumed_supplicants']],
        work=work, planned_bodies=ctx['recruits']+(5 if ctx['monster']=='Varn' else ctx['monster_bodies_minimum']))
    f._wish_projection[key] = result
    return result


def price_value(f, state):
    """Current public asset exposure, not odds of the eventual future board.

    Rule weights are conditional on an eligible outcome, not per target.
    Retain the old ten-point debt reserve and add urgency for near-due bills.
    """
    pools = {}
    def mean(values): return (sum(values)+len(values)-1)//len(values)
    hand, units, guards = state['hand'], state['units'], state['guards']
    if hand: pools['Cards'] = min(2,len(hand))*mean([2*r['attributes']['value'] for r in hand])
    if units: pools['Blood'] = min(2,len(units))*mean([material(r) for r in units])
    if guards: pools['Guards'] = mean([5*r['attributes']['value'] for r in guards])
    castles = [c for c in state['castles'] if c['attributes']['status']=='standing'
               and c['attributes'].get('construction_state','active')=='active']
    if castles:
        pools['Stone'] = mean([3*min(5,c['attributes']['integrity'])
            +12*int(operational(c) and c['attributes']['integrity']-5<7)
            +30*int(c['attributes']['integrity']<=5) for c in castles])
        pools['Ruin'] = mean([3*c['attributes']['integrity']+30 for c in castles])
    if f.resources['souls']>0: pools['Soul']=6
    if f.lord[f.pid]['attributes']['alive']: pools['Wishmaster']=75
    total=sum(PRICE_WEIGHTS[k] for k in pools)
    expected=(sum(PRICE_WEIGHTS[k]*v for k,v in pools.items())+total-1)//total if total else 0
    debts=[r for r in f.v['data']['kanifous_prices'] if r['owner']==f.pid]
    due=sum(r.get('due_round',f.v['round']+99)<=f.v['round']+1 for r in debts)
    return dict(score=max(10,expected)+10*len(debts)+4*due, current_asset_loss=expected,
        outstanding=len(debts), due_next_round=due, eligible_outcomes=pools,
        scope='current eligible asset pools; future cards, casualties, Price roll and target unknown')


def spawn_exposure(f, target, ctx, state):
    if ctx['recruit_lane']!=target['lane']: return 0
    p=target['field_position']; x=p['x_fp'] if f.pid==0 else 2400-p['x_fp']
    dx=max(0,-x,x-120);dy=max(0,90-p['y_fp'],p['y_fp']-510)
    return state['planned_bodies'] if dx*dx+dy*dy<=100*100 else 0


def wish_value(f, name, target, plan, ctx=None):
    from .coordination import context
    ctx=ctx or context(f,plan); state=projected(f,plan,ctx); price=price_value(f,state)
    result=dict(score=0,benefit=0,price=price,reason='',target=copy_data(target))
    benefit=0
    if name=='WishWealth':
        space=max(0,HAND_LIMIT-len(state['hand']))
        hundredths=sum(weight*min(space,count) for weight,count in ((20,1),(50,2),(30,3)))
        benefit=10*hundredths//100
        result.update(reason='draw_after_current_card_commitments',hand_after_commitments=len(state['hand']),
                      hand_space=space,expected_cards_hundredths=hundredths,draw_timing='after_combat_before_next_orders')
    elif name=='WishLongevity':
        castle=next(c for c in state['castles'] if c['id']==target['entity_id'])
        ceiling=min(LONGEVITY_INTEGRITY,castle['attributes']['max_integrity'])
        missing=max(0,ceiling-castle['attributes']['integrity']) if targetable(castle) else 0
        restores=bool(missing and castle['attributes']['integrity']<7<=ceiling)
        benefit=5*missing+12*restores
        result.update(reason='heal_remaining_after_own_work',integrity_after_work=castle['attributes']['integrity'],
                      healing=missing,restores_operation=restores,work=copy_data(state['work']))
    elif name=='WishPower':
        lane=target['lane']; own=sum(r['attributes']['lane']==lane for r in state['units'])
        planned=ctx['recruits']+ctx['monster_bodies_minimum'] if ctx['recruit_lane']==lane else 0
        need=max(0,len(f.units(f.enemy,lane))-own-planned)
        benefit=18+8*min(3,need)
        result.update(reason='guaranteed_body_with_remaining_lane_need',guaranteed_bodies=1,
                      lane_need_after_recruitment=need,extra_bodies='unknown')
    elif name=='WishDeath':
        p=target['field_position']; victims=[]
        for r in f.rows:
            if r['kind']!='marcher' or r['id'] in ctx['consumed_supplicants']: continue
            a=r['attributes']
            if a['lane']==target['lane'] and (a['x_fp']-p['x_fp'])**2+(a['y_fp']-p['y_fp'])**2<=100**2: victims.append(r)
        enemy=[r for r in victims if r['owner']==f.enemy]
        friendly=[r for r in victims if r['owner']==f.pid]
        exposure=spawn_exposure(f,target,ctx,state)
        benefit=sum(material(r) for r in enemy)-sum(material(r) for r in friendly)-18*exposure
        result.update(reason='material_removed_less_friendly_spawn_exposure',enemy_victims=[r['id'] for r in enemy],
                      friendly_victims=[r['id'] for r in friendly],planned_friendly_exposure_upper_bound=exposure)
    elif name=='WishResurrection':
        lane=target['lane']; known=[]; exposed=[]; seen=set(); limited=set()
        for r in sorted(f.v['data']['kanifous_losses'],key=lambda r:r['id']):
            a=r['attributes']; monster=a.get('monster_id','')
            # Ordinary planning observations expose the ledger after its
            # round-start reset, without the redundant round marker. Honor a
            # marker when a replay/scenario explicitly supplies one.
            if f.v['data'].get('kanifous_loss_round',f.v['round'])!=f.v['round']: continue
            if r['kind']!='marcher' or r['owner']!=f.pid or a['lane']!=lane or r['id'] in seen: continue
            if monsters.limited(monster) and (monsters.living(f.rows,f.pid,monster) or monster==ctx['monster'] or monster in limited): continue
            seen.add(r['id']);limited.add(monster);known.append(r['id']);benefit+=material(r,True)
        foes=f.units(f.enemy,lane)
        for r in state['units']:
            a=r['attributes']
            if a['lane']!=lane or r['id'] in seen or a.get('hidden',False): continue
            credit=0
            for foe in foes:
                b=foe['attributes']
                if b.get('hidden') or b.get('rout_round')==f.v['round']: continue
                reach=marching_spatial.vulture_range(f.world) if b.get('suit')=='Vulture' else 90
                distance=fort.distance(a,b)
                if a['hp']+a['armor']>4*b['attack']: continue
                if distance<=reach*reach: credit=max(credit,material(r,True)//2)
                elif distance<=(reach+travel(a,f.v['round'])+travel(b,f.v['round']))**2:
                    credit=max(credit,material(r,True)//4)
            if credit: exposed.append(dict(id=r['id'],discounted_value=credit));benefit+=credit
        result.update(reason='eligible_losses_and_discounted_reachable_danger',known_losses=known,
                      exposed=exposed,restoration_timing='after_marching_no_same_phase_combat')
    else: raise ValueError('Unknown ordinary Wish')
    result.update(benefit=benefit,score=benefit-price['score'])
    return result


def choices(f):
    # Wealth is always proposed: this round's spending may make room even when
    # the current hand is full. At most eleven choices, no hand-subset search.
    yield 'WishWealth', {}
    castles=[c for c in f.castles(f.pid) if targetable(c)
             and c['attributes']['integrity']<min(LONGEVITY_INTEGRITY,c['attributes']['max_integrity'])]
    for c in sorted(castles,key=lambda c:(c['attributes']['integrity'],c['id']))[:2]:
        yield 'WishLongevity', dict(entity_id=c['id'])
    for lane in LANES:
        target,_=f.cluster(lane,100)
        if target: yield 'WishDeath',target
        enemies=f.units(f.enemy,lane)
        if enemies:
            best=min(enemies,key=lambda r:(-material(r),r['id']))['attributes']
            valuable=dict(lane=lane,field_position=dict(x_fp=best['x_fp'],y_fp=best['y_fp']))
            if valuable!=target: yield 'WishDeath',valuable
        yield 'WishResurrection',dict(lane=lane)
        yield 'WishPower',dict(lane=lane)


class WishPlans:
    """Reconsider Wishes alongside complete orders within the common budget."""
    def __init__(self,f,enabled=True):
        self.f=f
        self.enabled=enabled and f.kind=='Kanifous' and any(f.available(n)[0] for n in WISHES)

    def alternatives(self,candidates,budget):
        if not self.enabled:return
        f=self.f; seen=set()
        def key(ps):return tuple(sorted(fingerprint([p.category,p.term,p.payload,p.cards]) for p in ps))
        existing={key(c['selected']) for c in candidates}
        for c in sorted(candidates,key=lambda c:(-c['score'],fingerprint(c['plan']))):
            anchors=[p for p in c['selected'] if not (p.category=='powers' and p.term in WISHES)]
            identity=key(anchors)
            if identity in seen:continue
            seen.add(identity); best=None; exhausted=False
            source=iter(choices(f))
            while budget.take('generated','kanifous'):
                try:name,target=next(source)
                except StopIteration:exhausted=True;break
                if not f.available(name)[0]:continue
                value=wish_value(f,name,target,c['plan'])
                if value['score']>0 and (best is None or value['score']>best[0]):best=value['score'],name,target
            if best:
                _,name,target=best; baseline=wish_value(f,name,target,dict(powers=[],order={}))
                p=power(name,target,baseline['score'],'wish_after_current_plan_commitments')
                combined=anchors+[p]; identity=key(combined)
                if identity not in existing:
                    if not budget.take('retained','kanifous'):return
                    existing.add(identity);yield combined
            if not exhausted:return

    def report(self,chosen,alternatives):
        return dict(enabled=self.enabled,alternatives=alternatives,
            selected=[copy_data(r) for r in chosen['coordination']['powers'] if r['power'] in WISHES],
            scope='own commitments and public assets; future Price outcomes, draws, enemy orders and spatial survival unknown')
