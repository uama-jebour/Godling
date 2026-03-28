extends SceneTree

const MIN_BUFFER := 4.0

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run_suite")


func _run_suite() -> void:
	_setup_content_db()
	_validate_battle("battle_auto_a01_probe", 77)
	_validate_battle("battle_auto_a02_hold_line", 202)
	_print_result_and_exit()


func _setup_content_db() -> void:
	var content_db: Node = load("res://autoload/content_db.gd").new()
	content_db.name = "ContentDB"
	get_root().add_child(content_db)


func _validate_battle(battle_id: String, seed: int) -> void:
	var director: RefCounted = load("res://systems/battle/battle_director.gd").new()
	var result: Dictionary = director.run_battle(
		{
			"battle_id": battle_id,
			"event_instance_id": "%s_%d" % [battle_id, seed],
			"map_id": "map_world_a_02_ashen_sanctum",
			"hero_snapshot": {
				"hero_id": "hero_pilgrim_a01"
			},
			"equipped_strategy_ids": ["strategy_support_drone", "strategy_demon_eye", "strategy_field_prayer"],
			"battle_seed": seed
		}
	)
	var entities: Array = result.get("map_effects", {}).get("entities", [])
	var living: Array = []
	for entity_value in entities:
		if typeof(entity_value) != TYPE_DICTIONARY:
			continue
		var entity: Dictionary = entity_value
		if bool(entity.get("alive", false)):
			living.append(entity)
	for i in range(living.size()):
		var a: Dictionary = living[i]
		var a_pos: Vector2 = _to_vec2(a.get("position", []))
		var a_radius: float = float(a.get("collision_radius", 18.0))
		for j in range(i + 1, living.size()):
			var b: Dictionary = living[j]
			var b_pos: Vector2 = _to_vec2(b.get("position", []))
			var b_radius: float = float(b.get("collision_radius", 18.0))
			var actual_distance: float = a_pos.distance_to(b_pos)
			var min_distance: float = a_radius + b_radius + MIN_BUFFER
			_assert_true(
				actual_distance + 0.25 >= min_distance,
				"%s 存活单位发生重叠：%s 与 %s 距离 %.2f，小于 %.2f。" % [
					battle_id,
					String(a.get("entity_id", "")),
					String(b.get("entity_id", "")),
					actual_distance,
					min_distance
				]
			)


func _to_vec2(value: Variant) -> Vector2:
	if typeof(value) == TYPE_ARRAY:
		var points: Array = value
		if points.size() >= 2:
			return Vector2(float(points[0]), float(points[1]))
	return Vector2.ZERO


func _assert_true(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)
	printerr("ASSERT FAILED: %s" % message)


func _print_result_and_exit() -> void:
	if _failures.is_empty():
		print("SMOKE TEST PASS: auto battle alive entities preserve visible spacing.")
		quit(0)
		return
	printerr("SMOKE TEST FAIL (%d):" % _failures.size())
	for message: String in _failures:
		printerr("- %s" % message)
	quit(1)
