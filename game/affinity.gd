extends Node
class_name Affinity
# T3.3 — 호감도(하트): 미호와의 관계 수치.
#
# 목적: "일일 대화(하루 1회 소폭)와 선물(영혼 호박 선호)로 호감도가 오르고,
#       하트 단계가 UI에 반영된다"를 회색 UI만으로 검증한다
#       (ADR-0001 그레이박스, CONTEXT '호감도').
#
# 설계 메모:
#   - energy.gd·wallet.gd와 같은 결: 이 노드는 "미호 호감도 수치"라는 단일 책임만
#     가진다. 대화/선물 트리거(말걸기)·HUD 표시·여우불 연동(T3.4)은 main이 맡고,
#     여기서는 상태(누적 점수·마지막 행동 날)와 changed 시그널만 제공한다.
#   - 두 채널로 오른다 — ㉠ 일일 대화(하루 1회 소폭, 느린 채널) ㉡ 선물(선호 작물 큰
#     폭, 빠른 채널). 둘 다 "하루 1회" 리듬에 맞춰 게임 날짜로 게이팅한다(같은 날
#     중복 보상 방지). 무엇이 '오늘'인지의 트리거 값(GameClock.day)은 main이 넘긴다.
#   - 하트 = 점수 / POINTS_PER_HEART(내림). MAX_HEARTS에서 멈춘다. CONTEXT '호감도'의
#     이중 보상(농사 효율↑ = 여우불 강화 T3.4 / 서사↑ = 미호 대사 변화)이 이 하트
#     단계 위에 얹힌다(여기서는 단계 값만 제공, 보상 연결은 각 시스템이 맡음).
#   - ★[S8-T2] 선호 판정은 이 노드에 없다 — 무엇을 얼마나 좋아하는가는 GiftPrefs(전 아이템
#     × 9인 테이블)가 소유하고, 여기는 그 결과 점수를 받아 "하루 1회"로 게이팅해 누적한다.
#   - ★[S8-T3] 그 "리듬" 축이 셋으로 늘었다 — **하루 1회 · 주 2회 · 생일 ×8**(ADR-0066 결정 3).
#     셋 다 *날짜*로만 갈리는 판단이라 전부 이 노드가 든다(아이템은 여전히 GiftPrefs 소관).
#     주(week)는 상태가 아니라 GameClock.week_of(day) 파생이고, 생일 판정도 상태가 아니라
#     Resident.BIRTHDAYS 테이블 조회다 — 이 노드는 결과 플래그 하나만 인자로 받는다.
#   - ★[S8-T4] 채널이 넷이 됐다 — 대화·선물·의뢰(add_points)에 **활동 실적**(activity_gain)이
#     붙는다(ADR-0066 결정 4). 무엇이 실적인지는 여전히 main이 알고, 여기는 일일 캡만 든다.
#   - ★[S8-T5 / ADR-0066 결정 5] **stage(진급된 칸)와 points(점수)가 분리됐다.** 점수가 만충해도
#     하트가 자동으로 오르지 않는다 — hearts()는 이제 점수 파생이 아니라 **진급된 칸(stage)**을
#     돌려주고, 점수는 그 위에서 자유롭게 쌓인다("점수는 만충 상태로 대기"). 진급은 main의 단계
#     관문(대화 트리거 + 메인 3인 deed AND)이 promote()를 불러야만 일어난다. 관문이 *무엇*인지
#     (장소·deed·비트 원장)는 이 노드가 모른다 — 여기는 "대기 중인가(pending_promotion)"와
#     "한 칸 올려라(promote)"라는 상태 전이만 소유한다(리듬·누적만 든다는 단일 책임 그대로).
#   - T2.5 세이브/로드 — 상태가 정수 셋(점수·마지막 대화날·마지막 선물날)뿐이라
#     그대로 직렬화된다. 복원 시 점수는 [0, MAX_POINTS]로 잘라 손상 세이브에 방어한다.

signal changed(points: int, hearts: int)  # 호감도가 바뀐 프레임(main이 HUD 갱신)

