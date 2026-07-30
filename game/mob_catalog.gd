extends RefCounted
class_name MobCatalog
# ★[S5-T5 / ADR-0063 결정 8] 잡귀 로스터 — 갱도 6종(밴드당 2 · 행동 아키타입 4 커버).
#
# 목적: "무엇이 어느 깊이에 나오고, 몇 대 맞으면 죽고, 얼마나 아프고, 어떻게 움직이는가"의 단일
#       출처. WeaponCatalog(무기 5종)·FishCatalog(어종)와 **문법이 1:1**이다 — 순수 static 데이터 +
#       조회. 개체 상태(위치·HP·행동 위상)는 Mob(mob.gd)이 들고, 배치는 MineFloors가 굴린다.
#
# 세 파일의 경계(어기면 T5 설계가 무너진다):
#   · MobCatalog(여기) = **종 데이터**. 무대·좌표·시계·인벤토리·렌더를 하나도 모른다.
#   · Mob(mob.gd)      = **개체 상태 + 행동 스텝**(순수 함수 — 입력은 dt·플레이어 위치·지형 콜백뿐).
#   · MineFloors       = **배치**(층 생성 시 결정 롤로 "어디에 무엇이 서는가"만).
#   · main             = **배선**(틱 폴링·접촉 피해·스윙 판정·드랍·그레이박스 렌더).
#
# 설계 메모(어기면 ADR-0063 결정 8·9 / ADR-0031 결정 3 위반):
#   - **갱도 잡귀는 관계-중립**이다. 이 파일엔 바나·affinity·호감도 참조가 한 줄도 없고, 처치 보상은
#     전투 base XP + 자재 드랍뿐이다(나락만 바나 도메인 — ADR-0031 결정 3).
#   - **나락 강몹 3종(야차·나찰·아귀)·보스 3기는 여기 없다** — S5-T7 소관이다(ADR-0063 결정 8 후단).
#     갱도 로스터에 섞으면 밴드 게이팅이 갱도 60층 축을 벗어나 버린다.
#   - **아키타입은 4개뿐**이다(통통·추적·위장·원거리). 표의 6종은 이 넷 위에 *플래그*(배회·넉백
#     저항·돌 부수기)를 얹어 갈린다 — 새 아키타입을 만들지 않는 이유는 ADR-0063이 "아키타입 4 커버"로
#     못 박았고, 행동 코드가 6갈래로 갈리면 결정적 스텝 검증이 6배로 늘기 때문이다.
#     · 그슨대 "배회·충돌" = 추적 + `wanders`(어그로 밖에선 어슬렁) + `breaks_rocks`(막히면 돌을 깬다)
#     · 불가사리 "넉백 저항·중장" = 추적 + `kb_resist`(★넉백 축 자체가 장비 클러스터 서랍이라
#       지금은 플래그 보관 — ADR-0063 결정 4 "몹 체급별 넉백 차이는 서랍")
#   - **HP/데미지/XP는 ADR-0063 결정 8 표 그대로**(스타듀 대응 몹 1:1 상속). 이동 속도·어그로 반경·
#     점프 주기·사거리·드랍률은 표에 없던 값이라 *이 태스크가 새로 정한 잠정치*다(아래 주석에 근거).
#   - 그레이박스 색은 여기 두지 않는다 — main의 `_MOB_COLORS`가 든다(`_MINE_NODE_COLORS` 선례:
#     카탈로그는 렌더를 모른다).

# ── 행동 아키타입(4종 — ADR-0063 결정 8) ─────────────────────────────────────
const ARCH_HOP := "hop"            # 통통 접근·점프 돌진(멈춤 ↔ 짧은 돌진 반복 — Green Slime 결)
const ARCH_CHASE := "chase"        # 등속 추적(부유·중장·배회형이 공유하는 축 — Bat/Golem/Metal Head)
const ARCH_DISGUISE := "disguise"  # 바위 위장(정지·무해 → 곡괭이 타격으로 활성화 — Rock Crab)
const ARCH_RANGED := "ranged"      # 원거리 화염구(제자리·사거리 안이면 발사 — Squid Kid)
const ARCHETYPES := [ARCH_HOP, ARCH_CHASE, ARCH_DISGUISE, ARCH_RANGED]

