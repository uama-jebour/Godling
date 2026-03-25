extends Control

const BATTLE_RUNNER_SCENE := preload("res://scenes/battle/battle_runner.tscn")
const MAP_ICON_BATTLE := preload("res://assets/ui/map_icons/battle.svg")
const MAP_ICON_RANDOM := preload("res://assets/ui/map_icons/random.svg")
const MAP_ICON_NARRATIVE := preload("res://assets/ui/map_icons/narrative.svg")
const MAP_ICON_FORCED := preload("res://assets/ui/map_icons/forced.svg")
const MAP_ICON_EXTRACT := preload("res://assets/ui/map_icons/extract.svg")
const BOOTSTRAP_WINDOW_SIZE := Vector2i(1820, 1120)
const BOOTSTRAP_WINDOW_MIN_SIZE := Vector2i(1560, 940)

@onready var summary_label: RichTextLabel = %SummaryLabel
@onready var map_surface: Control = %MapSurface
@onready var marker_layer: Control = %MarkerLayer
@onready var map_hint_label: Label = %MapHintLabel
@onready var map_hover_tooltip: PanelContainer = %MapHoverTooltip
@onready var map_hover_label: Label = %MapHoverLabel
@onready var refresh_button: Button = %RefreshButton
@onready var debug_give_item_button: Button = %DebugGiveItemButton
@onready var preview_battle_button: Button = %PreviewBattleButton

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
var _preview_instance: Node
var _hovered_event: Dictionary = {}
var _hovered_panel_mode: String = "none"


func _enter_tree() -> void:
	_configure_window_size()


func _ready() -> void:
	InputSetup.ensure_defaults()
	_configure_window_size()
	log_output.bbcode_enabled = false
	if map_surface != null and not map_surface.resized.is_connected(_on_map_surface_resized):
		map_surface.resized.connect(_on_map_surface_resized)
	_ensure_demo_home_loadout()
	_start_demo_run()
	_bind_ui_actions()
	_append_log("已进入灰烬圣坛外环，开始第1回合。")
	_refresh_all()
	call_deferred("_configure_window_size")


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
	preview_battle_button.pressed.connect(_on_preview_battle_pressed)
	action_button.pressed.connect(_on_action_pressed)
	extract_button.pressed.connect(_on_extract_pressed)
	resolve_forced_button.pressed.connect(_on_resolve_forced_pressed)


func _refresh_all() -> void:
	_render_summary()
	_render_map_events()
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


func _render_map_events() -> void:
	if marker_layer == null:
		return
	for child: Node in marker_layer.get_children():
		if child == map_hover_tooltip:
			continue
		child.queue_free()

	var board: Dictionary = _run_state().get_board_snapshot()
	var map_def: Dictionary = _content_db().get_map(String(_run_state().active_run.get("map_id", "")))
	var markers: Array = []
	var fixed_index := 0
	for event_def: Dictionary in board.get("random_slots", []):
		var slot_position: Array = event_def.get("slot_position", [0, 0])
		markers.append(_build_marker_spec(event_def, Vector2(float(slot_position[0]), float(slot_position[1])), "event", false))
	for event_def: Dictionary in board.get("fixed_events", []):
		markers.append(_build_marker_spec(event_def, _fixed_event_position(fixed_index, map_def), "event", true))
		fixed_index += 1
	var forced_event: Dictionary = _run_state().get_pending_forced_event()
	if not forced_event.is_empty():
		markers.append(_build_marker_spec(forced_event, Vector2(772, 112), "forced", true))
	var extraction_event: Dictionary = _run_state().get_extraction_event()
	var summary: Dictionary = _run_state().get_turn_summary()
	if bool(summary.get("can_extract", false)) and not extraction_event.is_empty():
		markers.append(_build_marker_spec(extraction_event, Vector2(110, 468), "extraction", true))

	if map_surface != null and map_surface.has_method("set_event_markers"):
		map_surface.call("set_event_markers", markers)
	for marker: Dictionary in markers:
		_add_map_marker(marker)

	if map_hint_label == null:
		return
	if markers.is_empty():
		map_hint_label.text = "当前地图上没有可处理事件。"
	else:
		map_hint_label.text = "点击地图事件点进入处理。战斗事件会直接进入出击战斗。"

