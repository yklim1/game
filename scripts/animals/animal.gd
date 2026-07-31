class_name Animal
extends CharacterBody2D
## 동물 적. 플레이어를 추격하고 접촉 피해를 준다. 투사체에 맞으면 사망. 풀에서 재사용된다.

var _pool: ObjectPool
var _hp: float = 0.0
var _speed: float = 0.0
var _contact_damage: float = 0.0
var _essence_value: int = 0
var _target: Node2D

@onready var _sprite: Sprite2D = $Sprite
@onready var _shape: CollisionShape2D = $CollisionShape2D

func set_pool(pool: ObjectPool) -> void:
	_pool = pool

func setup(data: AnimalData, spawn_pos: Vector2, target: Node2D, hp_mult: float, speed_mult: float) -> void:
	global_position = spawn_pos
	_target = target
	_hp = data.max_hp * hp_mult
	_speed = data.move_speed * speed_mult
	_contact_damage = data.contact_damage
	_essence_value = data.essence_value
	_sprite.modulate = data.color
	var target_diameter: float = data.radius * 2.0
	_sprite.scale = Vector2.ONE * (target_diameter / _sprite.texture.get_width())

func get_contact_damage() -> float:
	return _contact_damage

func on_acquire() -> void:
	visible = true
	set_physics_process(true)
	add_to_group("animal")
	_shape.set_deferred("disabled", false)

func on_release() -> void:
	visible = false
	set_physics_process(false)
	remove_from_group("animal")
	_target = null
	velocity = Vector2.ZERO
	_shape.set_deferred("disabled", true)

func _physics_process(_delta: float) -> void:
	if _target == null or not is_instance_valid(_target):
		return
	var dir: Vector2 = (_target.global_position - global_position).normalized()
	velocity = dir * _speed
	move_and_slide()

func take_damage(amount: float) -> void:
	_hp -= amount
	if _hp <= 0.0:
		_die()

func _die() -> void:
	EventBus.animal_died.emit(global_position, _essence_value)
	_return_to_pool()

func _return_to_pool() -> void:
	if _pool != null:
		_pool.release(self)
	else:
		queue_free()
