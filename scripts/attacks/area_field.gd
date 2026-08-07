class_name AreaField
extends Node2D
## AREA_FIELD 형태 공격(독 장판). 일정 시간 그 자리에 남아 주기적으로 범위 내 동물에게 데미지를 준다.
## 물리 대신 거리 계산 + 틱 타이머를 써서 대량 개체 상황의 부담을 줄인다.

var _pool: ObjectPool
var _life_left: float = 0.0
var _tick_interval: float = 0.5
var _tick_left: float = 0.0
var _radius_sq: float = 0.0
var _damage: float = 0.0
var _fallback_texture: Texture2D

@onready var _sprite: Sprite2D = $Sprite

func _ready() -> void:
	_fallback_texture = _sprite.texture

func set_pool(pool: ObjectPool) -> void:
	_pool = pool

func setup(ability: AbilityData, origin: Vector2, _dir: Vector2, damage: float) -> void:
	global_position = origin
	_life_left = ability.duration
	_tick_interval = maxf(ability.tick_interval, 0.05)
	_tick_left = 0.0
	var radius: float = ability.area_radius * RunState.area_mult
	_radius_sq = radius * radius
	_damage = damage
	var uses_art: bool = SpriteVisual.apply(_sprite, ability.attack_texture, _fallback_texture, radius * 2.0)
	_sprite.self_modulate = SpriteVisual.resolve_tint(uses_art, ability.color, ability.tint_attack_texture)

func on_acquire() -> void:
	visible = true
	set_physics_process(true)

func on_release() -> void:
	visible = false
	set_physics_process(false)

func _physics_process(delta: float) -> void:
	_life_left -= delta
	_tick_left -= delta
	if _tick_left <= 0.0:
		_tick_left = _tick_interval
		_apply_tick()
	if _life_left <= 0.0:
		_return_to_pool()

func _apply_tick() -> void:
	var origin: Vector2 = global_position
	for node in get_tree().get_nodes_in_group("animal"):
		var animal: Node2D = node as Node2D
		if animal == null:
			continue
		if origin.distance_squared_to(animal.global_position) > _radius_sq:
			continue
		if animal.has_method("take_damage"):
			animal.take_damage(_damage)

func _return_to_pool() -> void:
	if _pool != null:
		_pool.release(self)
	else:
		queue_free()
