class_name DamageNumber
extends Node2D
## 피격 지점에서 위로 떠오르며 사라지는 데미지 숫자. 풀에서 재사용된다.
##
## 숫자는 맞은 개체의 위치에 뜨므로 근접·장판 공격에서는 주인공과 겹치는 것이 정상이다.
## 그래서 겹침을 없애는 대신 "가림"을 줄인다: 반투명하게, 짧게, 빠르게 위로 빠지고, 좌우로 흩뿌린다.

## 시작 높이에 주는 작은 흔들림(px). 같은 프레임에 뜬 숫자들이 한 줄로 정렬되는 것을 막는다.
const VERTICAL_JITTER: float = 4.0

@export var duration: float = 0.34
@export var rise_speed: float = 110.0
## 같은 지점에 여러 번 맞아도 숫자가 한 덩어리로 뭉치지 않게 하는 좌우 분산 폭(px).
@export var spread: float = 22.0
## 피격 지점보다 이만큼 위에서 시작한다. 맞은 개체의 몸을 숫자가 곧바로 덮지 않게 한다.
@export var rise_offset: float = 14.0
## 가장 진할 때의 알파. 1.0 미만이면 숫자 아래에 있는 캐릭터의 실루엣이 비쳐 보인다.
@export_range(0.0, 1.0) var peak_alpha: float = 0.82
## 숫자 색. DESIGN.md 색 영역 분리 규칙상 주인공(진홍·크림)도 적(보라·독초록·앰버)도 아닌
## 중립 무채색이어야 하므로 살짝 차가운 흰색을 쓴다.
@export var color: Color = Color(0.92, 0.95, 1.0, 1.0)

var _pool: ObjectPool
var _life_left: float = 0.0

@onready var _label: Label = $Label

func set_pool(pool: ObjectPool) -> void:
	_pool = pool

func setup(spawn_pos: Vector2, amount: float) -> void:
	global_position = spawn_pos + Vector2(
		randf_range(-spread, spread),
		-rise_offset + randf_range(-VERTICAL_JITTER, VERTICAL_JITTER)
	)
	_life_left = duration
	_label.text = str(maxi(int(round(amount)), 1))
	_label.modulate = Color(color.r, color.g, color.b, peak_alpha)

func on_acquire() -> void:
	visible = true
	set_process(true)

func on_release() -> void:
	visible = false
	set_process(false)
	_life_left = 0.0

func _process(delta: float) -> void:
	_life_left -= delta
	if _life_left <= 0.0:
		_return_to_pool()
		return
	position.y -= rise_speed * delta
	_label.modulate.a = clampf(_life_left / duration * 1.6, 0.0, 1.0) * peak_alpha

func _return_to_pool() -> void:
	if _pool != null:
		_pool.release(self)
	else:
		queue_free()
