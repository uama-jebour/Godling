extends Node

signal interactive_battle_finished(result: Dictionary)

const BATTLE_SIMULATOR := preload("res://systems/battle/battle_simulator.gd")
const UNIT_TOKEN_SCENE := preload("res://scenes/battle/unit_token.tscn")
const DRAG_START_DISTANCE := 12.0
const DRAG_ATTACK_CURVE_ARC_MULTIPLIER := 0.24
const DRAG_ATTACK_CURVE_ARC_MIN := 46.0
const DRAG_ATTACK_CURVE_ARC_MAX := 128.0
const DRAG_ATTACK_CURVE_SAMPLE_DENSITY := 18.0
const DRAG_ATTACK_LINE_WIDTH := 7.2
const DRAG_ATTACK_ARROW_SCALE := 1.46
const DRAG_ATTACK_ARROW_GLOW_SCALE := 1.84
const ACTION_CARD_SIZE := Vector2(158, 228)
const ACTION_CARD_MIN_WIDTH := 132.0
const ACTION_CARD_MAX_WIDTH := 176.0
const ACTION_CARD_CORNER_RADIUS := 14
const MAIN_ITEM_CARD_LIMIT := 2
const ACTION_INFO_WIDTH_RATIO := 0.15
const ACTION_INFO_MIN_WIDTH := 180.0
const ACTION_INFO_MAX_WIDTH := 260.0
const ARENA_TOKEN_BASE_WIDTH := 248.0
const SKILL_ICON_PRIMARY := preload("res://assets/battle/icons/skill_primary.svg")
const SKILL_ICON_GUARD := preload("res://assets/battle/icons/skill_guard.svg")
const SKILL_ICON_BURST := preload("res://assets/battle/icons/skill_burst.svg")

@onready var battle_arena: Control = %BattleArena
@onready var arena_tint: ColorRect = get_node_or_null("%ArenaTint")
@onready var hero_lane: ColorRect = get_node_or_null("%HeroLane")
@onready var enemy_lane: ColorRect = get_node_or_null("%EnemyLane")
@onready var mid_gap: ColorRect = get_node_or_null("%MidGap")
@onready var center_line: ColorRect = get_node_or_null("%CenterLine")
@onready var battle_title: Label = %BattleTitle
@onready var battle_summary: RichTextLabel = %BattleSummary
@onready var hero_header: Label = %HeroHeader
@onready var hero_token: ColorRect = %HeroToken
@onready var hero_label: Label = %HeroLabel
@onready var enemy_header: Label = get_node_or_null("%EnemyHeader")
@onready var enemy_tokens: VBoxContainer = %EnemyTokens
@onready var tick_label: Label = %TickLabel
@onready var event_log: RichTextLabel = %EventLog
@onready var status_label: Label = get_node_or_null("%StatusLabel")
@onready var selected_target_label: Label = get_node_or_null("%SelectedTargetLabel")
@onready var root_vbox: VBoxContainer = $"../BattleUI/ShellMargin/ModalPanel/PanelMargin/RootVBox"
@onready var modal_panel: PanelContainer = $"../BattleUI/ShellMargin/ModalPanel"
@onready var top_row: HBoxContainer = $"../BattleUI/ShellMargin/ModalPanel/PanelMargin/RootVBox/TopRow"
@onready var side_vbox: VBoxContainer = $"../BattleUI/ShellMargin/ModalPanel/PanelMargin/RootVBox/ContentRow/SidePanel/SideMargin/SideVBox"
@onready var battle_summary_panel: PanelContainer = $"../BattleUI/ShellMargin/ModalPanel/PanelMargin/RootVBox/TopRow/BattleSummaryPanel"
@onready var hero_panel: PanelContainer = $"../BattleUI/ShellMargin/ModalPanel/PanelMargin/RootVBox/TopRow/HeroPanel"
@onready var side_panel: PanelContainer = $"../BattleUI/ShellMargin/ModalPanel/PanelMargin/RootVBox/ContentRow/SidePanel"
@onready var action_bar: HBoxContainer = $"../BattleUI/ShellMargin/ModalPanel/PanelMargin/RootVBox/ActionBar"
@onready var action_info_box: VBoxContainer = $"../BattleUI/ShellMargin/ModalPanel/PanelMargin/RootVBox/ActionBar/ActionInfo"
@onready var command_strip_scroll: ScrollContainer = get_node_or_null("%CommandStripScroll")
@onready var command_strip: HBoxContainer = get_node_or_null("%CommandStrip")
@onready var attack_button: Label = get_node_or_null("%AttackButton")
@onready var defend_button: Label = get_node_or_null("%DefendButton")
@onready var wait_button: Button = get_node_or_null("%WaitButton")
@onready var item_button: Button = get_node_or_null("%ItemButton")
@onready var attack_skill_card: Control = get_node_or_null("%AttackSkillCard")
@onready var defend_skill_card: Control = get_node_or_null("%DefendSkillCard")
var burst_button: Button
var burst_skill_card: Control
var burst_skill_icon: TextureRect
var burst_cooldown_mask: ColorRect
var burst_meta_label: Label
var burst_cooldown_tag: Label
var burst_cooldown_bar: ProgressBar
var burst_resource_tag: Label
var burst_resource_bar: ProgressBar
@onready var attack_skill_icon: TextureRect = get_node_or_null("%AttackSkillIcon")
@onready var defend_skill_icon: TextureRect = get_node_or_null("%DefendSkillIcon")
@onready var attack_cooldown_mask: ColorRect = get_node_or_null("%AttackCooldownMask")
@onready var defend_cooldown_mask: ColorRect = get_node_or_null("%DefendCooldownMask")
@onready var attack_meta_label: Label = get_node_or_null("%AttackMetaLabel")
@onready var attack_cooldown_tag: Label = get_node_or_null("%AttackCooldownTag")
@onready var attack_cooldown_bar: ProgressBar = get_node_or_null("%AttackCooldownBar")
@onready var attack_resource_tag: Label = get_node_or_null("%AttackResourceTag")
@onready var attack_resource_bar: ProgressBar = get_node_or_null("%AttackResourceBar")
@onready var defend_meta_label: Label = get_node_or_null("%DefendMetaLabel")
@onready var defend_cooldown_tag: Label = get_node_or_null("%DefendCooldownTag")
@onready var defend_cooldown_bar: ProgressBar = get_node_or_null("%DefendCooldownBar")
@onready var defend_resource_tag: Label = get_node_or_null("%DefendResourceTag")
@onready var defend_resource_bar: ProgressBar = get_node_or_null("%DefendResourceBar")
@onready var item_card_rack: HBoxContainer = get_node_or_null("%ItemCardRack")
@onready var item_card_a: PanelContainer = get_node_or_null("%ItemCardA")
@onready var item_card_b: PanelContainer = get_node_or_null("%ItemCardB")
@onready var item_card_a_icon: TextureRect = get_node_or_null("%ItemCardAIcon")
@onready var item_card_b_icon: TextureRect = get_node_or_null("%ItemCardBIcon")
@onready var item_card_a_title: Label = get_node_or_null("%ItemCardATitle")
@onready var item_card_b_title: Label = get_node_or_null("%ItemCardBTitle")
@onready var item_card_a_desc: Label = get_node_or_null("%ItemCardADesc")
@onready var item_card_b_desc: Label = get_node_or_null("%ItemCardBDesc")
@onready var item_card_a_meta: Label = get_node_or_null("%ItemCardAMeta")
@onready var item_card_b_meta: Label = get_node_or_null("%ItemCardBMeta")
@onready var item_card_a_use_button: Button = get_node_or_null("%ItemCardAUseButton")
@onready var item_card_b_use_button: Button = get_node_or_null("%ItemCardBUseButton")
@onready var item_popup_panel: PopupPanel = get_node_or_null("%ItemPopupPanel")
@onready var item_list_vbox: VBoxContainer = get_node_or_null("%ItemListVBox")

var _simulator: RefCounted
var _last_state: Dictionary = {}
var _log_lines: Array[String] = []
var _arena_nodes: Dictionary = {}
var _last_hp_by_entity: Dictionary = {}
var _last_visual_position_by_entity: Dictionary = {}
var _feedback_counts: Dictionary = {"hit": 0, "down": 0}
var _motion_feedback_counts: Dictionary = {"hero_advances": 0, "enemy_advances": 0, "animated_entities": 0}
var _combat_cue_counts: Dictionary = {"attack_lines": 0, "death_fades": 0}
var _timeline: Array = []
var _playback_nonce: int = 0
var _attack_line: Line2D
var _attack_arrow: Polygon2D
var _attack_arrow_glow: Polygon2D
var _attack_line_tween: Tween
var _attack_curve_points := PackedVector2Array()
var _interactive_mode := false
var _interactive_request: Dictionary = {}
var _interactive_context: Dictionary = {}
var _interactive_state: Dictionary = {}
var _selected_target_id := ""
var _focused_entity_id := ""
var _resolving_enemy_phase := false
var _last_action_signature := ""
var _action_deck_panel: PanelContainer
var _drag_in_progress := false
var _last_drag_payload: Dictionary = {}
var _pending_drag_source: Control
var _pending_drag_payload: Dictionary = {}
var _pending_drag_anchor := Vector2.ZERO
var _drag_source_position: Vector2 = Vector2.ZERO
var _item_card_item_ids := ["", ""]
var _recent_item_ids: Array[String] = []
var _current_action_card_width := ACTION_CARD_SIZE.x

const DEFAULT_SKILL_ICON := preload("res://icon.svg")


func _ready() -> void:
	set_process(true)
	if battle_arena != null and not battle_arena.resized.is_connected(_on_battle_arena_resized):
		battle_arena.resized.connect(_on_battle_arena_resized)
	if wait_button != null and not wait_button.pressed.is_connected(_on_wait_pressed):
		wait_button.pressed.connect(_on_wait_pressed)
	if item_button != null and not item_button.pressed.is_connected(_on_item_pressed):
		item_button.pressed.connect(_on_item_pressed)
	_build_action_deck()
	_relocate_hero_panel_to_sidebar()
	_apply_generated_art_preview()
	_apply_shell_texture_layers()
	_bind_drag_sources()
	_set_interaction_enabled(false)
	call_deferred("_refresh_layout_after_frame")


func _relocate_hero_panel_to_sidebar() -> void:
	if hero_panel == null or side_vbox == null:
		return
	if hero_panel.get_parent() != side_vbox:
		hero_panel.reparent(side_vbox)
		side_vbox.move_child(hero_panel, 0)
	hero_panel.custom_minimum_size = Vector2(0, 0)
	hero_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hero_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	if top_row != null and top_row.get_child_count() > 0 and battle_summary_panel != null:
		battle_summary_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL


func _process(_delta: float) -> void:
	_update_drag_hover_feedback()
	if not _drag_in_progress:
		return
	var viewport := get_viewport()
	if viewport == null or not viewport.has_method("gui_is_dragging"):
		return
	if bool(viewport.call("gui_is_dragging")):
		return
	var drag_success := false
	if viewport.has_method("gui_is_drag_successful"):
		drag_success = bool(viewport.call("gui_is_drag_successful"))
	if not drag_success:
		_show_reject_drop_fx(viewport.get_mouse_position())
		_show_drop_rejected_status(_last_drag_payload)
	_drag_in_progress = false
	_last_drag_payload = {}
	_drag_source_position = Vector2.ZERO
	_clear_all_drop_hovers()
	_hide_attack_line()


func _update_drag_hover_feedback() -> void:
	if not _drag_in_progress or _last_drag_payload.is_empty():
		_clear_all_drop_hovers()
		_hide_attack_line()
		return
	var viewport := get_viewport()
	if viewport == null:
		return
	var mouse_pos := viewport.get_mouse_position()
	var hovered_entity_id := ""
	for entity_id: String in _arena_nodes.keys():
		var token: Control = _arena_nodes[entity_id]
		if token == null:
			continue
		var token_rect := token.get_global_rect()
		token_rect = token_rect.grow(12.0)
		if token_rect.has_point(mouse_pos):
			hovered_entity_id = entity_id
			break
	var can_accept := false
	if not hovered_entity_id.is_empty():
		can_accept = _can_drop_payload_on_entity(hovered_entity_id, _last_drag_payload)
		# Draw attack line for any valid target during drag (both enemy and hero)
		if can_accept:
			_update_drag_attack_line(hovered_entity_id)
		else:
			_hide_attack_line()
	else:
		_hide_attack_line()
	for entity_id: String in _arena_nodes.keys():
		var token: Control = _arena_nodes[entity_id]
		if token == null or not token.has_method("notify_drag_hover"):
			continue
		var is_hovered := entity_id == hovered_entity_id
		token.call("notify_drag_hover", is_hovered, can_accept if is_hovered else false)
	# During drag, only keep one visual highlight (the hovered valid target).
	_apply_drag_highlight_override(hovered_entity_id, can_accept)


func _clear_all_drop_hovers() -> void:
	for entity_id: String in _arena_nodes.keys():
		var token: Control = _arena_nodes[entity_id]
		if token == null or not token.has_method("notify_drag_hover"):
			continue
		token.call("notify_drag_hover", false, false)
	_refresh_token_focus_visuals()


func _apply_drag_highlight_override(hovered_entity_id: String, can_accept: bool) -> void:
	for entity_id: String in _arena_nodes.keys():
		var token: Control = _arena_nodes[entity_id]
		if token == null or not token.has_method("set_targeted"):
			continue
		var side: String = "hero" if entity_id == "hero_1" else "enemy"
		var highlighted := can_accept and entity_id == hovered_entity_id
		token.call("set_targeted", highlighted, side)


