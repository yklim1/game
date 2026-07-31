class_name AbilityData
extends Resource
## 진화한 신체 부위/능력 정의 (데이터 주도). DESIGN.md 5.2 AbilityData 스키마 기반(MVP 최소 필드).

enum AttackKind { PROJECTILE, MELEE_ARC }
enum AimMode { NEAREST, RANDOM, FORWARD }

@export var id: String = ""
@export var display_name: String = ""
@export var attack_scene: PackedScene
@export var base_damage: float = 10.0
@export var cooldown: float = 0.9
@export var attack_kind: AttackKind = AttackKind.PROJECTILE
@export var projectile_count: int = 1
@export var pierce: int = 0
@export var range: float = 400.0
@export var projectile_speed: float = 420.0
@export var projectile_lifetime: float = 1.4
@export var spread_deg: float = 12.0
@export var aim_mode: AimMode = AimMode.NEAREST
@export var lineage: Array[String] = []
