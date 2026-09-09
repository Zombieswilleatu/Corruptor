# Orias: Mark, resummoning, and playable board

Orias is now selectable in `Prototype/U13/U13Board.tscn` and the same roster supplies Quickstart. Matches containing Orias use the Orias rules owner, including Guard deployment and resummoning for both players. Existing four-Lord fixtures and U12 remain separate.

## Board interaction

- Place Web opens two labeled lanes. Move the pointer to reposition the draft, then press **Set the Snare** to queue the selected Web position. Cancel or Escape queues nothing. Confirmation stages the declaration; the normal round submission still resolves it.
- Prepare Snare stages the existing next-round restriction and gains 1 Threat at joint lock. Guard webs remain centered on each zone's middle Guard card and contain no extra spiders.
- Place Guard accepts an empty numbered slot, then one hand card. Both Guard zones share the public Snare/Entanglement limit. Cards are reserved in the draft and can be returned before the powers step.
- Resummon Lord appears while banished. Select payment cards and review cost, payment, return Threat, and The Mark. Development returns the same Lord. An absent Lord cannot submit combat or new powers in its return round; those are available at the following submission.
- The active Web appears on the board's Marching lanes using the same fixed-point coordinate mapping as the moving cards. The existing animated spider follows its direction of movement.

## The Mark

An attributed Orias Hunt that banishes an enemy Lord at Threat 3 or greater grants **2 additional Souls and 1 additional Neutral Tear**. With normal banishment rewards, that is 4 Souls and 2 Neutral Tears total. The event captures Threat before banishment resets it.

The victim retains The Mark across resummoning and receives +1 return Threat, capped at 4. Repeated delivery of the same banishment fact does not award another bonus. A later qualifying banishment is a new reward event. No Recoil/Backwash clause is restored. Humbaba's absent Threat remains absent and never satisfies a numerical threshold. Orias uses its established base Defense of 6.

## Resummoning adapter

This U13 slice keeps the existing raw-card-value payment vocabulary: Orias 6, Deimos 7, Gremory 6, Humbaba 6, Kalligan 4; add 3 when that Lord is in the Breach. One operational Summoning Circle with at least 3 Integrity automatically supplies the existing blood offering: spend 3 Integrity for a 3-point cost reduction. Duplicate Circles do not stack; stable slot order selects one.

Unpaid cost becomes return Threat, up to 4. The Mark adds one after calculating shortfall, still capped at 4. Humbaba must cover the full cost with cards because it has no Threat stat. Cards cannot simultaneously pay for a summon, Guard deployment, construction/repair, or a Lord power.

Payment is sealed/discarded at joint lock. The Lord returns at the beginning of Development, before the other Development actions, with the same entity ID. The accepted U13 resummon addendum creates 1 Neutral Tear per return. There is no extra enforced absent round beyond waiting for the next submission after banishment. This adapter does not introduce mid-match Lord switching.

Mark identity, payment records, return counts, phase boundaries, public quotes, and replay restoration are validated. Random-legal candidates can select a legal resummon payment.

## Verification

The aggregate launcher now contains **82 suites**, adding the previously standalone Pursuit suite plus Mark, resummoning, and Orias board integration. The focused `--orias` group contains those four suites; the older `--snare` and `--orias-web` groups remain available.

```bash
bash Scripts/Sim/run_u13_foundation_tests.sh "$godot_u13_exe" --orias
bash Scripts/Sim/run_u13_foundation_tests.sh "$godot_u13_exe"
```

Both commands retain the pinned Godot 4.7.2 stable check. The board tests exercise cancel/confirm isolation, both-lane spatial selection, Guard card reservations, actual worker resolution, persistent Web display, the next-round Snare cap, and card-funded return controls. Rules tests cover reward thresholds, deterministic replay, malformed restoration, double spending, marked returns, Circle blood offering, and absent Threat.
