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
- The persistent scoreboard shows **Round N** and **Your side / Enemy: reached
  the goal**. Round 1 starts the session; finishing a round advances the counter
  to the next round. Each side scores when its units reach the far gate.
  These running totals include monster bodies, update with playback, survive
  round transitions, and clear with either arena reset action.
- Under **Random Spawns**, enable **Your side spawns each interval** and/or
  **Enemy spawns each interval**. For unattended fights, enable both, choose
  **Continuous · repeat rounds**, then click **Start**. Changes apply to the
  next interval; existing units keep fighting when automatic spawning is off.
- Manual units are already deployed and move in the next played interval.
  Requests made during an active interval queue for the following interval.
- Opening the sandbox starts with a fresh displayed seed. **New Random Arena**
  clears the field and chooses another seed for fresh draws and combat rolls.
- **Replay / Apply Seed** clears units, hazards, results and queued spawns and
  applies the displayed seed. The same seed and inputs repeat the same fight,
  including both sides' choices. Both reset actions preserve spawn toggles and
  playback selections and wait until the round-preparation worker finishes.
- The report shows live unit counts, cumulative spawns, deaths, banishments and
  goals, plus each side's actual cards and monster recipe for its last wave.

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

Vultures, Kopita, Sinodek and mobile Sooge now pace behind nearby allied
Butchers, Penitents, Lemeks and Kurchins. Within 420 distance and 180 sideways,
they slow to quarter speed while the frontliner takes the lead, then maintain
180 forward separation. They stop creeping when that screen engages in melee.
Supports do not slow one another, and they return to normal speed when no
eligible ally is nearby. Retreating, fleeing, waiting and undeployed allies do
not serve as screens. This changes local movement, never the saved Speed stat.

September 19 playtest balance uses **up to six ordinary melee attacks and
four ranged attacks per 200-tick round** (34/50-tick cooldowns, carried across
rounds). Vultures and towers share the ranged rate. Monster powers keep their
existing timing; Butchers retain 3 damage per hit.

Nearby advancing Butchers and released Wrights let a Penitent lead by 90 units,
then close at normal speed once it engages. Building, initial guarding, and
extended repair duty remain independent of that approach formation. Existing
support pacing for Vultures, Kopita, Sooge and Sinodek remains active.

Lemek, Fyra, Kopita, Tumler, Muno and Dotra now have **10 HP**. Each Varn body has
**4 HP**. Lemek has **4 Attack / 4 Armor**. Sooge and Sinodek keep their current
HP, Armor and powers. Ordinary regeneration remains 1 HP per round.

Tumler keeps pursuing his chosen enemy through clusters while avoiding slowing
pools. His **50% evasion is always active against direct attacks**, including
melee contact, deployment hold, retreat and fear. A landed melee hit while he
is hunting redirects him to the attacker, even if Armor absorbs it. Ranged
hits never redirect the hunt. Muno's dash and Dotra's ambush count as melee;
beams and Kopita pulses do not. Poison remains undodgeable. Misses spend the
normal attack cooldown and cannot apply on-hit poison or charm. Pale streaks
mark a dodge in the shared board/sandbox playback.

Kurchin has **15 HP / 6 Armor / 1 Attack**. While Armor is positive, he deflects
**75% of incoming direct attacks** without spending Armor or HP. Landed attacks
use normal Armor absorption, overflow and bypass rules. At zero Armor, the
deflection ends immediately, even for later attacks in the same tick. Poison
cannot be deflected. A shield glint marks successful deflections.

His **360-unit taunt pulls engaged enemies off their current targets** to
approach and attack him. Selection is rechecked every tick, so losing Kurchin
or leaving his radius restores normal targeting. Taunt still works after his
Armor is gone. It overrides ordinary approach pacing and Wright guard movement;
intact hostile walls and fear/retreat still apply. It cannot reach another lane
or target hidden units. Immobile units retain their normal movement limits.

Wrights now deal **1 melee damage**, down from 2. Each builds one structure at
an available site, defends it for at least one complete round, and repairs
1 HP at the start of each Marching round. It stays while its structure is
damaged and marches onward once the structure has full HP and that initial
guard period has elapsed:

| Structure | Availability | HP | Armor | Attack | Range |
| --- | --- | ---: | ---: | ---: | ---: |
| Wall | Two sites per side per lane | 6 | 2 | 0 | — |
| Tower | One central site behind two standing walls | 6 | 4 | 1 | 600 |

Construction takes 32 ticks at the site and pauses during melee. Ground enemies
must break walls in their path; allies pass through and flying monsters pass
over them. A later Wright can replace a destroyed wall. Walls and towers retain
damage until their assigned Wright repairs them. Repairs restore HP only,
never Armor, and stop after the Wright leaves or its structure is destroyed.
Towers fire every 50 ticks and respect the
Penitent ranged block; Sooge's beam can damage structures. Structures do not
count as marchers, reach gates, resurrect or award unit-death rewards.
Foundation marks appear only after a Wright claims a site. Both the main board
and sandbox display construction progress and completed structures.

