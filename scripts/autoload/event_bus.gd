extends Node
## 전역 시그널 허브. 계층이 다른 노드 간 통신은 여기로 발행/구독한다.

signal player_health_changed(current: float, maximum: float)
signal player_died
signal animal_died(position: Vector2, essence_value: int)
