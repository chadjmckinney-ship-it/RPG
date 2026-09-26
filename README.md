# Emberfall

A small, complete top-down RPG that runs in the browser with no build step and no dependencies.

Something crawled out of Cinder Hollow and stole the Hearthfire that keeps the village of Hollowmere alive. Find the wardens' key in the Gloamwood, open the sealed Hollow, and take the fire back from the Ember Wyrm.

## Play

Open `index.html` in a browser, or serve the folder:

```sh
python3 -m http.server 8000   # then visit http://localhost:8000
```

| Action | Keyboard | Touch |
| --- | --- | --- |
| Move | Arrows / WASD | D-pad |
| Talk, open, confirm | Enter / Space / Z | A |
| Back, open menu | Esc / X | B |
| Menu | M | MENU |

Progress saves to `localStorage` from the menu, or when you rest at the inn.

## What's in it

- **Three classes** (Knight, Mage, Rogue), each with five skills learned by level 10 and its own weapon line
- **Nine maps**: Hollowmere and four interiors, the Rivermarch overworld, the Gloamwood, and two floors of Cinder Hollow
- **Turn-based battles**: fire, ice and arcane weaknesses; poison, burn, slow and stun; buffs; crits; defend and flee
- **Two bosses**, the Thornback Alpha and the Ember Wyrm (which enrages at half health)
- **Two quests**, shops, an inn, a healing spring, chests, equipment comparison and a Phoenix Feather auto-revive
- A procedural pixel-art renderer (no image files), a WebAudio chiptune soundtrack, cave lighting, snow that turns to embers after the ending

## Layout

| File | Contents |
| --- | --- |
| `js/data.js` | Classes, skills, items, enemies, XP curve |
| `js/maps.js` | ASCII maps, warps, chests, NPC dialogue scripts, quests |
| `js/gfx.js` | Palette-string sprites and procedurally painted tiles |
| `js/audio.js` | Chiptune sequencer and sound effects |
| `js/ui.js` | Input focus stack, dialogue, menus, shop, title screen |
| `js/engine.js` | World state, movement, interaction, saving, rendering |
| `js/battle.js` | Battle flow, damage formulas, enemy AI, battle rendering |
| `js/main.js` | Boot, main loop, keyboard and touch wiring |

Maps are plain strings: digits are warps, lowercase letters are NPCs, and `C`/`S` chests and signs are filled in reading order from each map's `chests`/`signs` arrays.
