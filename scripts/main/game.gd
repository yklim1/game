class_name Game
extends Node2D
## 한 런의 루트. 풀·플레이어·스포너·웨이브·픽업·UI를 연결하고 사망 시 게임오버를 처리한다.

@onready var _player: Player = $Player
@onready var _animal_pool: ObjectPool = $AnimalPool
@onready var _pickup_pool: ObjectPool = $PickupPool
@onready var _attack_pools: AttackPoolRegistry = $AttackPools
@onready var _spawner: AnimalSpawner = $AnimalSpawner
@onready var _wave_director: WaveDirector = $WaveDirector
@onready var _pickup_manager: PickupManager = $PickupManager
@onready var _effect_manager: EffectManager = $EffectManager
@onready var _hit_stop: HitStop = $HitStop
@onready var _game_over_panel: Control = $UI/GameOver
@onready var _mutation_cards: MutationCardScreen = $UI/MutationCards
@onready var _shop: ShopScreen = $UI/Shop

func _enter_tree() -> void:
	# 자식(_ready)들이 런 데이터를 읽기 전에 초기화한다.
	RunState.reset()

func _ready() -> void:
	get_tree().paused = false
	_game_over_panel.visible = false
	_player.get_ability_manager().set_attack_registry(_attack_pools)
	_spawner.setup(_animal_pool, _player, _wave_director)
	_pickup_manager.setup(_pickup_pool, _player)
	EventBus.player_died.connect(_on_player_died)
	_wave_director.begin()

func get_player() -> Player:
	return _player

func get_animal_pool() -> ObjectPool:
	return _animal_pool

func get_pickup_pool() -> ObjectPool:
	return _pickup_pool

func get_attack_pools() -> AttackPoolRegistry:
	return _attack_pools

func get_spawner() -> AnimalSpawner:
	return _spawner

func get_wave_director() -> WaveDirector:
	return _wave_director

func get_pickup_manager() -> PickupManager:
	return _pickup_manager

func get_effect_manager() -> EffectManager:
	return _effect_manager

func get_hit_stop() -> HitStop:
	return _hit_stop

func get_mutation_card_screen() -> MutationCardScreen:
	return _mutation_cards

func get_shop_screen() -> ShopScreen:
	return _shop

func is_game_over_visible() -> bool:
	return _game_over_panel.visible

func _on_player_died() -> void:
	_game_over_panel.visible = true
	get_tree().paused = true
