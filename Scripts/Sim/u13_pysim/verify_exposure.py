"""Compare native damage adapters with the independent Python simulation."""
import json
import sys
from . import codec, marching, monster_effects, field_combat, powers
from .battle import Battle
from .marching_buffer import Buffer
from .lifecycle import RoundRules
from .copying import copy_data
from .verify import same


def verify(path):
    count = 0
    for line in open(path, encoding='utf-8'):
        record = codec.loads(line)
        c, options = record['context'], record['options']
        phase = marching.Phase(c, False, RoundRules.march_reaction, keep_background=True)
        operation = record['operation']
        tick = options.get('tick', 0)
        if operation == 'packet':
            result = monster_effects.damage(phase.w, Buffer(phase), copy_data(options['hit']), c, tick, RoundRules.march_reaction)
            result = {k: result[k] for k in ('world', 'events')}
        elif operation in ('melee', 'ranged'):
            if operation == 'melee': field_combat.melee(phase, tick, {})
            else: field_combat.volley(phase, {}, tick, {})
            result = dict(world=phase.w, events=phase.events)
        elif operation == 'hazard':
            battle = Battle(phase.w, c['round'], c['seed'], c['player_order'], c['hook'])
            events = powers.pulse(battle, options['active'], 'exposure-hazard')
            result = dict(world=battle.w, events=events)
        elif operation == 'reaction':
            resolved = RoundRules.march_reaction(phase.w, options['fact'], c['seed'], c['player_order'])
            result = {k: resolved[k] for k in ('world', 'events')}
        elif operation == 'web':
            state = dict(world=phase.w, seed=c['seed'], player_order=c['player_order'])
            resolved = powers.resolve(options['record'], state, c['round'])
            result = dict(world=state['world'], events=resolved['events'])
        else:
            raise ValueError(operation)
        same(record['result'], result, record['name'])
        count += 1
        print('PARITY', record['name'], flush=True)
    return dict(damage_adapter_cases=count, complete_world_and_events_match=True)


if __name__ == '__main__':
    print(json.dumps(verify(sys.argv[1])))
