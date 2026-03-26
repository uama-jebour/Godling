extends Control

const BATTLE_RUNNER_SCENE := preload("res://scenes/battle/battle_runner.tscn")
const MAP_ICON_BATTLE := preload("res://assets/ui/map_icons/battle.svg")
const MAP_ICON_RANDOM := preload("res://assets/ui/map_icons/random.svg")
const MAP_ICON_NARRATIVE := preload("res://assets/ui/map_icons/narrative.svg")
const MAP_ICON_FORCED := preload("res://assets/ui/map_icons/forced.svg")
const MAP_ICON_EXTRACT := preload("res://assets/ui/map_icons/extract.svg")
const BOOTSTRAP_WINDOW_SIZE := Vector2i(1820, 1120)
const BOOTSTRAP_WINDOW_MIN_SIZE := Vector2i(1560, 940)
const MAP_DESIGN_SIZE := Vector2(920.0, 560.0)
const COMPACT_LAYOUT_WIDTH := 1460.0
const COMPACT_LAYOUT_ASPECT := 1.45
const STACK_BUTTONS_WIDTH := 1320.0
const ANDROID_PREVIEW_SIZES := [
	Vector2i(1920, 1080),
	Vector2i(2160, 1080),
	Vector2i(2340, 1080),
	Vector2i(2400, 1080),
	Vector2i(2560, 1440)
]
const MAP_HINT_DEFAULT := "点击地图事件点进入处理。战斗事件会直接进入出击战斗。"
const MAP_HINT_EMPTY := "当前地图上没有可处理事件。"

@onready var summary_label: RichTextLabel = %SummaryLabel
@onready var map_surface: Control = %MapSurface
@onready var marker_layer: Control = %MarkerLayer
@onready var map_hint_label: Label = %MapHintLabel
@onready var map_hover_tooltip: PanelContainer = %MapHoverTooltip
@onready var map_hover_label: Label = %MapHoverLabel
@onready var refresh_button: Button = %RefreshButton
@onready var debug_give_item_button: Button = %DebugGiveItemButton
@onready var preview_battle_button: Button = %PreviewBattleButton
@onready var preview_android_size_button: Button = %PreviewAndroidSizeButton
@onready var title_label: Label = $Margin/MainRow/MapPanel/MapScroll/MapPadding/MapVBox/TitleLabel
@onready var event_title_label: Label = $Margin/MainRow/MapPanel/MapScroll/MapPadding/MapVBox/EventTitle

@onready var selected_event_title: Label = %SelectedEventTitle
@onready var selected_event_meta: Label = %SelectedEventMeta
@onready var selected_event_reward: RichTextLabel = %SelectedEventReward
@onready var action_button: Button = %ActionButton
@onready var extract_button: Button = %ExtractButton
@onready var resolve_forced_button: Button = %ResolveForcedButton
@onready var log_output: RichTextLabel = %LogOutput
@onready var dispatch_title_label: Label = $Margin/MainRow/DispatchPanel/DispatchScroll/DispatchPadding/DispatchVBox/DispatchTitle
@onready var root_margin: MarginContainer = $Margin
@onready var main_row: BoxContainer = $Margin/MainRow
@onready var map_panel: PanelContainer = $Margin/MainRow/MapPanel
@onready var dispatch_panel: PanelContainer = $Margin/MainRow/DispatchPanel
@onready var map_frame: PanelContainer = $Margin/MainRow/MapPanel/MapScroll/MapPadding/MapVBox/MapFrame
@onready var map_vbox: VBoxContainer = $Margin/MainRow/MapPanel/MapScroll/MapPadding/MapVBox
@onready var bottom_row: BoxContainer = $Margin/MainRow/MapPanel/MapScroll/MapPadding/MapVBox/BottomRow
@onready var dispatch_vbox: VBoxContainer = $Margin/MainRow/DispatchPanel/DispatchScroll/DispatchPadding/DispatchVBox
@onready var action_row: BoxContainer = $Margin/MainRow/DispatchPanel/DispatchScroll/DispatchPadding/DispatchVBox/ActionRow

var selected_event_id: String = ""
var panel_event: Dictionary = {}
var panel_mode: String = "none"
var log_lines: Array[String] = []
var _preview_instance: Node
var _hovered_event: Dictionary = {}
var _hovered_panel_mode: String = "none"
var _is_compact_layout := false
var _default_map_hint_text := MAP_HINT_DEFAULT
var _home_layer: Control
var _home_summary_label: RichTextLabel
var _home_title_label: Label
var _home_hero_select: OptionButton
var _home_map_select: OptionButton
var _home_item_slot_a: OptionButton
var _home_item_slot_b: OptionButton
var _home_relic_slot: OptionButton
var _home_start_button: Button
var _home_hint_label: Label
var _home_panel: PanelContainer
var _settlement_layer: Control
var _settlement_title_label: Label
var _settlement_body_label: RichTextLabel
var _settlement_return_button: Button
var _settlement_panel: PanelContainer
var _battle_result_layer: Control
var _battle_result_title_label: Label
var _battle_result_body_label: RichTextLabel
var _battle_result_continue_button: Button
var _battle_result_panel: PanelContainer
var _pending_battle_flow_result: Dictionary = {}
var _task_snapshot_label: RichTextLabel
var _delta_snapshot_label: RichTextLabel
var _forced_hint_label: Label
var _return_home_button: Button
var _narrative_option_box: VBoxContainer
var _narrative_option_select: OptionButton
var _narrative_option_preview_label: RichTextLabel
var _dispatch_task_panel: PanelContainer
var _dispatch_event_panel: PanelContainer
var _dispatch_action_panel: PanelContainer
var _dispatch_log_panel: PanelContainer
var _ui_phase := "home"
var _window_configured := false
var _android_preview_index := 0


func _enter_tree() -> void:
	_configure_window_size()


func _ready() -> void:
	InputSetup.ensure_defaults()
	_configure_window_size()
	log_output.bbcode_enabled = false
	if map_surface != null and not map_surface.resized.is_connected(_on_map_surface_resized):
		map_surface.resized.connect(_on_map_surface_resized)
	_ensure_demo_home_loadout()
	_bind_ui_actions()
	_build_runtime_ui_layers()
	_set_ui_phase("home")
	_apply_responsive_layout()
	_append_log("已进入家园准备阶段，请确认出发配置。")
	_refresh_all()
	call_deferred("_configure_window_size")
	call_deferred("_apply_responsive_layout")


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_apply_responsive_layout()


func _start_run_from_home_selection(map_id: String, hero_id: String, carried_items: Array, equipped_relics: Array) -> void:
	_progression_state().configure_home_loadout(hero_id, carried_items, equipped_relics)
	_run_state().start_new_run(map_id, hero_id, carried_items, equipped_relics)
	selected_event_id = ""
	panel_event = {}
	panel_mode = "none"
	_set_ui_phase("run")
	_append_log("已从家园出发：%s（英雄：%s）。" % [map_id, hero_id])
	_refresh_all()


func _bind_ui_actions() -> void:
	refresh_button.pressed.connect(_on_refresh_pressed)
	debug_give_item_button.pressed.connect(_on_debug_give_item_pressed)
	preview_battle_button.pressed.connect(_on_preview_battle_pressed)
	if preview_android_size_button != null:
		preview_android_size_button.pressed.connect(_on_preview_android_size_pressed)
	action_button.pressed.connect(_on_action_pressed)
	extract_button.pressed.connect(_on_extract_pressed)
	resolve_forced_button.pressed.connect(_on_resolve_forced_pressed)


func _apply_responsive_layout() -> void:
	if main_row == null:
		return
	var viewport_size: Vector2 = get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	var mobile_runtime := _is_mobile_runtime()
	var mobile_landscape := _is_mobile_landscape(viewport_size)
	var viewport_aspect: float = viewport_size.x / max(1.0, viewport_size.y)
	var compact: bool = viewport_size.x < COMPACT_LAYOUT_WIDTH or viewport_aspect < COMPACT_LAYOUT_ASPECT
	var stack_buttons: bool = compact or viewport_size.x < STACK_BUTTONS_WIDTH
	if mobile_runtime:
		compact = not mobile_landscape
		stack_buttons = not mobile_landscape
	_is_compact_layout = compact

	main_row.vertical = compact
	if root_margin != null:
		if mobile_runtime:
			var mobile_margin_h := 12 if mobile_landscape else 10
			var mobile_margin_v := 8 if mobile_landscape else 10
			root_margin.add_theme_constant_override("margin_left", mobile_margin_h)
			root_margin.add_theme_constant_override("margin_top", mobile_margin_v)
			root_margin.add_theme_constant_override("margin_right", mobile_margin_h)
			root_margin.add_theme_constant_override("margin_bottom", mobile_margin_v)
		else:
			root_margin.add_theme_constant_override("margin_left", 16 if compact else 26)
			root_margin.add_theme_constant_override("margin_top", 24 if compact else 60)
			root_margin.add_theme_constant_override("margin_right", 16 if compact else 26)
			root_margin.add_theme_constant_override("margin_bottom", 16 if compact else 26)
	if map_panel != null:
		if mobile_landscape:
			map_panel.custom_minimum_size = Vector2(920, 0)
			map_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
			map_panel.size_flags_stretch_ratio = 1.9
		else:
			map_panel.custom_minimum_size = Vector2(0, 0) if compact else Vector2(700, 0)
			map_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL if compact else Control.SIZE_FILL
			map_panel.size_flags_stretch_ratio = 1.0
	if dispatch_panel != null:
		if mobile_landscape:
			dispatch_panel.custom_minimum_size = Vector2(400, 0)
			dispatch_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
			dispatch_panel.size_flags_stretch_ratio = 0.76
		else:
			dispatch_panel.custom_minimum_size = Vector2(0, 0) if compact else Vector2(530, 0)
			dispatch_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL if compact else Control.SIZE_FILL
			dispatch_panel.size_flags_stretch_ratio = 1.0
	if map_frame != null:
		if mobile_runtime:
			map_frame.custom_minimum_size = Vector2(0, clampf(viewport_size.y * (0.68 if mobile_landscape else 0.34), 280.0, 560.0))
		else:
			map_frame.custom_minimum_size = Vector2(0, 360) if compact else Vector2(0, 460)
	if map_surface != null:
		if mobile_runtime:
			map_surface.custom_minimum_size = Vector2(0, clampf(map_frame.custom_minimum_size.y - 28.0, 248.0, 472.0))
		else:
			map_surface.custom_minimum_size = Vector2(0, 320) if compact else Vector2(0, 432)
	if title_label != null:
		title_label.add_theme_font_size_override("font_size", 20 if mobile_landscape else (24 if mobile_runtime else 26))
		title_label.custom_minimum_size = Vector2(0, 32 if mobile_runtime else 38)
	if event_title_label != null:
		event_title_label.add_theme_font_size_override("font_size", 15 if mobile_landscape else (16 if mobile_runtime else 18))
		event_title_label.custom_minimum_size = Vector2(0, 24 if mobile_runtime else 30)
	if summary_label != null:
		summary_label.add_theme_font_size_override("normal_font_size", 14 if mobile_landscape else (15 if mobile_runtime else 18))
		summary_label.custom_minimum_size = Vector2(0, 0 if mobile_landscape else (72 if mobile_runtime else 0))
	if map_hint_label != null:
		map_hint_label.add_theme_font_size_override("font_size", 12 if mobile_runtime else 15)
	if dispatch_title_label != null:
		dispatch_title_label.add_theme_font_size_override("font_size", 18 if mobile_landscape else (20 if mobile_runtime else 24))
		dispatch_title_label.custom_minimum_size = Vector2(0, 28 if mobile_runtime else 36)
	if selected_event_title != null:
		selected_event_title.add_theme_font_size_override("font_size", 16 if mobile_landscape else (18 if mobile_runtime else 20))
		selected_event_title.custom_minimum_size = Vector2(0, 26 if mobile_runtime else 30)
	if selected_event_meta != null:
		selected_event_meta.add_theme_font_size_override("font_size", 13 if mobile_landscape else (14 if mobile_runtime else 16))
	if selected_event_reward != null:
		selected_event_reward.add_theme_font_size_override("normal_font_size", 13 if mobile_landscape else (14 if mobile_runtime else 16))
		selected_event_reward.custom_minimum_size = Vector2(0, 132 if mobile_landscape else (150 if mobile_runtime else 180))
	if log_output != null:
		log_output.add_theme_font_size_override("normal_font_size", 13 if mobile_runtime else 17)
		log_output.custom_minimum_size = Vector2(0, 132 if mobile_landscape else (120 if mobile_runtime else 180))
	if _task_snapshot_label != null:
		_task_snapshot_label.custom_minimum_size = Vector2(0, 88 if mobile_landscape else 126)
	if _delta_snapshot_label != null:
		_delta_snapshot_label.custom_minimum_size = Vector2(0, 42 if mobile_landscape else 56)
	if bottom_row != null:
		bottom_row.vertical = stack_buttons
		bottom_row.add_theme_constant_override("separation", 6 if stack_buttons else 8)
	if action_row != null:
		action_row.vertical = stack_buttons
		action_row.add_theme_constant_override("separation", 6 if stack_buttons else 8)
	var action_font_size: int
	if mobile_runtime:
		action_font_size = 18 if mobile_landscape else 20
	else:
		action_font_size = 17 if compact else 19
	refresh_button.add_theme_font_size_override("font_size", action_font_size)
	debug_give_item_button.add_theme_font_size_override("font_size", action_font_size)
	preview_battle_button.add_theme_font_size_override("font_size", action_font_size)
	if preview_android_size_button != null:
		preview_android_size_button.add_theme_font_size_override("font_size", action_font_size)
	action_button.add_theme_font_size_override("font_size", action_font_size)
	extract_button.add_theme_font_size_override("font_size", action_font_size)
	resolve_forced_button.add_theme_font_size_override("font_size", action_font_size)
	if _return_home_button != null:
		_return_home_button.add_theme_font_size_override("font_size", action_font_size)
	if _home_start_button != null:
		_home_start_button.add_theme_font_size_override("font_size", action_font_size)
	if _settlement_return_button != null:
		_settlement_return_button.add_theme_font_size_override("font_size", action_font_size)
	if preview_android_size_button != null:
		preview_android_size_button.visible = _can_preview_android_sizes()
	_apply_overlay_layout(viewport_size, mobile_runtime, mobile_landscape)


