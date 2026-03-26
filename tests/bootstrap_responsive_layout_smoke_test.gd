extends SceneTree

const SCENE_PATH := "res://scenes/bootstrap.tscn"
const MAP_PANEL_PATH := "Margin/MainRow/MapPanel/MapScroll/MapPadding/MapVBox/MapFrame/MapFrameMargin/MapSurface"
const BOTTOM_ROW_PATH := "Margin/MainRow/MapPanel/MapScroll/MapPadding/MapVBox/BottomRow"
const ACTION_ROW_PATH := "Margin/MainRow/DispatchPanel/DispatchScroll/DispatchPadding/DispatchVBox/ActionRow"

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_setup_singletons()
	var scene: PackedScene = load(SCENE_PATH)
	if scene == null:
		_fail("无法加载 bootstrap 场景")
		_finish()
		return

	var bootstrap: Control = scene.instantiate()
	get_root().add_child(bootstrap)
	await process_frame
	await process_frame

	if bootstrap.get_script() == null:
		_fail("Bootstrap 响应式测试时脚本未挂载")
		_finish()
		return
	if not bootstrap.has_method("_apply_responsive_layout"):
		_fail("Bootstrap 响应式测试缺少 _apply_responsive_layout")
		_finish()
		return

	_test_case(bootstrap, Vector2i(1920, 1080), false, 432)
	_test_case(bootstrap, Vector2i(1600, 900), false, 432)
	_test_case(bootstrap, Vector2i(1500, 1200), true, 320)
	_test_case(bootstrap, Vector2i(1366, 768), true, 320)

	_finish()


func _test_case(bootstrap: Control, window_size: Vector2i, expected_compact: bool, expected_map_min_height: int) -> void:
	var window: Window = get_root().get_window()
	window.mode = Window.MODE_WINDOWED
	window.size = window_size
	await process_frame
	await process_frame

	bootstrap.call("_apply_responsive_layout")
	await process_frame

	var main_row: BoxContainer = bootstrap.get_node_or_null("Margin/MainRow")
	var bottom_row: BoxContainer = bootstrap.get_node_or_null(BOTTOM_ROW_PATH)
	var action_row: BoxContainer = bootstrap.get_node_or_null(ACTION_ROW_PATH)
	var map_surface: Control = bootstrap.get_node_or_null(MAP_PANEL_PATH)

	if main_row == null or bottom_row == null or action_row == null or map_surface == null:
		_fail("关键节点缺失，无法执行尺寸断言")
		return

	_assert_true(
		main_row.vertical == expected_compact,
		"%s 下 MainRow.vertical 预期=%s 实际=%s" % [str(window_size), str(expected_compact), str(main_row.vertical)]
	)
	_assert_true(
		bottom_row.vertical == expected_compact,
		"%s 下 BottomRow.vertical 预期=%s 实际=%s" % [str(window_size), str(expected_compact), str(bottom_row.vertical)]
	)
	_assert_true(
		action_row.vertical == expected_compact,
		"%s 下 ActionRow.vertical 预期=%s 实际=%s" % [str(window_size), str(expected_compact), str(action_row.vertical)]
	)
	_assert_true(
		int(map_surface.custom_minimum_size.y) == expected_map_min_height,
		"%s 下 MapSurface 最小高度预期=%d 实际=%d" % [
			str(window_size),
			expected_map_min_height,
			int(map_surface.custom_minimum_size.y)
		]
	)


func _setup_singletons() -> void:
	var content_db: Node = load("res://autoload/content_db.gd").new()
	content_db.name = "ContentDB"
	get_root().add_child(content_db)

	var progression: Node = load("res://autoload/progression_state.gd").new()
	progression.name = "ProgressionState"
	get_root().add_child(progression)

	var run_state: Node = load("res://autoload/run_state.gd").new()
	run_state.name = "RunState"
	get_root().add_child(run_state)


func _assert_true(condition: bool, message: String) -> void:
	if condition:
		return
	_fail(message)


func _fail(message: String) -> void:
	_failures.append(message)
	printerr("ASSERT FAILED: %s" % message)


func _finish() -> void:
	if _failures.is_empty():
		print("SMOKE TEST PASS: bootstrap responsive layout verified across target resolutions.")
		quit(0)
		return

	printerr("SMOKE TEST FAIL (%d):" % _failures.size())
	for msg: String in _failures:
		printerr("- %s" % msg)
	quit(1)
