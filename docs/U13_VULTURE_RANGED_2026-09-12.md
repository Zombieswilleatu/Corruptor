# Vulture ranged combat

Current U13 all-Lord and full-game matches use Vultures with **1 attack,
1 defense, 2 speed**, and **no armor piercing** in either ranged or melee attacks.
Health and regeneration retain their existing values.

Vultures advance until an eligible enemy is within four battlefield units
(800 fixed-point distance, with 200 per unit). They stop and throw a small knife.
They do not backpedal when enemies close; contact switches them to ordinary
melee. Ranged shots have a 32-tick cooldown; melee retains its eight-tick
cooldown. A shot also imposes eight ticks of recovery before melee. Cooldowns
persist across round boundaries. A Vulture resumes moving when no eligible enemy
remains in range.
Shots stay in the same lane, target the nearest eligible enemy with stable-ID
ties, respect Ghost Wish exclusions, and cannot fire while routed or fleeing.
Normal armor absorbs and is consumed by attacks before remaining damage reaches
health. Blood Wish applies to the next attack in either mode.

Each tick selects ranged shots simultaneously, then applies them before invoking
normal combat-death reactions. Reciprocal lethal shots both land. Overkill cannot
produce duplicate death reactions. Ranged attacks can interrupt an existing duel
by killing a participant; the surviving unit returns to normal contact selection.

The authoritative tape records attacker/target snapshots and damage. Board
playback uses a 0.18-second knife flight ending at the recorded impact. The small
projectile crops only the knife in Gem Dagger frame zero, points toward the target,
and disappears on impact. It never plays the coin or reward sequence. The board
clears projectiles on world/reset changes; visual interpolation does not modify
match state or saves.

`U13_VULTURE_RANGED_V3` versions current all-Lord and full-game policies. Production,
Predator, Wish Power and debug spawns use this profile. Earlier isolated subsystem
fixtures and the U12 baseline retain their frozen rules for regression comparisons.
Start a new current-profile match; older policy saves are not silently reinterpreted.

The September 17 Vulture attack reduction from 2 to 1 remains in both modes.
The accompanying 25% movement reduction was reverted after playtesting showed
excessive bunching. All Marchers and monsters use their original movement speeds,
including retreat and panic movement. Existing lane bonuses and slow effects
retain their original calculations. Rooted Sooge remains stationary. Python
mirrors the same rules; Vulture range, cadence, HP, armor and regeneration are
unchanged.

The focused `U13VultureRangedTestRunner` checks range, movement, both armor paths,
cadence, switching to melee, reciprocal kills, lane isolation, retreat, deterministic
replay, JSON round-boundary restore, projectile sampling, frame-zero cropping and
board/reset integration. The game gate now expects **16/16** including Vacant Throne
and the existing Sigil board check. Local simulation checks use Godot 4.5.1;
the complete board gate requires the pinned Windows Godot 4.7.2 runtime.

Movement rollback validation: 26 ranged checks, 61 movement checks in
`U13MarchingBalanceTestRunner`, and 135 monster checks passed with integer-division
warnings treated as errors. Python passed 26 focused tests and matched native
events/state across 12 monster phases (2,400 complete tick frames), including
Sooge's explicit beam-firing events. These are local Godot 4.5.1 diagnostics;
the Windows 4.7.2 playtest remains the production-runtime check.
