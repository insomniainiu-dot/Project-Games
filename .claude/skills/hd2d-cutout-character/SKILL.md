---
name: hd2d-cutout-character
description: Build or extend HD-2D look and anime-style skeletal (cutout, Spine-like) 2D characters in this Godot 4.7 project — new characters, poses, combos, finishers with cut-in/hitstop/slow-mo, new test scenes, and lighting/post-fx tuning. Use when asked to design a character, animate moves/skills, make a finisher, add a scene in the HD-2D style, or tune the look.
---

# HD-2D + Cutout Character Pipeline

Project: `C:\Users\tone_\Project-Games` (Godot 4.7.2, Forward+, D3D12). Godot exe:
`C:\Users\tone_\OneDrive\เดสก์ท็อป\Godot_v4.7.2-stable_win64.exe`.

Don't copy characters, art or levels from existing games. When the user sends a reference (for example a video of another game), copy the *technique*: how it moves, the camera work, the effects. Design the character itself from scratch. Theme is sci-fi space (see memory). Note any fantasy leftovers in the art.

## Existing building blocks (reuse, don't rebuild)

| File | What it gives |
|---|---|
| `world/scene_lighting.gd` (`SceneLighting`) | WorldEnvironment (AgX, glow, SSAO/SSIL, volumetric fog), sun, Camera3D with tilt-shift DoF, post-fx shader (warm/cool tint, vignette, grain), grass ground. `build()`, `follow(node)`. The camera follows `target.position + CAMERA_OFFSET`. |
| `world/mesh_factory.gd` (`MeshFactory`) | `mat(texture, tint)` makes pixel triplanar materials from `textures/{grass,stone,wall,wood,roof}.png`. `glow_mat(color, energy)` (energy above 1 picks up Glow). `box()` and `cylinder()`. |
| `world/scenery.gd` (`Scenery`) | Prop helpers you can call from outside: `_house`, `_lantern`, `_tree`, `_well`, `_bush` (needs `_rng` set first), `_build_motes()`. |
| `witch.gd` (`Witch`) | Classic sprite-sheet `Sprite3D` billboard character with breathing and blinking. |
| `world/cutout/cutout_rig.gd` (`CutoutRig`) | Skeletal 2D rig. Bones are Node2D and parts are Polygon2D (placeholder art, z order set by absolute `z_index`). Includes 2-bone leg IK, verlet scarf and coat chains, a sword smear trail, procedural idle and run, `to_pose()` tweens, and `make_pose()`. |
| `world/cutout/cutout_character.gd` (`CutoutCharacter`) | Puts the rig in the 3D world: SubViewport (HDR 2D) → billboard quad with a custom shader. Has `move()`, `attack()` (3-hit combo), `finisher(target)`, and a `cue(name, strength)` signal. |
| `tools/art_lab.tscn` | Look-tuning sandbox: live sliders for env/DoF/vignette, `Print values`, 4 weapon-tier glows, gem VFX bursts. |
| `tools/dock_lab.tscn` | Sci-fi "Dock 07" scene and finisher director: FOV zoom, letterbox, speed lines, hitstop, slow-mo, cut-in, flash, shockwave, damage numbers. |

## How the cutout character works

- The rig draws into a `SubViewport` (`VIEW` 280x240, feet at `FEET` (140,204)) with `use_hdr_2d = true`. Low resolution plus nearest filtering gives pixel-art output with smooth skeletal motion.
- The quad shader does Y-axis billboarding, alpha-cut via `discard` (so it casts shadows), a 1px dark outline, and `EMISSION = max(col - 1, 0)`. **Any part colored with values above 1.0 glows** (blade, eyes, trail).
- `PIXEL = 0.0135` world units per rig pixel. `to_world(p)` maps rig coordinates to local 3D.
- Angle convention for limbs: 0 = hanging down, **negative = swing forward**, positive = back. For torso and head, positive = lean forward. Facing is flipped with `_root.scale.x`.
- Legs use IK. A pose sets `foot_f_x/y` and `foot_b_x/y` targets (ground = y -3), not leg angles.
- Pose = `CutoutRig.make_pose({overrides})` (IDLE plus changes). Play a pose with `await rig.to_pose(pose, dur, trans, ease)` while `rig.mode = "action"`. Set `mode` back to `idle` or `run`; the rig blends back to procedural motion on its own.

