extends Control

@onready var summary_label: RichTextLabel = %SummaryLabel
@onready var event_list: VBoxContainer = %EventList
@onready var refresh_button: Button = %RefreshButton
@onready var debug_give_item_button: Button = %DebugGiveItemButton

@onready var selected_event_title: Label = %SelectedEventTitle
@onready var selected_event_meta: Label = %SelectedEventMeta
@onready var selected_event_reward: RichTextLabel = %SelectedEventReward
@onready var action_button: Button = %ActionButton
@onready var extract_button: Button = %ExtractButton
@onready var resolve_forced_button: Button = %ResolveForcedButton
@onready var log_output: RichTextLabel = %LogOutput

var selected_event_id: String = ""
var panel_event: Dictionary = {}
var panel_mode: String = "none"
var log_lines: Array[String] = []


func _ready() -> void:
	InputSetup.ensure_defaults()
	log_output.bbcode_enabled = false
	_ensure_demo_home_loadout()
	_start_demo_run()
	_bind_ui_actions()
	_append_log("已进入灰烬圣坛外环，开始第1回合。")
	_refresh_all()


func _start_demo_run() -> void:
	var loadout: Dictionary = _progression_state().get_home_loadout()
	_run_state().start_new_run(
		"map_world_a_02_ashen_sanctum",
		String(loadout.get("hero_id", "hero_pilgrim_a01")),
		loadout.get("carried_item_ids", []),
		loadout.get("equipped_relic_ids", [])
	)


func _bind_ui_actions() -> void:
	refresh_button.pressed.connect(_on_refresh_pressed)
	debug_give_item_button.pressed.connect(_on_debug_give_item_pressed)
	action_button.pressed.connect(_on_action_pressed)
	extract_button.pressed.connect(_on_extract_pressed)
	resolve_forced_button.pressed.connect(_on_resolve_forced_pressed)


func _refresh_all() -> void:
	_render_summary()
	_render_event_list()
	_render_dispatch_panel()
	_render_log()


func _render_summary() -> void:
	var summary: Dictionary = _run_state().get_turn_summary()
	if summary.is_empty():
		summary_label.text = "[color=#ff8f8f]Run initialization failed.[/color]"
		return

	var theme_name: String = _content_db().get_theme_name()
	var loot: Dictionary = _run_state().get_temporary_loot_snapshot()
	var progress: Dictionary = _run_state().get_progress_snapshot()
	var lines: Array[String] = []
	lines.append("[b]主题[/b] %s" % theme_name)
	lines.append("[b]地图[/b] %s (%s)" % [summary.get("map_name_cn", ""), summary.get("map_id", "")])
	lines.append("[b]英雄[/b] %s" % summary.get("hero_id", ""))
	lines.append("[b]回合[/b] %d  [b]危险度[/b] %d" % [summary.get("turn", 0), summary.get("danger_level", 0)])
	lines.append("[b]事件[/b] 随机 %d / 固定 %d" % [summary.get("random_event_count", 0), summary.get("fixed_event_count", 0)])
	lines.append("[b]可撤离[/b] %s" % _bool_text(bool(summary.get("can_extract", false))))
	lines.append("[b]临时战利品[/b] 物资 %d / 货币 %d / 圣遗 %d" % [
		loot.get("items", []).size(),
		loot.get("currencies", []).size(),
		loot.get("relics", []).size()
	])
	lines.append("[b]局内进度[/b] 任务 %d / 剧情标记 %d / 解锁标记 %d" % [
		progress.get("completed_tasks", []).size(),
		progress.get("story_flags", []).size(),
		progress.get("unlock_flags", []).size()
	])
	if not String(summary.get("pending_forced_event_id", "")).is_empty():
		lines.append("[color=#f6b26b][b]强制袭击待处理[/b] %s[/color]" % summary.get("pending_forced_event_id", ""))
	if bool(summary.get("is_extracted", false)):
		lines.append("[color=#b6f6a8][b]状态[/b] 已成功撤离[/color]")
	elif bool(summary.get("is_dead", false)):
		lines.append("[color=#ff9b9b][b]状态[/b] 角色已阵亡[/color]")
	summary_label.text = "\n".join(lines)


