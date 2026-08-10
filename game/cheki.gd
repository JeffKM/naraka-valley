extends RefCounted
class_name ChekiSession
# ★[S6-T5 / ADR-0064 결정 5] 상업 체키 = 입력·렌더와 분리된 순수 상태 머신(FishingSession 선례 1:1).
#
# 목적: ROADMAP Slice 6 — 카페 서빙 사슬(응대→체키)의 둘째 단을 *헤드리스에서 전부 재현 가능한*
#       순수 로직으로 만든다. 낮 카페의 시그니처 미니게임이고(CONTEXT [체키]), 밤 바 칵테일
#       (CocktailSession·S6-T6)이 뒤이어 같은 골격을 쓴다.
#
# 설계 메모(fishing.gd의 그 규범을 그대로 따른다 — 어기면 ADR-0061 결정 2·ADR-0064 결정 5 위반):
#   - **Node 아님·렌더 무의존**(RefCounted). 씬 트리에 안 붙고 _process도 없다 — main이 매 프레임
#     tick(delta, pressed)로 굴린다. 시그널도 없다(폴링 조회 API로 읽는다). 그래서 테스트가 씬 없이
#     new()로 전 시나리오를 0.05초 단위로 결정적으로 돌린다.
#   - **RNG = 시드 주입**(rng_seed). 같은 시드 + 같은 입력열 = 같은 결과. 이 세션의 모든 변주
#     (구도 목표·표류 속도·셔터 속도·스윗존)는 begin() 한 곳에서 순차로 뽑힌다.
#   - **혼력을 모른다 — 쓰지도 않는다**(CONTEXT [체키] "혼력 안 씀 = 시간 게이팅"). 낚시가
#     hook_gate로 혼력을 주입받던 자리가 여기엔 아예 없다. 체키의 비용은 *영업창의 시간*이다 —
#     세션을 도는 동안에도 다른 손님의 인내심은 계속 닳는다(깊이 vs 회전의 트레이드오프 = 본체).
#     그 경쟁은 main이 cafe.tick을 멈추지 *않음*으로써 성립한다(세션은 절대 시간을 멈추지 않는다).
#   - **돈·손님·메뉴를 모른다**. 매출 배수(Cafe.CHEKI_RATE)·단골 가중치(GuestPool.record_cheki)는
#     전부 하류다. 이 파일이 아는 건 "얼마나 잘 찍었나"(0..1 점수)뿐이다.
#   - **등급은 여기서 *정하지* 않고 *매핑만* 한다** — result()는 원자료(점수)를 넘기고, 하류(main)가
#     static `grade_for()`를 불러 등급을 얻는다(fishing.gd:28-29 "perfect_count만 노출" 원칙의 이행:
#     원자료와 해석을 갈라 두면 밸런스 문턱을 옮겨도 세션 로직이 안 흔들린다).
#   - **세이브 무상태**(cafe.gd·night_bar.gd·fishing.gd와 일관): 세션은 한 장 찍는 동안만 살아 있고
#     취침·저장 대상이 아니다. 저장되는 건 하류 산출물(지갑·단골 원장)뿐이다.
#   - **아티팩트 없음**(CONTEXT [체키] 상업 체키 — 손님이 가져간다). 사진 데이터·앨범·포즈 수집은
#     *개인 체키* 소관(이벤트 데이 의존 서랍)이라 이 파일에 자리가 없다.
#
# ── 상태 머신 ────────────────────────────────────────────────────────────────
# IDLE → AIM(구도 잡기) → SNAP(셔터 타이밍) → DONE.
# DONE은 종착역 — main이 result()를 읽고 세션을 버린다. **실패 종착역이 없다**(아래 무실패 주석).
enum State { IDLE, AIM, SNAP, DONE }

# 등급 3단 — **실패 등급이 없다**(ADR-0008 "평평 ≠ 막힘" · 코지 톤). 최저 등급 OK도 소액이나마
# 프리미엄이 붙는다: 체키는 스킬 스파이크가 아니라 *창작의 결*이라(CONTEXT [체키]) 잘 찍으면 더
# 받고 못 찍어도 잃지 않는다. 손해 보는 갈래를 만들면 "찍을까 말까"가 계산 문제가 되어 코지가 깨진다.
enum Grade { OK, GOOD, PERFECT }