const MAX_HEARTS := 5             # 그레이박스 하트 단계 수(밸런싱은 후속)

# ── 곡선 스케일 ─────────────────────────────────────────────────────────────
# 하트 한 칸 = 60점(만렙 300점). **값은 T7.3 이후 한 번도 안 바뀌었고 여기서도 안 바꾼다**
# (ADR-0066 결정 1 "값 유지·도출식만 절단" — 동작 완전 불변이 이 편집의 전부다).
#
# 유래(보존용 기록): T4.3이 14일 슬라이스 기준으로 하트당 40점을 잡았고(대화 8점/일만으로
# ♡1≈D5·♡2≈D10 — miho-heart-arc 목표 곡선), T7.3이 21일 런에 맞춰 가로축만 늘려
# 40 × 21/14 = 60점/칸이 됐다. 그 60이 지금 값이다.
#
# ★[S8-T4 / ADR-0066 결정 1] **사장 참조 절단**: 옛 코드는 이 60을
# `BASELINE_POINTS_PER_HEART * RunSummary.RUN_DAYS / BASELINE_DAYS`로 *계산*했다. 그런데
# S7이 21일 런 게이트를 폐지해(절기 달력 개통) `RunSummary.RUN_DAYS`는 **더는 아무 것도
# 결정하지 않는 사장 상수**가 됐다 — 엔딩 화면이 재사용할 자산으로 남아 있을 뿐이다. 죽은
# 상수를 곡선의 단일 진실원으로 두면 ㉠"런 길이를 고치면 관계 곡선이 따라온다"는 계약이
# 거짓이 되고 ㉡그 상수를 정리하려는 다음 사람이 관계 곡선을 모르고 흔든다. 그래서 값은
# 그대로 둔 채 도출식만 끊어 명시 상수로 박는다.
#
# ★[S8-T3이 적발한 비율 경보 — owner 큐] 만렙이 300점이라 **생일 러브 선물 한 번(40×8=320)이
#   미터를 통째로 채운다**(스타듀는 640/2500 ≈ 미터의 26%). 봉합한다면 생일 배율이 아니라
#   *이 60을* 올리는 쪽이 맞지만, **눈금 재조정은 owner 결재 사안**이라(ADR-0066 결정 1이
#   "값 불변"을 확정) 여기서는 손대지 않고 사실만 남긴다.
const POINTS_PER_HEART := 60                       # 하트 한 칸(= 옛 40 × 21/14)
const MAX_POINTS := MAX_HEARTS * POINTS_PER_HEART  # 만렙 점수(여기서 멈춤 — 300)

# T4.3 밸런싱: 5→8. 느린 대화 채널을 키워, 선물 없이 대화만으로도 14일에 ♡2 후반에
# 닿게 한다(여우불 ♡2 '번짐'까지 보장). ♡3은 선물(영혼 호박 등)이 밀어 올린다.
const DAILY_TALK_POINTS := 8         # 일일 대화 1회 소폭(느린 채널)
# ★[S8-T2 / ADR-0066 결정 2] 이 두 눈금은 이제 **GiftPrefs의 뉴트럴·러브 등급**이다(옛 "일반
#   선물 / 선호 작물 선물"이 그대로 승계됐다). 값의 주인은 여기로 두되(quest_board가 "선물
#   1회급" 눈금으로 GIFT_POINTS를 계속 참조한다 — 눈금이 갈리면 의뢰 보상이 조용히 어긋난다),
#   **무엇이 몇 점인가의 판정은 GiftPrefs가 소유**한다. 이 노드는 판정에 관여하지 않는다.
const GIFT_POINTS := 15              # 뉴트럴 등급(옛 일반 작물 선물)
const GIFT_PREFERRED_POINTS := 40    # 러브 등급(옛 선호 작물 선물 — 빠른 채널)

