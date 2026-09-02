extends RefCounted
class_name FishingSession
# ★[S3-T2 / ADR-0061 결정 2·6] 릴 격투 = 입력·렌더와 분리된 순수 상태 머신(데이브식, ADR-0030 결정 2).
#
# 목적: ROADMAP Slice 3 — "캐스팅→입질→당김/풀기 텐션 줄다리기"를 *헤드리스에서 전부 재현 가능한*
#       순수 로직으로 만든다. 이 파일은 이 코드베이스의 **첫 미니게임**이라, 후속 미니게임(체키·
#       칵테일·전투 QTE)의 구조 선례로 박제된다(ADR-0061 대안 검토 "main.gd 인라인 구현" 기각).
#
# 설계 메모(어기면 ADR-0061 결정 2 위반):
#   - **Node 아님·렌더 무의존**(RefCounted). 씬 트리에 안 붙고 _process도 없다 — main이 매 프레임
#     tick(delta, reeling)로 굴린다(night_bar.tick(delta, minutes)와 같은 결이되, 노드조차 아니다).
#     시그널도 없다(순수 클래스 — 폴링 조회 API로 읽는다). 그래서 테스트가 씬 없이 new()로 전 시나리오를
#     0.05초 단위로 결정적으로 돌린다.
#   - **RNG = 시드 주입**(rng_seed). 같은 시드 + 같은 입력열 = 같은 결과(결정성 = 헤드리스 게이트의 전제).
#     RandomNumberGenerator는 RefCounted라 순수성이 안 깨진다.
#   - **혼력을 모른다**(energy.gd 디커플링 — field.gd가 Foxfire를 모르는 그 패턴). 후킹 순간의 혼력
#     소모·차단은 main이 주입하는 `hook_gate: Callable`(→ bool)이 결정한다. 이 클래스는 "게이트가
#     거절하면 입질을 놓쳤다"만 안다(ADR-0061 결정 6 "혼력 부족 시 후킹 불가").
#   - **어종 데이터를 모른다**(S3-T3 fish_catalog 디커플링). 물고기 파라미터는 dict로 *주입*되고,
#     지금은 체급별 그레이박스 프리셋 4종(CLASS_PRESETS)이 그 자리를 채운다. fish_catalog가 생기면
#     같은 스키마 dict를 넘길 뿐 이 파일은 안 바뀐다.
#   - **스킬·기어 보정은 중립 훅으로만**(S3-T6 낚시 스킬 소관 · ★S3-T4 기어는 실효). mods의 네 계수는
#     기본값이 정확히 중립(1.0 / 0.0)이라 **맨몸 T1도 base 그대로 굴러간다**(ADR-0008 "평평 ≠ 막힘"의
#     순수 쇼케이스 — 낚시는 관계 곱셈기가 0인 유일 루프, ADR-0030 결정 1). 기어는 그 위에 얹히는
#     가속일 뿐이고, 이 파일은 여전히 **기어 카탈로그를 모른다**(GearCatalog가 dict를 만들어 준다).
#   - **세이브 무상태**(cafe.gd·night_bar.gd와 일관): 세션은 한 캐스팅 동안만 살아 있고 취침·저장 대상이
#     아니다. 저장되는 건 하류 산출물(인벤토리 어획물·혼력)뿐이다.
#   - 품질 등급은 여기서 정하지 않는다 — `perfect_count`만 노출하면 등급 매핑은 S3-T3(어종 카탈로그)이
#     한다("품질 = 퍼펙트 릴", 카탈로그 §1-D 이행). 이 파일이 등급을 알면 어종 데이터와 결합된다.

# ── 상태 머신(ADR-0061 결정 2) ───────────────────────────────────────────────
# IDLE → CASTING → WAITING(입질 대기·혼력 0) → BITE(입질 창) → FIGHT → LANDED / ESCAPED.
# LANDED·ESCAPED는 종착역(더 진행 안 함) — main이 result()를 읽고 세션을 버린다.
enum State { IDLE, CASTING, WAITING, BITE, FIGHT, LANDED, ESCAPED }

# 체급(ADR-0061 결정 3 스키마의 `체급` 축). 낚싯대 max_class와 같은 눈금 = 체급 게이트의 축.
enum WeightClass { SMALL, MEDIUM, LARGE, LEGEND }

