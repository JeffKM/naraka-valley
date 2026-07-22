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
signal buy_pressed(bulk: bool)         # 매대: 선택 씨앗 구매(bulk=Shift 대량 — 회귀 호환 유지)
signal buy_sprinkler_pressed(bulk: bool)  # ★ [S1R-T9] 매대: 저승 스프링클러 구매(bulk=Shift 대량)
signal buy_seed(crop_id: String, bulk: bool)  # ★ [S1R-T12] 매대 그리드: 특정 작물 씨앗 구매(행별 버튼)
signal close_pressed                   # ★ [S1R-T12] 우상단 X: 메뉴/패널 닫기(main이 _close_frame)
signal discard_slot(slot_index: int)   # ★ [S1R-T12] 휴지통: 집은 백팩 슬롯을 통째로 버림(확인 후)
signal save_pressed                    # ★ Phase B 옵션 탭: 저장(main이 _save_game 호출)
signal quit_pressed                    # ★ Phase B 옵션 탭: 저장하고 나가기
signal chest_store(slot_index: int)    # ★ Phase D 상자: 백팩 슬롯을 통째로 상자에 보관
signal chest_take(chest_index: int)    # ★ Phase D 상자: 상자 슬롯을 통째로 백팩으로 회수
signal music_vol_changed(delta: float) # ★ Phase D 설정: 음악 볼륨 증감(옵션 탭 −/+)
signal sfx_vol_changed(delta: float)   # ★ Phase D 설정: 효과음 볼륨 증감(옵션 탭 −/+)
signal fullscreen_toggled              # ★ Phase D 설정: 전체화면 토글(옵션 탭 체크박스)
signal profession_chosen(skill: String, prof_id: String)   # ★ ADR-0052 숙련 탭: 전문직 선택(main이 choose_profession)

# ★ [S1R-T11 / ADR-0048 실행] 내부 스킨·타이포를 HanjiUi 공용 문법으로 통일한다(신규 에셋 0).
# 셸(패널)·슬롯·버튼·탭·툴팁·바를 hanji_ui.gd 헬퍼(draw_frame/draw_plate/draw_text·팔레트 상수)로
# 그려, 핫바·시계·혼력 등 상시 HUD와 같은 태운 한지 톤을 공유한다(옛 raw draw_rect 색박스·
# 폴백 폰트·색박스 제거). 규격 박제(ADR-0025)는 HanjiUi에 중앙화(FRAME_MARGIN 22 / PLATE 12).
# FRAME_MARGIN은 패널 레이아웃 계산에도 쓰므로 로컬 상수로 남긴다(HanjiUi.FRAME_MARGIN과 동일 값).
const FRAME_MARGIN := 22.0

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

# ★ [S1R-T12] 엽전 아이콘(가격·소지금 표시 — clock_hud와 동일 에셋, 정체성 통일).
const COIN: Texture2D = preload("res://assets/ui/gold_coin.png")

# 컨텍스트(상단 레이어). NONE이면 닫힘(보이지 않음). ★ Phase D — CTX_CHEST(저장 상자) 추가.
enum { CTX_NONE, CTX_MENU, CTX_BIN, CTX_STORE, CTX_CHEST }
# 메뉴 탭(인벤토리 · 관계 · 숙련 · 옵션 — ADR-0048 §2 통합 탭 메뉴).
enum { TAB_INV, TAB_REL, TAB_SKILL, TAB_OPTIONS }
const TAB_COUNT := 4

const COLS := 6                  # 백팩·상자 공통 그리드 가로 칸 수(6열)
const SLOT := 48.0               # 슬롯 한 변(px)
const GAP := 4.0
const PAD := 26.0                # ★ 패널 안쪽 여백 — 9-slice 테두리(FRAME_MARGIN=22)보다 커야 슬롯·글자가
                                 #   나무 테두리 밑으로 파고들지 않는다(옛 16 < 22라 좌우 열이 6px 겹쳤다).
const TOP_H := 132.0             # 상단 컨텍스트 영역 높이
# ★ 백팩 스크롤(owner 2026-07-06) — 용량이 늘어도 패널이 틀 밖으로 안 넘치게, 백팩 그리드를 고정
# 높이 뷰포트(BP_VIS_ROWS행)로 보여주고 총 행이 더 많으면 세로 스크롤한다(휠·스크롤바). Inventory.SIZE=16은
# 6열×3행 → 2행 뷰포트라 스크롤바가 바로 뜬다. 패널 세로는 이 행 수로 고정(용량과 분리).
const BP_VIS_ROWS := 2           # 백팩 뷰포트에 한 번에 보이는 행 수(총 행 > 이 값이면 스크롤)
const SCROLLBAR_W := 6.0         # 백팩 스크롤바 폭

var inv: Inventory = null
var bin: ShippingBin = null
var chest: StorageChest = null   # ★ Phase D 저장 상자(CTX_CHEST 상단 그리드 — main이 set_chest로 주입)
var crop_icons: Dictionary = {}
# main이 매 프레임 채워 넣는 보조 텍스트(매대 헤더·정산 미리보기 등) — 프레임은 표시만.
var store_text: String = ""
# ★ [S1R-T12] 매대 아이템 행 데이터(main이 _store_items로 주입 — 무상태 렌더). 각 항목:
#   {icon_id, name, price, base, owned, kind("seed"/"placeable"), buy_id}. price<base면 할인 표시.
var store_items: Array = []
# ★ [S1R-T12] 인벤토리 탭 정보패널 값(main이 set_inv_info로 주입 — 무상태 표시).
var _inv_gold := 0
var _inv_income := 0
var _inv_date := ""
var _inv_farm := "안식 농원"

