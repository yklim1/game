class_name AttackPoolRegistry
extends Node2D
## 공격 씬(PackedScene)별 오브젝트 풀을 필요할 때 만들어 보관한다.
## 덕분에 새 능력 .tres 가 새 attack_scene 을 써도 코드 수정 없이 풀링이 적용된다.

@export var default_pool_size: int = 32

var _pools: Dictionary = {}

func get_pool(scene: PackedScene) -> ObjectPool:
	if scene == null:
		return null
	var key: String = scene.resource_path
	if _pools.has(key):
		return _pools[key]
	var pool: ObjectPool = ObjectPool.new()
	pool.name = "Pool_%s" % key.get_file().get_basename()
	pool.scene = scene
	pool.initial_size = default_pool_size
	add_child(pool)
	_pools[key] = pool
	return pool

func get_pools() -> Array[ObjectPool]:
	var result: Array[ObjectPool] = []
	for key in _pools:
		result.append(_pools[key])
	return result
