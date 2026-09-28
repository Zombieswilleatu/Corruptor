extends RefCounted

const Victory = preload("res://Scripts/Sim/U13Victory.gd")
const Monsters = preload("res://Scripts/Sim/U13MonsterRules.gd")
const LordText = preload("res://Prototype/U13/U13LordRules.gd")
const ENTRIES: Dictionary = {
	"objective": {
		"id": "objective",
		"title": "What wins the battle?",
		"body": "At the end of a round, 12 Souls wins if your Lord is alive. You can also win through Dominion: reach 5 Personal Tears, lead your opponent in Tears, and have the shared Veil at 12 or more.",
		"priority": 100,
		"urgent": false
	},
	"subjects": {
		"id": "subjects",
		"title": "One hand, several jobs",
		"body": "The same cards pay for Guards, attacks, Ward and some powers or rites. A card assigned to one job is unavailable to the others; you can change your plan before RESOLVE ROUND.",
		"priority": 86,
		"urgent": false
	},
	"stockpile": {
		"id": "stockpile",
		"title": "Keep one card",
		"body": "Your Stockpile offers a choice: keep one of these cards and discard the other. The grimoire hints do not count either offer until you choose.",
		"priority": 60,
		"urgent": false
	},
	"slaver": {
		"id": "slaver",
		"title": "Trade or keep your hand",
		"body": "Swap one card from your hand for an offered Slaver card, or pass. This is optional: look at the cards you need for defense, attacks and grimoires before trading.",
		"priority": 55,
		"urgent": false
	},
	"work": {
		"id": "work",
		"title": "Work follows your chosen castle",
		"body": "Newly placed Guards supply work to your selected castle. Unfinished construction also gains 3 work each round; the preview shows the actual gain after limits and repair locks.",
		"priority": 65,
		"urgent": false
	},
	"commission": {
		"id": "commission",
		"title": "Activate an unfinished castle",
		"body": "Commissioning makes an eligible unfinished castle active at its current Integrity. Its abilities become available, but it also loses its protected construction status.",
		"priority": 72,
		"urgent": false
	},
	"guards": {
		"id": "guards",
		"title": "Guards stay to defend",
		"body": "Place cards in the Lord or Castle Guard zone to protect that side of your board. They stay until removed, and each newly placed Guard also supplies 1 work to your work target.",
		"priority": 73,
		"urgent": false
	},
	"pair:Penitent": {
		"id": "pair:Penitent",
		"title": "A Penitent pair",
		"body": "Two fresh Penitent Guards in the same zone form a pair that adds 3 protection before the Guards take an attack. The bond ends if either member leaves.",
		"priority": 78,
		"urgent": false
	},
	"pair:Wright": {
		"id": "pair:Wright",
		"title": "A Wright pair builds or repairs",
		"body": "Two fresh Wright Guards in the same zone add a one-time work bonus: 5 for construction or rebuilding, 3 for repair. That is on top of 1 work per new Guard; surviving pairs do not repeat the placement bonus.",
		"priority": 78,
		"urgent": false
	},
	"pair:Butcher": {
		"id": "pair:Butcher",
		"title": "A Butcher pair",
		"body": "An intact Butcher pair can destroy up to 2 enemy marchers in its lane when that zone is attacked. The pair is tied to these two Guards, not to the slots.",
		"priority": 78,
		"urgent": false
	},
	"pair:Vulture": {
		"id": "pair:Vulture",
		"title": "A Vulture pair",
		"body": "An intact Vulture pair draws an extra card on following rounds. Removing either of its original Guards breaks the bond.",
		"priority": 78,
		"urgent": false
	},
	"commitment": {
		"id": "commitment",
		"title": "Choose your commitment",
		"body": "Commit cards to Hunt, Siege or Ward, or keep them by passing. DONE · NEXT only moves to the next planning page; RESOLVE ROUND locks your full plan.",
		"priority": 82,
		"urgent": false
	},
	"forecast": {
		"id": "forecast",
		"title": "Read the forecast as a baseline",
		"body": "The forecast uses the board you can currently see; hidden enemy choices and later powers can change the outcome. Butchers keep their printed value when attacking and Penitents when Warding; other suits lose 1 strength per card, to a minimum of 1.",
		"priority": 68,
		"urgent": false
	},
	"hunt": {
		"id": "hunt",
		"title": "Hunt the enemy Lord",
		"body": "A Hunt must get through the enemy defenses and exceed the Lord’s Defense to banish them. Banishment earns rewards, but the opponent can keep playing and may summon their Lord again.",
		"priority": 77,
		"urgent": false
	},
	"fracture": {
		"id": "fracture",
		"title": "Choose the banishment damage",
		"body": "If this Hunt banishes the Lord, Fracture can strike their Subjects or infrastructure. Choose the consequence before you lock the attack; the power only matters if the banishment succeeds.",
		"priority": 63,
		"urgent": false
	},
	"siege": {
		"id": "siege",
		"title": "Siege wears castles down",
		"body": "A Siege attacks a castle through its defenses. Damage to Integrity lasts between rounds, so even an attack that does not destroy it can help a later assault.",
		"priority": 77,
		"urgent": false
	},
	"interception": {
		"id": "interception",
		"title": "A castle is shielding your target",
		"body": "A Keep can protect a Lord, and a Bastion can intercept an attack aimed at another castle. The forecast names the defensive layer taking the damage before your intended target.",
		"priority": 61,
		"urgent": false
	},
	"ward": {
		"id": "ward",
		"title": "Protect one lane",
		"body": "Ward uses committed cards to reduce an incoming attack in its chosen lane this round. It recruits ordinary marchers at 2 printed suit value per marcher; it cannot summon grimoire monsters.",
		"priority": 77,
		"urgent": false
	},
	"split_ward": {
		"id": "split_ward",
		"title": "You can defend and attack",
		"body": "Drag cards onto your own Lord or Castle to Ward that zone. Drag different cards onto the enemy Lord to Hunt or an enemy castle to Siege. You can do both in one round; each card pays for only one job. No Reserve Ward click is needed.",
		"priority": 79,
		"urgent": false
	},
	"embolden": {
		"id": "embolden",
		"title": "Empty Guard slots embolden the enemy",
		"body": "Leave a Guard slot empty for a whole round and enemy marchers in that lane gain +10% health, attack, armor, regeneration and speed. Leave it empty longer and the bonus rises to +15%, then +20% per slot: up to +60% for three slots. A Guard lost this round gives you all of next round to replace it before its slot grants a bonus. Filling a slot removes that slot’s bonus when the Guard is placed. Your marchers benefit from the opponent’s empty slots too. This does not strengthen Hunt or Siege cards.",
		"priority": 80,
		"urgent": false
	},
	"ward_conversion": {
		"id": "ward_conversion",
		"title": "Ward conversion: claim the attacker’s recruits",
		"body": "A Ward in the attacked zone can turn the attacker’s new recruits against them. It must prevent a banishment, castle destruction or successful Pillage that would have happened without the Ward. Only surviving ordinary recruits made by that attack change sides; monsters and older troops stay with their owner. Claimed recruits enter at the defender’s end and march that round. Merely surviving an attack, or reducing its damage, is not enough.",
		"priority": 80,
		"urgent": false
	},
	"ward_reward": {
		"id": "ward_reward",
		"title": "That Ward saved you",
		"body": "Your Ward prevented an attack that would otherwise have succeeded, earning 1 Soul. This reward is limited to once per round; merely using Ward is not enough.",
		"priority": 74,
		"urgent": false
	},
	"grimoires": {
		"id": "grimoires",
		"title": "Ready, or one card away",
		"body": "READY means your available cards meet a grimoire; ONE AWAY means one Subject card is missing. STAGED means its ingredients are committed to Hunt or Siege; Guards, Ward and other payments cannot also count.",
		"priority": 57,
		"urgent": false
	},
	"summon": {
		"id": "summon",
		"title": "Choose a grimoire summon",
		"body": "These monsters qualify from the cards committed to your attack. Choose one or decline; a summon arrives alongside the ordinary marchers, and printed card values do not change the grimoire ingredients.",
		"priority": 81,
		"urgent": false
	},
	"pillage": {
		"id": "pillage",
		"title": "No enemy castles remain exposed",
		"body": "With no targetable enemy castle, Siege becomes Pillage: get past the lane’s defenses to earn a Soul. If a castle becomes active before the attack, it may become the Siege target instead.",
		"priority": 77,
		"urgent": false
	},
	"lord_inspection": {
		"id": "lord_inspection",
		"title": "Read your Lord’s full card",
		"body": "Press and hold your Lord card to enlarge it. Click the enlarged card to turn it over and read its abilities, including passives; you can inspect it whenever you need a reminder.",
		"priority": 95,
		"urgent": false
	},
	"resolve": {
		"id": "resolve",
		"title": "This locks your round",
		"body": "RESOLVE ROUND submits your complete plan: Guards, work, commitment, powers and rites. Check the staged cards and forecast first; closing this explanation does not submit anything.",
		"priority": 90,
		"urgent": true
	},
	"reveal": {
		"id": "reveal",
		"title": "Both plans are revealed",
		"body": "Once both players lock their choices, the commitments are revealed and resolved. Hidden choices are why a planning forecast can differ from the eventual result.",
		"priority": 48,
		"urgent": false
	},
	"recruitment": {
		"id": "recruitment",
		"title": "New recruits wait in staging",
		"body": "Cards committed to an attack recruit at 3:1 printed value per suit; Ward recruits at 2:1. New recruits appear in their lane’s staging area and cannot be marched in their birth round.",
		"priority": 64,
		"urgent": false
	},
	"march": {
		"id": "march",
		"title": "Launch the group you can see",
		"body": "MARCH sends the currently eligible staged group during this round’s closing march. Units recruited this round stay staged; the button does not schedule future recruits to follow them.",
		"priority": 71,
		"urgent": false
	},
	"capacity": {
		"id": "capacity",
		"title": "Staging holds 15 per side, per lane",
		"body": "Each staging area holds up to 15 units for its player. Older eligible reserves may be sent out to make room; a new batch that cannot fit is capped.",
		"priority": 69,
		"urgent": false
	},
	"opening": {
		"id": "opening",
		"title": "Marching during planning",
		"body": "A short opening march plays while you make this round’s choices. It has already been calculated, so taking longer in a modal does not give units extra movement or attacks.",
		"priority": 47,
		"urgent": false
	},
	"closing": {
		"id": "closing",
		"title": "The closing march",
		"body": "After the orders resolve, battlefield units move and fight automatically. The animation shows the calculated battle; skipping it changes the presentation, not the result.",
		"priority": 46,
		"urgent": false
	},
	"fortifications": {
		"id": "fortifications",
		"title": "Wrights defend fortified positions",
		"body": "Field Wrights build walls and, with enough helpers, towers. Repairs require a Wright to move within melee range; when defending a structure they can attack from range, while ordinary field combat stays melee.",
		"priority": 57,
		"urgent": false
	},
	"supplicants": {
		"id": "supplicants",
		"title": "Your unit became a Supplicant",
		"body": "A marcher at the far end of its lane becomes a Supplicant. Unreserved Supplicants are consumed for +1 strength each on your next attack in that lane; you can instead trade five from that lane for a Personal Tear.",
		"priority": 75,
		"urgent": false
	},
	"supplicant_trade": {
		"id": "supplicant_trade",
		"title": "Five Supplicants can become a Tear",
		"body": "Reserve five Supplicants from the same lane in Dominion Rites to gain 1 Personal Tear. Leave them unreserved to strengthen your next attack there; spending them on one purpose removes them from the other.",
		"priority": 80,
		"urgent": false
	},
	"aftermath": {
		"id": "aftermath",
		"title": "See what actually happened",
		"body": "Aftermath lists the actions, defensive layers, losses and rewards from this round. Use it to see why an attack stopped or where its damage went.",
		"priority": 25,
		"urgent": false
	},
	"banishment": {
		"id": "banishment",
		"title": "Banishment is not defeat",
		"body": "Your Lord has been banished, but the match continues. You can review the return cost on Resummon, or stay banished and use the actions still available to you.",
		"priority": 88,
		"urgent": true
	},
	"resummon": {
		"id": "resummon",
		"title": "Bring your Lord back",
		"body": "The Resummon page shows the current payment and resulting Threat before you pay. You may skip it and remain banished; cards reserved for the return cannot also fund other actions.",
		"priority": 85,
		"urgent": false
	},
	"threat": {
		"id": "threat",
		"title": "Threat changed",
		"body": "Threat affects powers and defenses. Most Lords lose 1 Defense at Threat 2, 2 at Threat 3, and 3 at Threat 4 or higher. Kroni uses Hunger for Defense instead, and Humbaba has no Threat. Orias also Hunts harder against a Lord at Threat 2 or higher.",
		"priority": 70,
		"urgent": false
	},
	"restriction": {
		"id": "restriction",
		"title": "Why Guard placement is limited",
		"body": "An active public effect has reduced how many Guards you can place this round. Existing Guards stay in place; the displayed limit applies to new placements.",
		"priority": 99,
		"urgent": true
	},
	"enemy_consume": {
		"id": "enemy_consume",
		"title": "The opponent ate a Guard",
		"body": "The opponent’s Consume removed a Guard rather than defeating it with a normal Hunt or Siege. Check the public power result and the remaining pair badges: losing a member also breaks its Guard pair.",
		"priority": 93,
		"urgent": true
	},
	"allegiance": {
		"id": "allegiance",
		"title": "A unit changed sides",
		"body": "An allegiance effect transferred a unit or Guard to the other player. Its new owner now controls it; this can also break a Guard pair.",
		"priority": 87,
		"urgent": true
	},
	"displacement": {
		"id": "displacement",
		"title": "A power changed a unit’s position",
		"body": "A public power moved or redirected units outside ordinary marching. The effect’s result identifies what changed; a different position can change who they fight next.",
		"priority": 73,
		"urgent": false
	},
	"repair_lock": {
		"id": "repair_lock",
		"title": "Damage can lock out repair",
		"body": "This castle cannot receive ordinary repair while its repair lock is active. Construction and any permitted reconstruction use their own eligibility rules; the work preview shows what your current target can gain.",
		"priority": 76,
		"urgent": false
	},
	"ruin": {
		"id": "ruin",
		"title": "A castle was ruined",
		"body": "A ruined castle loses its ordinary role. Most cannot be repaired back into service; Deimos can reconstruct a ruined Siege Engine, while a Profaned castle remains unavailable.",
		"priority": 73,
		"urgent": false
	},
	"tears": {
		"id": "tears",
		"title": "Personal Tears and the shared Veil",
		"body": "Personal Tears advance your own Dominion position and also increase the shared Veil. Neutral Tears increase the Veil without giving either player that personal progress.",
		"priority": 58,
		"urgent": false
	},
	"profane": {
		"id": "profane",
		"title": "Sacrifice a full castle",
		"body": "Profane sacrifices a full active castle for 1 Personal Tear and takes the place of your combat action. It cannot accompany reserved Ward, and damage before resolution can make the castle ineligible.",
		"priority": 84,
		"urgent": false
	},
	"invocation": {
		"id": "invocation",
		"title": "Spend cards for an Invocation",
		"body": "Invocation is a once-per-game rite with a Veil requirement and a card payment. The rite picker shows whether you qualify and which cards you will spend.",
		"priority": 76,
		"urgent": false
	},
	"profane_ruins": {
		"id": "profane_ruins",
		"title": "Turn a ruin into a Tear",
		"body": "Profane Ruins exchanges a Soul and an eligible ruined castle for a Personal Tear. Review the rite’s displayed cost before adding it to your plan.",
		"priority": 76,
		"urgent": false
	},
	"breach": {
		"id": "breach",
		"title": "A Lord entered the Breach",
		"body": "An absent Lord has joined the Breach and brought a persistent effect to the battle. The Veil display identifies the arrived Lord and current protection; future arrivals remain unknown.",
		"priority": 83,
		"urgent": false
	},
	"breach_wish": {
		"id": "breach_wish",
		"title": "An optional Breach Wish",
		"body": "The Wishmaster’s Breach effect can grant access to a Wish even when Kanifous is not your Lord. A successful Wish still creates a delayed Price, with heavier risks than an ordinary Wish.",
		"priority": 79,
		"urgent": false
	},
	"veil_bonus": {
		"id": "veil_bonus",
		"title": "The Veil strengthens attacks",
		"body": "At Veil 15, 19 and 23, committed Hunt and Siege attacks gain +1, +2 and +3 strength respectively. This does not increase marcher combat stats or the number recruited.",
		"priority": 75,
		"urgent": false
	},
	"late_reward": {
		"id": "late_reward",
		"title": "Decisive attacks are worth more now",
		"body": "From round 20, a Hunt banishment or destruction of the final Siege target earns an extra Soul, at most once per player per round. Partial damage, interception losses, artillery and Pillage do not qualify.",
		"priority": 86,
		"urgent": false
	},
	"near_win": {
		"id": "near_win",
		"title": "A victory condition is close",
		"body": "Souls and Personal Tears can end the match at settlement. Check both players: Ritual needs a living Lord, while Dominion needs the Veil threshold and a strict lead in Personal Tears.",
		"priority": 85,
		"urgent": false
	},
	"deadline": {
		"id": "deadline",
		"title": "The round deadline is close",
		"body": "If neither ordinary victory condition ends the match, round 25 compares Souls. A Soul tie goes to player 1—the first seat, which is you in this playable game.",
		"priority": 96,
		"urgent": true
	},
	"unit:Penitent": {
		"id": "unit:Penitent",
		"title": "Penitents hold the line",
		"body": "Penitents are defensive marchers, especially useful against Vulture fire. Their battlefield role is separate from the protection they provide as Guard cards.",
		"priority": 30,
		"urgent": false
	},
	"unit:Butcher": {
		"id": "unit:Butcher",
		"title": "Butchers are shock troops",
		"body": "Butchers fight at close range and punish enemies they can reach. They need a way past ranged fire to bring that damage to the back line.",
		"priority": 30,
		"urgent": false
	},
	"unit:Vulture": {
		"id": "unit:Vulture",
		"title": "Vultures attack from range",
		"body": "Vultures can damage enemies without standing next to them. A protected firing line is dangerous; reaching or disrupting that line limits its advantage.",
		"priority": 30,
		"urgent": false
	},
	"unit:Wright": {
		"id": "unit:Wright",
		"title": "Wrights support structures",
		"body": "Wrights are modest field fighters whose value grows around fortifications. Building, repairing and defending a position can let them contribute more than their melee damage suggests.",
		"priority": 30,
		"urgent": false
	},
	"power:PredatorOfRuin": {
		"id": "power:PredatorOfRuin",
		"title": "Predator of Ruin",
		"body": "Spawn two Vultures in your chosen lane. Consider where a ranged reinforcement can fire safely and support the rest of your force.",
		"priority": 74,
		"urgent": false
	},
	"power:InevitableRuin": {
		"id": "power:InevitableRuin",
		"title": "Inevitable Ruin",
		"body": "Queue damage to a qualifying enemy castle for the start of next round. The target can change before it fires, so read the eligibility and payment shown in the power controls.",
		"priority": 74,
		"urgent": false
	},
	"power:Rout": {
		"id": "power:Rout",
		"title": "Rout",
		"body": "Make enemies in the chosen lane retreat temporarily. It buys time, and friendly troops already in contact may exploit their retreat.",
		"priority": 74,
		"urgent": false
	},
	"power:WarMachine": {
		"id": "power:WarMachine",
		"title": "War Machine",
		"body": "An operational Siege Engine fires an extra shot at its retained target. Check the engine’s condition and current target before queuing it.",
		"priority": 74,
		"urgent": false
	},
	"power:MusterTheFaithful": {
		"id": "power:MusterTheFaithful",
		"title": "Muster the Faithful",
		"body": "Summon three Penitents into your chosen lane. Use them to reinforce a threatened position or support an advancing group.",
		"priority": 74,
		"urgent": false
	},
	"power:BreathOfLife": {
		"id": "power:BreathOfLife",
		"title": "Breath of Life",
		"body": "Heal friendly marchers in one lane and give them regeneration and movement benefits. Supplicants already waiting at the destination do not receive these benefits.",
		"priority": 74,
		"urgent": false
	},
	"power:Inferno": {
		"id": "power:Inferno",
		"title": "Inferno",
		"body": "Prepare fire for next round on an enemy castle or a lane. Lane fire hits both sides, so check where your own troops will be as well.",
		"priority": 74,
		"urgent": false
	},
	"power:Pyroclasm": {
		"id": "power:Pyroclasm",
		"title": "Pyroclasm",
		"body": "Your current Scorch pulses an extra time this round at its current location and intensity. The ordinary fire still occurs, and Pyroclasm is unavailable the following round.",
		"priority": 74,
		"urgent": false
	},
	"power:Snare": {
		"id": "power:Snare",
		"title": "Snare",
		"body": "Limit the opponent’s new Guard placements next round. It is most useful when that restriction helps a planned Hunt or Siege; check the payment in the power controls.",
		"priority": 74,
		"urgent": false
	},
	"power:Web": {
		"id": "power:Web",
		"title": "The Web",
		"body": "Place the Web where its slow will help your troops or delay a threatening group. Consider enemies approaching the area as well as those already inside it.",
		"priority": 74,
		"urgent": false
	},
	"power:Redirect": {
		"id": "power:Redirect",
		"title": "Redirect",
		"body": "Marchers from both sides inside the chosen circle move to the other lane after combat. Check the whole group before locking the placement.",
		"priority": 74,
		"urgent": false
	},
	"power:FalseOrders": {
		"id": "power:FalseOrders",
		"title": "False Orders",
		"body": "Move one Guard to its owner’s other zone before next round’s deployment. This can open a defense or reposition one of your own Guards.",
		"priority": 74,
		"urgent": false
	},
	"power:AllegianceShift": {
		"id": "power:AllegianceShift",
		"title": "Allegiance Shift",
		"body": "Enemy marchers inside the selected circle become yours after combat. Place the smaller target area carefully, and check the Reconfiguration cost before locking.",
		"priority": 74,
		"urgent": false
	},
	"power:Inversion": {
		"id": "power:Inversion",
		"title": "Inversion",
		"body": "Flip eligible Guards to the opposite player’s matching zone next round. Either side can be targeted, and a successful transfer adds a Neutral Tear.",
		"priority": 74,
		"urgent": false
	},
	"power:Consume": {
		"id": "power:Consume",
		"title": "Consume",
		"body": "Activate Consume to send Kroni from the neutral center at next round start. He bounces until he eats a Guard, which can be yours; you do not select a target. An enemy meal gains Hunger. A friendly meal prevents his automatic feeding penalty but adds no Hunger.",
		"priority": 74,
		"urgent": false
	},
	"power:Ravenous": {
		"id": "power:Ravenous",
		"title": "Ravenous",
		"body": "Place Kroni’s entry point to launch his battlefield attack. He can devour friendly troops too, so consider the whole route and inspect his card for the current Hunger and reward rules.",
		"priority": 74,
		"urgent": false
	},
	"power:Projection": {
		"id": "power:Projection",
		"title": "Projection",
		"body": "Reserve Essence and choose a Guard zone. After combat, Projection defeats its highest-value Guard at or below your spend. You can target either side: sacrificing your own Guard returns 2 Essence while Valak is active. Reserved Essence cannot shield a Hunt, and a miss still spends it.",
		"priority": 74,
		"urgent": false
	},
	"power:GravityOrb": {
		"id": "power:GravityOrb",
		"title": "Gravity Orb",
		"body": "Place the orb where its pull will influence the fight. Think about the position it creates for both sides, not just the units currently closest to it.",
		"priority": 74,
		"urgent": false
	},
	"power:WishPower": {
		"id": "power:WishPower",
		"title": "Wish for Power",
		"body": "Choose a lane for new marchers. A successful Wish creates a delayed Price; the exact debt is hidden until it is collected.",
		"priority": 74,
		"urgent": false
	},
	"power:WishLongevity": {
		"id": "power:WishLongevity",
		"title": "Wish for Longevity",
		"body": "Choose an eligible damaged active castle for the displayed repair. A successful Wish creates a delayed Price.",
		"priority": 74,
		"urgent": false
	},
	"power:WishResurrection": {
		"id": "power:WishResurrection",
		"title": "Wish for Resurrection",
		"body": "Choose a lane to bring back your marchers killed there this round after Marching. Guard cards and losses from earlier rounds do not qualify, and a successful Wish creates a Price.",
		"priority": 74,
		"urgent": false
	},
	"power:WishDeath": {
		"id": "power:WishDeath",
		"title": "Wish for Death",
		"body": "Destroy marchers inside the chosen small area, including friendlies. Check the placement carefully; a successful Wish creates a delayed Price.",
		"priority": 74,
		"urgent": false
	},
	"power:WishWealth": {
		"id": "power:WishWealth",
		"title": "Wish for Wealth",
		"body": "Gain cards through the Wish, with a delayed Price to pay later. More choices now can still carry a future cost.",
		"priority": 74,
		"urgent": false
	},
	"passive:bones": {
		"id": "passive:bones",
		"title": "Gremory picked the bones",
		"body": "Once per round, a kill by Gremory’s Vulture draws a card. A Predator of Ruin Vulture can also earn one Personal Tear in its lifetime after two enemy kills while Gremory is alive, with at most one such Tear per round. A Vulture blocked by that limit needs another kill in a later round.",
		"priority": 62,
		"urgent": false
	},
	"passive:ruins": {
		"id": "passive:ruins",
		"title": "Gremory sifted the ruins",
		"body": "The first castle destroyed each round lets Gremory take the top discarded card into hand. The castle does not have to be destroyed by Gremory.",
		"priority": 62,
		"urgent": false
	},
	"passive:fear": {
		"id": "passive:fear",
		"title": "Deimos drove Guards away",
		"body": "Deimos’s Fear Aura returns the lowest-value enemy Castle Guards to their owner’s hand before the Siege: one Guard, plus one for each point of Deimos’s Threat. Returned Guards no longer defend the attack.",
		"priority": 62,
		"urgent": false
	},
	"passive:endurance": {
		"id": "passive:endurance",
		"title": "Humbaba rewarded a survivor",
		"body": "At the end of Marching, an active Humbaba adds a Neutral Tear if at least one of his Penitents has exactly 1 HP. Keeping a wounded Penitent alive can therefore matter.",
		"priority": 62,
		"urgent": false
	},
	"passive:forge": {
		"id": "passive:forge",
		"title": "Kalligan repaired a castle",
		"body": "At round start, Kalligan restores 2 Integrity to each damaged standing castle he owns. Ruined and Profaned castles cannot receive this repair.",
		"priority": 62,
		"urgent": false
	},
	"passive:interlock": {
		"id": "passive:interlock",
		"title": "Odradek reflected a killing blow",
		"body": "Once per round, when an enemy marcher kills one of Odradek’s marchers, Psychic Interlock reflects the killing attack’s damage onto the attacker. Armor applies, and the original death still happens.",
		"priority": 62,
		"urgent": false
	},
	"passive:reconfiguration": {
		"id": "passive:reconfiguration",
		"title": "Odradek gained Reconfiguration",
		"body": "Odradek gains 1 Reconfiguration each round while active, up to 4. It pays for his powers; banishment empties the pool.",
		"priority": 62,
		"urgent": false
	},
	"passive:hunger": {
		"id": "passive:hunger",
		"title": "Kroni’s Hunger changed",
		"body": "Hunger determines Kroni’s Defense: 4 at zero, 6 at one or two, and 8 at three or more. Ward or Pass loses 1 Hunger. The first time he reaches 3 in a match earns a Personal Tear.",
		"priority": 62,
		"urgent": false
	},
	"passive:cannibal": {
		"id": "passive:cannibal",
		"title": "Kroni fed on his own Guard",
		"body": "If the round-start Consume check does not feed Kroni, he devours his own lowest-value Guard. This does not increase Hunger. If he has no Guard to eat, he loses 1 Hunger instead.",
		"priority": 62,
		"urgent": false
	},
	"passive:essence": {
		"id": "passive:essence",
		"title": "Valak’s Essence pool",
		"body": "Valak gains 2 Essence from enemy Guards defeated by his Hunt or Siege, up to a pool of 5. Unreserved Essence absorbs incoming Hunt strength after Ward. Projection can instead reserve it for an attack or a friendly sacrifice.",
		"priority": 62,
		"urgent": false
	},
	"passive:price": {
		"id": "passive:price",
		"title": "The Wish’s Price came due",
		"body": "A successful Wish creates a hidden Price due one to three rounds later. Its due round is public; its exact cost is revealed when collected. If nothing can be collected, the debt remains for a later round.",
		"priority": 62,
		"urgent": false
	},
	"passive:accelerate": {
		"id": "passive:accelerate",
		"title": "Orias increased the enemy’s Threat",
		"body": "The first enemy Lord Guard Orias defeats each round adds 1 Threat to that Lord. Higher Threat can weaken their Defense and make Orias’s next Hunt stronger.",
		"priority": 62,
		"urgent": false
	}
}