func _refresh_all() -> void:
	_refresh_home_layer()
	_render_summary()
	_render_map_events()
	_render_dispatch_panel()
	_render_task_snapshot()
	_render_resolution_delta()
	_render_forced_hint()
	_render_log()


func _render_summary() -> void:
	var summary: Dictionary = _run_state().get_turn_summary()
	if summary.is_empty():
		summary_label.text = "[color=#c7d3ff]尚未出发。请先在家园页确认英雄、携带物与目标地图。[/color]"
		return

	var theme_name: String = _content_db().get_theme_name()
	var loot: Dictionary = _run_state().get_temporary_loot_snapshot()
	var progress: Dictionary = _run_state().get_progress_snapshot()
	var lines: Array[String] = []
	lines.append("[b]%s[/b]｜%s｜英雄 %s" % [
		theme_name,
		summary.get("map_name_cn", ""),
		summary.get("hero_id", "")
	])
	lines.append(
		"回合 %d 危险 %d ｜ 事件 随机 %d / 固定 %d ｜ 撤离 %s" % [
			summary.get("turn", 0),
			summary.get("danger_level", 0),
			summary.get("random_event_count", 0),
			summary.get("fixed_event_count", 0),
			_bool_text(bool(summary.get("can_extract", false)))
		]
	)
	lines.append(
		"战利品 物资 %d 货币 %d 圣遗 %d ｜ 进度 任务 %d 剧情 %d 解锁 %d" % [
			loot.get("items", []).size(),
			loot.get("currencies", []).size(),
			loot.get("relics", []).size(),
			progress.get("completed_tasks", []).size(),
			progress.get("story_flags", []).size(),
			progress.get("unlock_flags", []).size()
		]
	)
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
	var story_order_by_event: Dictionary = _story_order_by_event_id(String(_run_state().active_run.get("map_id", "")))
	var markers: Array = []
	var fixed_index := 0
	for event_def: Dictionary in board.get("random_slots", []):
		var slot_position: Array = event_def.get("slot_position", [0, 0])
		var random_marker := _build_marker_spec(event_def, Vector2(float(slot_position[0]), float(slot_position[1])), "event", false)
		random_marker["story_order"] = int(story_order_by_event.get(String(event_def.get("id", "")), 99))
		markers.append(random_marker)
	for event_def: Dictionary in board.get("fixed_events", []):
		var fixed_marker := _build_marker_spec(event_def, _fixed_event_position(fixed_index, map_def), "event", true)
		fixed_marker["story_order"] = int(story_order_by_event.get(String(event_def.get("id", "")), fixed_index))
		markers.append(fixed_marker)
		fixed_index += 1
	var forced_event: Dictionary = _run_state().get_pending_forced_event()
	if not forced_event.is_empty():
		markers.append(
			_build_marker_spec(
				forced_event,
				_map_anchor_position(map_def, "forced_anchor", Vector2(772, 112)),
				"forced",
				true
			)
		)
	var extraction_event: Dictionary = _run_state().get_extraction_event()
	var summary: Dictionary = _run_state().get_turn_summary()
	if bool(summary.get("can_extract", false)) and not extraction_event.is_empty():
		markers.append(
			_build_marker_spec(
				extraction_event,
				_map_anchor_position(map_def, "extraction_anchor", Vector2(110, 468)),
				"extraction",
				true
			)
		)
	_append_story_ghost_markers(markers, map_def, story_order_by_event)
	markers = _spread_marker_positions(markers)

	if map_surface != null and map_surface.has_method("set_event_markers"):
		map_surface.call("set_event_markers", markers)
	if map_surface != null and map_surface.has_method("set_map_context"):
		map_surface.call("set_map_context", map_def)
	for marker: Dictionary in markers:
		if bool(marker.get("is_ghost", false)):
			continue
		_add_map_marker(marker)

	if map_hint_label == null:
		return
	if markers.is_empty():
		_default_map_hint_text = MAP_HINT_EMPTY
	else:
		_default_map_hint_text = MAP_HINT_DEFAULT
	map_hint_label.text = _default_map_hint_text

func _build_marker_spec(event_def: Dictionary, raw_position: Vector2, marker_mode: String, is_fixed: bool) -> Dictionary:
	var kind: String = String(event_def.get("resolution_type", "battle"))
	if marker_mode == "forced":
		kind = "forced"
	elif marker_mode == "extraction":
		kind = "extract"
	elif marker_mode == "ghost" and kind == "random":
		kind = "narrative"
	var event_kind: String = String(event_def.get("event_kind", ""))
	return {
		"event": event_def.duplicate(true),
		"x": raw_position.x,
		"y": raw_position.y,
		"title": String(event_def.get("title", "未命名事件")),
		"kind": kind,
		"event_kind": event_kind,
		"line_id": String(event_def.get("line_id", "")),
		"marker_mode": marker_mode,
		"is_fixed": is_fixed,
		"is_mainline": event_kind == "mainline" or event_kind == "mainline_battle",
		"is_side_fixed": is_fixed and (event_kind == "side_narrative" or event_kind == "side_battle"),
		"is_ghost": marker_mode == "ghost",
		"is_selected": String(event_def.get("id", "")) == selected_event_id and panel_mode == "event"
	}


func _fixed_event_position(index: int, map_def: Dictionary) -> Vector2:
	var fixed_anchors: Array = map_def.get("fixed_slot_anchors", [])
	if index < fixed_anchors.size():
		var fixed_anchor_value: Variant = fixed_anchors[index]
		if typeof(fixed_anchor_value) == TYPE_DICTIONARY:
			var fixed_anchor: Dictionary = fixed_anchor_value
			var fixed_position: Array = fixed_anchor.get("position", [620, 94])
			return Vector2(float(fixed_position[0]), float(fixed_position[1]))
		if typeof(fixed_anchor_value) == TYPE_ARRAY:
			var fixed_array: Array = fixed_anchor_value
			if fixed_array.size() >= 2:
				return Vector2(float(fixed_array[0]), float(fixed_array[1]))
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


func _map_anchor_position(map_def: Dictionary, key: String, fallback: Vector2) -> Vector2:
	var anchor_value: Variant = map_def.get(key, [])
	if typeof(anchor_value) == TYPE_ARRAY:
		var anchor_array: Array = anchor_value
		if anchor_array.size() >= 2:
			return Vector2(float(anchor_array[0]), float(anchor_array[1]))
	if typeof(anchor_value) == TYPE_DICTIONARY:
		var anchor_dict: Dictionary = anchor_value
		var position: Array = anchor_dict.get("position", [])
		if position.size() >= 2:
			return Vector2(float(position[0]), float(position[1]))
	return fallback


func _story_order_by_event_id(map_id: String) -> Dictionary:
	var order: Dictionary = {}
	if map_id.is_empty():
		return order
	var tasks: Array = _content_db().get_tasks_for_map(map_id, {})
	var index := 0
	for task_value in tasks:
		if typeof(task_value) != TYPE_DICTIONARY:
			continue
		var task_def: Dictionary = task_value
		var pool_type: String = String(task_def.get("pool_type", ""))
		if pool_type != "fixed_line" and String(task_def.get("task_type", "")) != "extraction":
			continue
		var event_ref: String = String(task_def.get("event_ref", ""))
		if event_ref.is_empty() or order.has(event_ref):
			continue
		order[event_ref] = index
		index += 1
	return order


func _append_story_ghost_markers(markers: Array, map_def: Dictionary, story_order_by_event: Dictionary) -> void:
	var map_id: String = String(_run_state().active_run.get("map_id", ""))
	if map_id.is_empty():
		return
	var snapshot: Dictionary = _run_state().get_task_snapshot()
	if snapshot.is_empty():
		return
	var existing_event_ids: Dictionary = {}
	for marker_value in markers:
		if typeof(marker_value) != TYPE_DICTIONARY:
			continue
		var marker: Dictionary = marker_value
		var event_id: String = String(marker.get("event", {}).get("id", ""))
		if not event_id.is_empty():
			existing_event_ids[event_id] = true
	var candidate_groups: Array = [
		snapshot.get("active_tasks", []),
		snapshot.get("upcoming_tasks", [])
	]
	for group in candidate_groups:
		for task_value in group:
			if typeof(task_value) != TYPE_DICTIONARY:
				continue
			var task: Dictionary = task_value
			var event_ref: String = String(task.get("event_ref", ""))
			if event_ref.is_empty() or existing_event_ids.has(event_ref):
				continue
			var event_def: Dictionary = _content_db().get_event(event_ref)
			if event_def.is_empty():
				continue
			var position := Vector2.ZERO
			if String(task.get("task_type", "")) == "extraction":
				position = _map_anchor_position(map_def, "extraction_anchor", Vector2(110, 468))
			else:
				position = _fixed_event_position(int(story_order_by_event.get(event_ref, 0)), map_def)
			var ghost_marker := _build_marker_spec(event_def, position, "ghost", true)
			ghost_marker["story_order"] = int(story_order_by_event.get(event_ref, 99))
			ghost_marker["title"] = "%s（后续）" % String(event_def.get("title", "未命名事件"))
			markers.append(ghost_marker)
			existing_event_ids[event_ref] = true