Sinodek is immune to the fear and banishment from his own void. The portal
remembers its creator even if charm changes his side. Other units, including
allies and the opposing Sinodek, remain vulnerable. His 25% cast chance starts
on his first active round, after the existing summon-round hold.

The own-void fix passed 641 native monster assertions, including ten directed
Sinodek phases across both sides. Godot 4.5.1 Linux and Python matched all
84 exported monster phases (16,800 ticks), including complete worlds and
events. See the [fix evidence](evidence/U13_SINODEK_VOID_FIX_2026-09-19.json).

Current tuning uses `U13_VULTURE_RANGED_V10_LANE_BALANCE` and `U13_MONSTERS_V11_VOID_CREATOR_IMMUNITY`.
Start a fresh game after updating; older rules fingerprints remain incompatible.

There are no Lords, cards on the battlefield, castles, passives, Veil effects
or victory conditions. At the end of an interval, surviving units waiting at
the far gate score an escape and leave without death effects. This prevents
indefinite gate congestion in a field with no Siege/Hunt phase. The arena is
capped at 64 active units; either generator waits when another wave could
exceed the cap, without consuming its cards. Priority alternates by interval
when there is only room for one wave. A worker resolves each interval without
touching live UI state.

Goal totals count recorded arrivals, even when a unit dies or is removed before
the round ends. Each body can score once for each side; the gate reached
determines credit if charm changed its allegiance. Playback uses the recorded
arrival tick, so pausing cannot reveal future goals and skipping display frames
cannot lose one. Waiting at a gate and ending the round do not score it again.

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
Before spending a defensive pair, it retains the possibility of a legal body
or monster from the remaining hand. If the planned commitment would produce
nothing, it uses the smallest available same-suit packet totaling at least
three, releasing saved recipe cards only if necessary. Draw limits, the
two-card savings cap and the 50% defensive-spending roll remain. Truly
insufficient hands can still produce no bodies; no free units or extra draws
are granted, and the report explains the shortfall. Continuous mode advances.

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

In the revised `wave-test` sample of 80 commitments, the generator produced
205 regular bodies (2.56 per interval), plus 57 monster summons: Lemek 16,
Varn 17, Fyra 5, Tumler 6, Muno 2, Dotra 6, Kopita 2 and Sooge 3. Kurchin and
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

The opening/fairness regression also checks the reported `lane-balance-1` seed,
which previously committed only Penitent 1 for home while the enemy spawned
four bodies. It now produces a body for both sides in interval one, with the
same round-two movement readiness. Controlled weak hands exercise savings and
defense priority without manufacturing cards; 768 additional waves check both
owners' card conservation and recipe legality. Twelve paired rounds reflect
the entire field and exchange ownership while keeping immutable identities
and random rolls, comparing the complete result and every event. Fresh-seed
and exact-replay controls are exercised through the menu. This is a targeted
side-symmetry check, not a population win-rate estimate. Current evidence is in
`docs/evidence/U13_SANDBOX_OPENING_FAIRNESS_2026-09-18.json`.

The scoreboard check exercises real arrivals from both ends, playback timing,
pause/resume, faster playback, persistent round and goal totals, duplicate
arrival events, removal after arrival, reset, and viewport bounds. It also runs
the existing sandbox menu and worker-flow checks. The focused result is in
`docs/evidence/U13_SANDBOX_SCOREBOARD_2026-09-18.json`.

`U13FieldCombatTestRunner.gd` covers independent and many-to-one melee, forward
and sideways reach boundaries, construction, wall collision, friendly/flying
passage, tower range, builder death and charm, replacement, save transport and
shared playback geometry. Native phase exports are replayed independently by
the Python simulator, comparing every event and tick. Historical duel-specific
fixtures explicitly retain their frozen non-ranged rules profile.

`U13SupportHuntTestRunner.gd` covers both owners, all four support types,
screen loss and engaged screens, support-only groups, deterministic evasion
boundaries, melee interception through Armor, ranged target retention, target
arrival and unavailable targets, ability damage categories and dodge playback.
Its exported phases are also checked by `u13_pysim.verify_monsters`; the focused
`run_u13_new_rules_quick.sh` includes both stages.

The September 19 adoption is covered by `U13LaneBalanceTestRunner.gd` (engaged
taunt, range/lane boundaries, wall blocking, defense roll thresholds, mid-volley
Armor depletion, poison and formation) and `U13CadenceTestRunner.gd` (four rounds
of continuous melee, Vulture and tower attacks). Both export complete phases
for `u13_pysim.verify_monsters`, including every visual tick and event.
