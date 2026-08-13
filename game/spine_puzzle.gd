extends RefCounted
class_name SpineReconstruction
# ★[S9b-T7 / ADR-0068 결정 8] B5 재구성 = **파편을 자기 공허에 잇는 최소 능동 메카닉**의
# 순수 상태 머신. [narrative-bible §6.5] 3단("봉인의 법칙 메카닉화")의 이행이다.
#
# 왜 능동인가: §2.2 봉인의 법칙 — *봉인은 본인이 스스로 닿아야 풀린다.* 자동 몽타주는 이 법칙의
#   정면 위반이라 §6.5가 명시적으로 기각했다. 그래서 마지막 선은 **플레이어 손가락이** 잇는다.
#
# 설계 메모(FishingSession·CutsceneRunner 규범 4번째 — 이 코드베이스의 확립 관례):
#   - **Node 아님·렌더 무의존**(RefCounted). 씬 트리에 안 붙고 _process도 없다 — main이 매
#     프레임 tick()으로 굴리고 **화면은 main이 이 객체의 상태를 읽어 그린다**(로직/렌더 분리).
#     그래서 테스트가 씬 없이 new()로 전 시나리오를 결정적으로 돌린다.
#   - **벽시계 무의존**(Time.* 금지). ★특히 강림 안전장치의 무입력 판정이 **초가 아니라 tick 수**다:
#     초로 재면 프레임 레이트가 판정에 새어 들어와 같은 입력 열이 다른 전이를 낳는다.
#   - **RNG = 시드 주입**. 같은 시드 + 같은 입력 열 = 같은 `trace()`. 결정성 판정의 눈금이다.
#   - **서사를 모른다.** 파편이 누구의 것인지·무슨 뜻인지 몰라 인덱스와 개수만 다룬다
#     (FishingSession이 어종을 모르고 CutsceneRunner가 캐릭터를 모르는 그 분업). 파편 표와
#     지문의 주인은 `spine.gd`이고, 여기는 "몇 개를 어떤 순서로 이어야 하나"만 안다.
#   - **세이브 무상태**. 한 번의 B5 동안만 살아 있고 결과는 척추 비트 한 칸(main `_spine_bits`)으로
#     남는다 — 중간 저장이 없는 이유는 이 장면이 한 자리에서 끝나기 때문이다(무실패라 이탈 유인도 0).
#
# ── ★ 무실패 계약([narrative-bible §6.5] 4 · 지시서 ⑥) ──────────────────────────
#   · 오답 페널티 0 · 타임아웃 0 · 실패 상태 자체가 **없다**(State에 FAILED가 없는 것이 그 구현).
#   · 틀린 연결은 *조용히 안 이어질 뿐*이다 — 소리도 감점도 되돌림도 없다.
#   · 그래서 이 장면은 **난도가 아니라 의식(儀式)**이다. 막히는 사람을 위한 것이 강림 안전장치다.

enum State { IDLE, ACTIVE, DONE }

# 강림 안전장치가 서기까지의 무입력 tick 수(≈60fps 기준 4초). 첫 지시가 이르면 퍼즐이 자기
# 자신을 대신 풀어 주는 꼴이 되고, 늦으면 소프트락 방지책이 아니게 된다 — 그 사이의 잠정값.
const HINT_IDLE_TICKS := 240
# 지시가 이미 서 있는데도 계속 무입력일 때, 다음 지문까지의 tick 수(같은 지문 반복 금지).
const HINT_REPEAT_TICKS := 300

var state: int = State.IDLE
var cursor: int = 0             # 지금 겨눈 파편 인덱스(허브는 절대 안 겨눈다 — 아래 _first_pick)

var _count := 0                 # 파편 총수(허브 포함)
var _hub := 0                   # 허브(= 자기 공허) 인덱스 — 나머지 전부가 여기로 모인다
var _order: PackedInt32Array = PackedInt32Array()   # 이어야 할 순서(시드 파생 셔플)
var _linked: PackedInt32Array = PackedInt32Array()  # 이어진 파편(순서대로)
var _idle := 0                  # 마지막 입력 이후 tick 수(벽시계 아님)
var _hint_on := false           # 강림 지시가 서 있나
var _hint_n := 0                # 지금까지 선 지시의 수(지문 순환 축 — spine.hint_line의 인자)
var _wrong := 0                 # 빗나간 시도 수(기록만 — 무실패라 아무 데도 안 쓰인다)
var _trace: PackedStringArray = PackedStringArray()

