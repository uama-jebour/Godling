extends RefCounted

const STATE_HELPER := preload("res://systems/battle/auto_battle_state.gd")
const SPEED_TO_PIXELS := 8.0
const RANGED_COMFORT_MIN := 0.55
const RANGED_COMFORT_MAX := 0.95
const MIN_SEPARATION_BUFFER := 8.0
const MAX_SPATIAL_RESOLVE_PASSES := 4

var _state_helper := STATE_HELPER.new()


func tick(state: Dictionary) -> void:
	var entities: Array = state.get("entities", [])
	var moved_positions: Array = []

	# 预计算威胁信息（用于英雄躲避）
	var threat_info: Dictionary = _calculate_threat_info(entities)

	for entity_value in entities:
		if typeof(entity_value) != TYPE_DICTIONARY:
			moved_positions.append([0.0, 0.0])
			continue
		var entity: Dictionary = entity_value
		if not bool(entity.get("alive", false)):
			entity["velocity"] = [0.0, 0.0]
			moved_positions.append(entity.get("position", [0.0, 0.0]))
			continue

		var entity_side: String = String(entity.get("side", ""))
		var next_position: Vector2

		# 英雄特殊处理：检测威胁并可能躲避
		if entity_side == "hero":
			next_position = _hero_next_position(state, entity, threat_info)
		else:
			var target: Dictionary = _nearest_target(entity, entities)
			entity["target_id"] = String(target.get("entity_id", ""))
			if target.is_empty():
				entity["velocity"] = [0.0, 0.0]
				moved_positions.append(entity.get("position", [0.0, 0.0]))
				continue
			next_position = _next_position(state, entity, target)

		entity["velocity"] = _state_helper.array_from_vector(next_position - _state_helper.vector_from_value(entity.get("position", [])))
		entity["position"] = _state_helper.array_from_vector(next_position)
		moved_positions.append(entity["position"])

	_resolve_spatial_constraints(state)


# 计算所有近战敌人对英雄的威胁信息
func _calculate_threat_info(entities: Array) -> Dictionary:
	var hero_pos: Vector2 = Vector2.ZERO
	var hero_found: bool = false

	# 先找到英雄位置
	for entity_value in entities:
		if typeof(entity_value) != TYPE_DICTIONARY:
			continue
		var entity: Dictionary = entity_value
		if String(entity.get("side", "")) == "hero" and bool(entity.get("alive", false)):
			hero_pos = _state_helper.vector_from_value(entity.get("position", []))
			hero_found = true
			break

	if not hero_found:
		return {"hero_pos": hero_pos, "melee_threats": []}

	# 收集所有近战敌人的威胁信息
	var melee_threats: Array = []
	for entity_value in entities:
		if typeof(entity_value) != TYPE_DICTIONARY:
			continue
		var entity: Dictionary = entity_value
		if not bool(entity.get("alive", false)):
			continue
		var side: String = String(entity.get("side", ""))
		if side == "hero" or side == "ally":
			continue

		var entity_pos: Vector2 = _state_helper.vector_from_value(entity.get("position", []))
		var distance: float = entity_pos.distance_to(hero_pos)
		var attack_range_px: float = _state_helper.unit_range_pixels(entity.get("attack_runtime", {}))

		# 只考虑近战敌人（range < 150px）且在威胁距离内的
		if attack_range_px < 150.0 and distance < 250.0:
			melee_threats.append({
				"entity_id": String(entity.get("entity_id", "")),
				"position": entity_pos,
				"distance": distance,
				"direction": (hero_pos - entity_pos).normalized()
			})

	return {"hero_pos": hero_pos, "melee_threats": melee_threats}


# 英雄移动逻辑：正常追击，但检测到多名近战威胁时躲避
func _hero_next_position(state: Dictionary, hero: Dictionary, threat_info: Dictionary) -> Vector2:
	var tick_rate: int = int(state.get("tick_rate", 5))
	var current_pos: Vector2 = _state_helper.vector_from_value(hero.get("position", []))
	var hero_speed: float = float(hero.get("move_speed", 10.0)) * SPEED_TO_PIXELS / max(1.0, float(tick_rate))

	var melee_threats: Array = threat_info.get("melee_threats", [])
	var threat_count: int = melee_threats.size()

	# 寻找最近的目标（用于正常追击）
	var entities: Array = state.get("entities", [])
	var target: Dictionary = _nearest_target(hero, entities)
	hero["target_id"] = String(target.get("entity_id", ""))

	var next_pos: Vector2
	# 如果有多名（2名以上）近战敌人在威胁范围内，执行躲避
	if threat_count >= 2:
		var evade_direction: Vector2 = _calculate_evade_direction(current_pos, melee_threats, state)
		next_pos = current_pos + (evade_direction * hero_speed)
	else:
		# 否则正常追击目标
		if target.is_empty():
			return current_pos
		next_pos = _next_position(state, hero, target)

	# 应用边界限制
	return _clamp_position_to_battlefield(next_pos, hero, state)


