extends Control
class_name HotbarHud
# Phase 2.7 C1 — 핫바 HUD(하단 12칸 슬롯 바, ADR-0024 마우스 조작 / ADR-0020 데이터 주도 아이템).
#
# 목적: 인벤토리 슬롯(= 핫바)을 화면 하단에 그려, 든 것이 무엇이고 무엇을 골랐는지 한눈에 보이게
#       한다(스타듀 동일 — 숫자키·휠로 고른 슬롯이 LMB 동사를 정한다). 그레이박스: 씨앗·수확물
#       아이콘은 작물 스프라이트(CROP_SPRITES) 재사용, 도구는 임시 색박스(ItemCatalog.tool_color_of).
#
# 설계 메모:
#   - lighting/audio처럼 코드 생성 자식(무상태, 세이브 대상 아님). main이 _setup_hotbar에서 붙이고
#     인벤토리·작물 아이콘을 주입한다. 인벤토리 changed 시그널로만 다시 그린다(폴링 없이 디커플링).
#   - CanvasLayer 자식이라 화면 좌표로 그린다(카메라와 무관). 전체 화면 앵커로 깔고 size로 하단 배치.
#   - 헤드리스 단위검증(main.tscn 로드)에서도 안전 — 텍스처는 유효 preload, _draw는 픽셀이 없어도
#     크래시하지 않는다(라이팅·손님 그리기와 같은 결).

const SLOTS := 16                 # = Inventory.SIZE(핫바 칸 수). 슬롯이 늘면 함께 키운다. ★S1-8: 12→16
const SLOT_PX := 24.0             # 한 칸 변(px) — ★owner 2026-07-03 HUD 가이드: 36→24(≈67%, 시야 확보)
const GAP := 2.0                  # 칸 사이 간격 — 16*24+15*2=414 < 640(양옆 ~113px 여백)
const MARGIN_BOTTOM := 10.0       # 화면 아래 여백
const PLATE_ALPHA := 0.82         # 슬롯 배경 알파(<1 = 뒤 지형 투과, 답답함 완화)
const HOTKEYS := "1234567890-="   # 슬롯 좌상단 단축키 인덱스(0..11). 12..15는 표시 없음(휠 전용)

var inv: Inventory = null         # 그릴 인벤토리(슬롯·선택). main이 주입.
var crop_icons: Dictionary = {}   # 작물군 id → mature 스프라이트(씨앗·수확물 아이콘 재사용). main 주입.

# main이 인벤토리·작물 아이콘을 주입하고 changed 구독을 건다. 전체 화면 앵커로 깔아 하단 배치 기준을 잡는다.
func setup(inventory: Inventory, icons: Dictionary) -> void:
	inv = inventory
	crop_icons = icons
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE  # 핫바가 마우스 클릭(도구 사용)을 가로채지 않게
	if inv != null and not inv.changed.is_connected(queue_redraw):
		inv.changed.connect(queue_redraw)
	queue_redraw()

# 부모 CanvasLayer가 UI scale(ADR-0018 ×1.5)을 먹어, 전체화면 앵커 Control의 size(=960×540)는
# *논리 좌표*가 아니다 — 화면에 실제로 보이는 영역은 size / scale(=640×360)다. 이걸 무시하면 핫바가
# 화면 아래(y≈726)로 밀려 안 보인다(C2 프레임과 같은 스케일 함정 — 보이는 영역 기준으로 배치).
func _view() -> Vector2:
	var sc := 1.0
	var par := get_parent()
	if par is CanvasLayer and par.scale.x != 0.0:
		sc = par.scale.x
	return Vector2(size.x / sc, size.y / sc)

# 슬롯 배치 원점(_draw·히트테스트 공용) — 하단 중앙, 보이는 논리 영역 기준.
func _slots_origin() -> Vector2:
	var view := _view()
	var total_w := SLOTS * SLOT_PX + (SLOTS - 1) * GAP
	return Vector2((view.x - total_w) * 0.5, view.y - SLOT_PX - MARGIN_BOTTOM)

