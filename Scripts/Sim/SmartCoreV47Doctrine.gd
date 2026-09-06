# SMART_CORE_V47_LAZY_SIEGE_BOUND_V1
# Promoted from validated experimental V4.7 wrapper.
# ALL_LORD_SMART_CORE_PILOT_V1
# DEFENSE_CULPABILITY_HARNESS_V1
class_name SmartCoreV47Doctrine
# SMART_CORE_EXPERIMENT_V1
# SMART_CORE_EXPERIMENT_V4
# SMART_CORE_EXPERIMENT_V4_1
# SMART_CORE_EXPERIMENT_V4_5_THREAT_CONVERSION_GATE
# SMART_CORE_EXPERIMENT_V4_6_RESOURCE_CONVERSION_SANITY
# SMART_CORE_EXPERIMENT_V4_7_CONCRETE_CONVERSION
# SMART_CORE_EXPERIMENT_V4_4_RESOURCE_HORIZON_ARBITRATION
extends RefCounted

const Prod = preload("res://Scripts/Sim/SmartCoreV47BaseDoctrine.gd")
const PolicyData = preload("res://Scripts/Sim/SmartCoreV47ShippingPolicy.gd")
const RoundEngineData = preload("res://Scripts/Sim/RoundEngine.gd")
const CastleIntegrityRulesData = preload("res://Scripts/Sim/CastleIntegrityRules.gd")

const SMART_REGROUP_MEANINGFUL_ATTACK_REACH: float = 0.35
const SMART_REGROUP_NO_FORECAST_FACE: int = 8
const SMART_REGROUP_MEANINGFUL_WARD: int = 6
const SMART_REGROUP_FLEX_CARDS: int = 4
const SMART_REGROUP_FLEX_VALUE: int = 14
const SMART_REGROUP_BAD_ATTACK_RATIO: float = 0.60
const SMART_REGROUP_THREAT_HAND: int = 5
const SMART_REGROUP_MIN_ATTACK_MAX_FACE: int = 4
const SMART_REGROUP_MIN_ATTACK_REACH: float = 0.20
const SMART_REGROUP_CHIP_MAX_CARD: int = 2
const SMART_REGROUP_PROFANE_MIN_SCORE: float = 0.75
const SMART_REGROUP_PROFANE_TOLERANCE: float = 0.75
const SMART_THREAT_ALL_IN_MIN_REACH: float = 0.70
const SMART_REGROUP_DECISIVE_MARGIN: float = 0.75
const SMART_REGROUP_EFFICIENT_WARD_MAX_FACE: int = 6
const SMART_REGROUP_CONVERSION_HUNT_MAX_FACE: int = 9
const SMART_REGROUP_CONVERSION_HUNT_MAX_CARDS: int = 3
const SMART_REGROUP_OVERFLOW_ATTACK_REACH: float = 0.20
const SMART_REGROUP_OPEN_CHIP_REACH: float = 0.20
const SMART_REGROUP_CAP_WARD_MAX_CARDS: int = 2
const SMART_REGROUP_CAP_WARD_MAX_FACE: int = 2

static func market_choices(game, rng = null) -> Dictionary:
    return Prod.market_choices(game, rng)

static func bid_choices(game, rng, rules: RuleConfig, policy = null) -> Dictionary:
    var d: Dictionary = Prod.bid_choices(game, rng, rules, policy)
    if policy == null or not policy.has_method("mode_for"):
        return d
    for p in game.players:
        var pid := int(p.pid)
        if not policy.constrained(pid) or policy.emergency_defense(game, pid, rules):
            continue
        var x := _pick(d, pid)
        if x.is_empty() or bool(x.get("pass", false)):
            continue
        var ids = x.get("cards", [])
        if typeof(ids) != TYPE_ARRAY:
            continue
        var remaining: Array = p.hand.duplicate()
        var kept: Array[String] = []
        for raw_id in ids:
            var cid := String(raw_id)
            var card = _find(remaining, cid)
            if card == null:
                continue
            var after: Array = remaining.duplicate()
            after.erase(card)
            if after.size() < int(policy.reserve_cards) or _total(after) < int(policy.reserve_value):
                continue
            kept.append(cid)
            remaining.erase(card)
        if kept.is_empty():
            d[pid] = {"pass": true}
        else:
            var y: Dictionary = x.duplicate(true)
            y["cards"] = kept
            d[pid] = y
    return d

