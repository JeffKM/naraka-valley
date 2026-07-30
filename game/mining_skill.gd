extends RefCounted
class_name MiningSkill
# ★[S5-T2 / ADR-0063 결정 9] 채광 숙련도(스킬 0~10) 순수 규칙 — ForageSkill·FishSkill 대칭.
#
# 목적: ROADMAP Slice 5 — "갱도에서 곡괭이를 계속 휘두르면 *무엇이* 달라지는가"를 한 곳에 정의한다.
#       XP는 세이브 상태라 main이 스칼라(_mining_xp)로 들고(별도 노드 없음 — _farming_xp·_foraging_xp·
#       _fishing_xp 관례), 이 파일은 그 XP를 레벨·계수로 옮기고 **한 번의 파괴가 무엇을 떨구는지**를
#       결정하는 순수 함수만 든다(skill.gd·forage_skill.gd와 같은 결).
#
# 설계 메모(어기면 ADR-0063 결정 9 / ADR-0052 / ADR-0027 위반):
#   - **XP 곡선은 5스킬 공통 기반**(ADR-0052). 곡선의 단일 출처는 FarmSkill이고 여기선 *위임*만 한다
#     (수치 복제 0 — ForageSkill/FishSkill과 완전 동형). 숙련 탭도 FarmSkill 임계로 진행바를 그린다.
#   - **XP = 캔 것별 고정 테이블**(스타듀 상속 — 결정 9). "비싼 걸 캐면 더 배운다"가 아니라 종별
#     고정값이다. 판매가 축이 스킬 곡선에 새면 안 된다(ADR-0052 §1 — ForageSkill이 같은 이유로
#     기준가 방식을 걷어냈다). 명부금강 150이 큰 건 *가격*이 아니라 **사건의 희소성** 때문이다.
#   - **레벨 효과 = 혼력 감산 + 크리 채굴 둘뿐.** ❌품질 등급(광물은 품질 무차원 — ItemCatalog
#     MINERALS 주석) ❌+판매가 ❌레벨 게이팅(L0도 전 노드 100% 채굴 가능, "평평≠막힘" — ADR-0008).
#     혼력 감산이 여기 사는 이유 = **도구 티어는 타수·범위·접근만**이라는 ADR-0027 경계다
#     (곡괭이 티어가 혼력을 깎으면 두 축이 겹친다 — 티어는 S5-T3에서 `MineFloors.node_hits` 위에 얹힌다).
#   - **퍼크 해석은 여기, 퍼크 *보유*는 main.** 이 파일은 ProfessionCatalog를 읽지 않는다 — main이
#     `_perk_value`로 뽑은 float 하나를 넘기면 그 의미(광석 +N·쌍 확률)를 여기서 푼다
#     (ForageSkill.wood_bonus 선례 동형 — 상태 없는 해석기). ★퍼크 *값 인코딩*(ProfessionCatalog의
#     빈 perks 배열 채우기)은 S5-T8 소관이라, 지금 이 해석기들은 0(중립)만 받는다.
#   - **드랍 롤은 결정적**(day·층·칸 시드). 전역 randf 금지 — 같은 칸을 몇 번 물어도 같은 답이라
#     헤드리스가 정확히 재현한다(MineFloors.roll_ladder와 같은 규율).
#   - **노드 부류·타수는 MineFloors가 단일 출처**다. 여기선 그 부류를 *읽어* 드랍 규칙만 가른다
#     (배치는 원장의 몫, 산출은 스킬의 몫 — TreeLedger.chop이 ForageSkill 상수를 읽는 것의 역방향).

# ── 레벨 상한(FarmSkill.MAX_LEVEL과 같은 눈금 — 어긋나면 mining_test가 잡는다) ──
const MAX_LEVEL := 10

