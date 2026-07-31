class_name AbilityManager
extends Node2D
## 능력 슬롯의 자동 발동을 담당. 현재는 능력 1종(최근접 조준 자동공격)을 처리한다.

@export var ability: AbilityData

const _NO_TARGET_RETRY: float = 0.1

var _projectile_pool: ObjectPool
var _cooldown_left: float = 0.0

func set_projectile_pool(pool: ObjectPool) -> void:
	_projectile_pool = pool

func _physics_process(delta: float) -> void:
	if ability == null or _projectile_pool == null:
		return
	_cooldown_left -= delta
	if _cooldown_left <= 0.0:
		_try_fire()

func _try_fire() -> void:
	var target: Node2D = _find_nearest_animal()
	if target == null:
		_cooldown_left = _NO_TARGET_RETRY
		return
	_cooldown_left = ability.cooldown
	var base_dir: Vector2 = (target.global_position - global_position).normalized()
	_fire_volley(base_dir)

func _fire_volley(base_dir: Vector2) -> void:
	var count: int = maxi(1, ability.projectile_count)
	var spread: float = deg_to_rad(ability.spread_deg)
	for i in count:
		var offset: float = 0.0
		if count > 1:
			offset = spread * (float(i) / float(count - 1) - 0.5)
		_fire_one(base_dir.rotated(offset))

func _fire_one(dir: Vector2) -> void:
	var projectile: Node = _projectile_pool.acquire()
	projectile.setup(
		global_position,
		dir,
		ability.base_damage,
		ability.projectile_speed,
		ability.projectile_lifetime,
		ability.pierce
	)

func _find_nearest_animal() -> Node2D:
	var animals: Array[Node] = get_tree().get_nodes_in_group("animal")
	var nearest: Node2D = null
	var best_dist_sq: float = ability.range * ability.range
	var origin: Vector2 = global_position
	for node in animals:
		var animal: Node2D = node as Node2D
		if animal == null:
			continue
		var dist_sq: float = origin.distance_squared_to(animal.global_position)
		if dist_sq < best_dist_sq:
			best_dist_sq = dist_sq
			nearest = animal
	return nearest
