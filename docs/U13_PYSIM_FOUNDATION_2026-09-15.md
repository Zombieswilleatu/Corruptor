# U13 PySim foundation — exact opening parity and portable traces

Status: implemented; local diagnostics green. Windows Godot 4.7.2 acceptance
is pending the focused command below. This builds the first slice defined in
[the parity inventory](U13_PYSIM_PARITY_2026-09-15.md).

## Implemented scope

`Scripts/Sim/u13_pysim/` is an independent Python namespace. It does not import
the legacy simulator, parse GDScript to obtain expected states, or copy a Godot
snapshot into the Python result. It implements:

- U13 keyed SHA-256 rejection RNG, with the existing Unicode, rejection-retry,
  single-choice and full unsigned-range reference cases;
- stable entity creation/update/retirement, the used-ID ledger and atomic
  restore, including duplicate faces and owner/slot changes;
- all nine Lords' initial fields, physical Castle loadouts and protected
  blueprints, three active starting Castles, 72 physical deck identities with
  three trimmed cards per suit, keyed shuffles, Slaver stock, draws and opening
  summon payments;
- first eligible Summoning Circle offering, stable hand-order tie-breaking for
  lowest-value payments, exhausted-hand shortfall without first-summon Threat
  or Tears, all resources and inert effect/Work/pair state;
- the complete initial match snapshot: both world copies, registry history,
  sealed-order slots, runtime cursor, empty queues, cooldowns and event log.

The roster rules hash and policy identity are pinned to the accepted Godot
contract. Pinning them does not mean Python implements later Lord powers.
Python round resolution, combat, Work settlement and spatial Marching remain
the next slices. No existing gameplay authority, UI, U12 file, legacy Python
module or golden trace is modified.

## Portable exact transport

`U13ExactData.gd` and `u13_pysim/codec.py` implement `U13_EXACT_DATA_V1` for
tooling. It is separate from the live game's Variant-based save envelope.

Every value is tagged: null, bool, integer, float, string, ordered array or
dictionary. Integers use canonical decimal strings. Finite binary64 floats use
their exact eight little-endian bytes as hex, including negative zero and
subnormal values. Dictionaries sort string keys; arrays preserve their order.
Tags cannot collide with user/game dictionary fields. Unknown tags, malformed
nodes, duplicate/unsorted dictionary entries and invalid ranges reject.

Comparison reports the first differing path and distinguishes missing/extra
fields, bool/int/float types and floating-point bits. There are no rounding
tolerances or unordered Guard/card comparisons.

One inventory correction: **RNG framing counts UTF-8 bytes; entity/effect ID
framing counts Unicode characters**, matching Godot `String.length()`. Python
preserves that distinction. GDScript can fold a negative-zero literal, so the
transport probe constructs that particular test value from explicit bits.

## Explicit Godot trace capture and replay

`U13ParityTrace.gd` records setup, Stockpile keep choices, Slaver swaps/passes,
complete submissions, individual authoritative hooks and next-round operations.
Inputs enter the existing conductor. It does not insert a new gameplay path or
call a bot to reconstruct missing choices during replay.

Each record retains the operation, its result, prior cursor, complete resulting
snapshot (including events), and current outcome. A future terminal record can
therefore carry the actual winner; this two-round fixture has no terminal win.
The focused fixture captures **49 operations across two rounds**, including all
20 hooks each round, two Stockpile choices, four Slaver choices, two submissions
and one next-round transition. Its submissions are empty/pass plans; full
powered/committed input coverage belongs to subsequent slices.

Replay starts a fresh Godot match and checks every resulting record against
the decoded export. Wrong provenance, changed phase state and out-of-order
operations reject. These later-phase comparisons are **Godot-to-Godot**, not
Python resolution parity. Python validates and retains their structure and
coverage while independently reproducing their opening.

Trace identity includes source revision and SHA-256 source fingerprint, actual
runtime/platform, schema, engine/policy/rules identities, RNG, event profile and
producer. Source fingerprinting covers simulation GDScript and the new Python
tools, with CRLF normalized to LF; it includes uncommitted source content. The
verifier recomputes it, so stale or changed-source exports fail. The working diff
is also packaged. `U13_BATCH_EVENTS_V1` omits only its two declared visual sample
types (`MARCHING_TICK`, `KRONI_ACTOR_TICK`); retained state/events are not pruned
by this exporter. Traces contain authoritative private data and remain test
artifacts, not player-facing views.

## Focused validation

Local Godot **4.5.1 Linux** diagnostics:

- 51 Godot checks, zero failures/script errors; about 23 seconds in this
  environment for generation, exact round trip and replay.
- 14 independently reproduced complete opening snapshots: 12 varied
  Lord/loadout cases, one exhausted-hand shortfall and the explicit-choice
  trace's opening. Every Lord appears in both seats; cases include active,
  unbuilt and duplicate Summoning Circles and duplicate Castle types.
- 19 Python comparison groups, zero failures; six Python unit tests also pass.
- Ten deliberate evidence corruptions reject: wrong revision/source, missing
  case, altered RNG, missing/extra state, forged ID, altered Castle slot,
  changed deck order and removed operation.
- Local 4.5.1 output is rejected by the acceptance verifier when diagnostic
  mode is not explicitly requested. Bash syntax passes.

The 23-second timing is diagnostic, not a Windows performance guarantee.
Each Windows runner stage has a 180-second watchdog and checks process exit,
engine errors and explicit completion footers (including CRLF output).

## Windows acceptance

Requires Git Bash, Godot **4.7.2 stable on Windows**, and **Python 3.10+**.
No pip packages are required. The wrapper discovers `python3`, `python` or `py`,
or accepts an explicit Python executable as its second argument.

```bash
cd "/c/Users/jerem/OneDrive/Documents/Corruptor-U13-Perf" &&
git pull --ff-only origin u13-basic-doctrine &&
bash Scripts/Sim/run_u13_pysim_foundation.sh \
  "/c/Users/jerem/OneDrive/Documents/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64.exe"
```

Success ends with `U13 PySim foundation passed: exact opening parity and Godot
trace replay.` The existing report packager produces one ZIP in Downloads,
containing the exact export, version/provenance, test logs and Python summary.
This is a short fixture gate, not another full-match campaign.

## Next slice

After Windows acceptance, mirror the timeline/submission and opening-round
economy transitions against these explicit inputs. Extend through Guard
deployment/Work/pairs, ordinary combat, then Marching and Lord effects in the
existing roadmap order. Expand deterministic reference games only after the
component boundaries agree. Common Smart Core/Lord doctrines and balance remain
later milestones.