# ── 공통 타이밍 상수(그레이박스 — 스펙카드로 잠금, ADR-0028) ──────────────────
const CAST_SECS := 0.4          # 캐스팅 모션 길이(찌가 물에 떨어지기까지)
const WAIT_MIN := 1.0           # 입질 대기 하한(초) — 시드 파생 균등분포
const WAIT_MAX := 4.0           # 입질 대기 상한(초)
const BITE_WINDOW := 0.8        # 입질 창(초) — 이 안에 당기지 않으면 놓침(짧게, 데이브 결)
const TENSION_MAX := 100.0      # 줄 끊김 임계 — 도달 = ESCAPED(line_broke)
const PERFECT_WINDOW := 0.3     # 퍼펙트 릴 창(초) — 발버둥 시작 후 이 안에 '풀기'로 전환하면 크리
const PERFECT_STAMINA_CUT := 8.0  # 퍼펙트 릴 1회당 물고기 스태미나 추가 삭감(크리 보상)
const TELEGRAPH_SECS := 0.5     # 발버둥 예고(초) — 이 구간 동안 HUD가 느낌표를 띄운다(읽기 가능한 발버둥)
const CLASS_BREAK_SECS := 1.2   # 체급 게이트 끊김 연출 길이(초) — 짧은 FIGHT 뒤 확정 ESCAPED
const BURST_JITTER := 0.25      # 발버둥 주기 지터(±비율) — 시드 파생, 리듬 암기 방지

# ── 체급별 그레이박스 프리셋(★[S3-T3 fish_catalog로 교체] — 그때는 이 표가 어종 dict로 주입된다) ──
# 읽는 법: stamina = 물고기 체력(당기면 drain/초로 닳음) · tension_rise = 당기는 동안 텐션↑(초당) ·
#   tension_fall = 푸는 동안 텐션↓(초당) · burst_* = 발버둥 주기/길이 · burst_mult = 발버둥 중 텐션↑ 배수 ·
#   distance = 시작 거리(당기면 pull_rate/초 ↓, 풀면 slack_rate/초 ↑) · energy = 후킹 혼력(결정 6 실값).
# 밸런스 의도: **소(0)는 계속 당겨도 이긴다**(짧은 격투 = 노동 가벼움, ADR-0030 결정 2). **중 이상은
#   계속 당기면 스태미나가 마르기 *전에* 줄이 끊긴다**(풀기를 강제 = 줄다리기의 성립 조건).
#     소  : 스태미나 24/drain 14 = 1.71s 만에 포획 · 텐션 20/s → 그때 34(안전)
#     중  : 스태미나 42/drain 12 = 3.50s · 텐션 36/s → 2.78s에 끊김  ← 끊김이 이김
#     대  : 스태미나 70/drain 12 = 5.83s · 텐션 40/s → 2.50s에 끊김
#     전설: 스태미나 110/drain 12 = 9.17s · 텐션 44/s → 2.27s에 끊김(점증 릴 파이트 = 미니보스)
const CLASS_PRESETS := [
	{   # 0 소 — 입문 체급(T1 낚싯대 허용). 짧고 관대.
		"weight_class": WeightClass.SMALL, "stamina": 24.0, "stamina_drain": 14.0,
		"tension_rise": 20.0, "tension_fall": 30.0, "burst_period": 3.2, "burst_len": 0.9,
		"burst_mult": 2.4, "distance": 30.0, "pull_rate": 8.0, "slack_rate": 3.0, "energy": 4,
	},
	{   # 1 중 — 첫 진짜 줄다리기(풀기를 안 배우면 못 잡는다).
		"weight_class": WeightClass.MEDIUM, "stamina": 42.0, "stamina_drain": 12.0,
		"tension_rise": 36.0, "tension_fall": 30.0, "burst_period": 2.8, "burst_len": 1.1,
		"burst_mult": 2.8, "distance": 40.0, "pull_rate": 8.0, "slack_rate": 3.5, "energy": 8,
	},
	{   # 2 대 — 긴 격투(퍼펙트 릴 없이는 지루하게 길다 = 크리의 존재 이유).
		"weight_class": WeightClass.LARGE, "stamina": 70.0, "stamina_drain": 12.0,
		"tension_rise": 40.0, "tension_fall": 28.0, "burst_period": 2.4, "burst_len": 1.3,
		"burst_mult": 3.2, "distance": 50.0, "pull_rate": 7.0, "slack_rate": 4.0, "energy": 14,
	},
	{   # 3 전설 — 선택 프레스티지 미니보스(T4 전용, ADR-0030 딸린 결정).
		"weight_class": WeightClass.LEGEND, "stamina": 110.0, "stamina_drain": 12.0,
		"tension_rise": 44.0, "tension_fall": 26.0, "burst_period": 2.0, "burst_len": 1.6,
		"burst_mult": 3.6, "distance": 60.0, "pull_rate": 6.0, "slack_rate": 5.0, "energy": 30,
	},
]