## Anime motion recipe (what makes it feel good)

1. **Anticipation**: wind up for 0.08–0.3s with `TRANS_QUAD`/`TRANS_BACK` `EASE_OUT`.
2. **Strike**: 0.06–0.1s with `TRANS_EXPO` `EASE_OUT`, `rig.trail_on = true`, plus a short `_slide` forward.
3. **Impact**: emit `cue("hit", strength)`. The scene responds with hitstop (`Engine.time_scale = 0` for ~0.05–0.12s using a timer with `ignore_time_scale`), shake, sparks, a light flash, and a damage number.
4. **Follow-through hold**: 0.1–0.2s so the eye can read the pose. Then trail off and return to idle.
5. Finishers add camera work: zoom FOV (DoF stays correct because camera distance doesn't change), letterbox, speed lines, darker exposure, slow-mo (`_base_scale`) during the cut-in, a flash and shockwave on the slam. UI tweens use `set_ignore_time_scale(true)`.
6. Separate roles: **the character emits cues, the scene directs the effects** (`_on_cue` in `dock_lab.gd`).

## Adding a new character / move

- New character: copy `cutout_rig.gd` `_build()` with new colors and part shapes, or swap Polygon2D parts for `Sprite2D` parts of painted art, one per bone. Keep the bone names so every pose still works.
- New move: add pose dicts in `cutout_character.gd` and a coroutine following the recipe. Check angles against the convention above.
- Weapon tiers: emissive material with energy by tier, plus an aura OmniLight from T3 and sparkle particles at T4 (see `art_lab.gd` `_set_tier`). Skill gems: one-shot additive particle burst plus an OmniLight flash in the gem's color.

## Verify every change (screenshot loop)

Scenes support `-- shot=<path.png>`. They auto-play and save PNGs, then quit. `dock_lab` saves idle, run, combo, finisher stages, and rig close-ups at 3x.

```powershell
$g = "C:\Users\tone_\OneDrive\เดสก์ท็อป\Godot_v4.7.2-stable_win64.exe"; $o = "<scratchpad>\dock"; New-Item -ItemType Directory -Force $o | Out-Null; $p = Start-Process $g -ArgumentList @('--path','C:\Users\tone_\Project-Games','res://tools/dock_lab.tscn','--',"`"shot=$o\dock.png`"") -Wait -PassThru -RedirectStandardOutput "$o\out.txt" -RedirectStandardError "$o\err.txt"; Get-Content "$o\err.txt" | Select-Object -Unique | Select -First 20
```

Then Read the PNGs and look at them. Run windowed, not `--headless`, or screenshots are blank.

## Gotchas learned

- **New `class_name` files** aren't visible to a command-line run until you run `--headless --path <proj> --import` once to rebuild the class cache.
- Typed GDScript: `for side in ["b","f"]` gives an untyped Variant, so `var x := side == "b"` fails to parse. Write `for side: String in [...]`.
- `ShaderMaterial.get_shader_parameter()` returns `null` for uniforms still at their shader default. Use a fallback value.
- `CanvasItem.to_global()` errors before the node is in the tree. Do the first pose and chain setup in `_ready`, not `_init`.
- Verlet cloth must be **dt-corrected** (`vel *= exp(-k*dt) * dt/prev_dt`, clamp dt ≤ 1/30). Per-frame damping depends on FPS, and a big first-frame dt flings the cloth upward.
- Trail drawing uses `draw_primitive` triangles, not Polygon2D, so self-intersecting arcs don't break triangulation.
- `Start-Process -ArgumentList` needs an array `@(...)`. Don't build an arg with `+` inline.
- In `--script` debug runs the Godot window is shown. Put temporary debug scripts in `tools/_*.gd` and delete them (including `.uid`) afterwards.

## Known limits / next steps

- Placeholder polygon art. Real art means painted parts per bone.
- Blade arcs below the feet sink into the floor (the quad intersects the ground).
- The theme is still mixed: the old board scenes use fantasy textures.
