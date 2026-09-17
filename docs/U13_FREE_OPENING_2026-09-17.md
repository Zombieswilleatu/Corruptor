# U13 free opening adopted — 2026-09-17

The user accepted the normal-draw/free-initial-Lord package after the
[162-pair comparison](U13_OPENING_COMPARISON_2026-09-17.md). It is now implemented
in the Godot game economy and the Python opening authority. The comparison's
round-one castle-loss incidence fell from 56.2% to 17.3%, while mean match length
changed from 17.76 to 18.02 rounds. Those remain Python experiment results, not a
claim of native full-game acceptance for this revision.

## New-match behavior

- Both Lords start alive for free, with summon count one, no return Tear and no
  initial Threat/Fracture. Initial Summoning Circles make no Blood Offering and
  retain their full current Integrity, normally 17.
- Setup deals only the three Slaver offers. There is no separate five-card setup
  hand and no initial card payment. Round one draws the ordinary five cards;
  active Stockpile and Slaver choices apply normally. The tested loadout reaches
  planning with six cards per seat.
- Round one permits the usual actions. Later draws, paid Resummon, Circle
  discounts, combat, castles, powers, recipes and Veil rules are unchanged.
- Initial summons retain canonical zero-cost ledger entries. The economy policy
  becomes `U13_GAME_ECONOMY_V5_FREE_OPENING`. The shuffle namespace deliberately
  stays `U13_GAME_ECONOMY_V4`, preserving the exact physical deck and trim
  sequence used by the experiment.

Start a new match for these rules. The existing strict save-policy check rejects
older paid-opening saves; it does not rewrite or refund them. Keep the previous
revision to resume those saves. U12 and assets are unchanged.

## Focused verification

Implemented from `ad53086c5f286f2c35541990b24366e7d900c8b1`. The tested working
source SHA-256 is
`7e2f5fb6612abd49b598c51fbcc2c9468651c1ddf3fbcc0862148f6645dc41bf`.
The [local evidence](evidence/U13_FREE_OPENING_LOCAL_2026-09-17.json) records the
precise scope, runtimes and replay digests.

- Linux CPython 3.12.14: all 93 rules tests and 22 opening/common-doctrine tests
  passed. Ordinary current-input fixtures now draw through round one; directed
  Guard-pair seed selectors were updated in both languages for the smaller hand.
- Godot 4.5.1 diagnostic: 16 economy checks, 164 conductor checks and 138 focused
  opening/export checks passed, with no failures or script errors. Coverage
  includes all nine Lords, optional Keep/duplicate Circles, later paid returns,
  three-round conductor replay, save/restore and atomic rejection.
- Nine native openings exactly match Python through first planning: 72 snapshots
  and 63 operations, including one active Stockpile and one inactive Stockpile
  per case. Six deliberate evidence corruptions were rejected.
- Three saved experimental games replay under the production adoption:
  `gremory_gremory_00`, `odradek_orias_00`, `kanifous_valak_00`; 43 rounds and
  1,071 explicit operations. Final states and castle metrics match the experiment
  after relabeling only the policy ID, rules hash and economy-version metadata.
  No gameplay state or event field is excluded from that comparison.

Godot 4.7.2 Windows and PyPy acceptance for this change is **pending**. Run the
bounded gate below, which enforces that exact native runtime, compares every
opening snapshot, runs the Python checks under both supplied runtimes, and
packages reports. Each stage has a three-minute watchdog and progress output.
It does not launch a full-game campaign.

```bash
bash Scripts/Sim/run_u13_opening_adoption.sh \
  "C:/Users/jerem/OneDrive/Documents/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64.exe" \
  "C:/Users/jerem/Downloads/pypy3.11-v7.3.23-win64/pypy3.11-v7.3.23-win64/pypy3.exe"
```

Historical native input/evidence files retain their tested revision. Their old
opening cards cannot be replayed as current inputs. The old comparison's three
setup tests are explicitly historical and skipped under V5; the new opening
tests and exact export cover the adopted setup. Do not relabel older full-game
acceptance as covering the new opening.

## Next doctrine work

The [810-game survey](U13_DOCTRINE_SURVEY_2026-09-17.md) already supplies concrete
targets. Keep the shared planner and nine separate Lord modules; no blanket
balance changes or another discovery sweep are needed to choose the next task.

1. **Admit Invocation into complete-plan evaluation.** It was generated 13,776
   times and selected zero times because immediate card-cost scoring discarded
   it before the planner assessed settlement. Add a bounded Rite anchor, then
   test winning, holding and adverse-settlement situations. Keep public-board
   projections uncertain where enemy orders can change the outcome; preserve
   candidate/plan/preview caps. Do not raise the global Tear weight as a shortcut.
2. **Score powers with the rest of their plan.** Projection and Consume sometimes
   choose Guards the same plan is about to destroy; Ravenous can consume its own
   newly recruited units. Account for effect timing, visible targets and friendly
   recruitment while retaining uncertainty about opposing orders. Friendly loss
   or a target-risk signal is not an automatic ban.
3. **Check Odradek's saving horizon.** Investigate whether cheap repeated powers
   prevent reaching useful Inversion/Redirect opportunities. Measure eligibility,
   affordability, selection and actual effects; do not target equal cast counts.

Validate each fix on its directed examples, then compare unchanged and candidate
doctrines under the **same adopted opening**, seeds and loadouts. Keep the
completed paid-opening survey as diagnostic history rather than a control for
new-opening win rates. Reassess early defense after these shared-competence fixes;
per-Lord weight tuning and serious balance conclusions come later.
