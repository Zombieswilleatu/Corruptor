# U13 Python paid Development: Rites and Resummon

## Why this comes before the common planner

The [doctrine diagnostic checkpoint](U13_DOCTRINE_START_2026-09-16.md) passed on
Windows CPython and PyPy at clean `a7544d6`. The planner needs to compare complete
plans with competing costs. Paid Rites and Resummon therefore belong in the
independent rules engine before shared weights are trained against it.

This checkpoint extends existing `FullMatch`, rather than replacing the mirror
or porting a policy into authority. No Godot production rules, shipping bot,
balance, U12, UI or assets change. The theoretical finale proposal remains a
separate discussion and is not implemented here. Current Godot U13 behavior is
the parity authority, including the current Ritual/Final Collapse/Dominion
settlement order.

## Implemented scope

`paid_development.py` independently implements the rules in
`U13DominionRites.gd`, `U13Resummoning.gd` and their production wrapper order:

- Rites: five matching-lane waiting Marchers per personal Tear; once-per-game
  Invocation gated by total Veil 7 and printed card value 11; Profane Ruins with
  two own ruins and two Souls. Cross-category card and Castle conflicts reject.
- Resummon: Lord costs, Breach surcharge, one operational Circle chosen by slot,
  offering damage/repair lock, shortfall up to four Threat, and Humbaba's full
  payment requirement. Humbaba never receives a Threat attribute.
- Return quotes account for Orias marks and Blood Conduit after the offering.
  A second Circle can protect the mark gain but cannot stack a return discount.
  These marked-return component cases do not enable Orias complete games.
- Submission pays Rites, then Resummon, before Guard/Work/combat admission.
  Previews stage paid choices on a detached world. Ordinary previews retain
  their existing path. Rejected joint locks restore both seats' payments,
  entity ownership, cards, ledgers, clocks and event history. Unaffordable return
  rejections retain the complete native quote, including cost and shortfall.
- Development resolves Rites before returns, followed by the existing native
  Guard/Work ordering. Supplicants remain until Development and retain their
  retired physical IDs. A return adds its Neutral Tear and updates presence for
  Vacant Throne; victory remains an end-of-round check.

FullMatch remains limited to **Gremory, Deimos, Humbaba and Kalligan** without
declared powers. Earlier Planning/Development/Resolution adapters keep their
original boundaries. Five Lord integrations, declaration/persistent-effect
lifecycle and 23 powers still block full-roster tuning. The capability report
distinguishes implemented-but-pending paid mechanics from unsupported powers.
The original reference diagnostic observer does not yet measure paid decisions;
its reason codes identify that observer limitation separately.

## Focused corpus

`paid_inputs.json` contains input decisions and separately labeled component
preparation. No expected native states are loaded into Python. The native
exporter executes production `U13GameConductor` and repeats the complete export
independently from setup plus decisions.

- The original two games retain every input operation and final digest.
- Two added games keep ordinary setup and reach actual victory with Rites and
  returns. The input-only driver delays Rites until round 12 to expose return
  behavior before a possible Dominion finish. That fixed coverage schedule is
  not a recommendation, tuned doctrine, weight search or strength comparison.
- Eighteen directed components cover all nine Lords' return quotes/payments,
  Breach and Circle costs, marks/Conduit, both Supplicant lanes, Invocation,
  Profane Ruins, combined Rite/return/Guard/Work/Ward admission, malformed or
  conflicting choices, missing reserved targets and resolution clocks.
  There are 258 component operations, including 93 expected rejections.
  Synthetic mark records are explicitly isolated quote/resolution probes;
  they are not claims of valid complete Orias games.
- Existing eight end-of-round settlement components and a full-world 200-tick
  Marching probe remain in the exact comparison. All semantic events, both
  player views and every state field are retained. Only the already accepted
  visual tick-event omission applies to ordinary batch snapshots.

The verifier rejects 13 existing identity/input/state/event corruptions and
seven paid-component corruptions, including return Threat, the return clock,
event views and retired identity history. Four full games are a focused
integration gate, not the future roster campaign. Profane Ruins and marked
returns have directed component coverage; this is not a claim that every
mechanic occurs in these four complete games.

## Verification and acceptance boundary

Local CPython passed 77 engine tests, including ten new payment/timing/rollback
tests, and the 20 existing doctrine diagnostic tests. Local Godot is official
Linux **4.5.1**, diagnostic only. Windows **4.7.2** acceptance with both CPython
and PyPy remains pending. This checkpoint makes no new throughput claim.

The final Python candidate matched four complete native games: **57 rounds,
1,462 operations**, all states/events/views, eight terminal rejections, eight
settlement fixtures and the 200-tick probe. Both old final digests are unchanged.
The new games include five Resummons, four Invocations and six Supplicant Rites.
Profane Ruins remains a directed-component case in this corpus.

The native full-game export captured 251 component operations. Review then added
seven rejected-payment probes; a fresh native component export matched all
**258 operations / 93 rejections**, including those quote payloads. The final
candidate passed the 13 full-stream corruption checks plus seven component
corruptions. [Local evidence](evidence/U13_PYSIM_PAID_DEVELOPMENT_LOCAL_2026-09-16.json)
keeps the two native references' distinct fingerprints and hashes, as well as
the final candidate fingerprint. The Windows runner produces one fresh combined
export from its actual checkout; it does not reuse or relabel these diagnostics.

Run from the checkpoint checkout in Windows Git Bash:

```bash
bash Scripts/Sim/run_u13_pysim_paid_development.sh \
  "C:/Users/jerem/OneDrive/Documents/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64.exe" \
  "C:/Users/jerem/Downloads/pypy3.11-v7.3.23-win64/pypy3.11-v7.3.23-win64/pypy3.exe"
```

The runner checks the exact Godot version, records source/input/runtime
identities and worktree diff, runs both Python test suites, exports/replays the
native reference, verifies it independently under CPython and PyPy and compares
their entire parity summaries. It packages one ZIP in Downloads. Its native
stage has a 60-minute ceiling and progress messages; this is trace export and
verification, not a match-speed measurement. Python stages have 15-minute limits.

After Windows acceptance, continue the shared declaration/persistent-effect
machinery and missing Lord integrations. The first actual doctrine milestone
still includes general power competence for all nine Lords, a bounded common
planner and separate Lord modules; specialize and tune only after that coverage.
