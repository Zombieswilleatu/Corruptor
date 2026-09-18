# U13 common doctrine V8: Guard placement and Work

V8 continues the Windows-accepted Odradek checkpoint at `eed8e2d`. It adds
bounded defensive comparisons to the experimental Python planner. Game rules,
castle Integrity, shared material weights and the playable Godot bot are not
changed by this doctrine pass. Greedy selection remains the default.

## Findings and directed evidence

The initial audit ran the first three rounds of all 81 ordered Lord matchups,
one seed per unordered pair, with the ordinary five-castle loadout and adopted
free-Lord opening. This is 486 planning decisions, not 81 complete games.
All selected Work targets were construction projects. In 81 decisions the bot
also had fresh Guard deployments and an unlocked, damaged active castle that
could receive Work. Those are opportunities to inspect, not 81 proven errors.

Changing just a Guard lane or Work target in recorded positions found nine
positions where an alternative preserved an existing active structure through
the round. Opposing orders were held fixed only for this retrospective replay;
the policy does not receive them. Newly activated structures that could avoid
destruction merely by staying unbuilt were excluded from that nine-position set.

V8's own selected plans preserve the Keep in two of these positions:

- `kroni_odradek_00`, round 2, seat 0: direct the same Guards' Work to the
  damaged Keep. The combat commitment, Guard placement and Kurchin recipe remain
  intact; the repair prevents the recorded Hunt from destroying the Keep.
- `kroni_valak_00`, round 3, seat 1: choose Wright Guards in the Lord lane,
  preserving the Keep while committing a different legal monster recipe.

The other seven positions remain uncorrected by the selected policy. These
directed cases establish concrete behavior, not a match win-rate benefit.

## Decision model

The planner compares six public stress cases: card attack strength 9, 15 and
21, each in the Lord and Castle lanes. Visible enemy Supplicants and Orias'
current Hunt bonus are added. These are equally weighted scenario points,
not hidden-hand estimates, probabilities or predicted opposing orders.

Each complete plan projects its known fresh Guards, fresh Penitent/Wright bonds,
actual capped Work, repair locks, persistent Work target and activation before
ordinary combat. It respects Ward's half-strength screen in the other lane,
reserved Projection Essence, sigils, the Keep's operational reduction and
Bastion interception. Siege uses the weakest targetable castle in the scenario.

Relative to continuing the current board without a new order, averting castle
destruction or Lord banishment receives the existing 30/32 material values,
averaged across those six cases. This is a score adjustment, never a legality
veto. Work replaces its old fixed score with three points per actual Integrity
gain plus the existing 30-point activation value, less progress that the
previous target already supplies without a new order. Capped or locked repairs
cannot invent gain; an old Wright and one fresh Wright cannot reactivate a pair.

Resummon, deliberate Profane sacrifice and paid-choice scenarios that already
settle the game retain their previous scores outside this small model. Enemy
powers, artillery, intervening reactions and spatial outcomes are unmodeled.
The scenario is therefore conditional even when its own Development calculation
matches authority. It does not certify survival against every legal attack.

## Candidate and diagnostic contract

Guard retention preserves a candidate in each available lane within the same
four-candidate cap. Up to four complete-plan slots consider an existing Guard
placement in the other lane or another retained Work target, preserving the
rest of the candidate's choices. They prioritize a high-scoring guarded plan
so a repair receives real Work. All cards and declarations are reassembled and
the entire plan is rescored; paid-resource omissions retain their own bounded
slots.

The limits remain 16 generated/four retained per category, 32 complete plans
and eight authority previews. Reserving alternatives can displace later ordinary
bundles; no Cartesian search or full-game candidate rollout is introduced.
Diagnostics distinguish scored public scenarios from actual resolution. In
particular, `selected_repairs` includes Work immediately after commissioning;
the evidence table below counts repairs to castles already active at planning.

## Opening behavior comparison

Both policies played all 81 openings on the same seeds and the `eed8e2d` rules,
including the first Dotra stalking pass but preceding `b61bc9e`. The candidate
was unchanged between this audit and the separate full-game comparison.