var context := CTX_NONE
var menu_tab := TAB_INV
var _held := -1                  # 메뉴 인벤토리 탭에서 집어 든 백팩 슬롯(-1=없음)
var _hover_tab := -1             # ★ 마우스가 호버 중인 메뉴 탭(-1=없음) — 아이콘 탭 툴팁용
# ★ 백팩 스크롤 상태(행 단위 스냅 — 부분 행이 없어 클리핑 불필요). first_row = 뷰포트 최상단에 보이는 행.
var _bp_first_row := 0           # 0.._bp_max_first_row(); 휠·스크롤바로 이동
var _bp_scroll_dragging := false # 스크롤바 썸을 잡고 드래그 중

# 히트 테스트 캐시(_draw에서 채우고 _gui_input에서 읽는다).
var _bp_rects: Array = []        # 백팩 12칸 Rect2
var _bin_rects: Array = []       # 출하함 대기 슬롯 [{rect, id}]
var _chest_rects: Array = []     # ★ Phase D 상자 슬롯 Rect2(인덱스=상자 슬롯 번호)
var _tab_rects: Array = []       # 메뉴 탭 4개 Rect2
var _bp_track_rect := Rect2()    # ★ 백팩 스크롤바 트랙(_draw_backpack이 채움 — 없으면 size 0)
var _bp_thumb_rect := Rect2()    # ★ 백팩 스크롤바 썸(드래그·점프 히트)
var _sort_rect := Rect2()
var _buy_rect := Rect2()
var _buy_sprinkler_rect := Rect2()   # ★ [S1R-T9] 매대 스프링클러 구매 버튼
# ★ [S1R-T12] 매대 그리드 행별 구매 버튼 히트 [{rect, kind, buy_id}] + 우상단 닫기 X + 휴지통.
var _store_row_rects: Array = []
var _close_rect := Rect2()            # 우상단 닫기 X(모든 컨텍스트)
var _trash_rect := Rect2()           # 인벤 탭 휴지통 슬롯(집은 상태로 클릭=버리기)
var _trash_pending := -1             # 버리기 확인 대기 중인 백팩 슬롯(-1=없음)
var _trash_yes_rect := Rect2()       # 확인 오버레이 [버리기]
var _trash_no_rect := Rect2()        # 확인 오버레이 [취소]
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
	_trash_pending = -1         # ★ 열 때 버리기 확인 대기 해제
	_bp_first_row = 0            # ★ 열 때 백팩 스크롤 맨 위로
	_bp_scroll_dragging = false
	visible = true
	_apply_heart_visibility()
	queue_redraw()

# 프레임을 닫는다.
func close() -> void:
	context = CTX_NONE
	_held = -1
	_trash_pending = -1
	_hover_tab = -1
	_bp_scroll_dragging = false
	visible = false
	_apply_heart_visibility()

func is_open() -> bool:
	return context != CTX_NONE

# 메뉴 탭을 바꾼다(인벤토리 ↔ 관계).
func set_tab(t: int) -> void:
	menu_tab = t
	_held = -1
	_trash_pending = -1
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

# ★ [S1R-T12] 인벤토리 탭 정보패널 값 주입(읽기 전용 — 소지금·총수입·날짜·농장명). main이 wallet·
# clock·누적 통계에서 파생해 인벤 탭이 열려 있을 때 넘긴다(set_settings·set_skills와 대칭, 무상태).
func set_inv_info(gold: int, income: int, date_str: String, farm_name: String) -> void:
	_inv_gold = gold
	_inv_income = income
	_inv_date = date_str
	if farm_name != "":
		_inv_farm = farm_name
	if context == CTX_MENU and menu_tab == TAB_INV:
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
			# 탭 바(y: PAD..PAD+32)·안내 문구(PAD+50) 아래로 내려 겹치지 않게 한다. ★ 기준을 PAD 반영으로
			# 통일 — 옛 하드코딩 +64는 PAD를 안 타 안내 문구(PAD+44)와 겹쳤다(owner 리포트 2026-07-06).
			# ★ C3 — 행마다 효과 줄을 한 칸 더 끼우므로 간격 48(하트 + 그 아래 곱셈기 한 줄 = 한 캐릭터 묶음).
			hb.position = Vector2(panel.position.x + PAD + 8.0, panel.position.y + PAD + 60.0 + i * 48.0)

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
	# 패널 폭 = 백팩 그리드 + 좌우 여백 + 스크롤바 자리(항상 확보 — 스크롤 유무로 폭이 안 바뀌게).
	# 세로 = 상단 컨텍스트(TOP_H) + 뷰포트(BP_VIS_ROWS행, 고정) + 상하 여백. ★ 하단은 프레임 9-slice
	# 테두리(FRAME_MARGIN)만큼 더 띄운다 — 옵션 탭 막줄·그리드 막줄이 나무 테두리에 안 걸치게
	# (owner 리포트 2026-07-06). 뷰포트가 고정이라 용량이 늘어도 패널이 틀 밖으로 안 넘친다(스크롤로 흡수).
	var grid_w := COLS * SLOT + (COLS - 1) * GAP
	var w := grid_w + PAD * 2.0 + SCROLLBAR_W + 6.0
	var grid_h := BP_VIS_ROWS * SLOT + (BP_VIS_ROWS - 1) * GAP
	var h := TOP_H + grid_h + PAD * 2.0 + FRAME_MARGIN + 6.0
	return Rect2((view.x - w) * 0.5, (view.y - h) * 0.5, w, h)

# ── 백팩 스크롤 계산(행 단위 스냅) ──────────────────────────────────────────────
func _bp_total_rows() -> int:
	return ceili(float(Inventory.SIZE) / float(COLS))

func _bp_max_first_row() -> int:
	return maxi(0, _bp_total_rows() - BP_VIS_ROWS)

