extends RefCounted
class_name NarakFloors
# ★[S5-T7 / ADR-0063 결정 7] 나락 리셋 런 — "이번 런의 몇 층이 어떻게 생겼나 + 지금 무엇을 캤나"만
# 소유하는 얇은 원장 + 결정적 층 생성기. MineFloors(갱도)의 짝이되 **수명이 정반대**다.
#
# 갱도와 갈리는 지점(이 파일이 별도로 존재하는 이유 — ADR-0063 결정 7):
#   · 갱도 = 광산형 영구 하강(도달 깊이 `mine_depth` 영구·엘리베이터 체크포인트·day-한정 층 상태).
#   · 나락 = **해골동굴형 리셋 런**(매 진입 1층·무한 깊이·엘리베이터 0·영구 depth 기록 0). 취침·기절·
#     퇴장 사다리가 전부 런 종료다. 그래서 이 원장엔 `to_save`/`load_save`가 **아예 없다** — 남길 게
#     없다는 것이 이 시스템의 정의다. 유일한 영구 흔적은 main의 `narak_best_boss`(최고 격파 관문)뿐이고,
#     그건 "런의 상태"가 아니라 "플레이어가 어디까지 갔었나"의 마일스톤이라 자리가 다르다.
#   · 하강 수단이 **확정 사다리가 아니다**: 돌을 깨야 사다리(또는 구멍)가 드러난다. 갱도가 "내려가는
#     사다리 1개 확정 배치"로 갇힘을 막는 것과 정반대의 긴장이고, 그 대신 **나가는 사다리**(착지 칸)가
#     늘 발밑에 있어 soft-lock이 0이다(언제든 런을 접고 나갈 수 있다).
#
# ★ 시드 네임스페이스 분리(어기면 갱도 층과 배치가 겹친다):
#   갱도는 `hash("mine:<day>:<floor>")`, 나락은 `hash("narak:<run>:<depth>")`다. **day가 아니라 런
#   카운터**를 무는 이유: 리셋 런은 "오늘 몇 번째로 내려왔나"가 판을 가르는 축이고(같은 날 두 번
#   들어가면 다른 판이어야 한다), 반대로 날이 바뀌어도 런이 이어지는 일은 없다(취침 = 런 종료).
#   ⚠️ 갱도 경로의 RNG 소비 순서는 이 파일이 한 칸도 안 건드린다(mining_test 골든 서명 보존).
#
# ★ 이 파일이 모르는 것(MineFloors와 같은 경계): 지형 타일 id·충돌·혼력·인벤토리·도구 티어·HP·전투.
#   층을 실제 그리드로 세우는 것도, 낙하 피해를 실제로 입히는 것도 전부 main이 한다.

# ── 층 그리드(갱도 층과 같은 치수 — 무대 문법을 공유한다) ─────────────────────
const FLOOR_W := 24
const FLOOR_H := 24

# ── 관문 보스(ADR-0063 결정 7 — 깊이 10/25/50 **보장 출현**) ──────────────────
# ★ 가중 롤이 아니라 **확정 배치**다: 마일스톤은 운이 아니라 도달의 보상이어야 한다(바나 매크로
#   눈금이 이 값에서 파생된다 — 운으로 흔들리면 눈금이 눈금이 아니다).
const BOSS_DEPTHS := [10, 25, 50]
# 깊이 → 보스 종 id(MobCatalog.BOSSES 키와 *같은 문자열*이되 리터럴로 둔다 — const 초기화식에서 타
# 클래스 상수를 안 읽는 이 저장소의 관례. narak_run_test가 두 로스터를 대조해 조용한 분기를 막는다).
const BOSS_BY_DEPTH := {
	10: "boss_okjol",        # 문지기 옥졸
	25: "boss_nachalwang",   # 업화 나찰왕
	50: "boss_daeagwi",      # 심연 대아귀
}

