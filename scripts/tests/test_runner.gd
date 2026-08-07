extends Node
## 경량 자체 시뮬레이션 테스트 러너 (외부 플러그인 없음, 테스트 전용).
## 헤드리스로 게임 씬을 실제로 돌리며 핵심 시스템을 검증하고, 실패 시 종료코드 1로 끝난다.
##
## 실행 예:
##   godot_console.exe --headless --fixed-fps 60 --path <프로젝트> res://scenes/tests/test_runner.tscn -- --combat=90 --soak=180

const GAME_SCENE_PATH: String = "res://scenes/main/game.tscn"
const SOAK_SAMPLE_INTERVAL: float = 15.0
## 소크 테스트에서 노드 수가 이 값을 넘으면 누수로 간주한다.
const NODE_COUNT_CEILING: int = 4000
## UI 반복 개폐 후 허용하는 노드 수 증가분.
const UI_NODE_TOLERANCE: int = 4
const UI_CYCLES: int = 25
## 화면 흔들림을 반복해도 카메라 오프셋이 정확히 0으로 돌아오는지 볼 횟수.
const SHAKE_CYCLES: int = 6
## 대량 사망 최악 조건에서 한 번에 죽이는 적 수.
const MASS_DEATH_COUNT: int = 400
## 오디오 폴리포니 검증에서 한 프레임에 몰아 넣는 재생 요청 수.
const AUDIO_BURST_REQUESTS: int = 300

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
var _mutations_acquired: Array[String] = []
var _synergy_events: Array[String] = []
var _purchase_events: int = 0
var _refused_events: int = 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_parse_args()
	EventBus.essence_collected.connect(func(value: int) -> void: _essence_gained += value)
	EventBus.player_leveled_up.connect(func(_level: int) -> void: _level_ups += 1)
	EventBus.player_health_changed.connect(func(current: float, maximum: float) -> void: _last_health = Vector2(current, maximum))
	EventBus.mutation_acquired.connect(func(data: MutationData) -> void: _mutations_acquired.append(data.id))
	EventBus.synergy_activated.connect(
		func(lineage: String, tier: int, description: String) -> void:
			_synergy_events.append("%s %d단 (%s)" % [lineage, tier, description])
	)
	EventBus.shop_purchased.connect(func(_data: MutationData, _cost: int) -> void: _purchase_events += 1)
	EventBus.shop_purchase_failed.connect(func(_data: MutationData, _cost: int) -> void: _refused_events += 1)
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
	await _case_mutation_cards()
	await _case_shop()
	await _case_synergy()
	await _case_ui_churn()
	await _case_hit_feedback()
	await _case_camera_shake()
	await _case_hit_stop()
	await _case_death_effect_pool()
	await _case_audio()
	await _case_mass_death()
	await _case_sprite_pipeline()
	if _run_soak:
		await _case_soak()

	_log("")
	_log("=== 결과: %d개 통과 / %d개 실패 (총 %.1fs) ===" % [_passed, _failed, float(Time.get_ticks_msec() - wall_start) / 1000.0])
	for failure in _failures:
		_log("  실패: %s" % failure)
	_log("RESULT %s" % ("PASS" if _failed == 0 else "FAIL"))
	await _drain_audio()
	get_tree().quit(0 if _failed == 0 else 1)

## 재생 중인 효과음을 끊고 몇 프레임 돌려 오디오 서버가 플레이백을 정리하게 한다.
## (그냥 종료하면 엔진이 "ObjectDB instances leaked" 경고를 남긴다.)
func _drain_audio() -> void:
	var audio: Node = get_node_or_null("/root/AudioManager")
	if audio == null:
		return
	audio.stop_all()
	for _i in 8:
		await get_tree().process_frame

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
	_check(_game.get_mutation_card_screen() != null, "MutationCards UI 존재")
	_check(_game.get_shop_screen() != null, "ShopScreen UI 존재")
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
	_check(RunState.get_lineage_count("포식") >= 1, "시작 능력의 계통이 집계됨 (포식 %d)" % RunState.get_lineage_count("포식"))
	await _stop_game()

func _case_content_db() -> void:
	_begin("2. ContentDB 데이터 로드")
	var abilities: Array = ContentDB.get_ability_ids()
	var animals: Array = ContentDB.get_animal_ids()
	var waves: Array[WaveData] = ContentDB.get_waves()
	var mutations: Array[MutationData] = ContentDB.get_mutations()
	var synergies: Array[LineageSynergyData] = ContentDB.get_synergies()
	_check(abilities.size() >= 4, "능력 .tres %d종 로드" % abilities.size())
	_check(animals.size() >= 5, "동물 .tres %d종 로드" % animals.size())
	_check(waves.size() >= 5, "웨이브 .tres %d개 로드" % waves.size())
	_check(mutations.size() >= 12, "변이 .tres %d종 로드" % mutations.size())
	_check(synergies.size() >= 2, "계통 시너지 .tres %d개 로드" % synergies.size())
	_check(ContentDB.get_animal("spore_ant") != null, "id로 동물 조회 가능")
	_check(ContentDB.get_ability("claw_swipe") != null, "id로 능력 조회 가능")
	_check(ContentDB.get_mutation("mut_sharp_claws") != null, "id로 변이 조회 가능")
	_check(ContentDB.get_animal("존재하지_않는_id") == null, "없는 id 조회 시 크래시 없이 null")
	_check(ContentDB.get_mutation("없는_변이") == null, "없는 변이 id 조회 시 null")
	var ordered: bool = true
	for i in range(1, waves.size()):
		if waves[i].index < waves[i - 1].index:
			ordered = false
	_check(ordered, "웨이브가 index 순으로 정렬됨")
	var payload_ok: bool = true
	for mutation in mutations:
		if mutation.payload.is_empty() or mutation.display_name.is_empty():
			payload_ok = false
			_log("    비어 있는 변이: %s" % mutation.id)
	_check(payload_ok, "모든 변이가 이름과 payload를 가짐")

func _case_combat() -> void:
	_begin("3. 전투 시뮬레이션 (%.0f초, 오토파일럿 카이팅 + 카드/상점 자동 처리)" % _combat_seconds)
	_essence_gained = 0
	_level_ups = 0
	_mutations_acquired.clear()
	_purchase_events = 0
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
	_check(
		RunState.get_mutation_total() >= _autopilot.cards_chosen and _autopilot.cards_chosen > 0,
		"레벨업 카드 자동 선택 %d회 → 변이 %d개 보유" % [_autopilot.cards_chosen, RunState.get_mutation_total()]
	)
	_check(_autopilot.shops_seen > 0, "웨이브 사이 상점이 %d회 열림" % _autopilot.shops_seen)
	_check(RunState.wave_index >= 2, "상점을 닫은 뒤 다음 웨이브로 진행 (현재 웨이브 %d)" % RunState.wave_index)
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
	_log("    자동 선택 변이: %s" % ", ".join(_mutations_acquired))
	_log("    상점 %d회 / 구매 %d개 / 리롤 %d회 / 사용한 먹이 %d" % [
		_autopilot.shops_seen, _autopilot.items_bought, _autopilot.rerolls, RunState.feed_spent
	])
	if not _synergy_events.is_empty():
		_log("    발동한 시너지: %s" % ", ".join(_synergy_events))
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

