extends RefCounted

const BATTLE_DIRECTOR := preload("res://systems/battle/battle_director.gd")

var _battle_director: RefCounted


func execute_battle(request: Dictionary, context: Dictionary = {}) -> Dictionary:
	var director_result: Dictionary = _director().run_battle(request, context)
	return _normalize_result(director_result)


func _director() -> RefCounted:
	if _battle_director == null:
		_battle_director = BATTLE_DIRECTOR.new()
	return _battle_director


func _normalize_result(source: Dictionary) -> Dictionary:
	return {
		"status": String(source.get("status", "invalid_request")),
		"victory": bool(source.get("victory", false)),
		"defeat_reason": String(source.get("defeat_reason", "")),
		"casualties": source.get("casualties", []).duplicate(true),
		"reward_package": source.get("reward_package", {}).duplicate(true),
		"completed_objectives": source.get("completed_objectives", []).duplicate(true),
		"spawned_story_flags": source.get("spawned_story_flags", []).duplicate(true),
		"spawned_unlock_flags": source.get("spawned_unlock_flags", []).duplicate(true),
		"map_effects": source.get("map_effects", {}).duplicate(true)
	}
