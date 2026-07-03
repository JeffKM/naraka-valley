extends SceneTree

# ═══════════════════════════════════════════════════════════════════════════
# 16px 베이스 룩 실험 하네스 (2026-07-04 grill — gemini-regen-batch.md §4.0)
#
# 목적: "16px 논리 해상도 + 무외곽선·소프트 베이스"가 현행 32-native보다 인게임에서
#       나은지 owner가 스타듀 레퍼런스와 나란히 눈으로 판정(GO/NO-GO)하기 위한 이미지 생성.
#
# ★핵심 유효성(스펙 §4.0-2): 16px 타일을 그냥 넣으면 화면상 절반 크기로 보여 "거짓 NO-GO"가
#   난다. 그래서 이 하네스는 논리 16px로 그린 뒤 SCALE=4 nearest 업스케일 → 온스크린 타일 64px로,
#   owner의 스타듀 스크린샷(≈64px/타일)과 물리 크기를 맞춘다.
#
# main.tscn에 의존하지 않는 독립 씬 — 룩(해상도·소프트·경계 유기성)만 격리해서 본다.
# 클럼프/tuft 스캐터는 기본 OFF(베이스 룩만 격리; Q5 = 클럼프는 별도 스캐터 프롭).
#
# 입력 계약: res://assets/_staging_tile16/  (없으면 절차 placeholder로 실행 — 파이프라인 선검증)
#   grass_a.png / grass_b.png / grass_c.png  (16×16 잔디 base 변종; c는 선택)
#   dirt.png                                  (16×16 흙길 base)
#   owner가 Gemini로 §4.0 STYLE 접두(무외곽선·소프트·16px)로 뽑아 이 파일명으로 저장.
#
# 사용:  ./run_tile16.sh   또는
#        godot --headless --path game --script res://tools/tile16_experiment.gd
# 산출:  tools/tile16_experiment.png     (SCALE배 — owner 판정용)
#        tools/tile16_experiment_x1.png  (논리 1:1 — 픽셀 검수용)
# ═══════════════════════════════════════════════════════════════════════════

const TILE := 16          # 논리 타일(px). 실험 대상 해상도.
const SCALE := 4          # nearest 업스케일 → 온스크린 TILE*SCALE = 64px(스타듀 정합).
const W := 24             # 테스트 구역 가로(타일)
const H := 14             # 테스트 구역 세로(타일)
const SCATTER := false    # 베이스 룩 격리 위해 tuft 스캐터 OFF(§4.0)

# ragged fringe(경계 유기화) — main.gd::_build_path_grass_fringe의 16px 포팅.
const _FR_MAX := 3        # 경계 넘나듦 최대 깊이(px, TILE16의 ~19% = 32px판 6px의 절반)
const _FR_DEAD := 0.12    # |signed| 이하 = 평평(경계선 그대로) — 균일 물결 방지

const IN_DIR := "res://assets/_staging_tile16/"
const GROUND := 0
const PATH := 1

var _grass: Array[Image] = []   # 잔디 변종 16×16
var _dirt: Image                # 흙길 16×16
var _grid: Array = []           # [y][x] = GROUND|PATH

func _init() -> void:
	_load_inputs()
	_build_grid()
	var bw := W * TILE
	var bh := H * TILE
	var out := Image.create(bw, bh, false, Image.FORMAT_RGBA8)
	# 1) 베이스 페인트 — 잔디 변종(per-cell 결정적 해시, main.gd salt 5 재현) / 흙길.
	for y in H:
		for x in W:
			var img: Image
			if _grid[y][x] == PATH:
				img = _dirt
			else:
				img = _grass[int(_h01(x, y, 5) * _grass.size()) % _grass.size()]
			out.blit_rect(img, Rect2i(0, 0, TILE, TILE), Vector2i(x * TILE, y * TILE))
	# 2) ragged fringe — 길↔풀 경계를 부호 있는 노이즈로 들쭉날쭉(스타듀식 들고남).
	_apply_fringe(out)
	# 3) SCALE배 nearest 업스케일 → owner 판정 이미지.
	out.save_png("res://tools/tile16_experiment_x1.png")
	var big := Image.create(bw, bh, false, Image.FORMAT_RGBA8)
	big.copy_from(out)
	big.resize(bw * SCALE, bh * SCALE, Image.INTERPOLATE_NEAREST)
	big.save_png("res://tools/tile16_experiment.png")
	print("✅ tile16_experiment.png  (논리 %d×%d → 온스크린 %d×%d, 타일 %dpx)" % [
		bw, bh, bw * SCALE, bh * SCALE, TILE * SCALE])
	print("   입력: ", _input_report)
	print("   SCATTER=", SCATTER, "  변종=", _grass.size(), "종")
	quit()

