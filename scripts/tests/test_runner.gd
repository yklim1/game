extends Node
## 경량 자체 시뮬레이션 테스트 러너 (외부 플러그인 없음, 테스트 전용).
## 헤드리스로 게임 씬을 실제로 돌리며 핵심 시스템을 검증하고, 실패 시 종료코드 1로 끝난다.
##
## 실행 예:
##   godot_console.exe --headless --path <프로젝트> res://scenes/tests/test_runner.tscn -- --combat=60 --soak=180

const GAME_SCENE_PATH: String = "res://scenes/main/game.tscn"
const SOAK_SAMPLE_INTERVAL: float = 15.0
## 소크 테스트에서 노드 수가 이 값을 넘으면 누수로 간주한다.
const NODE_COUNT_CEILING: int = 4000

## 웨이브 2~3까지 도달해 스케일링을 관측하려면 최소 70초 이상이 필요하다.
var _combat_seconds: float = 90.0
var _soak_seconds: float = 180.0
var _run_soak: bool = true

var _passed: int = 0
var _failed: int = 0
var _failures: Array[String] = []

var _game: Node
var _autopilot: TestAutopilot
var _essence_gained: int = 0
var _level_ups: int = 0
var _baseline_nodes: int = 0
var _last_health: Vector2 = Vector2.ZERO

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_parse_args()
	EventBus.essence_collected.connect(func(value: int) -> void: _essence_gained += value)
	EventBus.player_leveled_up.connect(func(_level: int) -> void: _level_ups += 1)
	EventBus.player_health_changed.connect(func(current: float, maximum: float) -> void: _last_health = Vector2(current, maximum))
	_run_all.call_deferred()

func _parse_args() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--combat="):
			_combat_seconds = float(arg.split("=")[1])
		elif arg.begins_with("--soak="):
			_soak_seconds = float(arg.split("=")[1])
		elif arg == "--no-soak":
			_run_soak = false

func _run_all() -> void:
	var wall_start: int = Time.get_ticks_msec()
	_log("=== Feral Bloom 자동 시뮬레이션 테스트 ===")
	_log("Godot %s | headless=%s" % [Engine.get_version_info().string, str(DisplayServer.get_name() == "headless")])
	_log("설정: combat=%.0fs soak=%.0fs" % [_combat_seconds, _soak_seconds if _run_soak else 0.0])
	_baseline_nodes = _node_count()

	await _case_boot()
	await _case_content_db()
	await _case_combat()
	await _case_contact_damage()
	await _case_game_over()
	await _case_runtime_ability_add()
	await _case_stress()
	if _run_soak:
		await _case_soak()

	_log("")
	_log("=== 결과: %d개 통과 / %d개 실패 (총 %.1fs) ===" % [_passed, _failed, float(Time.get_ticks_msec() - wall_start) / 1000.0])
	for failure in _failures:
		_log("  실패: %s" % failure)
	_log("RESULT %s" % ("PASS" if _failed == 0 else "FAIL"))
	get_tree().quit(0 if _failed == 0 else 1)

# ---------------------------------------------------------------- 테스트 케이스

