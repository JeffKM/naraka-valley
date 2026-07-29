extends RefCounted
class_name TreeLedger
# ★[S4-T3 / ADR-0062 결정 3] 나무 원장 — "지금 어느 칸에 어떤 나무가 몇 단계로 서 있나"만 소유하는
# 얇은 원장(ledger).
#
# 목적: ADR-0062 결정 3("벌목 = 나무 원장 + 코지 재성장, 경계 밴드는 불벌목")의 빌드 형태. 정적
#       장식이던 TREE를 **이원화**해서, 맵 테두리 프레이밍 밴드는 벽으로 남기고 *내부* 나무만 이
#       원장이 가져간다. 자라고·베이고·그루터기가 남고·다시 돋는 하루 사이클 전부를 이 파일이 든다.
#
# 왜 별개 원장인가(ForageSpawns/CrabPotLedger/Reclaim 동형 완전 분리):
#   - 나무 상태는 **플레이어 세이브 델타**다(배치 시드는 맵 빌더가 든다). 이 원장은 "어느 구역·어느
#     칸에 무슨 종이 몇 단계로 있나"만 알고, 지형·화면·인벤토리·혼력·전문직·도구를 하나도 모른다.
#     통행 판정·그리드 동기화·산출 적재는 전부 main이 하고, 퍼크 값은 chop 인자로 *주입*된다
#     (디커플링 — Reclaim이 후보 칸을 main에서 받는 것과 같은 결).
#   - **RefCounted(비-Node)**: ForageSpawns와 같은 판단 — 설치물이 아니라 순수 데이터라 씬 트리에
#     설 이유가 없다. main이 참조로 들고 질의한다.
#   - **개간(Reclaim)의 석화 고목과는 별개**다(ADR-0062 결정 3 "역할 분리"). 그건 1회성 debris이고
#     이건 재성장하는 자원이다 — 드랍(PETRIFIED_WOOD)도 다르고 원장도 다르다.
#
# 설계 메모(어기면 ADR-0062 결정 3 위반):
#   - **슬롯 모델**: 키가 있으면 슬롯이고, `stage 0 · stump false` = **빈 슬롯**(베어 없앤 자리)이다.
#     숲의 재성장은 *빈 슬롯*에서만 일어난다 — 원장이 "여긴 원래 나무 자리였다"를 기억하는 셈이라
#     길·빈터·워프 칸이 나무로 메워질 수 없다(맵 불변식의 구조적 보증).
#   - **결정 롤**: day + 구역 + 좌표 시드(ForageSpawns/CrabPotLedger 선례). 전역 randf 금지 —
#     같은 날 같은 칸은 몇 번을 굴려도 같은 결과라 헤드리스가 정확히 재현한다.
#   - **재성장 이원**(스타듀 농장/비농장 구분 그대로): 숲 = 빈 슬롯 20%/일 stage3 재출현 /
#     안식 농원 = 성숙목이 밤 15%로 반경 3칸 빈 칸에 자체 파종(stage1). 민둥산 죄책감 방지
#     (ADR-0033 "코지 재성장")의 실수치다.
#   - **혼력은 여기 없다**. 나무 작업 = 혼력 소모(ADR-0033)지만 그 소모는 main의 몫이다 —
#     이 파일이 SoulEnergy를 모르는 것이 "원장은 규칙만"의 구조적 보증이다.
#   - **XP는 반환만 한다**(마지막 타에만 CHOP_XP). 적립은 main._gain_forage_xp — ForageSkill이
#     고정 테이블의 단일 출처고 여긴 그 상수를 참조만 한다(수치 복제 0).

signal changed()   # 벌목·성장·재성장·파종·복원한 프레임(main이 듣고 그리드·충돌·드로우 갱신)

# ── 종 3(ADR-0062 결정 3 — CONTEXT [저승 삼목] 잠정 명명 그대로) ─────────────
const SP_PINE := "jeoseung_pine"    # 저승솔(소나무 대응 · 수액 솔넋진 5일 — 주기는 S4-T6)
const SP_MAPLE := "myeong_maple"    # 명단풍(단풍 대응 · 수액 명단풍꿀 9일)
const SP_OAK := "neok_oak"          # 넋참나무(참나무 대응 · 수액 넋수지 7일)
const SPECIES := [SP_PINE, SP_MAPLE, SP_OAK]
const SPECIES_NAMES := {SP_PINE: "저승솔", SP_MAPLE: "명단풍", SP_OAK: "넋참나무"}

# ── 성장 5단계(단계당 20%/일 — 스타듀 성숙 중앙값 24일 상속) ────────────────
const MAX_STAGE := 5          # 성숙(벌목 정타수·수액 채취 자격 — 자격 판정은 S4-T6)
const STAGE_EMPTY := 0        # 빈 슬롯(벤 자리 — 숲 재성장 후보)
const REGROW_STAGE := 3       # 숲 재출현 단계(묘목이 아니라 "어느새 중간 나무" — 코지)
const GROWTH_CHANCE := 0.20   # 미성숙목이 하루에 한 단계 오를 확률
const REGROW_CHANCE := 0.20   # 숲 빈 슬롯이 하루에 stage3로 되살아날 확률
const SEED_CHANCE := 0.15     # 안식 성숙목이 밤에 자체 파종할 확률
const SEED_RADIUS := 3        # 자체 파종 반경(칸 — 체비쇼프)
const HOME_CAP := 40          # 안식 원장 나무 총상한(자체 파종 폭주 방지 — 마당이 숲이 되지 않게)

