class_name Game
extends Node2D
## 한 런의 루트. 풀·플레이어·스포너·UI를 연결하고 사망 시 게임오버를 처리한다.

@onready var _player: Player = $Player
@onready var _projectile_pool: ObjectPool = $ProjectilePool
@onready var _animal_pool: ObjectPool = $AnimalPool
@onready var _spawner: AnimalSpawner = $AnimalSpawner
@onready var _game_over_panel: Control = $UI/GameOver

func _ready() -> void:
	RunState.reset()
	get_tree().paused = false
	_game_over_panel.visible = false
	_player.get_ability_manager().set_projectile_pool(_projectile_pool)
	_spawner.setup(_animal_pool, _player)
	EventBus.player_died.connect(_on_player_died)

func _on_player_died() -> void:
	_game_over_panel.visible = true
	get_tree().paused = true
