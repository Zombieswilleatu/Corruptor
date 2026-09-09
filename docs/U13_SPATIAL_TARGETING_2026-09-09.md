# U13 shared spatial targeting foundation

Runtime: Godot 4.7.2 stable. The preceding Marching audit was reported locally
green, including the six Breath runners. This change adds the shared spatial
contract needed before Orias and the later spatial Lords.

## Coordinates and regions

`U13SpatialSpace` owns the existing Marching dimensions: x is forward travel
0–2400, y is lateral position 0–600. Both bounds are inclusive. Marching aliases
these constants; its movement, steering, contact, spawning and battle algorithms
are unchanged.

Positions contain exactly `x_fp` and `y_fp`. Accept integral JSON floats and
normalize to integers; reject fractions, strings, booleans, nonfinite values,
extra fields and out-of-lane positions. Invalid normalization returns `{}`.

Regions are plain data:

```json
{"shape":"lane","lane":"Lord"}
{"shape":"circle","lane":"Castle","field_position":{"x_fp":1200,"y_fp":300},"radius_fp":250}
```

The radius above is an API example, **not Web tuning**. Radius may be 0–3000;
the upper bound already exceeds the lane diagonal and keeps integer arithmetic
bounded. A circle extending beyond the lane is intersected with that lane.
Circle membership includes the boundary. Squared integer distance needs no
floating tolerance or square root. Explicit padding permits contact with an
actor's extent; callers must supply the rule's reach. No universal body radius,
Godot physics callback, damage or allegiance rule is invented here.

`U13SpatialInput.target_at` converts a point in the supplied lane rectangle to
`{lane, field_position}`. It uses the current board orientation: bottom = x0,
top = x2400, left = y0, right = y600. Clicks outside are rejected, not clamped;
quantization rounds to the nearest integer, with positive half points upward.
The rectangle and click must share a canvas coordinate space. Pixels and
Vector2 values do not enter a declaration. Orias's future targeting UI will
provide its actual rectangle; this patch does not change existing lane clicks.

## Query authority and order

`U13SpatialQueries.capture(registry_snapshot)` validates the stable entity
registry and builds an owned, ephemeral set of live Marcher IDs, positions,
lanes and current allegiance. Waiters remain query subjects. Castles and other
non-Marcher entities are excluded. Capture failure leaves the last good capture
unchanged; callers must check the returned action before querying it.

- `members(region, owner_filter, padding_fp)` returns stable-ID order.
- `nearest(region, origin, owner_filter)` explicitly chooses distance, then ID.
- Filter -2 means any allegiance, -1 neutral, 0/1 the corresponding player.
- A valid miss returns empty IDs (or nearest id `""`); invalid queries return an
  `invalid` action. Callers must not turn invalid queries into gameplay fizzles.

Capture once at the authoritative hook/tick requiring a query and recapture
after movement, retirement, spawn or allegiance mutation. Do not persist this
view as another source of truth. Queries read a compact array in O(Marchers);
they do not clone a match or run a combat preview. Registry validation/copying
is a capture cost, so do not rebuild one capture per actor. The existing
optimized Marching neighbor grid is retained. Future per-tick Web integration
must use the checked geometry in the existing authoritative movement pass,
with profiling at that integration point.

## Keyed random placement

`random_position(region, seed, effect_id, purpose, sample_index)` samples uniformly
from canonical integer positions in the clipped region. It draws from the
clipped bounding box and rejects points outside the circle. Each axis uses a
separate purpose suffix; each sample has a length-prefixed semantic identity.
There is no mutable cursor, global RNG, clamping bias or obstacle-avoidance rule.
The existing SHA-256 rejection RNG remains unchanged. Exhausting 1024 attempts
is an explicit error, never a biased fallback. Golden vectors include Unicode
keys, clipping and a draw that rejects its first candidate.

## Serialization correction

`U13LordPowerDeclaration.from_json` previously cast fractional control fields
and nested `_fp` numbers to integers before validating. It now rejects lossy
numbers, numeric strings, booleans and unsafe integer magnitudes before casting.
Valid integer JSON round trips are preserved. The declaration envelope remains
geometry-neutral: bounds belong to spatial legality, not generic serialization.

## Verification and next gate

New small runners cover geometry, keyed placement, registry/query isolation,
JSON restore, retirement/current allegiance, UI conversion and lossy decoding.
The focused `--spatial` group has five runners; existing groups retain their
coverage. Foundation now has 63 runners, including the separate Rout visuals
runner added in this change. The default per-process watchdog remains 30s.

Source grammar, indentation, preload call arities and shell syntax were checked
in the implementation workspace. Golden vectors were computed independently
with Python's SHA-256. Stub-process wrapper checks exercise runner selection,
footers, error rejection and timeouts; they are not Godot validation. Godot is
not available in this workspace. Local Godot results remain the acceptance gate.

```bash
bash Scripts/Sim/run_u13_foundation_tests.sh \
  "/c/Users/jerem/OneDrive/Documents/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64.exe" \
  --spatial
```

Expected: `U13 spatial runners passed: 5/5`.

Orias is not enabled by this patch. Web still needs its explicit radius,
persistent region lifecycle, movement modifier, discrete damage integration,
legality, UI and random-legal path. Later Wishmaster contact/objective semantics
remain governed by the Wishmaster addendum.
