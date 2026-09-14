# Supplicants, zero-Integrity ruins, and playable history

## Evidence

The submitted round-21 Kanifous/Humbaba save contains 4,200 authoritative
MARCHING_TICK rows (200 per round), each also serialized in two player views.
Ticks already use attribute_delta_v1; they are not full attribute snapshots.
The 117,557,542-byte encoded save becomes 10,639,878 bytes after retiring those
completed samples: 90.95% smaller, about 11.05 times smaller. This is a measured
serialization comparison on a temporary decoded copy, not a migrated save or a
claim of a measured 21-round UI timing improvement.

At round 15, thirteen player Marchers were in the Castle lane near the gate,
but only five were waiting. Friendly personal space at the boundary obstructed
followers. There was no configured three/four-Supplicant cap. The player's
round-10 Siege consumed four Supplicants; round 11 consumed one. Castle-lane
Supplicants cannot support Hunts.

The player's slot-3 Siege Engine reached zero through Kanifous's round-7 Ruin
price. The old price explicitly made it defunct rather than ruined. This was an
authoritative status discrepancy, not merely a label problem.

## Changes

- Player-facing waiters are called **Supplicants**. Combat displays current
  available counts by lane, the automatic +1 strength per body, consumption,
  and exclusion of bodies reserved for rites. No new optional spend mechanic.
- Under guard-work V2, arrived friendly Marchers no longer obstruct followers
  through personal space at the enemy boundary. Ordinary spacing, hostile
  contact, lane restrictions, travel time, and arrival checks remain intact.
- In the guard-work game, Kanifous Stone/Ruin prices reaching zero and Gremory's
  Inevitable Ruin produce ruined Castles, clear artillery targets, and emit an
  explicit CASTLE_RUINED event. Existing price Tear accounting is preserved;
  no fabricated enemy kill credit or extra destruction rewards. Unbuilt and
  building zero-Integrity structures are not reclassified as ruins.
- Ordinary ruins cannot receive Work or Wish Longevity. Profane Ruins accepts
  them when its normal costs and ruin-count requirement are met. Living Deimos
  can still reconstruct his own ruined Siege Engine.
- Playable Aftermath retires completed MARCHING_TICK and KRONI_ACTOR_TICK rows
  after animation. State-change events and Marching start/end snapshots remain.
  Restoring a playable pause also retires completed-round samples. Batch and
  subsystem replay harnesses retain their existing history behavior.
- Retired samples become tiny invisible cursor placeholders. Replacing complete
  immutable rows preserves fork isolation and existing event cursors. Cache
  revision changes invalidate stale board views. Historical tick scrubbing is
  intentionally unavailable; the current playback tape remains intact.

## Compatibility and validation

Guard-work authority advances to U13_GUARD_WORK_V2 because gate and ruin rules
change. Start a new match; V1 saved games are not silently reinterpreted.
Historical test results remain evidence for their original ruleset.

Local Godot 4.5.1 diagnostic checks passed: Supplicant/history focused fixtures,
Guard Work, Action Flow Board (including two-round playback and trimmed save
restore), Playable Board, and Aftermath Ledger. Both mirrored gate fixtures
admitted twelve of thirteen bodies in one phase, including the five already
arrived. Enemy contact and ordinary spacing checks still pass.

Production acceptance remains exact Godot 4.7.2 stable:

    bash Scripts/Sim/run_u13_supplicant_history.sh /path/to/Godot_4.7.2_executable

This bounded runner packages its logs. A new 100-game balance run is not needed
to check these fixes. Balance conclusions need fresh V2 evidence later.