# ── 구멍(shaft) — 해골동굴 1:1(ADR-0063 결정 7) ───────────────────────────────
# 돌을 깨 사다리가 열리는 **그 사건의 20%**가 사다리 대신 구멍이다(사다리 롤과 별 축이 아니라 그
# 롤의 분기다 — "뭔가 뚫렸는데 그게 구멍이었다"). 낙하는 3~8층, 10%로 2x−1층(5~15).
const SHAFT_CHANCE := 0.20
const SHAFT_MIN := 3
const SHAFT_MAX := 8
const SHAFT_DOUBLE_CHANCE := 0.10
# 낙하 피해 = 건너뛴 층수 × 3 HP(ADR-0063 결정 7 상속). ★넉백 없이 들어간다 — 떨어지는 데엔 때린
# 사람이 없다(main이 `take_damage(amount, Vector2.ZERO)`로 부른다).
const FALL_DAMAGE_PER_FLOOR := 3

# ── 층 템플릿(그레이박스 — 갱도보다 넓고 빽빽하다) ───────────────────────────
# 갱도 템플릿(0.10~0.24)보다 밀도가 높은 이유: 나락엔 확정 하강 사다리가 없어서 **돌이 곧 길**이다.
# 돌이 적으면 사다리 롤을 굴릴 기회 자체가 모자라 층이 지루한 막다른 방이 된다.
static func templates() -> Array:
	return [
		{"id": "abyss", "size": Vector2i(20, 18), "density": 0.20},   # 넓은 심연 공동
		{"id": "pit", "size": Vector2i(15, 20), "density": 0.26},     # 좁고 깊은 수혈
		{"id": "vault", "size": Vector2i(18, 18), "density": 0.30},   # 정방 봉인실(가장 빽빽)
		{"id": "shard", "size": Vector2i(13, 13), "density": 0.24},   # 갈라진 파편 포켓
	]

# ── 광맥 로스터(나락 전용 — 갱도 NODE_TABLE과 **완전 분리**) ─────────────────
# ★ 부류 상수는 MineFloors 것을 **재사용**한다(타수·드랍 규칙의 축은 같다 — 광맥은 광맥이다).
#   갈리는 건 "무엇이 어느 깊이에 나오나"뿐이라, 표만 따로 든다.
# ★ 명동은 여기 없다 — 나락은 엔드게임 무대라 하위 티어가 자리를 먹으면 나락철 곡선이 묽어진다
#   (갱도의 "상위가 하위를 대체하지 않고 얹힌다"는 60층 축의 규칙이고, 여기는 그 축 밖이다).
const N_YUCHEOL := "ore_yucheol"                  # 유철 광석
const N_HWANGCHEONGEUM := "ore_hwangcheongeum"    # 황천금 광석
const N_NARAKCHEOL := "ore_narakcheol"            # ★나락철 — 깊이 10+·깊이 비례(이리듐 1:1)
const N_HONTAN := "hontan"                        # 혼탄(제련 연료)
const N_GEODE_EOPHWA := "geode_eophwa"            # 업화알돌
const N_GEM_YEOMJUSEOK := "gem_yeomjuseok"        # 염주석
const N_GEM_MYEONGBU := "gem_myeongbu_geumgang"   # 명부금강

# 부류 상수 — MineFloors.NODE_* 와 **같은 문자열**이되 리터럴로 다시 둔다(const 초기화식에서 타
# 클래스 상수를 안 읽는 이 저장소의 관례. narak_run_test가 두 쪽의 일치를 단언해 조용한 분기를 막는다).
const CLS_ORE := "ore"
const CLS_COAL := "coal"
const CLS_GEM := "gem"
const CLS_GEODE := "geode"

# 나락철을 뺀 고정 가중 표. {id, cls, weight} — 깊이 게이트가 없다(전 깊이 균일).
const NODE_TABLE := [
	{"id": N_HWANGCHEONGEUM, "cls": CLS_ORE, "weight": 34},
	{"id": N_YUCHEOL, "cls": CLS_ORE, "weight": 24},
	{"id": N_HONTAN, "cls": CLS_COAL, "weight": 16},
	{"id": N_GEODE_EOPHWA, "cls": CLS_GEODE, "weight": 10},
	{"id": N_GEM_YEOMJUSEOK, "cls": CLS_GEM, "weight": 6},
	{"id": N_GEM_MYEONGBU, "cls": CLS_GEM, "weight": 4},
]

