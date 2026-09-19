"""Nonstacking exposure: one extra point per positive packet before Armor."""


def active(a, clock):
    return a.get('dotra_exposed_from_tick', 0) <= clock < a.get('dotra_exposed_until_tick', 0)


def amount(a, base, clock):
    return max(0, base) + int(base > 0 and active(a, clock))


def phase_clock(world, number):
    return number * 200 + (200 if world['data'].get('marching_round', 0) >= number else 0)


def valid(a):
    return all(type(a.get(k, 0)) is int and 0 <= a.get(k, 0) <= 9007199254740991
               for k in ('dotra_exposed_from_tick', 'dotra_exposed_until_tick')) and a.get('dotra_exposed_until_tick', 0) >= a.get('dotra_exposed_from_tick', 0)
