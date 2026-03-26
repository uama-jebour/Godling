extends RefCounted

const TICK_LIMIT := 60
const REINFORCE_TRIGGER_TIME := 20
const HERO_BASE_POWER_MULTIPLIER := 2.1
const RELIC_BONUS_PER_RELIC := 0.12
const HERO_PRIMARY_DAMAGE_MULTIPLIER := 1.15
const HERO_BURST_DAMAGE_MULTIPLIER := 0.72
const HERO_GUARD_DAMAGE_FACTOR := 0.22
const ENEMY_PHASE_ATTACKER_LIMIT := 2
const ENEMY_DAMAGE_DIVISOR := 7.5
const ENEMY_DAMAGE_FLOOR := 0.8
const INITIAL_HERO_RESOLVE := 3
const HERO_RESOLVE_MAX := 4
const RESOLVE_GAIN_ON_WAIT := 1
const RESOLVE_GAIN_ON_ENEMY_PHASE_END := 1
const RESOLVE_GAIN_ON_GUARD := 1
const PRIMARY_COOLDOWN := 0
const GUARD_COOLDOWN := 2
const BURST_COOLDOWN := 2
const PRIMARY_COST := 1
const GUARD_COST := 1
const BURST_COST := 2
const FIELD_BALM_RECOVER_HP := 16.0


func initialize_state(request: Dictionary, battle_def: Dictionary, content_db: Node) -> Dictionary:
	if content_db == null:
		return {"invalid_reason": "missing_content_db"}

	var hero_snapshot: Dictionary = request.get("hero_snapshot", {})
	var hero_unit: Dictionary = content_db.get_unit(String(hero_snapshot.get("hero_id", "")))
	if hero_unit.is_empty():
		return {"invalid_reason": "missing_hero_unit"}

	var hero_runtime_stats: Dictionary = hero_snapshot.get("runtime_stats", {})
	var hero_max_hp: float = float(hero_runtime_stats.get("hp", hero_unit.get("hp", 0)))
	var hero_attack: float = float(hero_runtime_stats.get("attack_power", _unit_attack_power(hero_unit))) * _hero_power_modifier(request)

	var enemy_total_hp: float = 0.0
	var enemy_unit_total: int = 0
	var enemy_units: Array = []
	var enemy_entities: Array = []
	var enemy_entity_index: int = 0
	for group_value in battle_def.get("enemy_groups", []):
		if typeof(group_value) != TYPE_DICTIONARY:
			continue
		var group: Dictionary = group_value
		var unit_id: String = String(group.get("unit_id", ""))
		var unit_def: Dictionary = content_db.get_unit(unit_id)
		if unit_def.is_empty():
			return {"invalid_reason": "missing_enemy_unit"}
		var count: int = _resolve_enemy_group_count(group)
		if count <= 0:
			continue
		enemy_unit_total += count
		enemy_units.append({"unit_id": unit_id, "count": count})
		enemy_total_hp += float(unit_def.get("hp", 0)) * count
		var spawn: Array = group.get("spawn", [540, 180])
		for i in range(count):
			enemy_entity_index += 1
			enemy_entities.append(_create_enemy_entity(enemy_entity_index, unit_def, spawn, i))

	return {
		"content_db": content_db,
		"battle_def": battle_def.duplicate(true),
		"request": request.duplicate(true),
		"hero_unit": hero_unit.duplicate(true),
		"hero_hp": hero_max_hp,
		"hero_max_hp": hero_max_hp,
		"hero_attack": hero_attack,
		"hero_entity": _create_hero_entity(hero_unit, hero_max_hp, hero_attack),
		"enemy_total_hp": enemy_total_hp,
		"enemy_total_attack": _living_enemy_total_attack({"enemy_entities": enemy_entities}),
		"enemy_unit_total": enemy_unit_total,
		"enemy_units": enemy_units,
		"enemy_entities": enemy_entities,
		"events_triggered": [],
		"elapsed": 0,
		"turn_phase": "player",
		"selected_target_id": _first_alive_enemy_id(enemy_entities),
		"skill_slots": _default_skill_slots(),
		"hero_resolve": _balance_int("battle.initial_hero_resolve", INITIAL_HERO_RESOLVE),
		"hero_resolve_max": _balance_int("battle.hero_resolve_max", HERO_RESOLVE_MAX),
		"battle_items": _extract_battle_items(hero_snapshot, content_db),
		"consumed_items": [],
		"guard_active": false,
		"enemy_turn_queue": [],
		"enemy_turn_index": 0,
		"action_seq": 0,
		"last_action": {},
		"status_text": "选择一个敌人并发动攻击。"
	}