# ── 나락철 곡선(ADR-0063 결정 7 "10층+ 출현·깊이 비례 증가") ──────────────────
# 깊이 10 미만 = 0(안 나온다) · 10부터 깊이 1당 가중 +1 · 상한 80.
# **단조 비감소**가 계약이다(narak_run_test가 1~200 깊이를 훑어 단조성을 직접 단언한다) — 이 한
# 함수가 "깊이가 곧 보상"이라는 나락의 유일한 자원 곡선이라, 어디서도 꺾이면 안 된다.
const NARAKCHEOL_MIN_DEPTH := 10
const NARAKCHEOL_WEIGHT_CAP := 80

static func naracheol_weight(depth: int) -> int:
	if depth < NARAKCHEOL_MIN_DEPTH:
		return 0
	return mini(1 + (depth - NARAKCHEOL_MIN_DEPTH), NARAKCHEOL_WEIGHT_CAP)

# 이 깊이에 깔릴 수 있는 광맥 종 목록(표 순서 보존 = 결정적). 나락철은 가중이 0보다 클 때만 낀다.
static func node_pool(depth: int) -> Array:
	var out: Array = []
	if depth < 1:
		return out
	for e: Dictionary in NODE_TABLE:
		out.append(e)
	var w := naracheol_weight(depth)
	if w > 0:
		out.append({"id": N_NARAKCHEOL, "cls": CLS_ORE, "weight": w})
	return out

# 노드 종 id → 부류("" = 나락 광맥이 아님). ★MiningSkill.resolve_drop이 갱도 표에서 못 찾은 종을
#   여기로 되묻는다(나락철이 "광석"으로 굴러가는 유일한 접점).
static func node_class(node_id: String) -> String:
	if node_id == N_NARAKCHEOL:
		return CLS_ORE
	for e: Dictionary in NODE_TABLE:
		if String(e["id"]) == node_id:
			return String(e["cls"])
	return ""

static func is_node_kind(node_id: String) -> bool:
	return node_class(node_id) != ""

# 전 노드 종 id(테스트·아트 로스터 대조용 — 나락철 포함).
static func node_kinds() -> Array[String]:
	var out: Array[String] = []
	for e: Dictionary in NODE_TABLE:
		out.append(String(e["id"]))
	out.append(N_NARAKCHEOL)
	return out

# 이 칸을 부수는 데 드는 타수 — 규칙표는 ToolTier가 들고(수치 복제 0) 여기선 부류만 가른다.
# 갱도 `MineFloors.node_hits`와 **같은 표**를 본다(광맥 타수는 무대가 아니라 광맥의 성질이다).
static func node_hits(node_id: String, tier: int = 0) -> int:
	match node_class(node_id):
		CLS_ORE, CLS_COAL: return ToolTier.pickaxe_ore_hits(tier)
		CLS_GEM, CLS_GEODE: return ToolTier.pickaxe_gem_hits(tier)
	return MineFloors.ROCK_HITS

# ── 깊이 조회 ────────────────────────────────────────────────────────────────
# ★ 상한이 없다(무한 깊이 — ADR-0063 결정 7). 1 이상이면 전부 유효한 층이다.
static func is_valid_depth(depth: int) -> bool:
	return depth >= 1

static func is_boss_depth(depth: int) -> bool:
	return BOSS_DEPTHS.has(depth)

# 이 깊이의 관문 보스 종 id("" = 보스 층 아님).
static func boss_at(depth: int) -> String:
	return String(BOSS_BY_DEPTH.get(depth, ""))

# 이 깊이까지 내려가며 지나친 마지막 관문(0 = 아직 없음). 낙하로 건너뛴 보스는 "지나친" 게 아니라
# **못 만난** 것이라, 격파 마일스톤은 이 함수가 아니라 실제 처치가 올린다(main._narak_best_boss).
static func last_gate_at_or_before(depth: int) -> int:
	var best := 0
	for d: int in BOSS_DEPTHS:
		if d <= depth and d > best:
			best = d
	return best

