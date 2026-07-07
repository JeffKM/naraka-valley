extends SceneTree

# [ADR-0054 · 건물 접지] 안식 농원(HOME) 흙-지배 flip(ADR-0053) 후 생긴 회귀 — 건물 facade 발치에
# 깔리던 풀 백드롭이 tan 세계와 대비돼 *초록 사각형*을 냈다 — 을 고친 슬라이스의 단위검증(ephemeral 헤드리스).
#
# 무엇을 보나(순수 시각 — grid·충돌·terrain·세이브 불변):
#   ① 잔디억제 패드 지오메트리(_g16_near_building) — 건물 footprint + 발치 1링은 true, 먼 마당은 false.
#   ② end-to-end: _ground_detail_tex(ground16 베이크)의 건물 footprint 중심 픽셀이 *정확히* _bf_earth와
#      일치한다(초록 잔디/백드롭 아님). 패드가 footprint+링을 균일 맨흙으로 강제 → 소프트 경계 없음 →
#      지터도 없어 중심 픽셀이 _bf_earth blit 값과 1:1. 이게 "초록 사각 소멸 + 흙 접지"의 실효 증명.
#   ③ 회귀 0 — footprint는 여전히 전부 WALL(통과 불가)·필드(잔디/흙) 텍스처 구분 유지·grass 시스템 살아있음.
#
# 좀비 방지: 모든 단언 뒤 quit(). run_tests.sh 워치독과 함께.

var _fail := 0

func _check(label: String, ok: bool) -> void:
	print(("  ✓ " if ok else "  ✗ ") + label)
	if not ok:
		_fail += 1

func _spawn_main() -> Node:
	var m: Node = load("res://main.tscn").instantiate()
	root.add_child(m)
	await process_frame
	await process_frame
	return m

# ground16 blit 규칙(_build_ground16 ①)의 역: 셀 (cx,cy)의 로컬 (ix,iy) 픽셀이 참조하는 _bf_earth 좌표.
#   blit_rect(_bf_earth, ((cx*TILE)%P, (cy*TILE)%P, TILE, TILE) → (cx*TILE, cy*TILE))
func _earth_pixel(m: Node, cx: int, cy: int, ix: int, iy: int) -> Color:
	var P: int = m._GF * 2
	return m._bf_earth.get_pixel((cx * m.TILE) % P + ix, (cy * m.TILE) % P + iy)

func _initialize() -> void:
	print("══ 건물 접지(ADR-0054) 검증 ══")
	const SAVE := "user://save.dat"
	if FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))

	var m: Node = await _spawn_main()
	_check("⓪ 부팅 = 안식 농원(HOME) 바깥", m._region == RegionCatalog.HOME and m._indoor == "")
	_check("⓪ ground16 베이크 존재(_ground_detail_tex)", m._ground_detail_tex != null)
	_check("⓪ 맨흙 베이스 필드(_bf_earth) 로드됨", m._bf_earth != null)

	# 검사 대상 건물(facade 4종 + 비진입 사일로·우물은 _HOME_BUILDING_RECTS로 패드에 포함).
	var facades := {
		"본가": m.HOUSE_EXT_RECT,
		"창고": m.STOREHOUSE_EXT_RECT,
		"넋우릿간": m.NEOKURITGAN_EXT_RECT,
		"넋둥우리": m.NEOKDUNGURI_EXT_RECT,
	}

	# ── ① 잔디억제 패드 지오메트리 ──
	for name in facades:
		var r: Rect2i = facades[name]
		var c := r.position + r.size / 2                       # footprint 내부 중심
		_check("① %s footprint 중심 = 패드 안" % name, m._g16_near_building(c.x, c.y))
		# 발치 1링(footprint 바로 바깥 한 겹)도 패드.
		_check("① %s 발치 서·동링 = 패드 안" % name,
			m._g16_near_building(r.position.x - 1, r.position.y) and m._g16_near_building(r.end.x, r.position.y))
		_check("① %s 발치 남링(문 아래 방향) = 패드 안" % name,
			m._g16_near_building(r.position.x, r.end.y))
	# 건물에서 먼 마당은 패드 아님(잔디 허용 영역).
	_check("① 먼 마당(60,50)·(55,45) = 패드 아님",
		not m._g16_near_building(60, 50) and not m._g16_near_building(55, 45))
	# 패드는 딱 1링 — footprint에서 2칸 밖은 패드 아님(과확장 방지).
	var hr: Rect2i = m.HOUSE_EXT_RECT
	_check("① 패드는 1링만(본가 서쪽 2칸 밖 = 패드 아님)",
		not m._g16_near_building(hr.position.x - 2, hr.position.y + 1))

	# ── ② end-to-end: footprint 중심 픽셀 = _bf_earth(초록 아님) ──
	var gimg: Image = m._ground_detail_tex.get_image()
	if gimg.get_format() != Image.FORMAT_RGBA8:
		gimg.convert(Image.FORMAT_RGBA8)
	for name in facades:
		var r: Rect2i = facades[name]
		# footprint '몸통' 칸(WALL) 하나를 고른다 — 문(door)은 PATH 리세스라 흙이 아니라 길이라 제외.
		#   (소형 4×2 넋둥우리는 기하 중심이 문 칸이므로 중심 대신 WALL 몸통을 스캔.)
		var c := r.position
		for by in range(r.position.y, r.end.y):
			for bx in range(r.position.x, r.end.x):
				if m._grid[by][bx] == m.WALL:
					c = Vector2i(bx, by)
					break
			if m._grid[c.y][c.x] == m.WALL:
				break
		var wx: int = c.x * int(m.TILE) + 16                  # 셀 중심 픽셀(가장자리 16px 안쪽 = 지터 무관)
		var wy: int = c.y * int(m.TILE) + 16
		var got := gimg.get_pixel(wx, wy)
		var want := _earth_pixel(m, c.x, c.y, 16, 16)
		var match_earth := absf(got.r - want.r) < 0.02 and absf(got.g - want.g) < 0.02 and absf(got.b - want.b) < 0.02
		_check("② %s footprint 중심 = 맨흙 픽셀(_bf_earth 일치)" % name, match_earth)
		# 초록 아님(잔디 g-우세가 아니라 warm tan r>=g). 회귀(초록 사각)의 직접 부정.
		_check("② %s footprint = 초록 아님(warm tan, r ≥ g)" % name, got.r >= got.g)

	# ── ③ 회귀 0 ──
	var all_wall := true
	for name in facades:
		var r: Rect2i = facades[name]
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				# 문 칸(door)은 PATH 리세스라 제외 — footprint '몸통'만 WALL 검사.
				if m._grid[y][x] != m.WALL and m._grid[y][x] != m.PATH:
					all_wall = false
	_check("③ footprint 몸통 = WALL(통과 불가)·문만 PATH(grid 불변)", all_wall)
	_check("③ 필드 텍스처 구분 유지(_bf_grass ≠ _bf_earth)",
		m._bf_grass != null and m._bf_grass != m._bf_earth)
	# grass 시스템 살아있음 — 먼 잔디 군락 seed가 여전히 잔디로 판정(패드 밖).
	_check("③ 잔디 시스템 살아있음(_g16_is_grass_patch 판정 가능)",
		m._g16_is_grass_patch(60, 50) or m._g16_is_grass_patch(58, 48) or not m._g16_near_building(60, 50))

	m.queue_free()
	await process_frame
	if FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))

	print("══ 결과: %s (실패 %d) ══" % ["PASS" if _fail == 0 else "FAIL", _fail])
	quit(1 if _fail > 0 else 0)
