extends Node

signal interactive_battle_finished(result: Dictionary)

const BATTLE_SIMULATOR := preload("res://systems/battle/battle_simulator.gd")
const UNIT_TOKEN_SCENE := preload("res://scenes/battle/unit_token.tscn")

@onready var battle_arena: Control = %BattleArena
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
@onready var action_bar: HBoxContainer = $"../BattleUI/ShellMargin/ModalPanel/PanelMargin/RootVBox/ActionBar"
@onready var action_info_box: VBoxContainer = $"../BattleUI/ShellMargin/ModalPanel/PanelMargin/RootVBox/ActionBar/ActionInfo"
@onready var command_strip: HBoxContainer = $"../BattleUI/ShellMargin/ModalPanel/PanelMargin/RootVBox/ActionBar/CommandStrip"
@onready var attack_button: Button = get_node_or_null("%AttackButton")
@onready var defend_button: Button = get_node_or_null("%DefendButton")
@onready var wait_button: Button = get_node_or_null("%WaitButton")
@onready var item_button: Button = get_node_or_null("%ItemButton")
@onready var attack_skill_card: Control = get_node_or_null("%AttackSkillCard")
@onready var defend_skill_card: Control = get_node_or_null("%DefendSkillCard")
var burst_button: Button
var burst_skill_card: Control
var burst_skill_icon: TextureRect
var burst_cooldown_mask: ColorRect
var burst_meta_label: Label
var burst_cooldown_bar: ProgressBar
var burst_resource_bar: ProgressBar
@onready var attack_skill_icon: TextureRect = get_node_or_null("%AttackSkillIcon")
@onready var defend_skill_icon: TextureRect = get_node_or_null("%DefendSkillIcon")
@onready var attack_cooldown_mask: ColorRect = get_node_or_null("%AttackCooldownMask")
@onready var defend_cooldown_mask: ColorRect = get_node_or_null("%DefendCooldownMask")
@onready var attack_meta_label: Label = get_node_or_null("%AttackMetaLabel")
@onready var attack_cooldown_bar: ProgressBar = get_node_or_null("%AttackCooldownBar")
@onready var attack_resource_bar: ProgressBar = get_node_or_null("%AttackResourceBar")
@onready var defend_meta_label: Label = get_node_or_null("%DefendMetaLabel")
@onready var defend_cooldown_bar: ProgressBar = get_node_or_null("%DefendCooldownBar")
@onready var defend_resource_bar: ProgressBar = get_node_or_null("%DefendResourceBar")
@onready var item_popup_panel: PopupPanel = get_node_or_null("%ItemPopupPanel")
@onready var item_list_vbox: VBoxContainer = get_node_or_null("%ItemListVBox")

var _simulator: RefCounted
var _last_state: Dictionary = {}
var _log_lines: Array[String] = []
var _arena_nodes: Dictionary = {}
var _last_hp_by_entity: Dictionary = {}
var _death_hold_by_entity: Dictionary = {}
var _last_visual_position_by_entity: Dictionary = {}
var _feedback_counts: Dictionary = {"hit": 0, "down": 0}
var _motion_feedback_counts: Dictionary = {"hero_advances": 0, "enemy_advances": 0, "animated_entities": 0}
var _combat_cue_counts: Dictionary = {"attack_lines": 0, "death_fades": 0}
var _timeline: Array = []
var _playback_nonce: int = 0
var _attack_line: Line2D
var _attack_arrow: Polygon2D
var _attack_line_tween: Tween
var _interactive_mode := false
var _interactive_request: Dictionary = {}
var _interactive_context: Dictionary = {}
var _interactive_state: Dictionary = {}
var _selected_target_id := ""
var _resolving_enemy_phase := false
var _last_action_signature := ""
var _action_deck_panel: PanelContainer

const DEFAULT_SKILL_ICON := preload("res://icon.svg")


