"""Physical card piles, round draws and Slaver choices (Godot U13 authority)."""

from copy import deepcopy

from .primitives import draw as roll

MARKET = "U13_GAME_MARKET_V2"


class Rejected(ValueError):
    """A supported operation rejected by the rules; callers own transactions."""


class Unsupported(ValueError):
    """An unimplemented boundary, never represented as a Godot rules rejection."""


def require(condition, reason):
    if not condition:
        raise Rejected(reason)


def entity(world, identity):
    return next((row for row in world["entities"]["entities"] if row["id"] == identity), {})


def zones(world):
    return world["data"]["card_zones"]


def selection(hand, selected):
    return (type(selected) is list and all(type(x) is str for x in selected)
            and len(set(selected)) == len(selected) and all(x in hand for x in selected))


def cards_valid(world):
    z = zones(world)
    seen = set()
    for pile, owner in [(z["deck"], -1), (z["discard"], -1),
                        *[(z["hands"][p], p) for p in (0, 1)],
                        *[(z["committed"][p], p) for p in (0, 1)],
                        (z["market"], -1), (z["market_reserve"], -1)]:
        if type(pile) is not list:
            return False
        for identity in pile:
            if type(identity) is not str or identity in seen:
                return False
            row = entity(world, identity)
            if not row or row["kind"] != "card" or row["owner"] != owner or row["attributes"].get("role") == "guard":
                return False
            seen.add(identity)
    return all(row["id"] in seen for row in world["entities"]["entities"]
               if row["kind"] == "card" and row["attributes"].get("role") != "guard")


def recycle(z, seed, event_id):
    # This happens even when the hand is already full. Discard-only draws skip it.
    if not z["deck"] and z["discard"]:
        shuffled = z["discard"][:]
        for index in range(len(shuffled) - 1, 0, -1):
            pick = roll(seed, event_id, "DISCARD_RECYCLE", index, index + 1)
            shuffled[index], shuffled[pick] = shuffled[pick], shuffled[index]
        z["deck"] = shuffled
        z["discard"].clear()


def draw(world, pid, seed, event_id, from_discard=False):
    require(type(pid) is int and pid in (0, 1) and cards_valid(world), "card_draw_world_invalid")
    z = zones(world)
    if not from_discard:
        recycle(z, seed, event_id)
    pile = z["discard"] if from_discard else z["deck"]
    result = {"action": "draw", "drawn": False, "player_id": pid}
    if len(z["hands"][pid]) < z["hand_limit"] and pile:
        identity = pile.pop()
        z["hands"][pid].append(identity)
        entity(world, identity)["owner"] = pid
        result.update(drawn=True, card_id=identity)
    return result


def discard(world, pid, selected):
    require(type(pid) is int and pid in (0, 1) and cards_valid(world)
            and selection(zones(world)["hands"][pid], selected), "discard_payment_invalid")
    z = zones(world)
    for identity in selected:
        z["hands"][pid].remove(identity)
        z["discard"].append(identity)
        entity(world, identity)["owner"] = -1
    return {"action": "resolved"}


def event(kind, data, text="", private=None, redact=()):
    fact = {"type": kind, "text": text, "data": deepcopy(data)}
    public = deepcopy(fact)
    for key in redact:
        public["data"].pop(key, None)
    views = [deepcopy(public), deepcopy(public)]
    if private is not None:
        views[private] = deepcopy(fact)
    return {"event": fact, "views": views}


def sealed_event(kind, data, pid):
    row = event(kind, data)
    row["views"][1 - pid] = None
    return row


def operational(row):
    return (row.get("kind") == "castle" and row["attributes"]["status"] == "standing"
            and row["attributes"]["integrity"] > 0
            and row["attributes"]["construction_state"] == "active")


def stockpile(world, pid):
    choices = [r for r in world["entities"]["entities"] if r["owner"] == pid
               and operational(r) and r["attributes"]["castle_type"] == "Stockpile"]
    return min(choices, key=lambda r: r["attributes"]["castle_slot"]) if choices else {}


