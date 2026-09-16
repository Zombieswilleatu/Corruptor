# Live marching sprites

The playable U13 board draws Butcher, Penitent, Vulture and Wright using the
approved still poses and Godot motion from the animation gallery. The clash
window uses the same art. Sprite feet remain at the recorded world position;
depth sorting does not repack or move units. The live battlefield is 435 layout
pixels wide, 50% wider than the original 290 px sidebar. A thin outer foot ring
always shows ownership. The inner ring uses green for HP and pale steel for
Armor, with a dark track showing depleted portions. HP and Armor occupy separate
segments; losing one does not enlarge the other. Void still limits displayed
HP precision. There is no separate rectangular sprite health bar.

The field and clash-window terrain have a 50% dark overlay so unit silhouettes
read above it. Floating HP/Armor amounts, their source labels, the `NEW` label
and the extra clash outline are omitted. Damage uses the sprite's brief flash
and recoil together with the changing inner ring. Newly arriving units brighten
gently once over 0.8 seconds; opening a board/save does not flash existing units.
The distinct `SUPPLICANT` waiting-state label remains.

Armor has no authoritative maximum in the current unit contract. Its visual
capacity remembers the highest observed value for that unit (or an optional
future `max_armor`); a newly loaded save starts from its available Armor data.
This cosmetic capacity is never written into saves or game entities.

`U13MarcherSpriteCatalog` shares the preview's measured crops, anchors, masks
and body scale through `build_frames`. The game uses bundled assets, including
the approved Penitent and Sinodek stills. Textures and extracted poses are
cached per character. External sheet overrides remain a preview feature.

`U13MarcherSpriteVisuals` keeps cosmetic state by entity ID. Recorded movement
drives the march gesture; stationary, waiting and birth-held units idle. Clash
membership drives attack gestures, and Vulture's recorded ranged cooldown
change triggers its casting gesture. These gestures do not determine hit
timing or damage. Existing feedback flashes/recoils the sprite, while deaths
fade it alongside the existing ghost. Rout, Paradox slices, projectile paths,
targeting geometry and authoritative playback remain in place.

## Future monster contract

A future monster can use the existing `kind: "marcher"` presentation contract
(ID, owner, lane, position, HP/max HP, waiting and movement-ready round) with
`attributes.monster_id` set to a recipe name below. An optional
`attributes.sprite_id` overrides its art explicitly. Names are case insensitive.

| Recipe name | Current art |
| --- | --- |
| Lemek | Lemek |
| Varn | Ratton |
| Fyra | Pixie |
| Kopita | Kopita |
| Tumler | Dogger |
| Kurchin | BottleTree |
| Muno | Wraith |
| Dotra | Batboy, with grounded skitter |
| Sooge | Sooge |
| Sinodek | Approved transparent pixel still |

For Sooge, changing `attributes.sprite_form` to `"turret"` plays the existing
six-frame transformation once and keeps the rooted pose. A unit first loaded
already in turret form starts in the final pose. This is only a visual hook;
future rules must enforce permanent rooting, movement and combat stats.

Unknown art falls back to a marker; missing subject art can use its original
chit. This change does not create monsters, summon recipes, abilities, save
fields or simulation rules. Resetting the board clears all per-entity sprite
state. Full frame animation can replace this presentation later.

## Checks

Run `Scripts/Sim/U13MarcherSpritesTestRunner.gd` headlessly for asset mappings,
motion/feedback, input immutability, future monster forms, board drawing,
casualties, reset and a 48-unit field. `U13StillSpritePreviewTestRunner.gd`
checks that the shared extraction keeps all 14 gallery entries working.

Local diagnostic results (Godot 4.5.1): sprite integration, all 14 previews,
rout visuals and marcher feedback pass; the complete playable board compiles.
The existing Vulture ranged suite reports one failure, `one attack per eight
ticks`, both with this change and with the unchanged parent renderer. Its
projectile and board integration checks pass. Godot 4.7.2 remains the game's
authoritative runtime; interactive visual review remains necessary.
