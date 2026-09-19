"""Pyroclasm intensity, own commitments and independently resolved pulse facts."""
import copy
import json
from pathlib import Path
import unittest

from u13_pysim import full_match_inputs, recruitment
from u13_pysim.power_match import PowerMatch
from u13_pysim.power_rules import declaration
from u13_pysim.primitives import instance_id
from .common import CommonSmartCore
from .coordination import evaluate
from .diagnostics import fingerprint
from .facts import Facts
from .lords.kalligan import proposals
from .observation import observe, Preview
from .planner_probe import PlannerObserver
from .test_common import planning
from .test_coordination import guard
from .test_recipes_veil import hand


def view_with_scorch(kind='lane', intensity=1):
    view = observe(planning('Kalligan'), 0)
    target = dict(kind=kind, lane='Castle')
    if kind == 'castle': target = dict(kind='castle', entity_id=Facts(view).castles(1)[0]['id'])
    view['persistent'].append(dict(declaration=dict(player_id=0, power_id='Inferno'),
        target=target, stages=[dict(intensity=intensity)], stage_index=0))
    return view


def unit(view, identity, owner, flying=False, waiting=False, lane='Castle'):
    attrs = recruitment.profile('Vulture', lane, owner, 1, 1)
    attrs.update(flying=flying, waiting=waiting)
    view['board'].append(dict(id=identity, kind='marcher', owner=owner, attributes=attrs))


def pulse_plan(view, order=None):
    return dict(powers=[declaration(0, view['round'], 'Pyroclasm')], order=order or {})


def load_case(index=0):
    data = json.loads(Path(__file__).with_name('kalligan_pulse_cases.json').read_text())
    case = data['cases'][index]; game = PowerMatch(case['setup'])
    for op in case['prefix']:
        if game.apply(op)['action'] == 'invalid': raise AssertionError(op)
    return case, game


def through_direct(game, plans):
    game = copy.deepcopy(game)
    if game.apply(dict(kind='submit', plans=plans))['action'] == 'invalid': raise AssertionError(plans)
    while game.clock.hook != 'post_resolution_direct':
        if game.apply(full_match_inputs.next_operation(game))['action'] == 'invalid': raise AssertionError(game.clock.hook)
    before = copy.deepcopy(game._state['world'])
    cursor = len(game._state['events']['rows'])
    if game.apply(full_match_inputs.next_operation(game))['action'] == 'invalid': raise AssertionError('direct')
    return game, before, [row['event'] for row in game._state['events']['rows'][cursor:]]