func _case_mutation_cards() -> void:
	_begin("8. 레벨업 3택 변이 카드")
	await _start_game(false, false)
	if _game == null:
		return
	var cards: MutationCardScreen = _game.get_mutation_card_screen()
	var manager: AbilityManager = _game.get_player().get_ability_manager()
	var spawner: AnimalSpawner = _game.get_spawner()
	_check(not cards.is_open(), "시작 시 카드 UI 닫혀 있음")
	_check(not get_tree().paused, "시작 시 게임이 진행 중")

	RunState.add_xp(RunState.xp_to_next)
	await _simulate(0.1)
	_check(cards.is_open(), "레벨업 시 변이 카드 UI 표시")
	var options: Array[MutationData] = cards.get_options()
	_check(options.size() == 3, "선택지 3개 제시 (실제 %d개)" % options.size())
	var unique_ids: Dictionary = {}
	var names: Array[String] = []
	for option in options:
		unique_ids[option.id] = true
		names.append(option.display_name)
	_check(unique_ids.size() == options.size(), "선택지 %d개가 서로 중복 없음: %s" % [options.size(), ", ".join(names)])
	_check(get_tree().paused, "카드 표시 중 게임 일시정지")
	var spawned_at_pause: int = spawner.get_spawned_total()
	var kills_at_pause: int = RunState.kills
	await _simulate(0.5)
	_check(
		spawner.get_spawned_total() == spawned_at_pause and RunState.kills == kills_at_pause,
		"일시정지 중 스폰·전투 정지 (스폰 %d 고정)" % spawned_at_pause
	)

	var chosen: MutationData = options[0]
	var before: String = _stat_signature()
	_check(cards.choose(0), "카드 선택 처리 성공 ('%s')" % chosen.display_name)
	await _simulate(0.1)
	_check(_stat_signature() != before, "선택한 변이의 효과가 런 상태에 반영됨")
	_check(RunState.get_mutation_count(chosen.id) >= 1, "선택한 변이가 보유 목록에 기록됨")
	_check(not cards.is_open(), "선택 후 카드 UI 닫힘")
	_check(not get_tree().paused, "선택 후 게임 정상 재개")
	# 웨이브 1의 스폰 간격(1.2초)보다 길게 돌려 스폰이 다시 도는지 본다.
	await _simulate(2.0)
	_check(spawner.get_spawned_total() > spawned_at_pause, "재개 후 스폰 재개 (%d → %d)" % [spawned_at_pause, spawner.get_spawned_total()])

	# 수치 검증: payload 가 정확히 반영되는지 알려진 변이로 확인한다.
	var damage_before: float = RunState.damage_mult
	var applied: bool = RunState.apply_mutation(ContentDB.get_mutation("mut_sharp_claws"))
	_check(
		applied and is_equal_approx(RunState.damage_mult, damage_before + 0.15),
		"STAT 변이(날카로운 발톱) 적용: 데미지 배율 %.2f → %.2f (+0.15 기대)" % [damage_before, RunState.damage_mult]
	)
	var graft: MutationData = _unowned_ability_mutation()
	var abilities_before: int = manager.get_ability_count()
	if graft != null:
		RunState.apply_mutation(graft)
		await _simulate(0.05)
		_check(
			manager.get_ability_count() == abilities_before + 1,
			"NEW_ABILITY 변이(%s)로 능력 슬롯 %d → %d" % [graft.display_name, abilities_before, manager.get_ability_count()]
		)
	else:
		_check(false, "테스트용 미보유 능력 변이를 찾지 못함")

	# 여러 레벨이 한 번에 오르면 카드가 순차로 제시되어야 한다.
	RunState.add_xp(RunState.xp_to_next * 4)
	await _simulate(0.1)
	_check(cards.is_open(), "다중 레벨업 시 카드 표시")
	_check(cards.get_pending_count() >= 1, "남은 카드가 큐에 대기 (%d개)" % cards.get_pending_count())
	var resolved: int = 0
	while cards.is_open() and resolved < 12:
		cards.choose(0)
		resolved += 1
		await _simulate(0.05)
	_check(resolved >= 2, "대기 카드가 순차로 제시되어 %d회 선택됨" % resolved)
	_check(not get_tree().paused, "모든 카드 처리 후 게임 재개")
	await _stop_game()