func _render_event_list() -> void:
	for child: Node in event_list.get_children():
		child.queue_free()

	var board: Dictionary = _run_state().get_board_snapshot()
	for event_def: Dictionary in board.get("random_slots", []):
		var slot_id: String = String(event_def.get("slot_id", "slot"))
		_add_event_button(event_def, "随机事件 [%s]" % slot_id)
	for event_def: Dictionary in board.get("fixed_events", []):
		_add_event_button(event_def, "固定事件")

	if event_list.get_child_count() == 0:
		var empty_label := Label.new()
		empty_label.add_theme_font_size_override("font_size", 20)
		empty_label.text = "当前没有可处理事件。"
		event_list.add_child(empty_label)


func _add_event_button(event_def: Dictionary, prefix: String) -> void:
	var event_id: String = String(event_def.get("id", ""))
	var event_title: String = String(event_def.get("title", "未命名事件"))
	var resolution_type: String = String(event_def.get("resolution_type", ""))

	var button := Button.new()
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size = Vector2(0, 52)
	button.add_theme_font_size_override("font_size", 21)
	button.text = "%s %s｜%s%s" % [
		prefix,
		event_title,
		resolution_type,
		"  [已选择]" if event_id == selected_event_id and panel_mode == "event" else ""
	]
	button.pressed.connect(_on_event_selected.bind(event_id))
	event_list.add_child(button)


func _render_dispatch_panel() -> void:
	if panel_event.is_empty():
		selected_event_title.text = "未选择事件"
		selected_event_meta.text = "请选择左侧事件，或点击“处理强制袭击事件 / 触发撤离”。"
		selected_event_reward.text = ""
		action_button.disabled = true
		action_button.text = "处理当前事件"
		return

	var event_kind: String = String(panel_event.get("event_kind", ""))
	var resolution_type: String = String(panel_event.get("resolution_type", ""))
	var trigger_mode: String = String(panel_event.get("trigger_mode", ""))
	var battle_id: String = String(panel_event.get("battle_id", ""))

	selected_event_title.text = "%s" % String(panel_event.get("title", "未命名事件"))

	var meta_lines: Array[String] = []
	meta_lines.append("类型：%s / %s" % [event_kind, resolution_type])
	meta_lines.append("触发：%s" % trigger_mode)
	if not battle_id.is_empty():
		meta_lines.append("战斗模板：%s" % battle_id)
	if panel_mode == "forced":
		meta_lines.append("说明：这是额外强制事件，不占用回合。")
	if panel_mode == "extraction":
		meta_lines.append("说明：撤离成功后将把临时战利品写入本地存档。")
	selected_event_meta.text = "\n".join(meta_lines)
	selected_event_reward.text = _build_reward_text(panel_event)

	action_button.disabled = false
	match panel_mode:
		"event":
			action_button.text = "出击并处理该事件"
		"forced":
			action_button.text = "应对强制袭击"
		"extraction":
			action_button.text = "执行撤离事件"
		_:
			action_button.text = "处理当前事件"


func _build_reward_text(event_def: Dictionary) -> String:
	var lines: Array[String] = []
	lines.append("[b]奖励预览[/b]")
	var reward: Dictionary = event_def.get("reward_package", {})

	var currencies: Array = reward.get("currencies", [])
	var items: Array = reward.get("items", [])
	var relics: Array = reward.get("relics", [])
	var story_flags: Array = reward.get("story_flags", [])
	var unlock_flags: Array = reward.get("unlock_flags", [])
	var loot_tables: Array = reward.get("loot_tables", [])

	lines.append("货币：%s" % _format_stack_lines(currencies))
	lines.append("物资：%s" % _format_stack_lines(items))
	lines.append("圣遗：%s" % _format_stack_lines(relics))
	lines.append("剧情标记：%s" % (", ".join(story_flags) if not story_flags.is_empty() else "无"))
	lines.append("系统解锁：%s" % (", ".join(unlock_flags) if not unlock_flags.is_empty() else "无"))
	lines.append("掉落表：%s" % _format_loot_table_lines(loot_tables))

	var requirement: Dictionary = event_def.get("submission_requirement", {})
	if not requirement.is_empty():
		var item_id: String = String(requirement.get("item_id", ""))
		var grant_flag: String = String(requirement.get("grant_flag", ""))
		var has_item: bool = _run_state().has_item_for_requirement(item_id)
		lines.append("")
		lines.append("[b]提交需求[/b]")
		lines.append("所需物品：%s (%s)" % [_item_name(item_id), item_id])
		lines.append("当前是否持有：%s" % _bool_text(has_item))
		if not grant_flag.is_empty():
			lines.append("提交后标记：%s" % grant_flag)

	return "\n".join(lines)