func step_once(state: Dictionary) -> Dictionary:
	if state.has("invalid_reason"):
		return state
	if not is_battle_active(state):
		return state

	var target_id: String = _first_alive_enemy_id(state.get("enemy_entities", []))
	state = apply_player_attack(state, target_id)
	while is_battle_active(state) and String(state.get("turn_phase", "")) == "enemy":
		state = apply_enemy_phase(state)
	return state


func apply_player_burst(state: Dictionary) -> Dictionary:
	if state.has("invalid_reason"):
		return state
	if not is_battle_active(state):
		return state
	if String(state.get("turn_phase", "player")) != "player":
		state["status_text"] = "当前不是我方行动阶段。"
		return state
	var skill_gate: Dictionary = _validate_skill_usage(state, "burst")
	if not bool(skill_gate.get("ok", false)):
		state["status_text"] = String(skill_gate.get("reason", "该技能暂时无法使用。"))
		return state
	var hero_entity: Dictionary = state.get("hero_entity", {})
	if not bool(hero_entity.get("is_alive", true)):
		state["status_text"] = "英雄已倒下。"
		return state
	var targets_hit: int = 0
	var damage: float = float(state.get("hero_attack", 0.0)) * _balance_float("skills.burst_damage_multiplier", HERO_BURST_DAMAGE_MULTIPLIER)
	for enemy_entity_value in state.get("enemy_entities", []):
		if typeof(enemy_entity_value) != TYPE_DICTIONARY:
			continue
		var enemy_entity: Dictionary = enemy_entity_value
		if not bool(enemy_entity.get("is_alive", true)):
			continue
		_apply_damage_to_target_entity(state, String(enemy_entity.get("entity_id", "")), damage)
		targets_hit += 1
	_commit_skill_use(state, "burst")
	state["enemy_total_hp"] = _living_enemy_total_hp(state)
	state["enemy_total_attack"] = _living_enemy_total_attack(state)
	state["selected_target_id"] = _first_alive_enemy_id(state.get("enemy_entities", []))
	_push_last_action(state, {
		"actor_id": String(hero_entity.get("entity_id", "hero_1")),
		"actor_side": "hero",
		"actor_name": String(hero_entity.get("display_name", "Hero")),
		"target_id": "enemy_all",
		"target_name": "敌方全体",
		"target_side": "enemy",
		"skill_slot": "burst",
		"damage": damage,
		"targets_hit": targets_hit,
		"phase": "burst"
	})
	if float(state.get("enemy_total_hp", 0.0)) <= 0.0:
		state["turn_phase"] = "finished"
		state["status_text"] = "敌方被全部清除。"
		return state
	state["guard_active"] = false
	state["enemy_turn_queue"] = []
	state["enemy_turn_index"] = 0
	state["turn_phase"] = "enemy"
	state["status_text"] = "祷焰横扫撕开敌阵，敌方准备反击。"
	return state


func apply_player_attack(state: Dictionary, target_entity_id: String) -> Dictionary:
	if state.has("invalid_reason"):
		return state
	if not is_battle_active(state):
		return state
	if String(state.get("turn_phase", "player")) != "player":
		state["status_text"] = "当前不是我方行动阶段。"
		return state
	var skill_gate: Dictionary = _validate_skill_usage(state, "primary")
	if not bool(skill_gate.get("ok", false)):
		state["status_text"] = String(skill_gate.get("reason", "该技能暂时无法使用。"))
		return state

	var hero_entity: Dictionary = state.get("hero_entity", {})
	if not bool(hero_entity.get("is_alive", true)):
		state["status_text"] = "英雄已倒下。"
		return state

	var target: Dictionary = _find_alive_enemy_entity(state.get("enemy_entities", []), target_entity_id)
	if target.is_empty():
		state["status_text"] = "请选择有效目标。"
		return state

	var damage: float = float(state.get("hero_attack", 0.0)) * _balance_float("skills.primary_damage_multiplier", HERO_PRIMARY_DAMAGE_MULTIPLIER)
	_apply_damage_to_target_entity(state, String(target.get("entity_id", "")), damage)
	_commit_skill_use(state, "primary")
	state["enemy_total_hp"] = _living_enemy_total_hp(state)
	state["enemy_total_attack"] = _living_enemy_total_attack(state)
	state["selected_target_id"] = _first_alive_enemy_id(state.get("enemy_entities", []))
	_push_last_action(state, {
		"actor_id": String(hero_entity.get("entity_id", "hero_1")),
		"actor_side": "hero",
		"actor_name": String(hero_entity.get("display_name", "Hero")),
		"target_id": String(target.get("entity_id", "")),
		"target_name": String(target.get("display_name", "Enemy")),
		"target_side": "enemy",
		"skill_slot": "primary",
		"damage": damage,
		"phase": "player"
	})
	if float(state.get("enemy_total_hp", 0.0)) <= 0.0:
		state["turn_phase"] = "finished"
		state["status_text"] = "敌方被全部清除。"
		return state

	state["guard_active"] = false
	state["enemy_turn_queue"] = []
	state["enemy_turn_index"] = 0
	state["turn_phase"] = "enemy"
	state["status_text"] = "敌方准备反击。"
	return state