# 将位置限制在战场边界内
func _clamp_position_to_battlefield(pos: Vector2, entity: Dictionary, state: Dictionary) -> Vector2:
	var battlefield: Dictionary = state.get("battlefield", {})
	var size: Array = battlefield.get("size", [840, 480])
	var max_x: float = float(size[0]) if size.size() > 0 else 840.0
	var max_y: float = float(size[1]) if size.size() > 1 else 480.0
	var radius: float = float(entity.get("collision_radius", 18.0))

	return Vector2(
		clampf(pos.x, radius, max_x - radius),
		clampf(pos.y, radius, max_y - radius)
	)


# 计算躲避方向：远离威胁中心，同时考虑战场边界
func _calculate_evade_direction(hero_pos: Vector2, threats: Array, state: Dictionary) -> Vector2:
	if threats.is_empty():
		return Vector2.ZERO

	# 计算威胁中心（加权平均，越近的威胁权重越高）
	var threat_center: Vector2 = Vector2.ZERO
	var total_weight: float = 0.0

	for threat in threats:
		var weight: float = 1.0 / max(1.0, threat["distance"])
		threat_center += threat["position"] * weight
		total_weight += weight

	if total_weight > 0:
		threat_center /= total_weight

	# 躲避方向 = 远离威胁中心
	var evade_dir: Vector2 = (hero_pos - threat_center).normalized()

	# 如果威胁主要来自一侧，稍微向垂直方向偏移（侧向躲避）
	if threats.size() >= 3:
		var perpendicular: Vector2 = Vector2(-evade_dir.y, evade_dir.x)
		# 根据威胁分布决定向左还是向右躲
		var left_threat: float = 0.0
		var right_threat: float = 0.0
		for threat in threats:
			var to_threat: Vector2 = (threat["position"] - hero_pos).normalized()
			var cross: float = evade_dir.x * to_threat.y - evade_dir.y * to_threat.x
			if cross > 0:
				left_threat += 1.0 / max(1.0, threat["distance"])
			else:
				right_threat += 1.0 / max(1.0, threat["distance"])

		if left_threat > right_threat * 1.5:
			evade_dir = (evade_dir + perpendicular * 0.5).normalized()
		elif right_threat > left_threat * 1.5:
			evade_dir = (evade_dir - perpendicular * 0.5).normalized()

	# 如果躲避方向会导致移出战场，尝试调整方向
	var battlefield: Dictionary = state.get("battlefield", {})
	var size: Array = battlefield.get("size", [840, 480])
	var max_x: float = float(size[0]) if size.size() > 0 else 840.0
	var max_y: float = float(size[1]) if size.size() > 1 else 480.0

	# 检查是否会撞到边界
	var margin: float = 50.0  # 距离边界多少像素时开始调整
	var adjusted_dir: Vector2 = evade_dir

	if hero_pos.x < margin and adjusted_dir.x < 0:
		adjusted_dir.x = abs(adjusted_dir.x) * 0.5  # 减速并向右
	elif hero_pos.x > max_x - margin and adjusted_dir.x > 0:
		adjusted_dir.x = -abs(adjusted_dir.x) * 0.5  # 减速并向左

	if hero_pos.y < margin and adjusted_dir.y < 0:
		adjusted_dir.y = abs(adjusted_dir.y) * 0.5  # 减速并向下
	elif hero_pos.y > max_y - margin and adjusted_dir.y > 0:
		adjusted_dir.y = -abs(adjusted_dir.y) * 0.5  # 减速并向上

	return adjusted_dir.normalized()


func _nearest_target(source: Dictionary, entities: Array) -> Dictionary:
	var source_pos: Vector2 = _state_helper.vector_from_value(source.get("position", []))
	var nearest: Dictionary = {}
	var nearest_distance_sq := INF
	for entity_value in entities:
		if typeof(entity_value) != TYPE_DICTIONARY:
			continue
		var candidate: Dictionary = entity_value
		if not bool(candidate.get("alive", false)):
			continue
		if _same_friendly_side(String(source.get("side", "")), String(candidate.get("side", ""))):
			continue
		var candidate_pos: Vector2 = _state_helper.vector_from_value(candidate.get("position", []))
		var distance_sq: float = source_pos.distance_squared_to(candidate_pos)
		if distance_sq < nearest_distance_sq:
			nearest_distance_sq = distance_sq
			nearest = candidate
	return nearest