static func commitment_choices(game, rng, rules: RuleConfig, policy = null) -> Dictionary:
    var d: Dictionary = Prod.commitment_choices(game, rng, rules, policy)
    if policy == null or not policy.has_method("mode_for"):
        return d
    for p in game.players:
        var pid := int(p.pid)
        if policy.mode_for(pid) != PolicyData.MODE_PRESSURE or not bool(p.alive):
            continue
        var o = game.get_opponent(pid)
        if o == null:
            continue
        var best: Dictionary = {}
        var best_score := -INF
        var ward_score := -INF
        var ward_found := false
        for raw in Prod.evaluate_action_candidates(game, pid, rules):
            if typeof(raw) != TYPE_DICTIONARY:
                continue
            var c: Dictionary = raw
            var a := String(c.get("action", ""))
            var s := float(c.get("score", -INF))
            if a in ["Hunt", "Siege"] and s > best_score:
                best = c
                best_score = s
            elif a == "Ward":
                ward_found = true
                ward_score = s
        if best.is_empty():
            continue
        # Human-derived exception from the Kalligan playtest:
        # a visibly loaded opponent can justify a Ward read.
        if o.hand.size() >= 7 and ward_found and ward_score >= best_score + 0.25:
            continue
        d[pid] = Prod._commitment_decision_from_candidate(game, pid, best, rules)

    # SMART CORE V1 — threat/cover read.
    # SMART CORE V4.4 — resource horizon arbitrates BEFORE aggression promotion.
    #
    # Threat Read still asks whether a Production WARD is redundant under
    # structural cover. But before promoting that WARD into a normal Hunt/Siege,
    # Resource Horizon gets first refusal. If the current Hand is a REGROUP
    # state, Threat Read may inform danger, but it cannot force full aggression.
    for p in game.players:
        var pid := int(p.pid)
        if (
            not policy.smart_threat(pid)
            or not bool(p.alive)
            or policy.emergency_defense(game, pid, rules)
        ):
            continue

        var current: Dictionary = _pick(d, pid)
        if String(current.get("action", "")) != "Ward":
            continue

        var opponent = game.get_opponent(pid)
        if opponent == null:
            continue

        var keep_standing: bool = _castle_standing(p, "Keep")
        var bastion_standing: bool = _castle_standing(p, "Bastion")
        var covered: bool = keep_standing or bastion_standing
        var retained_hand: int = int(opponent.hand.size())
        var ward_target: String = String(current.get("target_type", ""))

        var low_threat_under_cover: bool = covered and retained_hand < 5
        var redundant_lord_ward: bool = keep_standing and ward_target == "Lord"

        if not low_threat_under_cover and not redundant_lord_ward:
            continue

        var best_attack: Dictionary = {}
        var best_attack_score: float = -INF
        var ward_score: float = -INF

        for raw in Prod.evaluate_action_candidates(game, pid, rules):
            if typeof(raw) != TYPE_DICTIONARY:
                continue
            var candidate: Dictionary = raw
            var action := String(candidate.get("action", ""))
            var score := float(candidate.get("score", -INF))
            if action in ["Hunt", "Siege"] and score > best_attack_score:
                best_attack = candidate
                best_attack_score = score
            elif action == "Ward":
                ward_score = maxf(ward_score, score)

        if best_attack.is_empty():
            continue

        var tolerance: float = 0.50
        if redundant_lord_ward:
            tolerance = 0.75

        if best_attack_score < ward_score - tolerance:
            continue

        # This is the V4.4 arbitration seam. Only veto a Threat promotion that
        # was ACTUALLY eligible to fire, so TVETO measures real policy conflict
        # rather than merely counting all Regroup rounds.
        if policy.smart_regroup(pid):
            var regroup_gate: Dictionary = _smart_regroup_analysis(
                game,
                pid,
                rules,
                true
            )
            if bool(regroup_gate.get("trigger", false)):
                var vetoed: Dictionary = current.duplicate(true)
                vetoed["smart_core_threat_vetoed_by_regroup"] = true
                vetoed["smart_core_threat_veto_reason"] = "resource_horizon_regroup"
                vetoed["smart_core_threat_veto_attack_score"] = best_attack_score
                vetoed["smart_core_threat_veto_ward_score"] = ward_score
                vetoed["smart_core_opponent_retained_hand"] = retained_hand
                d[pid] = vetoed
                continue

        var replacement: Dictionary = Prod._commitment_decision_from_candidate(
            game,
            pid,
            best_attack,
            rules
        )

        # SMART CORE V4.5 — THREAT CONVERSION GATE.
        #
        # A redundant WARD does not automatically justify cashing the entire
        # Hand into a merely plausible attack. If Threat would turn WARD into
        # an all-in attack, require a strong forecast before spending everything.
        # Otherwise HOLD the Hand through a zero-card WARD. This is deliberately
        # narrow: non-all-in Threat attacks retain V1 behavior unchanged.
        var replacement_cards = replacement.get(
            "cards",
            []
        )
        var replacement_card_count: int = 0
        if typeof(replacement_cards) == TYPE_ARRAY:
            replacement_card_count = replacement_cards.size()

        var attack_reach: float = float(
            best_attack.get(
                "forecast_reach",
                -1.0
            )
        )
        var all_in: bool = (
            not p.hand.is_empty()
            and replacement_card_count >= p.hand.size()
        )

        if (
            all_in
            and attack_reach < SMART_THREAT_ALL_IN_MIN_REACH
        ):
            var hold_choice: Dictionary = current.duplicate(true)
            hold_choice["cards"] = []
            hold_choice["smart_core_threat_conversion_hold"] = true
            hold_choice["smart_core_threat_hold_reason"] = "all_in_low_conversion"
            hold_choice["smart_core_threat_hold_attack_reach"] = attack_reach
            hold_choice["smart_core_threat_hold_attack_score"] = best_attack_score
            hold_choice["smart_core_threat_hold_ward_score"] = ward_score
            hold_choice["smart_core_opponent_retained_hand"] = retained_hand
            hold_choice["smart_core_threat_original_ward_target"] = ward_target
            hold_choice["smart_core_threat_hand_count"] = p.hand.size()
            hold_choice["smart_core_threat_hand_value"] = _total(p.hand)
            d[pid] = hold_choice
            continue

        replacement["smart_core_threat_override"] = true
        replacement["smart_core_threat_reason"] = (
            "keep_screens_lord"
            if redundant_lord_ward
            else "low_threat_under_cover"
        )
        replacement["smart_core_opponent_retained_hand"] = retained_hand

        # SMART THREAT CONSEQUENCE AUDIT V1
        # Diagnostic tags only. These expose information the doctrine already
        # calculated from legal/current state; they do not alter the decision.
        replacement["smart_core_threat_attack_score"] = best_attack_score
        replacement["smart_core_threat_ward_score"] = ward_score
        replacement["smart_core_threat_attack_reach"] = float(
            best_attack.get(
                "forecast_reach",
                -1.0
            )
        )
        replacement["smart_core_threat_candidate_action"] = String(
            best_attack.get(
                "action",
                ""
            )
        )
        replacement["smart_core_threat_candidate_target"] = String(
            best_attack.get(
                "forecast_target",
                ""
            )
        )
        replacement["smart_core_threat_hand_count"] = p.hand.size()
        replacement["smart_core_threat_hand_value"] = _total(p.hand)
        replacement["smart_core_threat_original_ward_target"] = ward_target
        d[pid] = replacement

    # SMART CORE V4.1 — REGROUP with hand-cap pressure.
    #
    # REGROUP is conservation, not hoarding. Preserve cards when current plays
    # are poor, but do not waste next round's draw capacity by carrying more
    # cards than the current rules can profitably absorb.
    #
    # Hand-cap pressure is a SOFT opportunity-cost signal:
    #   - useful Profane remains free,
    #   - small/overflow attacks are allowed,
    #   - open/light Castle chips need either cap pressure or plausible reach,
    #   - 2+ visible Castle Guards can justify a one-card discovery probe,
    #   - otherwise expendable overflow cards may reinforce WARD,
    #   - zero-card WARD remains the fallback.
    #
    # No hidden Guard values are read.
    for p in game.players:
        var pid: int = int(p.pid)

        if (
            not policy.smart_regroup(pid)
            or not bool(p.alive)
            or policy.emergency_defense(game, pid, rules)
        ):
            continue

        var analysis: Dictionary = _smart_regroup_analysis(
            game,
            pid,
            rules,
            true
        )

        if not smart_regroup_entry_allowed(
            analysis,
            policy,
            pid
        ):
            continue

        var current: Dictionary = _pick(d, pid)

        if bool(
            current.get(
                "smart_core_threat_vetoed_by_regroup",
                false
            )
        ):
            analysis["smart_core_threat_vetoed_by_regroup"] = true

        var current_action: String = String(
            current.get(
                "action",
                ""
            )
        )

        if current_action == "Profane":
            var profane_keep: Dictionary = current.duplicate(true)
            _tag_regroup_choice(
                profane_keep,
                analysis,
                "profane"
            )
            d[pid] = profane_keep
            continue

        var profane_candidate: Dictionary = analysis.get(
            "profane_candidate",
            {}
        )
        var profane_score: float = float(
            analysis.get(
                "profane_score",
                -INF
            )
        )
        var attack_score: float = float(
            analysis.get(
                "best_attack_score",
                -INF
            )
        )

        if (
            not profane_candidate.is_empty()
            and profane_score >= SMART_REGROUP_PROFANE_MIN_SCORE
            and profane_score >= attack_score - SMART_REGROUP_PROFANE_TOLERANCE
        ):
            var profane_choice: Dictionary = (
                Prod._commitment_decision_from_candidate(
                    game,
                    pid,
                    profane_candidate,
                    rules
                )
            )
            _tag_regroup_choice(
                profane_choice,
                analysis,
                "profane"
            )
            d[pid] = profane_choice
            continue

        var current_value: int = _ids_total(
            p.hand,
            current.get(
                "cards",
                []
            )
        )
        var current_card_count: int = 0
        var raw_current_cards = current.get(
            "cards",
            []
        )
        if typeof(raw_current_cards) == TYPE_ARRAY:
            current_card_count = raw_current_cards.size()

        var best_attack_score_now: float = float(
            analysis.get("best_attack_score", -INF)
        )
        var ward_score_now: float = float(
            analysis.get("ward_score", -INF)
        )
        var profane_score_now: float = float(
            analysis.get("profane_score", -INF)
        )
        var best_reach_for_decision: float = float(
            analysis.get("best_attack_reach", -1.0)
        )
        var threat_override_active: bool = bool(
            current.get("smart_core_threat_override", false)
        )

        var attack_decisive: bool = (
            best_attack_score_now
            >= maxf(ward_score_now, profane_score_now)
            + SMART_REGROUP_DECISIVE_MARGIN
        )
        var ward_decisive: bool = (
            ward_score_now
            >= maxf(best_attack_score_now, profane_score_now)
            + SMART_REGROUP_DECISIVE_MARGIN
        )

        # Conservation is not the objective by itself. If Production has a
        # clearly superior meaningful opportunity right now, preserve it.
        if (
            not threat_override_active
            and current_action in ["Hunt", "Siege"]
            and current_value > 0
            and attack_decisive
            and best_reach_for_decision >= SMART_REGROUP_MIN_ATTACK_REACH
        ):
            var decisive_attack: Dictionary = current.duplicate(true)
            _tag_regroup_choice(
                decisive_attack,
                analysis,
                "decisive_attack"
            )
            d[pid] = decisive_attack
            continue

        var underlying_ward_effective: int = int(
            analysis.get("ward_effective", 0)
        )
        var underlying_ward_decision: Dictionary = analysis.get(
            "ward_decision",
            {}
        )

        if (
            not threat_override_active
            and ward_decisive
            and underlying_ward_effective >= SMART_REGROUP_MEANINGFUL_WARD
            and not underlying_ward_decision.is_empty()
        ):
            var decisive_ward: Dictionary = underlying_ward_decision.duplicate(true)
            _tag_regroup_choice(
                decisive_ward,
                analysis,
                "decisive_ward"
            )
            d[pid] = decisive_ward
            continue

        # V4.7: efficient meaningful WARD is concrete value now.
        # ALL_LORD_SMART_CORE_PILOT_V1 may disable only this escape for the
        # full-roster minus-EWARD counterfactual. Current V4.7 is unchanged.
        if (
            policy.smart_core_eward_enabled(pid)
            and not threat_override_active
            and current_action == "Ward"
            and current_value > 0
            and current_value <= SMART_REGROUP_EFFICIENT_WARD_MAX_FACE
            and underlying_ward_effective >= SMART_REGROUP_MEANINGFUL_WARD
            and not underlying_ward_decision.is_empty()
        ):
            var efficient_ward: Dictionary = underlying_ward_decision.duplicate(true)
            _tag_regroup_choice(
                efficient_ward,
                analysis,
                "efficient_ward"
            )
            d[pid] = efficient_ward
            continue

        var best_reach: float = float(
            analysis.get(
                "best_attack_reach",
                -1.0
            )
        )
        var overflow: int = int(
            analysis.get(
                "overflow",
                0
            )
        )

        # V4.7: bounded Hunt conversion. Production already selected Hunt;
        # preserve it only when the spend and card count stay modest and the
        # existing minimum forecast-reach floor is met.
        if (
            not threat_override_active
            and current_action == "Hunt"
            and current_value > 0
            and current_value <= SMART_REGROUP_CONVERSION_HUNT_MAX_FACE
            and current_card_count > 0
            and current_card_count <= SMART_REGROUP_CONVERSION_HUNT_MAX_CARDS
            and best_reach >= SMART_REGROUP_MIN_ATTACK_REACH
        ):
            var conversion_hunt: Dictionary = current.duplicate(true)
            _tag_regroup_choice(
                conversion_hunt,
                analysis,
                "conversion_hunt"
            )
            d[pid] = conversion_hunt
            continue

        if (
            current_action in ["Hunt", "Siege"]
            and current_value > 0
            and current_value <= SMART_REGROUP_MIN_ATTACK_MAX_FACE
            and best_reach >= SMART_REGROUP_MIN_ATTACK_REACH
        ):
            var minimum_attack: Dictionary = current.duplicate(true)
            _tag_regroup_choice(
                minimum_attack,
                analysis,
                "minimum_attack"
            )
            d[pid] = minimum_attack
            continue

        # If a modest attack consumes only cards that would otherwise crowd
        # next round's draw, it is no longer "wasting the rebuilding hand."
        if (
            overflow > 0
            and current_action in ["Hunt", "Siege"]
            and current_card_count > 0
            and current_card_count <= overflow
            and best_reach >= SMART_REGROUP_OVERFLOW_ATTACK_REACH
        ):
            var overflow_attack: Dictionary = current.duplicate(true)
            _tag_regroup_choice(
                overflow_attack,
                analysis,
                "overflow_attack"
            )
            d[pid] = overflow_attack
            continue

        var opponent = game.get_opponent(pid)
        var covered: bool = bool(
            analysis.get(
                "covered",
                false
            )
        )
        var high_threat: bool = bool(
            analysis.get(
                "high_threat",
                false
            )
        )

        if (
            opponent != null
            and not opponent.castles.is_empty()
            and (covered or not high_threat)
        ):
            var cheap_card = _lowest_hand_card(
                p.hand
            )

            if (
                cheap_card != null
                and int(cheap_card.value) <= SMART_REGROUP_CHIP_MAX_CARD
            ):
                var siege_candidate: Dictionary = analysis.get(
                    "siege_candidate",
                    {}
                )
                var siege_reach: float = float(
                    analysis.get(
                        "siege_reach",
                        -1.0
                    )
                )
                var guard_count: int = opponent.castle_guards.size()

                # Open/light probes are no longer automatic. They need either
                # cap pressure or some plausible Siege reach. Heavy visible
                # Guard saturation still has discovery value by itself.
                var probe_reason: bool = (
                    overflow > 0
                    or guard_count >= 2
                    or (
                        guard_count <= 1
                        and siege_reach >= SMART_REGROUP_OPEN_CHIP_REACH
                    )
                )

                if (
                    probe_reason
                    and not siege_candidate.is_empty()
                ):
                    var chip_choice: Dictionary = (
                        Prod._commitment_decision_from_candidate(
                            game,
                            pid,
                            siege_candidate,
                            rules
                        )
                    )
                    chip_choice["cards"] = [
                        _id(cheap_card),
                    ]

                    var chip_kind: String = "chip_open"

                    if guard_count == 1:
                        chip_kind = "chip_light"
                    elif guard_count >= 2:
                        chip_kind = "chip_discovery"

                    _tag_regroup_choice(
                        chip_choice,
                        analysis,
                        chip_kind
                    )
                    d[pid] = chip_choice
                    continue

        var ward_candidate: Dictionary = analysis.get(
            "ward_candidate",
            {}
        )
        var ward_choice: Dictionary = {}

        if not ward_candidate.is_empty():
            ward_choice = Prod._commitment_decision_from_candidate(
                game,
                pid,
                ward_candidate,
                rules
            )
        elif current_action == "Ward":
            ward_choice = current.duplicate(true)
        else:
            ward_choice = {
                "action": "Ward",
                "target_pid": pid,
                "target_type": (
                    "Lord"
                    if not _castle_standing(p, "Keep")
                    else "Castle"
                ),
                "cards": [],
            }

        # If low-value cards would otherwise crowd the next draw, turn a small
        # amount of that overflow into real WARD reinforcement instead of
        # blindly carrying every card. Expensive cards are still allowed to
        # stay even when this sacrifices some draw room.
        var cap_ward_cards: Array[String] = (
            _cheap_expendable_ids(
                p.hand,
                overflow,
                SMART_REGROUP_CAP_WARD_MAX_CARDS,
                SMART_REGROUP_CAP_WARD_MAX_FACE
            )
        )

        if not cap_ward_cards.is_empty():
            ward_choice["cards"] = cap_ward_cards
            _tag_regroup_choice(
                ward_choice,
                analysis,
                "cap_ward"
            )
            d[pid] = ward_choice
            continue

        ward_choice["cards"] = []
        _tag_regroup_choice(
            ward_choice,
            analysis,
            "zero_ward"
        )
        d[pid] = ward_choice


    return d