func apply_player_defend(state: Dictionary) -> Dictionary:
	if state.has("invalid_reason"):
		return state
	if not is_battle_active(state):
		return state
	if String(state.get("turn_phase", "player")) != "player":
		return state
	var skill_gate: Dictionary = _validate_skill_usage(state, "guard")
	if not bool(skill_gate.get("ok", false)):
		state["status_text"] = String(skill_gate.get("reason", "该技能暂时无法使用。"))
		return state
	var hero_entity: Dictionary = state.get("hero_entity", {})
	_commit_skill_use(state, "guard")
	state["guard_active"] = true
	state["hero_resolve"] = min(int(state.get("hero_resolve_max", HERO_RESOLVE_MAX)), int(state.get("hero_resolve", 0)) + _balance_int("battle.resolve_gain_on_guard", RESOLVE_GAIN_ON_GUARD))
	_push_last_action(state, {
		"actor_id": String(hero_entity.get("entity_id", "hero_1")),
		"actor_side": "hero",
		"actor_name": String(hero_entity.get("display_name", "Hero")),
		"target_id": "hero_1",
		"target_name": "防御架势",
		"target_side": "hero",
		"skill_slot": "guard",
		"damage": 0.0,
		"phase": "defend"
	})
	state["turn_phase"] = "enemy"
	state["enemy_turn_queue"] = []
	state["enemy_turn_index"] = 0
	state["status_text"] = "你摆出了防御姿态。"
	return state


func apply_player_wait(state: Dictionary) -> Dictionary:
	if state.has("invalid_reason"):
		return state
	if not is_battle_active(state):
		return state
	if String(state.get("turn_phase", "player")) != "player":
		return state
	state["hero_resolve"] = min(int(state.get("hero_resolve_max", HERO_RESOLVE_MAX)), int(state.get("hero_resolve", 0)) + _balance_int("battle.resolve_gain_on_wait", RESOLVE_GAIN_ON_WAIT))
	var hero_entity: Dictionary = state.get("hero_entity", {})
	state["guard_active"] = false
	_push_last_action(state, {
		"actor_id": String(hero_entity.get("entity_id", "hero_1")),
		"actor_side": "hero",
		"actor_name": String(hero_entity.get("display_name", "Hero")),
		"target_id": "",
		"target_name": "观察战局",
		"target_side": "",
		"damage": 0.0,
		"phase": "wait"
	})
	state["turn_phase"] = "enemy"
	state["enemy_turn_queue"] = []
	state["enemy_turn_index"] = 0
	state["status_text"] = "你暂时保持阵型。"
	return state


func apply_player_item(state: Dictionary, item_id: String) -> Dictionary:
	if state.has("invalid_reason"):
		return state
	if not is_battle_active(state):
		return state
	if String(state.get("turn_phase", "player")) != "player":
		return state
	if item_id.is_empty():
		state["status_text"] = "当前没有可用道具。"
		return state
	var item_effect: Dictionary = _find_battle_item_effect(state, item_id)
	if item_effect.is_empty():
		state["status_text"] = "该道具无法在战斗中使用。"
		return state
	if not _consume_battle_item(state, item_id):
		state["status_text"] = "道具数量不足。"
		return state

	var hero_entity: Dictionary = state.get("hero_entity", {})
	var recover_value: float = float(item_effect.get("recover_hp", 0.0))
	if recover_value > 0.0:
		state["hero_hp"] = min(float(state.get("hero_max_hp", 0.0)), float(state.get("hero_hp", 0.0)) + recover_value)
	hero_entity["current_hp"] = max(0.0, float(state.get("hero_hp", 0.0)))
	hero_entity["is_alive"] = float(state.get("hero_hp", 0.0)) > 0.0
	state["hero_entity"] = hero_entity
	state["guard_active"] = false
	_push_last_action(state, {
		"actor_id": String(hero_entity.get("entity_id", "hero_1")),
		"actor_side": "hero",
		"actor_name": String(hero_entity.get("display_name", "Hero")),
		"target_id": "hero_1",
		"target_name": String(item_effect.get("display_name", item_id)),
		"target_side": "hero",
		"damage": -recover_value,
		"phase": "item"
	})
	state["turn_phase"] = "enemy"
	state["enemy_turn_queue"] = []
	state["enemy_turn_index"] = 0
	state["status_text"] = "已使用 %s，准备承受敌方回合。" % String(item_effect.get("display_name", item_id))
	return state