def continue_draw(world, seed, round_number):
    state = world["data"]["game_economy"]
    events = []
    while state["draw_player"] < 2:
        pid = state["draw_player"]
        for index in range(5):
            drawn = draw(world, pid, seed, f"round:{round_number}:draw:{pid}:{index}")
            events.append(event("ROUND_DRAW", drawn, private=pid, redact=("card_id",)))
        state["draw_player"] += 1
        castle = stockpile(world, pid)
        if not castle:
            continue
        offered = []
        for index in range(2):
            drawn = draw(world, pid, seed, f"round:{round_number}:stockpile:{pid}:{index}")
            events.append(event("STOCKPILE_DRAW", drawn, private=pid, redact=("card_id",)))
            if drawn["drawn"]:
                offered.append(drawn["card_id"])
        if len(offered) == 2:
            state["stockpile_pending"] = dict(player_id=pid, castle_id=castle["id"], card_ids=offered)
            break
    return events


def start_draw(world, seed, round_number):
    state = world["data"]["game_economy"]
    require(not state["stockpile_pending"] and state["draw_round"] == round_number - 1,
            "game_draw_clock_invalid")
    state.update(draw_round=round_number, draw_player=0)
    return continue_draw(world, seed, round_number)


def choose_stockpile(world, pid, choice, seed, round_number, hook):
    require(hook == "present_public_state", "stockpile_choice_window_closed")
    state = world["data"]["game_economy"]
    pending = state["stockpile_pending"]
    require(pending and pid == pending["player_id"] and set(choice) == {"keep_id"}
            and choice["keep_id"] in pending["card_ids"], "stockpile_choice_invalid")
    discarded = next(identity for identity in pending["card_ids"] if identity != choice["keep_id"])
    discard(world, pid, [discarded])
    state["stockpile_pending"] = {}
    chosen = event("STOCKPILE_SELECTED", dict(player_id=pid, castle_id=pending["castle_id"],
                   discard_id=discarded, keep_id=choice["keep_id"]), "Stockpile selection resolved.",
                   private=pid, redact=("keep_id",))
    return [chosen] + continue_draw(world, seed, round_number)


def market_event(kind, data):
    return event(kind, data, {"MARKET_REFRESHED": "The Slaver has new stock.",
                             "MARKET_PASSED": "Passed the Slaver.",
                             "MARKET_SWAPPED": "Exchanged a Subject at the Slaver."}[kind])


def market_begin(world, seed, round_number):
    state, z = world["data"]["game_market"], zones(world)
    require(state["round"] == round_number - 1 and state["seat"] == 2, "market_round_clock_invalid")
    events = []

    def bottom():
        for identity in z["market_reserve"]:
            z["deck"].insert(0, identity)
        z["market_reserve"].clear()

    if round_number > 1:
        old = z["market"][:]
        z["market_reserve"], z["market"] = old[:], []
        for index in range(3):
            recycle(z, seed, f"market:{round_number}:{index}")
            if not z["deck"] and z["market_reserve"]:
                bottom()
                recycle(z, seed, f"market:{round_number}:reuse:{index}")
            if not z["deck"]:
                break
            z["market"].append(z["deck"].pop())
        bottom()
        events.append(market_event("MARKET_REFRESHED", dict(round=round_number, old_ids=old, card_ids=z["market"][:])))
    state.update(round=round_number, seat=state["first_player"])
    return events


def choose_market(world, pid, choice, round_number, hook):
    state, z = world["data"]["game_market"], zones(world)
    require(hook == "present_public_state" and not world["data"]["game_economy"]["stockpile_pending"]
            and state["round"] == round_number and state["seat"] == pid, "market_choice_window_closed")
    passed = choice == {"market": "Pass"}
    if not passed:
        require(set(choice) == {"market", "take_id", "give_id"} and choice["market"] == "Swap"
                and choice["take_id"] in z["market"] and choice["give_id"] in z["hands"][pid], "market_swap_invalid")
        z["market"].remove(choice["take_id"])
        z["hands"][pid].remove(choice["give_id"])
        z["hands"][pid].append(choice["take_id"])
        z["market"].append(choice["give_id"])
        entity(world, choice["take_id"])["owner"] = pid
        entity(world, choice["give_id"])["owner"] = -1
    state["seat"] = 1 - pid if pid == state["first_player"] else 2
    return [market_event("MARKET_PASSED" if passed else "MARKET_SWAPPED",
                         dict(player_id=pid, round=round_number, choice=choice))]
