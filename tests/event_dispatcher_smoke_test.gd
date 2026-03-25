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

	_test_battle_and_random_dispatch()
	_test_narrative_dispatch()
	_test_forced_fail_keeps_no_rewards()

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


func _test_battle_and_random_dispatch() -> void:
	_start_new_run()
	var board: Dictionary = _run_state().get_board_snapshot()
	var random_slots: Array = board.get("random_slots", [])
	_assert_true(not random_slots.is_empty(), "首回合必须有随机事件可用于分发测试")
	if random_slots.is_empty():
		return

	var battle_event: Dictionary = _find_random_event_by_type(random_slots, "battle")
	var random_event: Dictionary = _find_random_event_by_type(random_slots, "random")

	_assert_true(not battle_event.is_empty(), "首回合应至少有1个 battle 类型随机事件")
	_assert_true(not random_event.is_empty(), "首回合应至少有1个 random 类型随机事件")
	if battle_event.is_empty() or random_event.is_empty():
		return

	var battle_result: Dictionary = _run_selected_event(String(battle_event.get("id", "")))
	var battle_dispatch: Dictionary = battle_result.get("dispatch_result", {})
	_assert_true(not battle_dispatch.is_empty(), "battle 事件应返回 dispatch_result")
	_assert_true(String(battle_dispatch.get("resolution_type", "")) == "battle", "battle 事件应走 battle 分发")
	_assert_true(bool(battle_dispatch.get("accepted", false)), "battle 分发结果应 accepted=true")
	var battle_payload: Dictionary = battle_dispatch.get("battle_result", {})
	_assert_true(String(battle_payload.get("status", "")) == "battle_runner_resolved", "battle 分发应经过 headless battle runner")
	_assert_true(bool(battle_payload.get("victory", false)), "battle stub 结果应返回 victory=true")
	_assert_true(
		int(battle_payload.get("map_effects", {}).get("elapsed_ticks", 0)) > 0,
		"battle 分发结果应包含真实推进的 tick 信息"
	)
	var battle_request: Dictionary = battle_dispatch.get("battle_request", {})
	_assert_true(not String(battle_request.get("battle_id", "")).is_empty(), "battle_request 应包含 battle_id")
	_assert_true(not String(battle_request.get("event_instance_id", "")).is_empty(), "battle_request 应包含 event_instance_id")
	_assert_true(not String(battle_request.get("map_id", "")).is_empty(), "battle_request 应包含 map_id")

	_start_new_run()
	var board_for_random: Dictionary = _run_state().get_board_snapshot()
	var random_only_event: Dictionary = _find_random_event_by_type(board_for_random.get("random_slots", []), "random")
	_assert_true(not random_only_event.is_empty(), "重开首回合后应至少有1个 random 类型随机事件")
	if random_only_event.is_empty():
		return

	var random_result: Dictionary = _run_selected_event(String(random_only_event.get("id", "")))
	var random_dispatch: Dictionary = random_result.get("dispatch_result", {})
	_assert_true(not random_dispatch.is_empty(), "random 事件应返回 dispatch_result")
	_assert_true(String(random_dispatch.get("resolution_type", "")) == "random", "random 事件应走 random 分发")
	_assert_true(not random_dispatch.get("random_result", {}).is_empty(), "random 分发应包含 random_result")


func _test_narrative_dispatch() -> void:
	_start_new_run()
	var selected: Dictionary = _run_state().select_event("event_a02_mainline_narrative")
	_assert_true(not selected.is_empty(), "应可选中主线叙事事件")
	if selected.is_empty():
		return

	var result: Dictionary = _run_state().complete_selected_event(true)
	var dispatch: Dictionary = result.get("dispatch_result", {})
	_assert_true(not dispatch.is_empty(), "叙事事件应返回 dispatch_result")
	_assert_true(String(dispatch.get("resolution_type", "")) == "narrative", "叙事事件应走 narrative 分发")
	_assert_true(not dispatch.get("narrative_result", {}).is_empty(), "narrative 分发应包含 narrative_result")


func _test_forced_fail_keeps_no_rewards() -> void:
	_start_new_run()
	var before: Dictionary = _run_state().get_temporary_loot_snapshot()
	_run_state().active_run["pending_forced_event"] = _content_db().get_event("event_a02_forced_demon_ambush")

	var result: Dictionary = _run_state().resolve_pending_forced_event(false)
	_assert_true(not result.is_empty(), "强制事件失败分支应返回结果")
	_assert_true(not bool(result.get("success", true)), "强制事件失败分支应返回 success=false")

	var dispatch: Dictionary = result.get("dispatch_result", {})
	_assert_true(not dispatch.is_empty(), "强制事件失败分支应返回 dispatch_result")
	_assert_true(not bool(dispatch.get("success", true)), "分发结果应标记 success=false")

	var after: Dictionary = _run_state().get_temporary_loot_snapshot()
	_assert_true(before == after, "强制事件失败时不应发放奖励")


func _run_selected_event(event_id: String) -> Dictionary:
	var selected: Dictionary = _run_state().select_event(event_id)
	_assert_true(not selected.is_empty(), "选择事件失败：%s" % event_id)
	if selected.is_empty():
		return {}
	return _run_state().complete_selected_event(true)


func _find_random_event_by_type(random_slots: Array, resolution_type: String) -> Dictionary:
	for event_def: Dictionary in random_slots:
		if String(event_def.get("resolution_type", "")) == resolution_type:
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
		print("SMOKE TEST PASS: event dispatcher boundary validated.")
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
