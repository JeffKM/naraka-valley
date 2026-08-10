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
#   - ★ seam 4 (S6-T2 주문 위상 — ADR-0064 결정 4): 손님은 자리에 앉는 순간 **희망 메뉴**를 들고
#     온다(want). 후보·가중치는 main이 order_pool로 *주입*하고 이 노드는 곳간·해금 원장·절기를
#     하나도 모른다(margin·spawn_scale과 정확히 같은 다리 — 디커플링). 주입이 없으면 기본 메뉴만
#     주문되므로 테스트 하네스에서도 카페가 base rate로 굴러간다.
#   - 범위 밖(후속): 손님 다양성·체키·팁·단골 유입(T4~T6). T5.4는 "아무 재료 1개로 서빙 → 정액 P"
#     까지였고, S6-T2가 그 자리에 주문·폴백·프리미엄을 얹었다(재료 소모는 곳간으로 옮겨갔다).

signal changed()                                       # 좌석/손님 상태가 바뀐 프레임(main이 다시 그림)
signal closed(revenue: int, served: int, left: int)   # 영업창 마감(19시) — 일일 정산 요약

# ★[S6-T3 / ADR-0064 결정 7] 좌석은 **카페 일구기 사다리**가 여는 콘텐츠가 됐다. N_SEATS는 이제
# *좌석 배열 크기 = 사다리 최대치*이고(좌석 칸·스툴 아트는 처음부터 다 놓여 있다 — 2단 예고를
# 무대가 먼저 말한다), 실제로 손님이 앉는 칸 수는 seam 5 `open_seats`가 정한다.
const N_SEATS := 5                # 좌석 배열 크기(= SEATS_STAGE2. SEAT_TILES 길이와 같아야 한다)
const SEATS_STAGE1 := 3           # 1단 영업 좌석(종전 그레이박스 3개 — 거동 불변)
const SEATS_STAGE2 := 5           # 2단 영업 좌석(잠정 레버 — ADR-0064 결정 7)
const OPEN_MIN := 15 * 60         # 15:00 영업 시작(하루 3슬롯 중 카페 영업창)
const CLOSE_MIN := 19 * 60        # 19:00 영업 마감(이후 빈 밤 → Sprint 6 바나 바)
const BASE_PRICE := 35            # 정액 서빙가 P(재료 무관) — raw 판매가보다 높게 둬
                                  #   "raw 덤프 vs 서빙" 공급사슬 긴장을 만든다(CONTEXT)
const DEFAULT_PATIENCE := 7.0     # 손님 기본 인내심(초) — ★seam 1: 바나 응대 보호 파라미터
const SPAWN_INTERVAL := 3.0       # 빈 자리에 새 손님이 앉는 간격(초)

# ★[S6-T2 / ADR-0064 결정 4] 주문 가중치(그레이박스 레버). 기본 메뉴는 언제나 후보고, 융합 메뉴는
# **곳간에 재고가 있을 때 세 배로 자주 불린다** — "쟁여 두면 그게 팔린다"가 곳간 적재의 보상이다.
# ★ 재고 없는 융합도 후보로 남는 것이 폴백 경로의 전제다(뽑혀도 기본 메뉴로 나가고 손님은 안 떠난다,
#   결정 4 "하드 실패 없음"). 재고 있는 것만 뽑으면 폴백이 죽은 코드가 되어 무막힘이 검증되지 않는다.
const W_BASIC := 1
const W_FUSION_STOCKED := 3
const W_FUSION_EMPTY := 1

# 좌석별 손님 상태. 빈 자리는 occupied=false. patience(남은 초)/max는 인내심 바·이탈 판정용.
# want(★S6-T2) = 이 손님이 시킨 메뉴 id(빈 자리는 ""). 착석 시 결정 롤로 정해진다.
var _seats: Array = []
var _open := false                # 현재 영업 중인가(영업창 안)
var _spawn_timer := 0.0           # 다음 손님까지 남은 초
var _was_open := false            # 직전 tick의 영업 상태(열림/닫힘 전이 감지용)

