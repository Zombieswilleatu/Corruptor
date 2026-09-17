"""Small behavior probe. New policy decisions are not a new native parity corpus."""
from collections import Counter
from dataclasses import asdict
import hashlib
import json
from pathlib import Path
import time

from u13_pysim import full_match_inputs, power_inputs
from u13_pysim.benchmark_full_match import digest
from u13_pysim.power_match import PowerMatch
from u13_pysim.primitives import instance_id
from u13_pysim.verify import source_identity, same
from .common import CommonSmartCore, VERSION
from .diagnostics import Recorder, fingerprint
from .observation import observe, Preview
from .reference_probe import ReferenceObserver, harness_hash

EVIDENCE = 'docs/evidence/U13_PYSIM_NINE_LORDS_5fb53e7.json'


class PlannerObserver(ReferenceObserver):
    def __init__(self, spec):
        super().__init__(spec)
        self.recorder = Recorder(spec['name'], spec['setup']['lords'], [VERSION]*2)
        self.declarations, self.effects, self.prices, self.firing, self.actors = {}, {}, {}, {}, {}
        self.max_work = Counter()
        self.rejected_previews = []
        self.decision_examples = []

    def accepted(self, number, seat, decision):
        for a in decision['assessments']:
            identity = self.recorder.assess(number, seat, **a)
            if identity: self.selected[(number, seat, a['category'], a['term'])] = identity
        plan = decision['plan']
        for source in plan['powers']:
            identity = self.selected[(number, seat, 'powers', source['power_id'])]
            self.declarations[source['declaration_id']] = identity
            self.firing[(source['fire_round'], seat, source['power_id'])] = identity
            for scope, suffix in (('pending', 'main'), ('persistent', source['power_id'])):
                self.effects[instance_id(scope, source['declaration_id'], suffix)] = identity
            self.prices[instance_id('price', source['declaration_id'], 'main')] = identity
        work = plan['order'].get('castle_action', {})
        if work.get('action') == 'Work':
            self.work_targets[(seat, work['target_id'])] = self.selected[(number, seat, 'work', 'Work')]
        elif work.get('action') == 'Activate':
            self.activation_targets[(number, seat)] = work['target_id']
        for key, value in decision['budget']['used'].items(): self.max_work[key] = max(self.max_work[key], value)
        self.rejected_previews.extend(decision['rejected_previews'])
        if len(self.decision_examples) < 12:
            self.decision_examples.append(dict(round=number, seat=seat, score=decision['score'],
                plan=plan, reasons=decision['chosen_reasons'], retained_candidates=decision['retained_candidates'],
                budget=decision['budget'], veil=decision['veil']))

    def card_choice(self, number, seat, decision):
        identity = self.recorder.assess(number, seat, **decision['assessment'])
        self.recorder.outcome(identity, 'accepted-card-choice:'+fingerprint(decision['operation']), number, 'resolved')
        for key, value in decision['budget']['used'].items(): self.max_work[key] = max(self.max_work[key], value)

    def event(self, index, event, current_round):
        kind, d = event['type'], event['data']
        number, seat = d.get('round', current_round), d.get('player_id')
        identity = self.declarations.get(d.get('declaration_id')) or self.effects.get(d.get('effect_id'))
        event_id, metrics = 'semantic-row:'+str(index), {}
        if kind in ('POWER_RESOLVED', 'FIZZLE_INVALID_TARGET') and identity:
            self.recorder.outcome(identity, event_id, number, 'resolved' if kind == 'POWER_RESOLVED' else 'fizzled')
        if kind == 'MARCHER_SPAWNED':
            identity = self.effects.get(d.get('attributes', {}).get('source_effect_id'))
            if identity: metrics = dict(marchers_spawned=1)
        elif kind == 'PERSONAL_TEAR_CREATED' and d.get('source') in ('waiters', 'invocation', 'profane_ruins'):
            term = dict(waiters='Supplicants', invocation='Invocation', profane_ruins='ProfaneRuins')[d['source']]
            identity = self.selected.get((number, seat, 'rites', term))
            if identity: self._attach(identity, event_id, number, dict(personal_tears=d['amount']))
        elif kind == 'LORD_RESUMMONED':
            identity = self.selected.get((number, seat, 'resummon', 'Resummon'))
            if identity: self._attach(identity, event_id, number, dict(lords_returned=1, return_threat=d['return_threat']))
        elif kind == 'KANIFOUS_WISH_RESOLVED':
            identity = self.selected.get((number, seat, 'powers', d['power']))
            metrics = dict(wish_effect_count=d['count'], wish_success=int(d['success']))
        elif kind in ('KANIFOUS_PRICE_RESOLVED', 'KANIFOUS_PRICE_DEFERRED'):
            identity = self.prices.get(d['id'])
            metrics = {'price_'+d['outcome'].lower(): 1}
        elif kind == 'VALAK_PROJECTION_RESOLVED':
            identity = self.selected.get((number, seat, 'powers', 'Projection'))
            metrics = dict(essence_spent=d['spend'], guards_removed=int(bool(d['victim'])), whiffs=int(d['whiff']))
        elif kind in ('WEB_HIT', 'GUARD_RECONFIGURED', 'CASTLE_DEFUNCT') and identity:
            metrics = {dict(WEB_HIT='web_hits', GUARD_RECONFIGURED='guards_moved', CASTLE_DEFUNCT='castles_disabled')[kind]: 1}
        elif kind == 'CASTLE_DAMAGED' and identity:
            metrics = dict(castle_damage=d['damage'])
        elif kind in ('ROUT_APPLIED', 'ALLEGIANCE_SHIFT_RESOLVED') and identity:
            metrics = dict(affected_marchers=len(d['affected_ids']))
        elif kind == 'REDIRECT_RESOLVED' and identity:
            metrics = dict(redirected_marchers=len(d['changes']))
        elif kind == 'RECONFIGURATION_RESOLVED' and identity:
            metrics = dict(guard_changes=d['moved'])
        elif kind in ('ARTILLERY_FIRED', 'ARTILLERY_NO_TARGET'):
            identity = self.effects.get(d['shot'])
            if identity:
                metrics = dict(artillery_damage=d['damage'], castles_destroyed=int(d['destroyed'])) if kind == 'ARTILLERY_FIRED' else dict(artillery_damage=0)
        elif kind == 'HAZARD_PULSED':
            identity = self.effects.get(d['pulse_id']) or identity
            if identity: metrics = dict(hazard_affected_entities=len(d['affected_ids']))
        elif kind == 'GRAVITY_ORB_CONSUMED' and identity:
            metrics = dict(enemy_units_consumed=int(d['unit']['owner'] != seat), friendly_units_consumed=int(d['unit']['owner'] == seat))
        elif kind == 'RAVENOUS_ARMED':
            identity = self.firing.get((number, d['actor']['owner'], 'Ravenous'))
            if identity: self.actors[d['actor']['id']] = identity
        elif kind == 'MARCHER_DEVOURED':
            identity = self.actors.get(d['actor_id'])
            if identity:
                own = d['actor']['owner'] == d['before']['owner']
                metrics = dict(enemy_units_consumed=int(not own), friendly_units_consumed=int(own))
        elif kind == 'GUARD_DEVOURED' and d['cause'] == 'Consume':
            identity = self.firing.get((number, seat, 'Consume'))
            if identity: metrics = dict(guards_consumed=1, guard_value=d['before']['attributes']['value'])
        elif kind == 'SNARE_ACTIVE' and identity:
            metrics = dict(public_guard_limit=d['guard_limit'])
        elif kind == 'COMBAT_ORDER_FIZZLED':
            identity = next((self.selected[(number, seat, 'combat', term)] for term in ('Hunt', 'Siege', 'Profane')
                             if (number, seat, 'combat', term) in self.selected), None)
            if identity: self._attach(identity, event_id, number, outcome='fizzled')
        if identity and metrics: self.recorder.effect(identity, event_id, number, metrics)
        super().event(index, event, current_round)

    def report(self):
        result = super().report()
        result.update(alternative_search='bounded candidates and assembled plans',
            power_measurements='measured choices, terminal status and named effects; unobserved spatial benefit remains unknown',
            stockpile_slaver='accepted bounded card choices', maximum_work=dict(sorted(self.max_work.items())),
            rejected_previews=self.rejected_previews, decision_examples=self.decision_examples)
        return result


