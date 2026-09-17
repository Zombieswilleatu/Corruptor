# Permanent Veil Breaches · initial playtest rules

Implemented from the accepted v0.2 proposal. The old generic Veil penalties stay disabled. Ritual, Dominion, Final Collapse and automatic Neutral Tears retain their existing conditions and precedence.

| Threshold | Arrival | Protection |
| --- | --- | --- |
| Veil 5 | First absent Lord | 1 current Personal Tear |
| Veil 9 | Second absent Lord | 2 current Personal Tears |
| Veil 13 | Third absent Lord | 3 current Personal Tears |
| Veil 17 | Fourth absent Lord | 4 current Personal Tears |
| Veil 21+ **and round 21+** | All remaining absent Lords | None |

Arrivals resolve at the next round start, before choices open. Multiple crossed thresholds resolve in order; all cascade identities are admitted before their entry effects resolve. With two distinct participating Lords, seven Lords are eligible: four ordinary arrivals and three in the cascade. Mirror matches exclude their one participating identity and therefore leave eight eligible Lords.

Selection uses a separate keyed, unweighted draw without replacement. Only revealed arrivals are stored; no future order is sent to the player or bot. Arrivals remain until the battle ends. A finished battle cannot activate a new arrival or acquire an extra playable round. Final Collapse can occur before the cascade's round gate.

Protection uses **current** Personal Tears. The Tear that crossed the threshold counts before the next arrival. Acquiring protection later does not undo earlier damage. Protection applies to permanent intruders; participating Lords' ordinary Breaches remain unprotected and coexist with them.

| Lord | Active effect | Permanent-arrival protection |
| --- | --- | --- |
| Gremory | First Guard defeat each round grants each player a card | Denies the opponent's bonus card |
| Deimos | Castle maximum Integrity reduced by 5, once while active | Own ceilings remain normal; gaining protection restores the ceiling without healing |
| Humbaba | 4 damage to exposed Castles on entry; 1 on later round starts, before repair | Own Castles ignore both contributions |
| Kalligan | Damaged eligible Castles regain 2 Integrity at round start | Denies the opponent's restoration |
| Orias | Threat 2+ limits Development to 2 Guards, captured before submission | Own deployment ignores the restriction |
| Odradek | One legal random Guard transfer or Marcher-circle allegiance change after combat | Protected units are excluded from targets and mixed-circle transfers; no reroll against immune units |
| Kroni | One neutral devouring manifestation per Marching phase | Own Marchers are neither frightened nor devoured by this manifestation |
| Valak | Marcher movement at half speed | Own movement, panic movement and Gravity Orb pull ignore this slowdown |
| Kanifous | One optional Breach Wish per player per round | Denies the opponent access |

Two protected players deny each other's beneficial effects. Environmental Castle destruction retains the existing neutral Tear/reaction path and awards no Siege Souls or Spoils of War. Humbaba's recurring damage also applies to an ordinary Breach, stops when he leaves, and never ticks in the entry round.

## The Unbound Wishmaster

The Void's visual penalty is removed. Any participating Lord, including a banished one, can take a Breach Wish while access is available. Normal Wish targeting, effects, timing and the shared one-Wish-per-round limit apply. A queued Wish remains armed under the ordinary firing rules.

Successful Breach Wishes create Prices due 1–3 rounds later. Their saved debt retains its Breach origin even if Kanifous leaves before collection. Ordinary Wishes keep the existing weights.

| Price | Ordinary weight | Breach weight |
| --- | ---: | ---: |
| Cards | 30 | 30 |
| Blood | 30 | 30 |
| Guards | 15 | 15 |
| Stone | 15 | 30 |
| Soul | 5 | 10 |
| Ruin | 4 | 8 |
| Lord banishment | 1 | 2 |

This doubles the **weight**, not the damage or absolute probability, of Stone and higher Prices. With every outcome legal, their combined probability rises from 25% to 40%. Ineligible outcomes are removed before drawing. An uncollectable debt stays owed. Each Stone-or-higher collection adds the existing Neutral Tear. A banishment Price targets the owing Lord and activates that Lord's actual ordinary Breach.

The modal says **BREACH WISH — HEAVIER PRICE** before the queue button and explains the doubled draw weights. The same warning appears on Kanifous's Breach description and revealed Veil marker.

## Display, saves and measurement

The existing wheel shows actual revealed Lords, each side's protection and effect descriptions. Future markers show only thresholds. The cascade explains both gates and its lack of protection. Personal Tear corner totals and wheel stamps use the same public resources.

Authoritative snapshots now contain `world.data.veil_breaches`: revealed `arrivals` with Lord, threshold, protection tier, round and Veil; the last checked round; first observed Veil-21 round; cascade activation round; and `round_history` entries with Veil, Kanifous activity, arrival count and winner. These distinguish time waiting above Veil 21 from actual cascade exposure. Existing playtime/decision-surface metadata remains intact.

The rules identity changed. Start a **new game** after updating; older rules snapshots intentionally fail compatibility checks. New saves preserve arrivals, protection, Wishes and debts exactly.

The proposed 5–10 second victory outro remains a later presentation pass. Existing Marching and Breach visuals are reused here.

## Verification

Focused native tests cover arrival gates, hidden identities, protection direction for all nine Lords, late ceiling restoration, erosion attribution, the Kroni/Odradek/Valak cascade, protected Marchers, Wish admission, save/replay and all seven heavier Price outcomes. Native UI tests exercise Deimos's actual queue/remove controls, the increased-Price warning, denial by enemy protection and Wish access while banished.

Independent Python comparisons match five arrival checks, fourteen effect checks, and 153 transitions across the five Breach Wishes and one ordinary Wish. Seven complete games match every event and final state between Godot and Python, and each final save restores exactly in Godot. All 56 targeted Python unit tests pass. These are correctness replays; they do not establish balance. All seven games ended before round 21, so the cascade gate is covered by the focused fixtures.

Reference input games were regenerated because the new effects change subsequent hands and choices. Native checks in this environment use Godot 4.5.1 diagnostically; the production runner still requires Godot 4.7.2 stable. Windows visual review remains the final presentation check. See the [verification record](evidence/U13_PERMANENT_BREACHES_2026-09-17.json).
