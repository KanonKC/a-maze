# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

"A Maze" is a first-person 3D horror maze game built in **Godot 4.7** (Forward Plus renderer, Jolt Physics, D3D12 on Windows). The UI and narrative text are in **Thai**. The player navigates a procedurally generated maze, collects clues, avoids a ghost, and escapes through the east exit.

## Running the Game

Open the project in the Godot editor and press **F5** (or the Play button) to run. There is no CLI build command — all development happens through the Godot editor. The main scene is `scenes/main_menu.tscn`.

## Architecture

### Scene / Node Tree

```
main.tscn
├── World/Player      (scripts/player.gd)   — CharacterBody3D
├── World/MazeLevel   (scripts/maze_level.gd) — Node3D, generates maze procedurally on _ready
└── HUD               (scripts/hud.gd)       — CanvasLayer
    └── (game_manager.gd is a child of the root scene node)
```

`game_manager.gd` is in group `"game_manager"` and acts as the central signal bus. `player.gd` is in group `"player"`, the ghost is in group `"ghost"`.

### Key Scripts

| Script | Role |
|--------|------|
| `scripts/game_manager.gd` | Signal hub: clue tracking, checkpoint, pause menu, win/lose. Holds references to player and HUD. |
| `scripts/maze_level.gd` | Procedural maze generation (iterative DFS per zone), 3D geometry building, item/ghost spawning. |
| `scripts/player.gd` | FPS movement, crouch, flashlight (draining battery), chalk placement, mirror SubViewport, danger level, footstep audio. |
| `scripts/ghost.gd` | AI with three states — PATROL / CHASE / SEARCH. Freezes when player stares at it (without flashlight). `chase_speed` increases each time a clue is collected. |
| `scripts/hud.gd` | Reads player state each frame; shows flashlight bar, clue counter, compass (spin rate tied to danger level), mirror view, chalk count, crouch indicator, crosshair (pulses red when ghost is frozen). |
| `scripts/clue_item.gd` | Area3D trigger; calls `game_manager.collect_clue()` on body enter. |
| `scripts/pickup_item.gd` | Area3D trigger; grants chalk (`item_type=0`) or mirror (`item_type=1`) to player. |
| `scripts/chalk_mark.gd` | MeshInstance3D placed on wall surface via raycast. |
| `scripts/end_screen.gd` | CanvasLayer shown on win or caught; built entirely in code. |
| `scripts/main_menu.gd` | Title screen; loads `scenes/main.tscn` on start. |

### Maze Generation (`maze_level.gd`)

The maze is **32 × 22 cells** divided into three concentric zones (inner/middle/outer). Each zone is carved independently with iterative DFS, then zones are connected by punching a fixed number of passage holes. Five fixed rooms are carved wide for clue placement. The exit is always on the east wall at row 11.

- Grid bitmask directions: `DN=1, DS=2, DE=4, DW=8`
- World-space cell center: `ox + col*STEP + CELL*0.5` (STEP = 3.5 units)
- All geometry (walls, floor, ceiling, exit arch) is built procedurally — no pre-made meshes.

### Signal Flow

```
clue collected → game_manager.collect_clue()
              → emits clue_collected, clue_text_revealed
              → calls ghost.increase_speed()
              → if clues_found >= 4: emits exit_unlocked
ghost catches player → game_manager.on_player_caught()
              → emits player_caught → hud.flash_caught(), end_screen.show_caught()
              → after 1.5 s: teleports player to checkpoint
player exits  → game_manager.on_player_exit() → emits game_won → end_screen.show_win()
```

## Input Actions (defined in project.godot)

| Action | Key |
|--------|-----|
| `move_forward/back/left/right` | WASD |
| `crouch` | Left Ctrl |
| `toggle_flashlight` | F |
| `use_chalk` | E |
| `use_mirror` | R (hold) |
| `ui_cancel` | Escape — pause/resume |

## Dev Notes

- Two extra pickup items are spawned near the player start position (`_cell_center(14,11)` and `(18,11)`) for quick testing — these are intentional dev aids marked with a comment.
- The ghost spawns at `_cell_center(28, 3)` (top-right outer zone), far from the player start at the maze center.
- `CLUES_NEEDED = 4` out of `CLUES_TOTAL = 5` are required to unlock the exit.
- Checkpoint is set automatically after collecting the 3rd clue, or manually via `game_manager.set_checkpoint()`.
- The pause menu and end screen are built entirely in GDScript (no `.tscn` files); edits go in `game_manager.gd` (`_build_pause_menu`) and `end_screen.gd`.
