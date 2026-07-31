extends Control
## 게임오버 패널. 일시정지 중에도 입력을 받도록 process_mode를 ALWAYS로 둔다(씬에서 설정).
## restart 입력 시 현재 씬을 다시 로드한다.

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("restart"):
		get_tree().paused = false
		get_tree().reload_current_scene()
