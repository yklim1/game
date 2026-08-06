class_name AbilityManager
extends Node2D
## 능력 슬롯의 자동 발동을 담당. 각 슬롯은 독립 쿨다운으로 동시에 운용된다.
## 능력 종류(투사체/근접/장판)는 AbilityData.attack_kind 와 attack_scene 으로만 결정된다.

const NO_TARGET_RETRY: float = 0.1

## 시작 시 장착할 능력 id 목록(res://data/abilities 의 .tres id). ContentDB에서 해석한다.
@export var starting_ability_ids: Array[String] = []
@export var max_slots: int = 6

var abilities: Array[AbilityData] = []

var _registry: AttackPoolRegistry
var _cooldowns: Array[float] = []

func _ready() -> void:
	RunState.ability_slots = max_slots
	EventBus.mutation_acquired.connect(_on_mutation_acquired)
	for id in starting_ability_ids:
		var ability: AbilityData = ContentDB.get_ability(id)
		if ability == null:
			push_warning("AbilityManager: 능력 id를 찾을 수 없음 '%s'" % id)
			continue
		add_ability(ability)

func set_attack_registry(registry: AttackPoolRegistry) -> void:
	_registry = registry

func add_ability(ability: AbilityData) -> bool:
	if ability == null or abilities.size() >= max_slots:
		return false
	abilities.append(ability)
	_cooldowns.append(0.0)
	EventBus.ability_added.emit(ability)
	return true

func has_ability(id: String) -> bool:
	for ability in abilities:
		if ability != null and ability.id == id:
			return true
	return false

## 변이 payload 의 "add_ability" 만 처리한다. 스탯 계열은 RunState 가 담당한다.
func _on_mutation_acquired(data: MutationData) -> void:
	var ability_id: String = String(data.payload.get("add_ability", ""))
	if ability_id.is_empty() or has_ability(ability_id):
		return
	var ability: AbilityData = ContentDB.get_ability(ability_id)
	if ability == null:
		push_warning("AbilityManager: 변이가 가리키는 능력 id를 찾을 수 없음 '%s'" % ability_id)
		return
	add_ability(ability)

func get_ability_count() -> int:
	return abilities.size()

func _rebuild_cooldowns() -> void:
	_cooldowns.clear()
	for _i in abilities.size():
		_cooldowns.append(0.0)

func _physics_process(delta: float) -> void:
	if _registry == null or RunState.is_game_over:
		return
	if _cooldowns.size() != abilities.size():
		_rebuild_cooldowns()
	for i in abilities.size():
		var ability: AbilityData = abilities[i]
		if ability == null:
			continue
		_cooldowns[i] -= delta
		if _cooldowns[i] <= 0.0:
			_cooldowns[i] = _try_fire(ability)

func _try_fire(ability: AbilityData) -> float:
	var dir: Vector2 = Vector2.RIGHT
	if _needs_target(ability):
		var target: Node2D = _find_target(ability)
		if target == null:
			return NO_TARGET_RETRY
		dir = (target.global_position - global_position).normalized()
	_fire_volley(ability, dir)
	return maxf(ability.cooldown * RunState.cooldown_mult, 0.02)

func _needs_target(ability: AbilityData) -> bool:
	return ability.attack_kind != AbilityData.AttackKind.AREA_FIELD

func _fire_volley(ability: AbilityData, base_dir: Vector2) -> void:
	var count: int = maxi(1, ability.projectile_count)
	var spread: float = deg_to_rad(ability.spread_deg)
	for i in count:
		var offset: float = 0.0
		if count > 1:
			offset = spread * (float(i) / float(count - 1) - 0.5)
		_spawn_attack(ability, base_dir.rotated(offset))

func _spawn_attack(ability: AbilityData, dir: Vector2) -> void:
	var pool: ObjectPool = _registry.get_pool(ability.attack_scene)
	if pool == null:
		return
	var attack: Node = pool.acquire()
	if attack == null or not attack.has_method("setup"):
		return
	attack.setup(ability, global_position, dir, _roll_damage(ability))

## 런 스탯(데미지 배율·능력별 보너스·크리티컬)을 반영한 최종 데미지.
func _roll_damage(ability: AbilityData) -> float:
	var damage: float = ability.base_damage * RunState.damage_mult
	damage *= 1.0 + RunState.get_ability_damage_bonus(ability.id)
	if RunState.crit_chance > 0.0 and randf() < RunState.crit_chance:
		damage *= RunState.crit_mult
	return damage

func _find_target(ability: AbilityData) -> Node2D:
	var animals: Array[Node] = get_tree().get_nodes_in_group("animal")
	if animals.is_empty():
		return null
	if ability.aim_mode == AbilityData.AimMode.RANDOM:
		return _pick_random_in_range(animals, ability.range)
	return _pick_nearest(animals, ability.range)

func _pick_nearest(animals: Array[Node], max_range: float) -> Node2D:
	var nearest: Node2D = null
	var best_dist_sq: float = max_range * max_range
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

func _pick_random_in_range(animals: Array[Node], max_range: float) -> Node2D:
	var range_sq: float = max_range * max_range
	var origin: Vector2 = global_position
	var candidates: Array[Node2D] = []
	for node in animals:
		var animal: Node2D = node as Node2D
		if animal != null and origin.distance_squared_to(animal.global_position) <= range_sq:
			candidates.append(animal)
	if candidates.is_empty():
		return null
	return candidates[randi() % candidates.size()]
