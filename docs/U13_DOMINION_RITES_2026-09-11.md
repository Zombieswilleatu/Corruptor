# U13 waiter spending and Dominion rites

The user accepted the opening/Fracture game gate at 13/13. This checkpoint
adds the next authoritative full-game choices and expands the gate to **14/14**.

## Rules recovered

- `FutureFeatures/CORRUPTOR_DESIGN_ADDENDUM_VEIL_SIEGE_CONSTRUCTION.md`, section 2:
  consume **five waiting Marchers in one lane** for **one personal Tear**.
  Exact physical bodies are selected. Multiple disjoint groups are accepted;
  the addendum specifies no once-per-round restriction. Both lanes can be used,
  but each five-body group must belong to a single lane. Current ownership
  applies, including Odradek transfers. Moving/enemy/missing bodies are illegal.
- `Prototype/PlayableRoundController.gd` selects `RuleConfig.lab_v6_5()`.
  Together with `DominionRiteEngine.gd`, this establishes **Cataclysmic
  Invocation**: Veil at least **7**, at least **11 raw card value**, **one personal
  Tear**, **once per match**. The U13 payload names the exact cards to discard;
  all selected cards are spent, including any overpayment.
- The same profile establishes **Profane the Ruins**: own at least **two ruined
  Castles**, spend **two Souls**, turn one selected ruined Castle into a
  **Profaned** Castle, gain **one personal Tear**. Once per round. Physical
  Castle IDs preserve duplicates; the other ruin remains. Defunct structures
  and unbuilt blueprints do not count. This is the ruined-Castle rite, not the
  separate active-Castle Profane action.

## U13 timing and submission

`order.rites` is optional. Omission is pass; it composes with guards, a Castle
action, resummoning, combat and Lord powers through the existing joint lock.
Choices use the presented state. A rite cannot borrow a later Soul gain or use
its own pending Tear to unlock Invocation at submission.

```json
{
  "rites": {
    "waiter_spends": [{"lane": "Lord", "marcher_ids": ["id1", "id2", "id3", "id4", "id5"]}],
    "invocation": {"card_ids": ["card1", "card2", "card3"]},
    "profane_ruins": {"castle_id": "physical-castle-id"}
  }
}
```

Cards/Souls are paid during the shared submission transaction. Invocation cards
cannot also pay a Lord power, summon, Castle action, guard or combat commitment.
A ruined Castle cannot be reconstructed and profaned by the same submission.

Rites resolve at the start of **Development**, before ordinary Development and
combat. Per player they resolve waiter groups, Invocation, then Profane, in the
conductor's player order. No prompt appears after submission lock. New arrivals
from this round's Marching become eligible at next round's planning.

Spent waiters retire without a damage/death callback: this is consumption,
matching existing support consumption, and awards no kill Souls or death
triggers. Remaining waiters can still support the matching Hunt/Siege. Rites
emit public `PERSONAL_TEAR_CREATED` events with source, payment/physical IDs,
and resulting Veil total. No archived Gremory passive is reintroduced.

## State, legality and bots

`U13DominionRites.gd` owns shape/legality, payment, resolution and restore checks.
The new profile is confined to the full-game content adapter. The core Lord
exercise boards retain their existing profiles. New full-game saves include
`U13_DOMINION_RITES_V1`; older full-game saves need a new game.

Sealed rite records stay private. Public projection includes the derived Veil
total and both Invocation-use rounds. Restore validates clocks, sealed choice
identity, original eligibility, payment conflicts, pre-Development payments,
retired waiter identities, the Profaned target and Invocation usage. Invalid
submissions/restores are atomic.

Random-Legal V3 includes pass at each rite stage and uses the same bulk legality
as the game. Waiter samples use stable-ID groups in one lane (all legal groups,
including combinations across lanes, can be submitted directly); Invocation
samples ascending/descending card values. This is bounded reachability sampling,
not strategic doctrine or a balance claim.

## Verification and remaining work

The new directed suite covers five/ten-body exchanges, mixed lanes, ownership,
duplicate spending, moving bodies, both rite prices/gates, malformed payloads,
shared card/Castle conflicts, immutable preview, atomic second-player rejection,
forged reservations/payment refunds, current Invocation-use forgery, public
privacy, every-hook JSON replay, next-round persistence, and a real Siege where
only the unspent sixth waiter provides support.

Run `bash Scripts/Sim/run_u13_game.sh <Godot-4.7.2-executable>`; expect **14/14**.
Local compatibility verification uses Godot 4.5.1; the Sigil board gate is left
to the user's pinned Windows 4.7.2 runtime.

Next: the remaining full-match rules, including active-Castle Profane/Pillage,
Vacant Throne, Veil threshold effects and legitimate victory. This checkpoint
adds Tear choices and the derived total; it does not claim complete matches,
threshold immunity, a victory evaluator or human full-game controls.
