# Kroni: remove Hunger, retain both powers

On the same sixteen matchups, Kroni won **4/16 without Hunger**, versus
**13/16 with the current kit** and **3/16 with the entire kit
disabled**. These are paired setups with bot replanning, not forced moves.

## Exact experiment

Remove Hunger gain/loss, defense scaling, the once-per-game personal Tear,
and Ravenous eating-radius scaling. Hunger stays zero; Lord defense is fixed
at 4 and Ravenous uses base radius 220. The Threat counter and original
Hunger-based defense implementation remain, so defense stays 4 at any Threat.

Everything else remains active:

- Consume still bounces from the neutral launch, can eat either side's guard,
  and satisfies feeding on either kind of successful meal.
- Automatic feeding still consumes Kroni's lowest-value own guard if Consume
  has not fed him that round. With no guard, there is now no Hunger to lose.
- Ravenous retains movement, enemy-route preference, friendly fire, fleeing,
  timing and cooldown. Eleven enemy bodies still grant **1 Soul and 1 neutral
  Tear**, once per use. Only its Hunger payout is removed.
- Base summon value, Fracture, opponents' kits, free monsters, split Ward,
  Veil timing, Soul target and round limit are unchanged.

The bot's Consume Hunger-gain credit and no-guard Hunger-preservation credit
are removed. Avoiding an actual automatic guard meal still receives its
existing credit. The standalone-Ward Hunger penalty is removed. Ravenous
geometry uses base radius from zero Hunger; its existing uncertain reward
score remains, with the Soul/neutral-Tear reward still available. These are
necessary awareness changes, not a broad doctrine retune.

All overrides are process-local in the Python experiment runner. No playable
or Godot rules were changed or pushed.

## Results

| Measure | Current kit | No Hunger | Entire kit off |
|---|---:|---:|---:|
| Kroni wins | 13/16 | 4/16 | 3/16 |
| Mean ending round | 13.56 | 14.06 | 15.62 |
| Median ending round | 13.0 | 13.5 | 16.5 |
| Games in rounds 15–20 | 5/16 | 4/16 | 8/16 |
| Kroni wins, seat 0 / seat 1 | 5 / 8 | 2 / 2 | 0 / 3 |

No-Hunger game range: 9–22 rounds.
Victory routes across both winners: {'Ritual': 13, 'Dominion': 3}.

No-Hunger Consume meals: 77 enemy and 27
friendly. Automatic guard meals: 72. Ravenous uses:
48; reward events: 17.

Each cell lists Kroni in seat 0 / seat 1; W/L is from Kroni's viewpoint.

| Opponent | Current kit | No Hunger | Entire kit off |
|---|---|---|---|
| Deimos | W R11 / W R10 | L R11 / L R10 | L R14 / L R11 |
| Gremory | W R13 / W R13 | W R14 / L R14 | L R12 / L R12 |
| Humbaba | W R14 / W R18 | W R18 / L R22 | L R19 / L R14 |
| Kalligan | L R10 / W R11 | L R10 / L R11 | L R17 / W R18 |
| Kanifous | L R13 / W R13 | L R15 / W R9 | L R21 / W R13 |
| Odradek | L R17 / W R10 | L R17 / W R13 | L R16 / W R9 |
| Orias | W R13 / W R15 | L R12 / L R16 | L R18 / L R20 |
| Valak | W R17 / W R19 | L R11 / L R22 | L R19 / L R17 |

## Interpretation

Removing Hunger reduced Kroni's wins from 13/16 to 4/16, close to the 3/16
full-kit-off result. This supports Hunger being a major contributor to his
advantage in this fixed sample. It does not mean Consume and Ravenous have
little value: the no-Hunger arm still pays automatic guard upkeep, while the
full-kit-off arm does not, and all bots replan.

Consume removed 77 enemy guards without Hunger versus 76 with the current kit.
Ravenous earned 17 rewards versus 19. Guard removal and Soul rewards remained
substantial while wins fell sharply. This is consistent with Hunger's defense,
radius and milestone package materially changing conversion into wins, but is
not an isolated measurement of defense or the milestone Tear.

Complete Hunger removal is a useful diagnostic, not a demonstrated final
balance fix: 4/16 wins may indicate an overcorrection. Average duration was
14.06 rounds and only 4/16 reached the 15–20 target, so it did not solve the
broader pacing goal. No further rule changes were made after seeing results.

## Limits and verification

This removes the complete Hunger system, including its costs and radius
scaling, rather than isolating defense or the personal-Tear milestone alone.
The comparison can show Hunger's combined importance under these bots, but
cannot assign the effect to one benefit. Removing the entire kit also removes
automatic guard feeding, so that arm is not a simple additive measurement of
Consume/Ravenous value. Sixteen games are a diagnostic sample; reversed seats
share an opponent/seed pairing, and these seeds have been used for several
exploratory tests. Do not treat the observed win rate as a tuned balance target.

Two workers completed all 16 games. Setups, weights and recursive source hashes
match the prior current-kit and powerless controls. All saved operation and
semantic hashes passed. No Hunger-change or milestone events occurred.
Runtime assertions checked Ravenous's base radius and retained rewards.
Consume meal counts agree with independent doctrine diagnostics.

Rejected candidate previews: **0** (details retained in evidence).
All actual submissions were legal. This is a Python match experiment, not a
new native full-game parity run.

```sh
python Scripts/Sim/run_u13_no_hunger_sample.py \
  --baseline ../tempo-roster-162-03 \
  --output ../kroni-no-hunger-sample-16-reproduction
```

Evidence: `docs/evidence/U13_NO_HUNGER_SAMPLE_16_2026-09-22.json` and adjacent
`.traces.tar.gz`, containing all 16 operations, semantic results and policy traces.
