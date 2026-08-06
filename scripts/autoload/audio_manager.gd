extends Node
## 효과음 재생 단일 창구. AudioStreamPlayer 를 고정 개수만 만들어 돌려 쓰므로(폴리포니 제한)
## 초당 수십 발을 쏴도 오디오 노드가 늘어나지 않는다.
## 게임플레이 노드를 직접 참조하지 않고 EventBus 시그널만 구독한다.
##
## 효과음 파일은 scripts/tools/generate_sfx.gd 로 직접 합성한 플레이스홀더다(외부 파일 미사용).

const SFX_DIR: String = "res://assets/audio"
const SFX_BUS: String = "SFX"

## 동시에 울릴 수 있는 효과음 수. 넘치면 가장 오래된 목소리를 재사용한다.
@export var max_voices: int = 16
@export var sfx_volume_db: float = -6.0
@export var muted: bool = false
## 실제 오디오 출력을 시도할지. 헤드리스(더미 오디오 드라이버)에서는 자동으로 꺼진다.
## 꺼져 있어도 재생 요청 카운트는 그대로 쌓여 자동 테스트로 트리거를 검증할 수 있다.
@export var playback_enabled: bool = true
## 같은 효과음이 이 간격(초) 안에 다시 요청되면 무시한다(연사·대량 사망 시 소리 뭉침 방지).
@export var throttle_seconds: float = 0.045
## 발사음은 더 자주 나므로 별도 간격을 준다.
@export var shoot_throttle_seconds: float = 0.07

## 이벤트 → 효과음 id. 파일명은 "sfx_<id>.wav".
const SFX_IDS: PackedStringArray = [
	"shoot", "hit", "kill", "player_hurt", "pickup", "level_up", "buy", "game_over",
]

var _streams: Dictionary = {}
var _voices: Array[AudioStreamPlayer] = []
var _next_voice: int = 0
var _last_played_at: Dictionary = {}
var _play_counts: Dictionary = {}
var _elapsed: float = 0.0

func _ready() -> void:
	# 카드·상점으로 트리가 멈춰도 구매·레벨업 효과음은 들려야 한다.
	process_mode = Node.PROCESS_MODE_ALWAYS
	# --headless 는 오디오도 더미 드라이버로 돌아가 재생이 끝나지 않는다(종료 시 플레이백 누수).
	# 자동 테스트는 재생 카운트로 검증하므로 출력만 생략한다.
	if DisplayServer.get_name() == "headless":
		playback_enabled = false
	_load_streams()
	_build_voices()
	EventBus.attack_fired.connect(_on_attack_fired)
	EventBus.animal_hit.connect(_on_animal_hit)
	EventBus.animal_died.connect(_on_animal_died)
	EventBus.player_hit.connect(_on_player_hit)
	EventBus.player_leveled_up.connect(_on_player_leveled_up)
	EventBus.essence_collected.connect(_on_pickup_collected)
	EventBus.feed_collected.connect(_on_pickup_collected)
	EventBus.shop_purchased.connect(_on_shop_purchased)
	EventBus.player_died.connect(_on_player_died)

func _process(delta: float) -> void:
	_elapsed += delta

## 종료 시 목소리가 스트림을 붙들고 있으면 "resource still in use" 경고가 남는다.
func _exit_tree() -> void:
	for voice in _voices:
		voice.stop()
		voice.stream = null
	_streams.clear()

# ---------------------------------------------------------------- 공개 API

## 효과음 재생. 등록되지 않은 id 나 스로틀에 걸린 요청은 조용히 무시한다.
func play(sfx_id: String, throttle: float = -1.0) -> bool:
	if muted or not _streams.has(sfx_id):
		return false
	var window: float = throttle_seconds if throttle < 0.0 else throttle
	var last: float = float(_last_played_at.get(sfx_id, -1000.0))
	if _elapsed - last < window:
		return false
	_last_played_at[sfx_id] = _elapsed
	_play_counts[sfx_id] = int(_play_counts.get(sfx_id, 0)) + 1
	if not playback_enabled:
		return true
	var voice: AudioStreamPlayer = _take_voice()
	if voice == null:
		return false
	voice.stream = _streams[sfx_id]
	voice.volume_db = sfx_volume_db
	voice.play()
	return true

func get_voice_count() -> int:
	return _voices.size()

func get_stream_count() -> int:
	return _streams.size()

func has_stream(sfx_id: String) -> bool:
	return _streams.has(sfx_id)

## 해당 효과음이 실제로 재생된 횟수(테스트·디버그용).
func get_play_count(sfx_id: String) -> int:
	return int(_play_counts.get(sfx_id, 0))

func get_total_play_count() -> int:
	var total: int = 0
	for value in _play_counts.values():
		total += int(value)
	return total

func reset_play_counts() -> void:
	_play_counts.clear()
	_last_played_at.clear()

func get_playing_voice_count() -> int:
	var count: int = 0
	for voice in _voices:
		if voice.playing:
			count += 1
	return count

## 재생 중인 모든 효과음을 끊는다(씬 전환·종료 정리용).
func stop_all() -> void:
	for voice in _voices:
		if voice.playing:
			voice.stop()
		voice.stream = null

func set_sfx_volume_db(value: float) -> void:
	sfx_volume_db = value
	for voice in _voices:
		voice.volume_db = value

# ---------------------------------------------------------------- 내부

func _load_streams() -> void:
	for sfx_id in SFX_IDS:
		var path: String = SFX_DIR.path_join("sfx_%s.wav" % sfx_id)
		if not ResourceLoader.exists(path):
			push_warning("AudioManager: 효과음 파일이 없습니다 %s" % path)
			continue
		var stream: AudioStream = ResourceLoader.load(path) as AudioStream
		if stream == null:
			push_warning("AudioManager: 효과음 로드 실패 %s" % path)
			continue
		_streams[sfx_id] = stream

func _build_voices() -> void:
	var bus: String = SFX_BUS if AudioServer.get_bus_index(SFX_BUS) >= 0 else "Master"
	for i in maxi(max_voices, 1):
		var voice: AudioStreamPlayer = AudioStreamPlayer.new()
		voice.name = "Voice%02d" % i
		voice.bus = bus
		voice.volume_db = sfx_volume_db
		add_child(voice)
		_voices.append(voice)

## 비어 있는 목소리를 먼저 쓰고, 전부 사용 중이면 라운드로빈으로 가장 오래된 것을 뺏는다.
func _take_voice() -> AudioStreamPlayer:
	if _voices.is_empty():
		return null
	for i in _voices.size():
		var index: int = (_next_voice + i) % _voices.size()
		if not _voices[index].playing:
			_next_voice = (index + 1) % _voices.size()
			return _voices[index]
	var stolen: AudioStreamPlayer = _voices[_next_voice]
	_next_voice = (_next_voice + 1) % _voices.size()
	return stolen

# ---------------------------------------------------------------- 이벤트 구독

func _on_attack_fired(_ability: AbilityData) -> void:
	play("shoot", shoot_throttle_seconds)

func _on_animal_hit(_position: Vector2, _damage: float) -> void:
	play("hit")

func _on_animal_died(_position: Vector2, _data: AnimalData, _essence_value: int) -> void:
	play("kill")

func _on_player_hit(_damage: float) -> void:
	play("player_hurt", 0.0)

func _on_player_leveled_up(_level: int) -> void:
	play("level_up", 0.0)

func _on_pickup_collected(_value: int) -> void:
	play("pickup", 0.08)

func _on_shop_purchased(_data: MutationData, _cost: int) -> void:
	play("buy", 0.0)

func _on_player_died() -> void:
	play("game_over", 0.0)