func _case_shop() -> void:
	_begin("9. 웨이브 사이 소굴 상점")
	await _start_game(false, false)
	if _game == null:
		return
	var shop: ShopScreen = _game.get_shop_screen()
	var manager: AbilityManager = _game.get_player().get_ability_manager()
	_check(not shop.is_open(), "시작 시 상점 닫혀 있음")

	RunState.feed = 80
	EventBus.wave_ended.emit(RunState.wave_index)
	await _simulate(0.1)
	_check(shop.is_open(), "웨이브 종료 시 상점 열림")
	_check(get_tree().paused, "상점 표시 중 게임 일시정지")
	var offers: Array[MutationData] = shop.get_offers()
	var offer_ids: Dictionary = {}
	var costs_ok: bool = true
	for i in offers.size():
		if offers[i] == null:
			continue
		offer_ids[offers[i].id] = true
		if shop.get_cost(i) <= 0:
			costs_ok = false
	_check(offers.size() == 4, "상품 4칸 구성 (실제 %d칸)" % offers.size())
	_check(offer_ids.size() == offers.size(), "상품이 서로 중복 없음 (%d종)" % offer_ids.size())
	_check(costs_ok, "모든 상품에 가격이 매겨짐")

	var target: MutationData = offers[0]
	var cost: int = shop.get_cost(0)
	var feed_before: int = RunState.feed
	var mutations_before: int = RunState.get_mutation_total()
	var abilities_before: int = manager.get_ability_count()
	_check(shop.buy(0), "충분한 먹이로 '%s' 구매 성공 (%d 먹이)" % [target.display_name, cost])
	await _simulate(0.05)
	_check(RunState.feed == feed_before - cost, "구매 시 재화 차감 (%d → %d)" % [feed_before, RunState.feed])
	_check(RunState.get_mutation_total() == mutations_before + 1, "구매한 변이가 실제로 추가됨 (%d → %d)" % [mutations_before, RunState.get_mutation_total()])
	if target.kind == MutationData.Kind.NEW_ABILITY:
		_check(manager.get_ability_count() == abilities_before + 1, "능력 상품 구매 시 능력 슬롯 증가")
	else:
		_check(manager.get_ability_count() == abilities_before, "스탯 상품 구매 시 능력 슬롯 유지")
	_check(shop.get_offers()[0] == null, "구매한 칸이 품절 처리됨")

	# 재화 부족 시 거부
	RunState.feed = 0
	var refused_before: int = _refused_events
	var mutations_now: int = RunState.get_mutation_total()
	var next_index: int = _first_available_offer(shop)
	_check(next_index >= 0, "구매 가능한 다음 상품 칸 존재")
	if next_index >= 0:
		_check(not shop.buy(next_index), "먹이 0일 때 구매 거부됨")
		_check(RunState.get_mutation_total() == mutations_now, "거부 시 변이가 추가되지 않음")
		_check(RunState.feed == 0, "거부 시 재화 변동 없음")
		_check(_refused_events == refused_before + 1, "구매 실패 시그널 발행")
		_check(shop.get_offers()[next_index] != null, "거부된 상품은 그대로 남아 있음")

	# 리롤(비용 점증)
	RunState.feed = 60
	var reroll_cost: int = shop.get_reroll_cost()
	var feed_at_reroll: int = RunState.feed
	_check(shop.reroll(), "리롤 성공 (%d 먹이)" % reroll_cost)
	_check(RunState.feed == feed_at_reroll - reroll_cost, "리롤 비용 차감 (%d → %d)" % [feed_at_reroll, RunState.feed])
	_check(shop.get_reroll_cost() > reroll_cost, "리롤 비용 점증 (%d → %d)" % [reroll_cost, shop.get_reroll_cost()])
	var refilled: int = 0
	for offer in shop.get_offers():
		if offer != null:
			refilled += 1
	_check(refilled == 4, "리롤 후 상품 4칸 재구성 (%d칸)" % refilled)

	shop.close()
	await _simulate(0.1)
	_check(not shop.is_open(), "상점 닫힘")
	_check(not get_tree().paused, "상점을 닫으면 전투 재개")
	await _stop_game()

func _case_synergy() -> void:
	_begin("10. 계통 시너지 발동")
	_synergy_events.clear()
	await _start_game(false, false)
	if _game == null:
		return
	var predator_start: int = RunState.get_lineage_count("포식")
	_check(predator_start >= 2, "시작 능력으로 포식 계통 %d개 보유" % predator_start)
	_check(RunState.get_synergy_tier("포식") == 0, "임계값 미만에서는 시너지 미발동")

	var crit_before: float = RunState.crit_chance
	var guard: int = 0
	while RunState.get_lineage_count("포식") < 3 and guard < 6:
		RunState.apply_mutation(ContentDB.get_mutation("mut_sharp_claws"))
		guard += 1
	_check(RunState.get_lineage_count("포식") >= 3, "포식 계통 %d개 확보" % RunState.get_lineage_count("포식"))
	_check(RunState.get_synergy_tier("포식") >= 1, "포식 3개 → 1단 세트 보너스 발동")
	_check(
		RunState.crit_chance >= crit_before + 0.12 - 0.0001,
		"1단 보너스 수치 반영: 크리 확률 %.2f → %.2f (+0.12 기대)" % [crit_before, RunState.crit_chance]
	)
	_check(not _synergy_events.is_empty(), "synergy_activated 시그널 수신: %s" % ", ".join(_synergy_events))

	var heal_before: float = RunState.heal_on_kill
	guard = 0
	while RunState.get_lineage_count("포식") < 5 and guard < 8:
		if not RunState.apply_mutation(ContentDB.get_mutation("mut_sharp_claws")):
			RunState.apply_mutation(ContentDB.get_mutation("mut_bloodlust"))
		guard += 1
	_check(RunState.get_synergy_tier("포식") >= 2, "포식 5개 → 2단 세트 보너스 발동 (계통 %d개)" % RunState.get_lineage_count("포식"))
	_check(RunState.heal_on_kill > heal_before, "2단 보너스 수치 반영: 처치 회복 %.2f → %.2f" % [heal_before, RunState.heal_on_kill])

	# 두 번째 계통(방어)도 독립적으로 발동해야 한다.
	var armor_before: float = RunState.armor
	guard = 0
	while RunState.get_lineage_count("방어") < 3 and guard < 8:
		if not RunState.apply_mutation(ContentDB.get_mutation("mut_thick_hide")):
			RunState.apply_mutation(ContentDB.get_mutation("mut_chitin_plate"))
		guard += 1
	_check(RunState.get_synergy_tier("방어") >= 1, "방어 3개 → 1단 세트 보너스 발동 (계통 %d개)" % RunState.get_lineage_count("방어"))
	_check(RunState.armor > armor_before, "방어 보너스 반영: 피해 감소 %.2f → %.2f" % [armor_before, RunState.armor])
	_log("    발동 이력: %s" % ", ".join(_synergy_events))
	await _stop_game()

func _case_ui_churn() -> void:
	_begin("11. 카드·상점 %d회 반복 개폐 (UI 노드 누수)" % UI_CYCLES)
	await _start_game(false, false)
	if _game == null:
		return
	var cards: MutationCardScreen = _game.get_mutation_card_screen()
	var shop: ShopScreen = _game.get_shop_screen()
	await _simulate(0.2)
	var nodes_before: int = _node_count()
	var opened_cards: int = 0
	var opened_shops: int = 0
	for _i in UI_CYCLES:
		RunState.add_xp(RunState.xp_to_next)
		await get_tree().process_frame
		if cards.is_open():
			opened_cards += 1
			var safety: int = 0
			while cards.is_open() and safety < 8:
				cards.choose(0)
				safety += 1
				await get_tree().process_frame
		RunState.feed = 40
		EventBus.wave_ended.emit(RunState.wave_index)
		await get_tree().process_frame
		if shop.is_open():
			opened_shops += 1
			shop.buy(0)
			shop.close()
		await get_tree().process_frame
	await _simulate(0.3)
	var nodes_after: int = _node_count()
	var orphans: int = int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	_check(opened_cards >= UI_CYCLES - 2, "카드 UI가 %d/%d회 정상적으로 열림" % [opened_cards, UI_CYCLES])
	_check(opened_shops >= UI_CYCLES - 2, "상점 UI가 %d/%d회 정상적으로 열림" % [opened_shops, UI_CYCLES])
	_check(
		nodes_after <= nodes_before + UI_NODE_TOLERANCE,
		"UI 반복 개폐 후 노드 수 유지 (%d → %d, 허용 +%d)" % [nodes_before, nodes_after, UI_NODE_TOLERANCE]
	)
	_check(orphans == 0, "UI 반복 개폐 후 고아 노드 0개 (실제 %d개)" % orphans)
	_check(not get_tree().paused, "반복 개폐 후 일시정지 상태가 남지 않음")
	_log("    보유 변이 %d개 / 구매 %d회 / 발동 시너지 %d건" % [
		RunState.get_mutation_total(), RunState.purchases, _synergy_events.size()
	])
	await _stop_game()

