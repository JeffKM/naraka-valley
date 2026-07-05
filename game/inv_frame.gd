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
signal save_pressed                    # ★ Phase B 옵션 탭: 저장(main이 _save_game 호출)
signal quit_pressed                    # ★ Phase B 옵션 탭: 저장하고 나가기
signal chest_store(slot_index: int)    # ★ Phase D 상자: 백팩 슬롯을 통째로 상자에 보관
signal chest_take(chest_index: int)    # ★ Phase D 상자: 상자 슬롯을 통째로 백팩으로 회수
signal music_vol_changed(delta: float) # ★ Phase D 설정: 음악 볼륨 증감(옵션 탭 −/+)
signal sfx_vol_changed(delta: float)   # ★ Phase D 설정: 효과음 볼륨 증감(옵션 탭 −/+)
signal fullscreen_toggled              # ★ Phase D 설정: 전체화면 토글(옵션 탭 체크박스)
signal profession_chosen(skill: String, prof_id: String)   # ★ ADR-0052 숙련 탭: 전문직 선택(main이 choose_profession)

# ★ Phase B(ADR-0048) 한지 9-slice 스킨 — 태운 한지 톤 계승([dialog-ui-hanji-redesign]).
# 이미 있으나 미배선이던 프레임 에셋을 즉시모드 _draw_nine으로 배선한다(신규 에셋 0 — owner 결정).
# 규격 박제(ADR-0025): hanji_frame 72² 테두리 22 / hanji_plate 40² 테두리 12. 같은 파일명·크기
# Gemini 결과로 코드 무수정 덮어쓰기 가능(ADR-0047).
const HANJI_FRAME: Texture2D = preload("res://assets/ui/hanji_frame.png")
const HANJI_PLATE: Texture2D = preload("res://assets/ui/hanji_plate.png")
const FRAME_MARGIN := 22.0
const PLATE_MARGIN := 12.0

# ★ [정체성 UI] 통합 탭 아이콘 4종(24×24, PixelLab·한지 톤 — gemini-ui-identity-spec §1).
# 인덱스 = TAB_INV/TAB_REL/TAB_SKILL/TAB_OPTIONS 순서. 라벨 텍스트를 아이콘으로 대체하고
# 탭을 정사각으로 좁힌다(owner 2026-07-05: 아이콘만 배선). 호버 시 한글명 툴팁으로 학습 보조.
const TAB_ICONS: Array[Texture2D] = [
	preload("res://assets/ui/tab_icon_inventory.png"),
	preload("res://assets/ui/tab_icon_social.png"),
	preload("res://assets/ui/tab_icon_skill.png"),
	preload("res://assets/ui/tab_icon_options.png"),
]
const TAB_LABELS := ["인벤토리", "관계", "숙련", "옵션"]   # 호버 툴팁용(아이콘만 배선이라 라벨은 툴팁에)

# 컨텍스트(상단 레이어). NONE이면 닫힘(보이지 않음). ★ Phase D — CTX_CHEST(저장 상자) 추가.
enum { CTX_NONE, CTX_MENU, CTX_BIN, CTX_STORE, CTX_CHEST }
# 메뉴 탭(인벤토리 · 관계 · 숙련 · 옵션 — ADR-0048 §2 통합 탭 메뉴).
enum { TAB_INV, TAB_REL, TAB_SKILL, TAB_OPTIONS }
const TAB_COUNT := 4

const COLS := 6                  # 백팩 그리드 가로 칸 수(12칸 = 6×2)
const ROWS := 2
const SLOT := 48.0               # 슬롯 한 변(px)
const GAP := 4.0
const PAD := 16.0                # 패널 안쪽 여백
const TOP_H := 132.0             # 상단 컨텍스트 영역 높이

var inv: Inventory = null
var bin: ShippingBin = null
var chest: StorageChest = null   # ★ Phase D 저장 상자(CTX_CHEST 상단 그리드 — main이 set_chest로 주입)
var crop_icons: Dictionary = {}
# main이 매 프레임 채워 넣는 보조 텍스트(매대 본문·정산 미리보기 등) — 프레임은 표시만.
var store_text: String = ""

