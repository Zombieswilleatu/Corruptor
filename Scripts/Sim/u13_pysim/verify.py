"""Verify independent Python opening results against a Godot-produced suite."""

import hashlib
import copy
from collections import Counter
from pathlib import Path
import struct
import subprocess

from . import VERSION, codec, opening, primitives

SUITE = "U13_PYSIM_FOUNDATION_SUITE_V1"
TRACE = "U13_PARITY_TRACE_V1"
PRODUCER = "U13_PARITY_EXPORT_V1"
SNAPSHOT_KEYS = {"schema_version", "engine_version", "policy_id", "rules_hash", "rng_version",
                 "seed", "world", "presentation_world", "submissions", "combat_orders", "player_order",
                 "runtime", "pending", "persistent", "cooldowns", "events"}
IDENTITY_KEYS = {"trace_schema", "producer", "authority", "source_revision", "source_sha256",
                 "runtime", "platform", "event_profile", "excluded_visual_events", "choice_policy",
                 "schema_version", "engine_version", "policy_id", "rules_hash", "rng_version"}
MODES = [opening.CASTLES,
         ["Keep", "Stockpile", "SiegeEngine", "SummoningCircle", "Bastion"],
         ["Keep", "SummoningCircle", "SummoningCircle", "Stockpile", "Bastion"],
         ["Keep", "Bastion", "Bastion", "SiegeEngine", "SiegeEngine"]]
HOOKS = ["round_start_scheduled", "persistent_advancement", "round_start_automatic",
         "present_public_state", "submission_lock", "development", "post_repair_artillery",
         "commitment_reveal", "combat_resolution", "post_resolution_spawns", "post_resolution_position",
         "post_resolution_allegiance", "post_resolution_movement_state", "post_resolution_hazards",
         "post_resolution_direct", "post_resolution_special_actors", "marching_start", "marching",
         "end_marching_checks", "aftermath"]


def source_identity(root):
    root = Path(root)
    revision = subprocess.check_output(["git", "-C", str(root), "rev-parse", "HEAD"], text=True).strip()
    sim = root / "Scripts/Sim"
    paths = list(sim.rglob("*.gd")) + list((sim / "u13_pysim").glob("*.py")) + [sim / "run_u13_pysim.py"]
    digest = hashlib.sha256()
    for path in sorted(paths, key=lambda item: item.relative_to(root).as_posix()):
        name = path.relative_to(root).as_posix().encode("utf-8")
        # Git Bash may check text out as CRLF. Pin source text, not checkout EOL.
        content = path.read_bytes().replace(b"\r\n", b"\n")
        digest.update(str(len(name)).encode() + b":" + name + hashlib.sha256(content).digest())
    return revision, digest.hexdigest()


def same(expected, actual, path):
    delta = codec.first_difference(expected, actual, path)
    if delta:
        raise ValueError(delta)


def shape(value, keys, path):
    if type(value) is not dict or set(value) != set(keys):
        raise ValueError(f"{path}: missing/extra fields or wrong type")


def trace_identity(trace, revision, source_hash, diagnostic, path):
    shape(trace, {"identity", "setup", "opening", "records"}, path)
    identity = trace["identity"]
    shape(identity, IDENTITY_KEYS, path + ".identity")
    required = {"trace_schema": TRACE, "producer": PRODUCER, "authority": "Godot U13",
                "source_revision": revision, "source_sha256": source_hash,
                "event_profile": "U13_BATCH_EVENTS_V1", "rng_version": primitives.RNG_VERSION,
                "excluded_visual_events": ["MARCHING_TICK", "KRONI_ACTOR_TICK"],
                "choice_policy": "explicit inputs; fixture selection is not doctrine"}
    if not diagnostic:
        required.update(runtime="4.7.2-stable (official)", platform="Windows")
    for key, value in required.items():
        same(value, identity[key], path + ".identity." + key)
    shape(trace["setup"], {"seed", "lords", "castles"}, path + ".setup")
    shape(trace["opening"], SNAPSHOT_KEYS, path + ".opening")
    for key in ("schema_version", "engine_version", "policy_id", "rules_hash", "rng_version"):
        if type(identity[key]) is not str or not identity[key]:
            raise ValueError(path + ".identity." + key + ": invalid")
        same(identity[key], trace["opening"][key], path + ".opening." + key)
    same(trace["setup"]["seed"], trace["opening"]["seed"], path + ".opening.seed")
    same([0, 1], trace["opening"]["player_order"], path + ".opening.player_order")