# ★seam 1: 새 손님 인내심(초). 기본값에서 시작하고 Sprint 6 바나 보호가 키운다.
var patience_secs: float = DEFAULT_PATIENCE
# ★seam 2(T5.5): 서빙 단가 배수. main이 CafeMargin.margin(멜♡)를 주입한다(♡0 ×1.0
# base → ♡5 ×2.0). 기본값 1.0 = 주입 없을 때의 base rate 안전판(ADR-0008 평평≠막힘).
var margin: float = 1.0
# ★seam 3(M2.4 카페 이벤트 데이): 손님 스폰 간격 배수. main이 이벤트일에 Festival.spawn_scale
# (0.5=2배 붐빔)을 주입한다(평소 1.0). 단가(margin=멜 마진 축)는 안 건드리고 *유입*만 키운다 —
# 축제라 사람이 몰리는 시간 한정 보너스라 '활동 곱셈기' 불침범(ADR-0008, festival.gd 참조).
# 기본값 1.0 = 주입 없을 때(평소·테스트)의 base rate 안전판.
var spawn_scale: float = 1.0
# ★seam 4(S6-T2): 오늘 날짜. main이 매 프레임 clock.day를 흘려넣는다(margin·spawn_scale과 같은 다리).
# 주문 롤 시드의 한 축이라 "같은 날 n번째 손님은 몇 번을 굴려도 같은 메뉴를 원한다"가 성립한다.
var day: int = 1
# ★seam 4(S6-T2): 주문 후보 융합 메뉴 [{"id": 메뉴 id, "in_stock": bool}, …]. main이 해금 원장·절기
# 창·곳간 재고 세 축을 합쳐 주입한다 — 이 노드는 곳간도 해금도 절기도 모른다(디커플링 유지).
# 빈 배열(기본값) = 기본 메뉴만 주문된다 = 주입 없는 하네스의 base rate 안전판(ADR-0008 평평≠막힘).
var order_pool: Array = []
# ★seam 5(S6-T3): 지금 영업에 쓰는 좌석 수. main이 카페 일구기 단계에서 파생해 주입한다
# (CafeMilestone.seats_of — margin·spawn_scale·order_pool과 정확히 같은 다리. 이 노드는 마일스톤을
# 모른다). 기본값 = 1단 좌석 = 주입 없는 하네스의 base rate 안전판(ADR-0008 평평≠막힘).
# ★ 좌석 *배열*은 항상 N_SEATS개다 — 여는 건 "앉힐 수 있는 앞쪽 n칸"이라 잠긴 칸은 영원히 빈 자리다.
var open_seats: int = SEATS_STAGE1

# 오늘 정산 누적(세이브 무상태 — 매일 영업 시작 시 리셋, 일시 표시·요약용).
var _today_revenue := 0
var _today_served := 0
var _today_left := 0
# 오늘 스폰 누계 = 주문 롤 시드의 serial 축(영업 시작 시 0). 좌석 인덱스가 아니라 *누계*인 이유:
# 같은 좌석에 하루 여러 손님이 앉으므로 좌석으로 시드를 잡으면 세 손님이 영원히 같은 메뉴만 시킨다.
var _spawned_today := 0

func _ready() -> void:
	for i in N_SEATS:
		_seats.append({"occupied": false, "patience": 0.0, "max_patience": patience_secs, "want": ""})

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
		_spawn_timer = SPAWN_INTERVAL * spawn_scale   # ★seam 3: 이벤트일 ×0.5 = 더 자주 채움
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
	_spawned_today = 0    # ★S6-T2 주문 롤 serial 리셋 — 하루의 주문열은 매일 새로 시작한다
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
		s["want"] = ""

# 새 날 시작(취침) 시 호출. 영업 중 잠들어 카페를 abandon한 경우 등 상태를 조용히
# 리셋한다(요약 없음 — 마감 요약은 19시 열림→닫힘 전이에서만 띄운다). 세이브 무상태라
# 다음 영업창이 깨끗이 다시 연다(_was_open=false로 다음 15시 전이를 정상 감지).
func end_day() -> void:
	_open = false
	_was_open = false
	_clear_seats()

# 빈 자리 하나에 새 손님을 앉힌다(앞에서부터 첫 빈 자리). 자리가 다 차 있으면 false.
# ★S6-T2: 앉는 순간 희망 메뉴를 결정 롤로 정한다(오늘 몇 번째 손님인가 = serial 시드).
# ★S6-T3: **앞쪽 open_seats칸까지만** 앉힌다(seam 5 — 잠긴 뒷칸은 2단이 열어 준다).
func _seat_customer() -> bool:
	var n := clampi(open_seats, 0, _seats.size())
	for i in n:
		var s: Dictionary = _seats[i]
		if not s["occupied"]:
			s["occupied"] = true
			s["patience"] = patience_secs
			s["max_patience"] = patience_secs
			s["want"] = roll_want(_spawned_today)
			_spawned_today += 1
			return true
	return false

