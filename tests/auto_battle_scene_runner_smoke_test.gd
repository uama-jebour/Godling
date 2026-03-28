extends SceneTree

var _failures: Array[String] = []
var _battle_result: Dictionary = {}


func _initialize() -> void:
	call_deferred("_run_suite")


func _run_suite() -> void:
	_setup_content_db()
	await _test_auto_scene_runner_playback()
	_print_result_and_exit()


func _setup_content_db() -> void:
	var content_db: Node = load("res://autoload/content_db.gd").new()
	content_db.name = "ContentDB"
	get_root().add_child(content_db)


func _test_auto_scene_runner_playback() -> void:
	var scene: PackedScene = load("res://scenes/battle/battle_runner.tscn")
	if scene == null:
		_assert_true(false, "无法加载 battle runner 场景")
		return
	var instance: Node = scene.instantiate()
	get_root().add_child(instance)
	if instance.has_signal("interactive_battle_finished"):
		instance.connect("interactive_battle_finished", Callable(self, "_on_battle_finished"))
	var battle_def: Dictionary = _content_db().get_battle("battle_auto_a01_probe")
	_assert_true(not battle_def.is_empty(), "应存在 auto battle 样例定义")
	if battle_def.is_empty():
		return
	if instance.has_method("start_interactive_battle"):
		instance.call(
			"start_interactive_battle",
			{
				"battle_id": "battle_auto_a01_probe",
				"event_instance_id": "auto_scene_runner_smoke",
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
				"preview_speed": 120.0
			}
		)
	await process_frame
	await process_frame
	if is_instance_valid(instance):
		var wait_button := instance.find_child("WaitButton", true, false) as Button
		_assert_true(wait_button != null, "auto_scene 观战应保留基础控制按钮")
		if wait_button != null:
			_assert_true(wait_button.text.contains("暂停"), "auto_scene 观战开始后应显示暂停按钮")
	var guard := 0
	while _battle_result.is_empty() and guard < 500:
		guard += 1
		await process_frame
	_assert_true(not _battle_result.is_empty(), "auto_scene 观战结束后应回调 battle 结果")
	if _battle_result.is_empty():
		return
	var map_effects: Dictionary = _battle_result.get("map_effects", {})
	_assert_true(String(_battle_result.get("status", "")) == "battle_runner_resolved", "auto_scene scene 播放后应返回结算结果")
	_assert_true(String(map_effects.get("backend", "")) == "auto_scene", "auto_scene scene 播放后应保留 auto_scene backend 标记")
	_assert_true(int(map_effects.get("timeline_frame_count", 0)) > 0, "auto_scene scene 播放后应返回时间线帧数")


func _on_battle_finished(result: Dictionary) -> void:
	_battle_result = result.duplicate(true)


func _content_db() -> Node:
	return get_root().get_node_or_null("ContentDB")


func _assert_true(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)
	printerr("ASSERT FAILED: %s" % message)


func _print_result_and_exit() -> void:
	if _failures.is_empty():
		print("SMOKE TEST PASS: auto battle scene runner playback verified.")
		quit(0)
		return
	printerr("SMOKE TEST FAIL (%d):" % _failures.size())
	for message: String in _failures:
		printerr("- %s" % message)
	quit(1)