func _update_drag_attack_line(entity_id: String) -> void:
	if battle_arena == null:
		_hide_attack_line()
		return
	var target_token: Control = _arena_nodes.get(entity_id)
	if target_token == null:
		_hide_attack_line()
		return
	
	# Get source position (from saved drag source position)
	var source_global: Vector2 = _drag_source_position
	if source_global == Vector2.ZERO:
		_hide_attack_line()
		return
	
	# Get target position (token center)
	var target_global: Vector2 = target_token.get_global_rect().get_center()
	
	# Convert to battle_arena local coordinates
	var arena_rect: Rect2 = battle_arena.get_global_rect()
	var source_pos: Vector2 = source_global - arena_rect.position
	var target_pos: Vector2 = target_global - arena_rect.position
	
	# Create or ensure attack line exists
	_ensure_attack_line()
	
	# Build a more cinematic drag curve: higher arc + denser samples.
	var curve_points: PackedVector2Array = _build_attack_curve_points(
		source_pos,
		target_pos,
		DRAG_ATTACK_CURVE_ARC_MULTIPLIER,
		DRAG_ATTACK_CURVE_ARC_MIN,
		DRAG_ATTACK_CURVE_ARC_MAX,
		DRAG_ATTACK_CURVE_SAMPLE_DENSITY
	)
	_attack_curve_points = curve_points
	
	# Draw the line with skill-specific color
	var kind: String = String(_last_drag_payload.get("kind", ""))
	var slot: String = String(_last_drag_payload.get("slot", ""))
	var line_color: Color = Color(0.98, 0.72, 0.28, 0.95)  # Default: primary (orange)
	if kind == "skill":
		match slot:
			"guard":
				line_color = Color(0.34, 0.62, 0.94, 0.95)  # Guard: blue
			"burst":
				line_color = Color(0.92, 0.36, 0.22, 0.95)  # Burst: red
	_attack_line.default_color = line_color
	_attack_line.width = DRAG_ATTACK_LINE_WIDTH
	_attack_line.points = curve_points
	# Reuse node with combat cue line: ensure previous fade-out alpha does not hide drag indicator.
	_attack_line.modulate.a = 1.0
	_attack_line.visible = true
	
	# Position arrow at target
	var direction: Vector2 = Vector2.RIGHT
	if curve_points.size() >= 2:
		direction = (curve_points[curve_points.size() - 1] - curve_points[curve_points.size() - 2]).normalized()
	if direction == Vector2.ZERO:
		direction = (target_pos - source_pos).normalized()
	if direction == Vector2.ZERO:
		direction = Vector2.RIGHT
	if _attack_arrow != null:
		_attack_arrow.position = target_pos
		_attack_arrow.rotation = direction.angle()
		_attack_arrow.scale = Vector2.ONE * DRAG_ATTACK_ARROW_SCALE
		_attack_arrow.color = Color(1.0, 0.99, 0.94, 1.0)
		_attack_arrow.modulate.a = 1.0
		_attack_arrow.visible = true
	if _attack_arrow_glow != null:
		_attack_arrow_glow.position = target_pos
		_attack_arrow_glow.rotation = direction.angle()
		_attack_arrow_glow.scale = Vector2.ONE * DRAG_ATTACK_ARROW_GLOW_SCALE
		_attack_arrow_glow.color = Color(line_color.r, line_color.g, line_color.b, 0.72)
		_attack_arrow_glow.modulate.a = 1.0
		_attack_arrow_glow.visible = true


func _ensure_attack_line() -> void:
	if _attack_line != null:
		return
	_ensure_fx_nodes()


func execute_battle(request: Dictionary, battle_def: Dictionary, context: Dictionary = {}) -> Dictionary:
	var content_db := get_node_or_null("/root/ContentDB")
	var state: Dictionary = _sim().initialize_state(request, battle_def, content_db)
	if state.has("invalid_reason"):
		return _decorate_result(_sim().build_result(state, context, "scene"), state)

	_reset_render_runtime()
	_capture_timeline_state(state, "Battle initialized")
	_render_state(state, "Battle initialized")
	while _sim().is_battle_active(state):
		state = _sim().step_once(state)
		_capture_timeline_state(state, "Tick %d resolved" % int(state.get("elapsed", 0)))
		_render_state(state, "Tick %d resolved" % int(state.get("elapsed", 0)))

	_last_state = state.duplicate(true)
	var result: Dictionary = _decorate_result(_sim().build_result(state, context, "scene"), state)
	if bool(context.get("preview_mode", false)):
		_start_preview_playback()
	call_deferred("_refresh_layout_after_frame")
	return result


func start_interactive_battle(request: Dictionary, battle_def: Dictionary, context: Dictionary = {}) -> void:
	_reset_render_runtime()
	_interactive_mode = true
	_interactive_request = request.duplicate(true)
	_interactive_context = context.duplicate(true)
	_interactive_state = _sim().initialize_state(request, battle_def, get_node_or_null("/root/ContentDB"))
	if _interactive_state.has("invalid_reason"):
		_finish_interactive_battle(_decorate_result(_sim().build_result(_interactive_state, context, "scene"), _interactive_state))
		return
	_selected_target_id = String(_interactive_state.get("selected_target_id", ""))
	_set_interaction_enabled(true)
	_render_state(_interactive_state, "战斗开始")
	_update_interaction_hud(_interactive_state)
	call_deferred("_refresh_layout_after_frame")


func get_last_state() -> Dictionary:
	return _last_state.duplicate(true)


func _sim() -> RefCounted:
	if _simulator == null:
		_simulator = BATTLE_SIMULATOR.new()
	return _simulator


func _reset_render_runtime() -> void:
	_timeline.clear()
	_log_lines.clear()
	_last_hp_by_entity.clear()
	_last_visual_position_by_entity.clear()
	_feedback_counts = {"hit": 0, "down": 0}
	_motion_feedback_counts = {"hero_advances": 0, "enemy_advances": 0, "animated_entities": 0}
	_combat_cue_counts = {"attack_lines": 0, "death_fades": 0}
	_playback_nonce += 1
	_selected_target_id = ""
	_focused_entity_id = ""
	_resolving_enemy_phase = false
	_last_action_signature = ""
	_drag_in_progress = false
	_last_drag_payload = {}
	_clear_pending_drag()
	_interactive_mode = false
	_interactive_request = {}
	_interactive_context = {}
	_interactive_state = {}
	_set_interaction_enabled(false)


func _decorate_result(result: Dictionary, state: Dictionary) -> Dictionary:
	_last_state = state.duplicate(true)
	var map_effects: Dictionary = result.get("map_effects", {}).duplicate(true)
	map_effects["scene_controller"] = name
	map_effects["scene_ticks_simulated"] = int(state.get("elapsed", 0))
	map_effects["rendered_enemy_token_count"] = enemy_tokens.get_child_count()
	map_effects["rendered_log_line_count"] = _log_lines.size()
	map_effects["rendered_arena_token_count"] = _arena_nodes.size()
	map_effects["visual_feedback_counts"] = _feedback_counts.duplicate(true)
	map_effects["motion_feedback_counts"] = _motion_feedback_counts.duplicate(true)
	map_effects["combat_cue_counts"] = _combat_cue_counts.duplicate(true)
	map_effects["timeline_frame_count"] = _timeline.size()
	map_effects["interactive_mode"] = _interactive_mode
	result["map_effects"] = map_effects
	return result


func _render_state(state: Dictionary, headline: String) -> void:
	_ensure_fx_nodes()
	_layout_arena_regions()
	var hero_hp: float = float(state.get("hero_hp", 0.0))
	var combat_focus: Dictionary = _current_combat_focus(state)
	hero_header.text = "当前交战"
	hero_label.text = "%s -> %s\n我方 %.1f   敌方 %.1f" % [
		String(combat_focus.get("actor_name", "")),
		String(combat_focus.get("target_name", "")),
		hero_hp,
		float(state.get("enemy_total_hp", 0.0))
	]
	var actor_side: String = String(combat_focus.get("actor_side", "hero"))
	if actor_side == "hero":
		hero_token.color = Color(0.46, 0.82, 1.0, 1.0) if hero_hp > 0.0 else Color(0.50, 0.24, 0.34, 1.0)
	else:
		hero_token.color = Color(0.34, 0.42, 0.54, 1.0)
	battle_title.text = _battle_display_name(state.get("battle_def", {}))

	var round_index: int = int(state.get("elapsed", 0)) + (0 if not _interactive_mode else 1)
	tick_label.text = "第 %d 回合交锋" % max(1, round_index)
	var mode_text := "可操作战斗" if _interactive_mode else "演示回放"
	battle_summary.text = "[b]%s[/b]\n%s  |  敌方生命 %.1f  |  编组 %d  |  事件 %d" % [
		_battle_display_name(state.get("battle_def", {})),
		mode_text,
		float(state.get("enemy_total_hp", 0.0)),
		state.get("enemy_units", []).size(),
		state.get("events_triggered", []).size()
	]
	if enemy_header != null:
		var alive_enemy_count: int = _alive_enemy_count(state)
		var total_enemy_count: int = state.get("enemy_entities", []).size()
		enemy_header.text = "敌方编组（存活 %d/%d）" % [alive_enemy_count, total_enemy_count]

	_sync_enemy_tokens(state.get("enemy_units", []))
	_sync_arena_tokens(state)
	_render_attack_cues(state)
	var action_brief: String = _format_action_brief(state)
	_log_lines.append("%s | %s | 我方 %.1f | 敌方 %.1f" % [
		headline,
		action_brief,
		hero_hp,
		float(state.get("enemy_total_hp", 0.0))
	])
	if not state.get("events_triggered", []).is_empty():
		_log_lines[_log_lines.size() - 1] += " | 事件=%s" % ",".join(state.get("events_triggered", []))
	while _log_lines.size() > 10:
		_log_lines.remove_at(0)
	event_log.text = "\n".join(_log_lines)
	_update_interaction_hud(state)


func _update_interaction_hud(state: Dictionary) -> void:
	if status_label == null or selected_target_label == null or attack_button == null:
		return
	if not _interactive_mode:
		status_label.text = "这是自动演示层，用来快速预览战斗表现。"
		selected_target_label.text = ""
		attack_button.modulate = Color(0.5, 0.5, 0.5, 1.0)
		attack_button.text = "技能·斩击"
		if defend_button != null:
			defend_button.modulate = Color(0.5, 0.5, 0.5, 1.0)
			defend_button.text = "技能·架盾"
		if burst_button != null:
			burst_button.disabled = true
			burst_button.text = "技能·祷焰横扫"
		if wait_button != null:
			wait_button.disabled = true
			wait_button.text = "结束回合"
		if item_button != null:
			item_button.disabled = true
			item_button.text = "更多道具"
		_refresh_main_item_cards([])
		_update_skill_card({}, attack_skill_card, attack_skill_icon, attack_meta_label, attack_cooldown_tag, attack_resource_tag, attack_cooldown_bar, attack_resource_bar, attack_cooldown_mask, 0, 0)
		_update_skill_card({}, defend_skill_card, defend_skill_icon, defend_meta_label, defend_cooldown_tag, defend_resource_tag, defend_cooldown_bar, defend_resource_bar, defend_cooldown_mask, 0, 0)
		_update_skill_card({}, burst_skill_card, burst_skill_icon, burst_meta_label, burst_cooldown_tag, burst_resource_tag, burst_cooldown_bar, burst_resource_bar, burst_cooldown_mask, 0, 0)
		return

	var phase: String = String(state.get("turn_phase", "player"))
	var selected_name: String = _entity_display_name(state, _selected_target_id)
	var battle_items: Array = state.get("battle_items", [])
	var skill_slots: Array = state.get("skill_slots", [])
	var slash_skill: Dictionary = _skill_slot(skill_slots, "primary")
	var guard_skill: Dictionary = _skill_slot(skill_slots, "guard")
	var burst_skill: Dictionary = _skill_slot(skill_slots, "burst")
	var slash_name: String = String(slash_skill.get("name_cn", "斩击"))
	var guard_name: String = String(guard_skill.get("name_cn", "架盾"))
	var burst_name: String = String(burst_skill.get("name_cn", "祷焰横扫"))
	var hero_resolve: int = int(state.get("hero_resolve", 0))
	var hero_resolve_max: int = int(state.get("hero_resolve_max", 0))
	var can_player_input := phase == "player" and not _resolving_enemy_phase
	var slash_block_reason: String = _skill_unavailable_reason(slash_skill, hero_resolve)
	var guard_block_reason: String = _skill_unavailable_reason(guard_skill, hero_resolve)
	var burst_block_reason: String = _skill_unavailable_reason(burst_skill, hero_resolve)
	var target_hp_text: String = _selected_target_hp_text(state, _selected_target_id)
	var fallback_status := "请选择一个敌人并发动攻击。"
	if not can_player_input:
		fallback_status = "敌方行动中，请等待当前反击结算。"
	status_label.text = String(state.get("status_text", fallback_status))
	if not can_player_input and String(state.get("turn_phase", "player")) != "player":
		status_label.text = "敌方行动中，请等待当前反击结算。"
	elif can_player_input and _selected_target_id.is_empty():
		status_label.text = "%s（先点击战场中的敌方目标）" % String(state.get("status_text", fallback_status))
	selected_target_label.text = "当前目标：%s%s" % [
		selected_name if not selected_name.is_empty() else "未选择",
		target_hp_text
	]
	attack_button.modulate = Color(0.5, 0.5, 0.5, 1.0) if not can_player_input or _selected_target_id.is_empty() or not slash_block_reason.is_empty() else Color.WHITE
	if not can_player_input:
		attack_button.text = "敌方行动中"
	elif _selected_target_id.is_empty():
		attack_button.text = "技能1·%s（先选目标）" % slash_name
	elif not slash_block_reason.is_empty():
		attack_button.text = "技能1·%s（%s）" % [slash_name, slash_block_reason]
	else:
		attack_button.text = "技能1·%s" % slash_name
	if defend_button != null:
		defend_button.modulate = Color(0.5, 0.5, 0.5, 1.0) if not can_player_input or not guard_block_reason.is_empty() else Color.WHITE
		if not can_player_input:
			defend_button.text = "敌方行动中"
		elif not guard_block_reason.is_empty():
			defend_button.text = "技能2·%s（%s）" % [guard_name, guard_block_reason]
		else:
			defend_button.text = "技能2·%s" % guard_name
	if burst_button != null:
		burst_button.disabled = not can_player_input or not burst_block_reason.is_empty()
		burst_button.tooltip_text = "对敌方全体造成压制伤害，适合削弱群体。"
		if not can_player_input:
			burst_button.text = "敌方行动中"
		elif not burst_block_reason.is_empty():
			burst_button.text = "技能3·%s（%s）" % [burst_name, burst_block_reason]
		else:
			burst_button.text = "技能3·%s" % burst_name
	if wait_button != null:
		wait_button.disabled = not can_player_input
		wait_button.text = "结束回合"
		wait_button.tooltip_text = "结束我方回合，恢复灵势并进入敌方回合。"
	if item_button != null:
		if battle_items.is_empty():
			item_button.text = "无可用道具"
			item_button.disabled = true
			item_button.tooltip_text = "当前没有可在战斗中使用的道具。"
		else:
			item_button.text = "更多道具"
			item_button.disabled = not can_player_input
			item_button.tooltip_text = "打开完整道具卡列表。"
	_refresh_main_item_cards(battle_items)
	_update_skill_card(slash_skill, attack_skill_card, attack_skill_icon, attack_meta_label, attack_cooldown_tag, attack_resource_tag, attack_cooldown_bar, attack_resource_bar, attack_cooldown_mask, hero_resolve, hero_resolve_max)
	_update_skill_card(guard_skill, defend_skill_card, defend_skill_icon, defend_meta_label, defend_cooldown_tag, defend_resource_tag, defend_cooldown_bar, defend_resource_bar, defend_cooldown_mask, hero_resolve, hero_resolve_max)
	_update_skill_card(burst_skill, burst_skill_card, burst_skill_icon, burst_meta_label, burst_cooldown_tag, burst_resource_tag, burst_cooldown_bar, burst_resource_bar, burst_cooldown_mask, hero_resolve, hero_resolve_max)
	_refresh_item_popup(battle_items)


func _capture_timeline_state(state: Dictionary, headline: String) -> void:
	_timeline.append({"state": state.duplicate(true), "headline": headline})


func _start_preview_playback() -> void:
	var nonce: int = _playback_nonce
	_log_lines.clear()
	_last_hp_by_entity.clear()
	_last_visual_position_by_entity.clear()
	if _timeline.is_empty():
		return
	call_deferred("_play_timeline_async", nonce)


