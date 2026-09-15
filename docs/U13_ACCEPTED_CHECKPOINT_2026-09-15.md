# U13 accepted mechanics and forecast checkpoint

Recorded 2026-09-15 from the completed Windows campaign and the user's forecast
playtest acceptance. This closes the pending Guard Work full-game validation
bookmark. It does not establish Lord balance or Python parity.

## Revision boundaries

| Evidence / change | Exact revision | Scope |
| --- | --- | --- |
| Completed 100-game campaign | `357d793825ffb23a91e928290b47f4eeb7d2af8b` | Random-Legal V5; Guard Work, defensive pairs, Supplicants, Pillage retargeting and prior fixes |
| Public Guards / Action Forecast | `dd9638ceaa90075421710c7d8c149749b4fff967` | Separate branch based on 357d793; user reports “the action forecast is working” |
| Parallel development head before integration | `5c1fa481dda58a32d7fd9b8dc1bd5e57fc26674e` | Subject/monster animation-gallery entry and sprite lookup fallback |

Both remote heads were fetched before integration. Their changes are disjoint.
The development integration retains both parents and preserves the animation
gallery files exactly. Forecast source files match dd9638c; the forecast shell
runner is marked executable consistently with the other launchers. U12 and the
legacy Python simulator/goldens are unchanged.

The former local forecast commit `ad85c1f` and remote `dd9638c` have the same
tree (`68b9f724d19aa630f3ca00a04a15978207845099`). Integrate the remote commit to
preserve its ancestry. Do not mistake the former local branch's upstream
(`origin/u13-basic-doctrine`) for its actual forecast branch.

## Accepted Windows campaign

Source archive:
`u13-full-matches-357d7938-e69de29b-r40-R439Sl-2026-09-14_21-23-20-Kl2kSJ.zip`

SHA-256:
`9e4bfd1b44aa5cf269bca873ae3d1eb45cb4b0fa7097e7e3b493d8c613462f67`

The archive's `summary.json`, `run-status.txt`, 100 per-game JSONs and logs were
checked. The derived [evidence record](evidence/U13_ACCEPTED_100_357d793.json)
pins the source hash, aggregates and individual game identities/hashes. The
original archive remains the source evidence; the derived record is not a replay
trace or a replacement for its full plans/logs.

| Check | Result |
| --- | --- |
| Runtime | `4.7.2.stable.official.ed1daf0bf` (Windows) |
| Source diff hash | `e69de29bb2d1d6434b8b29ae775ad8c2e48c5391` (clean) |
| Batch / bot | `U13_FULL_MATCH_BATCH_V2` / `U13_GAME_RANDOM_LEGAL_V5` |
| Event profile | `U13_BATCH_EVENTS_V1` |
| Requested / completed / replay verified | 100 / 100 / 100 |
| Exit status / gate passed | 0 / true |
| Unique game indices / ordered Lord pairings | 100 / all 81 |
| Censored / failed / missing / script errors | 0 / 0 / 0 / 0 |
| Round cap / actual rounds | 40 / 9–27 |
| Mean / median rounds | 20.07 / 20 |
| Dominion / Final Collapse | 52 / 48 |
| WORK_RESOLVED | 2,441 |
| GUARD_PAIR_FORMED / SCREEN / STRIKE | 239 / 164 / 94 |
| PILLAGE_RETARGETED | 4 |

This is Random-Legal completion, save/restore and deterministic Godot replay
evidence. It is not doctrine-strength, balance, or cross-engine parity evidence.
The earlier nine-game uploads and the older d605e3a campaign have different
scopes. Neither should be substituted for this archive. This campaign predates
dd9638c and does not validate its public-Guard doctrine or forecast changes.

## Accepted mechanics to mirror

Use the implementation and focused fixtures for exact timing. The following
summarizes the accepted profile; it is not a new balance change.

- One persistent Work Target. An unbuilt target receives +3 passive construction
  per round. Each newly deployed Guard in either zone contributes +1 Work; a
  fresh Wright pair adds +5 once. Surviving Guards do not generate recurring
  Work. Repair locks still apply. Ruins are irreparable except living Deimos's
  protected reconstruction of his own Siege Engine.
- Paid Repair/acceleration and the Wright payment exemption are retired. The
  legacy repair-token schema field is inert at zero, not a usable resource.
- Two fresh matching Guards form a bond between exact card IDs and slots.
  Breaking it ends its benefit; a replacement beside a survivor cannot restore
  it. Penitents screen 5 before Guards; Butchers destroy an opposing same-lane
  Marcher when attacked; Vultures add the ongoing capped draw while intact;
  Wrights grant their one-time Work. See [Guard Work](U13_GUARD_WORK_2026-09-14.md).
- Ward recruits at 2:1 per printed suit; Hunt/Siege retain 3:1. Matching-lane
  Supplicants supply +1 each to attacks and are consumed, excluding those
  reserved for Rites. Waiting friendlies no longer block gate arrivals.
- Kroni Consume reconciles broken pairs before validation. Relevant zero-
  Integrity Lord damage paths ruin Castles. Pillage deterministically retargets
  the leftmost targetable enemy Castle if one appears before resolution.
- Neutral pressure is +1 after rounds 13–20, then +2 from round 21, before
  victory evaluation. Veil threshold penalties remain disabled.
- The shared action modal, grouped Aftermath outcomes, history-sample retirement
  and save/log locations are accepted presentation/runtime behavior. See
  [action flow](U13_ACTION_FLOW_2026-09-14.md) and
  [Supplicants/history](U13_SUPPLICANTS_HISTORY_2026-09-14.md).

## Forecast and public information acceptance

The user accepted the playable version and explicitly confirmed the forecast
works. Deployed Guard faces, values and intact bonds are public to both players
and bots. Private hands and unrevealed simultaneous orders remain private.
Versions: `U13_BOT_PUBLIC_GUARDS_V2` and
`U13_BASIC_DOCTRINE_V8_PUBLIC_GUARDS`.

The forecast gives a current-board baseline including recruitment, support,
Guard defeat thresholds, pair screens, Sigils, interception and relevant target
basics. It labels assumptions; it does not assign invented probabilities or
simulate every simultaneous order/spatial reaction. See
[forecast scope](U13_ACTION_FORECAST_2026-09-14.md).

Previous local Godot 4.5.1 diagnostics passed ActionForecast, BasicDoctrine,
DoctrineCoverage, GuardWork, PlayableBoard and ActionFlowBoard. The merged tree
also passed the existing ActionForecast diagnostic: 87 checks, zero failures or
script errors. These are diagnostic results, not Windows 4.7.2 automated
acceptance. No separate Windows forecast-suite report was supplied at this
checkpoint; preserve that distinction from the user's playtest acceptance.

## Next milestone

Proceed to the [PySim parity inventory and first slice](U13_PYSIM_PARITY_2026-09-15.md),
then Common Smart Core and separate Lord doctrines, then serious balance testing,
then roguelite work. Do not reopen accepted UI work or request another broad
campaign merely to record or integrate this checkpoint.
