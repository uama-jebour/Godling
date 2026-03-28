extends RefCounted

const STATE_HELPER := preload("res://systems/battle/auto_battle_state.gd")
const AI_SYSTEM := preload("res://systems/battle/auto_battle_ai_system.gd")
const COMBAT_SYSTEM := preload("res://systems/battle/auto_battle_combat_system.gd")
const EVENT_SYSTEM := preload("res://systems/battle/auto_battle_event_system.gd")

var _state_helper := STATE_HELPER.new()
var _ai := AI_SYSTEM.new()
var _combat := COMBAT_SYSTEM.new()
var _events := EVENT_SYSTEM.new()


func run(request: Dictionary, battle_def: Dictionary, context: Dictionary = {}) -> Dictionary:
	var content_db: Node = _content_db()
	if content_db == null:
		return _invalid_result("missing_content_db")
	var state: Dictionary = _state_helper.initialize_state(request, battle_def, content_db)
	if state.has("invalid_reason"):
		return _invalid_result(String(state.get("invalid_reason", "invalid_request")))
	state["scheduled_strategy_commands"] = _normalized_commands(context.get("auto_strategy_commands", []), int(state.get("tick_rate", 5)))
	while _state_helper.is_battle_active(state):
		_step_once(state)
	state["completed"] = true
	return _state_helper.resolve_result(state, "auto_headless")


func step_preview(request: Dictionary, battle_def: Dictionary, context: Dictionary = {}) -> Dictionary:
	var content_db: Node = _content_db()
	if content_db == null:
		return _invalid_result("missing_content_db")
	var state: Dictionary = _state_helper.initialize_state(request, battle_def, content_db)
	if state.has("invalid_reason"):
		return _invalid_result(String(state.get("invalid_reason", "invalid_request")))
	state["scheduled_strategy_commands"] = _normalized_commands(context.get("auto_strategy_commands", []), int(state.get("tick_rate", 5)))
	var timeline_frames: Array = []
	var frame_cursor := {
		"action_count": 0,
		"notification_count": 0,
		"event_count": 0
	}
	_append_preview_frame(timeline_frames, state, "Battle initialized", frame_cursor)
	while _state_helper.is_battle_active(state):
		_step_once(state)
		_append_preview_frame(timeline_frames, state, _preview_headline(state), frame_cursor)
	state["completed"] = true
	var result: Dictionary = _state_helper.resolve_result(state, "auto_scene")
	var map_effects: Dictionary = result.get("map_effects", {}).duplicate(true)
	map_effects["backend"] = "auto_scene"
	map_effects["timeline_frame_count"] = timeline_frames.size()
	map_effects["rendered_entity_count"] = map_effects.get("entities", []).size()
	map_effects["timeline_frames"] = timeline_frames
	result["map_effects"] = map_effects
	return result


func _step_once(state: Dictionary) -> void:
	_ai.tick(state)
	_combat.tick_passive_strategies(state)
	_combat.tick_combat(state)
	_events.tick(state, _combat)
	var due_commands := _drain_due_commands(state)
	if not due_commands.is_empty():
		var responses: Array = _combat.apply_scheduled_active_strategies(state, due_commands)
		if not responses.is_empty():
			_events.apply_strategy_responses(state, responses)
	state["elapsed_ticks"] = int(state.get("elapsed_ticks", 0)) + 1


func _drain_due_commands(state: Dictionary) -> Array:
	var due: Array = []
	var remaining: Array = []
	var current_tick: int = int(state.get("elapsed_ticks", 0))
	for command_value in state.get("scheduled_strategy_commands", []):
		if typeof(command_value) != TYPE_DICTIONARY:
			continue
		var command: Dictionary = command_value
		if int(command.get("tick", -1)) <= current_tick:
			due.append(command)
		else:
			remaining.append(command)
	state["scheduled_strategy_commands"] = remaining
	return due


func _normalized_commands(commands: Array, tick_rate: int) -> Array:
	var normalized: Array = []
	for command_value in commands:
		if typeof(command_value) != TYPE_DICTIONARY:
			continue
		var command: Dictionary = command_value.duplicate(true)
		if not command.has("tick"):
			command["tick"] = _state_helper.seconds_to_ticks(float(command.get("at_seconds", 0.0)), tick_rate)
		normalized.append(command)
	return normalized


func _invalid_result(reason: String) -> Dictionary:
	return {
		"status": "invalid_request",
		"victory": false,
		"defeat_reason": reason,
		"casualties": [],
		"completed_objectives": [],
		"spawned_story_flags": [],
		"spawned_unlock_flags": [],
		"map_effects": {"simulation_mode": "auto_units"}
	}


