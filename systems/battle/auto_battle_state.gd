extends RefCounted

const DEFAULT_TICK_RATE := 5
const DEFAULT_MAX_SECONDS := 30
const RANGE_TO_PIXELS := 40.0


func initialize_state(request: Dictionary, battle_def: Dictionary, content_db: Node) -> Dictionary:
	if content_db == null:
		return {"invalid_reason": "missing_content_db"}
	var hero_snapshot: Dictionary = request.get("hero_snapshot", {})
	var hero_unit_id: String = String(hero_snapshot.get("hero_id", ""))
	var hero_unit: Dictionary = content_db.get_unit(hero_unit_id)
	if hero_unit.is_empty():
		return {"invalid_reason": "missing_hero_unit"}

	var seed: int = int(request.get("battle_seed", 0))
	if seed == 0:
		seed = int(hash("%s|%s|%s" % [
			String(battle_def.get("id", "")),
			String(request.get("event_instance_id", "")),
			hero_unit_id
		]))
	var rng := RandomNumberGenerator.new()
	rng.seed = seed

	var tick_rate: int = int(battle_def.get("tick_rate", DEFAULT_TICK_RATE))
	var battlefield: Dictionary = battle_def.get("battlefield", {}).duplicate(true)
	if battlefield.is_empty():
		battlefield = {
			"size": [840, 480],
			"blockers": [],
			"lanes": []
		}

	# 英雄随机出现在左侧区域 (x: 60-180, y: 160-320)
	var hero_base_pos: Array = battle_def.get("hero_spawn", [120, 240])
	var hero_random_x: float = hero_base_pos[0] + rng.randf_range(-60, 60)
	var hero_random_y: float = hero_base_pos[1] + rng.randf_range(-80, 80)
	var hero_position: Array = [hero_random_x, hero_random_y]
	var hero_entity: Dictionary = _create_entity("hero", hero_unit, hero_snapshot.get("runtime_stats", {}), hero_position, "hero_1")
	var entities: Array = [hero_entity]
	var next_entity_index := 1

	for ally_group_value in battle_def.get("ally_groups", []):
		if typeof(ally_group_value) != TYPE_DICTIONARY:
			continue
		var ally_group: Dictionary = ally_group_value
		var ally_unit: Dictionary = content_db.get_unit(String(ally_group.get("unit_id", "")))
		if ally_unit.is_empty():
			return {"invalid_reason": "missing_ally_unit"}
		var ally_count: int = _resolve_group_count(ally_group, rng)
		# 盟友随机出现在英雄附近的左侧区域
		var ally_base: Array = ally_group.get("spawn", [164, 288])
		var ally_random_x: float = ally_base[0] + rng.randf_range(-40, 40)
		var ally_random_y: float = ally_base[1] + rng.randf_range(-60, 60)
		var ally_spawn: Array = [ally_random_x, ally_random_y]
		for ally_index in range(ally_count):
			next_entity_index += 1
			entities.append(_create_entity("ally", ally_unit, {}, _formation_position(ally_spawn, ally_index, false), "ally_%d" % next_entity_index))

	for enemy_group_value in battle_def.get("enemy_groups", []):
		if typeof(enemy_group_value) != TYPE_DICTIONARY:
			continue
		var enemy_group: Dictionary = enemy_group_value
		var enemy_unit: Dictionary = content_db.get_unit(String(enemy_group.get("unit_id", "")))
		if enemy_unit.is_empty():
			return {"invalid_reason": "missing_enemy_unit"}
		var enemy_count: int = _resolve_group_count(enemy_group, rng)
		# 敌人随机出现在右侧区域，增加随机性避免排成一排
		var enemy_base: Array = enemy_group.get("spawn", [660, 230])
		var enemy_random_x: float = enemy_base[0] + rng.randf_range(-80, 80)
		var enemy_random_y: float = enemy_base[1] + rng.randf_range(-100, 100)
		var enemy_spawn: Array = [enemy_random_x, enemy_random_y]
		for enemy_index in range(enemy_count):
			next_entity_index += 1
			entities.append(_create_entity("enemy", enemy_unit, {}, _formation_position(enemy_spawn, enemy_index, true), "enemy_%d" % next_entity_index))

	var scripted_events: Array = []
	for event_id_value in battle_def.get("scripted_event_ids", []):
		var battle_event: Dictionary = content_db.get_battle_event(String(event_id_value))
		if battle_event.is_empty():
			continue
		scripted_events.append(
			{
				"source": battle_event.duplicate(true),
				"id": String(battle_event.get("id", "")),
				"stage": "idle",
				"notify_ticks_remaining": 0,
				"response_ticks_remaining": 0,
				"resolved": false,
				"cancelled": false,
				"triggered_tick": -1
			}
		)

	var strategies: Array = []
	for strategy_id_value in request.get("equipped_strategy_ids", []):
		var strategy_def: Dictionary = content_db.get_strategy(String(strategy_id_value))
		if strategy_def.is_empty():
			continue
		var cooldown_ticks: int = max(0, seconds_to_ticks(float(strategy_def.get("cooldown", 0.0)), tick_rate))
		strategies.append(
			{
				"source": strategy_def.duplicate(true),
				"id": String(strategy_def.get("id", "")),
				"kind": String(strategy_def.get("kind", "")),
				"cooldown_ticks": cooldown_ticks,
				"cooldown_remaining": 0,
				"next_pulse_tick": cooldown_ticks if cooldown_ticks > 0 else 0,
				"charges_remaining": int(strategy_def.get("charges", -1))
			}
		)

	var victory_rules: Dictionary = battle_def.get("victory_rules", {})
	var max_seconds: int = int(battle_def.get("max_seconds", DEFAULT_MAX_SECONDS))
	if String(victory_rules.get("type", "")) == "survive_for_duration":
		max_seconds = max(max_seconds, int(victory_rules.get("duration", 0)) + 6)

	return {
		"simulation_mode": "auto_units",
		"content_db": content_db,
		"battle_def": battle_def.duplicate(true),
		"request": request.duplicate(true),
		"seed": seed,
		"rng_seed": seed,
		"tick_rate": tick_rate,
		"max_ticks": max_seconds * tick_rate,
		"elapsed_ticks": 0,
		"battlefield": battlefield,
		"entities": entities,
		"next_entity_index": next_entity_index + 1,
		"scripted_events": scripted_events,
		"strategies": strategies,
		"scheduled_strategy_commands": [],
		"triggered_strategy_ids": [],
		"triggered_scripted_event_ids": [],
		"event_resolution_log": [],
		"notifications": [],
		"action_log": [],
		"last_action": {},
		"completed": false
	}


