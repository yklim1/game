class_name MutationPool
extends RefCounted
## 변이 카드/상점 후보를 등장 조건·중복 상한·희귀도 가중치로 추첨한다.
## 카드 UI와 상점이 같은 규칙을 공유하도록 한 곳에 모아 둔다.

const RARITY_WEIGHT: Dictionary = {
	MutationData.Rarity.COMMON: 1.0,
	MutationData.Rarity.RARE: 0.45,
	MutationData.Rarity.EPIC: 0.18,
}

## 서로 다른 변이를 count개 뽑는다(중복 없음). 후보가 모자라면 뽑을 수 있는 만큼만 반환한다.
static func draw(count: int, for_shop: bool = false) -> Array[MutationData]:
	var candidates: Array[MutationData] = eligible(for_shop)
	var result: Array[MutationData] = []
	for _i in maxi(count, 0):
		var picked: MutationData = _pick_weighted(candidates)
		if picked == null:
			break
		result.append(picked)
		candidates.erase(picked)
	return result

## 지금 등장 가능한 변이 목록.
static func eligible(for_shop: bool = false) -> Array[MutationData]:
	var result: Array[MutationData] = []
	for data in ContentDB.get_mutations():
		if data == null:
			continue
		if not (data.in_shop_pool if for_shop else data.in_card_pool):
			continue
		if RunState.get_mutation_count(data.id) >= maxi(data.max_stacks, 1):
			continue
		# 슬롯이 꽉 찼는데 새 능력 카드를 내보내면 아무 일도 일어나지 않는다.
		if data.kind == MutationData.Kind.NEW_ABILITY and RunState.get_ability_ids().size() >= RunState.ability_slots:
			continue
		if not requirements_met(data):
			continue
		result.append(data)
	return result

static func requirements_met(data: MutationData) -> bool:
	for requirement in data.requires:
		if not _check_requirement(requirement):
			return false
	return true

static func _check_requirement(requirement: String) -> bool:
	var parts: PackedStringArray = requirement.split(":")
	if parts.size() < 2:
		push_warning("MutationPool: 해석할 수 없는 requires '%s'" % requirement)
		return true
	match parts[0]:
		"ability":
			return RunState.has_ability(parts[1])
		"not_ability":
			return not RunState.has_ability(parts[1])
		"lineage":
			if parts.size() < 3:
				return true
			return RunState.get_lineage_count(parts[1]) >= int(parts[2])
		"level":
			return RunState.level >= int(parts[1])
	push_warning("MutationPool: 알 수 없는 requires 종류 '%s'" % requirement)
	return true

static func _pick_weighted(candidates: Array[MutationData]) -> MutationData:
	var total: float = 0.0
	for data in candidates:
		total += _weight_of(data)
	if total <= 0.0:
		return null
	var roll: float = randf() * total
	for data in candidates:
		roll -= _weight_of(data)
		if roll <= 0.0:
			return data
	return candidates.back()

static func _weight_of(data: MutationData) -> float:
	return maxf(data.weight, 0.0) * float(RARITY_WEIGHT.get(data.rarity, 1.0))