static func split(world: Dictionary) -> bool:
	return world.get("ward_experiment") == "U13_SPLIT_WARD_V1"

static func tempo(world: Dictionary) -> bool:
	return world.get("tempo_experiment") == "U13_VEIL_ATTACK_ROUND25_V1"

static func lesson(id: String, world: Dictionary = {}) -> Dictionary:
	var row: Dictionary = ENTRIES.get(id, {}).duplicate(true)
	if row.is_empty() and id.begins_with("unit:"):
		var monster: String = id.trim_prefix("unit:")
		if Monsters.ROSTER.has(monster):
			row = {"id": id, "title": monster + " on the battlefield", "body": str(Monsters.ROSTER[monster].ability), "priority": 31, "urgent": false}
	if row.is_empty() and id.begins_with("lord:"):
		var lord: String = id.trim_prefix("lord:")
		if LordText.RULES.has(lord):
			row = {"id": id, "title": lord + " · abilities", "body": LordText.for_lord(lord).passive, "priority": 35, "urgent": false}
	if id == "lord:Valak": row.body = ENTRIES["passive:essence"].body + "\n\n" + ENTRIES["power:Projection"].body
	if id == "objective":
		row.body = "At the end of a round, %d Souls wins if your Lord is alive. You can also win through Dominion: reach %d Personal Tears, lead your opponent in Tears, and have the shared Veil at %d or more." % [Victory.RITUAL_SOULS, Victory.DOMINION_TEARS, Victory.DOMINION_VEIL]
		row.body += (" If neither route wins first, round %d compares Souls; a tie goes to the first seat (you)." % Victory.round_limit(world.get("victory", {}))) if tempo(world) else " In this saved ruleset, Final Collapse at Veil 26 compares Souls; a tie goes to the first seat (you)."
	if id == "deadline": row.body = row.body.replace("round 25", "round %d" % Victory.round_limit(world.get("victory", {})))
	if world.get("victory", {}).has("round_limit"):
		if id in ["deadline", "objective"]:
			row.body = row.body.split(" A Soul tie")[0].replace("; a tie goes to the first seat (you).", ".") + " Ties compare Personal Tears, then active standing Castles, then whether the Lord is alive. Only a complete tie goes to the first seat."
		if id == "late_reward": row.body = row.body.replace("round 20", "round 17")
	if id == "forecast" and world.has("guard_work"):
		row.body = "The forecast uses the board you can currently see; hidden enemy choices and later powers can change the outcome. Every suit contributes its full printed value to Hunt, Siege and Ward. There is no off-suit strength penalty in this ruleset."
	if id == "ward" and not split(world):
		row.body = "In this saved ruleset, Ward gives full protection in its chosen lane and half in the other. It recruits at 2:1 and uses the older Sigil rules; the new separate attack-and-Ward option is not active."
	return row

