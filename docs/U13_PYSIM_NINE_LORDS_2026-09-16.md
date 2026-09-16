# U13 Python nine-Lord rules checkpoint

## Scope and authority

`u13_pysim.power_match.PowerMatch` extends the accepted Python simulator through
complete games with all nine existing Lords and all 23 declared powers. It uses
the same opening, paid Rites/Resummon, ordinary rules, transactions and flat-column
Marching kernel. The historical four-Lord `FullMatch` and isolated adapters retain
their explicit boundaries.

Current Godot U13 production rules remain authoritative. This checkpoint changes
the Python mirror and verification tools, not production Godot rules, balance,
the shipping bot, U12, playable UI or assets. The proposed permanent Veil and
monster system are outside this checkpoint. Experimental doctrine remains an
injected policy; no tuned policy is embedded in the rules engine.

## Rules added

| Lord | Declared powers | Additional integration |
| --- | --- | --- |
| Gremory | Predator of Ruin, Inevitable Ruin | Scheduled spawning/destruction, discard payment and firing rechecks |
| Deimos | War Machine, Rout | Extra artillery shot and persistent movement modifier |
| Humbaba | Muster the Faithful, Breath of Life | Recruitment and persistent regeneration aura |
| Kalligan | Pyroclasm, Inferno | Guard/lane pulses, relocation and original effect lifetime |
| Orias | Web, Snare | Spatial Web, Threat payment, public Guard limits and existing marks/Conduit |
| Odradek | Allegiance Shift, Redirect, Inversion, False Orders | Reconfiguration, Guard/Marcher transfers, Psychic Interlock and Paradox Geometry |
| Kroni | Consume, Ravenous | Hunger, scheduled feeding, swept actors, panic/flee/carry, rewards and Breach actor |
| Valak | Gravity Orb, Projection | Essence reservation, persistent orbs, projection and expiry |
| Kanifous | Wish Longevity, Death, Power, Resurrection, Wealth | Delayed Prices, smoke/lamp lifecycle, four suit outcomes and rejection |

The shared effect lifecycle handles canonical declaration identity, queue order,
resource/discard payment, cooldown registration/readiness, persistent stages and
expiry, relocation, invalid-target fizzles and ordered terminal events. Public
power events retain private per-player views for underlying card draws.

Submission previews stage the combined paid plan. A rejected second seat or
failed hook rolls back the first seat's changes, queue, resources, identities,
clocks and history. The owned transaction optimization remains conservative for
custom handlers or escaped state. Powers can change Marching ownership or spawn
units without depending on registry insertion order; the existing explicit
contact ordering remains in use.

Parity follows actual native timing. For example, a Work-only Kroni order is not
the native empty-Pass Hunger case. Full-game publication normalizes integral
actor floats like Godot's state/EventLog installation; raw tick probes preserve
their float bits. Neither distinction is a new rule.

## Focused reference corpus

`power_inputs.json` records decisions, not expected states. Native export uses
production `U13GameConductor` and independently replays the same inputs. Python
starts from setup and executes each operation without importing native outcomes.
All state fields, identity histories, ordered semantic events, per-player event
views, pending effects, cooldowns and persistent registries are compared.

Five games use ordinary setup and legal decisions through actual victory. There
are no fixture edits in these games:

| Match | Rounds | Input operations | Outcome |
| --- | ---: | ---: | --- |
| Gremory / Humbaba | 11 | 277 | Ritual, seat 0 |
| Deimos / Kalligan | 15 | 385 | Dominion, seat 1 |
| Orias / Odradek | 22 | 551 | Final Collapse, seat 0 |
| Kroni / Valak | 18 | 458 | Dominion, seat 0 |
| Kanifous / Gremory | 15 | 381 | Final Collapse, seat 1 |
| Total | 81 | 2,052 | Five completed games |