# ── 종 id(코드용 안정 id — 세이브엔 안 들어간다: 몹은 층 한정 비영속) ─────────
const HEOTGEOT := "mob_heotgeot"        # 헛것(1층+ · Green Slime 대응)
const EODUKKAEBI := "mob_eodukkaebi"    # 어둑깨비(11층+ · Bat 대응)
const DALGYAL := "mob_dalgyal"          # 달걀귀신(21층+ · Rock Crab 대응)
const GEUSEUNDAE := "mob_geuseundae"    # 그슨대(21층+ · Stone Golem 대응)
const BULGASARI := "mob_bulgasari"      # 불가사리(41층+ · Metal Head 대응)
const HWAGWI := "mob_hwagwi"            # 화귀(41층+ · Squid Kid 대응)

# ── 잡귀 부산물 2종(★신설 아이템 — ItemCatalog.MATERIALS에 등록) ─────────────
# "잡귀를 잡으면 무엇이 남는가"의 자리. 카페·제작 하류 소재이고 **품질 무차원 CAT_MATERIAL**이다
# (원목·수액·광물과 같은 판단 — 품질은 줍기·릴 격투의 축). id 상수는 ItemCatalog가 진실원이라
# 여기서는 **문자열 리터럴로 둔다**(const 초기화식에서 타 클래스 상수를 안 읽는 이 저장소의 관례 —
# main.MINE_ROCK_COST 주석과 같은 이유). mob_test가 `ItemCatalog.has_item`으로 두 쪽을 대조한다.
const DROP_NEOKGARU := "neokgaru"       # 넋가루 — 흩어진 잡귀가 남기는 회백색 가루(범용)
const DROP_HONBULSSI := "honbulssi"     # 혼불씨 — 잡귀 속에 남은 불씨(심층 종 산출)

# ── 종 표(ADR-0063 결정 8 — HP/데미지/XP는 원문 그대로) ──────────────────────
# 스키마:
#   name_ko    : 표시명(*명명 전부 잠정* — ADR-0063 결정 8 owner 큐)
#   arch       : 위 4 아키타입 중 하나
#   hp         : 최대 HP(★ADR 표 그대로)
#   damage     : 플레이어에게 주는 **고정 데미지**(변동 롤 없음 — ADR-0063 결정 4)
#   xp         : 처치 전투 XP(★ADR 표 그대로 · 관계-중립 base)
#   floor_min  : 출현 시작 층 · floor_max: 0 = 무제한(상위 종이 하위를 대체하지 않고 얹힌다 — 노드 결)
#   weight     : 스폰 가중(같은 밴드 안 등장 비율)
#   speed      : 이동 속도(px/s · 0 = 제자리). ★플레이어 160px/s 대비
#   aggro      : 어그로 반경(칸). 이 안에 들어오면 추적·발사가 시작된다
#   wanders    : 어그로 밖에서 어슬렁거리나(false = 제자리 대기)
#   kb_resist  : 넉백 저항(★플래그 보관 — 넉백 축은 장비 클러스터 서랍)
#   breaks     : 길이 막히면 일반 돌을 부수나(★부순 바위 = 채광 XP 0 — ADR-0063 결정 9)
#   reach      : 원거리 사거리(칸 · 0 = 근접 전용)
#   cooldown   : 발사 간격(초 · 원거리 전용)
#   shot_speed : 화염구 속도(px/s · 원거리 전용)
#
# ★ 잠정치의 근거(ADR 표에 없어 이 태스크가 정한 값 — 보고에 목록화됨):
#   · 속도는 **전부 플레이어(160px/s)보다 느리다**. 스타듀 갱도의 계약이 "도망칠 수 있다"이고,
#     추격을 못 떼면 이중 시계(채굴 ↔ 전투)가 전투 일방으로 무너진다.
#     헛것 = 돌진 순간만 빠르고 평균이 느림 / 어둑깨비 = 가장 빠름(박쥐) / 그슨대 = 가장 느림(골렘).
#   · 어그로 반경 6~9칸 = 화면 반쪽(내부해상도 640×360 → 20×11칸). "화면에 보이면 온다"가 기준.
#   · 화귀는 HP 1 유리대포라 **접근 전 처리**가 정답이 되게 사거리(7)를 어그로 밖으로 두지 않았다.
const MOBS := {
	HEOTGEOT: {
		"name_ko": "헛것", "arch": ARCH_HOP,
		"hp": 24, "damage": 5, "xp": 3,
		"floor_min": 1, "floor_max": 0, "weight": 40,
		"speed": 120.0, "aggro": 7.0, "wanders": true, "kb_resist": false, "breaks": false,
		"reach": 0.0, "cooldown": 0.0, "shot_speed": 0.0,
	},
	EODUKKAEBI: {
		"name_ko": "어둑깨비", "arch": ARCH_CHASE,
		"hp": 24, "damage": 6, "xp": 3,
		"floor_min": 11, "floor_max": 0, "weight": 34,
		"speed": 110.0, "aggro": 9.0, "wanders": true, "kb_resist": false, "breaks": false,
		"reach": 0.0, "cooldown": 0.0, "shot_speed": 0.0,
	},
	DALGYAL: {
		"name_ko": "달걀귀신", "arch": ARCH_DISGUISE,
		"hp": 30, "damage": 5, "xp": 4,
		"floor_min": 21, "floor_max": 0, "weight": 22,
		"speed": 60.0, "aggro": 6.0, "wanders": false, "kb_resist": false, "breaks": false,
		"reach": 0.0, "cooldown": 0.0, "shot_speed": 0.0,
	},
	GEUSEUNDAE: {
		"name_ko": "그슨대", "arch": ARCH_CHASE,
		"hp": 45, "damage": 8, "xp": 5,
		"floor_min": 21, "floor_max": 0, "weight": 26,
		"speed": 48.0, "aggro": 8.0, "wanders": true, "kb_resist": false, "breaks": true,
		"reach": 0.0, "cooldown": 0.0, "shot_speed": 0.0,
	},
	BULGASARI: {
		"name_ko": "불가사리", "arch": ARCH_CHASE,
		"hp": 40, "damage": 15, "xp": 6,
		"floor_min": 41, "floor_max": 0, "weight": 26,
		"speed": 84.0, "aggro": 9.0, "wanders": true, "kb_resist": true, "breaks": false,
		"reach": 0.0, "cooldown": 0.0, "shot_speed": 0.0,
	},
	HWAGWI: {
		"name_ko": "화귀", "arch": ARCH_RANGED,
		"hp": 1, "damage": 18, "xp": 15,
		"floor_min": 41, "floor_max": 0, "weight": 18,
		"speed": 0.0, "aggro": 7.0, "wanders": false, "kb_resist": false, "breaks": false,
		"reach": 7.0, "cooldown": 2.2, "shot_speed": 96.0,
	},
}

