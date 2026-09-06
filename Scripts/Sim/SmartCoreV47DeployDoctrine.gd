# Promoted from validated experimental V4.7 deploy wrapper.
# DEFENSE_CULPABILITY_HARNESS_V1
# DEFENSE_CULPABILITY_HARNESS_V1_2
# SMART_CORE_EXPERIMENT_V4
# SMART_CORE_EXPERIMENT_V4_1
class_name SmartCoreV47DeployDoctrine
extends RefCounted

const Prod = preload("res://Scripts/Sim/SmartCoreV47BaseDeployDoctrine.gd")
const ExperimentalDoctrine = preload(
    "res://Scripts/Sim/SmartCoreV47Doctrine.gd"
)

static func deploy_choices(game, rules: RuleConfig, policy = null) -> Dictionary:
    var d: Dictionary = Prod.deploy_choices(game, rules)
    if policy == null or not policy.has_method("mode_for"):
        return d

    # Pressure mode changes Commitment selection. Reserve against the actual
    # experimental Commitment plan, not only Production's predicted plan.
    var experimental_commitments: Dictionary = (
        ExperimentalDoctrine.commitment_choices(
            game,
            null,
            rules,
            policy
        )
    )


    # SMART CORE V4.1 — REGROUP hand-cap-aware Deploy.
    #
    # While Keep/Bastion already provides cover, preserve a rebuilding Hand,
    # but allow Production to use cards that would otherwise crowd next round's
    # draw. This is a soft carry target, not a quota: only Production-selected
    # Guard moves are considered, and the cheapest overflow moves are retained.
    for p in game.players:
        var pid: int = int(p.pid)

        if (
            not policy.smart_regroup(pid)
            or not bool(p.alive)
            or policy.emergency_defense(game, pid, rules)
        ):
            continue

        var analysis: Dictionary = (
            ExperimentalDoctrine.smart_regroup_predeploy(
                game,
                pid,
                rules
            )
        )

        if not ExperimentalDoctrine.smart_regroup_entry_allowed(
            analysis,
            policy,
            pid
        ):
            continue

        var choice: Dictionary = _pick(
            d,
            pid
        )

        if (
            choice.is_empty()
            or bool(choice.get("pass", false))
        ):
            continue

        var moves = choice.get(
            "moves",
            []
        )

        if typeof(moves) != TYPE_ARRAY:
            continue

        var kept: Array[Dictionary] = []
        var hand_moves: Array[Dictionary] = []
        var remaining: Array = p.hand.duplicate()

        for raw in moves:
            if typeof(raw) != TYPE_DICTIONARY:
                continue

            var move: Dictionary = raw.duplicate(true)
            move["source_index"] = -1

            if String(move.get("source", "")) != "Hand":
                kept.append(move)
                continue

            var cid: String = String(
                move.get(
                    "card",
                    ""
                )
            )
            var card = _find(
                remaining,
                cid
            )

            if card == null:
                continue

            hand_moves.append({
                "move": move,
                "card": card,
                "value": int(card.value),
                "id": cid,
            })
            remaining.erase(card)

        if hand_moves.is_empty():
            continue

        hand_moves.sort_custom(
            func(a: Dictionary, b: Dictionary) -> bool:
                if int(a["value"]) != int(b["value"]):
                    return int(a["value"]) < int(b["value"])
                return String(a["id"]) < String(b["id"])
        )

        var overflow_budget: int = int(
            analysis.get(
                "overflow",
                0
            )
        )
        var allow_count: int = mini(
            overflow_budget,
            hand_moves.size()
        )

        var planned_commitments: Dictionary = (
            ExperimentalDoctrine.commitment_choices(
                game,
                null,
                rules,
                policy
            )
        )
        var planned_choice: Dictionary = _pick(
            planned_commitments,
            pid
        )
        var raw_planned_ids = planned_choice.get(
            "cards",
            []
        )
        var planned_ids: Array[String] = []
        var planned_spend_count: int = 0
        var planned_spend_value: int = 0

        if typeof(raw_planned_ids) == TYPE_ARRAY:
            for raw_id in raw_planned_ids:
                var planned_id: String = String(raw_id)
                planned_ids.append(planned_id)
                var planned_card = _find(
                    p.hand,
                    planned_id
                )
                if planned_card != null:
                    planned_spend_count += 1
                    planned_spend_value += int(planned_card.value)

        var allowed_count: int = 0
        var allowed_value: int = 0
        var reallocated_count: int = 0
        var reallocated_value: int = 0
        var suppressed_count: int = 0
        var suppressed_value: int = 0

        for index: int in range(hand_moves.size()):
            var entry: Dictionary = hand_moves[index]
            var entry_id: String = String(entry["id"])
            var entry_value: int = int(entry["value"])
            var allow_move: bool = index < allow_count
            var reallocated: bool = false
            var planned_index: int = planned_ids.find(entry_id)

            if (
                not allow_move
                and planned_spend_count > 0
                and entry_value <= planned_spend_value
            ):
                # V4.7: equivalent planned-spend reallocation. One Production
                # Guard may replace one already-planned Commitment card, and
                # total reallocated face may not exceed planned spend.
                allow_move = true
                reallocated = true

            if allow_move:
                kept.append(entry["move"])
                allowed_count += 1
                allowed_value += entry_value

                if planned_index >= 0:
                    planned_ids.remove_at(planned_index)
                    planned_spend_count = maxi(0, planned_spend_count - 1)
                    planned_spend_value = maxi(
                        0,
                        planned_spend_value - entry_value
                    )
                elif reallocated:
                    planned_spend_count = maxi(0, planned_spend_count - 1)
                    planned_spend_value = maxi(
                        0,
                        planned_spend_value - entry_value
                    )

                if reallocated:
                    reallocated_count += 1
                    reallocated_value += entry_value
            else:
                suppressed_count += 1
                suppressed_value += entry_value

        if (
            allowed_count <= 0
            and suppressed_count <= 0
        ):
            continue

        var replacement: Dictionary = (
            {"pass": true}
            if kept.is_empty()
            else {"moves": kept}
        )
        replacement["smart_core_regroup_deploy_allowed"] = (
            allowed_count
        )
        replacement["smart_core_regroup_deploy_allowed_value"] = (
            allowed_value
        )
        replacement["smart_core_regroup_deploy_reallocated"] = (
            reallocated_count
        )
        replacement["smart_core_regroup_deploy_reallocated_value"] = (
            reallocated_value
        )
        replacement["smart_core_regroup_deploy_suppressed"] = (
            suppressed_count
        )
        replacement["smart_core_regroup_deploy_value"] = (
            suppressed_value
        )
        replacement["smart_core_regroup_deploy_carry_target"] = int(
            analysis.get(
                "carry_target",
                0
            )
        )
        replacement["smart_core_regroup_deploy_overflow"] = (
            overflow_budget
        )
        d[pid] = replacement


    for p in game.players:
        var pid := int(p.pid)
        if not policy.constrained(pid) or policy.emergency_defense(game, pid, rules):
            continue
        var x := _pick(d, pid)
        if x.is_empty() or bool(x.get("pass", false)):
            continue
        var moves = x.get("moves", [])
        if typeof(moves) != TYPE_ARRAY:
            continue
        var reserved_ids: Array[String] = []
        var commitment: Dictionary = _pick(
            experimental_commitments,
            pid
        )
        var raw_reserved = commitment.get("cards", [])

        if typeof(raw_reserved) == TYPE_ARRAY:
            for raw_id in raw_reserved:
                reserved_ids.append(String(raw_id))

        var remaining: Array = p.hand.duplicate()
        var kept: Array[Dictionary] = []
        for raw in moves:
            if typeof(raw) != TYPE_DICTIONARY:
                continue
            var m: Dictionary = raw.duplicate(true)
            m["source_index"] = -1
            if String(m.get("source", "")) != "Hand":
                kept.append(m)
                continue

            var card_id: String = String(m.get("card", ""))

            # Card ids are suit:value, so duplicates can exist. Consume one
            # reservation for one matching planned Commitment card.
            var reserved_index: int = reserved_ids.find(card_id)
            if reserved_index >= 0:
                reserved_ids.remove_at(reserved_index)
                continue

            var card = _find(remaining, card_id)
            if card == null:
                continue
            var after: Array = remaining.duplicate()
            after.erase(card)
            if after.size() < int(policy.reserve_cards) or _total(after) < int(policy.reserve_value):
                continue
            kept.append(m)
            remaining.erase(card)
        d[pid] = {"pass": true} if kept.is_empty() else {"moves": kept}
    return d

