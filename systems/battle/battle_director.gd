extends RefCounted

const HEADLESS_BATTLE_RUNNER := preload("res://systems/battle/headless_battle_runner.gd")
const AUTO_BATTLE_RUNNER := preload("res://systems/battle/auto_battle_runner.gd")
const BATTLE_RUNNER_SCENE := preload("res://scenes/battle/battle_runner.tscn")

var _battle_runner: RefCounted
var _auto_battle_runner: RefCounted


func run_battle(request: Dictionary, context: Dictionary = {}) -> Dictionary:
	var battle_id: String = String(request.get("battle_id", ""))
	if battle_id.is_empty():
		return _invalid_result("missing_battle_id")

	var content_db: Node = _content_db()
	if content_db == null:
		return _invalid_result("missing_content_db")

	var battle_def: Dictionary = content_db.get_battle(battle_id)
	if battle_def.is_empty():
		return _invalid_result("unknown_battle_id")

	var reward_package: Dictionary = request.get("configured_reward_package", {}).duplicate(true)
	var runner_result: Dictionary = _run_with_backend(request, battle_def, context)
	runner_result["reward_package"] = reward_package
	var map_effects: Dictionary = runner_result.get("map_effects", {}).duplicate(true)
	map_effects["battle_id"] = battle_id
	map_effects["map_id"] = String(request.get("map_id", battle_def.get("map_id", "")))
	map_effects["event_instance_id"] = String(request.get("event_instance_id", ""))
	runner_result["map_effects"] = map_effects
	return runner_result


func _invalid_result(reason: String) -> Dictionary:
	return {
		"status": "invalid_request",
		"victory": false,
		"defeat_reason": reason,
		"casualties": [],
		"reward_package": {},
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


func _runner() -> RefCounted:
	if _battle_runner == null:
		_battle_runner = HEADLESS_BATTLE_RUNNER.new()
	return _battle_runner


func _auto_runner() -> RefCounted:
	if _auto_battle_runner == null:
		_auto_battle_runner = AUTO_BATTLE_RUNNER.new()
	return _auto_battle_runner


func _run_with_backend(request: Dictionary, battle_def: Dictionary, context: Dictionary) -> Dictionary:
	var backend: String = _resolved_backend(battle_def, context)
	if backend == "auto_headless":
		return _auto_runner().run(request, battle_def, context)
	if backend == "auto_scene":
		return _auto_runner().step_preview(request, battle_def, context)
	if backend == "scene":
		var scene_result: Dictionary = _run_scene_backend(request, battle_def, context)
		if not scene_result.is_empty():
			return scene_result
	return _runner().run(request, battle_def, context)


func _run_scene_backend(request: Dictionary, battle_def: Dictionary, context: Dictionary) -> Dictionary:
	var loop: MainLoop = Engine.get_main_loop()
	if not (loop is SceneTree):
		return {}
	var tree := loop as SceneTree
	var instance: Node = BATTLE_RUNNER_SCENE.instantiate()
	if instance == null:
		return {}
	tree.get_root().add_child(instance)
	var result: Dictionary = {}
	if instance.has_method("execute_battle"):
		result = instance.call("execute_battle", request, battle_def, context)
	instance.queue_free()
	return result


func _resolved_backend(battle_def: Dictionary, context: Dictionary) -> String:
	var explicit_backend: String = String(context.get("battle_backend", ""))
	if not explicit_backend.is_empty():
		return explicit_backend
	if String(battle_def.get("battle_mode", "legacy_interactive")) == "auto_units":
		return "auto_headless"
	return "headless"