func _case_hit_feedback() -> void:
	_begin("12. 히트 플래시 · 넉백 (피격 시각/물리 피드백)")
	await _start_game(false, false)
	if _game == null:
		return
	var player: Player = _game.get_player()
	# 능력 사거리(최대 460px) 밖에 세워 두면 플레이어 공격이 끼어들지 않아 측정이 깨끗하다.
	var dummies: Array[Animal] = _spawn_dummies(1, 900.0)
	if dummies.is_empty():
		_check(false, "테스트용 동물을 풀에서 얻지 못함")
		return
	var animal: Animal = dummies[0]
	await _simulate(0.1)
	var base_color: Color = animal.get_base_color()
	_check(animal.get_sprite_color().is_equal_approx(base_color), "피격 전에는 데이터에 정의된 색 (%s)" % _color_text(base_color))

	var pos_before: Vector2 = animal.global_position
	animal.take_damage(3.0, Vector2.RIGHT)
	_check(animal.is_hit_flashing(), "피격 직후 히트 플래시 활성")
	_check(
		not animal.get_sprite_color().is_equal_approx(base_color),
		"플래시 중 색이 바뀜 (%s → %s)" % [_color_text(base_color), _color_text(animal.get_sprite_color())]
	)
	await _simulate(0.4)
	_check(not animal.is_hit_flashing(), "%.2fs 후 플래시 종료" % animal.hit_flash_duration)
	_check(animal.get_sprite_color().is_equal_approx(base_color), "플래시 후 원래 색으로 정확히 복귀")

	var moved: Vector2 = animal.global_position - pos_before
	_check(moved.x > 4.0, "넉백으로 피격 방향(+X)으로 %.1fpx 이동" % moved.x)
	_check(absf(moved.y) < absf(moved.x) * 0.5, "넉백 방향이 피격 방향과 일치 (dx=%.1f dy=%.1f)" % [moved.x, moved.y])
	_check(moved.length() < 80.0, "넉백이 과하지 않음 (%.1fpx < 80px)" % moved.length())
	var settled: Vector2 = animal.global_position
	await _simulate(0.5)
	_check(
		animal.global_position.distance_to(settled) < 1.0,
		"넉백이 감쇠해 멈춤 (이후 추가 이동 %.2fpx)" % animal.global_position.distance_to(settled)
	)

	# 반대 방향으로 때리면 반대로 밀려야 한다.
	var before_left: Vector2 = animal.global_position
	animal.take_damage(3.0, Vector2.LEFT)
	await _simulate(0.4)
	_check(animal.global_position.x < before_left.x - 4.0, "반대 방향 피격 시 반대로 밀림 (dx=%.1f)" % (animal.global_position.x - before_left.x))

	# 방향 인자가 없으면(장판 등) 넉백 없이 플래시만.
	var before_none: Vector2 = animal.global_position
	animal.take_damage(3.0)
	_check(animal.is_hit_flashing(), "방향 없는 피격도 플래시는 발생")
	await _simulate(0.3)
	_check(
		animal.global_position.distance_to(before_none) < 1.0,
		"방향 없는 피격은 넉백 없음 (이동 %.2fpx)" % animal.global_position.distance_to(before_none)
	)

	# 플레이어 무적 프레임 동안 스프라이트 알파가 실제로 오르내려야 한다.
	var alphas: Dictionary = {}
	player.take_damage(4.0)
	_check(player.is_invulnerable(), "피격 후 무적 프레임 진입")
	for _i in 30:
		await get_tree().physics_frame
		alphas[snappedf(player.get_sprite_alpha(), 0.01)] = true
	_check(alphas.size() >= 2, "무적 프레임 동안 알파가 %d단계로 깜빡임" % alphas.size())
	await _simulate(1.0)
	_check(not player.is_invulnerable(), "무적 프레임 종료")
	_check(is_equal_approx(player.get_sprite_alpha(), 1.0), "무적 종료 후 알파 1.0 복귀 (%.2f)" % player.get_sprite_alpha())
	await _stop_game()

func _case_camera_shake() -> void:
	_begin("13. 화면 흔들림 후 카메라 오프셋 0 복귀")
	await _start_game(false, false)
	if _game == null:
		return
	var player: Player = _game.get_player()
	var camera: CameraShake = player.get_camera()
	_check(camera != null, "플레이어 카메라에 CameraShake 적용")
	if camera == null:
		return
	_check(camera.offset == Vector2.ZERO, "시작 시 오프셋 0")

	player.take_damage(6.0)
	_check(camera.is_shaking(), "플레이어 피격 시 흔들림 시작 (EventBus.player_hit 구독)")
	var max_offset: float = 0.0
	for _i in 8:
		await get_tree().process_frame
		max_offset = maxf(max_offset, camera.offset.length())
	_check(max_offset > 0.0, "흔들림 중 오프셋이 실제로 움직임 (최대 %.2fpx)" % max_offset)
	_check(max_offset <= camera.max_strength * 1.5, "흔들림 폭이 상한 내 (%.2f <= %.2f)" % [max_offset, camera.max_strength * 1.5])
	await _simulate(1.0)
	_check(camera.offset == Vector2.ZERO, "흔들림 종료 후 오프셋 정확히 0 (%s)" % str(camera.offset))

	# 반복 흔들림 후에도 매번 정확히 0이어야 한다(누적 드리프트 금지).
	var drift_failures: int = 0
	var worst: Vector2 = Vector2.ZERO
	for _i in SHAKE_CYCLES:
		camera.shake(9.0, 0.15)
		await _simulate(0.5)
		if camera.offset != Vector2.ZERO:
			drift_failures += 1
			worst = camera.offset
	_check(
		drift_failures == 0,
		"%d회 반복 흔들림 후에도 매번 오프셋 0 (실패 %d회, 최악 %s)" % [SHAKE_CYCLES, drift_failures, str(worst)]
	)

	# 흔들리는 중 일시정지 UI가 열리면 오프셋이 남지 않아야 한다(_process 가 멈추므로).
	var cards: MutationCardScreen = _game.get_mutation_card_screen()
	camera.shake(10.0, 0.8)
	await get_tree().process_frame
	RunState.add_xp(RunState.xp_to_next)
	await get_tree().process_frame
	_check(cards.is_open(), "카드 UI 열림")
	_check(camera.offset == Vector2.ZERO and not camera.is_shaking(), "카드 진입 시 흔들림 초기화 (오프셋 %s)" % str(camera.offset))
	cards.choose(0)
	await _simulate(0.2)
	_check(not get_tree().paused and camera.offset == Vector2.ZERO, "카드 처리 후 재개 + 오프셋 0 유지")
	await _stop_game()