func apply_enemy_phase(state: Dictionary) -> Dictionary:
	if state.has("invalid_reason"):
		return state
	if not is_battle_active(state):
		return state
	if String(state.get("turn_phase", "player")) != "enemy":
		return state

	if state.get("enemy_turn_queue", []).is_empty():
		state["elapsed"] = int(state.get("elapsed", 0)) + 1
		_trigger_battle_events(state)
		state["enemy_total_hp"] = _living_enemy_total_hp(state)
		state["enemy_total_attack"] = _living_enemy_total_attack(state)
		state["enemy_turn_queue"] = _living_enemy_turn_queue(state)
		state["enemy_turn_index"] = 0
		if state["enemy_turn_queue"].is_empty():
			state["last_action"] = {}
			return _finalize_enemy_phase(state)

	var queue: Array = state.get("enemy_turn_queue", [])
	var turn_index: int = int(state.get("enemy_turn_index", 0))
	if turn_index >= queue.size():
		return _finalize_enemy_phase(state)

	var enemy_actor: Dictionary = queue[turn_index]
	var hero_damage: float = max(_balance_float("battle.enemy_damage_floor", ENEMY_DAMAGE_FLOOR), float(enemy_actor.get("attack_power", 0.0)) / _balance_float("battle.enemy_damage_divisor", ENEMY_DAMAGE_DIVISOR))
	if bool(state.get("guard_active", false)):
		hero_damage *= _balance_float("skills.guard_damage_factor", HERO_GUARD_DAMAGE_FACTOR)
	state["hero_hp"] = max(0.0, float(state.get("hero_hp", 0.0)) - hero_damage)
	_push_last_action(state, {
		"actor_id": String(enemy_actor.get("entity_id", "enemy")),
		"actor_side": "enemy",
		"actor_name": String(enemy_actor.get("display_name", "Enemy")),
		"target_id": "hero_1",
		"target_name": String(state.get("hero_entity", {}).get("display_name", "Hero")),
		"target_side": "hero",
		"damage": hero_damage,
		"phase": "enemy"
	})
	state["enemy_turn_index"] = turn_index + 1

	var hero_entity: Dictionary = state.get("hero_entity", {})
	hero_entity["current_hp"] = max(0.0, float(state.get("hero_hp", 0.0)))
	hero_entity["is_alive"] = float(state.get("hero_hp", 0.0)) > 0.0
	state["hero_entity"] = hero_entity
	state["selected_target_id"] = _first_alive_enemy_id(state.get("enemy_entities", []))
	if not bool(hero_entity.get("is_alive", true)):
		return _finalize_enemy_phase(state)
	if int(state.get("enemy_turn_index", 0)) >= queue.size():
		return _finalize_enemy_phase(state)
	state["turn_phase"] = "enemy"
	state["status_text"] = "%s 正在发动反击。" % String(enemy_actor.get("display_name", "Enemy"))
	return state


func is_battle_active(state: Dictionary) -> bool:
	if state.has("invalid_reason"):
		return false
	return (
		int(state.get("elapsed", 0)) < _balance_int("battle.tick_limit", TICK_LIMIT)
		and float(state.get("hero_hp", 0.0)) > 0.0
		and float(state.get("enemy_total_hp", 0.0)) > 0.0
	)


func build_result(state: Dictionary, context: Dictionary = {}, backend: String = "headless") -> Dictionary:
	if state.has("invalid_reason"):
		return _invalid_result(String(state.get("invalid_reason", "invalid_request")))

	var battle_def: Dictionary = state.get("battle_def", {})
	var hero_unit: Dictionary = state.get("hero_unit", {})
	var victory_type: String = String(battle_def.get("victory_type", ""))
	var survived: bool = float(state.get("hero_hp", 0.0)) > 0.0
	var enemies_cleared: bool = float(state.get("enemy_total_hp", 0.0)) <= 0.0
	var elapsed: int = int(state.get("elapsed", 0))
	var events_triggered: Array = state.get("events_triggered", [])
	var victory: bool = _resolve_victory(victory_type, survived, enemies_cleared, elapsed)
	if context.has("success_override"):
		victory = bool(context.get("success_override", victory))

	return {
		"status": "battle_runner_resolved",
		"victory": victory,
		"defeat_reason": "" if victory else _defeat_reason(victory_type, survived, enemies_cleared),
		"casualties": [] if victory else [{"unit_id": String(hero_unit.get("id", "")), "count": 1}],
		"completed_objectives": _completed_objectives(victory, victory_type, elapsed, events_triggered),
		"spawned_story_flags": [],
		"spawned_unlock_flags": [],
		"map_effects": {
			"battle_id": String(battle_def.get("id", "")),
			"backend": backend,
			"victory_type": victory_type,
			"elapsed_ticks": elapsed,
			"battle_events_triggered": events_triggered.duplicate(true),
			"enemy_units": state.get("enemy_units", []).duplicate(true),
			"enemy_entities": state.get("enemy_entities", []).duplicate(true),
			"hero_entity": state.get("hero_entity", {}).duplicate(true),
			"battle_items": state.get("battle_items", []).duplicate(true),
			"consumed_items": state.get("consumed_items", []).duplicate(true),
			"enemy_count_total": int(state.get("enemy_unit_total", 0)),
			"hero_hp_remaining": max(float(state.get("hero_hp", 0.0)), 0.0),
			"enemy_hp_remaining": max(float(state.get("enemy_total_hp", 0.0)), 0.0)
		}
	}


