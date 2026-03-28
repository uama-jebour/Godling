extends RefCounted

const STATE_HELPER := preload("res://systems/battle/auto_battle_state.gd")

var _state_helper := STATE_HELPER.new()


func tick_passive_strategies(state: Dictionary) -> void:
	var strategies: Array = state.get("strategies", [])
	var current_tick: int = int(state.get("elapsed_ticks", 0))
	for strategy_value in strategies:
		if typeof(strategy_value) != TYPE_DICTIONARY:
			continue
		var strategy: Dictionary = strategy_value
		if String(strategy.get("kind", "")) != "passive":
			continue
		if int(strategy.get("cooldown_ticks", 0)) <= 0 and current_tick > 0:
			continue
		if current_tick < int(strategy.get("next_pulse_tick", 0)):
			continue
		_apply_strategy_effect(state, strategy, {})
		strategy["next_pulse_tick"] = current_tick + max(1, int(strategy.get("cooldown_ticks", 1)))


func apply_scheduled_active_strategies(state: Dictionary, commands: Array) -> Array:
	var emitted_responses: Array = []
	for command_value in commands:
		if typeof(command_value) != TYPE_DICTIONARY:
			continue
		var command: Dictionary = command_value
		var strategy_id: String = String(command.get("strategy_id", ""))
		if strategy_id.is_empty():
			continue
		var strategy_runtime: Dictionary = _strategy_runtime(state, strategy_id)
		if strategy_runtime.is_empty():
			continue
		if String(strategy_runtime.get("kind", "")) != "active":
			continue
		if int(strategy_runtime.get("cooldown_remaining", 0)) > 0:
			continue
		var charges_remaining: int = int(strategy_runtime.get("charges_remaining", -1))
		if charges_remaining == 0:
			continue
		_apply_strategy_effect(state, strategy_runtime, command)
		strategy_runtime["cooldown_remaining"] = int(strategy_runtime.get("cooldown_ticks", 0))
		if charges_remaining > 0:
			strategy_runtime["charges_remaining"] = charges_remaining - 1
		var effect: Dictionary = strategy_runtime.get("source", {}).get("effect", {})
		var response_keyword: String = String(effect.get("response_keyword", ""))
		if not response_keyword.is_empty():
			emitted_responses.append(
				{
					"strategy_id": strategy_id,
					"keyword": response_keyword,
					"level": int(effect.get("response_level", 0))
				}
			)
	return emitted_responses


func tick_combat(state: Dictionary) -> void:
	var entities: Array = state.get("entities", [])
	var current_tick: int = int(state.get("elapsed_ticks", 0))

	# 回合制攻击：每 tick 只选一个单位出手，公平轮流
	# 收集所有存活且冷却完毕的单位（不管是否在攻击范围内）
	var ready_attackers: Array = []
	for entity_index in range(entities.size()):
		if typeof(entities[entity_index]) != TYPE_DICTIONARY:
			continue
		var entity: Dictionary = entities[entity_index]
		if not bool(entity.get("alive", false)):
			continue
		if int(entity.get("attack_runtime", {}).get("cooldown_remaining", 0)) > 0:
			continue
		var target_id: String = String(entity.get("target_id", ""))
		if target_id.is_empty():
			continue
		var target_index: int = _state_helper.find_entity_index(entities, target_id)
		if target_index < 0:
			continue
		var target: Dictionary = entities[target_index]
		if not bool(target.get("alive", false)):
			continue
		ready_attackers.append({"index": entity_index, "entity": entity, "target": target, "target_index": target_index, "in_range": _target_in_range(entity, target)})

	# 公平轮流选择：按 tick 轮询，但只选攻击范围内的单位
	# 如果当前 tick 选中的单位不在范围内，则该 tick 无人攻击
	if not ready_attackers.is_empty():
		var selected_index: int = current_tick % ready_attackers.size()
		var attacker: Dictionary = ready_attackers[selected_index]
		# 只有目标在攻击范围内才执行攻击
		if attacker["in_range"]:
			var entity: Dictionary = attacker["entity"]
			var target: Dictionary = attacker["target"]
			var target_index: int = attacker["target_index"]

			var damage: float = _damage_from_entity(state, entity, target)
			_apply_damage_to_target(state, target_index, damage, entity)
			var attack_runtime: Dictionary = entity.get("attack_runtime", {})
			attack_runtime["cooldown_remaining"] = max(1, int(round(float(state.get("tick_rate", 5)) / max(0.1, float(attack_runtime.get("speed", 1.0))))))
			entity["attack_runtime"] = attack_runtime
			state["last_action"] = {
				"tick": current_tick,
				"type": "attack",
				"actor_id": String(entity.get("entity_id", "")),
				"actor_side": String(entity.get("side", "")),
				"target_id": String(target.get("entity_id", "")),
				"target_side": String(target.get("side", "")),
				"damage": damage
			}
			state["action_log"].append(state["last_action"].duplicate(true))

	for entity_value in entities:
		if typeof(entity_value) != TYPE_DICTIONARY:
			continue
		var entity: Dictionary = entity_value
		var attack_runtime: Dictionary = entity.get("attack_runtime", {})
		attack_runtime["cooldown_remaining"] = max(0, int(attack_runtime.get("cooldown_remaining", 0)) - 1)
		entity["attack_runtime"] = attack_runtime
		_tick_statuses(entity)

	for strategy_value in state.get("strategies", []):
		if typeof(strategy_value) != TYPE_DICTIONARY:
			continue
		var strategy: Dictionary = strategy_value
		strategy["cooldown_remaining"] = max(0, int(strategy.get("cooldown_remaining", 0)) - 1)


