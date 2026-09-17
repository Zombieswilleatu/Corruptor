# Inevitable Ruin · 14-health rebalance

Inevitable Ruin now reduces a commissioned enemy Castle **above 14 Integrity to exactly 14**. Healthy Castles are eligible. Castles at 14 or below, protected construction, friendly Castles and missing, ruined or profaned targets are ineligible.

The existing two-card discard and next-round scheduled timing remain. Eligibility is checked again when the power fires. If intervening damage leaves the Castle at 14 or below, it fizzles without healing, further damage, refund or retargeting. Repair above 14 does not cancel it.

The Castle remains standing and operational. This causes ordinary Integrity damage, keeps any Siege Engine target, creates no repair lock, and grants no destruction rewards. Aftermath reports the damage and remaining health. UI target highlights, selection lists and both bot implementations use the same threshold; bots value only the damage the power can actually deal.

This supersedes the earlier zero-Integrity/Defunct behavior. The rules fingerprint changes; start a new game after updating.

Verified with native rule/UI, Gremory, Construction and bot checks; 27 Python tests; 203 exact native/Python transitions; and two complete Gremory games with matching event histories and final saves. See the [verification record](evidence/U13_INEVITABLE_RUIN_2026-09-17.json). The local engine is diagnostic Godot 4.5.1; production remains 4.7.2 stable.
