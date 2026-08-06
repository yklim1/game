class_name WaveDirector
extends Node
## 웨이브 진행(시간·스폰테이블·배율)을 관리한다. 웨이브 정의는 ContentDB가 로드한 WaveData(.tres).
## 마지막 웨이브 이후에는 마지막 웨이브를 반복하며 배율만 계속 올린다(엔드리스).

## 마지막 웨이브를 한 번 더 돌 때마다 곱해지는 추가 배율.
@export var loop_hp_mult: float = 1.35
@export var loop_speed_mult: float = 1.06
@export var loop_damage_mult: float = 1.15
@export var loop_elite_bonus: float = 0.08
## 웨이브 종료 후 소굴 상점이 닫힐 때까지 다음 웨이브를 미룬다.
@export var wait_for_shop: bool = true
## 마지막 웨이브를 한 번 더 돌 때마다 클리어 보상 먹이에 더해지는 값.
@export var loop_feed_bonus: int = 4

var _waves: Array[WaveData] = []
var _current_index: int = -1
var _loop_count: int = 0
var _time_left: float = 0.0
var _awaiting_shop: bool = false
var _fallback: WaveData

func _ready() -> void:
	EventBus.shop_closed.connect(_on_shop_closed)
	_waves = ContentDB.get_waves()
	if _waves.is_empty():
		push_warning("WaveDirector: 웨이브 데이터가 없어 기본 웨이브로 진행합니다.")
		_fallback = WaveData.new()
		_fallback.spawn_ids.assign(ContentDB.get_animal_ids())
		_waves = [_fallback]

## 첫 웨이브 시작. 런 데이터 초기화 이후에 호출되도록 Game이 명시적으로 부른다.
func begin() -> void:
	_current_index = -1
	_loop_count = 0
	_awaiting_shop = false
	_start_wave(0)

func is_awaiting_shop() -> bool:
	return _awaiting_shop

func _process(delta: float) -> void:
	if RunState.is_game_over or _current_index < 0 or _awaiting_shop:
		return
	var wave: WaveData = get_current_wave()
	if wave == null or wave.duration <= 0.0:
		return
	_time_left -= delta
	if _time_left <= 0.0:
		_end_wave(wave)

func _end_wave(wave: WaveData) -> void:
	var reward: int = maxi(wave.feed_reward + loop_feed_bonus * _loop_count, 0)
	if reward > 0:
		EventBus.feed_collected.emit(reward)
	EventBus.wave_ended.emit(get_wave_number())
	if wait_for_shop:
		_awaiting_shop = true
	else:
		_advance()

func _on_shop_closed() -> void:
	if not _awaiting_shop:
		return
	_awaiting_shop = false
	_advance()

func get_current_wave() -> WaveData:
	if _current_index < 0 or _current_index >= _waves.size():
		return null
	return _waves[_current_index]

func get_wave_number() -> int:
	var wave: WaveData = get_current_wave()
	if wave == null:
		return 0
	return wave.index + _loop_count * _waves.size()

func get_time_left() -> float:
	return maxf(_time_left, 0.0)

func get_hp_mult() -> float:
	var wave: WaveData = get_current_wave()
	if wave == null:
		return 1.0
	return wave.hp_mult * pow(loop_hp_mult, float(_loop_count))

func get_speed_mult() -> float:
	var wave: WaveData = get_current_wave()
	if wave == null:
		return 1.0
	return wave.speed_mult * pow(loop_speed_mult, float(_loop_count))

func get_damage_mult() -> float:
	var wave: WaveData = get_current_wave()
	if wave == null:
		return 1.0
	return wave.damage_mult * pow(loop_damage_mult, float(_loop_count))

func get_elite_chance() -> float:
	var wave: WaveData = get_current_wave()
	if wave == null:
		return 0.0
	return clampf(wave.elite_chance + loop_elite_bonus * float(_loop_count), 0.0, 1.0)

func get_spawn_interval() -> float:
	var wave: WaveData = get_current_wave()
	if wave == null:
		return 1.0
	return maxf(wave.spawn_interval, 0.05)

func get_batch_size() -> int:
	var wave: WaveData = get_current_wave()
	if wave == null:
		return 0
	return maxi(wave.batch_size, 0)

## 현재 웨이브 스폰 테이블에서 AnimalData.spawn_weight 가중치로 한 마리 고른다.
func pick_animal() -> AnimalData:
	var wave: WaveData = get_current_wave()
	if wave == null or wave.spawn_ids.is_empty():
		return null
	var total_weight: float = 0.0
	var candidates: Array[AnimalData] = []
	for id in wave.spawn_ids:
		var data: AnimalData = ContentDB.get_animal(id)
		if data == null:
			continue
		candidates.append(data)
		total_weight += maxf(data.spawn_weight, 0.0)
	if candidates.is_empty() or total_weight <= 0.0:
		return null
	var roll: float = randf() * total_weight
	for data in candidates:
		roll -= maxf(data.spawn_weight, 0.0)
		if roll <= 0.0:
			return data
	return candidates.back()

func _advance() -> void:
	var next: int = _current_index + 1
	if next >= _waves.size():
		next = 0
		_loop_count += 1
	_start_wave(next)

func _start_wave(index: int) -> void:
	_current_index = index
	var wave: WaveData = get_current_wave()
	if wave == null:
		return
	_time_left = wave.duration
	EventBus.wave_started.emit(get_wave_number(), wave)
