extends RefCounted
class_name CocktailSession
# ★[S6-T6 / ADR-0064 결정 6] 밤 바 칵테일 = 입력·렌더와 분리된 순수 상태 머신(ChekiSession 골격 1:1).
#
# 목적: ROADMAP Slice 6 — 밤 [나라카 바]의 정체성 활동을 *헤드리스에서 전부 재현 가능한* 순수
#       로직으로 만든다. 낮 카페가 [체키](창작·수집)면 밤 바는 **플레이어의 믹싱/타이밍 미니게임**
#       이다(CONTEXT [칵테일] — "낮 서빙의 단순 연장 아님, 밤에 독자 *액티브 스킬* 결").
#
# 설계 메모(cheki.gd가 fishing.gd에서 물려받은 그 규범을 그대로 잇는다 — 어기면 ADR-0064 결정 6 위반):
#   - **Node 아님·렌더 무의존**(RefCounted). 씬 트리에 안 붙고 _process도 없다 — main이 매 프레임
#     tick(delta, pressed)로 굴린다. 시그널도 없다(폴링 조회 API로 읽는다).
#   - **RNG = 시드 주입**(rng_seed). 같은 시드 + 같은 입력열 = 같은 결과. 이 세션의 모든 변주
#     (붓기 2회의 시작 위치·속도·방향·목표 + 셰이킹 박자 시작점)는 begin() 한 곳에서 순차로 뽑힌다.
#   - **혼력을 모른다 — 쓰지도 않는다**(밤 바는 시간 창으로만 제한 — night_bar.gd 주석·ADR-0010 #3).
#     칵테일의 비용은 *밤 창의 시간*이다: 세션을 젓는 동안에도 잡귀는 계속 접근하고 다른 손님의
#     인내심은 계속 닳는다(밤의 깊이 vs 회전+방어의 트레이드오프 = 본체). 그 경쟁은 main이
#     night_bar.tick을 멈추지 *않음*으로써 성립한다(세션은 절대 시간을 멈추지 않는다).
#   - **돈·손님·잡귀를 모른다**. 매출 배수(NightBar.COCKTAIL_RATE)는 하류다. 이 파일이 아는 건
#     "얼마나 잘 만들었나"(0..1 점수)뿐이다. **바나 보호 곱셈기(raid_amount·auto_block·patience_secs)
#     축에는 손끝도 안 닿는다** — 이 세션은 night_bar의 seam을 읽지도 쓰지도 않는다(ADR-0064 결정 6
#     "night_bar의 잡귀 방어·바나 보호 곱셈기는 불변").
#   - **등급은 여기서 *정하지* 않고 *매핑만* 한다** — result()는 원자료(점수)를 넘기고, 하류(main)가
#     static `grade_for()`를 불러 등급을 얻는다(cheki.gd와 같은 접점 규약).
#   - **세이브 무상태**(night_bar.gd·cafe.gd·cheki.gd와 일관): 세션은 한 잔을 만드는 동안만 살아
#     있고 취침·저장 대상이 아니다. 저장되는 건 하류 산출물(지갑)뿐이다.
#
# ── ★ 체키와 *결*이 다른 이유(같은 골격 위의 다른 손맛 — CONTEXT [칵테일] "종류가 다른 액티브") ──
#   ㉠ **입력 횟수**: 체키는 두 번 누르고 끝(구도·셔터). 칵테일은 **붓기 2회 + 박자 4회 = 6회**를
#      한 세션에서 친다. 같은 ~7.5초 안에 손이 세 배 바쁘다 = 액티브.
#   ㉡ **커서 속도·창 폭**: 붓기 커서는 체키 셔터(0.75~1.05)보다 빠르고(1.10~1.45) 창은 좁다
#      (0.13 vs 0.20). 겨누는 게 아니라 *쳐내는* 감각.
#   ㉢ **셰이킹 = 박자지 연타가 아니다**: 창이 주기적으로 열리고 그 안의 첫 누름만 적중이다. 창
#      밖의 누름은 stray로 점수를 깎으므로 **연타는 0점으로 수렴한다**(무작정 누르기가 최적해면
#      리듬이 아니라 손가락 시험이 된다). 창을 놓쳐도 다음 박자는 그대로 온다(회복 가능).
#
# ── 상태 머신 ────────────────────────────────────────────────────────────────
# IDLE → POUR(붓기 1회차) → POUR(붓기 2회차) → SHAKE(셰이킹) → DONE.
# DONE은 종착역 — main이 result()를 읽고 세션을 버린다. **실패 종착역이 없다**(아래 무실패 주석).
# ★ 붓기 2회는 *같은 State*를 두 번 산다(pour_round로 가른다) — 두 회차가 같은 동사·같은 HUD라
#   상태를 쪼갤 이유가 없고, 회차 수를 레버(POUR_ROUNDS)로 돌릴 수 있게 된다.
enum State { IDLE, POUR, SHAKE, DONE }

