extends Node

signal config_applied(config: Dictionary)
signal content_library_changed(snapshot: Dictionary)

const PRESET_DIR := "user://balance_presets"
const CONTENT_SAVE_PATH := "user://content_creations.json"
const DEFAULT_CREATED_CONTENT := {
	"items": [],
	"units": [],
	"links": {
		"battle_enemy_groups": [],
		"loot_table_entries": []
	}
}

const EDITOR_SECTIONS := [
	{
		"id": "battle_core",
		"name_cn": "战斗核心",
		"description": "决定我方基础伤害、敌方回合压力与战斗时长。",
		"entries": [
			{"path": "battle.hero_base_power_multiplier", "label": "英雄基础倍率", "description": "整体抬高我方攻击系数。", "default": 2.1, "min": 0.6, "max": 4.0, "step": 0.05},
			{"path": "battle.relic_bonus_per_relic", "label": "每件圣遗加成", "description": "每件装备圣遗带来的额外战斗增幅。", "default": 0.12, "min": 0.0, "max": 0.4, "step": 0.01},
			{"path": "battle.enemy_phase_attacker_limit", "label": "敌方回合出手数", "description": "单轮敌方最多参与反击的单位数。", "default": 2, "min": 1, "max": 4, "step": 1},
			{"path": "battle.enemy_damage_divisor", "label": "敌伤除数", "description": "敌方攻击换算成实际伤害时的除数，越高越温和。", "default": 7.5, "min": 4.0, "max": 12.0, "step": 0.25},
			{"path": "battle.enemy_damage_floor", "label": "敌伤下限", "description": "敌方单次反击的最低伤害。", "default": 0.8, "min": 0.2, "max": 3.0, "step": 0.1},
			{"path": "battle.tick_limit", "label": "战斗回合上限", "description": "超过此回合数仍未结束则强制结算。", "default": 60, "min": 10, "max": 120, "step": 1}
		]
	},
	{
		"id": "resolve_tempo",
		"name_cn": "灵势与节奏",
		"description": "控制技能循环、待机收益与每回合资源恢复。",
		"entries": [
			{"path": "battle.initial_hero_resolve", "label": "初始灵势", "description": "战斗开始时的灵势储备。", "default": 3, "min": 0, "max": 6, "step": 1},
			{"path": "battle.hero_resolve_max", "label": "灵势上限", "description": "灵势槽上限，决定可蓄积的资源深度。", "default": 4, "min": 1, "max": 8, "step": 1},
			{"path": "battle.resolve_gain_on_wait", "label": "待机回灵势", "description": "蓄势待机时恢复的灵势。", "default": 1, "min": 0, "max": 3, "step": 1},
			{"path": "battle.resolve_gain_on_enemy_phase", "label": "敌回合后回灵势", "description": "完成整轮敌方反击后恢复的灵势。", "default": 1, "min": 0, "max": 3, "step": 1},
			{"path": "battle.resolve_gain_on_guard", "label": "架盾回灵势", "description": "使用架盾时直接返还的灵势。", "default": 1, "min": 0, "max": 3, "step": 1}
		]
	},
	{
		"id": "skills",
		"name_cn": "技能位",
		"description": "控制斩击、架盾、祷焰横扫三类战术位的强度与循环。",
		"entries": [
			{"path": "skills.primary_damage_multiplier", "label": "斩击倍率", "description": "单体输出技能的伤害倍率。", "default": 1.15, "min": 0.5, "max": 2.5, "step": 0.05},
			{"path": "skills.primary_cooldown", "label": "斩击冷却", "description": "斩击使用后的冷却回合。", "default": 0, "min": 0, "max": 4, "step": 1},
			{"path": "skills.primary_cost", "label": "斩击灵势消耗", "description": "斩击释放所需的灵势点数。", "default": 1, "min": 0, "max": 4, "step": 1},
			{"path": "skills.guard_damage_factor", "label": "架盾承伤系数", "description": "架盾生效时敌伤乘数，越低越硬。", "default": 0.22, "min": 0.05, "max": 0.7, "step": 0.01},
			{"path": "skills.guard_cooldown", "label": "架盾冷却", "description": "架盾进入再次可用前的回合数。", "default": 2, "min": 0, "max": 4, "step": 1},
			{"path": "skills.guard_cost", "label": "架盾灵势消耗", "description": "架盾释放所需的灵势点数。", "default": 1, "min": 0, "max": 3, "step": 1},
			{"path": "skills.burst_damage_multiplier", "label": "横扫倍率", "description": "祷焰横扫对每个敌人的伤害倍率。", "default": 0.72, "min": 0.2, "max": 1.8, "step": 0.05},
			{"path": "skills.burst_cooldown", "label": "横扫冷却", "description": "祷焰横扫再次可用前的回合数。", "default": 2, "min": 0, "max": 5, "step": 1},
			{"path": "skills.burst_cost", "label": "横扫灵势消耗", "description": "祷焰横扫释放所需的灵势点数。", "default": 2, "min": 0, "max": 5, "step": 1}
		]
	},
	{
		"id": "run_board",
		"name_cn": "地图与恢复",
		"description": "影响每回合事件密度、危险增长、强制袭击时机与战斗回复。",
		"entries": [
			{"path": "board.random_event_density_multiplier", "label": "随机事件密度", "description": "影响每回合随机事件板的整体数量。", "default": 1.0, "min": 0.5, "max": 2.0, "step": 0.05},
			{"path": "board.danger_gain_per_turn", "label": "每回合危险增长", "description": "完成一次事件并推进回合后增加的危险度。", "default": 1, "min": 0, "max": 3, "step": 1},
			{"path": "board.forced_event_unlock_turn", "label": "强制袭击解锁回合", "description": "从第几回合开始允许触发强制袭击。", "default": 4, "min": 1, "max": 8, "step": 1},
			{"path": "board.forced_event_chance_multiplier", "label": "强制袭击概率倍率", "description": "对配置表中的强制袭击概率进行整体缩放。", "default": 1.0, "min": 0.0, "max": 2.0, "step": 0.05},
			{"path": "items.field_balm_recover_hp", "label": "战地敷膏恢复量", "description": "单次使用战斗治疗道具时回复的生命。", "default": 16.0, "min": 4.0, "max": 30.0, "step": 0.5}
		]
	}
]

var _flat_config: Dictionary = {}
var _created_content: Dictionary = DEFAULT_CREATED_CONTENT.duplicate(true)


