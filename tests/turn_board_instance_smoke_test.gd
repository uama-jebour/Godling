extends SceneTree

const SAVE_PATH := "user://progression_state.json"

var _failures: Array[String] = []
var _had_save_file := false
var _original_save_text := ""


func _initialize() -> void:
	call_deferred("_run_suite")


func _run_suite() -> void:
	randomize()
	_setup_singletons()
	_backup_save_file()
	_reset_progression_to_defaults()

	_test_turn1_event_instances()
	_test_fixed_event_lifecycle()

	_restore_save_file()
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


func _reset_progression_to_defaults() -> void:
	var content: Node = _content_db()
	var progression: Node = _progression_state()
	progression.state = content.get_default_progression_state()
	progression.configure_home_loadout(
		"hero_pilgrim_a01",
		["key_silent_litany_hint"],
		["relic_burned_prayer_wheel"]
	)
	progression.save_to_disk()


func _test_turn1_event_instances() -> void:
	_start_new_run()
	var board: Dictionary = _run_state().get_board_snapshot()
	var random_slots: Array = board.get("random_slots", [])
	var fixed_events: Array = board.get("fixed_events", [])

	_assert_true(not random_slots.is_empty(), "首回合应生成随机事件实例")
	for event_def: Dictionary in random_slots:
		_assert_true(not String(event_def.get("instance_id", "")).is_empty(), "随机事件应包含 instance_id")
		_assert_true(String(event_def.get("event_id", "")) == String(event_def.get("id", "")), "随机事件 event_id 应与 id 一致")
		_assert_true(int(event_def.get("spawn_turn", 0)) == 1, "随机事件 spawn_turn 应记录首回合")

	var mainline: Dictionary = _find_event_by_id(fixed_events, "event_a02_mainline_narrative")
	_assert_true(not mainline.is_empty(), "首回合应存在主线固定事件实例")
	_assert_true(not String(mainline.get("instance_id", "")).is_empty(), "固定事件应包含 instance_id")
	_assert_true(String(mainline.get("line_id", "")) == "line_a02_mainline", "固定事件应包含 line_id")
	_assert_true(String(mainline.get("state", "")) == "active", "固定事件初始 state 应为 active")
	_assert_true(int(mainline.get("spawn_turn", 0)) == 1, "固定事件 spawn_turn 应记录首次挂载回合")


func _test_fixed_event_lifecycle() -> void:
	_start_new_run()
	var board_turn1: Dictionary = _run_state().get_board_snapshot()
	var fixed_turn1: Dictionary = _find_event_by_id(board_turn1.get("fixed_events", []), "event_a02_mainline_narrative")
	var fixed_instance_id: String = String(fixed_turn1.get("instance_id", ""))

	_assert_true(not fixed_instance_id.is_empty(), "固定事件应有可追踪实例ID")

	var random_slots: Array = board_turn1.get("random_slots", [])
	_assert_true(not random_slots.is_empty(), "应有随机事件用于回合推进")
	if random_slots.is_empty():
		return

	_run_state().select_event(String(random_slots[0].get("id", "")))
	_run_state().complete_selected_event(true)

	var board_turn2: Dictionary = _run_state().get_board_snapshot()
	var fixed_turn2: Dictionary = _find_event_by_id(board_turn2.get("fixed_events", []), "event_a02_mainline_narrative")
	_assert_true(not fixed_turn2.is_empty(), "固定事件在未完成前应跨回合保留")
	_assert_true(String(fixed_turn2.get("instance_id", "")) == fixed_instance_id, "固定事件跨回合应保持同一 instance_id")
	_assert_true(int(fixed_turn2.get("spawn_turn", 0)) == 1, "固定事件跨回合应保留首次 spawn_turn")

	_run_state().select_event("event_a02_mainline_narrative")
	_run_state().complete_selected_event(true)

	var board_turn3: Dictionary = _run_state().get_board_snapshot()
	var fixed_turn3: Dictionary = _find_event_by_id(board_turn3.get("fixed_events", []), "event_a02_mainline_narrative")
	_assert_true(fixed_turn3.is_empty(), "固定事件完成后应从事件板移除")

	var progress: Dictionary = _run_state().get_progress_snapshot()
	_assert_true(
		progress.get("completed_tasks", []).has("task_a02_mainline_narrative"),
		"完成固定事件后应记录对应任务完成"
	)


func _find_event_by_id(events: Array, event_id: String) -> Dictionary:
	for event_def: Dictionary in events:
		if String(event_def.get("id", "")) == event_id:
			return event_def
	return {}


func _start_new_run() -> void:
	var loadout: Dictionary = _progression_state().get_home_loadout()
	_run_state().start_new_run(
		"map_world_a_02_ashen_sanctum",
		String(loadout.get("hero_id", "hero_pilgrim_a01")),
		loadout.get("carried_item_ids", []),
		loadout.get("equipped_relic_ids", [])
	)


func _assert_true(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)
	printerr("ASSERT FAILED: %s" % message)


func _print_result_and_exit() -> void:
	if _failures.is_empty():
		print("SMOKE TEST PASS: turn board event instance lifecycle validated.")
		quit(0)
		return

	printerr("SMOKE TEST FAIL (%d):" % _failures.size())
	for message: String in _failures:
		printerr("- %s" % message)
	quit(1)


func _content_db() -> Node:
	return get_root().get_node("ContentDB")


func _progression_state() -> Node:
	return get_root().get_node("ProgressionState")


func _run_state() -> Node:
	return get_root().get_node("RunState")
