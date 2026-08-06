class_name CameraShake
extends Camera2D
## 화면 흔들림. offset 을 매 프레임 절대값으로 다시 쓰기 때문에 누적 드리프트가 생기지 않고,
## 흔들림이 끝나면 offset 이 정확히 Vector2.ZERO 로 복귀한다.

## 화면 흔들림 사용 여부(Camera2D 의 내장 enabled 와 구분해 이름을 붙였다).
@export var shake_enabled: bool = true
## 플레이어 피격 시 흔들림 세기(픽셀)와 지속 시간(초).
@export var player_hit_strength: float = 6.0
@export var player_hit_duration: float = 0.26
## 강한 한 방(큰 데미지)용 흔들림. 0이면 아예 구독하지 않아 비용도 없다.
@export var strong_hit_strength: float = 0.0
@export var strong_hit_duration: float = 0.12
## 한 번에 이 이상의 피해가 들어가면 강한 타격으로 본다.
@export var strong_hit_damage: float = 40.0
## 한 번의 흔들림이 이 세기를 넘지 못하게 제한한다(여러 요청이 겹칠 때 과해지는 것 방지).
@export var max_strength: float = 12.0

var _strength: float = 0.0
var _duration: float = 0.0
var _time_left: float = 0.0

func _ready() -> void:
	set_process(false)
	EventBus.player_hit.connect(_on_player_hit)
	# 카드/상점이 열리면 트리가 멈춰 offset 이 흔들린 채로 남으므로 즉시 정리한다.
	EventBus.mutation_offered.connect(_on_pause_ui_opened)
	EventBus.shop_opened.connect(_on_shop_opened)
	EventBus.player_died.connect(reset)
	if strong_hit_strength > 0.0:
		EventBus.animal_hit.connect(_on_animal_hit)

func is_shaking() -> bool:
	return _time_left > 0.0

## 이미 흔들리는 중이면 더 강하고 긴 쪽을 채택한다(합산하지 않는다).
func shake(strength: float, duration: float) -> void:
	if not shake_enabled or strength <= 0.0 or duration <= 0.0:
		return
	_strength = minf(maxf(_strength, strength), max_strength)
	_duration = maxf(_duration, duration)
	_time_left = maxf(_time_left, duration)
	set_process(true)

func reset() -> void:
	_strength = 0.0
	_duration = 0.0
	_time_left = 0.0
	offset = Vector2.ZERO
	set_process(false)

func _process(delta: float) -> void:
	_time_left -= delta
	if _time_left <= 0.0:
		reset()
		return
	var amount: float = _strength * (_time_left / _duration)
	offset = Vector2(randf_range(-amount, amount), randf_range(-amount, amount))

func _on_player_hit(_damage: float) -> void:
	shake(player_hit_strength, player_hit_duration)

func _on_animal_hit(_position: Vector2, damage: float) -> void:
	if damage >= strong_hit_damage:
		shake(strong_hit_strength, strong_hit_duration)

func _on_pause_ui_opened(_options: Array) -> void:
	reset()

func _on_shop_opened(_wave_index: int) -> void:
	reset()
