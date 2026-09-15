"""Strict replay of nine-hook games and isolated ordinary-resolution inputs."""

from collections import Counter
from copy import deepcopy

from . import economy as e
from .resolution import ResolutionMatch, VERSION
from .resolution_fixtures import inputs, input_hash, component_initial, component_apply
from .timeline import HOOKS
from .verify import same, shape, trace_identity

SUITE = "U13_PYSIM_RESOLUTION_SUITE_V1"
TRACE = "U13_RESOLUTION_TRACE_V1"
PRODUCER = "U13_PYSIM_RESOLUTION_EXPORT_V1"
REQUIRED_EVENTS = ("ARTILLERY_FIRED", "ARTILLERY_NO_TARGET", "MARCHER_SPAWNED", "GUARD_PAIR_SCREEN",
                   "GUARD_PAIR_STRIKE", "BASTION_SCREENED", "KEEP_INTERPOSED", "PILLAGE_RETARGETED",
                   "PROFANE_RESOLVED", "LORD_BANISHED", "FRACTURE_HIT", "CASTLE_CEILING_CHANGED",
                   "THE_STONES_FORGET", "FEAR_AURA", "SIFTING_THE_RUINS", "GEM_DAGGER", "ACCELERATE",
                   "BLOOD_CONDUIT", "ORIAS_MARKED", "VALAK_ESSENCE_GAINED", "VALAK_ESSENCE_REINFORCED")


def verify(suite, revision, source_hash, diagnostic=False):
    shape(suite, {"schema", "inputs_sha256", "games", "components"}, "suite")
    same(SUITE, suite["schema"], "suite.schema")
    same(input_hash(), suite["inputs_sha256"], "suite.inputs_sha256")
    corpus = inputs()
    same(len(corpus["games"]), len(suite["games"]), "games.count")
    operations, rejections, events = 0, 0, Counter()
    for index, (spec, trace) in enumerate(zip(corpus["games"], suite["games"])):
        path = f"games[{index}]"
        trace_identity(trace, revision, source_hash, diagnostic, path, TRACE, PRODUCER)
        same(spec["setup"], trace["setup"], path+".setup")
        same(len(spec["operations"]), len(trace["records"]), path+".record_count")
        same(spec["operations"], [r["operation"] for r in trace["records"]], path+".inputs")
        game = ResolutionMatch(spec["setup"])
        same(game.snapshot(), trace["opening"], path+".opening")
        hooks = []
        for ordinal, record in enumerate(trace["records"]):
            before = game.snapshot()
            op = record["operation"]
            result = game.apply(op)
            actual = dict(index=ordinal, round=before["runtime"]["round"], hook_before=before["runtime"],
                          operation=op, result=result, state=game.snapshot(), outcome=game.outcome())
            same(actual, record, f"{path}.records[{ordinal}]")
            rejected = result["action"] == "invalid"
            if rejected: same(before, game.snapshot(), path+".rejection_rollback")
            elif op["kind"] == "step": hooks.append(op["hook"])
            rejections += rejected
            operations += 1
        same(list(HOOKS[:9]), hooks, path+".hooks")
        same("post_resolution_spawns", game.clock.hook, path+".boundary")
        events.update(row["event"]["type"] for row in game.state["events"]["rows"])
    same(len(corpus["games"]), rejections, "games.rejected_count")
    same([s["name"] for s in corpus["components"]], [s["name"] for s in suite["components"]], "components.names")
    component_count, fixture_count, component_rejections = 0, 0, 0
    for index, (spec, trace) in enumerate(zip(corpus["components"], suite["components"])):
        path = f"components[{index}]"
        shape(trace, {"name", "initial", "records"}, path)
        same(len(spec["operations"]), len(trace["records"]), path+".record_count")
        same(spec["operations"], [r["operation"] for r in trace["records"]], path+".inputs")
        world = component_initial(spec)
        same(world, trace["initial"], path+".initial")
        for ordinal, record in enumerate(trace["records"]):
            actual = component_apply(world, record["operation"])
            same(dict(operation=record["operation"], **actual), record, f"{path}.records[{ordinal}]")
            if actual["result"]["action"] == "invalid":
                same(world, actual["world"], path+".rejection_rollback")
                component_rejections += 1
            world = actual["world"]
            same(True, e.cards_valid(world), path+".physical_cards")
            fixture_count += record["operation"]["kind"].startswith("fixture_")
            component_count += 1
            events.update(row["event"]["type"] for row in actual["result"].get("events", []))
    same(4, component_rejections, "components.rejected_count")
    for name in REQUIRED_EVENTS:
        same(True, events[name] > 0, "coverage."+name)
    return dict(python_mirror=VERSION, source_revision=revision, source_sha256=source_hash,
                inputs_sha256=input_hash(), runtime=suite["games"][0]["identity"]["runtime"], diagnostic_only=diagnostic,
                fresh_games_matched=len(corpus["games"]), full_game_snapshots_matched=len(corpus["games"])+operations,
                game_operations_matched=operations, rejected_game_operations_matched=rejections,
                isolated_components_matched=len(corpus["components"]), component_operations_matched=component_count,
                component_fixture_operations=fixture_count, rejected_component_operations_matched=component_rejections,
                game_hooks_implemented=list(HOOKS[:9]), event_coverage=dict(sorted(events.items())),
                python_full_round_parity=False, python_full_match_parity=False,
                full_match_games_per_second=None, full_match_50000_wall_seconds=None, failures=0)


