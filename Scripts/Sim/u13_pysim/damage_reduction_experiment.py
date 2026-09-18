"""Isolated Kurchin mitigation overrides; never imported by production simulation.

Positive incoming damage is reduced before Armor, with a minimum of one.
Blocked, evaded and zero-damage attacks stay zero. Events expose prevention
separately so audit metrics do not mistake it for consumed Armor.
"""
import inspect
from . import field_combat, monster_effects


def amount(target, raw, reduction):
    return max(1, raw-reduction) if raw > 0 and target['attributes'].get('monster_id') == 'Kurchin' else raw


def replace_once(source, old, new):
    assert source.count(old) == 1, ('Review mitigation override', old)
    return source.replace(old, new)


def install(reduction):
    for module, name in ((field_combat, 'melee'), (field_combat, 'volley'), (monster_effects, 'damage')):
        source = inspect.getsource(getattr(module, name))
        if name == 'melee':
            source = replace_once(source, 'dealt, hp_after, evaded = 0, 0, False', 'dealt, hp_after, evaded, reduced = 0, 0, False, 0')
            old = "amount = 0 if evaded else shot['amount']"
            source = replace_once(source, old, old+"\n                reduced = amount-mitigate(target, amount); amount -= reduced")
            old = "damage_dealt=dealt, evaded=evaded, hp_after=hp_after, round=number"
        elif name == 'volley':
            source = replace_once(source, 'dealt, hp_after, blocked, evaded = 0, 0, False, False', 'dealt, hp_after, blocked, evaded, reduced = 0, 0, False, False, 0')
            old = "amount = 0 if blocked or evaded else shot['amount']; absorbed"
            source = replace_once(source, old, "amount = 0 if blocked or evaded else shot['amount']; reduced = amount-mitigate(target, amount); amount -= reduced; absorbed")
            old = 'blocked=blocked, evaded=evaded, damage_dealt=dealt, hp_after=hp_after'
        else:
            old = "amount=0 if blocked or evaded else hit['amount'];absorbed"
            source = replace_once(source, old, "amount=0 if blocked or evaded else hit['amount'];reduced=amount-mitigate(target,amount);amount-=reduced;absorbed")
            old = "blocked=blocked,evaded=evaded,damage_dealt=dealt,hp_after=a['hp']"
        source = replace_once(source, old, old+', damage_reduced=reduced')
        namespace = module.__dict__.copy()
        namespace['mitigate'] = lambda target, raw: amount(target, raw, reduction)
        exec(compile(source, '<pair-audit:kurchin-mitigation>', 'exec'), namespace)
        setattr(module, name, namespace[name])


def native(change, reduction):
    """Patch only copied files in a disposable native verification project."""
    for file, name in (('U13FieldMelee.gd', 'melee'), ('U13RangedMarching.gd', 'volley'), ('U13MonsterEffects.gd', 'damage')):
        if name == 'damage':
            old = '\tvar amount: int = 0 if blocked or evaded else int(hit.amount)'
            new = old+f'\n\tvar damage_reduced: int = mini({reduction}, maxi(0, amount-1)) if target.attributes.get("monster_id") == "Kurchin" else 0\n\tamount -= damage_reduced'
            change(file, old, new)
            old = '"blocked": blocked, "evaded": evaded, "damage_dealt": dealt, "hp_after": target.attributes.hp'
            change(file, old, old+', "damage_reduced": damage_reduced')
        else:
            change(file, '\t\tvar evaded: bool = false', '\t\tvar evaded: bool = false\n\t\tvar damage_reduced: int = 0')
            indent = '\t\t\t\t' if name == 'melee' else '\t\t\t'
            old = indent+('var amount: int = 0 if evaded else int(shot.amount)' if name == 'melee' else 'var amount: int = 0 if blocked or evaded else int(shot.amount)')
            new = old+f'\n{indent}damage_reduced = mini({reduction}, maxi(0, amount-1)) if target.attributes.get("monster_id") == "Kurchin" else 0\n{indent}amount -= damage_reduced'
            change(file, old, new)
            if name == 'melee':
                old = '"damage_dealt": dealt, "evaded": evaded, "hp_after": hp_after, "round": context.round'
                change(file, old, old+', "damage_reduced": damage_reduced')
            else:
                change(file, 'events.append(event("MARCHER_RANGED_ATTACK", details))', 'details["damage_reduced"] = damage_reduced\n\t\tevents.append(event("MARCHER_RANGED_ATTACK", details))')
