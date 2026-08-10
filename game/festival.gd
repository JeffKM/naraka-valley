class_name Festival
extends RefCounted
# ★[S7-T6 / ADR-0065 결정 8] 카페 이벤트 데이(테마 데이) 규칙의 단일 출처 — **절기 달력판**.
#
# 목적: CONTEXT [카페 이벤트 데이] — 절기 안의 정해진 날 카페가 한 컨셉으로 맞춰진다(장식·의상·
#       메뉴·체키). 그날 메인 4인(미호·멜·바나·옥자) 의상이 바뀌고 카페 내부가 테마 장식으로
#       바뀌며, 손님이 붐비고 잔값에 테마 프리미엄이 얹힌다.
#
# ★ 이 파일이 예고한 교체가 여기서 일어났다: 옛 `CYCLE=14`(day 14·28·42…)는 달력이 없던 시절의
#   임시 트리거였고("캘린더가 생기면 이 한 곳만 교체" — 옛 주석), Slice 7이 절기 달력을 개통하며
#   **테마 데이 4종 × 각 절기 25일 고정 슬롯**으로 바뀌었다. 2주 주기는 폐기됐다.
#
# 설계 메모:
#   - store_discount.gd·cafe_margin.gd·weather.gd와 같은 결: 이 클래스는 *세이브 무상태 static
#     규칙*이다. 상태 변수도 시그널도 세이브 키도 0이다. 달력 위치는 day에서, 해금은 **호출 측이
#     넘겨 주는 진척값**(카페 단계·누적 서빙 매출)에서 매번 파생된다.
#   - ★ **해금 입력은 main이 주입한다**(무상태 유지의 핵심). Festival은 CafeMilestone도 main도
#     읽지 않고 `stage`·`revenue` 두 정수를 인자로 받는다 — cafe가 margin·spawn_scale을 주입만
#     받는 것과 같은 다리다. 그래서 헤드리스에서 임의의 진척을 꽂아 달력을 통째로 굴려 볼 수 있다.
#   - ★ **달력 슬롯(theme_slot_for_day) ↔ 실제 개최(theme_for_day)를 갈라 둔다.** 슬롯은 day만
#     알면 답이 나오는 순수 파생이고(날씨의 강제 평온이 이걸 본다 — 아래 참조), 개최는 거기에
#     해금을 곱한 것이다. 비해금 테마의 25일은 **평일**이다(발동 자체가 안 됨 — 배너도 효과도 0).
#   - ADR-0008: 테마 데이는 **옵트인 기회 오버레이**다. 안 열어도(그날 카페를 안 돌려도) 손실은
#     0이고, 해금 전에도 카페 루프는 base rate로 온전히 굴러간다("평평 ≠ 막힘"). 이 층은 카페를
#     키운 사람에게 얹히는 *결실*이지 통과해야 할 관문이 아니다.
#   - 효과 상수(붐빔·틴트·고깔·배너)는 **4테마 공통 그레이박스**다. 테마별 차별화(초상화 변형·
#     테마별 장식 색·전용 메뉴)는 아트 트랙 서랍이다(CONTEXT [의상 모델] 자산 천장 — "첫 테마는
#     그레이박스로 루프 검증 후 하나씩").

# ── 테마 4종 — 인덱스가 곧 절기 인덱스다(GameClock.season_index_for_day와 같은 눈금) ────
# 절기당 1개라 "이 절기의 테마"가 곧 인덱스 그 자체가 된다(별도 매핑표 없음 — CONTEXT 확정
# 로스터: 피안=메이드 · 유화=바캉스 · 망연=힙합 · 성야=크리스마스, 계절 결 기준 작가 배치).
const MAID := 0        # 피안절(봄) — 메이드 데이(게임 시작 절기 = 첫 해금·첫 체험)
const VACANCE := 1     # 유화절(여름) — 바캉스 데이
const HIPHOP := 2      # 망연절(가을) — 힙합 데이
const XMAS := 3        # 성야절(겨울) — 크리스마스 데이
const NONE := -1       # 테마 없음(평일) — 반환값 눈금

