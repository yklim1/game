extends Control
## HUD: 체력·생존 시간·처치 수·웨이브·레벨/XP·먹이와 보유 변이/계통 진행도 표시.

## 계통 패널에 표시할 순서(DESIGN.md 5.3).
const LINEAGE_ORDER: PackedStringArray = ["포식", "독", "비행", "방어", "포자"]
const TOAST_DURATION: float = 3.5

var _toast_left: float = 0.0

@onready var _hp_label: Label = $HPLabel
@onready var _time_label: Label = $TimeLabel
@onready var _kills_label: Label = $KillsLabel
@onready var _wave_label: Label = $WaveLabel
@onready var _level_label: Label = $LevelLabel
@onready var _xp_bar: ProgressBar = $XPBar
@onready var _lineage_label: Label = $LineagePanel/LineageLabel
@onready var _mutation_label: Label = $LineagePanel/MutationLabel
@onready var _toast_label: Label = $SynergyToast

func _ready() -> void:
	EventBus.player_health_changed.connect(_on_health_changed)
	EventBus.xp_changed.connect(_on_xp_changed)
	EventBus.player_leveled_up.connect(_on_leveled_up)
	EventBus.player_stats_changed.connect(_refresh_build_panel)
	EventBus.synergy_activated.connect(_on_synergy_activated)
	# 일시정지(카드·상점) 중에는 _process 가 돌지 않으므로 재화 변화는 시그널로도 받는다.
	EventBus.feed_collected.connect(_on_feed_collected)
	EventBus.shop_purchased.connect(_on_shop_purchased)
	_toast_label.visible = false
	_on_health_changed(0.0, 0.0)
	_refresh_xp()
	_refresh_build_panel()

func _process(delta: float) -> void:
	_time_label.text = "TIME  %s" % _format_time(RunState.elapsed_time)
	_wave_label.text = "WAVE  %d" % RunState.wave_index
	_refresh_counters()
	_update_toast(delta)

func _refresh_counters() -> void:
	_kills_label.text = "KILLS  %d   FEED  %d" % [RunState.kills, RunState.feed]

func _on_feed_collected(_value: int) -> void:
	_refresh_counters()

func _on_shop_purchased(_data: MutationData, _cost: int) -> void:
	_refresh_counters()

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

## 보유 변이 수와 계통별 진행도(현재/다음 임계값, 발동 단계)를 갱신한다.
func _refresh_build_panel() -> void:
	var lines: PackedStringArray = ["계통 진행도"]
	for lineage in LINEAGE_ORDER:
		var count: int = RunState.get_lineage_count(lineage)
		if count <= 0:
			continue
		lines.append("%s  %d%s%s" % [lineage, count, _next_text(lineage, count), _tier_text(lineage)])
	if lines.size() == 1:
		lines.append("(아직 없음)")
	_lineage_label.text = "\n".join(lines)
	_mutation_label.text = "변이 %d개 · 능력 %d개" % [RunState.get_mutation_total(), RunState.get_ability_ids().size()]

func _next_text(lineage: String, count: int) -> String:
	var synergy: LineageSynergyData = ContentDB.get_synergy(lineage)
	if synergy == null:
		return ""
	var next: int = synergy.next_threshold(count)
	return "" if next <= 0 else " → %d" % next

func _tier_text(lineage: String) -> String:
	var tier: int = RunState.get_synergy_tier(lineage)
	return "" if tier <= 0 else "  " + "★".repeat(tier)

func _on_synergy_activated(lineage: String, tier: int, description: String) -> void:
	_toast_label.text = "계통 시너지 발동!  %s %d단 — %s" % [lineage, tier, description]
	_toast_label.visible = true
	_toast_left = TOAST_DURATION
	_refresh_build_panel()

func _update_toast(delta: float) -> void:
	if _toast_left <= 0.0:
		return
	_toast_left -= delta
	if _toast_left <= 0.0:
		_toast_label.visible = false

func _format_time(seconds: float) -> String:
	var total: int = int(seconds)
	return "%02d:%02d" % [total / 60, total % 60]
