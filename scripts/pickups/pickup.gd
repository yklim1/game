class_name Pickup
extends Node2D
## 바닥에 떨어지는 픽업(특성 정수 젬 / 먹이). 이동·흡수 판정은 PickupManager가 일괄 처리한다.
## 물리 노드를 쓰지 않아 대량으로 깔려도 부담이 적다.

enum Kind { ESSENCE, FEED }

@export var essence_color: Color = Color(1.0, 0.882, 0.302, 1.0)
@export var feed_color: Color = Color(1.0, 0.353, 0.847, 1.0)
@export var essence_scale: float = 0.09
@export var feed_scale: float = 0.12

var kind: Kind = Kind.ESSENCE
var value: int = 1

var _pool: ObjectPool

@onready var _sprite: Sprite2D = $Sprite

func set_pool(pool: ObjectPool) -> void:
	_pool = pool

func get_pool() -> ObjectPool:
	return _pool

func setup(pickup_kind: Kind, pickup_value: int, spawn_pos: Vector2) -> void:
	kind = pickup_kind
	value = pickup_value
	global_position = spawn_pos
	if kind == Kind.FEED:
		_sprite.self_modulate = feed_color
		_sprite.scale = Vector2.ONE * feed_scale
	else:
		_sprite.self_modulate = essence_color
		_sprite.scale = Vector2.ONE * essence_scale

func on_acquire() -> void:
	visible = true
	add_to_group("pickup")

func on_release() -> void:
	visible = false
	remove_from_group("pickup")
