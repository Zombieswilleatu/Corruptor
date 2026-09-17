# Focused Veil, monster and doctrine check — 2026-09-17

The permanent Veil and all ten monster recipes are implemented in Godot and
already mirrored in Python. This review began at `dc0a080` and incorporated
the concurrent castle-pressure tuning at `a419014`. It changes Python
correctness and diagnostics, with no native gameplay or balance changes.

## Findings and fixes

1. **Breach Wish doctrine recording crashed.** A legal Deimos
   `BreachWishLongevity` submission had no corresponding assessment row, so
   `PlannerObserver.accepted` raised `KeyError`. The common planner now records
   all five Breach Wish terms for every Lord. Resolution events carry the base
   Wish name plus a Breach marker; the observer uses that marker to retain the
   correct selection and heavier Price attribution. Plan assembly shares the
   one-Wish limit across ordinary and Breach Wishes before spending previews.
2. **Sooge resurrection diverged from Godot.** A Python loop copying rooting
   counters reused the declaration-ID variable. It therefore created the
   wrong revived entity ID and Price ID/delay. The loop now preserves that
   identity. A native fixture verifies mobile and turret forms, ordinary and
   Breach Wishes, and two consecutive resurrections per case. The old Python
   implementation fails the first native comparison; the fix matches all eight
   complete worlds and ordered event results.
3. **One favorable-power fixture was stale after balance tuning.** The stored
   Longevity example predated the new eight-Integrity cap. The directed doctrine
   test now builds current power components, retaining the assertions that every
   power has a legal proposal in its explicitly favorable fixture. Historical
   full-game evidence and replay inputs were not relabeled or regenerated.

The experimental policy is now `U13_COMMON_SMART_CORE_ALPHA_V2_BREACH_WISHES`.
Its weights and deterministic work limits are unchanged. Shipping Godot doctrine
is unchanged by this patch.

## Verification

Repeated on top of `a419014` with the fixes:

| Check | Result |
| --- | --- |
| Python power, Marching, common doctrine and diagnostic tests | 67 passed |
| Native permanent Veil | 78 checks; zero failures/errors |
| Native monster mechanics and recipe controls | 191 checks; zero failures/errors |
| Native Sooge resurrection regression | 56 checks; zero failures/errors |
| Independent Python Veil comparison | 5 arrival and 14 effect checks match |
| Independent Python monster phase comparison | 19 phases, 3,800 ticks and 4,185 events match |
| Independent Python resurrection comparison | 8 complete results match |

The initial `dc0a080` pass also checked native Veil-wheel controls, Breach Wish
controls, Supplicant cash-in, movement and BasicDoctrine. All ten recipe
admission/continuation cases matched Python over 594 transitions, including
atomic rejections and save restoration; the native export/replay reported
4,414 checks. Those results retain their earlier revision and are not claimed
as a rerun of every test under the later castle tuning.

Tests used **Godot 4.5.1 Linux diagnostically** and local CPython. They do not
replace Windows Godot 4.7.2 / PyPy acceptance. See the exact revisions,
fingerprints, reproduced failures and artifact hashes in the
[verification record](evidence/U13_NEW_RULES_QUICK_CHECK_2026-09-17.json).

The focused Windows runner enforces Godot 4.7.2, runs the 67 Python tests and
three native suites above, compares their exact exports, and creates a report
ZIP in Downloads. Each stage has a three-minute watchdog and progress output:

```bash
bash Scripts/Sim/run_u13_new_rules_quick.sh /path/to/Godot.exe /path/to/pypy3.exe
```

It performs no complete-game campaign. Both bots currently choose a qualifying
recipe from already committed cards; deliberate recipe saving and comparative
monster strategy remain doctrine work. Keep broad tuning claims and the larger
native campaign behind a chosen rules/balance checkpoint. Continue interactive
playtests for actual usability and pacing.
