extends SceneTree
# Phase 2.8 T3(④) — 실내 카메라 격리 마스크 회귀 잠금(ephemeral 헤드리스 단위검증).
#
# 왜 있나(코지-와이드 회귀의 재발 방지): ADR-0018이 뷰포트를 960×540(30×17타일)로 키웠는데
# 실내 cam rect(예: 20×13타일)는 그대로라 카메라 한계가 화면보다 작아 → 방 밖(외부 풀밭·이웃 방)이
# 사방으로 샜다("집 안인데 집 밖 보임"). IndoorMask가 방(cam rect) 바깥을 검정으로 덮어 막는다.
# 이 버그는 *헤드리스 회귀에 렌더가 없어 미감지*된 게 원인 — 그래서 렌더 없이도 잡히는 *와이어링·
# 기하 불변식*을 여기서 못박는다(육안 마스크 PNG는 tools/indoor_mask_check.gd가 GPU로 별도 확인).
#
# ★ 핵심 불변식(렌더 불필요):
#   ① 마스크 노드 존재 + CanvasLayer 최하위 자식(월드 위에 깔리되 HUD·대화·페이드보다 아래).
#   ② 실내일 때 _process가 마스크에 active=true + 그 건물 cam rect(px)를 주입한다(매 프레임 단일 출처).
#   ③ 외부일 때 active=false(아무것도 안 가림).
#   ④ ★ 모든 enterable 건물의 cam rect가 그 방 rect를 완전히 감싼다(cam ⊇ room).
#      → 마스크가 cam rect 바깥만 검게 덮어도 방이 안 잘리고, cam 안쪽 여백은 VOID(검은 배경)라
#        마스크 검정과 이음매 없이 이어진다 = 누출 0. cam이 뷰포트보다 작아도(그래서 마스크가 필요)
#        이 포함관계만 지키면 안전하다.
# 실행: godot --headless --path game --script res://playtest/indoor_mask_test.gd

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

# 건물 id/kind → 실내 방 rect. ★ 홈 집("집")은 kind=house지만 HOME 밴드 전용 rect(HOME_HOUSE_RECT)라
# 마을 공유 집(HOUSE_RECT)과 구분한다(interior_test 결).
func _room_rect(m: Node, id: String, kind: String) -> Rect2i:
	if id == "집":
		return m.HOME_HOUSE_RECT
	match kind:
		"house": return m.HOUSE_RECT
		"cafe": return m.CAFE_RECT
		"store": return m.STORE_RECT
		"storehouse": return m.STOREHOUSE_RECT
		"museum": return m.MUSEUM_RECT
		"fishshop": return m.FISHSHOP_RECT
		"woodshop": return m.WOODSHOP_RECT
		"smithy": return m.SMITHY_RECT
		"guild": return m.GUILD_RECT
	return Rect2i()

func _initialize() -> void:
	print("══ Phase 2.8 T3(④) 실내 카메라 격리 마스크 회귀 잠금 ══")
	const SAVE := "user://save.dat"
	# 첫 인스턴스가 옛/오염 세이브로 부팅되지 않게(테스트 격리). 마스크 검증은 세이브를 안 건드린다.
	if FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))

	var m: Node = await _spawn_main()

	# ── ① 마스크 노드 존재 + CanvasLayer 최하위 자식 ──
	_check("① 마스크 노드 존재(IndoorMask)", m.indoor_mask != null)
	var layer: Node = m.get_node("CanvasLayer")
	_check("① 마스크가 CanvasLayer 자식", m.indoor_mask.get_parent() == layer)
	_check("① 마스크가 최하위 자식(index 0 — 월드 위·HUD 아래)", layer.get_child(0) == m.indoor_mask)
	_check("① 마스크 입력 무시(MOUSE_FILTER_IGNORE)", m.indoor_mask.mouse_filter == Control.MOUSE_FILTER_IGNORE)

	# ── ③ 외부(부팅 직후)면 마스크 비활성 ──
	m._indoor = ""
	m._process(0.0)
	_check("③ 외부면 마스크 비활성(active=false)", not m.indoor_mask.active)

	# ── ②④ 모든 enterable 건물: 실내 와이어링 + cam ⊇ room ──
	# _buildings는 부팅 시 전 구역 15채를 한 번에 등록(카탈로그) → 워프 없이 전부 검증 가능.
	var enterable := 0
	for id in m._buildings.keys():
		var b: Dictionary = m._buildings[id]
		var cam: Rect2i = b["cam"]
		var room := _room_rect(m, id, b["kind"])
		# ④ cam이 방을 완전히 감싼다(마스크가 cam 밖만 덮어도 방이 안 잘림 = 누출 0의 기하 근거).
		_check("④ %s cam ⊇ room (방 안 잘림)" % id, room != Rect2i() and cam.encloses(room))
		# ② 실내 모드로 두고 _process가 마스크에 그 cam rect(px)를 주입하는가(단일 출처).
		m._indoor = id
		m._process(0.0)
		var want := Rect2(cam.position.x * m.TILE, cam.position.y * m.TILE, \
			cam.size.x * m.TILE, cam.size.y * m.TILE)
		_check("② %s 실내 → 마스크 active" % id, m.indoor_mask.active)
		_check("② %s 마스크 rect = 그 방 cam rect(px)" % id, m.indoor_mask.world_rect_px == want)
		enterable += 1
	_check("②b enterable 건물 15채 전부 검증", enterable == 15)

	# ── ③b 실내 → 외부 복귀 시 마스크 즉시 비활성(상태 안 샘) ──
	m._indoor = ""
	m._process(0.0)
	_check("③b 외부 복귀 → 마스크 비활성", not m.indoor_mask.active)

	m.queue_free()
	await process_frame

	print("══ 결과: %s ══" % ("PASS (실패 0)" if _fail == 0 else "FAIL (실패 %d)" % _fail))
	quit(1 if _fail > 0 else 0)