# ── 낚싯대 기본값(T1 상당 — 미주입 시의 폴백) ────────────────────────────────
# max_class = 줄 강도(허용 체급 상한 — 초과 어종을 걸면 확정 끊김, ADR-0061 결정 2 "체급 게이트").
# tension_safe_bonus = 텐션 상승 감쇠 비율(0.0 = 중립).
# ★[S3-T4] 실제 값은 이제 GearCatalog.rod_params(rod_id, tackles)가 만든다(4티어 max_class 0~3 +
#   태클 '코르크 보버' 안전 여유). 이 상수는 그 dict의 **스키마 원본이자 T1 폴백**으로 남는다 —
#   FishingSession은 여전히 기어 카탈로그를 모른다(주입 dict 하나가 유일한 접점).
const ROD_T1 := {"max_class": WeightClass.SMALL, "tension_safe_bonus": 0.0}

# ── 주입 파라미터(생성자에서 확정 — 이후 불변) ────────────────────────────────
var fish: Dictionary = {}       # 물고기 파라미터(위 프리셋 스키마 — S3-T3이 어종 dict를 넘긴다)
var rod: Dictionary = {}        # 낚싯대 파라미터(ROD_T1 스키마)
# 스킬/기어 보정 훅 — **기본값이 정확히 중립**(S3-T4 기어 / S3-T6 낚시 스킬이 채운다).
#   energy_factor      : 후킹 혼력 배수(1.0 = 중립 · 스킬 절감이 낮춘다 — FarmSkill.energy_factor 문법 대칭)
#   perfect_window_add : 퍼펙트 릴 창 가산(초, 0.0 = 중립 · 스킬 레벨이 키운다)
#   burst_damp         : 발버둥 텐션 배수 감쇠(0.0 = 중립 · 태클 '납추'가 채운다 — ★S3-T4 실효)
#   wait_factor        : 입질 대기 배수(1.0 = 중립 · 미끼가 낮춘다 — ★S3-T4 실효). cast()에서 한 번만 먹는다.
#   weather_factor     : 입질 대기 배수(1.0 = 중립 · ★S7-T3 날씨). wait_factor와 **축이 다르다** —
#                        아래 cast()의 클램프 규율 참조(기어는 순이득만·날씨는 양방향).
var mods: Dictionary = {"energy_factor": 1.0, "perfect_window_add": 0.0, "burst_damp": 0.0,
	"wait_factor": 1.0, "weather_factor": 1.0}
# ★ 후킹 게이트(→ bool). main이 "혼력을 낼 수 있나(내고 소모까지)"를 여기에 주입한다. 무효 Callable =
#   항상 통과(순수 로직 단독 테스트 기본값 — 이 클래스는 혼력을 모른다).
var hook_gate: Callable = Callable()

# ── 상태(읽기 전용으로 다뤄라 — 변경은 tick/cast/cancel만) ────────────────────
var state: int = State.IDLE
var tension: float = 0.0        # 줄 텐션 0~TENSION_MAX(100 도달 = 끊김)
var fish_stamina: float = 0.0   # 물고기 남은 스태미나(0 = 포획)
var distance: float = 0.0       # 물고기까지 남은 거리(0 = 포획)
var perfect_count: int = 0      # 퍼펙트 릴 성공 횟수(★ 품질 산정 재료 — 등급 매핑은 S3-T3)
var elapsed: float = 0.0        # 세션 시작(cast)부터의 누적 초
var line_broke := false         # 텐션 초과로 줄이 끊겼나
var line_broke_by_class := false  # 체급 게이트(약한 줄로 큰 놈)로 끊겼나 — HUD 문구·안내가 가른다
var missed_bite := false        # 입질 창을 놓쳤나(당기지 않음 or 후킹 게이트 거절 = 혼력 부족)
var hook_refused := false       # 후킹 게이트가 거절했나(= 혼력 부족 — main 안내 분기)