func _case_boot() -> void:
	_begin("1. 씬 로드 / 오토로드 초기화")
	_last_health = Vector2.ZERO
	_check(get_node_or_null("/root/EventBus") != null, "EventBus 오토로드 존재")
	_check(get_node_or_null("/root/RunState") != null, "RunState 오토로드 존재")
	_check(get_node_or_null("/root/ContentDB") != null, "ContentDB 오토로드 존재")
	await _start_game(false)
	_check(_game != null, "game.tscn 인스턴스화 성공")
	if _game == null:
		return
	_check(_game.get_player() != null, "Player 노드 존재")
	_check(_game.get_animal_pool() != null, "AnimalPool 존재")
	_check(_game.get_pickup_pool() != null, "PickupPool 존재")
	_check(_game.get_wave_director() != null, "WaveDirector 존재")
	var manager: AbilityManager = _game.get_player().get_ability_manager()
	_check(manager.get_ability_count() >= 2, "능력 슬롯 2개 이상 장착 (실제 %d개)" % manager.get_ability_count())
	var scenes_ok: bool = true
	for ability in manager.abilities:
		var scene_path: String = "null" if ability.attack_scene == null else ability.attack_scene.resource_path
		if ability.attack_scene == null:
			scenes_ok = false
		_log("    능력 '%s' kind=%d scene=%s" % [ability.id, ability.attack_kind, scene_path])
	_check(scenes_ok, "장착 능력의 attack_scene 이 모두 지정됨")
	var wave_number: int = _game.get_wave_director().get_wave_number()
	_check(wave_number == 1, "첫 웨이브 시작됨 (wave=%d)" % wave_number)
	# HUD 등 나중에 준비되는 구독자도 초기 체력을 받아야 한다(HP 0/0 표시 방지).
	_check(_last_health.y > 0.0, "시작 시 초기 체력 시그널 수신 (%.0f / %.0f)" % [_last_health.x, _last_health.y])
	await _stop_game()

func _case_content_db() -> void:
	_begin("2. ContentDB 데이터 로드")
	var abilities: Array = ContentDB.get_ability_ids()
	var animals: Array = ContentDB.get_animal_ids()
	var waves: Array[WaveData] = ContentDB.get_waves()
	_check(abilities.size() >= 4, "능력 .tres %d종 로드" % abilities.size())
	_check(animals.size() >= 5, "동물 .tres %d종 로드" % animals.size())
	_check(waves.size() >= 5, "웨이브 .tres %d개 로드" % waves.size())
	_check(ContentDB.get_animal("spore_ant") != null, "id로 동물 조회 가능")
	_check(ContentDB.get_ability("claw_swipe") != null, "id로 능력 조회 가능")
	_check(ContentDB.get_animal("존재하지_않는_id") == null, "없는 id 조회 시 크래시 없이 null")
	var ordered: bool = true
	for i in range(1, waves.size()):
		if waves[i].index < waves[i - 1].index:
			ordered = false
	_check(ordered, "웨이브가 index 순으로 정렬됨")

func _case_combat() -> void:
	_begin("3. 전투 시뮬레이션 (%.0f초, 오토파일럿 카이팅)" % _combat_seconds)
	_essence_gained = 0
	_level_ups = 0
	await _start_game(true)
	if _game == null:
		return
	var metrics: SimMetrics = SimMetrics.new()
	var third: float = _combat_seconds / 3.0
	await _simulate(third, metrics)
	var spawned_early: int = _game.get_spawner().get_spawned_total()
	var alive_early: int = _alive_count()
	await _simulate(third, metrics)
	await _simulate(_combat_seconds - third * 2.0, metrics)
	var spawned_late: int = _game.get_spawner().get_spawned_total()
	var animal_pool: ObjectPool = _game.get_animal_pool()

	var rate_early: float = float(spawned_early) / third
	var rate_late: float = float(spawned_late - spawned_early) / (_combat_seconds - third)
	_check(spawned_early > 0, "적이 스폰됨 (초반 %d마리)" % spawned_early)
	_check(spawned_late > spawned_early, "적 스폰이 계속 누적됨 (%d → %d)" % [spawned_early, spawned_late])
	_check(rate_late > rate_early, "웨이브 진행에 따라 스폰 속도 증가 (%.2f/s → %.2f/s)" % [rate_early, rate_late])
	_check(RunState.kills > 0, "투사체·근접 공격으로 적 처치 발생 (%d킬)" % RunState.kills)
	_check(_essence_gained > 0, "정수(젬) 흡수로 XP 획득 (%d XP)" % _essence_gained)
	_check(_level_ups >= 1, "레벨업 %d회 발생 (도달 레벨 %d)" % [_level_ups, RunState.level])
	_check(RunState.damage_mult > 1.0, "레벨업 자동 스탯 상승 적용 (데미지 x%.2f)" % RunState.damage_mult)
	_check(
		animal_pool.get_acquire_count() > animal_pool.get_total_count(),
		"동물 풀 재사용 확인 (대여 %d회 > 인스턴스 %d개)" % [animal_pool.get_acquire_count(), animal_pool.get_total_count()]
	)
	_check(
		animal_pool.get_total_count() <= _game.get_spawner().max_alive + 32,
		"동물 풀이 무한 증식하지 않음 (풀 %d개 <= 상한 %d)" % [animal_pool.get_total_count(), _game.get_spawner().max_alive + 32]
	)
	_log("    1/3 지점 동시 적 %d마리 / 관측된 최대 동시 적 %d마리 / 평균 프레임 %.2f ms (최대 %.2f ms)" % [
		alive_early, metrics.max_alive, metrics.avg_frame_ms(), metrics.max_frame_ms()
	])
	_log("    생존 시간 %.1fs, 처치 %d, 레벨 %d, 먹이 %d, 웨이브 %d" % [
		RunState.elapsed_time, RunState.kills, RunState.level, RunState.feed, RunState.wave_index
	])
	for line in metrics.bucket_lines():
		_log("    " + line)
	await _stop_game()