# 등급 3단 — **실패 등급이 없다**(ADR-0008 "평평 ≠ 막힘" · 코지 톤). 최저 등급도 소액이나마
# 프리미엄이 붙는다(NightBar.COCKTAIL_RATE[0] > 0). 체키와 같은 사다리를 쓰는 건 밤낮 두 심화
# 미니게임의 보상 문법을 하나로 유지하기 위해서다(플레이어가 두 번 배우지 않는다).
enum Grade { OK, GOOD, PERFECT }

# ── 타이밍·난이도 상수(그레이박스 레버 — 스펙카드로 잠금, ADR-0028) ────────────
# ★ 전반 기조: **체키보다 빠르고 좁고 잦다**. 단 반사신경 스파이크는 아니다 — 무실패 구조라
#   못 쳐도 잃지 않고, 창을 놓쳐도 다음 박자가 온다(코지 안에서의 액티브).
const ARM_SECS := 0.15          # 세션 시작 후 입력을 안 받는 준비 구간(초). 응대 입력이 그대로
                                #   흘러들어 첫 프레임에 붓기가 확정되는 사고를 막는다(체키 동형).

const POUR_ROUNDS := 2          # 붓기 라운드 수(잔에 술을 붓는 두 번 — 베이스·리큐르 결)
const POUR_SECS := 2.5          # 붓기 한 회차 제한(초) — 넘기면 *지금 자리 그대로* 자동 확정(무실패)
const POUR_SPEED_MIN := 1.10    # 붓기 커서 왕복 속도 하한 — ★체키 셔터(0.75)보다 빠르다(㉡)
const POUR_SPEED_MAX := 1.45    # 상한
const POUR_TOL := 0.13          # 점수가 0이 되는 목표 이탈 거리 — ★체키 셔터(0.20)보다 좁다(㉡)
const POUR_TARGET_MIN := 0.22   # 목표 위치 범위 — 트랙 끝에 붙지 않게(끝은 반사로 체류가 길어져
const POUR_TARGET_MAX := 0.78   #   난이도가 되레 이상해진다. 체키와 같은 이유)

const SHAKE_BEATS := 4          # 셰이킹 박자 수(창이 이만큼 열린다 — 다 놓쳐도 세션은 끝난다)
const SHAKE_PERIOD := 0.62      # 박자 간격(초) — 사람이 따라 칠 수 있는 느린 4박
const SHAKE_WINDOW := 0.14      # 박자 중심 ±(초) 열린 창. 이 안의 **첫** 누름만 적중이다
const SHAKE_LEAD_MIN := 0.45    # 첫 박자까지의 여유(초) 하한 — 시드로 흔들어 박자 시작을 못 외우게
const SHAKE_LEAD_MAX := 0.75    # 상한
const SHAKE_TAIL := 0.10        # 마지막 창이 닫힌 뒤 여운(초) — 이 시간이 지나면 자동 확정
# ★ 창 밖 누름(stray) 1회가 깎는 박자 수. **연타 억제의 유일한 장치**다(㉢): 1.0이면 한 번 삐끗에
#   적중 하나가 통째로 날아가 코지가 깨지고, 0이면 연타가 최적해가 되어 리듬이 사라진다. 그 사이.
const SHAKE_STRAY_PENALTY := 0.5