func _format_stack_lines(stacks: Array) -> String:
	if stacks.is_empty():
		return "无"
	var parts: Array[String] = []
	for stack: Dictionary in stacks:
		var item_id: String = String(stack.get("id", ""))
		var count: int = int(stack.get("count", 0))
		parts.append("%s x%d" % [_item_name(item_id), count])
	return ", ".join(parts)


func _format_loot_table_lines(loot_tables: Array) -> String:
	if loot_tables.is_empty():
		return "无"
	var parts: Array[String] = []
	for table_ref: Dictionary in loot_tables:
		parts.append("%s x%d" % [String(table_ref.get("id", "")), int(table_ref.get("rolls", 0))])
	return ", ".join(parts)


func _on_event_selected(event_id: String) -> void:
	var event_def: Dictionary = _run_state().select_event(event_id)
	if event_def.is_empty():
		_append_log("选择事件失败：%s" % event_id)
		return
	selected_event_id = event_id
	_open_panel(event_def, "event")
	_append_log("已选择事件：%s" % event_def.get("title", event_id))
	_refresh_all()


func _on_action_pressed() -> void:
	match panel_mode:
		"event":
			_handle_selected_event()
		"forced":
			_handle_forced_event()
		"extraction":
			_handle_extraction_event()
		_:
			_append_log("未选中可处理的事件。")
			_refresh_all()


func _handle_selected_event() -> void:
	if panel_event.is_empty():
		_append_log("请先选择一个事件。")
		_refresh_all()
		return

	var requirement: Dictionary = panel_event.get("submission_requirement", {})
	if not requirement.is_empty():
		var required_item_id: String = String(requirement.get("item_id", ""))
		var grant_flag: String = String(requirement.get("grant_flag", ""))
		var should_submit: bool = not grant_flag.is_empty() and not _has_story_flag(grant_flag)
		if should_submit:
			if not _run_state().has_item_for_requirement(required_item_id):
				_append_log("该事件需要提交 %s，当前未持有。" % _item_name(required_item_id))
				_refresh_all()
				return
			if _run_state().submit_mainline_item(required_item_id, grant_flag):
				_append_log("已提交主线物品：%s。" % _item_name(required_item_id))
			else:
				_append_log("提交失败：%s。" % required_item_id)
				_refresh_all()
				return

	var result: Dictionary = _run_state().complete_selected_event(true)
	if result.is_empty():
		_append_log("事件处理失败：未获取结果。")
		_refresh_all()
		return

	var resolved_event: Dictionary = result.get("selected_event", {})
	_append_log("事件完成：%s。" % resolved_event.get("title", "未命名事件"))

	selected_event_id = ""
	panel_event = {}
	panel_mode = "none"

	var forced_event: Dictionary = result.get("forced_event", {})
	if not forced_event.is_empty():
		_open_panel(forced_event, "forced")
		_append_log("警告：恶魔袭击触发：%s（不占回合）" % forced_event.get("title", "强制袭击"))

	_refresh_all()


