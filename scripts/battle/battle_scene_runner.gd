extends Node

signal interactive_battle_finished(result: Dictionary)

@onready var close_preview_button: Button = %ClosePreviewButton


func _ready() -> void:
	if close_preview_button != null:
		close_preview_button.visible = false
		close_preview_button.pressed.connect(_on_close_preview_pressed)
	var controller: Node = get_node_or_null("BattleSceneController")
	if controller != null and controller.has_signal("interactive_battle_finished"):
		var finished_callable := Callable(self, "_on_controller_battle_finished")
		if not controller.is_connected("interactive_battle_finished", finished_callable):
			controller.connect("interactive_battle_finished", finished_callable)


func execute_battle(request: Dictionary, battle_def: Dictionary, context: Dictionary = {}) -> Dictionary:
	var controller: Node = get_node_or_null("BattleSceneController")
	if controller == null or not controller.has_method("execute_battle"):
		return {
			"status": "invalid_request",
			"victory": false,
			"defeat_reason": "missing_scene_controller",
			"casualties": [],
			"reward_package": {},
			"completed_objectives": [],
			"spawned_story_flags": [],
			"spawned_unlock_flags": [],
			"map_effects": {"backend": "scene"}
		}
	return controller.call("execute_battle", request, battle_def, context)


func start_interactive_battle(request: Dictionary, battle_def: Dictionary, context: Dictionary = {}) -> void:
	var controller: Node = get_node_or_null("BattleSceneController")
	if controller == null or not controller.has_method("start_interactive_battle"):
		_on_controller_battle_finished(
			{
				"status": "invalid_request",
				"victory": false,
				"defeat_reason": "missing_scene_controller",
				"casualties": [],
				"reward_package": {},
				"completed_objectives": [],
				"spawned_story_flags": [],
				"spawned_unlock_flags": [],
				"map_effects": {"backend": "scene", "interactive_mode": true}
			}
		)
		return
	controller.call("start_interactive_battle", request, battle_def, context)


func set_preview_mode(enabled: bool) -> void:
	if close_preview_button != null:
		close_preview_button.visible = enabled


func _on_close_preview_pressed() -> void:
	queue_free()


func _on_controller_battle_finished(result: Dictionary) -> void:
	emit_signal("interactive_battle_finished", result)
	queue_free()