func _spread_marker_positions(markers: Array) -> Array:
	var output: Array = []
	for marker_value in markers:
		if typeof(marker_value) != TYPE_DICTIONARY:
			continue
		var marker: Dictionary = marker_value.duplicate(true)
		var base := Vector2(float(marker.get("x", 0.0)), float(marker.get("y", 0.0)))
		var candidate := base
		var attempt := 0
		while _has_marker_overlap(output, candidate, 58.0) and attempt < 24:
			attempt += 1
			var ring := int((attempt - 1) / 6)
			var angle := deg_to_rad(float((attempt * 57) % 360))
			var radius := 18.0 + (float(ring) * 16.0)
			candidate = base + Vector2(cos(angle), sin(angle)) * radius
			candidate.x = clamp(candidate.x, 40.0, MAP_DESIGN_SIZE.x - 40.0)
			candidate.y = clamp(candidate.y, 40.0, MAP_DESIGN_SIZE.y - 40.0)
		marker["x"] = candidate.x
		marker["y"] = candidate.y
		output.append(marker)
	return output


func _has_marker_overlap(existing_markers: Array, candidate: Vector2, min_distance: float) -> bool:
	for marker_value in existing_markers:
		if typeof(marker_value) != TYPE_DICTIONARY:
			continue
		var marker: Dictionary = marker_value
		var pos := Vector2(float(marker.get("x", 0.0)), float(marker.get("y", 0.0)))
		if pos.distance_to(candidate) < min_distance:
			return true
	return false


func _add_map_marker(marker: Dictionary) -> void:
	if marker_layer == null:
		return
	var marker_metrics: Dictionary = _marker_button_metrics(marker)
	var button_size: Vector2 = Vector2(marker_metrics.get("size", Vector2(50, 50)))
	var button := Button.new()
	button.custom_minimum_size = button_size
	button.size = button_size
	button.text = ""
	button.icon = _marker_icon(String(marker.get("kind", "battle")))
	button.expand_icon = false
	button.flat = false
	button.add_theme_font_size_override("font_size", int(marker_metrics.get("font_size", 12)))
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	button.tooltip_text = String(marker.get("title", "事件"))
	_apply_marker_button_style(button, marker)
	if bool(marker.get("is_selected", false)):
		button.scale = Vector2(1.12, 1.12)
	if bool(marker.get("is_mainline", false)):
		var chip := Label.new()
		chip.text = "主线"
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chip.add_theme_font_size_override("font_size", 9 if _is_mobile_runtime() else 8)
		chip.add_theme_color_override("font_color", Color(0.19, 0.12, 0.02, 1.0))
		chip.position = Vector2(6, 3)
		var chip_bg := ColorRect.new()
		chip_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chip_bg.color = Color(0.97, 0.82, 0.36, 0.95)
		chip_bg.position = Vector2(4, 2)
		chip_bg.size = Vector2(28, 14)
		button.add_child(chip_bg)
		button.add_child(chip)
	elif bool(marker.get("is_side_fixed", false)):
		var side_chip := Label.new()
		side_chip.text = "支线"
		side_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		side_chip.add_theme_font_size_override("font_size", 9 if _is_mobile_runtime() else 8)
		side_chip.add_theme_color_override("font_color", Color(0.05, 0.14, 0.16, 1.0))
		side_chip.position = Vector2(6, 3)
		var side_chip_bg := ColorRect.new()
		side_chip_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		side_chip_bg.color = Color(0.70, 0.92, 0.94, 0.95)
		side_chip_bg.position = Vector2(4, 2)
		side_chip_bg.size = Vector2(28, 14)
		button.add_child(side_chip_bg)
		button.add_child(side_chip)
	var scaled := _map_design_to_layer_point(
		Vector2(float(marker.get("x", 0.0)), float(marker.get("y", 0.0)))
	)
	button.position = scaled - (button_size * 0.5)
	button.pressed.connect(_on_map_event_pressed.bind(marker))
	button.mouse_entered.connect(func() -> void:
		_show_map_marker_hover(marker, button)
	)
	button.mouse_exited.connect(_hide_map_marker_hover)
	marker_layer.add_child(button)


func _marker_button_metrics(marker: Dictionary = {}) -> Dictionary:
	var is_mainline := bool(marker.get("is_mainline", false))
	var is_side_fixed := bool(marker.get("is_side_fixed", false))
	if _is_mobile_runtime():
		return {
			"size": Vector2(62, 62) if is_mainline else (Vector2(58, 58) if is_side_fixed else Vector2(56, 56)),
			"font_size": 13
		}
	var compact_marker := _is_compact_layout or marker_layer.size.x < 760.0
	if compact_marker:
		return {
			"size": Vector2(46, 46) if is_mainline else (Vector2(42, 42) if is_side_fixed else Vector2(40, 40)),
			"font_size": 11
		}
	return {
		"size": Vector2(56, 56) if is_mainline else (Vector2(50, 50) if is_side_fixed else Vector2(48, 48)),
		"font_size": 12
	}


func _map_design_to_layer_point(point: Vector2) -> Vector2:
	if marker_layer == null:
		return point
	var layer_size: Vector2 = marker_layer.size
	if layer_size.x <= 0.0 or layer_size.y <= 0.0:
		return point
	var scale: float = min(layer_size.x / MAP_DESIGN_SIZE.x, layer_size.y / MAP_DESIGN_SIZE.y)
	if scale <= 0.0:
		scale = 1.0
	var content_size: Vector2 = MAP_DESIGN_SIZE * scale
	var offset: Vector2 = (layer_size - content_size) * 0.5
	return offset + (point * scale)


func _render_dispatch_panel() -> void:
	var display_event: Dictionary = panel_event
	var display_mode: String = panel_mode
	var is_hover_preview := false
	if _narrative_option_box != null:
		_narrative_option_box.visible = false
	if not _hovered_event.is_empty():
		display_event = _hovered_event
		display_mode = _hovered_panel_mode
		is_hover_preview = true

	if _run_state().get_turn_summary().is_empty():
		selected_event_title.text = "尚未出发"
		selected_event_meta.text = "请先完成家园出发配置。"
		selected_event_reward.text = ""
		action_button.disabled = true
		action_button.text = "处理当前事件"
		return

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
	_render_narrative_option_box(display_event, is_hover_preview)

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
	lines.append("剧情标记：%s" % _format_story_flag_list(story_flags))
	lines.append("系统解锁：%s" % _format_unlock_flag_list(unlock_flags))
	lines.append("掉落表：%s" % _format_loot_table_lines(loot_tables))
	var option_list: Array = event_def.get("option_list", [])
	if not option_list.is_empty():
		var option_parts: Array[String] = []
		for option_value in option_list:
			if typeof(option_value) != TYPE_DICTIONARY:
				continue
			var option_def: Dictionary = option_value
			var option_text: String = String(option_def.get("text", "未命名选项"))
			var impact: String = String(option_def.get("preview_impact", ""))
			if impact.is_empty():
				option_parts.append(option_text)
			else:
				option_parts.append("%s（%s）" % [option_text, impact])
		lines.append("叙事选项：%s" % (", ".join(option_parts) if not option_parts.is_empty() else "无"))

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
			lines.append("提交后标记：%s" % _story_flag_name(grant_flag))

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
	if _ui_phase != "run":
		return
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
	if _ui_phase != "run":
		return
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

	var result: Dictionary = {}
	if String(panel_event.get("resolution_type", "")) == "narrative":
		result = _run_state().complete_selected_event_with_option(_selected_narrative_option_id())
	else:
		result = _run_state().complete_selected_event(true)
	_finalize_selected_event_result(result)


func _finalize_selected_event_result(result: Dictionary) -> void:
	if result.is_empty():
		_append_log("事件处理失败：未获取结果。")
		_refresh_all()
		return

	var resolved_event: Dictionary = result.get("selected_event", {})
	var dispatch_result: Dictionary = result.get("dispatch_result", {})
	var battle_result: Dictionary = dispatch_result.get("battle_result", {})
	var narrative_result: Dictionary = dispatch_result.get("narrative_result", {})
	if not battle_result.is_empty():
		_append_log(
			"事件完成：%s。战斗结果：%s。" % [
				resolved_event.get("title", "未命名事件"),
				"胜利" if bool(battle_result.get("victory", false)) else "失败"
			]
		)
	elif not narrative_result.is_empty():
		var selected_option_text: String = String(narrative_result.get("selected_option_text", ""))
		var preview_impact: String = String(narrative_result.get("selected_option_preview_impact", ""))
		if selected_option_text.is_empty():
			_append_log("叙事处理完成：%s。" % resolved_event.get("title", "未命名事件"))
		elif preview_impact.is_empty():
			_append_log("叙事处理完成：%s（选项：%s）。" % [resolved_event.get("title", "未命名事件"), selected_option_text])
		else:
			_append_log("叙事处理完成：%s（选项：%s，结果：%s）。" % [resolved_event.get("title", "未命名事件"), selected_option_text, preview_impact])
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
		_open_settlement_from_death()
		return

	_refresh_all()


func _on_extract_pressed() -> void:
	if _ui_phase != "run":
		return
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
		var settlement_snapshot: Dictionary = _progression_state().build_run_settlement_snapshot(extraction_result, {})
		_progression_state().add_loot_from_run(extraction_result)
		_append_log("成功：已撤离并写入本地存档。")
		_open_settlement(settlement_snapshot)
	else:
		_append_log("失败：撤离失败，角色阵亡。")
		_open_settlement_from_death()

	panel_event = {}
	panel_mode = "none"
	selected_event_id = ""
	if _ui_phase == "run":
		_refresh_all()


func _on_resolve_forced_pressed() -> void:
	if _ui_phase != "run":
		return
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
	var summary: Dictionary = _run_state().get_turn_summary()
	if bool(summary.get("is_dead", false)):
		_append_log("强制袭击中角色阵亡，进入回归结算。")
		_open_settlement_from_death()
		return
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


func _build_runtime_ui_layers() -> void:
	_inject_map_runtime_widgets()
	_inject_dispatch_runtime_widgets()
	_build_home_layer()
	_build_battle_result_layer()
	_build_settlement_layer()


func _inject_map_runtime_widgets() -> void:
	if map_vbox == null:
		return
	if _return_home_button == null and bottom_row != null:
		_return_home_button = Button.new()
		_return_home_button.custom_minimum_size = Vector2(0, 50)
		_return_home_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_return_home_button.text = "返回家园整备"
		_return_home_button.pressed.connect(_on_return_home_pressed)
		bottom_row.add_child(_return_home_button)
	if _forced_hint_label == null:
		_forced_hint_label = Label.new()
		_forced_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_forced_hint_label.text = ""
		_forced_hint_label.theme_type_variation = "HeaderSmall"
		map_vbox.add_child(_forced_hint_label)
		if map_hint_label != null:
			map_vbox.move_child(_forced_hint_label, map_hint_label.get_index() + 1)
	if _delta_snapshot_label == null:
		_delta_snapshot_label = RichTextLabel.new()
		_delta_snapshot_label.bbcode_enabled = true
		_delta_snapshot_label.fit_content = true
		_delta_snapshot_label.scroll_active = false
		_delta_snapshot_label.custom_minimum_size = Vector2(0, 56)
		map_vbox.add_child(_delta_snapshot_label)
		if _forced_hint_label != null:
			map_vbox.move_child(_delta_snapshot_label, _forced_hint_label.get_index() + 1)