# ── 캔 것별 고정 XP(ADR-0063 결정 9 — 스타듀 Mining XP 1:1) ───────────────────
const XP_MYEONGDONG := 5        # 명동 광맥(기축 — 이 값이 곡선의 눈금이다)
const XP_YUCHEOL := 12          # 유철 광맥
const XP_HWANGCHEONGEUM := 18   # 황천금 광맥
# 나락철 50 — **갱도엔 안 나온다**(나락 전용). 표를 여기 두는 이유는 수치의 단일 출처가 늘 이
# 파일이기 때문이고(ForageSkill의 이끼·그루터기 XP 판단 동형), 소비처는 S5-T7이다.
const XP_NARAKCHEOL := 50
const XP_GEM := 16              # 넋수정·명옥(보통 보석)
const XP_GEM_YEOMJUSEOK := 40   # 염주석(상위 보석)
const XP_GEM_MYEONGBU := 150    # 명부금강(다이아 대응 — 하루에 한 번 볼까 말까 한 사건)
const XP_GEODE := 8             # 넋알돌 노드
const XP_GEODE_EOPHWA := 16     # 업화알돌 노드
const XP_HONTAN := 10           # 혼탄 광맥
const XP_STONE := 0             # 일반 돌 = 0(그냥 길 트기 — 배움이 아니다)
const XP_STONE_ORE := 5         # 단, 돌에서 광석이 딸려 나오면 그 사건엔 명동과 같은 5

# ── 일반 돌 산출(ADR-0063 결정 9 "돌 0(광석 부산출 시 5)") ────────────────────
const STONE_YIELD := 1          # 돌 1개(계단·업화로 재료 — 스타듀 1:1)
const STONE_ORE_CHANCE := 0.05  # 5% 확률로 명동 광석 1개 부산출(*잠정*)

# ── 광맥 드랍 수량(ADR-0063 결정 2 — *잠정*) ─────────────────────────────────
const ORE_MIN := 1              # 광석·혼탄 광맥 1~3개(결정 롤)
const ORE_MAX := 3
const GEM_YIELD := 1            # 보석·지오드는 1개(지질사 퍼크가 쌍으로 만든다)

# ── 레벨 계수(ADR-0063 결정 9) ────────────────────────────────────────────────
# 혼력 감산 3%/lv(ADR-0019 원문 예시 이행) — Lv10에서 곡괭이 1타가 혼력 10 → 7.
const ENERGY_CUT_PER_LEVEL := 0.03
const ENERGY_FACTOR_MIN := 0.5   # 안전 하한(레벨 상한이 10이라 도달하지 않는 방어값)
# 크리 채굴 = 광석이 2배로 쏟아지는 순간. 1%/lv라 Lv10에서 10%(*잠정*) — 채집꾼(20% 더블드롭)보다
# 얇은 이유는 이쪽이 **레벨만으로** 붙는 base 효과라서다(퍼크가 아니다).
const CRIT_PER_LEVEL := 0.01

# ── 조회(XP → 레벨) ─────────────────────────────────────────────────────────
# 누적 XP → 레벨(0..10). ★곡선은 FarmSkill이 단일 출처(ADR-0052 "5스킬 공통 기반") — 위임만 한다.
static func level_for_xp(xp: int) -> int:
	return FarmSkill.level_for_xp(xp)

# 레벨 임계 배열(숙련 탭·테스트 조회용 — 공통 곡선 재수출).
static func xp_thresholds() -> Array:
	return FarmSkill.XP_THRESHOLDS

# ── 혼력 감산 계수(FarmSkill.energy_factor 대칭) ─────────────────────────────
# 곡괭이 1타 비용 = COST_PER_ACTION × 이 계수. Lv0 = 1.0(감산 없음 — "평평≠막힘").
static func energy_factor(level: int) -> float:
	var lv := clampi(level, 0, MAX_LEVEL)
	return clampf(1.0 - ENERGY_CUT_PER_LEVEL * float(lv), ENERGY_FACTOR_MIN, 1.0)

# ── 크리 채굴 ────────────────────────────────────────────────────────────────
# 지금 레벨의 크리 확률(0..1). Lv0 = 0.0 = 절대 안 터진다(레벨이 곧 이 효과의 유일한 축).
static func crit_chance(level: int) -> float:
	return clampf(CRIT_PER_LEVEL * float(clampi(level, 0, MAX_LEVEL)), 0.0, 1.0)

