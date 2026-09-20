# Orias doctrine: useful Web control and Snare preparation

The Python doctrine is now `U13_COMMON_SMART_CORE_ALPHA_V16_ORIAS_CONTROL`.
Orias previously valued Web by current enemy count and Snare by empty Guard
slots across both lanes. This pass connects each power to useful actions and
its actual timing. It changes doctrine, not game rules or Castle loadouts.

## Web

Web delivers one activation hit, then halves enemy movement inside its radius
through this Marching phase and the next. Entering later does not cause another
activation hit. Expiration is followed by one cooldown round.

- Compare nominal unopposed travel with travel through the circle. Consider
  current enemy positions and forward placements near their next-phase path.
- Value preventing a gate arrival, extending friendly ranged coverage,
  relieving an outmatched force, and delaying reinforcements to an existing
  fight. Retain a placement in each lane within the normal proposal budget.
- Do not count a movement slow as reduced attack speed. Already engaged
  enemies, firing Vultures, turrets and waiting Supplicants receive no such
  control credit. Activation damage and a possible finishing hit still matter.
- Include existing friendly units, Towers and same-plan recruits. Recruits
  can attack immediately; their next-round movement readiness does not prevent
  firing. Spawn-area support is discounted. Spent Supplicants are excluded.
- Respect visible Walls, lateral range and the two-phase horizon. Equal-range
  enemy Vultures do not supply imaginary extra firing distance.

These are straight-path scenarios. Congestion, enemy choices, survival, exact
spawn positions and future target changes remain uncertain. Second-phase
entrants receive three-quarter control credit. Initial weights price activation
hits at three points and potential kills at six extra points, cap total control
at 48, and reserve six points for holding the power. This is provisional policy
scoring, not a damage or win-rate prediction.

## Snare

Snare pays its Threat cost immediately and caps the opponent at **one new Guard
next round**, across both lanes. It never removes already deployed Guards or
strengthens this round's Hunt/Siege.

- Look for a next-round Hunt or Siege using cards that remain after every own
  commitment. Do not invent future draws or read the opponent's hand.
- Include existing unspent Supplicants and conditional arrivals during this
  Marching phase. The next attack occurs before next round's movement. Visible
  interceptions, Walls, birth movement holds and consumed troops constrain
  arrivals.
- Preserve existing enemy Guards. An own attack may conditionally create
  vacancies before Snare takes effect. Count vacancies in the prospective
  attack lane; two separate one-slot vacancies do not imply useful denial.
- Compare explicit new-Guard values of two and four, with the normal number of
  deployments versus one. Give the average benefit half credit for next-round
  uncertainty, capped at 28 points, then subtract the immediate cost.
- Price Threat, reduced Lord defense and Blood Conduit's three-Integrity cost.
  A same-plan Lord Ward may reduce later Threat; it cannot undo an exerted
  Circle. An expiring current cap is not treated as permanent.

The forecast records its prospective attack, retained cards, possible arrivals,
surviving Guards and assumed deployments. It is a reason to prepare, not an
irrevocable order for the following round. The bot reassesses the next public
board normally. New enemy deployments this round, Ward, repairs and combat
outcomes can invalidate the scenario.

## Verification and scope

CPython 3.12.14 and PyPy 7.3.20 / Python 3.11.13 each pass **51 focused methods**:
21 Orias checks, 11 existing power-coordination checks, 16 Rout checks and three
shared planner boundary checks. These include all nine Lords' opening legality,
input immutability, hidden-information independence, both player seats and
smaller custom budgets.

Four directed legal decisions match exactly across runtimes, including full
decision fingerprints: gate protection, Web placed for a later wave, Snare
before a supported Hunt, and holding Snare after that support is removed. One
controlled authority case runs two Marching phases and checks Web's expiration,
single activation damage window, Snare's delayed cap and its subsequent expiry.
Detailed reports and source hashes are in
[the evidence JSON](evidence/U13_ORIAS_CONTROL_DOCTRINE_2026-09-20.json).

Orias alternatives use at most 16 assessments and four retained alternatives
inside the existing **32 complete plans / eight legality previews**. No full
balance matches ran. Earlier Rout comparison work remains stopped. This is the
experimental Python planner; native shipping-policy port and Windows acceptance
are separate later gates. No native acceptance or balance improvement is claimed.

Next doctrine passes: Gremory's delayed Ruin, then Kanifous's Wish/Price choices.
