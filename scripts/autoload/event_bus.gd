extends Node
## 전역 시그널 허브. 계층이 다른 노드 간 통신은 여기로 발행/구독한다.

signal player_health_changed(current: float, maximum: float)
signal player_died
signal animal_died(position: Vector2, data: AnimalData, essence_value: int)
signal essence_collected(value: int)
signal feed_collected(value: int)
signal xp_changed(current_xp: int, xp_to_next: int, level: int)
signal player_leveled_up(level: int)
signal wave_started(index: int, data: WaveData)
signal wave_ended(index: int)

## 런 스탯(변이/시너지/능력)이 바뀌어 재계산이 필요할 때.
signal player_stats_changed
signal ability_added(ability: AbilityData)

## 3택 변이 카드
signal mutation_offered(options: Array)
signal mutation_acquired(data: MutationData)
signal mutation_cards_closed
signal synergy_activated(lineage: String, tier: int, description: String)

## 소굴 상점
signal shop_opened(wave_index: int)
signal shop_closed
signal shop_purchased(data: MutationData, cost: int)
signal shop_purchase_failed(data: MutationData, cost: int)
signal shop_rerolled(cost: int)
