extends Node
class_name NightBar
# T6.3 — 나라카 바 옵트인: 밤 영업 창 + 잡귀 등장 게이팅.
#
# 목적: ROADMAP T6.3 — 밤 창(19–24시)에 플레이어가 *바를 열 때만* 잡귀가 깃들고(옵트인),
#       자정 전에 자면 손실 0·밤 매출 0이 되는 "선택적 고위험-고보상 밤 루프"의 그릇을
#       회색 도형만으로 검증한다(ADR-0001 그레이박스, ADR-0010 밤 경비 옵트인).
#
# 설계 메모:
#   - cafe.gd와 정확히 대칭인 형제 노드다(낮 카페 ↔ 밤 바). 이 노드는 "밤 잡귀 시뮬레이션"
#     이라는 단일 책임만 가진다. 화면 표시(잡귀·접근 바 그리기)·입력(옵트인 키·막기 E)·
#     스폿 픽셀 위치는 main이 맡고, 여기서는 상태(스폿별 잡귀·접근)와 게이트만 준다.
#   - ★ 옵트인이 카페와의 핵심 차이다(ADR-0010 #6): 카페는 영업창(15–19시)에 들어가면
#     자동으로 열리지만(매일 손님), 밤 바는 창(19–24시) 안이어도 _opened가 켜져야만
#     잡귀가 등장한다. 안 열면 밤은 그냥 빈 밤이다 — 매일 세금이 아니라 *그 밤의 선택*.
#     은둔 농사파는 바를 한 번도 안 열어 밤에 처벌받지 않는다(ADR-0008 "평평 ≠ 막힘").
#   - 세이브 무상태(cafe.gd와 일관): 잡귀는 일시적이고 옵트인도 매일 새 선택이라(end_day가
#     리셋) 직렬화할 상태가 없다(SaveManager 불변). 밤 바 배치·바나 가시성은 시각·단계에서
#     파생되고, 저장되는 건 바나 affinity 한 조각뿐이다(T6.2).
#   - 시간 구동: main이 매 프레임 tick(delta, minutes)로 굴린다(GameClock을 직접 모름,
#     디커플링 — cafe와 같은 결). 접근·스폰은 실제 delta(초)로 돌리고, 밤 창 열림/닫힘만
#     게임 분(19–24시)으로 가른다. 시간 희소성은 이 5시간 창에 싣는다.
#   - 밤 경비는 혼력을 쓰지 않고 시간(밤 창)으로만 제한한다(ADR-0010 #3, ADR-0011 — 혼력은
#     노동 전용, 밤까지 끌면 아침 농사와 혼력 풀을 두고 싸운다). 그래서 이 노드는 혼력을
#     전혀 모른다(카페 서빙과 같은 결).
#   - ★ seam (막기 해소 = T6.4 얹힘): 잡귀가 접근(approach)을 다 쓰면 지금은 조용히 사라진다
#     (despawn). T6.4 막기가 여기에 "접근→E→격퇴 / 못 막으면 약탈" 반환 계약 {격퇴, 약탈량}
#     으로 얹히고(ADR-0010 #8), 약탈량이 _raided에 누적된다. 지금은 격퇴·약탈이 없어
#     tonight_raided()가 늘 0 — 완료기준 "자정 전 취침 시 손실 0·밤 매출 0"의 구조적 보장이다.
#   - ★ seam (인내심 = 바나 응대 보호 / 막기 데드라인): 잡귀 접근 시간은 approach_secs 한
#     파라미터(기본값)에서 나온다. cafe.gd patience_secs와 같은 자리 — T6.5 바나 ㉠ 보호가
#     이 값을 키우는 식으로 얹힌다(잡귀가 더 천천히 와 막을 여유 ↑). 지금은 기본값만.
#   - 범위 밖(후속): 막기 E·이중 손실·막기↔응대 경쟁(T6.4) · 바나 이중 보호 곱셈기(T6.5) ·
#     밤 손님 응대 매출(T6.4+). T6.3은 "바 열 때만 잡귀 등장 + 안 열면/일찍 자면 손실 0"까지만.