def expected_registry():
    ids = primitives.Entities()
    guard = ids.create("card", "deck:Butcher:1", 0, 0,
                       {"value": 3, "suit": "Butcher", "role": "guard", "slot": 0, "lane": "Lord"})
    ids.create("card", "deck:Butcher:1", 1, 0, {"value": 3, "suit": "Butcher"})
    ids.update(guard, 1, {"value": 3, "suit": "Butcher", "role": "guard", "slot": 2, "lane": "Castle"})
    castle = ids.create("castle", "setup:p0:Keep", 0, 0)
    ids.retire(castle)
    ids.create("castle", "rebuild_effect_17", 0, 0)
    return ids.snapshot()


def verify(suite, revision, source_hash, diagnostic=False):
    shape(suite, {"schema", "rng", "ids", "openings", "traces", "codec_probe", "registry"}, "suite")
    same(SUITE, suite["schema"], "suite.schema")
    same({"float": 0.1, "negative_zero": -0.0, "whole_float": 1.0, "large_int": 9007199254740993,
          "min_int": -(1 << 63), "max_int": (1 << 63) - 1,
          "tiny_float": struct.unpack("<d", bytes.fromhex("0100000000000000"))[0],
          "unicode": "s:é/龍/🕷", "empty_key": {"": [None, False, True, 0]},
          "tag_like_data": ["f", "arbitrary"]}, suite["codec_probe"], "codec_probe")
    rng_inputs = [["seed", "effect", "PRICE_DELAY", 0, 6], ["seed", "effect", "PRICE_TYPE", 0, 17],
                  ["s:é", "龍", "target", 42, 4294967296],
                  ["seed", "effect", "PRICE_TARGET", 3, 2147483649], ["seed", "effect", "one", 0, 1]]
    same([{"input": row, "value": primitives.draw(*row)} for row in rng_inputs], suite["rng"], "rng")
    id_inputs = [["card", "deck:Butcher:1", 0], ["marcher", "龍:é:🕷", 12],
                 ["castle", "rebuild:0", 1], ["lord", "a:b", 0]]
    same([{"input": row, "value": primitives.entity_id(*row)} for row in id_inputs], suite["ids"], "ids")
    same(expected_registry(), suite["registry"], "registry")
    same(13, len(suite["openings"]), "openings.count")
    same(1, len(suite["traces"]), "traces.count")
    checks = 5
    for index, trace in enumerate(suite["openings"]):
        path = f"openings[{index}]"
        trace_identity(trace, revision, source_hash, diagnostic, path)
        setup = {"seed": f"u13-python-opening:é:{index}",
                 "lords": [opening.LORDS[index % 9], opening.LORDS[(index + 1) % 9]],
                 "castles": [MODES[index % 4], MODES[(index + 1) % 4]]}
        if index == 12:
            setup = {"seed": "u13-python-shortfall:23", "lords": ["Odradek", "Humbaba"], "castles": [MODES[1], MODES[1]]}
        same(setup, trace["setup"], path + ".setup")
        same([], trace["records"], path + ".records")
        expected = opening.snapshot(setup["seed"], setup["lords"], setup["castles"])
        same(expected, trace["opening"], path + ".opening")
        checks += 1
    for index, trace in enumerate(suite["traces"]):
        path = f"traces[{index}]"
        trace_identity(trace, revision, source_hash, diagnostic, path)
        setup = trace["setup"]
        same({"seed": "u13-python-explicit-choices", "lords": ["Gremory", "Valak"],
              "castles": [["Keep", "Stockpile", "SummoningCircle", "Bastion", "SiegeEngine"]] * 2},
             setup, path + ".setup")
        same(opening.snapshot(setup["seed"], setup["lords"], setup["castles"]),
             trace["opening"], path + ".opening")
        before = trace["opening"]
        kinds = []
        steps = []
        for record_index, record in enumerate(trace["records"]):
            location = f"{path}.records[{record_index}]"
            shape(record, {"index", "round", "hook_before", "operation", "result", "state", "outcome"}, location)
            same(record_index, record["index"], location + ".index")
            same(before["runtime"], record["hook_before"], location + ".hook_before")
            same(before["runtime"]["round"], record["round"], location + ".round")
            shape(record["state"], SNAPSHOT_KEYS, location + ".state")
            for key in ("schema_version", "engine_version", "policy_id", "rules_hash", "rng_version", "seed"):
                same(trace["opening"][key], record["state"][key], location + ".state." + key)
            operation = record["operation"]
            kind = operation.get("kind")
            keys = {"step": {"kind", "hook"}, "stockpile": {"kind", "player_id", "keep_id"},
                    "market": {"kind", "player_id", "choice"}, "submit": {"kind", "plans"},
                    "next_round": {"kind"}}
            if kind not in keys:
                raise ValueError(location + ".operation.kind: unknown")
            shape(operation, keys[kind], location + ".operation")
            kinds.append(kind)
            if kind == "step":
                same(before["runtime"]["next_hook"], operation["hook"], location + ".operation.hook")
                steps.append((record["round"], operation["hook"]))
            if record["result"].get("action") == "invalid":
                raise ValueError(location + ".result: rejected operation")
            before = record["state"]
        same({"step": 40, "stockpile": 2, "market": 4, "submit": 2, "next_round": 1},
             dict(Counter(kinds)), path + ".operation_counts")
        same([(round_number, hook) for round_number in (1, 2) for hook in HOOKS], steps, path + ".hook_order")
        # Future phases are retained for Godot replay and later Python work;
        # this verifier deliberately does not claim Python resolution parity.
        checks += 1
    return {"python_mirror": VERSION, "checks": checks, "failures": 0,
            "opening_snapshots_matched": 14, "python_round_resolution_parity": False,
            "diagnostic_only": diagnostic, "source_revision": revision,
            "source_sha256": source_hash, "runtime": suite["openings"][0]["identity"]["runtime"]}


