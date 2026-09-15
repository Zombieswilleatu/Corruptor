"""Exact six-hook and isolated Guard/Work lifecycle replay against Godot."""

from copy import deepcopy

from . import economy as e
from .development import DevelopmentMatch, VERSION, SUITS, LANES
from .development_fixtures import setup, scripted_operations, component_world, component_apply, COMPONENT_NAMES
from .timeline import HOOKS
from .verify import same, shape, trace_identity

SUITE = "U13_PYSIM_DEVELOPMENT_SUITE_V1"
TRACE = "U13_DEVELOPMENT_TRACE_V1"
PRODUCER = "U13_PYSIM_DEVELOPMENT_EXPORT_V1"
COMPONENT_COUNTS = [31, *[19] * 6, 20, 20, 23, 9]


def verify(suite, revision, source_hash, diagnostic=False):
    shape(suite, {"schema", "games", "components"}, "suite")
    same(SUITE, suite["schema"], "suite.schema")
    same(9, len(suite["games"]), "games.count")
    pair_coverage, total = set(), 0
    for index, trace in enumerate(suite["games"]):
        path = f"games[{index}]"
        trace_identity(trace, revision, source_hash, diagnostic, path, TRACE, PRODUCER)
        same(setup(index), trace["setup"], path + ".setup")
        same(9, len(trace["records"]), path + ".record_count")
        same(scripted_operations(index), [record["operation"] for record in trace["records"]], path + ".inputs")
        game = DevelopmentMatch(trace["setup"])
        same(game.snapshot(), trace["opening"], path + ".opening")
        hooks = []
        for ordinal, record in enumerate(trace["records"]):
            location = f"{path}.records[{ordinal}]"
            before = game.snapshot()
            op = record["operation"]
            result = game.apply(op)
            actual = dict(index=ordinal, round=before["runtime"]["round"], hook_before=before["runtime"],
                          operation=op, result=result, state=game.snapshot(), outcome=game.outcome())
            same(actual, record, location)
            same(False, result["action"] == "invalid", location + ".accepted")
            if op["kind"] == "step":
                hooks.append(op["hook"])
            total += 1
        same(list(HOOKS[:6]), hooks, path + ".hooks")
        same("post_repair_artillery", game.clock.hook, path + ".last_hook")
        pairs = game.state["world"]["data"]["guard_work"]["pairs"]
        same(2, len(pairs), path + ".formed_pairs")
        pair_coverage.update((pair["suit"], pair["lane"]) for pair in pairs)
    same(sorted((suit, lane) for suit in SUITS for lane in LANES), sorted(pair_coverage), "coverage.pairs")

    same(COMPONENT_NAMES, [trace["name"] for trace in suite["components"]], "components.names")
    component_count, fixture_count, rejected = 0, 0, 0
    for index, trace in enumerate(suite["components"]):
        path = f"components[{index}]"
        shape(trace, {"name", "initial", "records"}, path)
        world = component_world()
        same(world, trace["initial"], path + ".initial")
        same(COMPONENT_COUNTS[index], len(trace["records"]), path + ".record_count")
        for ordinal, record in enumerate(trace["records"]):
            applied = component_apply(world, record["operation"])
            world = applied["world"]
            same(dict(operation=record["operation"], **applied), record, f"{path}.records[{ordinal}]")
            if not e.cards_valid(world):
                raise ValueError(path + ".card_conservation")
            fixture_count += record["operation"]["kind"].startswith("fixture_")
            rejected += applied["result"]["action"] == "invalid"
            component_count += 1
    same(7, rejected, "components.rejected_count")
    return dict(python_mirror=VERSION, source_revision=revision, source_sha256=source_hash,
                runtime=suite["games"][0]["identity"]["runtime"], diagnostic_only=diagnostic,
                development_games_matched=9, full_game_snapshots_matched=9 + total,
                game_operations_matched=total, component_operations_matched=component_count,
                component_fixture_operations=fixture_count, rejected_component_operations_matched=rejected,
                game_hooks_implemented=list(HOOKS[:6]), python_full_round_parity=False,
                python_full_match_parity=False, failures=0)


def verify_rejections(suite, revision, source_hash, diagnostic=False):
    probes = []
    def changed(path, mutate, marker):
        candidate, original = suite.copy(), suite
        parent = candidate
        for key in path[:-1]:
            parent[key] = original[key].copy()
            parent, original = parent[key], original[key]
        parent[path[-1]] = deepcopy(original[path[-1]])
        mutate(parent[path[-1]])
        probes.append((candidate, marker))

    base = ["games", 0, "records", -1, "state"]
    pairs = base + ["world", "data", "guard_work", "pairs", 0]
    changed(["games", 0, "identity"], lambda x: x.update(source_revision="wrong"), "source_revision")
    changed(["games", 0, "identity"], lambda x: x.update(source_sha256="wrong"), "source_sha256")
    changed(["games", 0, "records"], lambda x: x.pop(), "record_count")
    changed(pairs, lambda x: x.update(active=False), "active")
    changed(pairs + ["ids"], lambda x: x.reverse(), "ids")
    changed(pairs + ["slots"], lambda x: x.reverse(), "slots")
    changed(base + ["world", "data", "guard_work"], lambda x: x.update(developed_round=0), "developed_round")
    changed(base + ["world", "data", "guard_work", "targets"], lambda x: x.__setitem__(0, ""), "targets")
    first_guard = next(i for i, row in enumerate(suite["games"][0]["records"][-1]["state"]["world"]["entities"]["entities"])
                       if row["attributes"].get("role") == "guard")
    changed(base + ["world", "entities", "entities", first_guard, "attributes"], lambda x: x.update(slot=1), "slot")
    changed(base + ["events", "rows", -1, "event", "data"], lambda x: x.update(after=99), "after")
    changed(base + ["events", "rows", -1], lambda x: x["views"].__setitem__(0, {}), "views")
    # Vulture draws have real pile order, but public events contain no card ID.
    changed(["components", 7, "records", 8, "world", "data", "card_zones", "hands", 0],
            lambda x: x.reverse(), "hands")
    changed(["components", 1, "records", 13, "world", "data", "guard_work", "pairs", 0],
            lambda x: x.update(active=True), "active")
    changed(["components", 1, "records", 14, "world", "entities", "used_ids"], lambda x: x.pop(), "used_ids")
    for candidate, marker in probes:
        try:
            verify(candidate, revision, source_hash, diagnostic)
        except ValueError as error:
            if marker not in str(error):
                raise ValueError(f"wrong mismatch location for {marker}: {error}") from error
        else:
            raise ValueError("corrupted evidence accepted: " + marker)
    return len(probes)