func _ready() -> void:
	_load_created_content()
	_flat_config = get_default_flat_config()
	_sync_created_heroes_into_progression()
	_reload_content_db()


func get_default_flat_config() -> Dictionary:
	var defaults: Dictionary = {}
	for section_value in _all_sections():
		var section: Dictionary = section_value
		for entry_value in section.get("entries", []):
			var entry: Dictionary = entry_value
			defaults[String(entry.get("path", ""))] = entry.get("default")
	return defaults


func get_flat_config() -> Dictionary:
	return _flat_config.duplicate(true)


func get_value(path: String, fallback: Variant = null) -> Variant:
	if _flat_config.has(path):
		return _flat_config[path]
	return fallback


func get_editor_sections() -> Array:
	var sections: Array = []
	for section_value in _all_sections():
		var section: Dictionary = section_value
		var section_copy: Dictionary = {
			"id": String(section.get("id", "")),
			"name_cn": String(section.get("name_cn", "")),
			"description": String(section.get("description", "")),
			"entries": []
		}
		for entry_value in section.get("entries", []):
			var entry: Dictionary = entry_value
			var hydrated: Dictionary = entry.duplicate(true)
			var path: String = String(entry.get("path", ""))
			hydrated["value"] = _flat_config.get(path, entry.get("default"))
			section_copy["entries"].append(hydrated)
		sections.append(section_copy)
	return sections


func get_created_content() -> Dictionary:
	return _created_content.duplicate(true)


func get_created_links() -> Dictionary:
	_ensure_link_container()
	return _created_content.get("links", {}).duplicate(true)


func get_created_content_summary() -> Dictionary:
	var items: Array[String] = []
	var heroes: Array[String] = []
	var enemies: Array[String] = []
	for item_value in _created_content.get("items", []):
		if typeof(item_value) != TYPE_DICTIONARY:
			continue
		var item_def: Dictionary = item_value
		var item_id: String = String(item_def.get("id", ""))
		items.append("%s (%s)" % [_preferred_name(String(item_def.get("name_cn", "")), item_id, "item"), item_id])
	for unit_value in _created_content.get("units", []):
		if typeof(unit_value) != TYPE_DICTIONARY:
			continue
		var unit_def: Dictionary = unit_value
		var unit_id: String = String(unit_def.get("id", ""))
		var summary_line := "%s (%s)" % [_preferred_name(String(unit_def.get("name_cn", "")), unit_id, String(unit_def.get("camp", "enemy"))), unit_id]
		if String(unit_def.get("camp", "")) == "hero":
			heroes.append(summary_line)
		else:
			enemies.append(summary_line)
	return {
		"items": items,
		"heroes": heroes,
		"enemies": enemies
	}


func list_created_items() -> Array:
	return _created_content.get("items", []).duplicate(true)


func list_created_units(camp: String = "") -> Array:
	var result: Array = []
	for unit_value in _created_content.get("units", []):
		if typeof(unit_value) != TYPE_DICTIONARY:
			continue
		var unit_def: Dictionary = unit_value
		if not camp.is_empty() and String(unit_def.get("camp", "")) != camp:
			continue
		result.append(unit_def.duplicate(true))
	return result


func generate_content_id(prefix: String) -> String:
	var sanitized_prefix: String = _normalize_preset_name(prefix).to_lower()
	if sanitized_prefix.is_empty():
		sanitized_prefix = "entry"
	var attempt := 1
	while attempt <= 9999:
		var candidate := "%s_custom_%04d" % [sanitized_prefix, attempt]
		if not _content_id_exists("items", candidate) and not _content_id_exists("units", candidate):
			return candidate
		attempt += 1
	return "%s_custom_%d" % [sanitized_prefix, Time.get_ticks_msec()]


func upsert_item(payload: Dictionary) -> Dictionary:
	var item_id: String = _normalize_content_id(String(payload.get("id", "")), "item")
	if item_id.is_empty():
		return {"ok": false, "error": "invalid_id"}
	var existing_index := _find_created_index("items", item_id)
	var item_def := _build_item_definition(payload, item_id)
	if existing_index >= 0:
		_created_content["items"][existing_index] = item_def
	else:
		_created_content["items"].append(item_def)
	_persist_created_content()
	return {"ok": true, "id": item_id, "entry": item_def, "mode": "update" if existing_index >= 0 else "create"}


func create_item(payload: Dictionary) -> Dictionary:
	var item_id: String = _normalize_content_id(String(payload.get("id", "")), "item")
	if _content_id_exists("items", item_id):
		return {"ok": false, "error": "duplicate_id", "id": item_id}
	var result: Dictionary = upsert_item(payload)
	if not bool(result.get("ok", false)):
		return result
	if String(result.get("mode", "")) != "create":
		return {"ok": false, "error": "duplicate_id", "id": String(result.get("id", ""))}
	return result


func create_enemy(payload: Dictionary) -> Dictionary:
	return _create_unit(payload, "enemy")


func create_hero(payload: Dictionary) -> Dictionary:
	return _create_unit(payload, "hero")


func upsert_enemy(payload: Dictionary) -> Dictionary:
	return _upsert_unit(payload, "enemy")


func upsert_hero(payload: Dictionary) -> Dictionary:
	return _upsert_unit(payload, "hero")


func delete_created_item(item_id: String) -> Dictionary:
	return _delete_created_entry("items", item_id)


func delete_created_unit(unit_id: String, camp: String = "") -> Dictionary:
	var result: Dictionary = _delete_created_entry("units", unit_id)
	if bool(result.get("ok", false)) and not camp.is_empty():
		result["camp"] = camp
	return result


