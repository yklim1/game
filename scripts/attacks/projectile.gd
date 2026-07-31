class_name Projectile
extends Area2D
## 자동공격 투사체. 이동·수명·충돌·데미지 처리. 풀에서 재사용된다.

var _pool: ObjectPool
var _direction: Vector2 = Vector2.RIGHT
var _speed: float = 0.0
var _damage: float = 0.0
var _life_left: float = 0.0
var _pierce_left: int = 0

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func set_pool(pool: ObjectPool) -> void:
	_pool = pool

func setup(pos: Vector2, dir: Vector2, damage: float, speed: float, life: float, pierce: int) -> void:
	global_position = pos
	_direction = dir
	_damage = damage
	_speed = speed
	_life_left = life
	_pierce_left = pierce
	rotation = dir.angle()

func on_acquire() -> void:
	visible = true
	set_physics_process(true)
	set_deferred("monitoring", true)

func on_release() -> void:
	visible = false
	set_physics_process(false)
	set_deferred("monitoring", false)

func _physics_process(delta: float) -> void:
	global_position += _direction * _speed * delta
	_life_left -= delta
	if _life_left <= 0.0:
		_return_to_pool()

func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("animal"):
		return
	if body.has_method("take_damage"):
		body.take_damage(_damage)
	_pierce_left -= 1
	if _pierce_left < 0:
		_return_to_pool()

func _return_to_pool() -> void:
	if _pool != null:
		_pool.release(self)
	else:
		queue_free()
