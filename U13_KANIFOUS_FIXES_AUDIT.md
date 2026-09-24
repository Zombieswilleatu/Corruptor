# Kanifous fixes and follow-up audit — 2026-09-24

## Changes

- Wish Price presentation now recognizes a collection event by debt ID, owner, round and event type. Repeated session event lists cannot reopen the same acknowledged Price. Distinct debts and later deferred retries remain visible. Board reset clears the presentation queue/history.
- Python split-Ward admission keeps Ward cards in their hand until the other disjoint payments are admitted. Previously, temporarily removing them from every zone caused Rites/Resummon deck validation to fail. Explicit overlap checks prevent spending a Ward card on combat, guards, work, summoning or invocation too. This is a shared admission correction, not a Kanifous stat change.
- Wish of Power UI odds corrected to the existing 25%/50%/25% distribution for one/two/three bodies. Native and Python engines already agree on those odds.
- Updated one stale Resurrection test expectation to the current Lemek material value (54); the same test failed on the unmodified baseline.

## Paired audit

Current theater baseline includes Deimos engine-first/War Machine doctrine and 85% Rout flee speed. Standard castle order, Soul/Tear targets and all Lord kits are unchanged. Wish doctrine weights are unchanged.

32 exact setups in each arm: all eight Kanifous opponents, both seats, repeats 0 and 1 from the overnight survey. Three workers; 64 complete games. These are reused diagnostic seeds, not a fresh validation sample. The popup is native presentation code and cannot affect Python match outcomes.

| Measure | Before | Fixed |
|---|---:|---:|
| Kanifous wins | 13/32 | 12/32 |
| Rejected previews, both players | 18 | 0 |
| Kanifous banished planning turns | 86/509 | 78/495 |
| Mean ending round | 15.91 | 15.47 |
| Ordinary Wish Wealth casts | 0 | 0 |

| Opponent | Before | Fixed |
|---|---:|---:|
| Deimos | 2/4 | 2/4 |
| Gremory | 3/4 | 3/4 |
| Humbaba | 1/4 | 0/4 |
| Kalligan | 2/4 | 2/4 |
| Kroni | 1/4 | 1/4 |
| Odradek | 1/4 | 1/4 |
| Orias | 1/4 | 1/4 |
| Valak | 2/4 | 2/4 |

Paired result changes: 0 gained wins, 1 lost wins. Four games per opponent is too small for matchup balance conclusions.

## Orias comparison across the roster

The user's correction is supported: every opponent has a higher banished planning-turn share against Orias. Kanifous is not uniquely suppressed. These are the existing overnight games, before the current Deimos and admission fixes; 20 Orias games per opposing Lord and 140 games against their other seven nonmirror opponents. Percentages pool planning observations and are descriptive, not independent per-turn statistical trials.

| Lord | Against Orias | Against other opponents |
|---|---:|---:|
| Deimos | 36.1% (95/263) | 19.2% (393/2049) |
| Gremory | 24.1% (64/265) | 13.2% (267/2019) |
| Humbaba | 30.8% (85/276) | 20.0% (418/2091) |
| Kalligan | 24.6% (69/281) | 10.3% (224/2171) |
| Kanifous | 30.9% (98/317) | 16.6% (380/2282) |
| Kroni | 26.1% (81/310) | 16.9% (399/2367) |
| Odradek | 37.5% (115/307) | 15.3% (345/2247) |
| Valak | 20.7% (71/343) | 8.4% (207/2476) |

This supports auditing shared anti-Hunt defense and return quality before interpreting banished time as a Kanifous-specific kit flaw.

## Wealth remains an unresolved doctrine question

The existing doctrine values the expected 2.1 cards at at most 21 points, while Wish of Power starts at 39 points for expected material, plus up to 24 for lane need. Both subtract the same Price estimate on a given plan. Consequently ordinary Wealth cannot beat an available Power on that plan under these scores. Correctly estimating hand space alone cannot solve that ranking.

Wealth resolves after commitments, so the audit's nearly full expected draw does not mean it helps the current attack. Its flexibility for future attacks, recipes, repairs and returns may be undervalued; upcoming ordinary draws and the ten-card cap may also reduce its marginal benefit. A zero cast count under this structurally dominated scoring model cannot establish that the ability itself is underpowered. No Wealth kit buff or unvalidated score increase is included here.

## Verification and limits

- 60 focused Python tests passed: split-Ward, payment/rollback, Rites, Ward recipes, Kanifous scoring and comparison aggregation.
- Replayed kanifous_orias_01 at round 3. All five previously rejected Ward/resummon plans are legal after the fix; regenerated planning has no rejected previews there.
- Native board regression coverage added for repeated acknowledged events, distinct simultaneous debts, deferred next-round retries and reset. Godot is unavailable in this environment, so the native popup regression has NOT been executed here.
- No long roster run is required to accept the admission correction, but these 32 pairs do not establish new roster win rates. Re-run the broader survey on the corrected simulator before tuning kits from prior rejection-contaminated results.
