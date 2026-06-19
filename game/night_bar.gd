extends Node
class_name NightBar
# T6.3 — 나라카 바 옵트인: 밤 영업 창 + 잡귀 등장 게이팅.
# T6.4 — 밤 경비 1층 MVP: 막기 + 막기↔응대 경쟁 + 이중 손실.
# T6.5 — 바나 관계 보상축 = 이중 보호 축: 약탈량↓·창고 잡귀 자동 차단↑(㉠)·손님 인내심↑(㉡)
#        seam에 BanaGuard(바나 하트→보호)를 얹는다(bana_guard.gd, ADR-0010 #7).
#
# 목적(T6.3): 밤 창(19–24시)에 플레이어가 *바를 열 때만* 잡귀가 깃들고(옵트인), 자정 전에
#       자면 손실 0·밤 매출 0이 되는 "선택적 고위험-고보상 밤 루프"의 그릇을 회색 도형만으로
#       검증한다(ADR-0001 그레이박스, ADR-0010 밤 경비 옵트인).
# 목적(T6.4): 그 밤을 *실제로 굴린다* — 잡귀를 막고(접근→E→격퇴 즉시 판정, 전투 엔진 0),
#       동시에 바 손님을 응대해 밤 매출을 낸다. 둘은 *경쟁*한다(카운터를 비우고 막으러 가면
#       손님이 이탈). 손실은 시간 지평이 다른 *이중*이다 — 막기 실패→재고 약탈(미래 자산)/
#       응대 실패→현장 매출·단골 이탈(현재 자산). ADR-0010 #2·#4·#5, game-loops §2.4.
#
# 설계 메모:
#   - cafe.gd와 정확히 대칭인 형제 노드다(낮 카페 ↔ 밤 바). 이 노드는 "밤 무대 시뮬레이션"
#     이라는 단일 책임만 가진다(잡귀 막기 + 바 손님 응대). 화면 표시(잡귀·손님·바 그리기)·
#     입력(옵트인 키·막기 E·서빙 E)·스폿/좌석 픽셀 위치·지갑/재고 반영은 main이 맡고,
#     여기서는 상태(스폿별 잡귀·좌석별 손님)와 계약(막기 해소 {격퇴, 약탈량})만 준다.
#   - ★ 옵트인이 카페와의 핵심 차이다(ADR-0010 #6): 카페는 영업창(15–19시)에 들어가면
#     자동으로 열리지만(매일 손님), 밤 바는 창(19–24시) 안이어도 _opened가 켜져야만
#     잡귀·손님이 등장한다. 안 열면 밤은 그냥 빈 밤이다 — 매일 세금이 아니라 *그 밤의 선택*.
#     은둔 농사파는 바를 한 번도 안 열어 밤에 처벌받지 않는다(ADR-0008 "평평 ≠ 막힘").
#   - ★ 막기↔응대 경쟁(ADR-0010 #4): 잡귀(막기 대상)와 바 손님(응대 대상)이 같은 밤에
#     동시에 깃든다. main은 둘을 다른 칸에 그려(잡귀=문 안쪽 앞줄, 손님=카운터 줄) 플레이어가
#     한 번에 한쪽만 마주보게 한다 — 막으러 가면 카운터가 비어 손님 인내심이 그새 닳는다.
#     이 노드는 위치를 모르고 두 시뮬을 나란히 굴릴 뿐, 경쟁(기회비용)은 플레이어의 몸이
#     한 칸에만 있다는 사실에서 창발한다(순차로 두면 긴장 0 — 바나 '보호' 곱셈기가 보호할
#     대상이 사라진다). 낮의 "밭 vs 카운터"와 같은 기회비용 문법의 밤판(§2.8 직조).
#   - ★ 이중 손실(ADR-0010 #5, 시간 지평이 다름):
#       ㉮ 막기 실패 → 재고 약탈: 잡귀가 접근을 다 채우면 _raided에 raid_amount만큼 쌓고
#          resolved({repelled:false, raided})를 쏜다. main이 그 값만큼 낮에 쌓은 수확물(카페
#          재료)을 덜어낸다 → *내일* 카페가 굶음(미래 자산). 잡귀가 낮 농사 산물을 노리니
#          밤이 밭→재고→서빙 사슬에 자원으로 묶인다(직조).
#       ㉯ 응대 실패(카운터 비움) → 현장 매출·단골 이탈: 손님 인내심이 0이 되면 떠난다
#          (_left += 1, 매출 +0·벌칙 없음 → 무막힘). *지금* 눈앞 매출을 놓침(현재 자산).
#   - ★ 막기 해소 = 반환 계약 {격퇴 성공/실패, 약탈량}(ADR-0010 #8): 다운스트림(main의 이중
#     손실 적용·HUD·T6.5 바나 곱셈기)은 이 값만 소비하고 *어떻게* 격퇴했는지 모른다 —
#     field.gd가 Foxfire를 모른 채 advance_day(accel, reach) 값만 받는 그 패턴이다.
#     (B) MVP 구현 = "접근→E→즉시 격퇴", Phase 3 전투(§2.6)는 이 block()/돌파 *구현만*
#     교체하고 같은 {repelled, raided}를 돌려준다 → 다운스트림 재설계 0. HP·무기·적 패턴은
#     여기 없다(전투 엔진 0, ADR-0010 #2·ADR-0011 — Phase 3).
#   - 세이브 무상태(cafe.gd와 일관): 잡귀·손님은 일시적이고 옵트인도 매일 새 선택이라
#     (end_day가 리셋) 직렬화할 상태가 없다(SaveManager 불변). 저장되는 건 바나 affinity
#     한 조각뿐이다(T6.2). 약탈된 재고는 inventory가, 번 매출은 wallet이 각자 들고 저장한다.
#   - 시간 구동: main이 매 프레임 tick(delta, minutes)로 굴린다(GameClock을 직접 모름,
#     디커플링 — cafe와 같은 결). 접근·인내심·스폰은 실제 delta(초)로 돌리고, 밤 창 열림/닫힘만
#     게임 분(19–24시)으로 가른다. 시간 희소성은 이 5시간 창에 싣는다. 혼력은 전혀 모른다
#     (밤 경비는 혼력 안 씀, 시간 창으로만 제한 — ADR-0010 #3·ADR-0011).
#   - ★ seam(바나 보호 곱셈기 = T6.5 ㉠㉡ 얹힘, ADR-0010 #7 — 막기 판정 *위* 경제 손실축).
#     main이 매 프레임 BanaGuard.<축>(바나 하트)를 이 파라미터들에 주입한다(cafe.margin과 같은
#     다리 — 이 노드는 바나 호감도를 모르고 값만 받는다, 디커플링):
#       ㉠ 재고 방어: raid_amount(약탈량 — ♡↑ → 훔치는 재고량↓, 하한 1) + auto_block(내가 못
#          막은 돌파를 바나가 N마리까지 대신 막음 — 여우불 '범위'의 밤판). approach_secs(접근
#          시간)도 같은 축의 여분 seam(♡↑ → 잡귀가 더 천천히 와 막을 여유↑, 지금은 미주입).
#       ㉡ 응대 보호: patience_secs(손님 인내심) — ♡↑ → 카운터 빈 사이 손님이 더 오래 버팀
#          (cafe.patience_secs와 같은 자리, 응대 실패 손실 방어).
#     ♡0이면 세 축이 모두 기본값(raid=DEFAULT_RAID·auto_block=0·patience=DEFAULT_PATIENCE) =
#     바나 잠듦(밤은 거칠지만 base로 굴러감, ADR-0008 평평≠막힘). 매핑은 bana_guard.gd 한 곳.
#   - 범위 밖(후속): 자동 차단의 2층(차단 위치·잡귀 종류) · 손님 종류·요구 다양성 · 실제
#     전투(Phase 3). T6.5는 "이중 보호 축 주입(약탈량↓·자동차단↑·인내심↑)"까지만.

