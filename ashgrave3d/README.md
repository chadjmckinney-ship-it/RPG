# Ashgrave 3D

Real-time 3D rebuild of Ashgrave in **Godot 4.7.2** (GDScript, Forward+). Maren Vey's company crosses a procedurally generated plague province with pausable real-time party combat. Characters are Meshy/Blender `.glb` models; see `docs/BLENDER_EXPORT.md` for how to add them.

## Run
Open this folder in Godot 4.7.2 and press F5. Without Vulkan, Godot falls back to OpenGL (Compatibility) automatically.

Controls are shown along the bottom of the screen:
- **Right-click:** move, attack, talk, or gather.
- **Q / E / R:** abilities.
- **Space:** pause.
- **I / J / M:** pack, quests and map.
- **F5 / F9:** save and load.
- **Esc:** menu.
- **Camera:** WASD, the wheel, middle-drag, or Z / C.

## Tests
```sh
godot --headless --path . -s res://tests/run_tests.gd      # unit and scene tests
godot --headless --path . -s res://tests/balance.gd        # fight win rates (RUNS=n, ONLY=<filter>)
```
Screenshots need a display, for example:
```sh
OUT_DIR=/tmp xvfb-run -a godot --path . --rendering-driver opengl3 -s res://tests/screenshot_lineup.gd
```
Other screenshot scripts: `screenshot_world`, `screenshot_combat` and `screenshot_n3` (set `TITLE=1` for the title screen).
