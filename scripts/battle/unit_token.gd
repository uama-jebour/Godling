extends Control

signal token_pressed(entity_id: String)

const PORTRAITS := {
	"hero_pilgrim_a01": preload("res://assets/battle/placeholders/hero_pilgrim_a01.svg"),
	"enemy_hollow_deacon": preload("res://assets/battle/placeholders/enemy_hollow_deacon.svg"),
	"enemy_ashen_hunter": preload("res://assets/battle/placeholders/enemy_ashen_hunter.svg"),
	"enemy_demon_stalker": preload("res://assets/battle/placeholders/enemy_demon_stalker.svg")
}
const DEFAULT_ICONS := {
	"hero": preload("res://icon.svg"),
	"enemy": preload("res://icon.svg")
}

@onready var role_icon_bg: ColorRect = $RoleIconBg
@onready var role_icon: TextureRect = %RoleIcon
@onready var portrait: TextureRect = %Portrait
@onready var target_glow: ColorRect = %TargetGlow
@onready var damage_label: Label = %DamageLabel
@onready var overlay: ColorRect = $Overlay
@onready var shadow: ColorRect = $Shadow
@onready var name_label: Label = %NameLabel
@onready var hp_bar: ProgressBar = %HPBar
@onready var meta_label: Label = %MetaLabel

var _base_scale := Vector2.ONE
var _default_rotation := 0.0
var _entity_id := ""
var _damage_tween: Tween
var _action_tween: Tween
var _focus_tween: Tween
var _battle_scale := 1.0
var _drop_validator: Callable = Callable()
var _drop_handler: Callable = Callable()


func _ready() -> void:
	_base_scale = scale
	_default_rotation = rotation
	_apply_line_theme()


func _apply_line_theme() -> void:
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.18, 0.26, 0.36, 0.92)
	fill.border_color = Color(0.34, 0.60, 0.86, 0.78)
	fill.set_border_width_all(1)
	fill.corner_radius_top_left = 4
	fill.corner_radius_top_right = 4
	fill.corner_radius_bottom_left = 4
	fill.corner_radius_bottom_right = 4
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.06, 0.09, 0.14, 0.96)
	bg.border_color = Color(0.22, 0.34, 0.48, 0.84)
	bg.set_border_width_all(1)
	bg.corner_radius_top_left = 4
	bg.corner_radius_top_right = 4
	bg.corner_radius_bottom_left = 4
	bg.corner_radius_bottom_right = 4
	hp_bar.add_theme_stylebox_override("fill", fill)
	hp_bar.add_theme_stylebox_override("background", bg)


func configure_token(entity: Dictionary) -> void:
	var current_hp: float = float(entity.get("current_hp", 0.0))
	var max_hp: float = max(1.0, float(entity.get("max_hp", 1.0)))
	var side: String = String(entity.get("side", "enemy"))
	var is_alive: bool = bool(entity.get("is_alive", current_hp > 0.0))
	var unit_id: String = String(entity.get("unit_id", ""))
	var visual_def: Dictionary = _visual_def(unit_id)
	_entity_id = String(entity.get("entity_id", ""))

	portrait.texture = _resolve_portrait(unit_id, visual_def)
	var flip_override: Variant = visual_def.get("flip_h", null)
	if typeof(flip_override) == TYPE_BOOL:
		portrait.flip_h = bool(flip_override)
	else:
		portrait.flip_h = false
	_apply_visual_layout(side, visual_def)
	name_label.text = String(entity.get("display_name", unit_id))
	hp_bar.max_value = max_hp
	hp_bar.value = clamp(current_hp, 0.0, max_hp)
	meta_label.text = "%.1f / %.1f" % [current_hp, max_hp]

	if side == "hero":
		overlay.color = Color(0.07, 0.12, 0.18, 0.74)
		name_label.modulate = Color(0.90, 0.96, 1.0, 1.0)
		role_icon_bg.color = Color(0.12, 0.28, 0.42, 0.86)
	else:
		overlay.color = Color(0.16, 0.08, 0.12, 0.74)
		name_label.modulate = Color(1.0, 0.91, 0.94, 1.0)
		role_icon_bg.color = Color(0.42, 0.14, 0.24, 0.86)

	portrait.modulate = Color(1, 1, 1, 1) if is_alive else Color(0.52, 0.52, 0.52, 0.82)
	shadow.color = Color(0.01, 0.01, 0.01, 0.30) if is_alive else Color(0.01, 0.01, 0.01, 0.18)
	target_glow.color = Color(1, 0.95, 0.64, 0.0)
	modulate = Color(1, 1, 1, 1)
	scale = (_base_scale * _battle_scale) if is_alive else (_base_scale * _battle_scale * 0.94)


func _gui_input(event: InputEvent) -> void:
	if _entity_id.is_empty():
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		emit_signal("token_pressed", _entity_id)


func set_drop_callbacks(validator: Callable, handler: Callable) -> void:
	_drop_validator = validator
	_drop_handler = handler