func _build_marker_spec(event_def: Dictionary, raw_position: Vector2, marker_mode: String, is_fixed: bool) -> Dictionary:
	var kind: String = String(event_def.get("resolution_type", "battle"))
	if marker_mode == "forced":
		kind = "forced"
	elif marker_mode == "extraction":
		kind = "extract"
	return {
		"event": event_def.duplicate(true),
		"x": raw_position.x,
		"y": raw_position.y,
		"title": String(event_def.get("title", "未命名事件")),
		"kind": kind,
		"marker_mode": marker_mode,
		"is_fixed": is_fixed,
		"is_selected": String(event_def.get("id", "")) == selected_event_id and panel_mode == "event"
	}


func _fixed_event_position(index: int, map_def: Dictionary) -> Vector2:
	var presets := [
		Vector2(620, 94),
		Vector2(770, 146),
		Vector2(126, 462)
	]
	if index < presets.size():
		return presets[index]
	var anchors: Array = map_def.get("random_slot_anchors", [])
	if anchors.is_empty():
		return Vector2(620 + (index * 40), 94 + (index * 28))
	var anchor: Dictionary = anchors[index % anchors.size()]
	var position: Array = anchor.get("position", [620, 94])
	return Vector2(float(position[0]), float(position[1]))


func _add_map_marker(marker: Dictionary) -> void:
	var button := Button.new()
	button.custom_minimum_size = Vector2(136, 54)
	button.size = Vector2(136, 54)
	button.text = "%s\n%s" % [_marker_badge_text(marker), _marker_short_title(String(marker.get("title", "")))]
	button.icon = _marker_icon(String(marker.get("kind", "battle")))
	button.expand_icon = true
	button.add_theme_font_size_override("font_size", 14)
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	var color: Color = _marker_color(String(marker.get("kind", "battle")))
	button.modulate = color
	if bool(marker.get("is_selected", false)):
		button.scale = Vector2(1.06, 1.06)
	var design_size := Vector2(920.0, 560.0)
	var layer_size: Vector2 = marker_layer.size
	var scaled := Vector2(
		float(marker.get("x", 0.0)) / design_size.x * max(1.0, layer_size.x),
		float(marker.get("y", 0.0)) / design_size.y * max(1.0, layer_size.y)
	)
	button.position = scaled - Vector2(64, 26)
	button.pressed.connect(_on_map_event_pressed.bind(marker))
	button.mouse_entered.connect(func() -> void:
		_show_map_marker_hover(marker, button)
	)
	button.mouse_exited.connect(_hide_map_marker_hover)
	marker_layer.add_child(button)


func _render_dispatch_panel() -> void:
	var display_event: Dictionary = panel_event
	var display_mode: String = panel_mode
	var is_hover_preview := false
	if not _hovered_event.is_empty():
		display_event = _hovered_event
		display_mode = _hovered_panel_mode
		is_hover_preview = true

	if display_event.is_empty():
		selected_event_title.text = "未选择事件"
		selected_event_meta.text = "请选择左侧事件，或点击“处理强制袭击事件 / 触发撤离”。"
		selected_event_reward.text = ""
		action_button.disabled = true
		action_button.text = "处理当前事件"
		return

	var event_kind: String = String(display_event.get("event_kind", ""))
	var resolution_type: String = String(display_event.get("resolution_type", ""))
	var trigger_mode: String = String(display_event.get("trigger_mode", ""))
	var battle_id: String = String(display_event.get("battle_id", ""))

	selected_event_title.text = "%s%s" % [
		String(display_event.get("title", "未命名事件")),
		" [预览]" if is_hover_preview else ""
	]

	var meta_lines: Array[String] = []
	meta_lines.append("类型：%s / %s" % [event_kind, resolution_type])
	meta_lines.append("触发：%s" % trigger_mode)
	if not battle_id.is_empty():
		meta_lines.append("战斗模板：%s" % battle_id)
	if display_mode == "forced":
		meta_lines.append("说明：这是额外强制事件，不占用回合。")
	if display_mode == "extraction":
		meta_lines.append("说明：撤离成功后将把临时战利品写入本地存档。")
	if is_hover_preview:
		meta_lines.append("提示：当前为鼠标悬停预览，点击地图事件点后正式处理。")
	selected_event_meta.text = "\n".join(meta_lines)
	selected_event_reward.text = _build_reward_text(display_event)

	action_button.disabled = is_hover_preview
	match display_mode:
		"event":
			action_button.text = "出击并处理该事件" if not is_hover_preview else "点击地图点后处理该事件"
		"forced":
			action_button.text = "应对强制袭击" if not is_hover_preview else "点击地图点后应对强制袭击"
		"extraction":
			action_button.text = "执行撤离事件" if not is_hover_preview else "点击地图点后执行撤离"
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