# ── ★[S4-T8 / ADR-0062 결정 9 ㉡] 저승 이끼 ─────────────────────────────────
# "저비용 상시 자원"(카탈로그 §1-C)이라 **성숙목에만** 끼고, 낫 한 번에 벗겨지고, 며칠 뒤 다시 낀다.
# 성숙목 한정인 이유 = 자라는 중인 유목·베어 낸 그루터기·큰 장애물은 이끼가 앉을 몸이 아니고, 무엇보다
# "다 큰 나무를 찾아 숲을 돈다"는 동선이 벌목·수액과 같아야 곁들이답게 얹힌다(신규 동선 0).
const MOSS_CHANCE := 0.15     # 자격 있는 성숙목이 하룻밤에 이끼가 낄 확률(잠정 — owner 큐)
# 벗긴 직후엔 며칠 쉰다(긁자마자 다음 날 또 끼면 나무 한 그루가 무한 자판기가 된다). 3일 쿨다운 +
# 15% 롤이면 재착생 기대 ~3+6.7 ≈ 10일 — "숲을 한 바퀴 돌 때마다 몇 그루쯤"의 밀도다(잠정 — owner 큐).
const MOSS_COOLDOWN := 3      # 채취 후 재착생 롤이 다시 열리기까지의 일수

# ── 도끼 타격 카운트(0티어 기준 — 티어 감소는 ToolTier.axe_mature_hp) ────────
const HP_MATURE := 10         # 성숙목 10타(스타듀 0티어 상속 — ToolTier.AXE_MATURE_HP[0]과 동치)
const HP_STAGE4 := 3          # 4단계(거의 다 큰 나무) 3타
const HP_SAPLING := 1         # 1~3단계(유목) 1타 — 원장 즉시 제거
const HP_STUMP := 3           # 그루터기 제거 3타(잠정 — ADR-0062는 "도끼 수회")

# ── ★[S4-T4 / ADR-0062 결정 1 ㉡] 큰 장애물(large object) ───────────────────
# 보통 나무와 **다른 축**이다: 자라지 않고(성장 단계 없음), 도끼 *티어*가 없으면 아예 안 깨지며,
# 산출은 단단한 원목 고정 + 큰 장애물 XP 25다. 원장 슬롯을 공유하되 `large` 필드로 갈린다.
#   ㉠ 큰 그루터기(large_stump) — 명동 도끼(티어 1) · 경목 2 · **일일 리스폰**(지속 공급원.
#      스타듀 비밀의 숲 Large Stump 1:1 — 심층 6개 = 하루 12 경목).
#   ㉡ 큰 통나무(large_log) — 유철 도끼(티어 2) · 경목 8 · **재생성 없음**(영구 개방. 스타듀
#      Large Log 1:1 — 한 번 치우면 그 길이 영영 열린다 = 심층 구획의 열쇠).
const KIND_LARGE_STUMP := "large_stump"
const KIND_LARGE_LOG := "large_log"
const LARGE_KINDS := [KIND_LARGE_STUMP, KIND_LARGE_LOG]
const HP_LARGE_STUMP := 6     # 큰 그루터기 타수(잠정 — 성숙목보다 적되 보통 그루터기의 2배)
const HP_LARGE_LOG := 10      # 큰 통나무 타수(잠정 — 심층의 문이라 성숙목과 같은 무게)
const LARGE_STUMP_HARDWOOD := 2   # 큰 그루터기 산출 = 단단한 원목 2(스타듀 상속)
const LARGE_LOG_HARDWOOD := 8     # 큰 통나무 산출 = 단단한 원목 8(스타듀 상속)

# ── 산출(ADR-0062 결정 3 — 스타듀 상속) ─────────────────────────────────────
const WOOD_MIN := 12          # 성숙목 원목 12~16
const WOOD_MAX := 16
const SAP_YIELD := 5          # 성숙목 수액 5
const SEED_MIN := 0           # 성숙목 씨앗 0~2
const SEED_MAX := 2
const SEED_LEVEL := 1         # 씨앗 드랍 최소 채집 레벨(lvl1+ — ADR-0062 "레벨 1+")
const STAGE4_WOOD_MIN := 5    # 4단계 벌목 원목 5~8(잠정 — 성숙목의 절반 결. 수액·그루터기 없음)
const STAGE4_WOOD_MAX := 8
const STUMP_WOOD_MIN := 4     # 그루터기 제거 원목 4~9
const STUMP_WOOD_MAX := 9
const STUMP_XP := 2           # 그루터기 제거 채집 XP 2(ForageSkill 고정 테이블에 없는 잔여값 —
                              #   T2가 정의한 넷(줍기7·벌목14·큰장애물25·덤불1) 밖이라 여기 둔다)