const NAMES := ["메이드 데이", "바캉스 데이", "힙합 데이", "크리스마스 데이"]

# 각 절기의 **25일**이 테마 데이 슬롯이다(CONTEXT "그 절기 후반 ≈25일경 고정"). 절기 28일 중
# 후반에 두는 이유는 예고 리듬이다 — 절기가 익을 즈음 기대가 쌓이고, 사멸(28일 밤)로 넘어가기
# 전 마지막 잔치가 된다("12월 크리스마스" 같은 현실 월 표기의 게임판).
const DAY_OF_SEASON := 25

# ── 해금 사다리(잠정 그레이박스 레버 — ADR-0065 결정 8) ──────────────────────
# CONTEXT ㉢ "로스터 = [카페 일구기] 진행으로 해금(초반 소박 → 명소로 클수록 더 화려)". 앞 둘은
# 카페 사다리 **단계**로, 뒤 둘은 그 위의 **누적 서빙 매출 눈금**으로 연다(2단이 사다리 꼭대기라
# 3단을 발명하는 대신 가법 눈금을 얹었다 — CafeMilestone에 새 단계를 만들면 좌석·곳간·메뉴판까지
# 함께 정의해야 하는데 그건 이 태스크의 몫이 아니다).
# ★ 두 조건은 **OR가 아니라 각 테마당 하나씩**이다: 앞 둘은 매출 눈금 0(단계만 본다), 뒤 둘은
#   단계 눈금 0(매출만 본다). 표를 한 모양으로 두면 판정이 한 줄로 끝난다(is_unlocked).
# ⚠️ 값은 전부 owner 결재 대상 레버다. 여기 한 표만 고치면 전 파급이 따라온다.
const UNLOCK_STAGE := [1, 2, 0, 0]           # CafeMilestone.STAGE_1 / STAGE_2 눈금(테스트가 상수 대응을 단언)
const UNLOCK_REVENUE := [0, 0, 5000, 12000]  # 누적 서빙 매출(냥) — 힙합·크리스마스

# ── 당일 효과(4테마 공통 그레이박스) ─────────────────────────────────────────
# ㉠ 손님이 붐빈다 — 스폰 간격 ×0.5(2배). ★이건 '활동 곱셈기'가 아니다(ADR-0008/0014 구분,
#    store_discount와 평행): 관계에서 파생되지 않는 시간 한정 이벤트 보너스라 메인 독점 곱셈기를
#    침범하지 않는다. 손님이 많아도 매출은 플레이어가 더 많이 *서빙해야* 오른다(base 메카닉이
#    더 도는 결).
const SPAWN_SCALE := 0.5

# ㉡ 테마 프리미엄 — 그날 전 메뉴 매출 ×1.25(밤 바까지 물든다).
# ⚠️ 이건 옛 주석이 못 박았던 "단가 불침범"의 **의도된 개정**이다(ADR-0065 결정 8이 명시 승인).
#    다만 멜 마진 축을 건드리는 건 아니다: 프리미엄은 margin을 *바꾸지 않고* 그 옆에 곱해지는
#    별도 인자다(cafe.serve_price = 메뉴가 × margin × theme_premium). 관계 곱셈기는 그대로 관계에서
#    파생되고, 프리미엄은 달력에서 파생된다 — 두 축이 섞이지 않는다. 근거: 테마 데이는 CONTEXT가
#    "테마 프리미엄 메뉴가 매출 증폭 = 카페 성장의 눈에 보이는 결실"로 정의한 층이라, 유입만 키우고
#    단가를 못 건드리면 그 정의가 성립하지 않는다.
const SERVE_PREMIUM := 1.25

# ㉢ 체키 보상 +50% — 서빙가에 이미 프리미엄이 얹힌 위에 한 겹 더(CONTEXT "체키 수요↑").
#    체키는 테마 의상·테마 장식을 배경으로 찍는 사진이라 테마 데이가 그 값의 본산이다.
const CHEKI_PREMIUM := 1.5

