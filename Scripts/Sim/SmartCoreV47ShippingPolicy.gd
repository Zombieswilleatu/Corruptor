# SMART_CORE_V47_PROMOTED_SHARED_V1
# Promoted V4.7 strategy policy data/predicates. Construction remains excluded.
# ALL_LORD_SMART_CORE_PILOT_V1
# DEFENSE_CULPABILITY_HARNESS_V1
class_name SmartCoreV47ShippingPolicy
# SMART_CORE_EXPERIMENT_V1
# SMART_CORE_EXPERIMENT_V4
# SMART_CORE_EXPERIMENT_V4_3_COMBIFUCKINATION
extends RefCounted

const MODE_PRODUCTION := "production"
const MODE_PRESSURE := "pressure"
const MODE_DISCIPLINED := "disciplined"
const MODE_SMART_CONSTRUCTION := "smart_construction"
const MODE_SMART_THREAT := "smart_threat"
const MODE_SMART_REGROUP := "smart_regroup"
const MODE_SMART_CORE := "smart_core"

# REGROUP_ENTRY_TITRATION_V1 — experimental-only mode variants.
const MODE_SMART_REGROUP_MODERATE := "smart_regroup_moderate"
const MODE_SMART_REGROUP_STRICT := "smart_regroup_strict"
const MODE_SMART_CORE_MODERATE := "smart_core_moderate"
const MODE_SMART_CORE_STRICT := "smart_core_strict"

# ALL_LORD_SMART_CORE_PILOT_V1 — V4.7 minus-EWARD ablation.
const MODE_SMART_CORE_NO_EWARD := "smart_core_no_eward"

var policy_id := "defense-culpability-v1"
var temperature := 0.0
var error_rate := 0.0
var reserve_cards := 4
var reserve_value := 10
var mode_by_pid: Dictionary = {}

func _init(modes: Dictionary = {}, cards: int = 4, value: int = 10) -> void:
    mode_by_pid = modes.duplicate(true)
    reserve_cards = maxi(0, cards)
    reserve_value = maxi(0, value)

func mode_for(pid: int) -> String:
    return String(mode_by_pid.get(pid, mode_by_pid.get(str(pid), MODE_PRODUCTION)))

func constrained(pid: int) -> bool:
    # Legacy hard reserve belongs only to the old culpability modes.
    return mode_for(pid) in [MODE_PRESSURE, MODE_DISCIPLINED]

func smart_construction(pid: int) -> bool:
    # V4.3 COMBIFUCKINATION:
    # Smart Core candidate = Threat Read + Regroup only.
    # V3 Construction remains a separately selectable experiment and no longer
    # contaminates MODE_SMART_CORE.
    return mode_for(pid) == MODE_SMART_CONSTRUCTION

func smart_threat(pid: int) -> bool:
    return mode_for(pid) in [
        MODE_SMART_THREAT,
        MODE_SMART_CORE,
        MODE_SMART_CORE_MODERATE,
        MODE_SMART_CORE_STRICT,
        MODE_SMART_CORE_NO_EWARD,
    ]

func smart_regroup(pid: int) -> bool:
    return mode_for(pid) in [
        MODE_SMART_REGROUP,
        MODE_SMART_CORE,
        MODE_SMART_REGROUP_MODERATE,
        MODE_SMART_REGROUP_STRICT,
        MODE_SMART_CORE_MODERATE,
        MODE_SMART_CORE_STRICT,
        MODE_SMART_CORE_NO_EWARD,
    ]

func regroup_entry_profile(pid: int) -> String:
    match mode_for(pid):
        MODE_SMART_REGROUP_MODERATE, MODE_SMART_CORE_MODERATE:
            return "moderate"
        MODE_SMART_REGROUP_STRICT, MODE_SMART_CORE_STRICT:
            return "strict"
        MODE_SMART_REGROUP, MODE_SMART_CORE, MODE_SMART_CORE_NO_EWARD:
            return "current"
        _:
            return "off"

func smart_core_eward_enabled(pid: int) -> bool:
    return mode_for(pid) != MODE_SMART_CORE_NO_EWARD

func smart_any(pid: int) -> bool:
    return (
        smart_construction(pid)
        or smart_threat(pid)
        or smart_regroup(pid)
    )

func emergency_defense(game, pid: int, rules: RuleConfig) -> bool:
    var p = game.get_player(pid)
    var o = game.get_opponent(pid)
    if p == null or o == null:
        return false
    var veil := int(game.calculate_veil_total())
    if int(p.tears) >= int(rules.dominion_requirement) and veil >= int(rules.dominion_track) - 1:
        return true
    if bool(o.alive) and int(o.souls) >= int(rules.win_souls) - 1:
        return true
    return false