# ── 재성장 모드(구역 축) ────────────────────────────────────────────────────
const MODE_FOREST := "forest"   # 숲 — 빈 슬롯 재출현
const MODE_SEED := "seed"       # 안식 농원 — 성숙목 자체 파종

# 원장. { region(String) → { Vector2i → {"species","stage","hp","stump","moss","large","gone"} } }
#   · large("") = 보통 나무 슬롯 / large=KIND_* = 큰 장애물 슬롯(stage·species 미사용)
#   · gone = 큰 장애물이 치워졌나(큰 그루터기는 밤에 되돌아오고, 큰 통나무는 영영 true)
var _trees: Dictionary = {}
# 초기 배치를 이미 깐 구역 집합(재빌드마다 다시 심지 않게 — 벤 나무가 부활하면 안 된다).
var _seeded: Dictionary = {}

# ── 정적 규칙 ───────────────────────────────────────────────────────────────
# 이 구역의 재성장 모드. 안식 농원만 자체 파종이고 나머지(숲 2구역)는 빈 슬롯 재출현이다.
static func mode_for(region: String) -> String:
	return MODE_SEED if region == RegionCatalog.HOME else MODE_FOREST

# 이 칸의 종(결정적 — 좌표 해시). 같은 자리는 늘 같은 종이라 세이브 없이도 재현된다.
static func species_at_tile(region: String, t: Vector2i) -> String:
	var h: int = abs(hash("treesp:%s:%d:%d" % [region, t.x, t.y]))
	return SPECIES[h % SPECIES.size()]

# 단계별 도끼 타수(그루터기는 HP_STUMP). ★[S4-T4] 성숙목만 도끼 티어로 줄어든다(10/8/6) —
# 유목·4단계는 이미 1~3타라 줄일 여지가 없고, 티어의 의미는 "큰 걸 빨리·더 큰 걸 아예"다.
static func hp_for_stage(stage: int, tier: int = 0) -> int:
	if stage >= MAX_STAGE:
		return ToolTier.axe_mature_hp(tier)
	if stage == 4:
		return HP_STAGE4
	return HP_SAPLING

# 큰 장애물 종별 타수(도끼 티어로 줄지 않는다 — 티어는 여기선 *접근* 축이다, ADR-0027).
static func hp_for_large(kind: String) -> int:
	match kind:
		KIND_LARGE_STUMP: return HP_LARGE_STUMP
		KIND_LARGE_LOG: return HP_LARGE_LOG
	return 0

# 큰 장애물 종별 요구 도끼 티어(0 = 게이트 없음). 수치의 단일 출처는 ToolTier다(의존 한 방향).
static func tier_for_large(kind: String) -> int:
	match kind:
		KIND_LARGE_STUMP: return ToolTier.TIER_LARGE_STUMP
		KIND_LARGE_LOG: return ToolTier.TIER_LARGE_LOG
	return 0

# 큰 장애물 종별 단단한 원목 산출.
static func hardwood_for_large(kind: String) -> int:
	match kind:
		KIND_LARGE_STUMP: return LARGE_STUMP_HARDWOOD
		KIND_LARGE_LOG: return LARGE_LOG_HARDWOOD
	return 0

# 큰 장애물이 밤에 되돌아오나(큰 그루터기 O = 지속 공급 / 큰 통나무 X = 영구 개방).
static func respawns_large(kind: String) -> bool:
	return kind == KIND_LARGE_STUMP

static func large_name(kind: String) -> String:
	match kind:
		KIND_LARGE_STUMP: return "큰 그루터기"
		KIND_LARGE_LOG: return "큰 통나무"
	return ""

# 종 → 씨앗 아이템 id(ItemCatalog 단일 출처 — 이름·가격은 저기 산다).
static func seed_item_for(species: String) -> String:
	match species:
		SP_PINE: return ItemCatalog.SEED_JEOSEUNGSOL
		SP_MAPLE: return ItemCatalog.SEED_MYEONGDANPUNG
		SP_OAK: return ItemCatalog.SEED_NEOKCHAM
	return ""

static func species_name(species: String) -> String:
	return String(SPECIES_NAMES.get(species, species))

# ── 질의 ────────────────────────────────────────────────────────────────────
# 이 구역·이 칸이 원장 슬롯인가(나무가 서 있든 벤 자리든 — "여긴 나무 자리"의 판정).
func has_slot(region: String, t: Vector2i) -> bool:
	return _trees.has(region) and _trees[region].has(t)

# 이 칸이 물리적으로 차 있나(나무 or 그루터기) = **통행 불가 · 도끼 대상**. main의 통행·충돌·
# 그리드 동기화가 유일하게 보는 술어다(벌목 전 SOLID 동일 / 그루터기 제거 후 walkable).
func is_occupied(region: String, t: Vector2i) -> bool:
	if not has_slot(region, t):
		return false
	var e: Dictionary = _trees[region][t]
	if String(e.get("large", "")) != "":
		return not bool(e.get("gone", false))     # 큰 장애물 — 치우기 전엔 SOLID, 치운 뒤 열린다
	return int(e.get("stage", 0)) > 0 or bool(e.get("stump", false))

