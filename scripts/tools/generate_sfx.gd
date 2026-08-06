extends SceneTree
## 개발용 도구(런타임 게임 코드 아님): 플레이스홀더 효과음 .wav 를 직접 합성해 assets/audio 에 쓴다.
## 외부 사운드 파일을 내려받지 않고 파형(사인/구형파/삼각파/노이즈)에 엔벨로프를 걸어 PCM 을 만들므로
## 라이선스 문제가 없다(상업 출시 대비).
##
## 실행:
##   godot_console.exe --headless --path <프로젝트> --script res://scripts/tools/generate_sfx.gd
##   생성 후 임포트: godot_console.exe --headless --path <프로젝트> --import

const OUT_DIR: String = "res://assets/audio"
const SAMPLE_RATE: int = 22050
const MASTER_GAIN: float = 0.75
## 클릭음을 막기 위해 모든 소리의 앞뒤에 적용하는 짧은 페이드(초).
const EDGE_FADE: float = 0.004

enum Wave { SINE, SQUARE, TRIANGLE, SAW, NOISE }

func _initialize() -> void:
	var written: int = 0
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR)) != OK:
		print("경고: 출력 폴더를 만들 수 없습니다 (%s)" % OUT_DIR)
	for spec in _specs():
		var samples: PackedFloat32Array = _render(spec)
		var path: String = OUT_DIR.path_join("%s.wav" % String(spec["name"]))
		if _write_wav(path, samples):
			written += 1
			print("생성: %s (%.3fs, %d 샘플)" % [path, float(samples.size()) / float(SAMPLE_RATE), samples.size()])
		else:
			print("실패: %s" % path)
	print("총 %d개 효과음 생성 완료 (%d Hz, 16-bit mono)" % [written, SAMPLE_RATE])
	quit(0)

# ---------------------------------------------------------------- 사운드 정의
# layers: 각 레이어는 { wave, f0, f1, gain, attack, decay, start }
#   f0 → f1 로 주파수를 훑고, attack 후 decay 커브로 감쇠한다. start 는 레이어 시작 오프셋(초).

func _specs() -> Array[Dictionary]:
	return [
		{
			"name": "sfx_shoot",
			"length": 0.10,
			"layers": [
				{"wave": Wave.SQUARE, "f0": 720.0, "f1": 260.0, "gain": 0.32, "attack": 0.002, "decay": 2.6},
				{"wave": Wave.NOISE, "f0": 0.0, "f1": 0.0, "gain": 0.10, "attack": 0.001, "decay": 6.0},
			],
		},
		{
			"name": "sfx_hit",
			"length": 0.09,
			"layers": [
				{"wave": Wave.NOISE, "f0": 0.0, "f1": 0.0, "gain": 0.30, "attack": 0.001, "decay": 7.0},
				{"wave": Wave.TRIANGLE, "f0": 420.0, "f1": 150.0, "gain": 0.30, "attack": 0.002, "decay": 4.0},
			],
		},
		{
			"name": "sfx_kill",
			"length": 0.20,
			"layers": [
				{"wave": Wave.NOISE, "f0": 0.0, "f1": 0.0, "gain": 0.26, "attack": 0.002, "decay": 4.2},
				{"wave": Wave.SAW, "f0": 300.0, "f1": 70.0, "gain": 0.34, "attack": 0.003, "decay": 3.0},
				{"wave": Wave.SINE, "f0": 130.0, "f1": 55.0, "gain": 0.28, "attack": 0.004, "decay": 2.2},
			],
		},
		{
			"name": "sfx_player_hurt",
			"length": 0.26,
			"layers": [
				{"wave": Wave.SQUARE, "f0": 210.0, "f1": 84.0, "gain": 0.30, "attack": 0.004, "decay": 2.4},
				{"wave": Wave.NOISE, "f0": 0.0, "f1": 0.0, "gain": 0.16, "attack": 0.002, "decay": 5.0},
				{"wave": Wave.SINE, "f0": 96.0, "f1": 60.0, "gain": 0.26, "attack": 0.006, "decay": 1.8},
			],
		},
		{
			"name": "sfx_pickup",
			"length": 0.09,
			"layers": [
				{"wave": Wave.SINE, "f0": 880.0, "f1": 1470.0, "gain": 0.30, "attack": 0.002, "decay": 3.4},
				{"wave": Wave.TRIANGLE, "f0": 1760.0, "f1": 2200.0, "gain": 0.10, "attack": 0.002, "decay": 5.0},
			],
		},
		{
			"name": "sfx_level_up",
			"length": 0.42,
			"layers": [
				{"wave": Wave.TRIANGLE, "f0": 523.0, "f1": 523.0, "gain": 0.26, "attack": 0.005, "decay": 5.0, "start": 0.0},
				{"wave": Wave.TRIANGLE, "f0": 659.0, "f1": 659.0, "gain": 0.26, "attack": 0.005, "decay": 5.0, "start": 0.08},
				{"wave": Wave.TRIANGLE, "f0": 784.0, "f1": 784.0, "gain": 0.26, "attack": 0.005, "decay": 4.0, "start": 0.16},
				{"wave": Wave.SINE, "f0": 1046.0, "f1": 1046.0, "gain": 0.22, "attack": 0.006, "decay": 2.6, "start": 0.24},
			],
		},
		{
			"name": "sfx_buy",
			"length": 0.22,
			"layers": [
				{"wave": Wave.SINE, "f0": 700.0, "f1": 700.0, "gain": 0.26, "attack": 0.003, "decay": 6.0, "start": 0.0},
				{"wave": Wave.SINE, "f0": 1050.0, "f1": 1050.0, "gain": 0.24, "attack": 0.003, "decay": 4.0, "start": 0.06},
				{"wave": Wave.TRIANGLE, "f0": 1400.0, "f1": 1400.0, "gain": 0.12, "attack": 0.003, "decay": 5.0, "start": 0.06},
			],
		},
		{
			"name": "sfx_game_over",
			"length": 0.70,
			"layers": [
				{"wave": Wave.SAW, "f0": 320.0, "f1": 80.0, "gain": 0.26, "attack": 0.01, "decay": 1.6},
				{"wave": Wave.SINE, "f0": 160.0, "f1": 45.0, "gain": 0.30, "attack": 0.02, "decay": 1.2},
				{"wave": Wave.NOISE, "f0": 0.0, "f1": 0.0, "gain": 0.07, "attack": 0.02, "decay": 2.0},
			],
		},
	]

