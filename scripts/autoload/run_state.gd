extends Node
## 현재 런의 진행 데이터. 런 종료(재시작) 시 reset()으로 초기화한다.
## 영속(메타) 데이터는 여기에 두지 않는다.
## 보유 변이·계통 카운트·런 스탯의 단일 소유자이며, 게임플레이 노드를 직접 조작하지 않고
## EventBus 시그널(player_stats_changed / mutation_acquired / synergy_activated)로만 알린다.

## 레벨업 곡선: xp_to_next = BASE_XP * level ^ XP_GROWTH (DESIGN.md 4.5).
const BASE_XP: float = 5.0
const XP_GROWTH: float = 1.35
const ARMOR_CAP: float = 0.75
const DODGE_CAP: float = 0.6
const COOLDOWN_MULT_FLOOR: float = 0.3

var elapsed_time: float = 0.0
var kills: int = 0
var is_game_over: bool = false

var level: int = 1
var xp: int = 0
var xp_to_next: int = 0
var feed: int = 0
var feed_spent: int = 0
var purchases: int = 0
var wave_index: int = 0
## 능력 슬롯 수. AbilityManager 가 자신의 max_slots 로 알려준다.
var ability_slots: int = 6

var damage_mult: float = 1.0
var move_speed_mult: float = 1.0
var bonus_max_health: float = 0.0
var cooldown_mult: float = 1.0
var area_mult: float = 1.0
var pickup_radius_mult: float = 1.0
var armor: float = 0.0
var dodge_chance: float = 0.0
var crit_chance: float = 0.0
var crit_mult: float = 2.0
var heal_on_kill: float = 0.0

var mutations: Array[MutationData] = []

var _ability_damage_bonus: Dictionary = {}
var _mutation_counts: Dictionary = {}
var _lineage_counts: Dictionary = {}
var _synergy_tiers: Dictionary = {}
var _ability_ids: Array[String] = []

func _ready() -> void:
	reset()
	EventBus.animal_died.connect(_on_animal_died)
	EventBus.player_died.connect(_on_player_died)
	EventBus.essence_collected.connect(_on_essence_collected)
	EventBus.feed_collected.connect(_on_feed_collected)
	EventBus.wave_started.connect(_on_wave_started)
	EventBus.ability_added.connect(_on_ability_added)

func _process(delta: float) -> void:
	if not is_game_over:
		elapsed_time += delta

func reset() -> void:
	elapsed_time = 0.0
	kills = 0
	is_game_over = false
	level = 1
	xp = 0
	xp_to_next = _xp_required(level)
	feed = 0
	feed_spent = 0
	purchases = 0
	wave_index = 0
	ability_slots = 6
	damage_mult = 1.0
	move_speed_mult = 1.0
	bonus_max_health = 0.0
	cooldown_mult = 1.0
	area_mult = 1.0
	pickup_radius_mult = 1.0
	armor = 0.0
	dodge_chance = 0.0
	crit_chance = 0.0
	crit_mult = 2.0
	heal_on_kill = 0.0
	mutations.clear()
	_ability_damage_bonus.clear()
	_mutation_counts.clear()
	_lineage_counts.clear()
	_synergy_tiers.clear()
	_ability_ids.clear()

func add_xp(amount: int) -> void:
	if is_game_over or amount <= 0:
		return
	xp += amount
	while xp >= xp_to_next:
		xp -= xp_to_next
		_level_up()
	EventBus.xp_changed.emit(xp, xp_to_next, level)

# ---------------------------------------------------------------- 변이 / 계통

## 변이를 실제로 적용한다. 중복 상한을 넘으면 false.
func apply_mutation(data: MutationData) -> bool:
	if data == null or is_game_over:
		return false
	if get_mutation_count(data.id) >= maxi(data.max_stacks, 1):
		return false
	mutations.append(data)
	_mutation_counts[data.id] = get_mutation_count(data.id) + 1
	for tag in data.lineage:
		_add_lineage(tag, 1)
	_apply_payload(data.payload)
	EventBus.mutation_acquired.emit(data)
	_refresh_synergies()
	EventBus.player_stats_changed.emit()
	return true

func get_mutation_count(id: String) -> int:
	return int(_mutation_counts.get(id, 0))

func get_mutation_total() -> int:
	return mutations.size()

func has_ability(id: String) -> bool:
	return _ability_ids.has(id)

func get_ability_ids() -> Array[String]:
	return _ability_ids.duplicate()

