class_name DeathBurst
extends Node2D
## 동물 사망 시 사방으로 튀는 스프라이트 조각 연출. 풀에서 재사용된다.
## 파티클 노드 대신 미리 만들어 둔 조각 스프라이트를 직접 움직여 대량 사망 시 부담을 줄인다.

## 실제로 사용할 조각 수(씬에 있는 Shard 노드 수가 상한).
@export var shard_count: int = 6
@export var duration: float = 0.34
@export var speed_min: float = 90.0
@export var speed_max: float = 230.0
## 조각이 시간이 지나며 느려지는 비율(1.0 = 감속 없음).
@export_range(0.0, 1.0) var drag: float = 0.86
@export var shard_scale: float = 0.05

var _pool: ObjectPool
var _life_left: float = 0.0
var _shards: Array[Sprite2D] = []
var _velocities: Array[Vector2] = []

func _ready() -> void:
	for child in get_children():
		var shard: Sprite2D = child as Sprite2D
		if shard != null:
			_shards.append(shard)
			_velocities.append(Vector2.ZERO)

func set_pool(pool: ObjectPool) -> void:
	_pool = pool

func setup(spawn_pos: Vector2, color: Color) -> void:
	global_position = spawn_pos
	_life_left = duration
	var used: int = mini(shard_count, _shards.size())
	var base_angle: float = randf() * TAU
	for i in _shards.size():
		var shard: Sprite2D = _shards[i]
		if i >= used:
			shard.visible = false
			_velocities[i] = Vector2.ZERO
			continue
		var angle: float = base_angle + TAU * float(i) / float(used) + randf_range(-0.3, 0.3)
		_velocities[i] = Vector2(cos(angle), sin(angle)) * randf_range(speed_min, speed_max)
		shard.visible = true
		shard.position = Vector2.ZERO
		shard.scale = Vector2.ONE * shard_scale
		shard.self_modulate = color

func on_acquire() -> void:
	visible = true
	set_process(true)

func on_release() -> void:
	visible = false
	set_process(false)
	_life_left = 0.0

func _process(delta: float) -> void:
	_life_left -= delta
	if _life_left <= 0.0:
		_return_to_pool()
		return
	var ratio: float = _life_left / duration
	var damping: float = pow(drag, delta * 60.0)
	for i in _shards.size():
		var shard: Sprite2D = _shards[i]
		if not shard.visible:
			continue
		shard.position += _velocities[i] * delta
		_velocities[i] *= damping
		shard.self_modulate.a = ratio
		shard.scale = Vector2.ONE * shard_scale * (0.4 + 0.6 * ratio)

func _return_to_pool() -> void:
	if _pool != null:
		_pool.release(self)
	else:
		queue_free()