func link_enemy_to_battle(payload: Dictionary) -> Dictionary:
	_ensure_link_container()
	var battle_id: String = String(payload.get("battle_id", "")).strip_edges()
	var unit_id: String = String(payload.get("unit_id", "")).strip_edges()
	if battle_id.is_empty() or unit_id.is_empty():
		return {"ok": false, "error": "missing_id"}
	var content := _content_db()
	if content == null:
		return {"ok": false, "error": "missing_content_db"}
	if content.get_battle(battle_id).is_empty():
		return {"ok": false, "error": "missing_battle", "battle_id": battle_id}
	if content.get_unit(unit_id).is_empty():
		return {"ok": false, "error": "missing_unit", "unit_id": unit_id}
	var min_count: int = max(0, int(payload.get("count_min", 1)))
	var max_count: int = max(0, int(payload.get("count_max", min_count)))
	if max_count < min_count:
		var swapped := min_count
		min_count = max_count
		max_count = swapped
	var count: int = clampi(int(payload.get("count", max_count)), min_count, max_count)
	var spawn_x: int = int(payload.get("spawn_x", 540))
	var spawn_y: int = int(payload.get("spawn_y", 220))
	var link_key := "%s::%s" % [battle_id, unit_id]
	var link_entry := {
		"link_key": link_key,
		"battle_id": battle_id,
		"unit_id": unit_id,
		"count": count,
		"count_range": [min_count, max_count],
		"spawn": [spawn_x, spawn_y]
	}
	var mode := _upsert_link_entry("battle_enemy_groups", link_key, link_entry)
	_persist_created_content()
	return {
		"ok": true,
		"mode": mode,
		"link_key": link_key,
		"battle_id": battle_id,
		"unit_id": unit_id
	}


func link_item_to_loot_table(payload: Dictionary) -> Dictionary:
	_ensure_link_container()
	var loot_table_id: String = String(payload.get("loot_table_id", "")).strip_edges()
	var item_id: String = String(payload.get("item_id", "")).strip_edges()
	if loot_table_id.is_empty() or item_id.is_empty():
		return {"ok": false, "error": "missing_id"}
	var content := _content_db()
	if content == null:
		return {"ok": false, "error": "missing_content_db"}
	if content.get_loot_table(loot_table_id).is_empty():
		return {"ok": false, "error": "missing_loot_table", "loot_table_id": loot_table_id}
	if content.get_item(item_id).is_empty():
		return {"ok": false, "error": "missing_item", "item_id": item_id}
	var count: int = max(0, int(payload.get("count", 1)))
	var weight: int = max(0, int(payload.get("weight", 5)))
	var prob: float = clampf(float(payload.get("prob", 1.0)), 0.0, 1.0)
	var link_key := "%s::%s" % [loot_table_id, item_id]
	var link_entry := {
		"link_key": link_key,
		"loot_table_id": loot_table_id,
		"item_id": item_id,
		"kind": "item",
		"count": count,
		"weight": weight,
		"prob": prob
	}
	var mode := _upsert_link_entry("loot_table_entries", link_key, link_entry)
	_persist_created_content()
	return {
		"ok": true,
		"mode": mode,
		"link_key": link_key,
		"loot_table_id": loot_table_id,
		"item_id": item_id
	}


func reset_created_content() -> void:
	_created_content = DEFAULT_CREATED_CONTENT.duplicate(true)
	_persist_created_content()


func apply_flat_config(next_flat: Dictionary) -> Dictionary:
	_flat_config = _sanitize_flat_config(next_flat)
	emit_signal("config_applied", _flat_config.duplicate(true))
	return get_flat_config()


func reset_to_defaults() -> Dictionary:
	return apply_flat_config(get_default_flat_config())


func list_preset_names() -> Array:
	_ensure_preset_dir()
	var names: Array[String] = []
	var dir := DirAccess.open(PRESET_DIR)
	if dir == null:
		return []
	dir.list_dir_begin()
	while true:
		var file_name: String = dir.get_next()
		if file_name.is_empty():
			break
		if dir.current_is_dir():
			continue
		if not file_name.ends_with(".json"):
			continue
		names.append(file_name.trim_suffix(".json"))
	dir.list_dir_end()
	names.sort()
	return names


func export_preset(preset_name: String, flat_override: Dictionary = {}) -> Dictionary:
	var normalized_name: String = _normalize_preset_name(preset_name)
	if normalized_name.is_empty():
		return {"ok": false, "error": "invalid_preset_name"}
	_ensure_preset_dir()
	var payload := {
		"name": normalized_name,
		"saved_at_utc": Time.get_datetime_string_from_system(true, true),
		"config": _sanitize_flat_config(flat_override if not flat_override.is_empty() else get_flat_config())
	}
	var file := FileAccess.open("%s/%s.json" % [PRESET_DIR, normalized_name], FileAccess.WRITE)
	if file == null:
		return {"ok": false, "error": "open_failed"}
	file.store_string(JSON.stringify(payload, "\t"))
	return {"ok": true, "name": normalized_name}


