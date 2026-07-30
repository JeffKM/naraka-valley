extends RefCounted
class_name Mob
# ★[S5-T5 / ADR-0063 결정 8] 잡귀 개체 — 상태 + **순수 행동 스텝**.
#
# 목적: 한 마리의 "지금 어디에 있고 몇 남았고 무엇을 하는 중인가". 종 데이터는 MobCatalog가, 배치는
#       MineFloors가, 틱 폴링·접촉 피해·렌더는 main이 든다(mob_catalog.gd 머리말의 4분할 참조).
#
# ★ 로직/렌더 분리(혼 감지 마커 선례 — ForageSpawns가 감지 규칙을 들고 main이 ▼만 그린 그 경계):
#   이 파일은 **씬 노드가 아니고**(RefCounted) 텍스처·색·draw를 하나도 모른다. 행동은 전부
#   `step(dt, target_px, probe)` 하나로 접혀 있고, 그 셋이 유일한 입력이다:
#     · dt        = 흐른 초(main은 `_process(delta)`를 넘기고, 테스트는 고정 dt를 넘긴다)
#     · target_px = 플레이어 픽셀 위치(어그로·추적·발사 방향의 유일한 기준)
#     · probe     = `func(Vector2i) -> int` 지형 콜백(CELL_* — 몹은 _grid·타일 id·충돌 레이어를 모른다)
#   덕분에 main 없이 헤드리스로 행동을 굴려 검증할 수 있다(mob_test ④ 아키타입 4 스텝).
#
# ★ 결정성: 배회 방향 같은 "무작위"는 **개체 전용 RNG 하나를 정해진 순서로 소비**한다(스폰 시
#   day·층·인덱스로 시드를 박는다 — 좌표 해시 금지 규율 상속, ADR-0063 결정 1). 같은 dt 열을
#   먹이면 같은 궤적이 나온다.
#
# ★ 비영속: 몹 상태는 **세이브에 안 들어간다**(층 한정 — ADR-0063 결정 8 "층 한정 비영속").
#   층을 떠나면 소멸하고 재진입하면 재스폰된다(스타듀가 층 재진입 시 재생성하는 것과 같은 계약이라
#   day-한정 처치 원장도 필요 없다 — 그래서 to_save/load_save가 이 파일에 아예 없다).

# 지형 콜백 반환 코드(probe.call(tile) → 이 셋 중 하나).
const CELL_FREE := 0   # 걸을 수 있다
const CELL_ROCK := 1   # 깰 수 있는 일반 돌(★`breaks_rocks` 종만 통과 = 부순다. 광맥은 WALL로 준다)
const CELL_WALL := 2   # 암반·맵 밖·광맥 — 누구도 못 지난다

# 타일 한 변(px). ★main.TILE과 같은 값이되 숫자로 둔다 — const 초기화식에서 타 클래스 상수를 안 읽는
#   이 저장소의 관례(main.MINE_ROCK_COST 주석과 같은 이유). mob_test가 두 값의 일치를 단언한다.
const TILE_PX := 32

# 통통 아키타입의 두 위상(*잠정* — Green Slime의 "멈췄다 튄다" 리듬). 평균 속도가 speed × dash/(pause+
# dash) ≈ 1/4로 떨어져, 순간은 빠르지만 전체 추격은 느리다(도망칠 수 있다는 계약 유지).
const HOP_PAUSE := 0.72   # 멈춤(초)
const HOP_DASH := 0.26    # 돌진(초)

# 배회(어그로 밖) — 방향을 이 주기로 다시 뽑는다. 막히면 즉시 다시 뽑는다(벽에 붙어 떨지 않게).
const WANDER_SECS := 1.6
const WANDER_SPEED_FACTOR := 0.45   # 배회는 추적보다 느리다(어슬렁 — "곧 온다"가 아니라 "저기 있다")

# 접촉 피해 판정 반경(px). 몹 중심 ↔ 플레이어 중심이 이 안이면 닿았다(main이 쓴다 — 여기선 상수만
# 든다: 반경도 종 데이터가 아니라 *판정 규칙*이라 개체 파일이 자리다). TILE의 5/8(*잠정*).
const TOUCH_PX := 20.0

