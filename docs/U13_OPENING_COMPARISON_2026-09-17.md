# U13 opening comparison — 2026-09-17

> Subsequent decision: the user approved [production adoption](U13_FREE_OPENING_2026-09-17.md). This report preserves the original experiment and its exact scope. Reproduce its paid-opening control at `ad53086`; the current production setup is now the free-opening arm.

The normal-draw/free-Lord opening reduced games with a round-one castle loss
from **91/162 (56.2%) to 28/162 (17.3%)**, with almost unchanged match length:
**17.76 to 18.02 rounds**. This supports adopting the proposed opening and
playtesting it. The playable rules have not been changed by this experiment.

## Scope and exact source

- User authorized a comparison after identifying the oversized opening hand as
  a likely cause of early castle destruction.
- Source: `3af5ea860a71f4b91df820b2d18a4e160119d41d`. Engine and doctrine source
  exactly match the `c716b55` survey; the intervening commit added survey tools
  and documentation.
- Engine source SHA-256:
  `ae410d34ed0e1803f72575a1589e0df9f853a00001cd1b2eb9be9166a437e326`.
- Policy: `U13_COMMON_SMART_CORE_ALPHA_V3_RECIPES_VEIL`, unchanged default weights
  and planning budgets, with both seats independently planning under each opening.
- 162 paired cases / 324 complete games: all 81 ordered Lord matchups, including
  mirrors, twice. Uses repeats 00 and 01 of `u13-common-v3-survey-2026-09-17`.
- Each pair uses the same seed, Lords, seats, shuffled physical deck and loadout.
  Removing the setup deal changes which cards subsequent draws receive; later
  hands and decisions are allowed to diverge. Opposite seats also share a seed
  per unordered Lord pair/repeat, so these are not 162 independent seed clusters.
- Both seats use Keep, Stockpile, Summoning Circle, Siege Engine, Bastion, in
  that order. The first three are commissioned. Other loadouts were not sampled.
- Local Linux CPython 3.12.14, eight worker processes, round cap 40. This is a
  Python rule experiment, not new Windows/Godot/PyPy parity or a Lord-balance gate.

## Intervention

| Setup or rule | Control | Proposed opening |
|---|---|---|
| Separate setup deal | Five cards per seat | Omitted |
| Initial Lord summon | Pays lowest-value setup cards first | Free; Lord starts alive |
| Initial Circle offering | Three Integrity, discounted card cost | Omitted; no cost to discount |
| Initial Circle Integrity | 14 | 17 |
| Ordinary round-one draw | Five | Five |
| Stockpile and Slaver | Ordinary rules | Ordinary rules |
| Round-one action restrictions | None | None |
| Later Resummon, repairs, combat, powers, monsters, Veil | Current rules | Unchanged |

`compare_u13_openings.py` creates an ordinary `PowerMatch`, verifies its initial
deck/payment layout, then restores the undealt deck and removes only the initial
summon payments for the experimental arm. It retains all card IDs and trimming,
checks ownership/pile validity, and labels experimental snapshots with
`U13_EXPERIMENT_FREE_LORD_NORMAL_DRAW_V1` and a distinct rules hash. The probe's
constructor alias is replaced only within one scoped worker call. No production
module, hook, policy or native acceptance gate is edited.

## Results

| Measure | Current opening | Normal draw + free Lords |
|---|---:|---:|
| Complete games | 162 | 162 |
| Failed/censored games | 0 | 0 |
| Rejected plans / rejected previews | 0 / 0 | 0 / 0 |
| Games with a round-one castle loss | 91 (56.2%) | 28 (17.3%) |
| Individual round-one castle destructions | 156 | 37 |
| Games with any castle loss by round three | 103 (63.6%) | 85 (52.5%) |
| Median first castle-loss round, among games with a loss | 1 | 3 |
| Games without a castle loss | 1 | 0 |
| Mean match length | 17.76 | 18.02 |
| Median match length | 18 | 18 |
| Match-length range | 8–26 | 8–28 |
| `CASTLE_DESTROYED` events | 941 | 874 |
| Destructions per game | 5.81 | 5.40 |
| Additional Wish-Price castle ruins | 62 | 59 |
| Commissioned castles surviving at game end, both seats | 3.86 | 4.28 |