# ── 타이밍·난이도 상수(그레이박스 레버 — 스펙카드로 잠금, ADR-0028) ────────────
# ★ 전반 기조: **속도는 완만하고 창은 넉넉하다**. 반사신경 스파이크 금지(CONTEXT [체키] — 낮
#   시그니처는 창작·수집 결이지 스킬 스파이크가 아니다. 스파이크는 밤 칵테일 몫도 아니고 전투 몫).
const ARM_SECS := 0.15          # 세션 시작 후 입력을 안 받는 준비 구간(초). 서빙 입력이 그대로
                                #   흘러들어 첫 프레임에 셔터가 눌리는 사고를 막는다(연출 겸 방어).
const AIM_SECS := 4.0           # 구도 단계 제한(초) — 넘기면 *지금 자리 그대로* 자동 확정(무실패)
const AIM_SPEED_MIN := 0.35     # 구도 프레임 표류 속도 하한(트랙 1.0을 지나는 데 ~2.9초)
const AIM_SPEED_MAX := 0.55     # 상한(~1.8초) — 눈으로 좇을 수 있는 범위로 좁게 잡는다
const AIM_TOL := 0.30           # 구도 점수가 0이 되는 목표 이탈 거리(넓다 = 관대)
const AIM_TARGET_MIN := 0.20    # 목표 구도 위치 하한 — 트랙 끝에 붙지 않게(끝은 반사로 체류가 길어
const AIM_TARGET_MAX := 0.80    #   져 난이도가 되레 이상해진다)
const SNAP_SECS := 3.5          # 셔터 단계 제한(초) — 넘기면 자동 촬영(무실패)
const SNAP_SPEED_MIN := 0.75    # 셔터 커서 왕복 속도 하한 — 구도보다 빠르다(두 단의 결을 가른다)
const SNAP_SPEED_MAX := 1.05    # 상한
const SNAP_TOL := 0.20          # 타이밍 점수가 0이 되는 스윗존 이탈 거리(구도보다 좁다)
const SNAP_TARGET_MIN := 0.25   # 스윗존 위치 범위 — 구도와 같은 이유로 트랙 끝을 피한다
const SNAP_TARGET_MAX := 0.75

# 등급 문턱(종합 점수 = 구도·타이밍 평균). ★단조 규약: OK < GOOD < PERFECT 순서가 깨지면
# grade_for가 뒤집힌다(cheki_test ⓑ가 이 불변식을 단언한다).
const GRADE_GOOD := 0.55
const GRADE_PERFECT := 0.85

# ── 상태(읽기 전용으로 다뤄라 — 변경은 tick/begin/cancel만) ───────────────────
var state: int = State.IDLE
var aim_score: float = 0.0      # 구도 점수 0~1(AIM 확정 시 결정)
var timing_score: float = 0.0   # 타이밍 점수 0~1(SNAP 확정 시 결정)
var elapsed: float = 0.0        # 세션 시작(begin)부터의 누적 초
var aim_timeout := false        # 구도를 안 잡아 자동 확정됐나(HUD 문구·디버그 — 벌칙 아님)
var snap_timeout := false       # 셔터를 안 눌러 자동 촬영됐나

var _rng := RandomNumberGenerator.new()
var _phase_t := 0.0             # 현재 단계에 머문 시간(초)
var _was_pressed := false       # 직전 프레임의 버튼 상태 — **누른 순간(rising edge)** 판정용.
                                #   홀드가 아니라 edge를 보는 이유: 체키는 "겨누다 → 누른다"가 두
                                #   번 반복되는 리듬이라, 홀드로 받으면 한 번 누른 채로 두 단이
                                #   한꺼번에 지나간다. 세션이 스스로 edge를 재는 건 main이 폴링
                                #   (is_action_pressed) 한 값만 넘겨도 되게 해 테스트가 쉬워서다.
var _aim_pos := 0.0             # 구도 프레임의 현재 위치 0~1(트랙을 왕복 표류)
var _aim_vel := 0.0             # 그 속도(부호 = 방향 · 경계에서 반사)
var _aim_target := 0.5          # 목표 구도 위치(시드 파생)
var _snap_pos := 0.0            # 셔터 커서의 현재 위치 0~1
var _snap_vel := 0.0
var _snap_target := 0.5         # 스윗존 중심(시드 파생)

# rng_seed = 결정성의 단일 출처.
func _init(rng_seed: int) -> void:
	_rng.seed = rng_seed

