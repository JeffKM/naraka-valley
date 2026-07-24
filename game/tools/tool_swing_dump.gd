extends SceneTree
# game/tools/tool_swing_dump.gd
# [S1R-T10] 도구 스윙 육안 확인용 글루(ADR-0001 허용) — 4모션(hoe·water·scythe·harvest) × 4방향
# × 6프레임 전부를 한 장의 그리드 PNG로 CPU 합성한다(헤드리스 안전 — GPU 뷰포트 캡처 없음).
#
# 목적: 오케스트레이터가 PNG를 Read로 직접 판정할 수 있게. 시트 PNG를 그냥 붙여넣는 게 아니라
#   인게임 배선 경로(CharSprite.add_tool_motion → SpriteFrames + CharSprite.tool_anim 방향 선택 +
#   프레임 인덱싱)를 그대로 통과해서 그린다 → 애니 행 선택·프레임 인덱싱이 맞는지 검증이 목적.
#   각 행 왼쪽에 라벨(모션_방향)을 5×7 비트맵 폰트로 표기. 투명 픽셀은 체커 배경 위에 알파 합성.
#
# 출력: res://tools/tool_swing_review.png
# 사용: godot --headless --path game -s res://tools/tool_swing_dump.gd
#   (좀비 방지 워치독은 run_tests.sh 결 — 아래 셸 패턴 참고, 이 스크립트는 끝에서 quit())

const WALK_SHEET := "res://assets/characters/player_walk.png"
const MOTIONS := ["hoe", "water", "scythe", "harvest"]
const DIRS := [Vector2.DOWN, Vector2.UP, Vector2.RIGHT, Vector2.LEFT]
const DIR_NAMES := ["down", "up", "right", "left"]

const FRAME := 80        # 시트 프레임 규격(char_sprite.FRAME과 동일)
const PAD := 8           # 셀 간 여백
const LABEL_W := 180     # 좌측 라벨 열 폭
const FONT_SCALE := 2    # 5×7 폰트 확대 배율
const BG := Color(0.10, 0.10, 0.12)
const CHK_A := Color(0.22, 0.22, 0.25)   # 체커(투명 가시화)
const CHK_B := Color(0.30, 0.30, 0.34)
const LABEL_COLOR := Color(0.95, 0.92, 0.80)

func _initialize() -> void:
	# ── 인게임 배선 경로 그대로: walk 시트로 스프라이트 만들고 4모션을 얹는다(player._ready와 동일) ──
	var spr := CharSprite.make(WALK_SHEET)
	if spr == null:
		push_error("player_walk 시트 로드 실패 — CharSprite.make null")
		print("✗ player_walk 시트 로드 실패")
		quit()
		return
	var loaded: Array = []
	for motion in MOTIONS:
		var path := "res://assets/characters/player_%s.png" % motion
		var ok := CharSprite.add_tool_motion(spr, motion, path)
		loaded.append(ok)
		if not ok:
			print("  ⚠ %s 시트 없음/로드 실패 → 이 모션 행은 빈 칸(폴백)" % motion)
	var sf: SpriteFrames = spr.sprite_frames

	# ── 그리드 규격 산출 ──
	var cols := 6   # 모션당 프레임 수(대기 열 없음 — 규격 6). 실제 프레임 수와 대조 로그.
	var rows := MOTIONS.size() * DIRS.size()   # 4×4 = 16
	var grid_w := LABEL_W + cols * (FRAME + PAD) + PAD
	var grid_h := rows * (FRAME + PAD) + PAD
	var out := Image.create(grid_w, grid_h, false, Image.FORMAT_RGBA8)
	out.fill(BG)

	# ── 모션×방향 행을 순회하며 프레임을 배선 경로로 뽑아 블릿 ──
	var atlas_cache := {}   # 모션 → 시트 Image(RGBA8) 캐시
	var row := 0
	for motion in MOTIONS:
		for di in DIRS.size():
			var facing: Vector2 = DIRS[di]
			var anim := CharSprite.tool_anim(motion, facing)   # ★ 배선 경로: 방향 → 애니 이름
			var cy := PAD + row * (FRAME + PAD)
			# 라벨(모션_방향) — 세로 중앙
			_draw_text(out, "%s_%s" % [motion, DIR_NAMES[di]], PAD, cy + (FRAME - 7 * FONT_SCALE) / 2, LABEL_COLOR)
			var fcount := sf.get_frame_count(anim) if sf.has_animation(anim) else 0
			if row == 0 or di == 0:
				print("  · %s: 프레임 %d개%s" % [anim, fcount, "" if fcount == cols else "  ⚠(6 아님)"])
			for i in range(cols):
				var cx := LABEL_W + i * (FRAME + PAD)
				_fill_checker(out, cx, cy, FRAME, FRAME)
				if i >= fcount:
					continue   # 프레임 부족(폴백·규격 미달) → 체커만
				var cell := _frame_image(sf, anim, i, atlas_cache, motion)
				if cell != null:
					out.blend_rect(cell, Rect2i(0, 0, cell.get_width(), cell.get_height()), Vector2i(cx, cy))
			row += 1

	var out_path := "res://tools/tool_swing_review.png"
	var err := out.save_png(out_path)
	if err != OK:
		print("✗ 저장 실패(err=%d): %s" % [err, out_path])
	else:
		print("✅ tool_swing_review.png 저장 (%d×%d, %d행 × %d프레임)" % [grid_w, grid_h, rows, cols])
	spr.free()   # 트리에 안 붙인 스프라이트 정리(종료 시 RID 누수 경고 억제)
	quit()