# 이 칸을 부술 때 크리가 터지나. 시드에 **(day, 층, 칸)**을 물려 같은 자리면 몇 번을 물어도 같은
# 답이다(MineFloors.roll_ladder와 같은 규율 — 헤드리스 재현성).
# ★[S5-T7] `ns`는 **무대 네임스페이스**다("mine" = 갱도 / "narak" = 나락). 나락은 (run, depth)를
#   (day, floor) 자리에 넘기는데, 접두사가 없으면 run 3·깊이 7이 day 3·7층과 같은 시드를 받아
#   두 무대의 결과가 붙어 버린다. 기본값이 "mine"이라 기존 호출부는 한 줄도 안 바뀐다(회귀 0).
static func roll_crit(day: int, floor_no: int, tile: Vector2i, level: int, ns: String = "mine") -> bool:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s_crit:%d:%d:%d:%d" % [ns, day, floor_no, tile.x, tile.y])
	return rng.randf() < crit_chance(level)

# ── 캔 것 → XP ──────────────────────────────────────────────────────────────
# 노드 종 id → 고정 XP. ""(일반 돌) = 0(광석 부산출분은 resolve_drop이 따로 얹는다).
static func xp_for_node(node_id: String) -> int:
	match node_id:
		MineFloors.N_MYEONGDONG: return XP_MYEONGDONG
		MineFloors.N_YUCHEOL: return XP_YUCHEOL
		MineFloors.N_HWANGCHEONGEUM: return XP_HWANGCHEONGEUM
		MineFloors.N_HONTAN: return XP_HONTAN
		MineFloors.N_GEODE_NEOKAL: return XP_GEODE
		MineFloors.N_GEODE_EOPHWA: return XP_GEODE_EOPHWA
		MineFloors.N_GEM_NEOKSUJEONG, MineFloors.N_GEM_MYEONGOK: return XP_GEM
		MineFloors.N_GEM_YEOMJUSEOK: return XP_GEM_YEOMJUSEOK
		MineFloors.N_GEM_MYEONGBU: return XP_GEM_MYEONGBU
		ItemCatalog.ORE_NARAKCHEOL: return XP_NARAKCHEOL   # ★S5-T7 나락 소관(갱도 미출현)
	return XP_STONE

# ── 파괴 1회의 산출(순수·결정적) ─────────────────────────────────────────────
# 반환 = {"drops": [{"id", "count"}...], "xp": int, "crit": bool}.
#   node_id  = "" 이면 일반 돌(돌 1개 + 5% 명동 부산출), 아니면 광맥 종 id
#   level    = 채광 레벨(크리 확률의 유일한 축)
#   ore_bonus_n / gem_pair = main이 `_perk_value`로 뽑아 넘긴 퍼크 값의 해석 결과
#                            (광부 "광맥당 +1" · 지질사 "보석 쌍 확률" — 실 인코딩은 S5-T8)
# ★ main이 인벤토리·알림·XP 적립을 하고, 여기선 "무엇이 몇 개 나오나"만 정한다(무상태).
# ★[S5-T7] `ns` = 무대 네임스페이스(roll_crit 주석 참조 — 기본 "mine"이라 기존 호출부 불변).
static func resolve_drop(node_id: String, day: int, floor_no: int, tile: Vector2i,
		level: int, ore_bonus_n: int = 0, gem_pair: float = 0.0, ns: String = "mine") -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s_drop:%d:%d:%d:%d" % [ns, day, floor_no, tile.x, tile.y])
	var drops: Array = []
	var out := {"drops": drops, "xp": 0, "crit": false}
	if node_id == "":
		# 일반 돌 — 돌 1개는 확정, 5%로 명동 광석이 딸려 나온다(그 사건에만 XP 5).
		drops.append({"id": ItemCatalog.STONE, "count": STONE_YIELD})
		if rng.randf() < STONE_ORE_CHANCE:
			drops.append({"id": ItemCatalog.ORE_MYEONGDONG, "count": 1})
			out["xp"] = XP_STONE_ORE
		return out
	# ★[S5-T7] 갱도 표에 없는 종은 나락 표에 되묻는다 — 나락철이 "광석"으로 굴러가는 유일한 접점이다
	#   (없으면 나락철이 보석 취급을 받아 1개씩만 나온다: 이리듐 대응 티어가 조용히 반토막 나는 자리).
	var cls := MineFloors.node_class(node_id)
	if cls == "":
		cls = NarakFloors.node_class(node_id)
	var count := GEM_YIELD
	if cls == MineFloors.NODE_ORE or cls == MineFloors.NODE_COAL:
		count = rng.randi_range(ORE_MIN, ORE_MAX) + maxi(ore_bonus_n, 0)   # 광부 퍼크 +N
		if roll_crit(day, floor_no, tile, level, ns):
			count *= 2                                                     # ★크리 채굴 = 광석 2배
			out["crit"] = true
	elif cls == MineFloors.NODE_GEM and rng.randf() < clampf(gem_pair, 0.0, 1.0):
		count = 2                                                          # 지질사 퍼크 — 보석 쌍
	drops.append({"id": node_id, "count": count})
	out["xp"] = xp_for_node(node_id)
	return out

