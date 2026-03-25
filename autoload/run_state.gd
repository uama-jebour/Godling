extends Node

var active_run: Dictionary = {}


func start_new_run(map_id: String, hero_id: String, carried_items: Array, equipped_relics: Array) -> void:
	var map_def: Dictionary = _content_db().get_map(map_id)
	if map_def.is_empty():
		push_error("Cannot start run. Missing map id: %s" % map_id)
		return

	active_run = {
		"run_id": str(Time.get_unix_time_from_system()),
		"map_id": map_id,
		"world_id": map_def.get("world_id", ""),
		"turn": 1,
		"danger_level": 0,
		"map_name_cn": map_def.get("name_cn", ""),
		"hero_id": hero_id,
		"board_state": {
			"random_slots": [],
			"fixed_events": [],
			"selected_event_id": ""
		},
		"map_stats": map_def.get("base_stats", {}).duplicate(true),
		"temporary_inventory": [],
		"temporary_currencies": [],
		"temporary_relics": [],
		"carried_item_ids": carried_items.duplicate(true),
		"equipped_relics_snapshot": equipped_relics.duplicate(true),
		"completed_tasks": [],
		"story_flags_gained_this_run": [],
		"unlock_flags_gained_this_run": [],
		"triggered_forced_events": [],
		"pending_forced_event": {},
		"can_extract": false,
		"is_dead": false,
		"is_extracted": false
	}

	generate_turn_board()


func generate_turn_board() -> void:
	if active_run.is_empty():
		return

	var map_def: Dictionary = _content_db().get_map(active_run["map_id"])
	var range_values: Array = map_def.get("random_slot_count_range", [4, 6])
	var required_mix: Dictionary = {}
	var count_range := Vector2i(int(range_values[0]), int(range_values[1]))

	var turn_templates: Dictionary = map_def.get("turn_templates", {})
	var template: Dictionary = turn_templates.get(str(active_run["turn"]), {})
	if not template.is_empty():
		var random_count: int = int(template.get("random_count", -1))
		if random_count > 0:
			count_range = Vector2i(random_count, random_count)
		required_mix = template.get("required_mix", {})

	var context: Dictionary = _build_condition_context()
	var random_events: Array = _content_db().pick_random_events(active_run["map_id"], context, count_range, required_mix)
	var fixed_events: Array = _content_db().get_fixed_events(active_run["map_id"], context, true)

	active_run["board_state"]["random_slots"] = _attach_slot_ids(random_events, map_def.get("random_slot_anchors", []))
	active_run["board_state"]["fixed_events"] = fixed_events
	active_run["board_state"]["selected_event_id"] = ""


func select_event(event_id: String) -> Dictionary:
	if active_run.is_empty():
		return {}

	for event_def: Dictionary in active_run["board_state"]["random_slots"]:
		if String(event_def.get("id", "")) == event_id:
			active_run["board_state"]["selected_event_id"] = event_id
			return event_def
	for event_def: Dictionary in active_run["board_state"]["fixed_events"]:
		if String(event_def.get("id", "")) == event_id:
			active_run["board_state"]["selected_event_id"] = event_id
			return event_def
	return {}


func complete_selected_event(success: bool = true) -> Dictionary:
	var selected_id: String = String(active_run.get("board_state", {}).get("selected_event_id", ""))
	if selected_id.is_empty():
		return {}

	var event_def: Dictionary = _content_db().get_event(selected_id)
	_apply_event_rewards(event_def)
	if success:
		_apply_success_effects(event_def)

	active_run["can_extract"] = true
	var forced_event: Dictionary = _roll_forced_event()
	_advance_turn()

	return {
		"selected_event": event_def,
		"forced_event": forced_event
	}


func get_pending_forced_event() -> Dictionary:
	return active_run.get("pending_forced_event", {}).duplicate(true)


func resolve_pending_forced_event(success: bool = true) -> Dictionary:
	if active_run.is_empty():
		return {}
	var pending: Dictionary = active_run.get("pending_forced_event", {})
	if pending.is_empty():
		return {}
	if success:
		_apply_event_rewards(pending)
		_apply_success_effects(pending)
	active_run["pending_forced_event"] = {}
	return {"resolved_event": pending, "success": success}


func submit_mainline_item(required_item_id: String, apply_flag: String = "mainline_item_submitted") -> bool:
	if not _consume_temp_item(required_item_id):
		return false
	if not active_run["story_flags_gained_this_run"].has(apply_flag):
		active_run["story_flags_gained_this_run"].append(apply_flag)
	return true


func mark_mainline_completed() -> void:
	if not active_run["story_flags_gained_this_run"].has("mainline_completed"):
		active_run["story_flags_gained_this_run"].append("mainline_completed")


