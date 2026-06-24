extends RefCounted
class_name CafeMilestone
# T7.2 — 카페 마일스톤 1단(매크로 목표, ADR-0009): 멀티루프 산출물을 요구하는 목표치 + 진행도.
#
# 목적: ROADMAP T7.2 / ADR-0009 — "카페를 저승의 명소로 일구기"라는 매크로 목표(우리의
#       커뮤니티 센터 번들)의 *1단 그레이박스*를 한 곳에 정의한다. 스타듀의 번들이 "왜 이
#       산출물을 모으지?"에 답하듯, 마일스톤 1단은 **세 루프(농사·카페·관계)의 산출물을
#       동시에 요구**해 세 루프가 *함께 향하는 곳*을 만든다. 채우면 "카페 2단계!"가 뜨고
#       2단 미리보기 한 줄로 깊이를 암시한다(T3.5 사연 한 줄처럼 저비용 암시 — 진짜 카페
#       성장 시스템[새 구역·메뉴·손님층]은 게이트 통과 후 Phase 3, ADR-0009).
#
# 설계 메모:
#   - foxfire.gd(Foxfire)·cafe_margin.gd(CafeMargin)·summary.gd(RunSummary)와 같은 결:
#     이건 세이브 상태가 아니라 "정적 참조 규칙·문구"다. 1단 달성 여부는 *이미 저장되는*
#     누적값(거둔 영혼·누적 서빙 매출·세 호감도 하트)에서 매번 파생되므로(RunSummary.is_over가
#     day에서 파생되듯) 자체 상태가 없다 → 세이브할 게 없다. 그래서 씬 노드가 아니라 static +
#     class_name으로 어디서든 CafeMilestone.is_complete(...)로 읽는다. 진행도·달성·미리보기
#     문구만 여기서 조립하고, 화면에 언제·어떻게 띄울지(HUD 바·달성 팝업)는 main이 맡는다
#     (데이터/표시 디커플링 — 다른 시스템과 동일).
#   - ★ 멀티루프 요구(ADR-0009 핵심): 세 하위 목표가 *각각* 채워져야 1단이 닫힌다(AND 게이트).
#     진행 바 하나(overall_ratio)는 세 비율의 평균이라 *셋 다* 100%일 때만 100%가 된다 —
#     한 루프만 갈아서는 바가 안 찬다. 이게 "왜 농사·카페·관계를 다 하지?"에 스타듀 번들처럼
#     답한다(하위 분해를 HUD에 노출해 어느 루프가 뒤처지는지 보이게 한다).
#   - ★ "카페 매출"은 *서빙* 매출만 센다(카페 손님 서빙 + 밤 바 응대) — 출하대 raw 판매는
#     제외한다(ADR-0009 "운영 가능한 무대"). 마일스톤이 *카페를 운영하는 쪽*으로 당겨야
#     매크로 목표가 산다 — raw 덤프로 빠르게 골드를 벌어도 카페는 안 자란다(직조 긴장과 일관:
#     raw 덤프 vs 서빙, ADR-0008 희소성). 누적은 main이 _try_serve/_try_night_serve에서 쌓는다.
#   - 수치(목표치)는 그레이박스 기준값이며 밸런싱은 서랍이다(T7.3 슬라이스 21일 확장·곡선
#     재조정에서 "1단 완료 → 2단 갈망" 호에 맞춰 조정 — ROADMAP). 진짜 2단 콘텐츠는 Phase 3.

# ── 1단 목표치(멀티루프 산출물 — 각각 채워져야 1단 완료) ─────────────────────
# 세 루프에서 하나씩: 농사(거둔 영혼) · 카페/밤(누적 서빙 매출) · 관계(세 동료 하트 합).
const TARGET_HARVEST := 12   # 거둔 영혼(작물) — 농사 루프 산출물(_run_harvested 누적)
const TARGET_REVENUE := 400  # 누적 서빙 매출(카페 서빙 + 밤 응대) — 카페/밤 운영 루프 산출물
const TARGET_HEARTS := 8     # 세 동료 하트 합(미호+멜+바나, 최대 15) — 관계 루프 산출물

const BAR_CELLS := 5         # 진행 바 칸 수(그레이박스 텍스트 바)

# ── 진행도(각 하위 목표의 채움 비율 [0,1]) ───────────────────────────────────
# 목표가 0 이하면(방어) 이미 채운 것으로 본다(0 나눗셈 방지).
static func _ratio(value: int, target: int) -> float:
	if target <= 0:
		return 1.0
	return clampf(float(value) / float(target), 0.0, 1.0)