# ── 진행 API ────────────────────────────────────────────────────────────────
# 촬영 시작(IDLE에서만). 이번 세션의 변주를 시드에서 뽑는다.
# ★ 롤 순서(순차 소비): ①구도 시작 위치 ②구도 속도 ③구도 방향 ④목표 구도 ⑤셔터 시작 위치
#   ⑥셔터 속도 ⑦셔터 방향 ⑧스윗존. 신규 롤은 **맨 뒤로 승격**한다 — 앞에 끼우면 같은 시드의
#   결과열이 통째로 갈려 결정성 단언이 그 자리에서 터진다(cafe.roll_want·mine_floors와 같은 규율).
func begin() -> bool:
	if state != State.IDLE:
		return false
	state = State.AIM
	_phase_t = 0.0
	elapsed = 0.0
	_aim_pos = _rng.randf_range(0.0, 1.0)                              # ①
	_aim_vel = _rng.randf_range(AIM_SPEED_MIN, AIM_SPEED_MAX)          # ②
	if _rng.randf() < 0.5:                                             # ③
		_aim_vel = -_aim_vel
	_aim_target = _rng.randf_range(AIM_TARGET_MIN, AIM_TARGET_MAX)     # ④
	_snap_pos = _rng.randf_range(0.0, 1.0)                             # ⑤
	_snap_vel = _rng.randf_range(SNAP_SPEED_MIN, SNAP_SPEED_MAX)       # ⑥
	if _rng.randf() < 0.5:                                             # ⑦
		_snap_vel = -_snap_vel
	_snap_target = _rng.randf_range(SNAP_TARGET_MIN, SNAP_TARGET_MAX)  # ⑧
	return true

# 세션 취소(이동 입력 등). 종착 상태에서도 안전(멱등) — main이 세션 참조를 버리면 끝이다.
# ★ 취소는 **매출 0**이지 벌칙이 아니다(찍다 말았을 뿐 — 서빙 매출은 이미 받았다).
func cancel() -> void:
	state = State.IDLE

# 아직 굴러가는 세션인가(main의 tick·HUD 게이트).
func is_active() -> bool:
	return state == State.AIM or state == State.SNAP

# 결착이 났나 — main이 이 프레임에 결과를 수확하고 세션을 버린다.
func is_finished() -> bool:
	return state == State.DONE

# ★ 한 프레임 진행. pressed = 지금 셔터 버튼을 누르고 있는가(홀드 상태 그대로 넘겨라 — edge는
#   세션이 잰다). 결정적이라 테스트가 같은 delta·입력열을 먹이면 같은 결과가 나온다.
#   종착 상태에서는 무동작(멱등).
func tick(delta: float, pressed: bool) -> void:
	if not is_active():
		_was_pressed = pressed
		return
	elapsed += delta
	_phase_t += delta
	# 준비 구간 동안의 입력은 없던 것으로 흘려보낸다(단, 홀드 상태는 계속 추적해 구간이 끝난 뒤
	# *새로* 누를 때만 먹히게 한다 — 서빙 버튼을 붙잡고 있어도 그 홀드가 셔터가 되지 않는다).
	var fired := pressed and not _was_pressed and elapsed >= ARM_SECS
	_was_pressed = pressed
	match state:
		State.AIM:
			_tick_aim(delta, fired)
		State.SNAP:
			_tick_snap(delta, fired)

# 구도 단계: 표류하는 프레임을 목표에 겹쳤을 때 누른다. 제한 시간이 지나면 지금 자리로 자동 확정.
func _tick_aim(delta: float, fired: bool) -> void:
	_aim_pos = _drift(_aim_pos, delta)
	if fired:
		_lock_aim(false)
	elif _phase_t >= AIM_SECS:
		_lock_aim(true)

func _lock_aim(timed_out: bool) -> void:
	aim_score = _proximity(_aim_pos, _aim_target, AIM_TOL)
	aim_timeout = timed_out
	state = State.SNAP
	_phase_t = 0.0

# 셔터 단계: 왕복하는 커서가 스윗존에 들어왔을 때 누른다. 제한 시간이 지나면 자동 촬영.
func _tick_snap(delta: float, fired: bool) -> void:
	_snap_pos = _drift(_snap_pos, delta)
	if fired:
		_lock_snap(false)
	elif _phase_t >= SNAP_SECS:
		_lock_snap(true)

func _lock_snap(timed_out: bool) -> void:
	timing_score = _proximity(_snap_pos, _snap_target, SNAP_TOL)
	snap_timeout = timed_out
	state = State.DONE

