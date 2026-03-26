extends Node

const DATA_FILES := {
	"glossary": "res://data/glossary.json",
	"maps": "res://data/maps.json",
	"items": "res://data/items.json",
	"item_visuals": "res://data/item_visuals.json",
	"loot_tables": "res://data/loot_tables.json",
	"units": "res://data/units.json",
	"unit_visuals": "res://data/unit_visuals.json",
	"battle_events": "res://data/battle_events.json",
	"battles": "res://data/battles.json",
	"events": "res://data/events.json",
	"tasks": "res://data/tasks.json",
	"progression_defaults": "res://data/progression_defaults.json"
}

const ARRAY_DATA_KEYS := ["maps", "items", "loot_tables", "units", "battle_events", "battles", "events", "tasks"]
const DICT_DATA_KEYS := ["glossary", "progression_defaults", "unit_visuals", "item_visuals"]
const VALID_SPAWN_MODES := {"random_slot": true, "fixed_line": true}
const VALID_RESOLUTION_TYPES := {"battle": true, "random": true, "narrative": true}
const VALID_TRIGGER_MODES := {"board": true, "forced_non_turn": true}
const REQUIRED_FIELDS_BY_GROUP := {
	"maps": ["id", "world_id", "name_cn", "random_slot_count_range", "random_slot_anchors", "base_stats"],
	"items": ["id", "name_cn", "type"],
	"loot_tables": ["id", "name_cn", "mode", "entries"],
	"units": ["id", "camp", "name_cn", "hp", "attack"],
	"battle_events": ["id", "event_type", "trigger", "payload"],
	"battles": ["id", "map_id", "victory_type", "enemy_groups"],
	"events": ["id", "spawn_mode", "resolution_type", "trigger_mode", "event_kind", "map_ids", "conditions", "reward_package"],
	"tasks": ["id", "task_type", "event_ref", "pool_type", "entry_conditions"]
}
const REQUIRED_FIELDS_BY_OBJECT := {
	"glossary": ["visual_theme", "worlds", "world_terms", "naming_rules"],
	"progression_defaults": [
		"inventory_items",
		"currencies",
		"relics",
		"story_flags",
		"unlock_flags",
		"completed_tasks",
		"home_loadout"
	]
}

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

	for key: String in ARRAY_DATA_KEYS:
		if typeof(data.get(key, [])) != TYPE_ARRAY:
			push_error("%s must be an array in data contracts." % key)
			return ERR_INVALID_DATA
	for key: String in DICT_DATA_KEYS:
		if typeof(data.get(key, {})) != TYPE_DICTIONARY:
			push_error("%s must be an object in data contracts." % key)
			return ERR_INVALID_DATA

	for key: String in ARRAY_DATA_KEYS:
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


func list_maps() -> Array:
	var maps: Array = []
	for map_value in data.get("maps", []):
		if typeof(map_value) != TYPE_DICTIONARY:
			continue
		maps.append(_deep_copy_dict(map_value))
	return maps


func list_startable_maps(context: Dictionary = {}) -> Array:
	var check_context: Dictionary = {
		"turn": 1,
		"danger_level": 0,
		"story_flags": [],
		"unlock_flags": [],
		"completed_tasks": [],
		"item_ids": []
	}
	for key in context.keys():
		check_context[key] = context[key]

	var startable_map_ids: Dictionary = {}
	for event_value in data.get("events", []):
		if typeof(event_value) != TYPE_DICTIONARY:
			continue
		var event_def: Dictionary = event_value
		if String(event_def.get("trigger_mode", "board")) != "board":
			continue
		if not _conditions_match(event_def.get("conditions", []), check_context):
			continue
		for map_id_value in event_def.get("map_ids", []):
			var map_id: String = String(map_id_value)
			if map_id.is_empty():
				continue
			startable_map_ids[map_id] = true

	var selected: Array = []
	for map_value in data.get("maps", []):
		if typeof(map_value) != TYPE_DICTIONARY:
			continue
		var map_def: Dictionary = map_value
		var map_id: String = String(map_def.get("id", ""))
		if map_id.is_empty():
			continue
		if not startable_map_ids.has(map_id):
			continue
		selected.append(_deep_copy_dict(map_def))
	return selected