signal changed()                                       # 스폿/좌석 상태가 바뀐 프레임(main이 다시 그림)
signal closed(raided: int, revenue: int, left: int)    # 밤 마감(취침) — 밤 정산 요약(약탈·밤 매출·이탈)
signal resolved(result: Dictionary)                    # ★ 막기 해소 계약 {repelled, raided} — block 성공·잡귀 돌파 양쪽 발화

const N_SPOTS := 3                # 잡귀 접근 스폿 수(카페 좌석과 대칭 — 그레이박스 ~3개)
const N_SEATS := 3                # 바 손님 좌석 수(잡귀 스폿과 대칭 — 응대 경쟁 상대)
const OPEN_MIN := 19 * 60         # 19:00 밤 영업 시작 — T5.4가 남긴 '빈 밤 슬롯'(= Cafe.CLOSE_MIN)
const CLOSE_MIN := 24 * 60        # 24:00 자정 마감(= GameClock.END_MIN — 이 시각이면 강제 취침)
const SPAWN_INTERVAL := 4.0       # 빈 스폿에 새 잡귀가 깃드는 간격(초)
const CUST_INTERVAL := 3.5        # 빈 좌석에 새 바 손님이 앉는 간격(초)
const SERVE_PRICE := 30           # 밤 손님 정액 응대가(밤 매출 — 바나는 '마진'이 아니라 '보호'
                                  #   곱셈기라 단가 배수가 없다, 멜 카페와 분화 ADR-0008)
