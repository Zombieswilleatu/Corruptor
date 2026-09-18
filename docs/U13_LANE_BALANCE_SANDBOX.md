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
- Manual units are already deployed and move in the next played interval.
  Requests made during an active interval queue for the following interval.
- Reset clears units, hazards, results and queued spawns and applies the seed.
  The same seed and inputs reproduce the same simulation and enemy choices.
- The report shows live unit counts, cumulative spawns, deaths, banishments and
  escapes, plus the enemy's actual cards and monster recipe for the last wave.

The single field reuses the game's unit art, health/armor rings, ranged
projectiles, monster fields, hit feedback, death visuals and Sooge laser.
Regulars default to chits and monsters to sprites; both toggles are local to
the sandbox and do not change the main game's saved display preferences.

## Combat contract

`Scripts/Sim/U13LaneSandbox.gd` runs the existing `U13Marching.resolve`, with
the current ranged profile and monster rules. Regeneration, poison, charm
expiry, Sooge's increasing root odds and other active-round abilities retain
their normal round boundaries in both playback modes. Ongoing duels persist.
The 200 simulation ticks are displayed over 15 seconds at 1× playback.

There are no Lords, cards on the battlefield, castles, passives, Veil effects
or victory conditions. At the end of an interval, surviving units waiting at
the far gate score an escape and leave without death effects. This prevents
indefinite gate congestion in a field with no Siege/Hunt phase. The arena is
capped at 64 active units; the random enemy waits when another wave could
exceed the cap. A worker resolves each interval without touching live UI state.

## Random enemy baseline

This is a card-driven pressure generator, not the full doctrine opponent.
It uses the current deck's value counts and three-card trim per suit (60 cards),
draws five per interval, makes at most one recipe-improving Slaver trade from
three offers, may spend spare defensive pairs (50%), and saves up to two cards.
It commits 2–5 available cards, or the full qualifying recipe, and spends the
remaining unsaved cards elsewhere. No cards are duplicated or manufactured.

Recipe goals are weighted Easy 45%, Moderate 30%, Hard 20%, Very hard 5%.
These are goal weights, not guaranteed spawn rates. The opponent must actually
draw the ingredients. It selects at most one qualifying monster per wave,
respecting living-copy limits. Regular bodies and Varn swarm size are produced
by the game's `U13Combat._reveal`, alongside that monster; ordinary printed
suit totals are divided by three. AI units retain normal next-round deployment.
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
card/recipe legality and conservation across 80 waves, actual commitment
counts/deployment, escapes, menu integration, viewport bounds, both play modes,
pause, queued spawns, reset and returning to the selected loadout. The existing
playable-board regression also passes. Results and runtime limits are recorded
in `docs/evidence/U13_LANE_SANDBOX_2026-09-18.json`.