func _create_hero_entity(hero_unit: Dictionary, hero_hp: float, hero_attack: float) -> Dictionary:
	return {
		"entity_id": "hero_1",
		"side": "hero",
		"unit_id": String(hero_unit.get("id", "")),
		"display_name": String(hero_unit.get("name_cn", hero_unit.get("id", ""))),
		"current_hp": hero_hp,
		"max_hp": hero_hp,
		"attack_power": hero_attack,
		"position": [120, 190],
		"is_alive": true
	}


func _create_enemy_entity(entity_index: int, unit_def: Dictionary, spawn: Array, offset_index: int) -> Dictionary:
	var base_x: float = float(spawn[0]) if spawn.size() > 0 else 540.0
	var base_y: float = float(spawn[1]) if spawn.size() > 1 else 180.0
	var row: int = int(offset_index / 2)
	var column: int = offset_index % 2
	return {
		"entity_id": "enemy_%d" % entity_index,
		"side": "enemy",
		"unit_id": String(unit_def.get("id", "")),
		"display_name": String(unit_def.get("name_cn", unit_def.get("id", ""))),
		"current_hp": float(unit_def.get("hp", 0)),
		"max_hp": float(unit_def.get("hp", 0)),
		"attack_power": _unit_attack_power(unit_def),
		"position": [base_x + (column * 86.0), base_y + (row * 64.0)],
		"is_alive": true
	}


func _resolve_enemy_group_count(group: Dictionary) -> int:
	var count_range: Array = group.get("count_range", [])
	if count_range.size() >= 2:
		var min_count: int = int(count_range[0])
		var max_count: int = int(count_range[1])
		if max_count < min_count:
			var swap := min_count
			min_count = max_count
			max_count = swap
		return randi_range(max(0, min_count), max(0, max_count))
	return int(group.get("count", 0))


func _apply_damage_to_target_entity(state: Dictionary, target_entity_id: String, damage: float) -> void:
	if target_entity_id.is_empty() or damage <= 0.0:
		return
	for enemy_entity_value in state.get("enemy_entities", []):
		if typeof(enemy_entity_value) != TYPE_DICTIONARY:
			continue
		var enemy_entity: Dictionary = enemy_entity_value
		if String(enemy_entity.get("entity_id", "")) != target_entity_id:
			continue
		if not bool(enemy_entity.get("is_alive", true)):
			return
		var current_hp: float = float(enemy_entity.get("current_hp", 0.0))
		current_hp = max(0.0, current_hp - damage)
		enemy_entity["current_hp"] = current_hp
		enemy_entity["is_alive"] = current_hp > 0.0
		return


func _apply_damage_to_enemy_entities(state: Dictionary, damage: float) -> void:
	var target_entity_id: String = _first_alive_enemy_id(state.get("enemy_entities", []))
	_apply_damage_to_target_entity(state, target_entity_id, damage)


func _living_enemy_total_hp(state: Dictionary) -> float:
	var total_hp: float = 0.0
	for enemy_entity_value in state.get("enemy_entities", []):
		if typeof(enemy_entity_value) != TYPE_DICTIONARY:
			continue
		var enemy_entity: Dictionary = enemy_entity_value
		if not bool(enemy_entity.get("is_alive", true)):
			continue
		total_hp += max(0.0, float(enemy_entity.get("current_hp", 0.0)))
	return total_hp


func _living_enemy_total_attack(state: Dictionary) -> float:
	var total_attack: float = 0.0
	for enemy_entity_value in state.get("enemy_entities", []):
		if typeof(enemy_entity_value) != TYPE_DICTIONARY:
			continue
		var enemy_entity: Dictionary = enemy_entity_value
		if not bool(enemy_entity.get("is_alive", true)):
			continue
		total_attack += max(0.0, float(enemy_entity.get("attack_power", 0.0)))
	return total_attack


func _living_enemy_turn_queue(state: Dictionary) -> Array:
	var queue: Array = []
	for enemy_entity_value in state.get("enemy_entities", []):
		if typeof(enemy_entity_value) != TYPE_DICTIONARY:
			continue
		var enemy_entity: Dictionary = enemy_entity_value
		if not bool(enemy_entity.get("is_alive", true)):
			continue
		queue.append(enemy_entity.duplicate(true))
	return queue


