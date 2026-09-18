# Kalligan: single-Castle Scorch

Approved on 2026-09-18: Inferno targets **one exposed enemy Castle instance** or **either whole Marching lane**. Lord/Guard zones are no longer legal targets. There is no Guard damage, temporary Guard value, health tracking, spillover, or automatic retargeting.

## Rules

Inferno is still declared one round ahead. Scorch lasts three active rounds at **1 → 2 → 1** intensity. Preparing a switch moves the existing Scorch next round, before its normal pulse. Its original declaration, instance ID, activation, stage, expiry and expiration-bound cooldown remain unchanged. A move into or beyond expiry is rejected. Only one Scorch can be active per caster.

A Castle pulse removes current-intensity Integrity from only the selected Castle. It bypasses Guard, Sigil and Bastion interception, as direct environmental damage. Protected construction, own Castles and non-Castle entities cannot be selected. Crossing below 7 disables Castle abilities and applies the existing repair lock; reaching 0 ruins the Castle through the existing destruction/reaction path. Normal Castle-destruction Neutral Tears retain their once-per-round cap; environmental destruction earns no Siege/Artillery Souls or attacker Spoils.

If that Castle is destroyed before activation or during the burn, subsequent pulses affect nothing there. The original Scorch remains until its normal expiry and can still be switched if enough lifetime remains. This never selects another Castle automatically. Once a declaration is locked, banishing Kalligan does not cancel the armed fire; it prevents new power declarations.

Normal Castle fire occurs at persistent advancement (Step 2), before upkeep repairs. Lane fire remains at Marching start (Step 11), hits both players' grounded Marchers including waiting Marchers, consumes Armor before HP, and excludes flying units.

Pyroclasm remains a free extra pulse at post-resolution direct powers (Step 10F), at the **current location and intensity**. It does not apply the next round's queued switch early. Casting in round N blocks round N+1 and permits another cast in N+2, while Scorch remains active. The normal pulse still occurs.

| Three active rounds, without repairs | First | Peak | Last | Total |
| --- | ---: | ---: | ---: | ---: |
| Normal fire | 1 | 2 | 1 | 4 |
| Pyro on first and last | 2 | 2 | 2 | 6 |
| Pyro only at peak | 1 | 4 | 1 | 6 |

An Inferno declared in round 1 burns in rounds 2–4, expires in round 5, becomes declarable again in round 6, and starts its next burn in round 7. Switching does not postpone this schedule.

## Board and doctrine

The powers prompt highlights individual exposed enemy Castle cards and both Marching lanes. Guard zones no longer flash or accept Inferno. The selected Castle receives its own fire, intensity/duration badge and prepared-move notice. Pyro flashes the current target. The fallback dropdown also identifies individual Castle slots. Cooldown text now says every other round.

Both native and Python bots generate individual Castle targets. The Python common doctrine values capped Castle damage, shutdowns and destruction, and adjusts optional Pyro value for its own conditional Hunt/Siege damage to that exact Castle, including Keep and Bastion absorption. Lane Pyro continues to account for its own new recruits, ground monsters, power spawns and departing Supplicants. Flying monsters are not counted as ground exposure. These are bounded public estimates; enemy orders, repairs, artillery and reactions remain uncertain. No hidden-order access, rollout, hard veto, tuning campaign or candidate-budget increase was added.

Actual pulse diagnostics now distinguish Castle Integrity damage/destruction from Marcher HP/Armor damage and kills. Extra Pyro effects are attributed separately from automatic Inferno pulses. The abandoned temporary-Guard experiment is not included.

## Verification and checkpoint scope

The focused Castle corpus independently executes seven scenarios in Godot and Python, comparing every operation result, full state and semantic event/view. Godot also independently replays the entire corpus. Explicit assertions cover both six-damage schedules, no-Pyro four-damage fire, Castle → lane → another Castle switching, expiry/readiness, illegal targets and atomic rejection, lethal/empty targets, loss before activation, unchanged Guards, and armed fire after source banishment.

Local results: **139 Python tests; five complete games, 88 rounds and 2,221 operations, zero failures; 431 native hazard/integration/board/visual assertions; 7,322 native exact checks with an independent replay; all 1,001 operations and 1,009 records match independent CPython execution.**

Implementation `74dd9e9` has the exact Git tree tested locally as `99783b9`. Merge `b4cf99c` preserves the subsequent `be392ce` sandbox counters and an additive playback timing helper; it changes no Scorch, Python engine, or doctrine source. The evidence records both identities instead of rewriting captured provenance.

Local evidence and exact source identity are recorded in `docs/evidence/U13_KALLIGAN_CASTLE_FIRE_LOCAL_2026-09-18.json`. Local Godot is **4.5.1 on Linux**, so it is diagnostic coverage, not Windows 4.7.2 acceptance. The Windows command below runs native hazard/lifetime, board and visual gates; exports/replays the focused Castle corpus; compares it independently in CPython and PyPy; then checks common-doctrine tests, five complete games, and dual-runtime report equality.

The latest parallel support/hunting and sandbox-opening fixes through `628c4fa` are included. Historical natural lane and defense fixtures retain their original operations and gameplay assertions; their current observation fingerprints were refreshed for the new Scorch ledger/profile and monster metadata, with old fingerprints retained separately. Frozen older campaign evidence remains historical. The hazard profile and rule identity changed, so prior-rule saves are not migrated into the new Castle rules.

The earlier 34-game Kalligan pulse comparison used Guard targeting and repeatable-every-round Pyro. It is not Castle-rule balance evidence. Balance and fun still need play under this checkpoint; no win-rate improvement is claimed.

From the doctrine checkout in Git Bash:

```bash
git pull --ff-only origin u13-basic-doctrine &&
bash Scripts/Sim/run_u13_common_doctrine.sh \
  "C:/Users/jerem/Downloads/pypy3.11-v7.3.23-win64/pypy3.11-v7.3.23-win64/pypy3.exe" \
  --kalligan-godot "/c/Users/jerem/OneDrive/Documents/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64.exe"
```

The runner creates a ZIP in Downloads on success or failure. Windows CPython/PyPy and Godot 4.7.2 acceptance remains pending until that ZIP is reviewed.
