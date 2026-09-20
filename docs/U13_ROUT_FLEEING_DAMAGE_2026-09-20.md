# Rout: vulnerable during retreat

The user stopped the old/new/none doctrine comparison and authorized a rules
change: enemies affected by Rout take **+1 damage from regular attacks during
the retreat round only**. The next round's half-speed advance takes normal damage.

Ordinary melee and ranged hits include monsters' basic attacks and Tower shots.
The bonus applies to positive hits before Armor and respects armor bypass.
Blocks and evasion prevent the complete hit; zero-damage attacks remain zero.
Powers, hazards, poison and monster special packets receive no Rout bonus.
Dotra exposure remains independent: a regular hit during both effects gains
one point from each. A routed body stopped at its home boundary still has the
retreat status until the round ends.

Both the native game and Python simulator use the same attack-only boundary.
Rout's rule metadata records the new bonus, changing the native rules hash so
older saves cannot silently continue under different damage rules. The existing
membership, retreat/recovery stages, cooldown and snapshot fields are unchanged.
The in-game power description now explains the vulnerable retreat window.
Production doctrine remains V12, with no Deimos-specific Castle loadout tuning.

## Focused verification

- Godot **4.5.1**: 90 damage checks across 38 packet cases; zero failures.
- All 38 complete native worlds and event streams match independently replayed
  CPython **3.12.14** and PyPy **7.3.20 / Python 3.11.13** results exactly.
- Both Python runtimes pass three focused regression methods covering timing,
  exposure interaction and the compact-column legacy melee path.
- The existing Rout lifecycle runner passes 188 checks, including movement,
  membership, cooldown and save/restore. Its old four-body expectation was
  corrected to the current one existing body plus two Predator recruits.
- `git diff --check` passes. No balance matches were run for this rules change.

These are local correctness results. Godot 4.7.2 / Windows acceptance and a
strength conclusion for the new mechanic have not been established.

Reproduce from the repository root:

```sh
godot --headless --path . --script Scripts/Sim/U13RoutDamageTestRunner.gd -- /tmp/rout-packets.jsonl
PYTHONPATH=Scripts/Sim python -m u13_pysim.verify_exposure /tmp/rout-packets.jsonl
PYTHONPATH=Scripts/Sim python -m unittest u13_pysim.test_rout_damage -v
godot --headless --path . --script Scripts/Sim/U13RoutTestRunner.gd
```

## Stopped doctrine comparison

The planned 162-game old/new/none comparison ended at the user's request with
66 complete game records. It has no final aggregate strength conclusion and
does not measure this new damage rule. Partial records are preserved separately.
Its source is archived on `u13-rout-threeway-stopped-20260920` at
`30800d26322dc22c9f338fd5e5c7da0f095def08` (the same tree as locally tested
`2ba4de5b30cf5c0884dd88d51b24957cf13bb0e1`). The experimental doctrine hooks
were not added to the production branch.