func _ready() -> void:
	if battle_arena != null and not battle_arena.resized.is_connected(_on_battle_arena_resized):
		battle_arena.resized.connect(_on_battle_arena_resized)
	if attack_button != null and not attack_button.pressed.is_connected(_on_attack_pressed):
		attack_button.pressed.connect(_on_attack_pressed)
	if defend_button != null and not defend_button.pressed.is_connected(_on_defend_pressed):
		defend_button.pressed.connect(_on_defend_pressed)
	if wait_button != null and not wait_button.pressed.is_connected(_on_wait_pressed):
		wait_button.pressed.connect(_on_wait_pressed)
	if item_button != null and not item_button.pressed.is_connected(_on_item_pressed):
		item_button.pressed.connect(_on_item_pressed)
	_build_action_deck()
	_bind_clickable_cards()
	_set_interaction_enabled(false)
	call_deferred("_refresh_layout_after_frame")


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
	_death_hold_by_entity.clear()
	_last_visual_position_by_entity.clear()
	_feedback_counts = {"hit": 0, "down": 0}
	_motion_feedback_counts = {"hero_advances": 0, "enemy_advances": 0, "animated_entities": 0}
	_combat_cue_counts = {"attack_lines": 0, "death_fades": 0}
	_playback_nonce += 1
	_selected_target_id = ""
	_resolving_enemy_phase = false
	_last_action_signature = ""
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
		hero_token.color = Color(0.756863, 0.686275, 0.372549, 1) if hero_hp > 0.0 else Color(0.427451, 0.180392, 0.180392, 1)
	else:
		hero_token.color = Color(0.505882, 0.258824, 0.258824, 1)
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
		attack_button.disabled = true
		attack_button.text = "技能·斩击"
		if defend_button != null:
			defend_button.disabled = true
			defend_button.text = "技能·架盾"
		if burst_button != null:
			burst_button.disabled = true
			burst_button.text = "技能·祷焰横扫"
		if wait_button != null:
			wait_button.disabled = true
			wait_button.text = "结束回合"
		if item_button != null:
			item_button.disabled = true
			item_button.text = "选择道具"
		_update_skill_card({}, attack_skill_card, attack_skill_icon, attack_meta_label, attack_cooldown_bar, attack_resource_bar, attack_cooldown_mask, 0, 0)
		_update_skill_card({}, defend_skill_card, defend_skill_icon, defend_meta_label, defend_cooldown_bar, defend_resource_bar, defend_cooldown_mask, 0, 0)
		_update_skill_card({}, burst_skill_card, burst_skill_icon, burst_meta_label, burst_cooldown_bar, burst_resource_bar, burst_cooldown_mask, 0, 0)
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
	attack_button.disabled = not can_player_input or _selected_target_id.is_empty() or not slash_block_reason.is_empty()
	attack_button.tooltip_text = "攻击当前锁定目标并消耗灵势。"
	if not can_player_input:
		attack_button.text = "敌方行动中"
	elif _selected_target_id.is_empty():
		attack_button.text = "技能1·%s（先选目标）" % slash_name
	elif not slash_block_reason.is_empty():
		attack_button.text = "技能1·%s（%s）" % [slash_name, slash_block_reason]
	else:
		attack_button.text = "技能1·%s" % slash_name
	if defend_button != null:
		defend_button.disabled = not can_player_input or not guard_block_reason.is_empty()
		defend_button.tooltip_text = "降低本轮即将承受的敌方伤害。"
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
		wait_button.text = "蓄势待机"
		wait_button.tooltip_text = "不出手，恢复灵势并进入敌方回合。"
	if item_button != null:
		if battle_items.is_empty():
			item_button.text = "无可用道具"
			item_button.disabled = true
			item_button.tooltip_text = "当前没有可在战斗中使用的道具。"
		else:
			item_button.text = "道具 x%d" % battle_items.size()
			item_button.disabled = not can_player_input
			item_button.tooltip_text = "使用战斗道具后会立即进入敌方回合。"
	_update_skill_card(slash_skill, attack_skill_card, attack_skill_icon, attack_meta_label, attack_cooldown_bar, attack_resource_bar, attack_cooldown_mask, hero_resolve, hero_resolve_max)
	_update_skill_card(guard_skill, defend_skill_card, defend_skill_icon, defend_meta_label, defend_cooldown_bar, defend_resource_bar, defend_cooldown_mask, hero_resolve, hero_resolve_max)
	_update_skill_card(burst_skill, burst_skill_card, burst_skill_icon, burst_meta_label, burst_cooldown_bar, burst_resource_bar, burst_cooldown_mask, hero_resolve, hero_resolve_max)
	_refresh_item_popup(battle_items)


