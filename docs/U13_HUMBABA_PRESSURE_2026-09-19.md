# U13 Humbaba V12: reachable support and controlled replays

**Fresh result: V12 37–31 V11.** All 68 games completed: 1,282 rounds /
32,360 operations, zero failures, caps or rejected previews. The two repeats
finished 18–16 and 19–15. Of 34 policy pairs, V12 won both assignments eight
times, V11 five times, and 21 split.

Against the eight unchanged Lords at the same seats and seeds, Humbaba won
12/32 setups under V12 and 10/32 under V11: seven gained wins, five lost,
20 unchanged. This is encouraging fixed-loadout evidence for the candidate,
with limited seed coverage. It does not establish general strength or Lord
balance. Windows dual-runtime acceptance remains next.

This checkpoint tests a narrower Breath heuristic after V11 finished 90–102
against V10. Game rules, the immediate pulse, duration, cooldown, Scorch,
Deimos doctrine and shared weights are unchanged.

| Observed behavior | V11 | V12 |
| --- | ---: | ---: |
| Breath used / decisions with Breath ready | 175 / 175 | 177 / 218 |
| Breath held while ready | 0 | 41 |
| Opening Breath / 36 openings per policy | 36 | 0 |
| Opening Muster: Castle / Lord | 36 / 0 | 18 / 18 |
| Breath paired with same-lane Muster | 155 | 11 |
| Muster placed into already active Breath | 4 | 119 |
| Actual immediate HP restored | 213 | 193 |

Games and opportunities diverge. V12's result comes with **less immediate
healing**, so neither extra healing nor a single opening change explains the
win difference. The comparison measures the complete resulting policy.

[Compact evidence](evidence/U13_HUMBABA_PRESSURE_2026-09-19.json) records source
identities, the audit, diagnostic results and the evidence archive checksum.
Implementation `5dccbcb` has exactly the tested tree; reports retain its local
commit alias `ef403c5` (tree `1c317228cd711f22ed5b60f8fcd0bb3edb8cf517`).

## What the controlled replays establish

Twenty-eight complete continuations separate Muster's opening lane from Breath,
plus Rout from Work in one Deimos mirror. The selected submission preserves
ordinary orders and the opposing submission; the original frozen V11/V10
policies respond normally thereafter. All five original-choice controls
reproduce the saved complete operation stream and final state exactly.

The table reports whether **Humbaba** won; the number is the finishing round.
Each row holds the ordinary opening fixed across all six choices.

| Saved opening | Muster Lord, hold | Muster Lord, Breath Lord | Muster Lord, Breath Castle | Muster Castle, hold | Muster Castle, Breath Lord | Muster Castle, Breath Castle |
| --- | --- | --- | --- | --- | --- | --- |
| Humbaba / Valak 00, original loss | L23 | L21 | L21 | L22 | W21 | L21 |
| Kalligan / Humbaba 02, original loss | L15 | L23 | W15 | W21 | W19 | L17 |
| Gremory / Humbaba 00, original win | W14 | W18 | W18 | L20 | W16 | W14 |
| Kalligan / Humbaba 00, original win | W14 | L12 | W21 | L19 | W18 | W18 |

There is no universal opening repair. Holding Breath with Castle-lane Muster
saves one selected loss but breaks both selected wins. Switching Muster alone
does not consistently help. An empty-lane Breath wins some continuations by
changing the subsequent cooldown/action sequence; that is not evidence for
deliberately wasting the ability.

The early observations distinguish effects from outcomes. With Castle-lane
Muster, the immediate opening pulse heals zero HP in all four examples. Casting
on Castle advances the three new Penitents an extra 150 field-position units
each in the first Marching phase, versus holding. The ordinary round-two
regeneration checkpoint has the same total allied HP for these alternatives.
Later contact, casualties, orders and cooldown opportunities diverge. Increased
movement alone does not identify which continuation will win.

The separate round-two Deimos intervention gives:

| Work target | Hold Rout | Rout Castle |
| --- | --- | --- |
| Siege Engine | L15, original | W23 |
| Bastion | L18 | L23 |

Rout can matter beyond the current-pressure estimate, but this one selected
position does not justify a general Deimos change. Its doctrine remains V11's.

These are post-hoc diagnostic examples, not a strength cohort. The original
V10/V11 comparison remains unmodified.

## Candidate change

V11 prices every eligible movement window, including fresh recruits in an
empty lane. A same-lane Muster alone supplies six windows and 18 points before
ordinary recruits add further credit. This encourages immediate activation and
lane concentration without a reachable public objective.

V12 preserves capped immediate healing and the existing conditional next-regen
estimate. It credits movement only if nominal travel across the two active
rounds can reach a visible enemy, enemy field structure or the opposing gate.
The nominal estimate includes Breath's 25% speed and public enemy movement
readiness. Existing melee contact, Vulture stopping range, waiting units,
consumed Supplicants and rooted turrets are handled before movement credit.

Own ordinary recruits use their public committed suit and next-round readiness;
Muster uses three immediately ready Penitents. Planned spawn positions use the
home edge and lane centre, without reading keyed placement or hidden orders.
Monster spawn movement remains unpriced. Pacing, paths, modifiers, future enemy
recruitment and survival can invalidate the estimate: it is a preference, not
an authority rule or a promised combat benefit.

