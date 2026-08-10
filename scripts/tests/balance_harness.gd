extends Node
## 밸런스 계측 하네스 (테스트 전용). 기존 test_runner.gd 와 완전히 분리된 별도 씬/모드이며
## 게임 코드는 수정하지 않고 공개 API·입력·EventBus 구독만 사용한다.
##
## "기능이 동작하는가"는 test_runner 가 보고, 이 하네스는 "숫자가 말이 되는가"만 본다.
##
## 실행 예:
##   godot_console.exe --headless --fixed-fps 60 --path <프로젝트> \
##     res://scenes/tests/balance_harness.tscn -- --mode=all --seeds=101,202,303,404,505
##
## 모드
##   run      : 시드별로 한 판을 끝까지(사망 또는 --max-waves) 돌려 웨이브별 지표를 뽑는다.
##   ability  : 능력별 실효 DPS 벤치(고정 배치 허수아비, 밀집/산개 두 지형).
##   mutation : 변이 한 장의 공격/생존 기여도 벤치.
##   all      : 위 셋 전부.
##
## 카드/상점 선택 정책(--policy)은 하네스가 직접 처리한다. TestAutopilot 은 이동만 담당해
## 기존 테스트와 동작이 갈리지 않게 한다.

const GAME_SCENE_PATH: String = "res://scenes/main/game.tscn"
## 벤치 허수아비 HP. 절대 죽지 않게 해서 오버킬·리스폰 변수를 제거한다.
const DUMMY_HP: float = 1000000.0
const CROWD_COUNT: int = 36
## 허수아비를 동심원 위에 규칙적으로 놓으면 투사체 관통이 측정되지 않는다.
## (링마다 각도가 어긋나 어떤 직선에도 2마리밖에 걸리지 않아, pierce 를 올려도 값이 안 변한다.)
## 그래서 링 대신 고리 모양 띠 안에 시드 기반 난수로 흩뿌린다. 시드마다 배치가 달라지므로
## 평균과 표준편차가 의미를 갖는다.
## 밀집 지형(근접·오라에 유리): 적이 플레이어에게 달라붙은 상황.
const SWARM_BAND: Vector2 = Vector2(30.0, 120.0)
## 산개 지형(원거리에 유리): 적이 아직 몰려오지 않은 상황.
const SPREAD_BAND: Vector2 = Vector2(60.0, 320.0)
const DEFENSE_DUMMIES: int = 8
## 플레이어 Hurtbox(22px) 안에 확실히 겹치도록 붙이는 거리.
const DEFENSE_DISTANCE: float = 14.0
const ELITE_ESSENCE_BONUS: int = 4

var _mode: String = "all"
var _seeds: Array[int] = [101, 202, 303, 404, 505]
var _policies: Array[String] = ["random"]
var _max_waves: int = 20
var _max_seconds: float = 1200.0
var _bench_seconds: float = 12.0
var _defense_seconds: float = 4.0
var _csv_path: String = ""
## 진단 모드: 매 프레임 플레이어를 완전 회복시켜 죽지 않게 한다.
## 사망 시점이 아니라 "곡선 자체"(플레이어 성장 대 적 강화)를 끝까지 관측하기 위한 것으로,
## 이 모드의 생존 웨이브는 실제 난이도를 뜻하지 않는다. 받은 피해량은 그대로 기록된다.
var _immortal: bool = false
## 벤치 대상 필터(능력 id / 변이 id). 비어 있으면 전부 측정한다.
## 한 프로세스에서 여러 대상을 연달아 재면 앞선 측정이 뒤에 영향을 주는지 확인할 때,
## 대상 하나만 따로 돌려 프로세스 간 격리 상태에서의 값과 비교하는 데 쓴다.
var _only: Array[String] = []
## 허수아비 배치 전용 난수. 전역 RNG를 쓰면 변이(크리티컬 판정 등)가 난수를 소비해
## 같은 시드인데도 배치가 달라져 변이 간 비교가 무너진다.
var _layout_rng: RandomNumberGenerator = RandomNumberGenerator.new()

var _game: Node
var _autopilot: TestAutopilot

# ---- 현재 런의 누적 카운터 (웨이브 기록이 델타로 사용한다)
var _dmg_dealt: float = 0.0
var _dmg_taken: float = 0.0
var _hp_destroyed: float = 0.0
var _feed_income: int = 0
var _levels: Array[Dictionary] = []
var _records: Array[Dictionary] = []
var _open_record: Dictionary = {}
var _shop_visits: Array[Dictionary] = []
var _run_active: bool = false
var _capped: bool = false

# ---- 전체 실행에 걸친 집계
var _offer_counts: Dictionary = {}
var _chosen_counts: Dictionary = {}
var _shop_offer_counts: Dictionary = {}
var _shop_bought_counts: Dictionary = {}
var _csv_rows: Array[String] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_parse_args()
	EventBus.animal_hit.connect(_on_animal_hit)
	EventBus.animal_died.connect(_on_animal_died)
	EventBus.player_hit.connect(_on_player_hit)
	EventBus.feed_collected.connect(_on_feed_collected)
	EventBus.player_leveled_up.connect(_on_level_up)
	EventBus.wave_started.connect(_on_wave_started)
	EventBus.wave_ended.connect(_on_wave_ended)
	EventBus.player_died.connect(_on_player_died)
	EventBus.mutation_offered.connect(_on_mutation_offered)
	EventBus.shop_opened.connect(_on_shop_opened)
	_run_all.call_deferred()

func _parse_args() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--mode="):
			_mode = arg.split("=")[1]
		elif arg.begins_with("--seeds="):
			_seeds.clear()
			for part in arg.split("=")[1].split(","):
				if not part.is_empty():
					_seeds.append(int(part))
		elif arg.begins_with("--policy="):
			_policies.clear()
			for part in arg.split("=")[1].split(","):
				if not part.is_empty():
					_policies.append(part)
		elif arg.begins_with("--max-waves="):
			_max_waves = int(arg.split("=")[1])
		elif arg.begins_with("--max-seconds="):
			_max_seconds = float(arg.split("=")[1])
		elif arg.begins_with("--bench-seconds="):
			_bench_seconds = float(arg.split("=")[1])
		elif arg.begins_with("--csv="):
			_csv_path = arg.split("=")[1]
		elif arg.begins_with("--only="):
			_only.assign(Array(arg.split("=")[1].split(",")))
		elif arg == "--immortal":
			_immortal = true