const DEFAULT_APPROACH := 8.0     # 잡귀 기본 접근 시간(초) — ★seam ㉠: T6.5 보호가 키움(막을 여유↑)
const DEFAULT_PATIENCE := 7.0     # 바 손님 기본 인내심(초) — ★seam ㉡: T6.5 보호가 키움(이탈↓)
const DEFAULT_RAID := 3           # 잡귀 1마리 돌파 시 약탈 재고량(♡0 거친 base) — ★seam ㉠: T6.5
                                  #   바나 보호가 줄임(약탈량↓, BanaGuard.raid_amount, 하한 1). ♡0에
                                  #   여유를 줘 관계가 내려갈 자리를 둔다(cafe_margin ♡0 ×1.0과 같은 결).
const DEFAULT_AUTO_BLOCK := 0     # 내가 못 막은 돌파를 바나가 대신 막아주는 마리 수 — ★seam ㉠: T6.5
                                  #   바나 보호가 키움(창고 잡귀 자동 차단↑, BanaGuard.auto_block).
                                  #   ♡0이면 0 = 다 내가 막아야(바나 잠듦, ADR-0008 평평≠막힘).

# 스폿별 잡귀 상태. 빈 스폿은 active=false. approach(남은 초)/max는 접근 바·약탈 판정용.
var _spots: Array = []
# 좌석별 바 손님 상태. 빈 자리는 occupied=false. patience(남은 초)/max는 인내심 바·이탈 판정용.
var _seats: Array = []
var _opened := false              # ★ 오늘 밤 바를 열었나(옵트인) — 잡귀·손님 등장의 핵심 게이트
var _spawn_timer := 0.0           # 다음 잡귀까지 남은 초
var _cust_timer := 0.0            # 다음 바 손님까지 남은 초
var _was_active := false          # 직전 tick의 활성(열림 & 밤 창) 상태(닫힘 전이 감지용)

# ★seam ㉠: 새 잡귀 접근 시간(초). 기본값에서 시작하고 T6.5 바나 보호가 키운다(막을 여유↑).
var approach_secs: float = DEFAULT_APPROACH
# ★seam ㉡: 새 손님 인내심(초). 기본값에서 시작하고 T6.5 바나 보호가 키운다(이탈↓).
var patience_secs: float = DEFAULT_PATIENCE
# ★seam ㉠: 잡귀 1마리 돌파 시 약탈 재고량. 기본값에서 시작하고 T6.5 바나 보호가 줄인다(약탈량↓).
var raid_amount: int = DEFAULT_RAID
# ★seam ㉠: 내가 못 막은 돌파를 바나가 대신 막아주는 마리 수(밤당). 기본값(0)에서 시작하고 T6.5
# 바나 보호가 키운다(창고 잡귀 자동 차단↑ — 여우불 '범위'의 밤판, 못 간 스폿을 바나가 받침).
var auto_block: int = DEFAULT_AUTO_BLOCK