An empty full-health opening can now hold Breath while still casting Muster.
A healthy force approaching visible pressure can still receive Breath, and
same-lane pairing remains available within the existing bounded search. Raw
eligible movement windows and credited pressure windows are recorded separately.

The two historical empty-opening tests now assert holding Breath; their original
V11 fingerprints and all original input operations remain in the fixture.
The four other natural Rout/heal/support decisions retain their exact plans.

## Verification

- Local CPython 3.12.14: **168 tests**, five complete games, **84 rounds /
  2,118 operations**, zero failures or rejected previews.
- Forty-eight recorded detached public views across the eight other Lords:
  identical selected plans and scores under V11 and V12. This is a decision
  regression check with permissive admission, not 48 full-game controls.
- Same authority source SHA-256:
  `00dd00f2192f5c5913494b0cb7cea11fc58b04080ab1d8b9216c7760fc6c9c11`.
- Candidate policy/observer SHA-256:
  `cecf57e52ade545edb8da4ad1188c4dba44089cfaef2441e9a246c7ab306b97c`.

The accepted Windows native Breath rules gate remains valid. V12's Python
dual-runtime acceptance is still pending. The first Windows attempt and the
runner correction are recorded below. After pulling this checkpoint in
Git Bash, the wrapper produces the reports ZIP in Downloads:

```bash
git pull --ff-only origin u13-basic-doctrine &&
bash Scripts/Sim/run_u13_common_doctrine.sh \
  "C:/Users/jerem/Downloads/pypy3.11-v7.3.23-win64/pypy3.11-v7.3.23-win64/pypy3.exe"
```

### Incomplete Windows attempt and runner timeout correction

The uploaded `u13-common-doctrine-TwplP8-2026-09-19_10-04-05-X6kneQ.zip`
identifies clean revision `4dd3c02`. CPython passed **168 tests in 425.708
seconds**, followed by `gremory_humbaba` (**16 rounds / 400 operations**).
The runner then exited with status 1. No complete CPython report, PyPy log,
or comparison exists in the archive, so this is **not dual-runtime acceptance**.

The ZIP timestamps for `revision.txt` and `run-status.txt` are exactly 600
seconds apart. That matches the wrapper's old ten-minute limit for the
**entire** Python check (unit tests plus five games). The old timeout message
went only to the terminal, so the archive cannot directly confirm the reason;
its timing and otherwise passing log strongly indicate watchdog termination.

The wrapper now allows **1,800 seconds per Python check**, retains 600-second
limits for native and comparison commands, and records the runtime versions,
phase timings, exit reason and applicable deadline in the ZIP. A timeout kills
the active child and returns status 124, with the watchdog message in both the
phase log and `runner.log`. Nonzero command exits and error text from commands
that return zero still fail. `U13_DOCTRINE_TIMEOUT_SECONDS` can override the
Python deadline with a positive integer up to 86,400. `U13_REPORT_DOWNLOADS`
consistently selects the report folder and ZIP destination when set.

Seven local Linux process tests passed using explicit stub runtimes: the
successful sequence and separate deadlines, nonzero command failure, an error
with zero exit status, CPython timeout, PyPy timeout after CPython completes,
termination cleanup, and invalid deadline input. These verify the wrapper and
its packaged diagnostics; they are not CPython/PyPy doctrine parity evidence.
Run them separately with
`python3 Scripts/Sim/test_u13_doctrine_runner.py`.

This correction was applied after preserving the separate Vulture preview at
`b1f1609`. It changes the wrapper and adds its process tests; it does not alter
the doctrine suite, game assertions or policy. The next Windows run must finish
both checks and their comparison before acceptance can be recorded.

## Fixed fresh comparison protocol

The fresh comparison is fixed before results: **68 games**, all 17 ordered
matchups involving Humbaba, two repeats and both policy assignments. Opposite
Lord orders share the unordered-matchup/repeat seed. This gives 34 policy pairs
and 18 seed clusters. V11 is frozen from `5074b72`; both policies share the
accepted current engine and ordinary five-Castle loadout.

The namespace is `u13-humbaba-pressure-fresh-2026-09-19`, separate from the
diagnostic cases. Default greedy selection and shared weights are unchanged;
limits remain 16 generated / four retained per category, 32 complete plans and
eight previews. The round cap is 40; incomplete games count as failures. The
fixed set runs to completion without adaptive stopping or seed selection.

```bash
python Scripts/Sim/replay_u13_support_choices.py \
  --source /path/to/support-v10-v11-comparison \
  --output /path/to/support-choice-replays --workers 8
python Scripts/Sim/compare_u13_doctrines.py \
  --output /path/to/humbaba-v11-v12-comparison \
  --baseline 5074b720d601339b8f6bf7bd0753e984aba765f9 \
  --repeats 2 --workers 7 --lord Humbaba \
  --namespace u13-humbaba-pressure-fresh-2026-09-19
python Scripts/Sim/audit_u13_humbaba_pressure.py /path/to/humbaba-v11-v12-comparison
```

The replay runner freezes both original policies by Git revision, preserving
the diagnostic experiment even after the current policy changes. The fresh
comparison and audit verify full saved records and source identities.