func _play_timeline_async(nonce: int) -> void:
	await get_tree().process_frame
	for frame_value in _timeline:
		if nonce != _playback_nonce:
			return
		if typeof(frame_value) != TYPE_DICTIONARY:
			continue
		var frame: Dictionary = frame_value
		_render_state(frame.get("state", {}), String(frame.get("headline", "")))
		await get_tree().create_timer(0.42).timeout


func _sync_enemy_tokens(enemy_unit_rows: Array) -> void:
	for child: Node in enemy_tokens.get_children():
		child.queue_free()

	for enemy_row: Dictionary in enemy_unit_rows:
		var label := Label.new()
		label.add_theme_font_size_override("font_size", 18)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.text = "%s x%d" % [
			_enemy_display_name(String(enemy_row.get("unit_id", ""))),
			int(enemy_row.get("count", 0))
		]
		enemy_tokens.add_child(label)


func _sync_arena_tokens(state: Dictionary) -> void:
	var entities: Array = []
	var hero_entity: Dictionary = state.get("hero_entity", {})
	if not hero_entity.is_empty():
		entities.append(hero_entity)
	var enemy_entities: Array = state.get("enemy_entities", [])
	var alive_enemy_entities: Array = []
	for enemy_entity_value in enemy_entities:
		if typeof(enemy_entity_value) != TYPE_DICTIONARY:
			continue
		var enemy_entity: Dictionary = enemy_entity_value
		if bool(enemy_entity.get("is_alive", true)):
			alive_enemy_entities.append(enemy_entity)
	entities.append_array(enemy_entities)

	var enemy_index_by_id: Dictionary = {}
	for idx: int in alive_enemy_entities.size():
		var enemy_entity: Dictionary = alive_enemy_entities[idx]
		var enemy_entity_id: String = String(enemy_entity.get("entity_id", ""))
		if not enemy_entity_id.is_empty():
			enemy_index_by_id[enemy_entity_id] = idx

	var active_ids: Dictionary = {}
	for entity_value: Variant in entities:
		if typeof(entity_value) != TYPE_DICTIONARY:
			continue
		var entity: Dictionary = entity_value
		var entity_id: String = String(entity.get("entity_id", ""))
		if entity_id.is_empty():
			continue
		var is_alive: bool = bool(entity.get("is_alive", true))
		var side: String = String(entity.get("side", "enemy"))
		var current_hp: float = float(entity.get("current_hp", 0.0))
		var previous_hp: float = float(_last_hp_by_entity.get(entity_id, current_hp))
		var just_died: bool = (not is_alive) and previous_hp > 0.0
		if just_died:
			_combat_cue_counts["death_fades"] = int(_combat_cue_counts.get("death_fades", 0)) + 1
			_spawn_death_skull_fx(_death_fx_origin(entity_id, entity), side)
		var should_render: bool = is_alive or side == "hero"
		if not should_render:
			if just_died:
				_feedback_counts["down"] = int(_feedback_counts.get("down", 0)) + 1
			_last_hp_by_entity[entity_id] = current_hp
			continue
		active_ids[entity_id] = true
		var token: Control = _arena_nodes.get(entity_id)
		if token == null:
			token = UNIT_TOKEN_SCENE.instantiate()
			battle_arena.add_child(token)
			_arena_nodes[entity_id] = token
			if token.has_signal("token_pressed"):
				var pressed_callable := Callable(self, "_on_token_pressed")
				if not token.is_connected("token_pressed", pressed_callable):
					token.connect("token_pressed", pressed_callable)
		if token.has_method("set_drop_callbacks"):
			token.call(
				"set_drop_callbacks",
				Callable(self, "_can_drop_payload_on_entity"),
				Callable(self, "_drop_payload_on_entity")
			)
		if token.has_method("configure_token"):
			token.call("configure_token", entity)
		if token.has_method("set_battle_scale"):
			token.call("set_battle_scale", _formation_scale(entity, alive_enemy_entities.size(), battle_arena.size.x))
		var motion: Dictionary = _build_motion_profile(entity, state)
		_apply_token_feedback(token, entity_id, entity)
		var formation_position: Vector2 = _last_visual_position_by_entity.get(entity_id, Vector2.ZERO)
		if is_alive or String(entity.get("side", "")) == "hero":
			formation_position = _formation_position(entity, enemy_index_by_id, alive_enemy_entities.size())
			_last_visual_position_by_entity[entity_id] = formation_position
		token.position = formation_position + Vector2(float(motion.get("offset_x", 0.0)), float(motion.get("offset_y", 0.0)))
		if token.has_method("apply_motion_pose"):
			token.call("apply_motion_pose", motion)
		var highlighted: bool = (_focused_entity_id == entity_id)
		if not highlighted and _selected_target_id == entity_id and String(entity.get("side", "enemy")) == "enemy" and _interactive_mode:
			highlighted = true
		if token.has_method("set_targeted"):
			token.call("set_targeted", highlighted, String(entity.get("side", "enemy")))
		token.modulate.a = 0.38 if not is_alive else 1.0
		token.visible = true

	var stale_ids: Array = _arena_nodes.keys()
	for existing_id: String in stale_ids:
		if active_ids.has(existing_id):
			continue
		var token_to_remove: Node = _arena_nodes[existing_id]
		if token_to_remove != null:
			token_to_remove.queue_free()
		_arena_nodes.erase(existing_id)
		_last_hp_by_entity.erase(existing_id)
		_last_visual_position_by_entity.erase(existing_id)


func _apply_token_feedback(token: Control, entity_id: String, entity: Dictionary) -> void:
	var current_hp: float = float(entity.get("current_hp", 0.0))
	var is_alive: bool = bool(entity.get("is_alive", current_hp > 0.0))
	var previous_hp: float = float(_last_hp_by_entity.get(entity_id, current_hp))
	var just_died: bool = (not is_alive) and previous_hp > 0.0
	var feedback_type: String = ""
	var pulse_amount: float = 0.0
	var pulse_kind: String = "damage"
	if just_died:
		feedback_type = "down"
		_feedback_counts["down"] = int(_feedback_counts.get("down", 0)) + 1
	elif current_hp < previous_hp:
		feedback_type = "hit"
		pulse_amount = previous_hp - current_hp
		_feedback_counts["hit"] = int(_feedback_counts.get("hit", 0)) + 1
	elif current_hp > previous_hp:
		pulse_amount = current_hp - previous_hp
		pulse_kind = "heal"
	if token.has_method("apply_feedback"):
		token.call("apply_feedback", feedback_type)
	if pulse_amount > 0.0 and token.has_method("show_value_pulse"):
		token.call("show_value_pulse", pulse_amount, pulse_kind)
	_last_hp_by_entity[entity_id] = current_hp


func _build_motion_profile(entity: Dictionary, state: Dictionary) -> Dictionary:
	var side: String = String(entity.get("side", "enemy"))
	var is_alive: bool = bool(entity.get("is_alive", true))
	var action: Dictionary = state.get("last_action", {})
	var attack_phase: bool = is_alive and String(action.get("actor_id", "")) == String(entity.get("entity_id", ""))
	var stride: float = 14.0 if side == "hero" else -10.0
	var phase_name: String = String(action.get("phase", ""))
	var defend_phase: bool = is_alive and phase_name == "defend" and String(action.get("actor_id", "")) == String(entity.get("entity_id", ""))
	var offset_x: float = stride if attack_phase else 0.0
	var offset_y: float = -3.0 if attack_phase else 0.0
	if defend_phase:
		offset_x = -4.0 if side == "hero" else 4.0
		offset_y = 2.0
	if is_alive:
		_motion_feedback_counts["animated_entities"] = int(_motion_feedback_counts.get("animated_entities", 0)) + 1
		if attack_phase:
			if side == "hero":
				_motion_feedback_counts["hero_advances"] = int(_motion_feedback_counts.get("hero_advances", 0)) + 1
			else:
				_motion_feedback_counts["enemy_advances"] = int(_motion_feedback_counts.get("enemy_advances", 0)) + 1
	return {
		"side": side,
		"is_alive": is_alive,
		"attack_phase": attack_phase,
		"defend_phase": defend_phase,
		"offset_x": offset_x,
		"offset_y": offset_y,
		"lean": 1.0 if attack_phase else (-0.65 if defend_phase else 0.0),
		"pulse": 1.04 if attack_phase else (1.02 if defend_phase else 1.0)
	}


func _render_attack_cues(state: Dictionary) -> void:
	_ensure_fx_nodes()
	for entity_id: String in _arena_nodes.keys():
		var token: Control = _arena_nodes[entity_id]
		if token != null and token.has_method("set_targeted"):
			var side: String = "hero" if entity_id == "hero_1" else "enemy"
			var keep_selected: bool = (_focused_entity_id == entity_id) or (_interactive_mode and entity_id == _selected_target_id and side == "enemy")
			token.call("set_targeted", keep_selected, side)

	var action: Dictionary = state.get("last_action", {})
	var action_seq: int = int(action.get("seq", -1))
	var action_signature: String = str(action_seq)
	if action_seq < 0:
		action_signature = "%s|%s|%s|%s|%s|%s|%s" % [
			str(action.get("actor_id", "")),
			str(action.get("target_id", "")),
			str(action.get("phase", "")),
			str(action.get("damage", "")),
			str(state.get("elapsed", 0)),
			str(state.get("enemy_turn_index", 0)),
			str(state.get("hero_hp", 0.0)),
		]
	if action_signature == _last_action_signature:
		return
	_last_action_signature = action_signature
	if _attack_line_tween != null:
		_attack_line_tween.kill()
	_attack_line_tween = null
	_hide_attack_line()
	var source_id: String = String(action.get("actor_id", ""))
	var target_id: String = String(action.get("target_id", ""))
	if source_id.is_empty() or target_id.is_empty():
		return
	var phase_name: String = String(action.get("phase", ""))
	if phase_name == "defend":
		if _arena_nodes.has(source_id):
			var defend_token: Control = _arena_nodes[source_id]
			if defend_token != null and defend_token.has_method("play_action_cue"):
				defend_token.call("play_action_cue", "defend", String(action.get("actor_side", "hero")))
		return
	if not ["player", "enemy"].has(phase_name):
		return
	if not _arena_nodes.has(source_id) or not _arena_nodes.has(target_id):
		return
	var source_token: Control = _arena_nodes[source_id]
	var target_token: Control = _arena_nodes[target_id]
	if source_token == null or target_token == null:
		return
	var source_point: Vector2 = source_token.position + (source_token.custom_minimum_size * 0.5)
	var target_point: Vector2 = target_token.position + (target_token.custom_minimum_size * 0.5)
	var line_color := Color(1.0, 0.92, 0.42, 1.0) if String(action.get("actor_side", "hero")) == "hero" else Color(1.0, 0.42, 0.36, 0.96)
	_attack_curve_points = _build_attack_curve_points(source_point, target_point)
	_attack_line.default_color = line_color
	_attack_line.visible = true
	_attack_line.modulate.a = 1.0
	if _attack_arrow != null:
		_attack_arrow.color = Color(1.0, 0.98, 0.92, 1.0)
		_attack_arrow.visible = true
		_attack_arrow.modulate.a = 1.0
	if _attack_arrow_glow != null:
		_attack_arrow_glow.color = Color(line_color.r, line_color.g, line_color.b, 0.42)
		_attack_arrow_glow.visible = true
		_attack_arrow_glow.modulate.a = 1.0
	_set_attack_cue_progress(0.0)
	_combat_cue_counts["attack_lines"] = int(_combat_cue_counts.get("attack_lines", 0)) + 1
	if source_token.has_method("play_action_cue"):
		source_token.call("play_action_cue", "attack", String(action.get("actor_side", "hero")))
	if target_token.has_method("play_action_cue"):
		target_token.call("play_action_cue", "impact", String(action.get("target_side", "enemy")))
	_attack_line_tween = create_tween()
	_attack_line_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_attack_line_tween.tween_method(Callable(self, "_set_attack_cue_progress"), 0.0, 1.0, 0.28)
	_attack_line_tween.tween_interval(0.10)
	_attack_line_tween.parallel().tween_property(_attack_line, "modulate:a", 0.0, 0.48)
	if _attack_arrow != null:
		_attack_line_tween.parallel().tween_property(_attack_arrow, "modulate:a", 0.0, 0.48)
	if _attack_arrow_glow != null:
		_attack_line_tween.parallel().tween_property(_attack_arrow_glow, "modulate:a", 0.0, 0.48)
	_attack_line_tween.tween_callback(_hide_attack_line)
	if source_token.has_method("set_targeted"):
		source_token.call("set_targeted", true, String(action.get("actor_side", "hero")))
	if target_token.has_method("set_targeted"):
		target_token.call("set_targeted", true, String(action.get("target_side", "enemy")))


func _ensure_fx_nodes() -> void:
	if _attack_line != null:
		return
	_attack_line = Line2D.new()
	_attack_line.width = 9.0
	_attack_line.z_index = 20
	_attack_line.antialiased = true
	_attack_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	_attack_line.end_cap_mode = Line2D.LINE_CAP_ROUND
	_attack_line.joint_mode = Line2D.LINE_JOINT_ROUND
	_attack_line.visible = false
	battle_arena.add_child(_attack_line)
	_attack_arrow_glow = Polygon2D.new()
	_attack_arrow_glow.polygon = PackedVector2Array([
		Vector2(12, 0),
		Vector2(-18, 22),
		Vector2(-8, 7),
		Vector2(-58, 0),
		Vector2(-8, -7),
		Vector2(-18, -22)
	])
	_attack_arrow_glow.z_index = 21
	_attack_arrow_glow.visible = false
	battle_arena.add_child(_attack_arrow_glow)
	_attack_arrow = Polygon2D.new()
	_attack_arrow.polygon = PackedVector2Array([
		Vector2(10, 0),
		Vector2(-10, 16),
		Vector2(-2, 5),
		Vector2(-42, 0),
		Vector2(-2, -5),
		Vector2(-10, -16)
	])
	_attack_arrow.z_index = 22
	_attack_arrow.visible = false
	battle_arena.add_child(_attack_arrow)


func _hide_attack_line() -> void:
	if _attack_line != null:
		_attack_line.visible = false
		_attack_line.modulate.a = 1.0
	if _attack_arrow != null:
		_attack_arrow.visible = false
		_attack_arrow.modulate.a = 1.0
		_attack_arrow.scale = Vector2.ONE
	if _attack_arrow_glow != null:
		_attack_arrow_glow.visible = false
		_attack_arrow_glow.modulate.a = 1.0
		_attack_arrow_glow.scale = Vector2.ONE


func _build_attack_curve_points(
	source_point: Vector2,
	target_point: Vector2,
	arc_multiplier: float = 0.16,
	arc_min: float = 30.0,
	arc_max: float = 74.0,
	sample_density: float = 24.0
) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	var direction: Vector2 = target_point - source_point
	var distance: float = direction.length()
	if distance <= 0.001:
		points.append(source_point)
		points.append(target_point)
		return points
	var forward: Vector2 = direction.normalized()
	var normal: Vector2 = Vector2(-forward.y, forward.x)
	if normal.y > 0.0:
		normal *= -1.0
	var arc_height: float = clampf(distance * arc_multiplier, arc_min, arc_max)
	var control: Vector2 = source_point.lerp(target_point, 0.5) + (normal * arc_height)
	var sample_count: int = maxi(14, int(distance / max(6.0, sample_density)))
	for i in range(sample_count + 1):
		var t: float = float(i) / float(sample_count)
		var a: Vector2 = source_point.lerp(control, t)
		var b: Vector2 = control.lerp(target_point, t)
		points.append(a.lerp(b, t))
	return points