func _capture_timeline_state(state: Dictionary, headline: String) -> void:
	_timeline.append({"state": state.duplicate(true), "headline": headline})


func _start_preview_playback() -> void:
	var nonce: int = _playback_nonce
	_log_lines.clear()
	_last_hp_by_entity.clear()
	_death_hold_by_entity.clear()
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
		_update_death_hold(entity_id, entity)
		var should_render: bool = is_alive or String(entity.get("side", "")) == "hero"
		if not should_render:
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
		var highlighted: bool = _selected_target_id == entity_id and String(entity.get("side", "enemy")) == "enemy" and _interactive_mode
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
		_death_hold_by_entity.erase(existing_id)
		_last_visual_position_by_entity.erase(existing_id)


func _apply_token_feedback(token: Control, entity_id: String, entity: Dictionary) -> void:
	var current_hp: float = float(entity.get("current_hp", 0.0))
	var is_alive: bool = bool(entity.get("is_alive", current_hp > 0.0))
	var previous_hp: float = float(_last_hp_by_entity.get(entity_id, current_hp))
	var feedback_type: String = ""
	var pulse_amount: float = 0.0
	var pulse_kind: String = "damage"
	if current_hp < previous_hp:
		feedback_type = "hit"
		pulse_amount = previous_hp - current_hp
		_feedback_counts["hit"] = int(_feedback_counts.get("hit", 0)) + 1
	elif current_hp > previous_hp:
		pulse_amount = current_hp - previous_hp
		pulse_kind = "heal"
	if not is_alive:
		feedback_type = "down"
		_feedback_counts["down"] = int(_feedback_counts.get("down", 0)) + 1
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
	_attack_line.visible = false
	if _attack_arrow != null:
		_attack_arrow.visible = false
	for entity_id: String in _arena_nodes.keys():
		var token: Control = _arena_nodes[entity_id]
		if token != null and token.has_method("set_targeted"):
			var side: String = "hero" if entity_id == "hero_1" else "enemy"
			var keep_selected: bool = _interactive_mode and entity_id == _selected_target_id and side == "enemy"
			token.call("set_targeted", keep_selected, side)

	var action: Dictionary = state.get("last_action", {})
	var action_signature: String = "%s|%s|%s|%s" % [
		str(action.get("actor_id", "")),
		str(action.get("target_id", "")),
		str(action.get("phase", "")),
		str(action.get("damage", ""))
	]
	if action_signature == _last_action_signature:
		return
	_last_action_signature = action_signature
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
	var direction: Vector2 = (target_point - source_point).normalized()
	var arrow_point: Vector2 = target_point - (direction * 34.0)
	_attack_line.clear_points()
	_attack_line.add_point(source_point)
	_attack_line.add_point(arrow_point)
	_attack_line.default_color = Color(1.0, 0.92, 0.42, 1.0) if String(action.get("actor_side", "hero")) == "hero" else Color(1.0, 0.42, 0.36, 0.96)
	_attack_line.visible = true
	_attack_line.modulate.a = 1.0
	if _attack_arrow != null:
		_attack_arrow.position = arrow_point
		_attack_arrow.rotation = direction.angle()
		_attack_arrow.color = _attack_line.default_color
		_attack_arrow.visible = true
		_attack_arrow.modulate.a = 1.0
	_combat_cue_counts["attack_lines"] = int(_combat_cue_counts.get("attack_lines", 0)) + 1
	if source_token.has_method("play_action_cue"):
		source_token.call("play_action_cue", "attack", String(action.get("actor_side", "hero")))
	if target_token.has_method("play_action_cue"):
		target_token.call("play_action_cue", "impact", String(action.get("target_side", "enemy")))
	if _attack_line_tween != null:
		_attack_line_tween.kill()
	_attack_line_tween = create_tween()
	_attack_line_tween.tween_interval(0.24)
	_attack_line_tween.parallel().tween_property(_attack_line, "modulate:a", 0.0, 0.48)
	if _attack_arrow != null:
		_attack_line_tween.parallel().tween_property(_attack_arrow, "modulate:a", 0.0, 0.48)
	_attack_line_tween.tween_callback(_hide_attack_line)
	if source_token.has_method("set_targeted"):
		source_token.call("set_targeted", true, String(action.get("actor_side", "hero")))
	if target_token.has_method("set_targeted"):
		target_token.call("set_targeted", true, String(action.get("target_side", "enemy")))