def run_case(spec, policy):
    match, observer = PowerMatch(spec['setup']), PlannerObserver(spec)
    cursor, operations, decisions_ns, simulation_ns = 0, [], 0, 0
    while match.outcome()['winner'] == -1:
        if match.clock.round > 40: raise ValueError('censored policy probe: '+spec['name'])
        number, hook = match.clock.round, match.clock.hook
        start = time.perf_counter_ns()
        decisions, card_choice = None, None
        if hook == 'submission_lock' and match._state['submissions'] == [None, None]:
            decisions = [policy.decide(observe(match, seat), Preview(match, seat)) for seat in (0, 1)]
            op = dict(kind='submit', plans=[d['plan'] for d in decisions])
        elif hook == 'present_public_state' and match._state['world']['data']['game_economy']['stockpile_pending']:
            seat = match._state['world']['data']['game_economy']['stockpile_pending']['player_id']
            card_choice = policy.choose_card(observe(match, seat), 'stockpile'); op = card_choice['operation']
        elif hook == 'present_public_state' and match._state['world']['data']['game_market']['seat'] != 2:
            seat = match._state['world']['data']['game_market']['seat']
            card_choice = policy.choose_card(observe(match, seat), 'slaver'); op = card_choice['operation']
        else: op = full_match_inputs.next_operation(match)
        decisions_ns += time.perf_counter_ns()-start
        start = time.perf_counter_ns(); result = match.apply(op); simulation_ns += time.perf_counter_ns()-start
        if result['action'] == 'invalid': raise ValueError((spec['name'], number, hook, op, result))
        operations.append(op)
        if decisions:
            for seat, decision in enumerate(decisions): observer.accepted(number, seat, decision)
        if card_choice: observer.card_choice(number, op['player_id'], card_choice)
        events = match._state['events']['rows']
        for i in range(cursor, len(events)): observer.event(i, events[i]['event'], number)
        cursor = len(events)
        if op['kind'] == 'step': observer.hook_completed(hook, number)
    semantic = dict(name=spec['name'], setup=spec['setup'], rounds=match.clock.round, operations=len(operations),
                    decisions_sha256=fingerprint(operations), final_state_sha256=digest(match),
                    outcome=match.outcome(), diagnostics=observer.report())
    return semantic, dict(name=spec['name'], decision_ms=decisions_ns/1e6, simulation_ms=simulation_ns/1e6), operations