func _apply_strategy_effect(state: Dictionary, strategy: Dictionary, command: Dictionary) -> void:
	var strategy_def: Dictionary = strategy.get("source", {})
	var effect: Dictionary = strategy_def.get("effect", {})
	var effect_type: String = String(effect.get("type", ""))
	match effect_type:
		"pulse_damage":
			_damage_side(state, String(effect.get("target_side", "enemy")), float(effect.get("value", 0.0)), strategy)
		"pulse_heal":
			_heal_side(state, String(effect.get("target_side", "friendly")), float(effect.get("value", 0.0)), strategy)
		"pulse_shield":
			_shield_side(state, String(effect.get("target_side", "friendly")), float(effect.get("value", 0.0)), strategy)
		"single_target_damage":
			_damage_single_target(state, String(command.get("target_entity_id", "")), float(effect.get("value", 0.0)), strategy)
		"area_damage":
			var center := _resolve_strategy_center(state, command)
			_damage_area(state, center, float(effect.get("radius", 96.0)), String(effect.get("target_side", "enemy")), float(effect.get("value", 0.0)), strategy)
		_:
			pass
	_mark_strategy_triggered(state, String(strategy.get("id", "")))


func _damage_single_target(state: Dictionary, target_entity_id: String, damage: float, strategy: Dictionary) -> void:
	if target_entity_id.is_empty():
		return
	var target_index: int = _state_helper.find_entity_index(state.get("entities", []), target_entity_id)
	if target_index < 0:
		return
	_apply_damage_to_target(state, target_index, damage, {"entity_id": String(strategy.get("id", "")), "side": "strategy"})
	state["action_log"].append(
		{
			"tick": int(state.get("elapsed_ticks", 0)),
			"type": "strategy_single_target",
			"strategy_id": String(strategy.get("id", "")),
			"target_id": target_entity_id,
			"damage": damage
		}
	)


func _damage_area(state: Dictionary, center: Vector2, radius: float, target_side: String, damage: float, strategy: Dictionary) -> void:
	for entity_index in range(state.get("entities", []).size()):
		var entity: Dictionary = state.get("entities", [])[entity_index]
		if not bool(entity.get("alive", false)):
			continue
		if not _matches_target_side(String(entity.get("side", "")), target_side):
			continue
		var entity_pos: Vector2 = _state_helper.vector_from_value(entity.get("position", []))
		if entity_pos.distance_to(center) > radius:
			continue
		_apply_damage_to_target(state, entity_index, damage, {"entity_id": String(strategy.get("id", "")), "side": "strategy"})
	state["action_log"].append(
		{
			"tick": int(state.get("elapsed_ticks", 0)),
			"type": "strategy_area_damage",
			"strategy_id": String(strategy.get("id", "")),
			"radius": radius,
			"center": _state_helper.array_from_vector(center),
			"damage": damage
		}
	)


