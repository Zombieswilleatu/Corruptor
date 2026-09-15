# U13 PySim — artillery, commitment and ordinary combat

**Windows Godot 4.7.2 acceptance passed at clean `e51588d`.** Independent Python
replay of the uploaded exact export reproduced the complete Windows summary,
including all 16 corruption rejections, without a diagnostic override.

Implemented at `a79f0df` after the accepted copying checkpoint, based on
documentation commit `9cdfc095fce68dd5fdd46462ccf235cf7bc9f68b`.
The copying optimization's clean `88ef438` acceptance and matched
20.31 → 7.98 ms Windows partial timing retain their original scope and identity.

## Implemented boundary

`ResolutionMatch` extends the existing independent `DevelopmentMatch` through
the first nine hooks of a fresh game. It accepts the same explicit decisions and
stops at `post_resolution_spawns`. The existing five- and six-hook adapters retain
their boundaries. No expected Godot state is loaded into the Python match.

| New hook | Mirrored behavior |
| --- | --- |
| Post-Repair / Artillery | Operational floor of 7 Integrity, player/engine order, sticky target, keyed acquisition and reacquisition, repair locks, zero-Integrity ruination, Castle Tear clock and immediate destruction reactions. An engine disabled by an earlier shot cannot fire later in the same hook. |
| Commitment Reveal | Ward Sigils and nullable Humbaba Threat; public committed cards; printed suit totals at Ward 2:1 or Hunt/Siege 3:1; stable Marcher identity, exact integer profiles, 64-attempt keyed spawn placement and next-round movement readiness. |
| Combat Resolution | Pass/Ward, Hunt, Siege, Profane and isolated Pillage resolution; matching-lane Supplicant consumption; Ward, stable pair effects, strict Guard/Sigil thresholds, Keep/Bastion interception, rewards, banishment, Fracture and breach changes. |

Immediate reactions include Gremory's Sifting/Gem Dagger with correct draw
visibility; Deimos Fear Aura and Spoils; Humbaba's breach damage; Orias pursuit,
Accelerate/Mark and Blood Conduit; Odradek's banishment resource reset; Kroni's
Ward/Pass Hunger loss; Valak's Essence gain/reinforcement; Kanifous's lost-Guard
ledger; and pair reconciliation. The original Godot hook/reaction order is
preserved, including two opposing Hunts resolving after the first Lord's
banishment. Kalligan's exposed Defunct ledger remains observed at these hooks.

This is **not full-round, full-match or complete Lord-power parity**. Active power
declarations, paid Rites, Resummon, later rounds, Post-Resolution 10A–10G,
Marching, cleanup and victory remain outside this adapter. The inherited planning
prefix only admits fresh-game legal orders; castleless Pillage and later-round
artillery are currently covered as explicitly prepared isolated components.
Supplicants in the fixtures are prepared inputs; no simulated prior Marching or
Rites reservation is claimed. No fixture edit is a production match operation.

The resolution implementation leaves the rules authority, UI, U12, legacy Python
engine and shipping doctrine unchanged. `economy.operational` counts active
economic structures; the new structure-power predicate separately applies the
7-Integrity floor. No existing predicate was redefined to make these contracts
agree artificially.

## Exact evidence contract

`resolution_inputs.json` contains only setups and explicit operations, with no
expected states or results. Both engines consume those inputs and independently
construct their opening/prefix states. The manifest has its own normalized
SHA-256 in the suite and verifier report, in addition to the existing broad
Godot/Python source fingerprint. Editing input data cannot retain the old corpus
identity merely because it is a JSON file.

The Godot exporter runs the production conductor for fresh games and production
`U13GameContent.on_hook` for the isolated components. It records rejected
operations, performs an exact transport round trip, and independently replays
all cases. Component fixture mutations are named `fixture_*` and counted
separately from rule operations. They never replace an expected result.

The Python verifier compares every field of the complete match/world and ordered
event views. It also checks input identity/order, supported hooks, rejection
rollback, physical card conservation and directed event exposure. No fields are
dropped or numbers rounded to make a comparison pass.

Focused corpus:

- 18 fresh-game traces, every Lord in both seats, through all nine hooks.
- 234 game operations, including 18 atomic wrong-cursor rejections; 252 complete
  opening/operation snapshots.
- 42 isolated components with 241 operations: 192 explicit fixture preparations
  and 49 resolution calls, including four atomic rejections.
- Directed banishment of every Lord; Guard/Sigil equality and excess; active,
  disabled and zero-Integrity structures; pair breakage before defense; private
  draw identity; both Fracture categories; Pillage retargeting; and a second-player
  spawn identity collision after the first player's reveal already did work.
- 36 Python unit tests, retaining all 27 existing tests and adding nine ownership,
  rollback, ordering, visibility and boundary regressions.
