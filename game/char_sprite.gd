class_name CharSprite
extends RefCounted
# P2.3② 캐릭터 스프라이트 빌더 — P2.1 도색 시트(game/assets/characters/)를 그레이박스
# 대신 보여 줄 AnimatedSprite2D로 만든다. cast_preview의 시트 규약 그대로:
#   프레임 48×48 / 행 = 방향(down·up·right·left = 남·북·동·서) / 워크=행당 N프레임·대기=1프레임.
# 캐릭터 콘텐츠는 48×48 안에서 이미 ~16×35px(주변은 패딩)이라 *네이티브 스케일*로 보여 주면
# 16×32 규격(ADR-0003)에 맞는다 — 다운스케일 불요. 발치(콘텐츠 y≈40)를 노드 원점에 맞춘다
# (그레이박스가 발치 원점이던 것과 동일 → main의 타일 배치·충돌 손 안 댐).

const FRAME := Vector2i(48, 48)
const DIRS := ["down", "up", "right", "left"]   # 행 순서(시트 규약)
const FPS := 8.0
const FOOT_OFFSET_Y := -16   # 프레임 중심(24)에서 발치(≈40)를 노드 원점으로 끌어올림

# 시트 경로로 AnimatedSprite2D를 만든다(없으면 null → 호출부가 그레이박스 폴백 유지).
static func make(sheet_path: String) -> AnimatedSprite2D:
	if not ResourceLoader.exists(sheet_path):
		return null
	var sheet := load(sheet_path) as Texture2D
	if sheet == null:
		return null
	var sf := SpriteFrames.new()
	if sf.has_animation("default"):
		sf.remove_animation("default")
	var cols := int(sheet.get_width() / FRAME.x)   # 워크=N · 대기=1
	for row in DIRS.size():
		var anim: String = "walk_" + DIRS[row]
		sf.add_animation(anim)
		sf.set_animation_speed(anim, FPS)
		sf.set_animation_loop(anim, true)
		for col in cols:
			var at := AtlasTexture.new()
			at.atlas = sheet
			at.region = Rect2(col * FRAME.x, row * FRAME.y, FRAME.x, FRAME.y)
			sf.add_frame(anim, at)
	var spr := AnimatedSprite2D.new()
	spr.sprite_frames = sf
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST   # 도트 크리스프(ADR-0003)
	spr.offset = Vector2(0, FOOT_OFFSET_Y)
	spr.animation = "walk_down"
	spr.frame = 0
	return spr

# 바라보는 벡터 → 방향 애니 이름(가로 우선: 대각선은 좌우로 읽는다).
static func dir_anim(facing: Vector2) -> String:
	if absf(facing.x) > absf(facing.y):
		return "walk_right" if facing.x > 0.0 else "walk_left"
	return "walk_down" if facing.y >= 0.0 else "walk_up"
