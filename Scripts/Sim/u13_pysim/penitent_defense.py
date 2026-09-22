"""Independent seeded roll per incoming ranged hit, mirrored by native Godot."""
from .primitives import draw

CHANCE = 50


def blocks(target, attacker_id, seed, number, tick, kind):
    a = target['attributes']
    if target['kind'] != 'marcher' or a.get('suit') != 'Penitent' or 'monster_id' in a:
        return False
    key = f"{number}:{tick}:{kind}:{attacker_id}:{target['id']}"
    return draw(seed, key, 'PENITENT_RANGED_BLOCK', 0, 100) < CHANCE


def blocks_vulture_melee(target, attacker, seed, number, tick):
    a = attacker['attributes']
    return (attacker.get('kind') == 'marcher' and a.get('suit') == 'Vulture' and 'monster_id' not in a
            and blocks(target, attacker['id'], seed, number, tick, 'VultureMelee'))
