# Getting your characters into Ashgrave 3D

## Where files go
```
ashgrave3d/characters/<id>/<id>.glb        the character (mesh + armature + any clips)
ashgrave3d/characters/<id>/<anything>.glb  more clips for the same skeleton (optional)
ashgrave3d/characters/<id>/anims.json      optional overrides (see below)
ashgrave3d/equipment/<id>.glb              weapons and shields (N2)
```
`<id>` is the game's name for the character:
- party: `maren`, `oswin`, `ketta`
- story NPCs: `maud`, `nessa`, `harl`
- creatures: `risen`, `revenant`, `barrow_lord`, `ghoul`, `wight`, `hound`, `lurker`, `boar`, `crows`, `bandit`, `crossbow`, `cultist`, `ash_knight`

Anything without a `.glb` shows a grey stand-in mannequin, so you can add characters one at a time.

## Export settings (Blender → File → Export → glTF 2.0)
- **Format:** glTF Binary (`.glb`).
- **Include:** the mesh and its armature. Leave cameras and lights off.
- **Transform:** +Y Up (the default). Apply scale and rotation first (Ctrl+A → All Transforms).
- **Size:** metres, feet at the origin, about 1.6–1.8 m tall for people.
- **Facing:** Blender's −Y (front view), which is how Meshy exports. If yours faces the other way, set `"yaw": 0` in `anims.json`.
- **Animation:** tick Animations, and export each Action as its own clip ("Actions" or "NLA tracks").
- **Textures:** 2048 px is fine, 1024 px keeps the browser version light. PNG or JPEG.
- **Materials:** Principled BSDF only (base colour, normal, metallic/roughness).

## Animation clips
The game looks for these clips by name (any case, and the name only has to contain the word):

| Game action | Name should contain | If missing |
|---|---|---|
| idle | `idle` | holds the first frame of the walk and breathes |
| combat stance | `combat_idle` / `ready` / `stance` | uses idle |
| walk | `walk` | slides (needed!) |
| run | `run` / `jog` | walk cycle played faster |
| attack | `attack` / `slash` / `stab` / `punch` (several = they rotate) | forward lunge |
| cast | `cast` / `spell` | lunge |
| shoot | `shoot` / `bow` | lunge |
| hit | `hit` / `hurt` | flinch |
| death | `death` / `die` | falls over |

Clips shorter than 0.2 s are ignored. Meshy adds a 2-frame bind-pose clip, and this skips it.

**Meshy tip:** use the Animate feature on the same rigged model to make Idle, Run, Attack and Death, and download each one as a `.glb`. Drop them in the character's folder with any names, for example `maren_idle.glb` or `maren_attack.glb`. The game copies their clips onto the main model, because the skeletons match.

## anims.json (optional)
```json
{
  "yaw": 180,
  "scale": 1.0,
  "walk_speed": 1.4,
  "clips": {"idle": "Breathing_Idle", "attack": ["Slash_A", "Slash_B"]}
}
```
- **yaw:** degrees added so the model faces the way it walks. 180 suits Meshy and Blender −Y exports.
- **walk_speed:** metres per second the walk clip was animated for, so the feet don't slide.
- **clips:** explicit clip names when the keyword guess picks the wrong one.

## Weapons (from N2)
Name the hand bones `hand.R` and `hand.L`. Meshy's rig already does this. Model weapons with the grip at the origin, pointing along +Y.
