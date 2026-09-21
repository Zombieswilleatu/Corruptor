"""Portable, exact data transport; never round floats or collapse bool into int."""

import json
import hashlib
import math
import re
import struct

CODEC = "U13_EXACT_DATA_V1"


def pack(value, depth=0):
    if depth > 128:
        raise ValueError("data nesting limit")
    kind = type(value)
    if value is None:
        return ["n"]
    if kind is bool:
        return ["b", value]
    if kind is int and -(1 << 63) <= value < (1 << 63):
        return ["i", str(value)]
    if kind is float and math.isfinite(value):
        return ["f", struct.pack("<d", value).hex()]
    if kind is str:
        # Godot strings are Unicode scalar values, not lone UTF-16 surrogates.
        value.encode("utf-8")
        return ["s", value]
    if kind is list:
        return ["a", [pack(item, depth + 1) for item in value]]
    if kind is dict and all(type(key) is str for key in value):
        return ["d", [[key, pack(value[key], depth + 1)] for key in sorted(value)]]
    raise ValueError("unsupported data type or numeric range")


def unpack(node, depth=0):
    if depth > 128 or type(node) is not list or not node:
        raise ValueError("invalid exact-data node")
    tag = node[0]
    if node == ["n"]:
        return None
    if len(node) != 2 or type(tag) is not str:
        raise ValueError("invalid exact-data shape")
    value = node[1]
    if tag == "b" and type(value) is bool:
        return value
    if tag == "s" and type(value) is str:
        value.encode("utf-8")
        return value
    if tag == "i" and type(value) is str and re.fullmatch(r"0|-?[1-9][0-9]*", value):
        number = int(value)
        if -(1 << 63) <= number < (1 << 63):
            return number
    if tag == "f" and type(value) is str and re.fullmatch(r"[0-9a-f]{16}", value):
        number = struct.unpack("<d", bytes.fromhex(value))[0]
        if math.isfinite(number):
            return number
    if tag == "a" and type(value) is list:
        return [unpack(item, depth + 1) for item in value]
    if tag == "d" and type(value) is list:
        result = {}
        previous = None
        for row in value:
            if type(row) is not list or len(row) != 2 or type(row[0]) is not str:
                raise ValueError("invalid dictionary entry")
            key = row[0]
            key.encode("utf-8")
            if previous is not None and key <= previous:
                raise ValueError("duplicate or unsorted dictionary key")
            result[key] = unpack(row[1], depth + 1)
            previous = key
        return result
    raise ValueError("invalid exact-data value")


def dumps(value):
    return json.dumps({"codec": CODEC, "payload": pack(value)}, ensure_ascii=False,
                      separators=(",", ":"))


def _pack_chunks(value, depth=0):
    """Emit the exact tagged representation without building its second tree."""
    if depth > 128:
        raise ValueError("data nesting limit")
    kind = type(value)
    if kind is list:
        yield '["a",['
        for index, item in enumerate(value):
            if index: yield ','
            yield from _pack_chunks(item, depth + 1)
        yield ']]'
    elif kind is dict and all(type(key) is str for key in value):
        yield '["d",['
        for index, key in enumerate(sorted(value)):
            if index: yield ','
            yield '[' + json.dumps(key, ensure_ascii=False) + ','
            yield from _pack_chunks(value[key], depth + 1)
            yield ']'
        yield ']]'
    else:
        yield json.dumps(pack(value, depth), ensure_ascii=False, separators=(',', ':'))


def sha256(value):
    """Same digest as dumps(value).encode(), with bounded encoding workspace."""
    digest = hashlib.sha256()
    digest.update(b'{"codec":"U13_EXACT_DATA_V1","payload":')
    chunks, size = [], 0
    for chunk in _pack_chunks(value):
        chunks.append(chunk)
        size += len(chunk)
        if size >= 65536:
            digest.update(''.join(chunks).encode('utf-8'))
            chunks.clear()
            size = 0
    chunks.append('}')
    digest.update(''.join(chunks).encode('utf-8'))
    return digest.hexdigest()


def _unique_object(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError("duplicate JSON key")
        result[key] = value
    return result


def loads(text):
    envelope = json.loads(text, object_pairs_hook=_unique_object)
    if type(envelope) is not dict or set(envelope) != {"codec", "payload"} or envelope["codec"] != CODEC:
        raise ValueError("exact-data codec mismatch")
    return unpack(envelope["payload"])


def first_difference(expected, actual, path="$"):
    """Strict structure/float-bit comparison, including missing and extra fields."""
    if type(expected) is not type(actual):
        return f"{path}: type {type(expected).__name__} != {type(actual).__name__}"
    if type(expected) is dict:
        for key in sorted(set(expected) | set(actual)):
            child = f"{path}[{key!r}]"
            if key not in actual:
                return f"{child}: missing"
            if key not in expected:
                return f"{child}: unexpected"
            difference = first_difference(expected[key], actual[key], child)
            if difference:
                return difference
    elif type(expected) is list:
        if len(expected) != len(actual):
            return f"{path}: length {len(expected)} != {len(actual)}"
        for index, (left, right) in enumerate(zip(expected, actual)):
            difference = first_difference(left, right, f"{path}[{index}]")
            if difference:
                return difference
    elif type(expected) is float:
        if struct.pack("<d", expected) != struct.pack("<d", actual):
            return f"{path}: float bits {expected.hex()} != {actual.hex()}"
    elif expected != actual:
        return f"{path}: {expected!r} != {actual!r}"
    return None
