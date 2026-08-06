extends Node
## 테스트 전용: 게임 씬을 창 모드로 몇 초 돌린 뒤 뷰포트를 PNG로 저장한다.
## 헤드리스(더미 렌더러)에서는 의미 있는 이미지가 나오지 않으므로 일반 실행에서만 쓴다.
##
## 실행 예:
##   godot_console.exe --path <프로젝트> res://scenes/tests/screenshot_capture.tscn -- \
##       --delay=12 --mode=cards --out=docs/screenshots/phase3_upgrade_cards.png
##
## --mode=gameplay : 전투 화면 (기본)
## --mode=cards    : 강제로 레벨업시켜 3택 변이 카드 화면
## --mode=shop     : 강제로 웨이브를 종료시켜 소굴 상점 화면

const GAME_SCENE_PATH: String = "res://scenes/main/game.tscn"
const UI_WAIT_LIMIT: float = 3.0
## 상점 화면에 구매 가능한 상품이 보이도록 넣어 주는 먹이.
const SHOP_DEMO_FEED: int = 70

var _delay: float = 6.0
var _mode: String = "gameplay"
var _out_path: String = "docs/screenshots/phase3.png"

var _game: Node
var _autopilot: TestAutopilot

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--delay="):
			_delay = float(arg.split("=")[1])
		elif arg.begins_with("--out="):
			_out_path = arg.split("=")[1]
		elif arg.begins_with("--mode="):
			_mode = arg.split("=")[1]
	_run.call_deferred()

func _run() -> void:
	_game = (load(GAME_SCENE_PATH) as PackedScene).instantiate()
	get_tree().root.add_child(_game)
	_autopilot = TestAutopilot.new()
	_autopilot.set_player(_game.get_player())
	_autopilot.set_ui(_game.get_mutation_card_screen(), _game.get_shop_screen())
	get_tree().root.add_child(_autopilot)

	await _wait(_delay)
	match _mode:
		"cards":
			await _open_cards()
		"shop":
			await _open_shop()
	await _capture()

## 카드가 뜨면 오토파일럿이 바로 골라 버리므로 자동 처리를 끄고 레벨업을 강제한다.
func _open_cards() -> void:
	_autopilot.auto_resolve_ui = false
	var cards: MutationCardScreen = _game.get_mutation_card_screen()
	while cards.is_open():
		await get_tree().process_frame
	RunState.add_xp(RunState.xp_to_next)
	await _wait_until(func() -> bool: return cards.is_open())
	await _wait(0.4)

func _open_shop() -> void:
	_autopilot.auto_resolve_ui = false
	var shop: ShopScreen = _game.get_shop_screen()
	EventBus.feed_collected.emit(SHOP_DEMO_FEED)
	if not shop.is_open():
		EventBus.wave_ended.emit(RunState.wave_index)
	await _wait_until(func() -> bool: return shop.is_open())
	await _wait(0.4)

func _capture() -> void:
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
	print("SCREENSHOT OK: %s (%dx%d) mode=%s" % [absolute, image.get_width(), image.get_height(), _mode])
	get_tree().quit(0)

func _wait(seconds: float) -> void:
	var elapsed: float = 0.0
	while elapsed < seconds:
		await get_tree().process_frame
		elapsed += get_process_delta_time()

func _wait_until(predicate: Callable) -> void:
	var elapsed: float = 0.0
	while elapsed < UI_WAIT_LIMIT and not bool(predicate.call()):
		await get_tree().process_frame
		elapsed += get_process_delta_time()
