"""Incoming modifiers: exposure on packets, Rout on regular attacks only."""

ROUT_RETREAT_ATTACK_BONUS = 1


def active(a, clock):
    return a.get('dotra_exposed_from_tick', 0) <= clock < a.get('dotra_exposed_until_tick', 0)


def amount(a, base, clock):
    return max(0, base) + int(base > 0 and active(a, clock))


def regular_amount(a, base, clock, rout_round=None):
    """Rout adds one before Armor only in its retreat round, not recovery.

    The optional round comes from the compact Marching columns; ordinary
    field combat supplies the complete attributes. Blocks/evasion bypass this
    helper, and zero-damage attacks never become positive damage packets.
    """
    applied = a.get('rout_round', -1) if rout_round is None else rout_round
    bonus = ROUT_RETREAT_ATTACK_BONUS if base > 0 and applied == clock//200 else 0
    return amount(a, base, clock) + bonus


def phase_clock(world, number):
    return number * 200 + (200 if world['data'].get('marching_round', 0) >= number else 0)


def valid(a):
    return all(type(a.get(k, 0)) is int and 0 <= a.get(k, 0) <= 9007199254740991
               for k in ('dotra_exposed_from_tick', 'dotra_exposed_until_tick')) and a.get('dotra_exposed_until_tick', 0) >= a.get('dotra_exposed_from_tick', 0)
