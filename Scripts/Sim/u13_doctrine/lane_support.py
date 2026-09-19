"""Public lane geometry; conditional estimates, never a Marching rollout."""
from u13_pysim import field_combat


def mobile(a):
    return (a.get('step_fp', 0) > 0 and a.get('sprite_form') != 'turret'
            and (not a.get('hidden', False) or a.get('monster_id') == 'Dotra'))


def travel(a, number):
    if not mobile(a) or a.get('waiting') or a.get('movement_ready_round', 0) > number:
        return 0
    # Nominal unopposed distance, not a promise: pacing, walls, webs, targeting
    # and future enemies can all stop or alter actual movement.
    return 200*a['step_fp']


def free_to_advance(unit, enemies):
    a = unit['attributes']
    if not mobile(a) or a.get('waiting'):
        return False
    if field_combat.nearest(unit, enemies, 90, True):
        return False
    return not (a.get('suit') == 'Vulture' and field_combat.nearest(unit, enemies, 400))
