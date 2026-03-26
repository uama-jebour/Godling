extends SceneTree

const SAVE_PATH := "user://progression_state.json"

var _failures: Array[String] = []
var _had_save_file := false
var _original_save_text := ""


func _initialize() -> void:
	call_deferred("_run_suite")


func _run_suite() -> void:
	_setup_singletons()
	_backup_save_file()
	_reset_progression_to_defaults()
	_test_interactive_round_progression()
	_test_enemy_presence_stable_without_hero_damage()
	_test_interactive_commands()
	_test_patrol_battle_is_winnable()
	_test_loot_table_rolls_produce_rewards()
	_test_random_battle_group_counts()
	_test_run_state_accepts_interactive_battle_result()
	_restore_save_file()
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


func _backup_save_file() -> void:
	_had_save_file = FileAccess.file_exists(SAVE_PATH)
	if _had_save_file:
		_original_save_text = FileAccess.get_file_as_string(SAVE_PATH)


func _restore_save_file() -> void:
	if _had_save_file:
		var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
		if file != null:
			file.store_string(_original_save_text)
		return
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))


func _reset_progression_to_defaults() -> void:
	var content: Node = _content_db()
	var progression: Node = _progression_state()
	progression.state = content.get_default_progression_state()
	progression.configure_home_loadout(
		"hero_pilgrim_a01",
		["key_silent_litany_hint"],
		["relic_burned_prayer_wheel"]
	)
	progression.save_to_disk()


func _test_interactive_round_progression() -> void:
	var simulator: RefCounted = load("res://systems/battle/battle_simulator.gd").new()
	var battle_def: Dictionary = _content_db().get_battle("battle_a02_patrol")
	var state: Dictionary = simulator.initialize_state(
		{
			"battle_id": "battle_a02_patrol",
			"hero_snapshot": {
				"hero_id": "hero_pilgrim_a01",
				"runtime_stats": {
					"hp": 40.0,
					"attack_power": 5.0
				}
			},
			"equipped_relic_modifiers": []
		},
		battle_def,
		_content_db()
	)
	_assert_true(not state.has("invalid_reason"), "interactive 初始化不应失败")
	if state.has("invalid_reason"):
		return

	var target_id: String = String(state.get("selected_target_id", ""))
	_assert_true(not target_id.is_empty(), "interactive 初始应存在可选敌方目标")
	var before_enemy_hp: float = _enemy_hp_by_id(state, target_id)
	state = simulator.apply_player_attack(state, target_id)
	_assert_true(String(state.get("turn_phase", "")) == "enemy" or float(state.get("enemy_total_hp", 0.0)) <= 0.0, "玩家攻击后应轮到敌方阶段或直接结束")
	_assert_true(_enemy_hp_by_id(state, target_id) < before_enemy_hp, "玩家攻击后目标生命应下降")
	_assert_true(int(state.get("hero_resolve", 0)) == 2, "斩击后应消耗 1 点灵势")
	_assert_true(_skill_cooldown(state, "primary") == 0, "斩击应保持每回合可用")

	var hero_hp_before_enemy: float = float(state.get("hero_hp", 0.0))
	if simulator.is_battle_active(state):
		var expected_enemy_order: Array = _alive_enemy_ids(state)
		var enemy_swings := 0
		var enemy_actor_order: Array = []
		while simulator.is_battle_active(state) and String(state.get("turn_phase", "")) == "enemy":
			state = simulator.apply_enemy_phase(state)
			if String(state.get("last_action", {}).get("phase", "")) == "enemy":
				enemy_swings += 1
				enemy_actor_order.append(String(state.get("last_action", {}).get("actor_id", "")))
		_assert_true(int(state.get("elapsed", 0)) >= 1, "敌方阶段完成后应推进回合计数")
		_assert_true(float(state.get("hero_hp", 0.0)) < hero_hp_before_enemy, "敌方行动后英雄生命应下降")
		_assert_true(enemy_swings == expected_enemy_order.size(), "敌方阶段应由每名存活敌人依次反击")
		_assert_true(enemy_actor_order == expected_enemy_order, "敌方反击顺序应与战场左到右顺序一致")
		_assert_true(int(state.get("hero_resolve", 0)) >= 2, "敌方回合结束后应回复灵势")


