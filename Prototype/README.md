# Corruptor playable prototype

This folder is an isolated human-vs-bot vertical slice. It does not replace
`CorruptorMain.tscn`, alter the project main scene, or modify any canonical
simulation script.

The opponent uses the experimental **FIX A** Commitment scoring profile from
the post-green roadmap. Hunt, Siege, and Ward bases are equalized to `0.333`;
Ward's unconditional Soul/Castle/Threat weights are reduced from
`0.55/0.30/0.35` to `0.12/0.08/0.20`. The adapter lives entirely in
`Prototype/PlayableBotDoctrine.gd`; canonical `BotDoctrine.gd` is untouched.
The normal Standard softmax policy still samples the resulting scores.

## Run

Open `Prototype/PlayablePrototype.tscn` in Godot and press **F6**.

Choose both Lords and an integer seed. The player then makes every
discretionary decision for seat zero:

1. optional Orias Snare, Market, Repair, Dominion Rites, and Deploy moves;
2. resummon payment or an explicit remain-banished pass;
3. Reflex Bid, sealed order, target, and committed cards;
4. Kanifous's Invoke card and, for Wright, zero to two hidden Lord Guards;
5. Humbaba Toll, Consume/Inferno settings, Vessel, Reflex, Odradek Breach,
   and Gremory Inevitable Ruin choices when those windows open;
6. continue until one of the three canonical victory conditions fires.

From round two onward, the log identifies the Reflex Bid winner before
Commitment. Resolution then reports the actual Reflex second action separately
from the two primary revealed orders, including its actor and committed cards.

The opponent still takes its own turns through the configured bot doctrine.
System effects—draws, Veil drift, mandatory Lord powers, and resolution
bookkeeping—remain automatic. Market order is respected: if the bot has
priority, its trade resolves before the player is shown the live Market.
Opponent draws remain private. In this isolated prototype, a Lord's Breach
ability is active only while that Lord remains banished. A successful return
immediately closes the Breach and the match log identifies that transition.

The match log follows canonical execution order rather than reconstructing
events from the final state. It reports resolution precedence, Prelude effects,
the concrete outcome of every primary and Reflex action, Sigil interactions,
Lord powers, committed-card aftermath, Vulture/Wright pair bonuses, Vessel
offers, Finale effects, temporary-Guard cleanup, delayed Profane Tears, and the
specific event that opened a victory checkpoint. Cataclysmic Invocation and
other early Development victories are printed before the terminal banner, with
their payment, Tear/Veil change, and resulting win condition.

Hunt and Siege targeting expose only the defense information the attacker is
allowed to know. Each castle option shows its current breach-adjusted
structural DEF, while the target readout separates structural/Lord defense,
revealed Guard value, face-down Guard count, and the active zone Sigil. Before
a zone has been attacked, its Guard identities and values remain private to
their owner and the readout gives only a known defense floor. An attack turns
the current Guards in that zone face-up; the board and match log then identify
them. Newly deployed Guards begin face-down even when older Guards in that zone
have already been revealed. Revelation belongs to the card's current stay in a
specific Guard zone: a defeated or moved card is hidden if it later enters a
Guard zone again. Sigil creation, aging, expiration, breaks, and successful
blocks are reported explicitly in the match log.

Each player panel now includes a scrollable **Lord Card**. It states the
implemented summon/defense values, explains every active and Breach ability,
and displays live per-Lord state such as Kroni Hunger, Odradek Reconfiguration
tokens, Kanifous's invoked suit, Gremory's once-per-round uses, and Humbaba's
Patient state. When those powers resolve, the match log names the power and
reports its concrete result. These descriptions are based on the canonical
Godot engine behavior used by this prototype; they are not aspirational rules
text.

## Isolation boundary

The prototype uses the canonical engines and adds only player-by-player input
entry points where the old wrappers resolved both seats at once. Their default
behavior is unchanged for the simulator and bot runners. Deleting
`Prototype/` removes the human interface; canonical engine changes remain
rules-neutral plumbing for that interface.

The same hidden-information boundary applies to both seats. A Guard's identity
and value remain hidden while it protects a zone; attacks reveal the Guards in
that zone. Bot Commitment, Reflex, and Deploy-reservation doctrine receives a
private state view in which the opponent's unrevealed Guard count is preserved
but each hidden value is replaced by the neutral deck expectation (3). The bot
therefore estimates face-down defense instead of reading the real cards.

The controller generates decisions only for the bot seat. It pauses before
each human choice window and applies the selected input against the current
live state, preserving the existing deterministic flow without silently
substituting a bot choice for the player.