# 오늘 밤 정산 누적(세이브 무상태 — 매일 open_bar/end_day가 리셋, 일시 표시·요약용).
var _raided := 0                  # ㉮ 막기 실패로 약탈당한 재고량(누적)
var _revenue := 0                 # 응대 성공 밤 매출(누적)
var _left := 0                    # ㉯ 응대 실패(인내심 초과)로 떠난 손님 수(누적)
var _auto_blocks_left := 0        # 이 밤 남은 바나 자동 차단 횟수(open_bar가 auto_block으로 채움)
var _auto_blocked := 0            # 이 밤 바나가 자동 차단한 잡귀 수(누적, HUD·체감용)

func _ready() -> void:
	for i in N_SPOTS:
		_spots.append({"active": false, "approach": 0.0, "max_approach": approach_secs})
	for i in N_SEATS:
		_seats.append({"occupied": false, "patience": 0.0, "max_patience": patience_secs})

# ★ 옵트인: 플레이어가 밤 바를 연다. 밤 창(19–24시) 안에서만 열 수 있고, 한 번 열면 그 밤
# 동안 유지된다(end_day가 다음 밤을 위해 리셋). 이미 열려 있거나 창 밖이면 false(헛 호출
# 방어 — main은 창·옵트인 상태를 보고 프롬프트를 띄운 뒤 부른다). 여는 순간 잡귀·손님 정산을
# 리셋하고 스폰 타이머를 잡아 곧 잡귀와 손님이 깃들게 한다.
func open_bar(minutes: float) -> bool:
	if _opened or not _in_window(minutes):
		return false
	_opened = true
	_raided = 0
	_revenue = 0
	_left = 0
	_auto_blocked = 0
	_auto_blocks_left = auto_block   # ★ 이 밤 바나가 받쳐줄 횟수를 현재 하트 보호값으로 채운다
	_spawn_timer = SPAWN_INTERVAL
	_cust_timer = CUST_INTERVAL
	_clear_spots()
	_clear_seats()
	changed.emit()
	return true

# main이 매 프레임 호출한다. 활성(_opened & 밤 창) 일 때만 잡귀가 깃들고/접근하고 손님이
# 앉고/기다린다. 안 열었으면(옵트인 X) 창 안이어도 아무 일도 없다 — 빈 밤이다. 밤의 자연스러운
# 끝은 자정 강제 취침(24:00 = CLOSE_MIN)뿐이라 — 카페처럼 "영업 후 깨어 있는 시간"이 없다 —
# 정산 요약은 tick의 창-닫힘 전이가 아니라 취침 훅(end_day)에서 쏜다(아래 end_day 주석).
func tick(delta: float, minutes: float) -> void:
	var active_now := _opened and _in_window(minutes)
	_was_active = active_now
	if not active_now:
		return

	var dirty := false
	dirty = _tick_spots(delta) or dirty       # 잡귀 접근·돌파(막기 실패→약탈)
	dirty = _tick_customers(delta) or dirty    # 손님 인내심·이탈(응대 실패→매출·단골 이탈)
	if dirty:
		changed.emit()

# 잡귀 접근 감소 + 돌파 처리(★ 이중 손실 ㉮). 접근이 0이 되면 잡귀가 스폿을 비우며 재고를
# 약탈한다 — _raided에 raid_amount를 쌓고 막기 해소 계약 resolved({repelled:false, raided})를
# 쏜다(main이 그 값만큼 수확물을 덜어낸다, 미래 자산). 막아내면(block) 이 돌파에 안 닿는다.
# ★ T6.5 ㉠ 자동 차단: 내가 못 막은 돌파라도 바나 보호 횟수(_auto_blocks_left)가 남아 있으면
# 바나가 대신 막는다 — 약탈 0, 막기 해소 계약을 {repelled:true, auto:true}로 쏜다(다운스트림이
# '내 막기'와 구분해 안내하되 손실 적용은 안 함). 여우불 '범위'(못 준 칸을 대신 돌봄)의 밤판.
func _tick_spots(delta: float) -> bool:
	var dirty := false
	for s in _spots:
		if s["active"]:
			s["approach"] -= delta
			if s["approach"] <= 0.0:
				s["active"] = false
				if _auto_blocks_left > 0:
					_auto_blocks_left -= 1
					_auto_blocked += 1
					resolved.emit({"repelled": true, "raided": 0, "auto": true})
				else:
					_raided += raid_amount
					resolved.emit({"repelled": false, "raided": raid_amount})
				dirty = true
	# 새 잡귀 스폰(빈 스폿이 있을 때만 실제로 깃든다).
	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		_spawn_timer = SPAWN_INTERVAL
		if _spawn_jobgui():
			dirty = true
	return dirty

