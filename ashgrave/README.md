# Ashgrave

Open-world isometric RPG in Godot 4.3 (GDScript). Dark low fantasy: Maren Vey, a deserter scout, leads a party of up to four across a procedurally generated plague province.

Status: **Milestone 1 (foundation)**. Seeded chunk-streamed world, party selection and movement, tactical pause, day/night cycle.

## Run
Open this folder in Godot 4.3 and press F5.

| Input | Action |
| --- | --- |
| Left-click / drag | Select members |
| Right-click | Move selection (in formation) |
| 1–3, Tab | Select one member / everyone |
| Space | Tactical pause (orders still work) |
| WASD, wheel | Pan, zoom |

## Tests
```sh
godot --headless --path . -s res://tests/run_tests.gd
```
Screenshot (needs a display, e.g. `xvfb-run`): `OUT=/tmp/shot.png TOD=0.45 godot --path . -s res://tests/screenshot.gd`