# 밴드 순 id 목록(테스트·아트 로스터 순회의 단일 출처 — dict 삽입 순서를 신뢰하지 않는다).
const _ORDER := [HEOTGEOT, EODUKKAEBI, DALGYAL, GEUSEUNDAE, BULGASARI, HWAGWI]

# ── 드랍 표(*드랍률·수량 전부 잠정* — 스타듀 대응 몹 상속) ────────────────────
# 스키마: [{id, chance(0~1), min, max}] — 항목마다 독립 롤(한 몹이 둘 다 흘릴 수 있다).
# ★ 신규 아이템은 2종(넋가루·혼불씨)뿐이고 나머지는 **기존 광물 재사용**이다: 달걀귀신·그슨대가
#   돌을 흘리고(Rock Crab·Stone Golem 1:1) 불가사리가 유철 광석을 흘린다(Metal Head 1:1).
#   아이템 남발 없이 "잡귀도 채광 경제에 흘러든다"가 성립한다.
# ★ id를 리터럴로 두는 이유 = DROP_* 상수와 같다(const 초기화식 관례).
const DROPS := {
	HEOTGEOT: [{"id": DROP_NEOKGARU, "chance": 0.70, "min": 1, "max": 2}],
	EODUKKAEBI: [{"id": DROP_HONBULSSI, "chance": 0.55, "min": 1, "max": 1}],
	DALGYAL: [
		{"id": "stone", "chance": 0.60, "min": 1, "max": 2},
		{"id": DROP_NEOKGARU, "chance": 0.25, "min": 1, "max": 1},
	],
	GEUSEUNDAE: [
		{"id": "stone", "chance": 0.75, "min": 1, "max": 3},
		{"id": DROP_NEOKGARU, "chance": 0.30, "min": 1, "max": 1},
	],
	BULGASARI: [
		{"id": "ore_yucheol", "chance": 0.40, "min": 1, "max": 1},
		{"id": DROP_HONBULSSI, "chance": 0.40, "min": 1, "max": 1},
	],
	HWAGWI: [
		{"id": DROP_HONBULSSI, "chance": 0.80, "min": 1, "max": 2},
		{"id": DROP_NEOKGARU, "chance": 0.30, "min": 1, "max": 1},
	],
}

# ── 조회 ─────────────────────────────────────────────────────────────────────
static func has(kind: String) -> bool:
	return MOBS.has(kind)

static func kinds() -> Array:
	return _ORDER

static func name_of(kind: String) -> String:
	return String(MOBS[kind]["name_ko"]) if has(kind) else ""

static func arch_of(kind: String) -> String:
	return String(MOBS[kind]["arch"]) if has(kind) else ""

