#!/usr/bin/env python3
"""
golden_serializer.py — Canonical state serialization for cross-implementation testing.

The Python sim is the ORACLE. This module dumps its state to a stable, ordered,
implementation-agnostic JSON shape that the GDScript engine must reproduce byte
-comparably (after the same normalization).

Design rules for the format:
  * DETERMINISTIC ordering everywhere. Sets -> sorted lists. Dicts -> sorted keys.
    A diff must only ever fire on a real state difference, never on iteration order.
  * NAMES over object identity. Cards are "S{value}" style tokens by suit+value;
    lords/castles are their string ids. No Python object addresses leak in.
  * FLAT and EXPLICIT. Every field the engine must match is named. No "trust the
    class layout" — the schema is the contract, versioned by SCHEMA_VERSION.
  * The snapshot captures COMMITTED state at a phase boundary, not mid-mutation.

A "trace" is: config identity + seed + an ordered list of snapshots, one per
(round, checkpoint). The GDScript loader replays the same seed under the same
config and asserts snapshot-equality at each checkpoint.
"""

import json
import hashlib
from typing import List

SCHEMA_VERSION = 3   # bump when the snapshot shape changes; loaders check this


# ─────────────────────────────────────────────────────────────────────────────
#  CARD / COLLECTION NORMALIZATION
# ─────────────────────────────────────────────────────────────────────────────
def card_token(card) -> str:
    """A card is fully identified by suit+value (no per-instance identity in the
    rules). Token form: 'Butcher:4'. Suits are spelled out to survive any future
    single-letter collisions."""
    return f"{card.suit}:{card.value}"


def card_multiset(cards) -> List[str]:
    """Order-independent canonical form of a card collection. Guards are stripped
    highest-first in combat, but as *stored state* a zone is a multiset — so we
    sort tokens to make the snapshot invariant to insertion order. If ordering
    ever becomes rules-relevant for a zone, that zone gets its own ordered dumper."""
    return sorted(card_token(c) for c in cards)


def string_set(s) -> List[str]:
    return sorted(s)


# ─────────────────────────────────────────────────────────────────────────────
#  PLAYER / GAME SNAPSHOT
# ─────────────────────────────────────────────────────────────────────────────
# Fields are grouped and each is explicit. Round-scoped per-lord ability flags are
# included because they ARE state the engine must reproduce (a mis-set
# odradek_recoil_done changes the next combat). Grouped so a diff points at a
# subsystem, not a soup.

PLAYER_PERSISTENT = [
    "pid", "lord", "alive", "souls", "tears", "threat", "kroni_hunger",
    "repair_token", "first_summon_done",
]
PLAYER_ONCE_PER_GAME = [
    "cataclysmic_used", "vessel_used", "vessel_offered_lord",
    "kalligan_repair_used", "kroni_ravenous_used", "deimos_breach_claimed",
]
PLAYER_ROUND_SCOPED = [
    "action", "tgt_pid", "tgt_type", "ward_target", "prev_ward_target",
    "was_hunted", "was_sieged", "was_lord_attacked_prev", "was_castle_attacked_prev",
    "last_sieged_castle", "pending_profane", "orias_snare_active",
    "profane_ruins_used_this_round", "profane_this_round", "humbaba_patient",
    "odradek_recoil_done", "odradek_guards_defeated",
    "gremory_ruin_done", "gremory_inevitable_ruin_done", "gremory_veil_draw_done",
    "gremory_lord_guard_draw_done", "kanifous_outside_draws",
    "kanifous_invoked_suit", "kanifous_invoked_high", "kanifous_invokes_this_round",
    "kroni_consume_done", "kroni_personally_defeated_guard", "kroni_enemy_destroyed",
    "kroni_tear_milestone_fired",
]


