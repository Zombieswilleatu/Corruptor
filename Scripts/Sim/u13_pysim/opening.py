"""Independent production opening, matching U13GameEconomy and scenario setup.

All rules below are explicit Python implementations/constants. No expected
Godot state, legacy simulator, generated snapshot or GDScript parser is used.
"""

from collections import Counter
from . import veil, monsters
from .castle_balance import MAX_INTEGRITY
from .primitives import Entities, draw, entity_id

LORDS = ["Gremory", "Deimos", "Humbaba", "Kalligan", "Orias", "Odradek", "Kroni", "Valak", "Kanifous"]
CASTLES = ["Keep", "Bastion", "SummoningCircle", "Stockpile", "SiegeEngine"]
SUITS = ["Butcher", "Penitent", "Vulture", "Wright"]
COUNTS = [4, 4, 4, 3, 3]
COSTS = {"Orias": 6, "Deimos": 7, "Gremory": 6, "Humbaba": 6, "Kalligan": 4,
         "Odradek": 8, "Kroni": 5, "Valak": 6, "Kanifous": 4}
ECONOMY = "U13_GAME_ECONOMY_V5_FREE_OPENING"
# Opening-rule versioning must not reshuffle the deck used in the accepted A/B.
SHUFFLE_VERSION = "U13_GAME_ECONOMY_V4"
MARKET = "U13_GAME_MARKET_V2"
# Pin the accepted authority's complete roster identity. Matching this hash
# does not assert that the Python mirror implements those powers yet.
RULES_HASH = "42a89676dbc8f311be0b6cf679dc1e6b772f1b480c04a6706c36835b6183b8f4"
POLICY = ":".join([
    "U13_PERMANENT_BREACHES_V1",
    "U13_GUARD_WORK_V4", "U13_VICTORY_V2_ROUND_PRESSURE", "U13_PROFANE_PILLAGE_V1",
    "U13_VULTURE_RANGED_V4", "U13_VACANT_THRONE_V1", "U13_DOMINION_RITES_V1",
    "U13_FRACTURE_V1", "U13_SIGIL_LIFECYCLE_V1", "U13_BLOOD_CONDUIT_V1", MARKET,
    "U13_CASTLE_DEFENSES_V1", ECONOMY, "U13_KANIFOUS_V1", "U13_VALAK_V1",
    "U13_KRONI_WEIGHTED_ANGLES_V8", "U13_ODRADEK_COMPLETE_V2", "U13_ORIAS_MARK_BOARD_V4",
    monsters.VERSION, "U13_BATCH_EVENTS_V1"])


def castle_id(player, slot):
    return entity_id("castle", f"loadout:castle:{player}", slot)


def shuffle(cards, seed, purpose):
    for index in range(len(cards) - 1, 0, -1):
        pick = draw(seed, SHUFFLE_VERSION, purpose, index, index + 1)
        cards[index], cards[pick] = cards[pick], cards[index]


