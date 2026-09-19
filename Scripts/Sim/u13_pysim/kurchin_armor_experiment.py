"""Armor-gated deflection in disposable balance experiments only.

A deflected direct attack consumes neither Armor nor HP. A landed attack uses
normal damage rules, including overflow. At zero Armor, deflection stops.
Poison and banishment retain their rules. Production never imports this file.
"""
import inspect
from . import monster_effects as fx
from .primitives import draw


def install(chance):
    base = fx.evades

    def evades(unit, source, rows, context, tick, kind, structures=(), fleeing=()):
        a = unit['attributes']
        if a.get('monster_id') == 'Kurchin':
            if a['armor'] <= 0 or kind == 'Poison':
                return False
            key = f"{context['round']}:{tick}:{kind}:{source['id']}:{unit['id']}"
            return draw(context['seed'], key, 'KURCHIN_ARMORED_DEFLECTION', 0, 100) < chance
        return base(unit, source, rows, context, tick, kind, structures, fleeing)

    fx.evades = evades
    # Armor, rather than movement/fear, gates this defense. Keep Tumler's
    # existing fear rule while allowing Kurchin to deflect direct abilities.
    source = inspect.getsource(fx.damage)
    old = 'evaded=not fleeing and evades('
    assert source.count(old) == 1
    source = source.replace(old, "evaded=(not fleeing or a.get('monster_id')=='Kurchin') and evades(")
    namespace = fx.damage.__globals__.copy()
    namespace['evades'] = evades
    exec(compile(source, '<kurchin-armor-experiment>', 'exec'), namespace)
    fx.damage = namespace['damage']


def native_source(source, chance):
    old = '\tif kind == "Poison" or fleeing.has(unit.id) or not hunting(unit, rows, context.round, structures): return false'
    assert source.count(old) == 1
    branch = '''\tif unit.attributes.get("monster_id") == "Kurchin":
\t\tif int(unit.attributes.armor) <= 0 or kind == "Poison": return false
\t\tvar deflection_key: String = "%d:%d:%s:%s:%s" % [context.round, tick, kind, source.id, unit.id]
\t\treturn Lamp.draw(context.seed, deflection_key, "KURCHIN_ARMORED_DEFLECTION", 100) < CHANCE
'''.replace('CHANCE', str(chance))
    source = source.replace(old, branch + old)
    old = 'var evaded: bool = not fleeing and evades('
    assert source.count(old) == 1
    return source.replace(old, 'var evaded: bool = (not fleeing or target.attributes.get("monster_id") == "Kurchin") and evades(')