# ── ★[S8-T3 / ADR-0066 결정 3] 선물의 두 번째 리듬: 인당 주 2회 ─────────────
# 스타듀 동형. "하루 1회"만 있으면 선물이 매일의 의무가 되어(28일 절기 = 28회) 관계가 출석
# 체크로 굳는다 — 주 2회 상한이 그 그라인드를 끊고, 아낀 날을 대화·활동 채널이 채운다.
# ★ 하루 1회를 대체하는 게 아니라 **위에 AND로 얹힌다**: 같은 날 두 번도 막고(옛 규칙),
#   같은 주 세 번도 막는다(새 규칙).
# ★ 결혼 후 이 상한이 풀린다(ADR-0066 결정 8 — S8-T7 소관). 그래서 판정을 can_gift 한 곳에
#   모아 뒀다: 그때 예외 인자 하나가 늘 뿐 호출부는 안 바뀐다.
const GIFTS_PER_WEEK := 2

# 생일 배율(스타듀 1:1 — 러브부터 헤이트까지 전 등급에 곱한다. 음수도 ×8이지만 _add의 0 하한이
# 받아 준다 — 영구 적대 없음). ★배율이 GiftPrefs가 아니라 **여기** 있는 이유: 무엇이 몇 점인가는
# 아이템×사람의 판정(GiftPrefs 소유)이고, 오늘이 무슨 날인가는 **리듬**(하루 1회·주 2회와 같은
# 날짜 축 = Affinity 소유)이다. 배율을 GiftPrefs.POINTS에 섞으면 quest_board가 "선물 1회급"으로
# 참조하는 GIFT_POINTS 눈금이 날짜에 따라 흔들린다 — 그 결합을 건드리지 않으려면 여기가 맞다.
# ★잠정 경보(owner 큐 — 값은 ADR-0066 결정 3이 "스타듀 동형"으로 확정한 그대로 태웠다): 우리
#   5-스케일에선 만렙이 MAX_POINTS=300이라 **생일 러브 선물 한 번(40×8=320)이 미터를 통째로
#   채운다**(스타듀는 80×8=640 / 만렙 2500 ≈ 2.5하트). 눈금을 맞추려면 ×8이 아니라 곡선 쪽
#   (POINTS_PER_HEART)을 늘리는 게 맞고, 그건 S8-T4 소관이라 여기선 손대지 않는다. 초과분은
#   _add의 상한이 조용히 흡수한다(반환값은 명목 320 그대로 — 플레이어에겐 그게 사실이다).
const BIRTHDAY_MULT := 8

var points: int = 0
# ★[S8-T5 / ADR-0066 결정 5] 진급된 하트 칸(0..MAX_HEARTS). points에서 파생되지 않는 **독립 상태**다 —
#   점수가 만충해도 관문(promote)을 지나기 전엔 안 오른다. 곱셈기(여우불·마진·경비·할인)·대사 묶음이
#   전부 hearts()=stage를 읽으므로, "친해진 효과"는 관문을 지난 칸에서만 나온다.
var stage: int = 0
var last_talk_day: int = -1   # 마지막으로 일일 대화 보상을 받은 게임 날(-1 = 아직 없음)
var last_gift_day: int = -1   # 마지막으로 선물한 게임 날(-1 = 아직 없음)
# 주간 카운터(세이브 **가법 키** — 구세이브엔 없어 기본값으로 시작한다).
var gift_week: int = -1       # gifts_this_week가 속한 주(GameClock.week_of · -1 = 아직 없음)
var gifts_this_week: int = 0  # 그 주에 이미 건넨 횟수

# ── 조회 ──────────────────────────────────────────────────────────────────
# 현재 하트 단계(0..MAX_HEARTS). ★[S8-T5] 점수 파생(points/60 내림)이 아니라 **진급된 칸**이다 —
# 옛 의미가 필요한 곳(진급 대기 판정)은 points_hearts()를 쓴다.
func hearts() -> int:
	return mini(stage, MAX_HEARTS)

# 점수가 *허용하는* 하트 단계(옛 hearts()의 파생식 그대로). stage와의 차가 곧 대기 중인 진급이다.
func points_hearts() -> int:
	return mini(points / POINTS_PER_HEART, MAX_HEARTS)

# 진급 대기 중인가 — 점수는 다음 칸을 채웠는데 관문을 아직 안 지났다(관계 탭 "진급 대기" 배지의 값).
func pending_promotion() -> bool:
	return stage < points_hearts()

