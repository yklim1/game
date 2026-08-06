class_name TestAutopilot
extends Node
## 테스트 전용 가상 플레이어. 실제 입력 액션을 눌러 카이팅(가장 가까운 적에서 멀어지기)하고,
## 레벨업 변이 카드와 소굴 상점이 뜨면 공개 API로 처리해 시뮬레이션이 멈추지 않게 한다.
## 게임 코드는 전혀 수정하지 않고 입력/공개 API만 쓰므로 프로덕션 동작에 영향이 없다.

const MOVE_ACTIONS: PackedStringArray = ["move_left", "move_right", "move_up", "move_down"]

## 아레나 중심에서 이 거리 이상 벗어나면 중심 쪽으로 되돌아온다.
@export var leash_radius: float = 460.0
@export var center: Vector2 = Vector2(640.0, 360.0)
## 적이 이 거리 안에 있을 때만 회피한다. 없으면 중심으로 돌아간다.
@export var threat_radius: float = 320.0
## 적이 이 거리보다 멀면 급하지 않다고 보고 젬을 주우러 간다.
@export var comfort_radius: float = 170.0
@export var pickup_seek_radius: float = 460.0
## 이동 조작 여부. false 면 UI 처리만 한다.
@export var control_movement: bool = true
## 카드/상점을 자동으로 처리할지. false 면 테스트가 직접 UI를 다룬다.
@export var auto_resolve_ui: bool = true

var cards_seen: int = 0
var cards_chosen: int = 0
var shops_seen: int = 0
var items_bought: int = 0
var rerolls: int = 0

var _player: Node2D
var _cards: MutationCardScreen
var _shop: ShopScreen

func _ready() -> void:
	# 카드/상점이 뜨면 트리가 일시정지되므로 그때도 동작해야 한다.
	process_mode = Node.PROCESS_MODE_ALWAYS

func set_player(player: Node2D) -> void:
	_player = player

func set_ui(cards: MutationCardScreen, shop: ShopScreen) -> void:
	_cards = cards
	_shop = shop

func _physics_process(_delta: float) -> void:
	if auto_resolve_ui and _resolve_ui():
		return
	if not control_movement:
		return
	if _player == null or not is_instance_valid(_player):
		release_all()
		return
	_apply_direction(_desired_direction())

## 열려 있는 UI를 하나 처리했으면 true.
func _resolve_ui() -> bool:
	if _cards != null and is_instance_valid(_cards) and _cards.is_open():
		var options: Array[MutationData] = _cards.get_options()
		if options.is_empty():
			return true
		cards_seen += 1
		if _cards.choose(randi() % options.size()):
			cards_chosen += 1
		return true
	if _shop != null and is_instance_valid(_shop) and _shop.is_open():
		shops_seen += 1
		_shop_spree()
		_shop.close()
		return true
	return false

## 살 수 있는 것을 앞에서부터 사고, 여유가 있으면 한 번 리롤해 더 산다.
func _shop_spree() -> void:
	_buy_affordable()
	if RunState.feed >= _shop.get_reroll_cost() + 10 and _shop.reroll():
		rerolls += 1
		_buy_affordable()

func _buy_affordable() -> void:
	for i in _shop.get_offers().size():
		if _shop.get_offers()[i] == null:
			continue
		if RunState.feed >= _shop.get_cost(i) and _shop.buy(i):
			items_bought += 1

func _desired_direction() -> Vector2:
	var origin: Vector2 = _player.global_position
	var dir: Vector2 = Vector2.ZERO
	var threat: Node2D = _nearest_animal(origin)
	var urgent: bool = false
	if threat != null:
		var away: Vector2 = origin - threat.global_position
		urgent = away.length() < comfort_radius
		if away.length_squared() > 0.0:
			dir = away.normalized()
	if not urgent:
		var gem: Node2D = _nearest_in_group(origin, "pickup", pickup_seek_radius)
		if gem != null:
			var to_gem: Vector2 = (gem.global_position - origin).normalized()
			dir = (dir * 0.6 + to_gem).normalized() if dir != Vector2.ZERO else to_gem
	var to_center: Vector2 = center - origin
	if to_center.length() > leash_radius:
		dir = (dir + to_center.normalized() * 2.0).normalized()
	elif dir == Vector2.ZERO and to_center.length() > 8.0:
		dir = to_center.normalized()
	return dir

func _nearest_animal(origin: Vector2) -> Node2D:
	return _nearest_in_group(origin, "animal", threat_radius)

func _nearest_in_group(origin: Vector2, group: String, max_range: float) -> Node2D:
	var nearest: Node2D = null
	var best: float = max_range * max_range
	for node in get_tree().get_nodes_in_group(group):
		var candidate: Node2D = node as Node2D
		if candidate == null:
			continue
		var dist_sq: float = origin.distance_squared_to(candidate.global_position)
		if dist_sq < best:
			best = dist_sq
			nearest = candidate
	return nearest

func _apply_direction(dir: Vector2) -> void:
	_set_action("move_left", maxf(-dir.x, 0.0))
	_set_action("move_right", maxf(dir.x, 0.0))
	_set_action("move_up", maxf(-dir.y, 0.0))
	_set_action("move_down", maxf(dir.y, 0.0))

func _set_action(action: String, strength: float) -> void:
	if strength > 0.01:
		Input.action_press(action, strength)
	else:
		Input.action_release(action)

func release_all() -> void:
	for action in MOVE_ACTIONS:
		Input.action_release(action)

func _exit_tree() -> void:
	release_all()