var context := CTX_NONE
var menu_tab := TAB_INV
var _held := -1                  # 메뉴 인벤토리 탭에서 집어 든 백팩 슬롯(-1=없음)
var _hover_tab := -1             # ★ 마우스가 호버 중인 메뉴 탭(-1=없음) — 아이콘 탭 툴팁용

# 히트 테스트 캐시(_draw에서 채우고 _gui_input에서 읽는다).
var _bp_rects: Array = []        # 백팩 12칸 Rect2
var _bin_rects: Array = []       # 출하함 대기 슬롯 [{rect, id}]
var _chest_rects: Array = []     # ★ Phase D 상자 슬롯 Rect2(인덱스=상자 슬롯 번호)
var _tab_rects: Array = []       # 메뉴 탭 4개 Rect2
var _sort_rect := Rect2()
var _buy_rect := Rect2()
var _save_rect := Rect2()        # ★ Phase B 옵션 탭: 저장 버튼
var _quit_rect := Rect2()        # ★ Phase B 옵션 탭: 저장하고 나가기 버튼
# ★ Phase D 옵션 탭 설정 본체(볼륨 −/+ · 전체화면 체크박스) 히트 rect + main이 주입한 현재 값.
var _music_minus_rect := Rect2()
var _music_plus_rect := Rect2()
var _sfx_minus_rect := Rect2()
var _sfx_plus_rect := Rect2()
var _fullscreen_rect := Rect2()
var _set_music := 0.8            # main이 set_settings로 매 프레임 주입(GameSettings 파생 — 읽기 전용 표시)
var _set_sfx := 0.9
var _set_fullscreen := false

var _hearts: Array = []          # HeartBar 4개(관계 탭 재사용)
var _heart_effects: Array = []   # ★ C3 각 캐릭터의 관계 곱셈기 효과 줄(여우불·마진·경비·할인)
# ★ Phase B 숙련 탭: main이 FarmSkill에서 파생해 넘긴 행 [{name, level, max, xp, floor_xp, next_xp}].
# 관계 탭 _heart_effects와 대칭 — 프레임은 값을 받아 진행바만 그린다(무상태).
var _skill_rows: Array = []
# ★ ADR-0052 전문직 선택 버튼 클릭 영역 — _draw_skill_tab이 매 그리기마다 재구성 [{rect, skill, prof_id}].
var _prof_choice_rects: Array = []

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

# ★ Phase D — 저장 상자를 주입한다(main이 _setup_chest 뒤 호출). 내용이 바뀌면 다시 그린다(bin과 같은 결).
func set_chest(storage_chest: StorageChest) -> void:
	chest = storage_chest
	if chest != null and not chest.changed.is_connected(queue_redraw):
		chest.changed.connect(queue_redraw)

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
	_hover_tab = -1
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

# 메뉴 탭을 다음으로 순환(인벤토리 → 관계 → 숙련 → 옵션 → 인벤토리). ★ Phase B 4탭.
func cycle_tab() -> void:
	set_tab((menu_tab + 1) % TAB_COUNT)

# 숙련 탭 값 주입(읽기 전용). rows = [{name, level, max, xp, floor_xp, next_xp}]. main이 FarmSkill에서
# 파생해 넘긴다(_heart_rows와 대칭). next_xp==0이면 만렙 표기. ★ Phase B.
func set_skills(rows: Array) -> void:
	_skill_rows = rows
	queue_redraw()