func _damage_side(state: Dictionary, target_side: String, damage: float, strategy: Dictionary) -> void:
	for entity_index in range(state.get("entities", []).size()):
		var entity: Dictionary = state.get("entities", [])[entity_index]
		if not bool(entity.get("alive", false)):
			continue
		if not _matches_target_side(String(entity.get("side", "")), target_side):
			continue
		_apply_damage_to_target(state, entity_index, damage, {"entity_id": String(strategy.get("id", "")), "side": "strategy"})
	state["action_log"].append(
		{
			"tick": int(state.get("elapsed_ticks", 0)),
			"type": "strategy_pulse_damage",
			"strategy_id": String(strategy.get("id", "")),
			"damage": damage
		}
	)


func _heal_side(state: Dictionary, target_side: String, value: float, strategy: Dictionary) -> void:
	for entity_value in state.get("entities", []):
		if typeof(entity_value) != TYPE_DICTIONARY:
			continue
		var entity: Dictionary = entity_value
		if not bool(entity.get("alive", false)):
			continue
		if not _matches_target_side(String(entity.get("side", "")), target_side):
			continue
		entity["hp"] = min(float(entity.get("max_hp", 0.0)), float(entity.get("hp", 0.0)) + value)
	state["action_log"].append(
		{
			"tick": int(state.get("elapsed_ticks", 0)),
			"type": "strategy_pulse_heal",
			"strategy_id": String(strategy.get("id", "")),
			"value": value
		}
	)


func _shield_side(state: Dictionary, target_side: String, value: float, strategy: Dictionary) -> void:
	for entity_value in state.get("entities", []):
		if typeof(entity_value) != TYPE_DICTIONARY:
			continue
		var entity: Dictionary = entity_value
		if not bool(entity.get("alive", false)):
			continue
		if not _matches_target_side(String(entity.get("side", "")), target_side):
			continue
		entity["shield"] = float(entity.get("shield", 0.0)) + value
	state["action_log"].append(
		{
			"tick": int(state.get("elapsed_ticks", 0)),
			"type": "strategy_pulse_shield",
			"strategy_id": String(strategy.get("id", "")),
			"value": value
		}
	)


func _apply_damage_to_target(state: Dictionary, target_index: int, damage: float, actor: Dictionary) -> void:
	if damage <= 0.0:
		return
	var entities: Array = state.get("entities", [])
	var target: Dictionary = entities[target_index]
	if not bool(target.get("alive", false)):
		return
	var shield_value: float = float(target.get("shield", 0.0))
	var remaining_damage: float = damage
	if shield_value > 0.0:
		var absorbed: float = min(shield_value, remaining_damage)
		target["shield"] = shield_value - absorbed
		remaining_damage -= absorbed
	if remaining_damage > 0.0:
		target["hp"] = max(0.0, float(target.get("hp", 0.0)) - remaining_damage)
	if float(target.get("hp", 0.0)) <= 0.0:
		target["alive"] = false
		target["target_id"] = ""
		state["action_log"].append(
			{
				"tick": int(state.get("elapsed_ticks", 0)),
				"type": "death",
				"actor_id": String(actor.get("entity_id", "")),
				"target_id": String(target.get("entity_id", "")),
				"target_side": String(target.get("side", ""))
			}
		)


func _damage_from_entity(state: Dictionary, entity: Dictionary, target: Dictionary) -> float:
	var attack_runtime: Dictionary = entity.get("attack_runtime", {})
	var damage: float = float(attack_runtime.get("power", 1.0))
	damage *= _status_attack_multiplier(entity)
	damage += _strategy_bonus_damage(state, entity, target)
	return max(0.5, damage)


