extends RefCounted

const BATTLE_EXECUTOR_ADAPTER := preload("res://systems/battle/battle_executor_adapter.gd")

var _battle_adapter: RefCounted


func resolve_event(event_def: Dictionary, context: Dictionary) -> Dictionary:
	if event_def.is_empty():
		return {}

	var resolution_type: String = String(event_def.get("resolution_type", ""))
	match resolution_type:
		"battle":
			return _resolve_battle_event(event_def, context)
		"random":
			return _resolve_random_event(event_def, context)
		"narrative":
			return _resolve_narrative_event(event_def, context)
		_:
			return {
				"accepted": false,
				"error": "unsupported_resolution_type",
				"resolution_type": resolution_type,
				"event_id": String(event_def.get("id", ""))
			}


func _resolve_battle_event(event_def: Dictionary, context: Dictionary) -> Dictionary:
	var result: Dictionary = _build_base_result(event_def, context)
	var battle_id: String = String(event_def.get("battle_id", ""))
	var battle_request := {
		"battle_id": battle_id,
		"event_id": String(event_def.get("id", "")),
		"event_instance_id": result.get("event_instance_id", ""),
		"map_id": String(context.get("map_id", "")),
		"hero_snapshot": context.get("hero_snapshot", {}).duplicate(true),
		"ally_snapshot": context.get("ally_snapshot", []).duplicate(true),
		"equipped_relic_modifiers": context.get("equipped_relic_modifiers", []).duplicate(true),
		"configured_reward_package": result.get("reward_package", {}).duplicate(true)
	}
	result["battle_request"] = battle_request
	if battle_id.is_empty():
		result["accepted"] = false
		result["error"] = "missing_battle_id"
		return result

	var battle_result: Dictionary = context.get("battle_result_override", {}).duplicate(true)
	if battle_result.is_empty():
		battle_result = _battle_executor().execute_battle(
			battle_request,
			{
				"success_override": bool(context.get("success", true)),
				"apply_rewards_on_failure": bool(context.get("apply_rewards_on_failure", false))
			}
		)
	result["battle_result"] = battle_result
	var battle_victory: bool = bool(battle_result.get("victory", false))
	var apply_rewards_on_failure: bool = bool(context.get("apply_rewards_on_failure", false))
	result["success"] = battle_victory
	result["status"] = "resolved" if battle_victory else "failed"
	result["mark_completed"] = battle_victory
	result["apply_rewards"] = battle_victory or apply_rewards_on_failure
	result["hero_down"] = String(battle_result.get("defeat_reason", "")) == "hero_down"
	result["reward_package"] = battle_result.get("reward_package", {}).duplicate(true)
	result["grant_story_flags"] = _merge_string_arrays(
		event_def.get("grant_story_flags", []),
		battle_result.get("spawned_story_flags", [])
	)
	result["grant_unlock_flags"] = _merge_string_arrays(
		event_def.get("grant_unlock_flags", []),
		battle_result.get("spawned_unlock_flags", [])
	)
	return result


func _resolve_random_event(event_def: Dictionary, context: Dictionary) -> Dictionary:
	var result: Dictionary = _build_base_result(event_def, context)
	result["random_result"] = {
		"status": "resolved_directly",
		"roll_seed": int(context.get("roll_seed", -1))
	}
	return result


func _resolve_narrative_event(event_def: Dictionary, context: Dictionary) -> Dictionary:
	var result: Dictionary = _build_base_result(event_def, context)
	result["narrative_result"] = {
		"status": "resolved_directly",
		"submission_requirement": event_def.get("submission_requirement", {}).duplicate(true)
	}
	return result


func _build_base_result(event_def: Dictionary, context: Dictionary) -> Dictionary:
	var success: bool = bool(context.get("success", true))
	var apply_rewards_on_failure: bool = bool(context.get("apply_rewards_on_failure", false))
	return {
		"accepted": true,
		"status": "resolved" if success else "failed",
		"success": success,
		"event_id": String(event_def.get("id", "")),
		"event_instance_id": String(context.get("event_instance_id", "")),
		"resolution_type": String(event_def.get("resolution_type", "")),
		"trigger_mode": String(event_def.get("trigger_mode", "")),
		"map_id": String(context.get("map_id", "")),
		"apply_rewards": success or apply_rewards_on_failure,
		"reward_package": event_def.get("reward_package", {}).duplicate(true),
		"complete_task_id": String(event_def.get("complete_task_id", "")),
		"grant_story_flags": event_def.get("grant_story_flags", []).duplicate(true),
		"grant_unlock_flags": event_def.get("grant_unlock_flags", []).duplicate(true),
		"mark_completed": success
	}


func _battle_executor() -> RefCounted:
	if _battle_adapter == null:
		_battle_adapter = BATTLE_EXECUTOR_ADAPTER.new()
	return _battle_adapter


func _merge_string_arrays(primary: Array, secondary: Array) -> Array:
	var merged: Array = primary.duplicate(true)
	for value: Variant in secondary:
		var item: String = String(value)
		if item.is_empty():
			continue
		if not merged.has(item):
			merged.append(item)
	return merged
