extends SceneTree

const POSITION_EPSILON := 0.5

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run_suite")


func _run_suite() -> void:
	_setup_content_db()
	await _test_auto_preview_tokens_converge_toward_new_target()
	_print_result_and_exit()


func _setup_content_db() -> void:
	var content_db: Node = load("res://autoload/content_db.gd").new()
	content_db.name = "ContentDB"
	get_root().add_child(content_db)


func _test_auto_preview_tokens_converge_toward_new_target() -> void:
	var scene: PackedScene = load("res://scenes/battle/battle_runner.tscn")
	_assert_true(scene != null, "应能加载 battle_runner 场景")
	if scene == null:
		return
	var instance: Node = scene.instantiate()
	get_root().add_child(instance)

	var content_db: Node = get_root().get_node_or_null("ContentDB")
	var battle_def: Dictionary = content_db.get_battle("battle_auto_a01_probe")
	_assert_true(not battle_def.is_empty(), "应存在 auto battle 样例定义")
	if battle_def.is_empty():
		return

	instance.call(
		"start_interactive_battle",
		{
			"battle_id": "battle_auto_a01_probe",
			"event_instance_id": "auto_smooth_motion",
			"map_id": "map_world_a_02_ashen_sanctum",
			"hero_snapshot": {
				"hero_id": "hero_pilgrim_a01",
				"runtime_stats": {
					"hp": 48.0,
					"attack_power": 5.0
				}
			},
			"equipped_strategy_ids": ["strategy_support_drone"],
			"battle_seed": 202
		},
		battle_def,
		{
			"battle_backend": "auto_scene",
			"interactive_mode": false,
			"preview_speed": 1.0
		}
	)

	var controller: Node = instance.get_node_or_null("BattleSceneController")
	_assert_true(controller != null, "应能获取 BattleSceneController")
	if controller == null:
		return
	controller.set("_auto_preview_paused", true)
	await process_frame
	await process_frame

	var timeline: Array = controller.get("_timeline")
	_assert_true(timeline.size() > 1, "自动观战时间线应至少包含两帧")
	if timeline.size() <= 1:
		return

	var token := controller.get("_arena_nodes").get("hero_1") as Control
	_assert_true(token != null, "应能获取 hero_1 token")
	if token == null:
		return

	var first_frame: Dictionary = timeline[0]
	var target_frame: Dictionary = _find_frame_with_moved_entity(timeline, "hero_1")
	_assert_true(not target_frame.is_empty(), "应能找到 hero_1 发生位移的后续帧")
	if target_frame.is_empty():
		return

	var target_state: Dictionary = controller.call("_auto_frame_to_scene_state", target_frame)
	var hero_entity: Dictionary = target_state.get("hero_entity", {})
	var motion: Dictionary = controller.call("_build_motion_profile", hero_entity, target_state)
	var target_position: Vector2 = controller.call("_world_to_arena_position", target_state, hero_entity, token) + Vector2(
		float(motion.get("offset_x", 0.0)),
		float(motion.get("offset_y", 0.0))
	)
	var start_position: Vector2 = token.position
	_assert_true(
		start_position.distance_to(target_position) > POSITION_EPSILON,
		"测试前提失败：初始位置应与目标位置不同"
	)
	if start_position.distance_to(target_position) <= POSITION_EPSILON:
		return

	controller.call("_render_state", target_state, String(target_frame.get("headline", "smooth motion test")))

	var immediate_position: Vector2 = token.position
	_assert_true(
		immediate_position.distance_to(target_position) > POSITION_EPSILON,
		"切换到新帧后首帧不应直接瞬移到目标点"
	)

	await process_frame
	var after_one_frame: Vector2 = token.position
	for _i in 12:
		await process_frame
	var after_many_frames: Vector2 = token.position

	_assert_true(
		after_many_frames.distance_to(target_position) < after_one_frame.distance_to(target_position),
		"后续渲染帧应让 token 逐步逼近目标点"
	)
	_assert_true(
		after_many_frames.distance_to(target_position) < start_position.distance_to(target_position),
		"最终位置应比起点更接近目标点"
	)


func _find_frame_with_moved_entity(timeline: Array, entity_id: String) -> Dictionary:
	if timeline.is_empty():
		return {}
	var first_frame_value: Variant = timeline[0]
	if typeof(first_frame_value) != TYPE_DICTIONARY:
		return {}
	var first_position: Vector2 = _entity_position_from_frame(first_frame_value, entity_id)
	for index in range(1, timeline.size()):
		var frame_value: Variant = timeline[index]
		if typeof(frame_value) != TYPE_DICTIONARY:
			continue
		var frame_position: Vector2 = _entity_position_from_frame(frame_value, entity_id)
		if frame_position.distance_to(first_position) > POSITION_EPSILON:
			return frame_value
	return {}


func _entity_position_from_frame(frame: Dictionary, entity_id: String) -> Vector2:
	for entity_value in frame.get("entities", []):
		if typeof(entity_value) != TYPE_DICTIONARY:
			continue
		var entity: Dictionary = entity_value
		if String(entity.get("entity_id", "")) != entity_id:
			continue
		var values: Array = entity.get("position", [])
		if values.size() >= 2:
			return Vector2(float(values[0]), float(values[1]))
	return Vector2.ZERO


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