func _on_map_event_pressed(marker: Dictionary) -> void:
	var marker_mode: String = String(marker.get("marker_mode", "event"))
	var event_def: Dictionary = marker.get("event", {})
	var event_id: String = String(event_def.get("id", ""))
	if event_id.is_empty():
		return
	if marker_mode == "forced":
		_open_panel(event_def, "forced")
		_append_log("已在地图上定位强制袭击：%s。" % String(event_def.get("title", event_id)))
		_refresh_all()
		return
	if marker_mode == "extraction":
		_open_panel(event_def, "extraction")
		_append_log("已在地图上定位撤离点：%s。" % String(event_def.get("title", event_id)))
		_refresh_all()
		return
	var selected: Dictionary = _run_state().select_event(event_id)
	if selected.is_empty():
		selected = event_def.duplicate(true)
	if selected.is_empty():
		return
	selected_event_id = event_id
	_open_panel(selected, "event")
	_append_log("已在地图上定位事件：%s。" % String(selected.get("title", event_id)))
	_refresh_all()
	if String(selected.get("resolution_type", "")) == "battle":
		_launch_interactive_battle(selected)


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

	if String(panel_event.get("resolution_type", "")) == "battle":
		_launch_interactive_battle(panel_event)
		return

	var result: Dictionary = _run_state().complete_selected_event(true)
	_finalize_selected_event_result(result)


func _finalize_selected_event_result(result: Dictionary) -> void:
	if result.is_empty():
		_append_log("事件处理失败：未获取结果。")
		_refresh_all()
		return

	var resolved_event: Dictionary = result.get("selected_event", {})
	var dispatch_result: Dictionary = result.get("dispatch_result", {})
	var battle_result: Dictionary = dispatch_result.get("battle_result", {})
	if not battle_result.is_empty():
		_append_log(
			"事件完成：%s。战斗结果：%s。" % [
				resolved_event.get("title", "未命名事件"),
				"胜利" if bool(battle_result.get("victory", false)) else "失败"
			]
		)
	else:
		_append_log("事件完成：%s。" % resolved_event.get("title", "未命名事件"))

	selected_event_id = ""
	panel_event = {}
	panel_mode = "none"

	var forced_event: Dictionary = result.get("forced_event", {})
	if not forced_event.is_empty():
		_open_panel(forced_event, "forced")
		_append_log("警告：恶魔袭击触发：%s（不占回合）" % forced_event.get("title", "强制袭击"))
	var summary: Dictionary = _run_state().get_turn_summary()
	if bool(summary.get("is_dead", false)):
		_append_log("本次出击失败，英雄倒下，当前 run 已终止。")

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


