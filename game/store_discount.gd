extends RefCounted
class_name StoreDiscount
# M2.3 — 네오 관계 보상축 = 만물상 매대 할인(점주 단골 퍼크): 네오 호감도 하트 → 씨앗·물품 소매 할인율.
#
# 목적: ROADMAP M2.3 — "네오와 친해질수록 만물상 매대에서 같은 씨앗을 더 싸게 산다"의 그 매핑을
#       한 곳에 정의한다. CONTEXT '주민': 가게를 운영하는 점주가 "가벼운 호감도로 할인" 단골 퍼크를
#       준다(원래 ADR-0014가 T2 점주에 둔 퍼크). 네오는 *T1 비인간(결혼 가능)*이지만 만물상을
#       *직업으로* 운영하므로, 이 할인은 그 가게 앞면의 단골 보상이다 — 네오의 T1 서사·결혼 깊이와는
#       별개의 *소매 퍼크*다(깊이는 관계 트랙, 이건 가게 정책).
#
# 설계 메모:
#   - cafe_margin.gd(CafeMargin)·foxfire.gd(Foxfire)와 같은 결: 세이브 상태가 아니라 "정적
#     참조 규칙"이다. 할인율은 네오 하트에서 매번 파생되므로 자체 상태가 없다 → 세이브할 게
#     없다(SaveManager·main 세이브 불변). 그래서 씬 노드가 아니라 static + class_name으로
#     어디서든 StoreDiscount.price(base, h)로 읽는다. main이 _buy_seed_store에서 이 값을 받아
#     씨앗값을 깎기만 하고, 이 클래스는 네오 호감도가 어디서 오는지 모른다(데이터 디커플링).
#
#   - ★ 이것은 '활동 곱셈기'가 아니다(ADR-0008 / ADR-0014 구분 — 중요):
#       · ADR-0008 곱셈기 = *활동 산출 rate*를 가속한다(미호=자동화로 덜 심어도 자람 · 멜=마진으로
#         같은 서빙이 비싸짐 · 바나=보호로 밤 손실↓). 이 곱셈기는 **메인 4인 독점**이고, 캐릭터마다
#         *종류*가 달라 직조를 만든다.
#       · 만물상 할인 = *소매 가격(경제 싱크)*을 깎는 퍼크다. 농사·카페·낚시·채광 어느 *활동의
#         산출 rate*도 가속하지 않는다 — 그냥 씨앗을 사는 비용을 줄일 뿐이다. 그래서 ADR-0014가
#         T2에 허용한 "할인 퍼크"에 해당하고, ADR-0008이 메인에 묶어 둔 "활동 곱셈기"를 침범하지
#         않는다(주민은 *넓이*만, 깊이·곱셈기는 메인). 폭도 메인 곱셈기보다 작게 둔다(보조 퍼크).
#
#   - ★ 게이트가 아니라 base 위에 얹는다(ADR-0008 "평평 ≠ 막힘"): ♡0에서도 할인율 1.0이라
#     만물상은 정가로 굴러간다(은둔 활동파도 막히지 않음 — 카페 출하대 씨앗값과 동일 정가).
#     네오와 친해지면 그 위에 할인이 얹혀 같은 씨앗이 싸진다(관계 = 의도된 이득). 멜 출하대는
#     이 할인을 받지 않는다 — 만물상만의 단골 퍼크다(서비스 분산, world-map.md).
#
#   - 매핑(그레이박스 기준값 — 수치 밸런싱은 Phase 2 서랍):
#       할인율 = BASE_FACTOR − PER_HEART × 하트 = 1.0 − 0.06 × 하트
#       하트:   0     1     2     3     4     5
#       할인율: 1.00  0.94  0.88  0.82  0.76  0.70   (♡5 = 30% 할인)
#     선형 한 식으로 닫힌다(cafe_margin과 대칭, 부호만 반대 — 마진은 오르고 할인율은 내린다).

const MAX_HEARTS := Affinity.MAX_HEARTS  # 하트 상한(Affinity와 같은 5). 입력을 이 범위로 자름
const BASE_FACTOR := 1.0    # ♡0 정가(할인 없음) — 게이트가 아니라 base(만물상은 ♡0에서도 굴러감)
const PER_HEART := 0.06     # 하트당 할인 폭(♡5 = 0.70 = 30% 할인). 메인 곱셈기보다 작은 보조 퍼크

# 입력 하트를 [0, MAX_HEARTS]로 자른다(음수·범위 초과 방어).
static func _clamp_hearts(hearts: int) -> int:
	return clampi(hearts, 0, MAX_HEARTS)

# ── 조회(main이 매대 가격에 곱할 할인율) ────────────────────────────────────
# 소매 할인율(0.70~1.00). ♡0이면 1.0(정가), 하트가 오를수록 선형으로 작아진다(최대 30% 할인).
static func factor(hearts: int) -> float:
	return BASE_FACTOR - PER_HEART * _clamp_hearts(hearts)

# 정가(base)에 할인을 먹인 실제 매대 가격(정수, 최소 1). 할인이 0원으로 내려가지 않게 막는다.
static func price(base: int, hearts: int) -> int:
	if base <= 0:
		return 0
	return maxi(1, int(round(base * factor(hearts))))

# 현재 할인 퍼센트(0~30) — HUD·디버그용. ♡0이면 0%.
static func percent(hearts: int) -> int:
	return int(round((1.0 - factor(hearts)) * 100.0))

# HUD 한 줄 요약(현재 네오 할인 상태). 관계→매대 이득을 눈에 보이게 한다(체감, ADR-0008 정신).
#   ♡0: "네오 할인: 정가 — 네오와 친해지면 매대가 싸진다"
#   ♡>0: "네오 할인: −12% (만물상 매대)"
static func summary(hearts: int) -> String:
	if _clamp_hearts(hearts) <= 0:
		return "네오 할인: 정가 — 네오와 친해지면 매대가 싸진다"
	return "네오 할인: −%d%% (만물상 매대)" % percent(hearts)