# 백팩 하단 그리드가 그려지는 컨텍스트인가(관계·숙련·옵션 탭은 백팩을 안 그림).
func _backpack_visible() -> bool:
	if context == CTX_BIN or context == CTX_STORE or context == CTX_CHEST:
		return true
	return context == CTX_MENU and menu_tab == TAB_INV

func _scroll_bp(dir: int) -> void:
	var nf := clampi(_bp_first_row + dir, 0, _bp_max_first_row())
	if nf != _bp_first_row:
		_bp_first_row = nf
		queue_redraw()

# 썸 드래그/트랙 클릭 — 포인터 y를 트랙 범위에 매핑해 first_row를 잡는다.
func _drag_bp_scroll(p: Vector2) -> void:
	var mx := _bp_max_first_row()
	if mx == 0 or _bp_track_rect.size.y <= 0.0:
		return
	var t := clampf((p.y - _bp_track_rect.position.y) / _bp_track_rect.size.y, 0.0, 1.0)
	var nf := roundi(t * mx)
	if nf != _bp_first_row:
		_bp_first_row = nf
		queue_redraw()

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
	# ★ 한지 9-slice 패널(HanjiUi 공용 셸). 안쪽을 살짝 어둡게 깔아 슬롯·글자 대비를 확보
	# (한지 중앙이 밝아 아이콘이 묻히지 않게 — 이 위엔 밝은 글자 INK_LIGHT/INK_DIM을 쓴다).
	HanjiUi.draw_frame(self, panel)
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
	# ★ [S1R-T12] 우상단 닫기 X — 모든 컨텍스트 공통(스타듀 패널 닫기 문법). 9-slice 테두리 안쪽 모서리.
	_draw_close_x(panel)
	# ★ [S1R-T12] 버리기 확인 오버레이(집은 아이템 휴지통) — 대기 중이면 맨 위에 모달로.
	if _trash_pending >= 0:
		_draw_trash_confirm(panel)

# ★ [S1R-T12] 우상단 닫기 X 버튼(한지 plate + 먹빛 X). 클릭 시 close_pressed(main이 _close_frame).
func _draw_close_x(panel: Rect2) -> void:
	var sz := 22.0
	_close_rect = Rect2(panel.end.x - FRAME_MARGIN - sz + 2.0, panel.position.y + FRAME_MARGIN - 4.0, sz, sz)
	HanjiUi.draw_plate(self, _close_rect)
	var c := _close_rect
	var m := 6.0
	draw_line(c.position + Vector2(m, m), c.end - Vector2(m, m), HanjiUi.INK_LIGHT, 2.0)
	draw_line(Vector2(c.end.x - m, c.position.y + m), Vector2(c.position.x + m, c.end.y - m), HanjiUi.INK_LIGHT, 2.0)

# ★ [S1R-T12] 버리기 확인 — 화면 중앙 작은 한지 패널 + [버리기]/[취소]. 확인 1회(스타듀 파괴 방어).
func _draw_trash_confirm(panel: Rect2) -> void:
	var view := _view()
	draw_rect(Rect2(Vector2.ZERO, view), Color(0, 0, 0, 0.35))   # 이중 백드롭(모달 강조)
	var w := 260.0
	var h := 108.0
	var box := Rect2((view.x - w) * 0.5, (view.y - h) * 0.5, w, h)
	HanjiUi.draw_frame(self, box)
	var name := ""
	if inv != null and _trash_pending < Inventory.SIZE:
		name = ItemCatalog.name_of(inv.id_at(_trash_pending))
	HanjiUi.draw_text(self, box.position + Vector2(24.0, 34.0),
		"%s 을(를) 버릴까요?" % name, 14, HanjiUi.INK_LIGHT, w - 40.0)
	_trash_yes_rect = Rect2(box.position.x + 24.0, box.end.y - 40.0, 96.0, 26.0)
	_plate_btn(_trash_yes_rect)
	draw_rect(_trash_yes_rect, Color(0.72, 0.40, 0.34), false, 1.0)   # 파괴적 액센트
	HanjiUi.draw_text(self, _trash_yes_rect.position + Vector2(24.0, 18.0), "버리기", 14, Color(0.95, 0.72, 0.66))
	_trash_no_rect = Rect2(box.end.x - 24.0 - 96.0, box.end.y - 40.0, 96.0, 26.0)
	_plate_btn(_trash_no_rect)
	HanjiUi.draw_text(self, _trash_no_rect.position + Vector2(32.0, 18.0), "취소", 14, HanjiUi.INK_LIGHT)

# 공통 백팩 그리드(하단 고정 + 세로 스크롤). 뷰포트에 보이는 행만 그리고, 그 위치를 _bp_rects에
# 저장한다(뷰포트 밖 슬롯은 빈 Rect2 = 히트 없음). 행 단위 스냅이라 부분 행이 없어 클리핑이 필요 없다.
func _draw_backpack(panel: Rect2) -> void:
	_bp_rects.clear()
	_bp_rects.resize(Inventory.SIZE)
	_bp_first_row = clampi(_bp_first_row, 0, _bp_max_first_row())   # 용량 변화 방어
	var origin := _grid_origin(panel)
	for i in Inventory.SIZE:
		var col := i % COLS
		var row := i / COLS
		var vrow := row - _bp_first_row              # 뷰포트 기준 행(0..BP_VIS_ROWS-1이면 보임)
		if vrow < 0 or vrow >= BP_VIS_ROWS:
			_bp_rects[i] = Rect2()                   # 뷰포트 밖 — 히트 없음(빈 rect)
			continue
		var pos := origin + Vector2(col * (SLOT + GAP), vrow * (SLOT + GAP))
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
				HanjiUi.draw_text(self, pos + Vector2(SLOT - 16.0, SLOT - 5.0),
					str(n), 13, HanjiUi.INK_LIGHT)
	_draw_bp_scrollbar(panel, origin)

