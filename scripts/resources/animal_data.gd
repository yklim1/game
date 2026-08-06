class_name AnimalData
extends Resource
## 동물 적 정의 (데이터 주도). DESIGN.md 5.2 AnimalData 스키마 기반.
## 새 동물 추가는 코드 수정 없이 res://data/animals 에 .tres 를 추가하면 된다.

enum Behavior { CHASE }
enum Family { BUGS, CRITTERS, SCALE, WINGS, BRUTES, APEX }

@export var id: String = ""
@export var display_name: String = ""
@export var sprite: Texture2D
@export var color: Color = Color.WHITE
@export var max_hp: float = 10.0
@export var move_speed: float = 85.0
@export var contact_damage: float = 4.0
@export var essence_value: int = 1
## 먹이(Feed) 드롭 확률(0~1). 먹이는 Phase 3 소굴 상점 재화.
@export_range(0.0, 1.0) var feed_chance: float = 0.0
@export var behavior: Behavior = Behavior.CHASE
@export var spawn_weight: float = 1.0
@export var family: Family = Family.BUGS
@export var radius: float = 14.0
## 추격 시 좌우로 흔들리는 폭(픽셀/초). 0이면 직선 추격.
@export var wobble_strength: float = 0.0
@export var wobble_speed: float = 6.0
@export var tags: Array[String] = []
