# U13 full-game foundation — milestone 1

**Current checkpoint:** `U13_STOCKPILE_2026-09-11.md` adds private Selective Stores
choices and expands the game runner to 7/7.

**Current Castle checkpoint:** `U13_CASTLE_DEFENSES_2026-09-11.md` adds Keep/Bastion protection and expands the runner to 6/6.

**Later checkpoint:** `U13_GAME_DEVELOPMENT_2026-09-11.md` adds combined
Development planning and expands the current runner to 5/5. The 3/3 count below
describes the original opening/draw milestone.

The Lord overhaul is complete. The next acceptance target is the autonomous,
legitimate full match described in `U13_POST_OVERHAUL_ROADMAP.md`.
This commit begins that work; it does not claim the full-match gate is green.

## Run

```bash
bash Scripts/Sim/run_u13_game.sh "$GODOT_U13"
```

Expected: **3/3 game foundation runners**, on Windows Godot 4.7.2 stable.
This is a headless gate, not the playable board. The wrapper preserves failure
logs and checks both process status and explicit success markers. Its per-suite
watchdog is 90 seconds, matching the recent focused Kanifous wrapper.
Local compatibility testing uses Godot 4.5.1; it does not replace that Windows gate.

## Implemented

- `U13GameEconomy`: real seeded deck, opening deal, normal round draws, hand cap,
  discard recycling, private draw events and serialized draw clock.
- `U13GameContent`: the nine-Lord mechanics plus the new economy, with a distinct
  policy identity so exercise snapshots cannot silently become game snapshots.
- `U13GameConductor`: validated loadout, setup, round advancement, two complete
  submissions, public views and atomic save/restore. An invalid second plan leaves
  the first player's live state untouched. Existing legality remains authoritative.
- Three runners covering economy, all nine Lord openings / every-hook replay,
  and three Random-Legal rounds from real hands, repeated from JSON checkpoints.

No U12 or UI2 implementation was modified. Existing U13 visual/fixture runners
retain their previous economy while the full-game path is assembled separately.

## Recovered rules and explicit draft boundaries

| Topic | Source / decision in this milestone |
| --- | --- |
| Deck | `SeededGameSetup.gd`: 72 cards, four suits, values 1–5 with 4/4/4/3/3 copies per suit, remove three per suit, shuffle the remaining 60 |
| Opening hand | `GameSetup.gd`: five cards per player |
| Normal draws | `RoundEngine.gd`: five draws per round, including round one after the opening deal |
| Hand limit | `RuleConfig.gd`: ten; the first planning hand is therefore ten if no prior effect changes it |
| Recycling | Existing U13 `U13CardZones.draw`, including recycle-before-cap semantics |
| RNG | U13 keyed RNG, not the old sequential PythonRandom stream; same distribution, not old seed parity |
| Draw timing | End of `ROUND_START_AUTOMATIC`, after current Lord automatic effects/Price collection and before public-state presentation |
| Draw seat order | 0 then 1, as in the old ordinary draw step; not tied to resolution priority |
| Loadout | Five physical slots, at most two of a type, Keep first |
| Castle opening | All unbuilt, retained from U13's loadout boundary; no quickstart castles |
| Lord opening | Lords start present, retained from U13; old paid opening summon is not yet ported |
| Resources / guards | No exercise repair tokens, no preplaced guards/Marchers, zero starting resources |
| Market / Stockpile | Not migrated here; no three-card market row removed from the deck yet, no Selective Stores bonus |
| First-player / Reflex | Existing U13 fixed order retained for this checkpoint; broader game initiative rules require the later lifecycle audit |

The last five rows are draft setup/lifecycle boundaries, not newly settled final
balance rules. The old opening summon, market, and active-Castle setup cannot be
copied wholesale without reconciling the new construction and locked-submission
model. The roadmap remains the full-game acceptance contract.

## Migration audit / next work

| System | Current U13 status | Useful older sources / next task |
| --- | --- | --- |
| Draws / setup | Implemented in this milestone, with draft boundaries above | `GameSetup`, `SeededGameSetup`, `RoundEngine`, `DrawEngine` |
| Joint lock / hooks | Existing `U13Match` and `U13RoundTimeline` | Retain one authority; never reintroduce sequential prompts after lock |
| Guard deployment | Existing `U13GuardDeployment` | Verify full-game candidate coverage; do not rebuild the working rules |
| Resummoning | Existing `U13Resummoning` | Integrate candidate coverage and full match economy |
| Construction / Repair / reconstruction | Existing `U13Construction`, `U13Structures`, `U13CastleSlots` | Audit Commission terminology and complete submissions; keep physical slot identity |
| Castle printed powers | Partial; artillery present | `CastleIntegrityRules`, `RoundEngine`, `BotDeployDoctrine`; migrate each applicable power |
| Development / market / additional choices | Incomplete full-game flow | `RoundEngine`, `DevelopmentStartEngine`, `BotRoundEngine`; translate old ideas to locked U13 decisions |
| Siege / Ward / Hunt / waiter support | Existing `U13Combat` | Audit awards against accepted U13 rules rather than treating exercise behavior as final |
| Pillage / waiter-to-Tear spending | Not complete | Recover applicable rules and add exact shared legality |
| Veil / Dominion / victory | Not connected to this conductor | `DominionRiteEngine`, `VacantThroneEngine`, `ResolutionFinaleEngine`, `BotRoundEngine` |
| Random-Legal | Existing bounded candidate vocabulary, exercised here | Full-game coverage still required; three rounds do not prove all required choices |
| Player UI / Action Window / theater | Existing presentation references | `Prototype/UI2/ActionZone.gd`, `ResolutionTheater.gd`, U13 counterparts; observe resolved events only |
| Forecast / smart doctrine | Later phase | `ActionForecast`, `BotDoctrine`, `BotDeployDoctrine`, `BotDominionRiteDoctrine`; reuse heuristics, not old authority |

Next milestone: complete Development submission coverage and Castle behavior,
then the Veil/win lifecycle. Only after genuine game termination exists should
100–1,000 full games be called the autonomous match gate. A round budget must
remain a diagnostic limit, never be reported as a legitimate victory.

## Verification scope

- Real deck size/suit counts, high-value cards, zero fixture economy, seeded setup.
- Opening + first-round draw, cap behavior, actual discard recycling, private events.
- All nine Lords reach first planning using the same content implementation.
- Three all-pass rounds: JSON restore before each hook, identical complete state
  and event log after it; stale draw-clock snapshots rejected atomically.
- Kanifous versus Orias: three Random-Legal rounds, identical plans after restore,
  complete authoritative submission/resolution and exact replay.

No balance, victory, UI migration, full candidate coverage, or old-PySim parity
claim is made by these checks.
