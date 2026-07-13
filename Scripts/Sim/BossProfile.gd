class_name BossProfile
extends Resource

# Temporary boss config resource.
# Later, make one .tres per boss and load them through a CampaignConfig resource.
# Long-term this should become lord_id + campaign config overrides, not canon rules text.

@export var lord_id: String = ""
@export var display_name: String = ""

@export var breach_id: String = ""
@export var breach_name: String = ""
@export_multiline var breach_text: String = ""

@export_multiline var intent_text: String = ""

# Temporary fake-match scaffold values.
# These are not final rulebook mechanics.
@export var campaign_soul_reward: int = 0
@export var fake_neutral_tears: int = 0
@export var fake_player_threat: int = 0
