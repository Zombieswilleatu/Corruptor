# U13 Vacant Throne

Ports the tested `VacantThroneEngine` / `VacantThroneTests` rule into the full-game
conductor. The older Veil addendum's escalating 1/2/3 description is stale:
**two full Lordless rounds are safe; the third and every later consecutive
Lordless round award exactly one Soul to the opponent.**

A round counts only if the Lord was absent throughout it. The banishing/removal
round never counts. A return resets the streak at Aftermath, even if the Lord
is removed again in that round. The next absence gets two new grace rounds.
Breach identity does not matter. Both absent players may receive Souls; this
checkpoint does not yet implement the living-Lord Ritual victory evaluator.

The opt-in full-game profile records round-start counts, presence during the
round, completed counts and the last resolved round. First-hook initialization
and banishment reactions preserve presence even when removal precedes ordinary
scheduled-hook processing. Normal Development resummoning is observed through
the authoritative world. Aftermath settles both sides once and emits explicit
public `VACANT_THRONE_RESOLVED` events. No Tears or new choices are introduced.

Save checks bind clocks and counter arithmetic to the current round, and bind
post-planning presence to the presented world and actual summon counts. Forged
presence/streaks and duplicate settlement reject atomically. Full-game policy
version changes; start a new full game for this profile.

Verification: focused grace/flat-payment/reset/Breach/both-absent cases; four
real conductor rounds with every-hook JSON replay, including an actual return;
a real Hunt banishment followed by Aftermath; scheduled-removal presence; malformed
ledgers and forged saves. All fourteen local simulation suites pass on Godot
4.5.1. The Windows game gate now includes this runner: **15/15**, including Sigil
board integration on 4.7.2. The user's accepted 180-second override remains
available; no timeout default was changed.

Remaining match work includes active-Castle Profane/Pillage, Veil effects and
legitimate victory. A passing foundation still does not claim complete matches.