func _case_hit_stop() -> void:
	_begin("14. 히트스톱과 카드·상점 일시정지 로직의 공존")
	_check(is_equal_approx(Engine.time_scale, 1.0), "케이스 시작 시 time_scale 1.0")
	await _start_game(false, false)
	if _game == null:
		return
	var hit_stop: HitStop = _game.get_hit_stop()
	var player: Player = _game.get_player()
	var cards: MutationCardScreen = _game.get_mutation_card_screen()
	var shop: ShopScreen = _game.get_shop_screen()
	_check(hit_stop != null, "HitStop 노드 존재")
	if hit_stop == null:
		return
	_check(hit_stop.enabled, "히트스톱 활성 상태로 구성됨 (%.3fs · 배율 %.2f)" % [hit_stop.duration, hit_stop.slow_time_scale])

	player.take_damage(5.0)
	_check(hit_stop.is_active(), "플레이어 피격 시 히트스톱 발동")
	_check(Engine.time_scale < 1.0, "히트스톱 중 time_scale 감소 (%.3f)" % Engine.time_scale)
	await _simulate(0.5)
	_check(not hit_stop.is_active(), "히트스톱 자동 종료")
	_check(is_equal_approx(Engine.time_scale, 1.0), "히트스톱 후 time_scale 1.0 복귀 (%.3f)" % Engine.time_scale)

	# 히트스톱 중 레벨업 카드가 뜨면 시간 배율은 즉시 정상으로, 일시정지는 카드 로직이 담당한다.
	hit_stop.trigger()
	RunState.add_xp(RunState.xp_to_next)
	await get_tree().process_frame
	_check(cards.is_open(), "히트스톱 중에도 카드 UI 정상 표시")
	_check(is_equal_approx(Engine.time_scale, 1.0), "카드 진입 시 히트스톱 해제 (time_scale %.3f)" % Engine.time_scale)
	_check(get_tree().paused, "카드 표시 중 기존 일시정지 유지")
	cards.choose(0)
	await _simulate(0.2)
	_check(not get_tree().paused, "카드 선택 후 정상 재개")
	_check(is_equal_approx(Engine.time_scale, 1.0), "카드 선택 후 time_scale 1.0")

	# 상점도 동일해야 한다.
	hit_stop.trigger()
	RunState.feed = 40
	EventBus.wave_ended.emit(RunState.wave_index)
	await get_tree().process_frame
	_check(shop.is_open(), "히트스톱 중에도 상점 정상 표시")
	_check(is_equal_approx(Engine.time_scale, 1.0), "상점 진입 시 히트스톱 해제")
	_check(get_tree().paused, "상점 표시 중 일시정지 유지")
	shop.close()
	await _simulate(0.2)
	_check(not get_tree().paused and is_equal_approx(Engine.time_scale, 1.0), "상점 종료 후 재개 + time_scale 1.0")

	# 히트스톱이 걸린 채 씬이 사라져도 전역 time_scale 은 반드시 복구된다.
	hit_stop.trigger()
	await _stop_game()
	_check(is_equal_approx(Engine.time_scale, 1.0), "게임 씬 해제 후 time_scale 복귀 (%.3f)" % Engine.time_scale)

func _case_death_effect_pool() -> void:
	_begin("15. 사망 이펙트 · 데미지 숫자 풀링")
	await _start_game(false, false)
	if _game == null:
		return
	var effects: EffectManager = _game.get_effect_manager()
	_check(effects != null, "EffectManager 존재")
	if effects == null:
		return
	var burst_pool: ObjectPool = effects.get_burst_pool()
	var number_pool: ObjectPool = effects.get_number_pool()
	_check(burst_pool != null and number_pool != null, "사망 이펙트·데미지 숫자 풀 존재")
	var acquire_before: int = burst_pool.get_acquire_count()
	var number_acquire_before: int = number_pool.get_acquire_count()
	var nodes_before: int = _node_count()

	# 60마리를 세 번 몰살시켜 이펙트가 계속 재사용되는지 본다.
	var killed: int = 0
	for _batch in 3:
		for animal in _spawn_dummies(60, 900.0):
			animal.take_damage(999999.0, Vector2.RIGHT)
			killed += 1
		await _simulate(0.6)
	var burst_acquires: int = burst_pool.get_acquire_count() - acquire_before
	var number_acquires: int = number_pool.get_acquire_count() - number_acquire_before
	_check(killed >= 150, "%d마리 몰살 처리" % killed)
	_check(burst_acquires > 0, "사망 이펙트가 %d회 대여됨" % burst_acquires)
	_check(
		burst_acquires > burst_pool.get_total_count(),
		"사망 이펙트 재사용 확인 (대여 %d회 > 인스턴스 %d개)" % [burst_acquires, burst_pool.get_total_count()]
	)
	_check(
		burst_pool.get_total_count() <= effects.max_active_bursts,
		"사망 이펙트 풀이 상한 내 (%d <= %d)" % [burst_pool.get_total_count(), effects.max_active_bursts]
	)
	_check(number_acquires > 0, "데미지 숫자가 %d회 대여됨" % number_acquires)
	_check(
		number_pool.get_total_count() <= effects.max_active_numbers,
		"데미지 숫자 풀이 상한 내 (%d <= %d)" % [number_pool.get_total_count(), effects.max_active_numbers]
	)
	await _simulate(1.2)
	_check(effects.get_active_burst_count() == 0, "수명이 끝난 사망 이펙트 전부 반환 (활성 %d개)" % effects.get_active_burst_count())
	_check(effects.get_active_number_count() == 0, "수명이 끝난 데미지 숫자 전부 반환 (활성 %d개)" % effects.get_active_number_count())
	_log("    이펙트 노드: 사망 %d개 / 숫자 %d개 (노드 총계 %d → %d)" % [
		burst_pool.get_total_count(), number_pool.get_total_count(), nodes_before, _node_count()
	])
	await _stop_game()