func create_entity(side: String, unit_def: Dictionary, runtime_stats: Dictionary, position: Array, entity_id: String) -> Dictionary:
	return _create_entity(side, unit_def, runtime_stats, position, entity_id)


func create_event_spawn_entities(side: String, unit_def: Dictionary, count: int, spawn: Array, next_index: int) -> Array:
	var created: Array = []
	for offset in range(max(0, count)):
		created.append(_create_entity(side, unit_def, {}, _formation_position(spawn, offset, side == "enemy"), "%s_%d" % [side, next_index + offset]))
	return created


func resolve_result(state: Dictionary, backend: String) -> Dictionary:
	var entities: Array = state.get("entities", [])
	var survivors: Dictionary = {
		"hero": [],
		"ally": [],
		"enemy": []
	}
	var casualties_by_side: Dictionary = {
		"hero": 0,
		"ally": 0,
		"enemy": 0
	}
	for entity_value in entities:
		if typeof(entity_value) != TYPE_DICTIONARY:
			continue
		var entity: Dictionary = entity_value
		var side: String = String(entity.get("side", "enemy"))
		if bool(entity.get("alive", false)):
			survivors[side].append(String(entity.get("entity_id", "")))
		else:
			casualties_by_side[side] = int(casualties_by_side.get(side, 0)) + 1

	var battle_def: Dictionary = state.get("battle_def", {})
	var victory: bool = _is_victory(state)
	var defeat_reason := ""
	if not victory:
		defeat_reason = "hero_down" if not _hero_alive(state) else "objective_not_completed"

	return {
		"status": "battle_runner_resolved",
		"victory": victory,
		"defeat_reason": defeat_reason,
		"casualties": [] if victory else [{"unit_id": "hero_pilgrim_a01", "count": 1}],
		"completed_objectives": _completed_objectives(state, victory),
		"spawned_story_flags": [],
		"spawned_unlock_flags": [],
		"map_effects": {
			"battle_id": String(battle_def.get("id", "")),
			"backend": backend,
			"simulation_mode": "auto_units",
			"elapsed_ticks": int(state.get("elapsed_ticks", 0)),
			"elapsed_seconds": float(state.get("elapsed_ticks", 0)) / max(1.0, float(state.get("tick_rate", DEFAULT_TICK_RATE))),
			"survivors": survivors,
			"casualties_by_side": casualties_by_side,
			"triggered_strategy_ids": state.get("triggered_strategy_ids", []).duplicate(true),
			"triggered_scripted_event_ids": state.get("triggered_scripted_event_ids", []).duplicate(true),
			"entities": _serialize_entities(entities),
			"action_log": state.get("action_log", []).duplicate(true),
			"notifications": state.get("notifications", []).duplicate(true),
			"event_resolution_log": state.get("event_resolution_log", []).duplicate(true),
			"seed": int(state.get("seed", 0))
		}
	}


