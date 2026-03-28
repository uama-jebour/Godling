extends Control

signal token_pressed(entity_id: String)

const HitParticles := preload("res://scenes/battle/hit_particles.tscn")

const PORTRAITS := {
	"hero_pilgrim_a01": preload("res://assets/battle/placeholders/hero_pilgrim_a01.svg"),
	"enemy_hollow_deacon": preload("res://assets/battle/placeholders/enemy_hollow_deacon.svg"),
	"enemy_ashen_hunter": preload("res://assets/battle/placeholders/enemy_ashen_hunter.svg"),
	"enemy_demon_stalker": preload("res://assets/battle/placeholders/enemy_demon_stalker.svg")
}
const DEFAULT_ICONS := {
	"hero": preload("res://icon.svg"),
	"ally": preload("res://icon.svg"),
	"enemy": preload("res://icon.svg")
}
const TOKEN_CARD_SIZE := Vector2(100, 112)
const TOKEN_VISIBLE_BASELINE_PADDING := 6.0
const TOKEN_ALPHA_CROP_PADDING := 8
const HP_BAR_TO_PORTRAIT_GAP := 2.0
const NAME_PLATE_TO_PORTRAIT_GAP := 2.0
const NAME_LABEL_TOP_INSET := 3.0
const BASE_PLATE_SHADOW_TOP_INSET := 2.0
const BASE_PLATE_SHADOW_BOTTOM_INSET := 1.0
const BASE_PLATE_TRIM_TOP_INSET := 1.0
const BASE_PLATE_TRIM_HEIGHT := 6.0
const BASE_PLATE_OVERLAY_TOP_INSET := 2.0
const BASE_PLATE_OVERLAY_BOTTOM_INSET := 4.0

@onready var role_icon_bg: ColorRect = $RoleIconBg
@onready var role_icon: TextureRect = %RoleIcon
@onready var portrait: TextureRect = %Portrait
@onready var target_glow: TextureRect = %TargetGlow
@onready var damage_label: Label = %DamageLabel
@onready var base_plate_shadow: Panel = $BasePlateShadow
@onready var base_plate_frame: Panel = $BasePlateFrame
@onready var base_plate_trim: Panel = $BasePlateTrim
@onready var overlay: ColorRect = $Overlay
@onready var shadow: ColorRect = $Shadow
@onready var name_label: Label = %NameLabel
@onready var hp_bar: ProgressBar = %HPBar
@onready var meta_label: Label = %MetaLabel

var _particles_layer: Node
var _base_scale := Vector2.ONE
var _default_rotation := 0.0
var _entity_id := ""
var _damage_tween: Tween
var _action_tween: Tween
var _focus_tween: Tween
var _battle_scale := 1.0
var _drop_validator: Callable = Callable()
var _drop_handler: Callable = Callable()
var _cached_portrait_unit_id := ""
var _cached_portrait: Texture2D
var _cached_portrait_bounds_key := ""
var _cached_portrait_content_bounds: Dictionary = {}
var _target_glow_material: ShaderMaterial


func _ready() -> void:
	_base_scale = scale
	_default_rotation = rotation
	if shadow != null:
		shadow.visible = false
	_setup_target_glow_material()
	_apply_line_theme()
	_setup_particles_layer()


func _setup_particles_layer() -> void:
	# 获取或创建粒子层（在场景树的顶层，避免被父节点的变换影响）
	var root := get_tree().root
	_particles_layer = root.get_node_or_null("ParticlesLayer")
	if _particles_layer == null:
		_particles_layer = Node2D.new()
		_particles_layer.name = "ParticlesLayer"
		_particles_layer.z_index = 100  # 确保在最上层
		root.add_child(_particles_layer)


