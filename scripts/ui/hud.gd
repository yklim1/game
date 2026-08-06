extends Control
## HUD: 체력·생존 시간·처치 수·웨이브·레벨/XP·먹이 표시.

@onready var _hp_label: Label = $HPLabel
@onready var _time_label: Label = $TimeLabel
@onready var _kills_label: Label = $KillsLabel
@onready var _wave_label: Label = $WaveLabel
@onready var _level_label: Label = $LevelLabel
@onready var _xp_bar: ProgressBar = $XPBar

func _ready() -> void:
	EventBus.player_health_changed.connect(_on_health_changed)
	EventBus.xp_changed.connect(_on_xp_changed)
	EventBus.player_leveled_up.connect(_on_leveled_up)
	_on_health_changed(0.0, 0.0)
	_refresh_xp()

func _process(_delta: float) -> void:
	_time_label.text = "TIME  %s" % _format_time(RunState.elapsed_time)
	_kills_label.text = "KILLS  %d   FEED  %d" % [RunState.kills, RunState.feed]
	_wave_label.text = "WAVE  %d" % RunState.wave_index

func _on_health_changed(current: float, maximum: float) -> void:
	_hp_label.text = "HP  %d / %d" % [int(ceil(current)), int(ceil(maximum))]

func _on_xp_changed(_current_xp: int, _xp_to_next: int, _level: int) -> void:
	_refresh_xp()

func _on_leveled_up(_level: int) -> void:
	_refresh_xp()

func _refresh_xp() -> void:
	_level_label.text = "LV  %d   XP  %d / %d" % [RunState.level, RunState.xp, RunState.xp_to_next]
	_xp_bar.max_value = maxi(RunState.xp_to_next, 1)
	_xp_bar.value = RunState.xp

func _format_time(seconds: float) -> String:
	var total: int = int(seconds)
	return "%02d:%02d" % [total / 60, total % 60]