func resolve_extraction_event(success: bool = true) -> Dictionary:
	if active_run.is_empty():
		return {}
	var extraction_event: Dictionary = get_extraction_event()
	if extraction_event.is_empty():
		return {}
	if not success:
		active_run["is_dead"] = true
		return {
			"status": "failed",
			"event": extraction_event
		}

	_apply_event_rewards(extraction_event)
	_apply_success_effects(extraction_event)
	active_run["is_extracted"] = true
	active_run["can_extract"] = false

	var extraction_result := {
		"status": "extracted",
		"saved_items": active_run["temporary_inventory"].duplicate(true),
		"saved_currencies": active_run["temporary_currencies"].duplicate(true),
		"saved_relics": active_run["temporary_relics"].duplicate(true),
		"lost_items": [],
		"completed_tasks": active_run["completed_tasks"].duplicate(true),
		"story_flags_applied": active_run["story_flags_gained_this_run"].duplicate(true),
		"unlock_flags_applied": active_run["unlock_flags_gained_this_run"].duplicate(true)
	}

	return {
		"status": "success",
		"event": extraction_event,
		"extraction_result": extraction_result
	}


func get_extraction_event() -> Dictionary:
	var context: Dictionary = _build_condition_context()
	return _content_db().find_extraction_event(active_run.get("map_id", ""), context)


func get_turn_summary() -> Dictionary:
	if active_run.is_empty():
		return {}

	return {
		"map_id": active_run["map_id"],
		"world_id": active_run.get("world_id", ""),
		"map_name_cn": active_run.get("map_name_cn", ""),
		"hero_id": active_run.get("hero_id", ""),
		"turn": active_run["turn"],
		"danger_level": active_run["danger_level"],
		"random_event_count": active_run["board_state"]["random_slots"].size(),
		"fixed_event_count": active_run["board_state"]["fixed_events"].size(),
		"can_extract": active_run["can_extract"],
		"pending_forced_event_id": active_run.get("pending_forced_event", {}).get("id", ""),
		"is_extracted": active_run.get("is_extracted", false),
		"is_dead": active_run.get("is_dead", false)
	}


func get_board_snapshot() -> Dictionary:
	if active_run.is_empty():
		return {}
	return {
		"random_slots": active_run["board_state"]["random_slots"].duplicate(true),
		"fixed_events": active_run["board_state"]["fixed_events"].duplicate(true)
	}


func get_temporary_loot_snapshot() -> Dictionary:
	if active_run.is_empty():
		return {}
	return {
		"items": active_run.get("temporary_inventory", []).duplicate(true),
		"currencies": active_run.get("temporary_currencies", []).duplicate(true),
		"relics": active_run.get("temporary_relics", []).duplicate(true)
	}


func get_progress_snapshot() -> Dictionary:
	if active_run.is_empty():
		return {}
	return {
		"completed_tasks": active_run.get("completed_tasks", []).duplicate(true),
		"story_flags": active_run.get("story_flags_gained_this_run", []).duplicate(true),
		"unlock_flags": active_run.get("unlock_flags_gained_this_run", []).duplicate(true)
	}


func has_item_for_requirement(item_id: String) -> bool:
	if active_run.is_empty():
		return false
	if item_id.is_empty():
		return false
	for stack: Dictionary in active_run.get("temporary_inventory", []):
		if String(stack.get("id", "")) == item_id and int(stack.get("count", 0)) > 0:
			return true
	for carried_id: String in active_run.get("carried_item_ids", []):
		if carried_id == item_id:
			return true
	return false


func debug_grant_temp_item(item_id: String, count: int = 1) -> void:
	if active_run.is_empty():
		return
	if count <= 0:
		return
	_add_stacks(active_run["temporary_inventory"], [{"id": item_id, "count": count}])


func _apply_event_rewards(event_def: Dictionary) -> void:
	var reward: Dictionary = event_def.get("reward_package", {})
	_add_stacks(active_run["temporary_inventory"], reward.get("items", []))
	_add_stacks(active_run["temporary_currencies"], reward.get("currencies", []))
	_add_stacks(active_run["temporary_relics"], reward.get("relics", []))

	for flag_id: String in reward.get("story_flags", []):
		if not active_run["story_flags_gained_this_run"].has(flag_id):
			active_run["story_flags_gained_this_run"].append(flag_id)
	for unlock_id: String in reward.get("unlock_flags", []):
		if not active_run["unlock_flags_gained_this_run"].has(unlock_id):
			active_run["unlock_flags_gained_this_run"].append(unlock_id)


