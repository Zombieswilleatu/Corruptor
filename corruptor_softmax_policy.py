#!/usr/bin/env python3
"""
corruptor_softmax_policy.py

Deterministic Python mirror of the Godot softmax policy at temperature 0.

The rules engine remains in corruptor_sim.py. This module installs the
policy layer used by golden_master.py so Python and Godot compare the same
bot doctrine without relabelling an old trace.

Policy identity:
    softmax-2026.07-v1-golden
"""

from __future__ import annotations

from typing import Any, Dict, List, Optional, Tuple


POLICY_ID = "softmax-2026.07-v1-golden"

ACTION_HUNT = "Hunt"
ACTION_SIEGE = "Siege"
ACTION_WARD = "Ward"
ACTION_PROFANE = "Profane"

TARGET_LORD = "Lord"
TARGET_CASTLE = "Castle"

SIEGE_TARGET_ORDER = [
    "Stockpile",
    "SummoningCircle",
    "SiegeEngine",
    "Bastion",
    "Keep",
]

_SIM = None
_ORIGINAL_PLAYER_RESET_ROUND = None
_ORIGINAL_RESOLVE_HUNT = None
_ORIGINAL_RESOLVE_SIEGE = None


def install(sim_module) -> None:
    """Install the deterministic golden-core doctrine into corruptor_sim."""
    global _SIM
    global _ORIGINAL_PLAYER_RESET_ROUND
    global _ORIGINAL_RESOLVE_HUNT
    global _ORIGINAL_RESOLVE_SIEGE
    _SIM = sim_module

    sim_module.AI_POLICY = POLICY_ID

    player_type = sim_module.Player
    game_type = sim_module.Game

    if _ORIGINAL_PLAYER_RESET_ROUND is None:
        _ORIGINAL_PLAYER_RESET_ROUND = player_type.reset_round

    player_type.reset_round = _reset_round_with_previous_ward

    game_type._ai_market = _ai_market
    game_type._ai_bid = _ai_bid
    game_type._ai_choose_action = _ai_choose_action
    game_type._reserve_for_commitment = _reserve_for_commitment
    game_type._deploy_guards = _deploy_guards
    game_type._pick_siege_target = _pick_siege_target
    game_type._commit_for_attack = _commit_for_attack
    game_type._resolve_order = _resolve_order
    game_type._ai_repair_only = _ai_repair_only
    game_type._ai_offer_vessel = _ai_offer_vessel
    game_type._ai_reflex_choice = _ai_reflex_choice
    game_type._resolve_reflex_action = _resolve_reflex_action

    if _ORIGINAL_RESOLVE_HUNT is None:
        _ORIGINAL_RESOLVE_HUNT = game_type._resolve_hunt
    if _ORIGINAL_RESOLVE_SIEGE is None:
        _ORIGINAL_RESOLVE_SIEGE = game_type._resolve_siege

    game_type._resolve_hunt = _resolve_hunt_without_random_consume
    game_type._resolve_siege = _resolve_siege_without_random_consume


def _reset_round_with_previous_ward(self) -> None:
    """
    Mirror PlayerState.reset_round_state().

    The Python Player already carries prev_ward_target, but the legacy reset
    never copied the completed round's Ward target into it. That silently
    disabled the alternating-Ward doctrine in Python while Godot enforced it.
    """
    if _ORIGINAL_PLAYER_RESET_ROUND is None:
        raise RuntimeError(
            "Golden policy reset wrapper was installed without an original reset."
        )

    previous_ward_target = str(self.ward_target)
    _ORIGINAL_PLAYER_RESET_ROUND(self)
    self.prev_ward_target = previous_ward_target


def _require_sim():
    if _SIM is None:
        raise RuntimeError(
            "corruptor_softmax_policy.install(sim_module) must be called first."
        )
    return _SIM


def _argmax(candidates: List[Dict[str, Any]]) -> Dict[str, Any]:
    if not candidates:
        raise ValueError("Golden policy received no candidates.")

    selected = candidates[0]
    selected_score = float(selected.get("score", float("-inf")))
    selected_tie_rank = int(selected.get("tie_rank", 0))

    for candidate in candidates[1:]:
        score = float(candidate.get("score", float("-inf")))
        tie_rank = int(candidate.get("tie_rank", 0))

        if score > selected_score:
            selected = candidate
            selected_score = score
            selected_tie_rank = tie_rank
            continue

        if score == selected_score and tie_rank > selected_tie_rank:
            selected = candidate
            selected_tie_rank = tie_rank

    return selected


def _stable_sorted_cards(cards, descending: bool = False):
    return sorted(
        list(cards),
        key=lambda card: card.value,
        reverse=descending,
    )


def _card_total(cards) -> int:
    return sum(int(card.value) for card in cards)


def _butcher_bonus(cards) -> int:
    return 1 if sum(1 for card in cards if card.suit == "Butcher") >= 2 else 0


