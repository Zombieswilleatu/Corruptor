"""U13KeyedRng and U13EntityIds counterparts; no legacy sequential RNG."""

import copy
import hashlib
import math

RNG_VERSION = "U13_SHA256_REJECTION_V1"
IDS_VERSION = "U13_ENTITY_IDS_V1"
MAX_INTEGER = (1 << 53) - 1
KINDS = ("lord", "castle", "card", "marcher")


def integer(value):
    return (type(value) is int and abs(value) <= MAX_INTEGER) or (
        type(value) is float and math.isfinite(value)
        and abs(value) <= MAX_INTEGER and value.is_integer())


def normalize(value, depth=0):
    if depth > 64:
        raise ValueError("U13 data depth")
    if value is None or type(value) in (str, bool):
        return value
    if integer(value):
        return int(value)
    if type(value) is float and math.isfinite(value):
        return value
    if type(value) is list:
        return [normalize(item, depth + 1) for item in value]
    if type(value) is dict and all(type(key) is str for key in value):
        if any(key.endswith("_fp") and not integer(item) for key, item in value.items()):
            raise ValueError("fractional fixed-point field")
        return {key: normalize(item, depth + 1) for key, item in value.items()}
    raise ValueError("invalid U13 plain data")


def draw(seed, effect, purpose, roll_index, bound):
    if not all(type(item) is str and item for item in (seed, effect, purpose)):
        raise ValueError("rng_key_required")
    if not integer(roll_index) or roll_index < 0 or type(bound) is not int or not 1 <= bound <= (1 << 32):
        raise ValueError("rng_range_invalid")
    limit = (1 << 32) - (1 << 32) % bound
    for attempt in range(1024):
        fields = (RNG_VERSION, seed, effect, purpose, str(int(roll_index)), str(attempt))
        material = b"".join(str(len(field.encode("utf-8"))).encode("ascii") + b":"
                            + field.encode("utf-8") for field in fields)
        number = int.from_bytes(hashlib.sha256(material).digest()[:4], "big")
        if number < limit:
            return number % bound
    raise ValueError("rng_rejection_limit")


def instance_id(scope, origin, key):
    # Godot String.length() counts Unicode characters. RNG framing uses bytes.
    return f"u13_{scope}:{len(origin)}:{origin}:{len(key)}:{key}"


def entity_id(kind, origin, ordinal=0):
    if kind not in KINDS or type(origin) is not str or not origin or not integer(ordinal) or ordinal < 0:
        raise ValueError("entity_data_invalid")
    return instance_id("entity_" + kind, origin, str(int(ordinal)))


class Entities:
    def __init__(self):
        self.rows = {}
        self.used = set()

    def create(self, kind, origin, ordinal, owner, attributes=None):
        identity = entity_id(kind, origin, ordinal)
        if type(owner) is not int or owner not in (-1, 0, 1):
            raise ValueError("entity_data_invalid")
        attributes = normalize({} if attributes is None else attributes)
        if type(attributes) is not dict:
            raise ValueError("entity_data_invalid")
        if identity in self.used:
            raise ValueError("entity_identity_already_used")
        self.rows[identity] = dict(id=identity, kind=kind, origin=origin,
                                   ordinal=int(ordinal), owner=owner, attributes=attributes)
        self.used.add(identity)
        return identity

    def update(self, identity, owner, attributes):
        if identity not in self.rows or type(owner) is not int or owner not in (-1, 0, 1):
            raise ValueError("entity_update_invalid")
        attributes = normalize(attributes)
        if type(attributes) is not dict:
            raise ValueError("entity_update_invalid")
        self.rows[identity]["owner"] = owner
        self.rows[identity]["attributes"] = attributes

    def retire(self, identity):
        if identity not in self.rows:
            raise ValueError("entity_missing")
        del self.rows[identity]

    def snapshot(self):
        return {"schema_version": IDS_VERSION,
                "entities": [copy.deepcopy(self.rows[key]) for key in sorted(self.rows)],
                "used_ids": sorted(self.used)}

    def restore(self, raw):
        candidate = normalize(raw)
        if type(candidate) is not dict or candidate.get("schema_version") != IDS_VERSION:
            raise ValueError("entity_snapshot_invalid")
        if type(candidate.get("entities")) is not list or type(candidate.get("used_ids")) is not list:
            raise ValueError("entity_snapshot_invalid")
        rows = {}
        for row in candidate["entities"]:
            if type(row) is not dict or not {"id", "kind", "origin", "ordinal", "owner", "attributes"} <= row.keys():
                raise ValueError("entity_snapshot_invalid")
            key = entity_id(row["kind"], row["origin"], row["ordinal"])
            if row["id"] != key or key in rows or type(row["owner"]) is not int or row["owner"] not in (-1, 0, 1) or type(row["attributes"]) is not dict:
                raise ValueError("entity_snapshot_invalid")
            rows[key] = {field: row[field] for field in ("id", "kind", "origin", "ordinal", "owner", "attributes")}
        used_list = candidate["used_ids"]
        if not all(type(key) is str and key for key in used_list):
            raise ValueError("entity_snapshot_ids_invalid")
        used = set(used_list)
        if len(used) != len(used_list) or not rows.keys() <= used:
            raise ValueError("entity_snapshot_ids_invalid")
        self.rows, self.used = rows, used
