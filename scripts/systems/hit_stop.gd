class_name HitStop
extends Node
## 플레이어가 맞은 순간 아주 짧게 시간을 늦춰 타격을 강조한다.
## Engine.time_scale 은 전역이라, 씬이 빠지거나 UI 일시정지가 걸리면 반드시 원상복구한다.

const NORMAL_TIME_SCALE: float = 1.0

@export var enabled: bool = true
## 정지 길이(초). 게임 시간이 아니라 time_scale 을 되돌린 기준 시간으로 센다.
@export var duration: float = 0.05
## 정지 중 시간 배율(0에 가까울수록 강하게 멈춘다).
@export_range(0.01, 1.0) var slow_time_scale: float = 0.1

var _left: float = 0.0

func _ready() -> void:
	# 트리가 멈춰도 시간 배율은 반드시 되돌려야 한다.
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)
	EventBus.player_hit.connect(_on_player_hit)
	EventBus.mutation_offered.connect(_on_pause_ui_opened)
	EventBus.shop_opened.connect(_on_shop_opened)
	EventBus.player_died.connect(release)

func is_active() -> bool:
	return _left > 0.0

func trigger() -> void:
	if not enabled or duration <= 0.0:
		return
	_left = duration
	Engine.time_scale = slow_time_scale
	set_process(true)

func release() -> void:
	_left = 0.0
	Engine.time_scale = NORMAL_TIME_SCALE
	set_process(false)

func _process(delta: float) -> void:
	# delta 는 time_scale 이 곱해진 값이므로, 되돌려서 실제 경과 시간으로 센다.
	_left -= delta / maxf(Engine.time_scale, 0.01)
	if _left <= 0.0:
		release()

func _on_player_hit(_damage: float) -> void:
	trigger()

func _on_pause_ui_opened(_options: Array) -> void:
	release()

func _on_shop_opened(_wave_index: int) -> void:
	release()

func _exit_tree() -> void:
	Engine.time_scale = NORMAL_TIME_SCALE
