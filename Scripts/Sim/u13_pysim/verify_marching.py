"""Exact isolated phase replay, with the first divergent tick in the error path."""

from collections import Counter
from copy import deepcopy

from . import marching as m
from . import marching_fixtures as f
from .marching_columns import Columns
from .verify import same, shape


def transition(expected, actual, path):
    events = expected["result"].get("events", [])
    actual_events = actual["result"].get("events", [])
    same(len(events), len(actual_events), path + ".events.count")
    for ordinal, (left, right) in enumerate(zip(events, actual_events)):
        event = left["event"]
        details = event["data"]
        location = f"{path}.events[{ordinal}].round={details.get('round', '?')}.tick={details.get('tick', '?')}.{event['type']}"
        same(left, right, location)
    same(expected, actual, path)


def verify(suite, revision, source_hash, diagnostic=False, check_batch=True):
    shape(suite, {"schema", "inputs_sha256", "identity", "cases"}, "suite")
    same("U13_PYSIM_MARCHING_SUITE_V1", suite["schema"], "schema")
    same(f.input_hash(), suite["inputs_sha256"], "inputs_sha256")
    identity = suite["identity"]
    shape(identity, {"source_revision", "source_sha256", "runtime", "platform", "authority", "model", "scope", "tick_profile"}, "identity")
    required = dict(source_revision=revision, source_sha256=source_hash, authority="Godot U13Marching.resolve",
                    model=m.MODEL, scope="isolated phases; explicit fields/actors; no Lord reactions",
                    tick_profile="complete MARCHING_TICK attribute_delta_v1")
    if not diagnostic:
        required.update(runtime="4.7.2-stable (official)", platform="Windows")
    for key, value in required.items():
        same(value, identity[key], "identity." + key)
    manifest = f.load()
    same("U13_MARCHING_INPUTS_V1", manifest["schema"], "input.schema")
    same([c["name"] for c in manifest["cases"]], [c["name"] for c in suite["cases"]], "cases.names")
    operations = fixtures = rejected = phases = probes = 0
    counts = Counter()
    for spec, trace in zip(manifest["cases"], suite["cases"]):
        path = "cases[" + spec["name"] + "]"
        shape(trace, {"name", "initial", "probes", "records"}, path)
        world = f.initial(spec)
        same(world, trace["initial"], path + ".initial")
        same(spec["contact_probes"], [p["input"] for p in trace["probes"]], path + ".probe_inputs")
        for input, record in zip(spec["contact_probes"], trace["probes"]):
            ctx = f.context(spec, world, 1)
            ctx["seed"] = input["seed"]
            actual = m.contact(Columns(world["entities"]), input["lane"], ctx, input["clock"], True)
            same(dict(input=input, result=actual), record, path + f".probe[{probes}]")
            probes += 1
        same(len(spec["operations"]), len(trace["records"]), path + ".record_count")
        for ordinal, (op, record) in enumerate(zip(spec["operations"], trace["records"])):
            same(op, record["operation"], path + ".input")
            actual = f.apply(spec, world, op)
            transition(record, dict(operation=op, **actual), path + f".operation[{ordinal}]")
            same(op["expected_action"], actual["result"]["action"], path + ".expected_action")
            if actual["result"]["action"] == "invalid":
                same(world, actual["world"], path + ".rollback")
                rejected += 1
            if check_batch:
                batch = f.apply(spec, world, op, capture_ticks=False)
                same(actual["world"], batch["world"], path + ".batch.world")
                same(f.strip_ticks(actual["result"]), batch["result"], path + ".batch.events")
            world = actual["world"]
            operations += 1
            fixtures += op["kind"].startswith("fixture_")
            phases += op["kind"] == "march" and actual["result"]["action"] == "resolved"
            counts.update(row["event"]["type"] for row in actual["result"].get("events", []))
    same(phases * 200, counts["MARCHING_TICK"], "all_tick_frames")
    for name in ("MARCHER_CONTACT", "MARCHER_CLASH", "MARCHER_DEFEATED", "MARCHER_RANGED_ATTACK",
                 "MARCHER_WAITING", "MARCHER_REGENERATED", "MARCHER_DUEL_INTERRUPTED", "GRAVITY_ORB_CONSUMED"):
        same(True, counts[name] > 0, "coverage." + name)
    return dict(python_mirror=m.VERSION, source_revision=revision, source_sha256=source_hash,
                inputs_sha256=f.input_hash(), runtime=identity["runtime"], reference_platform=identity["platform"],
                diagnostic_only=diagnostic, isolated_cases_matched=len(manifest["cases"]),
                operations_matched=operations, fixture_operations=fixtures, rejected_operations=rejected,
                marching_phases_matched=phases, tick_frames_matched=counts["MARCHING_TICK"],
                contact_probes_matched=probes, batch_projection_verified=check_batch, event_coverage=dict(sorted(counts.items())),
                python_full_round_parity=False, python_full_match_parity=False,
                full_match_games_per_second=None, full_match_50000_wall_seconds=None, failures=0)