# 백팩 스크롤바(총 행 > 뷰포트일 때만). 트랙 + 썸(보이는 비율만큼 높이, first_row만큼 내림). 그리드
# 우측 여백에 세로로. 트랙/썸 Rect2를 캐시해 _gui_input이 드래그·트랙 점프에 쓴다.
func _draw_bp_scrollbar(panel: Rect2, origin: Vector2) -> void:
	_bp_track_rect = Rect2()
	_bp_thumb_rect = Rect2()
	var total := _bp_total_rows()
	if total <= BP_VIS_ROWS:
		return                                       # 다 보이면 스크롤바 없음
	var vis_h := BP_VIS_ROWS * SLOT + (BP_VIS_ROWS - 1) * GAP
	var bar_x := origin.x + COLS * (SLOT + GAP) - GAP + 6.0
	var track := Rect2(bar_x, origin.y, SCROLLBAR_W, vis_h)
	_bp_track_rect = track
	draw_rect(track, HanjiUi.INSET)
	draw_rect(track, HanjiUi.BORDER, false, 1.0)
	var thumb_h := maxf(vis_h * float(BP_VIS_ROWS) / float(total), 16.0)
	var mx := _bp_max_first_row()
	var t := 0.0 if mx == 0 else float(_bp_first_row) / float(mx)
	var thumb := Rect2(bar_x, track.position.y + (vis_h - thumb_h) * t, SCROLLBAR_W, thumb_h)
	_bp_thumb_rect = thumb
	draw_rect(thumb, HanjiUi.GOLD)

# 품질 등급 색(그레이박스 배지 — 은/금/이리듐). hotbar_hud와 동일 팔레트(뷰 책임, 카탈로그 무결합).
func _quality_color(q: int) -> Color:
	match q:
		1: return Color(0.78, 0.80, 0.85)   # 은
		2: return Color(0.96, 0.80, 0.25)   # 금
		3: return Color(0.60, 0.38, 0.88)   # 이리듐
		_: return Color.WHITE

func _draw_slot_box(rect: Rect2, highlight: bool) -> void:
	# ★ [S1R-T11] 슬롯 = 핫바와 동일한 태운 한지 plate(HanjiUi.draw_plate — 같은 텍스처·인셋). 집어 든
	#   슬롯은 밝은 금박 테두리를 덧그려 강조한다(핫바 선택 칸과 정합, 슬롯 룩 분열 해소).
	HanjiUi.draw_plate(self, rect)
	if highlight:
		draw_rect(rect, HanjiUi.GOLD_SOFT, false, 2.0)

# ★ [S1R-T11] 한지 버튼 바탕 — 핫바 슬롯과 같은 태운 한지 plate(HanjiUi.draw_plate). 라벨은
# 호출부가 HanjiUi.draw_text로 얹는다(raw draw_rect 색박스 버튼 → 공용 스킨 통일).
func _plate_btn(rect: Rect2, on := false) -> void:
	HanjiUi.draw_plate(self, rect)
	if on:
		draw_rect(rect, HanjiUi.GOLD_SOFT, false, 2.0)

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
		ItemCatalog.CAT_MATERIAL:
			# ★ 재료(건초·개간 드랍) — 케이스 누락으로 아이콘 없이 개수만 뜨던 버그 방어(owner 리포트
			#   2026-07-06 "6" 슬롯). 텍스처 있으면 쓰고, 없으면 건초=짚 금색·재료=흙 갈색 그레이박스.
			var mtex: Texture2D = crop_icons.get(id)
			if mtex != null:
				draw_texture_rect(mtex, inner, false)
			else:
				draw_rect(inner, Color(0.80, 0.66, 0.30) if ItemCatalog._is_hay(id) else Color(0.46, 0.36, 0.26))
		ItemCatalog.CAT_PLACEABLE:
			# ★ [S1R-T9] 설치물(스프링클러) 그레이박스 아이콘(핫바와 동일 — 청록 몸통 + 물방울 점).
			draw_rect(inner, Color(0.32, 0.52, 0.60))
			draw_circle(inner.position + Vector2(inner.size.x * 0.5, inner.size.y * 0.28), inner.size.x * 0.14, Color(0.62, 0.82, 0.92))

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
	var font := HanjiUi.font()
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
		HanjiUi.draw_plate(self, r, 1.0 if on else 0.55)
		if on:
			draw_rect(r, HanjiUi.GOLD_SOFT, false, 1.0)
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

# ★ 아이콘 탭 호버 툴팁 — 한글명 한지 칩(어두운 박스 + 밝은 글자).
# 위치 = 탭 바 우측 빈 공간(탭 행과 같은 높이). 옛 위치(호버 탭 바로 아래 tab.end.y+4)는 탭 칸 밖
# 아래로 삐져나와 곧바로 밑 내용(저장 버튼·설명)과 겹쳤다(owner 리포트 2026-07-06 "튀어나온다").
func _draw_tab_tooltip(font: Font, tab: Rect2, label: String) -> void:
	var fs := 12
	var tw: float = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var pad := 6.0
	var last: Rect2 = _tab_rects[_tab_rects.size() - 1]   # 마지막 탭 우측 = 항상 빈 공간(탭 4개는 좌측만 씀)
	var box := Rect2(last.end.x + 12.0, tab.position.y + (tab.size.y - 20.0) * 0.5, tw + pad * 2.0, 20.0)
	# HUD 툴팁(hud_tooltip.gd)과 같은 한지 칩 — 어두운 인셋 + 따뜻한 테두리 + 밝은 먹빛 외곽선 글자.
	draw_rect(box, Color(HanjiUi.INSET.r, HanjiUi.INSET.g, HanjiUi.INSET.b, 0.92))
	draw_rect(box, HanjiUi.BORDER, false, 1.0)
	HanjiUi.draw_text(self, box.position + Vector2(pad, 14.0), label, fs, HanjiUi.INK_LIGHT)

