extends SceneTree
# 통합 메뉴 프레임 육안 덤프(비-headless) — 옵션 탭·인벤토리 탭 렌더를 PNG로 굽는다.
# owner 리포트(2026-07-06) 레이아웃 수정 확인용: 옵션 탭 "설정"/"음악 볼륨" 겹침·정리 버튼 위치.
# ★ --headless 없이: godot --path game --script res://playtest/frame_dump.gd

func _read(p: String) -> PackedByteArray:
	var f := FileAccess.open(p, FileAccess.READ); var b := f.get_buffer(f.get_length()); f.close(); return b
func _write(p: String, b: PackedByteArray) -> void:
	var f := FileAccess.open(p, FileAccess.WRITE); f.store_buffer(b); f.close()

func _grab(name: String) -> void:
	for i in 6:
		await process_frame
	root.get_texture().get_image().save_png("/tmp/%s.png" % name)
	print("saved /tmp/%s.png" % name)

func _initialize() -> void:
	root.size = Vector2i(960, 540)
	# 세이브 격리(부팅이 새 게임/로드하므로 개발 save.dat 백업).
	var sp := SaveManager.slot_path(0)
	var bak := _read(sp) if FileAccess.file_exists(sp) else PackedByteArray()
	var had := FileAccess.file_exists(sp)

	var m: Node = load("res://main.tscn").instantiate()
	root.add_child(m)
	for i in 8:
		await process_frame

	# 옵션 탭 — 옵션(gear) 탭 호버 툴팁 표시(탭 바 우측에 뜨는지 확인)
	m._open_frame(InventoryFrame.CTX_MENU)
	m.frame.set_tab(InventoryFrame.TAB_OPTIONS)
	m.frame.set_settings(0.8, 0.9, false)
	m.frame._hover_tab = InventoryFrame.TAB_OPTIONS
	m.frame.queue_redraw()
	await _grab("frame_options")

	# 인벤토리 탭 — 정보패널(소지금·총수입·날짜·농장명)·휴지통·닫기 X + 스크롤바
	m.frame.set_tab(InventoryFrame.TAB_INV)
	m.frame._hover_tab = -1
	m.frame._bp_first_row = 0
	m.wallet.gold = 340
	m._total_income = 1280
	m.frame.set_inv_info(m.wallet.gold, m._total_income, m._inv_date_string(), "안식 농원")
	m.frame.queue_redraw()
	await _grab("frame_inv")

	# ★ [S1R-T12] 휴지통 버리기 확인 오버레이(집은 상태) — 슬롯 0을 집어 확인 띄움
	m.frame._held = 0
	m.frame._trash_pending = 0
	m.frame.queue_redraw()
	await _grab("frame_inv_trash")
	m.frame._held = -1
	m.frame._trash_pending = -1

	# 인벤토리 탭(스크롤 내림) — 3번째 행이 보이고 썸이 아래로 내려갔는지
	m.frame._bp_first_row = 1
	m.frame.queue_redraw()
	await _grab("frame_inv_scrolled")

	# 관계 탭 — 안내 문구와 하트 행이 안 겹치는지(owner 리포트 2026-07-06 세로 겹침 확인용)
	m.frame.set_tab(InventoryFrame.TAB_REL)
	m.frame._hover_tab = -1
	# ★[S8-T1] 관계 트랙 보유 9인 — 곱셈기 없는 주민(모찌·풀무·무골)은 효과 줄 없이 하트만 뜨고,
	#   패널을 넘치는 만큼은 세로 스크롤로 접힌다(하단 "▼ N" 안내가 함께 보이는지 확인용).
	# ★[S8-T9] 배지 4종(부부·혼례 준비 중·연애 중·진급 대기)을 한 화면에 깔아 **상태색 분화**를
	#   눈으로 대조한다 — 라이브에선 배우자·연인이 동시에 넷일 수 없어 이 덤프가 유일한 대조면이다.
	#   선물 리듬 꼬리도 같이 태운다(곱셈기 있는 행 = "… · 이번 주 선물 n/2", 없는 행 = 꼬리만).
	m.frame.set_hearts([
		{"name": "미호", "filled": 5, "total": 5, "effect": "여우불: 잠듦 — 미호와 친해지면 깨어난다 · 선물 매일 가능(부부)", "badge": "부부"},
		{"name": "멜", "filled": 5, "total": 5, "effect": "멜 마진: ×1.0 — 멜과 친해지면 단가가 오른다 · 이번 주 선물 2/2", "badge": "혼례 준비 중"},
		{"name": "바나", "filled": 5, "total": 5, "effect": "바나 경비: 잠듦 — 바나와 친해지면 밤을 지켜준다 · 이번 주 선물 1/2", "badge": "연애 중"},
		{"name": "네오", "filled": 0, "total": 5, "effect": "네오 할인: 정가 — 네오와 친해지면 매대가 싸진다 · 이번 주 선물 2/2", "badge": "진급 대기"},
		{"name": "모찌", "filled": 2, "total": 5, "effect": "이번 주 선물 0/2"},
		{"name": "뱃사공", "filled": 0, "total": 5, "effect": "생선가게 할인: 정가 · 이번 주 선물 2/2"},
		{"name": "옹이", "filled": 0, "total": 5, "effect": "목공방 할인: 정가 · 이번 주 선물 2/2"},
		{"name": "풀무", "filled": 1, "total": 5, "effect": "이번 주 선물 2/2"},
		{"name": "무골", "filled": 0, "total": 5, "effect": "이번 주 선물 2/2"},
	])
	m.frame.queue_redraw()
	await _grab("frame_rel")

	# ★[S8-T10] 달력 패널 — 생일 ♥ 마커(칸)와 범례 생일 줄의 **그린 하트 머리표**를 대조한다.
	#   폰트(neodgm.ttf)에 ♥ 글리프가 없어 범례 "♥ " 문자가 두부(□)로 뜨던 것을 `_draw_heart_mark`
	#   그림으로 바꾼 게 T10 봉합이라, 그 두 표시가 같은 형태로 보이는지는 눈으로만 판정된다.
	#   유화절(절기 인덱스 1 = 29~56일)에 생일이 둘(미호 7일·모찌 26일) 있어 범례가 두 줄 뜬다.
	m._close_frame()
	# 인트로 대화를 먼저 넘긴다 — 대화가 떠 있으면 상시 HUD가 접히고(_hud_hidden) 달력도 매
	# 프레임 close() 당해, 토글해도 다음 프레임에 사라진다.
	var guard := 0
	while m.dialogue.is_open() and guard < 50:
		m.dialogue.advance()
		guard += 1
	m.clock.day = 35                      # 유화절 7일차 = 미호 생일 당일
	for i in 4:                           # main._process가 set_state로 마킹을 다시 파생할 틈
		await process_frame
	m.calendar_panel.toggle()
	await _grab("frame_calendar")
	m.calendar_panel.close()

	# ★ [S1R-T11] 상점 — 매대 본문 타이포·구매 버튼 2개(씨앗/스프링클러) 한지 plate 확인
	m._close_frame()
	m._open_frame(InventoryFrame.CTX_STORE)
	await _grab("frame_store")

	# ★ [S1R-T11] 저장 상자 — 상단 상자 그리드·하단 백팩 슬롯이 핫바 plate와 정합인지 확인
	m._close_frame()
	m._open_frame(InventoryFrame.CTX_CHEST)
	await _grab("frame_chest")

	# ★ [S1R-T12] 출하함 — 품목별 정산 내역 행(아이콘|이름×수량|소계) + 총액 강조
	m._close_frame()
	m.ship_bin.pending.clear()
	m.ship_bin.add(CropCatalog.HONRYEONGCHO, 5, 0)
	m.ship_bin.add(CropCatalog.PIANHWA, 3, 1)
	m.ship_bin.add(CropCatalog.YEONGHON_HOBAK, 2, 0)
	m._open_frame(InventoryFrame.CTX_BIN)
	await _grab("frame_bin")
	m.ship_bin.pending.clear()

	m._close_frame()
	m.queue_free()
	await process_frame

	# 세이브 복원
	if FileAccess.file_exists(sp): DirAccess.remove_absolute(ProjectSettings.globalize_path(sp))
	if had: _write(sp, bak)
	quit(0)