func _ensure_fx_nodes() -> void:
	if _attack_line != null:
		return
	_attack_line = Line2D.new()
	_attack_line.width = 8.0
	_attack_line.z_index = 20
	_attack_line.antialiased = true
	_attack_line.visible = false
	battle_arena.add_child(_attack_line)
	_attack_arrow = Polygon2D.new()
	_attack_arrow.polygon = PackedVector2Array([Vector2(0, 0), Vector2(-30, 14), Vector2(-30, -14)])
	_attack_arrow.z_index = 21
	_attack_arrow.visible = false
	battle_arena.add_child(_attack_arrow)


func _hide_attack_line() -> void:
	if _attack_line != null:
		_attack_line.visible = false
	if _attack_arrow != null:
		_attack_arrow.visible = false


func _update_death_hold(entity_id: String, entity: Dictionary) -> void:
	var current_hp: float = float(entity.get("current_hp", 0.0))
	var previous_hp: float = float(_last_hp_by_entity.get(entity_id, current_hp))
	var is_alive: bool = bool(entity.get("is_alive", current_hp > 0.0))
	if not is_alive and previous_hp > 0.0 and not _death_hold_by_entity.has(entity_id):
		_combat_cue_counts["death_fades"] = int(_combat_cue_counts.get("death_fades", 0)) + 1


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
	var row_y: float = (arena_size.y * 0.5) - 92.0
	var hero_lane_width: float = clamp(arena_size.x * 0.25, 170.0, 250.0)
	var gap_band_width: float = clamp(arena_size.x * 0.18, 130.0, 240.0)
	var hero_x: float = 24.0 + max(10.0, (hero_lane_width - 180.0) * 0.5)
	if side == "hero":
		return Vector2(hero_x, row_y)

	var entity_id: String = String(entity.get("entity_id", ""))
	var enemy_index: int = int(enemy_index_by_id.get(entity_id, 0))
	var enemy_scale: float = _formation_scale(entity, enemy_count, arena_size.x)
	var token_width: float = 180.0 * enemy_scale
	var base_gap: float = clamp(arena_size.x * 0.018, 10.0, 22.0)
	var available_start_x: float = 24.0 + hero_lane_width + gap_band_width
	var available_width: float = max(120.0, arena_size.x - available_start_x - 24.0)
	var total_width: float = (float(enemy_count) * token_width) + (float(max(0, enemy_count - 1)) * base_gap)
	var gap: float = base_gap
	if enemy_count > 1 and total_width > available_width:
		gap = max(6.0, (available_width - (float(enemy_count) * token_width)) / float(enemy_count - 1))
		total_width = (float(enemy_count) * token_width) + (float(enemy_count - 1) * gap)
	var start_x: float = available_start_x + max(0.0, (available_width - total_width) * 0.5)
	start_x = clamp(start_x, available_start_x, max(available_start_x, arena_size.x - total_width - 18.0))
	return Vector2(start_x + (float(enemy_index) * (token_width + gap)), row_y + ((1.0 - enemy_scale) * 36.0))


