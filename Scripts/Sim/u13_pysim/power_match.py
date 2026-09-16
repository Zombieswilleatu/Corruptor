"""Nine-Lord adapter with native declared powers; experimental policy is injected.

The accepted four-Lord FullMatch API retains its explicit historical scope.
This adapter adds the remaining authority, using the same setup, transaction,
ordinary rules and Marcher kernel. It never consumes expected reference state.
"""
from . import economy as e, effects, powers
from .copying import copy_data, RollbackSnapshot
from .full_match import FullMatch
from .planning import PlanningMatch
from .lord_hooks import LordRoundRules
from .primitives import normalize

VERSION='U13_PYSIM_NINE_LORDS_V1'
LORDS=('Gremory','Deimos','Humbaba','Kalligan','Orias','Odradek','Kroni','Valak','Kanifous')


class PowerMatch(FullMatch):
    def _supported(self):
        w=self._state['world']
        if any(p['lord_id'] not in LORDS for p in w['players']):raise e.Unsupported('Unknown Lord')

    def _rollback_snapshot(self):
        owned=(type(self) is PowerMatch and not self._state_exposed and PlanningMatch._apply is _BASE_APPLY
               and all(getattr(getattr(self,k),'__func__',getattr(self,k)) is v for k,v in _OWNED.items())
               and all(getattr(module,name) is original for module,name,original in _HELPERS))
        return RollbackSnapshot(self._state,share_history=owned)

    def _submit_one(self,pid,plan):
        e.require(type(pid) is int and pid in (0,1) and self.clock.hook=='submission_lock','submission_window_closed')
        e.require(self._state['submissions'][pid] is None,'submission_already_locked')
        try:order=normalize(plan['order']);declarations=normalize(plan['powers'])
        except (ValueError,TypeError) as error:raise e.Rejected('submission_data_invalid') from error
        # Admission needs the mutable staged budget, never a clone of history.
        preview=copy_data({k:v for k,v in self._state.items() if k!='events'})
        preview['events']=dict(rows=[])
        effects.accept(preview,pid,declarations,self.clock.round,powers.validate)
        self._accept_power_order(preview,pid,order,declarations)
        self._state['submissions'][pid]=declarations;self._state['combat_orders'][pid]=order

    def _accept_power_order(self,state,pid,order,declarations):
        w=state['world'];n=self.clock.round
        events=super()._accept_order(w,pid,order)
        # Orias wraps Guard reservation and precedes Castle/combat reservation.
        snare=[]
        for s in declarations:
            if s['power_id']=='Snare':
                e.require(w['data']['snare_paid_rounds'][pid]<n,'snare_already_paid')
                b=LordRoundRules(w,n,state['seed'],state['player_order'],'submission_lock',state['persistent']['active'])
                lord=b.lord(pid);before=lord['attributes']['threat'];e.require(before<1000000,'snare_threat_limit')
                after,gained=b.conduit(lord,1);snare.extend(gained);w['data']['snare_paid_rounds'][pid]=n
                snare.append(e.event('SNARE_ARMED',dict(player_id=pid,target_player_id=s['target']['player_id'],round=n,hook='submission_lock',declaration_id=s['declaration_id'],threat_before=before,threat_after=after)))
            elif s['power_id']=='Projection':
                spend=s['parameters']['spend'];r=w['players'][pid]['resources']
                e.require(r['life_essence']>=spend and w['data']['valak_reserved'][pid]==0,'projection_essence_unavailable')
                r['life_essence']-=spend;w['data']['valak_reserved'][pid]=spend
        index=next((i for i,x in enumerate(events) if x['event']['type'] in ('CASTLE_ACTION_SEALED','COMBAT_ORDER_SEALED')),len(events))
        events[index:index]=snare
        e.require(sum(s['power_id'] in powers.WISHES for s in declarations)<=1,'one_wish_per_round')
        return events

    def _hook(self):
        s,n,hook=self._state,self.clock.round,self.clock.hook
        if hook=='submission_lock':
            e.require(all(x is not None for x in s['submissions']),'both_submissions_required')
            for pid in s['player_order']:
                declarations=s['submissions'][pid]
                effects.accept(s,pid,declarations,n,powers.validate)
                s['events']['rows'].extend(self._accept_power_order(s,pid,s['combat_orders'][pid],declarations))
        if hook=='persistent_advancement':effects.advance(s,n)
        effects.resolve_due(s,n,hook,powers.validate,powers.resolve)
        rules=LordRoundRules(s['world'],n,s['seed'],s['player_order'],hook,s['persistent']['active'])
        try:events=rules.run(s['combat_orders'])
        except e.Rejected as error:raise e.Rejected('transform_contract_error') from error
        s['world']=rules.w
        # Native world installation and EventLog.append normalize integral
        # floating-point data. Raw phase probes intentionally retain float bits.
        if hook=='marching' and rules.w['data'].get('kroni_actors'):
            rules.w['data']['kroni_actors']=normalize(rules.w['data']['kroni_actors'])
            events=normalize(events)
        s['events']['rows'].extend(events)
        if hook=='present_public_state':s['presentation_world']=copy_data(s['world'])


_OWNED={name:getattr(PowerMatch,name) for name in ('_apply','_hook','_supported','_submit_one','_accept_order','_accept_power_order','_combat_shape','outcome')}
_BASE_APPLY=PlanningMatch._apply

_HELPERS=[(module,name,getattr(module,name)) for module,names in ((effects,('accept','advance','resolve_due')),(powers,('validate','resolve'))) for name in names]