| First three rounds, both seats combined | Frozen V7 | V8 |
| --- | ---: | ---: |
| Planning decisions | 486 | 486 |
| Games with a castle loss | 40 | 18 |
| Games with a round-one castle loss | 20 | 10 |
| Castle destruction events | 78 | 31 |
| Guard cards committed | 527 | 656 |
| Hunt / Siege choices | 17 / 179 | 4 / 113 |
| Ward choices | 282 | 364 |
| Monster commitments | 476 | 481 |
| Actual repairs to already-active castles | 0 | 2 |
| Integrity restored by those repairs | 0 | 4 |
| Rejected previews | 0 | 0 |

The candidate chooses more defense and fewer attacks. These changed trajectories
do not show that all 47 fewer losses were mistakes corrected, or that the policy
is stronger. The same-side repair replay above supplies narrower causal evidence.
No score or pressure-point tuning followed these measurements.

## Reproduction and acceptance

The separate complete-game comparison finished **162/162 games, 3,036 rounds,
zero failures and zero rejected previews**. The result was **81-81**: 21 setup
sweeps for each policy and 39 splits. Each policy made 3,036 planning decisions.
V8 chose 727 Hunt/Siege attacks versus V7's 1,163, deployed 3,019 Guard cards
versus 2,402, and committed 2,943 monsters versus 2,927. This shows a substantial
behavior change and an even aggregate result in this sample; it does not
establish equivalence, a strength improvement or Lord balance.

The comparison uses frozen V7 at `eed8e2d`, both policy assignments for each of
81 ordered Lord matchups, a different seed namespace from the opening audit,
45 unordered seed clusters and one fixed loadout. Run it on the recorded
pre-`b61bc9e` engine when reproducing those historical outcomes:

```bash
python Scripts/Sim/compare_u13_doctrines.py \
  --baseline eed8e2d --repeats 1 --workers 6 \
  --namespace u13-defense-v8-comparison-2026-09-18 \
  --output early-defense-comparison
```

The pilot began before the implementation commit and before its new tests and
fixture were added. Its exact initial policy-package hash was independently
reconstructed from the implementation sources plus the prior fingerprint helper.
The original invocation's final source guard rejected the added test files;
the unchanged 162 records were subsequently verified and aggregated by the
normal runner in an isolated checkout with the exact original engine/package
fingerprints. No records, manifests or source guards were altered to accept them.
Raw logs and source reconstruction details are retained with the reports.

Local CPython 3.12.14 passed **129 tests and five complete games / 93 rounds /
2,333 operations**, with zero failures/rejected previews at `f83f515`.
After integrating the Dotra concealment update at `b61bc9e`, the same gate passed
at `fd3b906`, again 129 tests / 93 rounds / 2,333 operations. The two directed
positions differed only in the public monster-version label; both old observation
hashes are retained beside their integrated hashes. Their unchanged real-combat
assertions pass under the updated authority.

The later lane-sandbox update at `8c0fafd` is preserved in the publication.
It does not change the Python engine, doctrine, runner or directed inputs:
those files exactly match the tested integrated checkpoint. The broad comparison
still belongs to the earlier `eed8e2d` engine, not either subsequent update.
The published implementation is `249f54f`; its complete tree matches the local
integrated checkpoint `3dd82ee` (tree `b28bd8187d03618be66f2af656d639625c2f6547`).
The following documentation commit changes no implementation files.
See [source and result evidence](evidence/U13_EARLY_DEFENSE_LOCAL_2026-09-18.json).

The normal Windows CPython/PyPy gate checks the integrated checkpoint:

```bash
git pull --ff-only origin u13-basic-doctrine
bash Scripts/Sim/run_u13_common_doctrine.sh \
  "C:/Users/jerem/Downloads/pypy3.11-v7.3.23-win64/pypy3.11-v7.3.23-win64/pypy3.exe"
```

Windows acceptance remains pending. This is a Python doctrine checkpoint,
without a new native Godot parity or Lord-balance claim.