# ── ★[S6-T2 / ADR-0064 결정 4] 주문 결정 롤 ──────────────────────────────────
# 오늘 serial번째 손님이 시킬 메뉴 id. 시드 = day + serial이라 **같은 날 같은 순번은 몇 번을
# 굴려도 같은 메뉴**다(전역 randf 금지 — 헤드리스 재현의 전제. ForageSpawns.advance_day·
# MineFloors.generate와 같은 관례). 후보 = 기본 메뉴 전량 + 주입된 융합 메뉴(order_pool).
#
# ★ 롤 순서(순차 소비): ① 가중 추첨 1회가 전부다. 신규 롤을 붙일 땐 **맨 뒤로 승격**한다 —
#   앞에 끼우면 같은 시드의 결과열이 통째로 갈려 결정성 단언이 그 자리에서 터진다(mine_floors 규율).
# ★ 후보가 하나도 없으면 ""(도달 불가 — 기본 메뉴 4종은 항상 후보다. 방어).
func roll_want(serial: int) -> String:
	var ids: Array = []
	var weights: Array = []
	for bid in MenuCatalog.basic_ids():
		ids.append(String(bid))
		weights.append(W_BASIC)
	for raw_e in order_pool:
		if typeof(raw_e) != TYPE_DICTIONARY:
			continue
		var e: Dictionary = raw_e
		var mid := String(e.get("id", ""))
		if not MenuCatalog.is_fusion(mid):
			continue      # 기본 메뉴·오타 id가 풀에 섞여도 후보를 두 번 세지 않는다(주입 손상 방어)
		ids.append(mid)
		weights.append(W_FUSION_STOCKED if bool(e.get("in_stock", false)) else W_FUSION_EMPTY)
	if ids.is_empty():
		return ""
	var total := 0
	for w in weights:
		total += int(w)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("cafe_order:%d:%d" % [day, serial])
	var pick := rng.randi_range(0, total - 1)          # 순차 소비 ①
	for i in ids.size():
		pick -= int(weights[i])
		if pick < 0:
			return String(ids[i])
	return String(ids[ids.size() - 1])                 # 도달 X(가중 합 계산 방어)

# ── 조회(main이 그리기·입력에 쓴다) ─────────────────────────────────────────
func is_open() -> bool:
	return _open

# 이 좌석에 서빙을 기다리는 손님이 있는가(서빙 가능 판정).
func is_waiting(seat: int) -> bool:
	return seat >= 0 and seat < _seats.size() and _seats[seat]["occupied"]

# ★S6-T2: 이 좌석 손님이 시킨 메뉴 id("" = 빈 자리). main이 말풍선 그리기·서빙 분기에 쓴다.
func want_of(seat: int) -> String:
	if not is_waiting(seat):
		return ""
	return String(_seats[seat].get("want", ""))

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

# ── 서빙(main이 곳간 차감을 먼저 처리한 뒤 호출) ─────────────────────────────
# 이 좌석 손님에게 served_menu_id를 내주고 매출(메뉴가 × margin)을 돌려준다. 정산에 누적한다.
# 기다리는 손님이 없으면 0(잘못된 호출 방어 — main은 is_waiting 확인 후 부른다).
#
# ★[S6-T2] **무엇을 냈는지는 호출 측이 정한다** — 희망대로 융합을 냈는지(곳간 재고 있음), 기본
#   메뉴로 폴백했는지(재고 0)는 곳간을 아는 main의 판정이고, 이 노드는 그 결과를 값으로 받는다
#   (곳간 디커플링). 인자를 비우면 정액 BASE_PRICE로 매긴다 = 주문 위상 없는 하네스의 안전판.
func serve(seat: int, served_menu_id: String = "") -> int:
	if not is_waiting(seat):
		return 0
	_seats[seat]["occupied"] = false
	_seats[seat]["patience"] = 0.0
	_seats[seat]["want"] = ""
	var revenue := serve_price(served_menu_id)
	_today_served += 1
	_today_revenue += revenue
	changed.emit()
	return revenue

# ★seam 2(T5.5) + ★S6-T2: 서빙 단가 = **메뉴가 × margin** 한 값. 메뉴가는 MenuCatalog가 들고
# (기본 = 정액 / 융합 = 시그니처 기본가 ×2.5), margin은 main이 멜 하트에서 파생해 주입한다
# (CafeMargin) — ♡0이면 ×1.0(base 그대로), 친해질수록 같은 잔이 비싸진다. **멜 마진은 메뉴가
# *위에* 곱한다**(관계=곱셈기이지 게이트가 아니다, ADR-0008 — ♡0에서도 융합 프리미엄은 온전하다).
# 미지·빈 메뉴 id는 정액 BASE_PRICE로 떨어진다(옛 무주문 호출 경로의 base rate 보존).
func serve_price(menu_id: String = "") -> int:
	var base := MenuCatalog.price_of(menu_id) if MenuCatalog.has(menu_id) else BASE_PRICE
	return int(round(base * margin))