# ── 잡귀 스폰 수(깊이 비례) ──────────────────────────────────────────────────
# 갱도가 3~6 고정인 것과 달리 깊이에 따라 상한이 는다(깊이가 곧 난도 — 엘리베이터가 없으니
# 층수 자체가 유일한 난도 축이다). 20깊이마다 +1, 최대 +3.
const MOB_MIN := 3
const MOB_MAX := 6
const MOB_DEPTH_STEP := 20
const MOB_DEPTH_CAP := 3
const MOB_PICK_TRIES := 8
const MOB_SPAWN_CLEAR := 3      # 착지 칸 둘레(칸) — 내려서자마자 얻어맞지 않게

# ── 광맥 수 ──────────────────────────────────────────────────────────────────
const NODE_MIN := 4
const NODE_MAX := 9
const NODE_PICK_TRIES := 8

# ── 층 생성(결정적 순수 함수 — 이 파일의 심장) ────────────────────────────────
# 반환 = {"depth", "template", "rect", "entrance", "ladder", "rocks", "nodes", "mobs", "boss"}.
#   · entrance = 착지 칸 = **나가는 사다리**(런 종료·지상 복귀). 갱도의 "올라가는 사다리"와 자리는
#                같지만 의미가 다르다 — 여기선 한 층 위가 아니라 무대 밖으로 나간다.
#   · ladder   = 보통 (-1,-1) = **확정 하강 사다리 없음**(돌을 깨야 열린다 — 나락의 정의).
#                예외: 돌이 하나도 안 깔린 축퇴 층에서만 한 칸을 확정 배치한다(막다른 층 방지).
#   · boss     = 보스 좌표((-1,-1) = 보스 층 아님). 보스 층엔 일반 잡귀가 0이다.
# ★[S7-T3 / ADR-0065 결정 4] `mob_scale` = 잡귀 마리 수 배수(기본 1.0 = 중립 — MineFloors.generate와
#   같은 문법·같은 이유). **보스 층은 배수를 안 탄다**(아래 _scatter_mobs가 보스 한 기에서 조기
#   반환한다) — 관문은 날씨로 늘어나는 물건이 아니다.
static func generate(run: int, depth: int, mob_scale: float = 1.0) -> Dictionary:
	if not is_valid_depth(depth):
		return {}
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("narak:%d:%d" % [run, depth])   # ★갱도("mine:…")와 네임스페이스 분리
	# ① 템플릿 롤(순차 소비 1)
	var pool := templates()
	var tpl: Dictionary = pool[rng.randi_range(0, pool.size() - 1)]
	var sz: Vector2i = tpl["size"]
	# ② 방 위치 지터(순차 소비 2·3) — 사방에 최소 1칸 벽.
	var slack_x := maxi(FLOOR_W - sz.x - 2, 0)
	var slack_y := maxi(FLOOR_H - sz.y - 2, 0)
	var rect := Rect2i(1 + rng.randi_range(0, slack_x), 1 + rng.randi_range(0, slack_y), sz.x, sz.y)
	# ③ 착지 칸(= 나가는 사다리) 롤(순차 소비 4·5)
	var entrance := Vector2i(rect.position.x + rng.randi_range(0, sz.x - 1),
		rect.position.y + rng.randi_range(0, sz.y - 1))
	# ④ 돌 스캐터(순차 소비 6~) — 착지 칸과 그 십자 인접만 비운다(하강 사다리가 없으니 비울 자리도
	#    하나뿐이다. 갱도가 두 자리를 비우는 것과 갈리는 지점).
	var density := float(tpl["density"]) + minf(float(depth) * 0.001, 0.06)   # 깊을수록 촘촘(상한 +6%p)
	var rocks: Array[Vector2i] = []
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			var t := Vector2i(x, y)
			if _near(t, entrance):
				continue
			if rng.randf() < density:
				rocks.append(t)
	# ⑤ 광맥 승격(순차 소비 — 돌 확정 직후). 갱도와 같은 문법이되 표·깊이 축이 다르다.
	var nodes := _scatter_nodes(rng, depth, rocks)
	# ⑥ 잡귀·보스(순차 소비 맨 뒤 — 앞 롤을 한 번도 안 건드린다).
	var boss_tile := _boss_tile(rect, entrance, rocks) if is_boss_depth(depth) else Vector2i(-1, -1)
	var mobs := _scatter_mobs(rng, depth, rect, rocks, entrance, boss_tile, mob_scale)
	# ⑦ 축퇴 방어 — 돌이 하나도 없으면 사다리 롤을 굴릴 기회가 없다(막다른 층). 그때만 확정 하강
	#    사다리를 한 칸 놓는다. RNG를 안 쓰는 계산이라 스트림이 안 흔들린다.
	var ladder := Vector2i(-1, -1)
	if rocks.is_empty():
		ladder = _far_free_tile(rect, entrance, rocks, boss_tile)
	return {
		"depth": depth,
		"template": String(tpl["id"]),
		"rect": rect,
		"entrance": entrance,
		"ladder": ladder,
		"rocks": rocks,
		"nodes": nodes,
		"mobs": mobs,
		"boss": boss_tile,
	}

