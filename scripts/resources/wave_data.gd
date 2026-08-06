class_name WaveData
extends Resource
## 웨이브 정의 (데이터 주도). DESIGN.md 4.4 스폰/웨이브 스케일링 기반.
## 새 웨이브 추가는 코드 수정 없이 res://data/waves 에 .tres 를 추가하면 된다.

@export var index: int = 1
@export var display_name: String = ""
## 웨이브 지속 시간(초). 0 이하면 무한(마지막 웨이브 루프용).
@export var duration: float = 30.0
@export var spawn_interval: float = 1.1
@export var batch_size: int = 1
@export var hp_mult: float = 1.0
@export var speed_mult: float = 1.0
@export var damage_mult: float = 1.0
## 스폰된 동물이 엘리트가 될 확률(0~1).
@export_range(0.0, 1.0) var elite_chance: float = 0.0
## 이 웨이브에 등장하는 AnimalData id 목록. 비어 있으면 스폰하지 않는다.
@export var spawn_ids: Array[String] = []
