"""Historical pursuit control and isolated native projects for balance audits.

These overrides are tooling only. No production rules import this module.
"""
from pathlib import Path

from .monster_effects import distance, enemies


def legacy_steer(unit, destination, rows, fields):
    """Exact U13_MONSTERS_V8_HUNT_WAYPOINT pursuit for before/after trials."""
    a = unit['attributes']
    if a.get('monster_id') != 'Tumler' or not destination: return destination
    obstacles = [dict(x_fp=r['attributes']['x_fp'], y_fp=r['attributes']['y_fp'], radius=180)
                 for r in enemies(unit, rows, 340)
                 if r['id'] != a.get('hunt_target', '') and distance(r['attributes'], destination) != 0]
    obstacles.extend(dict(x_fp=f['x_fp'], y_fp=f['y_fp'], radius=240) for f in fields
                     if f['kind'] == 'pool' and f['lane'] == a['lane'] and distance(a, f) <= 400*400)
    for obstacle in obstacles:
        if ((obstacle['x_fp']-a['x_fp'])*(destination['x_fp']-a['x_fp']) < 0
                or abs(obstacle['y_fp']-a['y_fp']) >= obstacle['radius']): continue
        side = -1 if a['y_fp'] <= obstacle['y_fp'] else 1
        y = max(30, min(570, obstacle['y_fp']+side*obstacle['radius']))
        if abs(y-obstacle['y_fp']) < obstacle['radius']//2:
            y = max(30, min(570, obstacle['y_fp']-side*obstacle['radius']))
        if a['x_fp'] == obstacle['x_fp'] and a['y_fp'] == y: continue
        return dict(x_fp=obstacle['x_fp'], y_fp=y)
    return destination


BODY_DETOUR_GD = '''\tfor other in enemies(unit, rows, 340):
\t\tif other.id != a.get("hunt_target", "") and distance(other.attributes, destination) != 0:
\t\t\tobstacles.append({"x_fp": other.attributes.x_fp, "y_fp": other.attributes.y_fp, "radius": 180})
'''


def native_project(destination, variant):
    """Create a NEW scratch project. Source checkout is never modified."""
    from .unit_balance import VARIANTS
    tuning = VARIANTS[variant]
    if tuning['pursuit'] == 'committed':
        raise ValueError('The discarded committed-hunt prototype has no native override; use current, direct or legacy pursuit')
    root = Path(__file__).resolve().parents[3]
    destination = Path(destination).resolve()
    destination.mkdir(parents=True, exist_ok=False)
    for source in root.iterdir():
        if source.name.startswith('.') or source.name in ('Scripts', 'project.godot'): continue
        (destination/source.name).symlink_to(source, target_is_directory=source.is_dir())
    scripts = destination/'Scripts'; scripts.mkdir()
    for source in (root/'Scripts').iterdir():
        if source.name != 'Sim': (scripts/source.name).symlink_to(source, target_is_directory=source.is_dir())
    sim = scripts/'Sim'; sim.mkdir()
    for source in (root/'Scripts/Sim').iterdir():
        if source.name != 'U13MonsterEffects.gd': (sim/source.name).symlink_to(source, target_is_directory=source.is_dir())
    text = (root/'Scripts/Sim/U13MonsterEffects.gd').read_text()
    if tuning['armor']:
        old = '"sprite_form": "turret", "attack": 3, "armor": 6, "max_armor": 6, "step_fp": 0'
        if text.count(old) != 1: raise ValueError('Review native Sooge override')
        armor = 6+tuning['armor']
        text = text.replace(old, old.replace('"armor": 6, "max_armor": 6', f'"armor": {armor}, "max_armor": {armor}'))
    if tuning['pursuit'] == 'direct': text = text.replace(BODY_DETOUR_GD, '')
    if tuning['pursuit'] == 'legacy' and BODY_DETOUR_GD not in text:
        marker = '\tvar obstacles: Array = []\n'
        if text.count(marker) != 1: raise ValueError('Review native legacy pursuit override')
        text = text.replace(marker, marker+BODY_DETOUR_GD)
    (sim/'U13MonsterEffects.gd').write_text(text)
    (destination/'project.godot').write_text('''[application]
config/name="U13 isolated unit balance experiment"
[rendering]
renderer/rendering_method="gl_compatibility"
[debug]
gdscript/warnings/integer_division=2
''')
    return str(destination)
