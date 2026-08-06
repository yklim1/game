class_name EffectManager
extends Node2D
## 타격 피드백 이펙트(사망 조각·데미지 숫자)를 EventBus 구독으로 생성한다.
## 모든 이펙트는 풀에서 대여하며, 동시 개수 상한을 둬서 대량 사망 시 프레임이 무너지지 않게 한다.

## 동시에 살아 있을 수 있는 사망 이펙트 수. 넘치면 그 프레임의 사망은 연출을 생략한다.
@export var max_active_bursts: int = 40
## 데미지 숫자 표시 여부. 화면이 지저분하면 끈다.
@export var damage_numbers_enabled: bool = true
@export var max_active_numbers: int = 24
## 이 값보다 작은 피해는 숫자를 띄우지 않는다(장판 도트 도배 방지).
@export var damage_number_min: float = 1.0
## 사망 조각을 동물 색에서 흰색 쪽으로 이만큼 섞는다. 어두운 동물이 배경에 묻히는 것을 막는다.
@export_range(0.0, 1.0) var burst_color_whiten: float = 0.35

@onready var _burst_pool: ObjectPool = $DeathBurstPool
@onready var _number_pool: ObjectPool = $DamageNumberPool

func _ready() -> void:
	EventBus.animal_died.connect(_on_animal_died)
	EventBus.animal_hit.connect(_on_animal_hit)

func get_burst_pool() -> ObjectPool:
	return _burst_pool

func get_number_pool() -> ObjectPool:
	return _number_pool

func get_active_burst_count() -> int:
	return _burst_pool.get_active_count()

func get_active_number_count() -> int:
	return _number_pool.get_active_count()

func _on_animal_died(position: Vector2, data: AnimalData, _essence_value: int) -> void:
	if _burst_pool.get_active_count() >= max_active_bursts:
		return
	var burst: DeathBurst = _burst_pool.acquire() as DeathBurst
	if burst == null:
		return
	var tint: Color = Color.WHITE if data == null else data.color.lerp(Color.WHITE, burst_color_whiten)
	burst.setup(position, tint)

func _on_animal_hit(position: Vector2, damage: float) -> void:
	if not damage_numbers_enabled or damage < damage_number_min:
		return
	if _number_pool.get_active_count() >= max_active_numbers:
		return
	var number: DamageNumber = _number_pool.acquire() as DamageNumber
	if number == null:
		return
	number.setup(position, damage)
