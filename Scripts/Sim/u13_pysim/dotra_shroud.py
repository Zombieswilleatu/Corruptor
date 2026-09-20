"""Visible, temporary untargetability after Dotra's ambush; not damage immunity."""


def active(a, clock=-1):
    until = a.get('dotra_shroud_until_tick', 0)
    return (a.get('monster_id') == 'Dotra' and until > 0
            and (clock < 0 or a.get('dotra_shroud_from_tick', 0) <= clock < until))


def targetable(a):
    return not a.get('hidden', False) and not active(a)


def valid(a):
    return (all(type(a.get(k, 0)) is int and 0 <= a.get(k, 0) <= 9007199254740991
                for k in ('dotra_shroud_from_tick', 'dotra_shroud_until_tick'))
            and a.get('dotra_shroud_until_tick', 0) >= a.get('dotra_shroud_from_tick', 0))
