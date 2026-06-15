extends RefCounted
class_name Foxfire
# T3.4 — 여우불 성장 촉진 규칙(관계 보상형 A): 미호 호감도 하트 → 여우불 도움 세기.
#
# 목적: ROADMAP T3.4 — "미호 호감도가 높을수록 작물이 더 빨리/넓게 자라는 차이가
#       체감된다"의 그 매핑을 한 곳에서 정의한다(CONTEXT '여우불 성장 촉진' = 방식 A
#       관계 보상형 — 호감도가 오를수록 여우불 도움이 강해진다, 가속 폭·범위↑).
#       속죄 테마(ADR-0004): 미호의 불은 태우는 불 → 키우는 불(양육의 불).
#
# 설계 메모:
#   - crops.gd(CropCatalog)와 같은 결: 이건 세이브 상태가 아니라 "정적 참조 규칙"이다.
#     여우불 세기는 호감도 하트에서 매번 파생되므로 자체 상태가 없다 → 세이브할 게
#     없다(SaveManager·main 세이브 불변). 그래서 씬 노드가 아니라 static const +
#     class_name으로 어디서든 Foxfire.accel(h)/Foxfire.reach(h)로 읽는다.
#   - 두 축으로 도움을 준다(둘 다 하트와 함께 커진다 — '빨리'와 '넓게'를 분리해 체감):
#       ㉠ 가속(accel): 물 준(자라는) 칸이 하룻밤에 추가로 자라는 일수(기본 +1 위에 더함).
#          → 같은 작물이 더 빨리 다 자란다('빨리').
#       ㉡ 범위(reach): 물을 못 준 심긴 칸을 여우불이 대신 돌봐 자라게 하는 최대 칸 수.
#          → 깜빡한 칸도 진척돼 밭 전체가 더 넓게 자란다('넓게').
#   - 하트0(아직 안 친함)에선 둘 다 0 = 여우불 잠듦(순수 스타듀 성장만). 관계가 오르면
#     깨어나 강해진다(보상이 관계에 게이팅 — 방식 A). field.gd는 이 값을 인자로 받아
#     적용만 하고 Affinity를 모른다(시그널/데이터 디커플링). 하트→세기 매핑은 여기 한 곳.
#   - 그레이박스 기준값이며 밸런싱은 후속(에셋·튜닝은 Phase 2 이후). 미니게임형(C,
#     불 직접 조절)은 후속 확장 서랍(CONTEXT) — 여기서는 다루지 않는다.

const MAX_HEARTS := Affinity.MAX_HEARTS  # 하트 상한(Affinity와 같은 5). 입력을 이 범위로 자름

# ── 조회(하트 단계 → 여우불 도움) ───────────────────────────────────────────
# 입력 하트를 [0, MAX_HEARTS]로 자른다(음수·범위 초과 방어).
static func _clamp_hearts(hearts: int) -> int:
	return clampi(hearts, 0, MAX_HEARTS)

# 가속 폭(추가 성장일수). 물 준 칸이 기본 +1 위에 이만큼 더 자란다.
#   하트:  0 1 2 3 4 5  →  0 0 1 1 2 2  (하트 2칸당 +1, 하트0이면 0=잠듦).
static func accel(hearts: int) -> int:
	return _clamp_hearts(hearts) / 2

# 범위(돌볼 칸 수). 물을 못 준 심긴 칸을 이 수만큼 여우불이 대신 자라게 한다.
#   하트:  0 1 2 3 4 5  →  0 1 2 3 4 5  (하트당 1칸, 하트0이면 0=잠듦).
static func reach(hearts: int) -> int:
	return _clamp_hearts(hearts)

# 여우불이 깨어 있는가(둘 중 하나라도 작동). 하트0이면 false(잠듦).
static func is_awake(hearts: int) -> bool:
	return accel(hearts) > 0 or reach(hearts) > 0

# HUD 한 줄 요약(현재 여우불 도움 상태). 관계→농사 보상을 눈에 보이게 한다(체감).
#   잠듦: "여우불: 잠듦 — 미호와 친해지면 깨어난다"
#   깨어남: "여우불: N칸 돌봄" (가속이 있으면 " · 자람 +M"을 덧붙임)
static func summary(hearts: int) -> String:
	if not is_awake(hearts):
		return "여우불: 잠듦 — 미호와 친해지면 깨어난다"
	var text := "여우불: %d칸 돌봄" % reach(hearts)
	var a := accel(hearts)
	if a > 0:
		text += " · 자람 +%d" % a
	return text