func _inject_dispatch_runtime_widgets() -> void:
	if dispatch_vbox == null:
		return
	if _task_snapshot_label == null:
		_task_snapshot_label = RichTextLabel.new()
		_task_snapshot_label.bbcode_enabled = true
		_task_snapshot_label.fit_content = true
		_task_snapshot_label.scroll_active = false
		_task_snapshot_label.custom_minimum_size = Vector2(0, 126)
		dispatch_vbox.add_child(_task_snapshot_label)
		if selected_event_title != null:
			dispatch_vbox.move_child(_task_snapshot_label, selected_event_title.get_index())
	if _narrative_option_box == null:
		_narrative_option_box = VBoxContainer.new()
		_narrative_option_box.add_theme_constant_override("separation", 4)
		var option_label := Label.new()
		option_label.text = "叙事选项（1-3）"
		option_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_narrative_option_box.add_child(option_label)
		_narrative_option_select = OptionButton.new()
		_narrative_option_select.custom_minimum_size = Vector2(0, 44)
		_narrative_option_select.item_selected.connect(_on_narrative_option_selected)
		_narrative_option_box.add_child(_narrative_option_select)
		_narrative_option_preview_label = RichTextLabel.new()
		_narrative_option_preview_label.bbcode_enabled = true
		_narrative_option_preview_label.fit_content = true
		_narrative_option_preview_label.scroll_active = false
		_narrative_option_preview_label.custom_minimum_size = Vector2(0, 104)
		_narrative_option_box.add_child(_narrative_option_preview_label)
		_narrative_option_box.visible = false
		dispatch_vbox.add_child(_narrative_option_box)
		if action_row != null:
			dispatch_vbox.move_child(_narrative_option_box, action_row.get_index())
	_ensure_dispatch_cards()


func _build_home_layer() -> void:
	if _home_layer != null:
		return
	_home_layer = Control.new()
	_home_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_home_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_home_layer)

	var shade := ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.02, 0.02, 0.05, 0.78)
	_home_layer.add_child(shade)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_home_layer.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(760, 560)
	center.add_child(panel)
	_home_panel = panel

	var padding := MarginContainer.new()
	padding.add_theme_constant_override("margin_left", 20)
	padding.add_theme_constant_override("margin_top", 18)
	padding.add_theme_constant_override("margin_right", 20)
	padding.add_theme_constant_override("margin_bottom", 18)
	panel.add_child(padding)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 14)
	padding.add_child(vbox)

	var title := Label.new()
	title.text = "家园整备与出发"
	title.add_theme_font_size_override("font_size", 28)
	title.custom_minimum_size = Vector2(0, 44)
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	_home_title_label = title

	var body_row := HBoxContainer.new()
	body_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_row.add_theme_constant_override("separation", 16)
	vbox.add_child(body_row)

	var summary_panel := _build_overlay_card()
	summary_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	summary_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	summary_panel.size_flags_stretch_ratio = 0.95
	body_row.add_child(summary_panel)

	var summary_margin := MarginContainer.new()
	summary_margin.add_theme_constant_override("margin_left", 18)
	summary_margin.add_theme_constant_override("margin_top", 16)
	summary_margin.add_theme_constant_override("margin_right", 18)
	summary_margin.add_theme_constant_override("margin_bottom", 16)
	summary_panel.add_child(summary_margin)

	var summary_vbox := VBoxContainer.new()
	summary_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	summary_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	summary_vbox.add_theme_constant_override("separation", 10)
	summary_margin.add_child(summary_vbox)

	var summary_header := Label.new()
	summary_header.text = "出发概览"
	summary_header.add_theme_font_size_override("font_size", 20)
	summary_vbox.add_child(summary_header)

	_home_summary_label = RichTextLabel.new()
	_home_summary_label.bbcode_enabled = true
	_home_summary_label.fit_content = true
	_home_summary_label.scroll_active = false
	_home_summary_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_home_summary_label.custom_minimum_size = Vector2(0, 170)
	summary_vbox.add_child(_home_summary_label)

	var loadout_panel := _build_overlay_card()
	loadout_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	loadout_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	loadout_panel.size_flags_stretch_ratio = 1.25
	body_row.add_child(loadout_panel)

	var loadout_margin := MarginContainer.new()
	loadout_margin.add_theme_constant_override("margin_left", 18)
	loadout_margin.add_theme_constant_override("margin_top", 16)
	loadout_margin.add_theme_constant_override("margin_right", 18)
	loadout_margin.add_theme_constant_override("margin_bottom", 16)
	loadout_panel.add_child(loadout_margin)

	var loadout_vbox := VBoxContainer.new()
	loadout_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	loadout_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	loadout_vbox.add_theme_constant_override("separation", 10)
	loadout_margin.add_child(loadout_vbox)

	var loadout_header := Label.new()
	loadout_header.text = "整备配置"
	loadout_header.add_theme_font_size_override("font_size", 20)
	loadout_vbox.add_child(loadout_header)

	_home_hero_select = _build_home_option_row(loadout_vbox, "英雄")
	_home_map_select = _build_home_option_row(loadout_vbox, "目标地图")
	_home_item_slot_a = _build_home_option_row(loadout_vbox, "携带物 A")
	_home_item_slot_b = _build_home_option_row(loadout_vbox, "携带物 B")
	_home_relic_slot = _build_home_option_row(loadout_vbox, "装备圣遗")

	for option_btn: OptionButton in [_home_hero_select, _home_map_select, _home_item_slot_a, _home_item_slot_b, _home_relic_slot]:
		option_btn.item_selected.connect(_on_home_selection_changed)

	_home_hint_label = Label.new()
	_home_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_home_hint_label.text = "先整备再出发：进入地图后每回合只处理一个事件，危险度会上升，主线完成后可触发撤离。"
	loadout_vbox.add_child(_home_hint_label)

	_home_start_button = Button.new()
	_home_start_button.custom_minimum_size = Vector2(0, 56)
	_home_start_button.text = "确认配置并出发"
	_home_start_button.pressed.connect(_on_home_start_pressed)
	vbox.add_child(_home_start_button)


func _build_battle_result_layer() -> void:
	if _battle_result_layer != null:
		return
	_battle_result_layer = Control.new()
	_battle_result_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_battle_result_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	_battle_result_layer.visible = false
	add_child(_battle_result_layer)

	var shade := ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.02, 0.02, 0.06, 0.84)
	_battle_result_layer.add_child(shade)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_battle_result_layer.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(760, 500)
	center.add_child(panel)
	_battle_result_panel = panel

	var padding := MarginContainer.new()
	padding.add_theme_constant_override("margin_left", 22)
	padding.add_theme_constant_override("margin_top", 18)
	padding.add_theme_constant_override("margin_right", 22)
	padding.add_theme_constant_override("margin_bottom", 18)
	panel.add_child(padding)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 12)
	padding.add_child(vbox)

	_battle_result_title_label = Label.new()
	_battle_result_title_label.add_theme_font_size_override("font_size", 28)
	_battle_result_title_label.custom_minimum_size = Vector2(0, 42)
	_battle_result_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	vbox.add_child(_battle_result_title_label)

	_battle_result_body_label = RichTextLabel.new()
	_battle_result_body_label.bbcode_enabled = true
	_battle_result_body_label.fit_content = true
	_battle_result_body_label.scroll_active = true
	_battle_result_body_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_battle_result_body_label.custom_minimum_size = Vector2(0, 280)
	vbox.add_child(_battle_result_body_label)

	_battle_result_continue_button = Button.new()
	_battle_result_continue_button.custom_minimum_size = Vector2(0, 54)
	_battle_result_continue_button.text = "确认并返回作战地图"
	_battle_result_continue_button.pressed.connect(_on_battle_result_continue_pressed)
	vbox.add_child(_battle_result_continue_button)


func _build_settlement_layer() -> void:
	if _settlement_layer != null:
		return
	_settlement_layer = Control.new()
	_settlement_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_settlement_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_settlement_layer)

	var shade := ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.02, 0.02, 0.06, 0.82)
	_settlement_layer.add_child(shade)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_settlement_layer.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(760, 560)
	center.add_child(panel)
	_settlement_panel = panel

	var padding := MarginContainer.new()
	padding.add_theme_constant_override("margin_left", 22)
	padding.add_theme_constant_override("margin_top", 18)
	padding.add_theme_constant_override("margin_right", 22)
	padding.add_theme_constant_override("margin_bottom", 18)
	panel.add_child(padding)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 10)
	padding.add_child(vbox)

	_settlement_title_label = Label.new()
	_settlement_title_label.add_theme_font_size_override("font_size", 28)
	_settlement_title_label.custom_minimum_size = Vector2(0, 42)
	_settlement_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	vbox.add_child(_settlement_title_label)

	_settlement_body_label = RichTextLabel.new()
	_settlement_body_label.bbcode_enabled = true
	_settlement_body_label.custom_minimum_size = Vector2(0, 380)
	_settlement_body_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_settlement_body_label.scroll_active = true
	vbox.add_child(_settlement_body_label)

	_settlement_return_button = Button.new()
	_settlement_return_button.custom_minimum_size = Vector2(0, 56)
	_settlement_return_button.text = "返回家园继续整备"
	_settlement_return_button.pressed.connect(_on_settlement_return_home_pressed)
	vbox.add_child(_settlement_return_button)


func _build_home_option_row(parent: VBoxContainer, label_text: String) -> OptionButton:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.custom_minimum_size = Vector2(0, 48)
	parent.add_child(row)

	var label := Label.new()
	label.custom_minimum_size = Vector2(140, 0)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 18)
	label.text = label_text
	row.add_child(label)

	var selector := OptionButton.new()
	selector.custom_minimum_size = Vector2(0, 46)
	selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	selector.add_theme_font_size_override("font_size", 18)
	row.add_child(selector)
	return selector


func _build_overlay_card(bg: Color = Color(0.10, 0.10, 0.14, 0.96), border: Color = Color(0.24, 0.23, 0.34, 1.0)) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(1)
	style.corner_radius_top_left = 14
	style.corner_radius_top_right = 14
	style.corner_radius_bottom_right = 14
	style.corner_radius_bottom_left = 14
	panel.add_theme_stylebox_override("panel", style)
	return panel


func _ensure_dispatch_cards() -> void:
	if dispatch_vbox == null or _dispatch_task_panel != null:
		return
	_dispatch_task_panel = _build_overlay_card(Color(0.09, 0.10, 0.15, 0.98), Color(0.22, 0.24, 0.36, 1.0))
	_dispatch_task_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var task_margin := MarginContainer.new()
	task_margin.add_theme_constant_override("margin_left", 14)
	task_margin.add_theme_constant_override("margin_top", 12)
	task_margin.add_theme_constant_override("margin_right", 14)
	task_margin.add_theme_constant_override("margin_bottom", 12)
	_dispatch_task_panel.add_child(task_margin)
	var task_vbox := VBoxContainer.new()
	task_vbox.add_theme_constant_override("separation", 6)
	task_margin.add_child(task_vbox)
	var task_header := Label.new()
	task_header.text = "任务与主线"
	task_header.add_theme_font_size_override("font_size", 17)
	task_vbox.add_child(task_header)
	dispatch_vbox.add_child(_dispatch_task_panel)
	if _task_snapshot_label != null:
		_task_snapshot_label.reparent(task_vbox)
	dispatch_vbox.move_child(_dispatch_task_panel, 1)

	_dispatch_event_panel = _build_overlay_card(Color(0.11, 0.10, 0.14, 0.98), Color(0.28, 0.23, 0.30, 1.0))
	_dispatch_event_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var event_margin := MarginContainer.new()
	event_margin.add_theme_constant_override("margin_left", 14)
	event_margin.add_theme_constant_override("margin_top", 12)
	event_margin.add_theme_constant_override("margin_right", 14)
	event_margin.add_theme_constant_override("margin_bottom", 12)
	_dispatch_event_panel.add_child(event_margin)
	var event_vbox := VBoxContainer.new()
	event_vbox.add_theme_constant_override("separation", 6)
	event_margin.add_child(event_vbox)
	dispatch_vbox.add_child(_dispatch_event_panel)
	selected_event_title.reparent(event_vbox)
	selected_event_meta.reparent(event_vbox)
	selected_event_reward.reparent(event_vbox)
	if _narrative_option_box != null:
		_narrative_option_box.reparent(event_vbox)
	dispatch_vbox.move_child(_dispatch_event_panel, 3)

	_dispatch_action_panel = _build_overlay_card(Color(0.12, 0.11, 0.09, 0.98), Color(0.34, 0.28, 0.18, 1.0))
	_dispatch_action_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var action_margin := MarginContainer.new()
	action_margin.add_theme_constant_override("margin_left", 14)
	action_margin.add_theme_constant_override("margin_top", 12)
	action_margin.add_theme_constant_override("margin_right", 14)
	action_margin.add_theme_constant_override("margin_bottom", 12)
	_dispatch_action_panel.add_child(action_margin)
	var action_vbox := VBoxContainer.new()
	action_vbox.add_theme_constant_override("separation", 8)
	action_margin.add_child(action_vbox)
	var action_header := Label.new()
	action_header.text = "出击与撤离"
	action_header.add_theme_font_size_override("font_size", 17)
	action_vbox.add_child(action_header)
	dispatch_vbox.add_child(_dispatch_action_panel)
	action_row.reparent(action_vbox)
	resolve_forced_button.reparent(action_vbox)
	dispatch_vbox.move_child(_dispatch_action_panel, 4)

	_dispatch_log_panel = _build_overlay_card(Color(0.08, 0.09, 0.12, 0.98), Color(0.20, 0.24, 0.32, 1.0))
	_dispatch_log_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_dispatch_log_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var log_margin := MarginContainer.new()
	log_margin.add_theme_constant_override("margin_left", 14)
	log_margin.add_theme_constant_override("margin_top", 12)
	log_margin.add_theme_constant_override("margin_right", 14)
	log_margin.add_theme_constant_override("margin_bottom", 12)
	_dispatch_log_panel.add_child(log_margin)
	var log_vbox := VBoxContainer.new()
	log_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_vbox.add_theme_constant_override("separation", 6)
	log_margin.add_child(log_vbox)
	var log_header := Label.new()
	log_header.text = "作战记录"
	log_header.add_theme_font_size_override("font_size", 17)
	log_vbox.add_child(log_header)
	dispatch_vbox.add_child(_dispatch_log_panel)
	log_output.reparent(log_vbox)
	dispatch_vbox.move_child(_dispatch_log_panel, dispatch_vbox.get_child_count() - 1)


