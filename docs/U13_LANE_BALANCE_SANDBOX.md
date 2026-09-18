# Marcher and monster balance sandbox

Open **Lane Balance Sandbox** beside **Animation Previews** in the main menu.
The regular playable runner is unchanged. Returning to the menu preserves the
selected Lords and Castles and discards the sandbox session.

## Controls

- Choose Your side or Enemy, then click a regular-marcher button.
- Select one of the ten monsters, then Spawn. Varn creates its normal 3–5-body
  swarm. Sooge can start mobile or already rooted. Living Sooge/Sinodek limits
  still apply independently to each side.
- Spawn at the gate for normal travel, or nearer the center for quicker contact.
- Run one 15-second interval, or choose Continuous to repeat automatically.
  Pause/Resume and 0.5×/1×/2× playback are available; speed changes presentation,
  not movement or damage rules. Space pauses/resumes; Escape returns to the menu.
- Under **Random Spawns**, enable **Your side spawns each interval** and/or
  **Enemy spawns each interval**. For unattended fights, enable both, choose
  **Continuous · repeat rounds**, then click **Start**. Changes apply to the
  next interval; existing units keep fighting when automatic spawning is off.
- Manual units are already deployed and move in the next played interval.
  Requests made during an active interval queue for the following interval.
- Reset clears units, hazards, results and queued spawns and applies the seed.
  The same seed and inputs reproduce the same simulation and both sides' choices.
  Reset preserves the spawn toggles and playback selections.
- The report shows live unit counts, cumulative spawns, deaths, banishments and
  escapes, plus each side's actual cards and monster recipe for its last wave.

The single field reuses the game's unit art, health/armor rings, ranged
projectiles, monster fields, hit feedback, death visuals and Sooge laser.
Regulars default to chits and monsters to sprites; both toggles are local to
the sandbox and do not change the main game's saved display preferences.

## Combat contract

`Scripts/Sim/U13LaneSandbox.gd` runs the existing `U13Marching.resolve`, with
the current ranged profile and monster rules. Regeneration, poison, charm
expiry, Sooge's increasing root odds and other active-round abilities retain
their normal round boundaries in both playback modes. Every nearby unit fights
independently; the current rules no longer queue one exclusive duel per lane.
The 200 simulation ticks are displayed over 15 seconds at 1× playback.

September 18 range/cadence tuning is shared with the game and Python simulator:
Vulture range is **400** (previously 800); every Lemek ignores every Lemek
death pool, including enemy pools. Sooge's rooted beam reaches **1800**
(previously 600) and fires at most once per round, at least 200 ticks apart.
It charges for 32 ticks (about 2.3 seconds in this preview) with a gathering
blue-white glow, then aims at the nearest living enemy. A fast beam traces the
ground through that target to maximum range, leaving a lit scar. Eight ticks
later (about 0.6 seconds), blue eruptions detonate along the locked line,
dealing 3 damage to enemies and 1 to allies still in its path. Losing all
targets cancels the charge; death prevents release. Once fired, the pending
explosion survives Sooge's death. Charge, cooldown and pending blasts survive
round boundaries and saves. Continuous mode uses the same timing. Playback
speed changes scale the visible timing; the regular game's shorter playback
still represents one complete round.

Penitents now have a **50% block chance per incoming ranged hit**. This applies
to Vulture projectiles and Sooge's delayed beam damage, including collateral.
A successful block prevents both HP and Armor loss; failed blocks use normal
damage rules. Each attacker/target/hit has its own seeded roll. Blocks still
wake a newly deployed defender and spend the attacker's shot. A brief shield
glint marks the block on both chits and sprites; tooltips describe the boon.
Melee, poison, Kopita pulses, Muno strikes and ambushes do not trigger it.

Melee uses a narrow elliptical footprint: 90 units forward, 42 sideways. The
same footprint controls stopping, contact feedback and damage. Each attacker
has its own eight-tick cooldown, and reciprocal lethal attacks still land.
Unit feet, projectiles and structures share one screen-coordinate mapping.

Friendly marchers and monsters can pass through one another, including a
Wright holding a construction post or a Vulture standing at firing range.
Their initial spawn positions remain spread out, but friendly spacing never
stops movement or triggers sidesteps. Temporary overlap is allowed. Enemy
walls still block ground movement, and enemies still engage at melee range.

Wrights now deal **1 melee damage**, down from 2. Each builds one structure at
an available site, defends it for one complete round, then marches onward:

