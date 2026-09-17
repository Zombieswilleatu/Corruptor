# Veil wheel and decision timing

The playable U13 banner now exposes seven positions on a curved Veil wheel.
Scroll, drag, or use its arrows to look ahead and behind. Click a number to
inspect it; click the current **VEIL** readout to return to the live position.
With the wheel focused, Left/Right turn it, Home/End reach its limits, and
Enter/Space return to now. Browsing is presentation state and never changes
the match. Ordinary board refreshes preserve browsing; returning to now resumes
following Veil changes. The existing banner height is retained.

## Thresholds and stamps

| Veil | Marker | Status / stamp requirement |
| --- | --- | --- |
| 5 | Breach I | Planned; first Personal Tear |
| 7 | Invocation | Current rule; value 11, once per game |
| 9 | Breach II | Planned; second Personal Tear |
| 12 | Dominion | Current rule; five Personal Tears and a strict lead |
| 13 | Breach III | Planned; third Personal Tear |
| 17 | Breach IV | Planned; fourth Personal Tear |
| 21 | Cascade | Planned; also requires round 21; no protection |
| 26 | Final Collapse | Current round-end victory rule |

Blue **Y** seals represent you; red **O** seals represent the opponent. Both
use the public Personal Tear counts already shown in the corner panels.
One through four Tears stamp the corresponding arrival thresholds; the fifth
stamps Dominion eligibility. Further Tears do not create additional protection
tiers. Hollow seals show an unearned stamp.

The planned Breach markers have an asterisk and explicitly say **planned** in
their descriptions. Their positions and protection ladder follow
`FutureFeatures/Corruptor-Veil-Permanent-Breaches-Proposal-v0.2.md`.
This UI change does not activate permanent Breaches or their protection.
The wheel receives no hidden Lord sequence and reveals no future identities.

## Readable save telemetry, version 2

`playtime` stays beside the encoded authoritative payload. Existing top-level
`decision_ms`, `resolution_ms`, `total_ms`, and `history_complete` remain.
The new `rounds` array is ordered by round number:

```json
{
  "round": 3,
  "decision_ms": 50000,
  "resolution_ms": 6000,
  "total_ms": 56000,
  "decision_surfaces_ms": {
    "slaver": 8000,
    "work_target": 22000,
    "guards": 7000,
    "combat_commitment": 9000,
    "lord_powers": 1000,
    "dominion_rites": 1000,
    "aftermath": 2000
  }
}
```

This is an illustrative example, not a measurement from a saved match.
Other surface keys are `stockpile`, `resummon`, `history`, `board_review`, and
`game_menu`; `other` is the fallback for an unattributed surface. Absent keys
mean no recorded time on that surface. Revisiting a step accumulates in the
same bucket. Board targeting remains attributed to the active decision step;
explicit board review and History are separate. The buckets measure the active
UI context, not mouse motion, card counts, or the player's mental activity.

Each interval belongs to the context active before the transition. Worker and
playback time are resolution; next-round preparation belongs to the new round.
No mutable session is inspected while its worker runs. Setup, pause, unfocused
time, loading, offline time, and time after a finished match are excluded.
Nonterminal Aftermath review remains decision time in the round just played.
A save made mid-round naturally contains only that round's elapsed portion.

Version-1 telemetry loads without losing its totals. Its historical time goes
in `unattributed.decision_ms` and `unattributed.resolution_ms`, while subsequent
play gets real round/surface measurements. `breakdown_complete` is false when
historical detail is unavailable. Saves with no prior timing retain the existing
`history_complete: false` behavior. No estimates are substituted for missing
measurements. Per-round totals and surface sums are validated on load.

Round timing can reveal where pacing changes, but a slow screen alone does not
establish strategic depth or UI friction. Compare several games, and inspect
the screen breakdown before drawing that conclusion.

## Validation and related correction

The timing runner covers round and surface transitions, revisits, pause/offline
exclusion, JSON round trips, partial-round continuation, legacy totals, and
malformed breakdown rejection. The wheel runner covers bounds, scrolling,
dragging, keyboard return, refresh stability, stamps, and layout at 460, 800,
and 1100 pixels. Playable-board checks exercise actual save/load and phase UI.

Those checks also exposed an existing casualty-reader error: Lord power
resolvers may return bare event facts, while hook reactions carry an `event`
envelope. Godot and Python now accept both forms and still record only explicit
deaths. This does not change the Resurrection rule or authoritative schema.

Local checks use the available Godot 4.5.1 diagnostic engine. The production
4.7.2 requirement is unchanged. This environment cannot open a graphical
display, so final visual review remains on the Windows playable runner.

Passed: playtime, Veil wheel, playable-board, and UI-feedback runners, with
zero failures or script errors; Python powers/Marching tests, 24 passed;
`git diff --check`. The uploaded round-12 Windows save also loaded with its
840,782 ms total intact and its previous totals correctly marked unattributed.
Its wheel fit inside the existing 120-pixel banner at a 1920 × 1080 viewport.