func play_hit_particles() -> void:
	if _particles_layer == null or HitParticles == null:
		return

	var particles: CPUParticles2D = HitParticles.instantiate()
	_particles_layer.add_child(particles)

	# 将单位的全局位置转换为粒子层的本地位置
	var global_pos := global_position + size * 0.5
	particles.global_position = global_pos

	# 随机微调颜色（通过调整HSL）
	var color_variation := randf_range(-0.1, 0.1)
	particles.color = Color(
		clampf(particles.color.r + color_variation, 0.8, 1.0),
		clampf(particles.color.g - color_variation * 0.5, 0.1, 0.5),
		clampf(particles.color.b - color_variation * 0.3, 0.1, 0.3),
		particles.color.a
	)

	particles.emitting = true

	# 粒子播放完毕后自动删除
	await get_tree().create_timer(particles.lifetime + 0.1).timeout
	if is_instance_valid(particles):
		particles.queue_free()


func _apply_line_theme() -> void:
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.22, 0.33, 0.42, 0.96)
	fill.border_color = Color(0.58, 0.71, 0.78, 0.96)
	fill.set_border_width_all(1)
	fill.corner_radius_top_left = 3
	fill.corner_radius_top_right = 3
	fill.corner_radius_bottom_left = 3
	fill.corner_radius_bottom_right = 3
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.07, 0.08, 0.10, 0.98)
	bg.border_color = Color(0.34, 0.38, 0.42, 0.96)
	bg.set_border_width_all(1)
	bg.corner_radius_top_left = 3
	bg.corner_radius_top_right = 3
	bg.corner_radius_bottom_left = 3
	bg.corner_radius_bottom_right = 3
	hp_bar.add_theme_stylebox_override("fill", fill)
	hp_bar.add_theme_stylebox_override("background", bg)
	_apply_base_plate_theme(Color(0.48, 0.63, 0.74, 0.96), Color(0.18, 0.26, 0.34, 0.98))


func configure_token(entity: Dictionary) -> void:
	var current_hp: float = float(entity.get("current_hp", 0.0))
	var max_hp: float = max(1.0, float(entity.get("max_hp", 1.0)))
	var side: String = String(entity.get("side", "enemy"))
	var is_friendly := side == "hero" or side == "ally"
	var is_alive: bool = bool(entity.get("is_alive", current_hp > 0.0))
	var unit_id: String = String(entity.get("unit_id", ""))
	var visual_def: Dictionary = _visual_def(unit_id)
	_entity_id = String(entity.get("entity_id", ""))

	if _cached_portrait_unit_id != unit_id or _cached_portrait == null:
		_cached_portrait_unit_id = unit_id
		_cached_portrait = _resolve_portrait(unit_id, visual_def)
	portrait.texture = _cached_portrait
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
	meta_label.visible = false

	if is_friendly:
		overlay.color = Color(0.07, 0.12, 0.18, 0.74)
		name_label.modulate = Color(0.90, 0.96, 1.0, 1.0)
		role_icon_bg.color = Color(0.12, 0.28, 0.42, 0.86)
		_apply_base_plate_theme(Color(0.54, 0.74, 0.88, 0.96), Color(0.14, 0.22, 0.31, 0.98))
	else:
		overlay.color = Color(0.16, 0.08, 0.12, 0.74)
		name_label.modulate = Color(1.0, 0.91, 0.94, 1.0)
		role_icon_bg.color = Color(0.42, 0.14, 0.24, 0.86)
		_apply_base_plate_theme(Color(0.88, 0.56, 0.52, 0.96), Color(0.30, 0.15, 0.18, 0.98))

	portrait.modulate = Color(1, 1, 1, 1) if is_alive else Color(0.52, 0.52, 0.52, 0.82)
	_set_target_glow(Color(1, 0.95, 0.64, 0.0))
	modulate = Color(1, 1, 1, 1)
	scale = (_base_scale * _battle_scale) if is_alive else (_base_scale * _battle_scale * 0.94)