# ── 입력 로드 (없으면 절차 placeholder) ────────────────────────────────────
var _input_report := ""
func _load_inputs() -> void:
	var got := []
	var miss := []
	for nm in ["grass_a", "grass_b", "grass_c"]:
		var img := _try_load(IN_DIR + nm + ".png")
		if img != null:
			_grass.append(img); got.append(nm)
		elif nm != "grass_c":   # a,b 필수 / c 선택
			_grass.append(_placeholder_grass(_grass.size())); miss.append(nm)
	if _grass.is_empty():
		_grass.append(_placeholder_grass(0))
	_dirt = _try_load(IN_DIR + "dirt.png")
	if _dirt == null:
		_dirt = _placeholder_dirt(); miss.append("dirt")
	_input_report = "실물[%s] placeholder[%s]" % [", ".join(got), ", ".join(miss)]

func _try_load(path: String) -> Image:
	if not FileAccess.file_exists(path):
		return null
	var tex := load(path)
	if tex == null:
		return null
	var img: Image = tex.get_image()
	if img.get_format() != Image.FORMAT_RGBA8:
		img.convert(Image.FORMAT_RGBA8)
	if img.get_width() != TILE or img.get_height() != TILE:
		img.resize(TILE, TILE, Image.INTERPOLATE_NEAREST)
	return img

# placeholder = 무외곽선·저대비 warm-moss(§4.0 룩 근사) — 실물 도착 전 파이프라인·스케일 검증용.
func _placeholder_grass(variant: int) -> Image:
	var img := Image.create(TILE, TILE, false, Image.FORMAT_RGBA8)
	var base := Color(0.29, 0.42, 0.24).lerp(Color(0.33, 0.47, 0.27), variant * 0.5)  # warm-moss 변종
	for y in TILE:
		for x in TILE:
			var n := _h01(x + variant * 7, y, 31) - 0.5     # 저대비 값 노이즈 ±
			var c := Color(base.r + n * 0.05, base.g + n * 0.06, base.b + n * 0.04, 1.0)
			img.set_pixel(x, y, c)
	# 작고 부드러운 tuft 2~3점(2×2 어두운 dab, 외곽선 없이)
	for k in 3:
		var tx := int(_h01(k, variant, 41) * (TILE - 2))
		var ty := int(_h01(k, variant, 43) * (TILE - 2))
		for dy in 2:
			for dx in 2:
				var p := img.get_pixel(tx + dx, ty + dy)
				img.set_pixel(tx + dx, ty + dy, Color(p.r * 0.82, p.g * 0.86, p.b * 0.80, 1.0))
	return img

func _placeholder_dirt() -> Image:
	var img := Image.create(TILE, TILE, false, Image.FORMAT_RGBA8)
	var base := Color(0.52, 0.40, 0.29)   # warm tan
	for y in TILE:
		for x in TILE:
			var n := _h01(x, y, 51) - 0.5
			img.set_pixel(x, y, Color(base.r + n * 0.06, base.g + n * 0.05, base.b + n * 0.04, 1.0))
	return img

