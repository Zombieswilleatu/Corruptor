# SMART_CORE_V47_PROMOTED_SHARED_V1
class_name SmartCoreV47ShippingPolicyFactory
extends RefCounted

const PolicyData = preload(
    "res://Scripts/Sim/SmartCoreV47ShippingPolicy.gd"
)


static func from_selector(selector = null):
    var out = PolicyData.new({
        0: PolicyData.MODE_SMART_CORE,
        1: PolicyData.MODE_SMART_CORE,
    })

    if selector != null:
        out.policy_id = "%s+smart-core-v4.7" % str(
            selector.policy_id
        )
        out.temperature = float(
            selector.temperature
        )
        out.error_rate = float(
            selector.error_rate
        )

    return out


static func golden_planner():
    var out = PolicyData.new({
        0: PolicyData.MODE_SMART_CORE,
        1: PolicyData.MODE_SMART_CORE,
    })
    out.policy_id = "smart-core-v4.7-golden-planner"
    out.temperature = 0.0
    out.error_rate = 0.0
    return out