func _apply_base_plate_theme(accent: Color, frame_fill: Color) -> void:
	if base_plate_shadow != null:
		var shadow_style := StyleBoxFlat.new()
		shadow_style.bg_color = Color(0.01, 0.01, 0.01, 0.34)
		shadow_style.corner_radius_top_left = 9
		shadow_style.corner_radius_top_right = 9
		shadow_style.corner_radius_bottom_left = 12
		shadow_style.corner_radius_bottom_right = 12
		base_plate_shadow.add_theme_stylebox_override("panel", shadow_style)
	if base_plate_frame != null:
		var frame_style := StyleBoxFlat.new()
		frame_style.bg_color = frame_fill
		frame_style.border_color = accent.darkened(0.18)
		frame_style.set_border_width_all(2)
		frame_style.corner_radius_top_left = 9
		frame_style.corner_radius_top_right = 9
		frame_style.corner_radius_bottom_left = 12
		frame_style.corner_radius_bottom_right = 12
		base_plate_frame.add_theme_stylebox_override("panel", frame_style)
	if base_plate_trim != null:
		var trim_style := StyleBoxFlat.new()
		trim_style.bg_color = accent
		trim_style.corner_radius_top_left = 5
		trim_style.corner_radius_top_right = 5
		trim_style.corner_radius_bottom_left = 5
		trim_style.corner_radius_bottom_right = 5
		base_plate_trim.add_theme_stylebox_override("panel", trim_style)


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
	return TOKEN_CARD_SIZE + Vector2(DROP_MARGIN_EXPAND, DROP_MARGIN_EXPAND)


func notify_drag_hover(is_hovering: bool, can_accept: bool) -> void:
	if _drop_hover_active == is_hovering and target_glow.modulate.a > 0.0:
		return
	_drop_hover_active = is_hovering
	if _drop_hover_tween != null:
		_drop_hover_tween.kill()
	_drop_hover_tween = create_tween()
	_drop_hover_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if is_hovering and can_accept:
		var hover_color := Color(0.36, 0.88, 0.56, 0.34)
		_drop_hover_tween.parallel().tween_method(Callable(self, "_set_target_glow"), target_glow.modulate, hover_color, 0.12)
		_drop_hover_tween.parallel().tween_property(self, "scale", _base_scale * _battle_scale * Vector2(1.04, 1.04), 0.12)
	else:
		_drop_hover_tween.parallel().tween_method(Callable(self, "_set_target_glow"), target_glow.modulate, Color(1, 0.95, 0.64, 0.0), 0.18)
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
	var direction := -1.0 if side == "enemy" else 1.0
	var portrait_home: Vector2 = portrait.position
	var glow_home: Color = target_glow.modulate
	var overlay_home: Color = overlay.color
	_action_tween = create_tween()
	match cue_type:
		"attack":
			_set_target_glow(Color(1.0, 0.80, 0.34, 0.24))
			_action_tween.parallel().tween_property(portrait, "position:x", portrait_home.x + (18.0 * direction), 0.12)
			_action_tween.parallel().tween_property(self, "scale", _base_scale * _battle_scale * Vector2(1.05, 1.05), 0.12)
			_action_tween.parallel().tween_property(overlay, "color", overlay_home.lerp(Color(0.62, 0.22, 0.16, 0.78), 0.55), 0.12)
			_action_tween.tween_interval(0.05)
			_action_tween.parallel().tween_property(portrait, "position", portrait_home, 0.18)
			_action_tween.parallel().tween_property(self, "scale", _base_scale * _battle_scale, 0.18)
			_action_tween.parallel().tween_property(overlay, "color", overlay_home, 0.18)
		"defend":
			_set_target_glow(Color(0.52, 0.76, 1.0, 0.22))
			_action_tween.parallel().tween_property(self, "scale", _base_scale * _battle_scale * Vector2(0.98, 1.06), 0.16)
			_action_tween.parallel().tween_property(overlay, "color", overlay_home.lerp(Color(0.16, 0.24, 0.38, 0.82), 0.65), 0.16)
			_action_tween.tween_interval(0.08)
			_action_tween.parallel().tween_property(self, "scale", _base_scale * _battle_scale, 0.22)
			_action_tween.parallel().tween_property(overlay, "color", overlay_home, 0.22)
		"impact":
			_set_target_glow(Color(1.0, 0.56, 0.44, 0.26))
			_action_tween.parallel().tween_property(self, "scale", _base_scale * _battle_scale * Vector2(1.10, 0.96), 0.08)
			_action_tween.parallel().tween_property(overlay, "color", overlay_home.lerp(Color(0.55, 0.18, 0.18, 0.88), 0.55), 0.08)
			_action_tween.tween_interval(0.05)
			_action_tween.parallel().tween_property(self, "scale", _base_scale * _battle_scale, 0.18)
			_action_tween.parallel().tween_property(overlay, "color", overlay_home, 0.18)
		_:
			return
	_action_tween.tween_callback(func() -> void:
		_set_target_glow(glow_home)
		overlay.color = overlay_home
		portrait.position = portrait_home
		scale = _base_scale * _battle_scale
	)