def _profile_for(player) -> Dict[str, Any]:
    sim = _require_sim()
    return sim.LORD_AI.get(
        player.lord,
        {
            "aggro": 1.0,
            "control": 1.0,
            "risk": 1.0,
            "prefer": "",
        },
    )


def _action_candidates(game, player) -> List[Dict[str, Any]]:
    sim = _require_sim()
    opponent = game.opp(player.pid)

    if not player.alive:
        return [
            {
                "action": ACTION_WARD,
                "score": 0.0,
                "tie_rank": 3,
                "chip_siege": False,
            }
        ]

    profile = _profile_for(player)
    plan = game._plan(player, opponent)

    hunt_score = (
        game._score_hunt(player, opponent, plan)
        * float(profile.get("aggro", 1.0))
    )
    siege_score = (
        game._score_siege(player, opponent, plan)
        * float(profile.get("aggro", 1.0))
    )
    ward_score = (
        game._score_ward(player, opponent, plan)
        * float(profile.get("control", 1.0))
    )

    caution = max(0.0, 1.0 - float(profile.get("risk", 1.0)))
    hunt_score -= player.threat * caution * 0.9
    siege_score -= player.threat * caution * 0.5

    preferred_action = str(profile.get("prefer", ""))

    if preferred_action == ACTION_HUNT:
        hunt_score += 0.25
    if preferred_action == ACTION_SIEGE:
        siege_score += 0.25
    if preferred_action == ACTION_WARD:
        ward_score += 0.25

    profane_score = -5.0

    if len(player.castles) >= 3:
        soul_deficit = opponent.souls - player.souls
        tear_lead = player.tears - opponent.tears

        profane_score = 0.0

        if soul_deficit >= 2:
            profane_score += 1.6
        if player.tears >= 2 and tear_lead >= 1:
            profane_score += 1.8
        if plan == "race_dominion":
            profane_score += 1.2
        if plan == "deny_dominion":
            profane_score -= 1.0
        if plan == "deny_ritual":
            profane_score -= 2.0
        if player.lord == "Humbaba":
            profane_score -= 2.5

        if sim.VARIANT["ai_dominion_drive"]:
            profane_score += 0.9

            if len(player.castles) >= 4:
                profane_score += 0.5

            if opponent.alive and opponent.lord == "Odradek":
                profane_score += 0.8

    chip_siege = False

    if (
        opponent.alive
        and opponent.castles
        and opponent.castle_guards
    ):
        if (
            opponent.lord == "Odradek"
            and sim.VARIANT["reconfig_strict"]
            and player.lord == "Humbaba"
        ):
            chip_siege = True
            sigils_standing = (
                "fresh" in player.sigils.values()
                or "flipped" in player.sigils.values()
            )

            if (
                sigils_standing
                and opponent.tears + 1 >= game._dominion_req() - 1
            ):
                siege_score += 4.0
            elif sigils_standing:
                siege_score += 2.2
            else:
                siege_score -= 0.5

        if player.lord == "Kroni" and opponent.lord == "Humbaba":
            siege_score += 1.2
            chip_siege = True

    candidates: List[Dict[str, Any]] = []

    if opponent.alive:
        candidates.append(
            {
                "action": ACTION_HUNT,
                "score": hunt_score,
                "tie_rank": 0,
                "chip_siege": False,
            }
        )

    if opponent.castles:
        candidates.append(
            {
                "action": ACTION_SIEGE,
                "score": siege_score,
                "tie_rank": 2,
                "chip_siege": chip_siege,
            }
        )

    candidates.append(
        {
            "action": ACTION_WARD,
            "score": ward_score,
            "tie_rank": 3,
            "chip_siege": False,
        }
    )

    if len(player.castles) >= 3:
        candidates.append(
            {
                "action": ACTION_PROFANE,
                "score": profane_score,
                "tie_rank": 1,
                "chip_siege": False,
            }
        )

    return candidates


def _ai_market(self, player) -> None:
    """Public deterministic swap: best Market card for worst hand card."""
    if not self.market or not player.hand:
        return

    best_market = max(self.market, key=lambda card: card.value)
    worst_hand = min(player.hand, key=lambda card: card.value)

    if best_market.value <= worst_hand.value:
        return

    self.market.remove(best_market)
    player.hand.remove(worst_hand)
    player.hand.append(best_market)
    self.market.append(worst_hand)


def _ai_bid(self, player):
    """Evaluate bid sizes 0..3 and choose the golden-core argmax."""
    sim = _require_sim()

    if not player.hand:
        return []

    opponent = self.opp(player.pid)
    profile = _profile_for(player)
    plan = self._plan(player, opponent)

    desired_count = 1

    if plan in ("deny_ritual", "deny_dominion"):
        desired_count = 2

    if float(profile.get("control", 1.0)) >= 1.25:
        desired_count = max(desired_count, 2)

    if player.alive and player.souls >= sim.WIN_SOULS - 1:
        desired_count = max(desired_count, 2)

    ordered_hand = _stable_sorted_cards(player.hand)
    maximum_count = min(3, len(ordered_hand))

    candidates: List[Dict[str, Any]] = []

    for bid_count in range(maximum_count + 1):
        bid_cards = ordered_hand[:bid_count]
        bid_total = _card_total(bid_cards)

        score = (
            -abs(bid_count - desired_count) * 2.0
            - bid_total * 0.05
        )

        if bid_count == 0 and desired_count > 0:
            score -= 0.75

        candidates.append(
            {
                "score": score,
                "tie_rank": -bid_count,
                "cards": bid_cards,
            }
        )

    selected = _argmax(candidates)
    bid = list(selected["cards"])

    for card in bid:
        player.hand.remove(card)

    return bid


