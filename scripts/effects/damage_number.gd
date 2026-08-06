class_name DamageNumber
extends Node2D
## 피격 지점에서 위로 떠오르며 사라지는 데미지 숫자. 풀에서 재사용된다.

@export var duration: float = 0.45
@export var rise_speed: float = 62.0
@export var spread: float = 14.0
@export var color: Color = Color(1.0, 0.906, 0.702, 1.0)

var _pool: ObjectPool
var _life_left: float = 0.0

@onready var _label: Label = $Label

func set_pool(pool: ObjectPool) -> void:
	_pool = pool

func setup(spawn_pos: Vector2, amount: float) -> void:
	global_position = spawn_pos + Vector2(randf_range(-spread, spread), randf_range(-spread, 0.0))
	_life_left = duration
	_label.text = str(maxi(int(round(amount)), 1))
	_label.modulate = color

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
	position.y -= rise_speed * delta
	_label.modulate.a = clampf(_life_left / duration * 1.6, 0.0, 1.0)

func _return_to_pool() -> void:
	if _pool != null:
		_pool.release(self)
	else:
		queue_free()
