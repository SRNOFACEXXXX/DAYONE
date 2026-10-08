# Handoff for Claude — DAYONE (Godot survival game)

This is the project handoff requested by the user. It records the state before beginning zombie implementation so another assistant can continue without treating planned work as complete. Update the zombie section as files are downloaded, implemented, and tested.

## Project

- Godot project: `C:/Users/satoshi/Documents/ChatGPT/teste/teste GPT/battle_royale/game`
- Engine project config: `project.godot`; main scene is `res://ui/main_menu.tscn`.
- Engine used in recent checks: Godot 4.7.1, Compatibility renderer.
- Main systems: `core/`, game world: `maps/ilha/ilha.tscn`, test scenes: `tests/`.
- No project-root `AGENTS.md` was found. An `AGENTS.md` under `battle_royale/_ref_scenario_skills/` is outside this project's directory tree.

## Work already in the project

### Vehicles

- `core/drivable_vehicle.gd` implements a `VehicleBody3D` sedan controller with mass, engine/brake forces, front-wheel steering, four physical `VehicleWheel3D` suspension points, visual wheel alignment/rotation, driver entry/exit, doors/panels, and third-/first-person camera placement.
- Existing spawn integration is tested against the island rather than only a mocked chassis in `tests/vehicle_physics.gd`; it checks terrain spawn height, four suspension wheels/contact, hub-to-mesh alignment, wheel rotation, camera position, steering, exit, and parking.
- `tests/vehicle_field_test.gd` exercises suspension and repeated steering over bumps and samples a frame sequence. It checks tire/body clearance, hub error, speed, and roll angle.
- `tests/vehicle_player_flow.gd` checks entering/exiting spawned cars in the survival scene.
- Known caveat: these are Godot automation scenes. They do not guarantee every terrain feature or every imported car model has been manually driven in a full player session. Re-run the tests after changing vehicle code/assets.

### Construction

- `core/construction_system.gd` owns build selection, snapping, placement, construction collision, door interaction, deletion, and construction UI.
- Current controls in the construction mode: `B` opens the radial selection, Enter selects, `F` toggles piece alignment, click places, `Q` rotates, `X` deletes the aimed player piece, `G` exits build mode, Esc cancels/closes.
- Free construction is intentionally enabled for testing (`FREE_BUILD_MODE := true`). Do not mistake that test setting for a finished resource economy.
- The radial wheel now draws vector miniatures for foundation/floor, wall, window, door, roof, stairs, and pillar. The HUD reports specific placement rejection reasons.
- Placement overlap checks now use the actual component boxes of a piece (including window/door openings) and a small seam tolerance, instead of rejecting based on the full metadata box.
- `tests/construction_smoke.gd` builds a 2x2, two-storey test house using real physics raycasts and placement calls. It checks roof placement from below the second-storey ceiling at four camera angles, then checks foundation/wall continuity, stairs, door passage, delete, and exit.
- Last verified in this session: Godot 4.7.1 editor import + headless `res://tests/construction_smoke.tscn` passed; non-headless run captured four roof-from-below frames and the radial menu preview. The integration scene has a compact procedural test environment, not the full island map.
- Screenshot/GIF outputs are in the Windows temp folder and are disposable test artifacts: `construction_roof_below_00.png` through `_03.png`, `construction_roof_below.gif`, `construction_roof_below_contact.png`, and `construction_radial_menu.png`.

## Zombie implementation — CURRENT TASK, NOT YET IMPLEMENTED

### User goal

Create a useful zombie enemy for the open-world post-apocalyptic survival game. Required behavior and animation states:

1. Idle / standing.
2. Slow walk / patrol movement.
3. Detect a player, turn toward them, and play a growl/roar/scream cue.
4. Chase the player by running.
5. Attack the player at close range.
6. Death animation on lethal damage.

Also create a dedicated in-project training/test studio with a frame-by-frame image sequence so movement, transitions, orientation, foot contact, attack range, and death can be visually reviewed like a short video. Integrate into the real gameplay only after the rig/animation test is credible.

### Assets discovered (not extracted/copied into project yet)

User-provided folder: `C:/Users/satoshi/Desktop/Assets/atualização/zombies`

- `szombie_gltf.zip` contains `scene.gltf`, `scene.bin`, and base-color/ORM/normal textures for SZombie Variant 1.
- `szombie.zip` contains `SZombie_Variant_1/SK_SZombie_Variant_1.fbx`, a Cascadeur FBX, a static-mesh FBX, and texture maps (albedo, OpenGL/DirectX normal, metallic, occlusion, roughness, etc.).
- First task after this handoff: inspect/extract the rigged FBX and GLTF in a project-local asset folder; import into Godot and verify skeleton, scale, materials, and root orientation before retargeting animations. Preserve the source archives.

### Mixamo

- User supplied: `https://www.mixamo.com/#/?page=1&query=zombie` and explicitly says their browser is already logged in; use the existing Mixamo browser tab/account.
- Download or otherwise obtain suitable zombie clips for idle, slow walk, roar/scream, run, attack, and death. Prefer animation-only FBX (no character skin) when retargeting to the supplied zombie rig; confirm export settings and verify each import in Godot.
- Keep track of actual downloaded filenames and mapping from file to state in this document. Mixamo animations have not yet been opened/downloaded/imported as of this handoff.

### Planned architecture and validation

- Create a reusable zombie scene and controller/state machine; avoid burying all AI in a test scene. Suggested explicit states: `IDLE`, `PATROL`, `ALERT`, `CHASE`, `ATTACK`, `HIT` (optional), `DEAD`.
- Use navigation/path queries that respect the island's collision/navigation setup; stop at attack distance, face the player, apply damage on animation timing/cooldown, and prevent repeated death/damage transitions.
- Build a standalone zombie animation studio scene with floor, lights, camera orbit/markers, controls to select or trigger each state, and an automated scripted sequence. Save ordered PNG frames plus a GIF/contact sheet when possible; inspect the actual images before saying the animation looks correct.
- Test import warnings, scene startup, state transitions, player detection/loss, chase obstacle behavior, attack cooldown/range, death exactly once, and all animation clip mappings. Add a gameplay spawn only after these pass.
- Capture remaining failures and unverified items here. Do not report the zombie system as complete merely because clips import or a test scene opens.

## Command notes

From the project directory, use the installed Godot 4.7.1 executable with:

```powershell
& 'C:\Users\satoshi\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.WinGet.Source_8wekyb3d8bbwe\Godot_v4.7.1-stable_win64_console.exe' --headless --editor --path . --quit
& 'C:\Users\satoshi\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.WinGet.Source_8wekyb3d8bbwe\Godot_v4.7.1-stable_win64_console.exe' --headless --path . --scene res://tests/construction_smoke.tscn --quit-after 2600
```

Run vehicle checks individually with their corresponding scenes, e.g. `res://tests/vehicle_physics.tscn`, `res://tests/vehicle_field_test.tscn`, and `res://tests/vehicle_player_flow.tscn`. Check logs for both parser errors and failed `assert` messages; Godot can continue other code after an assertion failure, so a printed final `*_OK` line alone is insufficient.