func _strategy_bonus_damage(state: Dictionary, entity: Dictionary, target: Dictionary) -> float:
	var bonus := 0.0
	var source_side: String = String(entity.get("side", ""))
	if source_side != "hero" and source_side != "ally":
		return bonus
	for strategy_value in state.get("strategies", []):
		if typeof(strategy_value) != TYPE_DICTIONARY:
			continue
		var strategy: Dictionary = strategy_value
		var strategy_def: Dictionary = strategy.get("source", {})
		if String(strategy_def.get("kind", "")) != "passive":
			continue
		var effect: Dictionary = strategy_def.get("effect", {})
		if String(effect.get("type", "")) != "tag_bonus_damage":
			continue
		var tag: String = String(effect.get("tag", ""))
		if target.get("tags", []).has(tag):
			bonus += float(effect.get("bonus_damage", 0.0))
			_mark_strategy_triggered(state, String(strategy.get("id", "")))
	return bonus


func _status_attack_multiplier(entity: Dictionary) -> float:
	var multiplier := 1.0
	for status_value in entity.get("status_effects", []):
		if typeof(status_value) != TYPE_DICTIONARY:
			continue
		var status: Dictionary = status_value
		if String(status.get("kind", "")) == "attack_mult":
			multiplier *= float(status.get("value", 1.0))
	return multiplier


func _tick_statuses(entity: Dictionary) -> void:
	var remaining_statuses: Array = []
	for status_value in entity.get("status_effects", []):
		if typeof(status_value) != TYPE_DICTIONARY:
			continue
		var status: Dictionary = status_value
		var remaining_ticks: int = int(status.get("remaining_ticks", 0)) - 1
		if remaining_ticks > 0:
			status["remaining_ticks"] = remaining_ticks
			remaining_statuses.append(status)
	entity["status_effects"] = remaining_statuses


func _target_in_range(entity: Dictionary, target: Dictionary) -> bool:
	var entity_pos: Vector2 = _state_helper.vector_from_value(entity.get("position", []))
	var target_pos: Vector2 = _state_helper.vector_from_value(target.get("position", []))
	var combined_radius: float = float(entity.get("collision_radius", 18.0)) + float(target.get("collision_radius", 18.0))
	var spacing_distance: float = max(0.0, entity_pos.distance_to(target_pos) - combined_radius)
	return spacing_distance <= _state_helper.unit_range_pixels(entity.get("attack_runtime", {}))


func _strategy_runtime(state: Dictionary, strategy_id: String) -> Dictionary:
	for strategy_value in state.get("strategies", []):
		if typeof(strategy_value) != TYPE_DICTIONARY:
			continue
		var strategy: Dictionary = strategy_value
		if String(strategy.get("id", "")) == strategy_id:
			return strategy
	return {}


func _mark_strategy_triggered(state: Dictionary, strategy_id: String) -> void:
	if strategy_id.is_empty():
		return
	if not state.get("triggered_strategy_ids", []).has(strategy_id):
		state["triggered_strategy_ids"].append(strategy_id)


func apply_buff_to_side(state: Dictionary, target_side: String, buff_kind: String, value: float, duration_ticks: int, event_id: String) -> void:
	for entity_value in state.get("entities", []):
		if typeof(entity_value) != TYPE_DICTIONARY:
			continue
		var entity: Dictionary = entity_value
		if not bool(entity.get("alive", false)):
			continue
		if not _matches_target_side(String(entity.get("side", "")), target_side):
			continue
		entity["status_effects"].append(
			{
				"kind": buff_kind,
				"value": value,
				"remaining_ticks": duration_ticks,
				"source_event_id": event_id
			}
		)


func _matches_target_side(entity_side: String, target_side: String) -> bool:
	if target_side == "friendly":
		return entity_side == "hero" or entity_side == "ally"
	return entity_side == target_side


func _resolve_strategy_center(state: Dictionary, command: Dictionary) -> Vector2:
	if command.has("center"):
		return _state_helper.vector_from_value(command.get("center"), Vector2(620, 240))
	var target_id: String = String(command.get("target_entity_id", ""))
	if not target_id.is_empty():
		var entity := _state_helper.find_entity(state.get("entities", []), target_id)
		if not entity.is_empty():
			return _state_helper.vector_from_value(entity.get("position", []), Vector2(620, 240))
	return Vector2(620, 240)