func stage_at(region: String, t: Vector2i) -> int:
	return int(_trees[region][t].get("stage", 0)) if has_slot(region, t) else 0

# 남은 타수. ★[S4-T4] tier를 주면 **아직 손대지 않은** 대상은 그 티어 기준으로 환산해 보여 준다
# (프롬프트 "N타 남음"이 든 도끼의 실제 타수와 맞아야 티어의 실효가 읽힌다). 이미 친 대상은
# 시작할 때의 눈금을 그대로 이어 센다 — 중간에 도끼를 바꿔도 잔여 타수가 늘거나 줄지 않는다.
func hp_at(region: String, t: Vector2i, tier: int = 0) -> int:
	if not has_slot(region, t):
		return 0
	return _effective_hp(_trees[region][t], tier)

# 이 슬롯의 "지금부터 몇 타"(위 규칙의 단일 구현). 큰 장애물·그루터기는 티어 무관 고정.
func _effective_hp(e: Dictionary, tier: int) -> int:
	var hp := int(e.get("hp", 0))
	var kind := String(e.get("large", ""))
	if kind != "" or bool(e.get("stump", false)):
		return hp
	var stage := int(e.get("stage", 0))
	if stage < MAX_STAGE:
		return hp
	# 성숙목 — 무손상(0티어 만타수 그대로)일 때만 티어 환산이 걸린다.
	return hp_for_stage(stage, tier) if hp >= HP_MATURE else hp

# 이 칸이 큰 장애물 슬롯인가("" = 아님). 치워진 뒤에도 슬롯은 남으므로 종은 계속 조회된다.
func large_at(region: String, t: Vector2i) -> String:
	return String(_trees[region][t].get("large", "")) if has_slot(region, t) else ""

func is_large(region: String, t: Vector2i) -> bool:
	return large_at(region, t) != ""

# 이 칸을 치우는 데 필요한 도끼 티어(보통 나무는 0 — ADR-0027 "기본 벌목은 0티어에서도 된다").
func required_tier(region: String, t: Vector2i) -> int:
	return tier_for_large(large_at(region, t))

func is_stump(region: String, t: Vector2i) -> bool:
	return has_slot(region, t) and bool(_trees[region][t].get("stump", false))

# 성숙목이 서 있나(그루터기 아님) — 수액 채취 자격(S4-T6)·자체 파종 모수·아트 분기의 기준.
func is_mature(region: String, t: Vector2i) -> bool:
	return stage_at(region, t) >= MAX_STAGE and not is_stump(region, t)

func species_at(region: String, t: Vector2i) -> String:
	return String(_trees[region][t].get("species", "")) if has_slot(region, t) else ""

# ★[S4-T8] 저승 이끼 플래그 — T3이 자리만 잡아 둔 것을 여기서 실배선했다(낫 1회 채취).
func has_moss(region: String, t: Vector2i) -> bool:
	return has_slot(region, t) and bool(_trees[region][t].get("moss", false))

func set_moss(region: String, t: Vector2i, on: bool) -> void:
	if not has_slot(region, t):
		return
	_trees[region][t]["moss"] = on
	changed.emit()

# 이 나무에 이끼가 낄 자격이 있나 = **성숙목뿐**(유목·그루터기·큰 장애물·빈 슬롯 제외). 채취 후
# MOSS_COOLDOWN일이 지나야 롤이 다시 열린다(day 0 = 아직 한 번도 안 벗긴 나무 → 즉시 자격).
func can_moss(region: String, t: Vector2i, day: int) -> bool:
	if not is_mature(region, t) or has_moss(region, t):
		return false
	var last := int(_trees[region][t].get("mossday", 0))
	return last <= 0 or day - last >= MOSS_COOLDOWN

# 이끼를 벗긴다(낫 1회). 성공하면 true — 플래그를 내리고 **그 날짜를 기억**해 쿨다운을 건다.
# ★ 산출물(저승 이끼 1개)·XP·혼력은 전부 호출 측(main._scrape_moss)의 몫이다. 이 원장은 아이템을
#   모른다(chop이 산출 *수치*만 돌려주고 적재는 main이 하는 것과 같은 경계).
func scrape_moss(region: String, t: Vector2i, day: int) -> bool:
	if not has_moss(region, t):
		return false
	_trees[region][t]["moss"] = false
	_trees[region][t]["mossday"] = maxi(day, 1)
	changed.emit()
	return true

# 이 구역의 이끼 낀 칸 목록(드로우·검증 — tiles()가 정렬 순회라 결정적).
func moss_tiles(region: String) -> Array:
	var out: Array = []
	for t: Vector2i in tiles(region):
		if has_moss(region, t):
			out.append(t)
	return out

# 이 구역의 슬롯 전체(빈 슬롯 포함 — 그리드 동기화가 순회한다). 정렬(결정적 순회).
func tiles(region: String) -> Array:
	if not _trees.has(region):
		return []
	var out: Array = _trees[region].keys()
	out.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.y < b.y if a.y != b.y else a.x < b.x)
	return out