func _draw_inv_tab(panel: Rect2, font: Font) -> void:
	# ★ [S1R-T12] 정보패널 — 탭 바 아래 한지 plate. 농장명·날짜·소지금·총수입을 스타듀 인벤 좌측
	# 정보열처럼 한자리에 모은다(상시 HUD에서 걷어낸 골드·날짜를 여기서 복기). 우측엔 휴지통 슬롯.
	var plate := Rect2(panel.position.x + PAD, panel.position.y + PAD + 36.0,
		panel.size.x - PAD * 2.0, 74.0)
	HanjiUi.draw_plate(self, plate)
	var ix := plate.position.x + 12.0
	HanjiUi.draw_text(self, Vector2(ix, plate.position.y + 20.0), _inv_farm, 15, HanjiUi.GOLD_SOFT,
		plate.size.x - 90.0)
	HanjiUi.draw_text(self, Vector2(ix, plate.position.y + 40.0), _inv_date, 13, HanjiUi.INK_LIGHT)
	# 소지금(엽전 + 골드) · 총수입(엽전 + 누적) 한 줄.
	var gy := plate.position.y + 60.0
	HanjiUi.draw_text(self, Vector2(ix, gy), "소지금", 12, HanjiUi.INK_DIM)
	var cx := ix + 44.0
	draw_texture_rect(COIN, Rect2(cx, gy - 11.0, 12.0, 12.0), false)
	HanjiUi.draw_text(self, Vector2(cx + 15.0, gy), str(_inv_gold), 13, HanjiUi.GOLD)
	var ix2 := ix + 150.0
	HanjiUi.draw_text(self, Vector2(ix2, gy), "총수입", 12, HanjiUi.INK_DIM)
	var cx2 := ix2 + 44.0
	draw_texture_rect(COIN, Rect2(cx2, gy - 11.0, 12.0, 12.0), false)
	HanjiUi.draw_text(self, Vector2(cx2 + 15.0, gy), str(_inv_income), 13, HanjiUi.GOLD)
	# 휴지통 슬롯(우측) — 집은 상태로 클릭하면 확인 후 버린다. 빈손이면 안내만.
	_trash_rect = Rect2(plate.end.x - 12.0 - SLOT, plate.position.y + (plate.size.y - SLOT) * 0.5, SLOT, SLOT)
	_plate_btn(_trash_rect, _held >= 0)
	_draw_trash_icon(_trash_rect)
	# [정리] 버튼 + 안내 — 정보패널 아래(그리드 바로 위).
	_sort_rect = Rect2(panel.end.x - PAD - 72.0, panel.position.y + TOP_H + 2.0, 72.0, 26.0)
	_plate_btn(_sort_rect)
	HanjiUi.draw_text(self, _sort_rect.position + Vector2(16.0, 18.0), "정리", 14, HanjiUi.INK_LIGHT)
	var hint := "휴지통에 넣어 버리기" if _held >= 0 else "슬롯을 클릭해 집어 옮긴다"
	HanjiUi.draw_text(self, Vector2(panel.position.x + PAD, panel.position.y + TOP_H + 20.0),
		hint, 12, HanjiUi.INK_DIM)

# ★ [S1R-T12] 휴지통 픽토그램(그레이박스 — 몸통 + 뚜껑 + 세로 홈). 아이콘 에셋 없이 draw로 그린다.
func _draw_trash_icon(rect: Rect2) -> void:
	var c := rect.get_center()
	var body := Rect2(c.x - 11.0, c.y - 6.0, 22.0, 18.0)
	draw_rect(body, HanjiUi.INK_DIM)
	draw_rect(body, HanjiUi.BORDER, false, 1.0)
	draw_rect(Rect2(c.x - 14.0, c.y - 11.0, 28.0, 4.0), HanjiUi.BORDER)   # 뚜껑
	for dx in [-5.0, 0.0, 5.0]:
		draw_line(Vector2(c.x + dx, body.position.y + 3.0), Vector2(c.x + dx, body.end.y - 3.0),
			Color(0.10, 0.09, 0.08, 0.7), 1.0)

func _draw_rel_tab(panel: Rect2, font: Font) -> void:
	# 관계 탭: 하트는 HeartBar 자식이 그린다(_apply_heart_visibility 배치). 탭 바 아래에 '읽기 전용' 안내만
	# (4탭이 상단 폭을 다 써 우측 여백이 없음 — 탭 아래로 내린다).
	HanjiUi.draw_text(self, Vector2(panel.position.x + PAD + 8.0, panel.position.y + PAD + 50.0),
		"관계 — 읽기 전용(호감도는 대화·활동으로)", 12, HanjiUi.INK_DIM)
	# ★ C3 각 하트 행 아래에 그 캐릭터의 관계 곱셈기(여우불·마진·경비·할인) 한 줄. HeartBar와 같은
	# y 기준(panel.y + PAD + 60 + i*48, _apply_heart_visibility와 동일)에서 한 칸(+40) 내려 그린다.
	for i in _heart_effects.size():
		var eff: String = str(_heart_effects[i])
		if eff == "":
			continue
		var ey := panel.position.y + PAD + 60.0 + i * 48.0 + 40.0
		HanjiUi.draw_text(self, Vector2(panel.position.x + PAD + 12.0, ey), eff,
			12, HanjiUi.INK_DIM, panel.size.x - PAD * 2.0 - 12.0)