func _append_preview_frame(frames: Array, state: Dictionary, headline: String, cursor: Dictionary) -> void:
	var action_log: Array = state.get("action_log", [])
	var notifications: Array = state.get("notifications", [])
	var event_log: Array = state.get("event_resolution_log", [])
	frames.append(
		{
			"tick": int(state.get("elapsed_ticks", 0)),
			"elapsed_seconds": float(state.get("elapsed_ticks", 0)) / max(1.0, float(state.get("tick_rate", 5))),
			"headline": headline,
			"battle_def": state.get("battle_def", {}).duplicate(true),
			"battlefield": state.get("battlefield", {}).duplicate(true),
			"entities": _serialized_entities(state),
			"last_action": state.get("last_action", {}).duplicate(true),
			"new_actions": _slice_tail(action_log, int(cursor.get("action_count", 0))),
			"new_notifications": _slice_tail(notifications, int(cursor.get("notification_count", 0))),
			"new_event_resolutions": _slice_tail(event_log, int(cursor.get("event_count", 0))),
			"triggered_strategy_ids": state.get("triggered_strategy_ids", []).duplicate(true),
			"triggered_scripted_event_ids": state.get("triggered_scripted_event_ids", []).duplicate(true),
			"strategies": _serialize_strategies(state.get("strategies", []))
		}
	)
	cursor["action_count"] = action_log.size()
	cursor["notification_count"] = notifications.size()
	cursor["event_count"] = event_log.size()


func _preview_headline(state: Dictionary) -> String:
	var notifications: Array = state.get("notifications", [])
	if not notifications.is_empty():
		var last_notification_value: Variant = notifications[notifications.size() - 1]
		if typeof(last_notification_value) == TYPE_DICTIONARY:
			var last_notification: Dictionary = last_notification_value
			if int(last_notification.get("tick", -1)) == int(state.get("elapsed_ticks", 0)):
				var notification_text: String = String(last_notification.get("text", ""))
				if not notification_text.is_empty():
					return notification_text
	var event_log: Array = state.get("event_resolution_log", [])
	if not event_log.is_empty():
		var last_event_value: Variant = event_log[event_log.size() - 1]
		if typeof(last_event_value) == TYPE_DICTIONARY:
			var last_event: Dictionary = last_event_value
			if int(last_event.get("tick", -1)) == int(state.get("elapsed_ticks", 0)):
				return "Scripted event %s %s" % [
					String(last_event.get("event_id", "")),
					String(last_event.get("resolution", "resolved"))
				]
	var action: Dictionary = state.get("last_action", {})
	if not action.is_empty() and int(action.get("tick", -1)) == int(state.get("elapsed_ticks", 0)):
		match String(action.get("type", "")):
			"attack":
				return "Tick %d attack resolved" % int(state.get("elapsed_ticks", 0))
			"strategy_single_target", "strategy_area_damage", "strategy_pulse_damage", "strategy_pulse_heal", "strategy_pulse_shield":
				return "Tick %d strategy resolved" % int(state.get("elapsed_ticks", 0))
			_:
				pass
	return "Tick %d resolved" % int(state.get("elapsed_ticks", 0))


func _serialized_entities(state: Dictionary) -> Array:
	return _state_helper.resolve_result(state, "auto_scene").get("map_effects", {}).get("entities", []).duplicate(true)


func _slice_tail(values: Array, from_index: int) -> Array:
	var sliced: Array = []
	for index in range(max(0, from_index), values.size()):
		sliced.append(values[index].duplicate(true) if typeof(values[index]) == TYPE_DICTIONARY else values[index])
	return sliced


func _serialize_strategies(strategies: Array) -> Array:
	var serialized: Array = []
	for strategy_value in strategies:
		if typeof(strategy_value) != TYPE_DICTIONARY:
			continue
		var strategy: Dictionary = strategy_value
		var source: Dictionary = strategy.get("source", {})
		serialized.append(
			{
				"id": String(strategy.get("id", "")),
				"kind": String(strategy.get("kind", "")),
				"name_cn": String(source.get("ui", {}).get("name_cn", source.get("id", strategy.get("id", "")))),
				"cooldown_remaining": int(strategy.get("cooldown_remaining", 0)),
				"charges_remaining": int(strategy.get("charges_remaining", -1))
			}
		)
	return serialized


func _content_db() -> Node:
	var loop: MainLoop = Engine.get_main_loop()
	if loop is SceneTree:
		return (loop as SceneTree).get_root().get_node_or_null("ContentDB")
	return null
