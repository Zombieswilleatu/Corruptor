# V5 doctrine campaign and 100-game launcher

## Accepted baseline

Windows Godot 4.7.2 accepted `9e55f654`: five fixture suites, 462 checks, zero failures or script errors. This campaign used that gameplay code on local Godot 4.5.1 Linux, two workers, a 40-round cap, and independent planning/save/resolution replay for seeds 9 and 59. The other seven games used single-conductor legality checks.

**9 wins, 0 capped, 0 failures; 163 rounds.** Three Dominion, three Ritual and three Final Collapse wins. Player 0 won six games and player 1 won three. All Lords appeared in both seats. This is regression coverage, not a balance verdict.

| Seed | Lords | Rounds | Victory | Winning seat |
| --- | --- | ---: | --- | ---: |
| 9 | Gremory / Deimos | 12 | FinalCollapse | 0 |
| 19 | Deimos / Humbaba | 18 | Dominion | 0 |
| 29 | Humbaba / Kalligan | 28 | Ritual | 0 |
| 39 | Kalligan / Orias | 10 | Ritual | 0 |
| 49 | Orias / Odradek | 13 | Ritual | 0 |
| 59 | Odradek / Kroni | 17 | Dominion | 1 |
| 69 | Kroni / Valak | 19 | Dominion | 0 |
| 79 | Valak / Kanifous | 31 | FinalCollapse | 1 |
| 8 | Kanifous / Gremory | 15 | FinalCollapse | 1 |

## Action and power review

Twenty of 23 active powers appeared in plans. Inversion, False Orders and Wish Power did not appear in this small campaign; the earlier directed coverage remains relevant. Wish Resurrection appeared seven times naturally. Ward appeared ten times, with no run of four identical consecutive Ward choices.

The longest repeated Siege sequence was Kalligan attacking the same castle for nine rounds in seed 29. The available checkpoint showed actual damage and guard removal while the defender repaired; repetition alone is not evidence of a wasted order.

The next useful directed review is seed 79: Kanifous selected Hunt for 19 consecutive rounds (11–29). Many caused no banishment or guard loss, while some removed guards. Check card spending, recruitment value and Wish reservations before changing scores. The game still ended with a Kanifous Final Collapse win in round 31. No speculative combat-scoring change is bundled into the larger campaign.

Checkpoint event review covers only completed rounds before each periodic save, not every final round: 175 recorded power resolutions returned resolved; 12 of 200 recorded Sieges had no castle damage, guard loss, sigil break or successful Pillage. Two combat orders fizzled after their targets became unavailable. A resolved power does not by itself prove strategic benefit.

## 100-game launcher

`run_u13_doctrine_100.sh` runs 100 games with four workers by default, 40 rounds maximum per game, and replay on every fifth game (20 of 100). It clears fixture-only mode, runs the existing five preflight suites, and uses the existing failure handling, checkpoints and unique Downloads ZIP packaging. Worker count, round cap and replay interval retain their environment overrides.

The general scheduler previously repeated exact seeds after the first 81 games. Later cycles now add a multiple of 81 to the seed index, preserving the ordered Lord pair while generating a fresh game. The first nine seeds are unchanged; the first 81 cover every ordered Lord pairing, including self-matchups. A direct Bash schedule check verified 100 unique accepted seed indices, all 81 ordered pairs, the unchanged opening ring and 20 replay slots. Both shell scripts passed `bash -n`.

The local campaign took 340.37 seconds (5m 40s). A simple same-machine, same-two-worker extrapolation is about 63 minutes for 100 games. This does not predict Windows throughput or four-worker scaling. The user-facing 1–3 hour Windows estimate remains provisional; long games and replay contention can change it.

```bash
bash Scripts/Sim/run_u13_doctrine_100.sh \
  "/c/Users/jerem/OneDrive/Documents/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64.exe"
```

A capped match is reported separately from a failure; the campaign continues through capped games. Actual failures stop workers and preserve reports. Keep the computer awake while the unattended run is active.

Deferred visual issue: Ward artwork is stretched too far. User requested continuing doctrine; address its aspect/extent in the next visual pass.
