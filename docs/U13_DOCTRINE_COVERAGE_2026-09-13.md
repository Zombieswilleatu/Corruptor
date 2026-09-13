# U13 doctrine coverage and construction focus

## Accepted performance gate

The uploaded Windows `5b7dffbb` submission report is green: 317 checks, 176 exact
hook comparisons, zero failures. Joint submission was 20.5% lower across nine
openings and 44–47% lower with 2,000 prior events. See
`U13_SUBMISSION_PERFORMANCE.md`; these percentages do not describe whole games.

## Current V3 campaign

A fresh local campaign ran the published `5b7dffbb` code, including the Vulture
cadence change, before modifying doctrine. Godot 4.5.1 Linux diagnostic engine,
two game processes, 40-round cap. This is separate from Windows acceptance and
from the older V2 uploads. Independent planning/save/resolution replay ran on
seed indices 9 and 59; the other seven used single-conductor legality checks.

All nine games reached legitimate victory: **146 rounds, 9 wins, 0 capped,
0 failures**. Four Dominion, four Ritual, one Final Collapse. Every Lord appeared
in both seats. This small campaign is coverage evidence, not a balance verdict.

| Seed index | Lords | Final round | Victory |
| --- | --- | ---: | --- |
| 9 | Gremory / Deimos | 11 | Ritual |
| 19 | Deimos / Humbaba | 11 | Dominion |
| 29 | Humbaba / Kalligan | 15 | Dominion |
| 39 | Kalligan / Orias | 25 | Ritual |
| 49 | Orias / Odradek | 17 | Ritual |
| 59 | Odradek / Kroni | 21 | Dominion |
| 69 | Kroni / Valak | 15 | Dominion |
| 79 | Valak / Kanifous | 14 | Ritual |
| 8 | Kanifous / Gremory | 17 | Final Collapse |

Twenty of the 23 active powers appeared in committed plans. Inversion, Wish Power
and Wish Resurrection were absent from these nine matches. False Orders appeared
twice, Allegiance Shift five times, Ravenous eleven times. No cast quotas or
artificial score boosts were added to inflate those counts.

`U13DoctrineCoverageTestRunner.gd` supplies real, authoritative favorable states
for the three absent powers. It exercises actual selection, complete-cart
admission, resolution and save/replay. Inversion transfers all three enemy guards
when its receiving zone is empty; Resurrection restores three guards lost to an
opposing Hunt. Concealed enemy guard values are varied while the bot's public input and
selection remain identical. These are directed opportunities, not claims that
the powers had equally good opportunities in the campaign.

## Directed V4 change

The concrete common-planner problem was construction switching. For example,
both players in game 19 alternated Construct between their two protected projects
in rounds 1–7. Construct changes the single project receiving automatic progress;
starting the other project repeatedly delayed the first useful activation.

V4 keeps the current project until it finishes or is commissioned. It can still
Repair elsewhere while construction progresses, or Activate a ready castle.
Continuing an existing project without payment needs no redundant Construct
order. Paid acceleration is valued only for progress beyond the free amount;
a free full-health finish is not replaced by payment or early activation.

This is a bounded planning preference. Construction rules and human controls
still allow changing projects. Power scores and targeting are unchanged.
Self-targeted Inversion remains intentional. Pillage becoming invalid after an
opponent activates a castle is an accepted risk, per the user's clarification.

`U13ConstructionDoctrineTestRunner.gd` follows both seats through five actual
Development phases and exact replay, confirms commissioning and starting the
next project, and covers paid completion, free completion, and Repair alongside
continuing construction. The full basic-doctrine suite retains nine-Lord legal
plans, cached/uncached equality and concealed-guard checks.

## Local V4 verification

All five fixture suites passed on Godot 4.5.1 Linux: 456 checks in total
(133 army-action, 220 basic-doctrine, 15 wish, 60 construction and 28 power
coverage checks). This includes independent resolution/save replay; it does
not replace the Windows 4.7.2 gate below.

The first two completed V4 representative matches, seeds 49 and 79, reached
Ritual victories in rounds 18 and 15. Both seats commissioned their first new
castle in round 5 and their second in round 10, with intervening repairs and
no construction switching. Seed 79 also selected Wish Resurrection naturally.
These games are slightly longer than their V3 counterparts (17 and 14 rounds);
finishing defenses is a doctrine correction, not a promised runtime reduction.

Seed 19 exposed a defensive stall: Deimos repeatedly chose Castle Ward while
Humbaba repeatedly Sieged the same Keep, usually dealing zero castle damage.
The independent replay diagnostic completed 27 rounds without a legality,
script or replay error. It was deliberately interrupted during round 28 after
the construction checks were satisfied; its latest saved checkpoint is at
round 25. This is **not a third completed match, a cap result, or a termination
pass**. The prior V3 seed 19 won in round 11. Preserve this regression in game
length as the next focused doctrine case; do not report V4 as nine wins or as
an overall throughput improvement.

The relevant follow-up is the public-pressure estimate in
`U13CommonDoctrine.combat_score`: review how standing marchers and waiting units
justify recurring Ward and how a bot reacts to repeated ineffective Sieges.
Use the V4 seed `u13-full-match-v1:19` to reproduce it. Any adjustment must use
public history and board information, never the opponent's hidden guard faces
or simultaneous order. No Ward/Siege score change is included in this patch.

## Short Windows check

```bash
U13_DOCTRINE_FIXTURES_ONLY=1 bash Scripts/Sim/run_u13_doctrine.sh \
  "/c/Users/jerem/OneDrive/Documents/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64.exe"
```

This runs five focused suites and exits before starting matches. Its fresh ZIP
is written directly in Downloads with `UPLOAD THIS FILE:` printed. The ordinary
command still runs nine matches after those fixtures. Reports explicitly identify
the fixture-only mode and record zero requested games when it is selected.

Next: use current doctrine match reports to review repeated low-impact choices
and power outcomes. Keep a larger strategic-planner rewrite and extensive
simulation throughput work for the later planned milestones.
