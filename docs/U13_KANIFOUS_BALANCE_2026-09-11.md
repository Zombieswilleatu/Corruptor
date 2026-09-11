# Kanifous balance and unpaid Prices — 2026-09-11

Wish Power uses a separate keyed WISH_COUNT draw: 70% one Marcher, 25% two,
5% three. Suit draws remain independently keyed per spawned unit. Successful
Wishes still create one Price regardless of count.

Wish Death radius is now 100 field units (previously 270). The existing targeting
preview reads that same constant. This is a tight area, not a three-victim cap;
all friendly/enemy Marchers inside are destroyed. A fixture with three close
units and two outside the boundary verifies the reduced footprint.

Both players' mobile Marchers steer toward the nearest materialized lamp within
180 field units, the original lamp scatter radius. Stable lamp ID breaks equal
distance ties. Smoke does not attract and other-lane lamps are ignored. Attraction
uses ordinary movement speed, lane bounds and ally spacing. Existing combat
contact, waiting, delayed movement, retreat and Kroni panic retain precedence.
After a lamp is claimed/removed, normal targeting resumes. Lamp spawn scatter
remains 540, contact remains 65; neither is changed by this steering radius.

If no Price outcome has an eligible payment, the original debt remains in the
saved ledger with its original due date. Each later ROUND_START_AUTOMATIC retries
collection. The popup states that the Price is deferred and still owed; the Wish
panel shows overdue debts. Debt clears only after collection. Outcome selection
continues to use the existing weighted pool of currently eligible costs. This
change does not preselect an unavailable cost or change existing partial/up-to-two
Cards/Blood collection semantics.

Verification: Kanifous rules, board (headless compatibility-check) and Marching
integration suites on local Godot 4.5.1. Added count-distribution/keyed replay,
small Death footprint, both-player lamp steering and radius/lane/smoke/tie checks,
repeated unpaid debt retries, later payment, and full-match overdue checkpoint
restore and collection checks. Windows 4.7.2 visual/gameplay tuning is next.