def _ai_choose_action(self, player) -> None:
    """Deterministic Commitment argmax with no score jitter."""
    sim = _require_sim()
    opponent = self.opp(player.pid)

    if not player.alive:
        player.action = ACTION_WARD
        player.tgt_pid = player.pid
        player.tgt_type = TARGET_CASTLE
        player.ward_target = TARGET_CASTLE
        self._commit_for_ward(player, "neutral")
        return

    plan = self._plan(player, opponent)
    selected = _argmax(_action_candidates(self, player))
    action = selected["action"]

    if action == ACTION_HUNT and opponent.alive:
        player.action = ACTION_HUNT
        player.tgt_pid = opponent.pid
        player.tgt_type = TARGET_LORD
        self._commit_for_attack(
            player,
            opponent,
            TARGET_LORD,
            plan,
        )
        return

    if action == ACTION_SIEGE and opponent.castles:
        player.action = ACTION_SIEGE
        player.tgt_pid = opponent.pid
        player.tgt_type = TARGET_CASTLE
        self._commit_for_attack(
            player,
            opponent,
            TARGET_CASTLE,
            plan,
            chip=bool(selected.get("chip_siege", False)),
        )
        return

    if action == ACTION_PROFANE and len(player.castles) >= 3:
        player.action = ACTION_PROFANE
        player.tgt_pid = player.pid
        player.tgt_type = TARGET_CASTLE

        priority = sim.CASTLE_PRIORITIES.get(
            player.lord,
            sim.CASTLES,
        )

        player.pending_profane = next(
            (
                castle_name
                for castle_name in reversed(priority)
                if castle_name in player.castles
            ),
            next(iter(player.castles)),
        )

        player.committed = []
        return

    player.action = ACTION_WARD
    player.tgt_pid = player.pid

    if plan == "deny_ritual" and player.prev_ward_target != TARGET_LORD:
        player.ward_target = TARGET_LORD
    else:
        wants_lord = player.souls >= 2 or player.threat >= 2
        player.ward_target = TARGET_LORD if wants_lord else TARGET_CASTLE

        if player.ward_target == player.prev_ward_target:
            player.ward_target = (
                TARGET_CASTLE
                if player.ward_target == TARGET_LORD
                else TARGET_LORD
            )

    player.tgt_type = player.ward_target
    self._commit_for_ward(player, plan)


def _reserve_for_commitment(self, player):
    """
    Reserve the exact deterministic Commitment cards, then one lowest card
    from the remainder for Reflex Bid.
    """
    saved_hand = list(player.hand)
    saved_committed = list(player.committed)
    saved_action = player.action
    saved_tgt_pid = player.tgt_pid
    saved_tgt_type = player.tgt_type
    saved_ward_target = player.ward_target
    saved_pending_profane = player.pending_profane

    try:
        _ai_choose_action(self, player)
        reserved = list(player.committed)
    finally:
        player.hand = saved_hand
        player.committed = saved_committed
        player.action = saved_action
        player.tgt_pid = saved_tgt_pid
        player.tgt_type = saved_tgt_type
        player.ward_target = saved_ward_target
        player.pending_profane = saved_pending_profane

    reserved_ids = {id(card) for card in reserved}
    remaining = [
        card
        for card in saved_hand
        if id(card) not in reserved_ids
    ]

    if remaining:
        reserved.append(
            min(
                remaining,
                key=lambda card: card.value,
            )
        )

    return reserved



def _pick_siege_target(self, attacker, defender) -> str:
    """Mirror BotDoctrine.pick_siege_target exactly."""
    if not defender.castles:
        return ""

    if (
        defender.lord == "Deimos"
        and defender.alive
        and "SiegeEngine" in defender.castles
    ):
        return "SiegeEngine"

    for castle_name in SIEGE_TARGET_ORDER:
        if castle_name in defender.castles:
            return castle_name

    return next(iter(defender.castles))


