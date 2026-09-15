"""Owned phase columns; immutable entity IDs never become recyclable slots.

All mutable Marcher values live in parallel lists. Boundary dictionaries are
materialized only for events, snapshots and explicit reaction callbacks.
This is ordinary CPython, with no NumPy/native dependency or vectorization claim.
"""

from .copying import copy_data
from .primitives import Entities, IDS_VERSION

FIELDS = ("attack", "armor", "regen", "step_fp", "armor_bypass", "suit", "lane",
          "hp", "max_hp", "birth_round", "movement_ready_round", "x_fp", "y_fp",
          "contact_tick", "direction", "waiting", "waiting_since_round",
          "ranged_next_tick", "melee_next_tick", "rout_round", "rout_effect_id")


class Columns:
    def __init__(self, raw):
        checked = Entities()
        checked.restore(raw)
        rows = [checked.rows[key] for key in sorted(checked.rows)]
        if any(row["kind"] != "marcher" for row in rows):
            raise ValueError("The isolated Marching kernel accepts Marchers only")
        self.ids = [row["id"] for row in rows]
        self.index = {identity: i for i, identity in enumerate(self.ids)}
        self.origins = [row["origin"] for row in rows]
        self.ordinals = [row["ordinal"] for row in rows]
        self.owner = [row["owner"] for row in rows]
        self.alive = [True] * len(rows)
        self.used_ids = sorted(checked.used)
        self.extra = [({k: v for k, v in row["attributes"].items() if k not in FIELDS} or None) for row in rows]
        for field in FIELDS:
            setattr(self, field, [row["attributes"].get(field) for row in rows])

    def active(self):
        return [i for i, alive in enumerate(self.alive) if alive]

    def row(self, i):
        attributes = copy_data(self.extra[i]) if self.extra[i] is not None else {}
        for field in FIELDS:
            value = getattr(self, field)[i]
            if value is not None:
                attributes[field] = value
        return dict(id=self.ids[i], kind="marcher", origin=self.origins[i], ordinal=self.ordinals[i],
                    owner=self.owner[i], attributes=attributes)

    def rows(self):
        return [self.row(i) for i in self.active()]

    def snapshot(self):
        return dict(schema_version=IDS_VERSION, entities=self.rows(), used_ids=self.used_ids[:])

    def retire(self, i):
        self.alive[i] = False

    def live(self, identity):
        i = self.index.get(identity)
        return i if i is not None and self.alive[i] else None

    def delta_rows(self, bases):
        result = []
        for i in self.active():
            row = self.row(i)
            original = bases.get(row["id"])
            if original is None:
                result.append(row)
            else:
                a, old = row["attributes"], original["attributes"]
                result.append(dict(id=row["id"], owner=row["owner"], attributes={
                    k: v for k, v in a.items() if k in ("x_fp", "y_fp", "hp", "armor") or k not in old or old[k] != v}))
        return result