func is_battle_active(state: Dictionary) -> bool:
	if state.has("invalid_reason"):
		return false
	if bool(state.get("completed", false)):
		return false
	if int(state.get("elapsed_ticks", 0)) >= int(state.get("max_ticks", DEFAULT_MAX_SECONDS * DEFAULT_TICK_RATE)):
		return false
	if _is_victory(state):
		return false
	if _is_defeat(state):
		return false
	return true


func seconds_to_ticks(seconds: float, tick_rate: int) -> int:
	return maxi(0, int(round(seconds * float(max(1, tick_rate)))))


func unit_range_pixels(unit_or_attack: Dictionary) -> float:
	var attack: Dictionary = unit_or_attack.get("attack", unit_or_attack)
	return max(28.0, float(attack.get("range", 1.0)) * RANGE_TO_PIXELS)


func default_target_side(side: String) -> String:
	return "enemy" if side == "hero" or side == "ally" else "friendly"


func find_entity_index(entities: Array, entity_id: String) -> int:
	for index in range(entities.size()):
		var entity_value: Variant = entities[index]
		if typeof(entity_value) != TYPE_DICTIONARY:
			continue
		if String(entity_value.get("entity_id", "")) == entity_id:
			return index
	return -1


func find_entity(entities: Array, entity_id: String) -> Dictionary:
	var index: int = find_entity_index(entities, entity_id)
	return entities[index] if index >= 0 else {}


func current_side_hp_ratio(state: Dictionary, side: String) -> float:
	var hp_total := 0.0
	var hp_max := 0.0
	for entity_value in state.get("entities", []):
		if typeof(entity_value) != TYPE_DICTIONARY:
			continue
		var entity: Dictionary = entity_value
		if not _matches_side(String(entity.get("side", "")), side):
			continue
		hp_total += max(0.0, float(entity.get("hp", 0.0)))
		hp_max += max(0.0, float(entity.get("max_hp", 0.0)))
	if hp_max <= 0.0:
		return 0.0
	return hp_total / hp_max


func alive_count(state: Dictionary, side: String, unit_id: String = "") -> int:
	var count := 0
	for entity_value in state.get("entities", []):
		if typeof(entity_value) != TYPE_DICTIONARY:
			continue
		var entity: Dictionary = entity_value
		if not bool(entity.get("alive", false)):
			continue
		if not _matches_side(String(entity.get("side", "")), side):
			continue
		if not unit_id.is_empty() and String(entity.get("unit_id", "")) != unit_id:
			continue
		count += 1
	return count


func unit_present(state: Dictionary, unit_id: String) -> bool:
	return alive_count(state, "any", unit_id) > 0


func vector_from_value(value: Variant, fallback: Vector2 = Vector2.ZERO) -> Vector2:
	if typeof(value) == TYPE_VECTOR2:
		return value
	if typeof(value) == TYPE_ARRAY:
		var values: Array = value
		if values.size() >= 2:
			return Vector2(float(values[0]), float(values[1]))
	return fallback


func array_from_vector(value: Vector2) -> Array:
	return [snappedf(value.x, 0.01), snappedf(value.y, 0.01)]


func _create_entity(side: String, unit_def: Dictionary, runtime_stats: Dictionary, position: Array, entity_id: String) -> Dictionary:
	var attack: Dictionary = unit_def.get("attack", {}).duplicate(true)
	var max_hp: float = float(runtime_stats.get("hp", unit_def.get("hp", 0.0)))
	return {
		"entity_id": entity_id,
		"unit_id": String(unit_def.get("id", "")),
		"side": side,
		"display_name": String(unit_def.get("name_cn", unit_def.get("id", ""))),
		"position": position.duplicate(true),
		"velocity": [0.0, 0.0],
		"collision_radius": float(unit_def.get("collision_radius", max(16, int(unit_def.get("size", 3)) * 6))),
		"hp": max_hp,
		"max_hp": max_hp,
		"shield": 0.0,
		"move_speed": float(unit_def.get("move_speed", 8.0)),
		"move_ai": String(unit_def.get("movement_ai", "chase")),
		"combat_ai": String(unit_def.get("combat_ai", "melee_attack")),
		"attack_runtime": {
			"type": String(attack.get("type", "melee")),
			"power": float(runtime_stats.get("attack_power", attack.get("power", 1.0))),
			"speed": float(attack.get("speed", 1.0)),
			"range": float(attack.get("range", 1.0)),
			"cooldown_remaining": 0
		},
		"skill_runtime": [],
		"tags": unit_def.get("tags", []).duplicate(true),
		"status_effects": [],
		"alive": max_hp > 0.0,
		"target_id": ""
	}


