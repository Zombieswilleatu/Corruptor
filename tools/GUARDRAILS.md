# Corruptor Guardrails

These tools exist because behavior changes can legitimately invalidate deterministic
goldens, but the *process* of approving those changes should not become another
source of bugs.

## Daily precommit check

Run:

```bash
py tools/verify.py
```

It checks:

- repository policy-ID parity across Python, Godot, manifest, traces, and matrix;
- the canonical `bastion_wall` compatibility boundary;
- golden file self-consistency (recorded trace hashes vs snapshots and manifest);
- curated golden provenance;
- temporary exporter/candidate/backup debris outside `.corruptor_backups`;
- the Python unittest suite;
- `git diff --check`;
- `git diff --cached --check`.

If engine/golden-sensitive files changed, the tool deliberately refuses to call
the job fully complete without fresh Godot evidence. After F2, save/copy the Godot
output to a text file and run:

```bash
py tools/verify.py --godot-log path/to/godot_output.txt
```

The log must contain a final `Golden checks complete: N passed, 0 failed.` line and
must be newer than the changed engine/golden files.

`--quick` skips the Python unittest suite and is useful while iterating.

## AI policy version bumps

Never hand-edit policy IDs across six GDScript files plus every golden JSON again.

Dry run:

```bash
py tools/bump_policy_id.py softmax-YYYY.MM-description
```

Apply after reviewing the file list:

```bash
py tools/bump_policy_id.py softmax-YYYY.MM-description --apply
```

The tool backs up every touched canonical file under `.corruptor_backups/` and
replaces bytes rather than rewriting text, so CRLF/LF line endings elsewhere are
not churned.

A policy-ID bump is metadata/versioning only. If behavior changed, it does *not*
authorize new snapshots. Use the selective rebaseline workflow below.

## Selective golden rebaseline

`golden/lord_matrix.json` is a curated mixed-provenance oracle. Do **not** replace
all 81 rows from one current simulator merely because a policy/rule change caused
drift.

The installer is dry-run by default. Candidate generation remains separate from
candidate installation so the approval boundary is explicit.

Discovery pass:

```bash
py tools/rebaseline_goldens.py \
  --matrix-candidate golden/lord_matrix_godot_candidate.json \
  --trace game_deimos_valak_s1=golden/game_deimos_valak_s1_godot_candidate.json
```

It prints the exact matrix rows that differ. Review those names and put them in a
text file, one per line, e.g. `approved_rows.txt`.

Then rerun:

```bash
py tools/rebaseline_goldens.py \
  --matrix-candidate golden/lord_matrix_godot_candidate.json \
  --trace game_deimos_valak_s1=golden/game_deimos_valak_s1_godot_candidate.json \
  --expect-file approved_rows.txt \
  --authority godot \
  --apply
```

The apply step refuses unless:

- matrix scenario membership/order is unchanged;
- the changed row set is *exactly* the approved set;
- matrix metadata is unchanged unless explicitly allowed;
- `game:deal` and `round:01:end` remain unchanged by default;
- replacement full traces preserve those same early checkpoints by default;
- candidate `trace_hash` values actually match their snapshots;
- candidate `ai_version` equals the currently pinned policy;
- post-install repository guardrails pass.

Before writing, it creates a timestamped backup. On post-install validation
failure it restores the backup automatically. Successful in-repo `*_candidate.json`
files are cleaned up automatically.

Use `--allow-round1-change` only when the intended mechanic really does alter the
deal or first round. Use `--allow-metadata KEY` only for a metadata change you can
name and explain.

## Provenance

`golden/_provenance.json` records the important ownership rule:

- the Lord matrix is `mixed-curated`;
- its replacement policy is `selective-only`;
- selective install events append authority, changed rows, replaced traces, and
  preserved checkpoints.

This is intentionally a sidecar rather than part of the golden trace schema, so
it cannot perturb cross-language snapshot hashing.

## Recommended behavior-change workflow

1. Make the rule/doctrine change with focused Python + Godot unit tests.
2. If bot behavior changed, dry-run and apply `bump_policy_id.py`.
3. Run `py tools/verify.py`.
4. Run Godot F2 and inspect the first real divergence.
5. Generate *candidates*, never overwrite the oracle directly.
6. Dry-run `rebaseline_goldens.py` to discover the exact changed set.
7. Approve that set explicitly and rerun with `--apply`.
8. Run Python tests and Godot F2 again.
9. Run `py tools/verify.py --godot-log ...`.
10. Only then stage/commit.

The goal is not to prevent legitimate golden changes. It is to make every golden
change deliberate, attributable, reversible, and narrow.