# 이 구역의 차 있는 칸 수(나무+그루터기 — 검증·상한 판정).
func occupied_count(region: String) -> int:
	var n := 0
	for t: Vector2i in tiles(region):
		if is_occupied(region, t):
			n += 1
	return n

func slot_count(region: String) -> int:
	return int(_trees[region].size()) if _trees.has(region) else 0

func total() -> int:
	var n := 0
	for region in _trees:
		n += int(_trees[region].size())
	return n

# 원장이 아는 구역 목록(정렬 — 결정적 순회).
func regions() -> Array:
	var out: Array = _trees.keys()
	out.sort()
	return out

# ── 초기 배치(구역 첫 빌드 1회) ──────────────────────────────────────────────
func is_seeded(region: String) -> bool:
	return bool(_seeded.get(region, false))

# 이 구역의 원장 나무를 깐다. tiles = main이 실그리드에서 골라 준 *내부(비-경계 밴드) 나무 칸*
# (숲) 또는 프롭 나무 앵커(안식). 전부 성숙(stage 5)에서 시작한다 — 이미 서 있던 나무니까.
# ★ 멱등: 이미 깐 구역이면 무동작(재빌드·워프 재진입에 벤 나무가 부활하지 않는다).
# ★ 결정적: 종은 좌표 해시 파생이라 같은 맵이면 늘 같은 배치다(세이브 키 부재 시 재생성 정합).
func seed_region(region: String, tile_list: Array, stage: int = MAX_STAGE) -> int:
	if is_seeded(region):
		return 0
	_seeded[region] = true
	var st := clampi(stage, 1, MAX_STAGE)
	var n := 0
	for raw in tile_list:
		if typeof(raw) != TYPE_VECTOR2I:
			continue
		var t: Vector2i = raw
		if has_slot(region, t):
			continue
		_put(region, t, {"species": species_at_tile(region, t), "stage": st,
			"hp": hp_for_stage(st), "stump": false, "moss": false, "large": "", "gone": false})
		n += 1
	if n > 0:
		changed.emit()
	return n

# ★[S4-T4] 큰 장애물을 심는다(맵 빌더가 실좌표로 준다 — 원장은 어디가 심층인지 모른다).
# ★ 멱등 + **세이브 우선**: 이미 슬롯이 있으면 무동작이라, 치워 둔 큰 통나무가 재빌드·워프 재진입·
#   세이브 복원 뒤에 부활하지 않는다(영구 개방의 구조적 보증).
func seed_large(region: String, tile_list: Array, kind: String) -> int:
	if not kind in LARGE_KINDS:
		return 0
	var n := 0
	for raw in tile_list:
		if typeof(raw) != TYPE_VECTOR2I:
			continue
		var t: Vector2i = raw
		if has_slot(region, t):
			continue
		_put(region, t, {"species": "", "stage": 0, "hp": hp_for_large(kind),
			"stump": false, "moss": false, "large": kind, "gone": false})
		n += 1
	if n > 0:
		changed.emit()
	return n

# 이 구역의 큰 장애물 칸 목록(종 필터 · 정렬 순회 — 배치 검증·드로우·테스트).
func large_tiles(region: String, kind: String = "") -> Array:
	var out: Array = []
	for t: Vector2i in tiles(region):
		var k := large_at(region, t)
		if k == "" or (kind != "" and k != kind):
			continue
		out.append(t)
	return out