# 한 칸 진급한다(관문을 지난 순간 main이 부른다). 대기 중이 아니면 아무 일도 없다(false) —
# 점수가 안 받쳐 주는 진급은 존재하지 않는다("진급 = 만충 AND 관문"의 AND 한쪽을 여기서 지킨다).
# 한 번에 한 칸만 오른다: 점수가 여러 칸치 쌓였어도(생일 ×8 등) 관문은 칸마다 하나씩이다.
func promote() -> bool:
	if not pending_promotion():
		return false
	stage += 1
	changed.emit(points, hearts())
	return true

# 채운 하트 + 빈 하트 막대(HUD용). 예: 3/5 → "♥♥♥♡♡".
func heart_bar() -> String:
	var h := hearts()
	return "♥".repeat(h) + "♡".repeat(MAX_HEARTS - h)

# ── 일일 대화(하루 1회 소폭) ────────────────────────────────────────────────
# 오늘(이 게임 날) 아직 대화 보상을 안 받았으면 줄 수 있다.
func can_daily_talk(day: int) -> bool:
	return day != last_talk_day

# 일일 대화 보상을 적용한다. 오늘 이미 받았으면 false(점수 변화 없음 — 대사만 바뀐다).
# 성공 시 last_talk_day를 갱신하고 소폭 점수를 더한 뒤 true.
func daily_talk(day: int) -> bool:
	if not can_daily_talk(day):
		return false
	last_talk_day = day
	_add(DAILY_TALK_POINTS)
	return true

# ── 선물(선호 작물 큰 폭) ──────────────────────────────────────────────────
# ★[S8-T3] 이 주에 이미 몇 번 건넸나. 주가 바뀌었으면 0 — **리셋 루프가 없다**(파생 비교 하나로
#   되감긴다. 취침·로드·디버그 점프 어느 경로로 날이 넘어가도 자동이다).
func gifts_used_in_week(day: int) -> int:
	return gifts_this_week if GameClock.week_of(day) == gift_week else 0

# 이 주에 남은 선물 횟수(0..GIFTS_PER_WEEK — 프롬프트·관계 탭 표시용).
func gifts_left_in_week(day: int) -> int:
	return maxi(GIFTS_PER_WEEK - gifts_used_in_week(day), 0)

# 오늘 선물할 수 있는가. **두 리듬의 AND**다:
#   ㉠ 하루 1회 — 생일에도 유지된다(하루에 여덟 배를 두 번 받는 날은 없다).
#   ㉡ 주 2회 — **생일은 면제**다(ADR-0066 결정 3). 1년에 하루뿐인 날을 "이번 주 두 번 썼다"로
#      닫으면 달력 마커가 놀림이 된다. 면제된 선물은 주 카운터도 **소모하지 않는다**(gift 참조).
# ★[S8-T7 / ADR-0066 결정 8] week_exempt = **결혼 면제**(하루 1회 유지·주 2회만 해제). GIFTS_PER_WEEK
#   선언부가 예고한 "예외 인자 하나"가 이것이다 — 배우자 판정(spouse_id)은 main 소관이라 결과
#   플래그만 받는다(생일 판정을 플래그로 받는 것과 같은 결). 생일과 달리 **배율은 없다**(×8은
#   생일의 것). 미혼(false)이면 동작 완전 불변.
func can_gift(day: int, birthday: bool = false, week_exempt: bool = false) -> bool:
	if day == last_gift_day:
		return false
	return birthday or week_exempt or gifts_used_in_week(day) < GIFTS_PER_WEEK