# 화염구 수명(초) — 사거리를 넘어 화면 밖으로 날아가지 않게 자른다(reach 7칸 ÷ 96px/s ≈ 2.3s).
const SHOT_LIFE := 2.6

# ── 개체 상태 ────────────────────────────────────────────────────────────────
var kind: String = ""          # 종 id(MobCatalog)
var pos: Vector2 = Vector2.ZERO  # 픽셀 연속 위치(중심)
var home: Vector2i = Vector2i.ZERO  # 스폰 타일(배회 리쉬·디버그)
var hp: int = 0
var awake: bool = true         # 위장형만 false로 시작한다(곡괭이 타격 → wake())
var facing: Vector2 = Vector2.DOWN
var phase: float = 0.0         # 아키타입 위상(통통 주기 / 배회 주기 공용)
var dashing: bool = false      # 통통 — 지금 돌진 중인가
var burst: Vector2 = Vector2.ZERO  # 돌진·배회 방향(정규화)
var cool: float = 0.0          # 원거리 발사 쿨다운(초)
var hurt: float = 0.0          # 피격 플래시 잔량(초 — 렌더 전용 관측값)
var _rng := RandomNumberGenerator.new()

# 스폰 — 종·타일·결정적 시드를 받아 개체를 세운다. 위치는 타일 중심이다.
static func spawn(mob_kind: String, tile: Vector2i, seed_value: int) -> Mob:
	var m := Mob.new()
	m.kind = mob_kind
	m.home = tile
	m.pos = Vector2(tile.x * TILE_PX + TILE_PX * 0.5, tile.y * TILE_PX + TILE_PX * 0.5)
	m.hp = MobCatalog.max_hp(mob_kind)
	m.awake = not MobCatalog.is_disguise(mob_kind)   # 위장형은 바위인 척 잠들어 있다
	m._rng.seed = hash("mob:%s:%d" % [mob_kind, seed_value])
	m.cool = MobCatalog.cooldown_of(mob_kind) * 0.5   # 첫 발이 스폰 즉시 나가지 않게 반 주기 대기
	return m

# ── 파생 조회 ────────────────────────────────────────────────────────────────
func tile() -> Vector2i:
	return Vector2i(floori(pos.x / float(TILE_PX)), floori(pos.y / float(TILE_PX)))

func is_alive() -> bool:
	return hp > 0

# 지금 플레이어를 해칠 수 있나 — 위장 중(awake=false)엔 무해하다. 그게 "위장"의 메카닉적 의미다
# (바위인 줄 알고 지나가도 안 맞는다 → 곡괭이로 건드린 사람만 싸움이 붙는다).
func is_hostile() -> bool:
	return is_alive() and awake

func max_hp() -> int:
	return MobCatalog.max_hp(kind)

func hp_ratio() -> float:
	var m := max_hp()
	return clampf(float(hp) / float(m), 0.0, 1.0) if m > 0 else 0.0

func touch_damage() -> int:
	return MobCatalog.damage_of(kind)

func kill_xp() -> int:
	return MobCatalog.xp_of(kind)

# 플레이어와 닿았나(접촉 피해 판정 — main이 매 틱 묻는다).
func touches(target_px: Vector2) -> bool:
	return is_hostile() and pos.distance_to(target_px) <= TOUCH_PX

# ── 상태 전이 ────────────────────────────────────────────────────────────────
# 위장 해제(곡괭이 타격). 이미 깨어 있으면 무동작 = 멱등. 반환 = 이 호출이 실제로 깨웠나.
func wake() -> bool:
	if awake or not is_alive():
		return false
	awake = true
	phase = 0.0
	return true

# 피해를 받는다 — 깎인 양을 돌려준다. ★위장형은 맞으면 함께 깨어난다(검으로 후려친 바위가 계속
#   바위인 척할 수는 없다). HP 곡선·크리는 CombatSkill이 이미 정했고 여기선 차감만 한다.
func take_hit(amount: int) -> int:
	if not is_alive() or amount <= 0:
		return 0
	awake = true
	var dealt := mini(amount, hp)
	hp -= dealt
	hurt = 0.18
	return dealt