def _commit_for_attack(
    self,
    player,
    opponent,
    target_type: str,
    plan: str,
    chip: bool = False,
) -> None:
    """
    Exact deterministic mirror of BotDoctrine._commit_for_attack.

    This replaces the legacy Python commitment estimator because Deploy reserves
    against this decision before cards move to Guard zones.
    """
    sim = _require_sim()

    if chip:
        chip_guards = (
            opponent.castle_guards
            if target_type == TARGET_CASTLE
            else opponent.lord_guards
        )

        if chip_guards:
            needed_strength = max(
                int(card.value)
                for card in chip_guards
            )

            picked_cards = []
            picked_total = 0

            for card in _stable_sorted_cards(
                player.hand,
                descending=False,
            ):
                if picked_total > needed_strength:
                    break

                picked_cards.append(card)
                picked_total += int(card.value)

            if picked_total > needed_strength:
                for card in picked_cards:
                    player.hand.remove(card)

                player.committed = picked_cards
                return

    if target_type == TARGET_LORD:
        estimated_defense = int(
            opponent.lord_base_def(
                breach=self.breach
            )
        )

        estimated_defense += _card_total(
            opponent.lord_guards
        )

        estimated_defense += max(
            2,
            int(
                self._sigil_value(
                    opponent,
                    opponent.sigils.get(
                        TARGET_LORD,
                        "",
                    ),
                )
            ),
        )
    else:
        target_castle = _pick_siege_target(
            self,
            player,
            opponent,
        )

        estimated_defense = int(
            opponent.castle_def(
                target_castle,
                breach=self.breach,
            )
        )

        if "SiegeEngine" not in player.castles:
            estimated_defense += _card_total(
                opponent.castle_guards
            )

        estimated_defense += max(
            1,
            int(
                self._sigil_value(
                    opponent,
                    opponent.sigils.get(
                        TARGET_CASTLE,
                        "",
                    ),
                )
            ),
        )

    if plan in (
        "deny_ritual",
        "deny_dominion",
    ):
        padding = 2
    elif plan == "protect_souls":
        padding = 0
    else:
        padding = 1

    target_strength = (
        estimated_defense
        + padding
    )

    butchers = _stable_sorted_cards(
        [
            card
            for card in player.hand
            if card.suit == "Butcher"
        ],
        descending=True,
    )

    other_cards = _stable_sorted_cards(
        [
            card
            for card in player.hand
            if card.suit != "Butcher"
        ],
        descending=True,
    )

    committed = []
    committed_total = 0

    wants_bonus = (
        player.lord
        in (
            "Deimos",
            "Orias",
            "Gremory",
        )
        or plan.startswith(
            "deny"
        )
    )

    if wants_bonus:
        selected_butchers = butchers[:2]

        for card in selected_butchers:
            committed.append(card)
            committed_total += int(card.value)

        butchers = butchers[
            len(selected_butchers):
        ]

    for card in (
        butchers
        + other_cards
    ):
        if committed_total >= target_strength:
            break

        committed.append(card)
        committed_total += int(card.value)

    trim_allowance = (
        3
        if plan.startswith(
            "deny"
        )
        else 2
    )

    while (
        len(committed) > 1
        and committed_total
        - int(
            committed[-1].value
        )
        > target_strength
        + trim_allowance
    ):
        removed_card = committed.pop()
        committed_total -= int(
            removed_card.value
        )

    recoil_applies = (
        opponent.lord == "Odradek"
        and opponent.alive
        and not (
            player.lord == "Orias"
            and getattr(
                self,
                "orias_marked_lord",
                "",
            )
            == opponent.lord
        )
        and (
            target_type == TARGET_LORD
            or not sim.VARIANT[
                "recoil_hunts_only"
            ]
        )
    )

    if recoil_applies and committed:
        remaining_hand = list(
            player.hand
        )

        for card in committed:
            remaining_hand.remove(card)

        remaining_hand = _stable_sorted_cards(
            remaining_hand,
            descending=True,
        )

        def effective_recoil_total() -> int:
            if len(committed) <= 1:
                return 0

            values = sorted(
                (
                    int(card.value)
                    for card in committed
                ),
                reverse=True,
            )

            if sim.VARIANT[
                "recoil_lowest"
            ]:
                loss = values[-1]
            else:
                loss = values[1]

            return sum(values) - loss

        for card in remaining_hand:
            if effective_recoil_total() >= target_strength:
                break

            committed.append(card)

    for card in committed:
        player.hand.remove(card)

    player.committed = committed


def _remove_identity(cards, target) -> None:
    for index, card in enumerate(cards):
        if card is target:
            cards.pop(index)
            return

    cards.remove(target)


def _unreserved_cards(
    cards,
    reserved,
    descending: bool,
):
    available = list(cards)

    for reserved_card in reserved:
        try:
            _remove_identity(
                available,
                reserved_card,
            )
        except ValueError:
            continue

    return _stable_sorted_cards(
        available,
        descending=descending,
    )


def _frenzy_blocks_garrison(
    self,
    player,
) -> bool:
    frenzy_active = (
        self.breach == "Orias"
        or (
            self._total_tears() >= 6
            and player.tears < 6
        )
    )

    return (
        frenzy_active
        and player.threat >= 3
    )


def _maximum_castle_guards(
    player,
) -> int:
    sim = _require_sim()

    if (
        player.lord == "Humbaba"
        and sim.VARIANT[
            "humbaba_gate4"
        ]
        and not player.ruined_castles
    ):
        return 4

    return 3