- 16 evidence corruptions, including source/input identity, clocks, missing
  operations, spatial integer/readiness fields, event order, used IDs and a
  leaked private draw ID.

The local Godot 4.5.1 gate passed 1,632 checks with no failures or script errors.
Python matched all 252 snapshots and 241 component operations; all 36 unit tests
and 16 corruption probes passed. These are diagnostic results from the
uncommitted implementation on the named base, with source fingerprint
`db43533dc6a0d52379dc535523b6f0867e38730d3a727510a8bbf1542b2ae183`.
The final [diagnostic evidence](evidence/U13_PYSIM_RESOLUTION_LOCAL.json) retains
the verifier summary, input fingerprint and output hashes. It cannot replace
the exact Windows 4.7.2 acceptance gate.

## Windows acceptance

Accepted archive:
`u13-pysim-resolution-w5oKob-2026-09-15_01-10-11-qqDWm5.zip`.

- Archive SHA-256: `d60aadf36ed9d8fbf19aa443d3dcffbeb6b43332e9c7a6e45ee15a1c19201bfa`.
- Source revision: `e51588d26fc5987aaf8098f311f24bb345f8bf83`.
- Source fingerprint: `ce878bcecfb5c27ebb13070422be80f3b65f65704ce9d3673777fc71024e465a`.
- Input fingerprint: `e31c18c755344c51fb019ddfc1466b22b764a2641e55298cb0cf3742b9aa0e53`.
- Runtime: `4.7.2.stable.official.ed1daf0bf`, Windows; Python 3.14.7.
- Empty working diff, exit status 0, ten unique archive members and valid CRCs.
- 1,632 Godot checks, 252 exact snapshots, 241 component operations, 36 Python
  unit tests and 16 corruption probes; zero failures or script errors.

The tested revision includes the parallel playable-time change after `a79f0df`.
The resolution engine, exporter, input manifest and verifier are unchanged;
additional/updated Godot test scripts account for the broad source fingerprint
change. This resolution gate does not independently accept the playtime feature.

The [acceptance record](evidence/U13_PYSIM_RESOLUTION_e51588d.json) retains the
complete verifier summary, trace identity, all game/component cases, Lord/seat
exposure, independent replay result and every archive member's size and hash.
Independent replay ran Python against the uploaded Windows reference; it does
not claim a local Godot 4.7.2 run. Full rounds and full matches remain outside
the adapter; no new throughput measurement accompanies this acceptance.

The command below is retained for reproduction. This acceptance documentation
update needs no rerun.

```bash
cd /c/Users/jerem/OneDrive/Documents/Corruptor-U13-Perf &&
git pull --ff-only origin u13-basic-doctrine &&
bash Scripts/Sim/run_u13_pysim_resolution.sh \
  'C:/Users/jerem/OneDrive/Documents/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64.exe'
```

The runner requires Python 3.10+ and Godot 4.7.2 stable, runs the unit suite,
exports/replays Godot evidence, verifies it independently in Python, and packages
one `u13-pysim-resolution-*.zip` in Downloads with source/runtime identity and
working diff. It preserves the 15-second heartbeat and stops on errors. The
Godot stage has a 420-second watchdog: the first local attempt exceeded 180
seconds during independent replay after successfully exporting the corpus.
Python stages retain 180 seconds. Allow several minutes for this fixture gate.
This export/replay duration is not a simulation throughput measurement.

## Next performance boundary

No new speed claim accompanies these hooks. The 7.98 ms Windows and 10.08 ms Linux
figures both timed opening through Development on different runtimes/hardware;
their difference does not measure the cost of adding artillery or combat.
A proposed 50 ms whole-match budget is unmeasured. Do not subtract one partial
opening from it and assign the remainder to Marching: matches contain many
rounds, growing boards, reactions and policy work.

Next, exercise a bounded Python Marching kernel before completing every spatial
Lord effect. Godot's `U13MarchingBuffer` already separates phase working state
from authoritative snapshots. Keep the same separation when evaluating parallel
arrays for Python; the boundary entity dictionaries in `recruitment.py` do not
commit the tick loop to dictionaries per Marcher. Measure layout/conversion cost
before claiming an array or vectorized implementation wins.

Contact ordering is a rule: current Godot uses immutable-ID candidate order,
earliest contact arrival and keyed `CONTACT_TIE` selection. Spatial-grid iteration
order cannot substitute for that sequence. Include registry-order permutations
and compare contacts, RNG keys/indices, tick state and ordered events so the first
divergence identifies the round/tick/field, rather than only a final digest.

Measure and preserve the first legitimate setup-to-victory reference path as soon
as it exists. No fixture mutation may bridge missing rules in a claimed complete
game. Optimize against that exact reference before trusting sweep results.
Experimental doctrines remain injected outside the rules engine; only the chosen
shipping doctrine needs Godot decision parity. Common Smart Core, Lord doctrines,
serious balance and roguelite work retain their later roadmap positions.
