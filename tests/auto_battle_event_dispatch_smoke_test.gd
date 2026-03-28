extends SceneTree

const SAVE_PATH := "user://progression_state.json"

var _failures: Array[String] = []
var _had_save_file := false
var _original_save_text := ""


func _initialize() -> void:
	call_deferred("_run_suite")


func _run_suite() -> void:
	_setup_singletons()
	_backup_save_file()
	_reset_progression_to_defaults()
	_test_board_event_dispatches_to_auto_battle()
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


func _test_board_event_dispatches_to_auto_battle() -> void:
	var loadout: Dictionary = _progression_state().get_home_loadout()
	_run_state().start_new_run(
		"map_world_a_02_ashen_sanctum",
		String(loadout.get("hero_id", "hero_pilgrim_a01")),
		loadout.get("carried_item_ids", []),
		loadout.get("equipped_relic_ids", [])
	)
	var board: Dictionary = _run_state().get_board_snapshot()
	var random_slots: Array = board.get("random_slots", [])
	_assert_true(not random_slots.is_empty(), "首回合应有可推进事件")
	if random_slots.is_empty():
		return
	_run_state().select_event(String(random_slots[0].get("id", "")))
	_run_state().complete_selected_event(true)
	var selected: Dictionary = _select_random_board_event("event_a02_battle_auto_probe")
	_assert_true(not selected.is_empty(), "第2回合后应能选中新灰度 auto battle 固定节点")
	if selected.is_empty():
		return
	var result: Dictionary = _run_state().complete_selected_event(true)
	var battle_result: Dictionary = result.get("dispatch_result", {}).get("battle_result", {})
	_assert_true(String(battle_result.get("status", "")) == "battle_runner_resolved", "新 auto battle 事件应完成 battle 分发")
	_assert_true(
		String(battle_result.get("map_effects", {}).get("simulation_mode", "")) == "auto_units",
		"新 auto battle 事件应走 auto_units 新后端"
	)
	_assert_true(
		not battle_result.get("map_effects", {}).get("triggered_strategy_ids", []).is_empty(),
		"事件内预设策略应实际生效"
	)


func _select_random_board_event(event_id: String) -> Dictionary:
	var board: Dictionary = _run_state().get_board_snapshot()
	for event_value in board.get("random_slots", []):
		if typeof(event_value) != TYPE_DICTIONARY:
			continue
		var event_def: Dictionary = event_value
		if String(event_def.get("id", "")) != event_id:
			continue
		return _run_state().select_event(event_id)
	for event_value in board.get("fixed_events", []):
		if typeof(event_value) != TYPE_DICTIONARY:
			continue
		var fixed_event: Dictionary = event_value
		if String(fixed_event.get("id", "")) != event_id:
			continue
		return _run_state().select_event(event_id)
	return {}


func _assert_true(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)
	printerr("ASSERT FAILED: %s" % message)


func _print_result_and_exit() -> void:
	if _failures.is_empty():
		print("SMOKE TEST PASS: auto battle event dispatch validated.")
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