# 축제 의상 틴트(노드 modulate에 곱) — 도색 스프라이트·그레이박스 양쪽에 한 줄로 먹는
# 금빛 화사함. 평소 Color.WHITE에서 이 값으로 바뀌어 "오늘 차려입었다"가 한눈에 읽힌다.
const TINT := Color(1.18, 1.02, 0.72)

# 카페 축제 장식·머리 고깔 색(그레이박스 절차 도형). 홍·황 번갈아 = 잔치 가랜드 톤.
const BANNER_A := Color(0.86, 0.20, 0.24)  # 홍
const BANNER_B := Color(0.92, 0.74, 0.30)  # 황
const RUG := Color(0.62, 0.16, 0.20, 0.55) # 무대 카펫(반투명 — 바닥 위 덧깔기)

# ── 달력(day만 아는 순수 파생) ────────────────────────────────────────────────
# 이 날의 테마 **슬롯**(해금 무관 — 달력상 자리). day는 1부터(0·음수는 NONE — 손상 방어).
# ★ 해금을 안 보는 판정이 따로 있는 이유는 [저승 날씨]의 강제 평온 때문이다(아래 is_theme_slot).
static func theme_slot_for_day(d: int) -> int:
	if d <= 0 or GameClock.day_of_season(d) != DAY_OF_SEASON:
		return NONE
	return GameClock.season_index_for_day(d)

# 이 날이 달력상 테마 데이 자리인가(해금 무관).
# ★ **[저승 날씨]의 강제 평온이 보는 판정이 이것이다**(ADR-0065 결정 3 ↔ 8 접합). 강제 평온을
#   *개최* 여부가 아니라 *슬롯*으로 잡는 이유: 해금은 세이브 상태(매출·하트)에 걸려 있는데
#   Weather는 세이브를 모르는 순수 파생 롤이다. 슬롯 기준이면 Weather는 day 하나로 답을 내고
#   무상태가 보존된다. 부작용도 없다 — 해금 전이라 행사가 안 열리는 날에 하늘이 맑은 것은
#   누구도 손해 보지 않는 무해한 잉여다(그날 비가 안 온다고 막히는 것이 없다).
static func is_theme_slot(d: int) -> bool:
	return theme_slot_for_day(d) != NONE

# ── 해금(진척값은 호출 측이 주입 — 무상태 유지) ───────────────────────────────
# stage = 카페 일구기 단계(CafeMilestone.stage) · revenue = 누적 서빙 매출.
# 두 눈금 중 그 테마에 배정된 쪽만 실제로 문턱이 있고(다른 쪽은 0 = 무조건 통과), 결과적으로
# 메이드=1단 · 바캉스=2단 · 힙합=매출 5,000 · 크리스마스=매출 12,000이 된다.
static func is_unlocked(theme: int, stage: int, revenue: int) -> bool:
	if theme < 0 or theme >= NAMES.size():
		return false
	return stage >= int(UNLOCK_STAGE[theme]) and revenue >= int(UNLOCK_REVENUE[theme])

# 이 날 **실제로 열리는** 테마(달력 슬롯 ∧ 해금). 안 열리면 NONE = 평일.
# ★ 진척은 하루 중에도 자란다 — 25일 아침엔 잠겨 있다가 낮에 문턱을 넘으면 그 순간부터 테마
#   데이가 된다(파생값이라 주입 지점들이 다음 프레임에 따라붙는다). 하루를 못 기다리게 하는 쪽이
#   "결실"의 결에 맞고, 무상태 파생의 자연스러운 귀결이기도 하다.
static func theme_for_day(d: int, stage: int, revenue: int) -> int:
	var t := theme_slot_for_day(d)
	return t if is_unlocked(t, stage, revenue) else NONE

# 오늘이 이벤트 데이인가(= 열리는 테마가 있는가). 옛 `is_event_day(day)`의 자리를 잇되, 해금
# 입력을 받는다 — 달력만으로는 답이 안 나오기 때문이다(비해금 25일 = 평일).
static func is_event_day(d: int, stage: int, revenue: int) -> bool:
	return theme_for_day(d, stage, revenue) != NONE

