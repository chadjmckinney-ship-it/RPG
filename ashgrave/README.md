# Ashgrave

Open-world isometric RPG in Godot 4.3 (GDScript). Dark low fantasy: Maren Vey, a deserter scout, leads a party of up to four across a procedurally generated plague province.

Status: **Milestone 4 (quests & dialogue)**. Seeded world with villages, real-time party combat with tactical pause, gathering, crafting, trading, factions, save/load, branching dialogue, a two-part main story with a three-way ending choice, generated side quests, and recruitable companions with their own quests.

## Run
Open this folder in Godot 4.3 and press F5.

| Input | Action |
| --- | --- |
| Left-click / drag | Select members |
| Right-click | Move selection (in formation), or attack the enemy under the cursor |
| Shift + right-click | Queue the order after current ones |
| Q / E | First selected member's abilities (targeted ones wait for a left-click) |
| 1–3, Tab | Select one member / everyone |
| Space | Tactical pause (orders still work). Auto-pauses when enemies spot you or someone is badly hurt |
| Right-click a villager | Talk: story, recruitment, work (side quests) and trade. Number keys pick replies |
| Right-click a herb, ore seam or deadwood | Gather it |
| I | Pack: items, gear, crafting, quests, factions |
| J | Quest log (pick which quest the on-screen arrow tracks) |
| F5 / F9 | Save / load |
| WASD, wheel | Pan, zoom |

## Tests
```sh
godot --headless --path . -s res://tests/run_tests.gd
```
Screenshots (need a display; also `tests/screenshot_combat.gd`, e.g. `xvfb-run`): `OUT=/tmp/shot.png TOD=0.45 godot --path . -s res://tests/screenshot.gd`

## Story
Start by talking to **Warden Maud** in the village where you begin. Brother Oswin waits in the same village's tavern; Ketta is with Old Nessa in the nearest Hollow Folk village. Trade-folk offer side work (bounties, barrow clearing, supplies, letters, quarrels) built from whatever is nearby in your world.
