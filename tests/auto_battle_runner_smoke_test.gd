extends SceneTree

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run_suite")


func _run_suite() -> void:
	_setup_content_db()
	_test_auto_headless_battle_runs()
	_print_result_and_exit()


func _setup_content_db() -> void:
	var content_db: Node = load("res://autoload/content_db.gd").new()
	content_db.name = "ContentDB"
	get_root().add_child(content_db)


func _test_auto_headless_battle_runs() -> void:
	var director: RefCounted = load("res://systems/battle/battle_director.gd").new()
	var result: Dictionary = director.run_battle(
		{
			"battle_id": "battle_auto_a01_probe",
			"event_instance_id": "auto_smoke_1",
			"map_id": "map_world_a_02_ashen_sanctum",
			"hero_snapshot": {
				"hero_id": "hero_pilgrim_a01",
				"runtime_stats": {
					"hp": 44.0,
					"attack_power": 5.0
				}
			},
			"equipped_strategy_ids": ["strategy_support_drone", "strategy_demon_eye"],
			"battle_seed": 77
		}
	)
	_assert_true(String(result.get("status", "")) == "battle_runner_resolved", "auto headless battle 应返回结构化结果")
	_assert_true(String(result.get("map_effects", {}).get("backend", "")) == "auto_headless", "auto battle 默认应走 auto_headless")
	_assert_true(String(result.get("map_effects", {}).get("simulation_mode", "")) == "auto_units", "auto battle 应标记为 auto_units")
	_assert_true(int(result.get("map_effects", {}).get("elapsed_ticks", 0)) > 0, "auto battle 应推进至少 1 tick")
	_assert_true(not result.get("map_effects", {}).get("entities", []).is_empty(), "auto battle 应回填实体快照")
	_assert_true(not result.get("map_effects", {}).get("survivors", {}).is_empty(), "auto battle 应回填幸存者信息")


func _assert_true(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)
	printerr("ASSERT FAILED: %s" % message)


func _print_result_and_exit() -> void:
	if _failures.is_empty():
		print("SMOKE TEST PASS: auto battle headless runner validated.")
		quit(0)
		return
	printerr("SMOKE TEST FAIL (%d):" % _failures.size())
	for message: String in _failures:
		printerr("- %s" % message)
	quit(1)
