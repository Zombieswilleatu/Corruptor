# U13 production opening economy

The user reported this checkpoint's 12/12 gate green. The following Fracture
checkpoint expands the gate to 13/13; see `U13_FRACTURE_2026-09-11.md`.

This checkpoint replaces the provisional all-unbuilt/free-Lord setup in the
full-game conductor. It does not change U12 or the deliberately small U13 visual
exercise openings.

## Settled opening

- Each player still chooses five ordered physical Castle slots. A type may appear
  at most twice, Keep is optional and at most one Keep may be selected.
- Slots 1–3 start active and standing at their current effective maximum
  Integrity (normally 21). Slots 4–5 start unbuilt, Defunct, protected, and keep
  their sealed physical identities for later Construction.
- The Slaver's three public offers are dealt first, followed by five private Hand
  cards per player.
- Each opening Lord is summoned at its current U13 cost. Payment automatically
  takes the lowest-value cards from that player's Hand until the cost is covered
  or the Hand is empty; ties retain deterministic Hand order. Paid cards enter the
  shared discard, and overpayment is not refunded.
- If a starting Summoning Circle is operational, the lowest-slot copy makes one
  automatic Blood Offering: exert 3 Integrity and reduce that summon cost by 3.
  A duplicate Circle does not stack on the same opening summon.
- An opening payment shortfall creates no starting Threat or Fracture. The Lord
  starts alive with zero Threat when that stat exists. This first summon records
  summon count one and creates no Neutral Tear; the accepted U13 Tear applies to
  later returns after banishment.

The ordered first-three rule is how the accepted “any three” opening maps onto
U13's five sealed physical slots. Loadout order is therefore gameplay data, not
presentation-only sorting.

| Lord | Base opening cost |
| --- | ---: |
| Orias | 6 |
| Deimos | 7 |
| Gremory | 6 |
| Humbaba | 6 |
| Kalligan | 4 |
| Odradek | 8 |
| Kroni | 5 |
| Valak | 6 |
| Kanifous | 4 |

An eligible opening Blood Offering reduces the listed cost by 3.

## Repair decision

Playable U12 repeatedly prompts for Repair and can still permit a Construct.
U13 deliberately retains its accepted locked-order contract: each player may
submit exactly one `castle_action` per round—Construct, Repair, or Activate.
Resummoning, guard deployment, a Lord power, and combat can coexist when their
existing legality and non-overlapping payment rules permit them, but a sequential
`castle_actions` list is invalid.

## State and replay

`U13_GAME_ECONOMY_V4` stores a canonical opening ledger with the three starting
Castle IDs per player and an exact summon record: Lord identity, effective cost,
paid card IDs/values, shortfall, and Circle exertion. Validation binds the Circle
discount to the first actual starting Circle, requires ordered payment and rejects
forged counts, costs, identities, or overpayment continuation. Older game saves
must begin a new match.

`U13OpeningEconomyTestRunner` covers optional Keep and duplicate loadouts, physical
slot states, one Circle Offering, all nine current Lord costs, lowest-value payment,
a deterministic sparse-Hand shortfall, first-summon Tear/Threat state, atomic save
rejection, JSON replay, and the one-Castle-action rule. The game wrapper now expects
12/12 on the authoritative Windows Godot 4.7.2 stable runtime.

Next work is the remaining lifecycle rather than more opening revision: printed
Fracture/banishment, waiter spending, Dominion, Vacant Throne, Veil, and legitimate
victory before sustained full-match acceptance.