# 손님 인내심 감소 + 이탈 처리(★ 이중 손실 ㉯). 인내심이 0이 되면 손님이 떠난다 — _left를
# 올리고 매출은 +0(벌칙 없음 → 무막힘). 카운터를 비우고 막으러 간 사이 닳는 게 응대 실패다.
func _tick_customers(delta: float) -> bool:
	var dirty := false
	for s in _seats:
		if s["occupied"]:
			s["patience"] -= delta
			if s["patience"] <= 0.0:
				s["occupied"] = false
				_left += 1
				dirty = true
	# 새 손님 스폰(빈 자리가 있을 때만 실제로 앉는다).
	_cust_timer -= delta
	if _cust_timer <= 0.0:
		_cust_timer = CUST_INTERVAL
		if _seat_customer():
			dirty = true
	return dirty

func _clear_spots() -> void:
	for s in _spots:
		s["active"] = false
		s["approach"] = 0.0

func _clear_seats() -> void:
	for s in _seats:
		s["occupied"] = false
		s["patience"] = 0.0

# 새 날 시작(취침) 시 호출 — 밤의 자연스러운 끝. 바를 열었던 밤이면 정산 요약(closed)을 먼저
# 쏘고(약탈·밤 매출·이탈 — 옵트인의 대가와 보상), 그 다음 옵트인을 꺼 다음 밤을 *새 선택*으로
# 돌린다(매일 세금 아님, ADR-0010 #6). 안 열었던 밤이면 조용히 리셋만 한다(빈 밤엔 정산할 것이
# 없다 — 자정 전 취침 시 손실 0·밤 매출 0). 세이브 무상태라 다음 밤이 깨끗이 다시 시작된다.
func end_day() -> void:
	if _opened:
		closed.emit(_raided, _revenue, _left)
	_opened = false
	_was_active = false
	_raided = 0
	_revenue = 0
	_left = 0
	_auto_blocked = 0
	_auto_blocks_left = 0
	_clear_spots()
	_clear_seats()

# 빈 스폿 하나에 새 잡귀를 깃들인다(앞에서부터 첫 빈 스폿). 스폿이 다 차 있으면 false.
func _spawn_jobgui() -> bool:
	for s in _spots:
		if not s["active"]:
			s["active"] = true
			s["approach"] = approach_secs
			s["max_approach"] = approach_secs
			return true
	return false

# 빈 좌석 하나에 새 바 손님을 앉힌다(앞에서부터 첫 빈 자리). 자리가 다 차 있으면 false.
func _seat_customer() -> bool:
	for s in _seats:
		if not s["occupied"]:
			s["occupied"] = true
			s["patience"] = patience_secs
			s["max_patience"] = patience_secs
			return true
	return false

func _in_window(minutes: float) -> bool:
	return minutes >= OPEN_MIN and minutes < CLOSE_MIN

# ── 막기(★ 막기 해소 계약, main이 잡귀 칸을 바라보며 E일 때 호출) ──────────────
# 이 스폿의 잡귀를 즉시 격퇴 처리하고 막기 해소 계약 {repelled, raided}를 돌려준다(접근→E→
# 쫓아냄, 전투 엔진 0 — ADR-0010 #2). 막을 잡귀가 없으면 {repelled:false, raided:0}(헛 호출
# 방어 — main은 is_threat 확인 후 부른다). 성공도 resolved를 쏴 다운스트림이 막기 방식을 모른
# 채 결과만 소비하게 한다(Phase 3 전투가 이 *구현만* 교체, 같은 계약 — ADR-0010 #8).
func block(spot: int) -> Dictionary:
	if not is_threat(spot):
		return {"repelled": false, "raided": 0}
	_spots[spot]["active"] = false
	var result := {"repelled": true, "raided": 0}
	changed.emit()
	resolved.emit(result)
	return result

