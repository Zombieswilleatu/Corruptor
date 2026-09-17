"""New authority boundaries: atomic payment, durable identities and actor rollback."""
import unittest
from unittest.mock import patch
from . import economy as e, effects, powers, power_components, paid_inputs
from .copying import copy_data
from .power_match import PowerMatch
from .power_rules import declaration
from .full_match_inputs import next_operation
from .timeline import HOOKS


class PowerTests(unittest.TestCase):
    def test_resurrection_waits_for_marching_and_restores_only_the_selected_lane(self):
        from . import recruitment
        g = self.before_lock('Kanifous')
        world = g._state['world']
        lost_ids = []
        for lane in ('Lord', 'Castle'):
            for pid, suit in ((0, 'Butcher'), (1, 'Penitent')):
                a = recruitment.profile(suit, lane, pid, 0, 1)
                a.update(x_fp=600+pid*50, y_fp=300)
                if pid == 0: a.update(hp=1, armor=0)
                row = recruitment.create(world, 'resurrection:'+lane, pid, pid, a)
                if pid == 0: lost_ids.append(row['id'])
        source = declaration(0, 1, 'WishResurrection', dict(lane='Lord'))
        self.assertNotEqual('invalid', self.submit(g, [source])['action'])
        self.drive(g, 'end_marching_checks', 1)
        self.assertTrue(all(not e.entity(g._state['world'], key) for key in lost_ids))
        self.assertEqual(2, len(g._state['world']['data']['kanifous_losses']))
        self.assertEqual([], g._state['world']['data']['kanifous_prices'])
        op = dict(kind='step', hook='end_marching_checks')
        self.assertNotEqual('invalid', g.apply(op)['action'])
        revived = [r for r in g._state['world']['entities']['entities'] if r['kind']=='marcher' and r['owner']==0]
        self.assertEqual(1, len(revived))
        self.assertEqual(('Lord', 5, 1, 2), tuple(revived[0]['attributes'][k] for k in ('lane', 'hp', 'armor', 'movement_ready_round')))
        self.assertNotIn(revived[0]['id'], lost_ids)
        self.assertEqual(1, len(g._state['world']['data']['kanifous_prices']))

    def before_lock(self,lord):
        g=PowerMatch(paid_inputs.setup('power-test:'+lord,(lord,'Gremory')))
        while g.clock.hook!='submission_lock':
            self.assertNotEqual('invalid',g.apply(next_operation(g))['action'])
        return g

    def submit(self,g,sources,second=None):
        return g.apply(dict(kind='submit',plans=[dict(powers=sources,order={}),second or dict(powers=[],order={})]))

    def drive(self,g,hook,number):
        while g.clock.hook!=hook or g.clock.round!=number:
            if g.clock.hook=='submission_lock' and g._state['submissions']==[None,None]:op=dict(kind='submit',plans=[dict(powers=[],order={})]*2)
            else:op=next_operation(g)
            self.assertNotEqual('invalid',g.apply(op)['action'])

    def test_second_player_rejection_restores_first_queue_and_every_payment(self):
        g=self.before_lock('Odradek');before=g.snapshot()
        source=declaration(0,1,'Redirect',dict(lane='Lord',field_position=dict(x_fp=1000,y_fp=300)))
        second=dict(powers=[declaration(1,1,'PredatorOfRuin',dict(lane='wrong'))],order={})
        self.assertEqual('invalid',self.submit(g,[source],second)['action'])
        self.assertEqual(before,g.snapshot())
        self.assertEqual('game_submitted',self.submit(g,[source])['action'])
        # Preview leaves budgets, history and pending queues untouched.
        for key in ('world','pending','persistent','cooldowns','events','presentation_world'):
            self.assertEqual(before[key],g.snapshot()[key])
        self.assertNotEqual('invalid',g.apply(dict(kind='step',hook='submission_lock'))['action'])
        self.assertEqual(0,g._state['world']['players'][0]['resources']['reconfiguration'])

    def test_failed_resolver_restores_clock_world_queued_effect_and_history(self):
        g=self.before_lock('Gremory');source=declaration(0,1,'PredatorOfRuin',dict(lane='Lord'))
        self.submit(g,[source]);self.drive(g,'post_resolution_spawns',1);before=g.snapshot()
        original=powers.resolve
        def broken(*args):
            original(*args)
            raise e.Rejected('after spawn')
        with patch.object(powers,'resolve',broken):
            self.assertEqual('invalid',g.apply(dict(kind='step',hook='post_resolution_spawns'))['action'])
        self.assertEqual(before,g.snapshot())
        self.assertNotEqual('invalid',g.apply(dict(kind='step',hook='post_resolution_spawns'))['action'])
        self.assertEqual(3,sum(r['kind']=='marcher' for r in g._state['world']['entities']['entities']))

    def test_expiration_bound_clock_and_relocation_keep_original_lifetime(self):
        g=self.before_lock('Kalligan');s=declaration(0,1,'Inferno',dict(kind='lane',lane='Lord'))
        self.submit(g,[s]);self.drive(g,'submission_lock',2)
        active=copy_data(g._state['persistent']['active'][0]);old_clock=copy_data(g._state['cooldowns']['locks'][0])
        relocated=declaration(0,2,'Inferno',dict(kind='guard',lane='Castle',player_id=1))
        self.assertEqual('game_submitted',self.submit(g,[relocated])['action'])
        self.drive(g,'round_start_automatic',3)
        now=g._state['persistent']['active'][0]
        for key in ('effect_id','activated_round','declaration','stages'):self.assertEqual(active[key],now[key])
        self.assertEqual(relocated['target'],now['target'])
        self.assertEqual(old_clock,g._state['cooldowns']['locks'][0])
        self.drive(g,'round_start_automatic',5)
        self.assertEqual([],g._state['persistent']['active'])
        self.assertEqual(6,g._state['cooldowns']['locks'][0]['ready_round'])
        self.drive(g,'submission_lock',6)
        self.assertEqual([],g._state['cooldowns']['locks'])

    def test_repeatable_queue_spends_shared_budget_and_rejects_overspending_atomically(self):
        g=self.before_lock('Odradek');w=g._state['world'];w['players'][0]['resources']['reconfiguration']=4;g._state['presentation_world']=copy_data(w)
        sources=[declaration(0,1,'Redirect',dict(lane='Lord',field_position=dict(x_fp=900+10*i,y_fp=300)),index=i) for i in range(5)]
        before=g.snapshot();self.assertEqual('insufficient_resources',self.submit(g,sources)['reason']);self.assertEqual(before,g.snapshot())
        self.assertEqual('game_submitted',self.submit(g,sources[:4])['action'])
        g.apply(dict(kind='step',hook='submission_lock'))
        self.assertEqual(4,len(g._state['pending']['pending']));self.assertEqual([],g._state['cooldowns']['locks'])
        self.assertEqual(0,g._state['world']['players'][0]['resources']['reconfiguration'])

    def test_public_power_reaction_keeps_private_draw_views_private(self):
        state=dict(events=dict(rows=[]));source=dict(visibility='public')
        row=e.event('PRIVATE_DRAW',dict(player_id=0,card_id='secret'),private=0,redact=('card_id',))
        effects.append_event(state,row,source)
        self.assertEqual('secret',state['events']['rows'][0]['views'][0]['data']['card_id'])
        self.assertNotIn('card_id',state['events']['rows'][0]['views'][1]['data'])
        row['event']['data']['card_id']='changed'
        self.assertEqual('secret',state['events']['rows'][0]['event']['data']['card_id'])

    def test_consume_fizzles_after_source_banishment_without_repaying_or_retargeting(self):
        case=next(c for c in power_components.generate() if c['name']=='power_Consume');g=PowerMatch(case['setup'])
        for entry in case['operations'][:-1]:power_components.apply(g,entry['operation'])
        lord=e.entity(g._state['world'],g._state['world']['players'][0]['lord_entity_id']);lord['attributes'].update(alive=False,threat=0)
        queued=copy_data(g._state['pending']['pending'][0]);target=queued['declaration']['target']['entity_id']
        self.assertNotEqual('invalid',g.apply(case['operations'][-1]['operation'])['action'])
        self.assertTrue(e.entity(g._state['world'],target))
        fizzles=[r['event'] for r in g._state['events']['rows'] if r['event']['type']=='FIZZLE_INVALID_TARGET']
        self.assertEqual('kroni_source_banished',fizzles[-1]['data']['result']['reason'])
        self.assertEqual([],g._state['pending']['pending'])

    def test_extra_spatial_fields_do_not_change_isolated_marching_boundary(self):
        from . import marching
        g=self.before_lock('Kroni')
        with self.assertRaises(e.Unsupported):marching.resolve(dict(world=g._state['world'],round=1,hook='marching',seed='x',player_order=[0,1]))
