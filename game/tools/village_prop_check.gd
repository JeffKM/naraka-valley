extends SceneTree

# ★[S2-T9] 나루 야외 프롭 안전 검사(육안 글루 — 회귀 스위트가 아니라 배치 검증용).
# 벚꽃 나무 밑둥·돌담은 SOLID라 동선(PATH)·건물(WALL)·물 위에 앉으면 마을을 막거나 떠 보인다.
# 각 프롭이 실제로 점유하는 칸의 _grid 타일을 찍어 GROUND가 아닌 것만 보고한다.
# 사용: godot --headless --path game -s res://tools/village_prop_check.gd

const TILE := 32

func _init() -> void:
	var main = load("res://main.tscn").instantiate()
	get_root().add_child(main)
	await process_frame
	main._rebuild_region(RegionCatalog.NARU_VILLAGE)
	await process_frame
	var names := {
		main.GROUND: "GROUND", main.PATH: "PATH", main.WALL: "WALL", main.WATER: "WATER",
		main.SOIL: "SOIL", main.VOID: "VOID", main.CLIFF_BANK: "CLIFF_BANK",
	}
	var bad := 0
	for entry in main._prop_layouts.get("VILLAGE_OUTDOOR", []):
		var tex: Texture2D = entry[0]
		var sz: Vector2 = tex.get_size()
		var w := int(sz.x) / TILE
		var h := int(sz.y) / TILE
		var foot_only: bool = tex in main.FOOT_BAR_PROPS   # 나무 = 밑행만 SOLID
		for t in entry[1]:
			var y0: int = t.y + (h - 1) if foot_only else t.y
			for yy in range(y0, t.y + h):
				for xx in range(t.x, t.x + w):
					var g: int = main._grid[yy][xx]
					if g != main.GROUND:
						bad += 1
						print("❌ SOLID 프롭이 비-GROUND 칸: ", tex.resource_path.get_file(),
							" anchor=", t, " cell=(", xx, ",", yy, ") tile=", names.get(g, str(g)))
	# 광장·다리 rect가 실제로 걷기 가능한지(순수 시각이므로 통행 불변식)도 같이 본다.
	var blocked := 0
	for r: Rect2i in [main.NARU_PLAZA_RECT, main.NARU_BRIDGE_DECK_RECT]:
		for yy in range(r.position.y, r.end.y):
			for xx in range(r.position.x, r.end.x):
				var g: int = main._grid[yy][xx]
				if g == main.WALL or g == main.VOID:
					blocked += 1
					print("⚠️ 포장면 rect 안에 통과 불가 타일: (", xx, ",", yy, ") ", names.get(g, str(g)))
	print("검사 완료 — SOLID 프롭 오배치 ", bad, "건 / 포장면 막힌 칸 ", blocked, "건")
	quit(1 if bad > 0 else 0)
