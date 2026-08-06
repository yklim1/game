class_name TestAutopilot
extends Node
## 테스트 전용 가상 플레이어. 실제 입력 액션을 눌러 카이팅(가장 가까운 적에서 멀어지기)한다.
## 게임 코드는 전혀 수정하지 않고 Input 액션만 조작하므로 프로덕션 동작에 영향이 없다.

const MOVE_ACTIONS: PackedStringArray = ["move_left", "move_right", "move_up", "move_down"]

## 아레나 중심에서 이 거리 이상 벗어나면 중심 쪽으로 되돌아온다.
@export var leash_radius: float = 460.0
@export var center: Vector2 = Vector2(640.0, 360.0)
## 적이 이 거리 안에 있을 때만 회피한다. 없으면 중심으로 돌아간다.
@export var threat_radius: float = 320.0
## 적이 이 거리보다 멀면 급하지 않다고 보고 젬을 주우러 간다.
@export var comfort_radius: float = 170.0
@export var pickup_seek_radius: float = 460.0

var _player: Node2D

func set_player(player: Node2D) -> void:
	_player = player

func _physics_process(_delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		release_all()
		return
	_apply_direction(_desired_direction())

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