func _run_all() -> void:
	var wall_start: int = Time.get_ticks_msec()
	_log("=== Feral Bloom 밸런스 계측 ===")
	_log("Godot %s | headless=%s" % [Engine.get_version_info().string, str(DisplayServer.get_name() == "headless")])
	_log("mode=%s seeds=%s policy=%s max_waves=%d bench=%.0fs immortal=%s" % [
		_mode, str(_seeds), str(_policies), _max_waves, _bench_seconds, str(_immortal)
	])
	_log_data_snapshot()

	if _mode == "run" or _mode == "all":
		await _measure_runs()
	if _mode == "ability" or _mode == "all":
		await _measure_abilities()
	if _mode == "mutation" or _mode == "all":
		await _measure_mutations()

	_write_csv()
	_log("")
	_log("=== 계측 완료 (%.1fs) ===" % (float(Time.get_ticks_msec() - wall_start) / 1000.0))
	await _drain_audio()
	get_tree().quit(0)

## 지금 측정하는 데이터의 판본을 같이 남겨, 나중에 수치를 바꾼 뒤 비교할 수 있게 한다.
func _log_data_snapshot() -> void:
	_log("")
	_log("[DATA] 웨이브 정의")
	_log("  웨이브 | 지속  | 간격  | 배치 | HP배율 | 속도  | 피해  | 엘리트 | 보상 | 스폰/초 | 평균적HP | 적HP/초")
	for wave in ContentDB.get_waves():
		var mean_hp: float = _mean_spawn_hp(wave, wave.hp_mult, wave.elite_chance, 6.0)
		var rate: float = float(wave.batch_size) / maxf(wave.spawn_interval, 0.05)
		_log("  %6d | %5.0f | %5.2f | %4d | %6.2f | %5.2f | %5.2f | %6.2f | %4d | %7.2f | %8.1f | %7.1f" % [
			wave.index, wave.duration, wave.spawn_interval, wave.batch_size,
			wave.hp_mult, wave.speed_mult, wave.damage_mult, wave.elite_chance,
			wave.feed_reward, rate, mean_hp, rate * mean_hp,
		])
	_log("")
	_log("[DATA] 능력 이론 DPS (단일 표적 · 배율 1.0 기준)")
	for id in _sorted(ContentDB.get_ability_ids()):
		var ability: AbilityData = ContentDB.get_ability(id)
		_log("  %-14s dmg=%5.1f cd=%4.2f count=%d 이론DPS=%6.2f (%s)" % [
			ability.id, ability.base_damage, ability.cooldown, ability.projectile_count,
			_theoretical_dps(ability), _kind_name(ability.attack_kind),
		])

func _kind_name(kind: int) -> String:
	match kind:
		AbilityData.AttackKind.PROJECTILE:
			return "투사체"
		AbilityData.AttackKind.MELEE_ARC:
			return "근접"
		_:
			return "장판"

## 단일 표적 기준 이론 DPS. 장판은 지속/틱을 반영하되 쿨다운보다 오래 남는 겹침은 무시한다.
func _theoretical_dps(ability: AbilityData) -> float:
	var per_cycle: float = ability.base_damage * float(maxi(ability.projectile_count, 1))
	if ability.attack_kind == AbilityData.AttackKind.AREA_FIELD:
		var ticks: float = floor(ability.duration / maxf(ability.tick_interval, 0.05))
		per_cycle = ability.base_damage * ticks
	return per_cycle / maxf(ability.cooldown, 0.02)

# ================================================================ 모드 1: 한 판 계측

func _measure_runs() -> void:
	var by_policy: Dictionary = {}
	for policy in _policies:
		var runs: Array[Dictionary] = []
		for run_seed in _seeds:
			var result: Dictionary = await _play_run(run_seed, policy)
			runs.append(result)
		by_policy[policy] = runs
	_report_runs(by_policy)

func _play_run(run_seed: int, policy: String) -> Dictionary:
	seed(run_seed)
	_reset_run_counters()
	# 웨이브 1의 wave_started 는 game.tscn 의 _ready 안에서 발행되므로 먼저 켜 둔다.
	_run_active = true
	await _start_game(true, false)
	if _game == null:
		_run_active = false
		return {}
	var director: WaveDirector = _game.get_wave_director()
	var player: Player = _game.get_player()
	while _run_active:
		await get_tree().process_frame
		_resolve_ui_step(policy)
		if _game == null or not is_instance_valid(_game):
			break
		if _immortal:
			player.heal(player.get_max_health())
		if not _open_record.is_empty():
			var hp: float = player.get_health()
			_open_record["hp_min"] = minf(float(_open_record["hp_min"]), hp)
			var alive: int = _alive_count()
			_open_record["alive_max"] = maxi(int(_open_record["alive_max"]), alive)
			_open_record["alive_sum"] = float(_open_record["alive_sum"]) + float(alive)
			_open_record["frames"] = int(_open_record["frames"]) + 1
		if RunState.is_game_over:
			break
		if RunState.elapsed_time > _max_seconds:
			_capped = true
			break
		if director.get_wave_number() > _max_waves:
			# 상한에 걸려 방금 시작한 웨이브는 통계에 넣지 않는다(길이 0의 가짜 표본).
			_capped = true
			_open_record = {}
			break
	var summary: Dictionary = {
		"seed": run_seed,
		"policy": policy,
		"died": RunState.is_game_over,
		"capped": _capped,
		"death_time": RunState.elapsed_time,
		"death_wave": director.get_wave_number() if is_instance_valid(director) else 0,
		"kills": RunState.kills,
		"level": RunState.level,
		"feed": RunState.feed,
		"feed_spent": RunState.feed_spent,
		"purchases": RunState.purchases,
		"mutations": RunState.get_mutation_total(),
		"abilities": RunState.get_ability_ids().size(),
		"damage_dealt": _dmg_dealt,
		"damage_taken": _dmg_taken,
		"lineages": RunState.get_lineage_counts(),
		"waves": _records.duplicate(true),
		"levels": _levels.duplicate(true),
		"shops": _shop_visits.duplicate(true),
	}
	_close_open_record(true)
	summary["waves"] = _records.duplicate(true)
	_run_active = false
	get_tree().paused = false
	await _stop_game()
	return summary

func _reset_run_counters() -> void:
	_dmg_dealt = 0.0
	_dmg_taken = 0.0
	_hp_destroyed = 0.0
	_feed_income = 0
	_levels.clear()
	_records.clear()
	_shop_visits.clear()
	_open_record = {}
	_run_active = false
	_capped = false

# ---------------------------------------------------------------- 웨이브 기록

