# Playable U13 runner

2026-09-13 · `u13-basic-doctrine` · first full human-versus-doctrine integration.

## Launch

From the existing Doctrine worktree in Git Bash:

```bash
git fetch origin u13-basic-doctrine &&
git merge --ff-only FETCH_HEAD &&
bash Scripts/Sim/run_u13_playable.sh "/path/to/Godot_4.7.2_executable"
```

The launcher selects `Prototype/U13/U13PlayableBoard.tscn`. It does not change
the U12 main scene. `run_u13_board.sh` still launches the earlier exercise board;
`run_u13_game.sh` remains a foundation test gate. The new launcher is a visible
game, not a headless batch. It requires Godot 4.7.2 stable.

Every launch writes a uniquely named `u13-playable-<date>-<suffix>.log` directly
to Downloads and prints its path. SAVE writes a uniquely named
`u13-playable-<date>-r<round>-<suffix>.json` directly to Downloads. LOAD is available
both in setup and on the board. Saving preserves a valid staged human cart,
pending human Stockpile/Slaver choice, completed round, or finished game. Loading
validates the complete production snapshot before adopting it. Saves are local
match snapshots, not a bot input or a public multiplayer projection.

## Playing

- Choose both Lords and five Castle slots. Slots 1–3 begin active; 4–5 are
  blueprints. The full conductor handles the real deck and paid opening summons.
- Handle your Stockpile draw and Slaver trade when prompted. The bot handles
  its own choices. Card capacity can mean there is no Stockpile choice to make.
- Use the existing board gestures for Hunt, Siege, Ward, Castle development,
  Guard placement, resummoning, and all nine Lords' powers. A banished Lord
  does not disable the army's Hunt, Siege, Pillage or Ward. Opposing Hunts and
  resummoning alongside these army actions remain legal with separate card payments.
- With no active targetable enemy Castle, the **Siege** button automatically
  reads **Pillage** and selects the Castle zone. Choose cards normally, use
  ALL IN, or drag cards into that zone. Protected construction does not prevent
  Pillage. There is no separate Pillage choice in GAME / RITES.
- GAME / RITES provides Hunt's Subjects/Infrastructure Fracture choice,
  Profane, waiter spending, Invocation, and Profane Ruins. It stages
  these into the same complete submission. Multiple groups of five waiters in
  the same lane are supported; reserved waiters and Invocation cards are removed
  from the corresponding available choices.
- To turn waiters into Tears, open **GAME / RITES → SPEND FIVE WAITERS**,
  select five waiting marchers in one lane, and stage the group. Each group is
  consumed for one Personal Tear when the round resolves. Marchers still
  traveling and groups mixing lanes are ineligible.
- Continue from combat to powers, then resolve the sealed plan. The board plays
  the actual Marching tape. Skip Animation completes presentation and advances
  Aftermath; it does not skip authoritative hooks.
- Victory opens the result screen and prevents further rounds. Start a new
  game or save the finished result.

The full conductor owns draws, named Castle effects, combat, resummoning,
Fracture, Tear accounting and victory. The UI adds no parallel rule engine.
Veil threshold penalties and automatic drift remain disabled; Lord Breach powers
and victory thresholds remain active. Exercise-only debug mutations are disabled.

## Interaction and balance patch · 2026-09-13

The playable session now reuses public views, terminal status and one validated
planning baseline while the match is unchanged. A local revision changes on
submission, hook/choice adoption, restore and next-round advancement. Replacing
the owner also clears caches. Returned views are detached copies, caches are
bounded, and worker sessions do not share them. The existing batch legality
validator admits edited carts; rejected carts retain full preview error details.
Live submission still performs full authoritative validation. Resummoning
quotes and save loading no longer copy event history just to read the world.

Local Godot 4.5.1 opening-board measurements: repeated refreshes went from
90–94 ms to 15–17 ms; staging a Guard plus refreshing went from 151 ms to
21 ms. These are local interaction measurements, not Windows GPU or full-match
timings. They do not claim every frame or machine will meet the same budget.

