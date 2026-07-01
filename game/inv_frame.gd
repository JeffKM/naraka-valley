extends Control
class_name InventoryFrame
# Phase 2.7 C2 — 공통 인벤토리 프레임(§3.4 컨텍스트 스위칭 UI 셸).
#
# 목적: "하단 플레이어 가방(백팩)은 공통 모듈로 고정 + 상단 레이어만 컨텍스트로 교체"라는
#       §3.4 불변식을 한 Control로 구현한다(grill 2026-06-24). 한 화면을 세 컨텍스트가 공유한다:
#         · MENU  — 탭 셸(인벤토리 탭=백팩+정리 / 관계 탭=하트 읽기 전용, HeartBar 재사용)
#         · BIN   — 무인 출하함(상단=대기 내용/정산 미리보기, 하단=백팩, 클릭=드롭·롤백)
#         · STORE — 네오 매대(상단=구매 목록·할인, 하단=백팩, 클릭=구매·Shift 대량)
#       대화·일일 정산은 *별도 패널*이라 이 프레임 밖이다(백팩-하단 불변식 = 아이템 컨텍스트 전용).
#
# 설계 메모:
#   - hotbar_hud.gd·lighting.gd와 같은 결: 코드 생성 자식 Control(무상태 — 인벤토리·출하함이 상태를
#     들고, 프레임은 그걸 *그리고 입력만 라우팅*한다). inventory/bin의 changed로만 다시 그린다.
#   - 슬롯 이동(move_slot)·정리(sort)는 inventory에 직접 위임(순수 로직). 드롭·롤백·구매는 wallet/
#     inventory를 함께 건드리므로 시그널로 main에 올린다(deposit/takeback/buy) — 프레임은 지갑을 모른다.
#   - 관계 탭 하트는 HeartBar 노드 4개를 자식으로 붙여 재사용한다(grill "HeartBar 재사용"). 관계 탭일
#     때만 보이고, main이 set_hearts로 값을 흘려넣는다(읽기 전용 — 여기서 호감도를 못 바꾼다).
#   - 마우스 클릭(_gui_input)으로 조작한다(스타듀 UI = 마우스, ADR-0024는 *월드* 조작이고 패널은 클릭).
#     헤드리스 검증은 로직(move_slot·sort·bin·buy)을 직접 부르므로 클릭 경로와 무관하게 보장된다.

signal deposit_slot(slot_index: int)   # 출하함: 백팩 슬롯을 통째로 드롭(판매 예약)
signal takeback_id(id: String)         # 출하함: 대기분을 통째로 롤백(취침 전 회수)
signal buy_pressed(bulk: bool)         # 매대: 선택 씨앗 구매(bulk=Shift 대량)

# 컨텍스트(상단 레이어). NONE이면 닫힘(보이지 않음).
enum { CTX_NONE, CTX_MENU, CTX_BIN, CTX_STORE }
# 메뉴 탭.
enum { TAB_INV, TAB_REL }

const COLS := 6                  # 백팩 그리드 가로 칸 수(12칸 = 6×2)
const ROWS := 2
const SLOT := 48.0               # 슬롯 한 변(px)
const GAP := 4.0
const PAD := 16.0                # 패널 안쪽 여백
const TOP_H := 132.0             # 상단 컨텍스트 영역 높이

var inv: Inventory = null
var bin: ShippingBin = null
var crop_icons: Dictionary = {}
# main이 매 프레임 채워 넣는 보조 텍스트(매대 본문·정산 미리보기 등) — 프레임은 표시만.
var store_text: String = ""

var context := CTX_NONE
var menu_tab := TAB_INV
var _held := -1                  # 메뉴 인벤토리 탭에서 집어 든 백팩 슬롯(-1=없음)

# 히트 테스트 캐시(_draw에서 채우고 _gui_input에서 읽는다).
var _bp_rects: Array = []        # 백팩 12칸 Rect2
var _bin_rects: Array = []       # 출하함 대기 슬롯 [{rect, id}]
var _tab_rects: Array = []       # 메뉴 탭 2개 Rect2
var _sort_rect := Rect2()
var _buy_rect := Rect2()

