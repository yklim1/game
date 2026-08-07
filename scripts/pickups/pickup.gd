class_name Pickup
extends Node2D
## 바닥에 떨어지는 픽업(특성 정수 젬 / 먹이). 이동·흡수 판정은 PickupManager가 일괄 처리한다.
## 물리 노드를 쓰지 않아 대량으로 깔려도 부담이 적다.

enum Kind { ESSENCE, FEED }

@export var essence_color: Color = Color(1.0, 0.882, 0.302, 1.0)
@export var feed_color: Color = Color(1.0, 0.353, 0.847, 1.0)
## 실제 스프라이트(투명 PNG). 비우면 플레이스홀더를 위 색으로 물들여 쓴다.
@export var essence_texture: Texture2D
@export var feed_texture: Texture2D
## 화면 표시 크기(px, 긴 변). 텍스처 해상도와 무관하게 이 크기로 그려진다.
@export var essence_size: float = 12.0
@export var feed_size: float = 16.0

var kind: Kind = Kind.ESSENCE
var value: int = 1

var _pool: ObjectPool
var _fallback_texture: Texture2D

@onready var _sprite: Sprite2D = $Sprite

func _ready() -> void:
	_fallback_texture = _sprite.texture

func set_pool(pool: ObjectPool) -> void:
	_pool = pool

func get_pool() -> ObjectPool:
	return _pool

func setup(pickup_kind: Kind, pickup_value: int, spawn_pos: Vector2) -> void:
	kind = pickup_kind
	value = pickup_value
	global_position = spawn_pos
	var is_feed: bool = kind == Kind.FEED
	var texture: Texture2D = feed_texture if is_feed else essence_texture
	var color: Color = feed_color if is_feed else essence_color
	var uses_art: bool = SpriteVisual.apply(
		_sprite, texture, _fallback_texture, feed_size if is_feed else essence_size
	)
	_sprite.self_modulate = SpriteVisual.resolve_tint(uses_art, color, false)

func on_acquire() -> void:
	visible = true
	add_to_group("pickup")

func on_release() -> void:
	visible = false
	remove_from_group("pickup")
