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
		"equipped_strategy_ids": event_def.get("equipped_strategy_ids", []).duplicate(true),
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
	var options: Array = event_def.get("option_list", [])
	var selected_option: Dictionary = {}
	if not options.is_empty():
		var selected_id: String = String(context.get("narrative_option_id", ""))
		for option_value in options:
			if typeof(option_value) != TYPE_DICTIONARY:
				continue
			var option_def: Dictionary = option_value
			if String(option_def.get("id", "")) == selected_id:
				selected_option = option_def
				break
		if selected_option.is_empty():
			for option_value in options:
				if typeof(option_value) != TYPE_DICTIONARY:
					continue
				selected_option = option_value
				break
	if not selected_option.is_empty():
		var option_reward: Dictionary = selected_option.get("reward_package", {})
		result["reward_package"] = _merge_reward_packages(result.get("reward_package", {}), option_reward)
		result["grant_story_flags"] = _merge_string_arrays(
			result.get("grant_story_flags", []),
			selected_option.get("grant_story_flags", [])
		)
		result["grant_unlock_flags"] = _merge_string_arrays(
			result.get("grant_unlock_flags", []),
			selected_option.get("grant_unlock_flags", [])
		)
		var option_complete_task_id: String = String(selected_option.get("complete_task_id", ""))
		if not option_complete_task_id.is_empty():
			result["complete_task_id"] = option_complete_task_id
	result["narrative_result"] = {
		"status": "resolved_directly",
		"submission_requirement": event_def.get("submission_requirement", {}).duplicate(true),
		"selected_option_id": String(selected_option.get("id", "")),
		"selected_option_text": String(selected_option.get("text", "")),
		"selected_option_preview_impact": String(selected_option.get("preview_impact", ""))
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


func _merge_reward_packages(base_reward: Dictionary, option_reward: Dictionary) -> Dictionary:
	var merged: Dictionary = base_reward.duplicate(true)
	merged["currencies"] = merged.get("currencies", []).duplicate(true)
	merged["items"] = merged.get("items", []).duplicate(true)
	merged["relics"] = merged.get("relics", []).duplicate(true)
	_add_reward_stacks(merged["currencies"], option_reward.get("currencies", []))
	_add_reward_stacks(merged["items"], option_reward.get("items", []))
	_add_reward_stacks(merged["relics"], option_reward.get("relics", []))
	merged["story_flags"] = _merge_string_arrays(merged.get("story_flags", []), option_reward.get("story_flags", []))
	merged["unlock_flags"] = _merge_string_arrays(merged.get("unlock_flags", []), option_reward.get("unlock_flags", []))
	var base_tables: Array = merged.get("loot_tables", []).duplicate(true)
	for table_value in option_reward.get("loot_tables", []):
		if typeof(table_value) != TYPE_DICTIONARY:
			continue
		base_tables.append(table_value.duplicate(true))
	merged["loot_tables"] = base_tables
	return merged


func _add_reward_stacks(target: Array, source: Array) -> void:
	var index_by_id: Dictionary = {}
	for i: int in target.size():
		var stack_value: Variant = target[i]
		if typeof(stack_value) != TYPE_DICTIONARY:
			continue
		var stack: Dictionary = stack_value
		index_by_id[String(stack.get("id", ""))] = i
	for source_value in source:
		if typeof(source_value) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = source_value
		var item_id: String = String(entry.get("id", ""))
		var count: int = int(entry.get("count", 0))
		if item_id.is_empty() or count <= 0:
			continue
		if index_by_id.has(item_id):
			var idx: int = int(index_by_id[item_id])
			target[idx]["count"] = int(target[idx].get("count", 0)) + count
		else:
			target.append({"id": item_id, "count": count})
			index_by_id[item_id] = target.size() - 1
