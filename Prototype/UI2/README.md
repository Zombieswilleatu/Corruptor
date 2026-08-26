# Corruptor UI2

Parallel shipping-UI architecture. This directory does not replace or mutate
`Prototype/PlayablePrototype.gd`.

Current milestone: **Step 0.7 — production shell freeze candidate**.

The shell deliberately prioritizes structure over polish:

- Steam-first, 1280×720 minimum.
- BOARD is always visible.
- ACTION is always visible.
- CONSOLE is on demand.
- Two compact player pucks.
- Four zone rows: enemy Lord, enemy Castle, your Castle, your Lord.
- Five fixed Castle spine slots.
- Guard rows reserve current legal capacity; hidden Guards fill stable positions.
- Humbaba's conditional fourth Castle Guard slot appears only while Gate 4 applies.
- Sigils display current numeric value immediately beside the Guard row.
- Empty marching lanes stay thin and expand only while marchers exist.
- Zone rows size to content instead of consuming spare vertical space.
- Player pucks sit directly beside their own Lord/Castle zone block.
- Reveal / Results reserve no permanent space; they will overlay the board when active.
- Castle spine placeholders stay compact; full names live in tooltip/tap detail.
- Normal DEF renders as one number; base→current appears only when modified.
- Hand count uses the same label for both players; visibility is implied by perspective.
- Human Hand occupies the action region.
- Static reference/help belongs in the Console.
- Existing `PlayableRoundController` remains the gameplay authority.

Action buttons are intentionally disabled in this first shell. Interaction is
ported only after the information architecture is proven at 720p.


## Production-target composition

UI2 now follows the intended shipping hierarchy rather than the original debug bars:

- top: two player summaries framing the Dominion / Veil track
- left: Activity / Results rail
- center: enemy zones, real three-step Marching region, human zones, suited-value Hand
- right: current-decision rail
- Action Forecast belongs in the right rail and remains explicitly `WHOLE HAND`
- no spell/mana economy is introduced
- Lord and Castle Guard zones remain separate
- Castle board codes are unique: `KEP / BST / CIR / STK / ENG`
- Reveal / Results may overlay unused board surface but reserve no permanent row


## Step 0.6 hierarchy corrections

- Activity rail enables BBCode instead of printing tags literally.
- Flexible vertical space belongs to `BoardSurface`; Hand is a fixed bottom strip.
- Lord zones use a dedicated `LordCard` component with the current DEF as the focal number.
- Right action rail always shows the four action-card shapes; outside Commitment they are visibly disabled.
- Hunt copy includes the opponent's current Lord DEF.
- Forecast remains scoped as `WHOLE HAND` and only appears during Commitment.


## Step 0.7 distribution + phase discipline

- Board stack is content-sized; Hand follows it immediately.
- Any remaining vertical slack falls below the Hand, never between board and Hand.
- Local-player Lord/Castle zones are larger than opponent zones to create Arena-style perspective.
- Lord card removes redundant `LORD · DEF`; the large number is the focal read.
- Commitment action cards exist only during Commitment.
- Non-Commitment phases show only their own phase panel until real phase controls are ported.


## Authentic midgame showcase

`PlayableUI2Showcase.tscn` is a visual stress-test scene, not a playable
checkpoint. It creates a fresh locked seeded game and lets the real
`BotRoundEngine` resolve five full rounds, then the sixth round only through Reflex Bid using the current rules and policy.

The resulting real GameState is then rendered by UI2 while the Commitment rail
is exposed for layout testing. The top track explicitly labels the state
`MIDGAME SHOWCASE · POST R#` so this cannot be confused with a legal human
checkpoint.

Use the normal `PlayableUI2.tscn` for actual play.


## Real Commitment showcase

The UI2 showcase resolves R1-R5 completely with `BotRoundEngine`, then mirrors
the real R6 phase order only through Reflex Bid and stops BEFORE Commitment.
No commitment cards are moved out of Hand.

This gives UI2 a dense, legal decision-point fixture with a live Hand, current
Guards/Sigils/Castles/Marchers, and the actual Commitment action rail.


## UI2 populated-state pass

- The left rail no longer dumps raw engine phase names. It shows player-facing
  round/status copy only; future outcome summaries belong there.
- The deliberate `LowerBreathingRoom` spacer is removed. At 1280x720 the board
  owns flexible height and the Hand is a substantial fixed decision strip.