# ★ Phase D 설정 값 주입(읽기 전용 표시). main이 GameSettings에서 파생해 옵션 탭이 열려 있을 때 넘긴다
# (_skill_rows·_heart_effects와 대칭 — 프레임은 값을 받아 바·체크박스만 그린다, 무상태).
func set_settings(music: float, sfx: float, is_fullscreen: bool) -> void:
	_set_music = music
	_set_sfx = sfx
	_set_fullscreen = is_fullscreen
	if context == CTX_MENU and menu_tab == TAB_OPTIONS:
		queue_redraw()

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
	# ★ Phase B 한지 9-slice 패널(단색 draw_rect → 태운 한지 프레임). 안쪽을 살짝 어둡게 깔아
	# 슬롯·글자 대비를 확보(한지 중앙이 밝아 아이콘이 묻히지 않게).
	_draw_nine(HANJI_FRAME, panel, FRAME_MARGIN)
	draw_rect(panel.grow(-FRAME_MARGIN + 4.0), Color(0.10, 0.09, 0.08, 0.42))
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
		CTX_CHEST:
			_draw_chest_top(panel)
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
	# ★ Phase B 한지 plate 9-slice 슬롯. 집어 든 슬롯은 밝은 테두리를 덧그려 강조(스타듀 결).
	_draw_nine(HANJI_PLATE, rect, PLATE_MARGIN)
	if highlight:
		draw_rect(rect, Color(0.98, 0.90, 0.55), false, 2.0)

# ★ Phase B 즉시모드 9-slice — 텍스처를 9칸(모서리 고정 · 변/중앙 신축)으로 rect에 그린다.
# NinePatchRect 노드 대신 _draw 안에서 draw_texture_rect_region으로 처리(프레임은 즉시모드 셸).
func _draw_nine(tex: Texture2D, rect: Rect2, m: float) -> void:
	var tw := float(tex.get_width())
	var th := float(tex.get_height())
	# 목적지 모서리는 텍스처 모서리와 같게(신축 없이) 두되, rect가 2m보다 작으면 절반으로 죈다.
	var mx: float = minf(m, floorf(rect.size.x * 0.5))
	var my: float = minf(m, floorf(rect.size.y * 0.5))
	var sx := [0.0, m, tw - m]
	var sw := [m, tw - m * 2.0, m]
	var dx := [rect.position.x, rect.position.x + mx, rect.end.x - mx]
	var dw := [mx, rect.size.x - mx * 2.0, mx]
	var sy := [0.0, m, th - m]
	var sh := [m, th - m * 2.0, m]
	var dy := [rect.position.y, rect.position.y + my, rect.end.y - my]
	var dh := [my, rect.size.y - my * 2.0, my]
	for r in 3:
		for c in 3:
			draw_texture_rect_region(tex,
				Rect2(dx[c], dy[r], dw[c], dh[r]),
				Rect2(sx[c], sy[r], sw[c], sh[r]))

func _draw_icon(id: String, rect: Rect2) -> void:
	var pad := 6.0
	var inner := Rect2(rect.position + Vector2(pad, pad), rect.size - Vector2(pad * 2.0, pad * 2.0))
	match ItemCatalog.category_of(id):
		ItemCatalog.CAT_TOOL:
			# ★ [아트정리패스] 도구 아이콘(icons dict에 병합된 도구 텍스처). 없으면 옛 색박스 폴백.
			var ttex: Texture2D = crop_icons.get(id)
			if ttex != null:
				draw_texture_rect(ttex, inner, false)
			else:
				draw_rect(inner, ItemCatalog.tool_color_of(id))
		ItemCatalog.CAT_SEED:
			_draw_crop_tex(ItemCatalog.crop_of(id), inner)
		ItemCatalog.CAT_SAPLING:
			# ★ [S1-5b] 묘목 그레이박스 아이콘(핫바와 동일 — 밑동 갈색+새싹 초록).
			# ★ [아트정리패스] 묘목 아이콘(SAPLING_ICONS). 없으면 옛 밑동갈색+새싹초록 폴백.
			var stex: Texture2D = crop_icons.get(id)
			if stex != null:
				draw_texture_rect(stex, inner, false)
			else:
				draw_rect(inner, Color(0.42, 0.30, 0.20))
				draw_rect(Rect2(inner.position, Vector2(inner.size.x, inner.size.y * 0.45)), Color(0.35, 0.62, 0.35))
		ItemCatalog.CAT_HARVEST:
			_draw_crop_tex(id, inner)
		ItemCatalog.CAT_FERTILIZER:
			# ★ [아트정리패스] 비료 아이콘(icons dict에 병합된 FERT_ICONS). 없으면 옛 색박스 폴백.
			var ftex: Texture2D = crop_icons.get(id)
			if ftex != null:
				draw_texture_rect(ftex, inner, false)
			else:
				var fc := Color(0.40, 0.55, 0.32) if FertilizerCatalog.group_of(id) == "quality" else Color(0.30, 0.55, 0.55)
				draw_rect(inner, fc)