func _finalize_enemy_phase(state: Dictionary) -> Dictionary:
	var hero_entity: Dictionary = state.get("hero_entity", {})
	hero_entity["current_hp"] = max(0.0, float(state.get("hero_hp", 0.0)))
	hero_entity["is_alive"] = float(state.get("hero_hp", 0.0)) > 0.0
	state["hero_entity"] = hero_entity
	state["selected_target_id"] = _first_alive_enemy_id(state.get("enemy_entities", []))
	state["guard_active"] = false
	state["enemy_turn_queue"] = []
	state["enemy_turn_index"] = 0
	_advance_skill_cooldowns(state)
	state["hero_resolve"] = min(int(state.get("hero_resolve_max", HERO_RESOLVE_MAX)), int(state.get("hero_resolve", 0)) + _balance_int("battle.resolve_gain_on_enemy_phase", RESOLVE_GAIN_ON_ENEMY_PHASE_END))
	if not bool(hero_entity.get("is_alive", true)):
		state["turn_phase"] = "finished"
		state["status_text"] = "英雄已倒下，战斗失败。"
	elif float(state.get("enemy_total_hp", 0.0)) <= 0.0:
		state["turn_phase"] = "finished"
		state["status_text"] = "敌方被全部清除。"
	else:
		state["turn_phase"] = "player"
		state["status_text"] = "敌方反击结束，请选择下一名目标。"
	return state


func _trigger_battle_events(state: Dictionary) -> void:
	var battle_def: Dictionary = state.get("battle_def", {})
	var content_db: Node = state.get("content_db")
	for battle_event_value in _load_battle_events(content_db, battle_def.get("battle_event_ids", [])):
		if typeof(battle_event_value) != TYPE_DICTIONARY:
			continue
		var battle_event: Dictionary = battle_event_value
		if not _should_trigger_battle_event(battle_event, int(state.get("elapsed", 0)), state.get("events_triggered", [])):
			continue
		state["events_triggered"].append(String(battle_event.get("id", "")))
		var payload: Dictionary = battle_event.get("payload", {})
		if String(battle_event.get("event_type", "")) == "summon":
			var summon_unit: Dictionary = content_db.get_unit(String(payload.get("unit_id", "")))
			var summon_count: int = int(payload.get("count", 0))
			if not summon_unit.is_empty() and summon_count > 0:
				state["enemy_units"].append({"unit_id": String(payload.get("unit_id", "")), "count": summon_count})
				state["enemy_unit_total"] = int(state.get("enemy_unit_total", 0)) + summon_count
				var next_index: int = state.get("enemy_entities", []).size()
				for summon_idx in range(summon_count):
					next_index += 1
					state["enemy_entities"].append(_create_enemy_entity(next_index, summon_unit, [680, 140], summon_idx))
				state["enemy_total_hp"] = _living_enemy_total_hp(state)
				state["enemy_total_attack"] = _living_enemy_total_attack(state)


func _load_battle_events(content_db: Node, battle_event_ids: Array) -> Array:
	var loaded: Array = []
	for battle_event_id_value in battle_event_ids:
		var battle_event_id: String = String(battle_event_id_value)
		var battle_event: Dictionary = content_db.get_battle_event(battle_event_id)
		if not battle_event.is_empty():
			loaded.append(battle_event)
	return loaded


func _should_trigger_battle_event(battle_event: Dictionary, elapsed: int, events_triggered: Array) -> bool:
	var battle_event_id: String = String(battle_event.get("id", ""))
	if battle_event_id.is_empty() or events_triggered.has(battle_event_id):
		return false
	for trigger_value in battle_event.get("trigger", []):
		var trigger: String = String(trigger_value)
		if trigger.begins_with("elapsed>="):
			return elapsed >= int(trigger.trim_prefix("elapsed>="))
	return false


func _resolve_victory(victory_type: String, survived: bool, enemies_cleared: bool, elapsed: int) -> bool:
	match victory_type:
		"eliminate_all":
			return enemies_cleared and survived
		"kill_target":
			return enemies_cleared and survived
		"survive_and_clear":
			return survived and (enemies_cleared or elapsed >= REINFORCE_TRIGGER_TIME)
		"reach_exit":
			return survived and elapsed >= 12
		_:
			return enemies_cleared and survived


func _defeat_reason(victory_type: String, survived: bool, enemies_cleared: bool) -> String:
	if not survived:
		return "hero_down"
	if victory_type == "reach_exit":
		return "failed_to_reach_exit"
	if not enemies_cleared:
		return "objective_not_completed"
	return "battle_failed"


