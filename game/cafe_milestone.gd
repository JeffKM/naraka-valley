extends RefCounted
class_name CafeMilestone
# T7.2 — 카페 마일스톤(매크로 목표, ADR-0009): 멀티루프 산출물을 요구하는 목표치 + 진행도.
# ★[S6-T3 / ADR-0064 결정 7] **1단 재정의 + 2단 실장** — 이 파일이 "카페 일구기 사다리"의 단일
#   출처가 된다(단계 판정 + 각 단계가 여는 콘텐츠 값). 아래 §S6-T3 블록 참조.
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
#   - ★[S6-T3 / ADR-0064 결정 7] **옥자 축 = 이 누적 서빙 매출이 대변한다**(⚠️잠정 — ADR-0032
#     해석이라 owner 결재 대상). ADR-0029 §4의 카페-도메인 3인은 옥자·미호·멜인데 옥자는 호감도
#     미터가 없는 앵커다(ADR-0032 — 선물·하트 트랙 없음). 그래서 옥자 몫으로 새 미터를 신설하지
#     않고 "카페 실적이 곧 옥자의 인정"으로 읽어 *이미 3축에 있는 매출 축*이 그 자리를 든다. 결과:
#     신설 세이브 조각 0 · 하트 축만 미호+멜 2인으로 좁힌다(TARGET_HEARTS 주석).
#   - 수치(목표치)는 그레이박스 기준값이며 밸런싱은 서랍이다(T7.3 슬라이스 21일 확장·곡선
#     재조정에서 "1단 완료 → 2단 갈망" 호에 맞춰 조정 — ROADMAP). 진짜 2단 콘텐츠는 Phase 3.

# ── 1단 목표치(멀티루프 산출물 — 각각 채워져야 1단 완료) ─────────────────────
# 세 루프에서 하나씩: 농사(거둔 영혼) · 카페/밤(누적 서빙 매출) · 관계(**카페-도메인 하트 합**).
const TARGET_HARVEST := 12   # 거둔 영혼(작물) — 농사 루프 산출물(_run_harvested 누적)
const TARGET_REVENUE := 400  # 누적 서빙 매출(카페 서빙 + 밤 응대) — 카페/밤 운영 루프 산출물
# ★[S6-T3 / ADR-0064 결정 7] 하트 축 = **미호+멜 두 사람 합**(최대 10). 8→6은 그 좁힘에 맞춘
#   문턱 하향이다(잠정 레버 — owner 결재 대상). 바나가 빠진 근거는 main._milestone_hearts() 주석.
const TARGET_HEARTS := 6     # 미호+멜 하트 합(최대 10) — 관계 루프 산출물

const BAR_CELLS := 5         # 진행 바 칸 수(그레이박스 텍스트 바)

# ── ★[S6-T3 / ADR-0064 결정 7] 2단 목표치 ────────────────────────────────────
# 1단과 **같은 세 축**을 더 높은 문턱으로 다시 요구한다(축을 새로 만들지 않는다 — 새 축은 새
# 미터·새 세이브 조각이고, 사다리는 "같은 루프를 더 깊이"라야 1단에서 배운 것이 그대로 산다).
# 전부 잠정 그레이박스 레버다(owner 결재 대상 — 21일 슬라이스 곡선에 맞춰 재조정, T7.3 서랍).
#   · 수확 12→40  = 밭을 한 계절 굴린 몸집
#   · 매출 400→1800 = 융합 메뉴가 실제로 팔려야 닿는 자리(기본 잔 정액만으로는 한참 모자라게)
#   · 하트 6→9    = 미호+멜 최대 10 중 9(만렙 요구는 아님 — "평평≠막힘"의 여지를 한 칸 남긴다)
const S2_TARGET_HARVEST := 40
const S2_TARGET_REVENUE := 1800
const S2_TARGET_HEARTS := 9

# ── ★[S10-T5 / ADR-0069 결정 8] 3단 목표치 — 「저승의 명소」 ────────────────────
# 3단은 앞의 두 단과 **축이 다르다**: 세 축 AND가 아니라 **누적 서빙 매출 단독**이다. 근거는
# ADR-0029 "옥자=정점"의 이행이다 — 옥자에게 호감도 미터가 없으므로(ADR-0032) 그 자리를 이미
# 3축에 있던 매출 축이 대신 들고([S6-T3] 결정 7이 깐 해석 그대로), 새 미터·새 세이브 조각을 0으로
# 둔다. 수확·하트를 다시 요구하지 않는 이유도 같다: 2단에서 이미 요구했고, 3단이 묻는 것은
# "이 카페가 얼마나 팔리는 곳이 되었나" 하나뿐이다.
# ★ 단조성은 stage()가 **2단 완료를 AND로 물고** 성립시킨다(문턱 하나만으론 3단이 2단을 함의하지
#   못하므로 — 매출만 높고 하트가 낮은 판이 3단으로 뛰는 사고를 구조로 막는다).
# ★ 잠정(owner 큐): 1800 → 5000 ≈ 2.8배. 2단이 "융합 메뉴가 실제로 팔려야 닿는 자리"였다면
#   3단은 **그 메뉴판으로 한 절기를 더 굴린 자리**다(2단 해금분 — 좌석 5·손님 볼륨 ×1/0.7 — 이
#   붙은 뒤의 벌이라 체감 거리는 배수보다 짧다).
const S3_TARGET_REVENUE := 5000