# 트랙 0~1을 왕복(경계 반사). 두 단계가 같은 운동을 쓴다 — 속도만 다르다.
# ★ 상태 변수 둘(pos·vel)을 함께 굴려야 해서 _aim_/_snap_ 접두사로 나눠 두고 여기선 pos만 받는다.
func _drift(pos: float, delta: float) -> float:
	var vel := _aim_vel if state == State.AIM else _snap_vel
	var p := pos + vel * delta
	# while: delta가 크면 한 프레임에 두 번 튈 수 있다(헤드리스가 굵은 step을 먹일 때의 방어).
	while p < 0.0 or p > 1.0:
		if p < 0.0:
			p = -p
			vel = -vel
		else:
			p = 2.0 - p
			vel = -vel
	if state == State.AIM:
		_aim_vel = vel
	else:
		_snap_vel = vel
	return p

# 근접도 → 0~1 점수. 목표에 정확히 겹치면 1, tol만큼 벗어나면 0(그 밖은 0으로 클램프).
# ★ **0점도 실패가 아니다** — 등급 사다리의 바닥(OK)일 뿐이고 매출은 그래도 붙는다.
static func _proximity(pos: float, target: float, tol: float) -> float:
	if tol <= 0.0:
		return 0.0
	return clampf(1.0 - absf(pos - target) / tol, 0.0, 1.0)

# ── 조회(HUD·main·테스트 — 폴링 전용, 시그널 없음) ────────────────────────────
func aim_pos() -> float:
	return _aim_pos

func aim_target() -> float:
	return _aim_target

func snap_pos() -> float:
	return _snap_pos

func snap_target() -> float:
	return _snap_target

# 이 단계의 스윗존 반폭(HUD가 목표대의 *너비*를 그린다 — 넓이가 곧 관대함의 시각적 약속).
func tolerance() -> float:
	return AIM_TOL if state == State.AIM else SNAP_TOL

# 현재 단계의 남은 시간 비율(1 = 방금 시작 · 0 = 자동 확정 직전). HUD 모래시계.
func phase_left_ratio() -> float:
	var span := AIM_SECS if state == State.AIM else SNAP_SECS
	return clampf(1.0 - _phase_t / span, 0.0, 1.0) if span > 0.0 else 0.0

# 지금 커서가 스윗존 안인가(HUD 강조 — "지금 눌러라"의 유일한 신호).
func in_sweet_zone() -> bool:
	if state == State.AIM:
		return absf(_aim_pos - _aim_target) <= AIM_TOL
	if state == State.SNAP:
		return absf(_snap_pos - _snap_target) <= SNAP_TOL
	return false

# 종합 점수 0~1 = 구도·타이밍 **평균**(두 단의 무게가 같다 — 어느 한쪽만 잘해선 최고가 안 된다).
func score() -> float:
	return clampf((aim_score + timing_score) * 0.5, 0.0, 1.0)

# ★ 점수 → 등급(순수 static). 세션 밖에서도 부를 수 있어야 한다 — main이 result()의 원자료로
#   등급을 얻고, 테스트는 세션 없이 문턱만 따로 검증한다(fishing의 FishCatalog.quality_for 자리).
static func grade_for(total: float) -> int:
	if total >= GRADE_PERFECT:
		return Grade.PERFECT
	if total >= GRADE_GOOD:
		return Grade.GOOD
	return Grade.OK

# 등급 한글 표시명(알림·HUD — 그레이박스 판독성 우선).
static func grade_name(grade: int) -> String:
	match grade:
		Grade.PERFECT: return "인생샷"
		Grade.GOOD: return "잘 나온 컷"
		_: return "한 컷"

# ★ 결과 계약(main·테스트가 소비하는 유일한 산출물). **등급은 안 담는다** — 원자료(점수)만 넘기고
#   해석은 grade_for가 한다(fishing.result()가 perfect_count만 넘기는 그 원칙 1:1).
func result() -> Dictionary:
	return {
		"aim_score": aim_score,
		"timing_score": timing_score,
		"score": score(),
		"elapsed": elapsed,
		"aim_timeout": aim_timeout,
		"snap_timeout": snap_timeout,
	}

# 상태 한글 표시명(HUD·디버그).
func state_label() -> String:
	match state:
		State.AIM: return "구도 잡는 중"
		State.SNAP: return "셔터 타이밍"
		State.DONE: return "촬영 완료"
		_: return "대기"