static func commitment_choice(
    game,
    target_pid: int,
    rng,
    rules: RuleConfig,
    policy = null
) -> Dictionary:
    var d: Dictionary = {
        target_pid: Prod.commitment_choice(
            game, target_pid, rng, rules, policy
        )
    }
    if policy == null or not policy.has_method("mode_for"):
        return _pick(d, target_pid)
    for p in game.players:
        if int(p.pid) != target_pid:
            continue
        var pid := int(p.pid)
        if policy.mode_for(pid) != PolicyData.MODE_PRESSURE or not bool(p.alive):
            continue
        var o = game.get_opponent(pid)
        if o == null:
            continue
        var best: Dictionary = {}
        var best_score := -INF
        var ward_score := -INF
        var ward_found := false
        for raw in Prod.evaluate_action_candidates(game, pid, rules):
            if typeof(raw) != TYPE_DICTIONARY:
                continue
            var c: Dictionary = raw
            var a := String(c.get("action", ""))
            var s := float(c.get("score", -INF))
            if a in ["Hunt", "Siege"] and s > best_score:
                best = c
                best_score = s
            elif a == "Ward":
                ward_found = true
                ward_score = s
        if best.is_empty():
            continue
        # Human-derived exception from the Kalligan playtest:
        # a visibly loaded opponent can justify a Ward read.
        if o.hand.size() >= 7 and ward_found and ward_score >= best_score + 0.25:
            continue
        d[pid] = Prod._commitment_decision_from_candidate(game, pid, best, rules)

    # SMART CORE V1 — threat/cover read.
    # SMART CORE V4.4 — resource horizon arbitrates BEFORE aggression promotion.
    #
    # Threat Read still asks whether a Production WARD is redundant under
    # structural cover. But before promoting that WARD into a normal Hunt/Siege,
    # Resource Horizon gets first refusal. If the current Hand is a REGROUP
    # state, Threat Read may inform danger, but it cannot force full aggression.
    for p in game.players:
        if int(p.pid) != target_pid:
            continue
        var pid := int(p.pid)
        if (
            not policy.smart_threat(pid)
            or not bool(p.alive)
            or policy.emergency_defense(game, pid, rules)
        ):
            continue

        var current: Dictionary = _pick(d, pid)
        if String(current.get("action", "")) != "Ward":
            continue

        var opponent = game.get_opponent(pid)
        if opponent == null:
            continue

        var keep_standing: bool = _castle_standing(p, "Keep")
        var bastion_standing: bool = _castle_standing(p, "Bastion")
        var covered: bool = keep_standing or bastion_standing
        var retained_hand: int = int(opponent.hand.size())
        var ward_target: String = String(current.get("target_type", ""))

        var low_threat_under_cover: bool = covered and retained_hand < 5
        var redundant_lord_ward: bool = keep_standing and ward_target == "Lord"

        if not low_threat_under_cover and not redundant_lord_ward:
            continue

        var best_attack: Dictionary = {}
        var best_attack_score: float = -INF
        var ward_score: float = -INF

        for raw in Prod.evaluate_action_candidates(game, pid, rules):
            if typeof(raw) != TYPE_DICTIONARY:
                continue
            var candidate: Dictionary = raw
            var action := String(candidate.get("action", ""))
            var score := float(candidate.get("score", -INF))
            if action in ["Hunt", "Siege"] and score > best_attack_score:
                best_attack = candidate
                best_attack_score = score
            elif action == "Ward":
                ward_score = maxf(ward_score, score)

        if best_attack.is_empty():
            continue

        var tolerance: float = 0.50
        if redundant_lord_ward:
            tolerance = 0.75

        if best_attack_score < ward_score - tolerance:
            continue

        # This is the V4.4 arbitration seam. Only veto a Threat promotion that
        # was ACTUALLY eligible to fire, so TVETO measures real policy conflict
        # rather than merely counting all Regroup rounds.
        if policy.smart_regroup(pid):
            var regroup_gate: Dictionary = _smart_regroup_analysis(
                game,
                pid,
                rules,
                true
            )
            if bool(regroup_gate.get("trigger", false)):
                var vetoed: Dictionary = current.duplicate(true)
                vetoed["smart_core_threat_vetoed_by_regroup"] = true
                vetoed["smart_core_threat_veto_reason"] = "resource_horizon_regroup"
                vetoed["smart_core_threat_veto_attack_score"] = best_attack_score
                vetoed["smart_core_threat_veto_ward_score"] = ward_score
                vetoed["smart_core_opponent_retained_hand"] = retained_hand
                d[pid] = vetoed
                continue

        var replacement: Dictionary = Prod._commitment_decision_from_candidate(
            game,
            pid,
            best_attack,
            rules
        )

        # SMART CORE V4.5 — THREAT CONVERSION GATE.
        #
        # A redundant WARD does not automatically justify cashing the entire
        # Hand into a merely plausible attack. If Threat would turn WARD into
        # an all-in attack, require a strong forecast before spending everything.
        # Otherwise HOLD the Hand through a zero-card WARD. This is deliberately
        # narrow: non-all-in Threat attacks retain V1 behavior unchanged.
        var replacement_cards = replacement.get(
            "cards",
            []
        )
        var replacement_card_count: int = 0
        if typeof(replacement_cards) == TYPE_ARRAY:
            replacement_card_count = replacement_cards.size()

        var attack_reach: float = float(
            best_attack.get(
                "forecast_reach",
                -1.0
            )
        )
        var all_in: bool = (
            not p.hand.is_empty()
            and replacement_card_count >= p.hand.size()
        )

        if (
            all_in
            and attack_reach < SMART_THREAT_ALL_IN_MIN_REACH
        ):
            var hold_choice: Dictionary = current.duplicate(true)
            hold_choice["cards"] = []
            hold_choice["smart_core_threat_conversion_hold"] = true
            hold_choice["smart_core_threat_hold_reason"] = "all_in_low_conversion"
            hold_choice["smart_core_threat_hold_attack_reach"] = attack_reach
            hold_choice["smart_core_threat_hold_attack_score"] = best_attack_score
            hold_choice["smart_core_threat_hold_ward_score"] = ward_score
            hold_choice["smart_core_opponent_retained_hand"] = retained_hand
            hold_choice["smart_core_threat_original_ward_target"] = ward_target
            hold_choice["smart_core_threat_hand_count"] = p.hand.size()
            hold_choice["smart_core_threat_hand_value"] = _total(p.hand)
            d[pid] = hold_choice
            continue

        replacement["smart_core_threat_override"] = true
        replacement["smart_core_threat_reason"] = (
            "keep_screens_lord"
            if redundant_lord_ward
            else "low_threat_under_cover"
        )
        replacement["smart_core_opponent_retained_hand"] = retained_hand

        # SMART THREAT CONSEQUENCE AUDIT V1
        # Diagnostic tags only. These expose information the doctrine already
        # calculated from legal/current state; they do not alter the decision.
        replacement["smart_core_threat_attack_score"] = best_attack_score
        replacement["smart_core_threat_ward_score"] = ward_score
        replacement["smart_core_threat_attack_reach"] = float(
            best_attack.get(
                "forecast_reach",
                -1.0
            )
        )
        replacement["smart_core_threat_candidate_action"] = String(
            best_attack.get(
                "action",
                ""
            )
        )
        replacement["smart_core_threat_candidate_target"] = String(
            best_attack.get(
                "forecast_target",
                ""
            )
        )
        replacement["smart_core_threat_hand_count"] = p.hand.size()
        replacement["smart_core_threat_hand_value"] = _total(p.hand)
        replacement["smart_core_threat_original_ward_target"] = ward_target
        d[pid] = replacement

    # SMART CORE V4.1 — REGROUP with hand-cap pressure.
    #
    # REGROUP is conservation, not hoarding. Preserve cards when current plays
    # are poor, but do not waste next round's draw capacity by carrying more
    # cards than the current rules can profitably absorb.
    #
    # Hand-cap pressure is a SOFT opportunity-cost signal:
    #   - useful Profane remains free,
    #   - small/overflow attacks are allowed,
    #   - open/light Castle chips need either cap pressure or plausible reach,
    #   - 2+ visible Castle Guards can justify a one-card discovery probe,
    #   - otherwise expendable overflow cards may reinforce WARD,
    #   - zero-card WARD remains the fallback.
    #
    # No hidden Guard values are read.
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

        var analysis: Dictionary = _smart_regroup_analysis(
            game,
            pid,
            rules,
            true
        )

        if not smart_regroup_entry_allowed(
            analysis,
            policy,
            pid
        ):
            continue

        var current: Dictionary = _pick(d, pid)

        if bool(
            current.get(
                "smart_core_threat_vetoed_by_regroup",
                false
            )
        ):
            analysis["smart_core_threat_vetoed_by_regroup"] = true

        var current_action: String = String(
            current.get(
                "action",
                ""
            )
        )

        if current_action == "Profane":
            var profane_keep: Dictionary = current.duplicate(true)
            _tag_regroup_choice(
                profane_keep,
                analysis,
                "profane"
            )
            d[pid] = profane_keep
            continue

        var profane_candidate: Dictionary = analysis.get(
            "profane_candidate",
            {}
        )
        var profane_score: float = float(
            analysis.get(
                "profane_score",
                -INF
            )
        )
        var attack_score: float = float(
            analysis.get(
                "best_attack_score",
                -INF
            )
        )

        if (
            not profane_candidate.is_empty()
            and profane_score >= SMART_REGROUP_PROFANE_MIN_SCORE
            and profane_score >= attack_score - SMART_REGROUP_PROFANE_TOLERANCE
        ):
            var profane_choice: Dictionary = (
                Prod._commitment_decision_from_candidate(
                    game,
                    pid,
                    profane_candidate,
                    rules
                )
            )
            _tag_regroup_choice(
                profane_choice,
                analysis,
                "profane"
            )
            d[pid] = profane_choice
            continue

        var current_value: int = _ids_total(
            p.hand,
            current.get(
                "cards",
                []
            )
        )
        var current_card_count: int = 0
        var raw_current_cards = current.get(
            "cards",
            []
        )
        if typeof(raw_current_cards) == TYPE_ARRAY:
            current_card_count = raw_current_cards.size()

        var best_attack_score_now: float = float(
            analysis.get("best_attack_score", -INF)
        )
        var ward_score_now: float = float(
            analysis.get("ward_score", -INF)
        )
        var profane_score_now: float = float(
            analysis.get("profane_score", -INF)
        )
        var best_reach_for_decision: float = float(
            analysis.get("best_attack_reach", -1.0)
        )
        var threat_override_active: bool = bool(
            current.get("smart_core_threat_override", false)
        )

        var attack_decisive: bool = (
            best_attack_score_now
            >= maxf(ward_score_now, profane_score_now)
            + SMART_REGROUP_DECISIVE_MARGIN
        )
        var ward_decisive: bool = (
            ward_score_now
            >= maxf(best_attack_score_now, profane_score_now)
            + SMART_REGROUP_DECISIVE_MARGIN
        )

        # Conservation is not the objective by itself. If Production has a
        # clearly superior meaningful opportunity right now, preserve it.
        if (
            not threat_override_active
            and current_action in ["Hunt", "Siege"]
            and current_value > 0
            and attack_decisive
            and best_reach_for_decision >= SMART_REGROUP_MIN_ATTACK_REACH
        ):
            var decisive_attack: Dictionary = current.duplicate(true)
            _tag_regroup_choice(
                decisive_attack,
                analysis,
                "decisive_attack"
            )
            d[pid] = decisive_attack
            continue

        var underlying_ward_effective: int = int(
            analysis.get("ward_effective", 0)
        )
        var underlying_ward_decision: Dictionary = analysis.get(
            "ward_decision",
            {}
        )

        if (
            not threat_override_active
            and ward_decisive
            and underlying_ward_effective >= SMART_REGROUP_MEANINGFUL_WARD
            and not underlying_ward_decision.is_empty()
        ):
            var decisive_ward: Dictionary = underlying_ward_decision.duplicate(true)
            _tag_regroup_choice(
                decisive_ward,
                analysis,
                "decisive_ward"
            )
            d[pid] = decisive_ward
            continue

        # V4.7: efficient meaningful WARD is concrete value now.
        # ALL_LORD_SMART_CORE_PILOT_V1 may disable only this escape for the
        # full-roster minus-EWARD counterfactual. Current V4.7 is unchanged.
        if (
            policy.smart_core_eward_enabled(pid)
            and not threat_override_active
            and current_action == "Ward"
            and current_value > 0
            and current_value <= SMART_REGROUP_EFFICIENT_WARD_MAX_FACE
            and underlying_ward_effective >= SMART_REGROUP_MEANINGFUL_WARD
            and not underlying_ward_decision.is_empty()
        ):
            var efficient_ward: Dictionary = underlying_ward_decision.duplicate(true)
            _tag_regroup_choice(
                efficient_ward,
                analysis,
                "efficient_ward"
            )
            d[pid] = efficient_ward
            continue

        var best_reach: float = float(
            analysis.get(
                "best_attack_reach",
                -1.0
            )
        )
        var overflow: int = int(
            analysis.get(
                "overflow",
                0
            )
        )

        # V4.7: bounded Hunt conversion. Production already selected Hunt;
        # preserve it only when the spend and card count stay modest and the
        # existing minimum forecast-reach floor is met.
        if (
            not threat_override_active
            and current_action == "Hunt"
            and current_value > 0
            and current_value <= SMART_REGROUP_CONVERSION_HUNT_MAX_FACE
            and current_card_count > 0
            and current_card_count <= SMART_REGROUP_CONVERSION_HUNT_MAX_CARDS
            and best_reach >= SMART_REGROUP_MIN_ATTACK_REACH
        ):
            var conversion_hunt: Dictionary = current.duplicate(true)
            _tag_regroup_choice(
                conversion_hunt,
                analysis,
                "conversion_hunt"
            )
            d[pid] = conversion_hunt
            continue

        if (
            current_action in ["Hunt", "Siege"]
            and current_value > 0
            and current_value <= SMART_REGROUP_MIN_ATTACK_MAX_FACE
            and best_reach >= SMART_REGROUP_MIN_ATTACK_REACH
        ):
            var minimum_attack: Dictionary = current.duplicate(true)
            _tag_regroup_choice(
                minimum_attack,
                analysis,
                "minimum_attack"
            )
            d[pid] = minimum_attack
            continue

        # If a modest attack consumes only cards that would otherwise crowd
        # next round's draw, it is no longer "wasting the rebuilding hand."
        if (
            overflow > 0
            and current_action in ["Hunt", "Siege"]
            and current_card_count > 0
            and current_card_count <= overflow
            and best_reach >= SMART_REGROUP_OVERFLOW_ATTACK_REACH
        ):
            var overflow_attack: Dictionary = current.duplicate(true)
            _tag_regroup_choice(
                overflow_attack,
                analysis,
                "overflow_attack"
            )
            d[pid] = overflow_attack
            continue

        var opponent = game.get_opponent(pid)
        var covered: bool = bool(
            analysis.get(
                "covered",
                false
            )
        )
        var high_threat: bool = bool(
            analysis.get(
                "high_threat",
                false
            )
        )

        if (
            opponent != null
            and not opponent.castles.is_empty()
            and (covered or not high_threat)
        ):
            var cheap_card = _lowest_hand_card(
                p.hand
            )

            if (
                cheap_card != null
                and int(cheap_card.value) <= SMART_REGROUP_CHIP_MAX_CARD
            ):
                var siege_candidate: Dictionary = analysis.get(
                    "siege_candidate",
                    {}
                )
                var siege_reach: float = float(
                    analysis.get(
                        "siege_reach",
                        -1.0
                    )
                )
                var guard_count: int = opponent.castle_guards.size()

                # Open/light probes are no longer automatic. They need either
                # cap pressure or some plausible Siege reach. Heavy visible
                # Guard saturation still has discovery value by itself.
                var probe_reason: bool = (
                    overflow > 0
                    or guard_count >= 2
                    or (
                        guard_count <= 1
                        and siege_reach >= SMART_REGROUP_OPEN_CHIP_REACH
                    )
                )

                if (
                    probe_reason
                    and not siege_candidate.is_empty()
                ):
                    var chip_choice: Dictionary = (
                        Prod._commitment_decision_from_candidate(
                            game,
                            pid,
                            siege_candidate,
                            rules
                        )
                    )
                    chip_choice["cards"] = [
                        _id(cheap_card),
                    ]

                    var chip_kind: String = "chip_open"

                    if guard_count == 1:
                        chip_kind = "chip_light"
                    elif guard_count >= 2:
                        chip_kind = "chip_discovery"

                    _tag_regroup_choice(
                        chip_choice,
                        analysis,
                        chip_kind
                    )
                    d[pid] = chip_choice
                    continue

        var ward_candidate: Dictionary = analysis.get(
            "ward_candidate",
            {}
        )
        var ward_choice: Dictionary = {}

        if not ward_candidate.is_empty():
            ward_choice = Prod._commitment_decision_from_candidate(
                game,
                pid,
                ward_candidate,
                rules
            )
        elif current_action == "Ward":
            ward_choice = current.duplicate(true)
        else:
            ward_choice = {
                "action": "Ward",
                "target_pid": pid,
                "target_type": (
                    "Lord"
                    if not _castle_standing(p, "Keep")
                    else "Castle"
                ),
                "cards": [],
            }

        # If low-value cards would otherwise crowd the next draw, turn a small
        # amount of that overflow into real WARD reinforcement instead of
        # blindly carrying every card. Expensive cards are still allowed to
        # stay even when this sacrifices some draw room.
        var cap_ward_cards: Array[String] = (
            _cheap_expendable_ids(
                p.hand,
                overflow,
                SMART_REGROUP_CAP_WARD_MAX_CARDS,
                SMART_REGROUP_CAP_WARD_MAX_FACE
            )
        )

        if not cap_ward_cards.is_empty():
            ward_choice["cards"] = cap_ward_cards
            _tag_regroup_choice(
                ward_choice,
                analysis,
                "cap_ward"
            )
            d[pid] = ward_choice
            continue

        ward_choice["cards"] = []
        _tag_regroup_choice(
            ward_choice,
            analysis,
            "zero_ward"
        )
        d[pid] = ward_choice


    return _pick(d, target_pid)


