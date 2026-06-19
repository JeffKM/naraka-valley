extends Node
class_name Cafe
# T5.4 — 카페 운영 1층 MVP: 손님 서빙 + 일일 정산.
#
# 목적: ROADMAP T5.4 — 회색 손님이 빈 좌석에 앉고(좌석 착석형), 인내심 바가 도는
#       동안 플레이어가 자리로 가 서빙하면(보유 재료 1개 소모) 정액 P 골드가 들어오고,
#       못 가면 손님이 이탈(매출 손실, 벌칙 없음 → 무막힘)하는 "손님 응대" 루프를
#       회색 도형만으로 검증한다(ADR-0001 그레이박스, ADR-0007 카페 운영).
#
# 설계 메모:
#   - clock.gd·wallet.gd·field.gd와 같은 결: 이 노드는 "손님/좌석 시뮬레이션"이라는
#     단일 책임만 가진다. 화면 표시(손님·인내심 바 그리기)·입력(서빙 E)·지갑 반영·
#     좌석 픽셀 위치는 main이 맡고, 여기서는 상태(좌석별 손님·인내심)와 시그널만 준다.
#   - 세이브 무상태(ROADMAP T5.4): 손님은 일시적이고(서사·호감도 없는 가벼운 단골,
#     ADR-0005), 정산 누적도 매일 리셋된다 → 직렬화할 상태가 없다(SaveManager·main
#     세이브 불변). 로드 직후 영업창 안이면 다음 tick이 깨끗이 영업을 다시 연다.
#   - 시간 구동: main이 매 프레임 tick(delta, minutes)로 굴린다(GameClock을 직접 모름,
#     디커플링). 인내심·스폰은 실제 delta(초)로 돌려 플레이어 반응성에 맞추고, 영업창
#     열림/닫힘만 게임 분(15–19시)으로 가른다. 시간 희소성은 이 4시간 창에 싣는다.
#   - ★ seam 1 (인내심 = 바나 응대 보호): 새 손님 인내심은 patience_secs 한 파라미터
#     (기본값)에서 나온다. Sprint 6 바나 '응대 보호'가 이 값을 키우는 식으로 *구현
#     교체*되며 얹힌다(손님이 더 오래 기다림 = 응대 실패 손실 방어). 지금은 기본값만.
#   - ★ seam 2 (서빙 수익 = 멜 마진, T5.5 얹힘 완료): 서빙가는 BASE_PRICE × margin 한
#     값으로 나온다. margin은 외부에서 주입되는 단가 배수다(이 노드는 멜 호감도를 모름 —
#     디커플링). main이 매 프레임 CafeMargin.margin(멜♡)를 흘려넣어 ♡0 ×1.0(base rate,
#     평평≠막힘) → ♡5 ×2.0으로 분화한다(관계=곱셈기, ADR-0008). 하트→배수 매핑은
#     cafe_margin.gd 한 곳(foxfire.gd가 농사 쪽에서 맡는 자리의 카페판). 기본값 1.0은
#     주입이 없을 때(테스트 하네스 등)도 카페가 base rate로 굴러가게 하는 안전판이다.
#   - 범위 밖(후속): 특정 작물 요구·손님 다양성·메뉴 가공·체키·팁·단골 유입. T5.4는
#     "아무 재료 1개로 서빙 → 정액 P"까지만(grill 확정, CONTEXT/ROADMAP).

signal changed()                                       # 좌석/손님 상태가 바뀐 프레임(main이 다시 그림)
signal closed(revenue: int, served: int, left: int)   # 영업창 마감(19시) — 일일 정산 요약

const N_SEATS := 3                # 좌석 수(그레이박스 ~3개)
const OPEN_MIN := 15 * 60         # 15:00 영업 시작(하루 3슬롯 중 카페 영업창)
const CLOSE_MIN := 19 * 60        # 19:00 영업 마감(이후 빈 밤 → Sprint 6 바나 바)
const BASE_PRICE := 35            # 정액 서빙가 P(재료 무관) — raw 판매가보다 높게 둬
                                  #   "raw 덤프 vs 서빙" 공급사슬 긴장을 만든다(CONTEXT)
const DEFAULT_PATIENCE := 7.0     # 손님 기본 인내심(초) — ★seam 1: 바나 응대 보호 파라미터
const SPAWN_INTERVAL := 3.0       # 빈 자리에 새 손님이 앉는 간격(초)

# 좌석별 손님 상태. 빈 자리는 occupied=false. patience(남은 초)/max는 인내심 바·이탈 판정용.
var _seats: Array = []
var _open := false                # 현재 영업 중인가(영업창 안)
var _spawn_timer := 0.0           # 다음 손님까지 남은 초
var _was_open := false            # 직전 tick의 영업 상태(열림/닫힘 전이 감지용)

# ★seam 1: 새 손님 인내심(초). 기본값에서 시작하고 Sprint 6 바나 보호가 키운다.
var patience_secs: float = DEFAULT_PATIENCE
# ★seam 2(T5.5): 서빙 단가 배수. main이 CafeMargin.margin(멜♡)를 주입한다(♡0 ×1.0
# base → ♡5 ×2.0). 기본값 1.0 = 주입 없을 때의 base rate 안전판(ADR-0008 평평≠막힘).
var margin: float = 1.0

