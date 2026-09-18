"""Bounded sensitivity checks for paid-choice settlement projections.

These are resource shocks, not predicted/validated enemy plans or probabilities.
They do not simulate combat, powers, Marching, or future random effects. Passing
the checks earns a planning preference, never a proof or a legality veto.
"""
from u13_pysim.copying import copy_data
from u13_pysim.lifecycle import evaluate
from .veil_judgment import paid_scenario

VERSION = 'U13_CLOSING_JUDGMENT_V1'


def judgment(f, plan, projected):
    result = dict(status='not_projected_win', checks=[], adverse=[], interrupted=[],
                  conditional_own_profane=plan['order'].get('action') == 'Profane')
    if projected['winner'] != f.pid:
        return result
    world = paid_scenario(f, plan)
    # One opposing Tear; ordinary Siege's maximum single-castle reward after
    # defeating a Guard; a successful Hunt's reward and victim loss. Include
    # Tear + combat together because paid Rites and combat can coexist.
    shocks = [('tear', 1, 0, 0, 0, False),
              ('siege_reward', 0, 3, 0, 1, False),
              ('hunt_reward', 0, 2, -1, 1, True),
              ('tear_and_siege_reward', 1, 3, 0, 1, False),
              ('tear_and_hunt_reward', 1, 2, -1, 1, True)]
    # Orias can add a Mark reward to Hunt. At Threat 2, a Guard defeat can
    # Accelerate to 3 before banishment. This remains a conditional stress,
    # not a claim that the hidden enemy commitment can break our defenses.
    if (f.v['players'][f.enemy]['lord_id'] == 'Orias'
            and f.lord[f.pid]['attributes'].get('threat', 0) >= 2):
        shocks.append(('tear_and_marked_hunt_reward', 1, 4, -1, 2, True))
    for name, tears, souls, own_souls, neutral, banished in shocks:
        scenario = copy_data(world)
        enemy = scenario['players'][f.enemy]['resources']
        own = scenario['players'][f.pid]['resources']
        enemy['personal_tears'] += tears
        enemy['souls'] += souls
        own['souls'] = max(0, own['souls']+own_souls)
        scenario['data']['neutral_tears'] += neutral
        if banished:
            scenario['entities']['entities'][f.pid]['attributes']['alive'] = False
        outcome = evaluate(scenario)
        result['checks'].append(dict(name=name, **outcome))
        if outcome['winner'] == f.enemy: result['adverse'].append(name)
        if outcome['winner'] == -1: result['interrupted'].append(name)
    result['status'] = ('resilient' if not result['adverse'] and not result['interrupted']
                        and not result['conditional_own_profane'] else 'fragile')
    return result


def prioritize(f, candidates):
    """Keep scores ordered for greedy and softmax; preserve every candidate.

    The priority increment exceeds this decision's complete score span, so a
    larger finite material weight cannot accidentally buy off a resilient win.
    Fragile wins retain the old 70-point credit: a hypothetical resource swing
    does not make the opposing order known or justify giving up a closing chance.
    """
    for candidate in candidates:
        closing = judgment(f, candidate['plan'], candidate['projected'])
        candidate['closing'] = closing
        candidate['base_score'] = candidate['score']
        closing['win_credit'] = 70 if candidate['projected']['winner'] == f.pid else 0
        candidate['score'] += closing['win_credit']
    stride = max(c['score'] for c in candidates)-min(c['score'] for c in candidates)+1
    for candidate in candidates:
        bonus = stride if candidate['closing']['status'] == 'resilient' else 0
        candidate['closing']['priority_bonus'] = bonus
        candidate['score'] += bonus


def report(candidates, chosen):
    return dict(version=VERSION, plans=len(candidates),
        projected_wins=sum(c['closing']['status'] != 'not_projected_win' for c in candidates),
        resilient_plans=sum(c['closing']['status'] == 'resilient' for c in candidates),
        fragile_plans=sum(c['closing']['status'] == 'fragile' for c in candidates),
        checks=sum(len(c['closing']['checks']) for c in candidates),
        selected=copy_data(chosen['closing']), base_score=chosen['base_score'],
        scope='public paid-choice settlement plus bounded resource shocks; not enemy orders, exhaustive outcomes, or win probabilities',
        hard_veto=False)
