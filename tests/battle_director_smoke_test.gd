extends SceneTree

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run_suite")


func _run_suite() -> void:
	_setup_content_db()
	_test_director_runs_headless_battle()
	_test_director_runs_scene_battle_backend()
	_print_result_and_exit()


func _setup_content_db() -> void:
	var content_db: Node = load("res://autoload/content_db.gd").new()
	content_db.name = "ContentDB"
	get_root().add_child(content_db)


func _test_director_runs_headless_battle() -> void:
	var director: RefCounted = load("res://systems/battle/battle_director.gd").new()
	var battle_result: Dictionary = director.run_battle(
		{
			"battle_id": "battle_a02_forced_ambush",
			"event_instance_id": "forced_run_1",
			"map_id": "map_world_a_02_ashen_sanctum",
			"hero_snapshot": {
				"hero_id": "hero_pilgrim_a01",
				"runtime_stats": {
					"hp": 120.0,
					"attack_power": 1.0
				}
			},
			"ally_snapshot": [],
			"equipped_relic_modifiers": [],
			"configured_reward_package": {
				"currencies": [{"id": "currency_lumen_mark", "count": 22}],
				"items": [],
				"relics": [],
				"story_flags": [],
				"unlock_flags": [],
				"loot_tables": []
			}
		},
		{"success_override": true}
	)

	_assert_true(String(battle_result.get("status", "")) == "battle_runner_resolved", "BattleDirector 应调用 headless battle runner")
	_assert_true(bool(battle_result.get("victory", false)), "强制伏击测试应返回胜利")
	_assert_true(
		battle_result.get("map_effects", {}).get("battle_events_triggered", []).has("battle_event_demon_reinforce"),
		"带战斗内事件的 battle 应触发 reinforcement 事件"
	)
	_assert_true(
		int(battle_result.get("map_effects", {}).get("enemy_count_total", 0)) >= 4,
		"战斗结果应回填敌人总数"
	)
	_assert_true(
		battle_result.get("completed_objectives", []).has("objective_survive_and_clear"),
		"战斗结果应包含 victory_type 对应 objective"
	)
	_assert_true(
		String(battle_result.get("map_effects", {}).get("backend", "headless")) == "headless",
		"默认 BattleDirector 应使用 headless 后端"
	)


func _test_director_runs_scene_battle_backend() -> void:
	var director: RefCounted = load("res://systems/battle/battle_director.gd").new()
	var battle_result: Dictionary = director.run_battle(
		{
			"battle_id": "battle_a02_patrol",
			"event_instance_id": "scene_run_1",
			"map_id": "map_world_a_02_ashen_sanctum",
			"hero_snapshot": {
				"hero_id": "hero_pilgrim_a01",
				"runtime_stats": {
					"hp": 36.0,
					"attack_power": 4.0
				}
			},
			"ally_snapshot": [],
			"equipped_relic_modifiers": ["relic_burned_prayer_wheel"],
			"configured_reward_package": {
				"currencies": [],
				"items": [],
				"relics": [],
				"story_flags": [],
				"unlock_flags": [],
				"loot_tables": []
			}
		},
		{
			"battle_backend": "scene",
			"success_override": true
		}
	)

	_assert_true(String(battle_result.get("status", "")) == "battle_runner_resolved", "scene 后端也应返回 battle runner 结果")
	_assert_true(
		String(battle_result.get("map_effects", {}).get("backend", "")) == "scene",
		"指定 scene 后端时应通过场景实例执行"
	)
	_assert_true(
		String(battle_result.get("map_effects", {}).get("scene_controller", "")) == "BattleSceneController",
		"scene 后端应通过 BattleSceneController 执行"
	)
	_assert_true(
		int(battle_result.get("map_effects", {}).get("rendered_enemy_token_count", 0)) > 0,
		"scene 后端应渲染敌方 token"
	)
	_assert_true(
		int(battle_result.get("map_effects", {}).get("rendered_log_line_count", 0)) > 0,
		"scene 后端应写入 tick 日志"
	)
	_assert_true(
		int(battle_result.get("map_effects", {}).get("rendered_arena_token_count", 0)) >= 1,
		"scene 后端至少应保留英雄主战场节点"
	)
	_assert_true(
		int(battle_result.get("map_effects", {}).get("visual_feedback_counts", {}).get("hit", 0)) > 0,
		"scene 后端应记录单位受击反馈"
	)
	_assert_true(
		int(battle_result.get("map_effects", {}).get("motion_feedback_counts", {}).get("animated_entities", 0)) > 0,
		"scene 后端应记录单位节奏动画采样"
	)
	_assert_true(
		int(battle_result.get("map_effects", {}).get("motion_feedback_counts", {}).get("hero_advances", 0)) > 0
			or int(battle_result.get("map_effects", {}).get("motion_feedback_counts", {}).get("enemy_advances", 0)) > 0,
		"scene 后端应记录至少一侧的前压动作"
	)
	_assert_true(
		int(battle_result.get("map_effects", {}).get("combat_cue_counts", {}).get("attack_lines", 0)) > 0,
		"scene 后端应记录攻击连线演出"
	)
	_assert_true(
		int(battle_result.get("map_effects", {}).get("combat_cue_counts", {}).get("death_fades", 0)) > 0,
		"scene 后端应记录死亡淡出演出"
	)
	var enemy_hp_remaining: float = float(battle_result.get("map_effects", {}).get("enemy_hp_remaining", 0.0))
	var alive_enemy_entities: int = 0
	for enemy_entity: Dictionary in battle_result.get("map_effects", {}).get("enemy_entities", []):
		if bool(enemy_entity.get("is_alive", false)):
			alive_enemy_entities += 1
	_assert_true(
		enemy_hp_remaining <= 0.0 or alive_enemy_entities > 0,
		"只要敌方总生命大于 0，scene 结果里就必须还有可见敌方实体"
	)


func _assert_true(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)
	printerr("ASSERT FAILED: %s" % message)


func _print_result_and_exit() -> void:
	if _failures.is_empty():
		print("SMOKE TEST PASS: battle director headless loop validated.")
		quit(0)
		return

	printerr("SMOKE TEST FAIL (%d):" % _failures.size())
	for message: String in _failures:
		printerr("- %s" % message)
	quit(1)