func import_preset(preset_name: String) -> Dictionary:
	var normalized_name: String = _normalize_preset_name(preset_name)
	if normalized_name.is_empty():
		return {"ok": false, "error": "invalid_preset_name"}
	var path := "%s/%s.json" % [PRESET_DIR, normalized_name]
	if not FileAccess.file_exists(path):
		return {"ok": false, "error": "missing_preset"}
	var raw_text := FileAccess.get_file_as_string(path)
	if raw_text.is_empty():
		return {"ok": false, "error": "empty_preset"}
	var parsed: Variant = JSON.parse_string(raw_text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return {"ok": false, "error": "invalid_json"}
	var payload: Dictionary = parsed
	var config: Dictionary = payload.get("config", {})
	apply_flat_config(config)
	return {"ok": true, "name": normalized_name, "config": get_flat_config()}


func estimate_flat_impact(candidate_flat: Dictionary = {}) -> Dictionary:
	var base_flat: Dictionary = get_default_flat_config()
	var merged_flat: Dictionary = get_flat_config()
	for key: Variant in candidate_flat.keys():
		merged_flat[String(key)] = candidate_flat[key]
	merged_flat = _sanitize_flat_config(merged_flat)
	var base_metrics: Dictionary = _compute_metrics(base_flat)
	var merged_metrics: Dictionary = _compute_metrics(merged_flat)
	var difficulty_ratio: float = float(merged_metrics.get("difficulty_index", 1.0)) / max(0.001, float(base_metrics.get("difficulty_index", 1.0)))
	var cards := [
		_build_delta_card("我方输出", merged_metrics, base_metrics, "offense_index"),
		_build_delta_card("生存韧性", merged_metrics, base_metrics, "survival_index"),
		_build_delta_card("技能循环", merged_metrics, base_metrics, "tempo_index"),
		_build_delta_card("局内压力", merged_metrics, base_metrics, "run_pressure_index")
	]
	return {
		"difficulty_ratio": difficulty_ratio,
		"difficulty_summary": _difficulty_summary_text(difficulty_ratio),
		"cards": cards,
		"warnings": _build_warnings(merged_flat, merged_metrics, difficulty_ratio),
		"metrics": merged_metrics
	}


func _sanitize_flat_config(source: Dictionary) -> Dictionary:
	var sanitized: Dictionary = {}
	var defaults: Dictionary = get_default_flat_config()
	for section_value in _all_sections():
		var section: Dictionary = section_value
		for entry_value in section.get("entries", []):
			var entry: Dictionary = entry_value
			var path: String = String(entry.get("path", ""))
			var min_value: float = float(entry.get("min", 0.0))
			var max_value: float = float(entry.get("max", 0.0))
			var step_value: float = float(entry.get("step", 0.1))
			var raw_value: float = float(source.get(path, defaults.get(path)))
			var snapped: float = snappedf(clampf(raw_value, min_value, max_value), step_value)
			if _entry_is_integer(entry):
				sanitized[path] = int(round(snapped))
			else:
				sanitized[path] = snapped
	return sanitized


func _entry_is_integer(entry: Dictionary) -> bool:
	var step_value: float = float(entry.get("step", 0.1))
	return step_value >= 1.0 and is_equal_approx(fmod(step_value, 1.0), 0.0)


func _compute_metrics(flat: Dictionary) -> Dictionary:
	var offense_index: float = (
		float(flat.get("battle.hero_base_power_multiplier", 2.1))
		* (
			float(flat.get("skills.primary_damage_multiplier", 1.15))
			+ (
				float(flat.get("skills.burst_damage_multiplier", 0.72))
				* 0.9
				* (
					float(flat.get("battle.hero_resolve_max", 4))
					/ max(1.0, float(flat.get("skills.burst_cost", 2)))
				)
			)
		)
		* (1.0 + (float(flat.get("battle.relic_bonus_per_relic", 0.12)) * 1.5))
	)
	var survival_index: float = (
		(1.0 / max(0.05, float(flat.get("skills.guard_damage_factor", 0.22))))
		* (1.0 + (float(flat.get("items.field_balm_recover_hp", 16.0)) / 36.0))
		* (1.0 + (float(flat.get("battle.resolve_gain_on_guard", 1)) * 0.18))
	)
	var tempo_index: float = (
		float(flat.get("battle.initial_hero_resolve", 3)) * 0.24
		+ float(flat.get("battle.hero_resolve_max", 4)) * 0.26
		+ float(flat.get("battle.resolve_gain_on_wait", 1)) * 0.34
		+ float(flat.get("battle.resolve_gain_on_enemy_phase", 1)) * 0.42
	)
	var enemy_pressure_index: float = (
		float(flat.get("battle.enemy_phase_attacker_limit", 2))
		* (
			float(flat.get("battle.enemy_damage_floor", 0.8)) * 1.35
			+ (7.5 / max(1.0, float(flat.get("battle.enemy_damage_divisor", 7.5))))
		)
	)
	var run_pressure_index: float = (
		float(flat.get("board.random_event_density_multiplier", 1.0))
		* (1.0 + float(flat.get("board.danger_gain_per_turn", 1)) * 0.35)
		* (1.0 + float(flat.get("board.forced_event_chance_multiplier", 1.0)) * 0.18)
		* (1.0 + max(0.0, 4.0 - float(flat.get("board.forced_event_unlock_turn", 4))) * 0.12)
	)
	var difficulty_index: float = (
		(enemy_pressure_index * run_pressure_index)
		/ max(0.25, (offense_index * 0.62 + survival_index * 0.38) * (1.0 + tempo_index * 0.12))
	)
	return {
		"offense_index": offense_index,
		"survival_index": survival_index,
		"tempo_index": tempo_index,
		"enemy_pressure_index": enemy_pressure_index,
		"run_pressure_index": run_pressure_index,
		"difficulty_index": difficulty_index
	}


func _build_delta_card(label: String, current_metrics: Dictionary, base_metrics: Dictionary, metric_key: String) -> Dictionary:
	var current_value: float = float(current_metrics.get(metric_key, 1.0))
	var base_value: float = max(0.001, float(base_metrics.get(metric_key, 1.0)))
	var delta_ratio: float = (current_value / base_value) - 1.0
	return {
		"label": label,
		"delta_ratio": delta_ratio,
		"summary": _delta_summary_text(delta_ratio, label)
	}


func _difficulty_summary_text(difficulty_ratio: float) -> String:
	if difficulty_ratio <= 0.78:
		return "整体将明显变简单，玩家端容错与战斗胜率都会上升。"
	if difficulty_ratio <= 0.94:
		return "整体会略微偏向玩家，流程会更顺滑。"
	if difficulty_ratio < 1.08:
		return "整体仍接近当前基准，属于小幅微调。"
	if difficulty_ratio < 1.24:
		return "整体会略微变难，需要更谨慎地规划技能与道具。"
	return "整体将明显变难，当前最小原型可能重新出现高压卡关。"


func _delta_summary_text(delta_ratio: float, label: String) -> String:
	var percent: int = int(round(abs(delta_ratio) * 100.0))
	if percent == 0:
		return "%s 基本不变。" % label
	if delta_ratio > 0.0:
		return "%s 约提升 %d%%。" % [label, percent]
	return "%s 约下降 %d%%。" % [label, percent]


func _build_warnings(flat: Dictionary, metrics: Dictionary, difficulty_ratio: float) -> Array[String]:
	var warnings: Array[String] = []
	if difficulty_ratio >= 1.3:
		warnings.append("当前组合会显著抬高整体难度，最小可玩闭环可能重新接近“首战必败”。")
	elif difficulty_ratio <= 0.7:
		warnings.append("当前组合会显著降低整体难度，主线推进的压迫感可能被削弱。")
	if float(flat.get("skills.burst_damage_multiplier", 0.72)) >= float(flat.get("skills.primary_damage_multiplier", 1.15)) * 0.9 and int(flat.get("skills.burst_cost", 2)) <= 1:
		warnings.append("群攻横扫已经接近或超过单体斩击的效率，单体战术位会被挤压。")
	if int(flat.get("battle.enemy_phase_attacker_limit", 2)) >= 3 and float(flat.get("skills.guard_damage_factor", 0.22)) > 0.32:
		warnings.append("敌方单轮出手数较多，但架盾减伤偏弱，多敌战可能重新失控。")
	if float(flat.get("board.random_event_density_multiplier", 1.0)) > 1.35 and int(flat.get("board.danger_gain_per_turn", 1)) >= 2:
		warnings.append("地图事件密度与危险增长叠加偏高，中段节奏可能过于拥挤。")
	if float(flat.get("items.field_balm_recover_hp", 16.0)) >= 24.0 and float(metrics.get("survival_index", 1.0)) > 1.4:
		warnings.append("恢复道具已非常强，会抬高续航并削弱失败惩罚。")
	return warnings


func _all_sections() -> Array:
	var sections: Array = []
	for section_value in EDITOR_SECTIONS:
		sections.append(section_value)
	sections.append_array(_build_dynamic_sections())
	return sections


func _build_dynamic_sections() -> Array:
	var content := _content_db()
	if content == null:
		return []
	var sections: Array = []
	sections.append(_build_maps_section(content))
	sections.append(_build_units_section(content))
	sections.append(_build_items_section(content))
	sections.append(_build_battles_section(content))
	sections.append(_build_events_section(content))
	sections.append(_build_loot_tables_section(content))
	return sections


func _build_maps_section(content: Node) -> Dictionary:
	var entries: Array = []
	for map_value in content.list_maps():
		if typeof(map_value) != TYPE_DICTIONARY:
			continue
		var map_def: Dictionary = map_value
		var map_id: String = String(map_def.get("id", ""))
		var range_values: Array = map_def.get("random_slot_count_range", [])
		if range_values.size() >= 2:
			entries.append({"path": "maps.%s.random_slot_min" % map_id, "label": "%s 随机位下限" % String(map_def.get("name_cn", map_id)), "description": "该地图单回合最少生成多少随机事件。", "default": int(range_values[0]), "min": 1, "max": 8, "step": 1})
			entries.append({"path": "maps.%s.random_slot_max" % map_id, "label": "%s 随机位上限" % String(map_def.get("name_cn", map_id)), "description": "该地图单回合最多生成多少随机事件。", "default": int(range_values[1]), "min": 1, "max": 10, "step": 1})
	return {"id": "maps_content", "name_cn": "地图内容", "description": "按地图微调随机事件板的容量。", "entries": entries}


func _build_units_section(content: Node) -> Dictionary:
	var entries: Array = []
	for unit_value in content.data.get("units", []):
		if typeof(unit_value) != TYPE_DICTIONARY:
			continue
		var unit_def: Dictionary = unit_value
		var unit_id: String = String(unit_def.get("id", ""))
		var unit_name := _preferred_name(String(unit_def.get("name_cn", "")), unit_id, String(unit_def.get("camp", "enemy")))
		entries.append({"path": "units.%s.hp" % unit_id, "label": "%s 生命" % unit_name, "description": "单位基础生命值。", "default": int(unit_def.get("hp", 0)), "min": 1, "max": 120, "step": 1})
		var attack: Dictionary = unit_def.get("attack", {})
		entries.append({"path": "units.%s.attack_power" % unit_id, "label": "%s 攻击力" % unit_name, "description": "单位攻击面板中的威力值。", "default": float(attack.get("power", 0.0)), "min": 0.2, "max": 20.0, "step": 0.1})
		entries.append({"path": "units.%s.attack_speed" % unit_id, "label": "%s 攻速" % unit_name, "description": "单位攻击面板中的速度值。", "default": float(attack.get("speed", 1.0)), "min": 0.2, "max": 3.0, "step": 0.05})
	return {"id": "units_content", "name_cn": "英雄与敌人", "description": "直接调整英雄与各类敌人的基础数值。", "entries": entries}


func _build_items_section(content: Node) -> Dictionary:
	var entries: Array = []
	for item_value in content.data.get("items", []):
		if typeof(item_value) != TYPE_DICTIONARY:
			continue
		var item_def: Dictionary = item_value
		var combat_effect: Dictionary = item_def.get("combat_effect", {})
		if combat_effect.is_empty():
			continue
		var item_id: String = String(item_def.get("id", ""))
		var item_name := _preferred_name(String(item_def.get("name_cn", "")), item_id, "item")
		entries.append({"path": "items.%s.combat_effect_value" % item_id, "label": "%s 战斗效果" % item_name, "description": "该道具在战斗中的数值效果。", "default": float(combat_effect.get("value", 0.0)), "min": 0.0, "max": 60.0, "step": 0.5})
	return {"id": "items_content", "name_cn": "道具内容", "description": "调整具体道具的战斗效果值。", "entries": entries}


func _build_battles_section(content: Node) -> Dictionary:
	var entries: Array = []
	for battle_value in content.data.get("battles", []):
		if typeof(battle_value) != TYPE_DICTIONARY:
			continue
		var battle_def: Dictionary = battle_value
		var battle_id: String = String(battle_def.get("id", ""))
		for group_index: int in battle_def.get("enemy_groups", []).size():
			var group: Dictionary = battle_def.get("enemy_groups", [])[group_index]
			var unit_name := String(content.by_id.get("units", {}).get(String(group.get("unit_id", "")), {}).get("name_cn", group.get("unit_id", "")))
			entries.append({"path": "battles.%s.group.%d.count" % [battle_id, group_index], "label": "%s #%d 固定数量" % [battle_id, group_index + 1], "description": "编组 %s 的基础数量。" % unit_name, "default": int(group.get("count", 0)), "min": 0, "max": 12, "step": 1})
			var count_range: Array = group.get("count_range", [])
			if count_range.size() >= 2:
				entries.append({"path": "battles.%s.group.%d.min" % [battle_id, group_index], "label": "%s #%d 最小随机数" % [battle_id, group_index + 1], "description": "编组 %s 的随机下限。" % unit_name, "default": int(count_range[0]), "min": 0, "max": 12, "step": 1})
				entries.append({"path": "battles.%s.group.%d.max" % [battle_id, group_index], "label": "%s #%d 最大随机数" % [battle_id, group_index + 1], "description": "编组 %s 的随机上限。" % unit_name, "default": int(count_range[1]), "min": 0, "max": 16, "step": 1})
	return {"id": "battles_content", "name_cn": "战斗编组", "description": "按 battle 调整敌方编组数量与波动区间。", "entries": entries}


func _build_events_section(content: Node) -> Dictionary:
	var entries: Array = []
	for event_value in content.data.get("events", []):
		if typeof(event_value) != TYPE_DICTIONARY:
			continue
		var event_def: Dictionary = event_value
		var event_id: String = String(event_def.get("id", ""))
		var event_title: String = String(event_def.get("title", event_id))
		if event_def.has("weight"):
			entries.append({"path": "events.%s.weight" % event_id, "label": "%s 权重" % event_title, "description": "该事件在候选池中的出现权重。", "default": int(event_def.get("weight", 0)), "min": 0, "max": 200, "step": 1})
		entries.append_array(_build_reward_entries_for_prefix(event_id, event_title, event_def.get("reward_package", {})))
		for option_index: int in event_def.get("option_list", []).size():
			var option_def: Dictionary = event_def.get("option_list", [])[option_index]
			var option_title := "%s / 选项%d" % [event_title, option_index + 1]
			entries.append_array(_build_reward_entries_for_prefix("%s.option.%d" % [event_id, option_index], option_title, option_def.get("reward_package", {})))
	return {"id": "events_content", "name_cn": "事件奖励", "description": "调整事件权重与显式奖励包。", "entries": entries}


func _build_reward_entries_for_prefix(prefix: String, label_prefix: String, reward: Dictionary) -> Array:
	var entries: Array = []
	for stack_group in ["currencies", "items", "relics"]:
		for index: int in reward.get(stack_group, []).size():
			var stack: Dictionary = reward.get(stack_group, [])[index]
			entries.append({"path": "events.%s.%s.%d.count" % [prefix, stack_group, index], "label": "%s / %s #%d" % [label_prefix, _reward_group_name(stack_group), index + 1], "description": "显式奖励 %s 的数量。" % String(stack.get("id", "")), "default": int(stack.get("count", 0)), "min": 0, "max": 999, "step": 1})
	for index: int in reward.get("loot_tables", []).size():
		var loot_ref: Dictionary = reward.get("loot_tables", [])[index]
		entries.append({"path": "events.%s.loot_tables.%d.rolls" % [prefix, index], "label": "%s / 掉落表 #%d 抽取次数" % [label_prefix, index + 1], "description": "该奖励掉落表执行的 roll 次数。", "default": int(loot_ref.get("rolls", 1)), "min": 0, "max": 10, "step": 1})
	return entries


func _build_loot_tables_section(content: Node) -> Dictionary:
	var entries: Array = []
	for table_value in content.data.get("loot_tables", []):
		if typeof(table_value) != TYPE_DICTIONARY:
			continue
		var loot_table: Dictionary = table_value
		var table_id: String = String(loot_table.get("id", ""))
		var table_name: String = String(loot_table.get("name_cn", table_id))
		for entry_index: int in loot_table.get("entries", []).size():
			var loot_entry: Dictionary = loot_table.get("entries", [])[entry_index]
			var item_name := String(content.by_id.get("items", {}).get(String(loot_entry.get("id", "")), {}).get("name_cn", loot_entry.get("id", "")))
			entries.append({"path": "loot_tables.%s.entry.%d.count" % [table_id, entry_index], "label": "%s / %s 数量" % [table_name, item_name], "description": "该掉落条目命中后给出的数量。", "default": int(loot_entry.get("count", 0)), "min": 0, "max": 999, "step": 1})
			entries.append({"path": "loot_tables.%s.entry.%d.weight" % [table_id, entry_index], "label": "%s / %s 权重" % [table_name, item_name], "description": "该条目参与抽取时的相对权重。", "default": int(loot_entry.get("weight", 0)), "min": 0, "max": 100, "step": 1})
			entries.append({"path": "loot_tables.%s.entry.%d.prob" % [table_id, entry_index], "label": "%s / %s 概率" % [table_name, item_name], "description": "该条目进入权重池前的独立概率。", "default": float(loot_entry.get("prob", 1.0)), "min": 0.0, "max": 1.0, "step": 0.05})
	return {"id": "loot_tables_content", "name_cn": "掉落表", "description": "调整掉落表中的数量、权重与独立概率。", "entries": entries}


func _reward_group_name(stack_group: String) -> String:
	match stack_group:
		"currencies":
			return "货币"
		"items":
			return "物资"
		"relics":
			return "圣遗"
	return stack_group


func _content_db() -> Node:
	var main_loop: MainLoop = Engine.get_main_loop()
	if main_loop is SceneTree:
		return (main_loop as SceneTree).root.get_node_or_null("ContentDB")
	return null


func _progression_state() -> Node:
	var main_loop: MainLoop = Engine.get_main_loop()
	if main_loop is SceneTree:
		return (main_loop as SceneTree).root.get_node_or_null("ProgressionState")
	return null


func _build_item_definition(payload: Dictionary, item_id: String) -> Dictionary:
	var type_id: int = int(payload.get("type", 2))
	var display_name := _preferred_name(String(payload.get("name_cn", "")).strip_edges(), item_id, "item")
	var item_def := {
		"id": item_id,
		"name_cn": display_name,
		"type": type_id,
		"quality": clampi(int(payload.get("quality", 1)), 0, 5),
		"description": String(payload.get("description", "运行时新增道具。")).strip_edges(),
		"tags": _normalize_tags(payload.get("tags", []))
	}
	if item_def["description"].is_empty():
		item_def["description"] = "运行时新增道具。"
	var effect_kind: String = String(payload.get("combat_effect_kind", "")).strip_edges()
	var effect_value: float = max(0.0, float(payload.get("combat_effect_value", 0.0)))
	if not effect_kind.is_empty() and effect_value > 0.0:
		item_def["combat_effect"] = {
			"kind": effect_kind,
			"value": effect_value
		}
	return item_def


func _create_unit(payload: Dictionary, camp: String) -> Dictionary:
	var unit_id: String = _normalize_content_id(String(payload.get("id", "")), camp)
	if unit_id.is_empty():
		return {"ok": false, "error": "invalid_id"}
	if _content_id_exists("units", unit_id):
		return {"ok": false, "error": "duplicate_id", "id": unit_id}
	var unit_def := _build_unit_definition(payload, unit_id, camp)
	_created_content["units"].append(unit_def)
	_persist_created_content()
	return {"ok": true, "id": unit_id, "entry": unit_def}


func _upsert_unit(payload: Dictionary, camp: String) -> Dictionary:
	var unit_id: String = _normalize_content_id(String(payload.get("id", "")), camp)
	if unit_id.is_empty():
		return {"ok": false, "error": "invalid_id"}
	var existing_index := _find_created_index("units", unit_id)
	var unit_def := _build_unit_definition(payload, unit_id, camp)
	if existing_index >= 0:
		_created_content["units"][existing_index] = unit_def
	else:
		_created_content["units"].append(unit_def)
	_persist_created_content()
	return {"ok": true, "id": unit_id, "entry": unit_def, "mode": "update" if existing_index >= 0 else "create"}


func _build_unit_definition(payload: Dictionary, unit_id: String, camp: String) -> Dictionary:
	var attack_type: String = String(payload.get("attack_type", "melee")).strip_edges()
	var display_name := _preferred_name(String(payload.get("name_cn", "")).strip_edges(), unit_id, camp)
	var unit_def := {
		"id": unit_id,
		"camp": camp,
		"name_cn": display_name,
		"move_speed": clampi(int(payload.get("move_speed", 9)), 2, 24),
		"move_type": String(payload.get("move_type", "walk")).strip_edges(),
		"size": clampi(int(payload.get("size", 3)), 1, 8),
		"hp": clampi(int(payload.get("hp", 24)), 1, 240),
		"attack": {
			"type": attack_type,
			"power": clampf(float(payload.get("attack_power", 3.0)), 0.2, 30.0),
			"speed": clampf(float(payload.get("attack_speed", 1.0)), 0.2, 4.0),
			"range": clampi(int(payload.get("attack_range", 1)), 1, 16)
		},
		"movement_ai": "chase",
		"combat_ai": "ranged_attack" if attack_type == "ranged_flat" else "melee_attack",
		"tags": _normalize_unit_tags(payload.get("tags", []), camp)
	}
	return unit_def


func _content_id_exists(group_name: String, entry_id: String) -> bool:
	if entry_id.is_empty():
		return true
	for entry_value in _created_content.get(group_name, []):
		if typeof(entry_value) != TYPE_DICTIONARY:
			continue
		if String((entry_value as Dictionary).get("id", "")) == entry_id:
			return true
	var content := _content_db()
	if content == null:
		return false
	var index: Dictionary = content.by_id.get(group_name, {})
	return index.has(entry_id)


func _find_created_index(group_name: String, entry_id: String) -> int:
	for index: int in range(_created_content.get(group_name, []).size()):
		var entry_value: Variant = _created_content[group_name][index]
		if typeof(entry_value) != TYPE_DICTIONARY:
			continue
		if String((entry_value as Dictionary).get("id", "")) == entry_id:
			return index
	return -1


func _delete_created_entry(group_name: String, entry_id: String) -> Dictionary:
	if entry_id.is_empty():
		return {"ok": false, "error": "missing_id"}
	var index := _find_created_index(group_name, entry_id)
	if index < 0:
		return {"ok": false, "error": "missing_entry", "id": entry_id}
	var removed_entry: Dictionary = _created_content[group_name][index]
	_created_content[group_name].remove_at(index)
	_remove_links_for_entry(group_name, entry_id)
	var progression := _progression_state()
	if progression != null:
		if group_name == "units" and String(removed_entry.get("camp", "")) == "hero" and progression.has_method("remove_hero_from_roster"):
			progression.call("remove_hero_from_roster", entry_id)
		elif group_name == "items" and progression.has_method("remove_item_references"):
			progression.call("remove_item_references", entry_id)
	_persist_created_content()
	return {"ok": true, "id": entry_id}


func _remove_links_for_entry(group_name: String, entry_id: String) -> void:
	_ensure_link_container()
	var links: Dictionary = _created_content.get("links", {})
	if group_name == "items":
		links["loot_table_entries"] = _remove_link_entries_by_id(links.get("loot_table_entries", []), "item_id", entry_id)
	elif group_name == "units":
		links["battle_enemy_groups"] = _remove_link_entries_by_id(links.get("battle_enemy_groups", []), "unit_id", entry_id)
	_created_content["links"] = links


func _remove_link_entries_by_id(entries: Array, key: String, entry_id: String) -> Array:
	var filtered: Array = []
	for entry_value in entries:
		if typeof(entry_value) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_value
		if String(entry.get(key, "")) == entry_id:
			continue
		filtered.append(entry.duplicate(true))
	return filtered


func _upsert_link_entry(group_name: String, link_key: String, link_entry: Dictionary) -> String:
	var links: Dictionary = _created_content.get("links", {})
	var entries: Array = links.get(group_name, [])
	for index: int in range(entries.size()):
		var entry_value: Variant = entries[index]
		if typeof(entry_value) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_value
		if String(entry.get("link_key", "")) != link_key:
			continue
		entries[index] = link_entry.duplicate(true)
		links[group_name] = entries
		_created_content["links"] = links
		return "update"
	entries.append(link_entry.duplicate(true))
	links[group_name] = entries
	_created_content["links"] = links
	return "create"


func _persist_created_content() -> void:
	_save_created_content()
	_reload_content_db()
	_sync_created_heroes_into_progression()
	emit_signal("content_library_changed", get_created_content())


func _reload_content_db() -> void:
	var content := _content_db()
	if content != null and content.has_method("reload_all"):
		content.reload_all()


func _sync_created_heroes_into_progression() -> void:
	var progression := _progression_state()
	if progression == null or not progression.has_method("ensure_hero_in_roster"):
		return
	for unit_value in _created_content.get("units", []):
		if typeof(unit_value) != TYPE_DICTIONARY:
			continue
		var unit_def: Dictionary = unit_value
		if String(unit_def.get("camp", "")) == "hero":
			progression.call("ensure_hero_in_roster", String(unit_def.get("id", "")))


func _normalize_tags(raw_tags: Variant) -> Array:
	var tags: Array = []
	if typeof(raw_tags) == TYPE_STRING:
		for part in String(raw_tags).split(","):
			var cleaned: String = part.strip_edges()
			if cleaned.is_empty() or tags.has(cleaned):
				continue
			tags.append(cleaned)
	elif typeof(raw_tags) == TYPE_ARRAY:
		for tag_value in raw_tags:
			var cleaned: String = String(tag_value).strip_edges()
			if cleaned.is_empty() or tags.has(cleaned):
				continue
			tags.append(cleaned)
	return tags


func _normalize_unit_tags(raw_tags: Variant, camp: String) -> Array:
	var tags: Array = _normalize_tags(raw_tags)
	if not tags.has(camp):
		tags.append(camp)
	if camp == "hero" and not tags.has("hero"):
		tags.append("hero")
	elif camp == "enemy" and not tags.has("enemy"):
		tags.append("enemy")
	return tags


func _load_created_content() -> void:
	_created_content = DEFAULT_CREATED_CONTENT.duplicate(true)
	if not FileAccess.file_exists(CONTENT_SAVE_PATH):
		return
	var raw_text := FileAccess.get_file_as_string(CONTENT_SAVE_PATH)
	if raw_text.is_empty():
		return
	var parsed: Variant = JSON.parse_string(raw_text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var payload: Dictionary = parsed
	_created_content = _normalize_created_content(payload)


func _save_created_content() -> void:
	var file := FileAccess.open(CONTENT_SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Failed to save created content: %s" % CONTENT_SAVE_PATH)
		return
	file.store_string(JSON.stringify(_created_content, "\t"))


func _normalize_created_content(payload: Dictionary) -> Dictionary:
	var normalized := DEFAULT_CREATED_CONTENT.duplicate(true)
	for item_value in payload.get("items", []):
		if typeof(item_value) != TYPE_DICTIONARY:
			continue
		var item_def: Dictionary = item_value
		if String(item_def.get("id", "")).is_empty():
			continue
		normalized["items"].append({
			"id": String(item_def.get("id", "")),
			"name_cn": String(item_def.get("name_cn", "")),
			"type": int(item_def.get("type", 2)),
			"quality": int(item_def.get("quality", 1)),
			"description": String(item_def.get("description", "")),
			"tags": _normalize_tags(item_def.get("tags", [])),
			"combat_effect": item_def.get("combat_effect", {}).duplicate(true)
		})
	for unit_value in payload.get("units", []):
		if typeof(unit_value) != TYPE_DICTIONARY:
			continue
		var unit_def: Dictionary = unit_value
		if String(unit_def.get("id", "")).is_empty():
			continue
		normalized["units"].append({
			"id": String(unit_def.get("id", "")),
			"camp": String(unit_def.get("camp", "enemy")),
			"name_cn": String(unit_def.get("name_cn", "")),
			"move_speed": int(unit_def.get("move_speed", 9)),
			"move_type": String(unit_def.get("move_type", "walk")),
			"size": int(unit_def.get("size", 3)),
			"hp": int(unit_def.get("hp", 24)),
			"attack": unit_def.get("attack", {}).duplicate(true),
			"movement_ai": String(unit_def.get("movement_ai", "chase")),
			"combat_ai": String(unit_def.get("combat_ai", "melee_attack")),
			"tags": _normalize_unit_tags(unit_def.get("tags", []), String(unit_def.get("camp", "enemy")))
		})
	var links_payload: Dictionary = payload.get("links", {})
	if typeof(links_payload) == TYPE_DICTIONARY:
		for link_value in links_payload.get("battle_enemy_groups", []):
			if typeof(link_value) != TYPE_DICTIONARY:
				continue
			var link: Dictionary = link_value
			var battle_id: String = String(link.get("battle_id", "")).strip_edges()
			var unit_id: String = String(link.get("unit_id", "")).strip_edges()
			if battle_id.is_empty() or unit_id.is_empty():
				continue
			var count_range: Array = link.get("count_range", []).duplicate(true)
			var min_count: int = max(0, int(count_range[0])) if count_range.size() > 0 else 1
			var max_count: int = max(min_count, int(count_range[1])) if count_range.size() > 1 else min_count
			var count: int = clampi(int(link.get("count", max_count)), min_count, max_count)
			var spawn: Array = link.get("spawn", []).duplicate(true)
			var spawn_x: int = int(spawn[0]) if spawn.size() > 0 else 540
			var spawn_y: int = int(spawn[1]) if spawn.size() > 1 else 220
			normalized["links"]["battle_enemy_groups"].append({
				"link_key": "%s::%s" % [battle_id, unit_id],
				"battle_id": battle_id,
				"unit_id": unit_id,
				"count": count,
				"count_range": [min_count, max_count],
				"spawn": [spawn_x, spawn_y]
			})
		for link_value in links_payload.get("loot_table_entries", []):
			if typeof(link_value) != TYPE_DICTIONARY:
				continue
			var link: Dictionary = link_value
			var loot_table_id: String = String(link.get("loot_table_id", "")).strip_edges()
			var item_id: String = String(link.get("item_id", "")).strip_edges()
			if loot_table_id.is_empty() or item_id.is_empty():
				continue
			normalized["links"]["loot_table_entries"].append({
				"link_key": "%s::%s" % [loot_table_id, item_id],
				"loot_table_id": loot_table_id,
				"item_id": item_id,
				"kind": "item",
				"count": max(0, int(link.get("count", 1))),
				"weight": max(0, int(link.get("weight", 5))),
				"prob": clampf(float(link.get("prob", 1.0)), 0.0, 1.0)
			})
	return normalized


func _ensure_link_container() -> void:
	if typeof(_created_content.get("links", {})) != TYPE_DICTIONARY:
		_created_content["links"] = {"battle_enemy_groups": [], "loot_table_entries": []}
		return
	var links: Dictionary = _created_content.get("links", {})
	if typeof(links.get("battle_enemy_groups", [])) != TYPE_ARRAY:
		links["battle_enemy_groups"] = []
	if typeof(links.get("loot_table_entries", [])) != TYPE_ARRAY:
		links["loot_table_entries"] = []
	_created_content["links"] = links


func _ensure_preset_dir() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(PRESET_DIR))


func _normalize_preset_name(raw_name: String) -> String:
	var trimmed := raw_name.strip_edges()
	if trimmed.is_empty():
		return ""
	var normalized := ""
	for char_code in trimmed.to_utf8_buffer():
		var ch := char(char_code)
		var is_ascii_letter := (char_code >= 65 and char_code <= 90) or (char_code >= 97 and char_code <= 122)
		var is_digit := char_code >= 48 and char_code <= 57
		if is_ascii_letter or is_digit or ch == "_" or ch == "-":
			normalized += ch
		elif ch == " ":
			normalized += "_"
	return normalized.strip_edges()


func _normalize_content_id(raw_id: String, prefix: String) -> String:
	var normalized: String = _normalize_preset_name(raw_id).to_lower()
	if normalized.is_empty():
		normalized = "%s_custom_%d" % [prefix, Time.get_ticks_msec()]
	return normalized


func _preferred_name(name_cn: String, entry_id: String, category: String) -> String:
	var trimmed_name := name_cn.strip_edges()
	if not trimmed_name.is_empty() and trimmed_name != entry_id:
		return trimmed_name
	if entry_id.contains("_custom_"):
		var suffix := entry_id.get_slice("_custom_", 1)
		match category:
			"item":
				return "自定义道具 %s" % suffix
			"hero":
				return "自定义英雄 %s" % suffix
			"enemy":
				return "自定义敌人 %s" % suffix
	return entry_id if not trimmed_name.is_empty() else entry_id
