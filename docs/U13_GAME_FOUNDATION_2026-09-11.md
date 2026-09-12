# U13 full-game foundation — milestone 1

**Current checkpoint:** `U13_FRACTURE_2026-09-11.md` adds printed Fracture on
banishment and expands the game runner to 13/13. The user accepted the preceding
production-opening gate at 12/12.

**Accepted previous checkpoint:** the user reported the Sigil-expanded 11/11
game gate green on Windows Godot 4.7.2 at `3ef5964`.

**Parity audit:** See `U13_U12_PARITY_AUDIT_2026-09-11.md` for the verified
playable baseline, corrected Slaver priority, missing Conduit/Sigil lifecycle,
and revised completion queue.

**Earlier checkpoint:** `U13_GAME_MARKET_2026-09-11.md` adds market swaps and
refresh, expanding the runner to 8/8. Earlier checkpoint counts below are historical.

**Previous checkpoint:** `U13_STOCKPILE_2026-09-11.md` adds private Selective Stores
choices and expands the game runner to 7/7.

**Earlier Castle checkpoint:** `U13_CASTLE_DEFENSES_2026-09-11.md` adds Keep/Bastion protection and expands the runner to 6/6.

**Earlier Development checkpoint:** `U13_GAME_DEVELOPMENT_2026-09-11.md` adds combined
Development planning and expands the current runner to 5/5. The 3/3 count below
describes the original opening/draw milestone.

The Lord overhaul is complete. The next acceptance target is the autonomous,
legitimate full match described in `U13_POST_OVERHAUL_ROADMAP.md`.
This commit begins that work; it does not claim the full-match gate is green.

## Run

```bash
bash Scripts/Sim/run_u13_game.sh "$GODOT_U13"
```

Expected: **13/13 game foundation runners**, on Windows Godot 4.7.2 stable.
This is a headless gate, not the playable board. The wrapper preserves failure
logs and checks both process status and explicit success markers. Its per-suite
watchdog is 90 seconds, matching the recent focused Kanifous wrapper.
Local compatibility testing uses Godot 4.5.1; it does not replace that Windows gate.

## Implemented

- `U13GameEconomy`: real seeded deck, market and opening deal, three active
  starting Castles, paid opening summons, normal round draws, hand cap, discard
  recycling, private draw events and serialized opening/draw state.
- `U13GameContent`: the nine-Lord mechanics plus the new economy, with a distinct
  policy identity so exercise snapshots cannot silently become game snapshots.
- `U13GameConductor`: validated loadout, setup, round advancement, two complete
  submissions, public views and atomic save/restore. An invalid second plan leaves
  the first player's live state untouched. Existing legality remains authoritative.
- Thirteen focused runners cover economy/opening, all nine Lords, every-hook
  replay, Fracture, Development, Castle powers, Slaver, Sigils and Random-Legal.

No U12 or UI2 implementation was modified. Existing U13 visual/fixture runners
retain their previous economy while the full-game path is assembled separately.

## Recovered and settled rules

| Topic | Source / decision in this milestone |
| --- | --- |
| Deck | `SeededGameSetup.gd`: 72 cards, four suits, values 1–5 with 4/4/4/3/3 copies per suit, remove three per suit, shuffle the remaining 60 |
| Opening hand | `GameSetup.gd`: five cards per player |
| Normal draws | `RoundEngine.gd`: five draws per round, including round one after the opening deal |
| Hand limit | `RuleConfig.gd`: ten; paid opening cards leave the Hand before the normal five-card round-one draw, which then caps at ten |
| Recycling | Existing U13 `U13CardZones.draw`, including recycle-before-cap semantics |
| RNG | U13 keyed RNG, not the old sequential PythonRandom stream; same distribution, not old seed parity |
| Draw timing | End of `ROUND_START_AUTOMATIC`, after current Lord automatic effects/Price collection and before public-state presentation |
| Draw seat order | 0 then 1, as in the old ordinary draw step; not tied to resolution priority |
| Loadout | Five ordered physical slots, at most two of a type and at most one Keep; Keep is optional |
| Castle opening | The first three selected slots start active at full Integrity; the final two remain protected, unbuilt blueprints |
| Lord opening | Five cards are dealt, then the Lord is paid at its current U13 summon cost; the lowest-value cards are discarded until covered or the Hand is exhausted |
| Resources / guards | No exercise repair tokens, no preplaced guards/Marchers, zero starting resources |
| Market / Stockpile | Migrated in their focused checkpoints, including the three-card Slaver row and operational Selective Stores |
| First-player / Reflex | The Slaver's first visitor is keyed and seeded; combat Reflex remains separate |

