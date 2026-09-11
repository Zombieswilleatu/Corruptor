# Kanifous presentation — 2026-09-11

Resolved wish Prices now open a blocking “The Price of Wishes” board popup.
It identifies whose debt was collected, the outcome, affected piece labels,
and any neutral Tear increase. Continue dismisses one Price at a time.
Purple smoke draws attention to the affected player's side. The board consumes
public Price events after worker completion, including next-round automatic
hooks; presentation never applies the cost a second time.

The smoke warning keeps its plume and due-round label but no longer draws a
spawn-boundary ring. Lamp scatter radius increases from 180 to 540 field units.
Keyed rejection sampling keeps the lamp in the announced lane and within that
radius; no movement across lanes or off-field placement. Contact radius remains
65. The supplied RGBA lamp artwork replaces the placeholder and retains its
original pixels/transparency.

Validation: Kanifous rules and board suites passed headlessly on Godot 4.5.1;
board used the explicit compatibility-check flag. Tests cover wider bounded
scatter, keyed replay, a real wish becoming due through the next-round worker,
popup acknowledgement without state mutation, and lamp texture loading.
Windows 4.7.2 visual review remains with the user.

Received ZenBook profile: 65.297 seconds, zero Kroni failures. Checkpoint round
trips 19.218 seconds (restore validation 15.091), all hooks 11.457, planning
4.127, angle-gradient test 7.844. These are nested phase wall times; they do not
isolate CPU from console output overhead. No profiling optimization in this patch.
