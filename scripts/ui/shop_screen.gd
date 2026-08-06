class_name ShopScreen
extends Control
## 소굴 상점. 웨이브가 끝나면 열려 먹이(Feed)로 변이/능력을 구매한다(DESIGN.md 4.7).
## 닫으면 shop_closed 를 발행해 WaveDirector 가 다음 웨이브를 시작한다.

const OFFER_COUNT: int = 4
const REROLL_BASE_COST: int = 4
## 리롤할 때마다 비용이 이만큼씩 오른다.
const REROLL_COST_STEP: int = 3

var _offers: Array[MutationData] = []
var _open: bool = false
var _pending_open: bool = false
var _cards_open: bool = false
var _reroll_count: int = 0

@onready var _offer_roots: Array[Node] = [
	$Panel/Margin/VBox/Offers/Offer0,
	$Panel/Margin/VBox/Offers/Offer1,
	$Panel/Margin/VBox/Offers/Offer2,
	$Panel/Margin/VBox/Offers/Offer3,
]
@onready var _title: Label = $Panel/Margin/VBox/Title
@onready var _feed_label: Label = $Panel/Margin/VBox/FeedLabel
@onready var _status_label: Label = $Panel/Margin/VBox/Footer/StatusLabel
@onready var _reroll_button: Button = $Panel/Margin/VBox/Footer/RerollButton
@onready var _continue_button: Button = $Panel/Margin/VBox/Footer/ContinueButton

func _ready() -> void:
	visible = false
	for i in _offer_roots.size():
		_buy_button(i).pressed.connect(_on_buy_pressed.bind(i))
	_reroll_button.pressed.connect(_on_reroll_pressed)
	_continue_button.pressed.connect(close)
	EventBus.wave_ended.connect(_on_wave_ended)
	EventBus.mutation_offered.connect(_on_mutation_offered)
	EventBus.mutation_cards_closed.connect(_on_mutation_cards_closed)
	EventBus.player_died.connect(_on_player_died)

func is_open() -> bool:
	return _open

## 판매된 칸은 null 이 된다.
func get_offers() -> Array[MutationData]:
	return _offers

func get_cost(index: int) -> int:
	if index < 0 or index >= _offers.size() or _offers[index] == null:
		return 0
	return maxi(_offers[index].cost, 0)

func get_reroll_cost() -> int:
	return REROLL_BASE_COST + REROLL_COST_STEP * _reroll_count

func buy(index: int) -> bool:
	if not _open or index < 0 or index >= _offers.size():
		return false
	var data: MutationData = _offers[index]
	if data == null:
		return false
	var cost: int = get_cost(index)
	if not RunState.spend_feed(cost):
		_status_label.text = "먹이가 부족합니다 (%d 필요)" % cost
		EventBus.shop_purchase_failed.emit(data, cost)
		_refresh()
		return false
	if not RunState.apply_mutation(data):
		# 상한에 걸린 변이는 살 수 없다. 지불한 먹이를 되돌린다.
		RunState.feed += cost
		RunState.feed_spent -= cost
		_status_label.text = "이미 최대까지 획득한 변이입니다"
		EventBus.shop_purchase_failed.emit(data, cost)
		_refresh()
		return false
	RunState.purchases += 1
	_offers[index] = null
	_status_label.text = "%s 구매 (-%d 먹이)" % [data.display_name, cost]
	EventBus.shop_purchased.emit(data, cost)
	_refresh()
	return true

func reroll() -> bool:
	if not _open:
		return false
	var cost: int = get_reroll_cost()
	if not RunState.spend_feed(cost):
		_status_label.text = "리롤할 먹이가 부족합니다 (%d 필요)" % cost
		_refresh()
		return false
	_reroll_count += 1
	_draw_offers()
	_status_label.text = "리롤 (-%d 먹이)" % cost
	EventBus.shop_rerolled.emit(cost)
	_refresh()
	return true

func close() -> void:
	if not _open:
		return
	_open = false
	visible = false
	if not RunState.is_game_over:
		get_tree().paused = false
	EventBus.shop_closed.emit()

func open() -> void:
	if _open or RunState.is_game_over:
		return
	_pending_open = false
	_reroll_count = 0
	_draw_offers()
	_status_label.text = "구매하거나 다음 웨이브로 넘어가세요"
	_open = true
	visible = true
	get_tree().paused = true
	_refresh()
	EventBus.shop_opened.emit(RunState.wave_index)

func _on_wave_ended(_index: int) -> void:
	if RunState.is_game_over:
		return
	_pending_open = true
	_try_open()

func _on_mutation_offered(_options: Array) -> void:
	_cards_open = true

func _on_mutation_cards_closed() -> void:
	_cards_open = false
	_try_open()

func _on_player_died() -> void:
	_pending_open = false
	if _open:
		_open = false
		visible = false
		EventBus.shop_closed.emit()

## 변이 카드가 떠 있으면 카드가 모두 끝난 뒤에 연다(UI 겹침 방지).
func _try_open() -> void:
	if _pending_open and not _cards_open and not _open:
		open()

func _on_buy_pressed(index: int) -> void:
	buy(index)

func _on_reroll_pressed() -> void:
	reroll()

func _draw_offers() -> void:
	_offers = MutationPool.draw(OFFER_COUNT, true)
	while _offers.size() < OFFER_COUNT:
		_offers.append(null)

func _refresh() -> void:
	_title.text = "소굴 상점 — 웨이브 %d 종료" % RunState.wave_index
	_feed_label.text = "보유 먹이  %d   |   구매 %d회 · 사용 %d" % [RunState.feed, RunState.purchases, RunState.feed_spent]
	_reroll_button.text = "리롤 (%d)" % get_reroll_cost()
	_reroll_button.disabled = RunState.feed < get_reroll_cost()
	for i in _offer_roots.size():
		var root: Control = _offer_roots[i] as Control
		var data: MutationData = _offers[i] if i < _offers.size() else null
		if data == null:
			_label(i, "VBox/NameLabel").text = "— 품절 —"
			_label(i, "VBox/DescLabel").text = ""
			_label(i, "CostLabel").text = ""
			_buy_button(i).disabled = true
			_buy_button(i).text = "구매"
			root.modulate = Color(1.0, 1.0, 1.0, 0.45)
			continue
		var lineage_text: String = "무계통" if data.lineage.is_empty() else "/".join(data.lineage)
		_label(i, "VBox/NameLabel").text = "%s  [%s]" % [data.display_name, lineage_text]
		_label(i, "VBox/DescLabel").text = data.description
		_label(i, "CostLabel").text = "%d 먹이" % get_cost(i)
		_buy_button(i).disabled = RunState.feed < get_cost(i)
		_buy_button(i).text = "구매"
		root.modulate = Color.WHITE

func _label(index: int, path: String) -> Label:
	return _offer_roots[index].get_node("Margin/HBox/" + path) as Label

func _buy_button(index: int) -> Button:
	return _offer_roots[index].get_node("Margin/HBox/BuyButton") as Button