func _set_attack_cue_progress(progress: float) -> void:
	if _attack_line == null or _attack_curve_points.size() < 2:
		return
	var clamped: float = clampf(progress, 0.0, 1.0)
	var scaled_progress: float = clamped * float(_attack_curve_points.size() - 1)
	var base_index := int(floor(scaled_progress))
	var next_index: int = mini(base_index + 1, _attack_curve_points.size() - 1)
	var local_t: float = scaled_progress - float(base_index)
	var tip_point: Vector2 = _attack_curve_points[base_index].lerp(_attack_curve_points[next_index], local_t)
	var path: PackedVector2Array = PackedVector2Array()
	for i in range(base_index + 1):
		path.append(_attack_curve_points[i])
	if path.is_empty():
		path.append(_attack_curve_points[0])
	if path[path.size() - 1].distance_to(tip_point) > 0.001:
		path.append(tip_point)
	if path.size() < 2:
		path.append(tip_point)
	_attack_line.points = path
	_attack_line.visible = true
	var tangent: Vector2 = (_attack_curve_points[next_index] - _attack_curve_points[base_index]).normalized()
	if tangent == Vector2.ZERO and path.size() >= 2:
		tangent = (path[path.size() - 1] - path[path.size() - 2]).normalized()
	if tangent == Vector2.ZERO:
		tangent = Vector2.RIGHT
	if _attack_arrow_glow != null:
		_attack_arrow_glow.position = tip_point
		_attack_arrow_glow.rotation = tangent.angle()
		_attack_arrow_glow.visible = true
	if _attack_arrow != null:
		_attack_arrow.position = tip_point
		_attack_arrow.rotation = tangent.angle()
		_attack_arrow.visible = true


func _death_fx_origin(entity_id: String, entity: Dictionary) -> Vector2:
	var token: Control = _arena_nodes.get(entity_id)
	if token != null:
		var token_size: Vector2 = token.size
		if token_size.x <= 1.0 or token_size.y <= 1.0:
			token_size = token.custom_minimum_size
		return token.position + (token_size * 0.5)
	if _last_visual_position_by_entity.has(entity_id):
		return Vector2(_last_visual_position_by_entity[entity_id]) + Vector2(92.0, 82.0)
	var fallback_pos: Array = entity.get("position", [battle_arena.size.x * 0.7, battle_arena.size.y * 0.48])
	var px: float = float(fallback_pos[0]) if fallback_pos.size() > 0 else battle_arena.size.x * 0.7
	var py: float = float(fallback_pos[1]) if fallback_pos.size() > 1 else battle_arena.size.y * 0.48
	return Vector2(px, py)


func _spawn_death_skull_fx(origin: Vector2, side: String) -> void:
	if battle_arena == null:
		return
	var skull := _build_death_skull_node(side)
	skull.position = origin
	skull.z_index = 120
	battle_arena.add_child(skull)
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(skull, "position:y", origin.y - 52.0, 0.62)
	tween.parallel().tween_property(skull, "scale", Vector2(1.26, 1.26), 0.38)
	tween.parallel().tween_property(skull, "modulate:a", 0.0, 0.62)
	tween.tween_callback(skull.queue_free)


func _build_death_skull_node(side: String) -> Node2D:
	var root := Node2D.new()
	root.scale = Vector2(0.9, 0.9)
	var skull_color: Color = Color(1.0, 0.94, 0.84, 0.98)
	if side == "hero":
		skull_color = Color(0.82, 0.90, 1.0, 0.98)
	var head := Polygon2D.new()
	head.color = skull_color
	head.polygon = PackedVector2Array([
		Vector2(-16, -18),
		Vector2(16, -18),
		Vector2(20, -12),
		Vector2(20, 8),
		Vector2(14, 14),
		Vector2(-14, 14),
		Vector2(-20, 8),
		Vector2(-20, -12),
	])
	root.add_child(head)
	var jaw := Polygon2D.new()
	jaw.color = skull_color.darkened(0.04)
	jaw.polygon = PackedVector2Array([
		Vector2(-10, 14),
		Vector2(10, 14),
		Vector2(10, 24),
		Vector2(4, 28),
		Vector2(-4, 28),
		Vector2(-10, 24),
	])
	root.add_child(jaw)
	var left_eye := Polygon2D.new()
	left_eye.color = Color(0.08, 0.08, 0.10, 0.94)
	left_eye.polygon = PackedVector2Array([
		Vector2(-12, -4),
		Vector2(-4, -4),
		Vector2(-6, 4),
		Vector2(-10, 4),
	])
	root.add_child(left_eye)
	var right_eye := Polygon2D.new()
	right_eye.color = Color(0.08, 0.08, 0.10, 0.94)
	right_eye.polygon = PackedVector2Array([
		Vector2(4, -4),
		Vector2(12, -4),
		Vector2(10, 4),
		Vector2(6, 4),
	])
	root.add_child(right_eye)
	var nose := Polygon2D.new()
	nose.color = Color(0.12, 0.12, 0.14, 0.9)
	nose.polygon = PackedVector2Array([
		Vector2(0, 2),
		Vector2(-3, 8),
		Vector2(3, 8),
	])
	root.add_child(nose)
	return root


func _formation_position(entity: Dictionary, enemy_index_by_id: Dictionary, enemy_count: int) -> Vector2:
	var arena_size: Vector2 = battle_arena.size
	if arena_size.x < 400.0:
		arena_size.x = battle_arena.custom_minimum_size.x
	if arena_size.y < 240.0:
		arena_size.y = battle_arena.custom_minimum_size.y
	if arena_size.x < 400.0:
		arena_size.x = 860.0
	if arena_size.y < 240.0:
		arena_size.y = 520.0

	var side: String = String(entity.get("side", "enemy"))
	var row_y: float = (arena_size.y * 0.5) - 138.0
	var hero_lane_width: float = _hero_lane_width(arena_size.x)
	var gap_band_width: float = _gap_band_width(arena_size.x)
	var hero_scale: float = _formation_scale(entity, enemy_count, arena_size.x)
	var hero_token_width: float = ARENA_TOKEN_BASE_WIDTH * hero_scale
	var hero_x: float = 24.0 + max(10.0, (hero_lane_width - hero_token_width) * 0.5)
	var center_line_x: float = hero_lane_width + (gap_band_width * 0.5)
	var hero_max_x: float = center_line_x - hero_token_width - 42.0
	hero_x = clamp(hero_x, 12.0, max(12.0, hero_max_x))
	if side == "hero":
		return Vector2(hero_x, row_y)

	var entity_id: String = String(entity.get("entity_id", ""))
	var enemy_index: int = int(enemy_index_by_id.get(entity_id, 0))
	var enemy_scale: float = _formation_scale(entity, enemy_count, arena_size.x)
	var token_width: float = ARENA_TOKEN_BASE_WIDTH * enemy_scale
	var base_gap: float = clamp(arena_size.x * 0.018, 10.0, 28.0)
	var available_start_x: float = 24.0 + hero_lane_width + gap_band_width
	var available_width: float = max(120.0, arena_size.x - available_start_x - 24.0)
	var total_width: float = (float(enemy_count) * token_width) + (float(max(0, enemy_count - 1)) * base_gap)
	var gap: float = base_gap
	if enemy_count > 1 and total_width > available_width:
		gap = max(6.0, (available_width - (float(enemy_count) * token_width)) / float(enemy_count - 1))
		total_width = (float(enemy_count) * token_width) + (float(enemy_count - 1) * gap)
	var start_x: float = available_start_x + max(0.0, (available_width - total_width) * 0.5)
	start_x = clamp(start_x, available_start_x, max(available_start_x, arena_size.x - total_width - 18.0))
	return Vector2(start_x + (float(enemy_index) * (token_width + gap)), row_y + ((1.0 - enemy_scale) * 44.0))


func _formation_scale(entity: Dictionary, enemy_count: int, arena_width: float) -> float:
	if String(entity.get("side", "enemy")) == "hero":
		var desired_hero_scale := 1.34
		var center_line_x: float = _hero_lane_width(arena_width) + (_gap_band_width(arena_width) * 0.5)
		var hero_max_width: float = max(ARENA_TOKEN_BASE_WIDTH * 1.02, center_line_x - 12.0 - 42.0)
		var max_hero_scale: float = hero_max_width / ARENA_TOKEN_BASE_WIDTH
		return clamp(min(desired_hero_scale, max_hero_scale), 1.02, 1.34)
	var base_scale := 1.18
	match enemy_count:
		0, 1:
			base_scale = 1.30
		2:
			base_scale = 1.20
		3:
			base_scale = 1.10
		4:
			base_scale = 1.02
		_:
			base_scale = 0.96
	var gap_band_width: float = _gap_band_width(arena_width)
	var hero_lane_width: float = _hero_lane_width(arena_width)
	var available_width: float = max(120.0, arena_width - hero_lane_width - gap_band_width - 48.0)
	var preferred_gap: float = clamp(arena_width * 0.018, 10.0, 28.0)
	var total_gap: float = float(max(0, enemy_count - 1)) * preferred_gap
	var max_scale_for_width: float = (available_width - total_gap) / max(ARENA_TOKEN_BASE_WIDTH, float(enemy_count) * ARENA_TOKEN_BASE_WIDTH)
	return clamp(min(base_scale, max_scale_for_width), 0.92, 1.42)


func _layout_arena_regions() -> void:
	var arena_size: Vector2 = battle_arena.size
	if arena_size.x < 400.0:
		arena_size.x = max(860.0, battle_arena.custom_minimum_size.x)
	if arena_size.y < 240.0:
		arena_size.y = max(520.0, battle_arena.custom_minimum_size.y)
	var top: float = 0.0
	var bottom: float = arena_size.y
	var left_margin: float = 0.0
	var right_margin: float = 0.0
	var hero_lane_width: float = _hero_lane_width(arena_size.x)
	var gap_band_width: float = _gap_band_width(arena_size.x)
	var enemy_lane_start: float = left_margin + hero_lane_width + gap_band_width
	if hero_lane != null:
		hero_lane.position = Vector2(left_margin, top)
		hero_lane.size = Vector2(hero_lane_width, bottom - top)
	if mid_gap != null:
		mid_gap.position = Vector2(left_margin + hero_lane_width, top)
		mid_gap.size = Vector2(gap_band_width, bottom - top)
	if enemy_lane != null:
		enemy_lane.position = Vector2(enemy_lane_start, top)
		enemy_lane.size = Vector2(max(120.0, arena_size.x - enemy_lane_start - right_margin), bottom - top)
	if center_line != null:
		var line_x: float = left_margin + hero_lane_width + (gap_band_width * 0.5)
		center_line.position = Vector2(line_x, top)
		center_line.size = Vector2(2.0, bottom - top)


func _hero_lane_width(arena_width: float) -> float:
	return clamp(arena_width * 0.36, 300.0, 440.0)


func _gap_band_width(arena_width: float) -> float:
	return clamp(arena_width * 0.075, 56.0, 96.0)


func _current_combat_focus(state: Dictionary) -> Dictionary:
	var action: Dictionary = state.get("last_action", {})
	if not action.is_empty():
		return {
			"actor_name": String(action.get("actor_name", "")),
			"target_name": String(action.get("target_name", "")),
			"actor_side": String(action.get("actor_side", "hero"))
		}
	var hero_name: String = String(state.get("hero_unit", {}).get("name_cn", state.get("hero_unit", {}).get("id", "")))
	var target_name: String = _entity_display_name(state, _selected_target_id)
	if target_name.is_empty():
		target_name = "无目标"
	return {
		"actor_name": hero_name,
		"target_name": target_name,
		"actor_side": "hero"
	}


func _entity_display_name(state: Dictionary, entity_id: String) -> String:
	if entity_id == "hero_1":
		return String(state.get("hero_entity", {}).get("display_name", "Hero"))
	for enemy_entity_value in state.get("enemy_entities", []):
		if typeof(enemy_entity_value) != TYPE_DICTIONARY:
			continue
		var enemy_entity: Dictionary = enemy_entity_value
		if String(enemy_entity.get("entity_id", "")) == entity_id:
			return String(enemy_entity.get("display_name", entity_id))
	return ""


func _selected_target_hp_text(state: Dictionary, entity_id: String) -> String:
	if entity_id.is_empty():
		return ""
	for enemy_entity_value in state.get("enemy_entities", []):
		if typeof(enemy_entity_value) != TYPE_DICTIONARY:
			continue
		var enemy_entity: Dictionary = enemy_entity_value
		if String(enemy_entity.get("entity_id", "")) != entity_id:
			continue
		var hp: float = float(enemy_entity.get("current_hp", 0.0))
		var max_hp: float = float(enemy_entity.get("max_hp", 0.0))
		return "（HP %.1f/%.1f）" % [hp, max_hp]
	return ""


func _alive_enemy_count(state: Dictionary) -> int:
	var alive := 0
	for enemy_entity_value in state.get("enemy_entities", []):
		if typeof(enemy_entity_value) != TYPE_DICTIONARY:
			continue
		var enemy_entity: Dictionary = enemy_entity_value
		if bool(enemy_entity.get("is_alive", true)):
			alive += 1
	return alive


func _format_action_brief(state: Dictionary) -> String:
	var action: Dictionary = state.get("last_action", {})
	if action.is_empty():
		return "等待行动"
	var phase_name: String = String(action.get("phase", ""))
	var actor_name: String = String(action.get("actor_name", "未命名单位"))
	var target_name: String = String(action.get("target_name", "未命名目标"))
	var damage: float = float(action.get("damage", 0.0))
	match phase_name:
		"player":
			return "%s 对 %s 造成 %.1f 伤害" % [actor_name, target_name, max(0.0, damage)]
		"burst":
			return "%s 以祷焰横扫压制敌方全体（%.1f）" % [actor_name, max(0.0, damage)]
		"enemy":
			return "%s 对 %s 造成 %.1f 伤害" % [actor_name, target_name, max(0.0, damage)]
		"defend":
			return "%s 进入防御姿态" % actor_name
		"wait":
			return "%s 蓄势待机" % actor_name
		"item":
			return "%s 使用 %s" % [actor_name, target_name]
		_:
			return "%s -> %s" % [actor_name, target_name]


func _enemy_display_name(unit_id: String) -> String:
	var content_db := get_node_or_null("/root/ContentDB")
	if content_db == null:
		return unit_id
	var unit_def: Dictionary = content_db.get_unit(unit_id)
	if unit_def.is_empty():
		return unit_id
	return String(unit_def.get("name_cn", unit_id))