static func smart_regroup_predeploy(
    game,
    pid: int,
    rules: RuleConfig
) -> Dictionary:
    var analysis: Dictionary = _smart_regroup_analysis(
        game,
        pid,
        rules,
        false
    )

    # Before Deploy, opponent retained-Hand intent does not yet exist.
    # Only suppress Hand->Guard spending when existing structures already
    # provide cover. If exposed, Production deployment remains authoritative.
    analysis["trigger"] = (
        bool(analysis.get("trigger", false))
        and bool(analysis.get("covered", false))
    )

    return analysis


static func _smart_regroup_draw_budget(
    player,
    rules: RuleConfig
) -> Dictionary:
    var desired_draw_slots: int = int(
        RoundEngineData.BASE_DRAW_COUNT
    )

    var stockpile_active: bool = (
        CastleIntegrityRulesData.power_active(
            player,
            "Stockpile",
            rules
        )
    )

    if stockpile_active:
        if rules.stockpile_filter:
            # Selective Stores performs the normal five, then attempts two
            # additional draws and keeps one. To preserve the full choice, we
            # need room for both temporary draws before one is discarded.
            desired_draw_slots += 2
        else:
            desired_draw_slots += int(
                RoundEngineData.STOCKPILE_DRAW_BONUS
            )

    var carry_target: int = maxi(
        0,
        int(rules.hand_limit) - desired_draw_slots
    )
    var hand_count: int = player.hand.size()
    var overflow: int = maxi(
        0,
        hand_count - carry_target
    )

    return {
        "hand_limit": int(rules.hand_limit),
        "desired_draw_slots": desired_draw_slots,
        "carry_target": carry_target,
        "overflow": overflow,
        "stockpile_active": stockpile_active,
    }


