extends SceneTree

const DATA_PATHS := [
	"res://data/items.json",
	"res://data/events.json",
	"res://data/maps.json"
]

var _failures: Array[String] = []
var _original_text_by_path: Dictionary = {}


func _initialize() -> void:
	call_deferred("_run_suite")


func _run_suite() -> void:
	_setup_content_db()
	_backup_data_files()

	_test_baseline_ok()
	_test_duplicate_id_rejected()
	_test_bad_reference_rejected()
	_test_missing_required_field_rejected()

	_restore_data_files()
	_test_restore_ok()
	_print_result_and_exit()


func _setup_content_db() -> void:
	var content_db: Node = load("res://autoload/content_db.gd").new()
	content_db.name = "ContentDB"
	get_root().add_child(content_db)


func _backup_data_files() -> void:
	for path: String in DATA_PATHS:
		_original_text_by_path[path] = FileAccess.get_file_as_string(_to_abs(path))


func _restore_data_files() -> void:
	for path: String in _original_text_by_path.keys():
		var file := FileAccess.open(_to_abs(path), FileAccess.WRITE)
		if file == null:
			_failures.append("恢复文件失败：%s" % path)
			continue
		file.store_string(String(_original_text_by_path[path]))


func _test_baseline_ok() -> void:
	var code: int = _content_db().reload_all()
	_assert_true(code == OK, "基线数据应可通过 reload_all")


func _test_duplicate_id_rejected() -> void:
	var items: Array = _read_json_array("res://data/items.json")
	if items.is_empty():
		_failures.append("items.json 为空，无法验证重复 id")
		return

	items.append(items[0].duplicate(true))
	_write_json("res://data/items.json", items)

	var code: int = _content_db().reload_all()
	_assert_true(code == ERR_INVALID_DATA, "重复 id 应触发 ERR_INVALID_DATA")
	_restore_data_files()
	_content_db().reload_all()


func _test_bad_reference_rejected() -> void:
	var events: Array = _read_json_array("res://data/events.json")
	if events.is_empty():
		_failures.append("events.json 为空，无法验证坏引用")
		return

	var target_idx: int = -1
	for i: int in events.size():
		if String(events[i].get("resolution_type", "")) == "battle":
			target_idx = i
			break
	if target_idx < 0:
		_failures.append("未找到可用于坏引用测试的 battle 事件")
		return

	events[target_idx]["battle_id"] = "battle_missing_for_validation"
	_write_json("res://data/events.json", events)

	var code: int = _content_db().reload_all()
	_assert_true(code == ERR_INVALID_DATA, "坏引用应触发 ERR_INVALID_DATA")
	_restore_data_files()
	_content_db().reload_all()


func _test_missing_required_field_rejected() -> void:
	var maps: Array = _read_json_array("res://data/maps.json")
	if maps.is_empty():
		_failures.append("maps.json 为空，无法验证缺字段")
		return

	maps[0].erase("random_slot_anchors")
	_write_json("res://data/maps.json", maps)

	var code: int = _content_db().reload_all()
	_assert_true(code == ERR_INVALID_DATA, "缺失必填字段应触发 ERR_INVALID_DATA")
	_restore_data_files()
	_content_db().reload_all()


func _test_restore_ok() -> void:
	var code: int = _content_db().reload_all()
	_assert_true(code == OK, "恢复原始数据后应可再次通过 reload_all")


func _read_json_array(path: String) -> Array:
	var text: String = FileAccess.get_file_as_string(_to_abs(path))
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_ARRAY:
		return []
	return parsed


func _write_json(path: String, payload: Variant) -> void:
	var file := FileAccess.open(_to_abs(path), FileAccess.WRITE)
	if file == null:
		_failures.append("写入文件失败：%s" % path)
		return
	file.store_string(JSON.stringify(payload, "\t"))


func _to_abs(path: String) -> String:
	return ProjectSettings.globalize_path(path)


func _assert_true(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)
	printerr("ASSERT FAILED: %s" % message)


func _print_result_and_exit() -> void:
	if _failures.is_empty():
		print("SMOKE TEST PASS: content validation contracts verified.")
		quit(0)
		return

	printerr("SMOKE TEST FAIL (%d):" % _failures.size())
	for message: String in _failures:
		printerr("- %s" % message)
	quit(1)


func _content_db() -> Node:
	return get_root().get_node("ContentDB")
