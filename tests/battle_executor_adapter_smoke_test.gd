extends SceneTree

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run_suite")


func _run_suite() -> void:
	_setup_content_db()
	_test_valid_stub_result()
	_test_invalid_request()
	_print_result_and_exit()


func _setup_content_db() -> void:
	var content_db: Node = load("res://autoload/content_db.gd").new()
	content_db.name = "ContentDB"
	get_root().add_child(content_db)


func _test_valid_stub_result() -> void:
	var adapter: RefCounted = load("res://systems/battle/battle_executor_adapter.gd").new()
	var battle_result: Dictionary = adapter.execute_battle(
		{
			"battle_id": "battle_a02_patrol",
			"event_instance_id": "fix_run_1",
			"map_id": "map_world_a_02_ashen_sanctum",
			"hero_snapshot": {
				"hero_id": "hero_pilgrim_a01",
				"runtime_stats": {
					"hp": 36,
					"attack_power": 4.0
				}
			},
			"configured_reward_package": {
				"currencies": [{"id": "currency_lumen_mark", "count": 10}],
				"items": [],
				"relics": [],
				"story_flags": [],
				"unlock_flags": [],
				"loot_tables": []
			}
		},
		{"success_override": true}
	)

	_assert_true(String(battle_result.get("status", "")) == "battle_runner_resolved", "有效请求应返回 headless battle runner 状态")
	_assert_true(bool(battle_result.get("victory", false)), "success_override=true 时应返回 victory=true")
	_assert_true(
		int(battle_result.get("reward_package", {}).get("currencies", [])[0].get("count", 0)) == 10,
		"适配层应透传 configured_reward_package"
	)
	_assert_true(
		String(battle_result.get("map_effects", {}).get("victory_type", "")) == "eliminate_all",
		"BattleDirector 应回填 battle 定义中的 victory_type"
	)
	_assert_true(
		int(battle_result.get("map_effects", {}).get("elapsed_ticks", 0)) > 0,
		"headless battle runner 应真正推进至少1个 tick"
	)


func _test_invalid_request() -> void:
	var adapter: RefCounted = load("res://systems/battle/battle_executor_adapter.gd").new()
	var battle_result: Dictionary = adapter.execute_battle({}, {})
	_assert_true(String(battle_result.get("status", "")) == "invalid_request", "缺少 battle_id 应返回 invalid_request")
	_assert_true(not bool(battle_result.get("victory", true)), "invalid_request 不应返回 victory=true")
	_assert_true(String(battle_result.get("defeat_reason", "")) == "missing_battle_id", "invalid_request 应提供缺失原因")


func _assert_true(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)
	printerr("ASSERT FAILED: %s" % message)


func _print_result_and_exit() -> void:
	if _failures.is_empty():
		print("SMOKE TEST PASS: battle executor adapter contract validated.")
		quit(0)
		return

	printerr("SMOKE TEST FAIL (%d):" % _failures.size())
	for message: String in _failures:
		printerr("- %s" % message)
	quit(1)
