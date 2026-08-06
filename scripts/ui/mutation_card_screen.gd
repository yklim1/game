class_name MutationCardScreen
extends Control
## 레벨업(진화) 시 게임을 멈추고 서로 다른 변이 3장을 제시한다. 선택하면 효과를 적용하고 재개한다.
## 여러 레벨이 동시에 오르면 큐에 쌓아 순차로 제시한다(DESIGN.md 4.5).

const OPTION_COUNT: int = 3

var _options: Array[MutationData] = []
var _pending: int = 0
var _open: bool = false
var _shop_open: bool = false

@onready var _card_roots: Array[Node] = [$Cards/Card0, $Cards/Card1, $Cards/Card2]
@onready var _subtitle: Label = $Subtitle

func _ready() -> void:
	visible = false
	for i in _card_roots.size():
		_button(i).pressed.connect(_on_button_pressed.bind(i))
	EventBus.player_leveled_up.connect(_on_player_leveled_up)
	EventBus.player_died.connect(_on_player_died)
	EventBus.shop_opened.connect(_on_shop_opened)
	EventBus.shop_closed.connect(_on_shop_closed)

func is_open() -> bool:
	return _open

func get_options() -> Array[MutationData]:
	return _options

func get_pending_count() -> int:
	return _pending

## 카드 선택. 성공하면 효과가 적용되고 다음 카드 또는 전투 재개로 넘어간다.
func choose(index: int) -> bool:
	if not _open or index < 0 or index >= _options.size():
		return false
	var data: MutationData = _options[index]
	_options = []
	_open = false
	RunState.apply_mutation(data)
	if _pending > 0 and not RunState.is_game_over:
		_show_next()
	else:
		_close()
	return true

func _on_button_pressed(index: int) -> void:
	choose(index)

func _on_player_leveled_up(_level: int) -> void:
	_pending += 1
	if not _open and not _shop_open:
		_show_next()

func _on_shop_opened(_wave_index: int) -> void:
	_shop_open = true

func _on_shop_closed() -> void:
	_shop_open = false
	if not _open and _pending > 0:
		_show_next()

func _on_player_died() -> void:
	_pending = 0
	_options = []
	_open = false
	visible = false

func _show_next() -> void:
	if _pending <= 0 or RunState.is_game_over:
		_close()
		return
	_pending -= 1
	_options = MutationPool.draw(OPTION_COUNT)
	if _options.is_empty():
		push_warning("MutationCardScreen: 제시할 변이 후보가 없습니다.")
		_close()
		return
	_bind_options()
	_open = true
	visible = true
	get_tree().paused = true
	EventBus.mutation_offered.emit(_options)

func _bind_options() -> void:
	_subtitle.text = "레벨 %d — 변이를 하나 선택하세요" % RunState.level
	for i in _card_roots.size():
		var card: Control = _card_roots[i] as Control
		if i >= _options.size():
			card.visible = false
			continue
		card.visible = true
		var data: MutationData = _options[i]
		_label(i, "NameLabel").text = data.display_name
		_label(i, "MetaLabel").text = _meta_text(data)
		_label(i, "DescLabel").text = data.description
		_button(i).text = "선택"

func _meta_text(data: MutationData) -> String:
	var lineage_text: String = "무계통" if data.lineage.is_empty() else "/".join(data.lineage)
	return "%s · %s" % [lineage_text, _rarity_name(data.rarity)]

func _rarity_name(rarity: MutationData.Rarity) -> String:
	match rarity:
		MutationData.Rarity.RARE:
			return "레어"
		MutationData.Rarity.EPIC:
			return "에픽"
	return "커먼"

func _close() -> void:
	_open = false
	_options = []
	visible = false
	# 상점이 열려 있거나 게임오버면 일시정지를 유지한다.
	if not _shop_open and not RunState.is_game_over:
		get_tree().paused = false
	EventBus.mutation_cards_closed.emit()

func _label(index: int, node_name: String) -> Label:
	return _card_roots[index].get_node("Margin/VBox/" + node_name) as Label

func _button(index: int) -> Button:
	return _card_roots[index].get_node("Margin/VBox/ChooseButton") as Button
