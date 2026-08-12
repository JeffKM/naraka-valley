extends RefCounted
class_name CutsceneRunner
# ★[S9-T2 / ADR-0067 결정 2] 최소 컷신 러너 = **연출 등급 2**(인게임 스크립트 이벤트).
#
# 목적: 서사 바이블 §6.5 3등급제 중 등급 2를 연다. 등급 1(대화박스)은 dialogue.gd가 이미
#       맡고, 등급 S(풀 컷신 원화)는 척추와 함께 S9b다. 그 사이의 "NPC가 걸어 들어오고 화면이
#       어두워지며 시계가 멈추는" 인게임 연출만 여기가 담당한다.
#
# ★ 능력은 **정확히 4동사로 잠근다**(ADR-0067 결정 2 — 이 잠금이 이 파일의 존재 이유다):
#     ① npc   — NPC 스폰/이동   ② cam  — 카메라 팬
#     ③ fade  — 페이드 인/아웃  ④ clock — 시계 정지/재개
#   파티클 스크립트·연출 타임라인 편집기·사운드 큐·대사 삽입은 **만들지 않는다**. 스타듀 하트
#   이벤트도 이 네 동사로 대부분이 성립하고, 다섯 번째 동사를 여는 순간 이 파일은 미니 엔진이
#   되어 슬라이스를 삼킨다. 미지 동사는 무시하지 않고 **거절 기록 후 스킵**한다(아래 _init).
#
# 설계 메모(fishing.gd FishingSession 규범 그대로 — 이 코드베이스의 확립 관례):
#   - **Node 아님·렌더 무의존**(RefCounted). 씬 트리에 안 붙고 _process도 없다 — main이 매 프레임
#     advance(delta)로 굴리고, **화면 효과는 main이 이 객체의 상태를 읽어 적용**한다(로직/렌더 분리).
#     그래서 테스트가 씬 없이 new()로 전 시나리오를 결정적으로 돌린다.
#   - **벽시계 무의존**(Time.* 금지·RNG 0). 같은 스텝 배열 + 같은 delta 열 = 같은 전이열이다.
#     그 전이열을 trace()로 노출해 "결정적인가"를 테스트가 문자열 비교 한 번으로 잰다.
#   - **컷신 데이터는 캐릭터 파일이 소유한다**(ADR-0005 "서사 텍스트는 캐릭터에만"). 이 클래스는
#     스텝 배열을 받아 재생할 뿐 어떤 캐릭터도, 어떤 장면도 모른다 — 캐릭터 한 명 추가가 곧 파일
#     하나 추가가 되어 S9b 점진이 값싸진다. T2는 러너와 이음매만 만들고 데이터는 넣지 않는다.
#   - **단위를 모른다**: NPC 자리는 **타일 좌표(실수)**로 다루고 px 환산은 main이 한다(TILE 상수는
#     main의 것이다). 카메라 팬 오프셋만 픽셀인데, 그건 Camera2D.offset의 단위라 어쩔 수 없다.
#   - **세이브 무상태**(FishingSession·night_bar와 일관): 컷신은 재생 중 한 순간만 살아 있고 저장
#     대상이 아니다. ★특히 "시계 정지"가 세이브에 새 키를 남기면 안 된다 — 정지는 main이 재생 전
#     시계 상태를 스냅해 두고 끝나면 되돌리는 것으로 끝난다(main._end_cutscene).
#
# ── 스텝 데이터 포맷 ────────────────────────────────────────────────────────
# Array[Dictionary]. 각 항목은 "verb" 하나 + 그 동사의 인자, 그리고 공통 인자 "secs"(연출 길이).
# secs 생략·0 이하 = 즉시(한 프레임에 소비). 스텝은 **순차**로만 흐른다(동시 재생 없음 — 병렬을
# 열면 그게 곧 타임라인 편집기다).
#
#   {"verb": "npc",   "id": "miho", "tile": Vector2i(12, 8), "secs": 0.0}   # 스폰(즉시 등장)
#   {"verb": "npc",   "id": "miho", "tile": Vector2i(12, 5), "secs": 1.2}   # 그 자리로 걸어감(보간)
#   {"verb": "npc",   "id": "miho", "tile": Vector2i(12, 5), "visible": false}  # 퇴장(이동 후 사라짐)
#   {"verb": "cam",   "offset": Vector2(0, -48), "secs": 0.8}               # 카메라 팬(px 오프셋)
#   {"verb": "fade",  "to": 1.0, "secs": 0.4}                               # 암전(0.0 = 밝아짐)
#   {"verb": "clock", "running": false}                                     # 시계 정지(즉시)