def verify_rejections(suite, revision, source_hash, diagnostic=False):
    probes = []
    def change(path, mutation, marker):
        candidate, original = suite.copy(), suite
        parent = candidate
        for key in path[:-1]:
            parent[key] = original[key].copy()
            parent, original = parent[key], original[key]
        parent[path[-1]] = deepcopy(original[path[-1]])
        mutation(parent[path[-1]])
        probes.append((candidate, marker))
    change(["identity"], lambda x: x.update(source_revision="wrong"), "source_revision")
    change(["identity"], lambda x: x.update(source_sha256="wrong"), "source_sha256")
    change(["identity"], lambda x: x.update(tick_profile="tick samples omitted"), "tick_profile")
    bad = suite.copy(); bad["inputs_sha256"] = "wrong"; probes.append((bad, "inputs_sha256"))
    change(["cases", 0, "records"], lambda x: x.pop(), "record_count")
    change(["cases", 2, "probes", 0, "result"], lambda x: x.update(key="wrong"), "key")
    change(["cases", 2, "probes", 0, "result", "candidates"], lambda x: x.reverse(), "candidates")
    events = suite["cases"][0]["records"][0]["result"]["events"]
    tick = next(i for i, row in enumerate(events) if row["event"]["type"] == "MARCHING_TICK")
    base = ["cases", 0, "records", 0, "result", "events", tick]
    change(base + ["event", "data", "units", 0, "attributes"], lambda x: x.update(x_fp=x["x_fp"]+1), "tick=0")
    change(base + ["event", "data", "units", 0, "attributes"], lambda x: x.update(armor=x["armor"]+1), "armor")
    change(base + ["views", 1, "data"], lambda x: x.update(tick=999), "views")
    long = next(i for i,c in enumerate(suite["cases"]) if c["name"] == "duel_across_phase_boundary")
    change(["cases", long, "records", 0, "world", "data", "marching_duels", "Lord"], lambda x: x.update(next_tick=x["next_tick"]+1), "next_tick")
    actor = next(i for i,c in enumerate(suite["cases"]) if c["name"] == "gravity_pull_consumption_and_sweep")
    change(["cases", actor, "records", 0, "world", "data", "valak_orbs", 0], lambda x: x.update(consumed=x["consumed"]+1), "consumed")
    change(["cases", 2, "records", 0, "world", "entities", "used_ids"], lambda x: x.pop(), "used_ids")
    change(["cases", 2, "records", 0, "result", "events"], lambda x: x.reverse(), "events")
    for candidate, marker in probes:
        try:
            verify(candidate, revision, source_hash, diagnostic, check_batch=False)
        except ValueError as error:
            if marker not in str(error):
                raise ValueError(f"Wrong first-divergence path for {marker}: {error}") from error
        else:
            raise ValueError("Corrupted Marching evidence accepted: " + marker)
    return len(probes)