func show_value_pulse(value: float, pulse_kind: String = "damage") -> void:
	if damage_label == null:
		return
	damage_label.visible = true
	damage_label.position = Vector2((TOKEN_CARD_SIZE.x * 0.5) - 24.0, 6.0)
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

	var direction := -1.0 if side == "enemy" else 1.0
	rotation = _default_rotation + (0.025 * direction * lean)
	if attack_phase:
		scale *= Vector2(pulse, pulse)


func set_battle_scale(scale_value: float) -> void:
	_battle_scale = max(0.68, scale_value)
	scale = _base_scale * _battle_scale


func set_targeted(is_targeted: bool, side: String) -> void:
	if not is_targeted:
		_set_target_glow(Color(1, 0.95, 0.64, 0.0))
		_stop_focus_pulse()
		overlay.modulate = Color(1, 1, 1, 1)
		scale = _base_scale * _battle_scale
		return
	if side == "hero" or side == "ally":
		_set_target_glow(Color(0.66, 0.90, 1.0, 0.42))
		_start_focus_pulse(Color(0.66, 0.90, 1.0, 0.36), Color(0.66, 0.90, 1.0, 0.56))
	else:
		_set_target_glow(Color(1.0, 0.62, 0.54, 0.42))
		_start_focus_pulse(Color(1.0, 0.62, 0.54, 0.36), Color(1.0, 0.62, 0.54, 0.56))


func _start_focus_pulse(min_color: Color, max_color: Color) -> void:
	if _focus_tween != null:
		_focus_tween.kill()
	scale = _base_scale * _battle_scale * Vector2(1.02, 1.02)
	overlay.modulate = Color(1.06, 1.06, 1.08, 1.0)
	_focus_tween = create_tween()
	_focus_tween.set_loops()
	_focus_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_focus_tween.parallel().tween_method(Callable(self, "_set_target_glow"), target_glow.modulate, max_color, 0.36)
	_focus_tween.parallel().tween_property(self, "scale", _base_scale * _battle_scale * Vector2(1.035, 1.035), 0.36)
	_focus_tween.tween_interval(0.02)
	_focus_tween.parallel().tween_method(Callable(self, "_set_target_glow"), max_color, min_color, 0.36)
	_focus_tween.parallel().tween_property(self, "scale", _base_scale * _battle_scale * Vector2(1.015, 1.015), 0.36)


func _stop_focus_pulse() -> void:
	if _focus_tween != null:
		_focus_tween.kill()
		_focus_tween = null


func _setup_target_glow_material() -> void:
	if target_glow == null:
		return
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;

uniform vec4 glow_color : source_color = vec4(1.0, 0.95, 0.64, 0.0);
uniform float outline_size = 2.0;