# REGROUP_ENTRY_TITRATION_V1
# Experimental-only gate layered on top of the existing V4.7 trigger.
# Existing current modes remain byte-for-byte behaviorally equivalent.
#
# Profiles:
#   current  = untouched V4.7 trigger
#   moderate = trigger AND (<3 cards OR <10 face)
#   strict   = trigger AND (<2 cards OR <6 face)
#   off      = no Regroup
static func smart_regroup_entry_allowed(
    analysis: Dictionary,
    policy,
    pid: int
) -> bool:
    if not bool(analysis.get("trigger", false)):
        return false

    var profile: String = String(
        policy.regroup_entry_profile(pid)
    )

    if profile in ["moderate", "strict"]:
        var has_count: bool = analysis.has("hand_count")
        var has_value: bool = analysis.has("hand_value")

        assert(
            has_count,
            "Regroup entry titration missing analysis.hand_count"
        )
        assert(
            has_value,
            "Regroup entry titration missing analysis.hand_value"
        )

        # Release safety: missing keys fail CLOSED rather than silently
        # collapsing strict/moderate into current.
        if not has_count or not has_value:
            return false

    match profile:
        "current":
            return true
        "moderate":
            return (
                int(analysis["hand_count"]) < 3
                or int(analysis["hand_value"]) < 10
            )
        "strict":
            return (
                int(analysis["hand_count"]) < 2
                or int(analysis["hand_value"]) < 6
            )
        _:
            return false


