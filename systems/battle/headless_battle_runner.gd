extends RefCounted

const BATTLE_SIMULATOR := preload("res://systems/battle/battle_simulator.gd")

var _simulator: RefCounted

func run(request: Dictionary, battle_def: Dictionary, context: Dictionary = {}) -> Dictionary:
	var content_db: Node = _content_db()
	if content_db == null:
		return _invalid_result("missing_content_db")
	var state: Dictionary = _sim().initialize_state(request, battle_def, content_db)
	if state.has("invalid_reason"):
		return _invalid_result(String(state.get("invalid_reason", "invalid_request")))

	while _sim().is_battle_active(state):
		state = _sim().step_once(state)

	return _sim().build_result(state, context, "headless")


func _invalid_result(reason: String) -> Dictionary:
	return {
		"status": "invalid_request",
		"victory": false,
		"defeat_reason": reason,
		"casualties": [],
		"completed_objectives": [],
		"spawned_story_flags": [],
		"spawned_unlock_flags": [],
		"map_effects": {}
	}


func _content_db() -> Node:
	var loop: MainLoop = Engine.get_main_loop()
	if loop is SceneTree:
		var tree := loop as SceneTree
		return tree.get_root().get_node_or_null("ContentDB")
	return null


func _sim() -> RefCounted:
	if _simulator == null:
		_simulator = BATTLE_SIMULATOR.new()
	return _simulator