func _case_audio() -> void:
	_begin("16. 효과음 재생 · 오디오 플레이어 폴리포니")
	var audio: Node = get_node_or_null("/root/AudioManager")
	_check(audio != null, "AudioManager 오토로드 존재")
	if audio == null:
		return
	var required: PackedStringArray = ["shoot", "hit", "kill", "player_hurt", "pickup", "level_up", "buy", "game_over"]
	var missing: Array[String] = []
	for sfx_id in required:
		if not audio.has_stream(sfx_id):
			missing.append(sfx_id)
	_check(missing.is_empty(), "필요한 효과음 %d종 모두 로드 (누락: %s)" % [required.size(), "없음" if missing.is_empty() else ", ".join(missing)])
	var voices: int = audio.get_voice_count()
	_check(voices == audio.max_voices, "오디오 플레이어가 %d개로 고정 생성" % voices)

	# 폴리포니: 한 프레임에 수백 번 요청해도 오디오 노드가 늘지 않아야 한다.
	# 헤드리스는 기본적으로 출력이 꺼져 있으니 이 구간만 실제 재생을 켜서 목소리 재사용까지 본다.
	var playback_was_enabled: bool = audio.playback_enabled
	audio.playback_enabled = true
	var nodes_before: int = _node_count()
	for _i in AUDIO_BURST_REQUESTS:
		audio.play("hit", 0.0)
	await _simulate(0.3)
	_check(_node_count() <= nodes_before, "%d회 연속 재생 요청 후 노드 수 유지 (%d → %d)" % [AUDIO_BURST_REQUESTS, nodes_before, _node_count()])
	_check(audio.get_voice_count() == voices, "요청 폭주 후에도 오디오 플레이어 수 불변 (%d개)" % audio.get_voice_count())
	_check(
		audio.get_playing_voice_count() <= voices,
		"동시 재생이 폴리포니 상한 이하 (%d <= %d)" % [audio.get_playing_voice_count(), voices]
	)
	audio.stop_all()
	audio.playback_enabled = playback_was_enabled

	# 실제 전투에서 발사·피격·처치 효과음이 트리거되는지.
	await _start_game(true)
	if _game == null:
		return
	audio.reset_play_counts()
	# 적은 화면 밖(780px)에서 스폰되므로 사거리(460px) 안으로 들어올 시간을 준다.
	await _simulate(8.0)
	_check(audio.get_play_count("shoot") > 0, "능력 발동 시 발사 효과음 %d회" % audio.get_play_count("shoot"))
	_check(audio.get_play_count("hit") > 0, "적 피격 시 피격 효과음 %d회" % audio.get_play_count("hit"))
	if audio.get_play_count("kill") == 0:
		for animal in _spawn_dummies(3, 900.0):
			animal.take_damage(999999.0)
		await _simulate(0.2)
	_check(audio.get_play_count("kill") > 0, "적 사망 시 처치 효과음 %d회" % audio.get_play_count("kill"))

	var hurt_before: int = audio.get_play_count("player_hurt")
	_game.get_player().take_damage(3.0)
	await _simulate(0.2)
	_check(audio.get_play_count("player_hurt") > hurt_before, "플레이어 피격 효과음 재생 (%d회)" % audio.get_play_count("player_hurt"))

	var pickup_before: int = audio.get_play_count("pickup")
	await _simulate(0.2)
	EventBus.feed_collected.emit(1)
	await _simulate(0.1)
	_check(audio.get_play_count("pickup") > pickup_before, "아이템/젬 획득 효과음 재생 (%d회)" % audio.get_play_count("pickup"))

	var level_before: int = audio.get_play_count("level_up")
	RunState.add_xp(RunState.xp_to_next)
	await _simulate(0.2)
	_check(audio.get_play_count("level_up") > level_before, "레벨업 효과음 재생 (%d회)" % audio.get_play_count("level_up"))

	# 상점 구매는 오토파일럿을 잠시 끄고 직접 구매해 확인한다.
	_autopilot.auto_resolve_ui = false
	var shop: ShopScreen = _game.get_shop_screen()
	var buy_before: int = audio.get_play_count("buy")
	RunState.feed = 90
	EventBus.wave_ended.emit(RunState.wave_index)
	await _simulate(0.2)
	# 중복 상한에 걸린 상품이 있을 수 있으니 살 수 있는 칸을 찾아 구매한다.
	var bought: bool = false
	if shop.is_open():
		for i in shop.get_offers().size():
			if shop.get_offers()[i] != null and shop.buy(i):
				bought = true
				break
	await _simulate(0.1)
	_check(bought, "상점에서 실제 구매 성공")
	_check(audio.get_play_count("buy") > buy_before, "상점 구매 효과음 재생 (%d회)" % audio.get_play_count("buy"))
	shop.close()
	await _simulate(0.1)
	_autopilot.auto_resolve_ui = true

	var over_before: int = audio.get_play_count("game_over")
	_game.get_player().take_damage(_game.get_player().get_max_health() * 10.0)
	await _simulate(0.2)
	_check(audio.get_play_count("game_over") > over_before, "게임오버 효과음 재생 (%d회)" % audio.get_play_count("game_over"))

	_check(audio.get_voice_count() == voices, "전체 이벤트 재생 후에도 오디오 노드 %d개 유지" % audio.get_voice_count())
	_log("    효과음 재생 횟수: %s" % _audio_count_text(audio, required))
	get_tree().paused = false
	await _stop_game()

func _case_mass_death() -> void:
	_begin("17. 대량 사망 최악 조건 (이펙트·오디오 동시 부하)")
	await _start_game(true)
	if _game == null:
		return
	var audio: Node = get_node_or_null("/root/AudioManager")
	var effects: EffectManager = _game.get_effect_manager()
	var pool: ObjectPool = _game.get_animal_pool()
	var dummies: Array[Animal] = _spawn_dummies(MASS_DEATH_COUNT, 0.0)
	_check(dummies.size() >= MASS_DEATH_COUNT - 20, "동시 적 %d마리 확보" % dummies.size())
	var steady: SimMetrics = SimMetrics.new()
	await _simulate(3.0, steady)

	var burst: SimMetrics = SimMetrics.new()
	var nodes_before: int = _node_count()
	var voices_before: int = 0 if audio == null else audio.get_voice_count()
	var alive_before: int = _alive_count()
	# 한 프레임에 전부 죽여 사망 이펙트·효과음·젬 드롭이 동시에 몰리는 최악 조건을 만든다.
	for animal in dummies:
		if is_instance_valid(animal):
			animal.take_damage(999999.0, Vector2.RIGHT)
	await get_tree().physics_frame
	var removed: int = alive_before - _alive_count()
	await _simulate(3.0, burst)

	_log("    적 %d마리 유지    | 평균 프레임 %6.3f ms | 최대 %6.3f ms" % [
		steady.max_alive, steady.avg_frame_ms(), steady.max_frame_ms()
	])
	_log("    동시 사망 %d마리 | 평균 프레임 %6.3f ms | 최대 %6.3f ms" % [
		dummies.size(), burst.avg_frame_ms(), burst.max_frame_ms()
	])
	_check(burst.max_frame_ms() < 50.0, "대량 사망 최악 프레임 %.2f ms < 50 ms (헤드리스=렌더 비용 제외)" % burst.max_frame_ms())
	_check(
		removed >= MASS_DEATH_COUNT - 40,
		"한 프레임에 %d마리 동시 사망 처리 (%d → %d)" % [removed, alive_before, alive_before - removed]
	)
	_check(
		effects.get_burst_pool().get_total_count() <= effects.max_active_bursts,
		"대량 사망에도 사망 이펙트 풀 상한 유지 (%d <= %d)" % [effects.get_burst_pool().get_total_count(), effects.max_active_bursts]
	)
	_check(
		effects.get_number_pool().get_total_count() <= effects.max_active_numbers,
		"대량 사망에도 데미지 숫자 풀 상한 유지 (%d <= %d)" % [effects.get_number_pool().get_total_count(), effects.max_active_numbers]
	)
	if audio != null:
		_check(audio.get_voice_count() == voices_before, "대량 사망에도 오디오 플레이어 %d개 유지" % audio.get_voice_count())
	_check(pool.get_total_count() <= 640, "동물 풀 크기 제한 유지 (%d개)" % pool.get_total_count())
	_log("    노드 수 %d → %d (젬 드롭 포함)" % [nodes_before, _node_count()])
	await _stop_game()

