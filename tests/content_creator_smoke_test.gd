extends SceneTree

const SAVE_PATH := "user://progression_state.json"
const CREATED_CONTENT_PATH := "user://content_creations.json"

var _failures: Array[String] = []
var _had_save_file := false
var _original_save_text := ""
var _had_created_content := false
var _original_created_text := ""


func _initialize() -> void:
	call_deferred("_run_suite")


func _run_suite() -> void:
	_backup_files()
	_setup_singletons()
	_reset_state()
	_test_create_item()
	_test_create_enemy()
	_test_create_hero()
	_restore_files()
	_print_result_and_exit()


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

	var balance: Node = load("res://autoload/balance_state.gd").new()
	balance.name = "BalanceState"
	get_root().add_child(balance)


func _backup_files() -> void:
	_had_save_file = FileAccess.file_exists(SAVE_PATH)
	if _had_save_file:
		_original_save_text = FileAccess.get_file_as_string(SAVE_PATH)
	_had_created_content = FileAccess.file_exists(CREATED_CONTENT_PATH)
	if _had_created_content:
		_original_created_text = FileAccess.get_file_as_string(CREATED_CONTENT_PATH)


func _restore_files() -> void:
	_restore_text_file(SAVE_PATH, _had_save_file, _original_save_text)
	_restore_text_file(CREATED_CONTENT_PATH, _had_created_content, _original_created_text)


func _restore_text_file(path: String, had_file: bool, contents: String) -> void:
	if had_file:
		var file := FileAccess.open(path, FileAccess.WRITE)
		if file != null:
			file.store_string(contents)
		return
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _reset_state() -> void:
	var balance: Node = _balance_state()
	balance.reset_created_content()
	var progression: Node = _progression_state()
	progression.state = _content_db().get_default_progression_state()
	progression.save_to_disk()


func _test_create_item() -> void:
	var result: Dictionary = _balance_state().create_item({
		"id": "consumable_test_balm",
		"name_cn": "试制敷膏",
		"type": 6,
		"quality": 2,
		"description": "测试用治疗道具。",
		"combat_effect_kind": "heal",
		"combat_effect_value": 18.0,
		"tags": "consumable,testing"
	})
	_assert_true(bool(result.get("ok", false)), "创建道具应成功")
	var item_def: Dictionary = _content_db().get_item("consumable_test_balm")
	_assert_true(String(item_def.get("name_cn", "")) == "试制敷膏", "创建后应能从 ContentDB 读取新道具")
	_assert_true(float(item_def.get("combat_effect", {}).get("value", 0.0)) == 18.0, "创建道具的战斗效果值应保留")


func _test_create_enemy() -> void:
	var result: Dictionary = _balance_state().create_enemy({
		"id": "enemy_test_sentry",
		"name_cn": "试制哨兵",
		"hp": 26,
		"attack_power": 4.5,
		"attack_speed": 1.1,
		"attack_range": 3,
		"attack_type": "ranged_flat",
		"move_speed": 11,
		"size": 3,
		"tags": "enemy,test,sentry"
	})
	_assert_true(bool(result.get("ok", false)), "创建敌人应成功")
	var unit_def: Dictionary = _content_db().get_unit("enemy_test_sentry")
	_assert_true(String(unit_def.get("camp", "")) == "enemy", "创建敌人后阵营应为 enemy")
	_assert_true(float(unit_def.get("attack", {}).get("power", 0.0)) == 4.5, "创建敌人的攻击力应保留")


func _test_create_hero() -> void:
	var result: Dictionary = _balance_state().create_hero({
		"id": "hero_test_pilgrim",
		"name_cn": "试制行者",
		"hp": 44,
		"attack_power": 5.2,
		"attack_speed": 1.0,
		"attack_range": 2,
		"attack_type": "melee",
		"move_speed": 10,
		"size": 4,
		"tags": "hero,test,pilgrim"
	})
	_assert_true(bool(result.get("ok", false)), "创建英雄应成功")
	var hero_def: Dictionary = _content_db().get_unit("hero_test_pilgrim")
	_assert_true(String(hero_def.get("camp", "")) == "hero", "创建英雄后阵营应为 hero")
	_assert_true(_progression_state().state.get("hero_roster", []).has("hero_test_pilgrim"), "创建英雄后应自动加入家园 roster")


func _content_db() -> Node:
	return get_root().get_node("ContentDB")


func _progression_state() -> Node:
	return get_root().get_node("ProgressionState")


func _balance_state() -> Node:
	return get_root().get_node("BalanceState")


func _assert_true(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)
	printerr("ASSERT FAILED: %s" % message)


func _print_result_and_exit() -> void:
	if _failures.is_empty():
		print("SMOKE TEST PASS: runtime content creator registers items, enemies, and heroes.")
		quit(0)
		return
	printerr("SMOKE TEST FAIL (%d):" % _failures.size())
	for message: String in _failures:
		printerr("- %s" % message)
	quit(1)