# 보스가 서는 칸 = 착지 칸에서 **가장 먼** 빈 칸(RNG 0 — 확정 배치). 층을 가로질러 걸어가야
# 마주치므로 "관문"이라는 말이 무대에서 성립한다.
static func _boss_tile(rect: Rect2i, entrance: Vector2i, rocks: Array) -> Vector2i:
	return _far_free_tile(rect, entrance, rocks, Vector2i(-1, -1))

# 방 안에서 from 으로부터 가장 먼 빈 칸(돌·착지 칸·제외 칸 배제). 동률이면 먼저 만난 칸
# (위→아래·왼→오른) = 완전 결정적. 빈 칸이 하나도 없으면 (-1,-1).
static func _far_free_tile(rect: Rect2i, from: Vector2i, rocks: Array, skip: Vector2i) -> Vector2i:
	var blocked: Dictionary = {from: true}
	for r: Vector2i in rocks:
		blocked[r] = true
	if skip.x >= 0:
		blocked[skip] = true
	var best := Vector2i(-1, -1)
	var best_d := -1
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			var t := Vector2i(x, y)
			if blocked.has(t):
				continue
			var d := absi(x - from.x) + absi(y - from.y)
			if d > best_d:
				best_d = d
				best = t
	return best

# 잡귀 배치 = [{"kind", "tile", "boss"}]. 보스 층이면 **보스 한 기뿐**이다(일반 잡귀 0 — ADR-0063
# 결정 7 "보스 층 = 보스만"). 그 규칙이 여기 한 줄로 접혀 있어 main에 특별 분기가 없다.
static func _scatter_mobs(rng: RandomNumberGenerator, depth: int, rect: Rect2i,
		rocks: Array, entrance: Vector2i, boss_tile: Vector2i, mob_scale: float = 1.0) -> Array:
	var out: Array = []
	if is_boss_depth(depth):
		if boss_tile.x >= 0:
			out.append({"kind": boss_at(depth), "tile": boss_tile, "boss": true})
		return out
	var pool := MobCatalog.narak_pool(depth)
	if pool.is_empty():
		return out
	var blocked: Dictionary = {entrance: true}
	for r: Vector2i in rocks:
		blocked[r] = true
	var bonus := mini(depth / MOB_DEPTH_STEP, MOB_DEPTH_CAP)
	# ★[S7-T3] 마리 수 롤은 배수와 무관하게 먼저 굴린다(스트림 고정). 깊이 보너스까지 더한 **총량**에
	#   배수를 건다 — 심층일수록 혼불 바람의 체감이 커진다(위험도 보상도 함께 부푸는 결).
	var quota := int(round(float(rng.randi_range(MOB_MIN, MOB_MAX) + bonus) * maxf(mob_scale, 0.0)))
	var used: Dictionary = {}
	for _i in range(quota):
		var tile := Vector2i(-1, -1)
		for _try in range(MOB_PICK_TRIES):
			var t := Vector2i(rect.position.x + rng.randi_range(0, rect.size.x - 1),
				rect.position.y + rng.randi_range(0, rect.size.y - 1))
			if blocked.has(t) or used.has(t):
				continue
			if absi(t.x - entrance.x) + absi(t.y - entrance.y) <= MOB_SPAWN_CLEAR:
				continue
			tile = t
			break
		var kind := MobCatalog.roll_kind(pool, rng)   # ★자리를 못 찾아도 롤은 굴린다(스트림 고정)
		if tile == Vector2i(-1, -1) or kind == "":
			continue
		used[tile] = true
		out.append({"kind": kind, "tile": tile, "boss": false})
	return out