Vulture ranged shots now repeat every 32 simulation ticks instead of 8, a 75%
reduction in firing rate. Its 2 attack, 1 armor, speed 2, four-unit range and
non-piercing damage remain. Melee retains eight-tick exchanges, including when
an enemy closes during ranged reload; switching modes cannot reset the ranged
reload. Existing saves with the old shared attack clock remain readable.

Consume now checks that Kroni is present when the delayed bite fires. If he is
banished, it fizzles without eating the Guard or granting Hunger/feeding credit.
This is a Consume-specific firing check; the general armed-power rule remains.

## Doctrine V3

Odradek compares an affordable effect with saving toward an observed useful
Shift/Inversion target. Shift does not penalize friendly marchers; Redirect does,
and each uses its actual radius. Inversion values only available receiving slots;
the chosen Inversion lane is not filled with fresh guards. False Orders accounts
for destination capacity and public waiting pressure. There are no spell quotas.

Kanifous chooses a wish after its own complete card/development/guard allocation.
Death uses the actual 100-unit radius rather than 300. Wealth values card draws
(expected 2.1), remaining hand space and need, not Souls. Power uses its expected
1.35 recruits. Resurrection requires potential own guard losses under public
pressure; empty zones have no resurrection value. Longevity discounts queued
Repair. Public outstanding Prices increase a conservative risk penalty enough
to stop repeated marginal Wealth wishes. Outcomes of future Prices are never
sampled or inspected during planning.

The existing `U13_BOT_GUARD_SLOTS_V1` facade remains the only doctrine input:
enemy concealed guards expose occupied slots and opaque handles, not exact
values, suits or physical card IDs. Their strength estimate remains 3. Candidate
batches stay bounded at 32. Live submission still performs authoritative
admission, separately from planning-session caches.

## Validation and remaining acceptance

Local diagnostics used **Godot 4.5.1 Linux**, not the Windows acceptance runtime.
The basic-doctrine regression suite passed across all nine opening Lord pairs,
including exact replay, cached/uncached plans and concealed-face metamorphic
checks. Directed V3 fixtures cover wish radius, card need, debt restraint,
resource saving and guard-slot limits.

Playable session tests cover Stockpile and Slaver pauses, stale-choice rejection,
save/load of choices and a complete cart, independent production resolution
equality, animation-worker isolation, completed-round saves, and a real seeded
game finishing at round 12 with a restorable Dominion result.

The headless widget test drives setup, a human trade, Hunt, Fracture selection,
save/load, worker playback, Aftermath, next-round interaction, protected-zone
Pillage, Profane, multiple waiter groups, Invocation, Profane Ruins, and the
automatic terminal screen. It retains the production runtime check; its own
test harness explicitly enables widget exercise under the local diagnostic
engine. This is not Windows visual acceptance or a broad balance campaign.

Directed army-action checks also cover an absent Lord's Hunt, Siege, Pillage
and Ward, with and without resummoning. They verify separate card payments,
protected construction, guard defeats, Ward screening in both lanes, sealed
save/replay, and continued rejection of powers from an absent Lord. The widget
test stages Siege and Ward with an actually absent Lord.

For a focused Windows check without another full campaign:

```bash
bash Scripts/Sim/run_u13_playable_checks.sh "/path/to/Godot_4.7.2_executable"
```

That gate runs the army-action, V3 wish, interaction/cache, playable-session fixture and playable-widget
suites, preserves failures, and exports a unique upload ZIP directly to
Downloads. The longer representative full match is included when
`U13PlayableSessionTestRunner.gd` runs without `--fixtures-only`.

Next acceptance is a visible Windows 4.7.2 playthrough. The existing board
presentation remains in use; the roadmap's Action Window / Resolution Theater
and Action Forecast passes are still separate follow-ups.