# ── ★[S6-T3] 사다리 단계 ─────────────────────────────────────────────────────
const STAGE_NONE := 0   # 1단 진행 중
const STAGE_1 := 1      # 1단 완료(2단 진행 중)
const STAGE_2 := 2      # 2단 완료(3단 진행 중)
# ★[S10-T5 / ADR-0069 결정 8] 3단 = 사다리의 **최종** 단계다(무한 사다리가 아니다 — 결정 8 자구
#   "단수를 3으로 확정"). 4단을 예고하는 문구는 이 파일 어디에도 두지 않는다.
const STAGE_3 := 3      # 3단 완료(사다리 꼭대기 — 「저승의 명소」)

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

# ── ★[S6-T3] 2단 — 1단과 같은 문법(AND 게이트·세이브 무상태·누적값 파생) ───────
static func s2_harvest_ratio(harvested: int) -> float:
	return _ratio(harvested, S2_TARGET_HARVEST)

static func s2_revenue_ratio(revenue: int) -> float:
	return _ratio(revenue, S2_TARGET_REVENUE)

static func s2_hearts_ratio(hearts: int) -> float:
	return _ratio(hearts, S2_TARGET_HEARTS)

static func s2_overall_ratio(harvested: int, revenue: int, hearts: int) -> float:
	return (s2_harvest_ratio(harvested) + s2_revenue_ratio(revenue) + s2_hearts_ratio(hearts)) / 3.0

# 2단 완료. ★ 2단 문턱은 1단 문턱보다 모든 축에서 크거나 같으므로 2단 완료는 1단 완료를 **함의**
# 한다(사다리 단조성 — stage()가 그 불변식 위에 선다. milestone_test가 상수 관계를 단언한다).
static func is_stage2_complete(harvested: int, revenue: int, hearts: int) -> bool:
	return harvested >= S2_TARGET_HARVEST and revenue >= S2_TARGET_REVENUE and hearts >= S2_TARGET_HEARTS

# ── ★[S10-T5] 3단 — 매출 단독 축이되 **2단 완료를 AND로 문다** ──────────────────
# 이 AND가 사다리 단조성의 전부다(3단 완료 ⇒ 2단 완료 ⇒ 1단 완료). 1·2단처럼 세이브 무상태고,
# 문턱 상수도 그대로라 **구세이브의 단계 판정은 한 칸도 안 움직인다**(3단 문턱을 못 넘으면 종전과
# 똑같이 2단으로 읽힌다 — 세이브 키를 신설하지 않았으므로 마이그레이션 자체가 없다).
static func is_stage3_complete(harvested: int, revenue: int, hearts: int) -> bool:
	return is_stage2_complete(harvested, revenue, hearts) and revenue >= S3_TARGET_REVENUE

# 3단 진행 비율(매출 단독 축 — 1·2단의 세 축 평균과 달리 축이 하나라 바가 곧 매출이다).
static func s3_overall_ratio(revenue: int) -> float:
	return _ratio(revenue, S3_TARGET_REVENUE)

# 현재 사다리 단계(STAGE_NONE / STAGE_1 / STAGE_2 / ★STAGE_3). 누적값에서 매번 파생 — 세이브 무상태.
static func stage(harvested: int, revenue: int, hearts: int) -> int:
	if is_stage3_complete(harvested, revenue, hearts):
		return STAGE_3
	if is_stage2_complete(harvested, revenue, hearts):
		return STAGE_2
	if is_complete(harvested, revenue, hearts):
		return STAGE_1
	return STAGE_NONE

# ★[S10-T5 / ADR-0069 결정 8] 3단이 여는 것 = **늘봄방 건축 해금**(목공방 매대 행의 잠금 해제).
#   seats_of·larder_capacity_of와 같은 자리에 둔 이유도 같다 — "어느 단계에 무엇이 열리나"의
#   단일 출처. 값(비용·공기)은 Carpenter가 자기 데이터로 들고, 여기선 *언제*만 고른다.
static func greenhouse_unlocked(st: int) -> bool:
	return st >= STAGE_3

