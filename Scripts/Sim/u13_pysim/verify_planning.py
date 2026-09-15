"""Exact replay of the bounded planning suite, including rejected attempts."""

from collections import Counter
from copy import deepcopy

from . import economy as e, opening
from .planning import PlanningMatch, VERSION
from .timeline import Timeline, HOOKS
from .verify import same, shape, trace_identity

SUITE = "U13_PYSIM_PLANNING_SUITE_V1"
TRACE = "U13_PLANNING_TRACE_V1"
PRODUCER = "U13_PYSIM_PLANNING_EXPORT_V1"
MODES = [["Keep", "Stockpile", "SummoningCircle", "Bastion", "SiegeEngine"],
         ["Keep", "Bastion", "SummoningCircle", "Stockpile", "SiegeEngine"],
         ["Stockpile", "Stockpile", "SummoningCircle", "Bastion", "SiegeEngine"]]
SPECS = [dict(name=name, hand0=h0, hand1=h1, deck=deck, discard=discard, round=number)
         for name, h0, h1, deck, discard, number in [
             ("recycle_full_hand", 10, 0, 0, 8, 1), ("discard_only", 0, 0, 0, 1, 1),
             ("empty_piles", 0, 0, 0, 0, 1), ("stockpile_interseat", 0, 0, 7, 0, 1),
             ("stockpile_one_offer", 4, 0, 18, 0, 1), ("market_exhausted", 0, 0, 0, 0, 2),
             ("market_recycle", 0, 0, 1, 8, 2)]]


def setup(index):
    return dict(seed=f"u13-python-planning:é:{index}",
                lords=[opening.LORDS[index % 9], opening.LORDS[(index + 1) % 9]],
                castles=[MODES[index % 3], MODES[(index + 1) % 3]])


def packed_world(spec):
    config = setup(0)
    w = opening.world(config["seed"], config["lords"], config["castles"])
    z = e.zones(w)
    pool = [r["id"] for r in w["entities"]["entities"] if r["kind"] == "card" and r["id"] not in z["market"]]
    z.update(hands=[[], []], deck=[], discard=[], committed=[[], []])
    index = 0
    for pile, count in [(z["hands"][0], spec["hand0"]), (z["hands"][1], spec["hand1"]),
                        (z["deck"], spec["deck"]), (z["discard"], spec["discard"])]:
        pile.extend(pool[index:index + count])
        index += count
    z["committed"][0] = pool[index:]
    for identity in pool:
        e.entity(w, identity)["owner"] = (1 if identity in z["hands"][1] else
                                          0 if identity in z["hands"][0] or identity in z["committed"][0] else -1)
    w["data"]["game_market"]["round"] = spec["round"] - 1
    w["data"]["game_economy"]["draw_round"] = spec["round"] - 1
    return w


def component_apply(world, operation, number):
    candidate = deepcopy(world)
    kind, seed = operation["kind"], setup(0)["seed"]
    try:
        if kind == "draw":
            result = e.draw(candidate, operation["player_id"], seed, operation["event_id"], operation["from_discard"])
        elif kind == "discard":
            result = e.discard(candidate, operation["player_id"], operation["card_ids"])
        else:
            if kind == "draw_start":
                events = e.start_draw(candidate, seed, number)
            elif kind == "stockpile":
                events = e.choose_stockpile(candidate, operation["player_id"], {"keep_id": operation["keep_id"]},
                                            seed, number, "present_public_state")
            elif kind == "market_begin":
                events = e.market_begin(candidate, seed, number)
            elif kind == "market":
                events = e.choose_market(candidate, operation["player_id"], operation["choice"], number, "present_public_state")
            else:
                raise e.Unsupported("Unknown component operation " + str(kind))
            result = dict(action="resolved", events=events)
        return dict(result=result, world=candidate)
    except e.Rejected as error:
        return dict(result=dict(action="invalid", reason=str(error)), world=deepcopy(world))