func _apply_overlay_layout(viewport_size: Vector2, mobile_runtime: bool, mobile_landscape: bool) -> void:
	if _home_panel != null:
		if mobile_runtime:
			_home_panel.custom_minimum_size = Vector2(
				clampf(viewport_size.x * (0.92 if mobile_landscape else 0.9), 940.0, 1520.0),
				clampf(viewport_size.y * (0.92 if mobile_landscape else 0.78), 520.0, 860.0)
			)
		else:
			_home_panel.custom_minimum_size = Vector2(760, 560)
	if _home_title_label != null:
		_home_title_label.add_theme_font_size_override("font_size", 34 if mobile_landscape else (30 if mobile_runtime else 28))
		_home_title_label.custom_minimum_size = Vector2(0, 52 if mobile_runtime else 44)
	if _home_summary_label != null:
		_home_summary_label.add_theme_font_size_override("normal_font_size", 20 if mobile_landscape else (15 if mobile_runtime else 16))
		_home_summary_label.custom_minimum_size = Vector2(0, 220 if mobile_landscape else (140 if mobile_runtime else 170))
	if _home_hint_label != null:
		_home_hint_label.add_theme_font_size_override("font_size", 17 if mobile_landscape else (13 if mobile_runtime else 15))
	if _home_start_button != null:
		_home_start_button.custom_minimum_size = Vector2(0, 64 if mobile_landscape else (48 if mobile_runtime else 56))
	if _settlement_panel != null:
		if mobile_runtime:
			_settlement_panel.custom_minimum_size = Vector2(
				clampf(viewport_size.x * (0.74 if mobile_landscape else 0.9), 720.0, 1160.0),
				clampf(viewport_size.y * (0.84 if mobile_landscape else 0.8), 430.0, 720.0)
			)
		else:
			_settlement_panel.custom_minimum_size = Vector2(760, 560)
	if _settlement_title_label != null:
		_settlement_title_label.add_theme_font_size_override("font_size", 22 if mobile_runtime else 28)
	if _settlement_body_label != null:
		_settlement_body_label.add_theme_font_size_override("normal_font_size", 14 if mobile_runtime else 16)
		_settlement_body_label.custom_minimum_size = Vector2(0, 250 if mobile_landscape else (320 if mobile_runtime else 380))
	if _settlement_return_button != null:
		_settlement_return_button.custom_minimum_size = Vector2(0, 48 if mobile_runtime else 56)


func _set_ui_phase(phase: String) -> void:
	_ui_phase = phase
	if main_row != null:
		main_row.visible = phase == "run"
	if _home_layer != null:
		_home_layer.visible = phase == "home"
	if _settlement_layer != null:
		_settlement_layer.visible = phase == "settlement"
	if phase == "home":
		_prepare_home_selectors_from_loadout()
	_apply_responsive_layout()


func _prepare_home_selectors_from_loadout() -> void:
	if _home_layer == null:
		return
	var progression: Node = _progression_state()
	var loadout: Dictionary = progression.get_home_loadout()
	var state: Dictionary = progression.state

	var hero_ids: Array = state.get("hero_roster", []).duplicate(true)
	if hero_ids.is_empty():
		hero_ids.append(String(loadout.get("hero_id", "hero_pilgrim_a01")))
	var hero_entries: Array = []
	for hero_value in hero_ids:
		var hero_id: String = String(hero_value)
		if hero_id.is_empty():
			continue
		hero_entries.append({"id": hero_id, "label": "%s (%s)" % [_unit_name(hero_id), hero_id]})
	_populate_selector(
		_home_hero_select,
		hero_entries,
		String(loadout.get("hero_id", "hero_pilgrim_a01")),
		false,
		""
	)

	var map_entries: Array = []
	var startable_maps: Array = _content_db().list_startable_maps(_build_home_start_context())
	var has_startable_map := not startable_maps.is_empty()
	var map_source: Array = startable_maps if has_startable_map else _content_db().list_maps()
	for map_value in map_source:
		if typeof(map_value) != TYPE_DICTIONARY:
			continue
		var map_def: Dictionary = map_value
		var map_id: String = String(map_def.get("id", ""))
		if map_id.is_empty():
			continue
		var suffix := "" if has_startable_map else " [暂无可处理事件]"
		map_entries.append({"id": map_id, "label": "%s (%s)%s" % [String(map_def.get("name_cn", map_id)), map_id, suffix]})
	var saved_map_id: String = "map_world_a_02_ashen_sanctum"
	if not map_entries.is_empty():
		saved_map_id = String(map_entries[0].get("id", saved_map_id))
	_populate_selector(_home_map_select, map_entries, saved_map_id, false, "")
	if _home_start_button != null:
		_home_start_button.disabled = not has_startable_map
	if _home_hint_label != null:
		_home_hint_label.text = (
			"先整备再出发：进入地图后每回合只处理一个事件，危险度会上升，主线完成后可触发撤离。"
			if has_startable_map
			else "当前没有可开局地图：请先补充该地图的 board 事件内容。"
		)

	var carried_item_ids: Array = loadout.get("carried_item_ids", []).duplicate(true)
	var item_ids: Array = _collect_stack_ids(state.get("inventory_items", []))
	for carried_id in carried_item_ids:
		var carried: String = String(carried_id)
		if carried.is_empty():
			continue
		if not item_ids.has(carried):
			item_ids.append(carried)
	var item_entries: Array = []
	for item_value in item_ids:
		var item_id: String = String(item_value)
		if item_id.is_empty():
			continue
		item_entries.append({"id": item_id, "label": "%s (%s)" % [_item_name(item_id), item_id]})
	_populate_selector(
		_home_item_slot_a,
		item_entries,
		String(carried_item_ids[0]) if carried_item_ids.size() > 0 else "",
		true,
		"不携带"
	)
	_populate_selector(
		_home_item_slot_b,
		item_entries,
		String(carried_item_ids[1]) if carried_item_ids.size() > 1 else "",
		true,
		"不携带"
	)

	var relic_ids: Array = _collect_stack_ids(state.get("relics", []))
	var equipped_relic_ids: Array = loadout.get("equipped_relic_ids", []).duplicate(true)
	for relic_id in equipped_relic_ids:
		var relic: String = String(relic_id)
		if relic.is_empty():
			continue
		if not relic_ids.has(relic):
			relic_ids.append(relic)
	var relic_entries: Array = []
	for relic_value in relic_ids:
		var relic_id: String = String(relic_value)
		if relic_id.is_empty():
			continue
		relic_entries.append({"id": relic_id, "label": "%s (%s)" % [_item_name(relic_id), relic_id]})
	_populate_selector(
		_home_relic_slot,
		relic_entries,
		String(equipped_relic_ids[0]) if equipped_relic_ids.size() > 0 else "",
		true,
		"不装备"
	)
	_render_home_summary()


func _populate_selector(selector: OptionButton, entries: Array, selected_id: String, allow_empty: bool, empty_text: String) -> void:
	if selector == null:
		return
	selector.clear()
	if allow_empty:
		selector.add_item(empty_text)
		selector.set_item_metadata(0, "")
	for entry_value in entries:
		if typeof(entry_value) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_value
		var entry_id: String = String(entry.get("id", ""))
		if entry_id.is_empty():
			continue
		selector.add_item(String(entry.get("label", entry_id)))
		selector.set_item_metadata(selector.get_item_count() - 1, entry_id)
	var target_index := 0
	for i: int in range(selector.get_item_count()):
		if String(selector.get_item_metadata(i)) == selected_id:
			target_index = i
			break
	if selector.get_item_count() > 0:
		selector.select(target_index)


func _collect_stack_ids(stacks: Array) -> Array:
	var ids: Array = []
	for stack_value in stacks:
		if typeof(stack_value) != TYPE_DICTIONARY:
			continue
		var stack: Dictionary = stack_value
		var item_id: String = String(stack.get("id", ""))
		if item_id.is_empty():
			continue
		if ids.has(item_id):
			continue
		ids.append(item_id)
	return ids


func _render_home_summary() -> void:
	if _home_summary_label == null:
		return
	var state: Dictionary = _progression_state().state
	var hero_id: String = _selector_metadata(_home_hero_select)
	var map_id: String = _selector_metadata(_home_map_select)
	var carried: Array = _selected_home_items()
	var relics: Array = _selected_home_relics()
	var lines: Array[String] = []
	lines.append("[b]目标地图[/b] %s" % _map_name(map_id))
	lines.append("[b]开局可用事件[/b] %s" % _bool_text(_is_map_startable(map_id)))
	lines.append("[b]英雄[/b] %s" % _unit_name(hero_id))
	lines.append("[b]携带物[/b] %s" % (", ".join(_names_from_item_ids(carried)) if not carried.is_empty() else "无"))
	lines.append("[b]装备圣遗[/b] %s" % (", ".join(_names_from_item_ids(relics)) if not relics.is_empty() else "无"))
	if not _is_map_startable(map_id):
		lines.append("[color=#ffb089]提示：该地图当前未接入可处理事件，无法出发。[/color]")
	lines.append("")
	lines.append("[b]永久仓库[/b] 物资 %d / 货币 %d / 圣遗 %d" % [
		state.get("inventory_items", []).size(),
		state.get("currencies", []).size(),
		state.get("relics", []).size()
	])
	lines.append("[b]全局进度[/b] 任务 %d / 剧情标记 %d / 解锁 %d" % [
		state.get("completed_tasks", []).size(),
		state.get("story_flags", []).size(),
		state.get("unlock_flags", []).size()
	])
	_home_summary_label.text = "\n".join(lines)


func _refresh_home_layer() -> void:
	if _ui_phase != "home":
		return
	_render_home_summary()