# 테마 표시명("" = 범위 밖·평일). GameClock.season_name·Weather.name_of와 같은 관례.
static func name_of(theme: int) -> String:
	return NAMES[theme] if theme >= 0 and theme < NAMES.size() else ""

# ── 효과 조회(소비처가 값 하나만 물어보게 하는 얇은 표면) ──────────────────────
# ★ 인자가 day가 아니라 **테마**인 것이 옛 API와 갈리는 지점이다: 해금 판정을 아는 곳(main)이
#   테마를 한 번 파생해 두고 그 값을 각 seam에 흘려넣는다 — 각 소비처가 stage·revenue를 다시
#   들고 다닐 필요가 없고, CafeMilestone.spawn_scale_of(st)와 같은 모양이 된다.
# 손님 스폰 간격 배수(테마 데이 0.5=붐빔, 평일 1.0). ⚠️ main._refresh_cafe_ladder의 **단일 곱
# 자리**에서만 쓴다(축제 × 단계 × 날씨 — 따로 대입하면 먼저 쓴 값이 지워진다).
static func spawn_scale_of(theme: int) -> float:
	return SPAWN_SCALE if theme != NONE else 1.0

# 서빙 단가 배수(테마 데이 1.25, 평일 1.0) — cafe.theme_premium·night_bar.theme_premium에 주입.
static func serve_premium_of(theme: int) -> float:
	return SERVE_PREMIUM if theme != NONE else 1.0

# 체키 보상 배수(테마 데이 1.5, 평일 1.0) — cafe.cheki_premium에 주입. 서빙 프리미엄 *위에* 곱해져
# 테마 데이 체키는 평일 대비 1.25 × 1.5 = 1.875배가 된다(사슬 끝이 가장 굵다).
static func cheki_premium_of(theme: int) -> float:
	return CHEKI_PREMIUM if theme != NONE else 1.0

# ── 예고·배너 문구(main이 아침 알림·점괘 거울에 띄운다) ───────────────────────
# 당일 아침 배너. "오늘 카페가 무엇이 되는가" + 무엇이 달라지는가 한 줄.
static func banner_text(theme: int) -> String:
	if theme == NONE:
		return ""
	return "오늘은 %s — 손님이 몰리고 잔값이 오른다(체키는 더)" % name_of(theme)

# D-1 예고 배너(전날 아침). 스타듀 축제 예고의 자리 — 하루 전에 알아야 재료를 쟁이고 곳간을
# 채워 둘 수 있다(예고 = 준비할 시간을 주는 것이지 알림 그 자체가 아니다).
static func preview_text(theme: int) -> String:
	if theme == NONE:
		return ""
	return "내일은 %s — 곳간을 채워 두자" % name_of(theme)

# 점괘 거울 한 줄("N일 뒤: 메이드 데이"). days_ahead 0=오늘·1=내일.
static func upcoming_text(theme: int, days_ahead: int) -> String:
	if theme == NONE:
		return ""
	var when := "오늘" if days_ahead <= 0 else ("내일" if days_ahead == 1 else "%d일 뒤" % days_ahead)
	return "%s: %s" % [when, name_of(theme)]

# 캐릭터 머리 위 축제 고깔(홍 삼각 + 금빛 방울). 도색·그레이박스 공통 — 캐릭터 _draw가
# 스프라이트 위에도 덧그려 "축제 의상"을 명확히 한다. top_y = 머리 꼭대기 y(발치 원점 기준).
static func draw_hat(ci: CanvasItem, top_y: float) -> void:
	ci.draw_rect(Rect2(-3, top_y - 3, 6, 3), BANNER_A)   # 고깔 밑단(넓게)
	ci.draw_rect(Rect2(-2, top_y - 5, 4, 2), BANNER_A)   # 고깔 중단
	ci.draw_rect(Rect2(-1, top_y - 7, 2, 2), BANNER_B)   # 고깔 끝 금빛 방울
