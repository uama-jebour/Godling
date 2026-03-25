extends Node

const DATA_FILES := {
	"glossary": "res://data/glossary.json",
	"maps": "res://data/maps.json",
	"items": "res://data/items.json",
	"loot_tables": "res://data/loot_tables.json",
	"units": "res://data/units.json",
	"battle_events": "res://data/battle_events.json",
	"battles": "res://data/battles.json",
	"events": "res://data/events.json",
	"tasks": "res://data/tasks.json",
	"progression_defaults": "res://data/progression_defaults.json"
}

const VALID_SPAWN_MODES := {"random_slot": true, "fixed_line": true}
const VALID_RESOLUTION_TYPES := {"battle": true, "random": true, "narrative": true}
const VALID_TRIGGER_MODES := {"board": true, "forced_non_turn": true}

var data: Dictionary = {}
var by_id: Dictionary = {}


func _ready() -> void:
	var code := reload_all()
	if code != OK:
		push_error("ContentDB failed to load content. Please fix data files first.")


func reload_all() -> int:
	data.clear()
	by_id.clear()

	for key: String in DATA_FILES.keys():
		var file_path: String = DATA_FILES[key]
		var parsed: Variant = _read_json(file_path)
		if parsed == null:
			return ERR_FILE_CORRUPT
		data[key] = parsed

	for key: String in ["maps", "items", "loot_tables", "units", "battle_events", "battles", "events", "tasks"]:
		var index_result: Dictionary = _index_array_by_id(key, data.get(key, []))
		if index_result.is_empty() and data.get(key, []).size() > 0:
			return ERR_INVALID_DATA
		by_id[key] = index_result

	var errors: Array = _validate_data_contracts()
	if not errors.is_empty():
		for err_msg: String in errors:
			push_error(err_msg)
		return ERR_INVALID_DATA

	return OK


func get_default_progression_state() -> Dictionary:
	return _deep_copy_dict(data.get("progression_defaults", {}))


func get_theme_name() -> String:
	var glossary: Dictionary = data.get("glossary", {})
	return String(glossary.get("visual_theme", ""))


func get_map(map_id: String) -> Dictionary:
	return _deep_copy_dict(by_id.get("maps", {}).get(map_id, {}))


func get_event(event_id: String) -> Dictionary:
	return _deep_copy_dict(by_id.get("events", {}).get(event_id, {}))


func get_item(item_id: String) -> Dictionary:
	return _deep_copy_dict(by_id.get("items", {}).get(item_id, {}))


func pick_random_events(map_id: String, context: Dictionary, count_range: Vector2i, required_mix: Dictionary = {}) -> Array:
	var candidates: Array = []
	var all_events: Dictionary = by_id.get("events", {})

	for event_id: String in all_events.keys():
		var event_def: Dictionary = all_events[event_id]
		if String(event_def.get("spawn_mode", "")) != "random_slot":
			continue
		if not _event_matches_map(event_def, map_id):
			continue
		if not _conditions_match(event_def.get("conditions", []), context):
			continue
		candidates.append(event_def)

	if candidates.is_empty():
		return []

	candidates.shuffle()
	var wanted: int = randi_range(count_range.x, count_range.y)
	var required_total: int = 0
	for mix_count: Variant in required_mix.values():
		required_total += int(mix_count)
	wanted = max(wanted, required_total)
	wanted = min(wanted, candidates.size())

	var selected: Array = []
	var selected_ids: Dictionary = {}

	if not required_mix.is_empty():
		for resolution_type: String in required_mix.keys():
			var needed: int = int(required_mix[resolution_type])
			if needed <= 0:
				continue
			var pool: Array = []
			for candidate: Dictionary in candidates:
				if String(candidate.get("resolution_type", "")) == resolution_type and not selected_ids.has(candidate["id"]):
					pool.append(candidate)
			pool.shuffle()
			var take_count: int = min(needed, pool.size())
			for i: int in take_count:
				var event_def: Dictionary = pool[i]
				selected.append(_deep_copy_dict(event_def))
				selected_ids[event_def["id"]] = true

	while selected.size() < wanted:
		var appended := false
		for candidate: Dictionary in candidates:
			if selected_ids.has(candidate["id"]):
				continue
			selected.append(_deep_copy_dict(candidate))
			selected_ids[candidate["id"]] = true
			appended = true
			break
		if not appended:
			break

	return selected


func get_fixed_events(map_id: String, context: Dictionary, board_only: bool = true) -> Array:
	var selected: Array = []
	var all_events: Dictionary = by_id.get("events", {})

	for event_id: String in all_events.keys():
		var event_def: Dictionary = all_events[event_id]
		if String(event_def.get("spawn_mode", "")) != "fixed_line":
			continue
		if board_only and String(event_def.get("trigger_mode", "board")) != "board":
			continue
		if not _event_matches_map(event_def, map_id):
			continue
		if not _conditions_match(event_def.get("conditions", []), context):
			continue
		selected.append(_deep_copy_dict(event_def))

	return selected


func get_forced_non_turn_events(map_id: String, context: Dictionary, already_triggered: Array) -> Array:
	var selected: Array = []
	for event_def: Dictionary in get_fixed_events(map_id, context, false):
		if String(event_def.get("trigger_mode", "board")) != "forced_non_turn":
			continue
		if already_triggered.has(String(event_def.get("id", ""))):
			continue
		selected.append(event_def)
	return selected


func find_extraction_event(map_id: String, context: Dictionary) -> Dictionary:
	for event_def: Dictionary in get_fixed_events(map_id, context, false):
		if String(event_def.get("event_kind", "")) == "extraction":
			return event_def
	return {}


