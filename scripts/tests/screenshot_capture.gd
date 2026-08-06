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
## --mode=juice    : 타격감(히트 플래시·넉백·사망 이펙트·데미지 숫자·화면 흔들림)이 동시에 보이는 순간

const GAME_SCENE_PATH: String = "res://scenes/main/game.tscn"
const UI_WAIT_LIMIT: float = 3.0
## 상점 화면에 구매 가능한 상품이 보이도록 넣어 주는 먹이.
const SHOP_DEMO_FEED: int = 70
## 타격감 캡처에서 플레이어 주변에 세우는 표적 수.
const JUICE_TARGET_COUNT: int = 14

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
		"juice":
			await _stage_juice()
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

## 히트 플래시(0.09s)·사망 조각(0.34s)·데미지 숫자(0.45s)·화면 흔들림이 한 프레임에 겹치도록
## 표적을 세우고 절반은 살려 두고 절반은 즉사시킨 직후를 캡처한다.
func _stage_juice() -> void:
	_autopilot.control_movement = false
	var player: Player = _game.get_player()
	var pool: ObjectPool = _game.get_animal_pool()
	var data: AnimalData = ContentDB.get_animal("spore_ant")
	var targets: Array[Animal] = []
	for i in JUICE_TARGET_COUNT:
		var animal: Animal = pool.acquire() as Animal
		if animal == null:
			break
		var angle: float = TAU * float(i) / float(JUICE_TARGET_COUNT)
		var radius: float = 96.0 + 22.0 * float(i % 3)
		# 접촉 피해 0·이동속도 0으로 세워 두면 원하는 순간을 그대로 담을 수 있다.
		animal.setup(data, player.global_position + Vector2(cos(angle), sin(angle)) * radius, player, 1.0, 0.0, 0.0, false)
		targets.append(animal)
	await _wait(0.05)
	# 실제 플레이에서 나오는 크기의 피해(가시 12 / 발톱 24 등)로 절반은 즉사, 절반은 생존시킨다.
	for i in targets.size():
		var direction: Vector2 = (targets[i].global_position - player.global_position).normalized()
		targets[i].take_damage(24.0 if i % 2 == 0 else 9.0, direction)
	await _wait(0.06)
	player.take_damage(6.0)
	await _wait(0.05)
	_log_diagnostics()

## 스크린샷을 눈으로 볼 때 필요한 정보(카메라가 실제로 플레이어를 따라가는지, 소리가 나는지).
func _log_diagnostics() -> void:
	var player: Player = _game.get_player()
	var camera: CameraShake = player.get_camera()
	var screen_pos: Vector2 = get_viewport().get_canvas_transform() * player.global_position
	print("CAMERA: 플레이어 월드 %s → 화면 %s (뷰포트 중앙 %s) | current=%s offset=%s" % [
		str(player.global_position.round()),
		str(screen_pos.round()),
		str(get_viewport().get_visible_rect().size * 0.5),
		str(camera.is_current()),
		str(camera.offset),
	])
	var audio: Node = get_node_or_null("/root/AudioManager")
	if audio == null:
		return
	print("AUDIO: 출력 %s | 목소리 %d개 (재생 중 %d) | 재생 횟수 %d" % [
		"ON" if audio.playback_enabled else "OFF",
		audio.get_voice_count(),
		audio.get_playing_voice_count(),
		audio.get_total_play_count(),
	])

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
	var audio: Node = get_node_or_null("/root/AudioManager")
	if audio != null:
		audio.stop_all()
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