func _draw_crop_tex(crop_id: String, inner: Rect2) -> void:
	var tex: Texture2D = crop_icons.get(crop_id)
	if tex == null:
		var base := ItemCatalog._large_base(crop_id)   # 대형 산물(_large)이면 기준 아이콘 재사용
		if base != "":
			tex = crop_icons.get(base)
	if tex == null:
		draw_rect(inner, Color(0.8, 0.8, 0.8))
		return
	draw_texture_rect(tex, inner, false)

# ── 메뉴 상단(탭 바 + 탭별 내용) ──────────────────────────────────────────────
func _draw_menu_top(panel: Rect2) -> void:
	var font := ThemeDB.fallback_font
	# ★ [정체성 UI] 탭 4개 = 정사각 아이콘 탭(인벤토리·관계·숙련·옵션). 라벨 텍스트를 24×24 아이콘으로
	# 대체하고 폭을 좁힌다(owner 2026-07-05). 현재 탭은 밝은 한지 배경 + 아이콘 풀컬러, 비활성은
	# 어둡게 + 아이콘 감광(modulate). 한글명은 호버 툴팁으로.
	_tab_rects.clear()
	var tab_w := 34.0
	var tab_h := 32.0
	for i in TAB_COUNT:
		var r := Rect2(panel.position.x + PAD + i * (tab_w + GAP), panel.position.y + PAD, tab_w, tab_h)
		_tab_rects.append(r)
		var on := i == menu_tab
		draw_rect(r, Color(0.30, 0.22, 0.14, 0.85) if on else Color(0.14, 0.11, 0.08, 0.70))
		draw_rect(r, Color(0.95, 0.88, 0.60) if on else Color(0.50, 0.42, 0.30), false, 1.0)
		# 24×24 아이콘 중앙 정렬(비활성은 감광해 대비).
		var tex: Texture2D = TAB_ICONS[i]
		var isz := Vector2(24.0, 24.0)
		var ipos := r.position + (r.size - isz) * 0.5
		draw_texture_rect(tex, Rect2(ipos, isz), false,
			Color(1, 1, 1, 1) if on else Color(0.62, 0.62, 0.62, 0.9))
	# 호버 툴팁(아이콘만이라 첫 사용자 학습 보조 — 호버 탭 아래에 한글명 한지 칩).
	if _hover_tab >= 0 and _hover_tab < _tab_rects.size():
		_draw_tab_tooltip(font, _tab_rects[_hover_tab], TAB_LABELS[_hover_tab])
	match menu_tab:
		TAB_INV:
			_draw_inv_tab(panel, font)
		TAB_REL:
			_draw_rel_tab(panel, font)
		TAB_SKILL:
			_draw_skill_tab(panel, font)
		TAB_OPTIONS:
			_draw_options_tab(panel, font)

# ★ 아이콘 탭 호버 툴팁 — 호버 중인 탭 바로 아래에 한글명 한지 칩(어두운 박스 + 밝은 글자).
func _draw_tab_tooltip(font: Font, tab: Rect2, label: String) -> void:
	var fs := 12
	var tw: float = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var pad := 6.0
	var box := Rect2(tab.position.x, tab.end.y + 4.0, tw + pad * 2.0, 20.0)
	draw_rect(box, Color(0.10, 0.08, 0.06, 0.94))
	draw_rect(box, Color(0.55, 0.48, 0.32), false, 1.0)
	draw_string(font, box.position + Vector2(pad, 14.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 0.96, 0.84))

