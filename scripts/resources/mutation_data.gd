class_name MutationData
extends Resource
## 변이(업그레이드) 정의 (데이터 주도). DESIGN.md 5.2 MutationData 스키마 기반.
## 새 변이 추가는 코드 수정 없이 res://data/mutations 에 .tres 를 추가하면 된다.
##
## payload Dictionary 규약 (RunState._apply_payload 가 해석):
##   "damage_pct": float        데미지 배율 가산 (0.15 = +15%)
##   "move_speed_pct": float    이동속도 배율 가산
##   "max_health": float        최대 체력 가산(고정값)
##   "armor_pct": float         피해 감소 가산 (상한 RunState.ARMOR_CAP)
##   "cooldown_pct": float      쿨다운 감소 (0.10 = 10% 빠르게)
##   "area_pct": float          장판/근접 범위 배율 가산
##   "pickup_radius_pct": float 픽업 반경 배율 가산
##   "crit_chance": float       크리티컬 확률 가산
##   "crit_mult": float         크리티컬 배율 가산
##   "dodge_chance": float      회피 확률 가산
##   "heal_on_kill": float      처치 시 회복량 가산
##   "add_ability": String      능력 id 획득 (AbilityManager 가 처리)
##   "ability_id" + "ability_damage_pct": 특정 능력 데미지 가산

## DESIGN.md 의 `type` 필드. GDScript 가독성을 위해 이름만 kind 로 쓴다.
enum Kind { STAT, NEW_ABILITY, ABILITY_UP, SYNERGY }
enum Rarity { COMMON, RARE, EPIC }

@export var id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var kind: Kind = Kind.STAT
@export var payload: Dictionary = {}
@export var lineage: Array[String] = []
@export var rarity: Rarity = Rarity.COMMON
## 카드/상점 추첨 가중치. 희귀도 가중치와 곱해진다.
@export var weight: float = 1.0
## 등장 조건. "ability:<id>" / "not_ability:<id>" / "lineage:<계통>:<개수>" / "level:<레벨>"
@export var requires: Array[String] = []
## 한 런에서 중복 획득 가능한 최대 횟수.
@export var max_stacks: int = 1
## 소굴 상점 가격(먹이).
@export var cost: int = 10
@export var in_card_pool: bool = true
@export var in_shop_pool: bool = true