func _completed_objectives(victory: bool, victory_type: String, elapsed: int, events_triggered: Array) -> Array:
	if not victory:
		return []
	var objectives: Array = ["objective_%s" % victory_type]
	if not events_triggered.is_empty():
		objectives.append("triggered_%d_battle_events" % events_triggered.size())
	if elapsed > 0:
		objectives.append("elapsed_%d_ticks" % elapsed)
	return objectives


func _hero_power_modifier(request: Dictionary) -> float:
	var modifiers: Array = request.get("equipped_relic_modifiers", [])
	return _balance_float("battle.hero_base_power_multiplier", HERO_BASE_POWER_MULTIPLIER) + (float(modifiers.size()) * _balance_float("battle.relic_bonus_per_relic", RELIC_BONUS_PER_RELIC))


func _unit_attack_power(unit_def: Dictionary) -> float:
	var attack: Dictionary = unit_def.get("attack", {})
	return max(1.0, float(attack.get("power", 1))) * max(0.5, float(attack.get("speed", 1.0)))


func _first_alive_enemy_id(enemy_entities: Array) -> String:
	for enemy_entity_value in enemy_entities:
		if typeof(enemy_entity_value) != TYPE_DICTIONARY:
			continue
		var enemy_entity: Dictionary = enemy_entity_value
		if bool(enemy_entity.get("is_alive", true)):
			return String(enemy_entity.get("entity_id", ""))
	return ""


func _find_alive_enemy_entity(enemy_entities: Array, entity_id: String) -> Dictionary:
	for enemy_entity_value in enemy_entities:
		if typeof(enemy_entity_value) != TYPE_DICTIONARY:
			continue
		var enemy_entity: Dictionary = enemy_entity_value
		if String(enemy_entity.get("entity_id", "")) != entity_id:
			continue
		if bool(enemy_entity.get("is_alive", true)):
			return enemy_entity
	return {}


func _default_skill_slots() -> Array:
	return [
		{
			"slot": "primary",
			"skill_id": "skill_basic_slash",
			"name_cn": "斩击",
			"command": "attack",
			"description": "迅速前压，对选中的敌人造成高于基础值的稳定伤害。",
			"cooldown_max": _balance_int("skills.primary_cooldown", PRIMARY_COOLDOWN),
			"cooldown_remaining": 0,
			"resource_kind": "resolve",
			"resource_cost": _balance_int("skills.primary_cost", PRIMARY_COST)
		},
		{
			"slot": "guard",
			"skill_id": "skill_basic_guard",
			"name_cn": "架盾",
			"command": "defend",
			"description": "稳住阵线，本轮大幅降低敌方反击伤害，并回复1点灵势。",
			"cooldown_max": _balance_int("skills.guard_cooldown", GUARD_COOLDOWN),
			"cooldown_remaining": 0,
			"resource_kind": "resolve",
			"resource_cost": _balance_int("skills.guard_cost", GUARD_COST)
		},
		{
			"slot": "burst",
			"skill_id": "skill_litany_sweep",
			"name_cn": "祷焰横扫",
			"command": "burst",
			"description": "以较高灵势代价压制敌方全体，适合处理多目标战局。",
			"cooldown_max": _balance_int("skills.burst_cooldown", BURST_COOLDOWN),
			"cooldown_remaining": 0,
			"resource_kind": "resolve",
			"resource_cost": _balance_int("skills.burst_cost", BURST_COST)
		}
	]


func _extract_battle_items(hero_snapshot: Dictionary, content_db: Node) -> Array:
	var stacks: Array = []
	for stack_value in hero_snapshot.get("temporary_inventory", []):
		if typeof(stack_value) != TYPE_DICTIONARY:
			continue
		var stack: Dictionary = stack_value
		var item_id: String = String(stack.get("id", ""))
		if item_id.is_empty():
			continue
		var item_def: Dictionary = content_db.get_item(item_id)
		if int(item_def.get("type", 0)) != 6:
			continue
		var count: int = int(stack.get("count", 0))
		if count <= 0:
			continue
		var effect: Dictionary = _battle_item_effect(item_def)
		if effect.is_empty():
			continue
		stacks.append(
			{
				"id": item_id,
				"name_cn": String(item_def.get("name_cn", item_id)),
				"description": String(item_def.get("description", "")),
				"count": count,
				"target_type": _item_target_type_text(effect),
				"icon_path": String(content_db.get_item_visual(item_id).get("icon_path", "res://icon.svg")),
				"effect": effect
			}
		)
	return stacks


func _battle_item_effect(item_def: Dictionary) -> Dictionary:
	var combat_effect: Dictionary = item_def.get("combat_effect", {})
	var effect_kind: String = String(combat_effect.get("kind", ""))
	if effect_kind == "heal":
		return {
			"kind": "heal",
			"recover_hp": float(combat_effect.get("value", 0.0)),
			"display_name": String(item_def.get("name_cn", item_def.get("id", "")))
		}
	if String(item_def.get("id", "")) == "consumable_field_balm":
		return {
			"kind": "heal",
			"recover_hp": _balance_float("items.field_balm_recover_hp", FIELD_BALM_RECOVER_HP),
			"display_name": String(item_def.get("name_cn", item_def.get("id", "")))
		}
	return {}


