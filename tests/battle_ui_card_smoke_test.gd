extends SceneTree

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_setup_singletons()
	await _test_battle_ui_cards()
	_finish()


func _setup_singletons() -> void:
	var content_db: Node = load("res://autoload/content_db.gd").new()
	content_db.name = "ContentDB"
	get_root().add_child(content_db)


func _test_battle_ui_cards() -> void:
	var scene: PackedScene = load("res://scenes/battle/battle_runner.tscn")
	_assert_true(scene != null, "无法加载 battle_runner 场景")
	if scene == null:
		return

	var instance: Node = scene.instantiate()
	get_root().add_child(instance)
	await process_frame
	await process_frame

	var controller: Node = instance.get_node_or_null("BattleSceneController")
	_assert_true(controller != null, "缺少 BattleSceneController")
	if controller == null:
		instance.queue_free()
		await process_frame
		return

	var attack_card := instance.find_child("AttackSkillCard", true, false) as Control
	var item_card_a := instance.find_child("ItemCardA", true, false) as Control
	var item_card_b := instance.find_child("ItemCardB", true, false) as Control
	_assert_true(attack_card != null and item_card_a != null and item_card_b != null, "技能卡与主道具卡节点必须存在")
	if attack_card != null and item_card_a != null and item_card_b != null:
		_assert_true(
			_vec2_equal(attack_card.custom_minimum_size, item_card_a.custom_minimum_size)
			and _vec2_equal(item_card_a.custom_minimum_size, item_card_b.custom_minimum_size),
			"技能卡与主区道具卡 custom_minimum_size 应完全一致"
		)

	var fake_items: Array = [
		{
			"id": "item_a",
			"name_cn": "测试药剂 A",
			"description": "快速恢复少量生命。",
			"count": 1,
			"target_type": "目标：我方单体",
			"icon_path": "res://icon.svg",
			"effect": {"kind": "heal", "recover_hp": 8.0}
		},
		{
			"id": "item_b",
			"name_cn": "测试药剂 B",
			"description": "稳定恢复生命并清醒心神。",
			"count": 1,
			"target_type": "目标：我方单体",
			"icon_path": "res://icon.svg",
			"effect": {"kind": "heal", "recover_hp": 10.0}
		},
		{
			"id": "item_c",
			"name_cn": "测试药剂 C",
			"description": "高强度恢复生命。",
			"count": 1,
			"target_type": "目标：我方单体",
			"icon_path": "res://icon.svg",
			"effect": {"kind": "heal", "recover_hp": 12.0}
		}
	]

	controller.call("_refresh_main_item_cards", fake_items)
	var visible_ids: Array = controller.get("_item_card_item_ids")
	_assert_true(visible_ids.size() == 2, "主区道具卡应最多展示 2 张")
	if visible_ids.size() == 2:
		_assert_true(String(visible_ids[0]) == "item_a" and String(visible_ids[1]) == "item_b", "默认排序应先展示前两张道具")

	controller.call("_mark_item_recent", "item_c")
	controller.call("_refresh_main_item_cards", fake_items)
	visible_ids = controller.get("_item_card_item_ids")
	if visible_ids.size() == 2:
		_assert_true(String(visible_ids[0]) == "item_c", "最近使用道具应优先展示在主区首位")

	controller.call("_refresh_item_popup", fake_items)
	var item_list_vbox := instance.find_child("ItemListVBox", true, false) as VBoxContainer
	_assert_true(item_list_vbox != null, "道具弹窗列表节点必须存在")
	if item_list_vbox != null:
		_assert_true(item_list_vbox.get_child_count() == 3, "道具弹窗应按卡牌展示全部可用项")
		if item_list_vbox.get_child_count() > 0:
			var popup_card: Node = item_list_vbox.get_child(0)
			_assert_true(popup_card is PanelContainer, "道具弹窗项应为卡牌容器（PanelContainer）")
			if popup_card is Control and attack_card != null:
				_assert_true(
					_vec2_equal((popup_card as Control).custom_minimum_size, attack_card.custom_minimum_size),
					"弹窗道具卡应与技能卡保持同尺寸"
				)
			var use_buttons: Array = popup_card.find_children("*", "Button", true, false)
			_assert_true(not use_buttons.is_empty(), "道具弹窗卡应保留点击使用入口")
			if popup_card is Control:
				_assert_true(
					(popup_card as Control).get_signal_connection_list("gui_input").size() > 0,
					"道具弹窗卡应保留拖拽交互"
				)

	var command_strip_scroll := instance.find_child("CommandStripScroll", true, false) as ScrollContainer
	var command_strip := instance.find_child("CommandStrip", true, false) as HBoxContainer
	_assert_true(command_strip_scroll != null and command_strip != null, "命令区滚动容器应存在")
	if command_strip_scroll != null and command_strip != null:
		_assert_true(command_strip_scroll.horizontal_scroll_mode != 0, "窄宽场景下命令区应支持横向滚动")
		command_strip_scroll.custom_minimum_size = Vector2(260, command_strip_scroll.custom_minimum_size.y)
		await process_frame
		_assert_true(command_strip.size.x >= command_strip_scroll.size.x, "命令区内容应可通过滚动完整访问，避免裁切不可达")

	instance.queue_free()
	await process_frame


func _vec2_equal(a: Vector2, b: Vector2) -> bool:
	return is_equal_approx(a.x, b.x) and is_equal_approx(a.y, b.y)


func _assert_true(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)
	printerr("ASSERT FAILED: %s" % message)


func _finish() -> void:
	if _failures.is_empty():
		print("SMOKE TEST PASS: battle UI card layout validated.")
		quit(0)
		return
	printerr("SMOKE TEST FAIL (%d):" % _failures.size())
	for msg: String in _failures:
		printerr("- %s" % msg)
	quit(1)