# ── ★[S6-T3 / ADR-0064 결정 7] 단계 → 콘텐츠 값(카페 일구기 사다리 표) ────────
# "2단이 무엇을 여는가"의 단일 출처. main은 이 네 함수의 값을 각 시스템 seam에 *주입만* 한다
# (cafe.margin·spawn_scale과 같은 다리 — cafe도 larder도 마일스톤을 모른다).
# ★ 값 자체는 각 시스템이 자기 상수로 들고(Cafe.SEATS_* · Larder.CAPACITY_* · MenuCatalog.
#   FUSION_SLOTS_*), 여기선 **어느 단계에 어느 값인가**만 고른다 — 수치가 두 곳에 안 갈린다.
# ★ 상수 초기화식이 아니라 함수 안에서 타 클래스 상수를 읽는 건 이 저장소 관례다(로드 순서 의존 0 —
#   main._fallback_menu·ForageSpawns.zones와 같은 자리).
static func seats_of(st: int) -> int:
	return Cafe.SEATS_STAGE2 if st >= STAGE_2 else Cafe.SEATS_STAGE1

static func larder_capacity_of(st: int) -> int:
	return Larder.CAPACITY_STAGE2 if st >= STAGE_2 else Larder.CAPACITY

static func fusion_slots_of(st: int) -> int:
	return MenuCatalog.FUSION_SLOTS_STAGE2 if st >= STAGE_2 else MenuCatalog.FUSION_SLOTS_STAGE1

# 손님 스폰 간격 배수(작을수록 자주 = 붐빔). 2단 = 익명 손님 볼륨 증가(ADR-0064 결정 7 — T4 손님
# 풀 태스크의 *명명 단골·단골화 원장*과는 갈린다. 여기서 여는 건 **현행 스폰 볼륨 레버 하나**뿐).
# ★ 축제 배수(Festival.spawn_scale)와 **곱해서** 얹는다 — 축제일에 2단이면 둘 다 걸린다.
const SPAWN_SCALE_STAGE2 := 0.7

static func spawn_scale_of(st: int) -> float:
	return SPAWN_SCALE_STAGE2 if st >= STAGE_2 else 1.0

# ── 표시 문구(main이 HUD·팝업에 띄운다) ──────────────────────────────────────
# 진행 바 텍스트("▰▰▰▱▱"). 채운 칸은 비율을 BAR_CELLS로 반올림해 정한다.
static func bar(ratio: float) -> String:
	var filled := int(round(clampf(ratio, 0.0, 1.0) * BAR_CELLS))
	return "▰".repeat(filled) + "▱".repeat(BAR_CELLS - filled)

# HUD 한 줄(상시 노출 — 매크로 목표 진행 바). 바 + 세 하위 분해(어느 루프가 뒤처지는지 보이게 —
# 멀티루프 요구를 눈에). ★[S6-T3] **현재 단계의 문턱**을 보여 준다: 1단을 채우면 줄이 "카페 1단
# 완료 ★"로 멈추는 게 아니라 곧바로 2단 문턱으로 갈아탄다(사다리 — 다음 칸이 늘 보인다).
# 꼭대기(2단 완료)에서만 달성 문구로 굳는다.
static func summary(harvested: int, revenue: int, hearts: int) -> String:
	var st := stage(harvested, revenue, hearts)
	# ★[S10-T5] 꼭대기가 3단으로 올라갔다 — 2단을 채워도 줄은 굳지 않고 **3단 문턱으로 갈아탄다**
	#   (사다리 규칙 1:1 승계). 3단은 축이 매출 하나라 하위 분해도 그 한 축만 적는다.
	if st >= STAGE_3:
		return "카페 3단 완료 ★ — 저승의 명소가 되었다"
	if st >= STAGE_2:
		var r3 := s3_overall_ratio(revenue)
		return "카페 3단 %s %d%%  ·  매출 %d/%d" % [bar(r3), int(round(r3 * 100.0)),
			revenue, S3_TARGET_REVENUE]
	var r := s2_overall_ratio(harvested, revenue, hearts) if st >= STAGE_1 else overall_ratio(harvested, revenue, hearts)
	var th := S2_TARGET_HARVEST if st >= STAGE_1 else TARGET_HARVEST
	var tr := S2_TARGET_REVENUE if st >= STAGE_1 else TARGET_REVENUE
	var the := S2_TARGET_HEARTS if st >= STAGE_1 else TARGET_HEARTS
	return "카페 %d단 %s %d%%  ·  영혼 %d/%d  ·  매출 %d/%d  ·  친밀 %d/%d" % [
		st + 1, bar(r), int(round(r * 100.0)),
		harvested, th, revenue, tr, hearts, the,
	]