const DROP_MARGIN_EXPAND := 16.0

var _drop_hover_active := false
var _drop_hover_tween: Tween


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if _entity_id.is_empty() or not _drop_validator.is_valid():
		return false
	return bool(_drop_validator.call(_entity_id, data))


func _get_minimum_size() -> Vector2:
	return Vector2(248, 284) + Vector2(DROP_MARGIN_EXPAND, DROP_MARGIN_EXPAND)


func notify_drag_hover(is_hovering: bool, can_accept: bool) -> void:
	if _drop_hover_active == is_hovering and target_glow.color.a > 0.0:
		return
	_drop_hover_active = is_hovering
	if _drop_hover_tween != null:
		_drop_hover_tween.kill()
	_drop_hover_tween = create_tween()
	_drop_hover_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if is_hovering and can_accept:
		var hover_color := Color(0.36, 0.88, 0.56, 0.34)
		_drop_hover_tween.parallel().tween_property(target_glow, "color", hover_color, 0.12)
		_drop_hover_tween.parallel().tween_property(self, "scale", _base_scale * _battle_scale * Vector2(1.04, 1.04), 0.12)
	else:
		_drop_hover_tween.parallel().tween_property(target_glow, "color", Color(1, 0.95, 0.64, 0.0), 0.18)
		_drop_hover_tween.parallel().tween_property(self, "scale", _base_scale * _battle_scale, 0.18)


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if _entity_id.is_empty() or not _drop_handler.is_valid():
		return
	_drop_handler.call(_entity_id, data)


func apply_feedback(feedback_type: String) -> void:
	match feedback_type:
		"hit":
			scale = _base_scale * Vector2(1.08, 1.08)
			modulate = Color(1.16, 0.92, 0.92, 1.0)
		"down":
			scale = _base_scale * _battle_scale * Vector2(0.90, 0.90)
			modulate = Color(0.72, 0.72, 0.72, 0.76)
		_:
			scale = _base_scale * _battle_scale
			modulate = Color(1, 1, 1, 1)


func play_action_cue(cue_type: String, side: String = "hero") -> void:
	if _action_tween != null:
		_action_tween.kill()
	var direction := 1.0 if side == "hero" else -1.0
	var portrait_home: Vector2 = portrait.position
	var glow_home: Color = target_glow.color
	var overlay_home: Color = overlay.color
	_action_tween = create_tween()
	match cue_type:
		"attack":
			target_glow.color = Color(1.0, 0.80, 0.34, 0.24)
			_action_tween.parallel().tween_property(portrait, "position:x", portrait_home.x + (18.0 * direction), 0.12)
			_action_tween.parallel().tween_property(self, "scale", _base_scale * _battle_scale * Vector2(1.05, 1.05), 0.12)
			_action_tween.parallel().tween_property(overlay, "color", overlay_home.lerp(Color(0.62, 0.22, 0.16, 0.78), 0.55), 0.12)
			_action_tween.tween_interval(0.05)
			_action_tween.parallel().tween_property(portrait, "position", portrait_home, 0.18)
			_action_tween.parallel().tween_property(self, "scale", _base_scale * _battle_scale, 0.18)
			_action_tween.parallel().tween_property(overlay, "color", overlay_home, 0.18)
		"defend":
			target_glow.color = Color(0.52, 0.76, 1.0, 0.22)
			_action_tween.parallel().tween_property(self, "scale", _base_scale * _battle_scale * Vector2(0.98, 1.06), 0.16)
			_action_tween.parallel().tween_property(overlay, "color", overlay_home.lerp(Color(0.16, 0.24, 0.38, 0.82), 0.65), 0.16)
			_action_tween.tween_interval(0.08)
			_action_tween.parallel().tween_property(self, "scale", _base_scale * _battle_scale, 0.22)
			_action_tween.parallel().tween_property(overlay, "color", overlay_home, 0.22)
		"impact":
			target_glow.color = Color(1.0, 0.56, 0.44, 0.26)
			_action_tween.parallel().tween_property(self, "scale", _base_scale * _battle_scale * Vector2(1.10, 0.96), 0.08)
			_action_tween.parallel().tween_property(overlay, "color", overlay_home.lerp(Color(0.55, 0.18, 0.18, 0.88), 0.55), 0.08)
			_action_tween.tween_interval(0.05)
			_action_tween.parallel().tween_property(self, "scale", _base_scale * _battle_scale, 0.18)
			_action_tween.parallel().tween_property(overlay, "color", overlay_home, 0.18)
		_:
			return
	_action_tween.tween_callback(func() -> void:
		target_glow.color = glow_home
		overlay.color = overlay_home
		portrait.position = portrait_home
		scale = _base_scale * _battle_scale
	)


