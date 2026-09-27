# Ashgrave

Open-world isometric RPG in Godot 4.3 (GDScript). Dark low fantasy: Maren Vey, a deserter scout, leads a party of up to four across a procedurally generated plague province.

Status: **Milestone 5 (content & polish)**. Seeded world of 6 biomes and villages; 11 creature types and 2 bosses; pausable real-time party combat; gathering, crafting, trading, factions; branching dialogue, a main story with a three-way ending, generated side quests, two recruitable companions; procedural music and sound; title screen, world map, settings; save/load; browser build.

## Run
- **Browser:** the exported build lives in `docs/play/`. Turn on GitHub Pages for this branch's `/docs` folder, or serve `docs/` with any static web server, and open `play/`.
- **Godot:** open this folder in Godot 4.3 and press F5.
- **Rebuild the web version:** `godot --headless --path . --export-release "Web" ../docs/play/index.html` (needs the 4.3 web export template).

| Input | Action |
| --- | --- |
| Left-click / drag | Select members |
| Right-click | Move selection (in formation), or attack the enemy under the cursor |
| Shift + right-click | Queue the order after current ones |
| Q / E / R | First selected member's abilities (R unlocks at level 5; targeted ones wait for a left-click) |
| 1–3, Tab | Select one member / everyone |
| Space | Tactical pause (orders still work). Auto-pauses when enemies spot you or someone is badly hurt |
| Right-click a villager | Talk: story, recruitment, work (side quests) and trade. Number keys pick replies |
| Right-click a herb, ore seam or deadwood | Gather it |
| I | Pack: items, company (level and talents), gear, crafting, quests, factions |
| J | Quest log (pick which quest the on-screen arrow tracks) |
| F5 / F9 | Save / load |
| M | World map |
| Esc | Menu: save, load, settings, quit |
| WASD, wheel | Pan, zoom |

## Tests
```sh
godot --headless --path . -s res://tests/run_tests.gd
```
Screenshots (need a display; also `tests/screenshot_combat.gd`, e.g. `xvfb-run`): `OUT=/tmp/shot.png TOD=0.45 godot --path . -s res://tests/screenshot.gd`

## Leveling
The whole company shares one level (1–10) earned from kills, cleared camps and quests; late recruits join at the party's level. Each level raises stats; at levels 2, 4, 6, 8 and 10 every companion picks one of two talents (pack → Company), and at level 5 each gains a third ability (Maren: Cleave, Oswin: Sanctuary, Ketta: Volley). Enemies don't scale with you: camps farther from the start are ranked **Hardened (Lv 4)**, **Dread (Lv 7)** and **Elder (Lv 10)**, tougher and worth more XP. The Drowned Lord fights at Lv 4, the Ashen Knight at Lv 7.

## Story
Start by talking to **Warden Maud** in the village where you begin. Brother Oswin waits in the same village's tavern; Ketta is with Old Nessa in the nearest Hollow Folk village. Trade-folk offer side work (bounties, barrow clearing, supplies, letters, quarrels) built from whatever is nearby in your world.

## Balance
`tests/balance.gd` stages fights in the real game at 8x speed and prints win rate, fight length and health left, for Maren alone against early threats, the full party against every camp type, a geared party against both bosses, and levelled parties against ranked camps and bosses (by day and night):
```sh
godot --headless --path . -s res://tests/balance.gd        # RUNS=n, ONLY=<name filter>, DEBUG=1
```