func _battle_display_name(battle_def: Dictionary) -> String:
	var battle_id: String = String(battle_def.get("id", ""))
	match battle_id:
		"battle_a01_patrol":
			return "灰烬前哨巡逻战"
		"battle_a01_bridgehold":
			return "断桥据守战"
		"battle_a02_patrol":
			return "灰烬圣坛巡逻战"
		"battle_a02_husk_chapel":
			return "枯壳礼拜堂遭遇战"
		"battle_a02_forced_ambush":
			return "灰烬圣坛伏击战"
		"battle_a02_mainline_sanctum":
			return "圣所主线攻坚战"
		"battle_a02_extraction_breakthrough":
			return "撤离突破战"
		_:
			var map_id: String = String(battle_def.get("map_id", ""))
			if not map_id.is_empty():
				var content_db := get_node_or_null("/root/ContentDB")
				if content_db != null and content_db.has_method("get_map"):
					var map_def: Dictionary = content_db.get_map(map_id)
					var map_name_cn: String = String(map_def.get("name_cn", ""))
					if not map_name_cn.is_empty():
						return "%s 作战" % map_name_cn
			if battle_id.is_empty():
				return "战斗预览"
			return "战斗预览 %s" % battle_id


func _set_interaction_enabled(enabled: bool) -> void:
	if status_label != null:
		status_label.visible = enabled
	if selected_target_label != null:
		selected_target_label.visible = enabled
	if attack_button != null:
		attack_button.visible = enabled
	if defend_button != null:
		defend_button.visible = enabled
	if burst_button != null:
		burst_button.visible = enabled
		burst_button.disabled = not enabled
	if wait_button != null:
		wait_button.visible = enabled
		wait_button.disabled = not enabled
	if item_button != null:
		item_button.visible = enabled
		item_button.disabled = not enabled
	if item_popup_panel != null and not enabled:
		item_popup_panel.hide()


func _on_token_pressed(entity_id: String) -> void:
	_focused_entity_id = entity_id
	_refresh_token_focus_visuals()
	if not _interactive_mode or _resolving_enemy_phase:
		return
	if String(_interactive_state.get("turn_phase", "player")) != "player":
		return
	for enemy_entity_value in _interactive_state.get("enemy_entities", []):
		if typeof(enemy_entity_value) != TYPE_DICTIONARY:
			continue
		var enemy_entity: Dictionary = enemy_entity_value
		if String(enemy_entity.get("entity_id", "")) != entity_id:
			continue
		if not bool(enemy_entity.get("is_alive", true)):
			return
		_selected_target_id = entity_id
		var target_name: String = String(enemy_entity.get("display_name", entity_id))
		_render_state(_interactive_state, "已锁定目标：%s" % target_name)
		_refresh_token_focus_visuals()
		return


func _refresh_token_focus_visuals() -> void:
	for entity_id: String in _arena_nodes.keys():
		var token: Control = _arena_nodes[entity_id]
		if token == null or not token.has_method("set_targeted"):
			continue
		var side: String = "hero" if entity_id == "hero_1" else "enemy"
		var highlighted := (_focused_entity_id == entity_id)
		if not highlighted and _interactive_mode and side == "enemy" and _selected_target_id == entity_id:
			highlighted = true
		token.call("set_targeted", highlighted, side)


func _on_attack_pressed() -> void:
	if not _interactive_mode or _resolving_enemy_phase:
		return
	if _selected_target_id.is_empty():
		if status_label != null:
			status_label.text = "请先点击战场中的敌人，再发动攻击。"
		return
	_interactive_state = _sim().apply_player_attack(_interactive_state, _selected_target_id)
	_render_state(_interactive_state, "我方发动攻击")
	if not _sim().is_battle_active(_interactive_state):
		_finish_interactive_battle(_decorate_result(_sim().build_result(_interactive_state, _interactive_context, "scene"), _interactive_state))
		return
	if String(_interactive_state.get("turn_phase", "player")) != "enemy":
		_update_interaction_hud(_interactive_state)
		return
	_resolving_enemy_phase = true
	_update_interaction_hud(_interactive_state)
	call_deferred("_resolve_enemy_phase_async")


func _on_defend_pressed() -> void:
	if not _interactive_mode or _resolving_enemy_phase:
		return
	_interactive_state = _sim().apply_player_defend(_interactive_state)
	_render_state(_interactive_state, "我方进入防御")
	_queue_enemy_phase_or_finish()


func _on_burst_pressed() -> void:
	if not _interactive_mode or _resolving_enemy_phase:
		return
	_interactive_state = _sim().apply_player_burst(_interactive_state)
	_render_state(_interactive_state, "我方发动祷焰横扫")
	_queue_enemy_phase_or_finish()


func _on_wait_pressed() -> void:
	if not _interactive_mode or _resolving_enemy_phase:
		return
	_interactive_state = _sim().apply_player_wait(_interactive_state)
	_render_state(_interactive_state, "我方结束回合")
	_queue_enemy_phase_or_finish()


func _on_item_pressed() -> void:
	if not _interactive_mode or _resolving_enemy_phase:
		return
	var battle_items: Array = _interactive_state.get("battle_items", [])
	if battle_items.is_empty():
		if status_label != null:
			status_label.text = "当前没有可在战斗中使用的道具。"
		return
	if item_popup_panel != null:
		var popup_target := Vector2(item_button.global_position.x - 236.0, item_button.global_position.y - 12.0)
		var viewport_rect := get_viewport().get_visible_rect()
		var popup_width := _current_action_card_width + 72.0
		var popup_height: float = float(clamp((float(battle_items.size()) * 128.0) + 88.0, 180.0, 640.0))
		popup_target.x = clamp(popup_target.x, 10.0, max(10.0, viewport_rect.size.x - popup_width - 10.0))
		popup_target.y = clamp(popup_target.y, 10.0, max(10.0, viewport_rect.size.y - popup_height - 10.0))
		item_popup_panel.position = Vector2i(int(popup_target.x), int(popup_target.y))
		item_popup_panel.popup()


func _resolve_enemy_phase_async() -> void:
	while _interactive_mode and String(_interactive_state.get("turn_phase", "")) == "enemy":
		await get_tree().create_timer(0.62).timeout
		if not _interactive_mode:
			return
		_interactive_state = _sim().apply_enemy_phase(_interactive_state)
		_selected_target_id = String(_interactive_state.get("selected_target_id", _selected_target_id))
		var action: Dictionary = _interactive_state.get("last_action", {})
		var headline := "敌方完成行动"
		if String(action.get("phase", "")) == "enemy":
			headline = "%s 发动反击" % String(action.get("actor_name", "敌方"))
		_render_state(_interactive_state, headline)
		if not _sim().is_battle_active(_interactive_state):
			_resolving_enemy_phase = false
			_finish_interactive_battle(_decorate_result(_sim().build_result(_interactive_state, _interactive_context, "scene"), _interactive_state))
			return
	_resolving_enemy_phase = false
	_clear_pending_drag()
	_drag_in_progress = false
	_drag_source_position = Vector2.ZERO
	_refresh_drag_bindings()
	_update_interaction_hud(_interactive_state)


func _refresh_drag_bindings() -> void:
	# Only reset mouse filters, don't rebind signals to avoid connection issues
	if attack_skill_card != null:
		attack_skill_card.mouse_filter = Control.MOUSE_FILTER_STOP
		_set_descendants_mouse_filter(attack_skill_card)
	if defend_skill_card != null:
		defend_skill_card.mouse_filter = Control.MOUSE_FILTER_STOP
		_set_descendants_mouse_filter(defend_skill_card)
	if burst_skill_card != null:
		burst_skill_card.mouse_filter = Control.MOUSE_FILTER_STOP
		_set_descendants_mouse_filter(burst_skill_card)
	if item_card_a != null:
		item_card_a.mouse_filter = Control.MOUSE_FILTER_STOP
		_configure_main_item_card_drag_surface(item_card_a, item_card_a_use_button)
	if item_card_b != null:
		item_card_b.mouse_filter = Control.MOUSE_FILTER_STOP
		_configure_main_item_card_drag_surface(item_card_b, item_card_b_use_button)


func _finish_interactive_battle(result: Dictionary) -> void:
	_set_interaction_enabled(false)
	_interactive_mode = false
	_focused_entity_id = ""
	_resolving_enemy_phase = false
	emit_signal("interactive_battle_finished", result)


func _queue_enemy_phase_or_finish() -> void:
	if not _sim().is_battle_active(_interactive_state):
		_finish_interactive_battle(_decorate_result(_sim().build_result(_interactive_state, _interactive_context, "scene"), _interactive_state))
		return
	if String(_interactive_state.get("turn_phase", "player")) != "enemy":
		_update_interaction_hud(_interactive_state)
		return
	_resolving_enemy_phase = true
	_selected_target_id = ""
	_focused_entity_id = ""
	_update_interaction_hud(_interactive_state)
	call_deferred("_resolve_enemy_phase_async")


func _on_battle_arena_resized() -> void:
	_layout_arena_regions()
	_refresh_arena_entities()
	_layout_action_bar()


func _refresh_layout_after_frame() -> void:
	await get_tree().process_frame
	_layout_arena_regions()
	_refresh_arena_entities()
	_layout_action_bar()


func _refresh_arena_entities() -> void:
	var current_state: Dictionary = {}
	if _interactive_mode and not _interactive_state.is_empty():
		current_state = _interactive_state
	elif not _last_state.is_empty():
		current_state = _last_state
	if current_state.is_empty():
		return
	_sync_arena_tokens(current_state)
	_render_attack_cues(current_state)
	_update_interaction_hud(current_state)


func _first_battle_item_id(state: Dictionary) -> String:
	for stack_value in state.get("battle_items", []):
		if typeof(stack_value) != TYPE_DICTIONARY:
			continue
		var stack: Dictionary = stack_value
		if int(stack.get("count", 0)) <= 0:
			continue
		return String(stack.get("id", ""))
	return ""


func _refresh_item_popup(battle_items: Array) -> void:
	if item_list_vbox == null:
		return
	for child: Node in item_list_vbox.get_children():
		child.queue_free()
	var ranked_items: Array = _ranked_battle_items(battle_items)
	if ranked_items.is_empty():
		var empty_label := Label.new()
		empty_label.text = "当前没有可用战斗道具。"
		item_list_vbox.add_child(empty_label)
		return
	for stack_value in ranked_items:
		if typeof(stack_value) != TYPE_DICTIONARY:
			continue
		var stack: Dictionary = stack_value
		item_list_vbox.add_child(_build_item_popup_card(stack))


func _refresh_main_item_cards(battle_items: Array) -> void:
	var ranked_items: Array = _ranked_battle_items(battle_items)
	var item_count: int = ranked_items.size()
	var visible_slot_count: int = clampi(item_count, 1, MAIN_ITEM_CARD_LIMIT)
	for slot_index in range(MAIN_ITEM_CARD_LIMIT):
		var should_show_slot: bool = slot_index < visible_slot_count
		var has_item: bool = slot_index < item_count and typeof(ranked_items[slot_index]) == TYPE_DICTIONARY
		var stack: Dictionary = ranked_items[slot_index] if has_item else {}
		var item_id: String = String(stack.get("id", "")) if has_item else ""
		_item_card_item_ids[slot_index] = item_id
		var card: PanelContainer = _item_card_panel(slot_index)
		if card != null:
			card.visible = should_show_slot
		if not should_show_slot:
			_set_main_item_card_interactive(slot_index, false)
			continue
		_update_main_item_card(slot_index, stack)
		_set_main_item_card_interactive(slot_index, has_item and _can_accept_drag_drop_input())
	_apply_dynamic_action_card_width()


func _update_main_item_card(slot_index: int, stack: Dictionary) -> void:
	var card: PanelContainer = _item_card_panel(slot_index)
	var icon: TextureRect = _item_card_icon(slot_index)
	var title: Label = _item_card_title(slot_index)
	var desc: Label = _item_card_desc(slot_index)
	var meta: Label = _item_card_meta(slot_index)
	var use_button: Button = _item_card_use_button(slot_index)
	if card == null or icon == null or title == null or desc == null or meta == null or use_button == null:
		return
	var has_item := not stack.is_empty()
	card.visible = true
	card.modulate = Color.WHITE if has_item else Color(0.74, 0.74, 0.78, 0.72)
	icon.texture = _load_item_icon(String(stack.get("icon_path", ""))) if has_item else DEFAULT_SKILL_ICON
	icon.modulate = Color(0.70, 0.92, 0.66, 1.0) if has_item else Color(0.52, 0.52, 0.56, 0.94)
	if has_item:
		var item_name: String = String(stack.get("name_cn", stack.get("id", "道具")))
		var item_desc: String = String(stack.get("description", ""))
		var target_text: String = String(stack.get("target_type", "目标：即时生效"))
		var effect_text: String = _item_effect_summary(stack.get("effect", {}))
		title.text = item_name
		title.tooltip_text = item_name
		desc.text = item_desc
		desc.tooltip_text = item_desc
		desc.clip_text = true
		desc.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		meta.text = "数量 x%d | %s | %s" % [int(stack.get("count", 0)), target_text, effect_text]
		meta.tooltip_text = meta.text
		meta.clip_text = true
		meta.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		use_button.disabled = not _can_accept_drag_drop_input()
		use_button.text = "使用"
		use_button.visible = true
	else:
		title.text = "暂无道具"
		title.tooltip_text = "暂无道具"
		desc.text = "继续推进事件可获取新道具。"
		desc.tooltip_text = desc.text
		desc.clip_text = true
		desc.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		meta.text = "数量 x0 | 目标 - | 效果 -"
		meta.tooltip_text = meta.text
		meta.clip_text = true
		meta.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		use_button.disabled = true
		use_button.text = "空槽"
		use_button.visible = true


func _use_item_and_continue(item_id: String) -> void:
	if item_id.is_empty():
		return
	_mark_item_recent(item_id)
	if item_popup_panel != null:
		item_popup_panel.hide()
	_interactive_state = _sim().apply_player_item(_interactive_state, item_id)
	_render_state(_interactive_state, "我方使用道具")
	_queue_enemy_phase_or_finish()


func _skill_slot_name(skill_slots: Array, slot_id: String, fallback_name: String) -> String:
	for skill_value in skill_slots:
		if typeof(skill_value) != TYPE_DICTIONARY:
			continue
		var skill: Dictionary = skill_value
		if String(skill.get("slot", "")) == slot_id:
			return String(skill.get("name_cn", fallback_name))
	return fallback_name


func _skill_slot(skill_slots: Array, slot_id: String) -> Dictionary:
	for skill_value in skill_slots:
		if typeof(skill_value) != TYPE_DICTIONARY:
			continue
		var skill: Dictionary = skill_value
		if String(skill.get("slot", "")) == slot_id:
			return skill
	return {}


func _skill_is_ready(skill: Dictionary, hero_resolve: int) -> bool:
	if skill.is_empty():
		return false
	return int(skill.get("cooldown_remaining", 0)) <= 0 and hero_resolve >= int(skill.get("resource_cost", 0))


func _skill_unavailable_reason(skill: Dictionary, hero_resolve: int) -> String:
	if skill.is_empty():
		return "未配置"
	var cooldown_remaining: int = int(skill.get("cooldown_remaining", 0))
	if cooldown_remaining > 0:
		return "冷却中"
	if hero_resolve < int(skill.get("resource_cost", 0)):
		return "灵势不足"
	return ""


