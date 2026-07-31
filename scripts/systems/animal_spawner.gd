class_name AnimalSpawner
extends Node2D
## 화면 밖 원형 가장자리에서 적을 스폰. 시간이 지날수록 간격 단축·배치 수 증가(웨이브 스케일링).

@export var animal_data: AnimalData
@export var base_interval: float = 1.1
@export var min_interval: float = 0.3
@export var interval_decay_per_sec: float = 0.015
@export var spawn_radius: float = 780.0
@export var batch_start: int = 1
@export var seconds_per_extra_spawn: float = 18.0
@export var hp_growth_per_min: float = 0.5
@export var speed_growth_per_min: float = 0.12

var _pool: ObjectPool
var _target: Node2D
var _timer_left: float = 0.0

func setup(pool: ObjectPool, target: Node2D) -> void:
	_pool = pool
	_target = target

func _physics_process(delta: float) -> void:
	if _pool == null or _target == null or RunState.is_game_over:
		return
	_timer_left -= delta
	if _timer_left <= 0.0:
		_spawn_batch()
		_timer_left = _current_interval()

func _current_interval() -> float:
	var reduced: float = base_interval - RunState.elapsed_time * interval_decay_per_sec
	return maxf(min_interval, reduced)

func _current_batch_size() -> int:
	return batch_start + int(RunState.elapsed_time / seconds_per_extra_spawn)

func _spawn_batch() -> void:
	var minutes: float = RunState.elapsed_time / 60.0
	var hp_mult: float = 1.0 + minutes * hp_growth_per_min
	var speed_mult: float = 1.0 + minutes * speed_growth_per_min
	for _i in _current_batch_size():
		_spawn_one(hp_mult, speed_mult)

func _spawn_one(hp_mult: float, speed_mult: float) -> void:
	if animal_data == null:
		return
	var angle: float = randf() * TAU
	var pos: Vector2 = _target.global_position + Vector2(cos(angle), sin(angle)) * spawn_radius
	var animal: Node = _pool.acquire()
	animal.setup(animal_data, pos, _target, hp_mult, speed_mult)