# 선물 1회를 적용한다. 오늘 이미 했으면 0(획득 없음). 성공 시 적용한 점수를 그대로 반환한다.
# ★[S8-T2 / ADR-0066 결정 2] 인자가 "작물 id"에서 **점수**로 바뀌었다 — 무엇이 몇 점인지는
#   GiftPrefs(캐릭터별 선호 테이블)가 알고, 이 노드는 "하루 1회"라는 리듬과 누적만 소유한다
#   (affinity.gd 머리말의 단일 책임 그대로). 선물 아이템의 소모는 호출 측(main+Inventory) 책임.
# ★ **음수(혐오) 채널이 여기로 열린다**: points가 음수면 누적이 줄되 _add의 clamp가 0 아래로는
#   못 내려가게 잡는다(영구 적대 없음 — ADR-0022·ADR-0066 결정 2 "완만하고 영구 적대 없음").
#   반환값은 *명목* 점수라 0에서 −20을 맞아도 −20으로 알린다(플레이어에겐 "싫어했다"가 사실이고,
#   바닥에 눌린 건 시스템 사정이다).
# ★[S8-T3 / ADR-0066 결정 3] birthday=true면 ㉠주 2회 상한을 통과하고 ㉡주 카운터를 안 쓰며
#   ㉢점수에 BIRTHDAY_MULT(×8)가 곱해진다. 반환값도 곱한 뒤의 *명목* 점수다(플레이어가 본
#   "+320"이 사실이어야 한다 — 0 하한에 눌린 건 여전히 시스템 사정이다).
# ★[S8-T7] week_exempt(결혼)도 ㉠㉡은 같되 ㉢배율이 없다 — 상한이 풀린 사람의 선물이 카운터를
#   쓰면 "해제"가 장부상 거짓말이 된다(생일이 안 쓰는 것과 같은 이유).
func gift(points_gained: int, day: int, birthday: bool = false, week_exempt: bool = false) -> int:
	if not can_gift(day, birthday, week_exempt):
		return 0
	last_gift_day = day
	if not birthday and not week_exempt:
		# 주 카운터 소모 — 주가 바뀌었으면 이번 선물이 그 주의 첫 번째다.
		if GameClock.week_of(day) != gift_week:
			gift_week = GameClock.week_of(day)
			gifts_this_week = 0
		gifts_this_week += 1
	var applied := points_gained * (BIRTHDAY_MULT if birthday else 1)
	_add(applied)
	return applied

# ── ★[S8-T4 / ADR-0066 결정 4] 활동 → 하트(제3 채널 · 일일 캡) ──────────────
# ADR-0032가 확정한 "선물·일일 대화·활동 실적이 모두 하트를 채운다"의 **활동 축**이다. 무엇이
# 실적인지(수확·매출·처치)는 여기서 모른다 — main의 배선점이 사건마다 점수를 들고 온다. 이
# 노드가 지는 책임은 옛 두 채널과 같다: **리듬(하루 캡)과 누적**뿐.
#
# ★ 캡 12 = 일일 대화 8점과 병렬 규모(ADR-0066 결정 4). 캡이 없으면 하루 100번 수확하는 날에
#   관계가 한 칸씩 오르며 선물·대화 채널을 압도하고, 관계가 "활동의 부산물"로 전락한다
#   (ADR-0008의 곱셈기 성격이 뒤집힌다 — 관계가 활동을 가속해야지 그 반대가 아니다).
# ★ **메인 3인 전용 채널이다**(미호=수확 · 멜=서빙 매출 · 바나=나락 처치). 서브 주민 6인에게는
#   배선점이 없다 — 서사 바이블 §6.1의 "쉼터" 결(성과를 요구하지 않는 관계)을 코드로 지킨다.
#   호출부가 없으면 이 함수는 그 주민에게 영원히 안 불린다(여기 명단을 두지 않는 이유).
# ★ 진급 관문(T5)이 생겨도 이 채널은 **점수만** 채운다 — 관문은 칸 진급을 잠그지 점수 적립을
#   막지 않는다(ADR-0066 결정 5 "점수는 만충 상태로 대기"). 그래서 지금은 그냥 _add로 둔다.
const ACTIVITY_DAILY_CAP := 12

var activity_day := -1        # activity_today가 속한 게임 날(-1 = 아직 없음 — 세이브 가법 키)
var activity_today := 0       # 그날 활동으로 적립한 점수

# 오늘 활동으로 이미 얼마나 적립했나(날이 다르면 0 — 주간 카운터와 같은 파생 리셋. 루프 없음).
func activity_used_on(day: int) -> int:
	return activity_today if day == activity_day else 0

