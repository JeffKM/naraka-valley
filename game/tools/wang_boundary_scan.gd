# game/tools/wang_boundary_scan.gd
# HOME 지면 표면 경계쌍 스캔 — 어떤 Wang 전환 tileset을 생성해야 하는지 확정(조사).
# 실행: godot --headless --path game --script res://tools/wang_boundary_scan.gd

extends SceneTree

const RANK := {1: 4, 0: 3, 2: 2, 3: 1, 4: 0}   # 잔디>흙>길>밭>물

func _initialize() -> void:
	var m: Node = load("res://main.tscn").instantiate()
	root.add_child(m)
	await process_frame
	await process_frame
	# ground16 표면 격자 재현(_build_ground16 ①과 동일 산출 — surf만 필요).
	var W: int = m._grid_w
	var H: int = m._outdoor_h
	var surf: Array = []
	for y in H:
		var row: Array = []
		for x in W:
			row.append(m._g16_surface(x, y))
		surf.append(row)
	m._g16_cluster_cleanup(surf)
	for y in H:
		for x in W:
			if int(surf[y][x]) == 1 and m._g16_near_building(x, y):
				surf[y][x] = 0
	# 셀 4코너 꼭짓점 표면으로 경계쌍·삼중점 집계
	var pair_count := {}   # "lo_up" → 셀수
	var triple := 0
	for y in H:
		for x in W:
			if int(surf[y][x]) < 0:
				continue
			var cs := [_vsurf(surf, x, y, W, H), _vsurf(surf, x + 1, y, W, H),
					_vsurf(surf, x, y + 1, W, H), _vsurf(surf, x + 1, y + 1, W, H)]
			var uniq := {}
			for c in cs:
				if c >= 0:
					uniq[c] = true
			if uniq.size() < 2:
				continue
			if uniq.size() >= 3:
				triple += 1
			var ks: Array = uniq.keys()
			ks.sort_custom(func(a, b): return RANK[a] > RANK[b])
			var key := "%d_%d" % [ks[1], ks[0]]   # lo_up (위계: up=ks[0] 최상)
			pair_count[key] = int(pair_count.get(key, 0)) + 1
	print("── 경계쌍(lo_up = 위계 낮음_높음) → 경계 셀 수 ──")
	for k in pair_count:
		print("  %s : %d" % [k, pair_count[k]])
	print("삼중점(3표면 코너) 셀 수: %d" % triple)
	print("surf 코드: 0맨흙 1잔디 2길 3밭 4물")
	quit()

func _vsurf(surf: Array, vx: int, vy: int, W: int, H: int) -> int:
	var best := -1
	var best_r := -1
	for d: Vector2i in [Vector2i(-1, -1), Vector2i(0, -1), Vector2i(-1, 0), Vector2i(0, 0)]:
		var cx := vx + d.x
		var cy := vy + d.y
		if cx < 0 or cy < 0 or cx >= W or cy >= H:
			continue
		var s: int = surf[cy][cx]
		if s < 0:
			continue
		if RANK[s] > best_r:
			best_r = RANK[s]
			best = s
	return best
