# Orias hunting, The Mark, and Ward — doctrine V6

## Findings from the uploaded V5 100-game campaign

100 completed matches; 20 independently replay-verified. Orias chose 55 Hunts,
228 Sieges, 29 Passes and 11 Wards. Hunts were 19.4% of his Hunt + Siege choices.
The user's target is approximately 50% of attacks, measured over games, never a
forced action quota or a reason to ignore an immediate winning Siege.

The periodic checkpoints retained 38 Orias Hunt resolutions: 11 banishments,
24 Guard-clearing attacks without banishment, and three with neither. They killed
60 Guards. Checkpoint event history omits the last several rounds of each game;
these are not outcomes for all 55 Hunts.

The original interpretation of Orias's zero Fracture values was wrong. Fracture
is a fixed printed value (zero for Orias), distinct from his current Threat.
Banishment facts also reset Threat before recording it. Actual HUNT_RESOLVED DEF
shows all 11 recorded Orias banishments occurred below base DEF 6: eight at 3,
two at 4, one at 5. This establishes vulnerability, not a counterfactual proof
that each death was avoidable. Orias's recorded Blood Conduit costs were 34
activations / 102 Circle integrity / two crossings below operational integrity.

All Lords chose Ward 44 times in 3,088 choices. Checkpoints preserve 31 Wards:
27 Castle, four Lord; 20 single-card and 11 two-card commitments. Thirty attacks
had positive Ward screens, removing 106 incoming Strength in total. Two stopped
entirely at that screen. Lord Wards removed three Threat. These effects establish
utility but not superiority over the attack that could have been chosen instead.

## Changes

- Banishment facts retain pre-reset victim Threat; the entity still resets to
  zero. Full-game Fracture integration had suppressed Orias's The Mark because
  its callback saw zero. The older isolated Mark fixture lacked this profile.
- Hunt scoring puts Pursuit before Guards, respects strict Guard equality,
  values permanent Keep damage, and gives Orias productive Guard/Accelerate
  setup and the additional Mark reward. Banishment and Ritual opportunities
  retain priority. The shared Keep-damage correction benefits other Lords too.
- Snare prices every Circle exertion, its Repair lock and operational-floor loss,
  and the cost of further lowering DEF or accumulating recovery debt at DEF 3.
- Ward scoring values protection before Guards, half-strength opposite-lane
  coverage, fresh Sigil gain, and Lord Threat/DEF recovery. An intentionally weak
  public hand-count prior acknowledges possible commitment pressure; it never
  treats concealed cards or orders as known. Travelling Marchers contribute no
  immediate support; waiting Marchers are counted once.
- The match report records compact public combat events for every round,
  including the terminal round, instead of requiring periodic save decoding.
  This telemetry is collected outside the bot and is never a policy input.
- Doctrine version is V6. The existing acceptance launcher adds the new full-game
  Mark and Hunt/Ward doctrine fixture (seven preflight suites total).

## Validation and limits

Local runtime is Godot 4.5.1 Linux. Windows acceptance remains explicitly gated
on Godot 4.7.2; its version check has not been altered. Run the supplied doctrine
launcher on that runtime before calling the Windows acceptance green.

Passing local suites: BasicDoctrine, WishDoctrine, ConstructionDoctrine,
DoctrineCoverage, CommittedHunt, Fracture, and HuntWardDoctrine. The focused
fixture covers Mark below/at threshold with exact sealed/final save replay,
public Hunt setup/Guard equality, Ward recovery, Snare safety, and concealed
Guard invariance including Orias. Existing isolated OriasMark is also checked.

Small exploratory matches check behavior, not balance. Final scoring is checked separately on fixed seeds; campaign figures follow below.

## Final local pilot

Three final-code single-conductor matches, seeds 4, 13, 22, completed without
errors or caps. These are deliberately a small behavioral check, not evidence
of win-rate balance. Orias lost all three; further tuning requires the wider
Windows campaign.

| Seed | Orias Hunts | Orias Sieges | Orias Wards | Rounds | Winner |
| --- | ---: | ---: | ---: | ---: | --- |
| 4 | 7 | 3 | 1 | 11 | Gremory |
| 13 | 4 | 5 | 1 | 10 | Deimos |
| 22 | 3 | 7 | 1 | 11 | Humbaba |

Orias Hunt share: **14 / 29 = 48.3% of Hunts + Sieges**, versus 19.4% in V5.

An earlier six-match exploratory pass also completed; seed 4 independently
replayed planning/save/resolution. That pass preceded the final Snare and
mutually-exclusive Ward-lane refinements, so its exact action counts are not
reported as final-code performance. The final dedicated regression independently
checks sealed and completed Mark saves/replays.