# ★ Phase B 숙련 탭 — main이 넘긴 _skill_rows를 레벨·진행바로 그린다(읽기 전용, 관계 탭과 대칭).
func _draw_skill_tab(panel: Rect2, font: Font) -> void:
	_prof_choice_rects.clear()   # ★ ADR-0052 — 클릭 영역은 매 그리기마다 재구성(레이아웃 파생)
	var x := panel.position.x + PAD + 12.0
	var y := panel.position.y + PAD + 52.0
	if _skill_rows.is_empty():
		HanjiUi.draw_text(self, Vector2(x, y), "숙련 정보 없음", 13, HanjiUi.INK_DIM)
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
		HanjiUi.draw_text(self, Vector2(x, y), head, 15, HanjiUi.INK_LIGHT)
		# 진행바(한지 plate 트랙 + 앰버 채움).
		var track := Rect2(x, y + 8.0, bar_w, 12.0)
		draw_rect(track, HanjiUi.INSET)
		draw_rect(track, HanjiUi.BORDER, false, 1.0)
		var frac := 1.0 if maxed else clampf(float(xp - floor_xp) / float(maxi(next_xp - floor_xp, 1)), 0.0, 1.0)
		if frac > 0.0:
			draw_rect(Rect2(track.position, Vector2(track.size.x * frac, track.size.y)), HanjiUi.GOLD)
		var tail := "만렙" if maxed else "%d / %d XP" % [xp - floor_xp, next_xp - floor_xp]
		HanjiUi.draw_text(self, Vector2(x, y + 34.0), tail, 12, HanjiUi.INK_DIM)
		y += 50.0
		# ★ ADR-0052 — 고른 전문직 요약.
		var prof := String(row.get("profession", ""))
		if prof != "":
			HanjiUi.draw_text(self, Vector2(x, y), "전문직: %s" % prof, 12, HanjiUi.GOLD_SOFT)
			y += 20.0
		# ★ ADR-0052 — 선택 대기(pending) 시 2갈래 버튼(name + desc). 클릭 영역을 _prof_choice_rects에 등록.
		var options: Array = row.get("options", [])
		if not options.is_empty():
			var skill := String(row.get("skill", ""))
			HanjiUi.draw_text(self, Vector2(x, y), "▶ 전문직 선택 (Lv.%d):" % int(row.get("pending_tier", 0)), 13, HanjiUi.GOLD)
			y += 22.0
			for opt in options:
				var btn := Rect2(x + 8.0, y, bar_w - 16.0, 30.0)
				_plate_btn(btn)
				HanjiUi.draw_text(self, btn.position + Vector2(10.0, 13.0), String(opt.get("name", "")), 13, HanjiUi.INK_LIGHT)
				HanjiUi.draw_text(self, btn.position + Vector2(10.0, 26.0), String(opt.get("desc", "")), 10, HanjiUi.INK_DIM)
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
	_plate_btn(_save_rect)
	HanjiUi.draw_text(self, _save_rect.position + Vector2(14.0, 19.0), "저장", 14, HanjiUi.INK_LIGHT)
	_quit_rect = Rect2(x, y + 34.0, 200.0, 28.0)
	_plate_btn(_quit_rect)
	draw_rect(_quit_rect, Color(0.72, 0.40, 0.34), false, 1.0)   # 파괴적 동작(나가기) 경고 액센트
	HanjiUi.draw_text(self, _quit_rect.position + Vector2(14.0, 19.0), "저장하고 나가기", 14, Color(0.95, 0.72, 0.66))
	# ── ★ Phase D 설정 본체 ──
	# ★ 구분선을 볼륨 행과 확실히 띄운다 — 옛 (sy=y+84, 구분선 sy-8)은 "── 설정 ──"이 "음악 볼륨"
	#   라벨과 겹쳤다(owner 리포트 2026-07-06). 구분선을 위로(y+80)·첫 행을 아래로(y+104) 분리.
	HanjiUi.draw_text(self, Vector2(x, y + 80.0), "── 설정 ──", 13, HanjiUi.GOLD_SOFT)
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
	draw_rect(_fullscreen_rect, HanjiUi.INSET)
	draw_rect(_fullscreen_rect, HanjiUi.BORDER, false, 1.0)
	if _set_fullscreen:
		draw_rect(_fullscreen_rect.grow(-4.0), HanjiUi.GOLD)
	HanjiUi.draw_text(self, Vector2(x + 26.0, sy), "전체화면", 14, HanjiUi.INK_LIGHT)
	HanjiUi.draw_text(self, Vector2(x + 120.0, sy), "(F11)", 12, HanjiUi.INK_DIM)
	# 언어(한국어 고정 — 표시만, ADR-0048 §2).
	sy += 30.0
	HanjiUi.draw_text(self, Vector2(x, sy), "언어  한국어 (고정)", 12, HanjiUi.INK_DIM)

# ★ Phase D 볼륨 한 줄(라벨 · [−] · 트랙바 · [+] · 백분율). [−]/[+] 버튼 Rect2 둘을 배열로 돌려준다.
func _draw_volume_row(font: Font, x: float, yy: float, label: String, v01: float) -> Array:
	HanjiUi.draw_text(self, Vector2(x, yy), label, 14, HanjiUi.INK_LIGHT)
	var minus := Rect2(x + 92.0, yy - 14.0, 20.0, 18.0)
	_plate_btn(minus)
	HanjiUi.draw_text(self, minus.position + Vector2(7.0, 15.0), "-", 16, HanjiUi.INK_LIGHT)
	var track := Rect2(x + 118.0, yy - 12.0, 96.0, 12.0)
	draw_rect(track, HanjiUi.INSET)
	if v01 > 0.0:
		draw_rect(Rect2(track.position, Vector2(track.size.x * clampf(v01, 0.0, 1.0), track.size.y)), HanjiUi.GOLD)
	draw_rect(track, HanjiUi.BORDER, false, 1.0)
	var plus := Rect2(x + 220.0, yy - 14.0, 20.0, 18.0)
	_plate_btn(plus)
	HanjiUi.draw_text(self, plus.position + Vector2(6.0, 15.0), "+", 15, HanjiUi.INK_LIGHT)
	HanjiUi.draw_text(self, Vector2(x + 248.0, yy), "%d%%" % roundi(v01 * 100.0), 13, HanjiUi.INK_LIGHT)
	return [minus, plus]

