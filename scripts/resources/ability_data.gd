class_name AbilityData
extends Resource
## 진화한 신체 부위/능력 정의 (데이터 주도). DESIGN.md 5.2 AbilityData 스키마 기반.
## 새 능력 추가는 코드 수정 없이 res://data/abilities 에 .tres 를 추가하면 된다.

enum AttackKind { PROJECTILE, MELEE_ARC, AREA_FIELD }
enum AimMode { NEAREST, RANDOM, FORWARD }
enum Rarity { COMMON, RARE, EPIC }

@export var id: String = ""
@export var display_name: String = ""
@export var attack_scene: PackedScene
@export var base_damage: float = 10.0
@export var cooldown: float = 0.9
@export var attack_kind: AttackKind = AttackKind.PROJECTILE
@export var projectile_count: int = 1
@export var pierce: int = 0
## 조준 대상 탐색 사거리(픽셀).
@export var range: float = 400.0
@export var projectile_speed: float = 420.0
@export var projectile_lifetime: float = 1.4
@export var spread_deg: float = 12.0
## MELEE_ARC/AREA_FIELD 의 타격 반경(픽셀).
@export var area_radius: float = 96.0
## MELEE_ARC 부채꼴 각도(도). 360이면 전방위.
@export var arc_deg: float = 120.0
## AREA_FIELD 지속 시간(초).
@export var duration: float = 3.0
## AREA_FIELD 데미지 틱 간격(초).
@export var tick_interval: float = 0.5
@export var color: Color = Color.WHITE
@export var aim_mode: AimMode = AimMode.NEAREST
@export var rarity: Rarity = Rarity.COMMON
@export var lineage: Array[String] = []
