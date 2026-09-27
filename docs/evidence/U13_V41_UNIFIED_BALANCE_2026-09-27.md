# V41 unified balance baseline

Consolidates the accepted balance snapshots onto `u13-resolution-theater`, whose
published parent was `56e44c2da4d02a3129a2ad167401a110c8511ceb` (V33).
Policy: `U13_COMMON_SMART_CORE_ALPHA_V41_MULTIPLY_KALLIGAN_SURVIVAL`.

## Included behavior

- Kalligan adds survival value only against Orias. Three public Hunt-strength
  probes reward preventing banishment and Keep destruction, without forcing Ward
  or changing his kit, castle order, costs, or resummon rules.
- Odradek's Multiply costs 3, destroys one enemy guard, and creates up to three
  copies in the corresponding friendly guard zone. It resolves this round before
  Development, reserves slots for submitted hand deployments, pairs the first two
  copies, and awards no Tear. Allegiance Shift costs 4. Native simulation and the
  playable target picker now implement the accepted Python behavior.
- Retains Multiply's future-slot valuation and avoidance of the bot's attack lane.
  A future Multiply receives no saved-target credit when an already queued False
  Orders will move that guard out of the specified lane before it could fire.
  The ineffective near-ready candidate-expansion experiment is excluded.
- Redirect clears stale Wright work assignments while preserving completed work
  and repair cooldowns. Native and Python behavior agree.
- Carries forward accepted Kanifous matchup doctrine, Valak Hunt pressure,
  victory tiebreaks, and Humbaba's 25-point Muster Endurance Personal Tear model.
  The existing Deimos/rout baseline is retained.

## Balance evidence and limits

The isolated Kalligan experiment simulated 108 games with zero game failures or
rejected previews. Audited matchups improved from 2/20 to 13/20 wins; fresh
matchups improved from 7/20 to 10/20. Banishments fell from 81 to 44 and from 71
to 55 respectively. All 14 non-Orias comparison pairs produced identical
operation streams and final-state hashes. These are small matchup samples, not
proof of a 50% roster win rate. The Kalligan comparison used delayed Multiply in
both arms, so it does not measure interactions with the combined timing change.

The separate same-round Multiply comparison returned 8/32 wins in each arm,
with one gained and one lost win. Its timing is an accepted behavior change,
not a demonstrated overall win-rate increase. No new full-roster test has been
run on this consolidated source.

## Integration validation

- 67 focused Python tests passed across Odradek, Multiply, Redirect/Wright,
  Kalligan/Orias, Kanifous defense, Valak pressure, Endurance, and victory.
- 280 exact native/Python comparisons passed across 19 cases: four guard suits,
  zero through three reserved hand slots, both Wright build states, and a moved
  Multiply target. Full results, snapshots, events, and reloads are compared.
- Native Odradek, Odradek powers, doctrine coverage, Wish doctrine, Humbaba,
  victory, and focused playable Multiply targeting runners passed.
- Native integration ran on Godot 4.6 stable Linux. The user's Windows 4.7.2
  executable was not available here. No new full playable audiovisual smoke test
  is claimed.
- Two older defensive replay fixture subcases were already failing in both arms
  of the isolated Kalligan experiment, before the changed scoring executes.

Reproduce exact cross-engine cases without committing the large generated file:

```bash
python Scripts/Sim/generate_u13_multiply_parity.py /tmp/u13-multiply-parity.json
godot --headless --path . --script res://Scripts/Sim/U13MultiplyParityTestRunner.gd -- /tmp/u13-multiply-parity.json
```

## Next broad run

```bash
bash Scripts/Sim/run_u13_overnight.sh
```

Defaults: 810 games, three workers, worker recycling every six games, namespace
`u13-unified-v41-overnight-2026-09-27`. Output is
`~/Downloads/Corruptor/Balance/u13-unified-v41-overnight`.
The runner freezes and hashes its simulation source; repeat the command to resume.
Use `--prepare-only` to freeze and inspect the configuration without playing games.
