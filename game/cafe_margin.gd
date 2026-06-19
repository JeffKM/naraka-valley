extends RefCounted
class_name CafeMargin
# T5.5 — 멜 관계 보상축 = 마진(관계 곱셈기, ADR-0008): 멜 호감도 하트 → 서빙 단가 배수.
#
# 목적: ROADMAP T5.5 — "멜과 친해질수록 같은 서빙이 더 비싸게 팔린다"의 그 매핑을 한 곳에
#       정의한다. 멜의 보상축은 미호=자동화(여우불 — 덜 심어도 자람)와 *종류*가 다르다:
#       멜=마진(같은 산출물이 비싸게 팔림). 둘이 곱해질 때 직조 쾌감이 난다(ADR-0008).
#       속죄 테마(ADR-0004): 멜의 돈 재주는 착취가 아니라 *환대*로 카페를 굴리는 데 쓴다.
#
# 설계 메모:
#   - foxfire.gd(Foxfire)와 같은 결: 이건 세이브 상태가 아니라 "정적 참조 규칙"이다.
#     마진은 멜 하트에서 매번 파생되므로 자체 상태가 없다 → 세이브할 게 없다(SaveManager·
#     main 세이브 불변, cafe.gd 세이브 무상태와 일관). 그래서 씬 노드가 아니라 static +
#     class_name으로 어디서든 CafeMargin.margin(h)로 읽는다. cafe.gd는 이 값을 margin
#     파라미터(★seam 2)로 받아 곱하기만 하고 멜 호감도를 모른다(시그널/데이터 디커플링).
#     하트→배수 매핑은 여기 한 곳 — Foxfire.accel/reach가 농사 쪽에서 맡는 자리의 카페판.
#   - ★ 곱셈기는 게이트가 아니라 base 위에 얹는다(ADR-0008 "평평 ≠ 막힘"): ♡0에서도
#     배수 1.0이라 카페는 base rate로 굴러간다(은둔 활동파도 안 막힘). 관계가 오르면 그
#     위에 *항상 명백히 우월한* 가속(더 비싼 단가)을 얹는다 — 관계 = 의도된 최적 경로.
#   - 매핑(ROADMAP 앵커 ♡0 ×1.0 / ♡2 ×1.4 / ♡5 ×2.0를 그대로 만족하는 선형식):
#       배수 = BASE_MARGIN + PER_HEART × 하트 = 1.0 + 0.2 × 하트
#       하트:  0   1   2   3   4   5
#       배수: 1.0 1.2 1.4 1.6 1.8 2.0
#     세 앵커가 한 직선 위에 떨어져 별도 분기 없이 한 식으로 닫힌다. 그레이박스 기준값이며
#     수치(기울기·상한)는 밸런싱 서랍(Phase 2 이후). 팁·단골 유입·고부가 주문은 2층 서랍.

const MAX_HEARTS := Affinity.MAX_HEARTS  # 하트 상한(Affinity와 같은 5). 입력을 이 범위로 자름
const BASE_MARGIN := 1.0   # ♡0 base rate. 곱셈기가 아니라 base — 카페는 ♡0에서도 굴러감
const PER_HEART := 0.2     # 하트당 마진 증가폭(♡0 ×1.0 → ♡2 ×1.4 → ♡5 ×2.0를 만족)

# 입력 하트를 [0, MAX_HEARTS]로 자른다(음수·범위 초과 방어).
static func _clamp_hearts(hearts: int) -> int:
	return clampi(hearts, 0, MAX_HEARTS)

# ── 조회(cafe.gd가 serve_price에 곱할 배수) ─────────────────────────────────
# 서빙 단가 배수. ♡0이면 1.0(base rate), 하트가 오를수록 선형으로 커진다(최대 2.0).
static func margin(hearts: int) -> float:
	return BASE_MARGIN + PER_HEART * _clamp_hearts(hearts)

# HUD 한 줄 요약(현재 멜 마진 상태). 관계→카페 보상을 눈에 보이게 한다(체감, ADR-0008).
#   ♡0: "멜 마진: ×1.0 — 멜과 친해지면 단가가 오른다"
#   ♡>0: "멜 마진: ×1.4 (서빙 +40%)"
static func summary(hearts: int) -> String:
	var m := margin(hearts)
	if _clamp_hearts(hearts) <= 0:
		return "멜 마진: ×%.1f — 멜과 친해지면 단가가 오른다" % m
	return "멜 마진: ×%.1f (서빙 +%d%%)" % [m, int(round((m - 1.0) * 100.0))]