static func book(world: Dictionary) -> Array:
	var rows: Array = []
	for id in ENTRIES:
		if id == "embolden" and not world.get("embolden_ramp_experiment", false): continue
		if id == "ward_conversion" and world.get("ward_conversion_experiment") != "regular": continue
		if id in ["split_ward", "ward_reward"] and not split(world): continue
		if id in ["veil_bonus", "late_reward", "deadline"] and not tempo(world): continue
		rows.append(lesson(id, world))
	for name in Monsters.NAMES: rows.append(lesson("unit:" + name, world))
	for name in LordText.RULES: rows.append(lesson("lord:" + name, world))
	rows.sort_custom(func(a, b): return a.title < b.title)
	return rows

static func _add(rows: Array, id: String, w: Dictionary, detail: String = "") -> void:
	var entry: Dictionary = lesson(id, w)
	if entry.is_empty(): return
	if not detail.is_empty(): entry.body += "\n\n" + detail
	rows.append(entry)

# This accepts only public UI context. No match, hidden hand, future arrivals,
# pending enemy orders, RNG, or authority snapshot is consulted here.
static func opening_march_visible(c: Dictionary) -> bool:
	var number: int = int(c.get("round", 1))
	if number < 2 or not c.get("opening", false): return false
	# An opening tape can exist with empty lanes. Only its currently visible,
	# living, movement-ready Marchers count; reserves and Supplicants do not.
	for unit in c.get("visible_units", []):
		var a: Dictionary = unit.get("attributes", {})
		if unit.get("kind", "marcher") != "marcher": continue
		if int(a.get("hp", 0)) <= 0 or a.get("waiting", false): continue
		if int(a.get("movement_ready_round", number)) > number: continue
		return true
	return false

