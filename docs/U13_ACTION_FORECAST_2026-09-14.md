# U13 public Guards and Action Forecast — first pass

**2026-09-15 acceptance/integration:** The user confirmed “the action forecast
is working” at remote dd9638c. The completed 100-game campaign belongs to its
357d793 parent, not this change. Forecast/public Guards are now integrated into
`u13-basic-doctrine` alongside the 5c1fa48 sprite gallery work. See
[accepted checkpoint](U13_ACCEPTED_CHECKPOINT_2026-09-15.md) for exact evidence
and runtime distinctions. The branch-isolation instructions below describe the
earlier in-progress campaign.

User steering: continue forecast work while the 357d793 full-game batch runs.
Develop on u13-action-forecast; do not update the running checkout or fold new
bot behavior into that campaign's results. Deployed Guards are public. Hands
and simultaneous submissions remain private.

## Information policy

The board already projected enemy Guard faces. The doctrine facade previously
replaced them with anonymous handles and a value-3 prior. Both now receive the
same public cards. Active bonds are also public; broken bonds are not inferred
from a surviving same-suit card. Enemy bond badges use the enemy board zone.
Pair-formation events are public after Development, not during submission.
Doctrine V8 uses actual Guard values, including for Consume and Projection,
and includes known Penitent pair screens. The full-game Random-Legal policy
already read the unmasked public projection. No hand/deck/queued-order reveal
is introduced. Existing saves remain loadable.

## Shared service

Scripts/Sim/U13ActionForecast.gd accepts a public player view and the player's
proposed order. It neither receives nor clones an authoritative match, reads
an enemy hand, predicts RNG, executes a power, nor changes game state. Strength,
Guard values, pair screens and support use the same DoctrineView calculations
available to common doctrine. Lord defense and pursuit use U13LordStats;
Castle targetability and operational status use U13Structures.

The Combat modal displays the resulting structured analysis as a current-board
baseline. It covers:

- printed-suit recruitment (Ward 2:1, attacks 3:1), effective card strength;
- same-lane Supplicants, consumption and exclusion of those reserved for rites;
- Orias pursuit, public Guard values, strict Guard defeat/equality, Penitent
  pair screens, Sigils, Keep reduction/interception and Bastion interception;
- remaining Castle damage/ruination or Lord survival/banishment;
- Pillage success and the newly-active-Castle retarget rule;
- Ward protection in both lanes and Profane's conditional Tear exchange.

These are NOT success percentages or promises. The assumptions are always
shown: the opponent's new Guards/Ward/Work, pre-combat artillery and Lord power
reactions can change the baseline. The first pass does not simulate full
submission timing, probabilistic opponent choices, scheduled powers, spatial
Lord effects or the reactions triggered by Guard losses. Work already has its
separate projected-Integrity readout. Future forecast refinements should model
those dependencies explicitly rather than convert the baseline to fake odds.

## Verification

Local Godot 4.5.1 diagnostics pass for public Guard policy, forecast-versus-combat
comparisons through Guard/Sigil/interception breakpoints, Ward recruitment,
Pillage support, privacy, deterministic/read-only evaluation, bond visibility,
Guard Work replay, doctrine/coverage and board interactions. These are not a
replacement for Windows Godot 4.7.2 acceptance.

Focused Windows gate:

    bash Scripts/Sim/run_u13_action_forecast.sh /path/to/Godot_4.7.2_executable

Use a separate worktree while the full batch is running. Do not merge or switch
the batch's checkout during the campaign.
