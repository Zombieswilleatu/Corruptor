"""Multiply guard creation and same-round Development, mirrored by U13Odradek.gd."""
from . import economy as e
from .powers import guards, slots
from .primitives import entity_id, instance_id


def validate(source, world, phase):
    t=source['target'];pid=source['player_id'];row=e.entity(world,t.get('entity_id',''))
    valid=(not source['parameters'] and set(t)=={'entity_id','lane'}
           and t['lane'] in ('Lord','Castle') and row in guards(world)
           and row['owner']==1-pid and row['attributes']['lane']==t['lane'])
    if not valid:return 'multiply_target_unavailable'
    if phase=='declaration' and len(slots(world,pid,t['lane']))<2:return 'multiply_requires_two_slots'
    return ''


def resolve(record, state, number, battle):
    s=record['declaration'];world=state['world'];t=s['target'];pid=s['player_id']
    row=e.entity(world,t['entity_id']);a=row['attributes']
    suit,value=a['suit'],a['value'];created=[]
    fact=battle.fact(dict(command_id=instance_id('multiply',s['declaration_id'],row['id']),
                          kind='defeat_guard',target_id=row['id']))
    events=[e.event(fact['type'],fact['data'])];events.extend(battle.react(fact))
    origin=instance_id('multiply_copies',s['declaration_id'],'guards');registry=world['entities']
    # Development effects fire before the already sealed hand deployments.
    # Leave their slots available, matching the planner's own-plan forecast.
    order = world['data']['guard_orders'][pid]
    reserved = {m['slot'] for m in order['moves'] if m['lane'] == t['lane']} if record['fire_hook'] == 'development' and order and order['round'] == number else set()
    available = [slot for slot in slots(world,pid,t['lane']) if slot not in reserved]
    for ordinal,slot in enumerate(available[:3]):
        identity=entity_id('card',origin,ordinal)
        e.require(identity not in registry['used_ids'],'entity_identity_already_used')
        new=dict(id=identity,kind='card',origin=origin,ordinal=ordinal,owner=pid,
                 attributes=dict(role='guard',suit=suit,value=value,lane=t['lane'],slot=slot))
        registry['entities'].append(new);registry['used_ids'].append(identity);created.append(identity)
    registry['entities'].sort(key=lambda r:r['id']);registry['used_ids'].sort()
    if len(created)>=2:
        pair_ids=created[:2]
        pair=dict(player_id=pid,lane=t['lane'],suit=suit,ids=pair_ids,
                  slots=[e.entity(world,k)['attributes']['slot'] for k in pair_ids],round=number,active=True)
        world['data']['guard_work']['pairs'].append(pair)
        events.append(e.event('GUARD_PAIR_FORMED',dict(player_id=pid,round=number,lane=t['lane'],suit=suit,card_ids=pair_ids)))
    world['data'].setdefault('multiply_fresh_guards',[]).extend(dict(player_id=pid,round=number,
        card_id=k,lane=t['lane'],slot=e.entity(world,k)['attributes']['slot']) for k in created)
    events.append(e.event('MULTIPLY_RESOLVED',dict(declaration_id=s['declaration_id'],player_id=pid,
        round=number,hook=record['fire_hook'],target_id=t['entity_id'],suit=suit,value=value,
        created_ids=created,neutral_tears=0),'Multiply: enemy guard destroyed; '+str(len(created))+' copies created.'))
    return events