static func _smart_regroup_analysis(
    game,
    pid: int,
    rules: RuleConfig,
    post_deploy: bool
) -> Dictionary:
    var player = game.get_player(pid)
    var opponent = game.get_opponent(pid)

    if player == null or opponent == null or not bool(player.alive):
        return {
            "trigger": false,
        }

    var draw_budget: Dictionary = _smart_regroup_draw_budget(
        player,
        rules
    )

    var hand_value: int = _total(
        player.hand
    )
    var hand_count: int = player.hand.size()

    var best_attack: Dictionary = {}
    var best_attack_decision: Dictionary = {}
    var best_attack_score: float = -INF
    var best_attack_reach: float = -1.0
    var best_attack_value: int = 0

    var siege_candidate: Dictionary = {}
    var siege_score: float = -INF
    var siege_reach: float = -1.0

    var ward_candidate: Dictionary = {}
    var ward_decision: Dictionary = {}
    var ward_effective: int = 0
    var ward_score: float = -INF

    var profane_candidate: Dictionary = {}
    var profane_score: float = -INF

    for raw in Prod.evaluate_action_candidates(
        game,
        pid,
        rules
    ):
        if typeof(raw) != TYPE_DICTIONARY:
            continue

        var candidate: Dictionary = raw
        var action: String = String(
            candidate.get(
                "action",
                ""
            )
        )
        var score: float = float(
            candidate.get(
                "score",
                -INF
            )
        )

        if action in ["Hunt", "Siege"]:
            var decision: Dictionary = (
                Prod._commitment_decision_from_candidate(
                    game,
                    pid,
                    candidate,
                    rules
                )
            )
            var value: int = _ids_total(
                player.hand,
                decision.get(
                    "cards",
                    []
                )
            )
            var reach: float = float(
                candidate.get(
                    "forecast_reach",
                    -1.0
                )
            )

            if score > best_attack_score:
                best_attack = candidate
                best_attack_decision = decision
                best_attack_score = score
                best_attack_reach = reach
                best_attack_value = value

            if action == "Siege" and score > siege_score:
                siege_candidate = candidate
                siege_score = score
                siege_reach = reach

        elif action == "Ward":
            ward_score = score
            ward_candidate = candidate
            ward_decision = (
                Prod._commitment_decision_from_candidate(
                    game,
                    pid,
                    candidate,
                    rules
                )
            )
            ward_effective = _ward_ids_value(
                player,
                player.hand,
                ward_decision.get(
                    "cards",
                    []
                ),
                rules
            )

        elif action == "Profane" and score > profane_score:
            profane_candidate = candidate
            profane_score = score

    var meaningful_attack: bool = false

    if not best_attack.is_empty():
        if best_attack_reach >= SMART_REGROUP_MEANINGFUL_ATTACK_REACH:
            meaningful_attack = true
        elif (
            best_attack_reach < 0.0
            and best_attack_value >= SMART_REGROUP_NO_FORECAST_FACE
        ):
            meaningful_attack = true

    var attack_ratio: float = 0.0
    if hand_value > 0:
        attack_ratio = (
            float(best_attack_value)
            / float(hand_value)
        )

    var high_threat: bool = (
        post_deploy
        and opponent.hand.size() >= SMART_REGROUP_THREAT_HAND
    )

    var meaningful_defense: bool = (
        high_threat
        and ward_effective >= SMART_REGROUP_MEANINGFUL_WARD
    )

    var weak_flex: bool = (
        hand_count < SMART_REGROUP_FLEX_CARDS
        or hand_value < SMART_REGROUP_FLEX_VALUE
    )

    var expensive_bad_attack: bool = (
        not meaningful_attack
        and best_attack_value > 0
        and attack_ratio >= SMART_REGROUP_BAD_ATTACK_RATIO
    )

    var no_attack: bool = best_attack.is_empty()
    var overflow: int = int(
        draw_budget.get(
            "overflow",
            0
        )
    )

    var trigger: bool = (
        not meaningful_attack
        and not meaningful_defense
        and (
            weak_flex
            or expensive_bad_attack
            or no_attack
            or overflow > 0
        )
    )

    return {
        "trigger": trigger,
        "hand_value": hand_value,
        "hand_count": hand_count,
        "best_attack_candidate": best_attack,
        "best_attack_decision": best_attack_decision,
        "best_attack_score": best_attack_score,
        "best_attack_reach": best_attack_reach,
        "best_attack_value": best_attack_value,
        "attack_ratio": attack_ratio,
        "meaningful_attack": meaningful_attack,
        "ward_candidate": ward_candidate,
        "ward_decision": ward_decision,
        "ward_effective": ward_effective,
        "ward_score": ward_score,
        "meaningful_defense": meaningful_defense,
        "profane_candidate": profane_candidate,
        "profane_score": profane_score,
        "siege_candidate": siege_candidate,
        "siege_reach": siege_reach,
        "high_threat": high_threat,
        "covered": (
            _castle_standing(player, "Keep")
            or _castle_standing(player, "Bastion")
        ),
        "hand_limit": int(
            draw_budget.get(
                "hand_limit",
                int(rules.hand_limit)
            )
        ),
        "desired_draw_slots": int(
            draw_budget.get(
                "desired_draw_slots",
                0
            )
        ),
        "carry_target": int(
            draw_budget.get(
                "carry_target",
                0
            )
        ),
        "overflow": overflow,
        "stockpile_active": bool(
            draw_budget.get(
                "stockpile_active",
                false
            )
        ),
    }


