# Corruptor Experimental Balance Lab

This directory is a disposable, Godot-native balance sandbox. Canonical scripts
do not import it. Deleting `Experiments/BalanceLab` removes the lab without
changing the game, golden suite, parity soak, or canonical balance runner.

## General balance run

Open `ExperimentalBalanceRunner.tscn` and run the current scene.

The inspector exposes real experimental axes:

- **Testbed**
  - `Vanilla mirror` runs the synthetic s6/d5/r1 Lord with zero abilities and
    the neutral AI profile.
  - `Canonical roster` uses the selected production Lords.
- **FIX A doctrine** changes the actual Commitment action scores:
  Hunt/Siege/Ward bases become 0.333 and Ward's Soul/Castle/Threat
  accumulators become 0.12/0.08/0.20.
- **FIX B Profane** removes the actual Fresh-Sigil denial branch.
- **Custom softmax** supplies temperature and error rate to the production
  `BotSelector`.
- **Forced action seats** constrain each seat's legal Commitment candidates to
  Hunt, Siege, Ward, or Profane. If the requested action is temporarily
  illegal, the doctrine retains a legal fallback so the simulation does not
  manufacture invalid rounds.
- Softmax Profane targets are rechecked at the exact action boundary. If an
  earlier simultaneous Siege removed the selected castle, the bot retargets
  another active castle and the report increments `target_reevaluations`.
- **Temporary Rule Overrides** still support ordinary `RuleConfig` experiments.

Reports are written under:

`user://balance_reports/experiments`

The text and JSON reports identify every enabled axis. Experimental games also
record per-resolution action outcomes, including attack success, block counts,
failure gap, stop layer, and overcommit excess.

When no isolated feature is enabled (`Canonical roster`, FIX A/B off, both
seats on Doctrine), the runner delegates to the canonical `_play_game` method.
That is the control path.

## Pure-vs-pure matrix

Open `ExperimentalPureStrategyMatrixRunner.tscn` and run the current scene.

It automatically executes all 16 ordered Vanilla cells:

`Hunt / Siege / Ward / Profane` vs
`Hunt / Siege / Ward / Profane`

The output includes the seat-zero win-rate matrix, average rounds, win
conditions, and actual action counts for every cell. FIX A, FIX B, temperature,
games per cell, seed, and maximum rounds are inspector settings.

## Isolation model

`Runtime/` is an experimental copy of only the static-preload chain that must
change to make these features real. It owns:

- experimental setup and Lord content;
- doctrine and bot orchestration;
- Hunt, Siege, Profane, and Reflex resolution;
- attack diagnostic fields.

It continues to reuse canonical data types and unchanged engines. Nothing under
`Scripts/Sim` imports `Experiments/BalanceLab`.

The runtime copy should be refreshed deliberately after canonical simulation
changes. Treat a refresh as code review: preserve the explicit Vanilla, FIX A,
FIX B, forced-action, and diagnostic patches rather than blindly overwriting
the directory.