# 확정된 돌 목록 일부를 광맥으로 승격 — {Vector2i: 종 id}. MineFloors._scatter_nodes와 같은 문법이되
# 깊이 축(나락철 곡선)이 낀 표를 본다.
static func _scatter_nodes(rng: RandomNumberGenerator, depth: int, rocks: Array) -> Dictionary:
	var nodes: Dictionary = {}
	var pool := node_pool(depth)
	if rocks.is_empty() or pool.is_empty():
		return nodes
	var quota := mini(rng.randi_range(NODE_MIN, NODE_MAX), rocks.size())
	var total_w := 0
	for e: Dictionary in pool:
		total_w += int(e["weight"])
	if total_w <= 0:
		return nodes
	var chosen: Dictionary = {}
	var tries := 0
	while chosen.size() < quota and tries < quota * NODE_PICK_TRIES:
		tries += 1
		chosen[rng.randi_range(0, rocks.size() - 1)] = true
	var idx: Array = chosen.keys()
	idx.sort()
	for i: int in idx:
		var roll := rng.randi_range(0, total_w - 1)
		var pick: String = String(pool[pool.size() - 1]["id"])   # 폴백(도달 안 함)
		for e: Dictionary in pool:
			roll -= int(e["weight"])
			if roll < 0:
				pick = String(e["id"])
				break
		nodes[rocks[i]] = pick
	return nodes

static func _near(a: Vector2i, b: Vector2i) -> bool:
	return absi(a.x - b.x) + absi(a.y - b.y) <= 1

# ── 돌 파괴 → 사다리 / 구멍 롤 ───────────────────────────────────────────────
# ★ 확률 계산은 갱도 것을 **그대로 위임**한다(`MineFloors.ladder_chance` — base 2% + 남은 돌 역수 +
#   전멸 보너스). 수치를 복제하면 두 무대가 조용히 갈라지고, 무엇보다 "마지막 돌은 반드시 열린다"는
#   안전판(1/(0+1) = 1.0)이 나락에서 더 중요하다: 확정 하강 사다리가 없으니 그 보장이 유일한
#   "언젠가는 내려갈 수 있다"의 근거다.
static func roll_ladder(run: int, depth: int, tile: Vector2i, stones_left: int,
		mobs_cleared: bool = false, luck_bonus: float = 0.0) -> bool:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("narak_ladder:%d:%d:%d:%d" % [run, depth, tile.x, tile.y])
	return rng.randf() < MineFloors.ladder_chance(stones_left, mobs_cleared, luck_bonus)

# 열린 것이 사다리가 아니라 **구멍**인가(사다리 롤이 성공한 뒤에만 묻는다 — 20%).
static func roll_shaft(run: int, depth: int, tile: Vector2i) -> bool:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("narak_shaft:%d:%d:%d:%d" % [run, depth, tile.x, tile.y])
	return rng.randf() < SHAFT_CHANCE

# 이 구멍으로 몇 층을 떨어지나 — 3~8, 10%로 2x−1(5~15). ★소비 순서 고정: 기본 롤 → 배증 롤.
static func roll_fall_depth(run: int, depth: int, tile: Vector2i) -> int:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("narak_fall:%d:%d:%d:%d" % [run, depth, tile.x, tile.y])
	var n := rng.randi_range(SHAFT_MIN, SHAFT_MAX)
	if rng.randf() < SHAFT_DOUBLE_CHANCE:
		n = n * 2 - 1
	return n

# 낙하 피해(HP) — 건너뛴 층수 × 3. 순수 함수라 테스트가 공식을 직접 단언한다.
static func fall_damage(floors: int) -> int:
	return maxi(floors, 0) * FALL_DAMAGE_PER_FLOOR