| Structure | Availability | HP | Armor | Attack | Range |
| --- | --- | ---: | ---: | ---: | ---: |
| Wall | Two sites per side per lane | 6 | 2 | 0 | — |
| Tower | One central site behind two standing walls | 6 | 4 | 1 | 600 |

Construction takes 32 ticks at the site and pauses during melee. Ground enemies
must break walls in their path; allies pass through and flying monsters pass
over them. A later Wright can replace a destroyed wall. Walls and towers retain
damage without automatic repair. Towers fire every 32 ticks and respect the
Penitent ranged block; Sooge's beam can damage structures. Structures do not
count as marchers, reach gates, resurrect or award unit-death rewards.
Foundation marks appear only after a Wright claims a site. Both the main board
and sandbox display construction progress and completed structures.

Current tuning uses `U13_VULTURE_RANGED_V7_FRIENDLY_PASSAGE` and `U13_MONSTERS_V6_AMBUSH_REVEAL`.
Start a fresh game after updating; older rules fingerprints remain incompatible.

There are no Lords, cards on the battlefield, castles, passives, Veil effects
or victory conditions. At the end of an interval, surviving units waiting at
the far gate score an escape and leave without death effects. This prevents
indefinite gate congestion in a field with no Siege/Hunt phase. The arena is
capped at 64 active units; either generator waits when another wave could
exceed the cap, without consuming its cards. Priority alternates by interval
when there is only room for one wave. A worker resolves each interval without
touching live UI state.

## Random spawn baseline

This is a card-driven pressure generator, not the full doctrine opponent.
Home and enemy each have an independent deck, discard pile, saved cards and
recipe goal, with separate deterministic random streams. Both use the same
generation rules; enabling one never draws from the other side's cards.
It uses the current deck's value counts and three-card trim per suit (60 cards),
draws five per interval, makes at most one recipe-improving Slaver trade from
three offers, may spend spare defensive pairs (50%), and saves up to two cards.
It aims to commit 2–5 cards, or the full qualifying recipe, and spends the
remaining unsaved cards elsewhere. No cards are duplicated or manufactured.
Saving and defensive spending can leave fewer cards, and a weak commitment
can produce no bodies. Continuous mode still advances to the next interval.

Recipe goals are weighted Easy 45%, Moderate 30%, Hard 20%, Very hard 5%.
These are goal weights, not guaranteed spawn rates. Each side must actually
draw the ingredients. It selects at most one qualifying monster per wave,
respecting living-copy limits. Regular bodies and Varn swarm size are produced
by the game's `U13Combat._reveal`, alongside that monster; ordinary printed
suit totals are divided by three. Both commitments reveal together, with unique
card identities and normal next-round deployment. Living-copy limits are
checked against the summoning side, including charmed copies.
All monster recipes are unlocked. Stockpiles, Ward's extra bodies, Lord powers,
campaign unlocks and full defensive/Work decisions are intentionally absent.

In the reproducible `wave-test` sample of 80 commitments, the generator produced
196 regular bodies (2.45 per interval), plus 53 monster summons: Lemek 14,
Varn 13, Fyra 9, Tumler 6, Muno 4, Dotra 3, Kopita 3 and Sooge 1. Kurchin and
Sinodek did not qualify in that seed. A Varn summon is a swarm, not one body.
This sample checks plausible varied pressure; it is not a full-match balance
estimate.

## Validation

`Scripts/Sim/U13LaneSandboxTestRunner.gd` covers all profiles, direct equality
with the real Marching engine, deterministic replay, multi-round abilities,
card/recipe legality and conservation across 80 waves, independent home/enemy
draws and living-copy limits, paired commitment counts/deployment, capacity
waiting, escapes, menu integration, viewport bounds, both play modes, home-only
automatic starts, pause, queued spawns, reset and returning to the selected loadout. The existing
playable-board regression also passes. Results and runtime limits are recorded
in `docs/evidence/U13_LANE_SANDBOX_2026-09-18.json`.

`U13FieldCombatTestRunner.gd` covers independent and many-to-one melee, forward
and sideways reach boundaries, construction, wall collision, friendly/flying
passage, tower range, builder death and charm, replacement, save transport and
shared playback geometry. Native phase exports are replayed independently by
the Python simulator, comparing every event and tick. Historical duel-specific
fixtures explicitly retain their frozen non-ranged rules profile.
