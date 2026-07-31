extends Control
## 최소 HUD: 체력·생존 시간·처치 수 표시.

@onready var _hp_label: Label = $HPLabel
@onready var _time_label: Label = $TimeLabel
@onready var _kills_label: Label = $KillsLabel

func _ready() -> void:
	EventBus.player_health_changed.connect(_on_health_changed)
	_on_health_changed(0.0, 0.0)

func _process(_delta: float) -> void:
	_time_label.text = "TIME  %s" % _format_time(RunState.elapsed_time)
	_kills_label.text = "KILLS  %d" % RunState.kills

func _on_health_changed(current: float, maximum: float) -> void:
	_hp_label.text = "HP  %d / %d" % [int(ceil(current)), int(ceil(maximum))]

func _format_time(seconds: float) -> String:
	var total: int = int(seconds)
	return "%02d:%02d" % [total / 60, total % 60]