Loss timing includes destruction and Wish-Price ruins. No round-one loss in
either arm came from Wish Price. Destruction counts can include the same castle
again after reconstruction. Profaned ruins are not counted as surviving castles.

The decline in round-one loss incidence is **38.9 percentage points**, or **69.2%
relative**. Individual round-one destructions fell **76.3%**. Full-match direct
destruction fell only **7.1%**: after round one there were **785 control versus
837 experimental destructions**. The change mainly removes the opening burst;
castles remain vulnerable later.

The effect appears in both seed repetitions: round-one loss incidence was
**52 → 13 games** in repeat 00 and **39 → 15** in repeat 01, each out of 81.
Mean match length was 17.52 → 18.40 and 18.00 → 17.65 respectively. Across the
162 matched cases, 78 became longer, 65 shorter and 19 stayed the same length;
the mean paired change was **+0.265 rounds**. Round-one loss disappeared in 74
pairs and appeared in 11 other pairs. Winners changed in 54 pairs.

## What the doctrine did differently

| Round-one measure, 324 seat decisions per arm | Current | Proposed |
|---|---:|---:|
| Mean hand size after Stockpile/Slaver | 8.93 | 6.00 |
| Mean full-hand Hunt/Siege card strength | 23.82 | 15.32 |
| Hunt choices | 93 | 0 |
| Siege choices | 117 | 151 |
| Ward choices | 114 | 163 |
| Pass choices | 0 | 10 |
| Mean Guard cards deployed per seat | 0.70 | 1.05 |

Card strength is potential strength from the entire hand, not the amount actually
committed and not a forecast including all other effects. Aggression remains:
the proposed opening still produced Siege on **46.6% of opening decisions**.
It also changed targeting. Control round-one losses were 76 Keeps through Hunt
and 80 Circles through Siege; proposed-opening losses were 37 Keeps through Siege.

Victory routes were Final Collapse 99 → 89, Dominion 36 → 34, Ritual 27 → 39.
Per-Lord counts are retained in the evidence JSON but are too small, policy- and
loadout-dependent to justify Lord tuning. Existing Invocation and power/plan
conflict weaknesses remain in both arms.

## Validation and recommendation

All **162 control games** exactly reproduce their saved semantic reports,
operation digests, final-state digests and full policy observation/decision
traces from the earlier survey. The repeat-00 control also reproduces the earlier
81-game castle audit: 52 games with a round-one loss and 511 total castle losses.
Three focused setup tests passed. Three experimental games were independently
replayed from their saved operations; final digests and castle metrics matched.
Every saved record and both result summaries passed their fingerprint checks.

Recommendation: adopt the normal-draw/free-initial-Lord package for a playable
trial, then resume the identified doctrine fixes. It preserves early attacking
choices while giving the opening more room to develop, without a measured large
increase in match length. This result does not separately estimate the benefit
of the smaller hand versus restoring Circle Integrity: both belong to the tested
package. Production adoption needs matching Godot/Python opening changes and a
focused opening parity check; this experiment itself does not authorize a claim
that those changes have shipped or passed native acceptance.

## Reproduction and evidence

The [machine-readable evidence](evidence/U13_OPENING_COMPARISON_2026-09-17.json)
includes the manifest, complete paired summary, repetition breakdown and replay
checks. The companion archive retains all 324 full operation/decision records,
the 162 original control records, this report and the experiment's source.

From a checkout with matching production source and the original survey evidence:

```bash
python Scripts/Sim/compare_u13_openings.py verification/doctrine-survey-c716b55 \
  --output verification/opening-comparison --repeats 2 --workers 8
```

The runner rejects changed engine/policy source or mismatched cached identities.
Use a new output directory for a new source revision. No additional local run is
needed to inspect this completed comparison.