# 오늘 남은 활동 적립 여력(0..ACTIVITY_DAILY_CAP).
func activity_left_on(day: int) -> int:
	return maxi(ACTIVITY_DAILY_CAP - activity_used_on(day), 0)

# 활동 실적 n점을 적립한다 — **남은 여력만큼만** 붙고, 실제로 붙은 점수를 돌려준다(0 = 캡 소진).
# 넘친 몫은 조용히 버린다: 이월하면 다음 날 아침에 어제치가 공짜로 붙어 캡이 뜻을 잃는다.
func activity_gain(n: int, day: int) -> int:
	if n <= 0:
		return 0
	var grant := mini(n, activity_left_on(day))
	if grant <= 0:
		return 0
	if day != activity_day:
		activity_day = day
		activity_today = 0
	activity_today += grant
	_add(grant)
	return grant

# ── ★ [S2-T6] 외부 채널 가산(게시판 의뢰 보상 등) ──────────────────────────
# 대화(하루 1회)·선물(하루 1회)과 다른 제3 채널이 호감도를 올릴 때 쓴다. 여기서는 날짜를 보지
# 않는다 — 게이팅은 호출 측 이벤트가 이미 보장한다(의뢰 완료는 계약당 1회, QuestBoard가 중복
# 완료를 막는다). 두 일일 채널의 last_*_day를 건드리지 않아 대화·선물 리듬과 서로 독립이다.
func add_points(n: int) -> void:
	_add(n)

# 점수를 더하고 [0, MAX_POINTS]로 잘라 changed를 발화한다(음수·만렙 초과 방지).
func _add(n: int) -> void:
	points = clampi(points + n, 0, MAX_POINTS)
	changed.emit(points, hearts())

# ── T2.5 세이브/로드 ──────────────────────────────────────────────────────
# 상태가 정수 셋뿐이라 그대로 직렬화된다. 복원 시 점수를 잘라 손상 세이브에 방어한다.
# ★[S8-T3] 주간 카운터 2키는 **가법**이다 — 구세이브엔 없어 기본값(-1 / 0)으로 로드되고,
#   그 상태는 "이 주엔 아직 안 건넸다"라 아무것도 안 막힌다(무마이그레이션 하위호환).
func to_save() -> Dictionary:
	return {
		"points": points,
		"stage": stage,
		"last_talk_day": last_talk_day,
		"last_gift_day": last_gift_day,
		"gift_week": gift_week,
		"gifts_this_week": gifts_this_week,
		"activity_day": activity_day,
		"activity_today": activity_today,
	}

func load_save(data: Dictionary) -> void:
	points = clampi(int(data.get("points", 0)), 0, MAX_POINTS)
	# ★[S8-T5] stage 키는 **가법**인데 기본값이 특별하다 — 구세이브(키 없음)는 관문 도입 전에 이미
	#   그 하트로 플레이하던 세이브라, 옛 파생식(points_hearts)을 기본값으로 줘 **하트를 소급 강등하지
	#   않는다**(관문 도입이 기존 플레이어의 곱셈기·대사를 빼앗으면 그건 하위호환 파손이다).
	stage = clampi(int(data.get("stage", points_hearts())), 0, MAX_HEARTS)
	last_talk_day = int(data.get("last_talk_day", -1))
	last_gift_day = int(data.get("last_gift_day", -1))
	gift_week = int(data.get("gift_week", -1))
	# 손상 방어: 음수·상한 초과는 잘라 둔다(잘못된 값이 상한을 무력화하거나 영구 차단하지 않게).
	gifts_this_week = clampi(int(data.get("gifts_this_week", 0)), 0, GIFTS_PER_WEEK)
	# ★[S8-T4] 활동 캡 2키도 같은 가법 문법(구세이브 = -1/0 = "오늘 아직 안 벌었다").
	activity_day = int(data.get("activity_day", -1))
	activity_today = clampi(int(data.get("activity_today", 0)), 0, ACTIVITY_DAILY_CAP)
	changed.emit(points, hearts())