# ---------------------------------------------------------------- 합성

func _render(spec: Dictionary) -> PackedFloat32Array:
	var length: float = float(spec["length"])
	var total: int = int(round(length * float(SAMPLE_RATE)))
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(total)
	for layer in spec["layers"]:
		_mix_layer(out, layer, total)
	_apply_edges(out)
	_normalize(out)
	return out

func _mix_layer(out: PackedFloat32Array, layer: Dictionary, total: int) -> void:
	var wave: int = int(layer["wave"])
	var f0: float = float(layer["f0"])
	var f1: float = float(layer["f1"])
	var gain: float = float(layer["gain"])
	var attack: float = maxf(float(layer["attack"]), 0.0005)
	var decay: float = float(layer["decay"])
	var start: int = int(round(float(layer.get("start", 0.0)) * float(SAMPLE_RATE)))
	var span: int = total - start
	if span <= 0:
		return
	var phase: float = 0.0
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash("%s%f%f" % [str(wave), f0, gain])
	for i in span:
		var t: float = float(i) / float(SAMPLE_RATE)
		var progress: float = float(i) / float(span)
		var freq: float = lerpf(f0, f1, progress)
		phase += TAU * freq / float(SAMPLE_RATE)
		var env: float = _envelope(t, attack, decay)
		out[start + i] += _wave_value(wave, phase, rng) * gain * env

func _wave_value(wave: int, phase: float, rng: RandomNumberGenerator) -> float:
	match wave:
		Wave.SQUARE:
			return 1.0 if sin(phase) >= 0.0 else -1.0
		Wave.TRIANGLE:
			return asin(sin(phase)) * 2.0 / PI
		Wave.SAW:
			return fmod(phase, TAU) / PI - 1.0
		Wave.NOISE:
			return rng.randf_range(-1.0, 1.0)
	return sin(phase)

## 짧은 어택 후 지수 감쇠. decay 가 클수록 빨리 사라진다.
func _envelope(t: float, attack: float, decay: float) -> float:
	if t < attack:
		return t / attack
	return exp(-(t - attack) * decay * 3.0)

func _apply_edges(out: PackedFloat32Array) -> void:
	var fade: int = mini(int(round(EDGE_FADE * float(SAMPLE_RATE))), out.size() / 2)
	if fade <= 0:
		return
	for i in fade:
		var factor: float = float(i) / float(fade)
		out[i] *= factor
		out[out.size() - 1 - i] *= factor

func _normalize(out: PackedFloat32Array) -> void:
	var peak: float = 0.0
	for value in out:
		peak = maxf(peak, absf(value))
	if peak <= 0.0001:
		return
	var scale: float = MASTER_GAIN / peak
	for i in out.size():
		out[i] = clampf(out[i] * scale, -1.0, 1.0)

# ---------------------------------------------------------------- WAV 쓰기

func _write_wav(path: String, samples: PackedFloat32Array) -> bool:
	var pcm: PackedByteArray = PackedByteArray()
	pcm.resize(samples.size() * 2)
	for i in samples.size():
		pcm.encode_s16(i * 2, int(round(clampf(samples[i], -1.0, 1.0) * 32767.0)))
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	var data_size: int = pcm.size()
	file.store_buffer("RIFF".to_ascii_buffer())
	file.store_32(36 + data_size)
	file.store_buffer("WAVE".to_ascii_buffer())
	file.store_buffer("fmt ".to_ascii_buffer())
	file.store_32(16)
	file.store_16(1)  # PCM
	file.store_16(1)  # mono
	file.store_32(SAMPLE_RATE)
	file.store_32(SAMPLE_RATE * 2)  # byte rate = rate * channels * 2바이트
	file.store_16(2)  # block align
	file.store_16(16)  # bits per sample
	file.store_buffer("data".to_ascii_buffer())
	file.store_32(data_size)
	file.store_buffer(pcm)
	file.close()
	return true
