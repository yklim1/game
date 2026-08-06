extends Node
## 테스트 전용: 게임 씬을 창 모드로 몇 초 돌린 뒤 뷰포트를 PNG로 저장한다.
## 헤드리스(더미 렌더러)에서는 의미 있는 이미지가 나오지 않으므로 일반 실행에서만 쓴다.
##
## 실행 예:
##   godot_console.exe --path <프로젝트> res://scenes/tests/screenshot_capture.tscn -- --delay=6 --out=docs/screenshots/phase2.png

const GAME_SCENE_PATH: String = "res://scenes/main/game.tscn"

var _delay: float = 6.0
var _out_path: String = "docs/screenshots/phase2.png"

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--delay="):
			_delay = float(arg.split("=")[1])
		elif arg.begins_with("--out="):
			_out_path = arg.split("=")[1]
	_run.call_deferred()

func _run() -> void:
	var game: Node = (load(GAME_SCENE_PATH) as PackedScene).instantiate()
	get_tree().root.add_child(game)
	var autopilot: TestAutopilot = TestAutopilot.new()
	autopilot.set_player(game.get_player())
	get_tree().root.add_child(autopilot)

	var elapsed: float = 0.0
	while elapsed < _delay:
		await get_tree().process_frame
		elapsed += get_process_delta_time()

	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	if image == null:
		print("SCREENSHOT FAIL: 뷰포트 이미지를 얻지 못했습니다 (렌더러: %s)" % DisplayServer.get_name())
		get_tree().quit(1)
		return
	var absolute: String = ProjectSettings.globalize_path("res://").path_join(_out_path)
	DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
	var error: int = image.save_png(absolute)
	if error != OK:
		print("SCREENSHOT FAIL: 저장 실패 code=%d path=%s" % [error, absolute])
		get_tree().quit(1)
		return
	print("SCREENSHOT OK: %s (%dx%d)" % [absolute, image.get_width(), image.get_height()])
	get_tree().quit(0)
