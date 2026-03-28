# Auto Battle Smooth Movement Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make auto-battle preview unit movement render smoothly between timeline ticks without changing simulation results.

**Architecture:** Keep simulation and timeline generation unchanged. Add a render-state interpolation layer in `battle_scene_controller.gd` that stores per-entity target positions and moves visible tokens toward those targets every render frame. Guard interactive-mode behavior so only auto-preview playback uses smoothing by default.

**Tech Stack:** Godot 4, GDScript, SceneTree-based tests

---

### Task 1: Add Failing Smooth-Movement Test

**Files:**
- Create: `tests/auto_battle_smooth_motion_test.gd`
- Modify: `tests/auto_battle_scene_smoke_test.gd`
- Test: `tests/auto_battle_smooth_motion_test.gd`

- [ ] **Step 1: Write the failing test**

```gdscript
extends SceneTree

var _failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run_suite")

func _run_suite() -> void:
	_setup_content_db()
	await _test_auto_preview_token_moves_toward_target_over_frames()
	_print_result_and_exit()

func _setup_content_db() -> void:
	var content_db: Node = load("res://autoload/content_db.gd").new()
	content_db.name = "ContentDB"
	get_root().add_child(content_db)

func _test_auto_preview_token_moves_toward_target_over_frames() -> void:
	var scene: PackedScene = load("res://scenes/battle/battle_runner.tscn")
	var instance: Node = scene.instantiate()
	get_root().add_child(instance)
	var content_db: Node = get_root().get_node_or_null("ContentDB")
	var battle_def: Dictionary = content_db.get_battle("battle_auto_a01_probe")
	instance.call(
		"start_interactive_battle",
		{
			"battle_id": "battle_auto_a01_probe",
			"event_instance_id": "auto_smooth_motion",
			"map_id": "map_world_a_02_ashen_sanctum",
			"hero_snapshot": {"hero_id": "hero_pilgrim_a01", "runtime_stats": {"hp": 48.0, "attack_power": 5.0}},
			"equipped_strategy_ids": ["strategy_support_drone"],
			"battle_seed": 202
		},
		battle_def,
		{"battle_backend": "auto_scene", "interactive_mode": false, "preview_speed": 1.0}
	)
	await process_frame
	await process_frame
	var controller := instance.get_node("%BattleController")
	var token := controller.get("_arena_nodes").get("hero_1")
	var start_pos: Vector2 = token.position
	controller.call("_render_state", controller.call("_auto_frame_to_scene_state", controller.get("_timeline")[1]), "smooth test")
	await process_frame
	var after_one_frame: Vector2 = token.position
	var target_pos: Vector2 = controller.get("_token_target_positions").get("hero_1")
	for _i in 12:
		await process_frame
	var after_many_frames: Vector2 = token.position
	_assert_true(after_one_frame.distance_to(target_pos) > 0.5, "首帧不应直接瞬移到目标点")
	_assert_true(after_many_frames.distance_to(target_pos) < after_one_frame.distance_to(target_pos), "后续帧应逐步逼近目标点")

func _assert_true(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)
	printerr("ASSERT FAILED: %s" % message)

func _print_result_and_exit() -> void:
	if _failures.is_empty():
		print("TEST PASS: auto battle smooth motion verified.")
		quit(0)
		return
	printerr("TEST FAIL (%d):" % _failures.size())
	for message: String in _failures:
		printerr("- %s" % message)
	quit(1)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script tests/auto_battle_smooth_motion_test.gd`

Expected: FAIL because tokens still jump directly to the target position and the controller does not yet expose persistent render-target state.

- [ ] **Step 3: Keep smoke coverage focused**

Update `tests/auto_battle_scene_smoke_test.gd` only if needed to preserve a simple backend contract smoke test while the new test owns motion behavior.

- [ ] **Step 4: Re-run the new test before implementation**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script tests/auto_battle_smooth_motion_test.gd`

Expected: still FAIL for the same reason.

- [ ] **Step 5: Commit**

```bash
git add tests/auto_battle_smooth_motion_test.gd tests/auto_battle_scene_smoke_test.gd
git commit -m "test: add failing auto battle smooth motion coverage"
```

### Task 2: Implement Render-Layer Interpolation

**Files:**
- Modify: `scripts/battle/battle_scene_controller.gd`
- Test: `tests/auto_battle_smooth_motion_test.gd`
- Test: `tests/auto_battle_scene_smoke_test.gd`
- Test: `tests/auto_battle_hpbar_alignment_test.gd`
- Test: `tests/auto_battle_runner_smoke_test.gd`

- [ ] **Step 1: Add render-state fields**

Add controller fields for:

```gdscript
var _token_target_positions: Dictionary = {}
var _token_render_positions: Dictionary = {}