static func _tag_regroup_choice(
    choice: Dictionary,
    analysis: Dictionary,
    choice_name: String
) -> void:
    choice["smart_core_regroup"] = true
    choice["smart_core_regroup_choice"] = choice_name
    choice["smart_core_regroup_hand_value"] = int(
        analysis.get(
            "hand_value",
            0
        )
    )
    choice["smart_core_regroup_attack_value"] = int(
        analysis.get(
            "best_attack_value",
            0
        )
    )
    choice["smart_core_regroup_attack_reach"] = float(
        analysis.get(
            "best_attack_reach",
            -1.0
        )
    )
    choice["smart_core_regroup_ward_effective"] = int(
        analysis.get(
            "ward_effective",
            0
        )
    )
    choice["smart_core_regroup_hand_limit"] = int(
        analysis.get(
            "hand_limit",
            0
        )
    )
    choice["smart_core_regroup_draw_slots"] = int(
        analysis.get(
            "desired_draw_slots",
            0
        )
    )
    choice["smart_core_regroup_carry_target"] = int(
        analysis.get(
            "carry_target",
            0
        )
    )
    choice["smart_core_regroup_overflow"] = int(
        analysis.get(
            "overflow",
            0
        )
    )

    var raw_cards = choice.get(
        "cards",
        []
    )
    var spend_count: int = 0

    if typeof(raw_cards) == TYPE_ARRAY:
        spend_count = raw_cards.size()

    choice["smart_core_regroup_cap_spend"] = mini(
        int(
            analysis.get(
                "overflow",
                0
            )
        ),
        spend_count
    )
    choice["smart_core_threat_vetoed_by_regroup"] = bool(
        analysis.get(
            "smart_core_threat_vetoed_by_regroup",
            false
        )
    )