func _next_position(state: Dictionary, entity: Dictionary, target: Dictionary) -> Vector2:
	var tick_rate: int = int(state.get("tick_rate", 5))
	var current_pos: Vector2 = _state_helper.vector_from_value(entity.get("position", []))
	var target_pos: Vector2 = _state_helper.vector_from_value(target.get("position", []))
	var delta: Vector2 = target_pos - current_pos
	var center_distance: float = delta.length()
	if center_distance <= 0.001:
		return current_pos
	var direction: Vector2 = delta / center_distance
	var attack_runtime: Dictionary = entity.get("attack_runtime", {})
	var attack_range_px: float = _state_helper.unit_range_pixels(attack_runtime)
	var spacing_distance: float = _spacing_distance(entity, target, center_distance)

	# 计算包围偏移：根据 entity_id 生成稳定的偏移角度
	var surround_offset: Vector2 = _calculate_surround_offset(entity, target_pos, attack_range_px)

	var desired_direction: Vector2 = direction
	var desired_speed: float = float(entity.get("move_speed", 8.0)) * SPEED_TO_PIXELS / max(1.0, float(tick_rate))
	var combat_ai: String = String(entity.get("combat_ai", "melee_attack"))

	if combat_ai == "ranged_attack":
		if spacing_distance < attack_range_px * RANGED_COMFORT_MIN:
			desired_direction = -direction
		elif spacing_distance <= attack_range_px * RANGED_COMFORT_MAX:
			desired_speed = 0.0
	else:
		# 近战单位：攻击范围越短，越要积极贴近目标
		# 短程近战会尝试进入攻击范围并贴近，长程近战保持正常距离
		var engage_range_px: float = attack_range_px * _melee_engagement_factor(attack_range_px)
		if spacing_distance <= engage_range_px:
			desired_speed = 0.0
		else:
			# 添加包围偏移到移动方向
			desired_direction = (direction + surround_offset).normalized()

	var next_pos: Vector2 = current_pos + (desired_direction * desired_speed)
	return _clamp_position_to_battlefield(next_pos, entity, state)


# 根据攻击范围计算近战单位的 engagement factor
# 范围越短，factor 越小（越要积极贴近）
func _melee_engagement_factor(attack_range_px: float) -> float:
	# range 1 (40px) -> 0.5 (非常积极，要贴到很近)
	# range 2 (80px) -> 0.7 (比较积极)
	# range 3 (120px) -> 0.92 (标准距离)
	var range_units: float = attack_range_px / 40.0  # 转换为 range 单位
	if range_units <= 1.5:
		return 0.5
	elif range_units <= 2.5:
		return 0.7
	else:
		return 0.92


# 计算包围偏移，让多个敌人从不同方向接近（360度全方位）
func _calculate_surround_offset(entity: Dictionary, target_pos: Vector2, attack_range_px: float) -> Vector2:
	var entity_id: String = String(entity.get("entity_id", ""))
	if entity_id.is_empty():
		return Vector2.ZERO

	# 根据 entity_id 生成稳定的哈希值（0-360度）
	var hash_value: int = 0
	for i in range(entity_id.length()):
		hash_value = (hash_value * 31 + entity_id.unicode_at(i)) % 360

	# 全方向分布：0-360度，让敌人从各个方向包围
	var angle_rad: float = deg_to_rad(hash_value)

	# 偏移强度：近战单位包围欲望更强
	# 同时根据距离调整：越近包围偏移越小（避免贴身时乱动）
	var current_pos: Vector2 = _state_helper.vector_from_value(entity.get("position", []))
	var distance_to_target: float = current_pos.distance_to(target_pos)
	var base_strength: float = 0.5 if attack_range_px > 100 else 0.8
	var distance_factor: float = clampf(distance_to_target / 200.0, 0.2, 1.0)
	var offset_strength: float = base_strength * distance_factor

	# 计算垂直于目标方向的向量（侧向偏移）
	var to_target: Vector2 = target_pos - current_pos
	if to_target.length() <= 0.001:
		return Vector2.ZERO

	var perpendicular: Vector2 = Vector2(-to_target.y, to_target.x).normalized()

	# 结合径向和切向偏移，形成螺旋接近效果
	var radial_offset: Vector2 = to_target.normalized() * cos(angle_rad) * offset_strength * 0.3
	var tangent_offset: Vector2 = perpendicular * sin(angle_rad) * offset_strength

	return radial_offset + tangent_offset