func _on_wave_started(index: int, data: WaveData) -> void:
	if not _run_active or _game == null or not is_instance_valid(_game):
		return
	_close_open_record(false)
	var director: WaveDirector = _game.get_wave_director()
	var player: Player = _game.get_player()
	var spawner: AnimalSpawner = _game.get_spawner()
	_open_record = {
		"wave": index,
		"design_index": data.index,
		"loop": (index - 1) / maxi(ContentDB.get_waves().size(), 1),
		"t_start": RunState.elapsed_time,
		"t_end": RunState.elapsed_time,
		"duration": data.duration,
		"hp_start": player.get_health(),
		"hp_end": player.get_health(),
		"hp_max": player.get_max_health(),
		"hp_min": player.get_health(),
		"kills_start": RunState.kills,
		"kills": 0,
		"spawned_start": spawner.get_spawned_total(),
		"spawned": 0,
		"dmg_dealt_start": _dmg_dealt,
		"dmg_dealt": 0.0,
		"dmg_taken_start": _dmg_taken,
		"dmg_taken": 0.0,
		"hp_destroyed_start": _hp_destroyed,
		"hp_destroyed": 0.0,
		"feed_start": _feed_income,
		"feed_gained": 0,
		"feed_spent_start": RunState.feed_spent,
		"feed_spent": 0,
		"level_start": RunState.level,
		"level_end": RunState.level,
		"mutations": RunState.get_mutation_total(),
		"abilities": RunState.get_ability_ids().size(),
		"hp_mult": director.get_hp_mult(),
		"speed_mult": director.get_speed_mult(),
		"damage_mult": director.get_damage_mult(),
		"elite_chance": director.get_elite_chance(),
		"mean_enemy_hp": _mean_spawn_hp(data, director.get_hp_mult(), director.get_elite_chance(), spawner.elite_hp_mult),
		"alive_max": 0,
		"alive_sum": 0.0,
		"frames": 0,
		"completed": false,
		"died": false,
	}

func _on_wave_ended(_index: int) -> void:
	if _open_record.is_empty():
		return
	_open_record["completed"] = true
	_snapshot_open_record()

func _snapshot_open_record() -> void:
	if _open_record.is_empty() or _game == null or not is_instance_valid(_game):
		return
	var player: Player = _game.get_player()
	var spawner: AnimalSpawner = _game.get_spawner()
	_open_record["t_end"] = RunState.elapsed_time
	_open_record["hp_end"] = player.get_health()
	# 최대 체력은 웨이브 중에도 변이로 늘어나므로 종료 시점 값으로 갱신한다.
	_open_record["hp_max"] = player.get_max_health()
	_open_record["kills"] = RunState.kills - int(_open_record["kills_start"])
	_open_record["spawned"] = spawner.get_spawned_total() - int(_open_record["spawned_start"])
	_open_record["dmg_dealt"] = _dmg_dealt - float(_open_record["dmg_dealt_start"])
	_open_record["dmg_taken"] = _dmg_taken - float(_open_record["dmg_taken_start"])
	_open_record["hp_destroyed"] = _hp_destroyed - float(_open_record["hp_destroyed_start"])
	_open_record["feed_gained"] = _feed_income - int(_open_record["feed_start"])
	_open_record["level_end"] = RunState.level

## 웨이브가 끝난 뒤 상점에서 쓴 먹이까지 그 웨이브 기록에 담고 나서 닫는다.
func _close_open_record(force: bool) -> void:
	if _open_record.is_empty():
		return
	if not bool(_open_record["completed"]):
		_snapshot_open_record()
	_open_record["feed_spent"] = RunState.feed_spent - int(_open_record["feed_spent_start"])
	_open_record["mutations"] = RunState.get_mutation_total()
	_open_record["abilities"] = RunState.get_ability_ids().size()
	if force and RunState.is_game_over:
		_open_record["died"] = true
	_records.append(_open_record)
	_open_record = {}

func _on_player_died() -> void:
	if not _open_record.is_empty():
		_open_record["died"] = true
		_snapshot_open_record()
	_run_active = false

func _on_animal_hit(_position: Vector2, damage: float) -> void:
	_dmg_dealt += damage

func _on_player_hit(damage: float) -> void:
	_dmg_taken += damage

func _on_animal_died(_position: Vector2, data: AnimalData, essence_value: int) -> void:
	if data == null or _game == null or not is_instance_valid(_game):
		return
	var director: WaveDirector = _game.get_wave_director()
	if director == null or not is_instance_valid(director):
		return
	var is_elite: bool = essence_value >= data.essence_value + ELITE_ESSENCE_BONUS
	var mult: float = director.get_hp_mult() * (_game.get_spawner().elite_hp_mult if is_elite else 1.0)
	_hp_destroyed += data.max_hp * mult

func _on_feed_collected(value: int) -> void:
	_feed_income += value

func _on_level_up(level: int) -> void:
	if not _run_active:
		return
	var wave: int = 0
	if _game != null and is_instance_valid(_game):
		wave = _game.get_wave_director().get_wave_number()
	_levels.append({"level": level, "time": RunState.elapsed_time, "wave": wave})

func _on_mutation_offered(options: Array) -> void:
	for option in options:
		var data: MutationData = option as MutationData
		if data != null:
			_offer_counts[data.id] = int(_offer_counts.get(data.id, 0)) + 1

func _on_shop_opened(wave_index: int) -> void:
	if not _run_active or _game == null or not is_instance_valid(_game):
		return
	var shop: ShopScreen = _game.get_shop_screen()
	var costs: Array[int] = []
	for i in shop.get_offers().size():
		var data: MutationData = shop.get_offers()[i]
		if data == null:
			continue
		costs.append(shop.get_cost(i))
		_shop_offer_counts[data.id] = int(_shop_offer_counts.get(data.id, 0)) + 1
	_shop_visits.append({
		"wave": wave_index,
		"feed": RunState.feed,
		"costs": costs,
		"reroll": shop.get_reroll_cost(),
		"cheapest": 0 if costs.is_empty() else costs.min(),
		"mean_cost": 0.0 if costs.is_empty() else _mean_int(costs),
	})

## 적 한 마리 스폰당 기대 HP. 스폰 테이블 가중치 · 웨이브 배율 · 엘리트 확률을 반영한다.
func _mean_spawn_hp(wave: WaveData, hp_mult: float, elite_chance: float, elite_hp_mult: float) -> float:
	var total_weight: float = 0.0
	var weighted_hp: float = 0.0
	for id in wave.spawn_ids:
		var data: AnimalData = ContentDB.get_animal(id)
		if data == null:
			continue
		var weight: float = maxf(data.spawn_weight, 0.0)
		total_weight += weight
		weighted_hp += weight * data.max_hp
	if total_weight <= 0.0:
		return 0.0
	var base: float = weighted_hp / total_weight
	return base * hp_mult * (1.0 + elite_chance * (elite_hp_mult - 1.0))