var _rng := RandomNumberGenerator.new()
var _wait_secs := 0.0           # 이번 캐스팅의 입질까지 대기 시간(시드 파생)
var _phase_t := 0.0             # 현재 상태에 머문 시간(초) — CASTING/WAITING/BITE 진행 축
var _burst_timer := 0.0         # 다음 발버둥까지 남은 초
var _burst_left := 0.0          # 진행 중인 발버둥의 남은 초(>0 = 발버둥 중)
var _perfect_left := 0.0        # 퍼펙트 릴 창의 남은 초(>0 = 창 열림)
var _perfect_armed := false     # 이번 발버둥에서 아직 퍼펙트를 못 땄고, 시작 시점에 '당기는 중'이었나
var _perfect_flash := 0.0       # 퍼펙트 성공 연출 잔여(초) — HUD 플래시 전용(로직 무영향)
# ★[폴리시 R8] 직전 프레임의 홀드 상태 — 입질 후킹을 **누르는 순간(rising edge)** 으로 좁히는 축.
#   main이 넘기는 값은 `Input.is_action_pressed`(레벨)라, 캐스팅한 LMB를 놓지 않고 그대로 쥐고
#   있으면 BITE 진입 첫 프레임에 무조건 후킹됐다 = BITE_WINDOW의 반응 판정도 missed_bite 경로도
#   그 플레이 패턴에서 한 번도 실행되지 않았다(격투가 "홀드 = 당기기"라 홀드는 자연스러운 조작이고,
#   대기 구간엔 텐션·혼력 소모가 없어 리스크도 0이었다). 챈다 = 누르는 동작이다.
var _was_reeling := false
var _class_break_left := 0.0    # 체급 게이트 확정 끊김까지 남은 초(>0 = 이미 끊김 확정된 연출 구간)

# rng_seed = 결정성의 단일 출처. fish/rod/mods는 부분 dict를 넘겨도 기본값과 병합된다(호출 측 편의).
func _init(rng_seed: int, fish_params: Dictionary = {}, rod_params: Dictionary = {},
		mod_params: Dictionary = {}) -> void:
	_rng.seed = rng_seed
	fish = _merged(preset_for_class(int(fish_params.get("weight_class", WeightClass.SMALL))), fish_params)
	rod = _merged(ROD_T1, rod_params)
	mods = _merged(mods, mod_params)

# 기본 dict 위에 덮어쓰기(원본 불변 — const 중첩 dict 오염 방지).
static func _merged(base: Dictionary, over: Dictionary) -> Dictionary:
	var out := base.duplicate(true)
	for k in over:
		out[k] = over[k]
	return out

# 체급 → 그레이박스 프리셋 사본(범위 밖은 소로 클램프 — 손상 방어).
static func preset_for_class(wc: int) -> Dictionary:
	return CLASS_PRESETS[clampi(wc, 0, CLASS_PRESETS.size() - 1)].duplicate(true)

# 체급 → 후킹 혼력 기준값(ADR-0061 결정 6 실값: 소 4·중 8·대 14·전설 30). main이 사전 안내에 쓴다.
static func base_energy_for_class(wc: int) -> int:
	return int(CLASS_PRESETS[clampi(wc, 0, CLASS_PRESETS.size() - 1)]["energy"])

# ── 진행 API ────────────────────────────────────────────────────────────────
# 캐스팅 시작(IDLE에서만). 이번 캐스팅의 입질 대기 시간을 시드에서 뽑는다.
func cast() -> bool:
	if state != State.IDLE:
		return false
	state = State.CASTING
	_phase_t = 0.0
	elapsed = 0.0
	_was_reeling = false     # 캐스팅의 그 클릭은 후킹의 근거가 못 된다(다음 누름부터 센다)
	# ★[S3-T4] 미끼(일반 −40%·유인/보장 −20%)가 대기 시간을 줄인다. 하한 0.1로 클램프해 "즉시 입질"
	#   같은 축퇴를 막고, 상한 1.0으로 막아 미끼가 대기를 *늘리는* 방향은 열지 않는다(기어 = 언제나 순이득).
	# ★[S7-T3 / ADR-0065 결정 4] 날씨는 **별도 인자**다 — 기어 클램프(상한 1.0)를 함께 타면 잿눈의
	#   둔화(−15% = 대기 1.18배)가 통째로 잘려 나간다. 기어는 "언제나 순이득"이라는 계약을 지키고,
	#   날씨는 하늘이라 양방향으로 민다(하한 0.1·상한 3.0 = 축퇴·무한 대기 방어).
	_wait_secs = _rng.randf_range(WAIT_MIN, WAIT_MAX) \
		* clampf(float(mods.get("wait_factor", 1.0)), 0.1, 1.0) \
		* clampf(float(mods.get("weather_factor", 1.0)), 0.1, 3.0)
	return true