# ★ C3 시계 클러스터 곁 compact 한 줄(미니멀 HUD — 매크로 목표를 글랜서블하게, ADR-0018). 상시
# 라벨 난립을 정리하며 마일스톤은 시계 옆 작은 진행 표시로 남는다(ADR-0009 "왜 다 하지"의 글랜스
# 신호 유지). 완료 전엔 바+%만(하위 분해는 완료 팝업/관계 탭이 든다), 완료 후엔 "완료 ★".
static func compact(harvested: int, revenue: int, hearts: int) -> String:
	var st := stage(harvested, revenue, hearts)
	if st >= STAGE_3:
		return "카페 3단 완료 ★"
	if st >= STAGE_2:
		var r3 := s3_overall_ratio(revenue)
		return "카페 3단 %s %d%%" % [bar(r3), int(round(r3 * 100.0))]
	var r := s2_overall_ratio(harvested, revenue, hearts) if st >= STAGE_1 else overall_ratio(harvested, revenue, hearts)
	return "카페 %d단 %s %d%%" % [st + 1, bar(r), int(round(r * 100.0))]

# 2단 조건 미리보기 한 줄(ADR-0009 — 1단을 채운 순간 "다음 칸이 무엇인지"를 건다).
# ★[S6-T3] 2단이 **진짜 콘텐츠**가 됐으므로(좌석·곳간·메뉴판·손님) 문구도 그 실물을 말한다.
#   수치는 사다리 표에서 파생한다 — 레버를 돌리면 문구가 저절로 따라온다(문자열에 숫자 안 박음).
#   종전의 "삼도천 낚시가 다음 재료" 떡밥은 Slice 3에서 낚시가 실제로 개통돼 소임을 다했다.
# ★[S10-T5] 3단 미리보기 한 줄. 2단 미리보기와 같은 결이되 **축이 하나**라 문구도 한 축만 말한다
#   ("무엇을 더 해야 하나"가 매출 하나로 또렷한 것이 3단의 성격이다). 수치는 상수 파생 — 문자열에
#   숫자를 안 박는다(2단 미리보기와 같은 규칙).
static func stage3_preview() -> String:
	return "3단 미리보기: 누적 서빙 매출 %d → 「저승의 명소」 · 늘봄방(온실)을 지을 수 있게 된다" % S3_TARGET_REVENUE

static func stage2_preview() -> String:
	return "2단 미리보기: 좌석 %d→%d · 곳간 %d→%d · 메뉴판 %d→%d칸 · 손님이 더 몰린다" % [
		seats_of(STAGE_1), seats_of(STAGE_2),
		larder_capacity_of(STAGE_1), larder_capacity_of(STAGE_2),
		fusion_slots_of(STAGE_1), fusion_slots_of(STAGE_2),
	]

# 1단 달성 팝업 본문(여러 줄). 채우는 순간 한 번 뜬다(main이 일시 표시 — 비차단 자동 해제).
static func reached_text() -> String:
	return "\n".join([
		"───  카페 2단계!  ───",
		"한산하던 저승 카페에 온기가 돈다.",
		"",
		stage2_preview(),
	])

# ★[S6-T3] 2단 달성 팝업 본문. 1단 래치 선례를 그대로 따른다(main이 별도 래치로 1회만 띄운다).
# 1단이 "예고"였다면 2단은 *그 예고가 실제로 열렸음*을 확인해 준다 — 그래서 문구가 열린 것을 센다.
# ★[S10-T5] 종전의 "3단 콘텐츠가 아직 없어 3단계를 약속하지 않는다"는 단서는 **소임을 다했다** —
#   이 슬라이스가 3단을 실제로 지었으므로, 1단 팝업이 2단을 걸었던 그 자격으로 3단을 예고한다.
static func reached2_text() -> String:
	return "\n".join([
		"───  카페 2단 완성!  ───",
		"소문을 듣고 온 넋들로 자리가 모자란다.",
		"",
		"좌석 %d칸 · 곳간 %d칸 · 메뉴판 %d칸이 열렸다." % [
			seats_of(STAGE_2), larder_capacity_of(STAGE_2), fusion_slots_of(STAGE_2)],
		"",
		stage3_preview(),
	])

# ★[S10-T5 / ADR-0069 결정 8] 3단 달성 팝업 — 사다리의 **마지막 칸**이라 문구가 다음을 예고하지
#   않고 도착을 말한다(무한 사다리가 아니다). 여는 것은 늘봄방 하나뿐이므로 그것만 정확히 센다.
static func reached3_text() -> String:
	return "\n".join([
		"───  저승의 명소  ───",
		"삼도천 건너에서까지 넋들이 이 등불을 찾아온다.",
		"카페 일구기가 꼭대기에 닿았다.",
		"",
		"목공방에 늘봄방 도면이 걸렸다 — 절기가 바뀌어도 시들지 않는 밭.",
	])
