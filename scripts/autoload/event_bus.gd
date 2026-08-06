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
