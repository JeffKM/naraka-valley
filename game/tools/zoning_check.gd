extends SceneTree

# ★[ADR-0059 결정1 / S1R-T3] 남단 조닝 그리드 검증 글루(일회용 하네스) — 스파인 재배선·존 rect 정합을
#   그리드 레벨에서 확인한다(덤프 PNG에선 길 톤이 흙과 가까워 육안 판정 보조).
func _init() -> void:
	var m = load("res://main.tscn").instantiate()
	get_root().add_child(m)
	await process_frame
	await process_frame
	var ok := true
	# ① 스파인 북부 x38 y10..44 = PATH
	for y in range(10, 45):
		if m._grid[y][38] != m.PATH:
			print("✗ 스파인 북부 (38,%d) != PATH" % y); ok = false
	# ② 분기 가로 복도 y44 x33..40 = PATH
	for x in range(33, 41):
		if m._grid[44][x] != m.PATH:
			print("✗ 분기 복도 (%d,44) != PATH" % x); ok = false
	# ②' 연못 훅 x33 y41..44 = PATH(복도 → 연못 남안 물가)
	for y in range(41, 45):
		if m._grid[y][33] != m.PATH:
			print("✗ 연못 훅 (33,%d) != PATH" % y); ok = false
	# ③ 스폰 스퍼 x40 y44..60 = PATH
	for y in range(44, 61):
		if m._grid[y][40] != m.PATH:
			print("✗ 스폰 스퍼 (40,%d) != PATH" % y); ok = false
	# ④ 옛 데드런(x38 y46..60) 소거 = 더 이상 PATH 아님
	for y in range(46, 61):
		if m._grid[y][38] == m.PATH:
			print("✗ 옛 데드런 (38,%d) 잔존 PATH" % y); ok = false
	# ⑤ 연못 바이트 불변 — SPIRIT_POND_RECT 상수 불변 + 북단 행=CLIFF_BANK(_autotile_pond_siblings 유도),
	#   나머지 행 전부 WATER(기존 라이브 형태 그대로).
	var pr: Rect2i = m.SPIRIT_POND_RECT
	if pr != Rect2i(26, 34, 8, 7):
		print("✗ SPIRIT_POND_RECT 변조"); ok = false
	for x in range(pr.position.x, pr.end.x):
		if m._grid[pr.position.y][x] != m.CLIFF_BANK:
			print("✗ 연못 북단 (%d,%d) != CLIFF_BANK" % [x, pr.position.y]); ok = false
	for y in range(pr.position.y + 1, pr.end.y):
		for x in range(pr.position.x, pr.end.x):
			if m._grid[y][x] != m.WATER:
				print("✗ 연못 (%d,%d) != WATER" % [x, y]); ok = false
	# ⑥ ENCROACH 확장 후보 — 남동 개간지(OVERGROWN_EXPANSION_RECT) 안 후보 존재·물가 활동존 후보 0
	var cands: Array = m._encroach_candidates()
	var se := 0
	var pond_zone := 0
	for t in cands:
		if m.OVERGROWN_EXPANSION_RECT.has_point(t):
			se += 1
		if m.POND_ACTIVITY_RECT.has_point(t):
			pond_zone += 1
	print("후보 총 %d · 남동 개간지 %d · 물가존 %d" % [cands.size(), se, pond_zone])
	if se <= 0:
		print("✗ 남동 개간지 재점령 후보 0"); ok = false
	if pond_zone != 0:
		print("✗ 물가 활동존에 재점령 후보 잔존"); ok = false
	# ⑦ 존 rect 불변 제약 — 존이 건물·연못·우물과 안 겹침(FORAGE/ORCHARD/OVERGROWN)
	for e in [["FORAGE", m.FORAGE_FOREST_RECT], ["ORCHARD", m.ORCHARD_ZONE_RECT], ["OVERGROWN", m.OVERGROWN_EXPANSION_RECT]]:
		var r: Rect2i = e[1]
		for b in [m.HOUSE_EXT_RECT, m.STOREHOUSE_EXT_RECT, m.NEOKURITGAN_EXT_RECT, m.NEOKDUNGURI_EXT_RECT, m.SILO_EXT_RECT, m.WELL_RECT, m.STARTER_PATCH_RECT, m.SPIRIT_POND_RECT]:
			if r.intersects(b):
				print("✗ 존 %s가 고정 rect와 겹침 %s" % [e[0], b]); ok = false
	print("══ zoning_check: %s ══" % ("PASS" if ok else "FAIL"))
	quit(0 if ok else 1)