func _draw_inv_tab(panel: Rect2, font: Font) -> void:
	# [정리] 버튼 — 그리드 바로 위(설명 행) 우측에 앵커. 옛 위치(PAD+36)는 상단 빈 컨텍스트
	# 영역 한가운데 떠 보였다(owner 리포트 2026-07-06 "튀어나온다"). 설명은 짧게 줄여 좌측에 두어
	# 우측 버튼과 안 겹치게 한다(옛 긴 문구는 버튼까지 뻗어 겹쳤다).
	_sort_rect = Rect2(panel.end.x - PAD - 72.0, panel.position.y + TOP_H - 12.0, 72.0, 26.0)
	draw_rect(_sort_rect, Color(0.22, 0.20, 0.12, 0.85))
	draw_rect(_sort_rect, Color(0.55, 0.50, 0.35), false, 1.0)
	draw_string(font, _sort_rect.position + Vector2(16.0, 18.0), "정리", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 0.97, 0.88))
	draw_string(font, Vector2(panel.position.x + PAD, panel.position.y + TOP_H + 6.0),
		"슬롯을 클릭해 집어 다른 칸으로 옮긴다", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.82, 0.76, 0.66))

func _draw_rel_tab(panel: Rect2, font: Font) -> void:
	# 관계 탭: 하트는 HeartBar 자식이 그린다(_apply_heart_visibility 배치). 탭 바 아래에 '읽기 전용' 안내만
	# (4탭이 상단 폭을 다 써 우측 여백이 없음 — 탭 아래로 내린다).
	draw_string(font, Vector2(panel.position.x + PAD + 8.0, panel.position.y + PAD + 44.0),
		"관계 — 읽기 전용(호감도는 대화·활동으로)", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.78, 0.70, 0.58))
	# ★ C3 각 하트 행 아래에 그 캐릭터의 관계 곱셈기(여우불·마진·경비·할인) 한 줄. HeartBar와 같은
	# y 기준(panel.y + 64 + i*48)에서 한 칸(+40) 내려 그린다 — 상시 HUD에서 걷어낸 정보를 여기서 복기.
	for i in _heart_effects.size():
		var eff: String = str(_heart_effects[i])
		if eff == "":
			continue
		var ey := panel.position.y + 64.0 + i * 48.0 + 40.0
		draw_string(font, Vector2(panel.position.x + PAD + 12.0, ey), eff,
			HORIZONTAL_ALIGNMENT_LEFT, panel.size.x - PAD * 2.0 - 12.0, 12, Color(0.82, 0.78, 0.70))