def snapshot_player(pl) -> dict:
    out = {}
    for f in PLAYER_PERSISTENT + PLAYER_ONCE_PER_GAME + PLAYER_ROUND_SCOPED:
        out[f] = getattr(pl, f, None)
    # Collections (canonical/sorted)
    out["hand"]             = card_multiset(pl.hand)
    out["garrison"]         = card_multiset(pl.garrison)
    out["castle_guards"]    = card_multiset(pl.castle_guards)
    out["lord_guards"]      = card_multiset(pl.lord_guards)
    out["committed"]        = card_multiset(pl.committed)
    out["penitent_temp_guards"] = card_multiset(pl.penitent_temp_guards)
    out["castles"]          = string_set(pl.castles)
    out["ruined_castles"]   = string_set(pl.ruined_castles)
    out["profaned_castles"] = string_set(pl.profaned_castles)
    out["lord_pool"]        = list(pl.lord_pool)   # order matters (draft), keep as-is
    # Sigils: fixed-key dict, already deterministic
    out["sigils"]           = {"Lord": pl.sigils["Lord"], "Castle": pl.sigils["Castle"]}
    # Derived values the engine must also compute identically (cheap insurance:
    # catches a defense-formula divergence even when raw fields match)
    out["_derived_lord_def"] = pl.lord_base_def(breach=None)
    return out


def snapshot_game(game, checkpoint: str) -> dict:
    """One canonical snapshot of full game state at a named checkpoint."""
    return {
        "checkpoint":     checkpoint,
        "round":          game.round,
        "first_player":   game.fp,
        "breach":         game.breach,
        "breach_owner":   getattr(game, "breach_owner", -1),
        "reflex_winner":  getattr(game, "reflex_winner", None),
        "neutral_tears":  game.neutral_tears,
        "veil_total":     game._total_tears(),
        "winner":         game.winner,
        "win_by":         getattr(game, "win_by", ""),
        # Shared zones. Deck/discard ORDER matters (draw/search), so NOT sorted —
        # but we dump them as ordered token lists so the engine can match exactly.
        "deck":           [card_token(c) for c in game.deck],
        "discard":        [card_token(c) for c in game.discard],
        "market":         card_multiset(game.market),
        "players":        [snapshot_player(p) for p in game.players],
    }


def normalize_events(events) -> List[dict]:
    """Fake/real resolver events -> comparable list. Only type + sorted data keys;
    display text is NOT compared (it's UI copy, allowed to differ between impls)."""
    out = []
    for e in events or []:
        out.append({
            "type": e.get("type", ""),
            "data": {k: e["data"][k] for k in sorted(e.get("data", {}).keys())},
        })
    return out


# ─────────────────────────────────────────────────────────────────────────────
#  TRACE ASSEMBLY + STABLE HASH
# ─────────────────────────────────────────────────────────────────────────────
def config_identity(variant: dict, constants: dict) -> dict:
    """Which ruleset produced this trace. The loader asserts its RuleConfig maps
    to the same identity before trusting a diff (Law 5: data is invalid across
    config/policy versions)."""
    return {
        "schema_version": SCHEMA_VERSION,
        "constants": {k: constants[k] for k in sorted(constants)},
        "variant":   {k: variant[k]   for k in sorted(variant)},
    }


def canonical_json(obj) -> str:
    """Sorted-key, compact, stable text. This exact function must be mirrored on
    the GDScript side (sorted keys, no spaces) so hashes agree."""
    return json.dumps(obj, sort_keys=True, separators=(",", ":"), ensure_ascii=True)


def trace_hash(snapshots: List[dict]) -> str:
    h = hashlib.sha256()
    for s in snapshots:
        h.update(canonical_json(s).encode("utf-8"))
    return h.hexdigest()


def build_trace(name: str, seed: int, variant: dict, constants: dict,
                snapshots: List[dict], ai_version: str) -> dict:
    return {
        "name":         name,
        "seed":         seed,
        "ai_version":   ai_version,     # Law 5: policy version pins the trace
        "identity":     config_identity(variant, constants),
        "snapshots":    snapshots,
        "trace_hash":   trace_hash(snapshots),
    }