func _spacing_distance(entity: Dictionary, target: Dictionary, center_distance: float) -> float:
	var combined_radius: float = float(entity.get("collision_radius", 18.0)) + float(target.get("collision_radius", 18.0))
	return max(0.0, center_distance - combined_radius)


func _resolve_spatial_constraints(state: Dictionary) -> void:
	for _pass_index in range(MAX_SPATIAL_RESOLVE_PASSES):
		var separated: bool = _apply_separation(state)
		var constrained: bool = _apply_blockers_and_bounds(state)
		if not separated and not constrained:
			break


func _apply_separation(state: Dictionary) -> bool:
	var entities: Array = state.get("entities", [])
	var changed := false
	for i in range(entities.size()):
		if typeof(entities[i]) != TYPE_DICTIONARY:
			continue
		var a: Dictionary = entities[i]
		if not bool(a.get("alive", false)):
			continue
		for j in range(i + 1, entities.size()):
			if typeof(entities[j]) != TYPE_DICTIONARY:
				continue
			var b: Dictionary = entities[j]
			if not bool(b.get("alive", false)):
				continue
			var a_pos: Vector2 = _state_helper.vector_from_value(a.get("position", []))
			var b_pos: Vector2 = _state_helper.vector_from_value(b.get("position", []))
			var min_distance: float = float(a.get("collision_radius", 18.0)) + float(b.get("collision_radius", 18.0)) + MIN_SEPARATION_BUFFER
			var delta: Vector2 = b_pos - a_pos
			var distance: float = delta.length()
			if distance >= min_distance:
				continue
			var normal := Vector2.RIGHT if distance <= 0.001 else delta / distance
			var correction: float = (min_distance - max(distance, 0.001)) * 0.5
			a_pos -= normal * correction
			b_pos += normal * correction
			a["position"] = _state_helper.array_from_vector(a_pos)
			b["position"] = _state_helper.array_from_vector(b_pos)
			changed = true
	return changed


func _apply_blockers_and_bounds(state: Dictionary) -> bool:
	var battlefield: Dictionary = state.get("battlefield", {})
	var size: Array = battlefield.get("size", [840, 480])
	var max_x: float = float(size[0]) if size.size() > 0 else 840.0
	var max_y: float = float(size[1]) if size.size() > 1 else 480.0
	var blockers: Array = battlefield.get("blockers", [])
	var changed := false
	for entity_value in state.get("entities", []):
		if typeof(entity_value) != TYPE_DICTIONARY:
			continue
		var entity: Dictionary = entity_value
		if not bool(entity.get("alive", false)):
			continue
		var original_pos: Vector2 = _state_helper.vector_from_value(entity.get("position", []))
		var pos: Vector2 = original_pos
		var radius: float = float(entity.get("collision_radius", 18.0))
		pos.x = clampf(pos.x, radius, max_x - radius)
		pos.y = clampf(pos.y, radius, max_y - radius)
		for blocker_value in blockers:
			if typeof(blocker_value) != TYPE_DICTIONARY:
				continue
			var blocker: Dictionary = blocker_value
			if String(blocker.get("shape", "rect")) != "rect":
				continue
			var rect: Rect2 = Rect2(
				Vector2(float(blocker.get("x", 0.0)), float(blocker.get("y", 0.0))),
				Vector2(float(blocker.get("w", 0.0)), float(blocker.get("h", 0.0)))
			)
			var expanded: Rect2 = rect.grow(radius)
			if not expanded.has_point(pos):
				continue
			var left_distance: float = absf(pos.x - expanded.position.x)
			var right_distance: float = absf(pos.x - expanded.end.x)
			var top_distance: float = absf(pos.y - expanded.position.y)
			var bottom_distance: float = absf(pos.y - expanded.end.y)
			var min_distance: float = min(min(left_distance, right_distance), min(top_distance, bottom_distance))
			if is_equal_approx(min_distance, left_distance):
				pos.x = expanded.position.x
			elif is_equal_approx(min_distance, right_distance):
				pos.x = expanded.end.x
			elif is_equal_approx(min_distance, top_distance):
				pos.y = expanded.position.y
			else:
				pos.y = expanded.end.y
		if pos.distance_squared_to(original_pos) > 0.0001:
			changed = true
		entity["position"] = _state_helper.array_from_vector(pos)
	return changed


func _same_friendly_side(side_a: String, side_b: String) -> bool:
	var friendly_a := side_a == "hero" or side_a == "ally"
	var friendly_b := side_b == "hero" or side_b == "ally"
	return friendly_a == friendly_b