def _initial_data(loadouts):
    # Inert Lord fields are still authoritative state and are compared exactly.
    return {
        "combat_profile": "U13_CORE_ARTILLERY_COMBAT_V1",
        "neutral_tears": 0, "breach_lord": "",
        "sigils": [{"Lord": "", "Castle": ""} for _ in range(2)],
        "rout_profile": "U13_ROUT_V1", "deimos_spoils": [0, 0],
        "deimos_fear_round": [0, 0], "deimos_spoils_events": {},
        "construction_profile": "U13_CASTLE_DEVELOPMENT_V2", "construction_round": 0,
        "construction_targets": ["", ""], "castle_orders": [None, None],
        "castle_slot_profile": "U13_CASTLE_SLOTS_V1", "castle_loadouts": [list(x) for x in loadouts],
        "humbaba_profile": "U13_HUMBABA_BREATH_V2", "lane_aura_profile": "U13_LANE_AURAS_V1",
        "humbaba_end_round": 0, "humbaba_breach_entries": {}, "hunt_profile": "U13_CORE_HUNT_V1",
        "kalligan_profile": "U13_KALLIGAN_FIRE_V1", "hazard_profile": "U13_DISCRETE_HAZARDS_V1",
        "kalligan_upkeep_round": 0, "scorch_guard_round": 0, "scorch_lane_round": 0,
        "rekindle_rounds": [0, 0], "rekindle_defunct_ids": [],
        "guard_deployment_profile": "U13_HAND_GUARD_DEPLOYMENT_V1",
        "guard_deployment_round": 0, "guard_public_round": 0,
        "guard_public_limits": [6, 6], "guard_orders": [None, None], "snare_rounds": [0, 0],
        "resummon_profile": "U13_RESUMMON_V1", "summon_orders": [None, None],
        "summon_round": 0, "summon_counts": [1, 1], "orias_marks": [None, None],
        "snare_paid_rounds": [0, 0], "orias_accelerate": [None, None],
        "orias_profile": "U13_ORIAS_MARK_BOARD_V4", "spatial_field_profile": "U13_SPATIAL_WEB_FIELDS_V1",
        "odradek_profile": "U13_ODRADEK_COMPLETE_V2", "reconfiguration_round": 0,
        "interlock_rounds": [0, 0], "paradox_round": 0,
        "kroni_profile": "U13_KRONI_WEIGHTED_ANGLES_V8", "kroni_feed_round": 0,
        "kroni_action_round": 0, "kroni_breach_round": 0, "kroni_fed": [0, 0], "kroni_actors": [],
        "valak_profile": "U13_VALAK_V1", "valak_reserved": [0, 0], "valak_orbs": [],
        "kanifous_profile": "U13_KANIFOUS_V1", "kanifous_objects": [],
        "kanifous_prices": [], "kanifous_losses": [], "kanifous_loss_round": 0,
        "ranged_profile": "U13_VULTURE_RANGED_V4",
        "blood_conduit_profile": "U13_BLOOD_CONDUIT_V1", "castle_defense_profile": "U13_CASTLE_DEFENSES_V1",
        "sigil_lifecycle": {"version": "U13_SIGIL_LIFECYCLE_V1", "aged_round": 0, "created_round": 0},
        "fracture_profile": "U13_FRACTURE_V1", "fracture_events": {},
        "dominion_rites": {"version": "U13_DOMINION_RITES_V1", "resolved_round": 0,
                           "orders": [None, None], "invocation_rounds": [0, 0]},
        "vacant_throne": {"version": "U13_VACANT_THRONE_V1", "round": 0, "completed_round": 0,
                          "prior_counts": [0, 0], "counts": [0, 0], "present": [False, False]},
        "plunder": {"version": "U13_PROFANE_PILLAGE_V1", "resolved_round": 0, "results": [None, None]},
        "victory": {"version": "U13_VICTORY_V2_ROUND_PRESSURE", "checked_round": 0, "winner": -1, "win_by": ""},
        "guard_work": {"version": "U13_GUARD_WORK_V4", "targets": ["", ""], "pairs": [],
                       "developed_round": 0, "draw_round": 0},
    }


