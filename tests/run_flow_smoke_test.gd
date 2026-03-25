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

	_test_start_state()
	_test_turn_progression_and_selection()
	_test_forced_event_non_turn()
	_test_mainline_to_extraction()

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


func _test_start_state() -> void:
	_start_new_run()
	var summary: Dictionary = _run_state().get_turn_summary()
	_assert_true(summary.get("turn", 0) == 1, "初始回合应为1")
	_assert_true(summary.get("danger_level", -1) == 0, "初始危险度应为0")
	_assert_true(summary.get("random_event_count", 0) >= 4, "首回合随机事件数量应至少为4")
	_assert_true(summary.get("fixed_event_count", 0) >= 1, "首回合应至少存在1个固定事件")
	_assert_true(not bool(summary.get("can_extract", true)), "首回合不应允许撤离")


func _test_turn_progression_and_selection() -> void:
	_start_new_run()
	var board: Dictionary = _run_state().get_board_snapshot()
	var random_slots: Array = board.get("random_slots", [])
	_assert_true(not random_slots.is_empty(), "首回合必须有可选随机事件")
	if random_slots.is_empty():
		return

	var event_id: String = String(random_slots[0].get("id", ""))
	var selected: Dictionary = _run_state().select_event(event_id)
	_assert_true(String(selected.get("id", "")) == event_id, "选择事件后应返回对应事件")

	var result: Dictionary = _run_state().complete_selected_event(true)
	_assert_true(not result.is_empty(), "处理事件后应返回结算结果")

	var summary: Dictionary = _run_state().get_turn_summary()
	_assert_true(summary.get("turn", 0) == 2, "处理1个事件后应进入第2回合")
	_assert_true(summary.get("danger_level", -1) == 1, "处理1个事件后危险度应+1")
	_assert_true(bool(summary.get("can_extract", false)), "处理至少1个事件后应允许撤离")


func _test_forced_event_non_turn() -> void:
	_start_new_run()
	var triggered := false
	var turn_before := -1
	var turn_after := -1

	for _i: int in range(24):
		var advanced: bool = _complete_first_available_turn_event()
		if not advanced:
			break
		var pending: Dictionary = _run_state().get_pending_forced_event()
		if pending.is_empty():
			continue

		triggered = true
		turn_before = int(_run_state().get_turn_summary().get("turn", 0))
		var resolved: Dictionary = _run_state().resolve_pending_forced_event(true)
		_assert_true(not resolved.is_empty(), "触发后应可结算强制事件")
		turn_after = int(_run_state().get_turn_summary().get("turn", 0))
		break

	_assert_true(triggered, "第4回合后应在多次推进中触发至少一次强制袭击")
	if triggered:
		_assert_true(turn_before == turn_after, "强制袭击事件不应消耗回合")


func _test_mainline_to_extraction() -> void:
	_start_new_run()
	var run_state: Node = _run_state()

	run_state.debug_grant_temp_item("key_silent_litany", 1)

	var mainline_narrative: Dictionary = run_state.select_event("event_a02_mainline_narrative")
	_assert_true(not mainline_narrative.is_empty(), "应能选中主线叙事事件")

	var submitted: bool = run_state.submit_mainline_item("key_silent_litany", "mainline_item_submitted")
	_assert_true(submitted, "主线提交物应提交成功")

	var narrative_result: Dictionary = run_state.complete_selected_event(true)
	_assert_true(not narrative_result.is_empty(), "主线叙事事件应可完成")
	_maybe_resolve_pending_forced()

	var guard: int = 0
	while int(run_state.get_turn_summary().get("turn", 0)) < 6 and guard < 16:
		var advanced: bool = _complete_first_available_turn_event()
		if not advanced:
			break
		_maybe_resolve_pending_forced()
		guard += 1

	_assert_true(guard < 16, "推进到第6回合时触发了防死循环保护")

	var mainline_battle: Dictionary = run_state.select_event("event_a02_mainline_battle")
	_assert_true(not mainline_battle.is_empty(), "第6回合后应可选中主线战斗事件")

	var battle_result: Dictionary = run_state.complete_selected_event(true)
	_assert_true(not battle_result.is_empty(), "主线战斗应可完成")
	_maybe_resolve_pending_forced()

	var extraction_event: Dictionary = run_state.get_extraction_event()
	_assert_true(String(extraction_event.get("id", "")) == "event_a02_extraction_breakthrough", "完成主线后应开启撤离事件")

	var extraction_result: Dictionary = run_state.resolve_extraction_event(true)
	_assert_true(String(extraction_result.get("status", "")) == "success", "撤离事件应返回成功状态")
	_assert_true(not extraction_result.get("extraction_result", {}).is_empty(), "撤离成功后应返回入库数据")

	_progression_state().add_loot_from_run(extraction_result.get("extraction_result", {}))
	_assert_true(
		_progression_state().state.get("unlock_flags", []).has("equipment_tab_enabled"),
		"撤离成功后应持久化equipment_tab_enabled"
	)


func _complete_first_available_turn_event() -> bool:
	var board: Dictionary = _run_state().get_board_snapshot()
	var random_slots: Array = board.get("random_slots", [])
	var fixed_events: Array = board.get("fixed_events", [])

	if not random_slots.is_empty():
		var event_id: String = String(random_slots[0].get("id", ""))
		_run_state().select_event(event_id)
		_run_state().complete_selected_event(true)
		return true

	if not fixed_events.is_empty():
		var fixed_id: String = String(fixed_events[0].get("id", ""))
		_run_state().select_event(fixed_id)
		_run_state().complete_selected_event(true)
		return true

	_assert_true(false, "没有可用于推进的事件")
	return false


func _maybe_resolve_pending_forced() -> void:
	var pending: Dictionary = _run_state().get_pending_forced_event()
	if pending.is_empty():
		return
	_run_state().resolve_pending_forced_event(true)


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
		print("SMOKE TEST PASS: run flow and interaction logic validated.")
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