# ── 출하함 상단(대기 슬롯 + 정산 미리보기) ────────────────────────────────────
func _draw_bin_top(panel: Rect2) -> void:
	# ★ [S1R-T12] 출하 정산 = 품목별 [아이콘 | 이름×수량 | 소계 골드] 내역 행 + 총액 강조(GOLD).
	# 옛 가로 슬롯 나열을 스타듀 정산 브레이크다운으로 승격(클릭 회수는 각 행 아이콘 칸이 그대로 담당).
	HanjiUi.draw_text(self, Vector2(panel.position.x + PAD, panel.position.y + PAD + 18.0),
		"무인 출하함", 16, HanjiUi.GOLD_SOFT)
	var preview := bin.preview_gold() if bin != null else 0
	# 총액(우측 상단, GOLD 강조 — 엽전 아이콘 + 합계). ★ 닫기 X(우상단 모서리)와 겹치지 않게
	# FRAME_MARGIN + X 폭만큼 왼쪽으로 물린다.
	var total_str := "+%d" % preview
	var tw := HanjiUi.text_width(total_str, 15)
	var num_x := panel.end.x - FRAME_MARGIN - 28.0 - tw
	draw_texture_rect(COIN, Rect2(num_x - 15.0, panel.position.y + PAD + 8.0, 13.0, 13.0), false)
	HanjiUi.draw_text(self, Vector2(num_x, panel.position.y + PAD + 20.0), total_str, 15, HanjiUi.GOLD)
	HanjiUi.draw_text(self, Vector2(panel.position.x + PAD, panel.position.y + PAD + 38.0),
		"다음 아침 정산  ·  백팩 클릭=드롭 / 내역 클릭=회수", 12, HanjiUi.INK_DIM)
	# 품목별 내역 행(아이콘 칸=회수 히트). 상단 영역에 들어갈 만큼만 그리고 넘치면 "…외 N종".
	_bin_rects.clear()
	if bin == null:
		return
	const ROW_H := 30.0
	const ICON := 26.0
	var row_y := panel.position.y + PAD + 52.0
	var max_y := panel.position.y + TOP_H + PAD * 2.0 - 6.0   # 백팩 그리드 시작 직전까지
	var ids: Array = bin.ids()
	var max_rows := int((max_y - row_y) / ROW_H)
	var shown := mini(ids.size(), max_rows)
	for i in shown:
		var id: String = ids[i]
		var pos := Vector2(panel.position.x + PAD, row_y + i * ROW_H)
		var icon_rect := Rect2(pos, Vector2(ICON, ICON))
		_bin_rects.append({"rect": icon_rect, "id": id})
		_draw_slot_box(icon_rect, false)
		_draw_icon(id, icon_rect)
		var n := bin.count_of(id)
		var sub := 0
		for q in bin.qualities_of(id):
			sub += bin.count_of_quality(id, int(q)) * ItemCatalog.price_of(id, int(q))
		var ty := pos.y + ICON - 8.0
		HanjiUi.draw_text(self, Vector2(pos.x + ICON + 10.0, ty),
			"%s ×%d" % [ItemCatalog.name_of(id), n], 13, HanjiUi.INK_LIGHT, 150.0)
		var subs := "+%d" % sub
		HanjiUi.draw_text(self, Vector2(panel.end.x - PAD - HanjiUi.text_width(subs, 13), ty),
			subs, 13, HanjiUi.GOLD_SOFT)
	if ids.size() > shown:
		HanjiUi.draw_text(self, Vector2(panel.position.x + PAD, row_y + shown * ROW_H + 12.0),
			"…외 %d종" % (ids.size() - shown), 12, HanjiUi.INK_DIM)

# ── ★ Phase D 저장 상자 상단(보관 슬롯 그리드) ────────────────────────────────
# 상단 컨텍스트 영역에 상자 슬롯을 백팩과 같은 6열 그리드로 그린다(하단=백팩, 상단=상자). 클릭은
# _click_chest가 라우팅한다(백팩 슬롯 클릭=보관 / 상자 슬롯 클릭=회수 — bin 드롭의 양방향 판).
func _draw_chest_top(panel: Rect2) -> void:
	HanjiUi.draw_text(self, Vector2(panel.position.x + PAD, panel.position.y + PAD + 18.0),
		"저장 상자", 16, HanjiUi.GOLD_SOFT)
	HanjiUi.draw_text(self, Vector2(panel.position.x + PAD, panel.position.y + PAD + 38.0),
		"백팩 아이템 클릭=보관   ·   상자 아이템 클릭=회수 (판매 아님 — 순수 보관)",
		12, HanjiUi.INK_DIM)
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
				HanjiUi.draw_text(self, pos + Vector2(SLOT - 16.0, SLOT - 5.0), str(n), 13, HanjiUi.INK_LIGHT)