# ── 벌목(도끼 1스윙 = 1타) ───────────────────────────────────────────────────
# 조준 칸의 나무·그루터기를 한 번 친다. 반환 = {} (대상 없음 — main이 무동작) 또는
#   {"hit": true, "hp": 남은 타수, "felled": bool, "stump": bool(친 대상이 그루터기였나),
#    "cleared": bool(슬롯이 비었나 = 통행 가능해졌나), "wood": int, "hardwood": int, "sap": int,
#    "seed_id": String, "seeds": int, "xp": int, "species": String}
# ★ 산출은 **마지막 타에만** 실린다(중간 타는 전부 0 — "쓰러뜨린 사건"에 값을 매긴다, 결정 8).
# ★ 퍼크는 주입: wood_bonus(감지자 +N) · hardwood_chance(벌목꾼 확률). 이 원장은 ProfessionCatalog를
#   모른다(ForageSkill이 float → 의미 해석의 유일 접점 — FishSkill.crab_pot_* 선례).
# ★[S4-T4] 인자 둘이 늘었다: `tier`(든 도끼 티어 — 타수 환산 + 큰 장애물 게이트).
#   게이트에 걸리면 **상태를 하나도 안 건드리고** {"blocked": true, "need_tier": N, "large": kind}만
#   돌려준다 — 호출 측이 혼력을 쓰기 *전에* 거부할 수 있어야 "혼력 미소모"가 성립한다.
func chop(region: String, t: Vector2i, day: int, level: int = 0,
		wood_bonus: int = 0, hardwood_chance: float = 0.0, tier: int = 0) -> Dictionary:
	if not is_occupied(region, t):
		return {}
	var e: Dictionary = _trees[region][t]
	var large := String(e.get("large", ""))
	# ── 큰 장애물 게이트(ADR-0027 "접근 = 도구 티어") — 티어가 모자라면 무효타다 ──
	var need := tier_for_large(large)
	if tier < need:
		return {"blocked": true, "need_tier": need, "large": large, "hit": false}
	var was_stump: bool = bool(e.get("stump", false))
	var stage: int = int(e.get("stage", 0))
	var species := String(e.get("species", SP_PINE))
	var hp: int = maxi(_effective_hp(e, tier) - 1, 0)
	e["hp"] = hp
	_trees[region][t] = e
	var out := {"hit": true, "hp": hp, "felled": false, "stump": was_stump, "cleared": false,
		"wood": 0, "hardwood": 0, "sap": 0, "seed_id": "", "seeds": 0, "xp": 0, "species": species,
		"large": large, "blocked": false}
	if hp > 0:
		changed.emit()
		return out                                   # 중간 타 — 산출 0(사건이 아직 안 났다)
	# ── 마지막 타: 상태별로 결말이 갈린다 ──
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("chop:%s:%d:%d:%d" % [region, t.x, t.y, day])
	if large != "":
		# ㉮ 큰 장애물 제거 — 단단한 원목 고정 + 큰 장애물 XP 25. 슬롯은 남기고 `gone`만 세운다
		#    (큰 그루터기는 밤에 되살아나야 하고, 큰 통나무는 "여긴 원래 통나무였다"를 기억한다).
		out["hardwood"] = hardwood_for_large(large)
		out["xp"] = ForageSkill.LARGE_OBSTACLE_XP
		out["felled"] = true
		out["cleared"] = true
		e["gone"] = true
		e["hp"] = 0
		_trees[region][t] = e
		changed.emit()
		return out                                   # 벌목꾼 확률 미적용(경목이 이미 확정 산출이다)
	if was_stump:
		# ㉠ 그루터기 제거 — 슬롯이 비고(통행 가능) 원목 4~9 + XP 2.
		out["wood"] = rng.randi_range(STUMP_WOOD_MIN, STUMP_WOOD_MAX) + maxi(wood_bonus, 0)
		out["xp"] = STUMP_XP
		out["cleared"] = true
		_empty(region, t)
	elif stage >= MAX_STAGE:
		# ㉡ 성숙목 벌목 — 원목 12~16 + 수액 5 + 씨앗 0~2 + XP 14, 그리고 **그루터기가 남는다**.
		out["wood"] = rng.randi_range(WOOD_MIN, WOOD_MAX) + maxi(wood_bonus, 0)
		out["sap"] = SAP_YIELD
		out["xp"] = ForageSkill.CHOP_XP
		out["felled"] = true
		if level >= SEED_LEVEL:
			out["seeds"] = rng.randi_range(SEED_MIN, SEED_MAX)
			out["seed_id"] = seed_item_for(species)
		e["stump"] = true
		e["hp"] = HP_STUMP
		_trees[region][t] = e                        # 슬롯은 그대로 차 있다(그루터기 = 통행 불가)
	elif stage == 4:
		# ㉢ 4단계 벌목 — 다 크지 않아 그루터기가 안 남고 수액도 없다. 원목은 절반 결.
		out["wood"] = rng.randi_range(STAGE4_WOOD_MIN, STAGE4_WOOD_MAX) + maxi(wood_bonus, 0)
		out["xp"] = ForageSkill.CHOP_XP
		out["felled"] = true
		out["cleared"] = true
		if level >= SEED_LEVEL:
			out["seeds"] = rng.randi_range(SEED_MIN, 1)
			out["seed_id"] = seed_item_for(species)
		_empty(region, t)
	else:
		# ㉣ 유목(1~3단계) — 1타에 뽑히고 **씨앗만** 나온다(원목·수액·XP 0 = 남벌 유인 0).
		out["felled"] = true
		out["cleared"] = true
		if level >= SEED_LEVEL:
			out["seeds"] = 1
			out["seed_id"] = seed_item_for(species)
		_empty(region, t)
	# 벌목꾼(DIM_HARDWOOD) — 원목이 난 벌목에만 단단한 원목이 섞인다(씨앗만 나오는 유목은 제외).
	if out["wood"] > 0 and hardwood_chance > 0.0 and rng.randf() < hardwood_chance:
		out["hardwood"] = 1
	changed.emit()
	return out

