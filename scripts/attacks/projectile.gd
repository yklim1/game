class_name Projectile
extends Area2D
## PROJECTILE 형태 공격. 이동·수명·충돌·데미지 처리. 풀에서 재사용된다.

var _pool: ObjectPool
var _direction: Vector2 = Vector2.RIGHT
var _speed: float = 0.0
var _damage: float = 0.0
var _life_left: float = 0.0
var _pierce_left: int = 0
var _released: bool = true
var _fallback_texture: Texture2D
var _fallback_size: float = 0.0

@onready var _sprite: Sprite2D = $Sprite

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	# 여러 능력이 같은 투사체 씬(=같은 풀)을 공유하므로 폴백 텍스처와 기본 크기를 기억해 둔다.
	_fallback_texture = _sprite.texture
	_fallback_size = SpriteVisual.measure_display_size(_sprite)

func set_pool(pool: ObjectPool) -> void:
	_pool = pool

func setup(ability: AbilityData, origin: Vector2, dir: Vector2, damage: float) -> void:
	global_position = origin
	_direction = dir
	_damage = damage
	_speed = ability.projectile_speed
	_life_left = ability.projectile_lifetime
	_pierce_left = ability.pierce
	rotation = dir.angle()
	var size: float = ability.projectile_size if ability.projectile_size > 0.0 else _fallback_size
	var uses_art: bool = SpriteVisual.apply(_sprite, ability.attack_texture, _fallback_texture, size)
	_sprite.self_modulate = SpriteVisual.resolve_tint(uses_art, ability.color, ability.tint_attack_texture)

func on_acquire() -> void:
	_released = false
	visible = true
	set_physics_process(true)
	set_deferred("monitoring", true)

func on_release() -> void:
	_released = true
	visible = false
	set_physics_process(false)
	set_deferred("monitoring", false)

func _physics_process(delta: float) -> void:
	global_position += _direction * _speed * delta
	_life_left -= delta
	if _life_left <= 0.0:
		_return_to_pool()

func _on_body_entered(body: Node) -> void:
	if _released or not body.is_in_group("animal"):
		return
	if body.has_method("take_damage"):
		body.take_damage(_damage, _direction)
	_pierce_left -= 1
	if _pierce_left < 0:
		_return_to_pool()

func _return_to_pool() -> void:
	if _released:
		return
	if _pool != null:
		_pool.release(self)
	else:
		queue_free()
