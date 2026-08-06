class_name ObjectPool
extends Node2D
## 대량 개체(투사체/적/픽업) 재사용 풀. 대여 시 on_acquire(), 반환 시 on_release()를 호출한다.
## 풀링 대상은 set_pool(self)로 자신을 반환할 풀을 받고, on_acquire()/on_release()를 구현한다.

@export var scene: PackedScene
@export var initial_size: int = 32

var _free: Array[Node] = []
var _free_ids: Dictionary = {}
var _created: int = 0
var _acquired: int = 0

func _ready() -> void:
	prewarm(initial_size)

func prewarm(count: int) -> void:
	if scene == null:
		return
	for _i in count:
		release(_instantiate())

func acquire() -> Node:
	var node: Node
	if _free.is_empty():
		node = _instantiate()
	else:
		node = _free.pop_back()
		_free_ids.erase(node.get_instance_id())
	if node == null:
		return null
	_acquired += 1
	if node.has_method("on_acquire"):
		node.on_acquire()
	return node

func release(node: Node) -> void:
	if node == null:
		return
	# 같은 프레임에 두 번 반환되면 풀이 같은 노드를 중복 대여하게 되므로 막는다.
	if _free_ids.has(node.get_instance_id()):
		return
	if node.has_method("on_release"):
		node.on_release()
	_free_ids[node.get_instance_id()] = true
	_free.append(node)

func get_total_count() -> int:
	return _created

## 지금까지 대여된 횟수. 생성 수보다 크면 재사용이 일어났다는 뜻이다.
func get_acquire_count() -> int:
	return _acquired

func get_free_count() -> int:
	return _free.size()

func get_active_count() -> int:
	return _created - _free.size()

func _instantiate() -> Node:
	if scene == null:
		push_warning("ObjectPool: scene 이 비어 있어 인스턴스를 만들 수 없습니다 (%s)" % name)
		return null
	var node: Node = scene.instantiate()
	add_child(node)
	_created += 1
	if node.has_method("set_pool"):
		node.set_pool(self)
	return node
