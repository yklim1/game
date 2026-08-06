class_name LineageSynergyData
extends Resource
## 진화 계통(태그) 세트 보너스 정의. DESIGN.md 5.3 표 기반.
## 같은 계통의 능력·변이를 thresholds[i] 개 이상 모으면 payloads[i] 가 1회 적용된다.
## payload 키 규약은 MutationData 주석과 동일하다.

@export var lineage: String = ""
@export var display_name: String = ""
## 오름차순 임계값(예: [3, 5]).
@export var thresholds: Array[int] = []
## 각 임계값 도달 시 표시할 설명. thresholds 와 같은 길이.
@export var descriptions: Array[String] = []
## 각 임계값 도달 시 적용할 효과. thresholds 와 같은 길이.
@export var payloads: Array[Dictionary] = []

## thresholds 보다 짧은 배열이 들어와도 크래시하지 않도록 방어적으로 읽는다.
func get_description(tier_index: int) -> String:
	if tier_index < 0 or tier_index >= descriptions.size():
		return ""
	return descriptions[tier_index]

func get_payload(tier_index: int) -> Dictionary:
	if tier_index < 0 or tier_index >= payloads.size():
		return {}
	return payloads[tier_index]

## 보유 개수로 달성한 단계 수(0 = 미발동).
func tier_for_count(count: int) -> int:
	var tier: int = 0
	for threshold in thresholds:
		if count >= threshold:
			tier += 1
	return tier

func next_threshold(count: int) -> int:
	for threshold in thresholds:
		if count < threshold:
			return threshold
	return 0
