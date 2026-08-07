class_name Animal
extends CharacterBody2D
## 동물 적. 플레이어를 추격하고 접촉 피해를 준다. HP가 0이 되면 사망 시그널을 쏘고 풀로 돌아간다.

const ELITE_RADIUS_MULT: float = 1.6
const ELITE_COLOR_BLEND: float = 0.45
const ELITE_COLOR: Color = Color(1.0, 0.69, 0.13, 1.0)
const ELITE_ESSENCE_BONUS: int = 4

## 피격 순간 플레이스홀더 스프라이트를 이 색으로 물들인다.
@export var hit_flash_color: Color = Color(1.0, 1.0, 1.0, 1.0)
## 실제 스프라이트일 때의 플래시 배율. 흰색으로 덮으면 아트 형태가 사라지므로 원래 색을 이만큼 밝힌다.
@export var hit_flash_texture_gain: float = 1.9
## 플래시가 원래 색으로 돌아오기까지의 시간(초).
@export var hit_flash_duration: float = 0.09
## 피격 방향으로 밀리는 초기 속도(픽셀/초).
@export var knockback_strength: float = 210.0
## 넉백 속도가 0으로 줄어드는 감속(픽셀/초²). 클수록 짧게 밀린다.
@export var knockback_decay: float = 1100.0
## 엘리트는 넉백을 덜 받는다(0~1).
@export_range(0.0, 1.0) var knockback_elite_mult: float = 0.5

var _pool: ObjectPool
var _data: AnimalData
var _hp: float = 0.0
var _speed: float = 0.0
var _contact_damage: float = 0.0
var _essence_value: int = 0
var _is_elite: bool = false
var _alive: bool = false
var _wobble_strength: float = 0.0
var _wobble_speed: float = 0.0
var _wobble_phase: float = 0.0
var _target: Node2D
var _base_color: Color = Color.WHITE
var _flash_left: float = 0.0
var _knockback: Vector2 = Vector2.ZERO
var _uses_art: bool = false
var _fallback_texture: Texture2D

@onready var _sprite: Sprite2D = $Sprite
@onready var _shape: CollisionShape2D = $CollisionShape2D

## 데이터에 스프라이트가 없을 때 되돌아갈 플레이스홀더를 기억해 둔다(풀에서 재사용되므로 필수).
func _ready() -> void:
	_fallback_texture = _sprite.texture

func set_pool(pool: ObjectPool) -> void:
	_pool = pool

func setup(
	data: AnimalData,
	spawn_pos: Vector2,
	target: Node2D,
	hp_mult: float,
	speed_mult: float,
	damage_mult: float,
	is_elite: bool
) -> void:
	_data = data
	_target = target
	_is_elite = is_elite
	global_position = spawn_pos
	_hp = data.max_hp * hp_mult
	_speed = data.move_speed * speed_mult
	_contact_damage = data.contact_damage * damage_mult
	_essence_value = data.essence_value + (ELITE_ESSENCE_BONUS if is_elite else 0)
	_wobble_strength = data.wobble_strength
	_wobble_speed = data.wobble_speed
	_wobble_phase = randf() * TAU
	_flash_left = 0.0
	_knockback = Vector2.ZERO
	_alive = true
	_apply_visuals(data)

func _apply_visuals(data: AnimalData) -> void:
	var radius: float = data.radius
	var color: Color = data.color
	var size_mult: float = 1.0
	if _is_elite:
		radius *= ELITE_RADIUS_MULT
		size_mult = ELITE_RADIUS_MULT
		color = color.lerp(ELITE_COLOR, ELITE_COLOR_BLEND)
	var display_size: float = data.sprite_size if data.sprite_size > 0.0 else data.radius * 2.0
	_uses_art = SpriteVisual.apply(_sprite, data.sprite, _fallback_texture, display_size * size_mult)
	_base_color = SpriteVisual.resolve_tint(_uses_art, color, data.tint_sprite)
	_sprite.modulate = _base_color
	var circle: CircleShape2D = _shape.shape as CircleShape2D
	if circle != null:
		circle.radius = radius

func get_contact_damage() -> float:
	return _contact_damage

func is_elite() -> bool:
	return _is_elite

## 데이터에 정의된 원래 색(엘리트 보정 포함). 히트 플래시 복귀 검증용.
func get_base_color() -> Color:
	return _base_color

func get_sprite_color() -> Color:
	return _sprite.modulate

## 데이터에 실제 스프라이트가 지정돼 그려지고 있으면 true, 플레이스홀더 폴백이면 false.
func is_using_sprite_art() -> bool:
	return _uses_art

func is_hit_flashing() -> bool:
	return _flash_left > 0.0

func on_acquire() -> void:
	visible = true
	set_physics_process(true)
	add_to_group("animal")
	_shape.set_deferred("disabled", false)

func on_release() -> void:
	_alive = false
	visible = false
	set_physics_process(false)
	remove_from_group("animal")
	_target = null
	velocity = Vector2.ZERO
	_flash_left = 0.0
	_knockback = Vector2.ZERO
	_shape.set_deferred("disabled", true)

func _physics_process(delta: float) -> void:
	_update_flash(delta)
	if _target == null or not is_instance_valid(_target):
		return
	var dir: Vector2 = (_target.global_position - global_position).normalized()
	if _wobble_strength > 0.0:
		_wobble_phase += _wobble_speed * delta
		dir = (dir + dir.orthogonal() * sin(_wobble_phase) * _wobble_strength).normalized()
	velocity = dir * _speed + _knockback
	if _knockback != Vector2.ZERO:
		_knockback = _knockback.move_toward(Vector2.ZERO, knockback_decay * delta)
	move_and_slide()

func _update_flash(delta: float) -> void:
	if _flash_left <= 0.0:
		return
	_flash_left -= delta
	if _flash_left <= 0.0:
		_flash_left = 0.0
		_sprite.modulate = _base_color

## 피격 순간 실제로 쓰이는 플래시 색.
## 플레이스홀더는 지금까지처럼 흰색으로 덮고, 실제 스프라이트는 원래 색을 밝혀 형태를 유지한다.
func get_flash_color() -> Color:
	if not _uses_art:
		return hit_flash_color
	return Color(
		_base_color.r * hit_flash_texture_gain,
		_base_color.g * hit_flash_texture_gain,
		_base_color.b * hit_flash_texture_gain,
		_base_color.a
	)

## hit_direction 이 0이 아니면 그 방향으로 넉백된다(정규화는 내부에서 처리).
func take_damage(amount: float, hit_direction: Vector2 = Vector2.ZERO) -> void:
	if not _alive:
		return
	_hp -= amount
	_apply_hit_feedback(hit_direction)
	EventBus.animal_hit.emit(global_position, amount)
	if _hp <= 0.0:
		_die()

func _apply_hit_feedback(hit_direction: Vector2) -> void:
	_flash_left = hit_flash_duration
	_sprite.modulate = get_flash_color()
	if hit_direction == Vector2.ZERO or knockback_strength <= 0.0:
		return
	var strength: float = knockback_strength * (knockback_elite_mult if _is_elite else 1.0)
	_knockback = hit_direction.normalized() * strength

func _die() -> void:
	if not _alive:
		return
	_alive = false
	EventBus.animal_died.emit(global_position, _data, _essence_value)
	_return_to_pool()

func _return_to_pool() -> void:
	if _pool != null:
		_pool.release(self)
	else:
		queue_free()
