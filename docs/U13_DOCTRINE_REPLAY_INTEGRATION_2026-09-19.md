# U13 doctrine replay integration after Wright/Tumler changes

The uploaded Windows run at clean `8591fae` stopped after 148 CPython tests
with five failing observation fingerprints. PyPy and the complete games did
not run, so this upload does not accept the Deimos V10 checkpoint.

Commit `8591fae` added Marching Wright repair/release state and changed Tumler
cluster pursuit after the original Deimos verification at `349b7cf`. The saved
doctrine observations still described the earlier engine. Doctrine code and
weights had not changed between those revisions.

## Reviewed replay changes

All six original prefixes were independently replayed on both engine revisions.
The earlier engine reproduces every previous fingerprint. The current engine
reproduces all five mismatches in the Windows log. Setups, operation prefixes
and recorded opposing plans are identical; all six selected V10 plans are also
identical across the engines.

| Saved case | Observation differences on the current engine |
| --- | --- |
| Kroni–Odradek defense | Monster rules version only |
| Kroni–Valak defense | Monster rules version and two Wright state fields |
| Deimos–Humbaba artillery | 132 differences, including Marching positions, survivors, HP/armor, timers and Veil history |
| Deimos mirror artillery | 143 differences, including Marching positions, survivors, HP/armor and timers |
| Kalligan–Gremory pulse | Monster rules version and four Wright state fields |
| Kalligan–Deimos pulse | Monster rules version only |

The longer Deimos prefixes have real gameplay-state differences. Updating their
fingerprints required rechecking the tactical outcomes on the current engine.
Those assertions remain unchanged and pass:

- Both defense plans preserve an active Keep that the recorded original plan
  loses, while retaining a monster summon.
- Both Deimos replacements preserve the combat cards and recipe, retarget a
  surviving Castle and deal damage; the original Siege still fizzles after its
  target falls to artillery.
- Kalligan still omits the harmful Pyroclasm while retaining Ward/Kopita, and
  keeps the useful pulse with reduced friendly exposure.

The correction refreshes six observation fingerprints, retains their earlier
values with engine provenance, and adds the missing fingerprint assertion to
the useful-pulse case. It changes no gameplay rules, policy scores or tactical
outcome assertions. Recorded enemy plans remain confined to retrospective
resolution after the policy has chosen.

## Local verification and pending acceptance

Local CPython 3.12.14 passed **148 tests** and **five complete games / 88 rounds /
2,222 operations**, with zero failures or rejected previews. Tested local
revision `6617319` and published implementation `7738dc7` have identical Git
tree `2a4478d70590cfdd314099f1b33a82ce3a607ab0`.

The complete games run on the new Wright/Tumler engine; their changed outcomes
are separate from the six unchanged selected replay plans. The old five-game
report is not an expected result for this new engine.

Source fingerprints, failed-upload identity, replay hashes and game results are
recorded in [integration evidence](evidence/U13_DOCTRINE_REPLAY_INTEGRATION_2026-09-19.json).
The accompanying `Corruptor-Doctrine-Replay-Integration-2026-09-19.zip` preserves
the full local report and inputs, both sets of public replay observations,
reviewed differences and the original Windows failure logs.

Windows CPython/PyPy acceptance remains pending. This fixture correction adds
no native parity, balance or strength claim. Native acceptance of the parallel
[Wright/Tumler changes](U13_WRIGHT_REPAIR_2026-09-18.md) remains a separate gate.

Run from the doctrine checkout in Git Bash:

```bash
git pull --ff-only origin u13-basic-doctrine &&
bash Scripts/Sim/run_u13_common_doctrine.sh \
  "C:/Users/jerem/Downloads/pypy3.11-v7.3.23-win64/pypy3.11-v7.3.23-win64/pypy3.exe"
```

Upload the new ZIP from Downloads. Once this gate passes, the next tactical
review remains useful Rout displacement and Humbaba's Breath/Muster benefit.
