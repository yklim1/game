extends Node
## 시작 시 res://data 하위의 .tres를 모두 로드·캐싱하는 데이터 접근 단일 창구.
## 데이터 오류(잘못된 타입/빈 id/누락 폴더)가 있어도 크래시 없이 건너뛴다.

const ABILITY_DIR: String = "res://data/abilities"
const ANIMAL_DIR: String = "res://data/animals"
const WAVE_DIR: String = "res://data/waves"

var _abilities: Dictionary = {}
var _animals: Dictionary = {}
var _waves: Array[WaveData] = []

func _ready() -> void:
	reload()

func reload() -> void:
	_abilities.clear()
	_animals.clear()
	_waves.clear()
	for res in _load_dir(ABILITY_DIR):
		var ability: AbilityData = res as AbilityData
		if ability != null and not ability.id.is_empty():
			_abilities[ability.id] = ability
	for res in _load_dir(ANIMAL_DIR):
		var animal: AnimalData = res as AnimalData
		if animal != null and not animal.id.is_empty():
			_animals[animal.id] = animal
	for res in _load_dir(WAVE_DIR):
		var wave: WaveData = res as WaveData
		if wave != null:
			_waves.append(wave)
	_waves.sort_custom(func(a: WaveData, b: WaveData) -> bool: return a.index < b.index)

func get_ability(id: String) -> AbilityData:
	return _abilities.get(id, null) as AbilityData

func get_animal(id: String) -> AnimalData:
	return _animals.get(id, null) as AnimalData

func get_waves() -> Array[WaveData]:
	return _waves

func get_ability_ids() -> Array:
	return _abilities.keys()

func get_animal_ids() -> Array:
	return _animals.keys()

func _load_dir(path: String) -> Array[Resource]:
	var result: Array[Resource] = []
	var dir: DirAccess = DirAccess.open(path)
	if dir == null:
		push_warning("ContentDB: 데이터 폴더를 열 수 없음 %s" % path)
		return result
	for raw_name in dir.get_files():
		# 익스포트된 빌드에서는 .tres 가 .tres.remap 으로 나타난다.
		var file_name: String = raw_name.trim_suffix(".remap")
		if not file_name.ends_with(".tres"):
			continue
		var res: Resource = ResourceLoader.load(path.path_join(file_name))
		if res == null:
			push_warning("ContentDB: 로드 실패 %s" % file_name)
			continue
		result.append(res)
	return result