static func deploy_choice(
    game,
    target_pid: int,
    rules: RuleConfig,
    policy = null
) -> Dictionary:
    var d: Dictionary = {
        target_pid: Prod.deploy_choice(game, target_pid, rules)
    }
    if policy == null or not policy.has_method("mode_for"):
        return _pick(d, target_pid)

    # Pressure mode changes Commitment selection. Reserve against the actual
    # experimental Commitment plan, not only Production's predicted plan.
    var experimental_commitments: Dictionary = {
        target_pid: ExperimentalDoctrine.commitment_choice(
            game, target_pid, null, rules, policy
        )
    }


    # SMART CORE V4.1 — REGROUP hand-cap-aware Deploy.
    #
    # While Keep/Bastion already provides cover, preserve a rebuilding Hand,
    # but allow Production to use cards that would otherwise crowd next round's
    # draw. This is a soft carry target, not a quota: only Production-selected
    # Guard moves are considered, and the cheapest overflow moves are retained.
    for p in game.players:
        if int(p.pid) != target_pid:
            continue
        var pid: int = int(p.pid)

        if (
            not policy.smart_regroup(pid)
            or not bool(p.alive)
            or policy.emergency_defense(game, pid, rules)
        ):
            continue

        var analysis: Dictionary = (
            ExperimentalDoctrine.smart_regroup_predeploy(
                game,
                pid,
                rules
            )
        )

        if not ExperimentalDoctrine.smart_regroup_entry_allowed(
            analysis,
            policy,
            pid
        ):
            continue

        var choice: Dictionary = _pick(
            d,
            pid
        )

        if (
            choice.is_empty()
            or bool(choice.get("pass", false))
        ):
            continue

        var moves = choice.get(
            "moves",
            []
        )

        if typeof(moves) != TYPE_ARRAY:
            continue

        var kept: Array[Dictionary] = []
        var hand_moves: Array[Dictionary] = []
        var remaining: Array = p.hand.duplicate()

        for raw in moves:
            if typeof(raw) != TYPE_DICTIONARY:
                continue

            var move: Dictionary = raw.duplicate(true)
            move["source_index"] = -1

            if String(move.get("source", "")) != "Hand":
                kept.append(move)
                continue

            var cid: String = String(
                move.get(
                    "card",
                    ""
                )
            )
            var card = _find(
                remaining,
                cid
            )

            if card == null:
                continue

            hand_moves.append({
                "move": move,
                "card": card,
                "value": int(card.value),
                "id": cid,
            })
            remaining.erase(card)

        if hand_moves.is_empty():
            continue

        hand_moves.sort_custom(
            func(a: Dictionary, b: Dictionary) -> bool:
                if int(a["value"]) != int(b["value"]):
                    return int(a["value"]) < int(b["value"])
                return String(a["id"]) < String(b["id"])
        )

        var overflow_budget: int = int(
            analysis.get(
                "overflow",
                0
            )
        )
        var allow_count: int = mini(
            overflow_budget,
            hand_moves.size()
        )

        var planned_commitments: Dictionary = (
            ExperimentalDoctrine.commitment_choices(
                game,
                null,
                rules,
                policy
            )
        )
        var planned_choice: Dictionary = _pick(
            planned_commitments,
            pid
        )
        var raw_planned_ids = planned_choice.get(
            "cards",
            []
        )
        var planned_ids: Array[String] = []
        var planned_spend_count: int = 0
        var planned_spend_value: int = 0

        if typeof(raw_planned_ids) == TYPE_ARRAY:
            for raw_id in raw_planned_ids:
                var planned_id: String = String(raw_id)
                planned_ids.append(planned_id)
                var planned_card = _find(
                    p.hand,
                    planned_id
                )
                if planned_card != null:
                    planned_spend_count += 1
                    planned_spend_value += int(planned_card.value)

        var allowed_count: int = 0
        var allowed_value: int = 0
        var reallocated_count: int = 0
        var reallocated_value: int = 0
        var suppressed_count: int = 0
        var suppressed_value: int = 0

        for index: int in range(hand_moves.size()):
            var entry: Dictionary = hand_moves[index]
            var entry_id: String = String(entry["id"])
            var entry_value: int = int(entry["value"])
            var allow_move: bool = index < allow_count
            var reallocated: bool = false
            var planned_index: int = planned_ids.find(entry_id)

            if (
                not allow_move
                and planned_spend_count > 0
                and entry_value <= planned_spend_value
            ):
                # V4.7: equivalent planned-spend reallocation. One Production
                # Guard may replace one already-planned Commitment card, and
                # total reallocated face may not exceed planned spend.
                allow_move = true
                reallocated = true

            if allow_move:
                kept.append(entry["move"])
                allowed_count += 1
                allowed_value += entry_value

                if planned_index >= 0:
                    planned_ids.remove_at(planned_index)
                    planned_spend_count = maxi(0, planned_spend_count - 1)
                    planned_spend_value = maxi(
                        0,
                        planned_spend_value - entry_value
                    )
                elif reallocated:
                    planned_spend_count = maxi(0, planned_spend_count - 1)
                    planned_spend_value = maxi(
                        0,
                        planned_spend_value - entry_value
                    )

                if reallocated:
                    reallocated_count += 1
                    reallocated_value += entry_value
            else:
                suppressed_count += 1
                suppressed_value += entry_value

        if (
            allowed_count <= 0
            and suppressed_count <= 0
        ):
            continue

        var replacement: Dictionary = (
            {"pass": true}
            if kept.is_empty()
            else {"moves": kept}
        )
        replacement["smart_core_regroup_deploy_allowed"] = (
            allowed_count
        )
        replacement["smart_core_regroup_deploy_allowed_value"] = (
            allowed_value
        )
        replacement["smart_core_regroup_deploy_reallocated"] = (
            reallocated_count
        )
        replacement["smart_core_regroup_deploy_reallocated_value"] = (
            reallocated_value
        )
        replacement["smart_core_regroup_deploy_suppressed"] = (
            suppressed_count
        )
        replacement["smart_core_regroup_deploy_value"] = (
            suppressed_value
        )
        replacement["smart_core_regroup_deploy_carry_target"] = int(
            analysis.get(
                "carry_target",
                0
            )
        )
        replacement["smart_core_regroup_deploy_overflow"] = (
            overflow_budget
        )
        d[pid] = replacement


    for p in game.players:
        if int(p.pid) != target_pid:
            continue
        var pid := int(p.pid)
        if not policy.constrained(pid) or policy.emergency_defense(game, pid, rules):
            continue
        var x := _pick(d, pid)
        if x.is_empty() or bool(x.get("pass", false)):
            continue
        var moves = x.get("moves", [])
        if typeof(moves) != TYPE_ARRAY:
            continue
        var reserved_ids: Array[String] = []
        var commitment: Dictionary = _pick(
            experimental_commitments,
            pid
        )
        var raw_reserved = commitment.get("cards", [])

        if typeof(raw_reserved) == TYPE_ARRAY:
            for raw_id in raw_reserved:
                reserved_ids.append(String(raw_id))

        var remaining: Array = p.hand.duplicate()
        var kept: Array[Dictionary] = []
        for raw in moves:
            if typeof(raw) != TYPE_DICTIONARY:
                continue
            var m: Dictionary = raw.duplicate(true)
            m["source_index"] = -1
            if String(m.get("source", "")) != "Hand":
                kept.append(m)
                continue

            var card_id: String = String(m.get("card", ""))

            # Card ids are suit:value, so duplicates can exist. Consume one
            # reservation for one matching planned Commitment card.
            var reserved_index: int = reserved_ids.find(card_id)
            if reserved_index >= 0:
                reserved_ids.remove_at(reserved_index)
                continue

            var card = _find(remaining, card_id)
            if card == null:
                continue
            var after: Array = remaining.duplicate()
            after.erase(card)
            if after.size() < int(policy.reserve_cards) or _total(after) < int(policy.reserve_value):
                continue
            kept.append(m)
            remaining.erase(card)
        d[pid] = {"pass": true} if kept.is_empty() else {"moves": kept}
    return _pick(d, target_pid)


static func _pick(d: Dictionary, pid: int) -> Dictionary:
    var x = d.get(pid, d.get(str(pid), {}))
    return x if typeof(x) == TYPE_DICTIONARY else {}

static func _find(cards: Array, cid: String):
    for card in cards:
        var id := String(card.card_id()) if card.has_method("card_id") else "%s:%d" % [String(card.suit), int(card.value)]
        if id == cid:
            return card
    return null

static func _total(cards: Array) -> int:
    var n := 0
    for card in cards:
        n += int(card.value)
    return n