func show_value_pulse(value: float, pulse_kind: String = "damage") -> void:
	if damage_label == null:
		return
	damage_label.visible = true
	damage_label.position = Vector2(54.0, 10.0)
	damage_label.modulate = Color(1, 1, 1, 1)
	if pulse_kind == "heal":
		damage_label.text = "+%.0f" % abs(value)
		damage_label.modulate = Color(0.58, 1.0, 0.70, 1.0)
	else:
		damage_label.text = "-%.0f" % abs(value)
		damage_label.modulate = Color(1.0, 0.84, 0.50, 1.0)
	if _damage_tween != null:
		_damage_tween.kill()
	_damage_tween = create_tween()
	_damage_tween.parallel().tween_property(damage_label, "position:y", -8.0, 0.42)
	_damage_tween.parallel().tween_property(damage_label, "modulate:a", 0.0, 0.42)
	_damage_tween.tween_callback(func() -> void:
		damage_label.visible = false
		damage_label.modulate.a = 1.0
	)


func apply_motion_pose(motion: Dictionary) -> void:
	var side: String = String(motion.get("side", "enemy"))
	var is_alive: bool = bool(motion.get("is_alive", true))
	var attack_phase: bool = bool(motion.get("attack_phase", false))
	var lean: float = float(motion.get("lean", 0.0))
	var pulse: float = float(motion.get("pulse", 1.0))

	if not is_alive:
		rotation = _default_rotation
		return

	var direction := 1.0 if side == "hero" else -1.0
	rotation = _default_rotation + (0.025 * direction * lean)
	if attack_phase:
		scale *= Vector2(pulse, pulse)


func set_battle_scale(scale_value: float) -> void:
	_battle_scale = max(0.74, scale_value)
	scale = _base_scale * _battle_scale


func set_targeted(is_targeted: bool, side: String) -> void:
	if not is_targeted:
		target_glow.color = Color(1, 0.95, 0.64, 0.0)
		_stop_focus_pulse()
		overlay.modulate = Color(1, 1, 1, 1)
		scale = _base_scale * _battle_scale
		return
	if side == "hero":
		target_glow.color = Color(0.66, 0.90, 1.0, 0.42)
		_start_focus_pulse(Color(0.66, 0.90, 1.0, 0.36), Color(0.66, 0.90, 1.0, 0.56))
	else:
		target_glow.color = Color(1.0, 0.62, 0.54, 0.42)
		_start_focus_pulse(Color(1.0, 0.62, 0.54, 0.36), Color(1.0, 0.62, 0.54, 0.56))


func _start_focus_pulse(min_color: Color, max_color: Color) -> void:
	if _focus_tween != null:
		_focus_tween.kill()
	scale = _base_scale * _battle_scale * Vector2(1.02, 1.02)
	overlay.modulate = Color(1.06, 1.06, 1.08, 1.0)
	_focus_tween = create_tween()
	_focus_tween.set_loops()
	_focus_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_focus_tween.parallel().tween_property(target_glow, "color", max_color, 0.36)
	_focus_tween.parallel().tween_property(self, "scale", _base_scale * _battle_scale * Vector2(1.035, 1.035), 0.36)
	_focus_tween.tween_interval(0.02)
	_focus_tween.parallel().tween_property(target_glow, "color", min_color, 0.36)
	_focus_tween.parallel().tween_property(self, "scale", _base_scale * _battle_scale * Vector2(1.015, 1.015), 0.36)


func _stop_focus_pulse() -> void:
	if _focus_tween != null:
		_focus_tween.kill()
		_focus_tween = null


func _resolve_portrait(unit_id: String, visual_def: Dictionary) -> Texture2D:
	var portrait_path: String = String(visual_def.get("portrait_path", ""))
	if not portrait_path.is_empty() and ResourceLoader.exists(portrait_path):
		var loaded: Resource = load(portrait_path)
		if loaded is Texture2D:
			return loaded
	return PORTRAITS.get(unit_id, PORTRAITS.get("enemy_hollow_deacon"))


func _visual_def(unit_id: String) -> Dictionary:
	var content_db := get_node_or_null("/root/ContentDB")
	if content_db != null and content_db.has_method("get_unit_visual"):
		return content_db.get_unit_visual(unit_id)
	return {}


func _apply_visual_layout(side: String, visual_def: Dictionary) -> void:
	var portrait_scale: float = float(visual_def.get("portrait_scale", 1.0))
	var offset_y: float = float(visual_def.get("y_offset", 0.0))
	var offset_x: float = float(visual_def.get("x_offset", 0.0))
	portrait.scale = Vector2(portrait_scale, portrait_scale)
	portrait.position = Vector2(offset_x, offset_y)

	var icon_path: String = String(visual_def.get("icon_path", ""))
	if not icon_path.is_empty() and ResourceLoader.exists(icon_path):
		var loaded: Resource = load(icon_path)
		if loaded is Texture2D:
			role_icon.texture = loaded
			return
	role_icon.texture = DEFAULT_ICONS.get(side, DEFAULT_ICONS.get("enemy"))
