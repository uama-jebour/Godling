extends Node

const SAVE_PATH := "user://progression_state.json"

var state: Dictionary = {}


func _ready() -> void:
	state = _content_db().get_default_progression_state()
	_ensure_runtime_defaults()
	load_from_disk()


func load_from_disk() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		save_to_disk()
		return

	var raw_text := FileAccess.get_file_as_string(SAVE_PATH)
	if raw_text.is_empty():
		save_to_disk()
		return

	var parsed: Variant = JSON.parse_string(raw_text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("progression_state.json is invalid. Resetting to defaults.")
		save_to_disk()
		return

	state = _merge_defaults(parsed)
	_ensure_runtime_defaults()


func save_to_disk() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Failed to open save file: %s" % SAVE_PATH)
		return
	file.store_string(JSON.stringify(state, "\t"))


func add_loot_from_run(result: Dictionary) -> void:
	_add_stack_items("inventory_items", result.get("saved_items", []))
	_add_stack_items("currencies", result.get("saved_currencies", []))
	_add_stack_items("relics", result.get("saved_relics", []))

	for task_id: String in result.get("completed_tasks", []):
		if not state["completed_tasks"].has(task_id):
			state["completed_tasks"].append(task_id)

	for flag_id: String in result.get("story_flags_applied", []):
		if not state["story_flags"].has(flag_id):
			state["story_flags"].append(flag_id)

	for unlock_id: String in result.get("unlock_flags_applied", []):
		if not state["unlock_flags"].has(unlock_id):
			state["unlock_flags"].append(unlock_id)

	save_to_disk()


func get_equipped_relics() -> Array:
	return state.get("home_loadout", {}).get("equipped_relic_ids", []).duplicate(true)


func get_home_loadout() -> Dictionary:
	return state.get("home_loadout", {}).duplicate(true)


func configure_home_loadout(hero_id: String, carried_item_ids: Array, equipped_relic_ids: Array) -> void:
	state["home_loadout"] = {
		"hero_id": hero_id,
		"carried_item_ids": carried_item_ids.duplicate(true),
		"equipped_relic_ids": equipped_relic_ids.duplicate(true)
	}
	save_to_disk()


func get_context_for_conditions() -> Dictionary:
	var inventory_item_ids: Array = []
	for stack: Dictionary in state.get("inventory_items", []):
		var item_id: String = String(stack.get("id", ""))
		if not item_id.is_empty():
			inventory_item_ids.append(item_id)

	return {
		"story_flags": state.get("story_flags", []).duplicate(true),
		"unlock_flags": state.get("unlock_flags", []).duplicate(true),
		"completed_tasks": state.get("completed_tasks", []).duplicate(true),
		"item_ids": inventory_item_ids
	}


func _add_stack_items(target_key: String, source: Array) -> void:
	var target: Array = state.get(target_key, [])
	var index_by_id: Dictionary = {}

	for i: int in target.size():
		var item: Dictionary = target[i]
		index_by_id[String(item.get("id", ""))] = i

	for entry: Dictionary in source:
		var item_id: String = String(entry.get("id", ""))
		var count: int = int(entry.get("count", 0))
		if item_id.is_empty() or count <= 0:
			continue
		if index_by_id.has(item_id):
			var idx: int = index_by_id[item_id]
			target[idx]["count"] = int(target[idx].get("count", 0)) + count
		else:
			target.append({"id": item_id, "count": count})
			index_by_id[item_id] = target.size() - 1

	state[target_key] = target


func _merge_defaults(saved: Dictionary) -> Dictionary:
	var defaults: Dictionary = _content_db().get_default_progression_state()
	var merged := defaults.duplicate(true)
	for key: String in saved.keys():
		merged[key] = saved[key]
	return merged


func _ensure_runtime_defaults() -> void:
	if not state.has("inventory_items"):
		state["inventory_items"] = []
	if not state.has("currencies"):
		state["currencies"] = []
	if not state.has("relics"):
		state["relics"] = []
	if not state.has("story_flags"):
		state["story_flags"] = []
	if not state.has("unlock_flags"):
		state["unlock_flags"] = []
	if not state.has("completed_tasks"):
		state["completed_tasks"] = []
	if not state.has("home_loadout"):
		state["home_loadout"] = {
			"hero_id": "",
			"carried_item_ids": [],
			"equipped_relic_ids": []
		}


func _content_db() -> Node:
	return get_node("/root/ContentDB")