var _hearts: Array = []          # HeartBar 4개(관계 탭 재사용)
var _heart_effects: Array = []   # ★ C3 각 캐릭터의 관계 곱셈기 효과 줄(여우불·마진·경비·할인)

func _ready() -> void:
	# 관계 탭용 HeartBar 4개를 미리 붙여 둔다(평소 숨김 — 관계 탭일 때만 보임).
	for _i in 4:
		var hb := HeartBar.new()
		hb.visible = false
		add_child(hb)
		_hearts.append(hb)

# main이 인벤토리·출하함·작물 아이콘을 주입하고 changed 구독을 건다. 전체 화면 앵커로 깔되
# 처음엔 닫혀 있다(보이지 않음). 마우스 STOP라 열렸을 때 클릭을 잡아 월드로 새지 않게 한다(모달).
func setup(inventory: Inventory, shipping_bin: ShippingBin, icons: Dictionary) -> void:
	inv = inventory
	bin = shipping_bin
	crop_icons = icons
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	if inv != null and not inv.changed.is_connected(queue_redraw):
		inv.changed.connect(queue_redraw)
	if bin != null and not bin.changed.is_connected(queue_redraw):
		bin.changed.connect(queue_redraw)

# 프레임을 연다(컨텍스트 지정). 메뉴는 마지막 탭을 유지한다.
func open(ctx: int) -> void:
	context = ctx
	_held = -1
	visible = true
	_apply_heart_visibility()
	queue_redraw()

# 프레임을 닫는다.
func close() -> void:
	context = CTX_NONE
	_held = -1
	visible = false
	_apply_heart_visibility()

func is_open() -> bool:
	return context != CTX_NONE

# 메뉴 탭을 바꾼다(인벤토리 ↔ 관계).
func set_tab(t: int) -> void:
	menu_tab = t
	_held = -1
	_apply_heart_visibility()
	queue_redraw()

# 메뉴 탭을 다음으로 순환(인벤토리 → 관계 → 인벤토리).
func cycle_tab() -> void:
	set_tab(TAB_REL if menu_tab == TAB_INV else TAB_INV)

# 관계 탭 하트 값 주입(읽기 전용). rows = [{name, filled, total, effect}]. main이 affinity들에서 파생해
# 넘긴다. ★ C3 — effect(관계 곱셈기 한 줄)도 함께 받아 하트 아래에 그린다(_draw_menu_top REL 분기).
func set_hearts(rows: Array) -> void:
	_heart_effects.resize(_hearts.size())
	for i in _hearts.size():
		var hb: HeartBar = _hearts[i]
		if i < rows.size():
			var r: Dictionary = rows[i]
			hb.render(str(r.get("name", "")), int(r.get("filled", 0)), int(r.get("total", 5)))
			_heart_effects[i] = str(r.get("effect", ""))
		else:
			_heart_effects[i] = ""
	queue_redraw()

# 관계 탭일 때만 하트를 보이고, 패널 안 세로로 줄지어 배치한다(상단 컨텍스트 영역).
func _apply_heart_visibility() -> void:
	var show := context == CTX_MENU and menu_tab == TAB_REL
	var panel := _panel_rect()
	for i in _hearts.size():
		var hb: HeartBar = _hearts[i]
		hb.visible = show
		if show:
			# 탭 바(y: PAD..PAD+28) 아래로 내려 하트가 탭에 겹치지 않게 한다. ★ C3 — 행마다 효과 줄을
			# 한 칸 더 끼우므로 간격을 48로 넓힌다(하트 + 그 아래 곱셈기 한 줄 = 한 캐릭터 묶음).
			hb.position = Vector2(panel.position.x + PAD + 8.0, panel.position.y + 64.0 + i * 48.0)

# ── 기하(패널·그리드) ─────────────────────────────────────────────────────────
# 부모 CanvasLayer가 UI scale(ADR-0018 ×1.5)을 먹어, 전체화면 앵커 Control의 size(=960×540)는
# *논리 좌표*가 아니다 — 화면에 실제로 보이는 영역은 size / scale(=640×360)다. 중앙 정렬·백드롭은
# 이 보이는 영역 기준으로 잡아야 패널이 화면 밖으로 넘치지 않는다(핫바와 같은 스케일 함정 회피).
func _view() -> Vector2:
	var sc := 1.0
	var par := get_parent()
	if par is CanvasLayer and par.scale.x != 0.0:
		sc = par.scale.x
	return Vector2(size.x / sc, size.y / sc)