void fragment() {
	float center = texture(TEXTURE, UV).a;
	vec2 step_uv = TEXTURE_PIXEL_SIZE * outline_size;
	float neighbor = 0.0;
	neighbor = max(neighbor, texture(TEXTURE, UV + vec2(step_uv.x, 0.0)).a);
	neighbor = max(neighbor, texture(TEXTURE, UV + vec2(-step_uv.x, 0.0)).a);
	neighbor = max(neighbor, texture(TEXTURE, UV + vec2(0.0, step_uv.y)).a);
	neighbor = max(neighbor, texture(TEXTURE, UV + vec2(0.0, -step_uv.y)).a);
	neighbor = max(neighbor, texture(TEXTURE, UV + vec2(step_uv.x, step_uv.y)).a);
	neighbor = max(neighbor, texture(TEXTURE, UV + vec2(-step_uv.x, step_uv.y)).a);
	neighbor = max(neighbor, texture(TEXTURE, UV + vec2(step_uv.x, -step_uv.y)).a);
	neighbor = max(neighbor, texture(TEXTURE, UV + vec2(-step_uv.x, -step_uv.y)).a);
	float outline = max(neighbor - center, 0.0);
	COLOR = vec4(glow_color.rgb, glow_color.a * outline);
}
"""
	_target_glow_material = ShaderMaterial.new()
	_target_glow_material.shader = shader
	target_glow.material = _target_glow_material
	_set_target_glow(Color(1, 0.95, 0.64, 0.0))


func _set_target_glow(color: Color) -> void:
	if target_glow == null:
		return
	target_glow.modulate = color
	if _target_glow_material != null:
		_target_glow_material.set_shader_parameter("glow_color", color)


func _resolve_portrait(unit_id: String, visual_def: Dictionary) -> Texture2D:
	var portrait_path: String = String(visual_def.get("token_path", visual_def.get("portrait_path", "")))
	var resolved := _texture_from_path(portrait_path)
	if resolved != null:
		return _crop_texture_alpha_bounds(resolved)
	return PORTRAITS.get(unit_id, PORTRAITS.get("enemy_hollow_deacon"))


func _visual_def(unit_id: String) -> Dictionary:
	var content_db := get_node_or_null("/root/ContentDB")
	if content_db != null and content_db.has_method("get_unit_visual"):
		return content_db.get_unit_visual(unit_id)
	return {}


func _apply_visual_layout(side: String, visual_def: Dictionary) -> void:
	var portrait_scale: float = float(visual_def.get("token_scale", visual_def.get("portrait_scale", 1.0)))
	var offset_y: float = float(visual_def.get("token_y_offset", visual_def.get("y_offset", 0.0)))
	var offset_x: float = float(visual_def.get("token_x_offset", visual_def.get("x_offset", 0.0)))
	var baseline_nudge: float = float(visual_def.get("token_baseline_nudge", 0.0))
	var auto_bottom_shift: float = _auto_bottom_shift_for_texture(portrait.texture, portrait_scale)
	portrait.scale = Vector2(portrait_scale, portrait_scale)
	portrait.position = Vector2(offset_x, offset_y + auto_bottom_shift + baseline_nudge)
	target_glow.texture = portrait.texture
	target_glow.flip_h = portrait.flip_h
	target_glow.scale = portrait.scale
	target_glow.position = portrait.position
	_update_hp_bar_position()

	var icon_path: String = String(visual_def.get("icon_path", ""))
	var icon_texture := _texture_from_path(icon_path)
	if icon_texture != null:
		role_icon.texture = icon_texture
		return
	role_icon.texture = DEFAULT_ICONS.get(side, DEFAULT_ICONS.get("enemy"))


func _update_hp_bar_position() -> void:
	if portrait == null:
		return
	var scaled_size := Vector2(
		portrait.size.x * absf(portrait.scale.x),
		portrait.size.y * absf(portrait.scale.y)
	)
	var portrait_top: float = portrait.position.y
	var portrait_bottom: float = portrait_top + scaled_size.y
	var portrait_center_x: float = portrait.position.x + (scaled_size.x * 0.5)

	var hp_size := _control_size_or_default(hp_bar, Vector2(56.0, 8.0))
	_set_centered_control_rect(
		hp_bar,
		portrait_center_x,
		portrait_top - hp_size.y - HP_BAR_TO_PORTRAIT_GAP,
		hp_size
	)

	var frame_size := _control_size_or_default(base_plate_frame, Vector2(84.0, 28.0))
	var frame_top: float = portrait_bottom + NAME_PLATE_TO_PORTRAIT_GAP
	_set_centered_control_rect(base_plate_frame, portrait_center_x, frame_top, frame_size)

	var shadow_size := _control_size_or_default(
		base_plate_shadow,
		Vector2(
			frame_size.x - 2.0,
			frame_size.y - BASE_PLATE_SHADOW_TOP_INSET - BASE_PLATE_SHADOW_BOTTOM_INSET
		)
	)
	_set_centered_control_rect(
		base_plate_shadow,
		portrait_center_x,
		frame_top + BASE_PLATE_SHADOW_TOP_INSET,
		shadow_size
	)

	var trim_size := _control_size_or_default(
		base_plate_trim,
		Vector2(max(24.0, frame_size.x - 12.0), BASE_PLATE_TRIM_HEIGHT)
	)
	_set_centered_control_rect(
		base_plate_trim,
		portrait_center_x,
		frame_top + BASE_PLATE_TRIM_TOP_INSET,
		trim_size
	)

	var overlay_size := _control_size_or_default(
		overlay,
		Vector2(
			max(16.0, frame_size.x - 8.0),
			max(8.0, frame_size.y - BASE_PLATE_OVERLAY_TOP_INSET - BASE_PLATE_OVERLAY_BOTTOM_INSET)
		)
	)
	_set_centered_control_rect(
		overlay,
		portrait_center_x,
		frame_top + BASE_PLATE_OVERLAY_TOP_INSET,
		overlay_size
	)

	var name_size := _control_size_or_default(name_label, Vector2(64.0, 10.0))
	_set_centered_control_rect(
		name_label,
		portrait_center_x,
		frame_top + NAME_LABEL_TOP_INSET,
		name_size
	)


func _control_size_or_default(node: Control, fallback: Vector2) -> Vector2:
	if node == null:
		return fallback
	var size_value := node.size
	if size_value.x <= 0.0 or size_value.y <= 0.0:
		size_value = node.get_combined_minimum_size()
	if size_value.x <= 0.0 or size_value.y <= 0.0:
		return fallback
	return size_value


func _set_centered_control_rect(node: Control, center_x: float, top_y: float, rect_size: Vector2) -> void:
	if node == null:
		return
	node.anchor_left = 0.0
	node.anchor_top = 0.0
	node.anchor_right = 0.0
	node.anchor_bottom = 0.0
	var safe_size := Vector2(max(1.0, rect_size.x), max(1.0, rect_size.y))
	node.position = Vector2(
		round(center_x - (safe_size.x * 0.5)),
		round(top_y)
	)
	node.size = safe_size


func _texture_from_path(path: String) -> Texture2D:
	if path.is_empty():
		return null
	if ResourceLoader.exists(path):
		var loaded: Resource = load(path)
		if loaded is Texture2D:
			return loaded
	var absolute_path: String = ProjectSettings.globalize_path(path)
	if not FileAccess.file_exists(absolute_path):
		return null
	var image := Image.load_from_file(absolute_path)
	if image == null or image.is_empty():
		return null
	return ImageTexture.create_from_image(image)


func _crop_texture_alpha_bounds(texture: Texture2D) -> Texture2D:
	if texture == null:
		return null
	var image: Image = texture.get_image()
	if image == null or image.is_empty():
		return texture
	var bounds := _alpha_bounds_for_image(image)
	if bounds.size.x <= 0 or bounds.size.y <= 0:
		return texture
	var full_rect := Rect2i(Vector2i.ZERO, image.get_size())
	var crop_rect := Rect2i(
		max(0, int(bounds.position.x) - TOKEN_ALPHA_CROP_PADDING),
		max(0, int(bounds.position.y) - TOKEN_ALPHA_CROP_PADDING),
		min(full_rect.size.x, int(bounds.size.x) + (TOKEN_ALPHA_CROP_PADDING * 2)),
		min(full_rect.size.y, int(bounds.size.y) + (TOKEN_ALPHA_CROP_PADDING * 2))
	)
	if crop_rect.position.x + crop_rect.size.x > full_rect.size.x:
		crop_rect.size.x = full_rect.size.x - crop_rect.position.x
	if crop_rect.position.y + crop_rect.size.y > full_rect.size.y:
		crop_rect.size.y = full_rect.size.y - crop_rect.position.y
	if crop_rect == full_rect or crop_rect.size.x <= 0 or crop_rect.size.y <= 0:
		return texture
	var cropped := image.get_region(crop_rect)
	if cropped == null or cropped.is_empty():
		return texture
	return ImageTexture.create_from_image(cropped)


func _auto_bottom_shift_for_texture(texture: Texture2D, portrait_scale: float) -> float:
	if texture == null or portrait == null:
		return 0.0
	var content_bounds := _portrait_content_bounds(texture)
	if content_bounds.is_empty():
		return 0.0
	var tex_width: float = max(1.0, float(content_bounds.get("width", 1.0)))
	var tex_height: float = max(1.0, float(content_bounds.get("height", 1.0)))
	var fit_scale: float = min(
		portrait.size.x / tex_width,
		portrait.size.y / tex_height
	)
	var bottom_margin_px: float = float(content_bounds.get("bottom_margin", 0.0))
	return max(0.0, (bottom_margin_px * fit_scale * portrait_scale) - TOKEN_VISIBLE_BASELINE_PADDING)


func _portrait_content_bounds(texture: Texture2D) -> Dictionary:
	var cache_key := "%s:%s" % [texture.resource_path, texture.get_rid().get_id()]
	if cache_key == _cached_portrait_bounds_key and not _cached_portrait_content_bounds.is_empty():
		return _cached_portrait_content_bounds
	var image: Image = texture.get_image()
	if image == null or image.is_empty():
		return {}
	var bounds := _alpha_bounds_for_image(image)
	if bounds.size.x <= 0 or bounds.size.y <= 0:
		return {}
	var width: int = image.get_width()
	var height: int = image.get_height()
	var left: int = int(bounds.position.x)
	var top: int = int(bounds.position.y)
	var right: int = int(bounds.end.x) - 1
	var bottom: int = int(bounds.end.y) - 1
	_cached_portrait_bounds_key = cache_key
	_cached_portrait_content_bounds = {
		"width": width,
		"height": height,
		"left_margin": left,
		"top_margin": top,
		"right_margin": max(0, width - right - 1),
		"bottom_margin": max(0, height - bottom - 1)
	}
	return _cached_portrait_content_bounds


func _alpha_bounds_for_image(image: Image) -> Rect2i:
	if image == null or image.is_empty():
		return Rect2i()
	var width: int = image.get_width()
	var height: int = image.get_height()
	var left: int = width
	var top: int = height
	var right: int = -1
	var bottom: int = -1
	image.decompress()
	for y in height:
		for x in width:
			if image.get_pixel(x, y).a <= 0.03:
				continue
			left = min(left, x)
			top = min(top, y)
			right = max(right, x)
			bottom = max(bottom, y)
	if right < 0 or bottom < 0:
		return Rect2i()
	return Rect2i(left, top, (right - left) + 1, (bottom - top) + 1)
