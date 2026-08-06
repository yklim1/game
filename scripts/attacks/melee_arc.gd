class_name MeleeArc
extends Node2D
## MELEE_ARC 형태 공격(발톱 휘두르기). 발동 즉시 부채꼴 범위의 동물에게 데미지를 주고
## 짧은 시간 잔상만 남긴 뒤 풀로 돌아간다. 물리 대신 거리·각도 계산을 쓴다.

const VISUAL_DURATION: float = 0.14

var _pool: ObjectPool
var _life_left: float = 0.0

@onready var _sprite: Sprite2D = $Sprite

func set_pool(pool: ObjectPool) -> void:
	_pool = pool

func setup(ability: AbilityData, origin: Vector2, dir: Vector2, damage: float) -> void:
	global_position = origin
	rotation = dir.angle()
	_life_left = VISUAL_DURATION
	var radius: float = ability.area_radius * RunState.area_mult
	_sprite.self_modulate = ability.color
	_sprite.scale = Vector2.ONE * (radius * 2.0 / float(_sprite.texture.get_width()))
	_apply_damage(origin, dir, ability, damage, radius)

func on_acquire() -> void:
	visible = true
	set_process(true)

func on_release() -> void:
	visible = false
	set_process(false)

func _process(delta: float) -> void:
	_life_left -= delta
	_sprite.self_modulate.a = maxf(_life_left / VISUAL_DURATION, 0.0)
	if _life_left <= 0.0:
		_return_to_pool()

func _apply_damage(origin: Vector2, dir: Vector2, ability: AbilityData, damage: float, radius: float) -> void:
	var radius_sq: float = radius * radius
	var half_arc: float = deg_to_rad(ability.arc_deg) * 0.5
	for node in get_tree().get_nodes_in_group("animal"):
		var animal: Node2D = node as Node2D
		if animal == null:
			continue
		var offset: Vector2 = animal.global_position - origin
		if offset.length_squared() > radius_sq:
			continue
		if half_arc < PI and absf(dir.angle_to(offset)) > half_arc:
			continue
		if animal.has_method("take_damage"):
			# 휘두른 중심에서 바깥으로 밀어낸다(offset 이 0이면 넉백 없음).
			animal.take_damage(damage, offset.normalized())

func _return_to_pool() -> void:
	if _pool != null:
		_pool.release(self)
	else:
		queue_free()
