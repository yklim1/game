extends Node
## 현재 런의 진행 데이터. 런 종료(재시작) 시 reset()으로 초기화한다.
## 영속(메타) 데이터는 여기에 두지 않는다.

## 레벨업 곡선: xp_to_next = BASE_XP * level ^ XP_GROWTH (DESIGN.md 4.5).
const BASE_XP: float = 5.0
const XP_GROWTH: float = 1.35
## Phase 2 임시 자동 성장치. 3택 변이 카드는 Phase 3 범위.
const DAMAGE_MULT_PER_LEVEL: float = 0.08
const MOVE_SPEED_MULT_PER_LEVEL: float = 0.02
const MAX_HEALTH_PER_LEVEL: float = 4.0

var elapsed_time: float = 0.0
var kills: int = 0
var is_game_over: bool = false

var level: int = 1
var xp: int = 0
var xp_to_next: int = 0
var feed: int = 0
var wave_index: int = 0

var damage_mult: float = 1.0
var move_speed_mult: float = 1.0
var bonus_max_health: float = 0.0

func _ready() -> void:
	reset()
	EventBus.animal_died.connect(_on_animal_died)
	EventBus.player_died.connect(_on_player_died)
	EventBus.essence_collected.connect(_on_essence_collected)
	EventBus.feed_collected.connect(_on_feed_collected)
	EventBus.wave_started.connect(_on_wave_started)

func _process(delta: float) -> void:
	if not is_game_over:
		elapsed_time += delta

func reset() -> void:
	elapsed_time = 0.0
	kills = 0
	is_game_over = false
	level = 1
	xp = 0
	xp_to_next = _xp_required(level)
	feed = 0
	wave_index = 0
	damage_mult = 1.0
	move_speed_mult = 1.0
	bonus_max_health = 0.0

func add_xp(amount: int) -> void:
	if is_game_over or amount <= 0:
		return
	xp += amount
	while xp >= xp_to_next:
		xp -= xp_to_next
		_level_up()
	EventBus.xp_changed.emit(xp, xp_to_next, level)

func _level_up() -> void:
	level += 1
	xp_to_next = _xp_required(level)
	damage_mult += DAMAGE_MULT_PER_LEVEL
	move_speed_mult += MOVE_SPEED_MULT_PER_LEVEL
	bonus_max_health += MAX_HEALTH_PER_LEVEL
	EventBus.player_leveled_up.emit(level)

func _xp_required(for_level: int) -> int:
	return int(round(BASE_XP * pow(float(for_level), XP_GROWTH)))

func _on_animal_died(_position: Vector2, _data: AnimalData, _essence_value: int) -> void:
	kills += 1

func _on_player_died() -> void:
	is_game_over = true

func _on_essence_collected(value: int) -> void:
	add_xp(value)

func _on_feed_collected(value: int) -> void:
	feed += value

func _on_wave_started(index: int, _data: WaveData) -> void:
	wave_index = index
