extends Node
## 현재 런의 진행 데이터. 런 종료(재시작) 시 reset()으로 초기화한다.

var elapsed_time: float = 0.0
var kills: int = 0
var is_game_over: bool = false

func _ready() -> void:
	EventBus.animal_died.connect(_on_animal_died)
	EventBus.player_died.connect(_on_player_died)

func _process(delta: float) -> void:
	if not is_game_over:
		elapsed_time += delta

func reset() -> void:
	elapsed_time = 0.0
	kills = 0
	is_game_over = false

func _on_animal_died(_position: Vector2, _essence_value: int) -> void:
	kills += 1

func _on_player_died() -> void:
	is_game_over = true