# 세션 취소(이동 입력 등). 종착 상태에서도 안전(멱등) — main이 세션 참조를 버리면 끝이다.
func cancel() -> void:
	state = State.IDLE

# 아직 굴러가는 세션인가(main의 tick·HUD 게이트).
func is_active() -> bool:
	return state != State.IDLE and state != State.LANDED and state != State.ESCAPED

# 결착(포획/실패)이 났나 — main이 이 프레임에 결과를 수확하고 세션을 버린다.
func is_finished() -> bool:
	return state == State.LANDED or state == State.ESCAPED

# ★ 한 프레임 진행. reeling = 지금 LMB를 홀드(당김) 중인가. 결정적이라 테스트가 같은 delta 열을
#   먹이면 같은 결과가 나온다. 종착 상태에서는 무동작(멱등).
func tick(delta: float, reeling: bool) -> void:
	if not is_active():
		return
	elapsed += delta
	_phase_t += delta
	if _perfect_flash > 0.0:
		_perfect_flash = maxf(_perfect_flash - delta, 0.0)
	# ★[폴리시 R8] 후킹만 **누르는 순간**을 본다(격투의 당기기는 그대로 레벨 — 홀드가 곧 당김이다).
	var struck := reeling and not _was_reeling
	_was_reeling = reeling
	match state:
		State.CASTING:
			if _phase_t >= CAST_SECS:
				state = State.WAITING
				_phase_t = 0.0
		State.WAITING:
			# 입질 대기 = 혼력 0(ADR-0061 결정 6 "캐스팅·대기 = 0"). 시간만 흐른다.
			if _phase_t >= _wait_secs:
				state = State.BITE
				_phase_t = 0.0
		State.BITE:
			_tick_bite(struck)
		State.FIGHT:
			_tick_fight(delta, reeling)

# 입질 창: **채면**(누르는 순간) 후킹 시도(게이트 통과 시 FIGHT), 창을 넘기면 놓침(ESCAPED·혼력 0 소모).
# ★[폴리시 R8] 인자가 "홀드 중인가"에서 "이 프레임에 눌렀는가"로 좁혀졌다 — 쥐고만 있으면 창이
#   그냥 흐르고 놓친다(HUD가 안내하는 "[좌클릭]으로 챈다"의 반응 게이트가 그제야 실제 게이트가 된다).
func _tick_bite(struck: bool) -> void:
	if struck:
		_try_hook()
		return
	if _phase_t >= BITE_WINDOW:
		missed_bite = true
		state = State.ESCAPED

# ★ 후킹 = 이 세션에서 혼력이 나가는 유일한 순간(ADR-0061 결정 6). 게이트(main 주입)가 거절하면
#   = 혼력 부족 → 후킹 불가·입질 놓침으로 끝난다("평평 ≠ 막힘"의 예외가 아니라 자원 고갈의 정직한 결과).
#   통과하면 체급 게이트를 즉시 판정한다 — 낚싯대 줄 강도를 넘는 놈이면 이 시점에 끊김이 *확정*되고,
#   짧은 FIGHT 연출(CLASS_BREAK_SECS) 뒤 ESCAPED로 떨어진다(혼력은 이미 나갔다 = 리스크).
func _try_hook() -> void:
	if hook_gate.is_valid() and not bool(hook_gate.call()):
		hook_refused = true
		missed_bite = true
		state = State.ESCAPED
		return
	state = State.FIGHT
	_phase_t = 0.0
	tension = 0.0
	fish_stamina = float(fish.get("stamina", 24.0))
	distance = float(fish.get("distance", 30.0))
	_burst_timer = _next_burst_gap()
	if int(fish.get("weight_class", WeightClass.SMALL)) > int(rod.get("max_class", WeightClass.SMALL)):
		line_broke_by_class = true
		_class_break_left = CLASS_BREAK_SECS