# 등급 문턱(종합 점수). ★단조 규약: OK < GOOD < PERFECT 순서가 깨지면 grade_for가 뒤집힌다
# (cocktail_test ⓑ가 이 불변식을 단언한다). 체키와 같은 문턱 = 밤낮 사다리의 체감 통일.
const GRADE_GOOD := 0.55
const GRADE_PERFECT := 0.85

# ── 상태(읽기 전용으로 다뤄라 — 변경은 tick/begin/cancel만) ───────────────────
var state: int = State.IDLE
var pour_round: int = 0         # 지금 몇 회차 붓기인가(0-based · HUD 단계 표식)
var pour_scores: Array = []     # 회차별 붓기 점수 0~1(확정된 회차만 쌓인다)
var pour_timeouts: Array = []   # 회차별 자동 확정 여부(HUD 문구·디버그 — 벌칙 아님)
var shake_score: float = 0.0    # 셰이킹 점수 0~1(SHAKE 확정 시 결정)
var shake_hits: int = 0         # 창 안에서 제대로 친 박자 수
var shake_strays: int = 0       # 창 밖에서 헛친 횟수(연타 억제 — 점수만 깎고 벌칙은 없다)
var elapsed: float = 0.0        # 세션 시작(begin)부터의 누적 초

var _rng := RandomNumberGenerator.new()
var _phase_t := 0.0             # 현재 단계에 머문 시간(초)
var _was_pressed := false       # 직전 프레임의 버튼 상태 — **누른 순간(rising edge)** 판정용.
                                #   홀드가 아니라 edge를 보는 이유: 칵테일은 "붓다 → 붓다 → 네 번
                                #   흔든다"가 여섯 번 반복되는 리듬이라, 홀드로 받으면 한 번 누른
                                #   채로 전 단계가 통째로 지나간다. 세션이 스스로 edge를 재는 건
                                #   main이 폴링(is_action_pressed) 값만 넘겨도 되게 해 테스트가 쉬워서다.
var _pour_pos: Array = []       # 회차별 커서의 현재 위치 0~1(트랙을 왕복)
var _pour_vel: Array = []       # 그 속도(부호 = 방향 · 경계에서 반사)
var _pour_targets: Array = []   # 회차별 목표 위치(시드 파생)
var _shake_lead := 0.0          # 첫 박자 중심까지의 초(시드 파생)
var _shake_span := 0.0          # 셰이킹 단계 전체 길이(초) = lead + 간격×(박자-1) + 창 + 여운
var _beat_hit: Array = []       # 박자별 적중 여부(한 창에 두 번 쳐도 한 번만 센다)

# rng_seed = 결정성의 단일 출처.
func _init(rng_seed: int) -> void:
	_rng.seed = rng_seed

# ── 진행 API ────────────────────────────────────────────────────────────────
# 제조 시작(IDLE에서만). 이번 세션의 변주를 시드에서 뽑는다.
# ★ 롤 순서(순차 소비): 회차마다 ①시작 위치 ②속도 ③방향 ④목표를 뽑고(붓기 2회 = 8롤), 마지막에
#   ⑨셰이킹 lead. 신규 롤은 **맨 뒤로 승격**한다 — 앞에 끼우면 같은 시드의 결과열이 통째로 갈려
#   결정성 단언이 그 자리에서 터진다(cheki.begin·cafe.roll_want·mine_floors와 같은 규율).
func begin() -> bool:
	if state != State.IDLE:
		return false
	state = State.POUR
	pour_round = 0
	_phase_t = 0.0
	elapsed = 0.0
	pour_scores = []
	pour_timeouts = []
	_pour_pos = []
	_pour_vel = []
	_pour_targets = []
	for _i in POUR_ROUNDS:
		_pour_pos.append(_rng.randf_range(0.0, 1.0))                        # ①
		var v := _rng.randf_range(POUR_SPEED_MIN, POUR_SPEED_MAX)           # ②
		if _rng.randf() < 0.5:                                              # ③
			v = -v
		_pour_vel.append(v)
		_pour_targets.append(_rng.randf_range(POUR_TARGET_MIN, POUR_TARGET_MAX))  # ④
	_shake_lead = _rng.randf_range(SHAKE_LEAD_MIN, SHAKE_LEAD_MAX)          # ⑨
	_shake_span = _shake_lead + SHAKE_PERIOD * float(SHAKE_BEATS - 1) + SHAKE_WINDOW + SHAKE_TAIL
	_beat_hit = []
	for _i in SHAKE_BEATS:
		_beat_hit.append(false)
	shake_score = 0.0
	shake_hits = 0
	shake_strays = 0
	return true