# ── 행동 스텝(순수 함수 — 이 파일의 심장) ────────────────────────────────────
# 반환 이벤트 = {"broke": Vector2i, "fire": Vector2}
#   · broke = 부순 일반 돌 좌표((-1,-1) = 없음). ★main이 채광 XP **0**으로 처리한다(ADR-0063 결정 9).
#   · fire  = 화염구 발사 방향(Vector2.ZERO = 없음). main이 발사체를 세운다.
# 아키타입 4갈래가 여기 전부이고, 갈래마다 이동은 `_move`(축 분리 + 지형 probe) 하나를 공유한다.
func step(dt: float, target_px: Vector2, probe: Callable) -> Dictionary:
	var ev := {"broke": Vector2i(-1, -1), "fire": Vector2.ZERO}
	if not is_alive() or dt <= 0.0:
		return ev
	hurt = maxf(hurt - dt, 0.0)
	if not awake:
		return ev                      # 위장 중 = 완전 정지·무해(깨우는 건 wake()/take_hit()뿐)
	var to_target := target_px - pos
	var dist_px := to_target.length()
	var aggro_px := MobCatalog.aggro_tiles(kind) * float(TILE_PX)
	var chasing := dist_px <= aggro_px
	if chasing and dist_px > 0.001:
		facing = to_target / dist_px   # 어그로 안이면 늘 플레이어를 본다(렌더·돌진 방향의 기준)
	match MobCatalog.arch_of(kind):
		MobCatalog.ARCH_HOP:
			_step_hop(dt, chasing, probe, ev)
		MobCatalog.ARCH_CHASE, MobCatalog.ARCH_DISGUISE:
			_step_chase(dt, chasing, probe, ev)
		MobCatalog.ARCH_RANGED:
			_step_ranged(dt, dist_px, ev)
	return ev

# ① 통통 — 멈춤(HOP_PAUSE) ↔ 돌진(HOP_DASH)을 번갈아 한다. 돌진 방향은 **돌진이 시작되는 순간에만**
#    정해진다(그래서 옆으로 비키면 헛것이 빈 곳으로 튄다 = 읽고 대응할 수 있다).
func _step_hop(dt: float, chasing: bool, probe: Callable, ev: Dictionary) -> void:
	phase += dt
	if not dashing:
		if phase < HOP_PAUSE:
			return
		phase = 0.0
		dashing = true
		burst = facing if chasing else _pick_wander(probe)
		return
	if phase >= HOP_DASH:
		phase = 0.0
		dashing = false
		return
	var sp := MobCatalog.speed_of(kind) * (1.0 if chasing else WANDER_SPEED_FACTOR)
	_move(burst * sp * dt, probe, ev)

# ② 등속 추적 — 어그로 안이면 플레이어에게 직진하고, 밖이면 배회(wanders)하거나 제자리에 선다.
#    위장형도 *깨어난 뒤엔* 이 갈래를 쓴다(활성화 = 추적 개시. 별 아키타입을 안 만드는 이유).
func _step_chase(dt: float, chasing: bool, probe: Callable, ev: Dictionary) -> void:
	if chasing:
		_move(facing * MobCatalog.speed_of(kind) * dt, probe, ev)
		return
	if not MobCatalog.wanders(kind):
		return
	phase += dt
	if burst == Vector2.ZERO or phase >= WANDER_SECS:
		phase = 0.0
		burst = _pick_wander(probe)
	var moved_from := pos
	_move(burst * MobCatalog.speed_of(kind) * WANDER_SPEED_FACTOR * dt, probe, ev)
	if pos.is_equal_approx(moved_from):
		burst = _pick_wander(probe)    # 막혔으면 즉시 새 방향(벽에 붙어 떨지 않게)

# ③ 원거리 — 제자리에서 사거리 안이면 쿨다운마다 화염구를 뱉는다. reach ≤ aggro라 "보이면 쏜다".
func _step_ranged(dt: float, dist_px: float, ev: Dictionary) -> void:
	cool = maxf(cool - dt, 0.0)
	if dist_px > MobCatalog.reach_tiles(kind) * float(TILE_PX):
		return
	if cool > 0.0:
		return
	cool = MobCatalog.cooldown_of(kind)
	ev["fire"] = facing.normalized()

