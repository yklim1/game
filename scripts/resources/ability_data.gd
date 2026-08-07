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
## 공격 비주얼 텍스처(투사체·근접 잔상·장판 공용, 투명 PNG). 비우면 플레이스홀더를 color 로 물들여 쓴다.
## 규격은 docs/ART_ASSET_SPEC.md 참고.
@export var attack_texture: Texture2D
## PROJECTILE 표시 크기(px, 긴 변). 0이면 씬의 기본 크기를 유지한다.
## MELEE_ARC/AREA_FIELD 는 area_radius 로 크기가 정해지므로 이 값을 쓰지 않는다.
@export var projectile_size: float = 0.0
## 실제 텍스처에도 color 를 곱할지. 기본은 아트 원색 유지(false, 알파는 유지된다).
@export var tint_attack_texture: bool = false
## 대표색. 플레이스홀더 색이며 장판/잔상의 투명도(알파)는 실제 텍스처에서도 그대로 적용된다.
@export var color: Color = Color.WHITE
@export var aim_mode: AimMode = AimMode.NEAREST
@export var rarity: Rarity = Rarity.COMMON
@export var lineage: Array[String] = []