func _push_last_action(state: Dictionary, action: Dictionary) -> void:
	var next_seq: int = int(state.get("action_seq", 0)) + 1
	state["action_seq"] = next_seq
	var next_action: Dictionary = action.duplicate(true)
	next_action["seq"] = next_seq
	state["last_action"] = next_action


func _find_battle_item_effect(state: Dictionary, item_id: String) -> Dictionary:
	for stack_value in state.get("battle_items", []):
		if typeof(stack_value) != TYPE_DICTIONARY:
			continue
		var stack: Dictionary = stack_value
		if String(stack.get("id", "")) != item_id:
			continue
		if int(stack.get("count", 0)) <= 0:
			return {}
		return stack.get("effect", {}).duplicate(true)
	return {}


func _consume_battle_item(state: Dictionary, item_id: String) -> bool:
	for stack_index: int in state.get("battle_items", []).size():
		var stack: Dictionary = state["battle_items"][stack_index]
		if String(stack.get("id", "")) != item_id:
			continue
		var count: int = int(stack.get("count", 0))
		if count <= 0:
			return false
		state["battle_items"][stack_index]["count"] = count - 1
		state["consumed_items"].append({"id": item_id, "count": 1})
		if count - 1 <= 0:
			state["battle_items"].remove_at(stack_index)
		return true
	return false


func _validate_skill_usage(state: Dictionary, slot_id: String) -> Dictionary:
	var skill: Dictionary = _skill_slot(state, slot_id)
	if skill.is_empty():
		return {"ok": false, "reason": "技能位未配置。"}
	var cooldown_remaining: int = int(skill.get("cooldown_remaining", 0))
	if cooldown_remaining > 0:
		return {"ok": false, "reason": "%s 冷却中，还需 %d 回合。" % [String(skill.get("name_cn", slot_id)), cooldown_remaining]}
	var resource_cost: int = int(skill.get("resource_cost", 0))
	var hero_resolve: int = int(state.get("hero_resolve", 0))
	if hero_resolve < resource_cost:
		return {"ok": false, "reason": "灵势不足，无法施放 %s。" % String(skill.get("name_cn", slot_id))}
	return {"ok": true}


func _commit_skill_use(state: Dictionary, slot_id: String) -> void:
	for index: int in state.get("skill_slots", []).size():
		var skill: Dictionary = state["skill_slots"][index]
		if String(skill.get("slot", "")) != slot_id:
			continue
		state["hero_resolve"] = max(0, int(state.get("hero_resolve", 0)) - int(skill.get("resource_cost", 0)))
		state["skill_slots"][index]["cooldown_remaining"] = int(skill.get("cooldown_max", 0))
		return


func _advance_skill_cooldowns(state: Dictionary) -> void:
	for index: int in state.get("skill_slots", []).size():
		var skill: Dictionary = state["skill_slots"][index]
		state["skill_slots"][index]["cooldown_remaining"] = max(0, int(skill.get("cooldown_remaining", 0)) - 1)


func _skill_slot(state: Dictionary, slot_id: String) -> Dictionary:
	for skill_value in state.get("skill_slots", []):
		if typeof(skill_value) != TYPE_DICTIONARY:
			continue
		var skill: Dictionary = skill_value
		if String(skill.get("slot", "")) == slot_id:
			return skill
	return {}


func _item_target_type_text(effect: Dictionary) -> String:
	match String(effect.get("kind", "")):
		"heal":
			return "目标：我方单体"
		_:
			return "目标：即时生效"


func _balance_state() -> Node:
	var main_loop: MainLoop = Engine.get_main_loop()
	if main_loop is SceneTree:
		return (main_loop as SceneTree).root.get_node_or_null("BalanceState")
	return null


func _balance_float(path: String, fallback: float) -> float:
	var balance := _balance_state()
	if balance != null and balance.has_method("get_value"):
		return float(balance.call("get_value", path, fallback))
	return fallback


func _balance_int(path: String, fallback: int) -> int:
	var balance := _balance_state()
	if balance != null and balance.has_method("get_value"):
		return int(balance.call("get_value", path, fallback))
	return fallback


func _invalid_result(reason: String) -> Dictionary:
	return {
		"status": "invalid_request",
		"victory": false,
		"defeat_reason": reason,
		"casualties": [],
		"completed_objectives": [],
		"spawned_story_flags": [],
		"spawned_unlock_flags": [],
		"map_effects": {}
	}