static func candidates(c: Dictionary) -> Array:
	var rows: Array = []
	var w: Dictionary = c.get("world", {})
	var number: int = int(c.get("round", 1))
	var phase: String = c.get("phase", "")
	var planning: bool = c.get("planning", false)
	var order: Dictionary = c.get("order", {})
	var action: String = order.get("action", "")
	var intent: String = c.get("intent", "")
	var entities: Array = w.get("entities", [])
	var by_id: Dictionary = {}
	for entity in entities: by_id[entity.id] = entity
	var embolden_detail: String = _embolden_detail(c)
	if not embolden_detail.is_empty(): _add(rows, "embolden", w, embolden_detail)
	if c.get("board_entry", false): _add(rows, "objective", w)
	if phase == "Stockpile": _add(rows, "stockpile", w)
	if phase == "Slaver": _add(rows, "slaver", w)
	if planning:
		if not order.get("card_ids", []).is_empty() or not order.get("guard_moves", []).is_empty() or not c.get("powers", []).is_empty(): _add(rows, "subjects", w)
		if phase == "Guards":
			_add(rows, "guards", w)
			var limit: int = int(w.get("guard_placement_limits", [6, 6])[0])
			if limit < 6:
				var snared: bool = int(w.get("snare_rounds", [0, 0])[0]) == number
				_add(rows, "restriction", w, ("The opponent's Snare is active this round." if snared else "A public Breach effect limits your deployment.") + " You may place %d new Guards in total." % limit)
		var pairs: Dictionary = {}
		for move in order.get("guard_moves", []):
			var suit: String = by_id.get(move.get("card_id", ""), {}).get("attributes", {}).get("suit", "")
			var key: String = str(move.get("lane", "")) + ":" + suit
			pairs[key] = int(pairs.get(key, 0)) + 1
			if pairs[key] == 2: _add(rows, "pair:" + suit, w)
		var target_id: String = str(order.get("castle_action", {}).get("target_id", ""))
		var target: Dictionary = by_id.get(target_id, {}).get("attributes", {})
		if not target.is_empty():
			if order.castle_action.get("action") == "Activate": _add(rows, "commission", w)
			elif int(target.get("integrity", 0)) < int(target.get("max_integrity", 0)):
				_add(rows, "work", w)
				if int(target.get("repair_lock_until_round", 0)) >= number and target.get("construction_state") == "active" and target.get("status") != "ruined": _add(rows, "repair_lock", w)
		if phase == "Resummon": _add(rows, "resummon", w)
		if phase == "Combat": _add(rows, "commitment", w)
		if action in ["Hunt", "Siege", "Ward"]:
			_add(rows, "pillage" if c.get("pillage", false) and action == "Siege" else action.to_lower(), w)
			if not order.get("card_ids", []).is_empty(): _add(rows, "forecast", w)
			if action == "Hunt":
				var victim: Dictionary = by_id.get(order.get("target_id", ""), {})
				if int(victim.get("attributes", {}).get("fracture", 0)) > 0: _add(rows, "fracture", w)
			if action in ["Hunt", "Siege"]:
				for castle in entities:
					var a: Dictionary = castle.get("attributes", {})
					if castle.get("owner") == 1 and castle.get("kind") == "castle" and a.get("status") == "standing" and a.get("construction_state") == "active" and a.get("castle_type") == ("Keep" if action == "Hunt" else "Bastion") and castle.id != order.get("target_id", ""):
						_add(rows, "interception", w); break
		if split(w) and (action == "Ward" or order.has("ward")):
			_add(rows, "split_ward", w)
			if w.get("ward_conversion_experiment") == "regular": _add(rows, "ward_conversion", w)
		if phase == "Lord Powers": _add(rows, "lord_inspection", w)
		if phase == "Dominion Rites": _add(rows, "resolve", w)
		if action == "Profane": _add(rows, "profane", w)
		for rite in order.get("rites", {}):
			_add(rows, {"waiter_spends": "supplicant_trade", "invocation": "invocation", "profane_ruins": "profane_ruins"}.get(rite, ""), w)
		if intent == "Profane": _add(rows, "profane", w)
		for power in c.get("powers", []): _add(rows, "power:" + str(power.get("power_id", "")).trim_prefix("Breach"), w)
		_add(rows, "power:" + intent, w)
		if c.get("breach_wish", false) and phase == "Lord Powers": _add(rows, "breach_wish", w)
		if tempo(w) and phase in ["Combat", "Dominion Rites"]:
			if int(w.get("veil_total", 0)) >= 15: _add(rows, "veil_bonus", w)
			if number >= (17 if w.get("victory", {}).has("round_limit") else 20): _add(rows, "late_reward", w)
			if number >= Victory.round_limit(w.get("victory", {})) - 1: _add(rows, "deadline", w)
		for player in w.get("players", []):
			var r: Dictionary = player.get("resources", {})
			if int(r.get("souls", 0)) >= Victory.RITUAL_SOULS - 2 or (int(r.get("personal_tears", 0)) >= Victory.DOMINION_TEARS - 1 and int(w.get("veil_total", 0)) >= 10):
				_add(rows, "near_win", w); break
	if c.get("grimoire_interest", false): _add(rows, "grimoires", w)
	if c.get("summon_choice", false): _add(rows, "summon", w)
	if c.get("aftermath", false): _add(rows, "aftermath", w)
	if opening_march_visible(c): _add(rows, "opening", w)
	if c.get("closing", false): _add(rows, "closing", w)
	var waiters: Dictionary = {"Lord": 0, "Castle": 0}
	for unit in c.get("visible_units", []):
		var a: Dictionary = unit.get("attributes", {})
		_add(rows, "unit:" + str(a.get("monster_id", a.get("suit", ""))), w)
		if unit.get("owner") == 0 and a.get("waiting", false):
			waiters[str(a.get("lane", "Castle"))] += 1
	for lane in waiters:
		if waiters[lane] > 0: _add(rows, "supplicants", w)
		if waiters[lane] >= 5 and planning: _add(rows, "supplicant_trade", w, "%s lane: %d available Supplicants." % [lane, waiters[lane]])
	if not c.get("visible_structures", []).is_empty(): _add(rows, "fortifications", w)
	# A real reserve is visible now, not a future recruitment event in a tape.
	if not c.get("closing", false) and not c.get("opening", false):
		for lane in w.get("game_staging", {}).get("lanes", {}):
			var own: Array = w.game_staging.lanes[lane].get("units", []).filter(func(u): return u.owner == 0)
			if not own.is_empty(): _add(rows, "recruitment", w)
			if own.any(func(u): return int(u.attributes.get("staged_round", number)) < number) and planning: _add(rows, "march", w)
			if own.size() >= 13 and planning: _add(rows, "capacity", w)
	for event in c.get("events", []):
		var d: Dictionary = event.get("data", {})
		var passive: String = {"PICKING_THE_BONES": "bones", "SIFTING_THE_RUINS": "ruins", "FORGE_REPAIR": "forge", "PSYCHIC_INTERLOCK": "interlock", "RECONFIGURATION_GAINED": "reconfiguration", "KRONI_HUNGER_CHANGED": "hunger", "VALAK_ESSENCE_GAINED": "essence", "VALAK_ESSENCE_REINFORCED": "essence", "KANIFOUS_PRICE_RESOLVED": "price", "KANIFOUS_PRICE_DEFERRED": "price", "ACCELERATE": "accelerate"}.get(event.get("type", ""), "")
		if not passive.is_empty(): _add(rows, "passive:" + passive, w)
		match event.get("type", ""):
			"FEAR_AURA":
				if not d.get("returned_ids", []).is_empty(): _add(rows, "passive:fear", w)
			"ENDURANCE_CHECKED":
				if d.get("threshold_met", false): _add(rows, "passive:endurance", w)
			"WARD_RECRUITS_CONVERTED":
				var count: int = int(d.get("regular_count", 0))
				if count > 0 and w.get("ward_conversion_experiment") == "regular":
					# A real transfer outranks ordinary introductions, within the same cap.
					rows = rows.filter(func(row): return row.id != "ward_conversion")
					var claimant: String = "You" if int(d.get("player_id", -1)) == 0 else "The opponent"
					_add(rows, "ward_conversion", w, "%s claimed %d recruits in the %s lane this round. They now fight for the defender." % [claimant, count, d.get("lane", "")])
					rows[-1].priority = 98
					rows[-1].urgent = true
			"WARD_SOUL_GAINED":
				if split(w): _add(rows, "ward_reward", w)
			"COMBAT_ORDER_REVEALED": _add(rows, "reveal", w)
			"GUARD_DEVOURED":
				if int(d.get("player_id", -1)) == 1 and int(d.get("before", {}).get("owner", -1)) == 0: _add(rows, "enemy_consume", w)
				if d.get("cause") == "Cannibal Hunger": _add(rows, "passive:cannibal", w)
			"MARCHER_ALLEGIANCE_CHANGED": _add(rows, "allegiance", w)
			"GUARD_RECONFIGURED":
				_add(rows, "allegiance" if d.get("before", {}).get("owner") != d.get("after", {}).get("owner") else "displacement", w)
			"REDIRECT_RESOLVED":
				if not d.get("changes", []).is_empty(): _add(rows, "displacement", w)
			"LORD_BANISHED":
				if int(d.get("lord", {}).get("owner", -1)) == 0: _add(rows, "banishment", w)
			"CASTLE_DESTROYED": _add(rows, "ruin", w)
			"VEIL_LORD_ARRIVED":
				var lord: String = str(d.get("lord_id", ""))
				_add(rows, "breach", w, lord + ": " + str(LordText.for_lord(lord).breach))
			"NEUTRAL_TEAR_CREATED", "PERSONAL_TEAR_CREATED": _add(rows, "tears", w)
			"STAGING_OVERFLOW_RELEASED", "STAGING_RECRUITMENT_CAPPED": _add(rows, "capacity", w)
	if c.has("threat_change"):
		var change: Dictionary = c.threat_change
		_add(rows, "threat", w, "%s: %d → %d. %s" % [change.lord, change.before, change.after, change.get("reason", "See the public round result for its cause.")])
	return rows

