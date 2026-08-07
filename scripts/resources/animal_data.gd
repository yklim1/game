class_name AnimalData
extends Resource
## 동물 적 정의 (데이터 주도). DESIGN.md 5.2 AnimalData 스키마 기반.
## 새 동물 추가는 코드 수정 없이 res://data/animals 에 .tres 를 추가하면 된다.

enum Behavior { CHASE }
enum Family { BUGS, CRITTERS, SCALE, WINGS, BRUTES, APEX }

@export var id: String = ""
@export var display_name: String = ""
## 실제 스프라이트(투명 PNG). 비우면 플레이스홀더(icon.svg)를 color 로 물들여 쓴다.
## 규격은 docs/ART_ASSET_SPEC.md 참고.
@export var sprite: Texture2D
## 화면 표시 크기(px, 긴 변 기준). 0이면 충돌 반경에 맞춘다(radius * 2).
## 텍스처 원본 해상도와 무관하게 이 크기로 그려지므로, 아트 해상도가 달라도 게임 내 크기는 일정하다.
@export var sprite_size: float = 0.0
## 실제 스프라이트에도 color 를 곱할지. 기본은 아트 원색 유지(false).
@export var tint_sprite: bool = false
## 대표색. 플레이스홀더 색이자, 실제 스프라이트를 넣은 뒤에도 사망 조각 이펙트 색으로 계속 쓰인다.
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
