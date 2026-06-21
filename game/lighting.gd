extends CanvasModulate
class_name DayNightLighting
# P2.3③ — 밤 라이팅 오버레이.
#
# 목적: "밤이 밤으로 읽힌다"를 별도 밤 타일셋 없이(ROADMAP P2.3③) 한 장의 라이팅으로
#       만든다. 낮↔황혼↔밤을 시각(분)에서 파생한 화면 색조(CanvasModulate)로 잇고,
#       소울 등불(PROP_LANTERN) 자리에 따뜻한 빛웅덩이(PointLight2D)를 얹어 저승의
#       서늘한 인디고 밤에 카페·길이 "장소"로 떠오르게 한다.
#
# 설계 메모:
#   - 이 노드는 "라이팅" 단일 책임만 가진다. 시각(clock.minutes)을 들고 있지 않고,
#     main이 매 프레임 apply(minutes)로 흘려넣는다. 상태가 전부 시각에서 파생되므로
#     세이브 대상이 아니다(NPC station·바나 밤 등장과 같은 무상태 결, SaveManager 불변).
#   - CanvasModulate는 *기본 캔버스(월드)* 만 물들인다. HUD는 CanvasLayer라 영향을 안
#     받아 밤에도 글자가 또렷하다 — 그래서 별도 분리 작업이 필요 없다.
#   - 색·세기 곡선은 순수 함수(tint_for/lamp_energy_for)로 떼어 두 시각 키프레임 사이를
#     보간한다 → 헤드리스로 단언 가능(lighting_test.gd).

# ── 화면 색조 곡선 ─────────────────────────────────────────────────────────
# [게임 분, 색조] 키프레임. 그 사이는 선형 보간. 06:00 시작 ~ 24:00 쓰러짐(clock.gd).
# 저승 톤: 한낮은 백색(1,1,1)으로 원색 도트를 그대로 두고, 밤은 서늘한 인디고로 가라앉힌다
# (검정 아님 — 플레이가 가능할 만큼은 보이게, 밤 바가 핵심 활동이므로).
const TINT_STOPS := [
	[360.0,  Color(0.46, 0.52, 0.74)],  # 06:00 서늘한 새벽(어둑·푸름)
	[480.0,  Color(1.00, 1.00, 1.00)],  # 08:00 한낮(원색)
	[990.0,  Color(1.00, 1.00, 1.00)],  # 16:30 한낮 끝
	[1080.0, Color(0.98, 0.80, 0.58)],  # 18:00 황혼(앰버)
	[1200.0, Color(0.52, 0.46, 0.62)],  # 20:00 땅거미
	[1320.0, Color(0.32, 0.34, 0.56)],  # 22:00 밤
	[1440.0, Color(0.27, 0.29, 0.52)],  # 24:00 깊은 밤(저승 인디고)
]

# ── 등불 세기 곡선 ─────────────────────────────────────────────────────────
# [게임 분, PointLight2D.energy]. 한낮엔 꺼지고(0) 황혼~밤에 켜진다. 19:00은 밤 바
# 영업 시작(night_bar.OPEN_MIN)이라 그때 확실히 들어오게 맞춘다. 새벽은 어둑해 약하게.
const LAMP_STOPS := [
	[360.0,  0.55],  # 06:00 새벽 어둑 → 약하게
	[480.0,  0.0],   # 08:00 한낮 → 꺼짐
	[1020.0, 0.0],   # 17:00 → 꺼짐
	[1140.0, 0.8],   # 19:00 밤 바 영업 시작 → 켜짐
	[1260.0, 1.0],   # 21:00 → 최대
	[1440.0, 1.0],   # 24:00
]

# 등불 빛 색(따뜻한 앰버) — 차가운 인디고 밤과 대비돼 카페·길이 온기로 떠오른다.
const LAMP_COLOR := Color(1.0, 0.74, 0.42)
const LAMP_TEXTURE_SCALE := 1.6  # 128px 텍스처 × 1.6 ≈ 반경 6칸 빛웅덩이

var _lamps: Array[PointLight2D] = []

# main이 등불(소울 등불) 픽셀 좌표를 넘겨 빛웅덩이를 만든다. 자리의 진실은 main의
# PROP_LAYOUT(LANTERN_TILES)이고, 여기선 그 위치에 빛만 얹는다(가구 그리기와 디커플링).
func setup(lamp_positions: PackedVector2Array) -> void:
	var tex := _make_light_texture()
	for pos in lamp_positions:
		var lamp := PointLight2D.new()
		lamp.texture = tex
		lamp.color = LAMP_COLOR
		lamp.texture_scale = LAMP_TEXTURE_SCALE
		lamp.energy = 0.0
		lamp.position = pos
		add_child(lamp)
		_lamps.append(lamp)

# 매 프레임 시각으로 화면 색조와 등불 세기를 갱신한다(연속 float이라 부드럽게 흐른다).
func apply(minutes: float) -> void:
	color = tint_for(minutes)
	var e := lamp_energy_for(minutes)
	for lamp in _lamps:
		lamp.energy = e

func tint_for(minutes: float) -> Color:
	return _sample_color(TINT_STOPS, minutes)

func lamp_energy_for(minutes: float) -> float:
	return _sample_float(LAMP_STOPS, minutes)

# ── 보간 헬퍼 ──────────────────────────────────────────────────────────────
# 키프레임 양 끝 밖은 끝값으로 고정(clamp), 사이는 선형 보간.
func _sample_color(stops: Array, m: float) -> Color:
	if m <= stops[0][0]:
		return stops[0][1]
	for i in range(1, stops.size()):
		if m <= stops[i][0]:
			var t := (m - float(stops[i - 1][0])) / (float(stops[i][0]) - float(stops[i - 1][0]))
			return Color(stops[i - 1][1]).lerp(stops[i][1], t)
	return stops[stops.size() - 1][1]

func _sample_float(stops: Array, m: float) -> float:
	if m <= stops[0][0]:
		return stops[0][1]
	for i in range(1, stops.size()):
		if m <= stops[i][0]:
			var t := (m - float(stops[i - 1][0])) / (float(stops[i][0]) - float(stops[i - 1][0]))
			return lerpf(stops[i - 1][1], stops[i][1], t)
	return stops[stops.size() - 1][1]

# 코드로 만든 방사형 그라데이션(중심 불투명 → 가장자리 투명) — 외부 에셋 없이 부드러운
# 빛웅덩이를 만든다(ADR-0001 글루 코드 허용, 변환 엔진 아님). 모든 등불이 한 장을 공유.
func _make_light_texture() -> Texture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.width = 128
	tex.height = 128
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	return tex