func _update_skill_card(
	skill: Dictionary,
	card: Control,
	icon_node: TextureRect,
	meta_label: Label,
	cooldown_tag: Label,
	resource_tag: Label,
	cooldown_bar: ProgressBar,
	resource_bar: ProgressBar,
	cooldown_mask: ColorRect,
	hero_resolve: int,
	hero_resolve_max: int
) -> void:
	if meta_label == null or cooldown_tag == null or resource_tag == null or cooldown_bar == null or resource_bar == null:
		return
	meta_label.clip_text = true
	meta_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	cooldown_tag.clip_text = true
	cooldown_tag.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	resource_tag.clip_text = true
	resource_tag.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	if skill.is_empty():
		meta_label.text = "技能未配置"
		meta_label.tooltip_text = "技能未配置"
		cooldown_tag.text = "CD -/-"
		cooldown_tag.tooltip_text = cooldown_tag.text
		resource_tag.text = "消耗 - | 不可用"
		resource_tag.tooltip_text = resource_tag.text
		meta_label.modulate = Color(0.68, 0.70, 0.76, 1.0)
		cooldown_tag.modulate = Color(0.68, 0.70, 0.76, 1.0)
		resource_tag.modulate = Color(0.68, 0.70, 0.76, 1.0)
		if card != null:
			card.modulate = Color(0.82, 0.82, 0.86, 0.92)
		if icon_node != null:
			icon_node.texture = DEFAULT_SKILL_ICON
			icon_node.modulate = Color(0.72, 0.72, 0.72, 1.0)
		if cooldown_mask != null:
			cooldown_mask.color = Color(0.05, 0.07, 0.11, 0.0)
		cooldown_bar.max_value = 1
		cooldown_bar.value = 0
		resource_bar.max_value = 1
		resource_bar.value = 0
		return
	var cooldown_max: int = max(1, int(skill.get("cooldown_max", 1)))
	var cooldown_remaining: int = int(skill.get("cooldown_remaining", 0))
	var resource_cost: int = max(1, int(skill.get("resource_cost", 1)))
	var skill_ready: bool = cooldown_remaining <= 0
	var enough_resource: bool = hero_resolve >= resource_cost
	var available_now: bool = skill_ready and enough_resource and _can_accept_drag_drop_input()
	var description: String = String(skill.get("description", "")).replace("\n", " ")
	if description.is_empty():
		description = "暂无技能说明。"
	meta_label.text = description
	meta_label.tooltip_text = "%s\nCD %d/%d | 消耗 %d | 可用 %s" % [
		description,
		cooldown_remaining,
		cooldown_max,
		resource_cost,
		"是" if available_now else "否"
	]
	cooldown_tag.text = "CD %d/%d" % [cooldown_remaining, cooldown_max]
	cooldown_tag.tooltip_text = cooldown_tag.text
	resource_tag.text = "消耗 %d | %s" % [resource_cost, "可用" if available_now else "不可用"]
	resource_tag.tooltip_text = resource_tag.text
	meta_label.modulate = Color(0.86, 0.88, 0.94, 1.0)
	cooldown_tag.modulate = Color(0.62, 0.78, 1.0, 1.0) if skill_ready else Color(0.84, 0.62, 0.56, 1.0)
	resource_tag.modulate = Color(0.88, 0.95, 0.70, 1.0) if available_now else Color(1.0, 0.62, 0.62, 1.0)
	cooldown_bar.max_value = cooldown_max
	cooldown_bar.value = max(0, cooldown_max - cooldown_remaining)
	resource_bar.max_value = max(max(resource_cost, hero_resolve_max), 1)
	resource_bar.value = hero_resolve
	cooldown_bar.modulate = Color(0.62, 0.78, 1.0, 1.0)
	resource_bar.modulate = Color(0.96, 0.74, 0.34, 1.0) if enough_resource else Color(1.0, 0.42, 0.42, 1.0)
	if icon_node != null:
		icon_node.texture = _skill_icon_texture(String(skill.get("slot", "")))
		icon_node.modulate = Color.WHITE
	if cooldown_mask != null:
		cooldown_mask.color = Color(0.05, 0.07, 0.11, 0.42) if cooldown_remaining > 0 else Color(0.05, 0.07, 0.11, 0.0)
	if card != null:
		card.modulate = Color(1.0, 0.78, 0.78, 1.0) if not available_now else Color(1, 1, 1, 1)


func _build_item_popup_card(stack: Dictionary) -> Control:
	var card := PanelContainer.new()
	card.custom_minimum_size = _current_action_card_size()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	_apply_action_card_chrome(card, Color(0.56, 0.86, 0.48, 0.98), 212 + int(hash(String(stack.get("id", ""))) % 81))

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 8)
	card.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	margin.add_child(vbox)

	var head_row := HBoxContainer.new()
	head_row.add_theme_constant_override("separation", 8)
	vbox.add_child(head_row)

	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(24, 24)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = _load_item_icon(String(stack.get("icon_path", "")))
	icon.modulate = Color(0.70, 0.92, 0.66, 1.0)
	head_row.add_child(icon)

	var title := Label.new()
	title.custom_minimum_size = Vector2(0, 32)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 16)
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var item_name: String = String(stack.get("name_cn", stack.get("id", "道具")))
	title.text = item_name
	title.tooltip_text = item_name
	title.clip_text = true
	head_row.add_child(title)

	var desc := Label.new()
	var item_desc: String = String(stack.get("description", ""))
	desc.text = item_desc
	desc.tooltip_text = item_desc
	desc.add_theme_font_size_override("font_size", 12)
	desc.modulate = Color(0.86, 0.88, 0.94, 0.96)
	desc.clip_text = true
	desc.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	vbox.add_child(desc)

	var meta_row := HBoxContainer.new()
	meta_row.add_theme_constant_override("separation", 6)
	vbox.add_child(meta_row)

	var meta := Label.new()
	meta.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	meta.add_theme_font_size_override("font_size", 11)
	meta.text = "数量 x%d | %s | %s" % [
		int(stack.get("count", 0)),
		String(stack.get("target_type", "目标：即时生效")),
		_item_effect_summary(stack.get("effect", {}))
	]
	meta.tooltip_text = meta.text
	meta.clip_text = true
	meta.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	meta_row.add_child(meta)

	var use_button := Button.new()
	use_button.custom_minimum_size = Vector2(56, 28)
	use_button.text = "使用"
	use_button.disabled = not _can_accept_drag_drop_input()
	use_button.pressed.connect(func() -> void:
		_use_item_and_continue(String(stack.get("id", "")))
	)
	meta_row.add_child(use_button)

	_set_descendants_mouse_filter_except(card, [use_button])
	_bind_drag_source(card, Callable(self, "_item_drag_payload").bind(String(stack.get("id", ""))), Callable(), false)
	return card


func _build_action_deck() -> void:
	if action_bar == null or root_vbox == null or _action_deck_panel != null:
		return
	var old_index: int = action_bar.get_index()
	_action_deck_panel = PanelContainer.new()
	_action_deck_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.10, 0.14, 0.96)
	style.border_color = Color(0.30, 0.66, 0.98, 0.70)
	style.set_border_width_all(1)
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	_action_deck_panel.add_theme_stylebox_override("panel", style)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 10)
	_action_deck_panel.add_child(margin)

	action_bar.reparent(margin)
	root_vbox.add_child(_action_deck_panel)
	root_vbox.move_child(_action_deck_panel, old_index)

	action_bar.add_theme_constant_override("separation", 10)
	if command_strip_scroll != null:
		command_strip_scroll.custom_minimum_size = Vector2(0, 220)
		command_strip_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		command_strip_scroll.size_flags_vertical = Control.SIZE_FILL
	if action_info_box != null:
		action_info_box.add_theme_constant_override("separation", 8)
		action_info_box.size_flags_horizontal = Control.SIZE_FILL
		action_info_box.custom_minimum_size = Vector2(ACTION_INFO_MIN_WIDTH, 0)
	if command_strip != null:
		command_strip.add_theme_constant_override("separation", 8)
		_ensure_burst_skill_card()
	if item_card_rack != null:
		item_card_rack.add_theme_constant_override("separation", 8)
	if status_label != null:
		status_label.add_theme_font_size_override("font_size", 16)
		status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if selected_target_label != null:
		selected_target_label.add_theme_font_size_override("font_size", 16)
		selected_target_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if wait_button != null:
		wait_button.custom_minimum_size = Vector2(100, 50)
	if item_button != null:
		item_button.custom_minimum_size = Vector2(108, 50)
	if wait_button != null and action_info_box != null and wait_button.get_parent() != action_info_box:
		wait_button.reparent(action_info_box)
		wait_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		wait_button.custom_minimum_size = Vector2(0, 46)
		action_info_box.move_child(wait_button, action_info_box.get_child_count() - 1)
	_style_action_button(wait_button, Color(0.12, 0.19, 0.14, 1.0), Color(0.44, 0.90, 0.64, 0.95))
	_style_action_button(item_button, Color(0.12, 0.15, 0.23, 1.0), Color(0.50, 0.74, 1.0, 0.95))
	_apply_skill_card_theme()
	_apply_item_card_theme()
	_bind_main_item_card_buttons()
	_refresh_main_item_cards([])


func _apply_shell_texture_layers() -> void:
	_remove_shell_texture_layer(modal_panel, "ModalShellTexture")
	_remove_shell_texture_layer(battle_summary_panel, "SummaryShellTexture")
	_remove_shell_texture_layer(hero_panel, "HeroShellTexture")
	_remove_shell_texture_layer(side_panel, "SideShellTexture")


func _remove_shell_texture_layer(panel: PanelContainer, layer_name: String) -> void:
	if panel == null:
		return
	var texture_layer := panel.get_node_or_null(layer_name) as TextureRect
	if texture_layer != null:
		texture_layer.queue_free()


func _layout_action_bar() -> void:
	if action_bar == null or action_info_box == null or command_strip_scroll == null:
		return
	var bar_width: float = action_bar.size.x
	if bar_width <= 0.0:
		return
	var target_info_width: float = clampf(
		bar_width * ACTION_INFO_WIDTH_RATIO,
		ACTION_INFO_MIN_WIDTH,
		ACTION_INFO_MAX_WIDTH
	)
	action_info_box.size_flags_horizontal = Control.SIZE_FILL
	action_info_box.custom_minimum_size = Vector2(target_info_width, 0)
	command_strip_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_apply_dynamic_action_card_width()
	if command_strip != null:
		command_strip.custom_minimum_size = Vector2(maxf(0.0, command_strip_scroll.size.x), command_strip.custom_minimum_size.y)


func _apply_dynamic_action_card_width() -> void:
	if command_strip_scroll == null or command_strip == null:
		return
	var available_width: float = command_strip_scroll.size.x
	if available_width <= 0.0:
		return
	var wait_width: float = 0.0
	if wait_button != null and wait_button.get_parent() == command_strip:
		wait_width = wait_button.custom_minimum_size.x
	var item_button_width: float = 0.0
	if item_button != null and item_button.get_parent() == command_strip:
		item_button_width = item_button.custom_minimum_size.x
	var strip_gap: float = float(command_strip.get_theme_constant("separation"))
	var strip_gap_count: float = maxf(0.0, float(max(0, command_strip.get_child_count() - 1)))
	var rack_gap: float = 0.0
	if item_card_rack != null:
		rack_gap = float(item_card_rack.get_theme_constant("separation"))
	var visible_main_item_cards: int = _visible_main_item_card_count()
	var dynamic_card_slots: float = 3.0 + float(visible_main_item_cards)
	var non_card_width: float = wait_width + item_button_width + (strip_gap * strip_gap_count) + rack_gap
	var target_card_width: float = floor((available_width - non_card_width) / maxf(1.0, dynamic_card_slots))
	_current_action_card_width = clampf(target_card_width, ACTION_CARD_MIN_WIDTH, ACTION_CARD_MAX_WIDTH)
	_apply_current_action_card_size()


func _current_action_card_size() -> Vector2:
	return Vector2(_current_action_card_width, ACTION_CARD_SIZE.y)


func _apply_current_action_card_size() -> void:
	var card_size: Vector2 = _current_action_card_size()
	if attack_skill_card != null:
		attack_skill_card.custom_minimum_size = card_size
	if defend_skill_card != null:
		defend_skill_card.custom_minimum_size = card_size
	if burst_skill_card != null:
		burst_skill_card.custom_minimum_size = card_size
	if item_card_a != null:
		item_card_a.custom_minimum_size = card_size
	if item_card_b != null:
		item_card_b.custom_minimum_size = card_size


func _visible_main_item_card_count() -> int:
	var count := 0
	if item_card_a != null and item_card_a.visible:
		count += 1
	if item_card_b != null and item_card_b.visible:
		count += 1
	return count


func _style_action_button(button: Button, bg: Color, border: Color) -> void:
	if button == null:
		return
	var normal := StyleBoxFlat.new()
	normal.bg_color = bg
	normal.border_color = border
	normal.set_border_width_all(1)
	normal.corner_radius_top_left = 10
	normal.corner_radius_top_right = 10
	normal.corner_radius_bottom_left = 10
	normal.corner_radius_bottom_right = 10
	normal.shadow_color = Color(0, 0, 0, 0.22)
	normal.shadow_size = 1
	var hover := normal.duplicate()
	hover.bg_color = bg.lightened(0.08)
	var pressed := normal.duplicate()
	pressed.bg_color = bg.darkened(0.08)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("disabled", pressed)
	button.add_theme_font_size_override("font_size", 15)


func _apply_skill_card_theme() -> void:
	_apply_action_card_chrome(attack_skill_card as PanelContainer, Color(0.99, 0.63, 0.34, 1.0), 11)
	_apply_action_card_chrome(defend_skill_card as PanelContainer, Color(0.48, 0.76, 1.0, 1.0), 29)
	_apply_action_card_chrome(burst_skill_card as PanelContainer, Color(1.00, 0.46, 0.40, 1.0), 53)
	_apply_current_action_card_size()


func _apply_item_card_theme() -> void:
	_apply_action_card_chrome(item_card_a, Color(0.56, 0.92, 0.68, 0.98), 71)
	_apply_action_card_chrome(item_card_b, Color(0.56, 0.92, 0.68, 0.98), 89)
	_apply_current_action_card_size()


func _apply_generated_art_preview() -> void:
	_apply_generated_arena_backdrop()


func _apply_generated_arena_backdrop() -> void:
	if battle_arena == null:
		return
	var backdrop_layer := battle_arena.get_node_or_null("ArenaBackdropArt") as TextureRect
	if backdrop_layer != null:
		backdrop_layer.queue_free()
	if arena_tint != null:
		arena_tint.color = Color(0.07, 0.10, 0.17, 0.96)
	if hero_lane != null:
		hero_lane.color = Color(0.18, 0.34, 0.54, 0.13)
	if enemy_lane != null:
		enemy_lane.color = Color(0.38, 0.22, 0.30, 0.12)
	if mid_gap != null:
		mid_gap.color = Color(0.06, 0.10, 0.16, 0.20)
	if center_line != null:
		center_line.color = Color(0.58, 0.84, 1.0, 0.24)


