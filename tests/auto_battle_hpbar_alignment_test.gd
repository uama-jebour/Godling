extends SceneTree

const MAX_HP_BAR_TO_PORTRAIT_GAP := 6.0
const MAX_NAME_TO_PORTRAIT_GAP := 6.0

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run_suite")


func _run_suite() -> void:
	_setup_content_db()
	await _test_auto_scene_hpbar_alignment()
	_print_result_and_exit()


func _setup_content_db() -> void:
	var content_db: Node = load("res://autoload/content_db.gd").new()
	content_db.name = "ContentDB"
	get_root().add_child(content_db)


func _test_auto_scene_hpbar_alignment() -> void:
	var scene: PackedScene = load("res://scenes/battle/battle_runner.tscn")
	if scene == null:
		_assert_true(false, "无法加载 battle_runner 场景")
		return
	var instance: Node = scene.instantiate()
	get_root().add_child(instance)

	var content_db: Node = get_root().get_node_or_null("ContentDB")
	var battle_def: Dictionary = content_db.get_battle("battle_auto_a01_probe")
	_assert_true(not battle_def.is_empty(), "应存在 auto battle 样例定义")
	if battle_def.is_empty():
		return

	instance.call(
		"start_interactive_battle",
		{
			"battle_id": "battle_auto_a01_probe",
			"event_instance_id": "auto_scene_hpbar_alignment",
			"map_id": "map_world_a_02_ashen_sanctum",
			"hero_snapshot": {
				"hero_id": "hero_pilgrim_a01",
				"runtime_stats": {
					"hp": 48.0,
					"attack_power": 5.0
				}
			},
			"equipped_strategy_ids": ["strategy_support_drone"],
			"battle_seed": 202
		},
		battle_def,
		{
			"battle_backend": "auto_scene",
			"interactive_mode": false,
			"preview_speed": 0.5
		}
	)

	var arena: Control = instance.find_child("BattleArena", true, false)
	_assert_true(arena != null, "应能获取 BattleArena")
	if arena == null:
		return

	var token_count := 0
	for _i in 40:
		await process_frame
		token_count = _token_nodes(arena).size()
		if token_count > 0:
			break
	_assert_true(token_count > 0, "自动观战应渲染至少一个单位 token")
	if token_count <= 0:
		return

	for token: Control in _token_nodes(arena):
		var portrait := token.get_node("Portrait") as Control
		var hp_bar := token.get_node("HPBar") as Control
		var name_label := token.get_node("NameLabel") as Control
		var shadow := token.get_node("Shadow") as CanvasItem
		var portrait_rect: Rect2 = portrait.get_global_rect()
		var hp_rect: Rect2 = hp_bar.get_global_rect()
		var name_rect: Rect2 = name_label.get_global_rect()
		var entity_id: String = String(token.get("_entity_id"))
		var hp_gap: float = portrait_rect.position.y - hp_rect.end.y
		var name_gap: float = name_rect.position.y - portrait_rect.end.y
		_assert_true(
			hp_rect.end.y <= portrait_rect.position.y,
			"%s 的血条应在主体上方（hp_bottom=%.2f, portrait_top=%.2f）" % [
				entity_id,
				hp_rect.end.y,
				portrait_rect.position.y
			]
		)
		_assert_true(
			hp_gap >= 0.0 and hp_gap <= MAX_HP_BAR_TO_PORTRAIT_GAP,
			"%s 的血条与主体上边缘距离异常：%.2fpx（阈值 %.2fpx）" % [entity_id, hp_gap, MAX_HP_BAR_TO_PORTRAIT_GAP]
		)
		_assert_true(
			name_rect.position.y >= portrait_rect.end.y,
			"%s 的名称应在主体下方（name_top=%.2f, portrait_bottom=%.2f）" % [
				entity_id,
				name_rect.position.y,
				portrait_rect.end.y
			]
		)
		_assert_true(
			name_gap >= 0.0 and name_gap <= MAX_NAME_TO_PORTRAIT_GAP,
			"%s 的名称与主体下边缘距离异常：%.2fpx（阈值 %.2fpx）" % [entity_id, name_gap, MAX_NAME_TO_PORTRAIT_GAP]
		)
		_assert_true(
			shadow != null and not shadow.visible,
			"%s 的主体底部阴影应已移除" % entity_id
		)


func _token_nodes(arena: Control) -> Array[Control]:
	var nodes: Array[Control] = []
	for child in arena.get_children():
		if not (child is Control):
			continue
		var token := child as Control
		if token.has_node("Portrait") and token.has_node("HPBar"):
			nodes.append(token)
	return nodes


func _assert_true(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)
	printerr("ASSERT FAILED: %s" % message)


func _print_result_and_exit() -> void:
	if _failures.is_empty():
		print("TEST PASS: auto battle HP bar alignment verified.")
		quit(0)
		return
	printerr("TEST FAIL (%d):" % _failures.size())
	for message: String in _failures:
		printerr("- %s" % message)
	quit(1)