static func _cheap_expendable_ids(
    cards: Array,
    overflow: int,
    max_cards: int,
    max_face: int
) -> Array[String]:
    var out: Array[String] = []

    if overflow <= 0 or max_cards <= 0:
        return out

    var entries: Array[Dictionary] = []

    for card in cards:
        if int(card.value) > max_face:
            continue

        entries.append({
            "card": card,
            "value": int(card.value),
            "id": _id(card),
        })

    entries.sort_custom(
        func(a: Dictionary, b: Dictionary) -> bool:
            if int(a["value"]) != int(b["value"]):
                return int(a["value"]) < int(b["value"])
            return String(a["id"]) < String(b["id"])
    )

    var take_count: int = mini(
        overflow,
        mini(
            max_cards,
            entries.size()
        )
    )

    for index: int in range(take_count):
        out.append(
            String(
                entries[index]["id"]
            )
        )

    return out


static func _ids_total(
    cards: Array,
    raw_ids
) -> int:
    if typeof(raw_ids) != TYPE_ARRAY:
        return 0

    var remaining: Array = cards.duplicate()
    var total: int = 0

    for raw_id in raw_ids:
        var card = _find(
            remaining,
            String(raw_id)
        )

        if card == null:
            continue

        total += int(card.value)
        remaining.erase(card)

    return total


static func _ward_ids_value(
    player,
    cards: Array,
    raw_ids,
    rules: RuleConfig
) -> int:
    if typeof(raw_ids) != TYPE_ARRAY:
        return 0

    var remaining: Array = cards.duplicate()
    var total: int = 0

    for raw_id in raw_ids:
        var card = _find(
            remaining,
            String(raw_id)
        )

        if card == null:
            continue

        total += int(
            player.ward_card_value(
                card,
                rules
            )
        )
        remaining.erase(card)

    return total


static func _lowest_hand_card(
    cards: Array
):
    var best = null

    for card in cards:
        if best == null:
            best = card
            continue

        if int(card.value) < int(best.value):
            best = card
            continue

        if (
            int(card.value) == int(best.value)
            and _id(card) < _id(best)
        ):
            best = card

    return best


static func _castle_standing(player, castle_name: String) -> bool:
    return (
        player.castles.has(castle_name)
        and int(player.castle_integrity.get(castle_name, 0)) > 0
    )

static func _pick(d: Dictionary, pid: int) -> Dictionary:
    var x = d.get(pid, d.get(str(pid), {}))
    return x if typeof(x) == TYPE_DICTIONARY else {}

static func _find(cards: Array, cid: String):
    for card in cards:
        if _id(card) == cid:
            return card
    return null

static func _total(cards: Array) -> int:
    var n := 0
    for card in cards:
        n += int(card.value)
    return n

static func _id(card) -> String:
    if card == null:
        return ""
    if card.has_method("card_id"):
        return String(card.card_id())
    return "%s:%d" % [String(card.suit), int(card.value)]
