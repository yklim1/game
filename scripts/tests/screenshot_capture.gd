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
## --mode=sprite   : 적 일부에만 런타임 생성 텍스처를 지정해 "실제 스프라이트 + 폴백" 혼재 상태를 확인
## --mode=flash    : 같은 적을 왼쪽=평상시 / 오른쪽=피격 중 으로 나란히 세워 히트 플래시를 A/B 비교
## --mode=crowd    : 적을 대량으로 몰아넣어 주인공이 군중 속에서 식별되는지(색 영역 분리) 확인
## --sprite-test   : 다른 모드와 조합해 위 텍스처 지정을 함께 적용(예: juice + 텍스처 히트 플래시)
## --animal=<id>   : flash/crowd 모드에서 세울 적 id (기본 spore_ant)

const GAME_SCENE_PATH: String = "res://scenes/main/game.tscn"
## --mode=sprite 에서 텍스처를 지정해 볼 동물 id. 나머지 동물은 플레이스홀더로 남아 혼재 상태를 보여 준다.
const SPRITE_TEST_ANIMAL_IDS: PackedStringArray = ["spore_ant", "rabid_hare"]
const UI_WAIT_LIMIT: float = 3.0
## 상점 화면에 구매 가능한 상품이 보이도록 넣어 주는 먹이.
const SHOP_DEMO_FEED: int = 70
## 타격감 캡처에서 플레이어 주변에 세우는 표적 수.
const JUICE_TARGET_COUNT: int = 14
## flash 모드에서 세우는 A/B 쌍의 수.
const FLASH_PAIR_COUNT: int = 5
## flash 모드 격자 간격(px).
const FLASH_SPACING: float = 68.0
## crowd 모드에서 플레이어 주변에 몰아넣는 적 수.
const CROWD_COUNT: int = 90
## crowd 모드에서 적을 흩뿌리는 반경 범위(px).
const CROWD_MIN_RADIUS: float = 40.0
const CROWD_MAX_RADIUS: float = 330.0

var _delay: float = 6.0
var _mode: String = "gameplay"
var _out_path: String = "docs/screenshots/phase3.png"
var _sprite_test: bool = false
var _animal_id: String = "spore_ant"

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
		elif arg == "--sprite-test":
			_sprite_test = true
		elif arg.begins_with("--animal="):
			_animal_id = arg.split("=")[1]
	_run.call_deferred()

func _run() -> void:
	_game = (load(GAME_SCENE_PATH) as PackedScene).instantiate()
	get_tree().root.add_child(_game)
	_autopilot = TestAutopilot.new()
	_autopilot.set_player(_game.get_player())
	_autopilot.set_ui(_game.get_mutation_card_screen(), _game.get_shop_screen())
	get_tree().root.add_child(_autopilot)

	# 스폰되는 적이 처음부터 텍스처로 그려지도록 대기 전에 적용한다.
	if _sprite_test or _mode == "sprite":
		_apply_test_sprites()
	await _wait(_delay)
	match _mode:
		"cards":
			await _open_cards()
		"shop":
			await _open_shop()
		"juice":
			await _stage_juice()
		"flash":
			await _stage_flash_compare()
		"crowd":
			await _stage_crowd()
	await _capture()

## 실제 아트가 아직 없으므로 런타임에 만든 텍스처를 일부 동물 데이터에만 꽂아 본다.
## 저장소에 파일을 남기지 않으며, 이 프로세스의 메모리 상 리소스만 바뀐다.
func _apply_test_sprites() -> void:
	for animal_id in SPRITE_TEST_ANIMAL_IDS:
		var data: AnimalData = ContentDB.get_animal(animal_id)
		if data == null:
			continue
		data.sprite = _make_blob_texture(96, 64, data.color, Color(0.05, 0.03, 0.08, 1.0))
		data.sprite_size = data.radius * 2.8
		print("SPRITE TEST: '%s' 에 96x64 텍스처 지정 (표시 %.0fpx)" % [animal_id, data.sprite_size])