func _on_preview_battle_pressed() -> void:
	if _preview_instance != null and is_instance_valid(_preview_instance):
		_append_log("战斗预览已打开，请先关闭当前预览。")
		_refresh_all()
		return

	var preview_event: Dictionary = _preview_event_source()
	var preview_request: Dictionary = _run_state().build_battle_preview_request(preview_event)
	if preview_request.is_empty():
		_append_log("无法构造战斗预览请求。")
		_refresh_all()
		return

	var battle_id: String = String(preview_request.get("battle_id", ""))
	var battle_def: Dictionary = _content_db().get_battle(battle_id)
	if battle_def.is_empty():
		_append_log("缺少战斗定义：%s。" % battle_id)
		_refresh_all()
		return

	_preview_instance = BATTLE_RUNNER_SCENE.instantiate()
	get_tree().root.add_child(_preview_instance)
	if _preview_instance.has_method("set_preview_mode"):
		_preview_instance.call("set_preview_mode", true)
	if _preview_instance.tree_exited.is_connected(_on_preview_tree_exited):
		_preview_instance.tree_exited.disconnect(_on_preview_tree_exited)
	_preview_instance.tree_exited.connect(_on_preview_tree_exited)

	if _preview_instance.has_method("execute_battle"):
		_preview_instance.call(
			"execute_battle",
			preview_request,
			battle_def,
			{
				"battle_backend": "scene",
				"success_override": true,
				"preview_mode": true
			}
		)

	var preview_title: String = String(preview_event.get("title", battle_id))
	_append_log("已打开战斗预览：%s。" % preview_title)
	_refresh_all()


func _launch_interactive_battle(event_def: Dictionary) -> void:
	if _preview_instance != null and is_instance_valid(_preview_instance):
		_append_log("当前已有战斗界面打开，请先完成或关闭。")
		_refresh_all()
		return
	var battle_request: Dictionary = _run_state().build_battle_preview_request(event_def)
	if battle_request.is_empty():
		_append_log("无法构造战斗请求。")
		_refresh_all()
		return
	var battle_id: String = String(battle_request.get("battle_id", ""))
	var battle_def: Dictionary = _content_db().get_battle(battle_id)
	if battle_def.is_empty():
		_append_log("缺少战斗定义：%s。" % battle_id)
		_refresh_all()
		return

	_preview_instance = BATTLE_RUNNER_SCENE.instantiate()
	get_tree().root.add_child(_preview_instance)
	if _preview_instance.tree_exited.is_connected(_on_preview_tree_exited):
		_preview_instance.tree_exited.disconnect(_on_preview_tree_exited)
	_preview_instance.tree_exited.connect(_on_preview_tree_exited)
	if _preview_instance.has_signal("interactive_battle_finished"):
		var finished_callable := Callable(self, "_on_interactive_battle_finished")
		if not _preview_instance.is_connected("interactive_battle_finished", finished_callable):
			_preview_instance.connect("interactive_battle_finished", finished_callable)
	if _preview_instance.has_method("start_interactive_battle"):
		_preview_instance.call(
			"start_interactive_battle",
			battle_request,
			battle_def,
			{
				"battle_backend": "scene",
				"interactive_mode": true
			}
		)
	_append_log("已进入可操作战斗：%s。" % String(event_def.get("title", battle_id)))
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


func _on_map_surface_resized() -> void:
	_render_map_events()


func _on_preview_tree_exited() -> void:
	_preview_instance = null
	_refresh_all()


func _on_interactive_battle_finished(battle_result: Dictionary) -> void:
	var result: Dictionary = _run_state().complete_selected_event_with_battle_result(battle_result)
	_finalize_selected_event_result(result)


func _preview_event_source() -> Dictionary:
	if not panel_event.is_empty() and String(panel_event.get("battle_id", "")).is_empty() == false:
		return panel_event.duplicate(true)
	return _content_db().get_event("event_a02_battle_patrol")


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


func _marker_badge_text(marker: Dictionary) -> String:
	match String(marker.get("marker_mode", "event")):
		"forced":
			return "强制袭击"
		"extraction":
			return "撤离点"
	match String(marker.get("kind", "")):
		"battle":
			return "战斗"
		"narrative":
			return "叙事"
		"random":
			return "探索"
		_:
			return "事件"


func _marker_short_title(title: String) -> String:
	if title.length() <= 6:
		return title
	return title.substr(0, 6) + "…"


func _marker_hint_text(marker: Dictionary) -> String:
	var marker_mode: String = String(marker.get("marker_mode", "event"))
	var event_def: Dictionary = marker.get("event", {})
	if marker_mode == "forced":
		return "点击后在右侧打开强制事件处理"
	if marker_mode == "extraction":
		return "点击后在右侧打开撤离处理"
	var resolution_type: String = String(event_def.get("resolution_type", ""))
	if resolution_type == "battle":
		return "点击后直接进入出击战斗"
	return "点击后在右侧打开处理面板"