# ---------------------------------------------------------------- 카드/상점 정책

func _resolve_ui_step(policy: String) -> void:
	if _game == null or not is_instance_valid(_game):
		return
	var cards: MutationCardScreen = _game.get_mutation_card_screen()
	if cards.is_open():
		var options: Array[MutationData] = cards.get_options()
		if options.is_empty():
			return
		var index: int = _pick_card(options, policy)
		if cards.choose(index):
			var picked: MutationData = options[index]
			_chosen_counts[picked.id] = int(_chosen_counts.get(picked.id, 0)) + 1
		return
	var shop: ShopScreen = _game.get_shop_screen()
	if shop.is_open():
		_shop_step(shop, policy)
		shop.close()

func _pick_card(options: Array[MutationData], policy: String) -> int:
	if policy == "random":
		return randi() % options.size()
	var best: int = 0
	var best_score: float = -INF
	for i in options.size():
		var score: float = _score(options[i], policy)
		if score > best_score:
			best_score = score
			best = i
	return best

func _shop_step(shop: ShopScreen, policy: String) -> void:
	_buy_pass(shop, policy)
	if RunState.feed >= shop.get_reroll_cost() + 10 and shop.reroll():
		_buy_pass(shop, policy)

func _buy_pass(shop: ShopScreen, policy: String) -> void:
	# 정책 점수가 높은 순으로 살 수 있는 것을 산다(무작위 정책은 앞에서부터).
	var order: Array[int] = []
	for i in shop.get_offers().size():
		order.append(i)
	if policy != "random":
		order.sort_custom(
			func(a: int, b: int) -> bool:
				return _score_index(shop, a, policy) > _score_index(shop, b, policy)
		)
	for i in order:
		var data: MutationData = shop.get_offers()[i]
		if data == null:
			continue
		if RunState.feed >= shop.get_cost(i) and shop.buy(i):
			_shop_bought_counts[data.id] = int(_shop_bought_counts.get(data.id, 0)) + 1

func _score_index(shop: ShopScreen, index: int, policy: String) -> float:
	var data: MutationData = shop.get_offers()[index]
	if data == null:
		return -INF
	return _score(data, policy) / maxf(float(shop.get_cost(index)), 1.0)

## 정책 점수는 "사람이라면 이렇게 고를 것 같다"는 휴리스틱이다. 최적해가 아니며,
## 무작위 선택과 함께 돌려 결과의 상·하한을 잡는 용도로만 쓴다.
func _score(data: MutationData, policy: String) -> float:
	var offense: bool = policy == "damage"
	var total: float = 0.0
	for key in data.payload.keys():
		var value: float = 0.0
		if typeof(data.payload[key]) == TYPE_FLOAT or typeof(data.payload[key]) == TYPE_INT:
			value = float(data.payload[key])
		match String(key):
			"damage_pct":
				total += value * (100.0 if offense else 40.0)
			"ability_damage_pct":
				total += value * (55.0 if offense else 20.0)
			"cooldown_pct":
				total += value * (95.0 if offense else 35.0)
			"area_pct":
				total += value * (45.0 if offense else 20.0)
			"crit_chance":
				total += value * (70.0 if offense else 25.0)
			"crit_mult":
				total += value * (22.0 if offense else 8.0)
			"max_health":
				total += value * (0.25 if offense else 1.1)
			"armor_pct":
				total += value * (60.0 if offense else 320.0)
			"dodge_chance":
				total += value * (50.0 if offense else 260.0)
			"heal_on_kill":
				total += value * (25.0 if offense else 90.0)
			"move_speed_pct":
				total += value * (15.0 if offense else 85.0)
			"pickup_radius_pct":
				total += value * 8.0
			"add_ability":
				total += 85.0 if offense else 45.0
	return total

# ================================================================ 모드 2: 능력 DPS 벤치

func _measure_abilities() -> void:
	_log("")
	_log("[ABILITY] 능력별 실효 DPS 벤치 (%.0fs · 허수아비 %d마리 · 시드 %d개, 평균±표준편차)" % [
		_bench_seconds, CROWD_COUNT, _seeds.size()
	])
	_log("  능력           | 이론DPS | 밀집DPS(±sd)     | 산개DPS(±sd)     | 밀집/이론 | 산개/이론")
	for id in _sorted(ContentDB.get_ability_ids()):
		if not _only.is_empty() and not _only.has(id):
			continue
		var ability: AbilityData = ContentDB.get_ability(id)
		var swarm: Array[float] = await _bench_ability_dps(id, SWARM_BAND)
		var spread: Array[float] = await _bench_ability_dps(id, SPREAD_BAND)
		var theory: float = _theoretical_dps(ability)
		_log("  %-14s | %7.1f | %8.1f ±%-7.1f | %8.1f ±%-7.1f | %9.2f | %9.2f" % [
			id, theory,
			_mean(swarm), _stddev(swarm), _mean(spread), _stddev(spread),
			_mean(swarm) / maxf(theory, 0.01), _mean(spread) / maxf(theory, 0.01),
		])

func _bench_ability_dps(ability_id: String, band: Vector2) -> Array[float]:
	var results: Array[float] = []
	for bench_seed in _seeds:
		seed(bench_seed)
		_layout_rng.seed = bench_seed
		await _start_bench([ability_id])
		if _game == null:
			continue
		_spawn_crowd(band)
		var before: float = _dmg_dealt
		await _simulate(_bench_seconds)
		results.append((_dmg_dealt - before) / _bench_seconds)
		await _stop_game()
	if not _only.is_empty():
		_log("    (진단) %s band%.0f 시드별 DPS = %s" % [ability_id, band.x, str(results)])
	return results

# ================================================================ 모드 3: 변이 기여도 벤치