static func max_hp(kind: String) -> int:
	return int(MOBS[kind]["hp"]) if has(kind) else 0

# 플레이어에게 주는 고정 데미지(ADR-0063 결정 4 — 변동 롤 없음).
static func damage_of(kind: String) -> int:
	return int(MOBS[kind]["damage"]) if has(kind) else 0

# 처치 전투 XP(관계-중립 base — ADR-0031 결정 3).
static func xp_of(kind: String) -> int:
	return int(MOBS[kind]["xp"]) if has(kind) else 0

static func speed_of(kind: String) -> float:
	return float(MOBS[kind]["speed"]) if has(kind) else 0.0

static func aggro_tiles(kind: String) -> float:
	return float(MOBS[kind]["aggro"]) if has(kind) else 0.0

static func wanders(kind: String) -> bool:
	return bool(MOBS[kind]["wanders"]) if has(kind) else false

# 넉백 저항 — ★플래그 보관. 넉백 감쇠 배선은 장비 클러스터 서랍이 열릴 때(ADR-0063 결정 4).
static func kb_resist(kind: String) -> bool:
	return bool(MOBS[kind]["kb_resist"]) if has(kind) else false

# 길이 막히면 일반 돌을 부수나(★그슨대 하나 — 부순 바위 = 채광 XP 0, ADR-0063 결정 9).
static func breaks_rocks(kind: String) -> bool:
	return bool(MOBS[kind]["breaks"]) if has(kind) else false

static func reach_tiles(kind: String) -> float:
	return float(MOBS[kind]["reach"]) if has(kind) else 0.0

static func cooldown_of(kind: String) -> float:
	return float(MOBS[kind]["cooldown"]) if has(kind) else 0.0

static func shot_speed(kind: String) -> float:
	return float(MOBS[kind]["shot_speed"]) if has(kind) else 0.0

static func is_ranged(kind: String) -> bool:
	return arch_of(kind) == ARCH_RANGED

# 위장형인가 — 스폰 직후 무해·부동이고 곡괭이 타격으로 깨어난다(Mob.awake).
static func is_disguise(kind: String) -> bool:
	return arch_of(kind) == ARCH_DISGUISE

# ── 밴드 게이팅(MineFloors 배치가 읽는 유일한 접점) ──────────────────────────
# 이 층에 나올 수 있는 종 목록(표 순서 보존 = 결정적). 노드 `MineFloors.node_pool`과 완전 동형이다.
static func spawn_pool(floor_no: int) -> Array:
	var out: Array = []
	for kind: String in _ORDER:
		var e: Dictionary = MOBS[kind]
		if floor_no < int(e["floor_min"]):
			continue
		var fmax := int(e["floor_max"])
		if fmax > 0 and floor_no > fmax:
			continue
		out.append(kind)
	return out

static func weight_of(kind: String) -> int:
	return int(MOBS[kind]["weight"]) if has(kind) else 0

# 가중 롤 — rng를 **인자로 받는다**(시드 소유·순차 소비 순서는 배치 쪽 책임. WeaponCatalog.roll_damage
# 와 같은 판단). 풀이 비면 ""(호출 측이 스폰을 건너뛴다).
static func roll_kind(pool: Array, rng: RandomNumberGenerator) -> String:
	if pool.is_empty():
		return ""
	var total := 0
	for kind: String in pool:
		total += weight_of(kind)
	if total <= 0:
		return ""
	var roll := rng.randi_range(0, total - 1)
	for kind: String in pool:
		roll -= weight_of(kind)
		if roll < 0:
			return kind
	return String(pool[pool.size() - 1])

# ── 처치 드랍(순수·결정적) ───────────────────────────────────────────────────
# 반환 = [{"id": String, "count": int}]. 시드는 호출 측이 만든다(main은 day·층·스폰 인덱스를 엮어
# 넘긴다 — 좌표 해시 금지 규율은 몹에도 그대로 적용된다: 이웃 몹이 연속값을 받으면 안 된다).
# ★ RNG 순차 소비: 표 순서대로 ①확률 롤 → ②수량 롤. 순서를 바꾸면 같은 시드가 다른 답을 낸다.
static func roll_drops(kind: String, seed_value: int) -> Array:
	var out: Array = []
	if not has(kind):
		return out
	var table: Array = DROPS.get(kind, [])
	if table.is_empty():
		return out
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("mob_drop:%s:%d" % [kind, seed_value])
	for e: Dictionary in table:
		var hit := rng.randf() < float(e["chance"])
		var n := rng.randi_range(int(e["min"]), int(e["max"]))
		if hit and n > 0:
			out.append({"id": String(e["id"]), "count": n})
	return out