func get_ability_damage_bonus(id: String) -> float:
	return float(_ability_damage_bonus.get(id, 0.0))

## 능력별 데미지 보너스 합계(표시/검증용).
func get_ability_damage_bonus_total() -> float:
	var total: float = 0.0
	for value in _ability_damage_bonus.values():
		total += float(value)
	return total

func get_lineage_count(tag: String) -> int:
	return int(_lineage_counts.get(tag, 0))

func get_lineage_counts() -> Dictionary:
	return _lineage_counts.duplicate()

## 해당 계통에서 발동된 세트 보너스 단계 수(0 = 미발동).
func get_synergy_tier(tag: String) -> int:
	return int(_synergy_tiers.get(tag, 0))

func spend_feed(amount: int) -> bool:
	if amount < 0 or feed < amount:
		return false
	feed -= amount
	feed_spent += amount
	return true

func _on_ability_added(ability: AbilityData) -> void:
	if ability == null:
		return
	_ability_ids.append(ability.id)
	for tag in ability.lineage:
		_add_lineage(tag, 1)
	_refresh_synergies()
	EventBus.player_stats_changed.emit()

func _add_lineage(tag: String, amount: int) -> void:
	if tag.is_empty():
		return
	_lineage_counts[tag] = get_lineage_count(tag) + amount

## 계통 카운트가 임계값을 넘긴 만큼 세트 보너스를 적용한다. 이미 발동한 단계는 다시 적용하지 않는다.
func _refresh_synergies() -> void:
	for synergy in ContentDB.get_synergies():
		if synergy == null or synergy.lineage.is_empty():
			continue
		var reached: int = synergy.tier_for_count(get_lineage_count(synergy.lineage))
		var applied: int = get_synergy_tier(synergy.lineage)
		while applied < reached:
			_apply_payload(synergy.get_payload(applied))
			applied += 1
			_synergy_tiers[synergy.lineage] = applied
			EventBus.synergy_activated.emit(synergy.lineage, applied, synergy.get_description(applied - 1))

func _apply_payload(payload: Dictionary) -> void:
	for key in payload.keys():
		_apply_payload_entry(String(key), payload[key], payload)

func _apply_payload_entry(key: String, raw_value: Variant, payload: Dictionary) -> void:
	match key:
		"damage_pct":
			damage_mult += float(raw_value)
		"move_speed_pct":
			move_speed_mult = maxf(move_speed_mult + float(raw_value), 0.2)
		"max_health":
			bonus_max_health += float(raw_value)
		"armor_pct":
			armor = clampf(armor + float(raw_value), 0.0, ARMOR_CAP)
		"cooldown_pct":
			cooldown_mult = maxf(cooldown_mult * (1.0 - float(raw_value)), COOLDOWN_MULT_FLOOR)
		"area_pct":
			area_mult = maxf(area_mult + float(raw_value), 0.2)
		"pickup_radius_pct":
			pickup_radius_mult = maxf(pickup_radius_mult + float(raw_value), 0.2)
		"crit_chance":
			crit_chance = clampf(crit_chance + float(raw_value), 0.0, 1.0)
		"crit_mult":
			crit_mult += float(raw_value)
		"dodge_chance":
			dodge_chance = clampf(dodge_chance + float(raw_value), 0.0, DODGE_CAP)
		"heal_on_kill":
			heal_on_kill += float(raw_value)
		"ability_damage_pct":
			var ability_id: String = String(payload.get("ability_id", ""))
			if not ability_id.is_empty():
				_ability_damage_bonus[ability_id] = get_ability_damage_bonus(ability_id) + float(raw_value)
		"add_ability", "ability_id":
			pass  # AbilityManager 가 mutation_acquired 로 처리한다.
		_:
			push_warning("RunState: 알 수 없는 payload 키 '%s'" % key)

# ---------------------------------------------------------------- 내부

func _level_up() -> void:
	level += 1
	xp_to_next = _xp_required(level)
	EventBus.player_leveled_up.emit(level)

func _xp_required(for_level: int) -> int:
	return int(round(BASE_XP * pow(float(for_level), XP_GROWTH)))

func _on_animal_died(_position: Vector2, _data: AnimalData, _essence_value: int) -> void:
	kills += 1

func _on_player_died() -> void:
	is_game_over = true

func _on_essence_collected(value: int) -> void:
	add_xp(value)

func _on_feed_collected(value: int) -> void:
	feed += value

func _on_wave_started(index: int, _data: WaveData) -> void:
	wave_index = index
