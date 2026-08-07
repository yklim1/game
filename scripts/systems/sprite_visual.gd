class_name SpriteVisual
extends RefCounted
## 데이터(.tres)에 지정된 Texture2D 를 Sprite2D 에 적용하는 공용 헬퍼(정적 함수 모음).
##
## 규칙:
##  - 텍스처가 비어 있으면 씬에 붙어 있는 플레이스홀더(res://icon.svg)를 그대로 두고 색으로만 구분한다.
##  - 텍스처가 있으면 원본 해상도와 무관하게 "긴 변 = display_size(px)" 가 되도록 스케일을 맞춘다.
##  - 실제 아트는 기본적으로 색을 곱하지 않는다(원색 유지). 플레이스홀더일 때만 데이터 색으로 물들인다.
## 덕분에 실제 스프라이트는 .tres 필드를 채우는 것만으로 한 종류씩 점진적으로 교체할 수 있다.

## 텍스처의 긴 변 길이(px). null 이면 0.
static func texture_extent(texture: Texture2D) -> float:
	if texture == null:
		return 0.0
	var size: Vector2 = texture.get_size()
	return maxf(size.x, size.y)

## 스프라이트가 지금 화면에서 차지하는 크기(px, 긴 변).
## 씬에 저장된 기본 스케일을 읽어 두면 텍스처를 갈아 끼워도 같은 크기를 유지할 수 있다.
static func measure_display_size(sprite: Sprite2D) -> float:
	if sprite == null:
		return 0.0
	return texture_extent(sprite.texture) * maxf(absf(sprite.scale.x), absf(sprite.scale.y))

## texture 가 있으면 그것을, 없으면 fallback_texture 를 적용하고 긴 변이 display_size(px) 가 되게 맞춘다.
## display_size 가 0 이하면 스케일을 건드리지 않는다.
## 반환값: 실제 아트를 적용했으면 true, 플레이스홀더로 폴백했으면 false.
static func apply(sprite: Sprite2D, texture: Texture2D, fallback_texture: Texture2D, display_size: float) -> bool:
	if sprite == null:
		return false
	var uses_art: bool = texture != null
	var chosen: Texture2D = texture if uses_art else fallback_texture
	if chosen != null and sprite.texture != chosen:
		sprite.texture = chosen
	_fit(sprite, display_size)
	return uses_art

## 스프라이트에 곱할 색. 플레이스홀더는 데이터 색으로 물들이고, 실제 아트는 원색을 유지한다.
## tint_art 가 true 면 실제 아트에도 데이터 색을 곱한다(단색 실루엣 계열 아트용).
static func resolve_tint(uses_art: bool, color: Color, tint_art: bool) -> Color:
	if not uses_art or tint_art:
		return color
	return Color(1.0, 1.0, 1.0, color.a)

static func _fit(sprite: Sprite2D, display_size: float) -> void:
	if display_size <= 0.0:
		return
	var extent: float = texture_extent(sprite.texture)
	if extent <= 0.0:
		return
	sprite.scale = Vector2.ONE * (display_size / extent)
