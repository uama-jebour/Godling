extends RefCounted
class_name InputSetup


static func ensure_defaults() -> void:
	_bind_key_action("run_next_turn", KEY_SPACE)
	_bind_key_action("run_extract", KEY_E)
	_bind_key_action("open_task_panel", KEY_TAB)
	_bind_key_action("open_inventory_panel", KEY_I)
	_bind_key_action("confirm_event", KEY_ENTER)
	_bind_mouse_action("confirm_event", MOUSE_BUTTON_LEFT)


static func _bind_key_action(action_name: String, keycode: Key) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)

	for existing: InputEvent in InputMap.action_get_events(action_name):
		if existing is InputEventKey:
			var existing_key := existing as InputEventKey
			if existing_key.keycode == keycode:
				return

	var event := InputEventKey.new()
	event.keycode = keycode
	InputMap.action_add_event(action_name, event)


static func _bind_mouse_action(action_name: String, button_index: MouseButton) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)

	for existing: InputEvent in InputMap.action_get_events(action_name):
		if existing is InputEventMouseButton:
			var existing_button := existing as InputEventMouseButton
			if existing_button.button_index == button_index:
				return

	var event := InputEventMouseButton.new()
	event.button_index = button_index
	InputMap.action_add_event(action_name, event)