func _case_sprite_pipeline() -> void:
	_begin("18. 스프라이트 데이터 주도 교체 · 플레이스홀더 폴백")
	await _start_game(false, false)
	if _game == null:
		return
	var player: Player = _game.get_player()
	var placeholder: AnimalData = ContentDB.get_animal("spore_ant")
	# 실제 아트가 아직 없으므로 런타임 텍스처로 대신한다(저장소에 파일을 남기지 않는다).
	var art_data: AnimalData = placeholder.duplicate() as AnimalData
	art_data.sprite = _make_test_texture(96, 48)
	art_data.sprite_size = 40.0

	var animal: Animal = _game.get_animal_pool().acquire() as Animal
	_check(animal != null, "테스트용 동물을 풀에서 확보")
	if animal == null:
		return
	var sprite: Sprite2D = animal.get_node("Sprite") as Sprite2D
	var far_pos: Vector2 = player.global_position + Vector2(900.0, 0.0)
	animal.setup(art_data, far_pos, player, 1.0, 0.0, 0.0, false)
	_check(animal.is_using_sprite_art(), ".tres 에 지정한 텍스처로 그려짐")
	_check(sprite.texture == art_data.sprite, "Sprite2D 에 데이터의 텍스처가 적용됨")
	_check(
		is_equal_approx(SpriteVisual.measure_display_size(sprite), art_data.sprite_size),
		"원본 96×48 텍스처가 표시 크기 %.0fpx 로 정규화됨 (실제 %.1fpx)" % [
			art_data.sprite_size, SpriteVisual.measure_display_size(sprite)
		]
	)
	_check(sprite.modulate.is_equal_approx(Color.WHITE), "실제 아트에는 데이터 색이 덧칠되지 않음 (%s)" % _color_text(sprite.modulate))

	# 타격감: 텍스처에서도 플래시가 보여야 하고, 원래 색으로 정확히 복귀해야 한다.
	var art_base: Color = animal.get_base_color()
	animal.take_damage(1.0)
	_check(animal.is_hit_flashing(), "텍스처 스프라이트도 피격 시 플래시 활성")
	_check(
		animal.get_sprite_color().r > art_base.r,
		"플래시가 흰색 덮어쓰기가 아니라 밝히기로 동작 (%.2f → %.2f)" % [art_base.r, animal.get_sprite_color().r]
	)
	await _simulate(0.4)
	_check(animal.get_sprite_color().is_equal_approx(art_base), "텍스처 스프라이트도 플래시 후 원래 색 복귀")

	# 같은 풀 노드를 텍스처 없는 데이터로 재사용 → 플레이스홀더로 되돌아와야 한다(점진 교체 대응).
	animal.setup(placeholder, far_pos, player, 1.0, 0.0, 0.0, false)
	_check(not animal.is_using_sprite_art(), "텍스처가 없는 데이터는 플레이스홀더로 폴백")
	_check(sprite.texture != art_data.sprite, "폴백 시 씬 기본 텍스처로 되돌아감")
	_check(sprite.modulate.is_equal_approx(placeholder.color), "폴백은 데이터 색으로 물들여 그려짐 (%s)" % _color_text(sprite.modulate))
	_check(
		is_equal_approx(SpriteVisual.measure_display_size(sprite), placeholder.radius * 2.0),
		"폴백 크기 = 충돌 반경 기준 %.0fpx (실제 %.1fpx)" % [placeholder.radius * 2.0, SpriteVisual.measure_display_size(sprite)]
	)
	animal.take_damage(999999.0)

	# 능력(투사체)도 같은 규칙으로 동작해야 한다.
	var ability: AbilityData = ContentDB.get_ability("thorn_shot")
	var ability_art: AbilityData = ability.duplicate() as AbilityData
	ability_art.attack_texture = _make_test_texture(64, 32)
	ability_art.projectile_size = 24.0
	var pool: ObjectPool = _game.get_attack_pools().get_pool(ability.attack_scene)
	var projectile: Node = pool.acquire()
	_check(projectile != null, "투사체를 풀에서 확보")
	if projectile == null:
		await _stop_game()
		return
	var projectile_sprite: Sprite2D = projectile.get_node("Sprite") as Sprite2D
	projectile.setup(ability_art, far_pos, Vector2.RIGHT, 1.0)
	_check(projectile_sprite.texture == ability_art.attack_texture, "능력 .tres 의 attack_texture 가 투사체에 적용됨")
	_check(
		is_equal_approx(SpriteVisual.measure_display_size(projectile_sprite), ability_art.projectile_size),
		"투사체 표시 크기 %.0fpx 로 정규화 (실제 %.1fpx)" % [
			ability_art.projectile_size, SpriteVisual.measure_display_size(projectile_sprite)
		]
	)
	projectile.setup(ability, far_pos, Vector2.RIGHT, 1.0)
	_check(projectile_sprite.texture != ability_art.attack_texture, "텍스처 없는 능력은 플레이스홀더로 폴백")
	_check(
		projectile_sprite.self_modulate.is_equal_approx(ability.color),
		"폴백 투사체는 능력 색으로 물듦 (%s)" % _color_text(projectile_sprite.self_modulate)
	)
	pool.release(projectile)
	await _simulate(0.2)
	await _stop_game()

## 실제 아트 없이 텍스처 경로를 검증하기 위한 런타임 생성 텍스처.
func _make_test_texture(width: int, height: int) -> Texture2D:
	var image: Image = Image.create_empty(width, height, false, Image.FORMAT_RGBA8)
	image.fill(Color(1.0, 0.353, 0.847, 1.0))
	return ImageTexture.create_from_image(image)