def verify_rejections(suite, revision, source_hash, diagnostic=False):
    probes = []
    def changed(path, mutation, marker):
        candidate, original = suite.copy(), suite
        parent = candidate
        for key in path[:-1]:
            parent[key] = original[key].copy()
            parent, original = parent[key], original[key]
        parent[path[-1]] = deepcopy(original[path[-1]])
        mutation(parent[path[-1]])
        probes.append((candidate, marker))
    changed(["games",0,"identity"],lambda x:x.update(source_revision="wrong"),"source_revision")
    changed(["games",0,"identity"],lambda x:x.update(source_sha256="wrong"),"source_sha256")
    bad = suite.copy(); bad["inputs_sha256"] = "wrong"; probes.append((bad,"inputs_sha256"))
    changed(["games",0,"records"],lambda x:x.pop(),"record_count")
    state = ["games",0,"records",-1,"state"]
    changed(state+["world","data"],lambda x:x.update(artillery_round=0),"artillery_round")
    changed(state+["world","data"],lambda x:x.update(combat_reveal_round=0),"combat_reveal_round")
    changed(state+["world","data"],lambda x:x.update(combat_resolved_round=0),"combat_resolved_round")
    changed(state+["runtime"],lambda x:x.update(next_hook_index=10),"next_hook_index")
    rows = suite["games"][0]["records"][-1]["state"]["world"]["entities"]["entities"]
    marcher = next(i for i,r in enumerate(rows) if r["kind"] == "marcher")
    changed(state+["world","entities","entities",marcher,"attributes"],lambda x:x.update(x_fp=x["x_fp"]+1),"x_fp")
    changed(state+["world","entities","entities",marcher,"attributes"],lambda x:x.update(movement_ready_round=99),"movement_ready_round")
    changed(state+["events","rows",-1,"event","data"],lambda x:x.update(strength=999),"strength")
    changed(state+["events","rows",-1],lambda x:x["views"].__setitem__(0,{}),"views")
    changed(state+["world","entities","used_ids"],lambda x:x.pop(),"used_ids")
    changed(["components",0,"records",-1,"world","data"],lambda x:x.update(castle_tear_round=0),"castle_tear_round")
    changed(["components",0,"records",-1,"result","events"],lambda x:x.reverse(),"events")
    component = next(i for i,t in enumerate(suite["components"]) if t["name"] == "gem_dagger_private_draws")
    facts = suite["components"][component]["records"][-1]["result"]["events"]
    ordinal = next(i for i,r in enumerate(facts) if r["event"]["type"] == "GEM_DAGGER")
    opponent = 1 - facts[ordinal]["event"]["data"]["player_id"]
    changed(["components",component,"records",-1,"result","events",ordinal,"views",opponent,"data"],
            lambda x:x.update(card_id="private-leak"),"card_id")
    for candidate, marker in probes:
        try: verify(candidate, revision, source_hash, diagnostic)
        except ValueError as error:
            if marker not in str(error): raise ValueError(f"wrong mismatch location for {marker}: {error}") from error
        else: raise ValueError("corrupted evidence accepted: "+marker)
    return len(probes)
