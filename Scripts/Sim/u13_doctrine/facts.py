"""Shared public facts and conservative current-board estimates, never rollouts."""
from collections import Counter
from dataclasses import dataclass

from u13_pysim import split_ward
from u13_pysim.battle import defense, operational, targetable
from u13_pysim.castle_balance import PENITENT_PAIR_SCREEN
from u13_pysim.development import intact
from u13_pysim.power_rules import RULES

LANES = ('Lord', 'Castle')


@dataclass
class Proposal:
    category: str
    term: str
    payload: dict
    value: int
    reason: str
    cards: tuple = ()
    memory_bonus: int = 0


def power(name, target, value, reason, cards=(), **parameters):
    return Proposal('powers', name, dict(target=target, parameters=parameters), value, reason, tuple(cards))


def kroni_hunt_bonus(attributes, result):
    """Bounded value of suppressing hungry Kroni; never changes attack strength."""
    if attributes.get('lord_id') != 'Kroni' or not attributes.get('alive'):
        return 0
    tier = min(3, max(0, attributes.get('hunger', 0)))
    if result['banished']:
        return 8*tier
    return 3*tier*min(2, result['guards'])


class Facts:
    def __init__(self, view):
        from .opponent_memory import profile
        self.opponent = profile(view)
        self.v, self.pid = view, view['player_id']
        self.enemy = 1-self.pid
        self.rows = sorted(view['board'], key=lambda r: r['id'])
        self.by_id = {r['id']: r for r in self.rows + view['hand']}
        self.hand = sorted(view['hand'], key=lambda r: (r['attributes']['value'], r['id']))
        self.lord = [next(r for r in self.rows if r['kind'] == 'lord' and r['owner'] == p) for p in (0, 1)]
        self.kind = self.lord[self.pid]['attributes']['lord_id']
        self.resources = view['players'][self.pid]['resources']
        self.world = dict(players=view['players'], data=view['data'], entities=dict(entities=self.rows))
        self.veil = view['data']['neutral_tears'] + sum(p['resources']['personal_tears'] for p in view['players'])

    def units(self, seat, lane):
        return [r for r in self.rows if r['kind'] == 'marcher' and r['owner'] == seat
                and r['attributes']['lane'] == lane and r['attributes']['hp'] > 0]

    def guards(self, seat, lane):
        return [r for r in self.rows if r['kind'] == 'card' and r['owner'] == seat
                and r['attributes']['lane'] == lane]

    def castles(self, seat):
        return sorted((r for r in self.rows if r['kind'] == 'castle' and r['owner'] == seat),
                      key=lambda r: (r['attributes']['castle_slot'], r['id']))

    def free(self, seat, lane):
        occupied = {r['attributes']['slot'] for r in self.guards(seat, lane)}
        return [i for i in range(3) if i not in occupied]

    def available(self, name):
        from u13_pysim import veil
        if RULES[name].get('breach_wish',False):
            return (True, 'breach_wish_ready') if veil.affects(self.world, 'Kanifous', self.pid) else (False, 'breach_wish_unavailable')
        if not self.lord[self.pid]['attributes']['alive']:
            return False, 'source_banished'
        clock = next((r for r in self.v['cooldowns'] if r['declaration']['player_id'] == self.pid
                      and r['declaration']['power_id'] == name), None)
        active = self.active(name)
        if name == 'Inferno' and active and clock and clock['phase'] == 'awaiting_expiration':
            if self.v['round']+RULES[name]['delay_rounds'] >= active['activated_round']+len(active['stages']):
                return False, 'relocation_would_fire_after_expiration'
            return True, 'relocation_available'
        if clock or active:
            return False, 'cooldown_or_active'
        if any(self.resources.get(k, 0) < v for k, v in RULES[name]['cost'].items()):
            return False, 'resource_shortfall'
        return True, 'ready'

    def active(self, name):
        return next((r for r in self.v['persistent'] if r['declaration']['player_id'] == self.pid
                     and r['declaration']['power_id'] == name), None)

    def cluster(self, lane, radius, friendly_penalty=1):
        enemies, own = self.units(self.enemy, lane), self.units(self.pid, lane)
        def near(a, b):
            return ((a['x_fp']-b['x_fp'])**2 + (a['y_fp']-b['y_fp'])**2 <= radius*radius)
        scored = [(sum(near(r['attributes'], p['attributes']) for r in enemies)
                   - friendly_penalty*sum(near(r['attributes'], p['attributes']) for r in own), p)
                  for p in enemies]
        if not scored:
            return None, 0
        score, row = min(scored, key=lambda x: (-x[0], x[1]['id']))
        a = row['attributes']
        return dict(lane=lane, field_position=dict(x_fp=a['x_fp'], y_fp=a['y_fp'])), score

    def lane_need(self, lane):
        return max(0, len(self.units(self.enemy, lane))-len(self.units(self.pid, lane)))

    def payment(self, minimum, exempt=None):
        # Linear ordered prefix, never all hand subsets. The full-budget and
        # minimum-sufficient proposals give conservation an explicit candidate.
        ordered = sorted(self.hand, key=lambda r: (-r['attributes']['value'], r['id']))
        selected, total = [], 0
        for r in ordered:
            if total >= minimum: break
            selected.append(r['id'])
            a = r['attributes']
            total += a['value']
        return selected if total >= minimum else []

    def strength(self, ids, action):
        return sum(self.by_id[k]['attributes']['value'] for k in ids)

    def recruits(self, ids, action):
        suits = Counter()
        for key in ids:
            a = self.by_id[key]['attributes']; suits[a['suit']] += a['value']
        return sum(v // (2 if action == 'Ward' else 3) for v in suits.values())

    def attack_targets(self):
        """One legal public target per attack type, shared by recipe plans."""
        if self.lord[self.enemy]['attributes']['alive']:
            yield 'Hunt', 'Lord', self.lord[self.enemy]['id']
        castles = [c for c in self.castles(self.enemy) if targetable(c)]
        victim = min(castles, key=lambda c: (c['attributes']['integrity'], c['attributes']['castle_slot'])) if castles else None
        yield 'Siege', 'Castle', victim['id'] if victim else 'castle_zone:'+str(self.enemy)

    def attack_value(self, action, target, ids, weights):
        result = self.attack(action, target, ids)
        return (weights.recruit*self.recruits(ids, action)+12*result['guards']+weights.damage*result['damage']
                +weights.banishment*result['banished']+weights.destruction*result['destroyed']+12*result['pillage']
                +result['kroni_pressure_bonus']+result['orias_hunt_bonus'])

    def attack(self, action, target, ids, excluded_waiters=()):
        """Baseline layers only. Enemy orders and spatial reactions are unknown."""
        lane = 'Lord' if action == 'Hunt' else 'Castle'
        strength = self.strength(ids, action) + split_ward.attack_bonus(self.world)
        if action == 'Hunt' and self.kind == 'Orias' and self.lord[self.pid]['attributes']['alive']:
            strength += 1 + int(self.lord[self.enemy]['attributes'].get('threat', 0) >= 2)
        strength += sum(r['attributes']['waiting'] and r['id'] not in excluded_waiters for r in self.units(self.pid, lane))
        remaining, lost, damage, banished, destroyed = strength, 0, 0, False, False
        castle_hits = {}
        for pair in self.v['data']['guard_work']['pairs']:
            if pair['player_id'] == self.enemy and pair['lane'] == lane and pair['suit'] == 'Penitent' and intact(self.world, pair):
                remaining = max(0, remaining-PENITENT_PAIR_SCREEN)
        if lane == 'Lord' and self.lord[self.enemy]['attributes']['lord_id'] == 'Valak' and self.lord[self.enemy]['attributes']['alive']:
            remaining = max(0, remaining-self.v['players'][self.enemy]['resources']['life_essence'])
        for guard in sorted(self.guards(self.enemy, lane), key=lambda r: (-r['attributes']['value'], r['attributes']['slot'])):
            if remaining <= guard['attributes']['value']:
                remaining = 0; break
            remaining -= guard['attributes']['value']; lost += 1
        castles = [c for c in self.castles(self.enemy) if targetable(c)]
        pillage = action == 'Siege' and not castles
        if not pillage:
            sigil = '' if split_ward.enabled(self.world) else self.v['data']['sigils'][self.enemy][lane]
            remaining = max(0, remaining-(2 if sigil == 'fresh' else 1 if sigil else 0))
        if action == 'Hunt':
            keep = next((c for c in castles if c['attributes']['castle_type'] == 'Keep'), None)
            if keep and remaining:
                remaining = max(0, remaining-(3 if operational(keep) else 0))
                damage = min(remaining, keep['attributes']['integrity']); remaining -= damage
                castle_hits[keep['id']] = damage
            victim = self.lord[self.enemy]
            # Accelerate fires on the first credited Lord-guard defeat, before
            # the final Lord defense check. Pursuit was already fixed above.
            if self.kind == 'Orias' and self.lord[self.pid]['attributes']['alive'] and lost and victim['attributes']['lord_id'] != 'Humbaba':
                victim = dict(victim, attributes=dict(victim['attributes'], threat=victim['attributes'].get('threat',0)+1))
            banished = remaining > defense(self.world, victim)
        elif not pillage:
            victim = self.by_id[target]
            bastion = next((c for c in castles if c['attributes']['castle_type'] == 'Bastion'), None)
            if bastion and victim['attributes']['castle_type'] != 'Bastion':
                hit = min(remaining, bastion['attributes']['integrity']); damage += hit; remaining -= hit
                castle_hits[bastion['id']] = hit
            hit = min(remaining, victim['attributes']['integrity']); damage += hit
            castle_hits[victim['id']] = hit
            destroyed = remaining > 0 and hit == victim['attributes']['integrity']
        result = dict(strength=strength, guards=lost, damage=damage, banished=banished,
                      destroyed=destroyed, pillage=pillage and remaining > 0, castle_hits=castle_hits)
        result['kroni_pressure_bonus'] = (kroni_hunt_bonus(self.lord[self.enemy]['attributes'], result)
                                            if action == 'Hunt' else 0)
        result['orias_hunt_bonus'] = self.orias_hunt_value(result) if action == 'Hunt' else 0
        return result

    def orias_hunt_value(self, result):
        """Finite value for Orias's realized Hunt effects; no empty-attack bonus."""
        if self.kind != 'Orias' or not self.lord[self.pid]['attributes']['alive']:
            return 0
        enemy = self.lord[self.enemy]['attributes']
        if not enemy['alive']: return 0
        keep = next((c for c in self.castles(self.enemy) if c['attributes']['castle_type']=='Keep'
                     and targetable(c) and c['attributes']['integrity']>0),None)
        guards = result['guards']; banished = result['banished']
        broken = bool(keep and result['castle_hits'].get(keep['id'],0)>=keep['attributes']['integrity'])
        threat = enemy.get('threat',0)
        accelerates = bool(guards and enemy['lord_id']!='Humbaba')
        marked = banished and enemy['lord_id']!='Humbaba' and threat+int(accelerates)>=3
        # Keep destruction was represented only as damage in the shared Hunt
        # score. Mark pays two extra Souls; repeated banishments also deny powers.
        return (30*broken + 24*banished + 24*marked
                +6*int(accelerates and threat<4)
                +(8*min(2,guards) if not keep else 0))