func _render_task_snapshot() -> void:
	if _task_snapshot_label == null:
		return
	var snapshot: Dictionary = _run_state().get_task_snapshot()
	if snapshot.is_empty():
		_task_snapshot_label.text = "[b]任务线[/b]\n尚未进入地图。"
		return
	var lines: Array[String] = []
	lines.append("[b]当前任务 / 主线节点[/b]")
	lines.append("[color=#b6bdd9]回合 %d / 危险度 %d[/color]" % [int(snapshot.get("turn", 1)), int(snapshot.get("danger_level", 0))])
	var active_tasks: Array = snapshot.get("active_tasks", [])
	var current_task: Dictionary = _pick_featured_task(active_tasks)
	lines.append("")
	lines.append("[b]当前节点[/b]")
	if current_task.is_empty():
		lines.append("尚无已解锁任务节点。")
	else:
		lines.append("%s" % String(current_task.get("name_cn", "")))
		lines.append("类型：%s / 状态：%s" % [_task_type_name(String(current_task.get("task_type", ""))), _task_progress_text(current_task)])
		var objective_text: String = String(current_task.get("objective_text", ""))
		if not objective_text.is_empty():
			lines.append("目标：%s" % objective_text)
		lines.append("条件：%s" % _format_task_conditions(current_task.get("entry_conditions", [])))
		var impact: String = String(current_task.get("preview_impact", ""))
		if not impact.is_empty():
			lines.append("推进状态：%s" % impact)
		var next_hint: String = _format_next_unlocks(current_task.get("next_unlocks", []))
		if not next_hint.is_empty():
			lines.append("下一节点提示：%s" % next_hint)
		var event_title: String = String(current_task.get("event_title", ""))
		if not event_title.is_empty():
			lines.append("对应地图事件：%s" % event_title)

	var side_tasks: Array[String] = []
	for task_value in active_tasks:
		if typeof(task_value) != TYPE_DICTIONARY:
			continue
		var task: Dictionary = task_value
		if not current_task.is_empty() and String(task.get("id", "")) == String(current_task.get("id", "")):
			continue
		side_tasks.append("%s（%s）" % [String(task.get("name_cn", "")), _task_progress_text(task)])
	if not side_tasks.is_empty():
		lines.append("")
		lines.append("[b]并行节点[/b]")
		for side_line in side_tasks:
			lines.append("- %s" % side_line)
	var upcoming: Array = snapshot.get("upcoming_tasks", [])
	if not upcoming.is_empty():
		lines.append("")
		lines.append("[b]后续节点[/b]")
		var shown: int = 0
		for task_value in upcoming:
			if typeof(task_value) != TYPE_DICTIONARY:
				continue
			var upcoming_task: Dictionary = task_value
			lines.append("- %s：%s" % [
				String(upcoming_task.get("name_cn", "")),
				_format_task_conditions(upcoming_task.get("entry_conditions", []))
			])
			shown += 1
			if shown >= 3:
				break
	var completed: Array = snapshot.get("completed_tasks", [])
	if not completed.is_empty():
		var completed_names: Array[String] = []
		for task_value in completed:
			if typeof(task_value) != TYPE_DICTIONARY:
				continue
			completed_names.append(String(task_value.get("name_cn", "")))
		if not completed_names.is_empty():
			lines.append("")
			lines.append("[b]已完成推进[/b]")
			lines.append("已完成：%s" % ", ".join(completed_names))
	_task_snapshot_label.text = "\n".join(lines)


func _render_resolution_delta() -> void:
	if _delta_snapshot_label == null:
		return
	var delta: Dictionary = _run_state().get_last_resolution_delta()
	if delta.is_empty():
		_delta_snapshot_label.text = "[b]本次变化摘要[/b]\n暂无。"
		return
	var lines: Array[String] = []
	lines.append("[b]本次变化摘要[/b] %s" % String(delta.get("headline", "")))
	var event_title: String = String(delta.get("event_title", ""))
	if not event_title.is_empty():
		lines.append("事件：%s" % event_title)
	var compact_parts: Array[String] = []
	compact_parts.append("回合 %+d" % int(delta.get("turn_delta", 0)))
	compact_parts.append("危险 %+d" % int(delta.get("danger_delta", 0)))
	var items_text: String = _format_delta_stacks(delta.get("items_delta", []))
	if items_text != "无":
		compact_parts.append("物资 %s" % items_text)
	var currencies_text: String = _format_delta_stacks(delta.get("currencies_delta", []))
	if currencies_text != "无":
		compact_parts.append("货币 %s" % currencies_text)
	var relics_text: String = _format_delta_stacks(delta.get("relics_delta", []))
	if relics_text != "无":
		compact_parts.append("圣遗 %s" % relics_text)
	var task_delta: Array = delta.get("task_delta", [])
	if not task_delta.is_empty():
		compact_parts.append("任务 %s" % _format_task_name_list(task_delta))
	var story_delta: Array = delta.get("story_flags_delta", [])
	if not story_delta.is_empty():
		compact_parts.append("剧情 %s" % _format_story_flag_list(story_delta))
	var unlock_delta: Array = delta.get("unlock_flags_delta", [])
	if not unlock_delta.is_empty():
		compact_parts.append("解锁 %s" % _format_unlock_flag_list(unlock_delta))
	if compact_parts.is_empty():
		compact_parts.append("局内状态无新增变化")
	lines.append(" / ".join(compact_parts))
	var narrative_card: Dictionary = delta.get("narrative_card", {})
	if not narrative_card.is_empty():
		var selected_option_text: String = String(narrative_card.get("selected_option_text", ""))
		var narrative_parts: Array[String] = []
		if not selected_option_text.is_empty():
			narrative_parts.append("叙事选择 %s" % selected_option_text)
		var selected_impact: String = String(narrative_card.get("selected_option_preview_impact", ""))
		if not selected_impact.is_empty():
			narrative_parts.append("结果 %s" % selected_impact)
		var requirement: Dictionary = narrative_card.get("submission_requirement", {})
		if not requirement.is_empty():
			narrative_parts.append("后续提交 %s" % _item_name(String(requirement.get("item_id", ""))))
		if not narrative_parts.is_empty():
			lines.append(" / ".join(narrative_parts))
	var battle_card: Dictionary = delta.get("battle_card", {})
	if not battle_card.is_empty():
		var battle_parts: Array[String] = []
		battle_parts.append("战斗%s" % ("胜利" if bool(battle_card.get("victory", false)) else "失败"))
		var completed_objectives: Array = battle_card.get("completed_objectives", [])
		if not completed_objectives.is_empty():
			battle_parts.append("目标 %s" % ", ".join(completed_objectives))
		lines.append(" / ".join(battle_parts))
	if not String(delta.get("warning", "")).is_empty():
		lines.append("[color=#ff9b9b]警告：%s[/color]" % String(delta.get("warning", "")))
	_delta_snapshot_label.text = "\n".join(lines)


func _format_delta_stacks(stacks: Array) -> String:
	if stacks.is_empty():
		return "无"
	var parts: Array[String] = []
	for stack_value in stacks:
		if typeof(stack_value) != TYPE_DICTIONARY:
			continue
		var stack: Dictionary = stack_value
		var item_id: String = String(stack.get("id", ""))
		var count: int = int(stack.get("count", 0))
		if count == 0:
			continue
		parts.append("%s%+d" % [_item_name(item_id) + " ", count])
	return ", ".join(parts) if not parts.is_empty() else "无"


func _render_forced_hint() -> void:
	if _forced_hint_label == null:
		return
	var hint: Dictionary = _run_state().get_forced_event_hint()
	if hint.is_empty():
		_forced_hint_label.text = "强制袭击预警：未启用（尚未出发）"
		_forced_hint_label.modulate = Color(0.76, 0.82, 1.0, 1.0)
		return
	var status: String = String(hint.get("status", ""))
	_forced_hint_label.text = "强制袭击预警：%s" % String(hint.get("text", ""))
	match status:
		"pending":
			_forced_hint_label.modulate = Color(1.0, 0.75, 0.45, 1.0)
		"armed":
			_forced_hint_label.modulate = Color(0.98, 0.88, 0.54, 1.0)
		"locked":
			_forced_hint_label.modulate = Color(0.72, 0.82, 1.0, 1.0)
		_:
			_forced_hint_label.modulate = Color(0.82, 0.84, 0.92, 1.0)


func _render_narrative_option_box(event_def: Dictionary, is_hover_preview: bool) -> void:
	if _narrative_option_box == null or _narrative_option_select == null or _narrative_option_preview_label == null:
		return
	var options: Array = event_def.get("option_list", [])
	var is_narrative: bool = String(event_def.get("resolution_type", "")) == "narrative"
	if not is_narrative or options.is_empty():
		_narrative_option_box.visible = false
		return
	_narrative_option_box.visible = true
	_narrative_option_select.disabled = is_hover_preview

	var current_ids: Array[String] = []
	for i in range(_narrative_option_select.get_item_count()):
		current_ids.append(String(_narrative_option_select.get_item_metadata(i)))
	var incoming_ids: Array[String] = []
	for option_value in options:
		if typeof(option_value) != TYPE_DICTIONARY:
			continue
		incoming_ids.append(String(option_value.get("id", "")))
	var should_rebuild: bool = current_ids != incoming_ids
	if should_rebuild:
		_narrative_option_select.clear()
		for option_value in options:
			if typeof(option_value) != TYPE_DICTIONARY:
				continue
			var option_def: Dictionary = option_value
			var option_id: String = String(option_def.get("id", ""))
			if option_id.is_empty():
				continue
			var option_text := String(option_def.get("text", option_id))
			_narrative_option_select.add_item(option_text)
			_narrative_option_select.set_item_metadata(_narrative_option_select.get_item_count() - 1, option_id)
	if _narrative_option_select.get_item_count() > 0 and _narrative_option_select.selected < 0:
		_narrative_option_select.select(0)
	var selected_option: Dictionary = _find_narrative_option(event_def, _selected_narrative_option_id())
	_narrative_option_preview_label.text = _build_narrative_option_preview(event_def, selected_option, is_hover_preview)


func _selected_narrative_option_id() -> String:
	if _narrative_option_select == null:
		return ""
	if _narrative_option_select.selected < 0 or _narrative_option_select.selected >= _narrative_option_select.get_item_count():
		return ""
	return String(_narrative_option_select.get_item_metadata(_narrative_option_select.selected))


func _on_narrative_option_selected(_index: int) -> void:
	_render_dispatch_panel()


func _pick_featured_task(active_tasks: Array) -> Dictionary:
	for task_value in active_tasks:
		if typeof(task_value) != TYPE_DICTIONARY:
			continue
		var task: Dictionary = task_value
		if String(task.get("task_type", "")).begins_with("mainline") or String(task.get("task_type", "")) == "extraction":
			return task
	for task_value in active_tasks:
		if typeof(task_value) == TYPE_DICTIONARY:
			return task_value
	return {}


func _task_type_name(task_type: String) -> String:
	match task_type:
		"mainline_narrative":
			return "主线叙事"
		"mainline_battle":
			return "主线战斗"
		"side_narrative":
			return "支线叙事"
		"side_battle":
			return "支线战斗"
		"extraction":
			return "撤离节点"
		_:
			return task_type if not task_type.is_empty() else "未知"


func _task_progress_text(task: Dictionary) -> String:
	if bool(task.get("is_completed", false)):
		return "已完成"
	if bool(task.get("is_visible_on_board", false)):
		return "已上板，可处理"
	if bool(task.get("is_unlocked", false)):
		return "已解锁，待出现"
	return "未满足条件"


func _format_task_conditions(conditions: Array) -> String:
	if conditions.is_empty():
		return "无额外条件"
	var parts: Array[String] = []
	for cond_value in conditions:
		var cond_text: String = _task_condition_text(String(cond_value))
		if not cond_text.is_empty():
			parts.append(cond_text)
	return "；".join(parts) if not parts.is_empty() else "无额外条件"