func _panel_rect() -> Rect2:
	var view := _view()
	var grid_w := COLS * SLOT + (COLS - 1) * GAP
	var w := grid_w + PAD * 2.0
	var grid_h := ROWS * SLOT + (ROWS - 1) * GAP
	var h := TOP_H + grid_h + PAD * 3.0
	return Rect2((view.x - w) * 0.5, (view.y - h) * 0.5, w, h)

func _grid_origin(panel: Rect2) -> Vector2:
	# 백팩 그리드는 패널 하단(상단 컨텍스트 영역 아래).
	return Vector2(panel.position.x + PAD, panel.position.y + TOP_H + PAD * 2.0)

# ── 그리기 ────────────────────────────────────────────────────────────────────
func _draw() -> void:
	if context == CTX_NONE or inv == null:
		return
	# 월드를 어둡게(모달 백드롭) — 보이는 논리 영역(_view) 전체를 덮는다(scale 함정 회피).
	draw_rect(Rect2(Vector2.ZERO, _view()), Color(0, 0, 0, 0.45))
	var panel := _panel_rect()
	draw_rect(panel, Color(0.10, 0.10, 0.13, 0.96))
	draw_rect(panel, Color(0.55, 0.52, 0.40), false, 2.0)
	# 상단 컨텍스트 영역(탭/매대/출하함). 백팩은 관계 탭을 빼고 항상 하단에 그린다.
	match context:
		CTX_MENU:
			_draw_menu_top(panel)
			if menu_tab == TAB_INV:
				_draw_backpack(panel)
		CTX_BIN:
			_draw_bin_top(panel)
			_draw_backpack(panel)
		CTX_STORE:
			_draw_store_top(panel)
			_draw_backpack(panel)

# 공통 백팩 그리드(하단 고정). 슬롯 = 핫바와 동일 규격(빈칸·아이콘·개수 배지).
func _draw_backpack(panel: Rect2) -> void:
	_bp_rects.clear()
	_bp_rects.resize(Inventory.SIZE)
	var origin := _grid_origin(panel)
	for i in Inventory.SIZE:
		var col := i % COLS
		var row := i / COLS
		var pos := origin + Vector2(col * (SLOT + GAP), row * (SLOT + GAP))
		var rect := Rect2(pos, Vector2(SLOT, SLOT))
		_bp_rects[i] = rect
		var picked := i == _held
		_draw_slot_box(rect, picked)
		var id := inv.id_at(i)
		if id != "":
			_draw_icon(id, rect)
			# ★ S1-6 품질 배지(그레이박스 — 등급>0이면 좌하단 등급 색 점, 핫바와 동일 결).
			var q := inv.quality_at(i)
			if q > 0:
				draw_circle(pos + Vector2(8.0, SLOT - 8.0), 4.0, _quality_color(q))
			var n := inv.count_at(i)
			if n > 1:
				draw_string(ThemeDB.fallback_font, pos + Vector2(SLOT - 16.0, SLOT - 5.0),
					str(n), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)

# 품질 등급 색(그레이박스 배지 — 은/금/이리듐). hotbar_hud와 동일 팔레트(뷰 책임, 카탈로그 무결합).
func _quality_color(q: int) -> Color:
	match q:
		1: return Color(0.78, 0.80, 0.85)   # 은
		2: return Color(0.96, 0.80, 0.25)   # 금
		3: return Color(0.60, 0.38, 0.88)   # 이리듐
		_: return Color.WHITE

func _draw_slot_box(rect: Rect2, highlight: bool) -> void:
	draw_rect(rect, Color(0.16, 0.16, 0.20, 0.95))
	draw_rect(rect, Color(0.95, 0.92, 0.65) if highlight else Color(0.42, 0.42, 0.48), false, 2.0 if highlight else 1.0)

