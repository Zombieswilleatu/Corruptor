"""Replay the Armor sweep and explicit depletion/roll boundaries in Godot."""
import argparse
import json
from pathlib import Path
from . import kurchin_armor_balance as audit, kurchin_armor_experiment as defense, codec
from . import verify_monster_pair_balance as native
from .copying import copy_data
from .primitives import draw


def project(path, chance):
    native.native_project(path, f'a6_d{chance}')
    file = path/'Scripts/Sim/U13MonsterEffects.gd'
    file.write_text(defense.native_source(file.read_text(), chance))


def export(path, chance):
    path.mkdir(parents=True, exist_ok=False)
    records = []
    selected = [s for s in audit.specs(1) if s['variant'].endswith(f'_d{chance}')
                and s['opponent'] in ('3_Butcher', '3_Vulture', '3_Wright', '8_balanced')]
    for spec in selected:
        audit.run(spec, export=records)
    checks = []

    def append(world, seed, label):
        before = copy_data(world)
        result, _ = audit.pairs.audit.resolve_round(world, seed, 1)
        records.append(dict(world=before, seed=seed, round=1, result=result))
        facts = [r['event'] for r in result['events']]
        return result, facts

    variant = f'a6_d{chance}'
    audit.install(variant)
    for seat in (0, 1):
        for kind in ('Melee', 'Vulture'):
            for armor in (0, 2):
                for roll in ((chance-1, chance) if chance else (0,)):
                    spec = dict(mode='armor_sweep', focus='Kurchin', opponent='boundary',
                        teams=[['Kurchin'], ['Butcher' if kind == 'Melee' else 'Vulture']],
                        variant=variant, sample=0, seat=seat, layout='contact')
                    world, meta, _ = audit.initial(spec)
                    tank = next(u for u in world['entities']['entities'] if meta[u['id']]['group'] == 0)
                    foe = next(u for u in world['entities']['entities'] if meta[u['id']]['group'] == 1)
                    tank['attributes'].update(hp=100, max_hp=100, armor=armor, max_armor=armor, step_fp=0)
                    foe['attributes'].update(hp=100, max_hp=100, step_fp=0)
                    if kind == 'Vulture':
                        foe['attributes'].update(x_fp=tank['attributes']['x_fp']+250, y_fp=300)
                    key = f"1:0:{kind}:{foe['id']}:{tank['id']}"
                    seed = next(f'armor-boundary:{i}' for i in range(10000)
                        if draw(f'armor-boundary:{i}', key, 'KURCHIN_ARMORED_DEFLECTION', 0, 100) == roll)
                    result, facts = append(world, seed, 'boundary')
                    hits = [e['data'] for e in facts if e['type'] in ('MARCHER_MELEE_ATTACK', 'MARCHER_RANGED_ATTACK')
                            and e['data']['target']['id'] == tank['id']]
                    expected = armor > 0 and roll < chance
                    assert hits and hits[0]['evaded'] == expected, (chance, kind, armor, roll, hits[:1])
                    remaining = armor
                    for hit in hits:
                        if hit['evaded']:
                            assert remaining > 0 and hit['damage_dealt'] == 0
                        else:
                            raw = 3 if kind == 'Melee' else 1
                            consumed = min(remaining, raw)
                            assert hit['damage_dealt'] == raw-consumed
                            remaining -= consumed
                    after = next(u for u in result['world']['entities']['entities'] if u['id'] == tank['id'])
                    assert after['attributes']['armor'] == remaining
                    checks.append(dict(seat=seat, kind=kind, armor=armor, roll=roll,
                        expected_deflection=expected, attacks_checked=len(hits)))

        # Armor defense remains active during fear for direct abilities;
        # ongoing poison stays undodgeable, including when Armor remains.
        spec = dict(mode='armor_sweep', focus='Kurchin', opponent='fear', teams=[['Kurchin'], ['Muno']],
            variant=variant, sample=0, seat=seat, layout='contact')
        world, meta, _ = audit.initial(spec)
        tank = next(u for u in world['entities']['entities'] if meta[u['id']]['group'] == 0)
        foe = next(u for u in world['entities']['entities'] if meta[u['id']]['group'] == 1)
        tank['attributes'].update(x_fp=1000, y_fp=300, hp=100, max_hp=100, armor=100, max_armor=100)
        foe['attributes'].update(x_fp=1120, y_fp=300, hp=100, max_hp=100, armor=0)
        world['data']['monsters']['fields'] = [dict(kind='portal', id='armor-fear-portal', owner=1-seat,
            lane='Lord', x_fp=800, y_fp=300, expires_round=2)]
        tank['attributes'].update(poison_until_round=1, poison_source=copy_data(foe))
        key = f"1:0:Muno:{foe['id']}:{tank['id']}"
        seed = next(f'armor-fear:{i}' for i in range(10000)
            if draw(f'armor-fear:{i}', key, 'KURCHIN_ARMORED_DEFLECTION', 0, 100) == max(0, chance-1))
        result, facts = append(world, seed, 'fear')
        hits = [e['data'] for e in facts if e['type'] == 'MONSTER_ATTACK' and e['data']['target']['id'] == tank['id']]
        assert any(h['ability'] == 'Muno' and h.get('evaded') == (chance > 0) for h in hits)
        assert any(h['ability'] == 'Poison' and not h.get('evaded') for h in hits)
        checks.append(dict(seat=seat, kind='fear_ability_and_poison', attacks_checked=len(hits)))

    with (path/'inputs.jsonl').open('w') as inputs, (path/'expected.jsonl').open('w') as expected:
        for r in records:
            inputs.write(json.dumps({k:r[k] for k in ('world', 'seed', 'round')})+'\n')
            expected.write(codec.dumps(r['result'])+'\n')
    summary = dict(chance=chance, representative_battles=len(selected), phases=len(records), boundary_cases=checks)
    (path/'coverage.json').write_text(json.dumps(summary, indent=2)+'\n')
    print(json.dumps(dict(chance=chance, battles=len(selected), phases=len(records), boundary_cases=len(checks))))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=['project', 'export', 'compare'])
    parser.add_argument('path', type=Path)
    parser.add_argument('chance', nargs='?', type=int, choices=[0, 50, 75])
    args = parser.parse_args()
    if args.action == 'project': project(args.path, args.chance)
    elif args.action == 'export': export(args.path, args.chance)
    else: native.compare(args.path)
