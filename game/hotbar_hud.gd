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
const SLOT_PX := 36.0             # 한 칸 변(px) — ★S1-8: 16칸이 화면폭(640)에 맞게 44→36
const GAP := 3.0                  # 칸 사이 간격 — ★S1-8: 4→3 (16*36+15*3=621 < 640)
const MARGIN_BOTTOM := 12.0       # 화면 아래 여백

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

func _draw() -> void:
	if inv == null:
		return
	var view := _view()
	var total_w := SLOTS * SLOT_PX + (SLOTS - 1) * GAP
	var origin := Vector2((view.x - total_w) * 0.5, view.y - SLOT_PX - MARGIN_BOTTOM)
	for i in SLOTS:
		var pos := origin + Vector2(i * (SLOT_PX + GAP), 0.0)
		_draw_slot(i, pos)

func _draw_slot(i: int, pos: Vector2) -> void:
	var rect := Rect2(pos, Vector2(SLOT_PX, SLOT_PX))
	var selected := i == inv.selected_index
	# 칸 배경 + 테두리. 선택 칸은 배경이 밝고 테두리가 굵고 환하다(스타듀의 그 칸 강조).
	draw_rect(rect, Color(0.10, 0.10, 0.13, 0.78))
	draw_rect(rect, Color(0.95, 0.92, 0.65) if selected else Color(0.45, 0.45, 0.50), false, 2.0 if selected else 1.0)
	var id := inv.id_at(i)
	if id == "":
		return  # 빈 슬롯(배경만)
	_draw_icon(id, rect)
	# ★ S1-6 품질 배지(그레이박스 — 아트 배지=S1-10). 등급>0이면 좌하단에 등급 색 점(스타듀 별 위치).
	var q := inv.quality_at(i)
	if q > 0:
		draw_circle(pos + Vector2(8.0, SLOT_PX - 8.0), 4.0, _quality_color(q))
	# 스택 개수 배지(2개 이상일 때만 — 1이면 군더더기). 칸 우하단에 작은 숫자.
	var n := inv.count_at(i)
	if n > 1:
		draw_string(ThemeDB.fallback_font, pos + Vector2(SLOT_PX - 15.0, SLOT_PX - 4.0),
			str(n), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)

# 품질 등급 색(그레이박스 배지 — 은/금/이리듐). 0(일반)은 배지 없음이라 호출 안 됨.
func _quality_color(q: int) -> Color:
	match q:
		1: return Color(0.78, 0.80, 0.85)   # 은
		2: return Color(0.96, 0.80, 0.25)   # 금
		3: return Color(0.60, 0.38, 0.88)   # 이리듐
		_: return Color.WHITE

# 아이콘: 도구는 색박스(임시 그레이박스), 씨앗·수확물은 작물 mature 스프라이트 재사용.
func _draw_icon(id: String, rect: Rect2) -> void:
	var pad := 6.0
	var inner := Rect2(rect.position + Vector2(pad, pad), rect.size - Vector2(pad * 2.0, pad * 2.0))
	match ItemCatalog.category_of(id):
		ItemCatalog.CAT_TOOL:
			draw_rect(inner, ItemCatalog.tool_color_of(id))
		ItemCatalog.CAT_SEED:
			_draw_crop_tex(ItemCatalog.crop_of(id), inner)
		ItemCatalog.CAT_SAPLING:
			# ★ [S1-5b] 묘목 그레이박스 아이콘 — 밑동(갈색)+새싹(초록) 색 박스(대형 스프라이트=S1-10).
			draw_rect(inner, Color(0.42, 0.30, 0.20))
			draw_rect(Rect2(inner.position, Vector2(inner.size.x, inner.size.y * 0.45)), Color(0.35, 0.62, 0.35))
		ItemCatalog.CAT_HARVEST:
			_draw_crop_tex(id, inner)
		ItemCatalog.CAT_FERTILIZER:
			# ★ [S1-6] 비료 그레이박스 아이콘 — 품질군=초록 흙, 성장촉진군=청록(축 구분). 아트=하류.
			var fc := Color(0.40, 0.55, 0.32) if FertilizerCatalog.group_of(id) == "quality" else Color(0.30, 0.55, 0.55)
			draw_rect(inner, fc)

# 작물 스프라이트를 칸 안에 맞춰 그린다(없으면 흰 박스 폴백 — 손상 방어).
func _draw_crop_tex(crop_id: String, inner: Rect2) -> void:
	var tex: Texture2D = crop_icons.get(crop_id)
	if tex == null:
		draw_rect(inner, Color(0.8, 0.8, 0.8))
		return
	draw_texture_rect(tex, inner, false)