- Hand cards are sized as cards now (92x132) and are selectable in Commitment.
- Guard slots are card-shaped fixed objects: empty, hidden, and revealed are
  three visual states of the same slot.
- Castle spines expose Operational / Defunct / Building / Ruined / Profaned
  state text rather than relying on tiny glyphs.
- Commitment action cards are live. Choose an action, target where needed,
  select Hand cards, then Seal Order.
- The R6 showcase no longer traverses or displays the obsolete Reflex Bid
  phase; it stops after Summon and calls the controller's Commitment-prep path,
  which creates the bot's sealed order without consuming the human Hand.


## UI2 post-seal cleanup

- Guard mini-cards keep fixed height and vertically center inside expanded rows.
- Activity rail developer placeholder prose removed.
- Non-Commitment action rail states use player-facing copy.


## UI2 card-geometry resize pass

- Lord cards use a tarot silhouette (~72x124).
- Castle cards use a poker silhouette (~68x95).
- Guard cards use a mini-poker silhouette (~38x53).
- Hand cards use a poker silhouette (~94x132).
- Player fields may expand, but card objects and zone rows do not stretch.
- Enemy content anchors down toward marching lanes; human content anchors up toward them.


## UI2 resize pass 2 — expanding battlefield

- Lord tarot cards increased to ~86x148 so they are physically larger than poker cards.
- Castle poker cards increased slightly to ~72x101.
- Guard and Hand geometry remain unchanged from resize pass 1.
- Red/blue player fields are content-height rather than vertical stretch containers.
- The marching/reveal battlefield absorbs extra vertical room.
- Board and Hand explicitly expand horizontally to use the available center column.
- 1280x720 remains the minimum design target; larger windows expand the battlefield, not the cards.


## UI2 vertical battlefield v2

- The UI2 root and Frame fill the viewport; 1280x720 is the baseline rather than a 1024px-wide island.
- Activity and Action share the left rail.
- Strategic state and Hand remain in the center.
- Marching occupies a dedicated right-side battlefield.
- Lord and Castle lanes run vertically from enemy gate to player gate.
- Existing bind_players(human, bot) API and current three-step marching rules are preserved.
- No jungle, neutral-enemy, branching-lane, or other MOBA mechanics are added in this pass.


## UI2 battlefield tighten pass

- ActivityRail sizing is applied after add_child so its own _ready() cannot collapse the log region.
- The obsolete expanding StrategicGap is now a fixed 12px separator.
- The vertical marching battlefield is capped at 350px at the 1280 baseline; extra width goes to the strategic center.
- Every Lord/Castle lane now labels its slot columns as enemy lord | STEP | human lord.
- Marching mechanics and bind_players(human, bot) remain unchanged.


## UI2 intended split restored

- Activity remains the far-left rail and Your Action remains the far-right rail.
- The body now reads Activity | strategic center | marching battlefield | Action.
- Marching occupies the previously-unused right side of the playable field rather than replacing the Action rail.
- Hand remains under the strategic center; marching stays independent on its right.
- The current two-lane battlefield is constrained to 300px at the 1280 baseline, with 132px lane panels.
- Existing marching rules and bind_players(human, bot) remain unchanged.


## UI2 strategic-zone fill pass

- Enemy and human strategic fields now expand equally to consume the full board height above the Hand.
- Each player's Lord and Castle rows expand horizontally and vertically, splitting that player's field rather than clustering in the upper-left.
- Zone containers expand; tarot Lord cards, poker Castle cards, and Guard mini-cards retain their fixed geometry.
- The old enemy-bottom / human-top zone-stack alignment bias is removed because the full field is now intentionally tiled.
- Marching battlefield, Activity rail, Action rail, and gameplay mechanics are unchanged.


## UI2 zone-row full-width fix

- ZoneRow now opts into horizontal EXPAND_FILL in its own _ready().
- Each enemy/human Lord and Castle row is also forced to EXPAND_FILL after add_child(), so any ZoneRow _ready() geometry cannot override the parent layout intent.
- The red/blue strategic fields remain full-height; this fix makes the darker Lord/Castle row panels span the full field width as well.
- Tarot/poker/Guard card geometry remains fixed and unchanged.


## UI2 actual ZoneRow full-width fix

