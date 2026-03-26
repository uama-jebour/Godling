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

	_test_task_snapshot_and_narrative_branch()
	_test_forced_hint_and_resolution_delta()
	_test_death_and_settlement_snapshot()
	_test_abandon_run()
	_test_startable_map_filter()

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
		["key_silent_litany_hint", "consumable_field_balm"],
		["relic_burned_prayer_wheel"]
	)
	progression.save_to_disk()


func _test_task_snapshot_and_narrative_branch() -> void:
	_start_new_run()
	var start_snapshot: Dictionary = _run_state().get_task_snapshot()
	_assert_true(not start_snapshot.is_empty(), "开局后应可读取任务快照")
	_assert_true(_has_task(start_snapshot.get("active_tasks", []), "task_a02_mainline_narrative"), "首回合应存在主线叙事任务")

	_run_state().select_event("event_a02_mainline_narrative")
	var narrative_result: Dictionary = _run_state().complete_selected_event_with_option("focus_listen")
	_assert_true(not narrative_result.is_empty(), "主线叙事应可通过选项完成")
	_maybe_resolve_forced()

	var after_mainline_snapshot: Dictionary = _run_state().get_task_snapshot()
	_assert_true(
		_has_task(after_mainline_snapshot.get("active_tasks", []), "task_a02_sidebranch_omen"),
		"主线叙事后应解锁支线叙事任务"
	)

	_run_state().select_event("event_a02_sidebranch_omen")
	var side_result: Dictionary = _run_state().complete_selected_event_with_option("track_marks")
	_assert_true(not side_result.is_empty(), "支线叙事应可通过选项完成")
	_maybe_resolve_forced()

	var progress: Dictionary = _run_state().get_progress_snapshot()
	_assert_true(progress.get("story_flags", []).has("sidebranch_trail"), "支线追踪选项应写入 sidebranch_trail")

	var side_battle_snapshot: Dictionary = _run_state().get_task_snapshot()
	_assert_true(
		_has_task(side_battle_snapshot.get("active_tasks", []), "task_a02_sidebranch_battle"),
		"支线叙事后应出现支线战斗任务"
	)


func _test_forced_hint_and_resolution_delta() -> void:
	_start_new_run()
	var delta_start: Dictionary = _run_state().get_last_resolution_delta()
	_assert_true(String(delta_start.get("stage", "")) == "run_started", "新开局应产出 run_started delta")

	var hint_turn1: Dictionary = _run_state().get_forced_event_hint()
	_assert_true(String(hint_turn1.get("status", "")) == "locked", "第1回合强制事件提示应为 locked")

	var guard := 0
	while int(_run_state().get_turn_summary().get("turn", 0)) < 4 and guard < 12:
		if not _complete_one_event():
			break
		_maybe_resolve_forced()
		guard += 1
	_assert_true(guard < 12, "推进到第4回合时不应触发死循环保护")

	var hint_late: Dictionary = _run_state().get_forced_event_hint()
	_assert_true(
		String(hint_late.get("status", "")) != "locked",
		"第4回合后强制事件提示不应继续保持 locked"
	)

	var delta_after: Dictionary = _run_state().get_last_resolution_delta()
	_assert_true(not String(delta_after.get("headline", "")).is_empty(), "处理事件后应有变化摘要 headline")


func _test_death_and_settlement_snapshot() -> void:
	_start_new_run()
	_run_state().select_event("event_a02_mainline_narrative")
	_run_state().complete_selected_event_with_option("focus_listen")
	_maybe_resolve_forced()

	_run_state().active_run["is_dead"] = true
	var death_result: Dictionary = _run_state().consume_death_result()
	_assert_true(not death_result.is_empty(), "阵亡后应可消费死亡结算")
	_assert_true(
		death_result.get("story_flags_preserved", []).has("mainline_started"),
		"死亡结算应保留剧情标记"
	)

	var temp_loot: Dictionary = _run_state().get_temporary_loot_snapshot()
	_assert_true(temp_loot.get("items", []).is_empty(), "死亡结算后临时物资应清空")
	_assert_true(temp_loot.get("currencies", []).is_empty(), "死亡结算后临时货币应清空")
	_assert_true(temp_loot.get("relics", []).is_empty(), "死亡结算后临时圣遗应清空")

	var death_result_second: Dictionary = _run_state().consume_death_result()
	_assert_true(death_result_second.is_empty(), "死亡结算只能消费一次")

	var settlement_snapshot: Dictionary = _progression_state().build_run_settlement_snapshot({}, death_result)
	_assert_true(String(settlement_snapshot.get("status", "")) == "dead", "死亡结算快照状态应为 dead")
	_assert_true(
		settlement_snapshot.get("story_flags_preserved", []).has("mainline_started"),
		"死亡结算快照应保留剧情标记"
	)


func _test_abandon_run() -> void:
	_start_new_run()
	_assert_true(not _run_state().get_turn_summary().is_empty(), "开局后应存在 run summary")
	_run_state().abandon_current_run()
	_assert_true(_run_state().get_turn_summary().is_empty(), "放弃 run 后应清空 summary")
	_assert_true(String(_run_state().get_last_resolution_delta().get("stage", "")) == "run_abandoned", "放弃 run 后应记录 run_abandoned delta")


func _test_startable_map_filter() -> void:
	var context: Dictionary = _progression_state().get_context_for_conditions()
	context["turn"] = 1
	context["danger_level"] = 0
	var startable_maps: Array = _content_db().list_startable_maps(context)
	var has_a02 := false
	var has_a01 := false
	for map_value in startable_maps:
		if typeof(map_value) != TYPE_DICTIONARY:
			continue
		var map_id: String = String(map_value.get("id", ""))
		if map_id == "map_world_a_02_ashen_sanctum":
			has_a02 = true
		if map_id == "map_world_a_01_ruined_crossing":
			has_a01 = true
	_assert_true(has_a02, "当前内容下 A02 应为可开局地图")
	_assert_true(has_a01, "当前内容下 A01 应为可开局地图")
	_assert_true(startable_maps.size() >= 2, "当前应至少有2张可开局地图")


func _has_task(tasks: Array, task_id: String) -> bool:
	for task_value in tasks:
		if typeof(task_value) != TYPE_DICTIONARY:
			continue
		if String(task_value.get("id", "")) == task_id:
			return true
	return false


func _complete_one_event() -> bool:
	var board: Dictionary = _run_state().get_board_snapshot()
	var random_slots: Array = board.get("random_slots", [])
	if not random_slots.is_empty():
		var event_id: String = String(random_slots[0].get("id", ""))
		_run_state().select_event(event_id)
		_run_state().complete_selected_event(true)
		return true
	var fixed_events: Array = board.get("fixed_events", [])
	if not fixed_events.is_empty():
		var fixed_id: String = String(fixed_events[0].get("id", ""))
		_run_state().select_event(fixed_id)
		_run_state().complete_selected_event(true)
		return true
	return false


func _maybe_resolve_forced() -> void:
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
		print("SMOKE TEST PASS: run-state visibility APIs validated.")
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