func _on_extract_pressed() -> void:
	var summary: Dictionary = _run_state().get_turn_summary()
	if not bool(summary.get("can_extract", false)):
		_append_log("撤离尚不可用，请至少完成一个事件。")
		_refresh_all()
		return

	var extraction_event: Dictionary = _run_state().get_extraction_event()
	if extraction_event.is_empty():
		_append_log("当前还未满足撤离事件触发条件。")
		_refresh_all()
		return

	_open_panel(extraction_event, "extraction")
	_append_log("已打开撤离事件：%s。" % extraction_event.get("title", "撤离"))
	_refresh_all()


func _handle_extraction_event() -> void:
	var result: Dictionary = _run_state().resolve_extraction_event(true)
	if result.is_empty():
		_append_log("撤离处理失败：无可执行撤离事件。")
		_refresh_all()
		return

	if String(result.get("status", "")) == "success":
		var extraction_result: Dictionary = result.get("extraction_result", {})
		_progression_state().add_loot_from_run(extraction_result)
		_append_log("成功：已撤离并写入本地存档。")
	else:
		_append_log("失败：撤离失败，角色阵亡。")

	panel_event = {}
	panel_mode = "none"
	selected_event_id = ""
	_refresh_all()


func _on_resolve_forced_pressed() -> void:
	var forced_event: Dictionary = _run_state().get_pending_forced_event()
	if forced_event.is_empty():
		_append_log("当前没有待处理的强制袭击事件。")
		_refresh_all()
		return

	_open_panel(forced_event, "forced")
	_append_log("已打开强制袭击事件：%s。" % forced_event.get("title", "强制袭击"))
	_refresh_all()


func _handle_forced_event() -> void:
	var result: Dictionary = _run_state().resolve_pending_forced_event(true)
	if result.is_empty():
		_append_log("强制袭击处理失败：没有待处理事件。")
		_refresh_all()
		return

	var resolved_event: Dictionary = result.get("resolved_event", {})
	_append_log("强制事件已处理：%s。" % resolved_event.get("title", "强制袭击"))

	panel_event = {}
	panel_mode = "none"
	selected_event_id = ""
	_refresh_all()


func _on_refresh_pressed() -> void:
	_append_log("界面已刷新。")
	_refresh_all()


func _on_debug_give_item_pressed() -> void:
	_run_state().debug_grant_temp_item("key_silent_litany", 1)
	_append_log("调试物品已发放：静默祷词。")
	_refresh_all()


func _open_panel(event_def: Dictionary, mode: String) -> void:
	panel_event = event_def.duplicate(true)
	panel_mode = mode
	if mode == "event":
		selected_event_id = String(event_def.get("id", ""))


func _append_log(line: String) -> void:
	log_lines.append("[%s] %s" % [_time_string(), line])
	while log_lines.size() > 16:
		log_lines.remove_at(0)


func _render_log() -> void:
	log_output.text = "\n".join(log_lines)


func _has_story_flag(flag_id: String) -> bool:
	var progress: Dictionary = _run_state().get_progress_snapshot()
	return progress.get("story_flags", []).has(flag_id)


func _item_name(item_id: String) -> String:
	var item_def: Dictionary = _content_db().get_item(item_id)
	if item_def.is_empty():
		return item_id
	var name_cn: String = String(item_def.get("name_cn", ""))
	return item_id if name_cn.is_empty() else name_cn


func _bool_text(value: bool) -> String:
	return "是" if value else "否"


func _time_string() -> String:
	return Time.get_time_string_from_system()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("confirm_event"):
		_on_action_pressed()
	elif event.is_action_pressed("run_extract"):
		_on_extract_pressed()


func _ensure_demo_home_loadout() -> void:
	var loadout: Dictionary = _progression_state().get_home_loadout()
	if String(loadout.get("hero_id", "")).is_empty():
		_progression_state().configure_home_loadout(
			"hero_pilgrim_a01",
			["key_silent_litany_hint"],
			["relic_burned_prayer_wheel"]
		)


func _content_db() -> Node:
	return get_node("/root/ContentDB")


func _run_state() -> Node:
	return get_node("/root/RunState")


func _progression_state() -> Node:
	return get_node("/root/ProgressionState")