# 세션 취소(이동 입력 등). 종착 상태에서도 안전(멱등) — main이 세션 참조를 버리면 끝이다.
# ★ 취소는 **매출 0**이지 벌칙이 아니다(만들다 말았을 뿐 — 응대 매출은 이미 받았다).
func cancel() -> void:
	state = State.IDLE

# 아직 굴러가는 세션인가(main의 tick·HUD 게이트).
func is_active() -> bool:
	return state == State.POUR or state == State.SHAKE

# 결착이 났나 — main이 이 프레임에 결과를 수확하고 세션을 버린다.
func is_finished() -> bool:
	return state == State.DONE

# ★ 한 프레임 진행. pressed = 지금 버튼을 누르고 있는가(홀드 상태 그대로 넘겨라 — edge는 세션이
#   잰다). 결정적이라 테스트가 같은 delta·입력열을 먹이면 같은 결과가 나온다.
#   종착 상태에서는 무동작(멱등).
func tick(delta: float, pressed: bool) -> void:
	if not is_active():
		_was_pressed = pressed
		return
	elapsed += delta
	_phase_t += delta
	# 준비 구간 동안의 입력은 없던 것으로 흘려보낸다(단, 홀드 상태는 계속 추적해 구간이 끝난 뒤
	# *새로* 누를 때만 먹히게 한다 — 응대 버튼을 붙잡고 있어도 그 홀드가 붓기가 되지 않는다).
	var fired := pressed and not _was_pressed and elapsed >= ARM_SECS
	_was_pressed = pressed
	match state:
		State.POUR:
			_tick_pour(delta, fired)
		State.SHAKE:
			_tick_shake(fired)

# 붓기 단계: 빠르게 왕복하는 커서를 좁은 목표 창에 맞춰 누른다. 제한 시간이 지나면 지금 자리로
# 자동 확정하고 다음 회차(또는 셰이킹)로 넘어간다.
func _tick_pour(delta: float, fired: bool) -> void:
	_pour_pos[pour_round] = _drift(pour_round, delta)
	if fired:
		_lock_pour(false)
	elif _phase_t >= POUR_SECS:
		_lock_pour(true)

func _lock_pour(timed_out: bool) -> void:
	pour_scores.append(_proximity(float(_pour_pos[pour_round]),
		float(_pour_targets[pour_round]), POUR_TOL))
	pour_timeouts.append(timed_out)
	_phase_t = 0.0
	if pour_round + 1 < POUR_ROUNDS:
		pour_round += 1
	else:
		state = State.SHAKE

# 셰이킹 단계: 주기적으로 열리는 창 안에서 한 번씩 친다(연타 아님 — 창 밖 누름은 stray).
# ★ 확정 입력이 없다 — 마지막 창이 닫히고 여운이 지나면 *스스로* 끝난다(무실패의 극단: 한 번도
#   안 쳐도 세션은 최저 점수로 종착한다). 그래서 delta를 안 쓰고 누적 _phase_t만 본다.
func _tick_shake(fired: bool) -> void:
	if fired:
		var beat := _beat_at(_phase_t)
		if beat >= 0 and not _beat_hit[beat]:
			_beat_hit[beat] = true
			shake_hits += 1
		else:
			shake_strays += 1          # 창 밖 / 이미 친 창 — 연타가 이득이 되지 않게
	if _phase_t >= _shake_span:
		_lock_shake()

func _lock_shake() -> void:
	# 점수 = (적중 − 헛침×페널티) / 박자 수, 0~1 클램프. **음수가 안 나온다** — 아무리 난타해도
	# 바닥은 0점(= OK 등급 + 매출)이지 마이너스가 아니다(무실패, ADR-0008).
	var raw := (float(shake_hits) - float(shake_strays) * SHAKE_STRAY_PENALTY) / float(SHAKE_BEATS)
	shake_score = clampf(raw, 0.0, 1.0)
	state = State.DONE

