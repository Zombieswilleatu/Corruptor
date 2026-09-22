"""Incoming modifiers: exposure, Rout attacks, and one-use afterimages."""

ROUT_RETREAT_ATTACK_BONUS = 1


def active(a, clock):
    return a.get('dotra_exposed_from_tick', 0) <= clock < a.get('dotra_exposed_until_tick', 0)


def amount(a, base, clock):
    return max(0, base) + int(base > 0 and active(a, clock))


def regular_amount(a, base, clock, rout_round=None, round_number=None):
    """Rout adds one before Armor only in its retreat round, not recovery.

    The optional round comes from the compact Marching columns; ordinary
    field combat supplies the complete attributes. Blocks/evasion bypass this
    helper, and zero-damage attacks never become positive damage packets.
    """
    applied = a.get('rout_round', -1) if rout_round is None else rout_round
    bonus = ROUT_RETREAT_ATTACK_BONUS if base > 0 and applied == (clock//200 if round_number is None else round_number) else 0
    return amount(a, base, clock) + bonus


def apply(a, base, clock, regular=False, rout_round=None, round_number=None):
    """Consume one ward on a positive packet; forecasts keep using amount()."""
    incoming = regular_amount(a, base, clock, rout_round, round_number) if regular else amount(a, base, clock)
    if incoming > 0 and a.get('muno_ward', False):
        a['muno_ward'] = False
        return 0
    return incoming


def phase_clock(world, number):
    if 'marching_clock' in world['data']: return world['data']['marching_clock']
    return number * 200 + (200 if world['data'].get('marching_round', 0) >= number else 0)


def valid(a):
    if 'muno_ward' in a and (type(a['muno_ward']) is not bool or a.get('monster_id') != 'Muno'):
        return False
    return all(type(a.get(k, 0)) is int and 0 <= a.get(k, 0) <= 9007199254740991
               for k in ('dotra_exposed_from_tick', 'dotra_exposed_until_tick')) and a.get('dotra_exposed_until_tick', 0) >= a.get('dotra_exposed_from_tick', 0)
