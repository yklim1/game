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
## 무적 프레임 동안 깜빡이는 횟수(초당). 0이면 깜빡이지 않고 반투명만 유지한다.
@export var iframe_blink_hz: float = 9.0
## 깜빡임의 어두운 쪽 알파.
@export_range(0.0, 1.0) var iframe_min_alpha: float = 0.25
## 실제 플레이어 스프라이트(투명 PNG). 비우면 씬의 플레이스홀더(icon.svg)를 그대로 쓴다.
@export var sprite_texture: Texture2D
## 화면 표시 크기(px, 긴 변). 0이면 씬에 저장된 기본 크기를 유지한다.
@export var sprite_display_size: float = 0.0
## 실제 스프라이트에도 씬의 self_modulate 색을 곱할지. 기본은 아트 원색 유지(false).
@export var tint_sprite_texture: bool = false

var _health: float = 0.0
var _max_health_total: float = 0.0
var _iframe_left: float = 0.0
var _alive: bool = true

@onready var _sprite: Sprite2D = $Sprite
@onready var _hurtbox: Area2D = $Hurtbox
@onready var _ability_manager: AbilityManager = $AbilityManager
@onready var _camera: CameraShake = $Camera2D

func _ready() -> void:
	add_to_group("player")
	_apply_sprite()
	_max_health_total = max_health + RunState.bonus_max_health
	_health = _max_health_total
	EventBus.player_stats_changed.connect(_on_stats_changed)
	EventBus.animal_died.connect(_on_animal_died)
	# 아직 _ready 전인 UI도 초기 체력을 받도록 프레임 끝으로 미뤄 발행한다.
	EventBus.player_health_changed.emit.call_deferred(_health, _max_health_total)

## 스프라이트가 비어 있으면 씬의 플레이스홀더가 그대로 유지된다(무적 깜빡임은 modulate 를 쓰므로 영향 없음).
func _apply_sprite() -> void:
	var size: float = sprite_display_size
	if size <= 0.0:
		size = SpriteVisual.measure_display_size(_sprite)
	var uses_art: bool = SpriteVisual.apply(_sprite, sprite_texture, _sprite.texture, size)
	if uses_art:
		_sprite.self_modulate = SpriteVisual.resolve_tint(true, _sprite.self_modulate, tint_sprite_texture)

## 실제 스프라이트가 지정돼 그려지고 있으면 true.
func is_using_sprite_art() -> bool:
	return sprite_texture != null

func get_ability_manager() -> AbilityManager:
	return _ability_manager

func get_camera() -> CameraShake:
	return _camera

func is_invulnerable() -> bool:
	return _iframe_left > 0.0

## 무적 프레임 깜빡임 확인용. 평상시에는 1.0이다.
func get_sprite_alpha() -> float:
	return _sprite.modulate.a

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
		_iframe_left = 0.0
		_sprite.modulate.a = 1.0
		return
	_sprite.modulate.a = _blink_alpha()

## 무적 시간이 남아 있는 동안 알파를 오르내리게 해 "지금 무적"임을 보여 준다.
func _blink_alpha() -> float:
	if iframe_blink_hz <= 0.0:
		return iframe_min_alpha
	var phase: float = _iframe_left * iframe_blink_hz
	return iframe_min_alpha if int(phase * 2.0) % 2 == 0 else 1.0

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
	var taken: float = amount * (1.0 - RunState.armor)
	_health -= taken
	_iframe_left = iframe_duration
	_sprite.modulate.a = iframe_min_alpha
	EventBus.player_hit.emit(taken)
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
	_iframe_left = 0.0
	_sprite.modulate.a = 1.0
	set_physics_process(false)
	EventBus.player_died.emit()