Ten terminal rejection operations and eight settlement cases are checked
separately. The coverage input driver is deliberately bounded and scripted to
exercise mechanics; it is not the new doctrine and establishes no strength or
balance result. A Lord appearing in a full game does not imply every one of its
power branches occurred in that game.

The 34 separately labeled components contain 1,065 operations, including 126
expected atomic rejections and 37 explicit fixture preparations. They include:

- All 23 powers admitted, paid, queued and resolved through ordinary hooks.
- Twelve full 200-tick probes: 2,400 tick frames plus every intervening semantic
  event. These cover persistent fields, actors, all four lamp suits/rejection,
  Psychic Interlock and a Breach actor during Valak collapse.
- Source banishment before Consume, a repaired target before Inevitable Ruin,
  shared-budget repeatable queues, and the Work-only Kroni boundary.

Fixture preparation appears only in those named components and settlement
cases. Synthetic phase probes are not counted as additional complete games.
Ordinary batch games retain the accepted omission of presentation tick samples;
the directed probes compare the full raw tick stream.

The verifier also rejects the existing 13 evidence corruptions and three new
ones in pending effects, cooldowns and persistent stages. A mismatch identifies
the game/component, operation, round, hook and nested state/event path.

## Verification and Windows gate

Local Godot is official Linux **4.5.1**, so local results are diagnostic only.
The combined native export and independent replay passed **31,752 checks** with
zero failures or script errors.
Local CPython passed **84 cumulative engine tests** and **20 doctrine diagnostic
tests**, matched the complete corpus above and rejected all **16** corrupted
streams. Replaying the previously accepted Windows paid-development stream also
preserved all four games / 57 rounds / 1,462 game operations and 258 component
operations. That regression is a local candidate check against old accepted
evidence, not new Windows acceptance.

The combined native export/replay and Python comparison are recorded in
[local evidence](evidence/U13_PYSIM_NINE_LORDS_LOCAL_2026-09-16.json).
Final review added a guard that skips Wishmaster row snapshots when no live
Marcher has a ghost wish. The final candidate replays the unchanged native stream
with an identical complete summary; the evidence records its source fingerprint
separately from the original export's fingerprint. The Windows runner exports a
fresh stream from the actual checkout. This is not a new timing comparison.

Windows **4.7.2 stable**, CPython and PyPy acceptance remains pending.

Run from the new checkout in Windows Git Bash:

```bash
bash Scripts/Sim/run_u13_pysim_powers.sh \
  "C:/Users/jerem/OneDrive/Documents/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64.exe" \
  "C:/Users/jerem/Downloads/pypy3.11-v7.3.23-win64/pypy3.11-v7.3.23-win64/pypy3.exe"
```

The runner checks runtime identities, runs cumulative Python tests under both
interpreters, exports and independently replays the native reference, compares
the full stream under both interpreters, runs corruption checks and requires
identical complete summaries. It packages a ZIP in Downloads and reports progress.
The native stage has a 60-minute ceiling; each Python stage has 15 minutes.
This export/replay duration is not a simulation throughput benchmark.

## Next: shared doctrine

After the focused Windows gate, follow the accepted
[doctrine plan](U13_DOCTRINE_START_2026-09-16.md): add measured power/paid-choice
observations and candidate explanations, then build the bounded common planner
and nine separate Lord decision modules. U12 supplies selected ideas and
regression examples, not inherited architecture or weights. Each Lord needs
general power competence in this first pass; specialization comes later.

Keep the existing limits: 16 generated proposals per category, four retained,
32 complete plans scored and eight authoritative previews. Apply the reconciled
Veil settlement contract rather than avoiding all actions that add Tears.

Five focused roster games close the implementation dependency; they do not
replace the roadmap's approximately 50–100 exact reference games before serious
balance work. Expand that corpus around exercised planner behavior and mechanic
interactions, then use matched seeds, crossed seats, ablations and held-out
checks. No further optional optimization campaign is opened here.