# ★ Phase B 숙련 탭 — main이 넘긴 _skill_rows를 레벨·진행바로 그린다(읽기 전용, 관계 탭과 대칭).
func _draw_skill_tab(panel: Rect2, font: Font) -> void:
	_prof_choice_rects.clear()   # ★ ADR-0052 — 클릭 영역은 매 그리기마다 재구성(레이아웃 파생)
	var x := panel.position.x + PAD + 12.0
	var y := panel.position.y + PAD + 52.0
	if _skill_rows.is_empty():
		draw_string(font, Vector2(x, y), "숙련 정보 없음", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.72, 0.66, 0.56))
		return
	var bar_w := panel.size.x - PAD * 2.0 - 24.0
	for row in _skill_rows:
		var lv := int(row.get("level", 0))
		var mx := int(row.get("max", 10))
		var xp := int(row.get("xp", 0))
		var floor_xp := int(row.get("floor_xp", 0))
		var next_xp := int(row.get("next_xp", 0))
		var maxed := next_xp <= 0
		var head := "%s   Lv.%d%s" % [str(row.get("name", "")), lv, (" (MAX)" if maxed else "/%d" % mx)]
		draw_string(font, Vector2(x, y), head, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(1, 0.97, 0.88))
		# 진행바(한지 plate 트랙 + 앰버 채움).
		var track := Rect2(x, y + 8.0, bar_w, 12.0)
		draw_rect(track, Color(0.14, 0.11, 0.08, 0.85))
		draw_rect(track, Color(0.50, 0.42, 0.30), false, 1.0)
		var frac := 1.0 if maxed else clampf(float(xp - floor_xp) / float(maxi(next_xp - floor_xp, 1)), 0.0, 1.0)
		if frac > 0.0:
			draw_rect(Rect2(track.position, Vector2(track.size.x * frac, track.size.y)), Color(0.90, 0.66, 0.28))
		var tail := "만렙" if maxed else "%d / %d XP" % [xp - floor_xp, next_xp - floor_xp]
		draw_string(font, Vector2(x, y + 34.0), tail, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.82, 0.76, 0.66))
		y += 50.0
		# ★ ADR-0052 — 고른 전문직 요약.
		var prof := String(row.get("profession", ""))
		if prof != "":
			draw_string(font, Vector2(x, y), "전문직: %s" % prof, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.86, 0.78, 0.60))
			y += 20.0
		# ★ ADR-0052 — 선택 대기(pending) 시 2갈래 버튼(name + desc). 클릭 영역을 _prof_choice_rects에 등록.
		var options: Array = row.get("options", [])
		if not options.is_empty():
			var skill := String(row.get("skill", ""))
			draw_string(font, Vector2(x, y), "▶ 전문직 선택 (Lv.%d):" % int(row.get("pending_tier", 0)), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.95, 0.85, 0.45))
			y += 22.0
			for opt in options:
				var btn := Rect2(x + 8.0, y, bar_w - 16.0, 30.0)
				draw_rect(btn, Color(0.20, 0.24, 0.16, 0.88))
				draw_rect(btn, Color(0.60, 0.64, 0.42), false, 1.0)
				draw_string(font, btn.position + Vector2(10.0, 13.0), String(opt.get("name", "")), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 0.97, 0.88))
				draw_string(font, btn.position + Vector2(10.0, 26.0), String(opt.get("desc", "")), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.80, 0.74, 0.62))
				_prof_choice_rects.append({"rect": btn, "skill": skill, "prof_id": String(opt.get("id", ""))})
				y += 34.0
		y += 14.0   # 행 간 여백

# ★ Phase B 액션(저장·나가기) + ★ Phase D 설정 본체(음악·효과음 볼륨 −/+, 전체화면 토글, 언어=한국어 고정).
# 값은 main이 GameSettings에서 set_settings로 주입한 것을 읽어 바·체크박스로만 그린다(무상태 — 조작은
# 신호로 main에 올려 실제 볼륨·창모드·영속을 main이 수행, _click_menu TAB_OPTIONS 라우팅).
func _draw_options_tab(panel: Rect2, font: Font) -> void:
	var x := panel.position.x + PAD + 12.0
	var y := panel.position.y + PAD + 42.0
	_save_rect = Rect2(x, y, 200.0, 28.0)
	draw_rect(_save_rect, Color(0.20, 0.24, 0.16, 0.85))
	draw_rect(_save_rect, Color(0.55, 0.60, 0.40), false, 1.0)
	draw_string(font, _save_rect.position + Vector2(14.0, 19.0), "저장", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 0.97, 0.88))
	_quit_rect = Rect2(x, y + 34.0, 200.0, 28.0)
	draw_rect(_quit_rect, Color(0.28, 0.16, 0.14, 0.85))
	draw_rect(_quit_rect, Color(0.62, 0.42, 0.36), false, 1.0)
	draw_string(font, _quit_rect.position + Vector2(14.0, 19.0), "저장하고 나가기", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 0.94, 0.86))
	# ── ★ Phase D 설정 본체 ──
	# ★ 구분선을 볼륨 행과 확실히 띄운다 — 옛 (sy=y+84, 구분선 sy-8)은 "── 설정 ──"이 "음악 볼륨"
	#   라벨과 겹쳤다(owner 리포트 2026-07-06). 구분선을 위로(y+80)·첫 행을 아래로(y+104) 분리.
	draw_string(font, Vector2(x, y + 80.0), "── 설정 ──", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.90, 0.86, 0.60))
	var sy := y + 104.0
	var r1 := _draw_volume_row(font, x, sy, "음악 볼륨", _set_music)
	_music_minus_rect = r1[0]
	_music_plus_rect = r1[1]
	sy += 34.0
	var r2 := _draw_volume_row(font, x, sy, "효과음 볼륨", _set_sfx)
	_sfx_minus_rect = r2[0]
	_sfx_plus_rect = r2[1]
	# 전체화면 체크박스.
	sy += 38.0
	_fullscreen_rect = Rect2(x, sy - 14.0, 18.0, 18.0)
	draw_rect(_fullscreen_rect, Color(0.14, 0.11, 0.08, 0.90))
	draw_rect(_fullscreen_rect, Color(0.55, 0.50, 0.35), false, 1.0)
	if _set_fullscreen:
		draw_rect(_fullscreen_rect.grow(-4.0), Color(0.90, 0.66, 0.28))
	draw_string(font, Vector2(x + 26.0, sy), "전체화면", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 0.97, 0.88))
	draw_string(font, Vector2(x + 120.0, sy), "(F11)", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.72, 0.66, 0.56))
	# 언어(한국어 고정 — 표시만, ADR-0048 §2).
	sy += 30.0
	draw_string(font, Vector2(x, sy), "언어  한국어 (고정)", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.72, 0.66, 0.56))