# Observe actual public buffs. Guard-page warnings use only public vacancy history
# and the player's planned placements; never inspect enemy orders or future frames.
static func _embolden_detail(c: Dictionary) -> String:
	var w: Dictionary = c.get("world", {})
	if not w.get("embolden_ramp_experiment", false): return ""
	for unit in c.get("visible_units", []):
		var a: Dictionary = unit.get("attributes", {})
		var percent: int = int(a.get("_embolden_percent", 0))
		if percent > 0:
			return "%s marchers in the %s lane currently have a +%d%% bonus from the opposing Guard slots." % ["Your" if unit.get("owner") == 0 else "Enemy", a.get("lane", ""), percent]
	if not c.get("planning", false) or c.get("phase") != "Guards": return ""
	var history: Array = w.get("embolden_guard_history", {}).get("slots", [])
	if history.size() != 2: return ""
	for lane in ["Lord", "Castle"]:
		var filled: Array = []
		for row in w.get("entities", []):
			var a: Dictionary = row.get("attributes", {})
			if row.get("owner") == 0 and a.get("role") == "guard" and a.get("lane") == lane: filled.append(a.get("slot"))
		for move in c.get("order", {}).get("guard_moves", []):
			if move.get("lane") == lane: filled.append(move.get("slot"))
		var slots: Array = history[0].get(lane, [])
		for slot in range(slots.size()):
			if slot not in filled and int(slots[slot].get("age", 0)) > 0:
				return "Your %s zone has a Guard slot left empty long enough to empower enemy marchers. You can assign a Guard before locking this round." % lane
	return ""