func _draw() -> void:
	if inv == null:
		return
	var origin := _slots_origin()
	for i in SLOTS:
		var pos := origin + Vector2(i * (SLOT_PX + GAP), 0.0)
		_draw_slot(i, pos)

# ★ Phase C 툴팁용 — 논리 좌표(보이는 640×360)에서 그 위치의 핫바 슬롯 인덱스(없으면 -1).
# _draw와 같은 기하를 재계산한다(무상태 뷰라 캐시 대신 재계산 — 슬롯 16개 값싸다).
func slot_index_at(logical_pos: Vector2) -> int:
	if inv == null:
		return -1
	var origin := _slots_origin()
	for i in SLOTS:
		var pos := origin + Vector2(i * (SLOT_PX + GAP), 0.0)
		if Rect2(pos, Vector2(SLOT_PX, SLOT_PX)).has_point(logical_pos):
			return i
	return -1

func _draw_slot(i: int, pos: Vector2) -> void:
	var rect := Rect2(pos, Vector2(SLOT_PX, SLOT_PX))
	var selected := i == inv.selected_index
	# ★ Phase C — 태운 한지 plate 9-slice 슬롯(inv_frame 백팩과 동일 룩). 선택 칸은 밝은 금박
	# 테두리를 덧그려 강조한다(스타듀의 그 칸 강조). ★owner HUD 가이드: 배경 반투명(지형 투과).
	HanjiUi.draw_plate(self, rect, PLATE_ALPHA)
	if selected:
		draw_rect(rect, HanjiUi.GOLD_SOFT, false, 2.0)
	var id := inv.id_at(i)
	if id != "":
		_draw_icon(id, rect)
		# ★ S1-6 품질 배지 — 등급>0이면 좌하단에 등급 색 점(스타듀 별 위치).
		var q := inv.quality_at(i)
		if q > 0:
			draw_circle(pos + Vector2(6.0, SLOT_PX - 6.0), 3.0, _quality_color(q))
		# 스택 개수 배지(2개 이상만). 칸 우하단에 작은 숫자(외곽선으로 아이콘 위 가독).
		var n := inv.count_at(i)
		if n > 1:
			HanjiUi.draw_text(self, pos + Vector2(SLOT_PX - 11.0, SLOT_PX - 2.0),
				str(n), 10, HanjiUi.INK_LIGHT)
	# ★owner HUD 가이드 B — 슬롯 좌상단 단축키 인덱스(1..0,-,=). 스타듀식 퀵슬롯 가독.
	if i < HOTKEYS.length():
		HanjiUi.draw_text(self, pos + Vector2(2.0, 9.0), HOTKEYS[i], 9, HanjiUi.GOLD_SOFT)

# 품질 등급 색(그레이박스 배지 — 은/금/이리듐). 0(일반)은 배지 없음이라 호출 안 됨.
func _quality_color(q: int) -> Color:
	match q:
		1: return Color(0.78, 0.80, 0.85)   # 은
		2: return Color(0.96, 0.80, 0.25)   # 금
		3: return Color(0.60, 0.38, 0.88)   # 이리듐
		_: return Color.WHITE

# 아이콘: 도구는 색박스(임시 그레이박스), 씨앗·수확물은 작물 mature 스프라이트 재사용.
func _draw_icon(id: String, rect: Rect2) -> void:
	var pad := 4.0
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
			# ★ [S1-5b] 묘목 그레이박스 아이콘 — 밑동(갈색)+새싹(초록) 색 박스(대형 스프라이트=S1-10).
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
			# ★ 재료(건초·개간 드랍) — 케이스 누락으로 아이콘 없이 개수만 뜨던 버그(inv_frame과 동형 수정).
			var mtex: Texture2D = crop_icons.get(id)
			if mtex != null:
				draw_texture_rect(mtex, inner, false)
			else:
				draw_rect(inner, Color(0.80, 0.66, 0.30) if ItemCatalog._is_hay(id) else Color(0.46, 0.36, 0.26))

# 작물·수확물 스프라이트를 칸 안에 맞춰 그린다(없으면 흰 박스 폴백 — 손상 방어).
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
