class_name Animal
extends CharacterBody2D
## 동물 적. 플레이어를 추격하고 접촉 피해를 준다. HP가 0이 되면 사망 시그널을 쏘고 풀로 돌아간다.

const ELITE_RADIUS_MULT: float = 1.6
const ELITE_COLOR_BLEND: float = 0.45
const ELITE_COLOR: Color = Color(1.0, 0.69, 0.13, 1.0)
const ELITE_ESSENCE_BONUS: int = 4

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

@onready var _sprite: Sprite2D = $Sprite
@onready var _shape: CollisionShape2D = $CollisionShape2D

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
	_alive = true
	_apply_visuals(data)

func _apply_visuals(data: AnimalData) -> void:
	var radius: float = data.radius
	var color: Color = data.color
	if _is_elite:
		radius *= ELITE_RADIUS_MULT
		color = color.lerp(ELITE_COLOR, ELITE_COLOR_BLEND)
	if data.sprite != null:
		_sprite.texture = data.sprite
	_sprite.modulate = color
	_sprite.scale = Vector2.ONE * (radius * 2.0 / float(_sprite.texture.get_width()))
	var circle: CircleShape2D = _shape.shape as CircleShape2D
	if circle != null:
		circle.radius = radius

func get_contact_damage() -> float:
	return _contact_damage

func is_elite() -> bool:
	return _is_elite

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
	_shape.set_deferred("disabled", true)

func _physics_process(delta: float) -> void:
	if _target == null or not is_instance_valid(_target):
		return
	var dir: Vector2 = (_target.global_position - global_position).normalized()
	if _wobble_strength > 0.0:
		_wobble_phase += _wobble_speed * delta
		dir = (dir + dir.orthogonal() * sin(_wobble_phase) * _wobble_strength).normalized()
	velocity = dir * _speed
	move_and_slide()

func take_damage(amount: float) -> void:
	if not _alive:
		return
	_hp -= amount
	if _hp <= 0.0:
		_die()

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