func _test_enemy_presence_stable_without_hero_damage() -> void:
	var simulator: RefCounted = load("res://systems/battle/battle_simulator.gd").new()
	var battle_def: Dictionary = _content_db().get_battle("battle_a02_patrol")
	var state: Dictionary = simulator.initialize_state(
		{
			"battle_id": "battle_a02_patrol",
			"hero_snapshot": {
				"hero_id": "hero_pilgrim_a01",
				"runtime_stats": {
					"hp": 40.0,
					"attack_power": 5.0
				}
			},
			"equipped_relic_modifiers": []
		},
		battle_def,
		_content_db()
	)
	_assert_true(not state.has("invalid_reason"), "敌方稳定性测试初始化不应失败")
	if state.has("invalid_reason"):
		return
	var hp_before: float = float(state.get("enemy_total_hp", 0.0))
	var alive_before: Array = _alive_enemy_ids(state)
	state = simulator.apply_player_wait(state)
	while simulator.is_battle_active(state) and String(state.get("turn_phase", "")) == "enemy":
		state = simulator.apply_enemy_phase(state)
	_assert_true(is_equal_approx(float(state.get("enemy_total_hp", 0.0)), hp_before), "我方未造成伤害时，敌方总生命不应异常变化")
	_assert_true(_alive_enemy_ids(state) == alive_before, "我方未造成伤害时，敌方单位不应在下一回合异常消失")


func _test_interactive_commands() -> void:
	var simulator: RefCounted = load("res://systems/battle/battle_simulator.gd").new()
	var battle_def: Dictionary = _content_db().get_battle("battle_a02_patrol")
	var defend_state: Dictionary = simulator.initialize_state(
		{
			"battle_id": "battle_a02_patrol",
			"hero_snapshot": {
				"hero_id": "hero_pilgrim_a01",
				"runtime_stats": {
					"hp": 40.0,
					"attack_power": 4.0
				},
				"temporary_inventory": [{"id": "consumable_field_balm", "count": 1}]
			}
		},
		battle_def,
		_content_db()
	)
	var open_state: Dictionary = defend_state.duplicate(true)
	defend_state = simulator.apply_player_defend(defend_state)
	open_state = simulator.apply_player_wait(open_state)
	_assert_true(_skill_cooldown(defend_state, "guard") >= 1, "架盾后应至少进入 1 回合冷却")
	while simulator.is_battle_active(defend_state) and String(defend_state.get("turn_phase", "")) == "enemy":
		defend_state = simulator.apply_enemy_phase(defend_state)
	while simulator.is_battle_active(open_state) and String(open_state.get("turn_phase", "")) == "enemy":
		open_state = simulator.apply_enemy_phase(open_state)
	_assert_true(_skill_cooldown(defend_state, "guard") >= 1, "敌方回合结束后架盾不应立刻回满")
	_assert_true(
		float(defend_state.get("hero_hp", 0.0)) > float(open_state.get("hero_hp", 0.0)),
		"防御应比直接结束回合承受更少伤害"
	)

	var item_state: Dictionary = simulator.initialize_state(
		{
			"battle_id": "battle_a02_patrol",
			"hero_snapshot": {
				"hero_id": "hero_pilgrim_a01",
				"runtime_stats": {
					"hp": 28.0,
					"attack_power": 4.0
				},
				"temporary_inventory": [{"id": "consumable_field_balm", "count": 1}]
			}
		},
		battle_def,
		_content_db()
	)
	item_state["hero_hp"] = 12.0
	item_state["hero_entity"]["current_hp"] = 12.0
	item_state = simulator.apply_player_item(item_state, "consumable_field_balm")
	_assert_true(float(item_state.get("hero_hp", 0.0)) > 12.0, "使用道具后英雄生命应恢复")
	_assert_true(item_state.get("battle_items", []).is_empty(), "使用道具后库存应扣减")
	_assert_true(String(item_state.get("last_action", {}).get("phase", "")) == "item", "使用道具后应记录 item 行动")

	var burst_state: Dictionary = simulator.initialize_state(
		{
			"battle_id": "battle_a02_patrol",
			"hero_snapshot": {
				"hero_id": "hero_pilgrim_a01",
				"runtime_stats": {
					"hp": 36.0,
					"attack_power": 4.0
				}
			}
		},
		battle_def,
		_content_db()
	)
	var enemy_hp_before_burst: float = float(burst_state.get("enemy_total_hp", 0.0))
	burst_state = simulator.apply_player_burst(burst_state)
	_assert_true(float(burst_state.get("enemy_total_hp", 0.0)) < enemy_hp_before_burst, "祷焰横扫应压低敌方总生命")
	_assert_true(int(burst_state.get("hero_resolve", 0)) == 1, "祷焰横扫后应消耗 2 点灵势")
	_assert_true(_skill_cooldown(burst_state, "burst") >= 2, "祷焰横扫后应进入较长冷却")
	_assert_true(String(burst_state.get("last_action", {}).get("phase", "")) == "burst", "祷焰横扫后应记录 burst 行动")