func _draw_icon(id: String, rect: Rect2) -> void:
	var pad := 6.0
	var inner := Rect2(rect.position + Vector2(pad, pad), rect.size - Vector2(pad * 2.0, pad * 2.0))
	match ItemCatalog.category_of(id):
		ItemCatalog.CAT_TOOL:
			draw_rect(inner, ItemCatalog.tool_color_of(id))
		ItemCatalog.CAT_SEED:
			_draw_crop_tex(ItemCatalog.crop_of(id), inner)
		ItemCatalog.CAT_SAPLING:
			# ★ [S1-5b] 묘목 그레이박스 아이콘(핫바와 동일 — 밑동 갈색+새싹 초록).
			draw_rect(inner, Color(0.42, 0.30, 0.20))
			draw_rect(Rect2(inner.position, Vector2(inner.size.x, inner.size.y * 0.45)), Color(0.35, 0.62, 0.35))
		ItemCatalog.CAT_HARVEST:
			_draw_crop_tex(id, inner)
		ItemCatalog.CAT_FERTILIZER:
			# ★ [S1-6] 비료 그레이박스 아이콘 — 품질군=초록 흙, 성장촉진군=청록(축=구분). 아트=하류.
			var fc := Color(0.40, 0.55, 0.32) if FertilizerCatalog.group_of(id) == "quality" else Color(0.30, 0.55, 0.55)
			draw_rect(inner, fc)

func _draw_crop_tex(crop_id: String, inner: Rect2) -> void:
	var tex: Texture2D = crop_icons.get(crop_id)
	if tex == null:
		draw_rect(inner, Color(0.8, 0.8, 0.8))
		return
	draw_texture_rect(tex, inner, false)

# ── 메뉴 상단(탭 바 + 탭별 내용) ──────────────────────────────────────────────
func _draw_menu_top(panel: Rect2) -> void:
	var font := ThemeDB.fallback_font
	# 탭 두 개(인벤토리 | 관계). 현재 탭은 밝게.
	_tab_rects.clear()
	var labels := ["인벤토리", "관계"]
	var tab_w := 96.0
	for i in labels.size():
		var r := Rect2(panel.position.x + PAD + i * (tab_w + GAP), panel.position.y + PAD, tab_w, 28.0)
		_tab_rects.append(r)
		var on := i == menu_tab
		draw_rect(r, Color(0.22, 0.22, 0.28) if on else Color(0.14, 0.14, 0.18))
		draw_rect(r, Color(0.95, 0.92, 0.65) if on else Color(0.40, 0.40, 0.46), false, 1.0)
		draw_string(font, r.position + Vector2(12.0, 19.0), labels[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 14,
			Color.WHITE if on else Color(0.65, 0.65, 0.70))
	if menu_tab == TAB_INV:
		# [정리] 버튼(우상단).
		_sort_rect = Rect2(panel.end.x - PAD - 72.0, panel.position.y + PAD, 72.0, 28.0)
		draw_rect(_sort_rect, Color(0.20, 0.26, 0.20))
		draw_rect(_sort_rect, Color(0.45, 0.60, 0.45), false, 1.0)
		draw_string(font, _sort_rect.position + Vector2(16.0, 19.0), "정리", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
		draw_string(font, Vector2(panel.position.x + PAD, panel.position.y + TOP_H + 6.0),
			"플레이어 가방 — 슬롯을 클릭해 집고 다른 칸에 놓아 옮긴다", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.70, 0.70, 0.75))
	else:
		# 관계 탭: 하트는 HeartBar 자식이 그린다(_apply_heart_visibility 배치). 탭 바 오른쪽에 '읽기 전용' 안내만.
		draw_string(font, Vector2(panel.position.x + PAD + 210.0, panel.position.y + PAD + 19.0),
			"읽기 전용", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.62, 0.62, 0.68))
		# ★ C3 각 하트 행 아래에 그 캐릭터의 관계 곱셈기(여우불·마진·경비·할인) 한 줄. HeartBar와 같은
		# y 기준(panel.y + 64 + i*48)에서 한 칸(+24) 내려 그린다 — 상시 HUD에서 걷어낸 정보를 여기서 복기.
		for i in _heart_effects.size():
			var eff: String = str(_heart_effects[i])
			if eff == "":
				continue
			var ey := panel.position.y + 64.0 + i * 48.0 + 40.0
			draw_string(font, Vector2(panel.position.x + PAD + 12.0, ey), eff,
				HORIZONTAL_ALIGNMENT_LEFT, panel.size.x - PAD * 2.0 - 12.0, 12, Color(0.70, 0.72, 0.78))