# ── ★[S5-T3 / ADR-0063 결정 2·3] 지오드(알돌) 개봉 — 대장간 서비스 개당 25냥 ────
# 클린트 1:1의 저승판. **여기 사는 이유**: 개봉은 "무엇이 몇 개 나오나"의 순수 롤이라 드랍
# 규칙(resolve_drop)과 같은 축이고, 값(25냥)·차감·창구는 main과 점주 레코드의 몫이다.
#
# 설계 메모:
#   - **결정적 시드 = 개봉 카운터**다(`hash("geode:<id>:<n>")`). day·좌표를 쓸 수 없다 —
#     지오드는 인벤토리 아이템이라 "언제 어디서 깨나"가 플레이어 자유고, day 시드면 같은 날
#     같은 종을 몇 개 깨도 전부 같은 결과가 나온다(재롤 없음이 아니라 **차이 없음**이라 나쁘다).
#     카운터는 세이브 상태(main._geode_opened)이므로 한 번 쓴 시드는 다시 안 나온다 = 재롤 차단.
#   - **두 종의 분포가 실제로 다르다**(업화알돌 = 상위 금속·상위 보석·명부금강 비중↑). 같은 표에
#     가중치만 바꾼 게 아니라 **품목 자체가 갈린다** — 41층+ 알돌이 "더 깊은 것"으로 읽히게.
#   - **유물(유품) 저확률**: ADR-0063 결정 2가 "내용 = 광물·보석·유물(유품 저확률 — 혼백관 기증
#     사슬)"로 명시했다. RELICS 3종에서 결정 롤이라 혼백관 수집이 괭이질 외 경로를 하나 얻는다.
#   - 발굴자(지오드 2배)·보석사(보석 등급) 퍼크는 **인자 자리만** 열려 있다(값 인코딩 = S5-T8).
const GEODE_COST := 25          # 개봉 수수료(엽전 — 스타듀 클린트 25G 1:1)

# 넋알돌(1~40층) 표 — {id, weight}. 하위·중위 금속과 흔한 보석이 주류다.
static func geode_table_neokal() -> Array:
	return [
		{"id": ItemCatalog.STONE, "weight": 18},
		{"id": ItemCatalog.ORE_MYEONGDONG, "weight": 20},
		{"id": ItemCatalog.ORE_YUCHEOL, "weight": 14},
		{"id": ItemCatalog.HONTAN, "weight": 14},
		{"id": ItemCatalog.GEM_NEOKSUJEONG, "weight": 12},
		{"id": ItemCatalog.GEM_MYEONGOK, "weight": 8},
		{"id": ItemCatalog.GEM_YEOMJUSEOK, "weight": 4},
		{"id": ItemCatalog.RELIC_BINYEO, "weight": 2},      # 유품 저확률(혼백관 기증 사슬)
		{"id": ItemCatalog.RELIC_SPOON, "weight": 2},
		{"id": ItemCatalog.RELIC_KKOTSIN, "weight": 2},
	]