func _case_soak() -> void:
	_begin("19. 소크 테스트 (%.0f초 시뮬레이션)" % _soak_seconds)
	var metrics: SimMetrics = SimMetrics.new()
	var deaths: int = 0
	var total_kills: int = 0
	var best_level: int = 1
	var elapsed: float = 0.0
	var next_sample: float = SOAK_SAMPLE_INTERVAL
	var cards_total: int = 0
	var buys_total: int = 0
	_synergy_events.clear()
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
			cards_total += _autopilot.cards_chosen
			buys_total += _autopilot.items_bought
			get_tree().paused = false
			await _stop_game()
			await _start_game(true)
			last = Time.get_ticks_usec()
			if _game == null:
				break
	total_kills += RunState.kills
	cards_total += _autopilot.cards_chosen
	buys_total += _autopilot.items_bought
	var nodes_end: int = _node_count()
	var pool_total: int = _game.get_animal_pool().get_total_count()
	await _stop_game()
	await _simulate(0.3)
	var nodes_after_free: int = _node_count()
	var orphans: int = int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))

	_log("    시뮬레이션 %.0f초 / 사망 %d회 / 누적 처치 %d / 최고 레벨 %d" % [elapsed, deaths, total_kills, best_level])
	_log("    변이 카드 선택 %d회 / 상점 구매 %d개 / 시너지 발동 %d건" % [cards_total, buys_total, _synergy_events.size()])
	_log("    최대 동시 적 %d마리 / 최대 노드 %d개 / 동물 풀 %d개" % [metrics.max_alive, metrics.max_nodes, pool_total])
	_log("    평균 프레임 %.2f ms / 최대 프레임 %.2f ms / 프레임 %d개" % [metrics.avg_frame_ms(), metrics.max_frame_ms(), metrics.frame_count])
	for line in metrics.sample_lines():
		_log("    " + line)
	for line in metrics.bucket_lines():
		_log("    " + line)
	_check(metrics.frame_count > 0, "소크 시뮬레이션이 실제로 진행됨 (%d 프레임)" % metrics.frame_count)
	_check(cards_total > 0, "소크 중 변이 카드가 반복 처리됨 (%d회)" % cards_total)
	_check(nodes_end < NODE_COUNT_CEILING, "노드 수가 상한 미만 유지 (%d < %d)" % [nodes_end, NODE_COUNT_CEILING])
	_check(pool_total <= _baseline_pool_ceiling(), "동물 풀 크기가 상한 내 (%d <= %d)" % [pool_total, _baseline_pool_ceiling()])
	_check(
		nodes_after_free <= _baseline_nodes + 8,
		"게임 씬 해제 후 노드 수 복귀 (기준 %d → %d)" % [_baseline_nodes, nodes_after_free]
	)
	_check(orphans == 0, "고아 노드 0개 (실제 %d개)" % orphans)

# ---------------------------------------------------------------- 유틸

## 측정용 허수아비 동물. 이동속도·접촉피해 0, HP 를 크게 줘서 조건을 고정한다.
## distance 가 0이면 기존 부하 테스트와 같은 링(260~720px)에 흩뿌린다.
func _spawn_dummies(count: int, distance: float) -> Array[Animal]:
	var result: Array[Animal] = []
	if _game == null:
		return result
	var player: Player = _game.get_player()
	var data: AnimalData = ContentDB.get_animal("spore_ant")
	for i in count:
		var animal: Animal = _game.get_animal_pool().acquire() as Animal
		if animal == null:
			break
		var pos: Vector2 = _ring_position(player.global_position)
		if distance > 0.0:
			var angle: float = TAU * float(i) / float(maxi(count, 1))
			pos = player.global_position + Vector2(cos(angle), sin(angle)) * distance
		animal.setup(data, pos, player, 400.0, 0.0, 0.0, false)
		result.append(animal)
	return result

func _color_text(color: Color) -> String:
	return "rgba(%.2f, %.2f, %.2f, %.2f)" % [color.r, color.g, color.b, color.a]

func _audio_count_text(audio: Node, ids: PackedStringArray) -> String:
	var parts: Array[String] = []
	for sfx_id in ids:
		parts.append("%s=%d" % [sfx_id, audio.get_play_count(sfx_id)])
	return ", ".join(parts)

func _ring_position(center: Vector2) -> Vector2:
	var angle: float = randf() * TAU
	return center + Vector2(cos(angle), sin(angle)) * randf_range(260.0, 720.0)

func _baseline_pool_ceiling() -> int:
	return 320

## 런 스탯 전체를 문자열로 만들어 "무언가 바뀌었는지"를 비교한다.
func _stat_signature() -> String:
	return "%.4f|%.4f|%.2f|%.4f|%.4f|%.4f|%.4f|%.4f|%.4f|%.4f|%.4f|%.4f|%d" % [
		RunState.damage_mult,
		RunState.move_speed_mult,
		RunState.bonus_max_health,
		RunState.cooldown_mult,
		RunState.area_mult,
		RunState.pickup_radius_mult,
		RunState.armor,
		RunState.dodge_chance,
		RunState.crit_chance,
		RunState.crit_mult,
		RunState.heal_on_kill,
		RunState.get_ability_damage_bonus_total(),
		RunState.get_ability_ids().size(),
	]

## 아직 보유하지 않은 능력을 주는 변이 하나(없으면 null).
func _unowned_ability_mutation() -> MutationData:
	for data in ContentDB.get_mutations():
		if data.kind != MutationData.Kind.NEW_ABILITY:
			continue
		var ability_id: String = String(data.payload.get("add_ability", ""))
		if not ability_id.is_empty() and not RunState.has_ability(ability_id):
			return data
	return null

func _first_available_offer(shop: ShopScreen) -> int:
	for i in shop.get_offers().size():
		if shop.get_offers()[i] != null:
			return i
	return -1

func _start_game(with_autopilot: bool, auto_resolve_ui: bool = true) -> void:
	var packed: PackedScene = load(GAME_SCENE_PATH)
	if packed == null:
		_check(false, "game.tscn 로드 실패")
		return
	_game = packed.instantiate()
	get_tree().root.add_child(_game)
	await get_tree().process_frame
	await get_tree().physics_frame
	# 카드/상점이 열리면 트리가 멈추므로, 이동을 쓰지 않는 케이스에도 UI 처리용 오토파일럿을 붙인다.
	_autopilot = TestAutopilot.new()
	_autopilot.name = "TestAutopilot"
	_autopilot.control_movement = with_autopilot
	_autopilot.auto_resolve_ui = auto_resolve_ui
	_autopilot.set_player(_game.get_player())
	_autopilot.set_ui(_game.get_mutation_card_screen(), _game.get_shop_screen())
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
