"""Owned U13 declaration, pending, persistent and cooldown lifecycle.

The match owns the transaction. No doctrine, native state or reference result
is consulted here. Registry lists remain sorted exactly as native snapshots.
"""
import json
from . import economy as e
from .copying import copy_data
from .primitives import normalize, instance_id
from .timeline import HOOKS
from .power_rules import RULES


def source_copy(raw):
    try:
        s = normalize(raw)
    except (ValueError,TypeError):
        return {}
    if type(s) is not dict: return {}
    if any(type(s.get(k)) is not str for k in ('schema_version','declaration_id','lord_id','power_id','fire_hook','visibility')): return {}
    if any(type(s.get(k)) is not int for k in ('player_id','declared_round','fire_round','queue_index')): return {}
    if (s['schema_version']!='U13_LORD_DECLARATION_V1' or not all(s[k] for k in ('declaration_id','lord_id','power_id'))
            or s['player_id'] not in (0,1) or s['declared_round']<1 or s['queue_index']<0
            or s['fire_hook'] not in HOOKS or s['visibility'] not in ('public','hidden')
            or s['fire_round']!=-1 and s['fire_round']<s['declared_round']
            or any(type(s.get(k)) is not dict for k in ('target','cost','parameters'))): return {}
    return s


def record(scope, source, key='main', payload=None):
    return dict(effect_id=instance_id(scope,source['declaration_id'],key),effect_key=key,
                declaration=copy_data(source),payload=copy_data(payload or {}),public_data={})


def fact(kind, rec, **details):
    s=rec['declaration']
    details.update(effect_id=rec['effect_id'],declaration_id=s['declaration_id'],player_id=s['player_id'],power_id=s['power_id'])
    return dict(type=kind,text='',data=details)


def append_event(state, event, source):
    if 'event' in event and 'views' in event:
        row=copy_data(event)
        if source.get('visibility')!='public': row['views']=[None,None]
    else:
        row=dict(event=copy_data(event),views=[copy_data(event),copy_data(event)] if source.get('visibility')=='public' else [None,None])
    state['events']['rows'].append(row)


def slot(rec):
    s=rec['declaration']
    return json.dumps([s['player_id'],s['lord_id'],s['power_id']],separators=(',',':'),ensure_ascii=False)


def active_for(state, source):
    return next((r for r in state['persistent']['active'] if r['declaration']['player_id']==source['player_id'] and r['effect_key']==source['power_id']),{})


def clock_for(state, source):
    key=(source['player_id'],source['lord_id'],source['power_id'])
    return next((r for r in state['cooldowns']['locks'] if tuple(r['declaration'][k] for k in ('player_id','lord_id','power_id'))==key),{})


def timing(rec):
    return {k:rec[k] for k in ('phase','first_blocked_round','ready_round','cooldown_rounds')}


def target_valid(world, source, r):
    if not r['target_kind']: return
    key=source['target'].get('entity_id')
    e.require(type(key) is str,'target_id_required')
    row=e.entity(world,key)
    e.require(row and row['kind']==r['target_kind'],'target_missing_or_wrong_kind')
    if r['target_relation']=='own': e.require(row['owner']==source['player_id'],'target_not_owned')
    if r['target_relation']=='enemy': e.require(row['owner']==1-source['player_id'],'target_not_enemy')


