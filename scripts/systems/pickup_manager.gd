class_name PickupManager
extends Node2D
## 동물 사망 시 정수(젬)·먹이를 드롭하고, 픽업 반경 안으로 들어오면 흡수시킨다.
## 활성 픽업을 한 곳에서 일괄 갱신해 노드별 _process 를 없앤다.

@export var pickup_radius: float = 34.0
@export var magnet_radius: float = 210.0
@export var magnet_speed: float = 560.0
## 흡수되지 않은 픽업이 사라지기까지의 시간(초). 0 이하면 사라지지 않는다.
@export var lifetime: float = 0.0
@export var feed_value: int = 1

var _pool: ObjectPool
var _player: Node2D
var _active: Array[Pickup] = []
var _ages: Array[float] = []

func _ready() -> void:
	EventBus.animal_died.connect(_on_animal_died)

func setup(pool: ObjectPool, player: Node2D) -> void:
	_pool = pool
	_player = player

func get_active_count() -> int:
	return _active.size()

func _on_animal_died(position: Vector2, data: AnimalData, essence_value: int) -> void:
	if essence_value > 0:
		_spawn(Pickup.Kind.ESSENCE, essence_value, position)
	if data != null and data.feed_chance > 0.0 and randf() < data.feed_chance:
		_spawn(Pickup.Kind.FEED, feed_value, position + Vector2(randf_range(-12.0, 12.0), randf_range(-12.0, 12.0)))

func _spawn(kind: Pickup.Kind, value: int, position: Vector2) -> void:
	if _pool == null:
		return
	var pickup: Pickup = _pool.acquire() as Pickup
	if pickup == null:
		return
	pickup.setup(kind, value, position)
	_active.append(pickup)
	_ages.append(0.0)

func _physics_process(delta: float) -> void:
	if _player == null or not is_instance_valid(_player) or _active.is_empty():
		return
	var player_pos: Vector2 = _player.global_position
	var pickup_dist_sq: float = pickup_radius * pickup_radius
	var magnet_dist_sq: float = magnet_radius * magnet_radius
	var step: float = magnet_speed * delta
	for i in range(_active.size() - 1, -1, -1):
		var pickup: Pickup = _active[i]
		if pickup == null or not is_instance_valid(pickup):
			_remove_at(i)
			continue
		var offset: Vector2 = player_pos - pickup.global_position
		var dist_sq: float = offset.length_squared()
		if dist_sq <= pickup_dist_sq:
			_collect(pickup)
			_remove_at(i)
			continue
		if dist_sq <= magnet_dist_sq:
			pickup.global_position += offset.normalized() * step
		elif lifetime > 0.0:
			_ages[i] += delta
			if _ages[i] >= lifetime:
				_pool.release(pickup)
				_remove_at(i)

func _collect(pickup: Pickup) -> void:
	if pickup.kind == Pickup.Kind.FEED:
		EventBus.feed_collected.emit(pickup.value)
	else:
		EventBus.essence_collected.emit(pickup.value)
	_pool.release(pickup)

func _remove_at(index: int) -> void:
	_active.remove_at(index)
	_ages.remove_at(index)