signal changed()                  # 스폿/잡귀 상태가 바뀐 프레임(main이 다시 그림)
signal closed(raided: int)        # 밤 창 마감(또는 옵트인한 채 취침) — 밤 정산 요약(★seam: 지금 raided=0)

const N_SPOTS := 3                # 잡귀 접근 스폿 수(카페 좌석과 대칭 — 그레이박스 ~3개)
const OPEN_MIN := 19 * 60         # 19:00 밤 영업 시작 — T5.4가 남긴 '빈 밤 슬롯'(= Cafe.CLOSE_MIN)
const CLOSE_MIN := 24 * 60        # 24:00 자정 마감(= GameClock.END_MIN — 이 시각이면 강제 취침)
const SPAWN_INTERVAL := 4.0       # 빈 스폿에 새 잡귀가 깃드는 간격(초)
const DEFAULT_APPROACH := 8.0     # 잡귀 기본 접근 시간(초) — ★seam: T6.4 막기 데드라인·T6.5 보호 파라미터

# 스폿별 잡귀 상태. 빈 스폿은 active=false. approach(남은 초)/max는 접근 바·약탈 판정용.
var _spots: Array = []
var _opened := false              # ★ 오늘 밤 바를 열었나(옵트인) — 잡귀 등장의 핵심 게이트
var _spawn_timer := 0.0           # 다음 잡귀까지 남은 초
var _was_active := false          # 직전 tick의 활성(열림 & 밤 창) 상태(닫힘 전이 감지용)

# ★seam: 새 잡귀 접근 시간(초). 기본값에서 시작하고 T6.5 바나 ㉠ 보호가 키운다(막을 여유↑).
var approach_secs: float = DEFAULT_APPROACH

# 오늘 밤 약탈당한 재고량(세이브 무상태 — 매일 리셋). ★seam: 지금은 늘 0, T6.4 막기 실패가 누적.
var _raided := 0

func _ready() -> void:
	for i in N_SPOTS:
		_spots.append({"active": false, "approach": 0.0, "max_approach": approach_secs})

# ★ 옵트인: 플레이어가 밤 바를 연다. 밤 창(19–24시) 안에서만 열 수 있고, 한 번 열면 그 밤
# 동안 유지된다(end_day가 다음 밤을 위해 리셋). 이미 열려 있거나 창 밖이면 false(헛 호출
# 방어 — main은 창·옵트인 상태를 보고 프롬프트를 띄운 뒤 부른다). 여는 순간 잡귀 정산을
# 리셋하고 첫 스폰 타이머를 잡아 곧 잡귀가 깃들게 한다.
func open_bar(minutes: float) -> bool:
	if _opened or not _in_window(minutes):
		return false
	_opened = true
	_raided = 0
	_spawn_timer = SPAWN_INTERVAL
	_clear_spots()
	changed.emit()
	return true

# main이 매 프레임 호출한다. 활성(_opened & 밤 창) 일 때만 잡귀가 깃들고 접근한다. 안
# 열었으면(옵트인 X) 창 안이어도 아무 일도 없다 — 빈 밤이다. 밤의 자연스러운 끝은 자정
# 강제 취침(24:00 = CLOSE_MIN)뿐이라 — 카페처럼 "영업 후 깨어 있는 시간"이 없다 — 정산
# 요약은 tick의 창-닫힘 전이가 아니라 취침 훅(end_day)에서 쏜다(아래 end_day 주석).
func tick(delta: float, minutes: float) -> void:
	var active_now := _opened and _in_window(minutes)
	_was_active = active_now
	if not active_now:
		return

	var dirty := false
	# 접근 감소 + 약탈 처리. 접근이 0이 되면 잡귀가 스폿을 비운다(despawn). ★seam: T6.4 막기가
	# 여기에 "못 막으면 약탈"을 얹는다 — 지금은 약탈 없이 사라질 뿐이라 _raided는 0으로 남는다.
	for s in _spots:
		if s["active"]:
			s["approach"] -= delta
			if s["approach"] <= 0.0:
				s["active"] = false
				# ★seam(T6.4): _raided += 약탈량  ← 막기 실패 시 낮 농사 재고를 약탈(미래 자산).
				dirty = true
	# 새 잡귀 스폰(빈 스폿이 있을 때만 실제로 깃든다).
	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		_spawn_timer = SPAWN_INTERVAL
		if _spawn_jobgui():
			dirty = true
	if dirty:
		changed.emit()