func _task_condition_text(condition: String) -> String:
	if condition.is_empty():
		return ""
	if condition.begins_with("flag:"):
		return "需要剧情推进“%s”" % _story_flag_name(condition.trim_prefix("flag:"))
	if condition.begins_with("unlock:"):
		return "需要系统解锁“%s”" % _unlock_flag_name(condition.trim_prefix("unlock:"))
	if condition.begins_with("completed_task:"):
		return "需先完成 %s" % _task_name(condition.trim_prefix("completed_task:"))
	if condition.begins_with("has_item:"):
		return "需持有 %s" % _item_name(condition.trim_prefix("has_item:"))
	if condition.contains(">="):
		var parts: PackedStringArray = condition.split(">=")
		if parts.size() == 2:
			if parts[0] == "turn":
				return "到达第 %s 回合" % parts[1]
			if parts[0] == "danger_level":
				return "危险度达到 %s" % parts[1]
	return condition


func _format_next_unlocks(task_ids: Array) -> String:
	if task_ids.is_empty():
		return ""
	var names: Array[String] = []
	for task_id_value in task_ids:
		var task_id: String = String(task_id_value)
		if task_id.is_empty():
			continue
		names.append(_task_name(task_id))
	return " -> ".join(names)


func _format_task_name_list(task_ids: Array) -> String:
	var names: Array[String] = []
	for task_id_value in task_ids:
		var task_id: String = String(task_id_value)
		if task_id.is_empty():
			continue
		names.append(_task_name(task_id))
	return ", ".join(names) if not names.is_empty() else "无"


func _task_name(task_id: String) -> String:
	if task_id.is_empty():
		return ""
	var task_def: Dictionary = _content_db().get_task(task_id)
	if task_def.is_empty():
		return task_id
	return String(task_def.get("name_cn", task_id))


func _find_narrative_option(event_def: Dictionary, option_id: String) -> Dictionary:
	for option_value in event_def.get("option_list", []):
		if typeof(option_value) != TYPE_DICTIONARY:
			continue
		var option_def: Dictionary = option_value
		if String(option_def.get("id", "")) == option_id:
			return option_def
	for option_value in event_def.get("option_list", []):
		if typeof(option_value) == TYPE_DICTIONARY:
			return option_value
	return {}


func _build_narrative_option_preview(event_def: Dictionary, option_def: Dictionary, is_hover_preview: bool) -> String:
	var lines: Array[String] = []
	lines.append("[b]选项预览[/b]")
	if option_def.is_empty():
		lines.append("暂无可用选项。")
		return "\n".join(lines)
	lines.append("当前选择：%s" % String(option_def.get("text", option_def.get("id", "未命名选项"))))
	var preview_impact: String = String(option_def.get("preview_impact", ""))
	if not preview_impact.is_empty():
		lines.append("预期结果：%s" % preview_impact)
	var reward: Dictionary = option_def.get("reward_package", {})
	var reward_summary: Array[String] = []
	var currencies: String = _format_delta_stacks(reward.get("currencies", []))
	if currencies != "无":
		reward_summary.append("货币 %s" % currencies)
	var items: String = _format_delta_stacks(reward.get("items", []))
	if items != "无":
		reward_summary.append("物资 %s" % items)
	var relics: String = _format_delta_stacks(reward.get("relics", []))
	if relics != "无":
		reward_summary.append("圣遗 %s" % relics)
	var story_flags: Array = reward.get("story_flags", [])
	if not story_flags.is_empty():
		reward_summary.append("剧情标记 %s" % _format_story_flag_list(story_flags))
	var unlock_flags: Array = reward.get("unlock_flags", [])
	if not unlock_flags.is_empty():
		reward_summary.append("解锁 %s" % _format_unlock_flag_list(unlock_flags))
	if not reward_summary.is_empty():
		lines.append("直接变化：%s" % "；".join(reward_summary))
	var complete_task_id: String = String(option_def.get("complete_task_id", ""))
	if not complete_task_id.is_empty():
		lines.append("推进节点：完成 %s" % _task_name(complete_task_id))
	var submission_requirement: Dictionary = event_def.get("submission_requirement", {})
	if not submission_requirement.is_empty():
		lines.append("后续推进：取得并提交 %s 后继续。" % _item_name(String(submission_requirement.get("item_id", ""))))
	if is_hover_preview:
		lines.append("[color=#c9cde5]当前为悬停预览，点击地图事件后可正式选择。[/color]")
	return "\n".join(lines)


func _open_settlement(settlement_snapshot: Dictionary) -> void:
	selected_event_id = ""
	panel_event = {}
	panel_mode = "none"
	_render_settlement_snapshot(settlement_snapshot)
	_set_ui_phase("settlement")


func _open_battle_result(result: Dictionary) -> void:
	if _battle_result_layer == null:
		return
	_pending_battle_flow_result = result.duplicate(true)
	_render_battle_result_summary(result)
	_battle_result_layer.visible = true


func _close_battle_result() -> void:
	if _battle_result_layer != null:
		_battle_result_layer.visible = false


func _open_settlement_from_death() -> void:
	var death_result: Dictionary = _run_state().consume_death_result()
	if death_result.is_empty():
		return
	var settlement_snapshot: Dictionary = _progression_state().build_run_settlement_snapshot({}, death_result)
	_open_settlement(settlement_snapshot)


func _render_battle_result_summary(result: Dictionary) -> void:
	if _battle_result_title_label == null or _battle_result_body_label == null:
		return
	var resolved_event: Dictionary = result.get("selected_event", {})
	var dispatch_result: Dictionary = result.get("dispatch_result", {})
	var battle_result: Dictionary = dispatch_result.get("battle_result", {})
	var map_effects: Dictionary = battle_result.get("map_effects", {})
	var is_victory: bool = bool(battle_result.get("victory", false))
	_battle_result_title_label.text = "战斗结果：%s" % ("胜利" if is_victory else "失败")
	var lines: Array[String] = []
	lines.append("[b]战斗事件[/b] %s" % String(resolved_event.get("title", "未命名战斗")))
	lines.append("[b]结果判定[/b] %s" % ("已达成目标" if is_victory else "未达成目标"))
	lines.append("[b]剩余生命[/b] %.1f" % float(map_effects.get("hero_hp_remaining", 0.0)))
	lines.append("[b]剩余敌方生命[/b] %.1f" % float(map_effects.get("enemy_hp_remaining", 0.0)))
	lines.append("[b]敌方总数[/b] %d" % int(map_effects.get("enemy_count_total", 0)))
	lines.append("[b]战斗时长[/b] %d 回合节拍" % int(map_effects.get("elapsed_ticks", 0)))
	var completed_objectives: Array = battle_result.get("completed_objectives", [])
	lines.append("[b]目标完成[/b] %s" % (", ".join(completed_objectives) if not completed_objectives.is_empty() else "无"))
	var reward_package: Dictionary = battle_result.get("reward_package", {})
	if not reward_package.is_empty():
		lines.append("")
		lines.append("[b]战利品[/b]")
		lines.append("货币：%s" % _format_stack_lines(reward_package.get("currencies", [])))
		lines.append("物资：%s" % _format_stack_lines(reward_package.get("items", [])))
		lines.append("圣遗：%s" % _format_stack_lines(reward_package.get("relics", [])))
	if not String(battle_result.get("defeat_reason", "")).is_empty():
		lines.append("")
		lines.append("[color=#ff9b9b][b]失败原因[/b] %s[/color]" % String(battle_result.get("defeat_reason", "")))
	_battle_result_body_label.text = "\n".join(lines)


func _render_settlement_snapshot(snapshot: Dictionary) -> void:
	if _settlement_title_label == null or _settlement_body_label == null:
		return
	var status: String = String(snapshot.get("status", "idle"))
	match status:
		"extracted":
			_settlement_title_label.text = "回归结算：成功撤离"
		"dead":
			_settlement_title_label.text = "回归结算：任务失败"
		_:
			_settlement_title_label.text = "回归结算"
	var lines: Array[String] = []
	if status == "extracted":
		lines.append("[b]临时收益已转永久[/b]")
		lines.append("物资：%s" % _format_stack_lines(snapshot.get("saved_items", [])))
		lines.append("货币：%s" % _format_stack_lines(snapshot.get("saved_currencies", [])))
		lines.append("圣遗：%s" % _format_stack_lines(snapshot.get("saved_relics", [])))
		if not String(snapshot.get("bonus_note", "")).is_empty():
			lines.append("[color=#b6f6a8]%s[/color]" % String(snapshot.get("bonus_note", "")))
	elif status == "dead":
		lines.append("[b]死亡损失[/b]")
		lines.append("物资：%s" % _format_stack_lines(snapshot.get("lost_items", [])))
		lines.append("货币：%s" % _format_stack_lines(snapshot.get("lost_currencies", [])))
		lines.append("圣遗：%s" % _format_stack_lines(snapshot.get("lost_relics", [])))
		lines.append("")
		lines.append("[b]保留进度[/b]")
		lines.append("剧情标记：%s" % _format_story_flag_list(snapshot.get("story_flags_preserved", [])))
		lines.append("系统解锁：%s" % _format_unlock_flag_list(snapshot.get("unlock_flags_preserved", [])))
	lines.append("")
	lines.append("[b]任务与标记[/b]")
	lines.append("完成任务：%s" % _format_task_name_list(snapshot.get("completed_tasks", [])))
	lines.append("剧情标记：%s" % _format_story_flag_list(snapshot.get("story_flags_applied", [])))
	lines.append("系统解锁：%s" % _format_unlock_flag_list(snapshot.get("unlock_flags_applied", [])))
	lines.append("")
	lines.append("[b]结算后永久仓库快照[/b]")
	lines.append("物资：%s" % _format_stack_lines(snapshot.get("projected_inventory_items", [])))
	lines.append("货币：%s" % _format_stack_lines(snapshot.get("projected_currencies", [])))
	lines.append("圣遗：%s" % _format_stack_lines(snapshot.get("projected_relics", [])))
	_settlement_body_label.text = "\n".join(lines)


func _format_string_list(values: Array) -> String:
	if values.is_empty():
		return "无"
	var cleaned: Array[String] = []
	for value in values:
		var text: String = String(value)
		if text.is_empty():
			continue
		cleaned.append(text)
	return "无" if cleaned.is_empty() else ", ".join(cleaned)


func _format_story_flag_list(values: Array) -> String:
	if values.is_empty():
		return "无"
	var names: Array[String] = []
	for value in values:
		var flag_id: String = String(value)
		if flag_id.is_empty():
			continue
		names.append(_story_flag_name(flag_id))
	return "无" if names.is_empty() else ", ".join(names)


func _format_unlock_flag_list(values: Array) -> String:
	if values.is_empty():
		return "无"
	var names: Array[String] = []
	for value in values:
		var unlock_id: String = String(value)
		if unlock_id.is_empty():
			continue
		names.append(_unlock_flag_name(unlock_id))
	return "无" if names.is_empty() else ", ".join(names)


func _story_flag_name(flag_id: String) -> String:
	match flag_id:
		"mainline_started":
			return "主线已启动：找到静默祷词线索"
		"mainline_item_submitted":
			return "主线提交完成：静默祷词已献呈"
		"mainline_completed":
			return "主线已完成：圣坛核心已压制"
		"sidebranch_trail":
			return "支线线索已锁定：灰烬刻印轨迹"
		"sidebranch_extract_bonus_ready":
			return "侧线回报已就绪：撤离补给加成"
		"a01_crossing_log_read":
			return "残桥日志已读取"
		"a01_crossing_clue_collected":
			return "残桥线索已抄录"
		"a01_crossing_log_purged":
			return "污染残页已焚毁"
		_:
			return _humanize_symbol(flag_id)


func _unlock_flag_name(unlock_id: String) -> String:
	match unlock_id:
		"narrative_events_enabled":
			return "叙事事件已开放"
		"special_item_event_enabled":
			return "特殊物品事件已开放"
		"equipment_tab_enabled":
			return "家园装备页已开放"
		_:
			return _humanize_symbol(unlock_id)


