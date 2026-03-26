extends SceneTree

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_setup_singletons()
	var scene: PackedScene = load("res://scenes/bootstrap.tscn")
	if scene == null:
		_fail("无法加载 bootstrap 场景")
		_finish()
		return

	var instance: Node = scene.instantiate()
	get_root().add_child(instance)
	await process_frame
	await process_frame

	if instance.get_script() == null:
		_fail("Bootstrap 场景脚本未成功挂载")
	elif not instance.has_method("_refresh_all"):
		_fail("Bootstrap 场景脚本缺少预期方法 _refresh_all")

	if instance.get_node_or_null("Margin/MainRow/MapPanel") == null:
		_fail("缺少 MapPanel")
	if instance.get_node_or_null("Margin/MainRow/DispatchPanel") == null:
		_fail("缺少 DispatchPanel")
	if instance.get_node_or_null("Margin/MainRow/MapPanel/MapScroll/MapPadding/MapVBox/MapFrame/MapFrameMargin/MapSurface") == null:
		_fail("缺少 MapSurface")

	_finish()


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


func _fail(message: String) -> void:
	_failures.append(message)
	printerr("ASSERT FAILED: %s" % message)


func _finish() -> void:
	if _failures.is_empty():
		print("SMOKE TEST PASS: bootstrap scene loads and map layout nodes exist.")
		quit(0)
		return
	printerr("SMOKE TEST FAIL (%d):" % _failures.size())
	for msg: String in _failures:
		printerr("- %s" % msg)
	quit(1)