def _build_deploy_plan(
    self,
    player,
):
    """
    Build, but do not apply, one player's Deploy moves.

    Godot computes both players' Deploy choices against the same pre-Deploy
    board, then resolves them. Python's original loop planned player 1 only
    after player 0 had already deployed, changing Commitment reservations.
    """
    sim = _require_sim()
    opponent = self.opp(
        player.pid
    )

    hand = list(
        player.hand
    )

    garrison = list(
        player.garrison
    )

    castle_guard_count = len(
        player.castle_guards
    )

    lord_guard_count = len(
        player.lord_guards
    )

    maximum_castle_guards = (
        _maximum_castle_guards(
            player
        )
    )

    maximum_lord_guards = 3

    frenzy_blocked = (
        _frenzy_blocks_garrison(
            self,
            player,
        )
    )

    repair_blocks_hand = (
        player.repaired_this_round
        and not player
        .repair_token_used_this_repair
    )

    reserved = _reserve_for_commitment(
        self,
        player,
    )

    moves = []

    if player.orias_snare_active:
        selected_card = None
        source_name = ""

        if (
            not frenzy_blocked
            and garrison
        ):
            selected_card = _stable_sorted_cards(
                garrison,
                descending=True,
            )[0]

            source_name = "Garrison"

        if (
            selected_card is None
            and not repair_blocks_hand
        ):
            deployable_hand = (
                _unreserved_cards(
                    hand,
                    reserved,
                    descending=True,
                )
            )

            if deployable_hand:
                selected_card = (
                    deployable_hand[0]
                )

                source_name = "Hand"

        if selected_card is None:
            return moves

        prefer_lord = (
            player.alive
            and opponent.alive
            and not frenzy_blocked
            and lord_guard_count
            < maximum_lord_guards
        )

        if prefer_lord:
            moves.append(
                (
                    source_name,
                    TARGET_LORD,
                    selected_card,
                )
            )

            return moves

        if castle_guard_count < maximum_castle_guards:
            moves.append(
                (
                    source_name,
                    TARGET_CASTLE,
                    selected_card,
                )
            )

            return moves

        if lord_guard_count < maximum_lord_guards:
            moves.append(
                (
                    source_name,
                    TARGET_LORD,
                    selected_card,
                )
            )

        return moves

    garrison_moves = 0

    ordered_garrison = _stable_sorted_cards(
        garrison,
        descending=True,
    )

    if not frenzy_blocked:
        while (
            castle_guard_count
            < maximum_castle_guards
            and ordered_garrison
            and garrison_moves
            < sim.GARRISON_MAX
        ):
            card = ordered_garrison.pop(
                0
            )

            _remove_identity(
                garrison,
                card,
            )

            moves.append(
                (
                    "Garrison",
                    TARGET_CASTLE,
                    card,
                )
            )

            castle_guard_count += 1
            garrison_moves += 1

    if not repair_blocks_hand:
        deployable_hand = (
            _unreserved_cards(
                hand,
                reserved,
                descending=False,
            )
        )

        for card in deployable_hand:
            if (
                castle_guard_count
                >= maximum_castle_guards
            ):
                break

            moves.append(
                (
                    "Hand",
                    TARGET_CASTLE,
                    card,
                )
            )

            _remove_identity(
                hand,
                card,
            )

            castle_guard_count += 1

    castle_full = (
        castle_guard_count
        >= maximum_castle_guards
    )

    if (
        castle_full
        and not frenzy_blocked
    ):
        ordered_garrison = (
            _stable_sorted_cards(
                garrison,
                descending=True,
            )
        )

        while (
            lord_guard_count
            < maximum_lord_guards
            and ordered_garrison
            and garrison_moves
            < sim.GARRISON_MAX
        ):
            card = ordered_garrison.pop(
                0
            )

            _remove_identity(
                garrison,
                card,
            )

            moves.append(
                (
                    "Garrison",
                    TARGET_LORD,
                    card,
                )
            )

            lord_guard_count += 1
            garrison_moves += 1

    if not repair_blocks_hand:
        remaining_deployable = (
            _unreserved_cards(
                hand,
                reserved,
                descending=False,
            )
        )

        for card in remaining_deployable:
            if (
                lord_guard_count
                >= maximum_lord_guards
            ):
                break

            moves.append(
                (
                    "Hand",
                    TARGET_LORD,
                    card,
                )
            )

            _remove_identity(
                hand,
                card,
            )

            lord_guard_count += 1

    return moves


def _apply_deploy_plan(
    player,
    moves,
) -> None:
    for (
        source_name,
        target_name,
        card,
    ) in moves:
        source = (
            player.garrison
            if source_name == "Garrison"
            else player.hand
        )

        target = (
            player.lord_guards
            if target_name == TARGET_LORD
            else player.castle_guards
        )

        _remove_identity(
            source,
            card,
        )

        target.append(
            card
        )


