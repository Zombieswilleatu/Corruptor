# Unified round action modal

User-requested presentation change following Guard work. The playable scene now
uses `U13ActionFlowBoard`, extending the existing playable adapter. Authority,
card costs, ordering of resolution hooks, and saved game rules remain unchanged.

The existing decision modal hosts all top-level choices, in this order:

1. Stockpile, when a keep/discard choice is due.
2. Slaver trade or pass.
3. Work Target.
4. Resummon, if the Lord is absent.
5. Guard placement, when there is a card and an eligible slot.
6. Combat: Siege/Pillage, Hunt, Ward or skip. Hunt Fracture selection is here.
7. Lord powers, if the Lord is present.
8. Dominion rites, then final resolution.

A Stockpile choice or Slaver trade/pass advances through the actual economy
adapter. Selecting a Work Target on the pulsing board automatically advances.
Multi-card and multi-power steps use Done to finish selection. Filling the
available Guard placements also advances. Skip clears only that step's staged
choice; Done retains it. Done on Work also retains the persistent target.
Back reviews previous planning choices without discarding other staged orders.
Economy decisions already applied cannot be rewound by Back.

Work is no longer in the history header. Economy and rite controls are embedded
in the same scrollable action shell. Specialized board placement tools still
serve spatial Lord powers. Rites remain an optional final step: skipping powers
must not resolve the round before it. Profane Castle explicitly replaces combat,
as required by the existing rules. Closing a rite sub-picker returns to rites.

New saves retain the complete cart as before; loading begins at Work for review
rather than guessing which optional UI steps were considered finished. Invalid
loads retain both the current cart and current step. Aftermath and match result
presentation remain available in the same shell.

Validation: `run_u13_action_flow.sh` runs the new directed action-flow suite and
the full playable-board regression suite. It retains the exact Godot 4.7.2 stable
acceptance gate and packages logs. Local Godot 4.5.1 results are diagnostic only.
No 100-game rerun is needed for this presentation-only patch.
