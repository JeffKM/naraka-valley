extends SceneTree
# ★[prop-regen-roster §5.3] 통나무 5종 배치 후보 검증(임시 글루). 각 후보 타일에 대해:
#   ① 맵 경계 안 ② 지형 is_solid(_grid)=false(물·절벽·건물벽 회피) ③ 기존 프롭·건물 EXT rect와 겹침0.
#   통나무는 통과 O 순수 장식이라 발치 SOLID는 없지만, 시각 겹침을 피해 스프라이트 rect로 보수 판정.
# 사용: godot --headless --path game -s res://tools/logs_place_check.gd
const TILE := 32

func _init() -> void:
	var main = load("res://main.tscn").instantiate()
	get_root().add_child(main)
	await process_frame
	await process_frame

	# 후보(나무 클러스터 곁·빈 가장자리). 통과 후보만 PROP_LAYOUT_HOME에 채택.
	var cands := {
		"LOG_LONG": [Vector2i(63, 6), Vector2i(6, 40), Vector2i(66, 55)],
		"LOG_SHORT": [Vector2i(50, 5), Vector2i(14, 50), Vector2i(56, 32)],
		"LOG_UPRIGHT": [Vector2i(58, 7), Vector2i(72, 50), Vector2i(7, 45), Vector2i(66, 29)],
		"LOG_DIAG_A": [Vector2i(60, 9), Vector2i(16, 50), Vector2i(12, 38)],
		"LOG_DIAG_B": [Vector2i(52, 9), Vector2i(15, 52), Vector2i(68, 30)],
	}

	# 기존 점유 rect 수집(프롭 스프라이트 칸 + 건물 EXT + 연못/패치/방목).
	var occ: Array = []
	for e in main._prop_layouts.get("HOME", []):
		var sz: Vector2i = (e[0] as Texture2D).get_size()
		var wc := int(ceil(sz.x / float(TILE)))
		var hc := int(ceil(sz.y / float(TILE)))
		for t in e[1]:
			occ.append(Rect2i(t.x, t.y, wc, hc))
	for r in [main.HOUSE_EXT_RECT, main.STOREHOUSE_EXT_RECT, main.NEOKURITGAN_EXT_RECT,
			main.NEOKDUNGURI_EXT_RECT, main.STORE_EXT_RECT, main.SPIRIT_POND_RECT,
			main.STARTER_PATCH_RECT, main.PASTURE_SCAN_RECT]:
		occ.append(r)

	var reg: Dictionary = main.PROP_TEX_REGISTRY
	var ok_lines: Array = []
	for key in cands:
		var tex: Texture2D = reg[key]
		var sz: Vector2i = tex.get_size()
		var wc := int(ceil(sz.x / float(TILE)))
		var hc := int(ceil(sz.y / float(TILE)))
		for c in cands[key]:
			var rect := Rect2i(c.x, c.y, wc, hc)
			var reason := ""
			if c.x < 0 or c.y < 0 or c.x + wc > main._grid_w or c.y + hc > main._grid_h:
				reason = "OOB"
			if reason == "":
				for yy in range(c.y, c.y + hc):
					for xx in range(c.x, c.x + wc):
						if main.is_solid(main._grid[yy][xx]):
							reason = "SOLID@%d,%d" % [xx, yy]
			if reason == "":
				for o in occ:
					if rect.intersects(o):
						reason = "overlap %s" % str(o)
						break
			var tag := "OK  " if reason == "" else "FAIL"
			print("%s %-11s %s  (%dx%d)  %s" % [tag, key, str(c), wc, hc, reason])
			if reason == "":
				ok_lines.append("%s %s" % [key, str(c)])
	print("--- OK 후보 ---")
	for l in ok_lines:
		print(l)
	quit()
