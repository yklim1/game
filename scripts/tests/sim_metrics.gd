class_name SimMetrics
extends RefCounted
## 시뮬레이션 중 프레임 시간·개체 수를 모아 리포트로 만든다. 테스트 전용.

const BUCKET_SIZE: int = 25

var frame_count: int = 0
var total_frame_usec: int = 0
var max_frame_usec: int = 0
var max_alive: int = 0
var max_nodes: int = 0
var samples: Array[Dictionary] = []

var _bucket_usec: Dictionary = {}
var _bucket_frames: Dictionary = {}

func record_frame(frame_usec: int, alive: int) -> void:
	frame_count += 1
	total_frame_usec += frame_usec
	max_frame_usec = maxi(max_frame_usec, frame_usec)
	max_alive = maxi(max_alive, alive)
	var bucket: int = alive / BUCKET_SIZE
	_bucket_usec[bucket] = int(_bucket_usec.get(bucket, 0)) + frame_usec
	_bucket_frames[bucket] = int(_bucket_frames.get(bucket, 0)) + 1

func record_sample(sample: Dictionary) -> void:
	samples.append(sample)
	max_nodes = maxi(max_nodes, int(sample.get("nodes", 0)))

func avg_frame_ms() -> float:
	if frame_count == 0:
		return 0.0
	return float(total_frame_usec) / float(frame_count) / 1000.0

func max_frame_ms() -> float:
	return float(max_frame_usec) / 1000.0

## 동시 적 수 구간별 평균 프레임 시간(ms). 적이 늘 때 비용이 어떻게 변하는지 보기 위한 것.
func bucket_lines() -> Array[String]:
	var lines: Array[String] = []
	var keys: Array = _bucket_frames.keys()
	keys.sort()
	for key in keys:
		var frames: int = int(_bucket_frames[key])
		var usec: int = int(_bucket_usec[key])
		var lo: int = int(key) * BUCKET_SIZE
		var hi: int = lo + BUCKET_SIZE - 1
		lines.append("적 %3d-%3d마리 | 프레임 %6d | 평균 %6.2f ms" % [lo, hi, frames, float(usec) / float(frames) / 1000.0])
	return lines

func sample_lines() -> Array[String]:
	var lines: Array[String] = []
	for sample in samples:
		lines.append("t=%6.1fs | 적 %4d | 노드 %5d | 젬 %4d | 동물풀 %4d | 프레임평균 %6.2f ms" % [
			float(sample.get("time", 0.0)),
			int(sample.get("alive", 0)),
			int(sample.get("nodes", 0)),
			int(sample.get("pickups", 0)),
			int(sample.get("animal_pool", 0)),
			float(sample.get("frame_ms", 0.0)),
		])
	return lines
