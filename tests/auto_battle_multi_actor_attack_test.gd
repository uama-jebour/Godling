extends SceneTree

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run_suite")


func _run_suite() -> void:
	_setup_content_db()
	_test_multiple_units_contribute_attacks()
	_print_result_and_exit()


func _setup_content_db() -> void:
	var content_db: Node = load("res://autoload/content_db.gd").new()
	content_db.name = "ContentDB"
	get_root().add_child(content_db)


func _test_multiple_units_contribute_attacks() -> void:
	var director: RefCounted = load("res://systems/battle/battle_director.gd").new()
	var result: Dictionary = director.run_battle(
		{
			"battle_id": "battle_auto_a02_hold_line",
			"event_instance_id": "multi_actor_attack",
			"map_id": "map_world_a_02_ashen_sanctum",
			"hero_snapshot": {
				"hero_id": "hero_pilgrim_a01",
				"runtime_stats": {
					"hp": 52.0,
					"attack_power": 5.0
				}
			},
			"equipped_strategy_ids": [],
			"battle_seed": 414
		}
	)
	var action_log: Array = result.get("map_effects", {}).get("action_log", [])
	var hero_attack_count := 0
	var enemy_actor_ids: Dictionary = {}
	for action_value in action_log:
		if typeof(action_value) != TYPE_DICTIONARY:
			continue
		var action: Dictionary = action_value
		if String(action.get("type", "")) != "attack":
			continue
		var actor_side: String = String(action.get("actor_side", ""))
		var actor_id: String = String(action.get("actor_id", ""))
		if actor_side == "hero":
			hero_attack_count += 1
		elif actor_side == "enemy" and not actor_id.is_empty():
			enemy_actor_ids[actor_id] = true
	_assert_true(hero_attack_count > 0, "自动战斗日志中应出现英雄攻击记录")
	_assert_true(enemy_actor_ids.size() >= 2, "自动战斗日志中应至少出现两个不同敌人的攻击记录")


func _assert_true(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)
	printerr("ASSERT FAILED: %s" % message)


func _print_result_and_exit() -> void:
	if _failures.is_empty():
		print("SMOKE TEST PASS: multiple battle actors contribute attack actions.")
		quit(0)
		return
	printerr("SMOKE TEST FAIL (%d):" % _failures.size())
	for message: String in _failures:
		printerr("- %s" % message)
	quit(1)