def verify_rejections(suite, revision, source_hash, diagnostic=False):
    """Corrupt actual cross-engine evidence to prove the gate fails closed."""
    def bad_slot(candidate):
        castle = next(row for row in candidate["openings"][0]["opening"]["world"]["entities"]["entities"] if row["kind"] == "castle")
        castle["attributes"]["castle_slot"] += 1

    mutations = [
        (lambda x: x["openings"][0]["identity"].update(source_revision="wrong"), "source_revision"),
        (lambda x: x["openings"][0]["identity"].update(source_sha256="wrong"), "source_sha256"),
        (lambda x: x["openings"].pop(), "count"),
        (lambda x: x["rng"][0].update(value=-1), "rng"),
        (lambda x: x["openings"][0]["opening"].pop("cooldowns"), "opening"),
        (lambda x: x["openings"][0]["opening"]["world"]["data"].update(unexpected=0), "unexpected"),
        (lambda x: x["openings"][0]["opening"]["world"]["entities"]["entities"][0].update(id="forged"), "id"),
        (bad_slot, "castle_slot"),
        (lambda x: x["openings"][0]["opening"]["world"]["data"]["card_zones"]["deck"].reverse(), "deck"),
        (lambda x: x["traces"][0]["records"].pop(), "operation_counts"),
    ]
    for mutate, marker in mutations:
        candidate = copy.deepcopy(suite)
        mutate(candidate)
        try:
            verify(candidate, revision, source_hash, diagnostic)
        except ValueError as error:
            if marker not in str(error):
                raise ValueError(f"wrong mismatch location for {marker}: {error}") from error
        else:
            raise ValueError("negative gate unexpectedly accepted " + marker)
    return len(mutations)