def _deploy_guards(
    self,
    player,
) -> None:
    """
    Mirror BotDeployDoctrine.deploy_choices + DeployEngine.resolve.

    All plans are cached before the first player moves so player 1 does not
    reserve cards against player 0's already-mutated Guard board.
    """
    cache = getattr(
        self,
        "_softmax_deploy_plan_cache",
        None,
    )

    if cache is None:
        cache = {
            int(candidate.pid): (
                _build_deploy_plan(
                    self,
                    candidate,
                )
            )
            for candidate in self.players
        }

        self._softmax_deploy_plan_cache = cache

    moves = cache.get(
        int(
            player.pid
        ),
        [],
    )

    _apply_deploy_plan(
        player,
        moves,
    )

    if int(
        player.pid
    ) == int(
        self.players[-1].pid
    ):
        delattr(
            self,
            "_softmax_deploy_plan_cache",
        )


def _resolve_order(self):
    """Higher Commitment resolves first; ties use the stored first player."""
    value_zero = self.players[0].committed_value()
    value_one = self.players[1].committed_value()

    if value_zero > value_one:
        return [0, 1]

    if value_one > value_zero:
        return [1, 0]

    first = int(self.fp)
    return [first, 1 - first]


def _repair_cost(self, player, castle_name: str, use_token: bool) -> int:
    sim = _require_sim()

    cost = int(sim.CASTLE_COST[castle_name])

    if use_token:
        cost -= 3

    if player.lord == "Kalligan" and player.alive:
        cost -= 5 if player.kalligan_repair_used else 7

    if self.breach == "Kalligan":
        cost -= 1

    return max(1, cost)


def _ai_repair_only(self, player) -> None:
    """Choose an affordable repair atomically; never burn a token on a pass."""
    sim = _require_sim()

    if not player.ruined_castles:
        return

    priority = list(
        sim.CASTLE_PRIORITIES.get(
            player.lord,
            sim.CASTLES,
        )
    )

    available_total = _card_total(player.hand) + _card_total(player.garrison)
    use_token = player.repair_token > 0
    target: Optional[str] = None
    target_cost = 0

    for castle_name in priority:
        if castle_name not in player.ruined_castles:
            continue

        cost = _repair_cost(
            self,
            player,
            castle_name,
            use_token,
        )

        if available_total >= cost:
            target = castle_name
            target_cost = cost
            break

    if target is None:
        return

    if use_token:
        player.repair_token = 0

    self._pay(
        player,
        target_cost,
    )

    player.ruined_castles.discard(target)
    player.castles.add(target)
    player.repaired_this_round = True
    player.repair_token_used_this_repair = use_token

    if player.lord == "Kalligan" and player.alive:
        player.kalligan_repair_used = True
        opponent = self.opp(player.pid)
        self.persist_scorch_pid = opponent.pid
        self.persist_scorch_type = TARGET_LORD


def _dominion_requirement_after_vessel(self, vessel_player_id: int) -> int:
    sim = _require_sim()

    requirement = sim.DOMINION_REQUIREMENT

    if sim.VARIANT["humbaba_seal"]:
        for player in self.players:
            alive_after = (
                False
                if player.pid == vessel_player_id
                else player.alive
            )

            if alive_after and player.lord == "Humbaba":
                requirement += 1
                break

    return requirement


def _ai_offer_vessel(self, player) -> None:
    """Golden doctrine offers only when the current state seals Dominion."""
    sim = _require_sim()

    if player.vessel_used or not player.alive:
        return

    if self.winner is not None:
        return

    opponent = self.opp(player.pid)

    if opponent.souls + 1 >= sim.WIN_SOULS:
        return

    veil_after = self._total_tears() + 1

    if veil_after >= sim.FINAL_COLLAPSE_TRACK:
        return

    if veil_after < sim.DOMINION_TRACK:
        return

    personal_after = player.tears + 1

    if personal_after <= opponent.tears:
        return

    requirement = _dominion_requirement_after_vessel(
        self,
        player.pid,
    )

    if personal_after < requirement:
        return

    player.vessel_used = True
    player.vessel_offered_lord = player.lord

    self._gain_soul(
        opponent,
        1,
    )

    self._discard(
        player.lord_guards[:]
    )

    player.lord_guards.clear()
    player.alive = False

    self._gain_tear(
        player
    )



def _call_without_random_consume(original_method, self, *args, **kwargs):
    """
    The old oracle had probabilistic Consume branches inside combat.
    Godot golden-core consumes only when the Tear immediately seals Dominion.
    Returning 1.0 suppresses only those optional probability gates.
    """
    sim = _require_sim()
    original_random = sim.random.random

    try:
        sim.random.random = lambda: 1.0
        return original_method(self, *args, **kwargs)
    finally:
        sim.random.random = original_random


def _resolve_hunt_without_random_consume(self, *args, **kwargs):
    return _call_without_random_consume(
        _ORIGINAL_RESOLVE_HUNT,
        self,
        *args,
        **kwargs,
    )