func _marker_color(kind: String) -> Color:
	match kind:
		"battle":
			return Color(1.0, 0.88, 0.88, 1.0)
		"narrative":
			return Color(1.0, 0.98, 0.82, 1.0)
		"random":
			return Color(0.86, 0.92, 1.0, 1.0)
		"forced":
			return Color(1.0, 0.90, 0.82, 1.0)
		"extract":
			return Color(0.84, 1.0, 0.90, 1.0)
		_:
			return Color(1, 1, 1, 1)


func _marker_icon(kind: String) -> Texture2D:
	match kind:
		"battle":
			return MAP_ICON_BATTLE
		"narrative":
			return MAP_ICON_NARRATIVE
		"random":
			return MAP_ICON_RANDOM
		"forced":
			return MAP_ICON_FORCED
		"extract":
			return MAP_ICON_EXTRACT
		_:
			return MAP_ICON_RANDOM


func _show_map_marker_hover(marker: Dictionary, button: Button) -> void:
	_hovered_event = marker.get("event", {}).duplicate(true)
	_hovered_panel_mode = String(marker.get("marker_mode", "event"))
	if map_hint_label != null:
		map_hint_label.text = "%s｜%s" % [String(marker.get("title", "")), _marker_hint_text(marker)]
	if map_hover_tooltip != null and map_hover_label != null:
		map_hover_tooltip.visible = true
		map_hover_label.text = "%s\n%s" % [String(marker.get("title", "")), _marker_hint_text(marker)]
		var tooltip_pos := button.position + Vector2(button.size.x + 12.0, -4.0)
		if tooltip_pos.x + 220.0 > marker_layer.size.x:
			tooltip_pos.x = button.position.x - 232.0
		tooltip_pos.y = clamp(tooltip_pos.y, 8.0, max(8.0, marker_layer.size.y - 96.0))
		map_hover_tooltip.position = tooltip_pos
		if map_surface != null and map_surface.has_method("set_highlight_marker"):
			map_surface.call("set_highlight_marker", marker, tooltip_pos + Vector2(14.0, 20.0))
	_render_dispatch_panel()


func _hide_map_marker_hover() -> void:
	_hovered_event = {}
	_hovered_panel_mode = "none"
	if map_hover_tooltip != null:
		map_hover_tooltip.visible = false
	if map_surface != null and map_surface.has_method("clear_highlight_marker"):
		map_surface.call("clear_highlight_marker")
	_render_dispatch_panel()


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
			["key_silent_litany_hint", "consumable_field_balm"],
			["relic_burned_prayer_wheel"]
		)
		return
	var carried_item_ids: Array = loadout.get("carried_item_ids", []).duplicate(true)
	if not carried_item_ids.has("consumable_field_balm"):
		carried_item_ids.append("consumable_field_balm")
		_progression_state().configure_home_loadout(
			String(loadout.get("hero_id", "hero_pilgrim_a01")),
			carried_item_ids,
			loadout.get("equipped_relic_ids", []).duplicate(true)
		)


func _configure_window_size() -> void:
	if OS.has_feature("web"):
		return
	var window := get_window()
	if window == null:
		return
	window.min_size = BOOTSTRAP_WINDOW_MIN_SIZE
	window.mode = Window.MODE_WINDOWED
	var screen := DisplayServer.window_get_current_screen()
	var usable_rect := DisplayServer.screen_get_usable_rect(screen)
	if usable_rect.size.x > 0 and usable_rect.size.y > 0:
		var target_size := Vector2i(
			min(BOOTSTRAP_WINDOW_SIZE.x, usable_rect.size.x),
			min(BOOTSTRAP_WINDOW_SIZE.y, usable_rect.size.y)
		)
		window.size = target_size
		window.position = usable_rect.position + (usable_rect.size - target_size) / 2
	else:
		window.size = BOOTSTRAP_WINDOW_SIZE
	window.mode = Window.MODE_MAXIMIZED


func _content_db() -> Node:
	return get_node("/root/ContentDB")


func _run_state() -> Node:
	return get_node("/root/RunState")


func _progression_state() -> Node:
	return get_node("/root/ProgressionState")