# ── 테스트 구역: 잔디 밭 + 굽은 흙길(스타듀 레퍼런스 프레이밍 근사) ────────────
func _build_grid() -> void:
	_grid = []
	for y in H:
		var row := []
		for x in W:
			row.append(GROUND)
		_grid.append(row)
	# 세로로 굽이치는 흙길(사인 + 해시 지터, 폭 2~3) — owner 스크린샷의 구불길 재현.
	for y in H:
		var t := float(y) / float(H)
		var center := W * (0.30 + 0.22 * sin(t * PI * 2.4) + (_h01(0, y, 71) - 0.5) * 0.10)
		var half := 1.0 + _h01(0, y, 73)      # 폭 2~3
		for x in W:
			if absf(x - center) <= half:
				_grid[y][x] = PATH
	# 가로 분기 한 줄(교차부 유기성 확인)
	var by := int(H * 0.62)
	var bx_end := int(W * 0.82)
	for x in range(int(W * 0.30), bx_end):
		_grid[by][x] = PATH
		if _h01(x, by, 77) < 0.4 and by + 1 < H:
			_grid[by + 1][x] = PATH

# ── ragged fringe (main.gd 포팅, 16px) ──────────────────────────────────────
func _apply_fringe(out: Image) -> void:
	var bw := W * TILE
	var bh := H * TILE
	var neigh: Array[Vector2i] = [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]
	for y in H:
		for x in W:
			if _grid[y][x] != PATH:
				continue
			var pox := x * TILE
			var poy := y * TILE
			for dir in 4:
				var nx := x + neigh[dir].x
				var ny := y + neigh[dir].y
				if nx < 0 or ny < 0 or nx >= W or ny >= H:
					continue
				if _grid[ny][nx] != GROUND:
					continue
				var gimg: Image = _grass[int(_h01(nx, ny, 5) * _grass.size()) % _grass.size()]
				var horiz := dir <= 1
				var perp := poy
				if dir == 1: perp = poy + TILE
				elif dir == 2: perp = pox
				elif dir == 3: perp = pox + TILE
				for i in TILE:
					var along := (pox + i) if horiz else (poy + i)
					var signed := _h01(int(along / 2), perp, 610 + dir) - 0.5
					if absf(signed) <= _FR_DEAD:
						continue
					var micro := _h01(along, perp, 620 + dir)
					var mag := (absf(signed) - _FR_DEAD) / (0.5 - _FR_DEAD)
					var depth := clampi(1 + int(mag * (_FR_MAX - 1) + micro), 1, _FR_MAX)
					var grass_out := signed > 0.0     # +: 풀 볼록(길로) / −: 흙 오목(풀 깎임)
					for j in depth:
						var dx := 0; var dy := 0; var sx := 0; var sy := 0
						if grass_out:
							match dir:
								0: dx = i; dy = j; sx = i; sy = TILE - 1 - j
								1: dx = i; dy = TILE - 1 - j; sx = i; sy = j
								2: dx = j; dy = i; sx = TILE - 1 - j; sy = i
								3: dx = TILE - 1 - j; dy = i; sx = j; sy = i
							var gp := gimg.get_pixel(sx, sy)
							if j == depth - 1:
								gp = Color(gp.r * 0.80, gp.g * 0.80, gp.b * 0.84, gp.a)
							out.set_pixel(pox + dx, poy + dy, gp)
						else:
							match dir:
								0: dx = i; dy = -1 - j; sx = i; sy = j
								1: dx = i; dy = TILE + j; sx = i; sy = TILE - 1 - j
								2: dx = -1 - j; dy = i; sx = j; sy = i
								3: dx = TILE + j; dy = i; sx = TILE - 1 - j; sy = i
							var tx := pox + dx
							var ty := poy + dy
							if tx < 0 or ty < 0 or tx >= bw or ty >= bh:
								continue
							out.set_pixel(tx, ty, _dirt.get_pixel(sx, sy))

# main.gd::_gd_h01 동일 — 결정적 해시(프레임·재실행 고정).
func _h01(x: int, y: int, salt: int) -> float:
	var n: int = (x * 73856093) ^ (y * 19349663) ^ (salt * 83492791)
	n = n & 0x7fffffff
	return float(n % 100000) / 100000.0
