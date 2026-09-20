# Kanifous V19/V20: local paired comparison

This runner performs the broader comparison requested after the four-game
Kanifous diagnostic. No campaign games were run while preparing it.

From the repository root in Windows Git Bash:

```bash
git pull --ff-only origin u13-basic-doctrine
bash Scripts/Sim/run_u13_kanifous_comparison.sh
```

It detects PyPy in PATH or its usual extracted folder under Downloads, uses
four workers, and prints progress while running **72 games**: nine opponents,
two fresh seeds per matchup, both seats, both focal policy versions. The test
has 36 old/new pairs and 18 seed blocks because both seats share each seed.

The complete V19 and V20 policy packages are frozen from published commits
`3324566936834d42a52c8ff0173f3b612a709616` and
`99ac1997b75215fdb0cfe937cf098989bcf88e49`. Opponents always use V19, including
the Kanifous mirror. Both versions run against the current checkout's same
engine, recorded by source hash. This is experimental Python behavior testing;
it does not invoke Godot or establish native parity.

The report records paired wins, results by opponent and seat, Wish effects,
friendly Death casualties, Resurrection bodies, delayed Prices, failed games,
full operation streams and focal decisions. It writes a manifest before play
and checks record and source identities. No tuning occurs between games.
The previous diagnostic seed is excluded. Behavioral counts come from
different trajectories and do not alone identify the cause of a win.

On completion the shell wrapper creates a ZIP in Downloads and prints
`UPLOAD THIS FILE`. Failed games remain in the report and produce a nonzero
exit status. The completed-game files also provide checkpoints.

Optional explicit runtime and worker count:

```bash
U13_KANIFOUS_WORKERS=6 bash Scripts/Sim/run_u13_kanifous_comparison.sh \
  "C:/Users/jerem/Downloads/pypy3.11-v7.3.23-win64/pypy3.11-v7.3.23-win64/pypy3.exe"
```

To resume missing games, pass the original report directory as the second
argument, with the same checkout and runtime. Existing failed records are
preserved rather than silently rerun. Do not change source files during a run.

The Python entry point also accepts `--prepare-only` to verify policy freezing
and create the manifest without playing any games. Preparation validation
covers all 72 paired specifications and three focused accounting tests. No
new win-rate result is claimed by this runner-only change.
