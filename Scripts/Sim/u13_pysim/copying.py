"""Clone owned U13 plain data without Python object-copy dispatch.

This is not validation or normalization. Callers supply the built-in dict/list
and immutable scalar data already admitted by the engine. Float bits, integer
types, container order and internal aliases are preserved; every mutable
container is detached from the source. No serialization or projections occur.
"""

SCALARS = (str, int, float, bool, type(None))


def copy_data(value):
    return _clone(value, {})


class RollbackSnapshot:
    """Rollback storage, distinct from a fully detached public snapshot.

    share_history is only for owned FullMatch dispatch: old event rows and the
    presentation world are disjoint from mutable authority and never edited.
    The history list itself is copied, so appends roll back normally. A live
    state escape upgrades this backup before exposing either shared subtree.
    """

    def __init__(self, state, share_history=False):
        self.shared = share_history
        memo = {}
        if share_history:
            rows = state["events"]["rows"]
            presentation = state["presentation_world"]
            memo[id(rows)] = rows.copy()
            memo[id(presentation)] = presentation
        self.state = _clone(state, memo)

    def detach(self):
        if self.shared:
            detached = copy_data(self.state)
            # _apply already holds this dictionary as rollback_state.
            self.state.clear()
            self.state.update(detached)
            self.shared = False


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