# ── 원장 상태(전부 **런 한정** — 세이브 없음) ────────────────────────────────
signal changed()   # 채굴·사다리 개통·런 시작(main이 드로우·HUD 갱신)

var _run: int = 0              # 런 카운터(시드의 축 — 진입할 때마다 +1)
var _mined: Dictionary = {}    # {depth → {Vector2i: true}} 이번 런에 깬 돌
var _ladders: Dictionary = {}  # {depth → {Vector2i: true}} 돌을 깨 열린 사다리
var _shafts: Dictionary = {}   # {depth → {Vector2i: true}} 돌을 깨 뚫린 구멍(사다리와 별 목록)
var _node_hits: Dictionary = {}  # {depth → {Vector2i: 누적 타수}} 다타수 광맥의 진행

# 새 런을 연다 → 새 런 id. 이전 런의 기록은 **전량 소멸**한다(그게 리셋 런의 정의다).
func begin_run() -> int:
	_run += 1
	_mined = {}
	_ladders = {}
	_shafts = {}
	_node_hits = {}
	changed.emit()
	return _run

func run_id() -> int:
	return _run

# ── 채굴 기록 ────────────────────────────────────────────────────────────────
func is_mined(depth: int, tile: Vector2i) -> bool:
	return _mined.has(depth) and _mined[depth].has(tile)

func mark_mined(depth: int, tile: Vector2i) -> void:
	if not _mined.has(depth):
		_mined[depth] = {}
	_mined[depth][tile] = true
	if _node_hits.has(depth):
		_node_hits[depth].erase(tile)
	changed.emit()

func node_hits_done(depth: int, tile: Vector2i) -> int:
	if not _node_hits.has(depth):
		return 0
	return int(_node_hits[depth].get(tile, 0))

func add_node_hit(depth: int, tile: Vector2i) -> int:
	if not _node_hits.has(depth):
		_node_hits[depth] = {}
	var n := int(_node_hits[depth].get(tile, 0)) + 1
	_node_hits[depth][tile] = n
	changed.emit()
	return n

# 이 깊이에 **아직 남아 있는** 돌(배치 − 이번 런에 깬 것). 배치는 순수 함수에서 다시 파생한다.
func rocks_left(depth: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var layout := generate(_run, depth)
	if layout.is_empty():
		return out
	for t: Vector2i in layout["rocks"]:
		if not is_mined(depth, t):
			out.append(t)
	return out

func rocks_left_count(depth: int) -> int:
	return rocks_left(depth).size()

# ── 열린 하강 구멍/사다리(런 한정) ───────────────────────────────────────────
func add_ladder(depth: int, tile: Vector2i) -> void:
	if not _ladders.has(depth):
		_ladders[depth] = {}
	_ladders[depth][tile] = true
	changed.emit()

func add_shaft(depth: int, tile: Vector2i) -> void:
	if not _shafts.has(depth):
		_shafts[depth] = {}
	_shafts[depth][tile] = true
	changed.emit()

func has_ladder(depth: int, tile: Vector2i) -> bool:
	return _ladders.has(depth) and _ladders[depth].has(tile)

func has_shaft(depth: int, tile: Vector2i) -> bool:
	return _shafts.has(depth) and _shafts[depth].has(tile)

# 이 깊이의 하강 사다리 전부(축퇴 층의 확정 배치 + 돌을 깨 열린 것들). 정렬해 결정적으로 돌려준다.
func ladders(depth: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var layout := generate(_run, depth)
	if layout.is_empty():
		return out
	var fixed: Vector2i = layout["ladder"]
	if fixed.x >= 0:
		out.append(fixed)
	if _ladders.has(depth):
		var extra: Array = _ladders[depth].keys()
		extra.sort()
		for t: Vector2i in extra:
			if t != fixed:
				out.append(t)
	return out

# 이 깊이의 구멍 전부(정렬 — 결정적).
func shafts(depth: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if not _shafts.has(depth):
		return out
	var keys: Array = _shafts[depth].keys()
	keys.sort()
	for t: Vector2i in keys:
		out.append(t)
	return out