# ── 매대 상단(본문 텍스트 + 구매 버튼) ────────────────────────────────────────
func _draw_store_top(panel: Rect2) -> void:
	# ★ [S1R-T12] 매대 그리드 — 헤더(골드·할인) 2줄 + 품목 행 리스트 [아이콘|이름|가격(엽전)|구매].
	# store_text는 헤더(제목·골드·할인 요약)만, 품목은 store_items 데이터로 행을 그린다(평문 → 그리드).
	var y := panel.position.y + PAD + 14.0
	for line in store_text.split("\n"):
		HanjiUi.draw_text(self, Vector2(panel.position.x + PAD, y), line, 13, HanjiUi.INK_LIGHT,
			panel.size.x - PAD * 2.0)
		y += 18.0
	# 품목 행(아이콘·이름·가격·구매 버튼). 행 클릭 or 버튼 클릭으로 구매(Shift=대량).
	# 헤더(2줄) 아래부터 백팩 그리드 직전까지 꽉 채워 판매 품목 전부(씨앗 4 + 스프링클러)를 담는다.
	_store_row_rects.clear()
	const ROW_H := 22.0
	const ICON := 20.0
	var row_y := panel.position.y + PAD + 42.0
	var max_y := panel.position.y + TOP_H + PAD * 2.0 - 6.0   # 백팩 그리드 시작(_grid_origin) 직전까지
	var i := 0
	for item in store_items:
		var ry := row_y + i * ROW_H
		if ry + ROW_H > max_y:
			break
		var rowrect := Rect2(panel.position.x + PAD, ry, panel.size.x - PAD * 2.0, ROW_H - 2.0)
		var buyrect := Rect2(panel.end.x - PAD - 54.0, ry, 54.0, ROW_H - 4.0)
		_store_row_rects.append({"row": rowrect, "buy": buyrect,
			"kind": String(item.get("kind", "")), "buy_id": String(item.get("buy_id", ""))})
		# 아이콘.
		var icon_rect := Rect2(rowrect.position, Vector2(ICON, ICON))
		_draw_icon(String(item.get("icon_id", "")), icon_rect)
		# 이름.
		var ty := ry + ICON - 6.0
		HanjiUi.draw_text(self, Vector2(rowrect.position.x + ICON + 8.0, ty),
			String(item.get("name", "")), 13, HanjiUi.INK_LIGHT, 118.0)
		# 가격(엽전 + 숫자). 할인 시 정가→할인가.
		var price := int(item.get("price", 0))
		var base := int(item.get("base", price))
		var px := rowrect.position.x + ICON + 8.0 + 124.0
		if price < base:
			var bs := "%d→" % base
			HanjiUi.draw_text(self, Vector2(px, ty), bs, 11, HanjiUi.INK_DIM)
			px += HanjiUi.text_width(bs, 11) + 2.0
		draw_texture_rect(COIN, Rect2(px, ty - 11.0, 12.0, 12.0), false)
		HanjiUi.draw_text(self, Vector2(px + 15.0, ty), str(price), 13, HanjiUi.GOLD)
		# 구매 버튼.
		_plate_btn(buyrect)
		HanjiUi.draw_text(self, buyrect.position + Vector2(11.0, 16.0), "구매", 12, HanjiUi.INK_LIGHT)
		i += 1

# ★ [S1R-T12] 매대 행 구매 라우팅 — 행/버튼 클릭 시 종류별 시그널. Shift=대량.
func _buy_store_row(e: Dictionary, bulk: bool) -> void:
	match String(e.get("kind", "")):
		"placeable":
			buy_sprinkler_pressed.emit(bulk)
		"seed":
			buy_seed.emit(String(e.get("buy_id", "")), bulk)

# ── 클릭 라우팅 ───────────────────────────────────────────────────────────────
func _gui_input(event: InputEvent) -> void:
	if context == CTX_NONE:
		return
	# ★ 아이콘 탭 호버 추적 + 스크롤바 썸 드래그 중이면 포인터 이동을 스크롤로.
	if event is InputEventMouseMotion:
		_update_hover_tab(event.position)
		if _bp_scroll_dragging:
			_drag_bp_scroll(event.position)
		return
	if not (event is InputEventMouseButton):
		return
	# ★ 마우스 휠 = 백팩 세로 스크롤(백팩이 보이는 컨텍스트에서). 위=이전 행, 아래=다음 행.
	if event.pressed and _backpack_visible():
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_scroll_bp(-1); accept_event(); return
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_scroll_bp(1); accept_event(); return
	if event.button_index != MOUSE_BUTTON_LEFT:
		return
	# ★ 좌클릭 뗌 = 스크롤 드래그 종료.
	if not event.pressed:
		_bp_scroll_dragging = false
		return
	var p: Vector2 = event.position
	# ★ [S1R-T12] 버리기 확인 오버레이가 떠 있으면 그 버튼만 받는다(모달 — 다른 클릭 차단).
	if _trash_pending >= 0:
		if _trash_yes_rect.has_point(p):
			discard_slot.emit(_trash_pending)
			_trash_pending = -1
			_held = -1
			queue_redraw()
		elif _trash_no_rect.has_point(p):
			_trash_pending = -1
			queue_redraw()
		accept_event()
		return
	# ★ [S1R-T12] 우상단 닫기 X — 모든 컨텍스트 공통(다른 라우팅보다 먼저).
	if _close_rect.has_point(p):
		close_pressed.emit()
		accept_event()
		return
	# ★ 스크롤바: 썸 클릭=드래그 시작, 트랙 클릭=그 위치로 점프(다른 클릭 라우팅보다 먼저).
	if _backpack_visible() and _bp_track_rect.size.y > 0.0:
		if _bp_thumb_rect.has_point(p):
			_bp_scroll_dragging = true
			accept_event(); return
		elif _bp_track_rect.has_point(p):
			_drag_bp_scroll(p)
			accept_event(); return
	match context:
		CTX_MENU:
			_click_menu(p)
		CTX_BIN:
			_click_bin(p)
		CTX_STORE:
			for e in _store_row_rects:   # ★ [S1R-T12] 행/버튼 클릭=개별 구매(Shift 대량)
				if e["buy"].has_point(p) or e["row"].has_point(p):
					_buy_store_row(e, event.shift_pressed)
					break
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
	# ★ [S1R-T12] 휴지통 — 집은 상태로 클릭하면 확인 오버레이를 띄운다(빈손이면 무시).
	if _trash_rect.has_point(p):
		if _held >= 0:
			_trash_pending = _held
			queue_redraw()
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