func _measure_mutations() -> void:
	var starting: Array[String] = _starting_ability_ids()
	var base_dps: float = await _bench_build_dps(starting, null, SWARM_BAND)
	var base_defense: Dictionary = await _bench_build_defense(starting, null)
	_log("")
	_log("[MUTATION] 변이 1장의 기여도 (기준 빌드 = %s)" % ", ".join(starting))
	_log("  기준: 공격 %.1f DPS / 피해수용 %.2f HP/s / 실효생존 %.1fs" % [
		base_dps, float(base_defense["dps_taken"]), float(base_defense["survival"])
	])
	_log("  변이                 | 등급 | 가격 | 스택 | DPS    | ΔDPS(%) | 피해수용 | 실효생존 | Δ생존(%)")
	var rows: Array[Dictionary] = []
	for data in _sorted_mutations():
		var dps: float = await _bench_build_dps(starting, data, SWARM_BAND)
		var defense: Dictionary = await _bench_build_defense(starting, data)
		var survival: float = float(defense["survival"])
		rows.append({
			"data": data,
			"dps": dps,
			"dps_delta": (dps / maxf(base_dps, 0.01) - 1.0) * 100.0,
			"taken": float(defense["dps_taken"]),
			"survival": survival,
			"survival_delta": (survival / maxf(float(base_defense["survival"]), 0.01) - 1.0) * 100.0,
		})
	for row in rows:
		var data: MutationData = row["data"]
		_log("  %-20s | %4s | %4d | %4d | %6.1f | %+6.1f | %8.2f | %8.1f | %+6.1f" % [
			data.id, _rarity_name(data.rarity), data.cost, data.max_stacks,
			float(row["dps"]), float(row["dps_delta"]), float(row["taken"]),
			float(row["survival"]), float(row["survival_delta"]),
		])
	_log("  * 처치 회복(heal_on_kill)은 이 벤치에서 적을 죽이지 않으므로 0으로 나온다 — 별도 환산 필요.")

func _rarity_name(rarity: int) -> String:
	match rarity:
		MutationData.Rarity.COMMON:
			return "C"
		MutationData.Rarity.RARE:
			return "R"
		_:
			return "E"

func _bench_build_dps(ability_ids: Array[String], mutation: MutationData, band: Vector2) -> float:
	var results: Array[float] = []
	for bench_seed in _seeds:
		seed(bench_seed)
		_layout_rng.seed = bench_seed
		await _start_bench(ability_ids)
		if _game == null:
			continue
		if mutation != null:
			RunState.apply_mutation(mutation)
			await get_tree().physics_frame
		_spawn_crowd(band)
		var before: float = _dmg_dealt
		await _simulate(_bench_seconds)
		results.append((_dmg_dealt - before) / _bench_seconds)
		await _stop_game()
	return _mean(results)

## 접촉 피해만 받는 조건에서 초당 잃는 HP와, 그것으로 계산한 실효 생존 시간(초).
## 능력을 전부 비워 플레이어 공격이 허수아비 배치를 흔들지 않게 한다(순수 방어 측정).
func _bench_build_defense(_ability_ids: Array[String], mutation: MutationData) -> Dictionary:
	var taken: Array[float] = []
	var survival: Array[float] = []
	for bench_seed in _seeds:
		seed(bench_seed)
		await _start_bench([] as Array[String])
		if _game == null:
			continue
		if mutation != null:
			RunState.apply_mutation(mutation)
			await get_tree().physics_frame
		var player: Player = _game.get_player()
		_spawn_contact_ring()
		var before: float = _dmg_taken
		await _simulate(_defense_seconds)
		var rate: float = (_dmg_taken - before) / _defense_seconds
		taken.append(rate)
		survival.append(player.get_max_health() / maxf(rate, 0.01))
		await _stop_game()
	return {"dps_taken": _mean(taken), "survival": _mean(survival)}

func _starting_ability_ids() -> Array[String]:
	var packed: PackedScene = load("res://scenes/player/player.tscn")
	var probe: Node = packed.instantiate()
	var manager: AbilityManager = probe.get_node("AbilityManager") as AbilityManager
	var ids: Array[String] = manager.starting_ability_ids.duplicate()
	probe.free()
	return ids

# ---------------------------------------------------------------- 벤치 공용

## 벤치 환경: 스폰 중단 + 런 스탯/계통 백지화 + 능력 슬롯을 직접 지정.
## abilities 배열에 직접 대입하므로 ability_added 가 발행되지 않아 계통 카운트가 0에서 시작한다
## (변이 1장만의 효과를 재려면 계통 시너지가 끼어들면 안 된다).
func _start_bench(ability_ids: Array[String]) -> void:
	await _start_game(false, false)
	if _game == null:
		return
	_game.get_spawner().setup(null, null, null)
	# 히트스톱은 Engine.time_scale 을 건드려 측정 창을 왜곡한다. 벤치에서는 끈다.
	var hit_stop: HitStop = _game.get_hit_stop()
	if hit_stop != null:
		hit_stop.enabled = false
		hit_stop.release()
	# 씬이 뜨는 사이 웨이브 1이 실제 적을 한 마리 스폰하므로 배치를 흔들기 전에 걷어낸다.
	_clear_animals()
	RunState.reset()
	var manager: AbilityManager = _game.get_player().get_ability_manager()
	var list: Array[AbilityData] = []
	for id in ability_ids:
		var ability: AbilityData = ContentDB.get_ability(id)
		if ability != null:
			list.append(ability)
	manager.abilities.assign(list)
	# 씬이 뜨는 사이 기본 로드아웃(thorn_shot·claw_swipe·venom_gland)이 이미 발동해 있다.
	# 특히 venom_gland 의 장판은 duration 동안 살아남아 벤치 창 안에서 계속 틱 피해를 넣으므로,
	# 능력을 갈아끼운 뒤 살아 있는 공격체를 전부 회수해야 "능력 하나만"의 값이 나온다.
	_clear_attacks()
	await get_tree().physics_frame

## band = (안쪽 반지름, 바깥 반지름). 면적 균등 분포로 흩뿌려 한쪽으로 쏠리지 않게 한다.
func _spawn_crowd(band: Vector2) -> void:
	var player: Player = _game.get_player()
	var data: AnimalData = ContentDB.get_animal("spore_ant")
	for _i in CROWD_COUNT:
		var angle: float = _layout_rng.randf() * TAU
		var t: float = _layout_rng.randf()
		var radius: float = sqrt(lerp(band.x * band.x, band.y * band.y, t))
		var animal: Animal = _game.get_animal_pool().acquire() as Animal
		if animal == null:
			return
		animal.setup(
			data,
			player.global_position + Vector2(cos(angle), sin(angle)) * radius,
			player, DUMMY_HP / maxf(data.max_hp, 1.0), 0.0, 0.0, false
		)
		_freeze(animal)

func _spawn_contact_ring() -> void:
	var player: Player = _game.get_player()
	var data: AnimalData = ContentDB.get_animal("spore_ant")
	for i in DEFENSE_DUMMIES:
		var angle: float = TAU * float(i) / float(DEFENSE_DUMMIES)
		var animal: Animal = _game.get_animal_pool().acquire() as Animal
		if animal == null:
			return
		animal.setup(
			data,
			player.global_position + Vector2(cos(angle), sin(angle)) * DEFENSE_DISTANCE,
			player, DUMMY_HP / maxf(data.max_hp, 1.0), 0.0, 1.0, false
		)
		_freeze(animal)