# ── 출하함 상단(대기 슬롯 + 정산 미리보기) ────────────────────────────────────
func _draw_bin_top(panel: Rect2) -> void:
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(panel.position.x + PAD, panel.position.y + PAD + 18.0),
		"무인 출하함", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.90, 0.86, 0.60))
	var preview := bin.preview_gold() if bin != null else 0
	draw_string(font, Vector2(panel.position.x + PAD, panel.position.y + PAD + 40.0),
		"다음 아침 정산  +%d골드   ·   백팩 수확물 클릭=드롭 / 위 칸 클릭=회수" % preview,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.70, 0.70, 0.75))
	# 대기 슬롯(가로로 나열).
	_bin_rects.clear()
	if bin == null:
		return
	var origin := Vector2(panel.position.x + PAD, panel.position.y + PAD + 52.0)
	var i := 0
	for id in bin.ids():
		var pos := origin + Vector2(i * (SLOT + GAP), 0.0)
		var rect := Rect2(pos, Vector2(SLOT, SLOT))
		_bin_rects.append({"rect": rect, "id": id})
		_draw_slot_box(rect, false)
		_draw_icon(id, rect)
		var n := bin.count_of(id)
		if n > 1:
			draw_string(font, pos + Vector2(SLOT - 16.0, SLOT - 5.0), str(n), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)
		i += 1

# ── 매대 상단(본문 텍스트 + 구매 버튼) ────────────────────────────────────────
func _draw_store_top(panel: Rect2) -> void:
	var font := ThemeDB.fallback_font
	var y := panel.position.y + PAD + 16.0
	for line in store_text.split("\n"):
		draw_string(font, Vector2(panel.position.x + PAD, y), line, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.85, 0.85, 0.90))
		y += 18.0
	# 구매 버튼(좌클릭=1개 / Shift+좌클릭=대량).
	_buy_rect = Rect2(panel.position.x + PAD, panel.position.y + TOP_H - 6.0, 220.0, 26.0)
	draw_rect(_buy_rect, Color(0.20, 0.24, 0.30))
	draw_rect(_buy_rect, Color(0.45, 0.55, 0.65), false, 1.0)
	draw_string(font, _buy_rect.position + Vector2(12.0, 18.0), "[클릭] 구매   ·   [Shift+클릭] 대량",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)

# ── 클릭 라우팅 ───────────────────────────────────────────────────────────────
func _gui_input(event: InputEvent) -> void:
	if context == CTX_NONE:
		return
	if not (event is InputEventMouseButton) or not event.pressed or event.button_index != MOUSE_BUTTON_LEFT:
		return
	var p: Vector2 = event.position
	match context:
		CTX_MENU:
			_click_menu(p)
		CTX_BIN:
			_click_bin(p)
		CTX_STORE:
			if _buy_rect.has_point(p):
				buy_pressed.emit(event.shift_pressed)
	accept_event()

func _click_menu(p: Vector2) -> void:
	# 탭 전환.
	for i in _tab_rects.size():
		if _tab_rects[i].has_point(p):
			set_tab(i)
			return
	if menu_tab != TAB_INV:
		return
	# 정리 버튼.
	if _sort_rect.has_point(p):
		inv.sort()
		_held = -1
		return
	# 백팩 슬롯: 집기/놓기(클릭 이동).
	for i in _bp_rects.size():
		if _bp_rects[i].has_point(p):
			if _held < 0:
				if inv.id_at(i) != "":
					_held = i   # 집기(빈 칸은 집지 않는다)
			else:
				inv.move_slot(_held, i)   # 놓기(이동·스왑·병합)
				_held = -1
			queue_redraw()
			return
	# 패널 안 빈 곳 클릭 = 집은 것 내려놓기 취소.
	_held = -1
	queue_redraw()

func _click_bin(p: Vector2) -> void:
	# 백팩 수확물 슬롯 클릭 = 드롭(판매 예약).
	for i in _bp_rects.size():
		if _bp_rects[i].has_point(p):
			deposit_slot.emit(i)
			return
	# 대기 슬롯 클릭 = 롤백(회수).
	for e in _bin_rects:
		if e["rect"].has_point(p):
			takeback_id.emit(e["id"])
			return