func get_event(event_id: String) -> Dictionary:
	return _deep_copy_dict(by_id.get("events", {}).get(event_id, {}))


func get_task(task_id: String) -> Dictionary:
	return _deep_copy_dict(by_id.get("tasks", {}).get(task_id, {}))


func get_task_by_event_ref(event_id: String) -> Dictionary:
	for task_value in data.get("tasks", []):
		if typeof(task_value) != TYPE_DICTIONARY:
			continue
		var task_def: Dictionary = task_value
		if String(task_def.get("event_ref", "")) == event_id:
			return _deep_copy_dict(task_def)
	return {}


func get_tasks_for_map(map_id: String, context: Dictionary = {}) -> Array:
	var selected: Array = []
	for task_value in data.get("tasks", []):
		if typeof(task_value) != TYPE_DICTIONARY:
			continue
		var task_def: Dictionary = task_value
		var event_ref: String = String(task_def.get("event_ref", ""))
		if event_ref.is_empty():
			continue
		var event_def: Dictionary = by_id.get("events", {}).get(event_ref, {})
		if event_def.is_empty():
			continue
		if not _event_matches_map(event_def, map_id):
			continue
		var unlocked: bool = _conditions_match(task_def.get("entry_conditions", []), context)
		var hydrated: Dictionary = _deep_copy_dict(task_def)
		hydrated["is_unlocked"] = unlocked
		hydrated["event_title"] = String(event_def.get("title", event_ref))
		hydrated["event_kind"] = String(event_def.get("event_kind", ""))
		hydrated["resolution_type"] = String(event_def.get("resolution_type", ""))
		selected.append(hydrated)
	return selected


func get_item(item_id: String) -> Dictionary:
	return _deep_copy_dict(by_id.get("items", {}).get(item_id, {}))


func get_item_visual(item_id: String) -> Dictionary:
	return _deep_copy_dict(data.get("item_visuals", {}).get(item_id, {}))


func get_battle(battle_id: String) -> Dictionary:
	return _deep_copy_dict(by_id.get("battles", {}).get(battle_id, {}))


func get_unit(unit_id: String) -> Dictionary:
	return _deep_copy_dict(by_id.get("units", {}).get(unit_id, {}))


func get_unit_visual(unit_id: String) -> Dictionary:
	return _deep_copy_dict(data.get("unit_visuals", {}).get(unit_id, {}))


func get_battle_event(battle_event_id: String) -> Dictionary:
	return _deep_copy_dict(by_id.get("battle_events", {}).get(battle_event_id, {}))


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
	errors.append_array(_validate_required_fields())
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


func _validate_required_fields() -> Array:
	var errors: Array = []
	for group_name: String in REQUIRED_FIELDS_BY_GROUP.keys():
		var entries: Array = data.get(group_name, [])
		for entry_value: Variant in entries:
			if typeof(entry_value) != TYPE_DICTIONARY:
				errors.append("%s has a non-object entry." % group_name)
				continue
			var entry: Dictionary = entry_value
			var entry_id: String = String(entry.get("id", "<missing_id>"))
			for field_name: String in REQUIRED_FIELDS_BY_GROUP[group_name]:
				if not entry.has(field_name):
					errors.append("%s entry %s missing required field %s." % [group_name, entry_id, field_name])

	for object_name: String in REQUIRED_FIELDS_BY_OBJECT.keys():
		var payload: Dictionary = data.get(object_name, {})
		for field_name: String in REQUIRED_FIELDS_BY_OBJECT[object_name]:
			if not payload.has(field_name):
				errors.append("%s missing required field %s." % [object_name, field_name])

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