enum State { IDLE, PLAYING, DONE }

# ★ 허용 동사 4개 — 이 배열에 다섯 번째를 더하는 변경은 ADR-0067 결정 2의 개정을 요구한다.
const VERB_NPC := "npc"
const VERB_CAM := "cam"
const VERB_FADE := "fade"
const VERB_CLOCK := "clock"
const VERBS := [VERB_NPC, VERB_CAM, VERB_FADE, VERB_CLOCK]

# 전이 기록의 실수 자릿수 — trace를 float 잡음(1e-7 오차)에서 떼어 놓아 두 번의 재생이
# 문자열로 같아지게 한다(결정성 판정의 눈금).
const TRACE_DIGITS := 2

# ── 상태(읽기 전용으로 다뤄라 — 변경은 start/advance/cancel만) ───────────────
var state: int = State.IDLE
var elapsed: float = 0.0        # 재생 시작부터의 누적 초(순수 누적 — 벽시계 아님)

# 화면 효과 상태(main이 폴링해 적용한다 — 시그널 없음, FishingSession 결).
var fade: float = 0.0           # 0.0 = 투명(평소) … 1.0 = 완전 암전
var camera: Vector2 = Vector2.ZERO   # 카메라 팬 오프셋(px — Camera2D.offset 단위)
var clock_on: bool = true       # 이 컷신이 게임 시계를 흐르게 두는가(false = 정지 요청)

var _steps: Array = []          # 정규화된 스텝(미지 동사는 여기 안 들어온다)
var _i: int = -1                # 지금 재생 중인 스텝 인덱스(-1 = 아직 시작 안 함)
var _step_t: float = 0.0        # 현재 스텝에 머문 시간(초)
var _npc: Dictionary = {}       # id → {"tile": Vector2(실수 타일 좌표), "visible": bool} — **등장한 것만**
# ★ 이 컷신이 등장시킬 NPC id 전량(스텝 데이터에서 _init이 미리 뽑는다 — 등장 *전*에도 알 수 있다).
#   _npc(런타임 등록)와 나누는 이유: main은 재생을 시작하기 전에 "누구의 그림을 건드릴 것인가"를
#   알아야 원상태를 스냅해 둘 수 있는데, 런타임 등록은 그 NPC의 스텝이 시작돼야 채워진다.
var _cast: PackedStringArray = PackedStringArray()
var _rejected: PackedStringArray = PackedStringArray()   # 거절된 미지 동사(입력 순서대로)
var _trace: PackedStringArray = PackedStringArray()      # 전이열(결정성 판정용)

# 스텝 시작 순간의 값(보간의 출발점) — 스텝마다 _begin_step이 새로 잡는다.
var _from_tile := Vector2.ZERO
var _from_cam := Vector2.ZERO
var _from_fade := 0.0

# 스텝 배열을 받아 **즉시 정규화**한다(재생 중 파싱 0 — 미지 동사 판정이 재생 타이밍에 좌우되면
# 결정성이 깨진다). 미지 동사·비-딕셔너리 항목은 조용히 무시하지 않고 _rejected에 남기고 스킵한다:
# 무시하면 "왜 그 장면이 안 나왔지"가 영원히 안 잡히고, 예외를 던지면 캐릭터 파일 오타 하나가
# 게임을 세운다. 거절은 기록되고 나머지 스텝은 그대로 재생된다.
func _init(steps: Array = []) -> void:
	for k in steps.size():
		var raw = steps[k]
		if typeof(raw) != TYPE_DICTIONARY:
			_reject("<%s>" % type_string(typeof(raw)), k)
			continue
		var s: Dictionary = raw
		var verb := String(s.get("verb", ""))
		if not VERBS.has(verb):
			_reject(verb, k)
			continue
		var step := _normalized(verb, s)
		_steps.append(step)
		if verb == VERB_NPC:
			var id := String(step["id"])
			if id != "" and not _cast.has(id):
				_cast.append(id)   # 등장 순서대로(중복 없음) — main의 원상태 스냅 목록

func _reject(verb: String, at: int) -> void:
	_rejected.append(verb)
	_trace.append("reject:%d:%s" % [at, verb])

