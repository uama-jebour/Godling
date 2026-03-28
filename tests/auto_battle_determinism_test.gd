extends SceneTree

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run_suite")


func _run_suite() -> void:
	_setup_content_db()
	_test_same_seed_stays_deterministic()
	_print_result_and_exit()


func _setup_content_db() -> void:
	var content_db: Node = load("res://autoload/content_db.gd").new()
	content_db.name = "ContentDB"
	get_root().add_child(content_db)


func _test_same_seed_stays_deterministic() -> void:
	var director: RefCounted = load("res://systems/battle/battle_director.gd").new()
	var request := {
		"battle_id": "battle_auto_a01_probe",
		"event_instance_id": "auto_determinism",
		"map_id": "map_world_a_02_ashen_sanctum",
		"hero_snapshot": {
			"hero_id": "hero_pilgrim_a01",
			"runtime_stats": {
				"hp": 42.0,
				"attack_power": 5.0
			}
		},
		"equipped_strategy_ids": ["strategy_support_drone", "strategy_demon_eye"],
		"battle_seed": 303
	}
	var result_a: Dictionary = director.run_battle(request, {})
	var result_b: Dictionary = director.run_battle(request, {})
	var effects_a: Dictionary = result_a.get("map_effects", {})
	var effects_b: Dictionary = result_b.get("map_effects", {})
	_assert_true(int(effects_a.get("elapsed_ticks", -1)) == int(effects_b.get("elapsed_ticks", -2)), "相同 seed 的 elapsed_ticks 应一致")
	_assert_true(
		JSON.stringify(effects_a.get("survivors", {})) == JSON.stringify(effects_b.get("survivors", {})),
		"相同 seed 的 survivors 应一致"
	)
	_assert_true(
		JSON.stringify(effects_a.get("casualties_by_side", {})) == JSON.stringify(effects_b.get("casualties_by_side", {})),
		"相同 seed 的 casualties_by_side 应一致"
	)
	_assert_true(
		JSON.stringify(effects_a.get("triggered_scripted_event_ids", [])) == JSON.stringify(effects_b.get("triggered_scripted_event_ids", [])),
		"相同 seed 的 scripted event 触发结果应一致"
	)


func _assert_true(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)
	printerr("ASSERT FAILED: %s" % message)


func _print_result_and_exit() -> void:
	if _failures.is_empty():
		print("SMOKE TEST PASS: auto battle determinism verified.")
		quit(0)
		return
	printerr("SMOKE TEST FAIL (%d):" % _failures.size())
	for message: String in _failures:
		printerr("- %s" % message)
	quit(1)