static func harvest_ratio(harvested: int) -> float:
	return _ratio(harvested, TARGET_HARVEST)

static func revenue_ratio(revenue: int) -> float:
	return _ratio(revenue, TARGET_REVENUE)

static func hearts_ratio(hearts: int) -> float:
	return _ratio(hearts, TARGET_HEARTS)

# 진행 바 하나(세 비율의 평균). 각 비율이 [0,1]로 잘려 있어 평균=1.0은 *셋 다* 1.0일
# 때만 성립한다 — 한 루프만 초과 달성해도 바를 못 채운다(멀티루프 요구를 바 하나로 표현).
static func overall_ratio(harvested: int, revenue: int, hearts: int) -> float:
	return (harvest_ratio(harvested) + revenue_ratio(revenue) + hearts_ratio(hearts)) / 3.0

# 1단 완료 = 세 하위 목표가 *각각* 달성(AND 게이트 — overall_ratio==1.0과 동치). 누적값에서
# 매번 파생되므로(세이브 무상태) 이어받은 세이브가 이미 넘겼으면 시작 시 바로 완료로 보인다.
static func is_complete(harvested: int, revenue: int, hearts: int) -> bool:
	return harvested >= TARGET_HARVEST and revenue >= TARGET_REVENUE and hearts >= TARGET_HEARTS

# ── 표시 문구(main이 HUD·팝업에 띄운다) ──────────────────────────────────────
# 진행 바 텍스트("▰▰▰▱▱"). 채운 칸은 비율을 BAR_CELLS로 반올림해 정한다.
static func bar(ratio: float) -> String:
	var filled := int(round(clampf(ratio, 0.0, 1.0) * BAR_CELLS))
	return "▰".repeat(filled) + "▱".repeat(BAR_CELLS - filled)

# HUD 한 줄(상시 노출 — 매크로 목표 진행 바). 완료 전엔 바 + 세 하위 분해(어느 루프가
# 뒤처지는지 보이게 — 멀티루프 요구를 눈에), 완료 후엔 달성 + 2단 미리보기.
static func summary(harvested: int, revenue: int, hearts: int) -> String:
	if is_complete(harvested, revenue, hearts):
		return "카페 1단 완료 ★ — %s" % stage2_preview()
	var r := overall_ratio(harvested, revenue, hearts)
	return "카페 1단 %s %d%%  ·  영혼 %d/%d  ·  매출 %d/%d  ·  친밀 %d/%d" % [
		bar(r), int(round(r * 100.0)),
		harvested, TARGET_HARVEST, revenue, TARGET_REVENUE, hearts, TARGET_HEARTS,
	]

# ★ C3 시계 클러스터 곁 compact 한 줄(미니멀 HUD — 매크로 목표를 글랜서블하게, ADR-0018). 상시
# 라벨 난립을 정리하며 마일스톤은 시계 옆 작은 진행 표시로 남는다(ADR-0009 "왜 다 하지"의 글랜스
# 신호 유지). 완료 전엔 바+%만(하위 분해는 완료 팝업/관계 탭이 든다), 완료 후엔 "완료 ★".
static func compact(harvested: int, revenue: int, hearts: int) -> String:
	if is_complete(harvested, revenue, hearts):
		return "카페 1단 완료 ★"
	var r := overall_ratio(harvested, revenue, hearts)
	return "카페 1단 %s %d%%" % [bar(r), int(round(r * 100.0))]

# 2단 조건 미리보기 한 줄(ADR-0009 — 깊이를 *암시*만, 진짜 2단은 Phase 3). 측정 신호
# "1단 깨니 2단 갈망하나"의 갈망을 거는 자리. 삼도천 낚시(game-loops §2.2)를 떡밥으로 — "왜
# 낚시를 하지?"의 답이 카페 성장임을 미리 비춘다(ADR-0009 번들 구조).
static func stage2_preview() -> String:
	return "2단 미리보기: 새 단골·메뉴가 열린다 (삼도천 낚시·가공이 다음 재료 — Phase 3)"

# 1단 달성 팝업 본문(여러 줄). 채우는 순간 한 번 뜬다(main이 일시 표시 — 비차단 자동 해제).
static func reached_text() -> String:
	return "\n".join([
		"───  카페 2단계!  ───",
		"한산하던 저승 카페에 온기가 돈다.",
		"",
		stage2_preview(),
	])