# 스텝 1건을 재생기가 쓰는 고정 스키마로 편다(기본값 채움·타입 통일·음수 secs 방어).
# 원본 dict는 건드리지 않는다 — 캐릭터 파일의 const 배열을 오염시키지 않기 위함이다.
func _normalized(verb: String, s: Dictionary) -> Dictionary:
	var out := {"verb": verb, "secs": maxf(float(s.get("secs", 0.0)), 0.0)}
	match verb:
		VERB_NPC:
			out["id"] = String(s.get("id", ""))
			out["tile"] = Vector2(s.get("tile", Vector2.ZERO))
			out["visible"] = bool(s.get("visible", true))
		VERB_CAM:
			out["offset"] = Vector2(s.get("offset", Vector2.ZERO))
		VERB_FADE:
			out["to"] = clampf(float(s.get("to", 0.0)), 0.0, 1.0)
		VERB_CLOCK:
			out["running"] = bool(s.get("running", false))   # 기본은 정지(이 동사를 쓰는 이유)
	return out

# ── 진행 API ────────────────────────────────────────────────────────────────
# 재생 시작. 유효 스텝이 하나도 없으면 시작하지 않고 false를 돌려준다 — main은 이 값을 보고
# **평소 대화로 되돌아간다**(훅이 빈 데이터를 주면 컷신 없는 현행 거동. 하위호환의 뿌리).
func start() -> bool:
	if state != State.IDLE or _steps.is_empty():
		return false
	state = State.PLAYING
	elapsed = 0.0
	_i = 0
	_begin_step(_steps[0])
	return true

# 재생 취소(중단). 화면 효과 원복은 main 몫이다 — 이 객체는 "끝났다"만 말한다(멱등).
func cancel() -> void:
	if state == State.PLAYING:
		_trace.append("cancel:%d" % _i)
	state = State.DONE

func is_playing() -> bool:
	return state == State.PLAYING

func is_done() -> bool:
	return state == State.DONE

# ★ 한 프레임 진행. 결정적이라 같은 스텝 배열에 같은 delta 열을 먹이면 같은 전이열이 나온다.
# 한 프레임에 여러 스텝이 끝날 수 있다(즉시 스텝 연쇄·긴 delta) — 남은 예산을 순서대로 소비한다.
# 종착(DONE)·미시작(IDLE)에서는 무동작(멱등 — main이 참조를 버릴 때까지 안전).
func advance(delta: float) -> void:
	if state != State.PLAYING:
		return
	var budget := maxf(delta, 0.0)
	elapsed += budget
	# 가드 = 스텝 수 + 2. 한 프레임이 전 스텝을 통째로 삼켜도 충분하고, 어떤 입력에도 무한 루프가
	# 안 난다(즉시 스텝만으로 이뤄진 컷신도 여기서 한 번에 끝난다).
	var guard := _steps.size() + 2
	while state == State.PLAYING and guard > 0:
		guard -= 1
		var s: Dictionary = _steps[_i]
		var dur := float(s["secs"])
		var room := dur - _step_t
		if budget < room:
			# 이 스텝 안에서 프레임이 끝난다 — 진행률만 갱신하고 나간다.
			_step_t += budget
			_apply(s, _step_t / dur if dur > 0.0 else 1.0)
			return
		# 이 스텝은 이 프레임에 끝난다 — 끝값을 정확히 찍고 다음으로.
		budget -= maxf(room, 0.0)
		_apply(s, 1.0)
		_finish_step(s)
		_i += 1
		if _i >= _steps.size():
			state = State.DONE
			_trace.append("end")
			return
		_begin_step(_steps[_i])
		if budget <= 0.0 and float(_steps[_i]["secs"]) > 0.0:
			return   # 예산 소진 + 다음 스텝은 시간이 걸린다 = 여기서 프레임을 끝낸다

# 스텝 시작 — 보간의 출발점을 잡고, 즉시 확정되는 것(등장·시계)을 여기서 적용한다.
func _begin_step(s: Dictionary) -> void:
	_step_t = 0.0
	var verb := String(s["verb"])
	_trace.append("begin:%d:%s" % [_i, verb])
	match verb:
		VERB_NPC:
			var id := String(s["id"])
			var to: Vector2 = s["tile"]
			# 아직 등장하지 않은 NPC면 **그 자리에 스폰**한다(출발점 = 도착점 = 보간 없음).
			# 이미 있는 NPC면 지금 자리에서 목적지로 보간한다 = 같은 동사가 스폰과 이동을 겸한다.
			if not _npc.has(id):
				_npc[id] = {"tile": to, "visible": bool(s["visible"])}
			_from_tile = Vector2(_npc[id]["tile"])
			# ★ 가시성 타이밍: 등장(true)은 **시작 즉시**, 퇴장(false)은 **이동을 마친 뒤**(_finish_step).
			#   그래야 "걸어 들어온다"와 "걸어 나가 사라진다"가 둘 다 자연스럽다.
			if bool(s["visible"]):
				_npc[id]["visible"] = true
		VERB_CAM:
			_from_cam = camera
		VERB_FADE:
			_from_fade = fade
		VERB_CLOCK:
			clock_on = bool(s["running"])   # 즉시 동사(길이 무의미 — secs를 줘도 그냥 대기가 된다)