# 오늘 정산 누적(세이브 무상태 — 매일 영업 시작 시 리셋, 일시 표시·요약용).
var _today_revenue := 0
var _today_served := 0
var _today_left := 0

func _ready() -> void:
	for i in N_SEATS:
		_seats.append({"occupied": false, "patience": 0.0, "max_patience": patience_secs})

# main이 매 프레임 호출한다. 실제 delta(초)로 인내심·스폰을 굴리고, 영업창 열림/닫힘은
# 게임 분(minutes)으로 가른다. 마감(열림→닫힘 전이) 순간에 정산 요약(closed)을 쏜다.
func tick(delta: float, minutes: float) -> void:
	var open_now := minutes >= OPEN_MIN and minutes < CLOSE_MIN
	if open_now and not _was_open:
		_open_shop()
	elif not open_now and _was_open:
		_close_shop()
	_was_open = open_now
	if not _open:
		return

	var dirty := false
	# 인내심 감소 + 이탈 처리(인내심 0 → 손님이 떠남, 매출 +0·벌칙 없음 → 무막힘).
	for s in _seats:
		if s["occupied"]:
			s["patience"] -= delta
			if s["patience"] <= 0.0:
				s["occupied"] = false
				_today_left += 1
				dirty = true
	# 새 손님 스폰(빈 자리가 있을 때만 실제로 앉는다).
	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		_spawn_timer = SPAWN_INTERVAL
		if _seat_customer():
			dirty = true
	if dirty:
		changed.emit()

# 영업 시작: 정산을 리셋하고 첫 손님 스폰 타이머를 짧게 잡아 곧바로 손님이 들어오게 한다.
func _open_shop() -> void:
	_open = true
	_today_revenue = 0
	_today_served = 0
	_today_left = 0
	_spawn_timer = 0.5
	_clear_seats()
	changed.emit()

# 영업 마감: 자리를 비우고 일일 정산 요약을 쏜다(main이 팝업으로 띄운다).
func _close_shop() -> void:
	_open = false
	_clear_seats()
	closed.emit(_today_revenue, _today_served, _today_left)
	changed.emit()

func _clear_seats() -> void:
	for s in _seats:
		s["occupied"] = false
		s["patience"] = 0.0

# 새 날 시작(취침) 시 호출. 영업 중 잠들어 카페를 abandon한 경우 등 상태를 조용히
# 리셋한다(요약 없음 — 마감 요약은 19시 열림→닫힘 전이에서만 띄운다). 세이브 무상태라
# 다음 영업창이 깨끗이 다시 연다(_was_open=false로 다음 15시 전이를 정상 감지).
func end_day() -> void:
	_open = false
	_was_open = false
	_clear_seats()

# 빈 자리 하나에 새 손님을 앉힌다(앞에서부터 첫 빈 자리). 자리가 다 차 있으면 false.
func _seat_customer() -> bool:
	for s in _seats:
		if not s["occupied"]:
			s["occupied"] = true
			s["patience"] = patience_secs
			s["max_patience"] = patience_secs
			return true
	return false

# ── 조회(main이 그리기·입력에 쓴다) ─────────────────────────────────────────
func is_open() -> bool:
	return _open

# 이 좌석에 서빙을 기다리는 손님이 있는가(서빙 가능 판정).
func is_waiting(seat: int) -> bool:
	return seat >= 0 and seat < _seats.size() and _seats[seat]["occupied"]

# 이 좌석 손님의 인내심 잔량 비율(0~1) — 인내심 바 그리기용. 빈 자리면 0.
func patience_ratio(seat: int) -> float:
	if not is_waiting(seat):
		return 0.0
	var s: Dictionary = _seats[seat]
	var m: float = s["max_patience"]
	return clampf(s["patience"] / m, 0.0, 1.0) if m > 0.0 else 0.0

func today_revenue() -> int:
	return _today_revenue

func today_served() -> int:
	return _today_served

# 오늘 인내심 초과로 떠난(이탈) 손님 수 — 마감 정산 요약·디버그용.
func today_left() -> int:
	return _today_left

# ── 서빙(main이 재료 소모를 먼저 처리한 뒤 호출) ─────────────────────────────
# 이 좌석 손님을 서빙 완료 처리하고 매출(정액 P × margin)을 돌려준다. 정산에 누적한다.
# 기다리는 손님이 없으면 0(잘못된 호출 방어 — main은 is_waiting 확인 후 부른다).
func serve(seat: int) -> int:
	if not is_waiting(seat):
		return 0
	_seats[seat]["occupied"] = false
	_seats[seat]["patience"] = 0.0
	var revenue := serve_price()
	_today_served += 1
	_today_revenue += revenue
	changed.emit()
	return revenue

# ★seam 2(T5.5): 서빙 단가 = 정액 P × margin 한 값. margin은 main이 멜 하트에서 파생해
# 주입한다(CafeMargin) — ♡0이면 ×1.0(P_base 그대로), 친해질수록 같은 서빙이 비싸진다.
func serve_price() -> int:
	return int(round(BASE_PRICE * margin))