# ★ Phase D 볼륨 한 줄(라벨 · [−] · 트랙바 · [+] · 백분율). [−]/[+] 버튼 Rect2 둘을 배열로 돌려준다.
func _draw_volume_row(font: Font, x: float, yy: float, label: String, v01: float) -> Array:
	draw_string(font, Vector2(x, yy), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.90, 0.86, 0.66))
	var minus := Rect2(x + 92.0, yy - 14.0, 20.0, 18.0)
	draw_rect(minus, Color(0.22, 0.20, 0.12, 0.85))
	draw_rect(minus, Color(0.55, 0.50, 0.35), false, 1.0)
	draw_string(font, minus.position + Vector2(7.0, 15.0), "-", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 0.97, 0.88))
	var track := Rect2(x + 118.0, yy - 12.0, 96.0, 12.0)
	draw_rect(track, Color(0.14, 0.11, 0.08, 0.85))
	draw_rect(track, Color(0.50, 0.42, 0.30), false, 1.0)
	if v01 > 0.0:
		draw_rect(Rect2(track.position, Vector2(track.size.x * clampf(v01, 0.0, 1.0), track.size.y)), Color(0.90, 0.66, 0.28))
	var plus := Rect2(x + 220.0, yy - 14.0, 20.0, 18.0)
	draw_rect(plus, Color(0.22, 0.20, 0.12, 0.85))
	draw_rect(plus, Color(0.55, 0.50, 0.35), false, 1.0)
	draw_string(font, plus.position + Vector2(6.0, 15.0), "+", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(1, 0.97, 0.88))
	draw_string(font, Vector2(x + 248.0, yy), "%d%%" % roundi(v01 * 100.0), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 0.97, 0.88))
	return [minus, plus]

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