# 스텝 진행률 t(0..1) 적용 — 보간 동사만 여기서 값이 움직인다.
func _apply(s: Dictionary, t: float) -> void:
	var k := clampf(t, 0.0, 1.0)
	match String(s["verb"]):
		VERB_NPC:
			var id := String(s["id"])
			if _npc.has(id):
				_npc[id]["tile"] = _from_tile.lerp(Vector2(s["tile"]), k)
		VERB_CAM:
			camera = _from_cam.lerp(Vector2(s["offset"]), k)
		VERB_FADE:
			fade = lerpf(_from_fade, float(s["to"]), k)

# 스텝 종료 — 퇴장(visible=false)이 여기서 확정되고, 전이열에 끝값 스냅샷을 남긴다.
func _finish_step(s: Dictionary) -> void:
	var verb := String(s["verb"])
	var tail := ""
	match verb:
		VERB_NPC:
			var id := String(s["id"])
			if _npc.has(id) and not bool(s["visible"]):
				_npc[id]["visible"] = false
			var p := Vector2(_npc[id]["tile"]) if _npc.has(id) else Vector2.ZERO
			tail = "%s@%s,%s,%s" % [id, _r(p.x), _r(p.y), "1" if npc_visible(id) else "0"]
		VERB_CAM:
			tail = "%s,%s" % [_r(camera.x), _r(camera.y)]
		VERB_FADE:
			tail = _r(fade)
		VERB_CLOCK:
			tail = "1" if clock_on else "0"
	_trace.append("end:%d:%s:%s" % [_i, verb, tail])

# 전이열용 실수 표기(자릿수 고정 — 부동소수 잡음 제거).
func _r(v: float) -> String:
	return String.num(v, TRACE_DIGITS)

# ── 조회(main·HUD·테스트 — 폴링 전용, 시그널 없음) ────────────────────────────
func fade_alpha() -> float:
	return clampf(fade, 0.0, 1.0)

func camera_offset() -> Vector2:
	return camera

# 이 컷신이 게임 시계를 흐르게 두는가(false = 정지 요청 — main이 clock.running에 반영).
func clock_running() -> bool:
	return clock_on

# **지금까지 등장한** NPC id 목록. main의 매 프레임 적용 루프가 쓴다 — 아직 스폰 전인 NPC까지
# 여기 실리면 main이 그 그림을 (0,0)으로 끌고 가 버린다.
func npc_ids() -> PackedStringArray:
	var out := PackedStringArray()
	for id in _npc:
		out.append(String(id))
	return out

# ★ 이 컷신이 손댈 NPC id **전량**(스텝 데이터 파생 — 등장 전에도 안다). main이 재생 **전**
# 원상태를 스냅하고 재생 후 되돌리는 목록이다. 스냅을 npc_ids()로 뜨면 첫 스텝이 페이드인 컷신에서
# 목록이 비어 아무것도 복원되지 않는다(실증된 사고 — cutscene_test ④j가 그 회귀 가드).
func cast_ids() -> PackedStringArray:
	return _cast.duplicate()

# 그 NPC의 지금 자리(실수 타일 좌표 — px 환산은 main). 등장 전이면 원점.
func npc_tile(id: String) -> Vector2:
	return Vector2(_npc[id]["tile"]) if _npc.has(id) else Vector2.ZERO

func npc_visible(id: String) -> bool:
	return bool(_npc[id]["visible"]) if _npc.has(id) else false

# 재생 대상 스텝 수(거절분 제외).
func step_count() -> int:
	return _steps.size()

# 거절된 미지 동사 목록(입력 순서). 빈 배열 = 스텝 전량이 4동사 안이었다.
func rejected_verbs() -> PackedStringArray:
	return _rejected.duplicate()

# ★ 전이열 — 이 러너의 결정성 계약. 같은 스텝 배열 + 같은 delta 열이면 두 번의 재생이 이 배열까지
#   똑같다(테스트가 문자열 비교로 잰다). 거절·시작·끝값·종료가 전부 여기 실린다.
func trace() -> PackedStringArray:
	return _trace.duplicate()

# 상태 한글 표시명(디버그 — 그레이박스 판독성 우선, FishingSession.state_label 결).
func state_label() -> String:
	match state:
		State.PLAYING: return "재생 중"
		State.DONE: return "종료"
		_: return "대기"