func _apply_action_card_chrome(panel: PanelContainer, accent: Color, noise_seed: int) -> void:
	if panel == null:
		return
	var base := StyleBoxFlat.new()
	base.bg_color = Color(0.09, 0.12, 0.17, 0.98)
	base.border_color = accent
	base.set_border_width_all(1)
	base.corner_radius_top_left = ACTION_CARD_CORNER_RADIUS
	base.corner_radius_top_right = ACTION_CARD_CORNER_RADIUS
	base.corner_radius_bottom_left = ACTION_CARD_CORNER_RADIUS
	base.corner_radius_bottom_right = ACTION_CARD_CORNER_RADIUS
	base.shadow_color = Color(accent.r, accent.g, accent.b, 0.12)
	base.shadow_size = 2
	panel.add_theme_stylebox_override("panel", base)
	_ensure_action_card_layers(panel, accent, noise_seed)


func _ensure_action_card_layers(panel: PanelContainer, accent: Color, noise_seed: int) -> void:
	var _unused_noise_seed := noise_seed
	var top_glow := panel.get_node_or_null("CardTopGlow") as ColorRect
	if top_glow == null:
		top_glow = ColorRect.new()
		top_glow.name = "CardTopGlow"
		top_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		top_glow.anchor_right = 1.0
		top_glow.offset_bottom = 34.0
		panel.add_child(top_glow)
		panel.move_child(top_glow, 0)
	top_glow.color = Color(accent.r, accent.g, accent.b, 0.14)
	var surface_layer := panel.get_node_or_null("CardSurface")
	if surface_layer != null:
		surface_layer.queue_free()
	var noise_layer := panel.get_node_or_null("CardNoise")
	if noise_layer != null:
		noise_layer.queue_free()
	var frame_layer := panel.get_node_or_null("CardFrame") as Panel
	if frame_layer == null:
		frame_layer = Panel.new()
		frame_layer.name = "CardFrame"
		frame_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame_layer.anchor_right = 1.0
		frame_layer.anchor_bottom = 1.0
		frame_layer.offset_left = 1.0
		frame_layer.offset_top = 1.0
		frame_layer.offset_right = -1.0
		frame_layer.offset_bottom = -1.0
		panel.add_child(frame_layer)
		panel.move_child(frame_layer, 1)
	var frame_style := StyleBoxFlat.new()
	frame_style.bg_color = Color(0, 0, 0, 0)
	frame_style.border_color = Color(accent.r, accent.g, accent.b, 0.34)
	frame_style.set_border_width_all(1)
	frame_style.corner_radius_top_left = ACTION_CARD_CORNER_RADIUS - 2
	frame_style.corner_radius_top_right = ACTION_CARD_CORNER_RADIUS - 2
	frame_style.corner_radius_bottom_left = ACTION_CARD_CORNER_RADIUS - 2
	frame_style.corner_radius_bottom_right = ACTION_CARD_CORNER_RADIUS - 2
	frame_layer.add_theme_stylebox_override("panel", frame_style)
	var rune_stripe := panel.get_node_or_null("CardRuneStripe") as ColorRect
	if rune_stripe == null:
		rune_stripe = ColorRect.new()
		rune_stripe.name = "CardRuneStripe"
		rune_stripe.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rune_stripe.anchor_right = 1.0
		rune_stripe.anchor_bottom = 1.0
		rune_stripe.offset_left = 8.0
		rune_stripe.offset_top = 8.0
		rune_stripe.offset_right = -8.0
		rune_stripe.offset_bottom = -8.0
		panel.add_child(rune_stripe)
		panel.move_child(rune_stripe, 3)
	rune_stripe.color = Color(accent.r, accent.g, accent.b, 0.05)


func _skill_icon_texture(slot_id: String) -> Texture2D:
	match slot_id:
		"guard":
			return SKILL_ICON_GUARD
		"burst":
			return SKILL_ICON_BURST
		"primary":
			return SKILL_ICON_PRIMARY
	return DEFAULT_SKILL_ICON


func _bind_main_item_card_buttons() -> void:
	if item_card_a_use_button != null and not item_card_a_use_button.pressed.is_connected(_on_main_item_use_pressed.bind(0)):
		item_card_a_use_button.pressed.connect(_on_main_item_use_pressed.bind(0))
	if item_card_b_use_button != null and not item_card_b_use_button.pressed.is_connected(_on_main_item_use_pressed.bind(1)):
		item_card_b_use_button.pressed.connect(_on_main_item_use_pressed.bind(1))


func _on_main_item_use_pressed(slot_index: int) -> void:
	if slot_index < 0 or slot_index >= _item_card_item_ids.size():
		return
	var item_id: String = String(_item_card_item_ids[slot_index])
	if item_id.is_empty() or not _can_accept_drag_drop_input():
		return
	_use_item_and_continue(item_id)


func _item_card_panel(slot_index: int) -> PanelContainer:
	match slot_index:
		0:
			return item_card_a
		1:
			return item_card_b
	return null


func _item_card_icon(slot_index: int) -> TextureRect:
	match slot_index:
		0:
			return item_card_a_icon
		1:
			return item_card_b_icon
	return null


func _item_card_title(slot_index: int) -> Label:
	match slot_index:
		0:
			return item_card_a_title
		1:
			return item_card_b_title
	return null


func _item_card_desc(slot_index: int) -> Label:
	match slot_index:
		0:
			return item_card_a_desc
		1:
			return item_card_b_desc
	return null


func _item_card_meta(slot_index: int) -> Label:
	match slot_index:
		0:
			return item_card_a_meta
		1:
			return item_card_b_meta
	return null


func _item_card_use_button(slot_index: int) -> Button:
	match slot_index:
		0:
			return item_card_a_use_button
		1:
			return item_card_b_use_button
	return null


func _set_main_item_card_interactive(slot_index: int, interactive: bool) -> void:
	var card: PanelContainer = _item_card_panel(slot_index)
	var use_button: Button = _item_card_use_button(slot_index)
	var has_item: bool = not String(_item_card_item_ids[slot_index]).is_empty()
	if card != null:
		if interactive:
			card.modulate = Color(1, 1, 1, 1) if has_item else Color(0.74, 0.74, 0.78, 0.72)
		else:
			card.modulate = Color(0.72, 0.72, 0.76, 0.84) if has_item else Color(0.68, 0.68, 0.72, 0.68)
	if use_button != null:
		use_button.disabled = not interactive or not has_item


func _item_slot_drag_payload(slot_index: int) -> Dictionary:
	if slot_index < 0 or slot_index >= _item_card_item_ids.size():
		return {}
	var item_id: String = String(_item_card_item_ids[slot_index])
	return _item_drag_payload(item_id)


func _ranked_battle_items(battle_items: Array) -> Array:
	var by_id: Dictionary = {}
	var ordered_ids: Array[String] = []
	for stack_value in battle_items:
		if typeof(stack_value) != TYPE_DICTIONARY:
			continue
		var stack: Dictionary = stack_value
		var item_id: String = String(stack.get("id", ""))
		if item_id.is_empty() or int(stack.get("count", 0)) <= 0:
			continue
		by_id[item_id] = stack
		ordered_ids.append(item_id)
	var ranked: Array = []
	var seen: Dictionary = {}
	for recent_id: String in _recent_item_ids:
		if recent_id.is_empty() or not by_id.has(recent_id) or seen.has(recent_id):
			continue
		ranked.append((by_id[recent_id] as Dictionary).duplicate(true))
		seen[recent_id] = true
	for item_id: String in ordered_ids:
		if seen.has(item_id):
			continue
		ranked.append((by_id[item_id] as Dictionary).duplicate(true))
		seen[item_id] = true
	return ranked


func _mark_item_recent(item_id: String, move_to_front: bool = true) -> void:
	if item_id.is_empty():
		return
	var next_order: Array[String] = []
	for existing_id: String in _recent_item_ids:
		if existing_id == item_id:
			continue
		next_order.append(existing_id)
	if move_to_front:
		next_order.insert(0, item_id)
	else:
		next_order.append(item_id)
	_recent_item_ids = next_order


func _item_effect_summary(effect: Dictionary) -> String:
	match String(effect.get("kind", "")):
		"heal":
			return "治疗 +%d" % int(round(float(effect.get("recover_hp", 0.0))))
		_:
			return "即时效果"


func _load_item_icon(icon_path: String) -> Texture2D:
	var path: String = icon_path if not icon_path.is_empty() else "res://icon.svg"
	if ResourceLoader.exists(path):
		var loaded: Resource = load(path)
		if loaded is Texture2D:
			return loaded
	return DEFAULT_SKILL_ICON


func _ensure_burst_skill_card() -> void:
	if command_strip == null or burst_skill_card != null:
		return
	var insert_index: int = command_strip.get_children().find(item_card_rack)
	if insert_index < 0:
		insert_index = command_strip.get_children().find(item_button)
	if insert_index < 0:
		insert_index = command_strip.get_child_count()
	var card := PanelContainer.new()
	card.name = "BurstSkillCard"
	card.custom_minimum_size = _current_action_card_size()
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	command_strip.add_child(card)
	command_strip.move_child(card, insert_index)
	burst_skill_card = card

	var cooldown_mask := ColorRect.new()
	cooldown_mask.name = "BurstCooldownMask"
	cooldown_mask.anchor_right = 1.0
	cooldown_mask.anchor_bottom = 1.0
	cooldown_mask.grow_horizontal = Control.GROW_DIRECTION_BOTH
	cooldown_mask.grow_vertical = Control.GROW_DIRECTION_BOTH
	cooldown_mask.color = Color(0.05, 0.07, 0.11, 0.0)
	cooldown_mask.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(cooldown_mask)
	burst_cooldown_mask = cooldown_mask

	var margin := MarginContainer.new()
	margin.name = "BurstSkillMargin"
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 8)
	card.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.name = "BurstSkillVBox"
	vbox.add_theme_constant_override("separation", 4)
	margin.add_child(vbox)

	var head_row := HBoxContainer.new()
	head_row.name = "BurstHeadRow"
	head_row.add_theme_constant_override("separation", 8)
	vbox.add_child(head_row)

	var icon := TextureRect.new()
	icon.name = "BurstSkillIcon"
	icon.custom_minimum_size = Vector2(24, 24)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	head_row.add_child(icon)
	burst_skill_icon = icon

	var button := Button.new()
	button.name = "BurstButton"
	button.custom_minimum_size = Vector2(0, 38)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.text = "技能3·祷焰横扫"
	button.add_theme_font_size_override("font_size", 16)
	if not button.pressed.is_connected(_on_burst_pressed):
		button.pressed.connect(_on_burst_pressed)
	head_row.add_child(button)
	burst_button = button

	var meta := Label.new()
	meta.name = "BurstMetaLabel"
	meta.text = "冷却正常 | 灵势 2"
	meta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	meta.add_theme_font_size_override("font_size", 12)
	vbox.add_child(meta)
	burst_meta_label = meta

	var cooldown_row := HBoxContainer.new()
	cooldown_row.name = "BurstCooldownRow"
	cooldown_row.add_theme_constant_override("separation", 6)
	vbox.add_child(cooldown_row)

	var cooldown_tag := Label.new()
	cooldown_tag.text = "CD"
	cooldown_tag.custom_minimum_size = Vector2(26, 0)
	cooldown_tag.add_theme_font_size_override("font_size", 11)
	cooldown_row.add_child(cooldown_tag)
	burst_cooldown_tag = cooldown_tag

	var cooldown_bar := ProgressBar.new()
	cooldown_bar.name = "BurstCooldownBar"
	cooldown_bar.custom_minimum_size = Vector2(0, 8)
	cooldown_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cooldown_bar.show_percentage = false
	cooldown_row.add_child(cooldown_bar)
	burst_cooldown_bar = cooldown_bar

	var resource_row := HBoxContainer.new()
	resource_row.name = "BurstResourceRow"
	resource_row.add_theme_constant_override("separation", 6)
	vbox.add_child(resource_row)

	var resource_tag := Label.new()
	resource_tag.text = "灵势"
	resource_tag.custom_minimum_size = Vector2(26, 0)
	resource_tag.add_theme_font_size_override("font_size", 11)
	resource_row.add_child(resource_tag)
	burst_resource_tag = resource_tag

	var resource_bar := ProgressBar.new()
	resource_bar.name = "BurstResourceBar"
	resource_bar.custom_minimum_size = Vector2(0, 8)
	resource_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	resource_bar.show_percentage = false
	resource_row.add_child(resource_bar)
	burst_resource_bar = resource_bar


func _bind_drag_sources() -> void:
	_bind_drag_source(attack_skill_card, Callable(self, "_skill_drag_payload").bind("primary"), Callable(self, "_on_attack_pressed"))
	_bind_drag_source(defend_skill_card, Callable(self, "_skill_drag_payload").bind("guard"), Callable(self, "_on_defend_pressed"))
	_bind_drag_source(burst_skill_card, Callable(self, "_skill_drag_payload").bind("burst"), Callable(self, "_on_burst_pressed"))
	_configure_main_item_card_drag_surface(item_card_a, item_card_a_use_button)
	_configure_main_item_card_drag_surface(item_card_b, item_card_b_use_button)
	_bind_drag_source(item_card_a, Callable(self, "_item_slot_drag_payload").bind(0), Callable(self, "_on_main_item_use_pressed").bind(0), false)
	_bind_drag_source(item_card_b, Callable(self, "_item_slot_drag_payload").bind(1), Callable(self, "_on_main_item_use_pressed").bind(1), false)


func _bind_drag_source(
	card: Control,
	payload_provider: Callable,
	click_action: Callable = Callable(),
	ignore_descendants: bool = true
) -> void:
	if card == null:
		return
	if not card.is_inside_tree():
		# Defer binding until node is ready
		card.ready.connect(func(): _bind_drag_source(card, payload_provider, click_action, ignore_descendants), CONNECT_ONE_SHOT)
		return
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	if ignore_descendants:
		_set_descendants_mouse_filter(card)
	# Bind drag handler (only once during initialization)
	var drag_handler := Callable(self, "_on_drag_source_gui_input").bind(card, payload_provider, click_action)
	if not card.gui_input.is_connected(drag_handler):
		card.gui_input.connect(drag_handler)


func _configure_main_item_card_drag_surface(card: Control, use_button: Button) -> void:
	if card == null:
		return
	_set_descendants_mouse_filter_except(card, [use_button])


func _set_descendants_mouse_filter(node: Node) -> void:
	for child: Node in node.get_children():
		if child is Control:
			var control := child as Control
			control.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_set_descendants_mouse_filter(child)


func _set_descendants_mouse_filter_except(node: Node, exceptions: Array) -> void:
	for child: Node in node.get_children():
		if child is Control:
			var control := child as Control
			var should_ignore := true
			for except in exceptions:
				if except is Control and (control == except or (except as Control).is_ancestor_of(control)):
					should_ignore = false
					break
			control.mouse_filter = Control.MOUSE_FILTER_IGNORE if should_ignore else Control.MOUSE_FILTER_STOP
		_set_descendants_mouse_filter_except(child, exceptions)