# 격투 1프레임. 순서가 의미를 만든다: ①체급 확정 끊김 ②발버둥 진행/퍼펙트 판정 ③텐션 ④스태미나·거리 ⑤결착.
func _tick_fight(delta: float, reeling: bool) -> void:
	# ① 체급 게이트 — 이미 끊김이 확정된 연출 구간(당기든 풀든 결과 불변, ADR-0030 "약한 줄로 큰 놈").
	if line_broke_by_class:
		_class_break_left -= delta
		tension = minf(tension + TENSION_MAX * delta / CLASS_BREAK_SECS, TENSION_MAX)
		if _class_break_left <= 0.0:
			line_broke = true
			state = State.ESCAPED
		return

	# ② 발버둥(burst) — 시드 파생 주기로 시작하고, 시작 순간 '당기는 중'이었다면 퍼펙트 창이 열린다.
	var bursting := _burst_left > 0.0
	if bursting:
		_burst_left -= delta
		if _burst_left <= 0.0:
			_burst_timer = _next_burst_gap()
	else:
		_burst_timer -= delta
		if _burst_timer <= 0.0:
			_burst_left = float(fish.get("burst_len", 1.0))
			_perfect_left = PERFECT_WINDOW + float(mods.get("perfect_window_add", 0.0))
			_perfect_armed = reeling   # 당기는 중이 아니었다면 '풀 것'이 없다 = 퍼펙트 대상 아님
			bursting = true
	# 퍼펙트 릴 판정 — 창이 열린 동안 당김→풀기 전환에 성공하면 크리(스태미나 추가 삭감).
	if _perfect_left > 0.0:
		_perfect_left -= delta
		if _perfect_armed and not reeling:
			_perfect_armed = false
			_perfect_left = 0.0
			perfect_count += 1
			fish_stamina -= PERFECT_STAMINA_CUT
			_perfect_flash = 0.35

	# ③ 텐션 — 당기면 오르고 풀면 내린다. 발버둥 중 당기면 급등(burst_mult, 태클 납추가 감쇠).
	if reeling:
		var rise := float(fish.get("tension_rise", 20.0))
		rise *= 1.0 - clampf(float(rod.get("tension_safe_bonus", 0.0)), 0.0, 0.9)
		if bursting:
			var bm := float(fish.get("burst_mult", 2.4)) - float(mods.get("burst_damp", 0.0))
			rise *= maxf(bm, 1.0)
		tension = minf(tension + rise * delta, TENSION_MAX)
	else:
		tension = maxf(tension - float(fish.get("tension_fall", 30.0)) * delta, 0.0)

	# ④ 스태미나·거리 — 당기면 물고기가 지치고 가까워지고, 풀면 거리를 소폭 되찾는다(스태미나는 회복 없음).
	var dist_max := float(fish.get("distance", 30.0))
	if reeling:
		fish_stamina -= float(fish.get("stamina_drain", 14.0)) * delta
		distance = maxf(distance - float(fish.get("pull_rate", 8.0)) * delta, 0.0)
	else:
		distance = minf(distance + float(fish.get("slack_rate", 3.0)) * delta, dist_max)

	# ⑤ 결착 — 줄 끊김이 포획보다 우선(같은 프레임에 둘 다면 끊김. 리스크가 이긴다).
	if tension >= TENSION_MAX:
		line_broke = true
		state = State.ESCAPED
	elif fish_stamina <= 0.0 or distance <= 0.0:
		fish_stamina = maxf(fish_stamina, 0.0)
		state = State.LANDED

# 다음 발버둥까지의 간격(시드 파생 지터 — 리듬 암기 방지).
func _next_burst_gap() -> float:
	var period := float(fish.get("burst_period", 3.0))
	return period * _rng.randf_range(1.0 - BURST_JITTER, 1.0 + BURST_JITTER)

# ── 조회(HUD·main·테스트 — 폴링 전용, 시그널 없음) ────────────────────────────
func tension_ratio() -> float:
	return clampf(tension / TENSION_MAX, 0.0, 1.0)

func stamina_ratio() -> float:
	var m := float(fish.get("stamina", 1.0))
	return clampf(fish_stamina / m, 0.0, 1.0) if m > 0.0 else 0.0

func distance_ratio() -> float:
	var m := float(fish.get("distance", 1.0))
	return clampf(distance / m, 0.0, 1.0) if m > 0.0 else 0.0

# 지금 발버둥 중인가(HUD 붉은 강조·퍼펙트 창의 모체).
func is_bursting() -> bool:
	return _burst_left > 0.0