func _case_contact_damage() -> void:
	_begin("4. 접촉 피해로 플레이어 HP 감소")
	await _start_game(false)
	if _game == null:
		return
	var player: Player = _game.get_player()
	var before: float = player.get_health()
	var animal: Node = _game.get_animal_pool().acquire()
	# 이동속도 0으로 플레이어 위에 붙여 접촉 판정을 강제한다.
	animal.setup(ContentDB.get_animal("spore_ant"), player.global_position, player, 1.0, 0.0, 1.0, false)
	await _simulate(0.6)
	_check(player.get_health() < before, "접촉 후 HP 감소 (%.0f → %.0f)" % [before, player.get_health()])
	await _stop_game()

func _case_game_over() -> void:
	_begin("5. HP 0 → 게임오버 상태 전이")
	await _start_game(false)
	if _game == null:
		return
	var player: Player = _game.get_player()
	player.take_damage(player.get_max_health() * 10.0)
	await _simulate(0.2)
	_check(RunState.is_game_over, "RunState.is_game_over = true")
	_check(not player.is_alive(), "플레이어 사망 상태")
	_check(_game.is_game_over_visible(), "게임오버 UI 표시")
	_check(get_tree().paused, "게임 트리 일시정지")
	var spawned_at_death: int = _game.get_spawner().get_spawned_total()
	get_tree().paused = false
	await _simulate(1.0)
	_check(
		_game.get_spawner().get_spawned_total() == spawned_at_death,
		"게임오버 후 스폰 중단 (%d → %d)" % [spawned_at_death, _game.get_spawner().get_spawned_total()]
	)
	await _stop_game()

func _case_runtime_ability_add() -> void:
	_begin("6. 공격 형태 3종 발동 + 데이터로 정의된 능력 추가")
	await _start_game(false)
	if _game == null:
		return
	var manager: AbilityManager = _game.get_player().get_ability_manager()
	var before: int = manager.get_ability_count()
	var added: bool = manager.add_ability(ContentDB.get_ability("feather_burst"))
	_check(added and manager.get_ability_count() == before + 1, "feather_burst.tres 장착 (%d → %d)" % [before, manager.get_ability_count()])

	# 근접(120px)·투사체(460px) 사거리 안에 정지한 표적을 두어 세 공격 형태를 모두 발동시킨다.
	var player: Player = _game.get_player()
	var target_hp: float = 40.0
	for offset in [Vector2(70.0, 0.0), Vector2(-70.0, 30.0), Vector2(0.0, -80.0)]:
		var animal: Node = _game.get_animal_pool().acquire()
		animal.setup(ContentDB.get_animal("twisted_boar"), player.global_position + offset, player, target_hp, 0.0, 0.0, false)
	await _simulate(3.0)

	var pools: Array[ObjectPool] = _game.get_attack_pools().get_pools()
	var all_used: bool = pools.size() > 0
	for pool in pools:
		_log("    공격 풀 %s: 인스턴스 %d개 / 대여 %d회" % [pool.name, pool.get_total_count(), pool.get_acquire_count()])
		if pool.get_acquire_count() <= 0:
			all_used = false
	_check(pools.size() >= 3, "공격 씬(투사체·근접·장판)별 풀이 자동 생성됨 (%d개)" % pools.size())
	_check(all_used, "생성된 공격 풀이 모두 실제로 사용됨")
	_check(RunState.kills > 0 or _alive_count() > 0, "표적이 유지된 채 공격이 진행됨 (처치 %d)" % RunState.kills)
	await _stop_game()