# count = 파편 총수(허브 포함) · hub = 허브 인덱스. 순서는 여기서 **한 번에** 정한다 —
# 진행 중에 뽑으면 "언제 뽑았나"가 결정성에 섞인다(CutsceneRunner가 _init에서 파싱을 끝내는 결).
func _init(rng_seed: int, count: int, hub: int = 0) -> void:
	_count = maxi(count, 0)
	_hub = clampi(hub, 0, maxi(_count - 1, 0))
	var rest: Array[int] = []
	for i in _count:
		if i != _hub:
			rest.append(i)
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	# Fisher–Yates — Array.shuffle()은 전역 RNG를 타서 시드 주입이 안 먹는다(결정성 구멍).
	for i in range(rest.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t := rest[i]
		rest[i] = rest[j]
		rest[j] = t
	_order = PackedInt32Array(rest)
	cursor = _first_pick()

# 허브가 아닌 첫 인덱스(커서의 출발점). 허브만 있는 판이면 허브를 겨눈다(방어).
func _first_pick() -> int:
	for i in _count:
		if i != _hub:
			return i
	return _hub

func start() -> bool:
	if _count <= 1 or state != State.IDLE:
		return false               # 이을 것이 없는 판은 시작하지 않는다(빈 컷신 거절과 같은 결)
	state = State.ACTIVE
	_trace.append("start:%d:%d:%d" % [_count, _hub, _order.size()])
	_trace.append("cur:%d" % cursor)
	return true

func is_active() -> bool:
	return state == State.ACTIVE

func is_done() -> bool:
	return state == State.DONE

# ── 진행 ────────────────────────────────────────────────────────────────────
# 한 프레임 — main이 매 프레임 정확히 한 번 부른다. **delta를 안 받는다**(위 머리말: 무입력
# 판정이 초가 아니라 tick 수라야 결정적이다).
func tick() -> void:
	if state != State.ACTIVE:
		return
	_idle += 1
	if not _hint_on and _idle >= HINT_IDLE_TICKS:
		_arm_hint()
	elif _hint_on and _idle >= HINT_REPEAT_TICKS:
		_arm_hint()

func _arm_hint() -> void:
	_hint_on = true
	_hint_n += 1
	_idle = 0
	_trace.append("hint:%d:%d" % [next_index(), _hint_n])

# 입력이 들어오면 지시가 물러난다 — 플레이어가 스스로 움직이는 동안 곁에서 지켜보는 것이
# 이 안전장치의 예의다(§5.2 확증선: 대신 풀어 주는 것이 아니라 못 풀 때만 곁을 지킨다).
func _touch() -> void:
	_idle = 0
	_hint_on = false

# 커서 이동(±1 · 허브를 건너뛰며 순환). 방향키 넷은 main이 ±1로 접어 넘긴다.
func move_cursor(step: int) -> void:
	if state != State.ACTIVE or _count <= 1 or step == 0:
		return
	var dir := 1 if step > 0 else -1
	var i := cursor
	for _n in _count:
		i = posmod(i + dir, _count)
		if i != _hub:
			break
	cursor = i
	_touch()
	_trace.append("cur:%d" % cursor)

# 지금 이어야 할 파편(= 정답). 다 이었으면 −1.
func next_index() -> int:
	if _linked.size() >= _order.size():
		return -1
	return int(_order[_linked.size()])

# 이 파편을 공허에 잇는다. 성공 = true.
# ★ **무실패**: 틀리면 false를 돌려줄 뿐 상태가 하나도 안 상한다(감점·되돌림·종료 전부 없다).
#   그리고 빗나간 시도는 **무입력 카운터를 되돌리지 않는다** — 헤매는 사람에게서 안전장치를
#   빼앗지 않으려는 의도적 비대칭이다(성공·커서 이동만 지시를 물린다).
func link(index: int) -> bool:
	if state != State.ACTIVE:
		return false
	if index != next_index():
		_wrong += 1
		_trace.append("miss:%d" % index)
		return false
	_linked.append(index)
	_touch()
	_trace.append("link:%d:%d" % [index, _linked.size()])
	if _linked.size() >= _order.size():
		state = State.DONE
		_trace.append("done")
	return true

# 커서가 겨눈 파편을 잇는다([Enter]·좌클릭의 공통 창구).
func confirm() -> bool:
	return link(cursor)

# ── 조회(main·테스트가 읽는다 — 시그널 없음, FishingSession 결) ────────────────
func is_linked(index: int) -> bool:
	return _linked.has(index)

func linked_count() -> int:
	return _linked.size()

func need_count() -> int:
	return _order.size()

func hub_index() -> int:
	return _hub

func count() -> int:
	return _count

# 강림 지시가 서 있으면 그 파편 인덱스, 아니면 −1(main이 이 값으로 테를 두르고 지문을 낸다).
func hint_index() -> int:
	return next_index() if _hint_on and state == State.ACTIVE else -1

# 지금까지 선 지시의 수 — main이 `Spine.hint_line(n-1)`로 지문을 고른다(결정적 순환).
func hint_count() -> int:
	return _hint_n

func wrong_count() -> int:
	return _wrong

func idle_ticks() -> int:
	return _idle

# 전이열 — "같은 시드 + 같은 입력 열 = 같은 문자열"이 결정성의 눈금이다(CutsceneRunner 결).
func trace() -> PackedStringArray:
	return _trace.duplicate()

func trace_text() -> String:
	return "|".join(_trace)
