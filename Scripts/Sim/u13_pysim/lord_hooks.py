"""Remaining Lord wrapper hooks, in the native content inheritance order."""
from . import economy as e, powers, kroni_actors as kroni, wishmaster
from .copying import copy_data
from .primitives import instance_id, draw
from .lifecycle import RoundRules


class LordRoundRules(RoundRules):
    def __init__(self,world,number,seed,player_order,hook,active):
        super().__init__(world,number,seed,player_order,hook)
        self.effects=active

    def context(self):
        return dict(world=self.w,round=self.number,seed=self.seed,player_order=self.order,
                    hook=self.hook,persistent_effects=self.effects,full_roster=True)

    def run(self, orders):
        events = super().run(orders)
        wishmaster.record_losses(self.w, events)
        return events

    def extra(self):
        w,n,d,hook=self.w,self.number,self.w['data'],self.hook;events=[]
        if hook in ('persistent_advancement','marching_start'):
            kind='guard' if hook=='persistent_advancement' else 'lane'
            for active in sorted(self.effects,key=lambda a:(self.order.index(a['declaration']['player_id']),a['effect_id'])):
                if active['declaration']['power_id']=='Inferno' and active['target']['kind']==kind:
                    events.extend(powers.pulse(self,active,instance_id('normal_pulse',active['effect_id'],str(n)+hook)))
        if hook=='round_start_automatic':
            for pid in (0,1):
                if self.active(pid,'Odradek'):
                    r=w['players'][pid]['resources'];before=r['reconfiguration'];r['reconfiguration']=min(4,before+1)
                    events.append(powers.odradek_event('RECONFIGURATION_GAINED',dict(player_id=pid,before=before,after=r['reconfiguration'],round=n)))
        if hook=='post_resolution_allegiance' and d['breach_lord']=='Odradek':
            pools={}
            for lane in powers.LANES:
                candidates=sorted(powers.eligible(w,0,lane,1)+powers.eligible(w,1,lane,0))
                if candidates:pools[lane]=candidates
            bodies=sorted(r['id'] for r in w['entities']['entities'] if r['kind']=='marcher')
            if bodies:pools['Marcher']=bodies
            identity=instance_id('paradox',str(n),'breach');kinds=sorted(pools)
            if not kinds:events.append(powers.odradek_event('PARADOX_GEOMETRY',dict(event_id=identity,round=n,kind='none',reason='no_valid_targets')))
            else:
                kind=kinds[draw(self.seed,identity,'PARADOX_KIND',0,len(kinds))];key=pools[kind][draw(self.seed,identity,'PARADOX_TARGET',0,len(pools[kind]))]
                events.append(powers.odradek_event('PARADOX_GEOMETRY',dict(event_id=identity,round=n,hook=hook,kind=kind,target_id=key)))
                r=e.entity(w,key)
                if kind=='Marcher':
                    a=r['attributes'];events.extend(powers.shift(self,dict(lane=a['lane'],field_position=dict(x_fp=a['x_fp'],y_fp=a['y_fp'])),-1,identity))
                else:
                    before=powers.transfer(w,key,r['owner'],1-r['owner'],kind,True)
                    e.require(before is not None,'paradox_selected_transfer_failed')
                    events.append(powers.odradek_event('GUARD_RECONFIGURED',dict(before=before,after=e.entity(w,key),power='ParadoxGeometry',event_id=identity,round=n,hook=hook)))
        if hook=='round_start_scheduled':
            for pid in self.order:
                if not self.active(pid,'Kroni') or d['kroni_fed'][pid]==n:continue
                candidates=sorted((r for r in powers.guards(w) if r['owner']==pid),key=lambda r:(r['attributes']['value'],r['id']))
                if candidates:events.append(kroni.devour_guard(w,candidates[0],pid,n,'Cannibal Hunger'))
                else:events.extend(kroni.feed(w,pid,-1,n,'Cannibal Hunger'))
        elif hook=='marching_start' and d['breach_lord']=='Kroni':
            actor=kroni.create(instance_id('insatiable',str(n),'breach'),-1,n,0,True,self.seed)
            d['kroni_actors'].append(actor);events.append(e.event('INSATIABLE_HUNGER_MANIFESTED',dict(actor=actor,round=n),'Insatiable Hunger manifests in the field.'))
        elif hook=='marching':
            for actor in d['kroni_actors']:
                if not actor['breach'] and actor['consumed']>=6 and not actor['rewarded']:
                    actor['rewarded']=True;w['players'][actor['owner']]['resources']['souls']+=1;d['neutral_tears']+=1
                    events.extend(kroni.feed(w,actor['owner'],1,n,'Ravenous'))
                    events.append(e.event('RAVENOUS_REWARDED',dict(actor_id=actor['id'],player_id=actor['owner'],round=n,consumed=actor['consumed'],souls=1,hunger=1,neutral_tears=1),'Ravenous: +1 Soul, +1 Hunger, +1 Neutral Tear.'))
        if hook=='persistent_advancement':
            ids={a['effect_id'] for a in self.effects}
            d['valak_orbs']=[r for r in d['valak_orbs'] if r['id'] in ids]
        events.extend(wishmaster.advance(self))
        if hook=='present_public_state':
            d['guard_public_limits']=[min(1 if d['snare_rounds'][pid]==n else 6,2 if d['breach_lord']=='Orias' and self.lord(pid)['attributes'].get('threat',0)>=2 else 6) for pid in (0,1)]
        return events