# 이 시각(단계 내 초)에 열려 있는 박자 인덱스(없으면 -1). 창은 겹치지 않는다(PERIOD > WINDOW×2).
func _beat_at(t: float) -> int:
	for i in SHAKE_BEATS:
		if absf(t - beat_center_secs(i)) <= SHAKE_WINDOW:
			return i
	return -1

# 트랙 0~1을 왕복(경계 반사). 회차별 pos·vel을 함께 굴린다.
func _drift(idx: int, delta: float) -> float:
	var p := float(_pour_pos[idx]) + float(_pour_vel[idx]) * delta
	var vel := float(_pour_vel[idx])
	# while: delta가 크면 한 프레임에 두 번 튈 수 있다(헤드리스가 굵은 step을 먹일 때의 방어).
	while p < 0.0 or p > 1.0:
		if p < 0.0:
			p = -p
			vel = -vel
		else:
			p = 2.0 - p
			vel = -vel
	_pour_vel[idx] = vel
	return p

# 근접도 → 0~1 점수. 목표에 정확히 겹치면 1, tol만큼 벗어나면 0(그 밖은 0으로 클램프).
# ★ **0점도 실패가 아니다** — 등급 사다리의 바닥(OK)일 뿐이고 매출은 그래도 붙는다.
static func _proximity(pos: float, target: float, tol: float) -> float:
	if tol <= 0.0:
		return 0.0
	return clampf(1.0 - absf(pos - target) / tol, 0.0, 1.0)

# ── 조회(HUD·main·테스트 — 폴링 전용, 시그널 없음) ────────────────────────────
# ★ HUD는 두 단계를 **같은 트랙 한 줄**로 그린다(그래서 조회 API도 트랙 문법으로 통일한다):
#   붓기 = 왕복하는 커서 + 창 1개 · 셰이킹 = 왼→오 한 번 흐르는 시간 커서 + 창 SHAKE_BEATS개.
#   한 화면 문법으로 두 결을 보이니 플레이어가 판을 두 번 배우지 않는다.
# 트랙 위 커서 위치 0~1.
func cursor_pos() -> float:
	if state == State.POUR:
		return float(_pour_pos[pour_round])
	if state == State.SHAKE:
		return clampf(_phase_t / _shake_span, 0.0, 1.0) if _shake_span > 0.0 else 0.0
	return 0.0

# 지금 단계의 창 개수(붓기 1 · 셰이킹 = 박자 수).
func zone_count() -> int:
	if state == State.POUR:
		return 1
	if state == State.SHAKE:
		return SHAKE_BEATS
	return 0

# i번째 창의 중심(트랙 0~1 좌표).
func zone_center(i: int) -> float:
	if state == State.POUR:
		return float(_pour_targets[pour_round])
	if state == State.SHAKE and _shake_span > 0.0:
		return clampf(beat_center_secs(i) / _shake_span, 0.0, 1.0)
	return 0.0

# 창의 반폭(트랙 0~1 좌표) — HUD가 목표대의 *너비*를 그린다(넓이가 곧 관대함의 시각적 약속).
func zone_half_width() -> float:
	if state == State.POUR:
		return POUR_TOL
	if state == State.SHAKE and _shake_span > 0.0:
		return SHAKE_WINDOW / _shake_span
	return 0.0

# i번째 박자를 이미 쳤나(HUD 점 표식 — 셰이킹 전용).
func beat_hit(i: int) -> bool:
	return i >= 0 and i < _beat_hit.size() and bool(_beat_hit[i])

# i번째 박자 중심의 단계 내 시각(초). 테스트 드라이버가 "언제 칠지"를 이걸로 안다.
func beat_center_secs(i: int) -> float:
	return _shake_lead + SHAKE_PERIOD * float(i)

# 현재 단계에 머문 시간(초) — 테스트 드라이버·디버그.
func phase_time() -> float:
	return _phase_t

