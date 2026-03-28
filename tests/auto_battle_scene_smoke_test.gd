extends SceneTree

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run_suite")


func _run_suite() -> void:
	_setup_content_db()
	_test_auto_scene_preview_backend()
	_print_result_and_exit()


func _setup_content_db() -> void:
	var content_db: Node = load("res://autoload/content_db.gd").new()
	content_db.name = "ContentDB"
	get_root().add_child(content_db)


func _test_auto_scene_preview_backend() -> void:
	var director: RefCounted = load("res://systems/battle/battle_director.gd").new()
	var result: Dictionary = director.run_battle(
		{
			"battle_id": "battle_auto_a01_probe",
			"event_instance_id": "auto_scene_smoke",
			"map_id": "map_world_a_02_ashen_sanctum",
			"hero_snapshot": {
				"hero_id": "hero_pilgrim_a01",
				"runtime_stats": {
					"hp": 44.0,
					"attack_power": 5.0
				}
			},
			"equipped_strategy_ids": ["strategy_support_drone"],
			"battle_seed": 202
		},
		{
			"battle_backend": "auto_scene"
		}
	)
	var map_effects: Dictionary = result.get("map_effects", {})
	_assert_true(String(map_effects.get("backend", "")) == "auto_scene", "auto_scene backend 应返回 auto_scene 标记")
	_assert_true(int(map_effects.get("timeline_frame_count", 0)) > 0, "auto_scene backend 应返回时间线帧数")
	_assert_true(int(map_effects.get("rendered_entity_count", 0)) > 0, "auto_scene backend 应返回实体数量")


func _assert_true(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)
	printerr("ASSERT FAILED: %s" % message)


func _print_result_and_exit() -> void:
	if _failures.is_empty():
		print("SMOKE TEST PASS: auto battle scene preview verified.")
		quit(0)
		return
	printerr("SMOKE TEST FAIL (%d):" % _failures.size())
	for message: String in _failures:
		printerr("- %s" % message)
	quit(1)