# 발버둥 예고 구간인가(HUD 느낌표 — 읽고 대응할 시간을 준다, "발버둥 읽기" ADR-0030).
func is_telegraphing() -> bool:
	return state == State.FIGHT and not line_broke_by_class and not is_bursting() \
		and _burst_timer <= TELEGRAPH_SECS

# 퍼펙트 릴 창이 아직 열려 있나(HUD 초록 테두리).
func is_perfect_window() -> bool:
	return _perfect_left > 0.0

# 퍼펙트 성공 플래시가 남아 있나(HUD 연출 전용 — 로직 무영향).
func perfect_flash() -> bool:
	return _perfect_flash > 0.0

# ★[폴리시 R10] 후킹 비용식의 **클램프 하한**(비용이 0으로 내려가 후킹이 공짜가 되는 것만 막는다).
const MIN_HOOK_ENERGY := 1

# ★[폴리시 R11] 이번 캐스팅에서 **실제로 도달 가능한 최저 후킹 비용**. R10은 캐스팅 사전 판정에
#   위 클램프 하한(1)을 그대로 썼는데, 그 값은 **도달 불가능**하다: base는 늘 CLASS_PRESETS 폴백이고
#   (어종 dict에 "energy" 오버라이드가 한 종도 없다) 최저 체급이 4, 절감 계수의 하한이 0.70이라
#   맨 아래 비용도 round(4×0.70)=3이다. 그래서 혼력 1~3에서는 사전 판정이 통과시켜 놓고 후킹
#   게이트가 **반드시** 실패했다 — 미끼만 태우고 100% "입질을 놓쳤다"를 반복할 수 있었다(R10이
#   걷어내겠다고 선언한 바로 그 손실이 혼력 0 한 칸만 빼고 남아 있었다).
#   ★ 최저 체급을 손으로 적지 않고 프리셋 표 전체에서 파생한다(표가 늘거나 순서가 바뀌어도 따라온다).
#   ★ ADR-0008과 충돌하지 않는다: 저혼력을 막는 게이트가 아니라 "확정 실패 + 자원 소각"만 걷는다.
#     이 값을 낼 수 있으면 그대로 던진다(어떤 어종이 걸릴지는 여전히 굴려 봐야 안다).
static func min_hook_energy(mods: Dictionary) -> int:
	var factor := float(mods.get("energy_factor", 1.0))
	var lowest := -1
	for p in CLASS_PRESETS:
		var c := maxi(int(round(float(p["energy"]) * factor)), MIN_HOOK_ENERGY)
		if lowest < 0 or c < lowest:
			lowest = c
	return lowest if lowest > 0 else MIN_HOOK_ENERGY

# 이 세션의 후킹 혼력 비용(체급 기준값 × 스킬 절감 계수, 하한 MIN_HOOK_ENERGY). main이 사전 판정·소모에 쓴다.
func energy_cost() -> int:
	var base := int(fish.get("energy", base_energy_for_class(int(fish.get("weight_class", WeightClass.SMALL)))))
	return maxi(int(round(float(base) * float(mods.get("energy_factor", 1.0)))), MIN_HOOK_ENERGY)

# 물고기 체급(0~3).
func weight_class() -> int:
	return int(fish.get("weight_class", WeightClass.SMALL))

# ★ 결과 계약(main·테스트가 소비하는 유일한 산출물). 등급 매핑은 하지 않는다 — perfect_count를 넘길
#   뿐이고 "퍼펙트 → 품질"은 S3-T3(어종 카탈로그)이 맡는다(night_bar.block의 {repelled,raided} 결).
func result() -> Dictionary:
	return {
		"landed": state == State.LANDED,
		"weight_class": weight_class(),
		"perfect_count": perfect_count,
		"elapsed": elapsed,
		"line_broke": line_broke,
		"line_broke_by_class": line_broke_by_class,
		"missed_bite": missed_bite,
		"hook_refused": hook_refused,
		"energy_cost": energy_cost(),
		"fish_id": String(fish.get("id", "")),   # ★[S3-T3] 어종 id(지금은 빈 문자열 = 체급 스텁)
	}

# 상태 한글 표시명(HUD·디버그 — 그레이박스 판독성 우선).
func state_label() -> String:
	match state:
		State.CASTING: return "던지는 중"
		State.WAITING: return "입질 기다리는 중"
		State.BITE: return "입질!"
		State.FIGHT: return "격투"
		State.LANDED: return "포획"
		State.ESCAPED: return "놓침"
		_: return "대기"
