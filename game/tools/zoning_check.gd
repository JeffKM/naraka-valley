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

	# ═══ [S1R-T4] BFS 통행 단언 — 능선 차단 유지 + forage 숲 도달성/밀집 + P5 일렬 소거 ═══════════
	# 프롭 물리 블록 모델(_rebuild_prop_collision 규칙 거울): foot-bar 프롭=풋프린트 밑행만, 그 외 SOLID=
	#   풀 풋프린트, 개간된 debris·비-solid weeds=통과. 능선 seam(x=HIGHLAND_E↔+1, y≤HIGHLAND_S)=_ridge_body 차단.
	var HE: int = m.HIGHLAND_E
	var HS: int = m.HIGHLAND_S
	var w: int = m._grid_w
	var oh: int = m._outdoor_h
	var blocked: Dictionary = {}
	for entry in m._home_prop_entries():
		var tex = entry[0]
		if not (tex in m.SOLID_PROPS):
			continue
		var sz: Vector2 = tex.get_size()
		var tw: int = maxi(int(round(sz.x / m.TILE)), 1)
		var th: int = maxi(int(round(sz.y / m.TILE)), 1)
		var footbar: bool = tex in m.FOOT_BAR_PROPS
		var is_debris: bool = m.DEBRIS_KIND.has(tex)
		for a in entry[1]:
			if is_debris and m.reclaim != null and m.reclaim.is_cleared(a):
				continue
			if footbar:
				for dx in range(tw):
					blocked[a + Vector2i(dx, th - 1)] = true   # 발치 밑행만
			else:
				for dx in range(tw):
					for dy in range(th):
						blocked[a + Vector2i(dx, dy)] = true
	var walk := func(t: Vector2i) -> bool:
		if t.x < 0 or t.y < 0 or t.x >= w or t.y >= oh:
			return false
		var id: int = m._grid[t.y][t.x]
		if id == m.VOID or id == m.WATER or m.is_solid(id):
			return false
		return not blocked.has(t)
	# BFS(스폰 → 4방향), 능선 seam 차단 포함.
	var spawn: Vector2i = m.SPAWN_TILE
	var seen: Dictionary = {}
	var stack: Array = [spawn]
	seen[spawn] = true
	while not stack.is_empty():
		var t: Vector2i = stack.pop_back()
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = t + d
			if seen.has(n) or not walk.call(n):
				continue
			# 능선 seam(고지 x≤HE ↔ 저지 x≥HE+1, y≤HS)은 못 넘는다(_ridge_body 거울).
			if t.y <= HS and ((t.x == HE and n.x == HE + 1) or (t.x == HE + 1 and n.x == HE)):
				continue
			seen[n] = true
			stack.append(n)
	# ⑧ 능선 차단 유지 — 스폰(저지)에서 고지(x≤HE, y<HS) 도달 0(seam 동편 + 남향 debris 게이트 봉인).
	var hi_reach: int = 0
	for hy in range(0, HS):
		for hx in range(0, HE + 1):
			if seen.has(Vector2i(hx, hy)):
				hi_reach += 1
	print("고지 도달 %d(기대 0) · 능선 seam+게이트 봉인" % hi_reach)
	if hi_reach != 0:
		print("✗ 능선/게이트 차단 뚫림 — 고지 %d칸 도달" % hi_reach); ok = false
	# ⑨ forage 숲 도달성(유기 틈으로 관통) + 밀집(프롭 풋프린트) 동시 성립 — 완전 봉쇄 금지.
	var fr: Rect2i = m.FORAGE_FOREST_RECT
	var f_total := fr.size.x * fr.size.y
	var f_reach := 0
	var f_block := 0
	for fy in range(fr.position.y, fr.end.y):
		for fx in range(fr.position.x, fr.end.x):
			var ft := Vector2i(fx, fy)
			if seen.has(ft):
				f_reach += 1
			if blocked.has(ft):
				f_block += 1
	print("forage 숲 %d칸 · 도달 %d · 프롭블록 %d" % [f_total, f_reach, f_block])
	if f_reach < int(f_total * 0.5):
		print("✗ forage 숲 도달성 부족(유기 틈 봉쇄) %d/%d" % [f_reach, f_total]); ok = false
	if f_block < 40:
		print("✗ forage 숲 밀집 부족(프롭블록 %d < 40)" % f_block); ok = false
	# ⑩ P5 — 옛 x20 완벽 일렬 덤불 소거 확인 + 능선 밴드(x17..20,y1..25) SOLID 프롭선 존재.
	var col_bush := 0
	var ridge_solid := 0
	for entry in m._home_prop_entries():
		var tex = entry[0]
		for a in entry[1]:
			if tex == m.PROP_BUSH and a.x == 20 and a.y >= 1 and a.y <= 25:
				col_bush += 1
			if (tex in m.SOLID_PROPS) and a.x >= 17 and a.x <= 20 and a.y >= 1 and a.y <= 25:
				ridge_solid += 1
	print("능선 x20 덤불열 %d(기대 0) · 능선밴드 SOLID 프롭 %d" % [col_bush, ridge_solid])
	if col_bush != 0:
		print("✗ 옛 일렬 덤불 잔존 %d" % col_bush); ok = false
	if ridge_solid < 4:
		print("✗ 능선 대체 프롭선 부족(%d < 4)" % ridge_solid); ok = false

	print("══ zoning_check: %s ══" % ("PASS" if ok else "FAIL"))
	quit(0 if ok else 1)