def _resolve_siege_without_random_consume(self, *args, **kwargs):
    return _call_without_random_consume(
        _ORIGINAL_RESOLVE_SIEGE,
        self,
        *args,
        **kwargs,
    )

def _effective_guard_total(attacker, guards) -> int:
    if not guards:
        return 0

    total = _card_total(guards)

    ignore_lowest = (
        (
            attacker.lord == "Valak"
            and attacker.alive
            and len(guards) >= 2
        )
        or (
            attacker.lord == "Kanifous"
            and attacker.alive
            and attacker.kanifous_invoked_suit == "Butcher"
        )
    )

    if ignore_lowest:
        total -= min(
            guards,
            key=lambda card: card.value,
        ).value

    return total


def _recoil_adjusted_cards(game, attacker, defender, cards, hunt: bool):
    sim = _require_sim()
    effective = list(cards)

    if not effective:
        return effective

    clean_orias_hunt = (
        hunt
        and attacker.lord == "Orias"
        and getattr(game, "orias_marked_lord", None) == defender.lord
    )

    recoil_applies = (
        defender.lord == "Odradek"
        and defender.alive
        and not defender.odradek_recoil_done
        and not clean_orias_hunt
        and (
            hunt
            or not sim.VARIANT["recoil_hunts_only"]
        )
    )

    if not recoil_applies:
        return effective

    if sim.VARIANT["recoil_lowest"]:
        victim = min(
            effective,
            key=lambda card: card.value,
        )
    else:
        ordered = _stable_sorted_cards(
            effective,
            descending=True,
        )

        victim = ordered[1] if len(ordered) > 1 else ordered[0]

    effective.remove(victim)
    return effective


def _hunt_strength(game, attacker, defender, cards) -> int:
    effective = _recoil_adjusted_cards(
        game,
        attacker,
        defender,
        cards,
        hunt=True,
    )

    strength = _card_total(effective) + _butcher_bonus(effective)

    if attacker.lord == "Orias" and attacker.alive:
        strength += 1

        if defender.threat >= 2:
            strength += 1

    return strength


def _siege_strength(game, attacker, defender, cards) -> int:
    sim = _require_sim()

    effective = _recoil_adjusted_cards(
        game,
        attacker,
        defender,
        cards,
        hunt=False,
    )

    strength = _card_total(effective) + _butcher_bonus(effective)

    if (
        attacker.lord == "Deimos"
        and attacker.alive
        and (
            "SiegeEngine" in attacker.castles
            or sim.VARIANT["deimos_war_machine_free"]
        )
    ):
        lost_castles = len(attacker.ruined_castles)

        if not sim.VARIANT["war_machine_ignores_profaned"]:
            lost_castles += len(attacker.profaned_castles)

        strength += max(
            0,
            2 - lost_castles,
        )

    if attacker.lord == "Kalligan" and attacker.alive:
        strength += 2 if defender.ruined_castles else 1

    return strength


def _minimal_hunt_commit(game, attacker, defender):
    ordered_hand = _stable_sorted_cards(
        attacker.hand,
        descending=True,
    )

    required_defense = (
        defender.lord_base_def(
            breach=game.breach
        )
        + _effective_guard_total(
            attacker,
            defender.lord_guards,
        )
        + game._sigil_value(
            defender,
            defender.sigils["Lord"],
        )
    )

    selected = []

    for card in ordered_hand:
        selected.append(card)

        if _hunt_strength(
            game,
            attacker,
            defender,
            selected,
        ) > required_defense:
            return selected

    return []


def _best_reflex_siege_target(game, attacker, defender) -> str:
    selected_castle = ""
    selected_required = None
    selected_rank = None

    for rank, castle_name in enumerate(SIEGE_TARGET_ORDER):
        if castle_name not in defender.castles:
            continue

        required = (
            defender.castle_def(
                castle_name,
                breach=game.breach,
                game=game,
            )
            + _effective_guard_total(
                attacker,
                defender.castle_guards,
            )
            + game._sigil_value(
                defender,
                defender.sigils["Castle"],
            )
        )

        if (
            selected_required is None
            or required < selected_required
            or (
                required == selected_required
                and rank < selected_rank
            )
        ):
            selected_castle = castle_name
            selected_required = required
            selected_rank = rank

    return selected_castle


def _minimal_siege_commit(game, attacker, defender, target_castle: str):
    ordered_hand = _stable_sorted_cards(
        attacker.hand,
        descending=True,
    )

    required_defense = (
        defender.castle_def(
            target_castle,
            breach=game.breach,
            game=game,
        )
        + _effective_guard_total(
            attacker,
            defender.castle_guards,
        )
        + game._sigil_value(
            defender,
            defender.sigils["Castle"],
        )
    )

    selected = []

    for card in ordered_hand:
        selected.append(card)

        if _siege_strength(
            game,
            attacker,
            defender,
            selected,
        ) > required_defense:
            return selected

    return []


