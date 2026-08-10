extends Node
class_name GameClock
# T1.5 — 하루 사이클(게임 내 시계).
#
# 목적: "시간이 흐르고, 취침하면 날짜가 +1 되며 시간이 아침으로 리셋된다"를
#       회색 UI만으로 검증한다(ADR-0001 그레이박스).
#
# 설계 메모:
#   - 이 노드는 "시간"이라는 단일 책임만 가진다. 화면 연출(페이드)·취침 입력은
#     main.gd가 맡고, 여기서는 상태(날짜·분)와 시그널만 제공한다.
#   - ROADMAP 메모대로 이 시계는 "혼력 회복·작물 성장의 트리거"가 된다.
#     그래서 다른 시스템(T2.3 작물 성장, T2.4 혼력)이 코드 수정 없이 붙을 수
#     있도록 day_advanced / collapsed 시그널을 노출한다. 지금은 아무도 안 듣지만
#     훅은 미리 열어 둔다.
#   - 하루는 06:00에 시작해 24:00에 "쓰러짐"으로 끝난다(스타듀식 강제 취침).
#     실제 시간 REAL_SECONDS_PER_DAY초에 그 18시간을 흘려, 눈으로 흐름이 보이게 한다.

signal minute_ticked(day: int, minutes: int)  # 게임 내 '분'이 바뀐 프레임
signal day_advanced(day: int)                  # 취침으로 새 날이 시작됨
signal collapsed()                             # 24:00 도달 → 강제 취침해야 함

const START_MIN := 6 * 60            # 06:00 — 하루 시작(아침)
const END_MIN := 24 * 60            # 24:00 — 이 시각이면 쓰러진다(강제 취침)
const REAL_SECONDS_PER_DAY := 90.0  # 06:00→24:00(18시간)을 실제 90초에 흘린다(그레이박스 속도)

# ── 저승 절기 유도(S1-5b · ADR-0045) — 읽기 전용 파생, 상태 변수 없음 ──────────
# clock은 절기 상태를 들지 않고, 기존 day에서 계산되는 순수 파생 함수만 노출한다.
# 절기당 28일 = 1년 112일(CONTEXT [저승 절기]), 게임 시작 = 피안절 1일(day 1 → index 0).
# ⚠️ 사멸 판정·날씨·축제·예보는 여기 없다 — 그건 Slice 7(계절·날씨·축제)이 이 위에 얹는다.
#    지금 유일한 소비자는 orchard(혼의 나무)로, "지금 내 결실 절기인가?"만 읽는다(ADR-0045).
const DAYS_PER_SEASON := 28
const SEASON_NAMES := ["피안절", "유화절", "망연절", "성야절"]   # index 0..3(봄·여름·가을·겨울결)

# 어떤 날(1부터)의 절기 인덱스(0=피안·1=유화·2=망연·3=성야). static이라 헤드리스에서도 가볍다.
static func season_index_for_day(d: int) -> int:
	return ((d - 1) / DAYS_PER_SEASON) % 4

# ★[S7-T1 / ADR-0065 결정 1] 이 날이 절기의 첫날인가(day 1 포함 — 게임 시작도 피안절 1일이라
# 같은 전환 취급이다). 절기 전환 이벤트의 **단일 진실원**: 예전엔 forage_spawn이 이 식을 자기
# 안에서 굴려 혼자 감지했지만, Slice 7이 여러 시스템(사멸·재스폰·날씨 강제 평온)을 같은 날에
# 걸므로 판정을 여기로 승격해 이중 발화를 원천 차단한다.
static func is_season_first_day(d: int) -> bool:
	return (d - 1) % DAYS_PER_SEASON == 0

# ★[S7-T1] 이 날의 절기 내 일차(1..28, 1-기반). HUD 날짜·덤불 절기 창 등이 각자 굴리던
# `(day-1)%28+1` 중복 파생을 여기로 수렴한다(season_index_for_day와 같은 무상태 파생 관례).
static func day_of_season(d: int) -> int:
	return (d - 1) % DAYS_PER_SEASON + 1

# ★[S7-T4 / ADR-0065 결정 6] 이 날이 절기의 **마지막 날**(28일차)인가 — `is_season_first_day`의 짝.
# 점괘 거울의 D-1 사멸 경고가 유일한 소비자다: 오늘이 마지막 날 = 내일이 전환일 = 오늘 밤 지난
# 절기 작물이 스러진다. 판정을 여기 두는 이유는 첫날 판정과 같다 — 절기 경계를 아는 곳이 하나여야
# 사멸(T2)·재스폰·경고가 서로 다른 식을 굴리다 하루씩 어긋나는 사고가 안 난다.
static func is_season_last_day(d: int) -> bool:
	return d >= 1 and day_of_season(d) == DAYS_PER_SEASON

# 절기 인덱스 → 표시명("" = 범위 밖). flavor·프롬프트용.
static func season_name(idx: int) -> String:
	return SEASON_NAMES[idx] if idx >= 0 and idx < SEASON_NAMES.size() else ""

# 현재 절기 인덱스(현재 day 기준 편의 메서드).
func season_index() -> int:
	return season_index_for_day(day)

var day := 1
var minutes: float = START_MIN
var running := true                  # false면 시간 정지(취침 연출 중 등)

var _per_real_sec := 0.0             # 실제 1초당 흘러가는 게임 분
var _collapsed := false              # collapsed 시그널 중복 발화 방지

func _ready() -> void:
	_per_real_sec = float(END_MIN - START_MIN) / REAL_SECONDS_PER_DAY

func _process(delta: float) -> void:
	if not running:
		return
	var before := int(minutes)
	minutes += _per_real_sec * delta
	if minutes >= END_MIN:
		minutes = END_MIN
		running = false
		if not _collapsed:
			_collapsed = true
			collapsed.emit()
	if int(minutes) != before:
		minute_ticked.emit(day, int(minutes))

# 취침: 날짜 +1, 시간을 아침으로 리셋하고 다시 흐르게 한다(완료기준).
func sleep() -> void:
	day += 1
	minutes = START_MIN
	_collapsed = false
	running = true
	day_advanced.emit(day)
	minute_ticked.emit(day, int(minutes))

# ── T2.5 세이브/로드 ──────────────────────────────────────────────────────
# 시간이라는 단일 책임에 맞게, 자기 상태(날짜·분)만 직렬화/복원한다. 파일 IO는
# SaveManager가, 조율은 main이 맡는다(디커플링). 진행 플래그(running·_collapsed)는
# 저장하지 않는다 — 로드 직후엔 다시 시간이 흐르는 게 자연스럽다.
func to_save() -> Dictionary:
	return {"day": day, "minutes": minutes}

func load_save(data: Dictionary) -> void:
	day = int(data.get("day", 1))
	minutes = float(data.get("minutes", START_MIN))
	running = true
	_collapsed = false

# ── 표시용 헬퍼 ────────────────────────────────────────────────────────────
func clock_string() -> String:
	var m := int(minutes)
	return "%02d:%02d" % [m / 60, m % 60]

func phase() -> String:
	var h := int(minutes) / 60
	if h < 11:
		return "아침"
	if h < 17:
		return "낮"
	if h < 21:
		return "저녁"
	return "밤"
