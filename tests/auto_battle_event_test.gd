extends SceneTree

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run_suite")


func _run_suite() -> void:
	_setup_content_db()
	_test_event_response_can_cancel_reinforcement()
	_test_event_chain_can_apply_without_response()
	_print_result_and_exit()


func _setup_content_db() -> void:
	var content_db: Node = load("res://autoload/content_db.gd").new()
	content_db.name = "ContentDB"
	get_root().add_child(content_db)


func _test_event_response_can_cancel_reinforcement() -> void:
	var director: RefCounted = load("res://systems/battle/battle_director.gd").new()
	var result: Dictionary = director.run_battle(
		{
			"battle_id": "battle_auto_a02_hold_line",
			"event_instance_id": "auto_event_cancel",
			"map_id": "map_world_a_02_ashen_sanctum",
			"hero_snapshot": {
				"hero_id": "hero_pilgrim_a01",
				"runtime_stats": {
					"hp": 52.0,
					"attack_power": 5.0
				}
			},
			"equipped_strategy_ids": ["strategy_signal_scrambler"],
			"battle_seed": 414
		},
		{
			"auto_strategy_commands": [
				{"strategy_id": "strategy_signal_scrambler", "at_seconds": 8.0, "center": [692, 226]}
			]
		}
	)
	var resolution_log: String = JSON.stringify(result.get("map_effects", {}).get("event_resolution_log", []))
	_assert_true(resolution_log.contains("\"event_id\":\"battle_event_auto_reinforcement\""), "事件日志应包含 reinforcement 事件")
	_assert_true(resolution_log.contains("\"resolution\":\"cancelled\""), "增援事件应可被主动策略取消")


func _test_event_chain_can_apply_without_response() -> void:
	var director: RefCounted = load("res://systems/battle/battle_director.gd").new()
	var result: Dictionary = director.run_battle(
		{
			"battle_id": "battle_auto_a02_hold_line",
			"event_instance_id": "auto_event_apply",
			"map_id": "map_world_a_02_ashen_sanctum",
			"hero_snapshot": {
				"hero_id": "hero_pilgrim_a01",
				"runtime_stats": {
					"hp": 52.0,
					"attack_power": 5.0
				}
			},
			"equipped_strategy_ids": ["strategy_support_drone", "strategy_demon_eye"],
			"battle_seed": 414
		}
	)
	var triggered_events: Array = result.get("map_effects", {}).get("triggered_scripted_event_ids", [])
	_assert_true(triggered_events.has("battle_event_auto_reinforcement"), "无打断时 reinforcement 应触发")
	_assert_true(triggered_events.has("battle_event_auto_enemy_frenzy"), "reinfocement 后续 buff 事件应触发")


func _assert_true(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)
	printerr("ASSERT FAILED: %s" % message)


func _print_result_and_exit() -> void:
	if _failures.is_empty():
		print("SMOKE TEST PASS: auto battle events verified.")
		quit(0)
		return
	printerr("SMOKE TEST FAIL (%d):" % _failures.size())
	for message: String in _failures:
		printerr("- %s" % message)
	quit(1)