def run(root, weights=None, output_inputs=None):
    root = Path(root); policy = CommonSmartCore(weights)
    evidence = json.loads((root/EVIDENCE).read_text())
    same('accepted Windows focused parity gate', evidence['status'], 'parity_prerequisite')
    games, times, inputs = [], [], []
    for spec in json.loads(power_inputs.PATH.read_text())['cases']:
        semantic, timing, operations = run_case(spec, policy)
        games.append(semantic); times.append(timing)
        inputs.append(dict(name=spec['name'], setup=spec['setup'], operations=operations))
        print(f"PASS planner {spec['name']}: {semantic['rounds']} rounds; {semantic['operations']} operations", flush=True)
    if output_inputs:
        Path(output_inputs).write_text(json.dumps(dict(policy=VERSION, scope='new alpha decisions, not native-accepted', cases=inputs), indent=2)+'\n')
    revision, engine = source_identity(root)
    semantic = dict(policy=VERSION, weights=asdict(policy.weights), limits=asdict(policy.limits),
        parity_evidence_revision=evidence['exact_comparison']['source_revision'],
        scope='five alpha behavior games on accepted rules; not new native decision parity, strength, balance or throughput evidence',
        games=games, failures=0)
    runner_hash = fingerprint({name: hashlib.sha256((root/'Scripts/Sim'/name).read_bytes().replace(b'\r\n', b'\n')).hexdigest()
                              for name in ('run_u13_common_doctrine.py', 'run_u13_common_doctrine.sh')})
    return dict(source_revision=revision, engine_source_sha256=engine, harness_source_sha256=harness_hash(root),
                runner_source_sha256=runner_hash, semantic=semantic, semantic_sha256=fingerprint(semantic), timings=times)


def compare_reports(first, second):
    for report in (first, second):
        same(0, report['semantic']['failures'], 'failures')
        same(fingerprint(report['semantic']), report['semantic_sha256'], 'report_integrity')
    for key in ('source_revision', 'engine_source_sha256', 'harness_source_sha256', 'runner_source_sha256', 'semantic', 'semantic_sha256', 'tests_passed'):
        same(first[key], second[key], 'runtime_comparison.'+key)