func _case_stress() -> void:
	_begin("7. 부하 테스트 (동시 적 수 대비 프레임 시간)")
	await _start_game(true)
	if _game == null:
		return
	var pool: ObjectPool = _game.get_animal_pool()
	var player: Player = _game.get_player()
	var max_frame_ms: float = 0.0
	for target_count in [80, 200, 400]:
		while _alive_count() < target_count:
			var animal: Node = pool.acquire()
			if animal == null:
				break
			# 측정 중 죽거나 플레이어를 죽이지 않도록 HP를 크게, 접촉 피해를 0으로 둔다.
			animal.setup(ContentDB.get_animal("spore_ant"), _ring_position(player.global_position), player, 400.0, 1.0, 0.0, false)
		var stage: SimMetrics = SimMetrics.new()
		await _simulate(3.0, stage)
		max_frame_ms = maxf(max_frame_ms, stage.max_frame_ms())
		_log("    동시 적 약 %4d마리 | 평균 프레임 %6.3f ms | 최대 %6.3f ms" % [
			stage.max_alive, stage.avg_frame_ms(), stage.max_frame_ms()
		])
	_check(_alive_count() >= 300, "대량 동시 적 유지 (%d마리)" % _alive_count())
	_check(pool.get_total_count() <= 640, "부하 상황에서도 풀 크기 제한적 (%d개)" % pool.get_total_count())
	_check(max_frame_ms < 50.0, "부하 상황 최대 프레임 시간 %.2f ms < 50 ms (헤드리스=렌더 비용 제외)" % max_frame_ms)
	await _stop_game()

func _ring_position(center: Vector2) -> Vector2:
	var angle: float = randf() * TAU
	return center + Vector2(cos(angle), sin(angle)) * randf_range(260.0, 720.0)

