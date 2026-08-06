class_name AnimalSpawner
extends Node2D
## 화면 밖 원형 가장자리에서 동물을 스폰한다. 스폰 종류·간격·배율은 WaveDirector가 제공한다.

@export var spawn_radius: float = 780.0
## 동시에 살아 있을 수 있는 동물 수 상한(성능·풀 폭주 방지).
@export var max_alive: int = 260
@export var elite_hp_mult: float = 6.0
@export var elite_speed_mult: float = 0.8
@export var elite_damage_mult: float = 1.6

var _pool: ObjectPool
var _target: Node2D
var _director: WaveDirector
var _timer_left: float = 0.0
var _spawned_total: int = 0

func setup(pool: ObjectPool, target: Node2D, director: WaveDirector) -> void:
	_pool = pool
	_target = target
	_director = director

func get_spawned_total() -> int:
	return _spawned_total

func _physics_process(delta: float) -> void:
	if _pool == null or _target == null or _director == null or RunState.is_game_over:
		return
	_timer_left -= delta
	if _timer_left > 0.0:
		return
	_timer_left = _director.get_spawn_interval()
	_spawn_batch()

func _spawn_batch() -> void:
	var alive: int = get_tree().get_nodes_in_group("animal").size()
	var budget: int = mini(_director.get_batch_size(), max_alive - alive)
	for _i in maxi(budget, 0):
		_spawn_one()

func _spawn_one() -> void:
	var data: AnimalData = _director.pick_animal()
	if data == null:
		return
	var animal: Node = _pool.acquire()
	if animal == null:
		return
	var is_elite: bool = randf() < _director.get_elite_chance()
	var hp_mult: float = _director.get_hp_mult()
	var speed_mult: float = _director.get_speed_mult()
	var damage_mult: float = _director.get_damage_mult()
	if is_elite:
		hp_mult *= elite_hp_mult
		speed_mult *= elite_speed_mult
		damage_mult *= elite_damage_mult
	animal.setup(data, _random_spawn_position(), _target, hp_mult, speed_mult, damage_mult, is_elite)
	_spawned_total += 1

func _random_spawn_position() -> Vector2:
	var angle: float = randf() * TAU
	return _target.global_position + Vector2(cos(angle), sin(angle)) * spawn_radius