func _clear_spots() -> void:
	for s in _spots:
		s["active"] = false
		s["approach"] = 0.0

# 새 날 시작(취침) 시 호출 — 밤의 자연스러운 끝. 바를 열었던 밤이면 정산 요약(closed)을 먼저
# 쏘고(★seam: 지금 raided=0 — "자정 전 취침 시 손실 0·밤 매출 0"의 구조적 보장), 그 다음
# 옵트인을 꺼 다음 밤을 *새 선택*으로 돌린다(매일 세금 아님, ADR-0010 #6). 안 열었던 밤이면
# 조용히 리셋만 한다(빈 밤엔 정산할 것이 없다). 세이브 무상태라 다음 밤이 깨끗이 다시 시작된다.
func end_day() -> void:
	if _opened:
		closed.emit(_raided)
	_opened = false
	_was_active = false
	_raided = 0
	_clear_spots()

# 빈 스폿 하나에 새 잡귀를 깃들인다(앞에서부터 첫 빈 스폿). 스폿이 다 차 있으면 false.
func _spawn_jobgui() -> bool:
	for s in _spots:
		if not s["active"]:
			s["active"] = true
			s["approach"] = approach_secs
			s["max_approach"] = approach_secs
			return true
	return false

func _in_window(minutes: float) -> bool:
	return minutes >= OPEN_MIN and minutes < CLOSE_MIN

# ── 조회(main이 그리기·입력·HUD에 쓴다) ────────────────────────────────────
# 지금 밤 창(19–24시) 안인가 — 옵트인 프롬프트를 띄울지 판단(창 밖이면 못 연다).
func is_window(minutes: float) -> bool:
	return _in_window(minutes)

# 오늘 밤 바를 열었나(옵트인 게이트). 안 열었으면 잡귀가 없고 밤 손실도 0이다.
func is_opened() -> bool:
	return _opened

# 지금 잡귀가 깃들 수 있는 활성 상태인가(열림 & 밤 창) — 직전 tick 기준. main이 잡귀
# 그리기/막기 처리 여부를 가른다.
func is_active() -> bool:
	return _was_active

# 이 스폿에 막아야 할 잡귀가 있는가(막기 대상 판정 — T6.4가 쓴다).
func is_threat(spot: int) -> bool:
	return spot >= 0 and spot < _spots.size() and _spots[spot]["active"]

# 이 스폿 잡귀의 접근 잔량 비율(0~1) — 접근 바 그리기용. 빈 스폿이면 0.
func approach_ratio(spot: int) -> float:
	if not is_threat(spot):
		return 0.0
	var s: Dictionary = _spots[spot]
	var m: float = s["max_approach"]
	return clampf(s["approach"] / m, 0.0, 1.0) if m > 0.0 else 0.0

# 활성 잡귀 수 — HUD "잡귀 N" 표시용.
func threat_count() -> int:
	var n := 0
	for s in _spots:
		if s["active"]:
			n += 1
	return n

# 오늘 밤 약탈당한 재고량(★seam: T6.3은 늘 0 — 막기 실패 약탈은 T6.4). 완료기준 손실 0 검증.
func tonight_raided() -> int:
	return _raided