## 넉백을 끄지 않으면 이동속도 0인 허수아비가 맞을 때마다 밀려나 배치가 무너진다.
## (근접 능력이 자기 오라 밖으로 적을 밀어내 오히려 DPS가 떨어지는 가짜 결과가 나온다.)
func _freeze(animal: Animal) -> void:
	animal.knockback_strength = 0.0

# ================================================================ 리포트

func _report_runs(by_policy: Dictionary) -> void:
	for policy in by_policy.keys():
		var runs: Array = by_policy[policy]
		_log("")
		_log("[RUN/%s] 시드별 결과" % policy)
		_log("  시드   | 결과   | 도달웨이브 | 생존시간 | 레벨 | 처치  | 변이 | 능력 | 누적피해   | 받은피해")
		for run in runs:
			if run.is_empty():
				continue
			_log("  %6d | %-6s | %10d | %7.1fs | %4d | %5d | %4d | %4d | %10.0f | %8.0f" % [
				int(run["seed"]), ("사망" if bool(run["died"]) else "상한도달"),
				int(run["death_wave"]), float(run["death_time"]), int(run["level"]), int(run["kills"]),
				int(run["mutations"]), int(run["abilities"]), float(run["damage_dealt"]), float(run["damage_taken"]),
			])
		_report_wave_table(policy, runs)
		_report_slopes(policy, runs)
		_report_levels(policy, runs)
		_report_economy(policy, runs)
	_report_pool_usage()

func _report_wave_table(policy: String, runs: Array) -> void:
	var grouped: Dictionary = _group_waves(runs)
	var keys: Array = grouped.keys()
	keys.sort()
	_log("")
	_log("[RUN/%s] 웨이브별 집계 (시드 %d개 · 평균±표준편차)" % [policy, _seeds.size()])
	_log("  웨 | 시도 | 클리어 | 종료HP(%) | 최저HP(%) | 처치/초 | 플레이어DPS | 처치HP/초 | 적HP유입/초 | 소화율 | 여유배수 | 받은피해/초 | 실효생존s | 동시적")
	for key in keys:
		var group: Array = grouped[key]
		var attempts: int = group.size()
		var cleared: int = 0
		var hp_end: Array[float] = []
		var hp_min: Array[float] = []
		var kps: Array[float] = []
		var dps: Array[float] = []
		var destroyed: Array[float] = []
		var pressure: Array[float] = []
		var digest: Array[float] = []
		var ratio: Array[float] = []
		var taken: Array[float] = []
		var survival: Array[float] = []
		var alive: Array[float] = []
		for record in group:
			if bool(record["completed"]):
				cleared += 1
			var seconds: float = maxf(float(record["t_end"]) - float(record["t_start"]), 0.1)
			var max_hp: float = maxf(float(record["hp_max"]), 1.0)
			hp_end.append(clampf(float(record["hp_end"]) / max_hp * 100.0, 0.0, 100.0))
			hp_min.append(clampf(float(record["hp_min"]) / max_hp * 100.0, 0.0, 100.0))
			kps.append(float(record["kills"]) / seconds)
			var player_dps: float = float(record["dmg_dealt"]) / seconds
			var killed_hps: float = float(record["hp_destroyed"]) / seconds
			var enemy_hps: float = float(record["spawned"]) * float(record["mean_enemy_hp"]) / seconds
			var taken_rate: float = float(record["dmg_taken"]) / seconds
			dps.append(player_dps)
			destroyed.append(killed_hps)
			pressure.append(enemy_hps)
			digest.append(killed_hps / maxf(enemy_hps, 0.01))
			ratio.append(player_dps / maxf(enemy_hps, 0.01))
			taken.append(taken_rate)
			survival.append(minf(max_hp / maxf(taken_rate, 0.01), 9999.0))
			if int(record["frames"]) > 0:
				alive.append(float(record["alive_sum"]) / float(record["frames"]))
			_csv_rows.append("%s,%d,%d,%d,%.2f,%.1f,%.1f,%d,%d,%.1f,%.1f,%.1f,%.1f,%.3f,%.2f,%d" % [
				policy, int(record.get("seed", 0)), int(record["wave"]), int(record["design_index"]),
				seconds, float(record["hp_end"]), float(record["hp_min"]), int(record["kills"]),
				int(record["spawned"]), player_dps, killed_hps, enemy_hps, float(record["mean_enemy_hp"]),
				player_dps / maxf(enemy_hps, 0.01), taken_rate, int(record["level_end"]),
			])
		_log("  %2d | %4d | %6d | %-9s | %-9s | %-7s | %-11s | %-9s | %-11s | %-6s | %-8s | %-11s | %9.1f | %5.0f" % [
			int(key), attempts, cleared,
			_stat(hp_end, 0), _stat(hp_min, 0), _stat(kps, 2), _stat(dps, 0), _stat(destroyed, 0),
			_stat(pressure, 0), _stat(digest, 2), _stat(ratio, 2), _stat(taken, 1),
			_mean(survival), _mean(alive),
		])
	_report_loop_table(policy, grouped)

## 웨이브 5개가 소진되면 WaveDirector 가 1번 웨이브로 돌아가며 루프 배율만 곱한다.
## 같은 설계 웨이브가 루프마다 얼마나 세지는지(=난이도가 톱니처럼 되돌아가는지) 본다.
func _report_loop_table(policy: String, grouped: Dictionary) -> void:
	var cells: Dictionary = {}
	var loops: Dictionary = {}
	for key in grouped.keys():
		for record in grouped[key]:
			var design: int = int(record["design_index"])
			var loop: int = int(record["loop"])
			loops[loop] = true
			var cell_key: String = "%d/%d" % [design, loop]
			if not cells.has(cell_key):
				cells[cell_key] = {"ratio": [] as Array[float], "hp_mult": [] as Array[float]}
			var seconds: float = maxf(float(record["t_end"]) - float(record["t_start"]), 0.1)
			var enemy_hps: float = float(record["spawned"]) * float(record["mean_enemy_hp"]) / seconds
			cells[cell_key]["ratio"].append(float(record["dmg_dealt"]) / seconds / maxf(enemy_hps, 0.01))
			cells[cell_key]["hp_mult"].append(float(record["hp_mult"]))
	var loop_keys: Array = loops.keys()
	loop_keys.sort()
	if loop_keys.size() < 2:
		return
	_log("")
	_log("[RUN/%s] 루프별 동일 설계 웨이브의 여유배수 (웨이브 소진 후 되돌아감 확인)" % policy)
	var header: String = "  설계웨이브 |"
	for loop in loop_keys:
		header += " 루프%d      |" % int(loop)
	_log(header)
	for design in range(1, ContentDB.get_waves().size() + 1):
		var line: String = "  %10d |" % design
		for loop in loop_keys:
			var cell: Variant = cells.get("%d/%d" % [design, int(loop)], null)
			if cell == null:
				line += "      —     |"
			else:
				line += " %5.2f(x%.2f)|" % [_mean(cell["ratio"]), _mean(cell["hp_mult"])]
		_log(line)