- Found the direct cause of the unused strategic-board strip: ZoneRow._ready() set EXPAND_FILL and then immediately overwrote it with SIZE_SHRINK_BEGIN.
- Removed the SHRINK_BEGIN override.
- ZoneRow minimum width is now 0 rather than 650, allowing the parent strategic field to determine width while child minimums still protect content.
- The internal HBox now explicitly EXPAND_FILLs horizontally and vertically.
- Lord, Castle, Guard, Sigil, Hand, marching, Activity, and Action geometry are otherwise unchanged.


## UI2 ZoneRow spacer distribution

- Full-width ZoneRows now distribute spare horizontal width between the fixed card/object cluster, Guard cluster, and Sigil.
- The former single trailing spacer was removed because it left all gameplay content packed against the left edge.
- Two equal EXPAND_FILL gaps now produce: zone label | cards | gap | guards | gap | sigil.
- Lord tarot cards, Castle poker cards, Guard mini-cards, and Sigils retain fixed geometry; no card art will be stretched to fill the row.


## UI2 card-scale-up pass

- The logical design baseline remains 1280x720, so the 1080p rough targets were scaled down rather than copied literally.
- Lord cards: ~100x150, now the strongest visual anchor in each player half.
- Castle cards: ~88x126.
- Guard cards: ~54x80, reading as miniature Subject cards rather than pips/chips.
- Hand cards: ~104x150.
- Lord/Castle rows grow only enough to contain the larger cards; empty padding does not scale with them.
- Object and Guard cluster widths were increased so five Castle cards and three Guards fit without stretching art slots.


## UI2 PlayerBoard restructure

- ZoneRow is retained as a compiled fallback/data helper but superseded in the rendered shell by PlayerBoard.
- Each player now renders as one horizontal board: LordGroup | vertical LordGuards | expanding CastleGroup.
- Only CastleGroup gets horizontal EXPAND_FILL; LordGroup and LordGuards are content-sized.
- Lord and Castle sigils live inside their owning groups.
- Lord Guards are vertical; Castle Guards are horizontal by design.
- 1920x1080 is the visual acceptance target for this pass.
- Target sizes: Lord 160x230, Castle 120x150, Guard 70x95, Hand 150x215.
- Existing ZoneRow bindings remain live but hidden during the migration so rollback is simple.
- PlayerBoard delegates guard-slot-count and sigil-value rules to the existing ZoneRow helper, preserving current special-case rules without duplicating them.


## UI2 PlayerBoard vertical-budget correction

- The original 265px PlayerBoard estimate was too small for three 95px Lord Guards plus header/gaps.
- PlayerBoard target is now 300px and the root no longer requests vertical EXPAND_FILL.
- Lord Guards use a compact 58x72 rendering inside the vertical Lord-Guard rail.
- Castle Guards remain 70x95 horizontally.
- Lord cards remain ~160x230, Castle cards 120x150, Hand cards 150x215.
- Canonical Subject suit palette: Butcher = red, Penitent = blue, Wright = yellow, Vulture = purple.
- Suit-color styling should use this palette when card-art/border treatment is wired; this geometry pass does not mix in palette styling.


## UI2 Hand fan + Castle Guard centering v2

- HandView left-aligns its card row and uses -35px separation to overlap cards.
- Hand cards get a light 2.5-degree fan around the current Hand center, pivoting from the bottom center.
- Card z-order follows Hand order so overlap renders predictably.
- Castle Guards are centered across the full CastleGroup.
- A 70px invisible reserve mirrors the Castle Sigil width on the left; the real Sigil remains on the right.


## UI2 revealed Guard-card suit borders

- Revealed Guard cards use the canonical Subject suit palette on their border and suit glyph.
- Butcher = red, Penitent = blue, Wright = yellow, Vulture = purple.
- Revealed Guard borders are 3px; hidden and empty slots remain neutral 1px.
- GuardPip.gd remains the compatibility filename/class for now, though the rendered object is conceptually a Guard Card.


## UI2 shared Subject suit styling

- SubjectSuitStyle.gd is the canonical palette/style helper for Subject cards.
- Butcher = red, Penitent = blue, Wright = yellow, Vulture = purple.
- Revealed Guard Cards and all Hand cards use the same canonical suit accent.
- Hand cards receive a 3px suit border in normal/hover/pressed/disabled states and a 4px focus border.
- Future Retinue cards should use SubjectSuitStyle.gd rather than defining their own palette.
- GuardPip.gd remains the compatibility filename/class for now, but no longer owns a duplicate suit palette.
