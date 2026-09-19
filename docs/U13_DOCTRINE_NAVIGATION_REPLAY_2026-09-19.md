# Doctrine replay integration after navigation recovery

**2026-09-19 · V12 unchanged · local CPython passed**

The parallel update `176e175` changes shared Marching navigation. This pass
integrates the doctrine replay expectations with that engine, preserving its
implementation. Its protected staging remains a lane-sandbox experiment;
full-game recruitment and submission keep their existing deployment rules.

The [Rout timing experiment](U13_ROUT_TIMING_2026-09-19.md) is preserved at
`2099326`, with the exact tested tree. Its 36 continuations precede navigation
recovery and were not rerun on this engine. These compatibility checks do not
extend its behavioral or strength conclusions to the newer rules.

## Reviewed replay changes

All **13 saved cases** retain their original input prefixes and opposing orders.
All remain legal. **Nine observations change; one selected plan changes.**
The [comparison evidence](evidence/U13_DOCTRINE_NAVIGATION_REPLAY_2026-09-19.json)
records both sets of fingerprints and actual outcomes.

The sole plan change is Humbaba/Valak round six: the same Ward cards, guard
moves, castle action, monster and Lord-lane Breath now recruit in Lord instead
of Castle. Breath therefore supports six planned ordinary recruits as well as
the existing column. The previous existing-unit-only case interpretation at
`2099326` remains in its history; the current regression again requires positive
planned-recruit support. The added fresh Castle-lane example also remains valid
with ten planned recruits, so that coverage is retained.

Both artillery examples still turn a fizzled Siege into damage: **10 and 12**.
Both defensive examples still preserve the Keep where the recorded original
choice loses it. Breath's actual heal remains one in the wounded-recipient
case and zero in the recruit cases. Kalligan's first recorded bad pulse still
hits 13 friendly and seven enemy bodies; the revised decisions still omit it.
No tactical assertion was weakened to accommodate a changed board hash.

## Gate and source scope

Local **CPython 3.12.14 passed 168 tests and five complete games**, totaling
**94 rounds / 2,367 operations**, with no failures or rejected previews.
Every recorded input stream matches its report digest. The unchanged V12 policy,
weights, greedy selection and 32-plan/eight-preview limits are preserved.

Engine SHA-256: `2badf329e59610a69f92227c0dc85a7366b59d24776ae375c4f339503ac55710`.
Report semantic SHA-256: `5e1d138fde20d8aee8d94915eb56d0fbcdd80202dec3dbb0378ba6b0461be4f3`.
The report's local source alias `81891ef` is the merge before
reviewed expectation updates; the recorded harness hash pins those tested files.

This is not a new native-parity or Windows/PyPy acceptance. The existing Windows
acceptance at `77ff661` stays scoped to that earlier revision. To check the
combined revision on Windows, use the existing common-doctrine runner. The
older gate does not accept the new navigation rules.

Archive: `Corruptor-Doctrine-Navigation-Integration-2026-09-19.zip` (363589 bytes).
SHA-256: `e35d92fde82efca8b413fa359901bf42b6a80f8b65248a052c834dcbf8633236`.
The archive contains full before/after observations, decisions, tactical outcomes
and the current gate's complete reports, input streams and logs.