## 성장(플레이어 DPS)과 강화(적 HP 유입)의 웨이브당 증가율을 비교한다.
## 이 비율이 계속 커지면 후반이 시시해지고, 계속 작아지면 즉사 구간이 생긴다.
func _report_slopes(policy: String, runs: Array) -> void:
	var grouped: Dictionary = _group_waves(runs)
	var keys: Array = grouped.keys()
	keys.sort()
	if keys.size() < 2:
		return
	_log("")
	_log("[RUN/%s] 성장 대 강화 기울기" % policy)
	_log("  웨 | 플레이어DPS | 웨이브당증가 | 적HP유입/초 | 웨이브당증가 | 여유배수 | 배수변화")
	var prev_dps: float = 0.0
	var prev_pressure: float = 0.0
	var prev_ratio: float = 0.0
	var first_dps: float = 0.0
	var first_pressure: float = 0.0
	var last_dps: float = 0.0
	var last_pressure: float = 0.0
	for key in keys:
		var group: Array = grouped[key]
		var dps_values: Array[float] = []
		var pressure_values: Array[float] = []
		for record in group:
			var seconds: float = maxf(float(record["t_end"]) - float(record["t_start"]), 0.1)
			dps_values.append(float(record["dmg_dealt"]) / seconds)
			pressure_values.append(float(record["spawned"]) * float(record["mean_enemy_hp"]) / seconds)
		var dps: float = _mean(dps_values)
		var pressure: float = _mean(pressure_values)
		var ratio: float = dps / maxf(pressure, 0.01)
		if first_dps == 0.0:
			first_dps = dps
			first_pressure = pressure
		last_dps = dps
		last_pressure = pressure
		_log("  %2d | %11.1f | %11s%% | %11.1f | %11s%% | %8.2f | %7s%%" % [
			int(key), dps, _growth(prev_dps, dps), pressure, _growth(prev_pressure, pressure),
			ratio, _growth(prev_ratio, ratio),
		])
		prev_dps = dps
		prev_pressure = pressure
		prev_ratio = ratio
	# 웨이브가 소진되면 난이도가 1번 웨이브로 되돌아가므로, 저자가 설계한 램프(첫 루프)만으로
	# 기울기를 계산한다. 루프 구간을 섞으면 톱니 때문에 평균이 무의미해진다.
	var authored: int = ContentDB.get_waves().size()
	var first_authored_dps: float = 0.0
	var first_authored_pressure: float = 0.0
	var last_authored_dps: float = 0.0
	var last_authored_pressure: float = 0.0
	var authored_steps: float = 0.0
	for key in keys:
		if int(key) > authored:
			continue
		var group: Array = grouped[key]
		var dps_values: Array[float] = []
		var pressure_values: Array[float] = []
		for record in group:
			var seconds: float = maxf(float(record["t_end"]) - float(record["t_start"]), 0.1)
			dps_values.append(float(record["dmg_dealt"]) / seconds)
			pressure_values.append(float(record["spawned"]) * float(record["mean_enemy_hp"]) / seconds)
		if first_authored_dps == 0.0:
			first_authored_dps = _mean(dps_values)
			first_authored_pressure = _mean(pressure_values)
		else:
			authored_steps += 1.0
		last_authored_dps = _mean(dps_values)
		last_authored_pressure = _mean(pressure_values)
	if authored_steps > 0.0 and first_authored_dps > 0.0 and first_authored_pressure > 0.0:
		var dps_cagr: float = (pow(last_authored_dps / first_authored_dps, 1.0 / authored_steps) - 1.0) * 100.0
		var pressure_cagr: float = (pow(last_authored_pressure / first_authored_pressure, 1.0 / authored_steps) - 1.0) * 100.0
		_log("  설계 웨이브 1→%d 웨이브당 기하평균 증가율: 플레이어 %+.1f%% vs 적 %+.1f%% → 격차 %+.1f%%p/웨이브" % [
			authored, dps_cagr, pressure_cagr, dps_cagr - pressure_cagr
		])
	# prev_* 는 표 출력용으로만 쓰였고, first/last 는 위 블록에서 다시 계산한다.
	if first_dps > 0.0 and last_dps > 0.0 and first_pressure > 0.0 and last_pressure > 0.0:
		_log("  (참고) 관측 전체 구간 %d→%d: 플레이어 %.0f→%.0f DPS, 적 %.0f→%.0f HP/s" % [
			int(keys.front()), int(keys.back()), first_dps, last_dps, first_pressure, last_pressure
		])

func _growth(previous: float, current: float) -> String:
	if previous <= 0.0:
		return "    —"
	return "%+5.1f" % ((current / previous - 1.0) * 100.0)

func _report_levels(policy: String, runs: Array) -> void:
	_log("")
	_log("[RUN/%s] 레벨업 시점 (시드 평균)" % policy)
	_log("  레벨 | 필요XP | 누적XP | 도달시각    | 도달웨이브   | 도달한시드")
	var by_level: Dictionary = {}
	for run in runs:
		for event in run.get("levels", []):
			var level: int = int(event["level"])
			if not by_level.has(level):
				by_level[level] = {"times": [] as Array[float], "waves": [] as Array[float]}
			by_level[level]["times"].append(float(event["time"]))
			by_level[level]["waves"].append(float(event["wave"]))
	var keys: Array = by_level.keys()
	keys.sort()
	var cumulative: int = 0
	for key in keys:
		var level: int = int(key)
		var need: int = int(round(RunState.BASE_XP * pow(float(level - 1), RunState.XP_GROWTH)))
		cumulative += need
		_log("  %4d | %6d | %6d | %-11s | %-12s | %10d" % [
			level, need, cumulative,
			_stat(by_level[key]["times"], 1), _stat(by_level[key]["waves"], 1),
			by_level[key]["times"].size(),
		])

