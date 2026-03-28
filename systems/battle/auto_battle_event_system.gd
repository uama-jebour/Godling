extends RefCounted

const STATE_HELPER := preload("res://systems/battle/auto_battle_state.gd")

var _state_helper := STATE_HELPER.new()


func tick(state: Dictionary, combat_system: RefCounted) -> void:
	for runtime_value in state.get("scripted_events", []):
		if typeof(runtime_value) != TYPE_DICTIONARY:
			continue
		var runtime: Dictionary = runtime_value
		if bool(runtime.get("resolved", false)) or bool(runtime.get("cancelled", false)):
			continue
		var source: Dictionary = runtime.get("source", {})
		match String(runtime.get("stage", "idle")):
			"idle":
				if _conditions_match(state, source.get("trigger_conditions", [])):
					runtime["triggered_tick"] = int(state.get("elapsed_ticks", 0))
					var notify_ticks: int = _state_helper.seconds_to_ticks(float(source.get("notify", {}).get("countdown", 0.0)), int(state.get("tick_rate", 5)))
					if notify_ticks > 0:
						runtime["stage"] = "notifying"
						runtime["notify_ticks_remaining"] = notify_ticks
						_push_notification(state, runtime, "notify")
					else:
						_enter_response_or_apply(state, runtime, combat_system)
			"notifying":
				runtime["notify_ticks_remaining"] = max(0, int(runtime.get("notify_ticks_remaining", 0)) - 1)
				if int(runtime.get("notify_ticks_remaining", 0)) <= 0:
					_enter_response_or_apply(state, runtime, combat_system)
			"responding":
				runtime["response_ticks_remaining"] = max(0, int(runtime.get("response_ticks_remaining", 0)) - 1)
				if int(runtime.get("response_ticks_remaining", 0)) <= 0:
					_apply_event(state, runtime, combat_system)


func apply_strategy_responses(state: Dictionary, responses: Array) -> void:
	for response_value in responses:
		if typeof(response_value) != TYPE_DICTIONARY:
			continue
		var response_payload: Dictionary = response_value
		for runtime_value in state.get("scripted_events", []):
			if typeof(runtime_value) != TYPE_DICTIONARY:
				continue
			var runtime: Dictionary = runtime_value
			if String(runtime.get("stage", "")) != "responding":
				continue
			var response: Dictionary = runtime.get("source", {}).get("response", {})
			if String(response.get("keyword", "")) != String(response_payload.get("keyword", "")):
				continue
			if int(response_payload.get("level", 0)) < int(response.get("level", 0)):
				continue
			runtime["stage"] = "cancelled"
			runtime["cancelled"] = true
			state["event_resolution_log"].append(
				{
					"tick": int(state.get("elapsed_ticks", 0)),
					"event_id": String(runtime.get("id", "")),
					"resolution": "cancelled",
					"strategy_id": String(response_payload.get("strategy_id", ""))
				}
			)


func _enter_response_or_apply(state: Dictionary, runtime: Dictionary, combat_system: RefCounted) -> void:
	var response: Dictionary = runtime.get("source", {}).get("response", {})
	var response_type: String = String(response.get("type", "none"))
	var time_limit: int = _state_helper.seconds_to_ticks(float(response.get("time_limit", 0.0)), int(state.get("tick_rate", 5)))
	if response_type == "none" or time_limit <= 0:
		_apply_event(state, runtime, combat_system)
		return
	runtime["stage"] = "responding"
	runtime["response_ticks_remaining"] = time_limit
	_push_notification(state, runtime, "response")


func _apply_event(state: Dictionary, runtime: Dictionary, combat_system: RefCounted) -> void:
	var source: Dictionary = runtime.get("source", {})
	var payload: Dictionary = source.get("payload", {})
	match String(source.get("event_type", "")):
		"summon":
			_apply_summon(state, payload)
		"buff":
			combat_system.apply_buff_to_side(
				state,
				String(payload.get("target_side", "enemy")),
				String(payload.get("buff_kind", "attack_mult")),
				float(payload.get("value", 1.0)),
				_state_helper.seconds_to_ticks(float(payload.get("duration", 0.0)), int(state.get("tick_rate", 5))),
				String(runtime.get("id", ""))
			)
	runtime["stage"] = "resolved"
	runtime["resolved"] = true
	var event_id: String = String(runtime.get("id", ""))
	if not state.get("triggered_scripted_event_ids", []).has(event_id):
		state["triggered_scripted_event_ids"].append(event_id)
	state["event_resolution_log"].append(
		{
			"tick": int(state.get("elapsed_ticks", 0)),
			"event_id": event_id,
			"resolution": "applied",
			"event_type": String(source.get("event_type", ""))
		}
	)


func _apply_summon(state: Dictionary, payload: Dictionary) -> void:
	var content_db: Node = state.get("content_db")
	var unit_id: String = String(payload.get("unit_id", ""))
	var count: int = int(payload.get("count", 0))
	var unit_def: Dictionary = content_db.get_unit(unit_id)
	if unit_def.is_empty() or count <= 0:
		return
	var spawn: Array = payload.get("spawn", [720, 240]).duplicate(true)
	var next_index: int = int(state.get("next_entity_index", 1))
	var created: Array = _state_helper.create_event_spawn_entities("enemy", unit_def, count, spawn, next_index)
	for entity_value in created:
		state["entities"].append(entity_value)
	state["next_entity_index"] = next_index + created.size()


func _conditions_match(state: Dictionary, trigger_conditions: Array) -> bool:
	for condition_value in trigger_conditions:
		if typeof(condition_value) != TYPE_DICTIONARY:
			return false
		var condition: Dictionary = condition_value
		var condition_type: String = String(condition.get("type", ""))
		match condition_type:
			"elapsed_gte":
				var seconds_elapsed: float = float(state.get("elapsed_ticks", 0)) / max(1.0, float(state.get("tick_rate", 5)))
				if seconds_elapsed < float(condition.get("value", 0.0)):
					return false
			"side_hp_ratio_lte":
				if _state_helper.current_side_hp_ratio(state, String(condition.get("side", "enemy"))) > float(condition.get("value", 0.0)):
					return false
			"unit_alive_count_lte":
				if _state_helper.alive_count(state, String(condition.get("side", "enemy")), String(condition.get("unit_id", ""))) > int(condition.get("value", 0)):
					return false
			"unit_present":
				if not _state_helper.unit_present(state, String(condition.get("unit_id", ""))):
					return false
			"event_triggered":
				if not state.get("triggered_scripted_event_ids", []).has(String(condition.get("event_id", ""))):
					return false
			_:
				return false
	return true


func _push_notification(state: Dictionary, runtime: Dictionary, stage: String) -> void:
	var source: Dictionary = runtime.get("source", {})
	var notify: Dictionary = source.get("notify", {})
	state["notifications"].append(
		{
			"tick": int(state.get("elapsed_ticks", 0)),
			"event_id": String(runtime.get("id", "")),
			"stage": stage,
			"text": String(notify.get("text", "")),
			"countdown": float(notify.get("countdown", 0.0))
		}
	)
