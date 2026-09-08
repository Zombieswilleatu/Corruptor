# U13 Humbaba — first rules slice

Runtime: Godot 4.7.2 stable. Branch: `u13-lord-overhaul`.

The prior board gate is locally accepted: 6/6 at the 30-second default, followed
by the user's visual acceptance of Guard outlines and sequential curved artillery.
This returns to the implementation plan's low-spatial Humbaba wave.

## Rules in this slice

- **Lord of This World:** Humbaba stores no Threat attribute. The shared
  `U13LordStats.threat_value` returns null, never zero, and threshold queries
  return false even for a zero threshold. Content admission/save restoration
  rejects an attached Threat attribute. Future Threat-changing mechanics must
  preserve this absence rather than creating or coercing the stat.
- **Woven Into the Stones:** Hunt defense is 2 plus the number of the owner's
  standing physical Castle instances. Standing means exposed/commissioned,
  positive Integrity; a Castle below the operational floor still stands.
  Protected construction, zero-Integrity Defunct, Ruined and Profaned copies do
  not count. Duplicate instances count separately. The shared Castle Guard zone
  remains unchanged. The Hunt resolver and projected Lord stats use one query.
- **Muster the Faithful:** declare one lane, spawn exactly three Penitents at
  Step 10A with current-round movement readiness and ordinary authoritative spawn
  placement. The shared activation clock blocks the firing round and the next
  round; it is Ready again at R+2. An armed Muster survives later Banishment.
- **Endurance of the Faithful:** at Step 13, a living Humbaba with at least one
  surviving friendly Penitent at exactly 1 final HP creates one Neutral Tear.
  Multiple qualifying bodies still produce only one Tear; Armor is irrelevant.
  No damage-history flag is used. Canonical Step-3 regeneration remains unchanged;
  a body healed above 1 does not qualify. The passive uses the existing living-Lord
  convention. Its once-per-round ledger is checked against the restored cursor.
- **The Stones Forget:** one pulse of four Integrity damage on each standing,
  exposed Castle on both sides when Humbaba enters the Breach. Damage four remains
  the specification's provisional tuning value. Protected builds are untouched.
  Normal repair-lock transitions, ruin state, Castle identity, Castle-destruction
  Tear cap and Gremory reactions apply. Environmental destruction has no credited
  attacking player: it earns neither Siege Souls nor Deimos's Spoils of War.

Breach facts in this profile include the actual banished Lord instance ID. The
pulse ledger is keyed by the authoritative Breach event identity, so duplicate
fact delivery or save/restore cannot fire it twice. A later new entry may fire
again; simply remaining in the Breach does nothing. Stable Castle-ID order owns
this simultaneous pulse's event serialization, not geometric distance.

## Scope and next gate

`U13Humbaba` composes the existing Deimos/Gremory rules with a separately pinned
content profile. Existing Gremory/Deimos match policies and the playable picker
remain unchanged. `U13HumbabaScenario` is an isolated headless fixture: five
Castle slots per player, two exposed Castles at 8 and 3 Integrity, three unbuilt
Castles, and the existing exercise hand/resources. It enables the already
implemented basic Hunt path. This does not establish the production opening.

**Breath of Life remains next:** it needs the planned shared lane aura and
canonical regeneration modifier. No provisional unit tag or separate heal clock
has been introduced. This is not a claim that Humbaba or Milestone 3 is complete.
After local acceptance, finish that shared aura/Breath slice before integrating
Humbaba's completed controls into the board; Kalligan follows in the Lord wave.

## Focused verification

Three bounded processes cover:

1. Stat absence, standing/protected Castle distinctions, exact final HP,
   regeneration, deaths, once-per-round checks, Breach damage/protection,
   destruction reactions, repeat delivery and new entries.
2. Central declaration rejection and snapshot atomicity, three-round cooldown
   replay with real Marching, JSON restoration, distinct spawn positions,
   strict Hunt defense, and Muster firing after Banishment/Stone damage.
3. Keyed random choice through central legality, a bounded actual random batch
   plus independent replay, and Endurance opportunity/body/Tear telemetry.

The focused wrapper also runs the existing Hunt, Deimos and Castle-loadout
regressions. Every process retains the default 30-second deadline, error scan,
completion marker and fail-fast handling. Expected counts: Humbaba **6/6**, full
foundation **28/28**, board **6/6**. Grammar/static checks and stub-engine wrapper
checks are not Godot compilation or gameplay execution; local engine verification
is required before moving on.

```bash
git pull --ff-only origin u13-lord-overhaul &&
bash Scripts/Sim/run_u13_foundation_tests.sh \
  "/c/Users/jerem/OneDrive/Documents/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64.exe" \
  --humbaba
```

After that gate, optional larger frequency/replay coverage uses:

```bash
bash Scripts/Sim/run_u13_random_batch.sh \
  "/c/Users/jerem/OneDrive/Documents/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64.exe" \
  --roster=humbaba
```

Reports remain in Downloads (`u13_random_humbaba.json` and `.log`). This mode
uses Humbaba/Gremory, both centralized candidate providers, existing keyed
random choice, Construction and basic Hunt/Siege/Ward. It reports Endurance
checks, threshold-met rounds and qualifying bodies separately; Endurance is a
passive, so a declaration/threshold ratio is not meaningful. Tear source and
Stones Forget entry/Castle-hit counts are included. These measure frequency and
reachability, not strength, win rates or balance.