# ── 배선 경로로 한 프레임의 Image를 뽑는다(SpriteFrames → AtlasTexture region) ──
func _frame_image(sf: SpriteFrames, anim: String, i: int, cache: Dictionary, motion: String) -> Image:
	var tex := sf.get_frame_texture(anim, i)
	var at := tex as AtlasTexture
	if at == null or at.atlas == null:
		return null
	if not cache.has(motion):
		var full := at.atlas.get_image()
		if full == null:
			return null
		if full.get_format() != Image.FORMAT_RGBA8:
			full.convert(Image.FORMAT_RGBA8)
		cache[motion] = full
	var atlas_img: Image = cache[motion]
	var r := Rect2i(at.region)
	# 경계 clamp(방어).
	r.position.x = clampi(r.position.x, 0, maxi(0, atlas_img.get_width() - 1))
	r.position.y = clampi(r.position.y, 0, maxi(0, atlas_img.get_height() - 1))
	r.size.x = mini(r.size.x, atlas_img.get_width() - r.position.x)
	r.size.y = mini(r.size.y, atlas_img.get_height() - r.position.y)
	return atlas_img.get_region(r)

# ── 셀 배경 체커(투명 픽셀 가시화) ──
func _fill_checker(img: Image, ox: int, oy: int, w: int, h: int) -> void:
	const S := 8
	for y in range(h):
		for x in range(w):
			var c := CHK_A if ((x / S) + (y / S)) % 2 == 0 else CHK_B
			img.set_pixel(ox + x, oy + y, c)

# ── 5×7 비트맵 폰트(대문자 + '_' + 공백) — 필요한 글자만. 라벨은 to_upper()로 그린다 ──
const GLYPHS := {
	"A": [" ### ", "#   #", "#   #", "#####", "#   #", "#   #", "#   #"],
	"C": [" ### ", "#   #", "#    ", "#    ", "#    ", "#   #", " ### "],
	"D": ["#### ", "#   #", "#   #", "#   #", "#   #", "#   #", "#### "],
	"E": ["#####", "#    ", "#    ", "#### ", "#    ", "#    ", "#####"],
	"F": ["#####", "#    ", "#    ", "#### ", "#    ", "#    ", "#    "],
	"G": [" ### ", "#   #", "#    ", "# ###", "#   #", "#   #", " ### "],
	"H": ["#   #", "#   #", "#   #", "#####", "#   #", "#   #", "#   #"],
	"I": ["#####", "  #  ", "  #  ", "  #  ", "  #  ", "  #  ", "#####"],
	"L": ["#    ", "#    ", "#    ", "#    ", "#    ", "#    ", "#####"],
	"N": ["#   #", "##  #", "##  #", "# # #", "#  ##", "#  ##", "#   #"],
	"O": [" ### ", "#   #", "#   #", "#   #", "#   #", "#   #", " ### "],
	"P": ["#### ", "#   #", "#   #", "#### ", "#    ", "#    ", "#    "],
	"R": ["#### ", "#   #", "#   #", "#### ", "# #  ", "#  # ", "#   #"],
	"S": [" ####", "#    ", "#    ", " ### ", "    #", "    #", "#### "],
	"T": ["#####", "  #  ", "  #  ", "  #  ", "  #  ", "  #  ", "  #  "],
	"U": ["#   #", "#   #", "#   #", "#   #", "#   #", "#   #", " ### "],
	"V": ["#   #", "#   #", "#   #", "#   #", " # # ", " # # ", "  #  "],
	"W": ["#   #", "#   #", "#   #", "# # #", "# # #", "## ##", "#   #"],
	"Y": ["#   #", "#   #", " # # ", "  #  ", "  #  ", "  #  ", "  #  "],
	"_": ["     ", "     ", "     ", "     ", "     ", "     ", "#####"],
	" ": ["     ", "     ", "     ", "     ", "     ", "     ", "     "],
}

func _draw_text(img: Image, text: String, x: int, y: int, color: Color) -> void:
	var up := text.to_upper()
	var cursor := x
	for ci in range(up.length()):
		var ch := up[ci]
		var glyph: Array = GLYPHS.get(ch, GLYPHS[" "])
		for gy in range(glyph.size()):
			var line: String = glyph[gy]
			for gx in range(line.length()):
				if line[gx] == "#":
					_fill_block(img, cursor + gx * FONT_SCALE, y + gy * FONT_SCALE, color)
		cursor += (5 + 1) * FONT_SCALE   # 글자폭 5 + 자간 1

func _fill_block(img: Image, px: int, py: int, color: Color) -> void:
	for yy in range(FONT_SCALE):
		for xx in range(FONT_SCALE):
			var tx := px + xx
			var ty := py + yy
			if tx >= 0 and ty >= 0 and tx < img.get_width() and ty < img.get_height():
				img.set_pixel(tx, ty, color)