func _test_patrol_battle_is_winnable() -> void:
	var simulator: RefCounted = load("res://systems/battle/battle_simulator.gd").new()
	var battle_def: Dictionary = _content_db().get_battle("battle_a02_patrol")
	var state: Dictionary = simulator.initialize_state(
		{
			"battle_id": "battle_a02_patrol",
			"hero_snapshot": {
				"hero_id": "hero_pilgrim_a01",
				"runtime_stats": {
					"hp": 36.0,
					"attack_power": 4.0
				},
				"temporary_inventory": [{"id": "consumable_field_balm", "count": 1}]
			}
		},
		battle_def,
		_content_db()
	)
	_assert_true(not state.has("invalid_reason"), "平衡验证初始化不应失败")
	if state.has("invalid_reason"):
		return
	while simulator.is_battle_active(state):
		if String(state.get("turn_phase", "player")) == "player":
			if float(state.get("hero_hp", 0.0)) <= 12.0 and not state.get("battle_items", []).is_empty():
				state = simulator.apply_player_item(state, "consumable_field_balm")
			else:
				state = simulator.apply_player_attack(state, String(state.get("selected_target_id", "")))
		else:
			state = simulator.apply_enemy_phase(state)
	var result: Dictionary = simulator.build_result(state)
	_assert_true(bool(result.get("victory", false)), "基础巡逻战在默认英雄面板下应可通过")


func _test_loot_table_rolls_produce_rewards() -> void:
	var loot_result: Dictionary = _content_db().roll_loot_table("loot_table_a02_basic_field", 2)
	var total_entries: int = loot_result.get("items", []).size() + loot_result.get("currencies", []).size() + loot_result.get("relics", []).size()
	_assert_true(total_entries > 0, "掉落表 roll 后应生成至少一类奖励")


