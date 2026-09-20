# Kanifous V22: Power-only default

User requested a best-guess selection and short internal verification instead
of another long comparison. Select the Power-only valuation profile by default.
Retain actual Power spawn odds of 25/50/25 percent (mean two bodies) from 42e37b0.
The extra short-hand Wealth bonus and speculative Resurrection cap remain
explicit experimental profiles; neither is active in the default policy.
Existing commitment-aware Wish timing, Price valuation and Death friendly-fire
checks remain active. This profile still chooses among all five Wishes.

## Selection evidence

Verified upload: u13-kanifous-v21-calibration-gXhmBy-2026-09-20_15-54-09-iCfiqY.zip
SHA256: 01f40672ced56120286c12ac3b5c74b2b5df7217c2bd5e91d53cbe0f7e577eac
Source revision: 35d78dcc66e7232a96461636eb516106736021e4.
All 180 records, frozen policy files, engine identity, runner copies, semantic,
trace and operation hashes, aggregate and 36 reused controls were verified.

| Profile | Wins / 36 |
| --- | ---: |
| V20 | 13 |
| Power only | 17 |
| Wealth only | 15 |
| Resurrection cap only | 13 |
| Combined | 15 |

V19 won 16/36 on the same setups. Power-only gained seven and lost three versus
V20; versus V19 it gained five and lost four. This small reused-seed sample
supports a provisional choice, not a general strength claim. The comparison
used the old 1.35-body rules; it does not establish that Power needed a buff
or measure the strength of the retained two-body rules.

## Short verification

42 focused Common/Kanifous/calibration/comparison tests passed. The additional
smoke check plays four actual rounds per seat versus Gremory using normal
planning, card choices, simulation and delayed Prices. Both seats select Power
at opening, spawn two bodies in this sample, and resolve Prices. All 208
operations are admitted with zero rejected previews. Runtime about 11 seconds.
This deliberately stops early and reports no wins or balance conclusions.

Reproduce the smoke check (from repo root):

```bash
python Scripts/Sim/verify_u13_kanifous_power.py
```

The prior V21 campaign remains reproducible at its pinned revision. Its runner
requires V21 and intentionally rejects this V22 checkout. No new full campaign
was run or requested.

### Smoke evidence

```json
{
  "policy": "U13_COMMON_SMART_CORE_ALPHA_V22_KANIFOUS_POWER_DEFAULT",
  "scope": "two four-round smoke checks; no win-rate evidence",
  "checks": [
    {
      "focal_seat": 0,
      "completed_rounds": 4,
      "operations": 104,
      "operations_sha256": "cf182a223de88147430fac74c6c644f3dcd39e83c2f2999cbe1994d1d7c20faa",
      "selected": {
        "WishPower": 1,
        "WishDeath": 1,
        "WishResurrection": 2
      },
      "power_bodies": [
        2
      ],
      "prices_resolved": 1,
      "rejected_previews": 0
    },
    {
      "focal_seat": 1,
      "completed_rounds": 4,
      "operations": 104,
      "operations_sha256": "4993181d3afe867b4a3100bc04a898bbf8d55c20805902127f4a6d2ad644d526",
      "selected": {
        "WishPower": 1,
        "WishDeath": 3
      },
      "power_bodies": [
        2
      ],
      "prices_resolved": 3,
      "rejected_previews": 0
    }
  ],
  "wall_seconds": 11.381691514001432
}
```
