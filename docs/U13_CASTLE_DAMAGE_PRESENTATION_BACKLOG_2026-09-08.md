# Castle damage presentation — accepted follow-up

Implementation status: included in the [Humbaba board slice](U13_HUMBABA_BOARD_2026-09-08.md).
The original U12 construction shader is reused unchanged; commissioned damage
uses cached fragments. Local board and visual acceptance are pending.

User request, recorded during the first Humbaba rules slice. Apply at the next
appropriate Castle presentation pass; do not interrupt the current rules gate.

Follow-up clarification: Construction mechanics, numerical Integrity/progress,
lifecycle labels and card-based Commission are already in U13. Progressive
construction artwork is not yet ported. Include that in this UI pass: audit the
U12 presentation first, then make the artwork assemble/reveal as construction
advances. After Commission, low Integrity should read as damage rather than
unfinished construction. Both presentations must follow authoritative lifecycle
and normalized Integrity, with clear protected/operational labels retained.

Reuse each Castle's existing card artwork. Fracture it programmatically into
pieces, then progressively move/rotate the pieces inward and downward so the
card appears to collapse as its Integrity falls. No separately commissioned
damaged-card illustrations are required.

Use remaining Integrity divided by maximum Integrity, not hard-coded thresholds:

| Remaining fraction | Presentation band |
| --- | --- |
| Above 2/3 | Intact artwork |
| Above 1/3 through 2/3 | Some damage / fractured |
| 1/3 or below | Heavily damaged / collapsed |

Exact boundaries should use integer comparisons (for example `3 * integrity`
against `2 * maximum` and `maximum`) so changing the Integrity ceiling does not
require retuning fixed numbers. The amount of collapse can interpolate within
and between bands as damage changes. Zero Integrity should agree with the
existing Defunct/Ruined state rather than invent another gameplay state.

Keep protected construction visually distinct: an unfinished build's low progress
is not combat damage. Commissioned copies may immediately display their actual
low-Integrity damage band. Guard outlines, target pulses, click/drag hit regions,
card identity, accessibility labels and readable Integrity must remain usable.
Repaired cards should visibly recover; appearance never owns simulation damage.

Implementation considerations for the presentation pass: cache fragment geometry
and source textures, use a small bounded number of pieces per card, animate only
when state changes, and retain the board's responsive worker/playback path.
Choose the handling of temporary maximum-Integrity modifiers alongside the
existing displayed maximum so art and numerical Integrity remain consistent.