# 셰이킹 단계 전체 길이(초, 시드 파생) — 세션 상한 단언·HUD.
func shake_span() -> float:
	return _shake_span

# ★ 세션 최장 길이(초, static) — 시드와 무관한 상한. "미니게임이 밤 창을 통째로 먹지 않는다"는
#   시간 게이팅의 산술적 보증이고, cocktail_test ⓑ가 실측을 이 값과 대조한다.
static func max_session_secs() -> float:
	return POUR_SECS * float(POUR_ROUNDS) + SHAKE_LEAD_MAX \
		+ SHAKE_PERIOD * float(SHAKE_BEATS - 1) + SHAKE_WINDOW + SHAKE_TAIL

# 현재 단계의 남은 시간 비율(1 = 방금 시작 · 0 = 자동 확정 직전). HUD 모래시계.
func phase_left_ratio() -> float:
	var span := POUR_SECS if state == State.POUR else _shake_span
	return clampf(1.0 - _phase_t / span, 0.0, 1.0) if span > 0.0 else 0.0

# 지금 커서가 창 안인가(HUD 강조 — "지금 눌러라"의 유일한 신호). 이미 친 박자 창은 꺼진다.
func in_sweet_zone() -> bool:
	if state == State.POUR:
		return absf(float(_pour_pos[pour_round]) - float(_pour_targets[pour_round])) <= POUR_TOL
	if state == State.SHAKE:
		var b := _beat_at(_phase_t)
		return b >= 0 and not _beat_hit[b]
	return false

# 확정된 붓기 점수들의 평균(아직 한 회차도 안 끝났으면 0).
func pour_score() -> float:
	if pour_scores.is_empty():
		return 0.0
	var sum := 0.0
	for s in pour_scores:
		sum += float(s)
	return sum / float(pour_scores.size())

# 종합 점수 0~1 = **붓기(정확도) 절반 + 셰이킹(박자) 절반**. 두 *결*의 무게가 같다 — 붓기만 잘하고
# 리듬을 놓치면 최고가 안 나온다(회차 수를 늘려도 붓기가 판을 독식하지 않게 회차 평균을 쓴다).
func score() -> float:
	return clampf(pour_score() * 0.5 + shake_score * 0.5, 0.0, 1.0)

# ★ 점수 → 등급(순수 static). 세션 밖에서도 부를 수 있어야 한다 — main이 result()의 원자료로
#   등급을 얻고, 테스트는 세션 없이 문턱만 따로 검증한다(ChekiSession.grade_for와 같은 자리).
static func grade_for(total: float) -> int:
	if total >= GRADE_PERFECT:
		return Grade.PERFECT
	if total >= GRADE_GOOD:
		return Grade.GOOD
	return Grade.OK

# 등급 한글 표시명(알림·HUD — 그레이박스 판독성 우선). 체키(한 컷/잘 나온 컷/인생샷)와 대칭 결.
static func grade_name(grade: int) -> String:
	match grade:
		Grade.PERFECT: return "인생 한 잔"
		Grade.GOOD: return "잘 섞인 잔"
		_: return "한 잔"

# ★ 결과 계약(main·테스트가 소비하는 유일한 산출물). **등급은 안 담는다** — 원자료(점수)만 넘기고
#   해석은 grade_for가 한다(cheki.result()와 같은 원칙). 키는 평평하게 둔다(중첩 배열 비교 회피).
func result() -> Dictionary:
	return {
		"pour_score": pour_score(),
		"shake_score": shake_score,
		"score": score(),
		"elapsed": elapsed,
		"shake_hits": shake_hits,
		"shake_strays": shake_strays,
		"pour_timeouts": pour_timeouts.duplicate(),
	}

# 상태 한글 표시명(HUD·디버그). 붓기는 회차를 말해 준다(같은 State를 두 번 사는 걸 문구가 갈라 준다).
func state_label() -> String:
	match state:
		State.POUR: return "붓기 %d/%d" % [pour_round + 1, POUR_ROUNDS]
		State.SHAKE: return "셰이킹 %d/%d" % [shake_hits, SHAKE_BEATS]
		State.DONE: return "제조 완료"
		_: return "대기"
