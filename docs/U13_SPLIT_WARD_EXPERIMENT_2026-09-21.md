# Split Ward experiment — 21 September 2026

Status: implemented and tested as an **opt-in Python simulation experiment** on
top of performance-updated `2ee3d54`. Production Python, Godot and the playable
UI retain the current single-action rules. Do not send these experimental
orders to Godot or describe this as a playable/native parity update.

## Experimental rules

- One nonempty Ward alone, or one Hunt/Siege plus one nonempty Ward.
- Each action commits separate cards from the same hand. Those cards cannot
  also fund powers, guards, castle work, Invocation or resummoning.
- Ward recruits normally at 2:1 printed suit value; Hunt/Siege at 3:1.
- Only the attack can summon a recipe monster, using its own committed cards.
  Existing field and staged monsters continue to work normally.
- Ward screens only its chosen lane. No off-lane half screen.
- No Sigil creation, persistent defense, fresh-Sigil soul award, or Sigil's
  automatic Lord-threat reduction. Empty legacy Sigil fields remain in the
  serialized world for compatibility; fresh experimental games never use them.
- At most one soul per defender per round, only when removing Ward's screen
  from the actual pre-attack state changes failure into success. Hunt success
  means banishment; Siege success means destruction of its final target;
  castleless Siege success means pillage. Reduced damage alone does not pay.
  A screening Keep/Bastion lost without the attack succeeding is not success.
- The counterfactual runs on detached authority data with the same keyed RNG;
  its events and resource changes are discarded. It is never shown to the bot.

Primary attack fields retain their existing shape, with an optional nested
`ward: {action: "Ward", lane: "Lord" | "Castle", card_ids: [...]}` commitment.
Enable explicitly with setup `ward_experiment: "U13_SPLIT_WARD_V1"`.

## Bot and performance

The bot considers attack-first and Ward-first disjoint commitments, including
attack recipes. It scores recruitment, card spending, attack outcome and
lane-specific public defense before normal legal preview/selection. Recipe
conservation sees both commitments' cards. The hidden-order-dependent soul
reward is not separately forecast or given speculative bonus credit.

At most 16 split bundle generation reservations, four retained split candidates,
32 total complete plans and eight legal previews. The four split plan slots
come from the existing complete-plan budget, so other proposals can change as
well as the rules. This is a combined rules-and-policy trial, not a clean
estimate of the rules' effect under an identical strategy.

The optimized PowerMatch dispatch and immutable-history rollback remain active;
no monkey patches or slow match subclass. Runner uses two processes, recycling
the pool every four games. The shell launcher selects PyPy; an explicitly named
interpreter also works. This local trial used CPython 3.12, not Windows PyPy.

## Paired result

Six fresh games per arm, same seeds/loadouts/seats: Gremory–Kanifous,
Kalligan–Deimos, Humbaba–Kroni, each in both seat orders. These are six paired
games, not independent full-roster balance evidence. Orias, Odradek and Valak
are covered by focused planner checks but not these full games.

| Measure | Current attack-only recipes | Split Ward |
|---|---:|---:|
| Completed games | 6 | 6 |
| Total rounds | 96 | 86 |
| Planning decisions | 192 | 172 |
| Ward decisions | 0 | 40 (23.3%) |
| Monster summons | 189 | 167 |
| Summons per 100 decisions | 98.4 | 97.1 |
| Monster bodies per 100 decisions | 144.8 | 131.4 |
| Normal recruits per 100 decisions | 318.2 | 415.1 |
| Banishments | 11 | 9 |
| Rejected previews | 0 | 0 |

All 40 selected Wards were paired with attacks. Opponents attacked the warded
lane 24 times; eight Wards changed attack success into failure and paid eight
souls. Seven saved a Siege target and one prevented a Hunt banishment.

Ward regained a role under this bot. Monster summoning frequency barely moved;
the lower total largely reflects fewer rounds. The more visible economy change
was roughly 30% more normal recruits per decision. Monster body frequency fell
about 9%, which also depends on recipe choice and Varn's variable body count.
Do not claim the experiment establishes monster scarcity or improved balance.

Raw paired counts and frozen-source identity:
`docs/evidence/U13_SPLIT_WARD_SCREEN_2026-09-21.json`.

## Validation

71 focused checks passed across split Ward, existing Ward/recipes, recipe
reservation, common doctrine, copying/rollback, planning and resolution.
Coverage includes disjoint payment rollback, no Ward recipes, separate recruit
ratios/unique spawn IDs, field/staged monster usability, lane-only protection,
Hunt/Siege/pillage causal rewards, guards-alone rejection, no double payment,
all nine Lords' deterministic legal planning, and optimized rollback opt-in.

All twelve games completed with zero rejected previews. Frozen source hashes,
record/trace/operation hashes, split card disjointness, zero Sigil events and
per-player/round reward caps were checked. Two extra contract tests were added
after freezing the trial; simulation and policy code match the tested snapshot.

An additional legacy defensive-plan fixture check still fails in two cases
(`kroni_odradek_00`, `kroni_valak_00`) during archived-prefix admission. The same
failures were reproduced on the pre-experiment checkout; they are not counted
among the 71 passing checks and have not been silently rewritten.

No Godot checks were run for this Python-only experiment. Native rules, native
bot, session admission and playable split-card UI remain a separate integration
step if this direction is retained.

## Run the bounded comparison

The table above records the original twelve-game trial. The runner now also
includes a third, decisive-attack soul-bonus arm: its default is 18 games;
`--full-roster` selects 243 games. See the decisive-soul follow-up report.

From a clean checkout of the updated branch:

```bash
bash Scripts/Sim/run_u13_lord_balance.sh --split-ward-experiment
```

Or explicitly choose CPython:

```bash
bash Scripts/Sim/run_u13_lord_balance.sh python --split-ward-experiment
```

The runner freezes source, runs focused checks, plays eighteen games with two
workers, verifies records, and packages a report ZIP. It requires neither the
old 810-game archive nor Godot. `--prepare-only` freezes/checks without games.
Keep the earlier dirty Doctrine checkout intact; use the clean Ward worktree.