func _formation_scale(entity: Dictionary, enemy_count: int, arena_width: float) -> float:
	if String(entity.get("side", "enemy")) == "hero":
		return 1.0
	var base_scale := 0.96
	match enemy_count:
		0, 1:
			base_scale = 0.96
		2:
			base_scale = 0.88
		3:
			base_scale = 0.82
		4:
			base_scale = 0.76
		_:
			base_scale = 0.70
	var gap_band_width: float = clamp(arena_width * 0.16, 110.0, 220.0)
	var hero_lane_width: float = clamp(arena_width * 0.24, 160.0, 230.0)
	var available_width: float = max(120.0, arena_width - hero_lane_width - gap_band_width - 48.0)
	var preferred_gap: float = clamp(arena_width * 0.018, 10.0, 22.0)
	var total_gap: float = float(max(0, enemy_count - 1)) * preferred_gap
	var max_scale_for_width: float = (available_width - total_gap) / max(180.0, float(enemy_count) * 180.0)
	return clamp(min(base_scale, max_scale_for_width), 0.52, 0.96)


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
	var hero_lane_width: float = clamp(arena_size.x * 0.25, 170.0, 250.0)
	var gap_band_width: float = clamp(arena_size.x * 0.18, 130.0, 240.0)
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
		center_line.size = Vector2(4.0, bottom - top)


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
		"battle_a02_patrol":
			return "灰烬圣坛巡逻战"
		"battle_a02_forced_ambush":
			return "灰烬圣坛伏击战"
		_:
			return battle_id if not battle_id.is_empty() else "战斗预览"


func _set_interaction_enabled(enabled: bool) -> void:
	if status_label != null:
		status_label.visible = enabled
	if selected_target_label != null:
		selected_target_label.visible = enabled
	if attack_button != null:
		attack_button.visible = enabled
		attack_button.disabled = not enabled
	if defend_button != null:
		defend_button.visible = enabled
		defend_button.disabled = not enabled
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
		return


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
	if battle_items.size() == 1:
		_use_item_and_continue(String(battle_items[0].get("id", "")))
		return
	if item_popup_panel != null:
		var popup_target := Vector2(item_button.global_position.x - 188.0, item_button.global_position.y - 12.0)
		var viewport_rect := get_viewport().get_visible_rect()
		var popup_width := 348.0
		var popup_height: float = float(clamp((float(battle_items.size()) * 92.0) + 70.0, 140.0, 460.0))
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
	_update_interaction_hud(_interactive_state)


func _finish_interactive_battle(result: Dictionary) -> void:
	_set_interaction_enabled(false)
	_interactive_mode = false
	_resolving_enemy_phase = false
	emit_signal("interactive_battle_finished", result)


func _queue_enemy_phase_or_finish() -> void:
	if not _sim().is_battle_active(_interactive_state):
		_finish_interactive_battle(_decorate_result(_sim().build_result(_interactive_state, _interactive_context, "scene"), _interactive_state))
		return
	_resolving_enemy_phase = true
	_selected_target_id = ""
	_update_interaction_hud(_interactive_state)
	call_deferred("_resolve_enemy_phase_async")


func _on_battle_arena_resized() -> void:
	_layout_arena_regions()
	_refresh_arena_entities()


func _refresh_layout_after_frame() -> void:
	await get_tree().process_frame
	_layout_arena_regions()
	_refresh_arena_entities()


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
	if battle_items.is_empty():
		var empty_label := Label.new()
		empty_label.text = "当前没有可用战斗道具。"
		item_list_vbox.add_child(empty_label)
		return
	for stack_value in battle_items:
		if typeof(stack_value) != TYPE_DICTIONARY:
			continue
		var stack: Dictionary = stack_value
		item_list_vbox.add_child(_build_item_row(stack))


func _use_item_and_continue(item_id: String) -> void:
	if item_id.is_empty():
		return
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