def verify(suite, revision, source_hash, diagnostic=False):
    shape(suite, {"schema", "games", "components", "timeline"}, "suite")
    same(SUITE, suite["schema"], "suite.schema")
    same(9, len(suite["games"]), "games.count")
    total, rejected, actions, visitors = 0, 0, set(), set()
    for index, trace in enumerate(suite["games"]):
        path = f"games[{index}]"
        trace_identity(trace, revision, source_hash, diagnostic, path, TRACE, PRODUCER)
        same(setup(index), trace["setup"], path + ".setup")
        game = PlanningMatch(trace["setup"])
        same(game.snapshot(), trace["opening"], path + ".opening")
        accepted_hooks, choices = [], Counter()
        for ordinal, record in enumerate(trace["records"]):
            location = f"{path}.records[{ordinal}]"
            before = game.snapshot()
            op = record["operation"]
            result = game.apply(op)
            actual = dict(index=ordinal, round=before["runtime"]["round"], hook_before=before["runtime"],
                          operation=op, result=result, state=game.snapshot(), outcome=game.outcome())
            same(actual, record, location)
            total += 1
            if result["action"] == "invalid":
                same(before, game.snapshot(), location + ".rollback")
                rejected += 1
            else:
                choices[op["kind"]] += 1
                if op["kind"] == "step":
                    accepted_hooks.append(op["hook"])
                if op["kind"] == "market" and choices["market"] == 1:
                    visitors.add(op["player_id"])
        same(list(HOOKS[:5]), accepted_hooks, path + ".accepted_hooks")
        same("development", game.clock.hook, path + ".last_hook")
        # A nearly full hand can yield only one/zero offers and no choice. Two
        # active copies still grant one benefit. Counts pin this directed corpus.
        stockpiles = [1, 1, 0, 0, 1, 2, 1, 0, 0][index]
        same(stockpiles, choices["stockpile"], path + ".stockpile_choices")
        same(2, choices["market"], path + ".market_choices")
        same(1 if index % 2 == 0 else 2, choices["submit"] + choices["submit_one"], path + ".submissions")
        # The corpus must retain its directed rejected attempts, not just green paths.
        same(20 + 5 * stockpiles + (3 if index % 2 else 0), len(trace["records"]), path + ".record_count")
        for order in game.state["combat_orders"]:
            actions.add(order.get("action", "Pass"))
    same({"Pass", "Ward", "Hunt", "Siege", "Profane"}, actions, "coverage.actions")
    # Sets are coverage bookkeeping, not a state comparison projection.
    if visitors != {0, 1}:
        raise ValueError("coverage.first_slaver_visitors")

    same(SPECS, [trace["spec"] for trace in suite["components"]], "components.specs")
    component_count = 0
    for index, trace in enumerate(suite["components"]):
        path = f"components[{index}]"
        shape(trace, {"spec", "initial", "records"}, path)
        world = packed_world(trace["spec"])
        same(world, trace["initial"], path + ".initial")
        same([2, 2, 2, 5, 4, 3, 3][index], len(trace["records"]), path + ".record_count")
        for ordinal, record in enumerate(trace["records"]):
            applied = component_apply(world, record["operation"], trace["spec"]["round"])
            world = applied["world"]
            same(dict(operation=record["operation"], **applied), record, f"{path}.records[{ordinal}]")
            if not e.cards_valid(world):
                raise ValueError(path + ".card_conservation")
            component_count += 1

    clock = Timeline()
    same(52, len(suite["timeline"]), "timeline.count")
    for index, record in enumerate(suite["timeline"]):
        op = record["operation"]
        if op["kind"] == "begin":
            result = clock.begin(op["round"])
        elif op["kind"] in ("run", "reject"):
            payload = {"action": "invalid", "reason": "fixture_rejection"} if op["kind"] == "reject" else None
            result = clock.run(op["hook"], payload)
        else:
            raise ValueError(f"timeline[{index}].operation.kind")
        same(dict(operation=op, result=result, state=clock.snapshot()), record, f"timeline[{index}]")
    same(True, clock.completed, "timeline.completed")
    same(2, clock.round, "timeline.round")
    return dict(python_mirror=VERSION, source_revision=revision, source_sha256=source_hash,
                runtime=suite["games"][0]["identity"]["runtime"], diagnostic_only=diagnostic,
                planning_games_matched=9, full_game_snapshots_matched=9 + total,
                game_operations_matched=total, rejected_operations_matched=rejected,
                economy_component_operations_matched=component_count, timeline_operations_matched=52,
                game_hooks_implemented=list(HOOKS[:5]), python_full_round_parity=False, failures=0)


def verify_rejections(suite, revision, source_hash, diagnostic=False):
    # Clone only a changed branch of this large immutable evidence tree.
    probes = []
    def changed(path, mutate, marker):
        candidate = suite.copy()
        parent = candidate
        original = suite
        for key in path[:-1]:
            parent[key] = original[key].copy()
            parent, original = parent[key], original[key]
        parent[path[-1]] = deepcopy(original[path[-1]])
        mutate(parent[path[-1]])
        probes.append((candidate, marker))

    changed(["games", 0, "identity"], lambda x: x.update(source_revision="wrong"), "source_revision")
    changed(["games", 0, "identity"], lambda x: x.update(source_sha256="wrong"), "source_sha256")
    changed(["games", 0, "records", 0, "state", "world", "players", 0, "resources"],
            lambda x: x.update(souls=1), "souls")
    changed(["games", 0, "records", 0, "hook_before"], lambda x: x.update(round=2), "round")
    changed(["games", 0, "records"], lambda x: x.pop(), "accepted_hooks")
    changed(["games", 0, "records", -1, "state", "combat_orders", 0], lambda x: x.update(extra=1), "extra")
    changed(["games", 0, "records", -1, "state", "world", "data", "guard_orders", 0, "moves", 0],
            lambda x: x.update(slot=0), "slot")
    changed(["games", 0, "records", -1, "state", "events", "rows", -1],
            lambda x: x["views"].__setitem__(0, deepcopy(x["event"])), "views")
    changed(["components", 0, "records", 0, "world", "data", "card_zones", "deck"],
            lambda x: x.reverse(), "deck")
    changed(["components", 5, "records", 0, "world", "data", "card_zones", "market"],
            lambda x: x.reverse(), "market")
    changed(["timeline", 12, "state", "execution_log", 0], lambda x: x.update(top_level_step=99), "top_level_step")
    for candidate, marker in probes:
        try:
            verify(candidate, revision, source_hash, diagnostic)
        except ValueError as error:
            if marker not in str(error):
                raise ValueError(f"wrong mismatch location for {marker}: {error}") from error
        else:
            raise ValueError("corrupted evidence accepted: " + marker)
    return len(probes)