# ── 하루 경과(성장 + 재성장) — 취침 트리거 ───────────────────────────────────
# 반환 = {"grown": [{region,tile,stage}], "regrown": [{region,tile}], "seeded": [{region,tile}]}.
#   ① 성장 — 미성숙목(1~4단계·비-그루터기)이 20%/일로 한 단계 오른다(성숙 중앙값 24일 결).
#   ② 숲 재성장 — 빈 슬롯이 20%/일로 stage3에 되살아난다(그루터기까지 치운 자리만).
#   ③ 안식 자체 파종 — 성숙목이 15%로 반경 3칸의 *빈 칸*에 stage1을 뿌린다. "빈 칸인가"는
#      main이 free_cb(Callable(region, tile) -> bool)로 주입한다 — 이 원장은 밭·프롭·지형을 모른다
#      (Reclaim이 후보를 받는 것과 같은 디커플링). free_cb가 무효면 파종을 건너뛴다.
#   · 결정적: day + 구역 + 좌표 시드. 구역·좌표는 정렬 순회라 Dictionary 키 순서에 안 기댄다.
func advance_day(day: int, free_cb: Callable = Callable()) -> Dictionary:
	var out := {"grown": [], "regrown": [], "seeded": [], "large_respawned": [], "mossed": []}
	for region: String in regions():
		var mode := mode_for(region)
		for t: Vector2i in tiles(region):
			var e: Dictionary = _trees[region][t]
			var stage: int = int(e.get("stage", 0))
			var stump: bool = bool(e.get("stump", false))
			var large := String(e.get("large", ""))
			var rng := RandomNumberGenerator.new()
			rng.seed = hash("treeday:%d:%s:%d:%d" % [day, region, t.x, t.y])
			# ★[S4-T4] 큰 장애물 슬롯은 성장·재성장 축 **밖**이다(자라지 않는다). 큰 그루터기만
			#   확정적으로 되살아나고(일일 리스폰 = 지속 공급), 큰 통나무는 영영 치워진 채다.
			if large != "":
				if bool(e.get("gone", false)) and respawns_large(large):
					e["gone"] = false
					e["hp"] = hp_for_large(large)
					_trees[region][t] = e
					out["large_respawned"].append({"region": region, "tile": t, "large": large})
				continue
			if stump:
				continue                                   # 그루터기는 안 자란다(치워야 자리가 난다)
			# ★[S4-T8 / ADR-0062 결정 9 ㉡] 저승 이끼 착생 롤 — **성숙목만**(자격·쿨다운 판정은
			#   can_moss가 통째로 든다). 성장·재성장 축과 완전히 독립이다: 성숙목은 이미 다 자라
			#   아래 두 분기에 안 걸리고, 시드 접두사가 달라 두 사건이 상관되지도 않는다.
			if can_moss(region, t, day):
				var mrng := RandomNumberGenerator.new()
				mrng.seed = hash("moss:%d:%s:%d:%d" % [day, region, t.x, t.y])
				if mrng.randf() < MOSS_CHANCE:
					e["moss"] = true
					_trees[region][t] = e
					out["mossed"].append({"region": region, "tile": t})
			if stage > 0 and stage < MAX_STAGE:
				if rng.randf() < GROWTH_CHANCE:
					stage += 1
					e["stage"] = stage
					e["hp"] = hp_for_stage(stage)
					_trees[region][t] = e
					out["grown"].append({"region": region, "tile": t, "stage": stage})
			elif stage == STAGE_EMPTY and mode == MODE_FOREST:
				if rng.randf() < REGROW_CHANCE:
					e["species"] = species_at_tile(region, t)
					e["stage"] = REGROW_STAGE
					e["hp"] = hp_for_stage(REGROW_STAGE)
					e["moss"] = false
					e["mossday"] = 0            # 되살아난 나무는 이끼 이력이 없다(쿨다운 초기화)
					_trees[region][t] = e
					out["regrown"].append({"region": region, "tile": t})
	# ③ 자체 파종(안식) — 성숙목마다 한 번씩 굴린다. 상한(HOME_CAP)에 닿으면 멈춘다.
	if free_cb.is_valid():
		for region: String in regions():
			if mode_for(region) != MODE_SEED:
				continue
			for t: Vector2i in tiles(region):
				if occupied_count(region) >= HOME_CAP:
					break
				if not is_mature(region, t):
					continue
				var rng := RandomNumberGenerator.new()
				rng.seed = hash("treeseed:%d:%s:%d:%d" % [day, region, t.x, t.y])
				if rng.randf() >= SEED_CHANCE:
					continue
				var spot := _pick_seed_spot(region, t, free_cb, rng)
				if spot == Vector2i(-1, -1):
					continue
				_put(region, spot, {"species": species_at_tile(region, spot), "stage": 1,
					"hp": hp_for_stage(1), "stump": false, "moss": false})
				out["seeded"].append({"region": region, "tile": spot})
	if not out["grown"].is_empty() or not out["regrown"].is_empty() or not out["seeded"].is_empty() \
			or not out["large_respawned"].is_empty() or not out["mossed"].is_empty():
		changed.emit()
	return out

