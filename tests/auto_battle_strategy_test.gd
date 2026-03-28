extends SceneTree

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run_suite")


func _run_suite() -> void:
	_setup_content_db()
	_test_passive_and_active_strategies_apply()
	_print_result_and_exit()


func _setup_content_db() -> void:
	var content_db: Node = load("res://autoload/content_db.gd").new()
	content_db.name = "ContentDB"
	get_root().add_child(content_db)


func _test_passive_and_active_strategies_apply() -> void:
	var director: RefCounted = load("res://systems/battle/battle_director.gd").new()
	var result: Dictionary = director.run_battle(
		{
			"battle_id": "battle_auto_a02_hold_line",
			"event_instance_id": "auto_strategy_1",
			"map_id": "map_world_a_02_ashen_sanctum",
			"hero_snapshot": {
				"hero_id": "hero_pilgrim_a01",
				"runtime_stats": {
					"hp": 48.0,
					"attack_power": 5.0
				}
			},
			"equipped_strategy_ids": [
				"strategy_support_drone",
				"strategy_demon_eye",
				"strategy_field_prayer",
				"strategy_signal_scrambler"
			],
			"battle_seed": 808
		},
		{
			"auto_strategy_commands": [
				{"strategy_id": "strategy_signal_scrambler", "at_seconds": 8.0, "center": [692, 226]}
			]
		}
	)
	var map_effects: Dictionary = result.get("map_effects", {})
	var triggered_strategy_ids: Array = map_effects.get("triggered_strategy_ids", [])
	_assert_true(triggered_strategy_ids.has("strategy_support_drone"), "周期伤害策略应触发")
	_assert_true(triggered_strategy_ids.has("strategy_field_prayer"), "周期护盾策略应触发")
	_assert_true(triggered_strategy_ids.has("strategy_demon_eye"), "tag 增伤策略应触发")
	_assert_true(triggered_strategy_ids.has("strategy_signal_scrambler"), "主动策略应触发")
	var action_text: String = JSON.stringify(map_effects.get("action_log", []))
	_assert_true(action_text.contains("strategy_pulse_damage"), "行动日志应记录 passive damage")
	_assert_true(action_text.contains("strategy_pulse_shield"), "行动日志应记录 passive shield")
	_assert_true(action_text.contains("strategy_area_damage"), "行动日志应记录 active area damage")


func _assert_true(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)
	printerr("ASSERT FAILED: %s" % message)


func _print_result_and_exit() -> void:
	if _failures.is_empty():
		print("SMOKE TEST PASS: auto battle strategies verified.")
		quit(0)
		return
	printerr("SMOKE TEST FAIL (%d):" % _failures.size())
	for message: String in _failures:
		printerr("- %s" % message)
	quit(1)