The opening rows are now settled U13 rules, not exercise-fixture assumptions.
Their implementation deliberately keeps U13's locked-submission and construction
model instead of importing the U12 controller wholesale.

## Migration audit / next work

| System | Current U13 status | Useful older sources / next task |
| --- | --- | --- |
| Draws / setup | Implemented, including production Castles and paid opening summon | `GameSetup`, `SeededGameSetup`, `RoundEngine`, `DrawEngine` |
| Joint lock / hooks | Existing `U13Match` and `U13RoundTimeline` | Retain one authority; never reintroduce sequential prompts after lock |
| Guard deployment | Existing `U13GuardDeployment`, covered by complete-plan tests | Preserve shared legality; do not rebuild the working rules |
| Resummoning | Integrated with full-game candidates and opening economy | Preserve later-return Threat/Mark/Tear rules separately from the first summon |
| Construction / Repair / reconstruction | Existing `U13Construction`, `U13Structures`, `U13CastleSlots` | Audit Commission terminology and complete submissions; keep physical slot identity |
| Castle printed powers | Engine, Keep, Bastion, Stockpile and Circle paths migrated | Keep their instance and operational rules in focused authorities |
| Development / market / additional choices | Core Development and Slaver paths implemented | Add only the remaining waiter/lifecycle choices through explicit U13 APIs |
| Siege / Ward / Hunt / waiter support | Existing `U13Combat` | Audit awards against accepted U13 rules rather than treating exercise behavior as final |
| Profane / Pillage / waiter-to-Tear spending | Implemented in the full-game profile | `U13Plunder` and `U13DominionRites`; exact shared legality and replay |
| Veil / Dominion / victory | Tear routes, Dominion rites and Vacant Throne connected; Veil effects/drift disabled pending redesign; victory next | Recover current lifecycle from `ResolutionFinaleEngine` and `BotRoundEngine` |
| Random-Legal | Existing bounded candidate vocabulary, exercised here | Full-game coverage still required; three rounds do not prove all required choices |
| Player UI / Action Window / theater | Existing presentation references | `Prototype/UI2/ActionZone.gd`, `ResolutionTheater.gd`, U13 counterparts; observe resolved events only |
| Forecast / smart doctrine | Later phase | `ActionForecast`, `BotDoctrine`, `BotDeployDoctrine`, `BotDominionRiteDoctrine`; reuse heuristics, not old authority |

Next milestone: complete the win lifecycle. Per the 2026-09-12 user decision,
Veil threshold effects and automatic drift stay disabled pending a design pass.
Tear accumulation, Dominion rites and current Lord Breach powers remain active. Waiter spending,
Dominion rites, Vacant Throne and Profane/Pillage have focused authorities. Only after genuine game termination
exists should
100–1,000 full games be called the autonomous match gate. A round budget must
remain a diagnostic limit, never be reported as a legitimate victory.

## Verification scope

- Real deck size/suit counts, high-value cards, zero fixture economy, seeded setup.
- Ordered three-Castle opening, optional Keep/duplicate loadouts, every current
  Lord cost, Circle Blood Offering, sparse-hand payment, and first-round draw.
- Cap behavior, actual discard recycling, private events, corruption rejection.
- All nine Lords reach first planning using the same content implementation.
- Three all-pass rounds: JSON restore before each hook, identical complete state
  and event log after it; stale draw-clock snapshots rejected atomically.
- Kanifous versus Orias: three Random-Legal rounds, identical plans after restore,
  complete authoritative submission/resolution and exact replay.

No balance, victory, UI migration, full candidate coverage, or old-PySim parity
claim is made by these checks.