class KalliganTests(unittest.TestCase):
    def test_castle_pulse_uses_current_intensity_and_does_not_target_guards(self):
        view = view_with_scorch('castle')
        row = Facts(view).by_id[view['persistent'][0]['target']['entity_id']]
        row['attributes'].update(construction_state='active', integrity=17)
        guard(view, 'one', 1)
        for intensity, score in ((1,8), (2,16), (1,8)):
            view['persistent'][0]['stages'][0]['intensity'] = intensity
            found = next(p for p in proposals(Facts(view)) if p.term == 'Pyroclasm')
            self.assertEqual(score, found.value)
        self.assertFalse(any(p.payload['target'].get('kind')=='guard' for p in proposals(Facts(view))))
        row['attributes'].update(integrity=0,status='ruined')
        self.assertNotIn('Pyroclasm', [p.term for p in proposals(Facts(view))])

    def test_own_attack_removes_only_selected_castle_pulse_value(self):
        view = view_with_scorch('castle', 2); hand(view, [('Butcher', 5)])
        f = Facts(view); victim=f.by_id[view['persistent'][0]['target']['entity_id']]
        for row in f.castles(1): row['attributes']['construction_state']='unbuilt'
        victim['attributes'].update(integrity=1,construction_state='active')
        view['data']['sigils'][1]['Castle']=''
        order=dict(action='Siege',lane='Castle',target_id=victim['id'],card_ids=['ingredient:0'])
        row=evaluate(Facts(view),pulse_plan(view,order))['powers'][0]
        self.assertEqual((26,0,-26),(row['exposure_before'],row['exposure_after'],row['score_delta']))
        order=dict(action='Ward',lane='Castle',card_ids=['ingredient:0'])
        self.assertEqual(0,evaluate(Facts(view),pulse_plan(view,order))['score_delta'])

    def test_new_recruits_ground_monsters_and_flyers_are_distinct(self):
        view = view_with_scorch(); hand(view, [('Vulture', 6)])
        for i in range(8): unit(view, 'enemy'+str(i), 1)
        unit(view, 'own-flyer', 0, flying=True)
        order = dict(action='Ward', lane='Castle', card_ids=['ingredient:0'])
        first = evaluate(Facts(view), pulse_plan(view, order))['powers'][0]
        self.assertEqual((56,35,3), (first['exposure_before'],first['exposure_after'],first['ordinary_recruits']))
        order['monster_choice'] = 'Fyra'
        self.assertEqual(-21, evaluate(Facts(view), pulse_plan(view, order))['score_delta'])
        order['monster_choice'] = 'Varn'
        row = evaluate(Facts(view), pulse_plan(view, order))['powers'][0]
        self.assertEqual(-42, row['score_delta'])
        self.assertEqual(3, row['grounded_monster_bodies_minimum']); self.assertTrue(row['unknown_extra_varn_bodies'])
        order['lane'] = 'Lord'
        self.assertEqual(0, evaluate(Facts(view), pulse_plan(view, order))['score_delta'])

    def test_departing_supplicants_and_breach_arrivals_use_their_real_lane(self):
        view = view_with_scorch(); unit(view,'ground',0,waiting=True); unit(view,'fly',0,True,True)
        unit(view,'enemy',1); hand(view,[('Butcher',1)])
        f = Facts(view)
        order = dict(action='Siege',lane='Castle',target_id=f.castles(1)[0]['id'],card_ids=['ingredient:0'])
        row = evaluate(f,pulse_plan(view,order))['powers'][0]
        self.assertEqual((7,1),(row['score_delta'],row['consumed_ground_supplicants']))
        order = dict(rites=dict(waiter_spends=[dict(lane='Castle',marcher_ids=['ground','fly'])]))
        p = pulse_plan(view,order)
        p['powers'].append(declaration(0,view['round'],'BreachWishPower',dict(lane='Castle'),index=1))
        row = evaluate(f,p)['powers'][0]
        self.assertEqual((0,1),(row['score_delta'],row['power_bodies_minimum']))

    def test_natural_bad_pulse_is_omitted_without_changing_the_commitment(self):
        case, game = load_case(); view = observe(game,0)
        self.assertEqual(case['view_sha256'],fingerprint(view))
        before = game.snapshot(); choice = CommonSmartCore().decide(view,Preview(game,0))
        self.assertEqual(before,game.snapshot())
        self.assertEqual(case['original_plans'][0]['order'],choice['plan']['order'])
        self.assertEqual([],choice['plan']['powers'])
        self.assertGreater(choice['coordination']['adjusted_plans']['Pyroclasm'],0)
        _, world, old_events = through_direct(game,case['original_plans'])
        pulse = next(e['data'] for e in old_events if e['type']=='HAZARD_PULSED')
        owners = {r['id']:r['owner'] for r in world['entities']['entities']}
        self.assertEqual((13,7),tuple(sum(owners[k]==seat for k in pulse['affected_ids']) for seat in (0,1)))
        plans = copy.deepcopy(case['original_plans']); plans[0] = choice['plan']
        _, _, new_events = through_direct(game,plans)
        self.assertFalse(any(e['type']=='HAZARD_PULSED' for e in new_events))
        self.assertEqual('Kopita',choice['plan']['order']['monster_choice'])

    def test_natural_useful_pulse_survives_with_less_friendly_exposure(self):
        case, game = load_case(1); view = observe(game,0)
        self.assertEqual(case['view_sha256'],fingerprint(view))
        choice = CommonSmartCore().decide(view,Preview(game,0))
        self.assertIn('Pyroclasm',[s['power_id'] for s in choice['plan']['powers']])
        exposures = []
        for plan in (case['original_plans'][0],choice['plan']):
            plans = copy.deepcopy(case['original_plans']); plans[0] = plan
            _,world,events = through_direct(game,plans)
            pulse = next(e['data'] for e in events if e['type']=='HAZARD_PULSED')
            owners = {r['id']:r['owner'] for r in world['entities']['entities']}
            exposures.append(tuple(sum(owners[k]==seat for k in pulse['affected_ids']) for seat in (0,1)))
        self.assertEqual([(24,28),(14,28)],exposures)

    def test_natural_choice_is_legal_deterministic_and_within_existing_caps(self):
        _, game = load_case(); view = observe(game,0); before = game.snapshot()
        policy = CommonSmartCore(); first = policy.decide(view,Preview(game,0))
        view['board'].reverse(); view['hand'].reverse()
        self.assertEqual(first,policy.decide(view,Preview(game,0)))
        self.assertEqual(before,game.snapshot())
        self.assertEqual('legal',Preview(game,0)(first['plan'])['action'])
        for name,count in first['budget']['used'].items():
            limit = 16 if name.startswith('generated:') else 4 if name.startswith('retained:') else 32 if name=='complete_plans' else 8
            self.assertLessEqual(count,limit)
        self.assertFalse(first['coordination']['hard_veto'])

    def test_observer_attributes_actual_pulse_hp_armor_and_ownership(self):
        case, game = load_case(); after,world,events = through_direct(game,case['original_plans'])
        observer = PlannerObserver(dict(name='pulse-facts',setup=case['setup']))
        active = next(r for r in game._state['persistent']['active'] if r['declaration']['power_id']=='Inferno')
        source = case['original_plans'][0]['powers'][0]
        for term,key in [('Inferno',active['effect_id']),('Pyroclasm',instance_id('pending',source['declaration_id'],'main'))]:
            identity = observer.recorder.assess(3,0,'powers',term,legal=True,affordable=True,selected=True,reason='actual_replay')
            observer.effects[key] = identity
            if term=='Pyroclasm': observer.declarations[source['declaration_id']] = identity
        for i,event in enumerate(events): observer.event(i,event,3)
        groups = {g['term']:g for g in observer.report()['groups']}
        metrics = groups['Pyroclasm']['metrics']
        self.assertEqual((13,7),(metrics['friendly_hazard_marchers_hit'],metrics['enemy_hazard_marchers_hit']))
        for seat,prefix in ((0,'friendly_'),(1,'enemy_')):
            damage = sum(e['data']['hp_before']-e['data']['hp_after'] for e in events
                         if e['type'] in ('MARCHER_DAMAGED','MARCHER_DEFEATED') and e['data']['victim']['owner']==seat)
            self.assertEqual(damage,metrics[prefix+'hazard_hp_damage'])
        self.assertEqual({},groups['Inferno']['metrics'])
        # The automatic pulse later in the same round belongs to Inferno.
        cursor = len(after._state['events']['rows'])
        while after.clock.hook != 'marching':
            self.assertNotEqual('invalid',after.apply(full_match_inputs.next_operation(after))['action'])
        for i,row in enumerate(after._state['events']['rows'][cursor:],len(events)):
            observer.event(i,row['event'],3)
        groups = {g['term']:g for g in observer.report()['groups']}
        self.assertEqual(1,groups['Inferno']['metrics']['hazard_pulses'])
        self.assertEqual(1,groups['Pyroclasm']['metrics']['hazard_pulses'])


if __name__ == '__main__': unittest.main()