# ── ★ Phase D 저장 상자 상단(보관 슬롯 그리드) ────────────────────────────────
# 상단 컨텍스트 영역에 상자 슬롯을 백팩과 같은 6열 그리드로 그린다(하단=백팩, 상단=상자). 클릭은
# _click_chest가 라우팅한다(백팩 슬롯 클릭=보관 / 상자 슬롯 클릭=회수 — bin 드롭의 양방향 판).
func _draw_chest_top(panel: Rect2) -> void:
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(panel.position.x + PAD, panel.position.y + PAD + 18.0),
		"저장 상자", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.90, 0.86, 0.60))
	draw_string(font, Vector2(panel.position.x + PAD, panel.position.y + PAD + 38.0),
		"백팩 아이템 클릭=보관   ·   상자 아이템 클릭=회수 (판매 아님 — 순수 보관)",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.70, 0.70, 0.75))
	_chest_rects.clear()
	if chest == null:
		return
	_chest_rects.resize(StorageChest.SIZE)
	var origin := Vector2(panel.position.x + PAD, panel.position.y + PAD + 48.0)
	for i in StorageChest.SIZE:
		var col := i % COLS
		var row := i / COLS
		var pos := origin + Vector2(col * (SLOT + GAP), row * (SLOT + GAP))
		var rect := Rect2(pos, Vector2(SLOT, SLOT))
		_chest_rects[i] = rect
		_draw_slot_box(rect, false)
		var id := chest.id_at(i)
		if id != "":
			_draw_icon(id, rect)
			var q := chest.quality_at(i)
			if q > 0:
				draw_circle(pos + Vector2(8.0, SLOT - 8.0), 4.0, _quality_color(q))
			var n := chest.count_at(i)
			if n > 1:
				draw_string(font, pos + Vector2(SLOT - 16.0, SLOT - 5.0), str(n), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)

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
	# ★ 아이콘 탭 호버 추적(메뉴 컨텍스트만) — 클릭과 무관하게 마우스 이동으로 툴팁 갱신.
	if event is InputEventMouseMotion:
		_update_hover_tab(event.position)
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
		CTX_CHEST:
			_click_chest(p)
	accept_event()

# ★ 마우스 호버 탭 갱신(메뉴 컨텍스트만) — 바뀔 때만 다시 그린다(툴팁 표시).
func _update_hover_tab(p: Vector2) -> void:
	var h := -1
	if context == CTX_MENU:
		for i in _tab_rects.size():
			if _tab_rects[i].has_point(p):
				h = i
				break
	if h != _hover_tab:
		_hover_tab = h
		queue_redraw()

func _click_menu(p: Vector2) -> void:
	# 탭 전환.
	for i in _tab_rects.size():
		if _tab_rects[i].has_point(p):
			set_tab(i)
			return
	# ★ Phase B/D 옵션 탭: 저장·나가기(신호) + ★ Phase D 볼륨 −/+·전체화면(신호 — main이 실제 적용·영속).
	if menu_tab == TAB_OPTIONS:
		const VOL_STEP := 0.1
		if _save_rect.has_point(p):
			save_pressed.emit()
		elif _quit_rect.has_point(p):
			quit_pressed.emit()
		elif _music_minus_rect.has_point(p):
			music_vol_changed.emit(-VOL_STEP)
		elif _music_plus_rect.has_point(p):
			music_vol_changed.emit(VOL_STEP)
		elif _sfx_minus_rect.has_point(p):
			sfx_vol_changed.emit(-VOL_STEP)
		elif _sfx_plus_rect.has_point(p):
			sfx_vol_changed.emit(VOL_STEP)
		elif _fullscreen_rect.has_point(p):
			fullscreen_toggled.emit()
		return
	# ★ ADR-0052 숙련 탭: 전문직 선택 버튼(신호 — main이 choose_profession + 갱신). 옵션 탭과 같은 결.
	if menu_tab == TAB_SKILL:
		for e in _prof_choice_rects:
			if e["rect"].has_point(p):
				profession_chosen.emit(String(e["skill"]), String(e["prof_id"]))
				return
		return
	if menu_tab != TAB_INV:
		return   # 관계 탭은 읽기 전용(본문 클릭 없음)
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

# ★ Phase D 저장 상자 클릭: 백팩 슬롯=보관(chest_store) / 상자 슬롯=회수(chest_take). 출하함과 달리
# 아이템 종류 제한이 없다(도구·씨앗·수확물 다 보관 가능 — 순수 보관). main이 실제 이동을 조율한다.
func _click_chest(p: Vector2) -> void:
	for i in _bp_rects.size():
		if _bp_rects[i].has_point(p):
			chest_store.emit(i)
			return
	for i in _chest_rects.size():
		if _chest_rects[i].has_point(p):
			chest_take.emit(i)
			return