func _humanize_symbol(raw_id: String) -> String:
	if raw_id.is_empty():
		return ""
	var text: String = raw_id.replace("_", " ")
	var parts: PackedStringArray = text.split(" ")
	var cleaned: Array[String] = []
	for part in parts:
		if part.is_empty():
			continue
		cleaned.append(part.capitalize())
	return raw_id if cleaned.is_empty() else " ".join(cleaned)


func _names_from_item_ids(ids: Array) -> Array[String]:
	var names: Array[String] = []
	for item_value in ids:
		var item_id: String = String(item_value)
		if item_id.is_empty():
			continue
		names.append(_item_name(item_id))
	return names


func _selector_metadata(selector: OptionButton) -> String:
	if selector == null or selector.get_item_count() <= 0:
		return ""
	var selected_idx := selector.selected
	if selected_idx < 0:
		selected_idx = 0
	if selected_idx >= selector.get_item_count():
		selected_idx = selector.get_item_count() - 1
	return String(selector.get_item_metadata(selected_idx))


func _selected_home_items() -> Array:
	var selected: Array = []
	for selector: OptionButton in [_home_item_slot_a, _home_item_slot_b]:
		var item_id: String = _selector_metadata(selector)
		if item_id.is_empty():
			continue
		if selected.has(item_id):
			continue
		selected.append(item_id)
	return selected


func _selected_home_relics() -> Array:
	var relic_id: String = _selector_metadata(_home_relic_slot)
	return [] if relic_id.is_empty() else [relic_id]


func _map_name(map_id: String) -> String:
	if map_id.is_empty():
		return "未选择"
	var map_def: Dictionary = _content_db().get_map(map_id)
	if map_def.is_empty():
		return map_id
	return String(map_def.get("name_cn", map_id))


func _build_home_start_context() -> Dictionary:
	var context: Dictionary = _progression_state().get_context_for_conditions()
	context["turn"] = 1
	context["danger_level"] = 0
	return context


func _is_map_startable(map_id: String) -> bool:
	if map_id.is_empty():
		return false
	for map_value in _content_db().list_startable_maps(_build_home_start_context()):
		if typeof(map_value) != TYPE_DICTIONARY:
			continue
		if String(map_value.get("id", "")) == map_id:
			return true
	return false


func _unit_name(unit_id: String) -> String:
	if unit_id.is_empty():
		return "未选择"
	var unit_def: Dictionary = _content_db().get_unit(unit_id)
	if unit_def.is_empty():
		return unit_id
	var unit_name: String = String(unit_def.get("name_cn", ""))
	return unit_id if unit_name.is_empty() else unit_name


func _on_home_selection_changed(_index: int) -> void:
	_render_home_summary()


func _on_home_start_pressed() -> void:
	var hero_id: String = _selector_metadata(_home_hero_select)
	var map_id: String = _selector_metadata(_home_map_select)
	var carried_items: Array = _selected_home_items()
	var equipped_relics: Array = _selected_home_relics()
	if hero_id.is_empty():
		_append_log("出发失败：未选择英雄。")
		return
	if map_id.is_empty():
		_append_log("出发失败：未选择目标地图。")
		return
	if not _is_map_startable(map_id):
		_append_log("出发失败：%s 当前没有可处理事件，请先切换地图或补内容。" % _map_name(map_id))
		return
	_start_run_from_home_selection(map_id, hero_id, carried_items, equipped_relics)


func _on_settlement_return_home_pressed() -> void:
	_append_log("已返回家园，可重新整备出发。")
	_set_ui_phase("home")
	_refresh_all()


func _on_return_home_pressed() -> void:
	if _ui_phase != "run":
		return
	_run_state().abandon_current_run()
	selected_event_id = ""
	panel_event = {}
	panel_mode = "none"
	_append_log("已结束当前作战并返回家园整备。")
	_set_ui_phase("home")
	_refresh_all()


func _append_log(line: String) -> void:
	log_lines.append("[%s] %s" % [_time_string(), line])
	while log_lines.size() > 16:
		log_lines.remove_at(0)


func _on_map_surface_resized() -> void:
	_apply_responsive_layout()
	_render_map_events()


func _on_preview_tree_exited() -> void:
	_preview_instance = null
	_refresh_all()


func _on_preview_android_size_pressed() -> void:
	if not _can_preview_android_sizes():
		return
	_android_preview_index = (_android_preview_index + 1) % ANDROID_PREVIEW_SIZES.size()
	_apply_android_preview_size(ANDROID_PREVIEW_SIZES[_android_preview_index], true)


func _on_interactive_battle_finished(battle_result: Dictionary) -> void:
	var result: Dictionary = _run_state().complete_selected_event_with_battle_result(battle_result)
	if result.is_empty():
		_finalize_selected_event_result(result)
		return
	var dispatch_result: Dictionary = result.get("dispatch_result", {})
	if dispatch_result.get("battle_result", {}).is_empty():
		_finalize_selected_event_result(result)
		return
	_open_battle_result(result)


func _on_battle_result_continue_pressed() -> void:
	var result: Dictionary = _pending_battle_flow_result.duplicate(true)
	_pending_battle_flow_result = {}
	_close_battle_result()
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
	if bool(marker.get("is_mainline", false)):
		return "主线节点"
	if bool(marker.get("is_side_fixed", false)):
		return "支线节点"
	if bool(marker.get("is_ghost", false)):
		return "后续节点"
	if bool(marker.get("is_fixed", false)):
		return "固定节点"
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
	if bool(marker.get("is_ghost", false)):
		return "后续任务锚点：当前不可点击，仅用于提示推进方向"
	var resolution_type: String = String(event_def.get("resolution_type", ""))
	if bool(marker.get("is_mainline", false)):
		if resolution_type == "battle":
			return "主线固定节点：点击后进入关键战斗"
		return "主线固定节点：点击后推进叙事骨架"
	if bool(marker.get("is_side_fixed", false)):
		return "支线固定节点：会持续保留在地图上等待处理"
	if bool(marker.get("is_fixed", false)):
		return "固定节点：不会被随机事件刷新覆盖"
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


func _apply_marker_button_style(button: Button, marker: Dictionary) -> void:
	var base_color: Color = _marker_color(String(marker.get("kind", "battle")))
	button.modulate = Color(1, 1, 1, 1)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(base_color.r * 0.18, base_color.g * 0.18, base_color.b * 0.22, 0.92)
	normal.corner_radius_top_left = 22
	normal.corner_radius_top_right = 22
	normal.corner_radius_bottom_right = 22
	normal.corner_radius_bottom_left = 22
	normal.shadow_color = Color(0.0, 0.0, 0.0, 0.34)
	normal.shadow_size = 6
	normal.shadow_offset = Vector2(0, 3)
	normal.border_color = base_color
	normal.set_border_width_all(2)
	if bool(marker.get("is_mainline", false)):
		normal.bg_color = Color(0.25, 0.18, 0.05, 0.96)
		normal.border_color = Color(0.98, 0.82, 0.32, 1.0)
		normal.set_border_width_all(3)
	elif bool(marker.get("is_side_fixed", false)):
		normal.bg_color = Color(0.08, 0.18, 0.20, 0.94)
		normal.border_color = Color(0.62, 0.90, 0.94, 1.0)
		normal.set_border_width_all(3)
	if bool(marker.get("is_selected", false)):
		normal.border_color = Color(0.98, 0.97, 0.92, 1.0)
		normal.set_border_width_all(4)
	var hover := normal.duplicate()
	hover.bg_color = normal.bg_color.lightened(0.16)
	hover.border_color = normal.border_color.lightened(0.10)
	var pressed := normal.duplicate()
	pressed.bg_color = normal.bg_color.darkened(0.12)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", hover)


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
		if map_hover_tooltip.get_parent() == marker_layer:
			marker_layer.move_child(map_hover_tooltip, marker_layer.get_child_count() - 1)
		map_hover_tooltip.z_index = 300
		map_hover_tooltip.visible = true
		map_hover_label.text = "%s\n%s\n%s" % [
			_marker_badge_text(marker),
			String(marker.get("title", "")),
			_marker_hint_text(marker)
		]
		var tooltip_width: float = clamp(marker_layer.size.x * 0.42, 170.0, 240.0)
		map_hover_tooltip.custom_minimum_size = Vector2(tooltip_width, 0)
		var tooltip_pos := button.position + Vector2(button.size.x + 12.0, -4.0)
		if tooltip_pos.x + tooltip_width > marker_layer.size.x:
			tooltip_pos.x = button.position.x - (tooltip_width + 12.0)
		tooltip_pos.x = clamp(tooltip_pos.x, 8.0, max(8.0, marker_layer.size.x - tooltip_width - 8.0))
		tooltip_pos.y = clamp(tooltip_pos.y, 8.0, max(8.0, marker_layer.size.y - 96.0))
		map_hover_tooltip.position = tooltip_pos
		if map_surface != null and map_surface.has_method("set_highlight_marker"):
			map_surface.call("set_highlight_marker", marker, tooltip_pos + Vector2(14.0, 20.0))
	_render_dispatch_panel()


func _hide_map_marker_hover() -> void:
	_hovered_event = {}
	_hovered_panel_mode = "none"
	if map_hint_label != null:
		map_hint_label.text = _default_map_hint_text
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
	if _ui_phase != "run":
		return
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
	if _window_configured:
		return
	if OS.has_feature("web") or _is_mobile_runtime():
		_window_configured = true
		return
	if OS.has_feature("editor"):
		var editor_window := get_window()
		if editor_window != null:
			editor_window.min_size = BOOTSTRAP_WINDOW_MIN_SIZE
			_apply_android_preview_size(ANDROID_PREVIEW_SIZES[_android_preview_index], false)
		_window_configured = true
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
	_window_configured = true


func _can_preview_android_sizes() -> bool:
	return OS.has_feature("editor") and not OS.has_feature("web") and not _is_mobile_runtime()


func _apply_android_preview_size(target_size: Vector2i, announce: bool) -> void:
	if not _can_preview_android_sizes():
		return
	var window := get_window()
	if window == null:
		return
	var min_w: int = min(BOOTSTRAP_WINDOW_MIN_SIZE.x, target_size.x)
	var min_h: int = min(BOOTSTRAP_WINDOW_MIN_SIZE.y, target_size.y)
	window.min_size = Vector2i(min_w, min_h)
	window.mode = Window.MODE_WINDOWED
	var screen := DisplayServer.window_get_current_screen()
	var usable_rect := DisplayServer.screen_get_usable_rect(screen)
	var final_size := target_size
	if usable_rect.size.x > 0 and usable_rect.size.y > 0:
		final_size = Vector2i(
			min(target_size.x, usable_rect.size.x),
			min(target_size.y, usable_rect.size.y)
		)
		window.position = usable_rect.position + (usable_rect.size - final_size) / 2
	window.size = final_size
	_update_android_preview_button_text(final_size)
	if announce:
		_append_log("安卓横屏预览已切换为 %dx%d。" % [final_size.x, final_size.y])
	call_deferred("_apply_responsive_layout")


func _update_android_preview_button_text(size: Vector2i) -> void:
	if preview_android_size_button == null:
		return
	preview_android_size_button.text = "安卓横屏预览：%dx%d" % [size.x, size.y]


func _is_mobile_runtime() -> bool:
	return OS.has_feature("mobile") or OS.has_feature("android") or OS.get_name() == "Android"


func _is_mobile_landscape(viewport_size: Vector2) -> bool:
	return _is_mobile_runtime() and viewport_size.x >= viewport_size.y * 1.15


func _content_db() -> Node:
	return get_node("/root/ContentDB")


func _run_state() -> Node:
	return get_node("/root/RunState")


func _progression_state() -> Node:
	return get_node("/root/ProgressionState")
