"""Experimental attack cooldowns; production code never imports this module."""
import inspect
from . import field_combat


def install(melee, ranged):
    assert melee > 0 and ranged > 0
    for name in ('melee', 'volley'):
        function = getattr(field_combat, name)
        source = getattr(function, '_audit_source', None) or inspect.getsource(function)
        changes = [('clock+8', f'clock+{melee}', 2)] if name == 'melee' else [('clock+32', f'clock+{ranged}', 2), ('clock+8', f'clock+{melee}', 1)]
        for old, new, count in changes:
            assert source.count(old) == count, (name, old, 'review cooldown override')
            source = source.replace(old, new)
        namespace = function.__globals__.copy()
        exec(compile(source, '<cadence-audit:'+name+'>', 'exec'), namespace)
        namespace[name]._audit_source = source
        setattr(field_combat, name, namespace[name])


def native(change, melee, ranged):
    change('U13FieldMelee.gd', 'const INTERVAL: int = 8', f'const INTERVAL: int = {melee}')
    change('U13RangedMarching.gd', 'const EXCHANGE_TICKS: int = 8', f'const EXCHANGE_TICKS: int = {melee}')
    change('U13RangedMarching.gd', 'const RANGED_INTERVAL_TICKS: int = 32', f'const RANGED_INTERVAL_TICKS: int = {ranged}')