func _validate_data_contracts() -> Array:
	var errors: Array = []
	var maps_index: Dictionary = by_id.get("maps", {})
	var items_index: Dictionary = by_id.get("items", {})
	var loot_index: Dictionary = by_id.get("loot_tables", {})
	var units_index: Dictionary = by_id.get("units", {})
	var battles_index: Dictionary = by_id.get("battles", {})
	var events_index: Dictionary = by_id.get("events", {})

	for map_id: String in maps_index.keys():
		var map_def: Dictionary = maps_index[map_id]
		var range_value: Array = map_def.get("random_slot_count_range", [])
		var anchors: Array = map_def.get("random_slot_anchors", [])
		if range_value.size() != 2:
			errors.append("Map %s random_slot_count_range must contain exactly 2 numbers." % map_id)
		elif anchors.size() < int(range_value[1]):
			errors.append("Map %s has fewer anchors than max random slot count." % map_id)

	for loot_id: String in loot_index.keys():
		var loot_def: Dictionary = loot_index[loot_id]
		for entry: Dictionary in loot_def.get("entries", []):
			if String(entry.get("kind", "")) == "item" and not items_index.has(String(entry.get("id", ""))):
				errors.append("Loot table %s references missing item %s." % [loot_id, String(entry.get("id", ""))])

	for battle_id: String in battles_index.keys():
		var battle_def: Dictionary = battles_index[battle_id]
		var map_id: String = String(battle_def.get("map_id", ""))
		if not maps_index.has(map_id):
			errors.append("Battle %s references missing map %s." % [battle_id, map_id])
		for group: Dictionary in battle_def.get("enemy_groups", []):
			var unit_id: String = String(group.get("unit_id", ""))
			if not units_index.has(unit_id):
				errors.append("Battle %s references missing unit %s." % [battle_id, unit_id])

	for event_id: String in events_index.keys():
		var event_def: Dictionary = events_index[event_id]
		var spawn_mode: String = String(event_def.get("spawn_mode", ""))
		var resolution_type: String = String(event_def.get("resolution_type", ""))
		var trigger_mode: String = String(event_def.get("trigger_mode", "board"))
		if not VALID_SPAWN_MODES.has(spawn_mode):
			errors.append("Event %s has invalid spawn_mode %s." % [event_id, spawn_mode])
		if not VALID_RESOLUTION_TYPES.has(resolution_type):
			errors.append("Event %s has invalid resolution_type %s." % [event_id, resolution_type])
		if not VALID_TRIGGER_MODES.has(trigger_mode):
			errors.append("Event %s has invalid trigger_mode %s." % [event_id, trigger_mode])
		if resolution_type == "battle":
			var battle_id_ref: String = String(event_def.get("battle_id", ""))
			if not battles_index.has(battle_id_ref):
				errors.append("Event %s references missing battle %s." % [event_id, battle_id_ref])
		var reward: Dictionary = event_def.get("reward_package", {})
		for loot_ref: Dictionary in reward.get("loot_tables", []):
			var table_id: String = String(loot_ref.get("id", ""))
			if not loot_index.has(table_id):
				errors.append("Event %s reward references missing loot table %s." % [event_id, table_id])

	for task_def: Dictionary in data.get("tasks", []):
		var task_id: String = String(task_def.get("id", ""))
		var event_ref: String = String(task_def.get("event_ref", ""))
		if not events_index.has(event_ref):
			errors.append("Task %s references missing event %s." % [task_id, event_ref])

	return errors


func _conditions_match(conditions: Array, context: Dictionary) -> bool:
	for condition_value: Variant in conditions:
		var condition: String = String(condition_value)
		if condition.is_empty():
			continue
		if condition.begins_with("turn>="):
			var target_turn := int(condition.trim_prefix("turn>="))
			if int(context.get("turn", 0)) < target_turn:
				return false
		elif condition.begins_with("danger_level>="):
			var target_danger := int(condition.trim_prefix("danger_level>="))
			if int(context.get("danger_level", 0)) < target_danger:
				return false
		elif condition.begins_with("flag:"):
			var flag_id: String = condition.trim_prefix("flag:")
			if not context.get("story_flags", []).has(flag_id):
				return false
		elif condition.begins_with("unlock:"):
			var unlock_id: String = condition.trim_prefix("unlock:")
			if not context.get("unlock_flags", []).has(unlock_id):
				return false
		elif condition.begins_with("completed_task:"):
			var task_id: String = condition.trim_prefix("completed_task:")
			if not context.get("completed_tasks", []).has(task_id):
				return false
		elif condition.begins_with("has_item:"):
			var item_id: String = condition.trim_prefix("has_item:")
			if not context.get("item_ids", []).has(item_id):
				return false
		else:
			return false
	return true


func _event_matches_map(event_def: Dictionary, map_id: String) -> bool:
	var map_ids: Array = event_def.get("map_ids", [])
	return map_ids.has(map_id)


func _index_array_by_id(group_name: String, source: Array) -> Dictionary:
	var index: Dictionary = {}
	for entry: Dictionary in source:
		var item_id: String = String(entry.get("id", ""))
		if item_id.is_empty():
			push_error("%s has an entry without id." % group_name)
			return {}
		if index.has(item_id):
			push_error("%s has duplicated id %s." % [group_name, item_id])
			return {}
		index[item_id] = entry
	return index


func _read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		push_error("Missing data file: %s" % path)
		return null
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		push_error("Data file is empty: %s" % path)
		return null
	var parsed: Variant = JSON.parse_string(text)
	if parsed == null:
		push_error("Data file is not valid JSON: %s" % path)
		return null
	return parsed


func _deep_copy_dict(source: Dictionary) -> Dictionary:
	return source.duplicate(true)
