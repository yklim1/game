class_name Player
extends CharacterBody2D
## 플레이어(작은 동물). 8방향 이동, 체력, 무적 프레임, 접촉 피해 처리.

@export var move_speed: float = 220.0
@export var max_health: float = 100.0
@export var iframe_duration: float = 0.5

var _health: float = 0.0
var _iframe_left: float = 0.0

@onready var _sprite: Sprite2D = $Sprite
@onready var _hurtbox: Area2D = $Hurtbox
@onready var _ability_manager: AbilityManager = $AbilityManager

func _ready() -> void:
	add_to_group("player")
	_health = max_health
	EventBus.player_health_changed.emit(_health, max_health)

func get_ability_manager() -> AbilityManager:
	return _ability_manager

func _physics_process(delta: float) -> void:
	_handle_movement()
	_update_iframe(delta)
	_check_contact_damage()

func _handle_movement() -> void:
	var dir: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = dir * move_speed
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
	if _iframe_left > 0.0:
		return
	_health -= amount
	_iframe_left = iframe_duration
	_sprite.modulate.a = 0.4
	EventBus.player_health_changed.emit(maxf(_health, 0.0), max_health)
	if _health <= 0.0:
		_die()

func _die() -> void:
	set_physics_process(false)
	EventBus.player_died.emit()
