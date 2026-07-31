# Odradek Interlock — Godot integration

**LAB_PROFILE_VERSION:** `6.8.1-odradek-interlock-port`

The installer patches Python automatically because the anchors are verifiable.
It **stages** `Scripts/Sim/OdradekInterlockEngine.gd` and leaves the call sites to
you, because rewriting engines it has never read is how installers break repos.

This is the checklist.

---

## 1 · Why a shared engine

Pre-port there were **three** Psychic Recoil implementations: the after-Reveal
path plus separate remove-and-discard copies inside the Hunt and Siege resolvers.
`odradek_recoil_done` is shared and per-round, so the resolver copies fired only
when the primary action did not attack Odradek but a Momentum second action did.

Low frequency — but two different mechanics in one build, and it silently
invalidated the balance measurement it was supposed to support. **Do not
reproduce that shape.** Every path calls the same transition.

---

## 2 · Call sites to rewire

| file | current | becomes |
| --- | --- | --- |
| `RevealEngine.gd` | inline Recoil (primary path) | `OdradekInterlockEngine.resolve_recoil(...)` |
| `HuntResolutionEngine.gd` | inline Recoil (Momentum path) | same call |
| `SiegeResolutionEngine.gd` | inline Recoil (Momentum path) | same call |
| `CommitmentEngine.gd` | — | `spend_bank(...)` before finalising commitment |
| `ReflexActionEngine.gd` | — | `spend_bank(...)` on the Momentum attack |
| lord-death / banish path | — | `discard_bank(..., "banished")` |
| action evaluator | — | `apply_doctrine(...)` |
| post-action | — | `update_ward_streak(...)` |

**Caller responsibilities before `resolve_recoil`:** defender is Odradek, alive,
targeted by this Hunt/Siege; Orias's clean Marked Prey Hunt does not suppress it;
for Sieges, `recoil_hunts_only` is false. Everything else belongs to the engine —
the once-per-round flag, selection, the Interlock lock/replace, the steal, the
Soul.

---

## 3 · `# API:` substitution points

Every line in the engine marked `# API:` is a guess at your types. Replace with
your real accessors:

| in the file | meaning |
| --- | --- |
| `rules.odr_recoil`, `rules.odr_recoil_bank`, … | your `RuleConfig` accessor style |
| `odradek.odradek_recoil_done` | `PlayerState` field |
| `odradek.odradek_bank` | new nullable `Card` field |
| `attacker.committed` | committed-card array |
| `game.discard_cards([...])` | your discard sink |
| `game.gain_soul(player, 1)` | your Soul award |
| `game.stat_bank_spent` | stat sink, or delete |

---

## 4 · New persistent state

`Player` / `PlayerState` gain:

```
odradek_bank        nullable Card   — face up, publicly visible
consecutive_wards   int
```

Both must be:

- copied by simulation state duplication
- exposed to the bot's information view
- serialised in golden/debug snapshots (`PlayableMatchSnapshot.gd`)
- **counted as a physical-card zone in every conservation census**
- **preserved across ordinary round resets** — they are *not* per-round flags
- cleared only through explicit bank transitions

`odradek_recoil_done` stays per-round and continues to reset normally.

`removed_from_play` is untouched — the standalone lab does **not** have that
zone, so take Kroni's census tracking from *this* branch, not from the lab.

---

## 5 · Determinism warning

Python selects the second-highest committed card via `sorted(..., reverse=True)`,
which is **stable** — equal values keep committed order.

**Godot's `sort_custom` is not guaranteed stable.** The reference engine therefore
decorates with the original index and compares it as an explicit tiebreak. Do not
"simplify" that back to a plain value sort or Hunt-vs-Hunt parity will drift on
duplicate-valued commitments, and it will only show up in a matrix seed months
later.

`test_tie_resolves_deterministically_by_commit_order` in the Python suite is the
matching assertion; write its GDScript twin.

---

## 6 · Result contract and narration

Recoil results must stop calling a banked card "discarded". Fields:

```
taken_card · bank_before · bank_after · replaced_card · locked · soul_gain
```

Commitment / second-action results add `bank_spent_card`.

```
Odradek — Psychic Recoil: banked Penitent:4 from the attack; gained 1 Soul.
Odradek — Interlock: Penitent:3 could not exceed the banked Penitent:4; Recoil locked.
Odradek — Interlock: discarded banked Penitent:3 and replaced it with Vulture:5.
Odradek — Interlock spent: Vulture:5 joined the Hunt; Recoil rearmed.
Odradek was Banished; the banked Wright:4 was discarded.
Odradek — Reconfiguration: Tokens 2→0; placed 1 Neutral Tear.
```

**UI:**
- `Interlock bank: Vulture:4` in Odradek's visible status — it is **face up**, so
  hiding it removes the entire read the mechanic exists to create
- projected Hunt/Siege strength must include the automatic bank card
- the bank is **not selectable** — spending is automatic
- no pre-Reveal narration that leaks a sealed attack

**Lord card text needs rewriting.** The current text still describes Hunt-only,
lowest-card, discard. It must say: Hunt **or** Siege, second-highest, face-up
bank, replacement by a strictly larger card, and spend-on-attack.

---

## 7 · Lab profile values

```
clocks   WIN_SOULS=12   DOMINION_REQUIREMENT=5   FINAL_COLLAPSE_TRACK=26
         DOMINION_TRACK=12  (unchanged)

rules    odr_recoil_bank          = true
         fix_breach_discard_alias = true      # bug fix — enable it
         reconfig_neutral         = true
         reconfig_tokens_needed   = 3
         reconfig_strict          = false
         recoil_hunts_only        = false
         recoil_lowest            = false

doctrine doctrine_ward_threat     = 0.20
         doctrine_ward_stagnation = 0.30
         doctrine_bank_urgency    = 0.35
```

**Canonical DE v2 keeps every one of these at its current value** — Hunt-only
Recoil, lowest-card discard, strict one-Guard denial, five-token personal Tear, no
bank, doctrine terms at zero.

`doctrine_bank_urgency` is not optional. Without it the bot banks once and never
attacks to unlock, so Recoil switches off for the rest of the game and the whole
mechanic is unmeasurable. This was verified the hard way.

---

## 8 · Versioning

```
SIM_VERSION          unchanged — canonical rules are untouched
LAB_PROFILE_VERSION  6.8.1-odradek-interlock-port
Python AI policy     heuristic-2026.07-lab-kits
```

Godot's selector stays honestly named `softmax`; it is not renamed. The lab
doctrine values belong to the lab rules/profile identity, and Python's
balance-report policy id matches the source lab.

---

## 9 · Do not regenerate goldens

The installer deliberately does not touch traces, manifests, or matrix fixtures.

**Run the existing traces against the new engine first and read the
divergences.** Each one should map to an intended change; anything you cannot
explain is a bug you just introduced. Regenerating alongside the code makes the
suite agree with itself by construction and encodes whatever you shipped as
correct — which is exactly how the card-duplication fault survived 228 passing
golden checks.

Add each player's bank to Godot's matrix conservation census before the run, or
it will report 60→59 the first time a card is held.

---

## 10 · Expectations for the measurement

This patch ports **Odradek only**. Kalligan's lane Scorch and Kroni's
fallback/milestone revisions are not included, so **do not expect the full lab
roster spread**.

Report locked and pool separately. In the source lab at these settings, locked
spread was 26.0 while pool was 42.9 — and roughly 19 points of that pool gap is
Kalligan at ~24%, who is not in this patch. Reading the pool number as an
Interlock regression would be a mistake.
