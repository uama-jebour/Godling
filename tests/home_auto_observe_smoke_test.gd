extends SceneTree

const SAVE_PATH := "user://progression_state.json"

var _failures: Array[String] = []
var _had_save_file := false
var _original_save_text := ""


func _initialize() -> void:
	call_deferred("_run_suite")


func _run_suite() -> void:
	_backup_save_file()
	_setup_singletons()
	await _test_home_button_launches_auto_observer()
	_restore_save_file()
	_teardown_singletons()
	_print_result_and_exit()


func _setup_singletons() -> void:
	var content_db: Node = load("res://autoload/content_db.gd").new()
	content_db.name = "ContentDB"
	get_root().add_child(content_db)

	var progression: Node = load("res://autoload/progression_state.gd").new()
	progression.name = "ProgressionState"
	get_root().add_child(progression)

	var run_state: Node = load("res://autoload/run_state.gd").new()
	run_state.name = "RunState"
	get_root().add_child(run_state)


func _backup_save_file() -> void:
	_had_save_file = FileAccess.file_exists(SAVE_PATH)
	if _had_save_file:
		_original_save_text = FileAccess.get_file_as_string(SAVE_PATH)


func _restore_save_file() -> void:
	if _had_save_file:
		var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
		if file != null:
			file.store_string(_original_save_text)
		return
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))


func _teardown_singletons() -> void:
	for node_name in ["RunState", "ProgressionState", "ContentDB"]:
		var node := get_root().get_node_or_null(node_name)
		if node != null:
			node.free()


func _test_home_button_launches_auto_observer() -> void:
	var scene: PackedScene = load("res://scenes/bootstrap.tscn")
	_assert_true(scene != null, "无法加载 bootstrap 场景")
	if scene == null:
		return
	var instance: Node = scene.instantiate()
	get_root().add_child(instance)
	await process_frame
	await process_frame
	await process_frame
	var observe_button := _find_button_by_text(instance, "测试观战")
	_assert_true(observe_button != null, "家园页应存在测试观战按钮")
	if observe_button == null:
		return
	_assert_true(not observe_button.disabled, "测试观战按钮默认应可点击")
	observe_button.emit_signal("pressed")
	await process_frame
	await process_frame
	var preview_instance: Node = instance.get("_preview_instance")
	_assert_true(preview_instance != null and is_instance_valid(preview_instance), "点击测试观战后应打开 battle runner")
	if preview_instance != null and is_instance_valid(preview_instance):
		var wait_button := preview_instance.find_child("WaitButton", true, false) as Button
		_assert_true(wait_button != null, "测试观战应进入同一套 auto_scene 观战链路")
		preview_instance.queue_free()
		await process_frame
	instance.queue_free()
	await process_frame


func _find_button_by_text(root: Node, text: String) -> Button:
	for node in root.find_children("*", "Button", true, false):
		var button := node as Button
		if button != null and button.text == text:
			return button
	return null


func _assert_true(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)
	printerr("ASSERT FAILED: %s" % message)


func _print_result_and_exit() -> void:
	if _failures.is_empty():
		print("SMOKE TEST PASS: home auto observe button launches tactical auto battle scene.")
		quit(0)
		return
	printerr("SMOKE TEST FAIL (%d):" % _failures.size())
	for message: String in _failures:
		printerr("- %s" % message)
	quit(1)