# ── 응대(main이 호출 — 밤 매출은 재료 무소모 정액, 현재 자산) ──────────────────
# 이 좌석 손님을 응대 완료 처리하고 밤 매출(정액 SERVE_PRICE)을 돌려준다. 정산에 누적한다.
# 기다리는 손님이 없으면 0(잘못된 호출 방어 — main은 is_waiting 확인 후 부른다). 카페 서빙과
# 달리 재료를 소모하지 않는다 — 응대 매출은 '현재 자산'이고, '미래 자산'(재고)은 잡귀 약탈
# 쪽이 건드린다(ADR-0010 #5 현재/미래 분리, 바나는 마진 아닌 보호라 단가 배수도 없다).
func serve(seat: int) -> int:
	if not is_waiting(seat):
		return 0
	_seats[seat]["occupied"] = false
	_seats[seat]["patience"] = 0.0
	_revenue += SERVE_PRICE
	changed.emit()
	return SERVE_PRICE

# ── 조회(main이 그리기·입력·HUD에 쓴다) ────────────────────────────────────
# 지금 밤 창(19–24시) 안인가 — 옵트인 프롬프트를 띄울지 판단(창 밖이면 못 연다).
func is_window(minutes: float) -> bool:
	return _in_window(minutes)

# 오늘 밤 바를 열었나(옵트인 게이트). 안 열었으면 잡귀·손님이 없고 밤 손실도 0이다.
func is_opened() -> bool:
	return _opened

# 지금 잡귀·손님이 깃들 수 있는 활성 상태인가(열림 & 밤 창) — 직전 tick 기준. main이 잡귀·
# 손님 그리기/막기·서빙 처리 여부를 가른다.
func is_active() -> bool:
	return _was_active

# 이 스폿에 막아야 할 잡귀가 있는가(막기 대상 판정 — main의 E 입력이 쓴다).
func is_threat(spot: int) -> bool:
	return spot >= 0 and spot < _spots.size() and _spots[spot]["active"]

# 이 좌석에 응대를 기다리는 손님이 있는가(서빙 대상 판정 — main의 E 입력이 쓴다).
func is_waiting(seat: int) -> bool:
	return seat >= 0 and seat < _seats.size() and _seats[seat]["occupied"]

# 이 스폿 잡귀의 접근 잔량 비율(0~1) — 접근 바 그리기용. 빈 스폿이면 0.
func approach_ratio(spot: int) -> float:
	if not is_threat(spot):
		return 0.0
	var s: Dictionary = _spots[spot]
	var m: float = s["max_approach"]
	return clampf(s["approach"] / m, 0.0, 1.0) if m > 0.0 else 0.0

# 이 좌석 손님의 인내심 잔량 비율(0~1) — 인내심 바 그리기용. 빈 자리면 0.
func patience_ratio(seat: int) -> float:
	if not is_waiting(seat):
		return 0.0
	var s: Dictionary = _seats[seat]
	var m: float = s["max_patience"]
	return clampf(s["patience"] / m, 0.0, 1.0) if m > 0.0 else 0.0

# 활성 잡귀 수 — HUD "잡귀 N" 표시용.
func threat_count() -> int:
	var n := 0
	for s in _spots:
		if s["active"]:
			n += 1
	return n

# 응대를 기다리는 손님 수 — HUD "손님 N" 표시용.
func customer_count() -> int:
	var n := 0
	for s in _seats:
		if s["occupied"]:
			n += 1
	return n

# 오늘 밤 약탈당한 재고량(★ 이중 손실 ㉮ 누적). 완료기준·정산 요약·디버그용.
func tonight_raided() -> int:
	return _raided

# 오늘 밤 응대 매출(밤 매출 누적). 정산 요약·HUD용.
func tonight_revenue() -> int:
	return _revenue

# 오늘 밤 인내심 초과로 떠난(이탈) 손님 수(★ 이중 손실 ㉯ 누적). 정산 요약·디버그용.
func tonight_left() -> int:
	return _left

# 오늘 밤 바나가 자동 차단한(내가 못 막았으나 약탈 0으로 막힌) 잡귀 수(★ ㉠ 누적). HUD·체감용.
func tonight_auto_blocked() -> int:
	return _auto_blocked

# 이 밤 남은 바나 자동 차단 횟수(HUD "자동차단 N/M"·디버그용).
func auto_blocks_left() -> int:
	return _auto_blocks_left