def _ai_reflex_choice(self, player, opponent):
    """Golden-core second action with full board knowledge."""
    sim = _require_sim()

    candidates: List[Dict[str, Any]] = [
        {
            "score": 0.0,
            "tie_rank": 0,
            "choice": None,
        }
    ]

    if player.committed:
        return None

    if opponent.alive and player.threat < sim.MAX_THREAT:
        hunt_cards = _minimal_hunt_commit(
            self,
            player,
            opponent,
        )

        if hunt_cards:
            hunt_score = 3.0

            if opponent.souls >= sim.WIN_SOULS - 2:
                hunt_score += 0.35

            if player.lord == "Orias":
                hunt_score += 0.20

            candidates.append(
                {
                    "score": hunt_score,
                    "tie_rank": 1,
                    "choice": (
                        ACTION_HUNT,
                        hunt_cards,
                        TARGET_LORD,
                    ),
                }
            )

    if opponent.castles:
        target_castle = _best_reflex_siege_target(
            self,
            player,
            opponent,
        )

        if target_castle:
            siege_cards = _minimal_siege_commit(
                self,
                player,
                opponent,
                target_castle,
            )

            if siege_cards:
                siege_score = 2.0

                if len(opponent.castles) <= 2:
                    siege_score += 0.25

                if player.lord in (
                    "Deimos",
                    "Kalligan",
                    "Gremory",
                ):
                    siege_score += 0.20

                candidates.append(
                    {
                        "score": siege_score,
                        "tie_rank": 2,
                        "choice": (
                            ACTION_SIEGE,
                            siege_cards,
                            target_castle,
                        ),
                    }
                )

    if (
        player.alive
        and player.threat >= 2
        and player.sigils["Lord"] == ""
    ):
        candidates.append(
            {
                "score": 1.0 + player.threat * 0.15,
                "tie_rank": 4,
                "choice": (
                    ACTION_WARD,
                    [],
                    TARGET_LORD,
                ),
            }
        )

    if (
        player.castles
        and player.sigils["Castle"] == ""
        and (
            player.souls >= sim.WIN_SOULS - 2
            or player.tears >= 2
        )
    ):
        candidates.append(
            {
                "score": (
                    0.9
                    + player.souls * 0.05
                    + player.tears * 0.10
                ),
                "tie_rank": 3,
                "choice": (
                    ACTION_WARD,
                    [],
                    TARGET_CASTLE,
                ),
            }
        )

    return _argmax(candidates)["choice"]


def _predict_reflex_action(self, winner, target) -> str:
    profile = _profile_for(winner)
    aggression = float(profile.get("aggro", 1.0))
    control = float(profile.get("control", 1.0))
    preferred = str(profile.get("prefer", ""))

    candidates: List[Dict[str, Any]] = []

    if target.alive and winner.threat < _require_sim().MAX_THREAT:
        score = 3.0 * aggression + target.threat * 0.10

        if preferred == ACTION_HUNT:
            score += 0.25

        candidates.append(
            {
                "score": score,
                "tie_rank": 1,
                "action": ACTION_HUNT,
            }
        )

    if target.castles:
        score = 2.0 * aggression + len(target.castles) * 0.05

        if preferred == ACTION_SIEGE:
            score += 0.25

        candidates.append(
            {
                "score": score,
                "tie_rank": 2,
                "action": ACTION_SIEGE,
            }
        )

    can_ward = (
        (
            winner.alive
            and winner.sigils["Lord"] == ""
        )
        or (
            winner.castles
            and winner.sigils["Castle"] == ""
        )
    )

    if can_ward:
        score = 1.0 * control + winner.threat * 0.10

        if preferred == ACTION_WARD:
            score += 0.25

        candidates.append(
            {
                "score": score,
                "tie_rank": 3,
                "action": ACTION_WARD,
            }
        )

    if not candidates:
        return ""

    return str(
        _argmax(candidates)["action"]
    )


def _discard_unexecuted_reflex_cards(self, player, choice) -> None:
    if choice is None:
        return

    cards = list(choice[1])

    for card in cards:
        if card in player.hand:
            player.hand.remove(card)

    self._discard(cards)


def _resolve_reflex_action(self, pid: int) -> None:
    player = self.players[pid]
    opponent = self.opp(pid)

    choice = _ai_reflex_choice(
        self,
        player,
        opponent,
    )

    if (
        self.breach == "Odradek"
        and self.breach_owner >= 0
        and self.breach_owner != pid
        and choice is not None
    ):
        thief = self.players[self.breach_owner]

        if thief.hand:
            guess = _predict_reflex_action(
                self,
                player,
                thief,
            )

            if guess == choice[0]:
                self.stat_breach_triggers += 1

                _discard_unexecuted_reflex_cards(
                    self,
                    player,
                    choice,
                )

                stolen_choice = _ai_reflex_choice(
                    self,
                    thief,
                    player,
                )

                if stolen_choice is not None:
                    self._execute_reflex(
                        thief,
                        player,
                        stolen_choice,
                    )

                return

    if choice is not None:
        self._execute_reflex(
            player,
            opponent,
            choice,
        )
