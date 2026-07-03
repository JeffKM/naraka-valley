extends SceneTree

# ═══════════════════════════════════════════════════════════════════════════
# 16px 베이스 룩 실험 하네스 (2026-07-04 grill — gemini-regen-batch.md §4.0)
#
# 목적: "16px 논리 해상도 + 무외곽선·소프트 베이스"가 현행 32-native보다 나은지 owner가
#       스타듀 레퍼런스와 나란히 눈으로 판정(GO/NO-GO).
#
# ★입력 = Gemini 지형 "필드" 텍스처(2048²)를 tools/gemini_grass_to_field.py가 워터마크 제거 +
#   FIELD px 다운스케일한 것(grill 확정: 필드 128 청키감). 하네스는 이 필드를 월드좌표 모듈로로
#   타일링(단위 16px 셀 반복이 아니라 필드 연속 → 격자 반복 없음) + 굽은 흙길 + 유기적 경계.
#   Q5: 베이스 = grass_a만. b/c 큰 클럼프는 스캐터 프롭 별도(여기 미사용).
#
# ★스케일 유효성(§4.0-2): 논리로 그린 뒤 SCALE=4 nearest 업스케일 → 온스크린 타일 64px로
#   owner 스타듀 스크린샷(≈64px/타일)과 물리 크기를 맞춘다(거짓 NO-GO 방지).
#
# 입력: res://assets/_staging_tile16/{grass_a,dirt}_field.png (128², 글루 산출). 없으면 placeholder.
# 사용: ./run_tile16.sh  또는  godot --headless --path game --script res://tools/tile16_experiment.gd
# 산출: tools/tile16_experiment.png (SCALE배·판정용) / _x1.png (논리 1:1·픽셀검수)
# ═══════════════════════════════════════════════════════════════════════════

const TILE := 16          # 논리 타일(px)
const SCALE := 4          # nearest 업스케일 → 온스크린 64px(스타듀 정합)
const W := 24             # 테스트 구역 가로(타일)
const H := 14             # 세로(타일)
const FIELD := 128        # 필드 텍스처 한 변(px) — 월드 모듈로 타일링 주기(=8타일)
const JIT := 5            # 경계 지터 진폭(px) — 셀 판정 좌표 흔들어 ragged terrain 경계
const IN_DIR := "res://assets/_staging_tile16/"
const GROUND := 0
const PATH := 1

var _grass: Image
var _dirt: Image
var _grid: Array = []
var _report := ""

func _init() -> void:
	_load_fields()
	_build_grid()
	var lw := W * TILE
	var lh := H * TILE
	var out := Image.create(lw, lh, false, Image.FORMAT_RGBA8)
	# 픽셀별: 지터로 셀 판정(유기적 경계) → 필드를 월드좌표로 샘플(격자 반복 없는 연속 지형).
	for ly in lh:
		for lx in lw:
			var jx := lx + int((_h01(lx, ly, 610) - 0.5) * JIT * 2.0)
			var jy := ly + int((_h01(lx, ly, 620) - 0.5) * JIT * 2.0)
			var cx := clampi(jx / TILE, 0, W - 1)
			var cy := clampi(jy / TILE, 0, H - 1)
			var src: Image = _dirt if _grid[cy][cx] == PATH else _grass
			out.set_pixel(lx, ly, src.get_pixel(lx % FIELD, ly % FIELD))
	out.save_png("res://tools/tile16_experiment_x1.png")
	var big := Image.create(lw, lh, false, Image.FORMAT_RGBA8)
	big.copy_from(out)
	big.resize(lw * SCALE, lh * SCALE, Image.INTERPOLATE_NEAREST)
	big.save_png("res://tools/tile16_experiment.png")
	print("✅ tile16_experiment.png  (논리 %d×%d → 온스크린 %d×%d, 타일 %dpx)" % [
		lw, lh, lw * SCALE, lh * SCALE, TILE * SCALE])
	print("   입력: ", _report, "  FIELD=", FIELD)
	quit()

# ── 필드 로드(글루 산출) 또는 placeholder ──────────────────────────────────
func _load_fields() -> void:
	_grass = _try(IN_DIR + "grass_a_field.png")
	_dirt = _try(IN_DIR + "dirt_field.png")
	var g := "grass_a" if _grass != null else ""
	var d := "dirt" if _dirt != null else ""
	if _grass == null: _grass = _placeholder(Color(0.29, 0.42, 0.24), 31)
	if _dirt == null: _dirt = _placeholder(Color(0.52, 0.40, 0.29), 51)
	_report = "실물[%s %s]" % [g, d] if (g != "" or d != "") else "placeholder(전부)"

func _try(path: String) -> Image:
	if not FileAccess.file_exists(path):
		return null
	var tex = load(path)
	if tex == null:
		return null
	var img: Image = tex.get_image()
	if img.get_format() != Image.FORMAT_RGBA8:
		img.convert(Image.FORMAT_RGBA8)
	if img.get_width() != FIELD or img.get_height() != FIELD:
		img.resize(FIELD, FIELD, Image.INTERPOLATE_LANCZOS)
	return img

# placeholder = 무외곽선·저대비 warm 필드(실물 도착 전 파이프라인·스케일 검증용).
func _placeholder(base: Color, salt: int) -> Image:
	var img := Image.create(FIELD, FIELD, false, Image.FORMAT_RGBA8)
	for y in FIELD:
		for x in FIELD:
			var n := _h01(x, y, salt) - 0.5
			img.set_pixel(x, y, Color(base.r + n * 0.06, base.g + n * 0.06, base.b + n * 0.04, 1.0))
	return img

# ── 테스트 구역: 잔디 밭 + 굽은 흙길 ────────────────────────────────────────
func _build_grid() -> void:
	_grid = []
	for y in H:
		var row := []
		for x in W:
			row.append(GROUND)
		_grid.append(row)
	for y in H:
		var t := float(y) / float(H)
		var center := W * (0.30 + 0.22 * sin(t * PI * 2.4) + (_h01(0, y, 71) - 0.5) * 0.10)
		var half := 1.0 + _h01(0, y, 73)
		for x in W:
			if absf(x - center) <= half:
				_grid[y][x] = PATH
	var by := int(H * 0.62)
	for x in range(int(W * 0.30), int(W * 0.82)):
		_grid[by][x] = PATH
		if _h01(x, by, 77) < 0.4 and by + 1 < H:
			_grid[by + 1][x] = PATH

# main.gd::_gd_h01 동일 — 결정적 해시(프레임·재실행 고정).
func _h01(x: int, y: int, salt: int) -> float:
	var n: int = (x * 73856093) ^ (y * 19349663) ^ (salt * 83492791)
	n = n & 0x7fffffff
	return float(n % 100000) / 100000.0