# 성숙목 주위 반경 SEED_RADIUS의 빈 칸 하나(없으면 (-1,-1)). 후보는 정렬 순회로 모으고 rng로
# 하나 고른다 — 순회가 결정적이라 같은 날 같은 나무는 늘 같은 자리에 뿌린다.
func _pick_seed_spot(region: String, origin: Vector2i, free_cb: Callable,
		rng: RandomNumberGenerator) -> Vector2i:
	var cands: Array = []
	for dy in range(-SEED_RADIUS, SEED_RADIUS + 1):
		for dx in range(-SEED_RADIUS, SEED_RADIUS + 1):
			if dx == 0 and dy == 0:
				continue
			var c := origin + Vector2i(dx, dy)
			if c.x < 0 or c.y < 0:
				continue
			if is_occupied(region, c):
				continue                                   # 이미 나무·그루터기
			if not bool(free_cb.call(region, c)):
				continue                                   # main이 "빈 칸 아님"이라 판정(밭·프롭·지형)
			cands.append(c)
	if cands.is_empty():
		return Vector2i(-1, -1)
	return cands[rng.randi_range(0, cands.size() - 1)]

# ── 내부 조작 ───────────────────────────────────────────────────────────────
func _put(region: String, t: Vector2i, entry: Dictionary) -> void:
	if not _trees.has(region):
		_trees[region] = {}
	_trees[region][t] = entry

# 슬롯을 비운다(벤 자리 — 키는 남긴다. 숲 재성장 후보이자 "여긴 원래 나무 자리"의 기억).
func _empty(region: String, t: Vector2i) -> void:
	if not has_slot(region, t):
		return
	_trees[region][t] = {"species": "", "stage": STAGE_EMPTY, "hp": 0, "stump": false, "moss": false,
		"mossday": 0, "large": "", "gone": false}

# ── 세이브/로드(ForageSpawns 패턴 계승) — 슬라이스 키 "tree_ledger" 네임스페이스 ──
# 구역별 [x, y, species, stage, hp, stump(0/1), moss(0/1), large, gone(0/1), mossday] 10항 배열
# 목록 + 시드 완료 구역 목록.
# ★ 하위호환: 키 없는 구세이브 = 원장 0 → 구역 첫 빌드의 seed_region이 초기 배치를 **결정적으로**
#   재생성한다(종 = 좌표 해시라 같은 맵이면 같은 배치 — ADR-0062 결정 7 요구).
func to_save() -> Dictionary:
	var out: Dictionary = {}
	for region in _trees:
		var arr: Array = []
		for t: Vector2i in _trees[region]:
			var e: Dictionary = _trees[region][t]
			arr.append([t.x, t.y, String(e.get("species", "")), int(e.get("stage", 0)),
				int(e.get("hp", 0)), 1 if bool(e.get("stump", false)) else 0,
				1 if bool(e.get("moss", false)) else 0,
				String(e.get("large", "")), 1 if bool(e.get("gone", false)) else 0,
				int(e.get("mossday", 0))])
		out[region] = arr
	var seeded: Array = _seeded.keys()
	seeded.sort()
	return {"trees": out, "seeded": seeded}

func load_save(data: Dictionary) -> void:
	_trees = {}
	_seeded = {}
	var raw: Variant = data.get("trees", {})
	if typeof(raw) == TYPE_DICTIONARY:
		for region in raw:
			var arr: Variant = raw[region]
			if typeof(arr) != TYPE_ARRAY:
				continue
			var by_tile: Dictionary = {}
			for raw_e in arr:
				if typeof(raw_e) != TYPE_ARRAY:
					continue
				var e: Array = raw_e
				if e.size() < 4:
					continue
				var sp := String(e[2])
				if sp != "" and not sp in SPECIES:
					sp = ""                       # 미지 종은 조용히 버린다(inventory._sanitize 결)
				var stage: int = clampi(int(e[3]), 0, MAX_STAGE)
				var hp: int = int(e[4]) if e.size() >= 5 else hp_for_stage(stage)
				var stump: bool = e.size() >= 6 and int(e[5]) != 0
				var moss: bool = e.size() >= 7 and int(e[6]) != 0
				# ★[S4-T4] 8·9항(큰 장애물 종·치움 여부)은 구세이브(7항)엔 없다 → 보통 나무로 읽힌다
				#   (하위호환). 미지 종 id는 조용히 버려 보통 나무로 강등한다(species 정화와 같은 결).
				var large := String(e[7]) if e.size() >= 8 else ""
				if large != "" and not large in LARGE_KINDS:
					large = ""
				var gone: bool = e.size() >= 9 and int(e[8]) != 0
				# ★[S4-T8] 10항(이끼 채취일 — 재착생 쿨다운의 기준)도 구세이브엔 없다 → 0 = "한 번도
				#   안 벗긴 나무"로 읽혀 즉시 자격이 된다(하위호환. 8·9항과 같은 결).
				var mossday: int = int(e[9]) if e.size() >= 10 else 0
				by_tile[Vector2i(int(e[0]), int(e[1]))] = {"species": sp, "stage": stage,
					"hp": maxi(hp, 0), "stump": stump, "moss": moss, "large": large, "gone": gone,
					"mossday": maxi(mossday, 0)}
			if not by_tile.is_empty():
				_trees[String(region)] = by_tile
	var seeded: Variant = data.get("seeded", [])
	if typeof(seeded) == TYPE_ARRAY:
		for r in seeded:
			_seeded[String(r)] = true
	changed.emit()