func _resolve_group_count(group: Dictionary, rng: RandomNumberGenerator) -> int:
	var count_range: Array = group.get("count_range", [])
	if count_range.size() >= 2:
		var min_count: int = int(count_range[0])
		var max_count: int = int(count_range[1])
		if max_count < min_count:
			var swap := min_count
			min_count = max_count
			max_count = swap
		return rng.randi_range(max(0, min_count), max(0, max_count))
	return max(0, int(group.get("count", 0)))


func _formation_position(base_spawn: Array, offset_index: int, enemy_side: bool) -> Array:
	var row: int = int(offset_index / 2)
	var column: int = offset_index % 2
	var x_dir := -1.0 if enemy_side else 1.0
	return [
		float(base_spawn[0]) + (float(column) * 48.0 * x_dir),
		float(base_spawn[1]) + (float(row) * 54.0) - (18.0 if column == 1 else 0.0)
	]


func _resolve_position_array(source: Variant, fallback: Array) -> Array:
	if typeof(source) == TYPE_ARRAY:
		var values: Array = source
		if values.size() >= 2:
			return [float(values[0]), float(values[1])]
	return fallback.duplicate(true)


func _is_victory(state: Dictionary) -> bool:
	var victory_rules: Dictionary = state.get("battle_def", {}).get("victory_rules", {})
	var rule_type: String = String(victory_rules.get("type", state.get("battle_def", {}).get("victory_type", "eliminate_all")))
	match rule_type:
		"survive_for_duration":
			return _hero_alive(state) and int(state.get("elapsed_ticks", 0)) >= seconds_to_ticks(float(victory_rules.get("duration", 0.0)), int(state.get("tick_rate", DEFAULT_TICK_RATE)))
		_:
			return alive_count(state, "enemy") <= 0 and _hero_alive(state)


func _is_defeat(state: Dictionary) -> bool:
	var defeat_rules: Dictionary = state.get("battle_def", {}).get("defeat_rules", {})
	if bool(defeat_rules.get("hero_down", true)) and not _hero_alive(state):
		return true
	if bool(defeat_rules.get("all_friendly_down", false)) and alive_count(state, "friendly") <= 0:
		return true
	return false


func _hero_alive(state: Dictionary) -> bool:
	return alive_count(state, "hero") > 0


func _completed_objectives(state: Dictionary, victory: bool) -> Array:
	if not victory:
		return []
	var battle_def: Dictionary = state.get("battle_def", {})
	var victory_rules: Dictionary = battle_def.get("victory_rules", {})
	var rule_type: String = String(victory_rules.get("type", battle_def.get("victory_type", "eliminate_all")))
	var objectives := ["objective_%s" % rule_type]
	if not state.get("triggered_scripted_event_ids", []).is_empty():
		objectives.append("triggered_%d_scripted_events" % state.get("triggered_scripted_event_ids", []).size())
	if not state.get("triggered_strategy_ids", []).is_empty():
		objectives.append("triggered_%d_strategies" % state.get("triggered_strategy_ids", []).size())
	return objectives


func _serialize_entities(entities: Array) -> Array:
	var serialized: Array = []
	for entity_value in entities:
		if typeof(entity_value) != TYPE_DICTIONARY:
			continue
		var entity: Dictionary = entity_value.duplicate(true)
		entity["position"] = _resolve_position_array(entity.get("position", []), [0.0, 0.0])
		entity["velocity"] = _resolve_position_array(entity.get("velocity", []), [0.0, 0.0])
		serialized.append(entity)
	return serialized


func _matches_side(entity_side: String, query_side: String) -> bool:
	if query_side == "any":
		return true
	if query_side == "friendly":
		return entity_side == "hero" or entity_side == "ally"
	return entity_side == query_side