def accept(state, pid, declarations, number, validator):
    try: normalize(declarations)
    except (ValueError,TypeError) as error: raise e.Rejected('submission_data_invalid') from error
    seen=set()
    for index,raw in enumerate(declarations):
        s=source_copy(raw)
        e.require(s and s['player_id']==pid and s['queue_index']==index
                  and s['declaration_id']==instance_id('declaration',f'{pid}:{number}',str(index)), 'submission_identity_invalid')
        e.require(s['power_id'] in RULES,'unknown_power')
        r=RULES[s['power_id']]
        e.require(s['power_id'] not in seen or r.get('repeatable',False),'duplicate_power_in_submission')
        seen.add(s['power_id']);active=active_for(state,s)
        e.require(not active or r.get('persistent_relocatable',False),'persistent_power_already_active')
        w=state['world'];present=state['presentation_world']
        e.require(s['declared_round']==number and s['lord_id']==r['lord_id'],'declaration_source_invalid')
        fire=s['declared_round'] if s['fire_round']==-1 else s['fire_round']
        e.require(fire==number+r['delay_rounds'] and s['fire_hook']==r['fire_hook'],'declaration_timing_invalid')
        cost=copy_data(r['cost']);count=r.get('discard_count',0)
        if count:
            ids=s['cost'].get('discard_ids')
            e.require(type(ids) is list and len(ids)==count and all(type(x) is str and x for x in ids)
                      and len(set(ids))==count,'declaration_terms_invalid')
            cost['discard_ids']=ids
        e.require(s['visibility']==r['visibility'] and s['cost']==cost,'declaration_terms_invalid')
        lord=e.entity(w,present['players'][pid]['lord_entity_id'])
        e.require(present['players'][pid]['lord_id']==s['lord_id'] and lord and lord['owner']==pid and lord['attributes']['alive'],'source_unavailable')
        clock=clock_for(state,s);relocating=False
        if r.get('persistent_relocatable'):
            relocating=bool(active and clock and clock['phase']=='awaiting_expiration' and clock['persistent_effect_id']==active['effect_id']
                            and fire<active['activated_round']+len(active['stages']))
            e.require(not active or relocating,'persistent_relocation_not_ready')
        e.require(r.get('repeatable') or relocating or state['cooldowns']['round']>=1 and not clock,'power_not_ready')
        for resource,amount in r['cost'].items(): e.require(w['players'][pid]['resources'].get(resource,0)>=amount,'insufficient_resources')
        target_valid(w,s,r)
        # Validators see the presentation baseline with only their own staged budget.
        preview=copy_data(present)
        preview['players'][pid]['resources']=copy_data(w['players'][pid]['resources'])
        reason=validator(s,preview,'declaration',state['persistent']['active'])
        if reason: raise e.Rejected('rule_rejected',dict(action='invalid',reason='rule_rejected',detail=reason))
        if count:
            ids=s['cost']['discard_ids'];z=e.zones(w)
            e.require(e.selection(z['hands'][pid],ids),'discard_payment_invalid')
            for key in ids:
                z['hands'][pid].remove(key);z['discard'].append(key);e.entity(w,key)['owner']=-1
            append_event(state,dict(type='CARDS_DISCARDED',text='',data=dict(player_id=pid,card_ids=ids,declaration_id=s['declaration_id'])),s)
        clock_events=[]
        if not r.get('repeatable') and not active:
            clock=record('cooldown',s);reg=state['cooldowns']
            e.require(clock['effect_id'] not in reg['used_ids'],'cooldown_declaration_already_used')
            waiting=r['cooldown_on']=='expiration';n=reg['round']
            clock.update(registered_round=n,cooldown_rounds=r['cooldown_rounds'],
                         persistent_effect_id=instance_id('persistent',s['declaration_id'],s['power_id']) if waiting else '',
                         phase='awaiting_expiration' if waiting else 'cooling',first_blocked_round=0 if waiting else n+1,
                         ready_round=0 if waiting else n+r['cooldown_rounds']+1)
            reg['locks'].append(clock);reg['locks'].sort(key=slot)
            reg['used_ids'].append(clock['effect_id']);reg['used_ids'].sort()
            clock_events.append(fact('COOLDOWN_ARMED' if waiting else 'COOLDOWN_STARTED',clock,**timing(clock)))
        for resource,amount in r['cost'].items(): w['players'][pid]['resources'][resource]-=amount
        pending=record('pending',s,payload=dict(relocate_effect_id=active['effect_id']) if active else {})
        reg=state['pending'];e.require(pending['effect_id'] not in reg['used_ids'],'effect_id_already_used')
        pending.update(fire_round=fire,fire_hook=s['fire_hook'])
        reg['pending'].append(pending);reg['pending'].sort(key=lambda r:r['effect_id'])
        reg['used_ids'].append(pending['effect_id']);reg['used_ids'].sort()
        append_event(state,fact('POWER_DECLARED',pending),s)
        for event in clock_events: append_event(state,event,s)