func _apply_success_effects(event_def: Dictionary) -> void:
	var complete_task_id: String = String(event_def.get("complete_task_id", ""))
	if not complete_task_id.is_empty() and not active_run["completed_tasks"].has(complete_task_id):
		active_run["completed_tasks"].append(complete_task_id)

	for flag_id: String in event_def.get("grant_story_flags", []):
		if not active_run["story_flags_gained_this_run"].has(flag_id):
			active_run["story_flags_gained_this_run"].append(flag_id)

	for unlock_id: String in event_def.get("grant_unlock_flags", []):
		if not active_run["unlock_flags_gained_this_run"].has(unlock_id):
			active_run["unlock_flags_gained_this_run"].append(unlock_id)


func _roll_forced_event() -> Dictionary:
	var context: Dictionary = _build_condition_context()
	var forced_candidates: Array = _content_db().get_forced_non_turn_events(
		active_run["map_id"],
		context,
		active_run["triggered_forced_events"]
	)
	if forced_candidates.is_empty():
		active_run["pending_forced_event"] = {}
		return {}

	for event_def: Dictionary in forced_candidates:
		var chance: float = float(event_def.get("chance", 0.0))
		if randf() <= chance:
			active_run["pending_forced_event"] = event_def.duplicate(true)
			active_run["triggered_forced_events"].append(String(event_def.get("id", "")))
			return active_run["pending_forced_event"]

	active_run["pending_forced_event"] = {}
	return {}


func _advance_turn() -> void:
	active_run["turn"] = int(active_run["turn"]) + 1
	active_run["danger_level"] = int(active_run["danger_level"]) + 1
	generate_turn_board()


func _build_condition_context() -> Dictionary:
	var progression_ctx: Dictionary = _progression_state().get_context_for_conditions()
	var item_ids: Array = progression_ctx.get("item_ids", []).duplicate(true)
	for stack: Dictionary in active_run.get("temporary_inventory", []):
		var item_id: String = String(stack.get("id", ""))
		if not item_id.is_empty():
			item_ids.append(item_id)
	for item_id: String in active_run.get("carried_item_ids", []):
		item_ids.append(item_id)

	var all_story_flags: Array = progression_ctx.get("story_flags", []).duplicate(true)
	for flag_id: String in active_run.get("story_flags_gained_this_run", []):
		if not all_story_flags.has(flag_id):
			all_story_flags.append(flag_id)

	var all_unlock_flags: Array = progression_ctx.get("unlock_flags", []).duplicate(true)
	for unlock_id: String in active_run.get("unlock_flags_gained_this_run", []):
		if not all_unlock_flags.has(unlock_id):
			all_unlock_flags.append(unlock_id)

	var all_completed_tasks: Array = progression_ctx.get("completed_tasks", []).duplicate(true)
	for task_id: String in active_run.get("completed_tasks", []):
		if not all_completed_tasks.has(task_id):
			all_completed_tasks.append(task_id)

	return {
		"turn": active_run.get("turn", 1),
		"danger_level": active_run.get("danger_level", 0),
		"story_flags": all_story_flags,
		"unlock_flags": all_unlock_flags,
		"completed_tasks": all_completed_tasks,
		"item_ids": item_ids
	}


func _attach_slot_ids(events: Array, anchors: Array) -> Array:
	var mapped: Array = []
	var anchor_count: int = anchors.size()
	for i: int in events.size():
		var event_def: Dictionary = events[i].duplicate(true)
		if anchor_count > 0:
			var anchor: Dictionary = anchors[i % anchor_count]
			event_def["slot_id"] = anchor.get("id", "slot_%d" % i)
			event_def["slot_position"] = anchor.get("position", [0, 0])
		mapped.append(event_def)
	return mapped


func _add_stacks(target: Array, source: Array) -> void:
	var index_by_id: Dictionary = {}
	for i: int in target.size():
		index_by_id[String(target[i].get("id", ""))] = i
	for entry: Dictionary in source:
		var item_id: String = String(entry.get("id", ""))
		var count: int = int(entry.get("count", 0))
		if item_id.is_empty() or count <= 0:
			continue
		if index_by_id.has(item_id):
			var index: int = int(index_by_id[item_id])
			target[index]["count"] = int(target[index].get("count", 0)) + count
		else:
			target.append({"id": item_id, "count": count})
			index_by_id[item_id] = target.size() - 1


func _consume_temp_item(item_id: String) -> bool:
	for i: int in active_run["temporary_inventory"].size():
		var stack: Dictionary = active_run["temporary_inventory"][i]
		if String(stack.get("id", "")) != item_id:
			continue
		var count: int = int(stack.get("count", 0))
		if count <= 0:
			return false
		count -= 1
		if count <= 0:
			active_run["temporary_inventory"].remove_at(i)
		else:
			active_run["temporary_inventory"][i]["count"] = count
		return true
	return false


func _content_db() -> Node:
	return get_node("/root/ContentDB")


func _progression_state() -> Node:
	return get_node("/root/ProgressionState")
