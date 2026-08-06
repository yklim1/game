class_name Player
extends CharacterBody2D
## 플레이어(작은 동물). 8방향 이동, 체력, 무적 프레임, 접촉 피해 처리.
## 성장은 변이(3택 카드/상점)로만 이루어지며, RunState 스탯 변화는
## EventBus.player_stats_changed 로 전달받아 반영한다.

@export var move_speed: float = 220.0
@export var max_health: float = 100.0
@export var iframe_duration: float = 0.5
## 변이로 최대 체력이 오를 때 그만큼 즉시 회복시킨다.
@export var heal_on_max_health_gain: bool = true

var _health: float = 0.0
var _max_health_total: float = 0.0
var _iframe_left: float = 0.0
var _alive: bool = true

@onready var _sprite: Sprite2D = $Sprite
@onready var _hurtbox: Area2D = $Hurtbox
@onready var _ability_manager: AbilityManager = $AbilityManager

func _ready() -> void:
	add_to_group("player")
	_max_health_total = max_health + RunState.bonus_max_health
	_health = _max_health_total
	EventBus.player_stats_changed.connect(_on_stats_changed)
	EventBus.animal_died.connect(_on_animal_died)
	# 아직 _ready 전인 UI도 초기 체력을 받도록 프레임 끝으로 미뤄 발행한다.
	EventBus.player_health_changed.emit.call_deferred(_health, _max_health_total)

func get_ability_manager() -> AbilityManager:
	return _ability_manager

func get_health() -> float:
	return _health

func get_max_health() -> float:
	return _max_health_total

func is_alive() -> bool:
	return _alive

func _physics_process(delta: float) -> void:
	_handle_movement()
	_update_iframe(delta)
	_check_contact_damage()

func _handle_movement() -> void:
	var dir: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = dir * move_speed * RunState.move_speed_mult
	move_and_slide()

func _update_iframe(delta: float) -> void:
	if _iframe_left <= 0.0:
		return
	_iframe_left -= delta
	if _iframe_left <= 0.0:
		_sprite.modulate.a = 1.0

func _check_contact_damage() -> void:
	if _iframe_left > 0.0:
		return
	var damage: float = 0.0
	for body in _hurtbox.get_overlapping_bodies():
		if body.is_in_group("animal") and body.has_method("get_contact_damage"):
			damage = maxf(damage, body.get_contact_damage())
	if damage > 0.0:
		take_damage(damage)

func take_damage(amount: float) -> void:
	if _iframe_left > 0.0 or not _alive:
		return
	if RunState.dodge_chance > 0.0 and randf() < RunState.dodge_chance:
		_iframe_left = iframe_duration * 0.5
		return
	_health -= amount * (1.0 - RunState.armor)
	_iframe_left = iframe_duration
	_sprite.modulate.a = 0.4
	EventBus.player_health_changed.emit(maxf(_health, 0.0), _max_health_total)
	if _health <= 0.0:
		_die()

func heal(amount: float) -> void:
	if not _alive or amount <= 0.0:
		return
	var before: float = _health
	_health = minf(_health + amount, _max_health_total)
	if _health != before:
		EventBus.player_health_changed.emit(_health, _max_health_total)

func _on_animal_died(_position: Vector2, _data: AnimalData, _essence_value: int) -> void:
	heal(RunState.heal_on_kill)

func _on_stats_changed() -> void:
	var new_max: float = max_health + RunState.bonus_max_health
	var gained: float = new_max - _max_health_total
	_max_health_total = new_max
	if heal_on_max_health_gain and gained > 0.0:
		_health = minf(_health + gained, _max_health_total)
	_health = minf(_health, _max_health_total)
	EventBus.player_health_changed.emit(maxf(_health, 0.0), _max_health_total)

func _die() -> void:
	if not _alive:
		return
	_alive = false
	set_physics_process(false)
	EventBus.player_died.emit()
