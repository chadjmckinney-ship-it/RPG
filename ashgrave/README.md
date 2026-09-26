# Ashgrave

Open-world isometric RPG in Godot 4.3 (GDScript). Dark low fantasy: Maren Vey, a deserter scout, leads a party of up to four across a procedurally generated plague province.

Status: **Milestone 2 (combat core)**. Seeded chunk-streamed world, party control, real-time combat with tactical pause and queued orders, 4 creature types in seeded camps, 6 abilities, day/night cycle.

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
| WASD, wheel | Pan, zoom |

## Tests
```sh
godot --headless --path . -s res://tests/run_tests.gd
```
Screenshots (need a display; also `tests/screenshot_combat.gd`, e.g. `xvfb-run`): `OUT=/tmp/shot.png TOD=0.45 godot --path . -s res://tests/screenshot.gd`
