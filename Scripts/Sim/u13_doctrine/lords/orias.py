"""Orias: Web current enemies; trade Threat for a useful next-round Guard cap.

Passives: shared Hunt estimates include public Pursuit. Snare adds Threat now;
its delayed cap never counts as removing already deployed Guards.
"""
from ..facts import LANES, power

LORD = 'Orias'


def proposals(f):
    for lane in LANES:
        target, count = f.cluster(lane, 270, friendly_penalty=0)
        if target:
            yield power('Web', target, 12*count, 'web_visible_enemy_cluster')
    vacancies = sum(len(f.free(f.enemy, lane)) for lane in LANES)
    threat = f.lord[f.pid]['attributes'].get('threat', 0)
    if vacancies >= 2 and threat < 3:
        yield power('Snare', dict(player_id=f.enemy), 6*vacancies-6*threat, 'next_round_reinforcement_cap_costs_threat')