func _update_skill_card(skill: Dictionary, card: Control, icon_node: TextureRect, meta_label: Label, cooldown_bar: ProgressBar, resource_bar: ProgressBar, cooldown_mask: ColorRect, hero_resolve: int, hero_resolve_max: int) -> void:
	if meta_label == null or cooldown_bar == null or resource_bar == null:
		return
	if skill.is_empty():
		meta_label.text = "技能未配置"
		if card != null:
			card.modulate = Color(1, 1, 1, 1)
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
	var enough_resource: bool = hero_resolve >= resource_cost
	meta_label.text = "冷却 %d/%d | 灵势 %d/%d | %s" % [
		cooldown_remaining,
		cooldown_max,
		hero_resolve,
		resource_cost,
		String(skill.get("description", ""))
	]
	meta_label.modulate = Color(1.0, 0.52, 0.52, 1.0) if not enough_resource else Color(0.86, 0.88, 0.94, 1.0)
	cooldown_bar.max_value = cooldown_max
	cooldown_bar.value = max(0, cooldown_max - cooldown_remaining)
	resource_bar.max_value = max(resource_cost, hero_resolve_max)
	resource_bar.value = hero_resolve
	cooldown_bar.modulate = Color(0.62, 0.78, 1.0, 1.0)
	resource_bar.modulate = Color(0.96, 0.74, 0.34, 1.0) if enough_resource else Color(1.0, 0.42, 0.42, 1.0)
	if icon_node != null:
		icon_node.texture = DEFAULT_SKILL_ICON
		match String(skill.get("slot", "")):
			"guard":
				icon_node.modulate = Color(0.54, 0.76, 1.0, 1.0)
			"burst":
				icon_node.modulate = Color(1.0, 0.62, 0.34, 1.0)
			_:
				icon_node.modulate = Color(1.0, 0.84, 0.46, 1.0)
	if cooldown_mask != null:
		cooldown_mask.color = Color(0.05, 0.07, 0.11, 0.42) if cooldown_remaining > 0 else Color(0.05, 0.07, 0.11, 0.0)
	if card != null:
		card.modulate = Color(1.0, 0.78, 0.78, 1.0) if not enough_resource else Color(1, 1, 1, 1)


func _build_item_row(stack: Dictionary) -> Control:
	var row := PanelContainer.new()
	row.custom_minimum_size = Vector2(0, 92)
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 8)
	row.add_child(margin)
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	margin.add_child(hbox)
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(40, 40)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var icon_path: String = String(stack.get("icon_path", "res://icon.svg"))
	if ResourceLoader.exists(icon_path):
		var loaded: Resource = load(icon_path)
		if loaded is Texture2D:
			icon.texture = loaded
	hbox.add_child(icon)
	var text_box := VBoxContainer.new()
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_box.add_theme_constant_override("separation", 2)
	hbox.add_child(text_box)
	var title := Label.new()
	title.text = "%s x%d" % [String(stack.get("name_cn", stack.get("id", ""))), int(stack.get("count", 0))]
	title.add_theme_font_size_override("font_size", 15)
	text_box.add_child(title)
	var desc := Label.new()
	desc.text = String(stack.get("description", ""))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_font_size_override("font_size", 12)
	text_box.add_child(desc)
	var target := Label.new()
	target.text = String(stack.get("target_type", "目标：即时生效"))
	target.add_theme_font_size_override("font_size", 12)
	text_box.add_child(target)
	var use_button := Button.new()
	use_button.custom_minimum_size = Vector2(76, 34)
	use_button.text = "使用"
	use_button.pressed.connect(func() -> void:
		_use_item_and_continue(String(stack.get("id", "")))
	)
	hbox.add_child(use_button)
	_bind_card_click_target(row, Callable(self, "_use_item_and_continue").bind(String(stack.get("id", ""))), use_button)
	return row


func _build_action_deck() -> void:
	if action_bar == null or root_vbox == null or _action_deck_panel != null:
		return
	var old_index: int = action_bar.get_index()
	_action_deck_panel = PanelContainer.new()
	_action_deck_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.11, 0.08, 0.96)
	style.border_color = Color(0.53, 0.42, 0.18, 1.0)
	style.set_border_width_all(2)
	style.corner_radius_top_left = 18
	style.corner_radius_top_right = 18
	style.corner_radius_bottom_left = 18
	style.corner_radius_bottom_right = 18
	_action_deck_panel.add_theme_stylebox_override("panel", style)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_bottom", 14)
	_action_deck_panel.add_child(margin)

	action_bar.reparent(margin)
	root_vbox.add_child(_action_deck_panel)
	root_vbox.move_child(_action_deck_panel, old_index)

	action_bar.add_theme_constant_override("separation", 20)
	if action_info_box != null:
		action_info_box.add_theme_constant_override("separation", 8)
	if command_strip != null:
		command_strip.add_theme_constant_override("separation", 12)
		_ensure_burst_skill_card()
	if status_label != null:
		status_label.add_theme_font_size_override("font_size", 16)
	if selected_target_label != null:
		selected_target_label.add_theme_font_size_override("font_size", 16)
	_style_action_button(wait_button, Color(0.23, 0.27, 0.19, 1.0), Color(0.62, 0.74, 0.42, 1.0))
	_style_action_button(item_button, Color(0.18, 0.22, 0.30, 1.0), Color(0.44, 0.62, 0.88, 1.0))
	_style_skill_card(attack_skill_card, Color(0.24, 0.15, 0.12, 1.0), Color(0.72, 0.46, 0.22, 1.0))
	_style_skill_card(defend_skill_card, Color(0.12, 0.18, 0.24, 1.0), Color(0.34, 0.56, 0.82, 1.0))
	_style_skill_card(burst_skill_card, Color(0.26, 0.12, 0.10, 1.0), Color(0.90, 0.50, 0.18, 1.0))