# 배회 방향 하나(4방향 중 결정 롤 — 개체 RNG 순차 소비). 대각은 안 쓴다: 그레이박스 무대가
# 타일 격자라 축 정렬 배회가 "복도를 따라 어슬렁"으로 읽힌다.
func _pick_wander(_probe: Callable) -> Vector2:
	const DIRS := [Vector2.RIGHT, Vector2.LEFT, Vector2.DOWN, Vector2.UP]
	return DIRS[_rng.randi_range(0, DIRS.size() - 1)]

# ── 이동(축 분리 + 지형 probe) ───────────────────────────────────────────────
# x·y를 따로 밀어 벽에 스치면 미끄러진다(한 축이 막혀도 다른 축은 살아 코너에 끼지 않는다).
# 일반 돌(CELL_ROCK)은 `breaks_rocks` 종에게만 "부술 대상"이고, 그 종도 **그 프레임엔 못 지난다**
# (부수는 신호만 올리고 통과는 다음 틱 — main이 돌을 치워 준 뒤다. 벽 관통 버그의 뿌리를 막는다).
func _move(delta_v: Vector2, probe: Callable, ev: Dictionary) -> void:
	if delta_v == Vector2.ZERO:
		return
	var breaker := MobCatalog.breaks_rocks(kind)
	for axis in 2:
		var step_v := Vector2(delta_v.x, 0.0) if axis == 0 else Vector2(0.0, delta_v.y)
		if step_v == Vector2.ZERO:
			continue
		var dest := pos + step_v
		var t := Vector2i(floori(dest.x / float(TILE_PX)), floori(dest.y / float(TILE_PX)))
		var cell := int(probe.call(t))
		if cell == CELL_FREE:
			pos = dest
		elif cell == CELL_ROCK and breaker and ev["broke"] == Vector2i(-1, -1):
			ev["broke"] = t            # ★부순 바위 = 채광 XP 0(main이 그 규칙을 지킨다)

# ── 화염구(발사체 — 순수 스텝) ───────────────────────────────────────────────
# 발사체는 상태가 넷뿐이라(위치·속도·데미지·수명) 개체 클래스를 하나 더 만들지 않고 **불투명 dict**로
# 둔다(main이 배열로 들고 여기 static 스텝에 흘린다 — 몹 레코드가 dict인 것과 같은 결).
static func make_shot(from_px: Vector2, dir: Vector2, mob_kind: String) -> Dictionary:
	return {
		"pos": from_px,
		"vel": dir.normalized() * MobCatalog.shot_speed(mob_kind),
		"damage": MobCatalog.damage_of(mob_kind),
		"life": SHOT_LIFE,
		"kind": mob_kind,
	}

# 한 틱 전진. 반환 = 아직 살아 있나(false = 수명 끝 또는 지형에 부딪힘 → main이 목록에서 뺀다).
# ★ 화염구는 **돌에도 막힌다**(CELL_FREE가 아니면 소멸) — 바위 뒤로 숨는 것이 실제 회피가 된다.
static func step_shot(shot: Dictionary, dt: float, probe: Callable) -> bool:
	shot["life"] = float(shot["life"]) - dt
	if float(shot["life"]) <= 0.0:
		return false
	var dest: Vector2 = Vector2(shot["pos"]) + Vector2(shot["vel"]) * dt
	var t := Vector2i(floori(dest.x / float(TILE_PX)), floori(dest.y / float(TILE_PX)))
	if int(probe.call(t)) != CELL_FREE:
		return false
	shot["pos"] = dest
	return true

# 이 화염구가 플레이어에 닿았나(접촉 판정은 몹과 같은 반경을 쓴다 — 판정 규칙 단일화).
static func shot_touches(shot: Dictionary, target_px: Vector2) -> bool:
	return Vector2(shot["pos"]).distance_to(target_px) <= TOUCH_PX
