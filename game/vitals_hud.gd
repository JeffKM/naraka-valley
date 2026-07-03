extends Control
class_name VitalsHud
# Phase 2.7 C3 — 우하단 혼력 바(+ 체력 바 자리 예약, 스타듀식 미니멀 HUD).
#
# 목적: 텍스트 "혼력: 80/100"을 우하단의 *바*로 바꿔 한눈에 읽히게 한다(ADR-0018 미니멀 HUD).
#       혼력은 노동 자원(괭이질·물주기·수확마다 소모, T2.4)이라 항상 봐야 하므로 상시 HUD에 남는다.
#       체력(HP)은 Phase 3 ⑤ 전투에서 들어올 별도 자원(ADR-0011 — 채광=혼력·전투=체력)이라,
#       여기선 *자리만* 비워 둔다(빈 회색 바 + "체력 —") — 레이아웃이 나중에 안 흔들리게.
#
# 설계 메모:
#   - hotbar_hud.gd·notice_feed.gd와 같은 결: 코드 생성 자식 Control(무상태 — 혼력은 SoulEnergy가
#     소유). main이 _setup_vitals에서 붙이고 energy를 주입한다. energy.changed로만 다시 그린다.
#   - 부모 CanvasLayer scale(ADR-0018 ×1.5)을 되돌려 보이는 영역(=640×360) 우하단에 배치한다
#     (핫바·피드와 같은 스케일 함정 회피). 핫바(하단 중앙)와 겹치지 않게 오른쪽 끝에 둔다.

# ★ owner 2026-07-03 3차 HUD 가이드 — 우하단 혼력바 압축(BAR_W/H·라벨 축소). 체력 placeholder
#   빈 바는 자리만 먹어 제거(Phase 3 전투에서 재도입 — 그때 두 바 레이아웃 복원). 우하단 구석 밀착.
const BAR_W := 100.0          # 바 길이(px, 논리 좌표) — 132→100 압축
const BAR_H := 11.0           # 바 높이 — 14→11
const MARGIN := 10.0          # 화면 오른쪽 여백
# 핫바(하단 중앙)와 안 겹치게 바를 핫바 *위*로 올린다. 하단에서 RESERVE_BOTTOM만큼 띄운 자리가 바닥.
const RESERVE_BOTTOM := 40.0  # 핫바(24px+여백)가 작아져 코너로 더 내려붙임(80→40)
const LABEL_W := 26.0         # 바 왼쪽 라벨 폭("혼력")

var energy: SoulEnergy = null  # 그릴 혼력(현재/최대). main이 주입.

# main이 혼력을 주입하고 changed 구독을 건다. 전체 화면 앵커로 깔아 우하단 배치 기준을 잡는다.
func setup(soul_energy: SoulEnergy) -> void:
	energy = soul_energy
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if energy != null and not energy.changed.is_connected(_on_energy_changed):
		energy.changed.connect(_on_energy_changed)
	queue_redraw()

func _on_energy_changed(_current: int, _maximum: int) -> void:
	queue_redraw()

func _view() -> Vector2:
	var sc := 1.0
	var par := get_parent()
	if par is CanvasLayer and par.scale.x != 0.0:
		sc = par.scale.x
	return Vector2(size.x / sc, size.y / sc)

func _draw() -> void:
	if energy == null:
		return
	var view := _view()
	var right := view.x - MARGIN
	# ★ 혼력 바 한 줄만(체력 placeholder 제거) 태운 한지 플레이트로 감싼다.
	var soul_top := view.y - RESERVE_BOTTOM - BAR_H
	var plate := Rect2(right - BAR_W - LABEL_W - 7.0, soul_top - 6.0,
		BAR_W + LABEL_W + 14.0, BAR_H + 12.0)
	HanjiUi.draw_plate(self, plate)
	# 혼력 바(현재/최대). 바닥나면 채움이 0 → 비어 보이고, 색이 식는다(취침 신호).
	var ratio := clampf(float(energy.current) / float(SoulEnergy.MAX), 0.0, 1.0)
	var low := not energy.can_act()
	# 혼(soul) 보랏빛 채움 — 바닥나면 식은 붉은빛(취침 신호).
	var fill := Color(0.52, 0.46, 0.76) if not low else Color(0.62, 0.42, 0.44)
	_draw_bar(Vector2(right - BAR_W, soul_top), "혼력", ratio, fill)

# 라벨 + 인셋 트랙 + 채움(ratio) + 수치.
func _draw_bar(pos: Vector2, label: String, ratio: float, fill: Color) -> void:
	# 왼쪽 라벨(먹빛 — 밝은 한지 위 가독). 외곽선으로 선명.
	HanjiUi.draw_text(self, pos + Vector2(-LABEL_W, BAR_H - 1.0), label, 10, HanjiUi.INK)
	var box := Rect2(pos, Vector2(BAR_W, BAR_H))
	draw_rect(box, HanjiUi.INSET)
	if ratio > 0.0:
		draw_rect(Rect2(pos, Vector2(BAR_W * ratio, BAR_H)), fill)
	draw_rect(box, HanjiUi.BORDER, false, 1.0)
	# 수치 텍스트를 바 안에 작게(현재/최대) — 어두운 트랙 위라 밝은 글자.
	if energy != null:
		HanjiUi.draw_text(self, pos + Vector2(BAR_W - 40.0, BAR_H - 1.0),
			"%d/%d" % [energy.current, SoulEnergy.MAX], 10, HanjiUi.INK_LIGHT)