func _report_economy(policy: String, runs: Array) -> void:
	_log("")
	_log("[RUN/%s] 먹이 수급 대 상점 물가" % policy)
	_log("  웨 | 상점입장먹이 | 상품평균가   | 최저가 | 리롤가 | 살수있는개수")
	var by_wave: Dictionary = {}
	for run in runs:
		for visit in run.get("shops", []):
			var wave: int = int(visit["wave"])
			if not by_wave.has(wave):
				by_wave[wave] = {"feed": [] as Array[float], "mean": [] as Array[float], "cheap": [] as Array[float], "reroll": [] as Array[float], "afford": [] as Array[float]}
			by_wave[wave]["feed"].append(float(visit["feed"]))
			by_wave[wave]["mean"].append(float(visit["mean_cost"]))
			by_wave[wave]["cheap"].append(float(visit["cheapest"]))
			by_wave[wave]["reroll"].append(float(visit["reroll"]))
			by_wave[wave]["afford"].append(float(visit["feed"]) / maxf(float(visit["mean_cost"]), 1.0))
	var keys: Array = by_wave.keys()
	keys.sort()
	for key in keys:
		var entry: Dictionary = by_wave[key]
		_log("  %2d | %-12s | %-12s | %6.1f | %6.1f | %11.2f" % [
			int(key), _stat(entry["feed"], 1), _stat(entry["mean"], 1),
			_mean(entry["cheap"]), _mean(entry["reroll"]), _mean(entry["afford"]),
		])
	var totals: Array[float] = []
	var spent: Array[float] = []
	for run in runs:
		totals.append(float(int(run["feed"]) + int(run["feed_spent"])))
		spent.append(float(run["feed_spent"]))
	_log("  런 전체 먹이 획득 %s / 사용 %s" % [_stat(totals, 1), _stat(spent, 1)])

func _report_pool_usage() -> void:
	_log("")
	_log("[POOL] 변이 등장·선택 빈도 (전체 실행 합계)")
	_log("  변이                 | 등급 | 카드등장 | 카드선택 | 선택률 | 상점등장 | 상점구매")
	for data in _sorted_mutations():
		var offered: int = int(_offer_counts.get(data.id, 0))
		var chosen: int = int(_chosen_counts.get(data.id, 0))
		_log("  %-20s | %4s | %8d | %8d | %5.1f%% | %8d | %8d" % [
			data.id, _rarity_name(data.rarity), offered, chosen,
			0.0 if offered == 0 else float(chosen) / float(offered) * 100.0,
			int(_shop_offer_counts.get(data.id, 0)), int(_shop_bought_counts.get(data.id, 0)),
		])

func _group_waves(runs: Array) -> Dictionary:
	var grouped: Dictionary = {}
	for run in runs:
		for record in run.get("waves", []):
			var copy: Dictionary = record.duplicate()
			copy["seed"] = int(run.get("seed", 0))
			var key: int = int(copy["wave"])
			if not grouped.has(key):
				grouped[key] = []
			grouped[key].append(copy)
	return grouped

func _write_csv() -> void:
	if _csv_path.is_empty() or _csv_rows.is_empty():
		return
	var file: FileAccess = FileAccess.open(_csv_path, FileAccess.WRITE)
	if file == null:
		_log("CSV 쓰기 실패: %s" % _csv_path)
		return
	file.store_line("policy,seed,wave,design_index,seconds,hp_end,hp_min,kills,spawned,player_dps,enemy_hp_per_s,mean_enemy_hp,ratio,damage_taken_per_s,level_end")
	for row in _csv_rows:
		file.store_line(row)
	file.close()
	_log("CSV 저장: %s (%d행)" % [_csv_path, _csv_rows.size()])

# ================================================================ 유틸

func _sorted(values: Array) -> Array:
	var copy: Array = values.duplicate()
	copy.sort()
	return copy

func _sorted_mutations() -> Array[MutationData]:
	var list: Array[MutationData] = ContentDB.get_mutations().duplicate()
	list.sort_custom(func(a: MutationData, b: MutationData) -> bool: return a.id < b.id)
	return list

func _mean(values: Array) -> float:
	if values.is_empty():
		return 0.0
	var total: float = 0.0
	for value in values:
		total += float(value)
	return total / float(values.size())

func _mean_int(values: Array[int]) -> float:
	var converted: Array[float] = []
	for value in values:
		converted.append(float(value))
	return _mean(converted)

func _stddev(values: Array) -> float:
	if values.size() < 2:
		return 0.0
	var average: float = _mean(values)
	var total: float = 0.0
	for value in values:
		total += pow(float(value) - average, 2.0)
	return sqrt(total / float(values.size() - 1))

func _stat(values: Array, decimals: int) -> String:
	if values.is_empty():
		return "—"
	return "%.*f±%.*f" % [decimals, _mean(values), decimals, _stddev(values)]

func _start_game(with_movement: bool, autopilot_ui: bool) -> void:
	var packed: PackedScene = load(GAME_SCENE_PATH)
	if packed == null:
		_log("game.tscn 로드 실패")
		return
	_game = packed.instantiate()
	get_tree().root.add_child(_game)
	await get_tree().process_frame
	await get_tree().physics_frame
	_autopilot = TestAutopilot.new()
	_autopilot.name = "BalanceAutopilot"
	_autopilot.control_movement = with_movement
	_autopilot.auto_resolve_ui = autopilot_ui
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

## 벤치 측정 창은 물리 프레임 수로 센다. delta 누적은 Engine.time_scale(히트스톱)이나
## 프레임 드랍에 흔들려서 시드가 같아도 측정 구간 길이가 달라진다.
func _simulate(seconds: float) -> void:
	var ticks: int = int(round(seconds * float(Engine.physics_ticks_per_second)))
	for _i in ticks:
		await get_tree().physics_frame

## 살아 있는 투사체·근접 궤적·장판을 전부 풀로 돌려보낸다.
func _clear_attacks() -> void:
	for pool in _game.get_attack_pools().get_pools():
		for child in pool.get_children():
			pool.release(child)

## 게임 씬이 뜨는 동안 스포너가 웨이브 1 배치를 이미 뿌려놓는다. 허수아비 배치 전에 비운다.
func _clear_animals() -> void:
	var pool: ObjectPool = _game.get_animal_pool()
	for node in get_tree().get_nodes_in_group("animal"):
		var animal: Animal = node as Animal
		if animal != null and is_instance_valid(animal):
			pool.release(animal)

func _alive_count() -> int:
	return get_tree().get_nodes_in_group("animal").size()

func _drain_audio() -> void:
	var audio: Node = get_node_or_null("/root/AudioManager")
	if audio == null:
		return
	audio.stop_all()
	for _i in 8:
		await get_tree().process_frame

func _log(message: String) -> void:
	print(message)
