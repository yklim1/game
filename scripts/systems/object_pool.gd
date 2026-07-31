class_name ObjectPool
extends Node2D
## 대량 개체(투사체/적) 재사용 풀. 대여 시 on_acquire(), 반환 시 on_release()를 호출한다.
## 풀링 대상은 set_pool(self)로 자신을 반환할 풀을 받고, on_acquire()/on_release()를 구현한다.

@export var scene: PackedScene
@export var initial_size: int = 32

var _free: Array[Node] = []

func _ready() -> void:
	if scene == null:
		return
	for _i in initial_size:
		var node: Node = _instantiate()
		release(node)

func acquire() -> Node:
	var node: Node
	if _free.is_empty():
		node = _instantiate()
	else:
		node = _free.pop_back()
	if node.has_method("on_acquire"):
		node.on_acquire()
	return node

func release(node: Node) -> void:
	if node.has_method("on_release"):
		node.on_release()
	_free.append(node)

func _instantiate() -> Node:
	var node: Node = scene.instantiate()
	add_child(node)
	if node.has_method("set_pool"):
		node.set_pool(self)
	return node