def world(seed, lords, loadouts):
    if type(seed) is not str or not seed or type(lords) is not list or len(lords) != 2 or any(lord not in LORDS for lord in lords):
        raise ValueError("game_setup_invalid")
    if type(loadouts) is not list or len(loadouts) != 2:
        raise ValueError("game_loadout_invalid")
    for selection in loadouts:
        if type(selection) is not list or len(selection) != 5 or any(type(x) is not str or x not in CASTLES for x in selection):
            raise ValueError("game_loadout_invalid")
        if any(count > (1 if kind == "Keep" else 2) for kind, count in Counter(selection).items()):
            raise ValueError("game_loadout_invalid")
    ids = Entities()
    players = []
    active = [[], []]
    for pid, lord in enumerate(lords):
        attributes = {"lord_id": lord, "alive": True}
        if lord != "Humbaba":
            attributes["threat"] = 0
        if lord == "Kroni":
            attributes.update(hunger=0, hunger_milestone=False)
        lord_id = ids.create("lord", f"smoke:lord:{pid}", 0, pid, attributes)
        players.append({"lord_id": lord, "lord_entity_id": lord_id,
                        "resources": {"souls": 0, "personal_tears": 0, "repair_tokens": 0,
                                      "reconfiguration": 0, "life_essence": 0}})
        for slot, kind in enumerate(loadouts[pid]):
            starting = slot < 3
            castle = ids.create("castle", f"loadout:castle:{pid}", slot, pid, {
                "combat_profile": "siege_engine" if kind == "SiegeEngine" else "plain_integrity",
                "status": "standing" if starting else "defunct", "integrity": MAX_INTEGRITY if starting else 0,
                "max_integrity": MAX_INTEGRITY, "base_max_integrity": MAX_INTEGRITY, "artillery_target": "",
                "artillery_acquisitions": 0, "construction_state": "active" if starting else "unbuilt",
                "castle_type": kind, "castle_slot": slot})
            if starting:
                active[pid].append(castle)
    deck = []
    for suit in SUITS:
        suit_cards = []
        for value, count in enumerate(COUNTS, 1):
            for _ in range(count):
                suit_cards.append(ids.create("card", "game:deck:" + suit, len(suit_cards), -1,
                                             {"suit": suit, "value": value}))
        shuffle(suit_cards, seed, "trim:" + suit)
        for card in suit_cards[:3]:
            ids.retire(card)
        deck.extend(suit_cards[3:])
    shuffle(deck, seed, "opening")
    data = _initial_data(loadouts)
    zones = {"hands": [[], []], "deck": deck, "discard": [], "committed": [[], []],
             "hand_limit": 10, "market": [deck.pop() for _ in range(3)], "market_reserve": []}
    data["card_zones"] = zones
    data["game_market"] = {"version": MARKET, "round": 0, "seat": 2,
                           "first_player": draw(seed, MARKET, "FIRST_PLAYER", 0, 2)}
    data["game_economy"] = {"version": ECONOMY, "opening_dealt": True, "draw_round": 0,
                            "draw_player": 2, "stockpile_pending": {},
                            "opening": {"active_castle_count": 3, "active_castle_ids": active, "summons": []}}
    # First summons are free. The ordinary first-round draw creates the hand;
    # paid_development retains the Lord costs and Blood Offering for returns.
    for pid, lord in enumerate(lords):
        data["game_economy"]["opening"]["summons"].append({
            "player_id": pid, "lord_id": lord, "lord_entity_id": players[pid]["lord_entity_id"],
            "cost": 0, "paid_value": 0, "shortfall": 0,
            "card_ids": [], "card_values": [], "circle_id": "", "circle_exerted": 0})
    world = {"players": players, "entities": ids.snapshot(), "data": data}
    monsters.configure(world)
    veil.configure(world)
    return world


def snapshot(seed, lords, loadouts):
    from .copying import copy_data
    state = world(seed, lords, loadouts)
    return {
        "schema_version": "U13_MATCH_V1", "engine_version": "4.7.2",
        "policy_id": POLICY, "rules_hash": RULES_HASH, "rng_version": "U13_SHA256_REJECTION_V1",
        "seed": seed, "world": state, "presentation_world": copy_data(state),
        "submissions": [None, None], "combat_orders": [{}, {}], "player_order": [0, 1],
        "runtime": {"round": 1, "next_hook_index": 0, "next_hook": "round_start_scheduled",
                    "completed": False, "execution_log": [], "timeline_version": "U13_LORD_TIMELINE_V1"},
        "pending": {"schema_version": "U13_PENDING_EFFECTS_V1", "pending": [], "used_ids": []},
        "persistent": {"schema_version": "U13_PERSISTENT_EFFECTS_V1", "active": [], "advanced_round": 0, "used_ids": []},
        "cooldowns": {"schema_version": "U13_COOLDOWNS_V1", "locks": [], "round": 0, "used_ids": []},
        "events": {"schema_version": "U13_EVENT_LOG_V1", "rows": []}}