func _on_drag_source_gui_input(event: InputEvent, source: Control, payload_provider: Callable, click_action: Callable = Callable()) -> void:
	if source == null:
		return
	var viewport := source.get_viewport()
	if viewport == null:
		return
	var mouse_pos := viewport.get_mouse_position()
	var inside_source: bool = source.get_global_rect().has_point(mouse_pos)
	if event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		if mouse_button.button_index != MOUSE_BUTTON_LEFT:
			return
		if mouse_button.pressed:
			if not inside_source:
				return
			_pending_drag_source = source
			_pending_drag_payload = _drag_payload_from_provider(payload_provider)
			_pending_drag_anchor = mouse_button.global_position
			return
		if _pending_drag_source == source and click_action.is_valid():
			if mouse_button.global_position.distance_to(_pending_drag_anchor) < DRAG_START_DISTANCE:
				click_action.call()
		_clear_pending_drag()
		return
	if event is not InputEventMouseMotion:
		return
	var mouse_motion := event as InputEventMouseMotion
	if _pending_drag_source != source:
		return
	if (mouse_motion.button_mask & MOUSE_BUTTON_MASK_LEFT) == 0:
		_clear_pending_drag()
		return
	if _pending_drag_payload.is_empty():
		return
	if mouse_motion.global_position.distance_to(_pending_drag_anchor) < DRAG_START_DISTANCE:
		return
	_begin_drag_payload(source, _pending_drag_payload)
	_clear_pending_drag()


func _begin_drag_payload(source: Control, payload: Dictionary) -> void:
	if source == null or payload.is_empty():
		return
	var preview := _build_drag_preview(payload)
	source.force_drag(payload, preview)
	_drag_in_progress = true
	_last_drag_payload = payload.duplicate(true)
	_drag_source_position = source.get_global_rect().get_center()


func _drag_payload_from_provider(payload_provider: Callable) -> Dictionary:
	if not payload_provider.is_valid():
		return {}
	var payload_data: Variant = payload_provider.call()
	if typeof(payload_data) != TYPE_DICTIONARY:
		return {}
	var payload: Dictionary = payload_data
	if String(payload.get("kind", "")).is_empty():
		return {}
	return payload.duplicate(true)


func _clear_pending_drag() -> void:
	_pending_drag_source = null
	_pending_drag_payload = {}
	_pending_drag_anchor = Vector2.ZERO


func _build_drag_preview(payload: Dictionary) -> Control:
	var kind := String(payload.get("kind", ""))
	var is_skill := kind == "skill"
	var is_item := kind == "item"
	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.custom_minimum_size = Vector2(180, 52)
	
	var shadow := PanelContainer.new()
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shadow.custom_minimum_size = Vector2(180, 52)
	shadow.position = Vector2(3, 3)
	var shadow_style := StyleBoxFlat.new()
	shadow_style.bg_color = Color(0.0, 0.0, 0.0, 0.42)
	shadow_style.corner_radius_top_left = 10
	shadow_style.corner_radius_top_right = 10
	shadow_style.corner_radius_bottom_left = 10
	shadow_style.corner_radius_bottom_right = 10
	shadow.add_theme_stylebox_override("panel", shadow_style)
	root.add_child(shadow)
	
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.custom_minimum_size = Vector2(180, 52)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.11, 0.16, 0.96)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	style.set_border_width_all(1)
	if is_skill:
		var slot := String(payload.get("slot", "primary"))
		match slot:
			"primary":
				style.border_color = Color(1.0, 0.67, 0.42, 1.0)
				style.shadow_color = Color(1.0, 0.67, 0.42, 0.22)
			"guard":
				style.border_color = Color(0.49, 0.79, 1.0, 1.0)
				style.shadow_color = Color(0.49, 0.79, 1.0, 0.22)
			"burst":
				style.border_color = Color(1.0, 0.50, 0.48, 1.0)
				style.shadow_color = Color(1.0, 0.50, 0.48, 0.22)
			_:
				style.border_color = Color(0.70, 0.84, 1.0, 0.95)
				style.shadow_color = Color(0.70, 0.84, 1.0, 0.18)
		style.shadow_size = 2
	elif is_item:
		style.border_color = Color(0.56, 0.92, 0.70, 1.0)
		style.shadow_color = Color(0.56, 0.92, 0.70, 0.20)
		style.shadow_size = 2
	else:
		style.border_color = Color(0.64, 0.80, 1.0, 0.95)
		style.shadow_color = Color(0.64, 0.80, 1.0, 0.16)
		style.shadow_size = 2
	panel.add_theme_stylebox_override("panel", style)
	root.add_child(panel)
	
	var glow := PanelContainer.new()
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glow.custom_minimum_size = Vector2(184, 56)
	glow.position = Vector2(-2, -2)
	var glow_style := StyleBoxFlat.new()
	glow_style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	if is_skill:
		glow_style.border_color = Color(style.border_color.r, style.border_color.g, style.border_color.b, 0.22)
	else:
		glow_style.border_color = Color(style.border_color.r, style.border_color.g, style.border_color.b, 0.18)
	glow_style.set_border_width_all(3)
	glow_style.corner_radius_top_left = 12
	glow_style.corner_radius_top_right = 12
	glow_style.corner_radius_bottom_left = 12
	glow_style.corner_radius_bottom_right = 12
	glow.add_theme_stylebox_override("panel", glow_style)
	root.add_child(glow)
	
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)
	
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	margin.add_child(hbox)
	
	if is_skill or is_item:
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(20, 20)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture = DEFAULT_SKILL_ICON
		if is_skill:
			icon.modulate = style.border_color
		else:
			icon.modulate = Color(0.68, 0.92, 0.62, 1.0)
		hbox.add_child(icon)
	
	var label := Label.new()
	label.text = _drag_preview_text(payload)
	label.modulate = Color(0.93, 0.97, 1.0, 1.0)
	label.add_theme_font_size_override("font_size", 15)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox.add_child(label)
	
	return root


func _drag_preview_text(payload: Dictionary) -> String:
	var kind: String = String(payload.get("kind", ""))
	if kind == "skill":
		return "技能: %s" % String(payload.get("name", "未命名"))
	if kind == "item":
		return "道具: %s" % String(payload.get("name", "未命名"))
	return "动作"


func _skill_drag_payload(slot_id: String) -> Dictionary:
	if not _interactive_mode:
		return {}
	var skill: Dictionary = _skill_slot(_interactive_state.get("skill_slots", []), slot_id)
	if skill.is_empty():
		return {}
	return {
		"kind": "skill",
		"slot": slot_id,
		"name": String(skill.get("name_cn", slot_id))
	}


func _item_drag_payload(item_id: String) -> Dictionary:
	if not _interactive_mode:
		return {}
	var stack: Dictionary = _battle_item_stack(item_id)
	if stack.is_empty():
		return {}
	return {
		"kind": "item",
		"item_id": item_id,
		"name": String(stack.get("name_cn", item_id))
	}


func _battle_item_stack(item_id: String) -> Dictionary:
	for stack_value in _interactive_state.get("battle_items", []):
		if typeof(stack_value) != TYPE_DICTIONARY:
			continue
		var stack: Dictionary = stack_value
		if String(stack.get("id", "")) != item_id:
			continue
		if int(stack.get("count", 0)) <= 0:
			return {}
		return stack
	return {}


func _can_drop_payload_on_entity(entity_id: String, data: Variant) -> bool:
	var payload: Dictionary = _normalize_drag_payload(data)
	if payload.is_empty():
		return false
	if not _can_accept_drag_drop_input():
		return false
	var kind: String = String(payload.get("kind", ""))
	if kind == "skill":
		return _can_drop_skill_payload(entity_id, payload)
	if kind == "item":
		return _can_drop_item_payload(entity_id, payload)
	return false


func _drop_payload_on_entity(entity_id: String, data: Variant) -> void:
	var payload: Dictionary = _normalize_drag_payload(data)
	if payload.is_empty():
		return
	if not _can_drop_payload_on_entity(entity_id, payload):
		_show_reject_drop_fx(get_viewport().get_mouse_position())
		_show_drop_rejected_status(payload)
		return
	var kind: String = String(payload.get("kind", ""))
	if kind == "skill":
		_apply_skill_drop(entity_id, payload)
		return
	if kind == "item":
		_apply_item_drop(entity_id, payload)


func _normalize_drag_payload(data: Variant) -> Dictionary:
	if typeof(data) != TYPE_DICTIONARY:
		return {}
	var payload: Dictionary = data
	if String(payload.get("kind", "")).is_empty():
		return {}
	return payload


func _can_accept_drag_drop_input() -> bool:
	if not _interactive_mode or _resolving_enemy_phase:
		return false
	return String(_interactive_state.get("turn_phase", "player")) == "player"


func _can_drop_skill_payload(entity_id: String, payload: Dictionary) -> bool:
	var slot_id: String = String(payload.get("slot", ""))
	if slot_id.is_empty():
		return false
	var skill: Dictionary = _skill_slot(_interactive_state.get("skill_slots", []), slot_id)
	if skill.is_empty():
		return false
	var unavailable_reason: String = _skill_unavailable_reason(skill, int(_interactive_state.get("hero_resolve", 0)))
	if not unavailable_reason.is_empty():
		return false
	match slot_id:
		"primary", "burst":
			return _is_alive_enemy_entity(entity_id)
		"guard":
			return entity_id == "hero_1" and _is_hero_alive()
		_:
			return false


func _can_drop_item_payload(entity_id: String, payload: Dictionary) -> bool:
	var item_id: String = String(payload.get("item_id", ""))
	if item_id.is_empty():
		return false
	var stack: Dictionary = _battle_item_stack(item_id)
	if stack.is_empty():
		return false
	var effect: Dictionary = stack.get("effect", {})
	match String(effect.get("kind", "")):
		"heal":
			return entity_id == "hero_1" and _is_hero_alive()
		_:
			return false


func _apply_skill_drop(entity_id: String, payload: Dictionary) -> void:
	_show_drop_success_fx(entity_id, payload)
	match String(payload.get("slot", "")):
		"primary":
			_selected_target_id = entity_id
			_on_attack_pressed()
		"guard":
			_on_defend_pressed()
		"burst":
			_selected_target_id = entity_id
			_on_burst_pressed()


func _apply_item_drop(_entity_id: String, payload: Dictionary) -> void:
	_show_drop_success_fx(_entity_id, payload)
	_use_item_and_continue(String(payload.get("item_id", "")))


func _is_alive_enemy_entity(entity_id: String) -> bool:
	for enemy_entity_value in _interactive_state.get("enemy_entities", []):
		if typeof(enemy_entity_value) != TYPE_DICTIONARY:
			continue
		var enemy_entity: Dictionary = enemy_entity_value
		if String(enemy_entity.get("entity_id", "")) != entity_id:
			continue
		return bool(enemy_entity.get("is_alive", true))
	return false


func _is_hero_alive() -> bool:
	var hero_entity: Dictionary = _interactive_state.get("hero_entity", {})
	return bool(hero_entity.get("is_alive", float(_interactive_state.get("hero_hp", 0.0)) > 0.0))


func _show_drop_rejected_status(payload: Dictionary) -> void:
	if status_label == null:
		return
	var kind: String = String(payload.get("kind", ""))
	if kind == "skill":
		status_label.text = "该单位不支持此技能目标，未触发动作。"
		return
	if kind == "item":
		status_label.text = "该单位不支持此道具目标，未触发动作。"
		return
	status_label.text = "目标不支持该动作。"


func _show_reject_drop_fx(viewport_position: Vector2) -> void:
	if battle_arena == null:
		return
	var to_local: Transform2D = battle_arena.get_global_transform_with_canvas().affine_inverse()
	var local_pos: Vector2 = to_local * viewport_position
	var marker := _build_reject_marker()
	marker.position = local_pos
	marker.z_index = 240
	battle_arena.add_child(marker)
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(marker, "scale", Vector2(1.18, 1.18), 0.18)
	tween.parallel().tween_property(marker, "position:y", local_pos.y - 12.0, 0.24)
	tween.parallel().tween_property(marker, "modulate:a", 0.0, 0.24)
	tween.tween_callback(marker.queue_free)


func _build_reject_marker() -> Node2D:
	var root := Node2D.new()
	root.scale = Vector2(0.92, 0.92)
	var ring := Line2D.new()
	ring.width = 4.0
	ring.default_color = Color(1.0, 0.28, 0.24, 0.95)
	ring.closed = true
	ring.antialiased = true
	var ring_points := PackedVector2Array()
	var segments := 18
	for i in range(segments):
		var angle: float = (TAU * float(i)) / float(segments)
		ring_points.append(Vector2(cos(angle), sin(angle)) * 14.0)
	ring.points = ring_points
	root.add_child(ring)
	var slash := Line2D.new()
	slash.width = 5.0
	slash.default_color = Color(1.0, 0.32, 0.26, 0.96)
	slash.antialiased = true
	slash.points = PackedVector2Array([Vector2(-9, 9), Vector2(9, -9)])
	root.add_child(slash)
	return root


func _show_drop_success_fx(entity_id: String, payload: Dictionary) -> void:
	if battle_arena == null:
		return
	var token: Control = _arena_nodes.get(entity_id)
	if token == null:
		return
	var kind := String(payload.get("kind", ""))
	var success_color := Color(0.42, 0.88, 0.58, 0.95)
	if kind == "skill":
		var slot := String(payload.get("slot", "primary"))
		match slot:
			"primary":
				success_color = Color(0.98, 0.72, 0.28, 0.95)
			"guard":
				success_color = Color(0.34, 0.62, 0.94, 0.95)
			"burst":
				success_color = Color(0.94, 0.42, 0.22, 0.95)
	elif kind == "item":
		success_color = Color(0.56, 0.86, 0.48, 0.95)
	
	var origin := token.position + (token.size * 0.5)
	for ring_index in range(3):
		var ring := _build_success_ring(ring_index, success_color)
		ring.position = origin
		ring.z_index = 200
		battle_arena.add_child(ring)
		var delay := float(ring_index) * 0.08
		var tween := create_tween()
		tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_interval(delay)
		tween.parallel().tween_property(ring, "scale", Vector2(1.6 + float(ring_index) * 0.3, 1.6 + float(ring_index) * 0.3), 0.32)
		tween.parallel().tween_property(ring, "modulate:a", 0.0, 0.32)
		tween.tween_callback(ring.queue_free)


func _build_success_ring(ring_index: int, color: Color) -> Node2D:
	var root := Node2D.new()
	root.scale = Vector2(1.8, 1.8)
	var ring := Line2D.new()
	ring.width = 3.0 - float(ring_index) * 0.5
	ring.default_color = color
	ring.closed = true
	ring.antialiased = true
	var ring_points := PackedVector2Array()
	var segments := 24
	var radius := 20.0 + float(ring_index) * 8.0
	for i in range(segments):
		var angle: float = (TAU * float(i)) / float(segments)
		ring_points.append(Vector2(cos(angle), sin(angle)) * radius)
	ring.points = ring_points
	root.add_child(ring)
	return root