func _case_soak() -> void:
	_begin("8. 소크 테스트 (%.0f초 시뮬레이션)" % _soak_seconds)
	var metrics: SimMetrics = SimMetrics.new()
	var deaths: int = 0
	var total_kills: int = 0
	var best_level: int = 1
	var elapsed: float = 0.0
	var next_sample: float = SOAK_SAMPLE_INTERVAL
	await _start_game(true)
	if _game == null:
		return
	var last: int = Time.get_ticks_usec()
	while elapsed < _soak_seconds:
		await get_tree().process_frame
		var now: int = Time.get_ticks_usec()
		var frame_usec: int = now - last
		last = now
		elapsed += get_process_delta_time()
		var alive: int = _alive_count()
		metrics.record_frame(frame_usec, alive)
		best_level = maxi(best_level, RunState.level)
		if elapsed >= next_sample:
			next_sample += SOAK_SAMPLE_INTERVAL
			metrics.record_sample({
				"time": elapsed,
				"alive": alive,
				"nodes": _node_count(),
				"pickups": _game.get_pickup_manager().get_active_count(),
				"animal_pool": _game.get_animal_pool().get_total_count(),
				"frame_ms": metrics.avg_frame_ms(),
			})
		if RunState.is_game_over:
			deaths += 1
			total_kills += RunState.kills
			get_tree().paused = false
			await _stop_game()
			await _start_game(true)
			last = Time.get_ticks_usec()
			if _game == null:
				break
	total_kills += RunState.kills
	var nodes_end: int = _node_count()
	var pool_total: int = _game.get_animal_pool().get_total_count()
	await _stop_game()
	await _simulate(0.3)
	var nodes_after_free: int = _node_count()
	var orphans: int = int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))

	_log("    시뮬레이션 %.0f초 / 사망 %d회 / 누적 처치 %d / 최고 레벨 %d" % [elapsed, deaths, total_kills, best_level])
	_log("    최대 동시 적 %d마리 / 최대 노드 %d개 / 동물 풀 %d개" % [metrics.max_alive, metrics.max_nodes, pool_total])
	_log("    평균 프레임 %.2f ms / 최대 프레임 %.2f ms / 프레임 %d개" % [metrics.avg_frame_ms(), metrics.max_frame_ms(), metrics.frame_count])
	for line in metrics.sample_lines():
		_log("    " + line)
	for line in metrics.bucket_lines():
		_log("    " + line)
	_check(metrics.frame_count > 0, "소크 시뮬레이션이 실제로 진행됨 (%d 프레임)" % metrics.frame_count)
	_check(nodes_end < NODE_COUNT_CEILING, "노드 수가 상한 미만 유지 (%d < %d)" % [nodes_end, NODE_COUNT_CEILING])
	_check(pool_total <= _baseline_pool_ceiling(), "동물 풀 크기가 상한 내 (%d <= %d)" % [pool_total, _baseline_pool_ceiling()])
	_check(
		nodes_after_free <= _baseline_nodes + 8,
		"게임 씬 해제 후 노드 수 복귀 (기준 %d → %d)" % [_baseline_nodes, nodes_after_free]
	)
	_check(orphans == 0, "고아 노드 0개 (실제 %d개)" % orphans)

# ---------------------------------------------------------------- 유틸

func _baseline_pool_ceiling() -> int:
	return 320

func _start_game(with_autopilot: bool) -> void:
	var packed: PackedScene = load(GAME_SCENE_PATH)
	if packed == null:
		_check(false, "game.tscn 로드 실패")
		return
	_game = packed.instantiate()
	get_tree().root.add_child(_game)
	await get_tree().process_frame
	await get_tree().physics_frame
	if with_autopilot:
		_autopilot = TestAutopilot.new()
		_autopilot.name = "TestAutopilot"
		_autopilot.set_player(_game.get_player())
		get_tree().root.add_child(_autopilot)
		await get_tree().physics_frame

func _stop_game() -> void:
	if _autopilot != null and is_instance_valid(_autopilot):
		_autopilot.release_all()
		_autopilot.queue_free()
	_autopilot = null
	if _game != null and is_instance_valid(_game):
		_game.queue_free()
	_game = null
	get_tree().paused = false
	await get_tree().process_frame
	await get_tree().process_frame

func _simulate(seconds: float, metrics: SimMetrics = null) -> void:
	var elapsed: float = 0.0
	var last: int = Time.get_ticks_usec()
	while elapsed < seconds:
		await get_tree().process_frame
		var now: int = Time.get_ticks_usec()
		var frame_usec: int = now - last
		last = now
		elapsed += get_process_delta_time()
		if metrics != null:
			metrics.record_frame(frame_usec, _alive_count())

func _alive_count() -> int:
	return get_tree().get_nodes_in_group("animal").size()

func _node_count() -> int:
	return int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))

func _begin(title: String) -> void:
	_log("")
	_log("[CASE] %s" % title)

func _check(condition: bool, message: String) -> void:
	if condition:
		_passed += 1
		_log("  [PASS] %s" % message)
	else:
		_failed += 1
		_failures.append(message)
		_log("  [FAIL] %s" % message)

func _log(message: String) -> void:
	print(message)
