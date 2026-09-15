"""Clone owned U13 plain data without Python object-copy dispatch.

This is not validation or normalization. Callers supply the built-in dict/list
and immutable scalar data already admitted by the engine. Float bits, integer
types, container order and internal aliases are preserved; every mutable
container is detached from the source. No serialization or projections occur.
"""

SCALARS = (str, int, float, bool, type(None))


def copy_data(value):
    return _clone(value, {})


def _clone(item, memo):
    # A module-level function avoids a recursive closure retaining each copied
    # graph until cyclic garbage collection runs.
    kind = type(item)
    if kind is not dict and kind is not list:
        if kind not in SCALARS:
            raise TypeError("U13 copy requires plain data")
        return item
    identity = id(item)
    if identity in memo:
        return memo[identity]
    result = item.copy()
    memo[identity] = result
    entries = result.items() if kind is dict else enumerate(result)
    for key, child in entries:
        child_kind = type(child)
        if child_kind is dict or child_kind is list:
            result[key] = _clone(child, memo)
        elif child_kind not in SCALARS:
            raise TypeError("U13 copy requires plain data")
    return result
