extends Node

const DATA_FILES := {
	"glossary": "res://data/glossary.json",
	"maps": "res://data/maps.json",
	"items": "res://data/items.json",
	"item_visuals": "res://data/item_visuals.json",
	"loot_tables": "res://data/loot_tables.json",
	"strategies": "res://data/strategies.json",
	"units": "res://data/units.json",
	"unit_visuals": "res://data/unit_visuals.json",
	"battle_events": "res://data/battle_events.json",
	"battles": "res://data/battles.json",
	"events": "res://data/events.json",
	"tasks": "res://data/tasks.json",
	"progression_defaults": "res://data/progression_defaults.json"
}

const ARRAY_DATA_KEYS := ["maps", "items", "loot_tables", "strategies", "units", "battle_events", "battles", "events", "tasks"]
const DICT_DATA_KEYS := ["glossary", "progression_defaults", "unit_visuals", "item_visuals"]
const DEFAULT_AUTO_BATTLEFIELD_VISUAL_PATH := "res://output/imagegen/godling-auto-battle-tactical-v2/map-auto-battle-generic-v2.png"
const VALID_SPAWN_MODES := {"random_slot": true, "fixed_line": true}
const VALID_RESOLUTION_TYPES := {"battle": true, "random": true, "narrative": true}
const VALID_TRIGGER_MODES := {"board": true, "forced_non_turn": true}
const VALID_BATTLE_MODES := {"legacy_interactive": true, "auto_units": true}
const VALID_STRATEGY_KINDS := {"passive": true, "active": true}
const VALID_AUTO_TRIGGER_CONDITION_TYPES := {
	"elapsed_gte": true,
	"side_hp_ratio_lte": true,
	"unit_alive_count_lte": true,
	"unit_present": true,
	"event_triggered": true
}
const REQUIRED_FIELDS_BY_GROUP := {
	"maps": ["id", "world_id", "name_cn", "random_slot_count_range", "random_slot_anchors", "base_stats"],
	"items": ["id", "name_cn", "type"],
	"loot_tables": ["id", "name_cn", "mode", "entries"],
	"strategies": ["id", "kind", "trigger_conditions", "effect", "cooldown", "charges", "target_rule", "ui"],
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

	_merge_runtime_created_content()

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
	return _apply_balance_overrides("maps", map_id, _deep_copy_dict(by_id.get("maps", {}).get(map_id, {})))


func list_maps() -> Array:
	var maps: Array = []
	for map_value in data.get("maps", []):
		if typeof(map_value) != TYPE_DICTIONARY:
			continue
		var map_def: Dictionary = map_value
		maps.append(_apply_balance_overrides("maps", String(map_def.get("id", "")), _deep_copy_dict(map_def)))
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
	return _apply_balance_overrides("events", event_id, _deep_copy_dict(by_id.get("events", {}).get(event_id, {})))


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
	return _apply_balance_overrides("items", item_id, _deep_copy_dict(by_id.get("items", {}).get(item_id, {})))


func get_strategy(strategy_id: String) -> Dictionary:
	return _deep_copy_dict(by_id.get("strategies", {}).get(strategy_id, {}))


func list_strategies() -> Array:
	var selected: Array = []
	for strategy_value in data.get("strategies", []):
		if typeof(strategy_value) != TYPE_DICTIONARY:
			continue
		selected.append(_deep_copy_dict(strategy_value))
	return selected


func get_item_visual(item_id: String) -> Dictionary:
	return _deep_copy_dict(data.get("item_visuals", {}).get(item_id, {}))


func get_battle(battle_id: String) -> Dictionary:
	return _apply_balance_overrides("battles", battle_id, _deep_copy_dict(by_id.get("battles", {}).get(battle_id, {})))


func get_unit(unit_id: String) -> Dictionary:
	return _apply_balance_overrides("units", unit_id, _deep_copy_dict(by_id.get("units", {}).get(unit_id, {})))


func get_loot_table(loot_table_id: String) -> Dictionary:
	return _apply_balance_overrides("loot_tables", loot_table_id, _deep_copy_dict(by_id.get("loot_tables", {}).get(loot_table_id, {})))


func get_unit_visual(unit_id: String) -> Dictionary:
	return _deep_copy_dict(data.get("unit_visuals", {}).get(unit_id, {}))


func get_battle_event(battle_event_id: String) -> Dictionary:
	return _deep_copy_dict(by_id.get("battle_events", {}).get(battle_event_id, {}))


func pick_random_events(map_id: String, context: Dictionary, count_range: Vector2i, required_mix: Dictionary = {}) -> Array:
	var candidates: Array = []
	var all_events: Dictionary = by_id.get("events", {})

	for event_id: String in all_events.keys():
		var event_def: Dictionary = get_event(event_id)
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
		var event_def: Dictionary = get_event(event_id)
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


func roll_loot_table(loot_table_id: String, rolls: int = 1) -> Dictionary:
	var loot_table: Dictionary = get_loot_table(loot_table_id)
	if loot_table.is_empty() or rolls <= 0:
		return {"items": [], "currencies": [], "relics": []}
	var result := {
		"items": [],
		"currencies": [],
		"relics": []
	}
	for _i in range(rolls):
		var picked_entry: Dictionary = _pick_loot_entry(loot_table.get("entries", []))
		if picked_entry.is_empty():
			continue
		var stack := {"id": String(picked_entry.get("id", "")), "count": int(picked_entry.get("count", 0))}
		var item_def: Dictionary = get_item(String(picked_entry.get("id", "")))
		var item_type: int = int(item_def.get("type", 0))
		if item_type == 1:
			result["currencies"].append(stack)
		elif item_type == 10:
			result["relics"].append(stack)
		else:
			result["items"].append(stack)
	return result


func _validate_data_contracts() -> Array:
	var errors: Array = []
	errors.append_array(_validate_required_fields())
	var maps_index: Dictionary = by_id.get("maps", {})
	var items_index: Dictionary = by_id.get("items", {})
	var loot_index: Dictionary = by_id.get("loot_tables", {})
	var strategies_index: Dictionary = by_id.get("strategies", {})
	var units_index: Dictionary = by_id.get("units", {})
	var battles_index: Dictionary = by_id.get("battles", {})
	var battle_events_index: Dictionary = by_id.get("battle_events", {})
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

	for strategy_id: String in strategies_index.keys():
		var strategy_def: Dictionary = strategies_index[strategy_id]
		var strategy_kind: String = String(strategy_def.get("kind", ""))
		if not VALID_STRATEGY_KINDS.has(strategy_kind):
			errors.append("Strategy %s has invalid kind %s." % [strategy_id, strategy_kind])
		if typeof(strategy_def.get("trigger_conditions", [])) != TYPE_ARRAY:
			errors.append("Strategy %s trigger_conditions must be an array." % strategy_id)
		var effect: Dictionary = strategy_def.get("effect", {})
		if typeof(effect) != TYPE_DICTIONARY or String(effect.get("type", "")).is_empty():
			errors.append("Strategy %s is missing effect.type." % strategy_id)

	for battle_id: String in battles_index.keys():
		var battle_def: Dictionary = battles_index[battle_id]
		var map_id: String = String(battle_def.get("map_id", ""))
		if not maps_index.has(map_id):
			errors.append("Battle %s references missing map %s." % [battle_id, map_id])
		for group: Dictionary in battle_def.get("enemy_groups", []):
			var unit_id: String = String(group.get("unit_id", ""))
			if not units_index.has(unit_id):
				errors.append("Battle %s references missing unit %s." % [battle_id, unit_id])
		var battle_mode: String = String(battle_def.get("battle_mode", "legacy_interactive"))
		if not VALID_BATTLE_MODES.has(battle_mode):
			errors.append("Battle %s has invalid battle_mode %s." % [battle_id, battle_mode])
		if battle_mode == "auto_units":
			if typeof(battle_def.get("battlefield", {})) != TYPE_DICTIONARY:
				errors.append("Battle %s auto_units battlefield must be an object." % battle_id)
			else:
				var battlefield: Dictionary = battle_def.get("battlefield", {})
				var field_size: Array = battlefield.get("size", [])
				if field_size.size() != 2:
					errors.append("Battle %s battlefield.size must contain 2 numbers." % battle_id)
			if typeof(battle_def.get("victory_rules", {})) != TYPE_DICTIONARY:
				errors.append("Battle %s auto_units victory_rules must be an object." % battle_id)
			if typeof(battle_def.get("defeat_rules", {})) != TYPE_DICTIONARY:
				errors.append("Battle %s auto_units defeat_rules must be an object." % battle_id)
			var battlefield_visual_path: String = String(battle_def.get("battlefield_visual_path", "")).strip_edges()
			if (not battlefield_visual_path.is_empty()) and (not _resource_path_exists(battlefield_visual_path)):
				errors.append("Battle %s battlefield_visual_path is missing: %s." % [battle_id, battlefield_visual_path])
			var hero_spawn: Array = battle_def.get("hero_spawn", [])
			if hero_spawn.size() != 2:
				errors.append("Battle %s auto_units hero_spawn must contain 2 numbers." % battle_id)
			for ally_group_value in battle_def.get("ally_groups", []):
				if typeof(ally_group_value) != TYPE_DICTIONARY:
					continue
				var ally_group: Dictionary = ally_group_value
				var ally_unit_id: String = String(ally_group.get("unit_id", ""))
				if not units_index.has(ally_unit_id):
					errors.append("Battle %s references missing ally unit %s." % [battle_id, ally_unit_id])
			for event_id_value in battle_def.get("scripted_event_ids", []):
				var scripted_event_id: String = String(event_id_value)
				if not battle_events_index.has(scripted_event_id):
					errors.append("Battle %s references missing scripted event %s." % [battle_id, scripted_event_id])

	for battle_event_id: String in battle_events_index.keys():
		var battle_event: Dictionary = battle_events_index[battle_event_id]
		var trigger_conditions: Array = battle_event.get("trigger_conditions", [])
		for condition_value in trigger_conditions:
			if typeof(condition_value) != TYPE_DICTIONARY:
				errors.append("Battle event %s has non-object trigger condition." % battle_event_id)
				continue
			var condition: Dictionary = condition_value
			var condition_type: String = String(condition.get("type", ""))
			if not VALID_AUTO_TRIGGER_CONDITION_TYPES.has(condition_type):
				errors.append("Battle event %s has invalid trigger condition %s." % [battle_event_id, condition_type])

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


func _balance_state() -> Node:
	return get_node_or_null("/root/BalanceState")


func _merge_runtime_created_content() -> void:
	var balance := _balance_state()
	if balance == null or not balance.has_method("get_created_content"):
		return
	var created: Dictionary = balance.call("get_created_content")
	for item_value in created.get("items", []):
		if typeof(item_value) != TYPE_DICTIONARY:
			continue
		var item_def: Dictionary = _deep_copy_dict(item_value)
		var item_id: String = String(item_def.get("id", ""))
		if item_id.is_empty():
			continue
		_upsert_data_array_entry("items", item_def)
		var item_visuals: Dictionary = data.get("item_visuals", {})
		if not item_visuals.has(item_id):
			item_visuals[item_id] = _default_item_visual(item_id)
			data["item_visuals"] = item_visuals
	for unit_value in created.get("units", []):
		if typeof(unit_value) != TYPE_DICTIONARY:
			continue
		var unit_def: Dictionary = _deep_copy_dict(unit_value)
		var unit_id: String = String(unit_def.get("id", ""))
		if unit_id.is_empty():
			continue
		_upsert_data_array_entry("units", unit_def)
		var unit_visuals: Dictionary = data.get("unit_visuals", {})
		if not unit_visuals.has(unit_id):
			unit_visuals[unit_id] = _default_unit_visual(unit_def)
			data["unit_visuals"] = unit_visuals
	_merge_runtime_links(created.get("links", {}))


func _merge_runtime_links(links: Variant) -> void:
	if typeof(links) != TYPE_DICTIONARY:
		return
	var links_dict: Dictionary = links
	for link_value in links_dict.get("battle_enemy_groups", []):
		if typeof(link_value) != TYPE_DICTIONARY:
			continue
		_apply_runtime_battle_enemy_link(link_value)
	for link_value in links_dict.get("loot_table_entries", []):
		if typeof(link_value) != TYPE_DICTIONARY:
			continue
		_apply_runtime_loot_entry_link(link_value)
	for link_value in links_dict.get("event_reward_loot_tables", []):
		if typeof(link_value) != TYPE_DICTIONARY:
			continue
		_apply_runtime_event_reward_loot_link(link_value)


func _apply_runtime_battle_enemy_link(link: Dictionary) -> void:
	var battle_id: String = String(link.get("battle_id", "")).strip_edges()
	var unit_id: String = String(link.get("unit_id", "")).strip_edges()
	if battle_id.is_empty() or unit_id.is_empty():
		return
	if not _data_array_has_id("battles", battle_id):
		return
	if not _data_array_has_id("units", unit_id):
		return
	var link_key := String(link.get("link_key", "%s::%s" % [battle_id, unit_id]))
	var count_range: Array = link.get("count_range", []).duplicate(true)
	var min_count: int = int(count_range[0]) if count_range.size() > 0 else max(0, int(link.get("count", 1)))
	var max_count: int = int(count_range[1]) if count_range.size() > 1 else max(min_count, int(link.get("count", min_count)))
	if max_count < min_count:
		var swapped := min_count
		min_count = max_count
		max_count = swapped
	var count: int = clampi(int(link.get("count", max_count)), min_count, max_count)
	var spawn: Array = link.get("spawn", []).duplicate(true)
	var spawn_x: int = int(spawn[0]) if spawn.size() > 0 else 540
	var spawn_y: int = int(spawn[1]) if spawn.size() > 1 else 220
	var battle_index := _find_data_array_index("battles", battle_id)
	if battle_index < 0:
		return
	var battles: Array = data.get("battles", [])
	var battle_def: Dictionary = _deep_copy_dict(battles[battle_index])
	var enemy_groups: Array = battle_def.get("enemy_groups", []).duplicate(true)
	var runtime_group := {
		"runtime_link_key": link_key,
		"unit_id": unit_id,
		"count": count,
		"count_range": [min_count, max_count],
		"spawn": [spawn_x, spawn_y]
	}
	var updated := false
	for group_index: int in range(enemy_groups.size()):
		var group_value: Variant = enemy_groups[group_index]
		if typeof(group_value) != TYPE_DICTIONARY:
			continue
		var group: Dictionary = group_value
		if String(group.get("runtime_link_key", "")) != link_key:
			continue
		enemy_groups[group_index] = runtime_group
		updated = true
		break
	if not updated:
		enemy_groups.append(runtime_group)
	battle_def["enemy_groups"] = enemy_groups
	battles[battle_index] = battle_def
	data["battles"] = battles


func _apply_runtime_loot_entry_link(link: Dictionary) -> void:
	var loot_table_id: String = String(link.get("loot_table_id", "")).strip_edges()
	var item_id: String = String(link.get("item_id", "")).strip_edges()
	if loot_table_id.is_empty() or item_id.is_empty():
		return
	if not _data_array_has_id("loot_tables", loot_table_id):
		return
	if not _data_array_has_id("items", item_id):
		return
	var link_key := String(link.get("link_key", "%s::%s" % [loot_table_id, item_id]))
	var table_index := _find_data_array_index("loot_tables", loot_table_id)
	if table_index < 0:
		return
	var loot_tables: Array = data.get("loot_tables", [])
	var table_def: Dictionary = _deep_copy_dict(loot_tables[table_index])
	var entries: Array = table_def.get("entries", []).duplicate(true)
	var runtime_entry := {
		"runtime_link_key": link_key,
		"kind": String(link.get("kind", "item")),
		"id": item_id,
		"count": max(0, int(link.get("count", 1))),
		"weight": max(0, int(link.get("weight", 5))),
		"prob": clampf(float(link.get("prob", 1.0)), 0.0, 1.0)
	}
	var updated := false
	for entry_index: int in range(entries.size()):
		var entry_value: Variant = entries[entry_index]
		if typeof(entry_value) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_value
		if String(entry.get("runtime_link_key", "")) != link_key:
			continue
		entries[entry_index] = runtime_entry
		updated = true
		break
	if not updated:
		entries.append(runtime_entry)
	table_def["entries"] = entries
	loot_tables[table_index] = table_def
	data["loot_tables"] = loot_tables


func _apply_runtime_event_reward_loot_link(link: Dictionary) -> void:
	var event_id: String = String(link.get("event_id", "")).strip_edges()
	var loot_table_id: String = String(link.get("loot_table_id", "")).strip_edges()
	if event_id.is_empty() or loot_table_id.is_empty():
		return
	if not _data_array_has_id("events", event_id):
		return
	if not _data_array_has_id("loot_tables", loot_table_id):
		return
	var event_index := _find_data_array_index("events", event_id)
	if event_index < 0:
		return
	var option_index: int = max(-1, int(link.get("option_index", -1)))
	var target_key := "root" if option_index < 0 else "option.%d" % option_index
	var link_key := String(link.get("link_key", "%s::%s::%s" % [event_id, target_key, loot_table_id]))
	var runtime_ref := {
		"runtime_link_key": link_key,
		"id": loot_table_id,
		"rolls": max(0, int(link.get("rolls", 1)))
	}
	var events: Array = data.get("events", [])
	var event_def: Dictionary = _deep_copy_dict(events[event_index])
	if option_index < 0:
		var root_reward: Dictionary = event_def.get("reward_package", {}).duplicate(true)
		event_def["reward_package"] = _upsert_runtime_reward_loot_ref(root_reward, runtime_ref)
	else:
		var option_list: Array = event_def.get("option_list", []).duplicate(true)
		if option_index >= option_list.size():
			return
		if typeof(option_list[option_index]) != TYPE_DICTIONARY:
			return
		var option_def: Dictionary = _deep_copy_dict(option_list[option_index])
		var option_reward: Dictionary = option_def.get("reward_package", {}).duplicate(true)
		option_def["reward_package"] = _upsert_runtime_reward_loot_ref(option_reward, runtime_ref)
		option_list[option_index] = option_def
		event_def["option_list"] = option_list
	events[event_index] = event_def
	data["events"] = events


func _upsert_runtime_reward_loot_ref(reward: Dictionary, runtime_ref: Dictionary) -> Dictionary:
	var normalized_reward: Dictionary = reward.duplicate(true)
	var loot_tables: Array = normalized_reward.get("loot_tables", []).duplicate(true)
	var link_key: String = String(runtime_ref.get("runtime_link_key", ""))
	var updated := false
	for index: int in range(loot_tables.size()):
		var loot_value: Variant = loot_tables[index]
		if typeof(loot_value) != TYPE_DICTIONARY:
			continue
		var loot_ref: Dictionary = loot_value
		if String(loot_ref.get("runtime_link_key", "")) != link_key:
			continue
		loot_tables[index] = runtime_ref.duplicate(true)
		updated = true
		break
	if not updated:
		loot_tables.append(runtime_ref.duplicate(true))
	normalized_reward["loot_tables"] = loot_tables
	return normalized_reward


func _default_item_visual(_item_id: String) -> Dictionary:
	return {
		"icon_path": "res://icon.svg",
		"origin": "runtime_created",
		"notes": "Runtime-created item uses fallback icon."
	}


func _default_unit_visual(unit_def: Dictionary) -> Dictionary:
	var camp: String = String(unit_def.get("camp", "enemy"))
	var portrait_path := "res://assets/battle/placeholders/enemy_hollow_deacon.svg"
	if camp == "hero":
		portrait_path = "res://assets/battle/placeholders/hero_pilgrim_a01.svg"
	return {
		"portrait_path": portrait_path,
		"token_path": portrait_path,
		"icon_path": "res://icon.svg",
		"portrait_scale": 1.0,
		"token_scale": 1.0,
		"x_offset": 0.0,
		"y_offset": 0.0,
		"token_x_offset": 0.0,
		"token_y_offset": 0.0,
		"origin": "runtime_created",
		"notes": "Runtime-created unit uses fallback portrait."
	}


func _resource_path_exists(path: String) -> bool:
	if path.is_empty():
		return false
	if ResourceLoader.exists(path):
		return true
	return FileAccess.file_exists(ProjectSettings.globalize_path(path))


func _data_array_has_id(group_name: String, entry_id: String) -> bool:
	for entry_value in data.get(group_name, []):
		if typeof(entry_value) != TYPE_DICTIONARY:
			continue
		if String((entry_value as Dictionary).get("id", "")) == entry_id:
			return true
	return false


func _find_data_array_index(group_name: String, entry_id: String) -> int:
	var entries: Array = data.get(group_name, [])
	for index: int in range(entries.size()):
		var entry_value: Variant = entries[index]
		if typeof(entry_value) != TYPE_DICTIONARY:
			continue
		if String((entry_value as Dictionary).get("id", "")) == entry_id:
			return index
	return -1


func _upsert_data_array_entry(group_name: String, entry: Dictionary) -> void:
	var entry_id: String = String(entry.get("id", ""))
	if entry_id.is_empty():
		return
	var entries: Array = data.get(group_name, [])
	for index: int in range(entries.size()):
		var existing_value: Variant = entries[index]
		if typeof(existing_value) != TYPE_DICTIONARY:
			continue
		if String((existing_value as Dictionary).get("id", "")) == entry_id:
			entries[index] = entry
			data[group_name] = entries
			return
	entries.append(entry)
	data[group_name] = entries


func _apply_balance_overrides(group_name: String, entry_id: String, payload: Dictionary) -> Dictionary:
	if payload.is_empty():
		return payload
	var balance := _balance_state()
	if balance == null or not balance.has_method("get_value"):
		return payload
	match group_name:
		"maps":
			var range_values: Array = payload.get("random_slot_count_range", []).duplicate(true)
			if range_values.size() >= 2:
				range_values[0] = int(balance.call("get_value", "maps.%s.random_slot_min" % entry_id, int(range_values[0])))
				range_values[1] = int(balance.call("get_value", "maps.%s.random_slot_max" % entry_id, int(range_values[1])))
				payload["random_slot_count_range"] = range_values
		"units":
			payload["hp"] = int(balance.call("get_value", "units.%s.hp" % entry_id, int(payload.get("hp", 0))))
			var attack: Dictionary = payload.get("attack", {}).duplicate(true)
			attack["power"] = float(balance.call("get_value", "units.%s.attack_power" % entry_id, float(attack.get("power", 0.0))))
			attack["speed"] = float(balance.call("get_value", "units.%s.attack_speed" % entry_id, float(attack.get("speed", 1.0))))
			payload["attack"] = attack
		"items":
			var combat_effect: Dictionary = payload.get("combat_effect", {}).duplicate(true)
			if not combat_effect.is_empty():
				combat_effect["value"] = float(balance.call("get_value", "items.%s.combat_effect_value" % entry_id, float(combat_effect.get("value", 0.0))))
				payload["combat_effect"] = combat_effect
		"battles":
			var groups: Array = payload.get("enemy_groups", []).duplicate(true)
			for group_index: int in groups.size():
				var group: Dictionary = groups[group_index]
				group["count"] = int(balance.call("get_value", "battles.%s.group.%d.count" % [entry_id, group_index], int(group.get("count", 0))))
				var count_range: Array = group.get("count_range", []).duplicate(true)
				if count_range.size() >= 2:
					count_range[0] = int(balance.call("get_value", "battles.%s.group.%d.min" % [entry_id, group_index], int(count_range[0])))
					count_range[1] = int(balance.call("get_value", "battles.%s.group.%d.max" % [entry_id, group_index], int(count_range[1])))
					group["count_range"] = count_range
				groups[group_index] = group
			payload["enemy_groups"] = groups
		"events":
			payload["weight"] = int(balance.call("get_value", "events.%s.weight" % entry_id, int(payload.get("weight", 0))))
			payload["reward_package"] = _apply_reward_overrides(entry_id, payload.get("reward_package", {}).duplicate(true), balance)
			var option_list: Array = payload.get("option_list", []).duplicate(true)
			for option_index: int in option_list.size():
				var option_def: Dictionary = option_list[option_index]
				option_def["reward_package"] = _apply_reward_overrides("%s.option.%d" % [entry_id, option_index], option_def.get("reward_package", {}).duplicate(true), balance)
				option_list[option_index] = option_def
			payload["option_list"] = option_list
		"loot_tables":
			var entries: Array = payload.get("entries", []).duplicate(true)
			for entry_index: int in entries.size():
				var loot_entry: Dictionary = entries[entry_index]
				loot_entry["count"] = int(balance.call("get_value", "loot_tables.%s.entry.%d.count" % [entry_id, entry_index], int(loot_entry.get("count", 0))))
				loot_entry["weight"] = int(balance.call("get_value", "loot_tables.%s.entry.%d.weight" % [entry_id, entry_index], int(loot_entry.get("weight", 0))))
				loot_entry["prob"] = float(balance.call("get_value", "loot_tables.%s.entry.%d.prob" % [entry_id, entry_index], float(loot_entry.get("prob", 1.0))))
				entries[entry_index] = loot_entry
			payload["entries"] = entries
	return payload


func _apply_reward_overrides(prefix: String, reward: Dictionary, balance: Node) -> Dictionary:
	reward["currencies"] = _apply_reward_stack_overrides(prefix, "currencies", reward.get("currencies", []), balance)
	reward["items"] = _apply_reward_stack_overrides(prefix, "items", reward.get("items", []), balance)
	reward["relics"] = _apply_reward_stack_overrides(prefix, "relics", reward.get("relics", []), balance)
	var loot_tables: Array = reward.get("loot_tables", []).duplicate(true)
	for index: int in loot_tables.size():
		var table_ref: Dictionary = loot_tables[index]
		table_ref["rolls"] = int(balance.call("get_value", "events.%s.loot_tables.%d.rolls" % [prefix, index], int(table_ref.get("rolls", 1))))
		loot_tables[index] = table_ref
	reward["loot_tables"] = loot_tables
	return reward


func _apply_reward_stack_overrides(prefix: String, stack_group: String, stacks: Array, balance: Node) -> Array:
	var adjusted: Array = stacks.duplicate(true)
	for index: int in adjusted.size():
		var stack: Dictionary = adjusted[index]
		stack["count"] = int(balance.call("get_value", "events.%s.%s.%d.count" % [prefix, stack_group, index], int(stack.get("count", 0))))
		adjusted[index] = stack
	return adjusted


func _pick_loot_entry(entries: Array) -> Dictionary:
	var candidates: Array = []
	var total_weight := 0.0
	for entry_value in entries:
		if typeof(entry_value) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_value
		if randf() > float(entry.get("prob", 1.0)):
			continue
		var weight: float = max(0.0, float(entry.get("weight", 0.0)))
		if weight <= 0.0:
			continue
		candidates.append(entry)
		total_weight += weight
	if candidates.is_empty() or total_weight <= 0.0:
		return {}
	var roll: float = randf() * total_weight
	var cursor := 0.0
	for entry_value in candidates:
		var entry: Dictionary = entry_value
		cursor += float(entry.get("weight", 0.0))
		if roll <= cursor:
			return _deep_copy_dict(entry)
	return _deep_copy_dict(candidates.back())


func _deep_copy_dict(source: Dictionary) -> Dictionary:
	return source.duplicate(true)