def advance(state, number):
    p=state['persistent'];c=state['cooldowns']
    e.require(p['advanced_round']==0 or number==p['advanced_round']+1,'persistent_advancement_round_out_of_order')
    for rec in p['active'][:]:
        age=number-rec['activated_round'];s=rec['declaration']
        e.require(0<=age<=rec['stage_index']+1,'persistent_lifecycle_gap')
        if age>=len(rec['stages']):
            p['active'].remove(rec)
            append_event(state,fact('PERSISTENT_EFFECT_EXPIRED',rec,round=number),s)
            for clock in c['locks']:
                if clock['persistent_effect_id']!=rec['effect_id']: continue
                e.require(number==c['round']+1 and clock['phase']=='awaiting_expiration','cooldown_expiration_must_precede_advancement')
                clock.update(phase='cooling',first_blocked_round=number,ready_round=number+clock['cooldown_rounds'])
                append_event(state,fact('COOLDOWN_STARTED',clock,**timing(clock)),s)
        elif age!=rec['stage_index']:
            rec['stage_index']=age
            append_event(state,fact('PERSISTENT_EFFECT_ADVANCED',rec,round=number,stage_index=age),s)
    p['advanced_round']=number
    e.require(c['round']==0 or number==c['round']+1,'cooldown_advancement_round_out_of_order')
    for clock in c['locks'][:]:
        if clock['phase']=='cooling' and clock['ready_round']<=number:
            append_event(state,fact('COOLDOWN_READY',clock,round=number),clock['declaration']);c['locks'].remove(clock)
    c['round']=number


def resolve_due(state, number, hook, validator, resolver):
    reg=state['pending'];due=[];rank=HOOKS.index(hook)
    for rec in reg['pending']:
        when=(rec['fire_round'],HOOKS.index(rec['fire_hook']))
        e.require(when>=(number,rank),'overdue_pending_effect')
        if when==(number,rank): due.append(rec)
    order=state['player_order']
    due.sort(key=lambda r:(order.index(r['declaration']['player_id']),r['declaration']['declared_round'],r['declaration']['queue_index'],r['effect_id']))
    finished=[]
    for rec in due:
        s=rec['declaration'];r=RULES[s['power_id']];relocate=rec['payload'].get('relocate_effect_id','')
        active=next((x for x in state['persistent']['active'] if x['effect_id']==relocate),{}) if relocate else {}
        reason='relocation_effect_expired' if relocate and not active else ''
        if not reason:
            try: target_valid(state['world'],s,r)
            except e.Rejected as error: reason=str(error)
            if not reason: reason=validator(s,state['world'],'firing',state['persistent']['active'])
        if reason:
            if reason!='relocation_effect_expired' and r['cooldown_on']=='expiration' and not relocate:
                clock=clock_for(state,s)
                e.require(clock and clock['phase']=='awaiting_expiration','cooldown_lock_missing')
                clock.update(phase='cooling',first_blocked_round=number+1,ready_round=number+clock['cooldown_rounds']+1)
                append_event(state,fact('COOLDOWN_STARTED',clock,**timing(clock)),s)
            outcome=dict(action='fizzle',reason=reason)
        else:
            result=resolver(rec,state,number)
            for event in result.get('events',[]): append_event(state,event,s)
            if relocate:
                active['target']=copy_data(s['target']);active['payload']['last_relocation']=copy_data(s)
                append_event(state,fact('PERSISTENT_EFFECT_RELOCATED',active,target=s['target'],round=number),s)
            elif rec['effect_key']=='main' and r['stages']:
                new=record('persistent',s,s['power_id'],result.get('persistent_payload',{}))
                p=state['persistent'];e.require(new['effect_id'] not in p['used_ids'],'effect_id_already_used')
                e.require(not active_for(state,s),'persistent_slot_occupied')
                new.update(activated_round=number,stage_index=0,stages=copy_data(r['stages']),target=copy_data(s['target']))
                p['active'].append(new);p['active'].sort(key=lambda x:x['effect_id'])
                p['used_ids'].append(new['effect_id']);p['used_ids'].sort()
                append_event(state,fact('PERSISTENT_EFFECT_STARTED',new,round=number),s)
            outcome=dict(action='resolved')
        reg['pending'].remove(rec)
        finished.append((fact('POWER_RESOLVED' if outcome['action']=='resolved' else 'FIZZLE_INVALID_TARGET',rec,round=number,hook=hook,result=outcome),s))
    # Native queue emits all terminal records after every same-hook resolver.
    for event,s in finished: append_event(state,event,s)
