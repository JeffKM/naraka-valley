class_name CharSprite
extends RefCounted
# P2.3② 캐릭터 스프라이트 빌더 — P2.1 도색 시트(game/assets/characters/)를 그레이박스
# 대신 보여 줄 AnimatedSprite2D로 만든다. cast_preview의 시트 규약 그대로:
#   프레임 48×48 / 행 = 방향(down·up·right·left = 남·북·동·서) / 워크=행당 N프레임·대기=1프레임.
# 캐릭터 콘텐츠는 48×48 안에서 이미 ~16×35px(주변은 패딩)이라 *네이티브 스케일*로 보여 주면
# 16×32 규격(ADR-0003)에 맞는다 — 다운스케일 불요. 발치(콘텐츠 y≈40)를 노드 원점에 맞춘다
# (그레이박스가 발치 원점이던 것과 동일 → main의 타일 배치·충돌 손 안 댐).

const FRAME := Vector2i(80, 80)   # standard size56 통일본 native(콘텐츠 최대 ~70px) — 얼굴 선명·체형 통일
const DIRS := ["down", "up", "right", "left"]   # 행 순서(시트 규약)
const FPS := 8.0
const TOOL_FPS := 12.0   # 도구 스윙은 워크보다 스냅하게(6프레임 → 기본 0.5s 1회)
const FOOT_OFFSET_Y := -36   # 프레임 중심(40)에서 발치(≈76)를 노드 원점으로 끌어올림

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

# ★ [S1R-T10] 도구 스윙 4모션 시트를 기존 스프라이트의 SpriteFrames에 얹는다(walk와 같은 시트 규약:
#   480×320 = 6열×4행, 프레임 80×80, 행=방향). motion = 애니 접두사(예: "hoe" → "hoe_down" …).
#   스윙은 1회 재생이라 루프를 끈다(끝나면 animation_finished가 뜬다 → 호출부가 워크/대기로 복귀).
#   반환: 얹기 성공(true) / 시트 없음·로드 실패(false — 호출부는 색박스 폴백을 그대로 유지).
static func add_tool_motion(spr: AnimatedSprite2D, motion: String, sheet_path: String) -> bool:
	if spr == null or spr.sprite_frames == null:
		return false
	if not ResourceLoader.exists(sheet_path):
		return false
	var sheet := load(sheet_path) as Texture2D
	if sheet == null:
		return false
	var sf := spr.sprite_frames
	var cols := int(sheet.get_width() / FRAME.x)   # 모션 프레임 수(대기 열 없음)
	for row in DIRS.size():
		var anim: String = motion + "_" + DIRS[row]
		if sf.has_animation(anim):
			sf.remove_animation(anim)
		sf.add_animation(anim)
		sf.set_animation_speed(anim, TOOL_FPS)
		sf.set_animation_loop(anim, false)   # 스윙 = 1회 재생(끝에서 멈추고 신호)
		for col in cols:
			var at := AtlasTexture.new()
			at.atlas = sheet
			at.region = Rect2(col * FRAME.x, row * FRAME.y, FRAME.x, FRAME.y)
			sf.add_frame(anim, at)
	return true

# 도구 스윙 방향 애니 이름 — dir_anim의 방향부(walk_ 뒤)를 떼어 motion 접두사로 갈아끼운다.
static func tool_anim(motion: String, facing: Vector2) -> String:
	var dir := dir_anim(facing).substr(5)   # "walk_" 5글자 제거 → "down"/"up"/"right"/"left"
	return motion + "_" + dir
