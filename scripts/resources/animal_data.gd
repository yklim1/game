class_name AnimalData
extends Resource
## 동물 적 정의 (데이터 주도). DESIGN.md 5.2 AnimalData 스키마 기반(MVP 최소 필드).

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
@export var behavior: Behavior = Behavior.CHASE
@export var spawn_weight: float = 1.0
@export var family: Family = Family.BUGS
@export var radius: float = 14.0
@export var tags: Array[String] = []