# 업화알돌(41층+·나락) 표 — 상위 금속·상위 보석 중심. 하위 금속·돌은 **빠진다**(깊이의 값).
static func geode_table_eophwa() -> Array:
	return [
		{"id": ItemCatalog.ORE_YUCHEOL, "weight": 16},
		{"id": ItemCatalog.ORE_HWANGCHEONGEUM, "weight": 22},
		{"id": ItemCatalog.HONTAN, "weight": 12},
		{"id": ItemCatalog.GEM_MYEONGOK, "weight": 12},
		{"id": ItemCatalog.GEM_YEOMJUSEOK, "weight": 16},
		{"id": ItemCatalog.GEM_MYEONGBU_GEUMGANG, "weight": 8},
		{"id": ItemCatalog.GEM_OSAEK_HONOK, "weight": 2},   # 오색혼옥의 **첫 획득 경로**(초희귀)
		{"id": ItemCatalog.RELIC_BINYEO, "weight": 4},
		{"id": ItemCatalog.RELIC_SPOON, "weight": 4},
		{"id": ItemCatalog.RELIC_KKOTSIN, "weight": 4},
	]

# 이 지오드 id의 개봉 표(빈 배열 = 지오드가 아니다).
static func geode_table(geode_id: String) -> Array:
	match geode_id:
		ItemCatalog.GEODE_NEOKAL:
			return geode_table_neokal()
		ItemCatalog.GEODE_EOPHWA:
			return geode_table_eophwa()
	return []

static func is_geode(geode_id: String) -> bool:
	return not geode_table(geode_id).is_empty()

# 개봉 1회의 산출(순수·결정적). 반환 = {"id", "count"}({} = 지오드 아님).
#   counter    = 이 세이브의 누적 개봉 횟수(시드 — 같은 값이면 같은 답, 늘어나면 새 롤)
#   double_ch  = 발굴자 퍼크 "지오드 2배" 확률(0..1 — 값 인코딩 S5-T8까지 0.0)
static func open_geode(geode_id: String, counter: int, double_ch: float = 0.0) -> Dictionary:
	var table := geode_table(geode_id)
	if table.is_empty():
		return {}
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("geode:%s:%d" % [geode_id, counter])
	var total := 0
	for e: Dictionary in table:
		total += int(e["weight"])
	var roll := rng.randi_range(0, total - 1)
	var pick := String(table[table.size() - 1]["id"])   # 폴백(정수 롤이라 도달 안 함)
	for e: Dictionary in table:
		roll -= int(e["weight"])
		if roll < 0:
			pick = String(e["id"])
			break
	var n := 1
	# 유품은 **절대 2개로 늘리지 않는다** — 혼백관은 종당 1점이라 두 번째는 죽은 판매품이 된다.
	if not ItemCatalog._is_relic(pick) and rng.randf() < clampf(double_ch, 0.0, 1.0):
		n = 2
	return {"id": pick, "count": n}

# 발굴자(DIM_EXCAVATE) — 지오드 개봉 2배 확률(0..1). ★차원 상수 자체는 S5-T8이 신설한다
#   (지금은 main이 0.0을 넘기는 인자 자리 — ore_bonus·gem_pair 해석기와 같은 결).
static func geode_double_chance(perk: float) -> float:
	return clampf(perk, 0.0, 1.0)

# ── 퍼크 해석(main._perk_value가 뽑은 float → 의미) ──────────────────────────
# ★ 지금은 셋 다 0(중립)만 들어온다 — ProfessionCatalog의 채광 트리 perks가 아직 비어 있고
#   그 인코딩이 S5-T8 소관이기 때문이다. ForageSkill의 "미배선 퍼크 3종"과 정확히 같은 자리로,
#   T8은 카탈로그 데이터만 채우면 아래 해석기와 main의 조회가 그대로 실효된다(호출부 무변경).
# 광부(DIM_ORE_BONUS) — 광맥당 광석 +N. 카탈로그 정의값이 곧 N이다(수치 복제 0).
static func ore_bonus(perk: float) -> int:
	return int(maxf(perk, 0.0))

# 지질사(DIM_GEM_PAIR) — 보석이 쌍으로 나올 확률(0..1).
static func gem_pair_chance(perk: float) -> float:
	return clampf(perk, 0.0, 1.0)