const AUTO_PREVIEW_POSITION_LERP_SPEED := 14.0
const AUTO_PREVIEW_POSITION_SNAP_DISTANCE := 0.75
```

Also clear both dictionaries inside `_reset_render_runtime()` and when stale tokens are removed.

- [ ] **Step 2: Split logical target computation from visible placement**

In `_sync_arena_tokens(state)`, compute the token target position exactly as today:

```gdscript
var target_position := formation_position + Vector2(float(motion.get("offset_x", 0.0)), float(motion.get("offset_y", 0.0)))
```

Then:

```gdscript
_token_target_positions[entity_id] = target_position
if not _token_render_positions.has(entity_id):
	_token_render_positions[entity_id] = target_position
	token.position = target_position
elif _should_snap_token_position(state):
	_token_render_positions[entity_id] = target_position
	token.position = target_position
else:
	token.position = Vector2(_token_render_positions[entity_id])
```

This keeps new spawns and explicit snap scenarios stable while existing auto-preview tokens keep their current rendered position.

- [ ] **Step 3: Add per-frame smoothing in `_process(delta)`**

Extend `_process(delta)` with:

```gdscript
_update_auto_preview_token_motion(delta)
```

Implement:

```gdscript
func _update_auto_preview_token_motion(delta: float) -> void:
	if not _auto_preview_active:
		return
	var weight := 1.0 - exp(-AUTO_PREVIEW_POSITION_LERP_SPEED * max(0.0, delta))
	for entity_id: String in _arena_nodes.keys():
		if not _token_target_positions.has(entity_id):
			continue
		var token: Control = _arena_nodes[entity_id]
		if token == null:
			continue
		var current_pos: Vector2 = Vector2(_token_render_positions.get(entity_id, token.position))
		var target_pos: Vector2 = Vector2(_token_target_positions[entity_id])
		var next_pos := current_pos.lerp(target_pos, weight)
		if next_pos.distance_to(target_pos) <= AUTO_PREVIEW_POSITION_SNAP_DISTANCE:
			next_pos = target_pos
		_token_render_positions[entity_id] = next_pos
		token.position = next_pos
```

- [ ] **Step 4: Add snap guard helpers**

Implement:

```gdscript
func _should_snap_token_position(state: Dictionary) -> bool:
	return not _auto_preview_active or not bool(state.get("use_world_positions", false))
```

Also snap current render positions inside resize/refresh paths that relayout the arena:

```gdscript
func _snap_all_token_render_positions_to_targets() -> void:
	for entity_id: String in _arena_nodes.keys():
		if not _token_target_positions.has(entity_id):
			continue
		var token: Control = _arena_nodes[entity_id]
		if token == null:
			continue
		var target_pos: Vector2 = Vector2(_token_target_positions[entity_id])
		_token_render_positions[entity_id] = target_pos
		token.position = target_pos
```

Call it after arena resize refreshes if needed.

- [ ] **Step 5: Run the new motion test**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script tests/auto_battle_smooth_motion_test.gd`

Expected: PASS

- [ ] **Step 6: Run regression tests**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script tests/auto_battle_scene_smoke_test.gd`
Expected: `SMOKE TEST PASS: auto battle scene preview verified.`

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script tests/auto_battle_hpbar_alignment_test.gd`
Expected: `TEST PASS: auto battle HP bar alignment verified.`

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script tests/auto_battle_runner_smoke_test.gd`
Expected: `SMOKE TEST PASS: auto battle headless runner validated.`

- [ ] **Step 7: Commit**

```bash
git add scripts/battle/battle_scene_controller.gd tests/auto_battle_smooth_motion_test.gd tests/auto_battle_scene_smoke_test.gd tests/auto_battle_hpbar_alignment_test.gd tests/auto_battle_runner_smoke_test.gd
git commit -m "feat: smooth auto battle preview movement"
```