func _test_run_state_accepts_interactive_battle_result() -> void:
	var loadout: Dictionary = _progression_state().get_home_loadout()
	_run_state().start_new_run(
		"map_world_a_02_ashen_sanctum",
		String(loadout.get("hero_id", "hero_pilgrim_a01")),
		loadout.get("carried_item_ids", []),
		loadout.get("equipped_relic_ids", [])
	)
	var battle_event: Dictionary = _content_db().get_event("event_a02_battle_patrol")
	battle_event["instance_id"] = "itest_battle_1"
	battle_event["spawn_turn"] = 1
	_run_state().active_run["board_state"]["random_slots"] = [battle_event]
	var selected: Dictionary = _run_state().select_event("event_a02_battle_patrol")
	_assert_true(not selected.is_empty(), "应可选中注入的 battle 事件")
	if selected.is_empty():
		return

	var result: Dictionary = _run_state().complete_selected_event_with_battle_result(
		{
			"status": "battle_runner_resolved",
			"victory": true,
			"defeat_reason": "",
			"casualties": [],
			"reward_package": {
				"currencies": [{"id": "currency_lumen_mark", "count": 9}],
				"items": [],
				"relics": [],
				"story_flags": [],
				"unlock_flags": [],
				"loot_tables": []
			},
			"completed_objectives": ["objective_eliminate_all"],
			"spawned_story_flags": [],
			"spawned_unlock_flags": [],
			"map_effects": {"backend": "scene", "interactive_mode": true}
		}
	)
	_assert_true(not result.is_empty(), "interactive battle 结果应可回写到 RunState")
	var summary: Dictionary = _run_state().get_turn_summary()
	_assert_true(int(summary.get("turn", 0)) == 2, "interactive battle 结算后应推进到下一回合")
	var loot: Dictionary = _run_state().get_temporary_loot_snapshot()
	_assert_true(int(loot.get("currencies", [])[0].get("count", 0)) >= 9, "interactive battle 奖励应写入临时货币")


func _test_random_battle_group_counts() -> void:
	var simulator: RefCounted = load("res://systems/battle/battle_simulator.gd").new()
	var battle_def: Dictionary = _content_db().get_battle("battle_a02_patrol")
	var seen_totals: Dictionary = {}
	for _i in range(8):
		var state: Dictionary = simulator.initialize_state(
			{
				"battle_id": "battle_a02_patrol",
				"hero_snapshot": {
					"hero_id": "hero_pilgrim_a01",
					"runtime_stats": {
						"hp": 36.0,
						"attack_power": 4.0
					}
				}
			},
			battle_def,
			_content_db()
		)
		seen_totals[int(state.get("enemy_unit_total", 0))] = true
	_assert_true(seen_totals.size() >= 2, "普通战斗模板的敌人数应存在随机变化")


func _enemy_hp_by_id(state: Dictionary, entity_id: String) -> float:
	for enemy_entity_value in state.get("enemy_entities", []):
		if typeof(enemy_entity_value) != TYPE_DICTIONARY:
			continue
		var enemy_entity: Dictionary = enemy_entity_value
		if String(enemy_entity.get("entity_id", "")) == entity_id:
			return float(enemy_entity.get("current_hp", 0.0))
	return -1.0


func _alive_enemy_ids(state: Dictionary) -> Array:
	var ids: Array = []
	for enemy_entity_value in state.get("enemy_entities", []):
		if typeof(enemy_entity_value) != TYPE_DICTIONARY:
			continue
		var enemy_entity: Dictionary = enemy_entity_value
		if not bool(enemy_entity.get("is_alive", true)):
			continue
		ids.append(String(enemy_entity.get("entity_id", "")))
	return ids


func _skill_cooldown(state: Dictionary, slot_id: String) -> int:
	for skill_value in state.get("skill_slots", []):
		if typeof(skill_value) != TYPE_DICTIONARY:
			continue
		var skill: Dictionary = skill_value
		if String(skill.get("slot", "")) == slot_id:
			return int(skill.get("cooldown_remaining", 0))
	return -1


func _content_db() -> Node:
	return get_root().get_node("ContentDB")


func _progression_state() -> Node:
	return get_root().get_node("ProgressionState")


func _run_state() -> Node:
	return get_root().get_node("RunState")


func _assert_true(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)
	printerr("ASSERT FAILED: %s" % message)


func _print_result_and_exit() -> void:
	if _failures.is_empty():
		print("SMOKE TEST PASS: interactive battle loop validated.")
		quit(0)
		return
	printerr("SMOKE TEST FAIL (%d):" % _failures.size())
	for message: String in _failures:
		printerr("- %s" % message)
	quit(1)