func _style_action_button(button: Button, bg: Color, border: Color) -> void:
	if button == null:
		return
	var normal := StyleBoxFlat.new()
	normal.bg_color = bg
	normal.border_color = border
	normal.set_border_width_all(2)
	normal.corner_radius_top_left = 12
	normal.corner_radius_top_right = 12
	normal.corner_radius_bottom_left = 12
	normal.corner_radius_bottom_right = 12
	var hover := normal.duplicate()
	hover.bg_color = bg.lightened(0.08)
	var pressed := normal.duplicate()
	pressed.bg_color = bg.darkened(0.08)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("disabled", pressed)
	button.add_theme_font_size_override("font_size", 17)


func _style_skill_card(card: Control, bg: Color, border: Color) -> void:
	if card == null or not (card is PanelContainer):
		return
	var panel := card as PanelContainer
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(2)
	style.corner_radius_top_left = 14
	style.corner_radius_top_right = 14
	style.corner_radius_bottom_left = 14
	style.corner_radius_bottom_right = 14
	panel.add_theme_stylebox_override("panel", style)


func _ensure_burst_skill_card() -> void:
	if command_strip == null or burst_skill_card != null:
		return
	var insert_index: int = command_strip.get_children().find(wait_button)
	if insert_index < 0:
		insert_index = command_strip.get_child_count()
	var card := PanelContainer.new()
	card.name = "BurstSkillCard"
	card.custom_minimum_size = Vector2(190, 0)
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

	var resource_bar := ProgressBar.new()
	resource_bar.name = "BurstResourceBar"
	resource_bar.custom_minimum_size = Vector2(0, 8)
	resource_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	resource_bar.show_percentage = false
	resource_row.add_child(resource_bar)
	burst_resource_bar = resource_bar


func _bind_clickable_cards() -> void:
	_bind_card_click_target(attack_skill_card, Callable(self, "_on_attack_pressed"), attack_button)
	_bind_card_click_target(defend_skill_card, Callable(self, "_on_defend_pressed"), defend_button)
	_bind_card_click_target(burst_skill_card, Callable(self, "_on_burst_pressed"), burst_button)


func _bind_card_click_target(card: Control, action: Callable, exclude_button: Button = null) -> void:
	if card == null:
		return
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	_set_descendants_mouse_filter(card, exclude_button)
	if not card.gui_input.is_connected(_on_card_gui_input.bind(action, exclude_button)):
		card.gui_input.connect(_on_card_gui_input.bind(action, exclude_button))


func _set_descendants_mouse_filter(node: Node, exclude_button: Button) -> void:
	for child: Node in node.get_children():
		if child == exclude_button:
			continue
		if child is Control:
			var control := child as Control
			control.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_set_descendants_mouse_filter(child, exclude_button)


func _on_card_gui_input(event: InputEvent, action: Callable, exclude_button: Button = null) -> void:
	if event is not InputEventMouseButton:
		return
	var mouse_event := event as InputEventMouseButton
	if mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed:
		return
	if exclude_button != null and exclude_button.get_global_rect().has_point(mouse_event.global_position):
		return
	action.call()