## 굵은 아웃라인 카툰 스프라이트를 흉내 낸 타원 블롭. 정사각이 아니어서 크기 정규화도 함께 확인된다.
func _make_blob_texture(width: int, height: int, fill: Color, outline: Color) -> Texture2D:
	var image: Image = Image.create_empty(width, height, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.0, 0.0, 0.0, 0.0))
	var cx: float = float(width - 1) * 0.5
	var cy: float = float(height - 1) * 0.5
	for y in height:
		for x in width:
			var nx: float = (float(x) - cx) / cx
			var ny: float = (float(y) - cy) / cy
			var dist: float = nx * nx + ny * ny
			if dist > 1.0:
				continue
			image.set_pixel(x, y, outline if dist > 0.62 else fill)
	return ImageTexture.create_from_image(image)

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

## 히트 플래시를 눈으로/픽셀로 판정하려면 같은 적의 "평상시"와 "피격 중"이 한 화면에 있어야 한다.
## 왼쪽 열은 손대지 않고, 오른쪽 열만 피격시킨 직후를 캡처한다.
func _stage_flash_compare() -> void:
	_autopilot.control_movement = false
	var player: Player = _game.get_player()
	var origin: Vector2 = player.global_position
	var calm: Array[Animal] = []
	var hit: Array[Animal] = []
	for i in FLASH_PAIR_COUNT:
		var y: float = (float(i) - float(FLASH_PAIR_COUNT - 1) * 0.5) * FLASH_SPACING
		var left: Animal = _stand_target(origin + Vector2(-FLASH_SPACING * 1.6, y))
		var right: Animal = _stand_target(origin + Vector2(FLASH_SPACING * 1.6, y))
		if left != null:
			calm.append(left)
		if right != null:
			hit.append(right)
	await _wait(0.2)
	# 플래시(0.09s)가 살아 있는 동안 캡처되도록 피격은 캡처 직전에, 대기 없이 한다.
	for animal in hit:
		animal.take_damage(1.0)
	_log_flash_boxes(calm, hit)

## 군중 가독성 검증: 주인공을 적으로 완전히 둘러싸 "0.1초 안에 찾을 수 있는가"를 눈으로 본다.
func _stage_crowd() -> void:
	_autopilot.control_movement = false
	var origin: Vector2 = _game.get_player().global_position
	var placed: int = 0
	for i in CROWD_COUNT:
		var angle: float = randf() * TAU
		var radius: float = randf_range(CROWD_MIN_RADIUS, CROWD_MAX_RADIUS)
		if _stand_target(origin + Vector2(cos(angle), sin(angle)) * radius) != null:
			placed += 1
	await _wait(0.2)
	print("CROWD: '%s' %d마리 배치 (반경 %.0f~%.0fpx)" % [_animal_id, placed, CROWD_MIN_RADIUS, CROWD_MAX_RADIUS])

## 이동속도 0·접촉피해 0·HP 대량으로 세워 두는 표적. 원하는 순간을 그대로 담을 수 있다.
func _stand_target(position: Vector2) -> Animal:
	var data: AnimalData = ContentDB.get_animal(_animal_id)
	if data == null:
		return null
	var animal: Animal = _game.get_animal_pool().acquire() as Animal
	if animal == null:
		return null
	animal.setup(data, position, _game.get_player(), 400.0, 0.0, 0.0, false)
	return animal

## 캡처된 PNG에서 어디를 재 볼지 알 수 있게 화면 좌표를 남긴다(육안 판정을 픽셀로 뒷받침하려면 필요).
func _log_flash_boxes(calm: Array[Animal], hit: Array[Animal]) -> void:
	var transform: Transform2D = get_viewport().get_canvas_transform()
	for i in mini(calm.size(), hit.size()):
		print("FLASH PAIR %d: 평상시 화면 %s | 피격 중 화면 %s" % [
			i,
			str((transform * calm[i].global_position).round()),
			str((transform * hit[i].global_position).round()),
		])

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
