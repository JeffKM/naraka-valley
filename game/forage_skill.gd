extends RefCounted
class_name ForageSkill
# ★[S4-T2 / ADR-0062 결정 8] 채집 숙련도(스킬 0~10) 순수 규칙 — FarmSkill·FishSkill 대칭.
#
# 목적: ROADMAP Slice 4 — "숲을 헤집고 다니면 *무엇이* 달라지는가"를 한 곳에 정의한다.
#       XP는 세이브 상태라 main이 스칼라(_foraging_xp)로 들고(별도 노드 없음 — _farming_xp·_fishing_xp
#       관례), 이 파일은 그 XP를 레벨·계수·감지 대상으로 옮기는 순수 함수만 든다(skill.gd·fish_skill.gd와
#       같은 결). **세이브 키 `foraging_xp`는 개명하지 않는다**(하위호환 — 구세이브가 그대로 실린다).
#
# 설계 메모(어기면 ADR-0062 결정 8 / ADR-0052 / ADR-0008 위반):
#   - **XP 곡선은 5스킬 공통 기반**(ADR-0052). 곡선의 단일 출처는 FarmSkill이고 여기선 *위임*만 한다
#     (수치 복제 0 — FishSkill과 완전 동형). 숙련 탭도 FarmSkill 임계로 진행바를 그리므로 위임이 곧 정합.
#   - **XP = 행위별 고정 테이블**(스타듀 상속 — 결정 8). 옛 `_gain_forage_xp(기준가)` 방식은 "비싼 걸
#     주우면 더 배운다"라 판매가 축(관계 곱셈기 전용, ADR-0052 §1)이 스킬 곡선에 새는 구조였다.
#     고정 XP는 그 누수를 끊는다 — 무엇을 줍든 줍는 행위 자체가 같은 배움이다.
#   - **레벨 효과 = 품질 계단 + 혼 감지 둘뿐.** ❌혼력 절감(줍기는 이미 혼력 0 — ADR-0033 #1이라
#     절감할 비용 자체가 없다) ❌+판매가 ❌레벨 게이팅(L0도 전 동작 100% 가동, "평평≠막힘").
#     혼 감지(lvl3+)는 *게이트가 아니라 편의*다 — 감지 없이도 눈으로 찾아 다 주울 수 있다.
#   - **퍼크 해석은 여기, 퍼크 *보유*는 main.** 이 파일은 ProfessionCatalog를 읽지 않는다 — main이
#     `_perk_value`로 뽑은 float 하나를 넘기면 그 의미(원목 +N·확률·등급 계단)를 여기서 푼다
#     (FishSkill.crab_pot_* 선례 동형 — 상태 없는 해석기).
#   - **감지 대상 선정은 결정적**(최근접 · 동률이면 좌표 정렬). 전역 randf 금지 — 헤드리스가 정확히
#     재현한다(ForageSpawns 결정 롤과 같은 규율).

# ── 레벨 상한(FarmSkill.MAX_LEVEL과 같은 눈금 — 어긋나면 forage_skill_test ①이 잡는다) ──
const MAX_LEVEL := 10

# ── 행위별 고정 XP(ADR-0062 결정 8 — 스타듀 Foraging XP 1:1) ─────────────────
# 줍기 7 = 이 스킬의 기축이다. L1(임계 100)까지 15회, 즉 빈터 몇 판이면 첫 레벨이 온다.
const PICK_XP := 7
# 벌목 **마지막 타**에만 14(중간 타는 0 — "쓰러뜨린 사건"에 값을 매긴다). 소비처는 S4-T3.
const CHOP_XP := 14
# 큰 장애물(큰 통나무·큰 그루터기) 제거 25 — 도끼 티어 게이트를 넘은 사건이라 가장 크다. 소비처 S4-T4.
const LARGE_OBSTACLE_XP := 25
# 덤불 흔들기 1 — 곁들이 행위라 최소값(누적은 되되 곡선을 흔들지 않는다). 소비처 S4-T8.
const BUSH_SHAKE_XP := 1

# ── 혼 감지(base lvl3+ · 감지자 퍼크로 범위 확대) ─────────────────────────────
# CONTEXT [혼 감지]·미혹 "길 잃음" 테마의 최초 실장. lvl3인 이유 = 줍기 7XP 기준 L3(임계 600)이
# 대략 86회 줍기 = "숲을 한동안 다닌 사람"이라 감각이 트이는 지점으로 읽힌다.
const DETECT_LEVEL := 3
# base 범위(칸). 뷰포트 960×540 / TILE 32 = 화면 30×16.9칸이라 반경 14는 **화면 밖 한 뼘**이다
# — 마커가 "지금 화면 너머 저쪽"을 가리키는 편의로 정확히 기능하고, 구역 전체를 밝히진 않는다.
const DETECT_RADIUS := 14
# 감지자(DIM_DETECT) 퍼크 = 구역 전체. 반경 대신 이 센티넬을 쓴다(거대 상수 대신 명시적 무제한).
const DETECT_RANGE_ALL := -1
# "대상 없음" 센티넬. 채집물 좌표는 전부 0 이상이라 (-1,-1)과 절대 충돌하지 않는다.
const NO_TARGET := Vector2i(-1, -1)

# ── 퍼크 해석 상수(그레이박스 잠정 — ADR-0028 스펙카드 잠금 대상) ────────────
# 벌목꾼(DIM_HARDWOOD) — 모든 나무에서 단단한 원목이 섞여 나올 확률. 심층 그루터기(확정 산출)와
# 달리 "어디서든 가끔"이라 25%면 벌목 4회당 1개 = 체감되되 심층의 존재 이유를 안 잡아먹는다.
const HARDWOOD_CHANCE := 0.25
# 수액꾼(DIM_TAP_QUALITY) — 수액 등급 계단 +1(일반→은→금). 등급 상한은 소비처(S4-T6)가 클램프한다.
const TAP_QUALITY_STEP := 1

# ── 조회(XP → 레벨) ─────────────────────────────────────────────────────────
# 누적 XP → 레벨(0..10). ★곡선은 FarmSkill이 단일 출처(ADR-0052 "5스킬 공통 기반") — 위임만 한다.
static func level_for_xp(xp: int) -> int:
	return FarmSkill.level_for_xp(xp)

# 레벨 임계 배열(숙련 탭·테스트 조회용 — 공통 곡선 재수출).
static func xp_thresholds() -> Array:
	return FarmSkill.XP_THRESHOLDS

# ── 품질 계단(채집 레벨 → 기본 등급) ────────────────────────────────────────
# ADR-0052 §채집: L0~3 일반 / L4~6 은 / L7+ 금. **이리듐은 base로 안 나온다** — 약초학자 전문직
# 하한으로만 닿는다(퍼크가 의미를 갖게). 호출 측이 `maxi(base_quality, quality_floor)`로 합친다.
static func base_quality(level: int) -> int:
	if level >= 7:
		return ItemCatalog.Q_GOLD
	if level >= 4:
		return ItemCatalog.Q_SILVER
	return ItemCatalog.Q_NORMAL

# ── 퍼크 해석(main._perk_value가 뽑은 float → 의미) ──────────────────────────
# 약초학자(DIM_QUALITY_FLOOR) — 산출물 등급 하한. 0 = 퍼크 없음(중립).
static func quality_floor(perk: float) -> int:
	return int(clampf(perk, 0.0, float(ItemCatalog.Q_IRIDIUM)))

# 채집꾼(DIM_DOUBLE_DROP) — 2배 드롭 확률(0..1). 카탈로그 정의값 0.20을 그대로 통과시킨다.
static func double_drop_chance(perk: float) -> float:
	return clampf(perk, 0.0, 1.0)

# ★[S4-T3/T6이 소비할 훅] 미배선 퍼크 3종 — 퍼크 데이터는 ADR-0052가 이미 잠갔고, 이 세 줄이 그
#   해석 접점이다(벌목·수액 시스템이 아직 없어 지금은 소비처가 없다 = FishSkill.crab_pot_* 선례).
# 감지자(DIM_WOOD_BONUS) — 벌목 원목 +N. 카탈로그 정의값(1.0)이 곧 N이다(수치 복제 0).
static func wood_bonus(perk: float) -> int:
	return int(maxf(perk, 0.0))

# 벌목꾼(DIM_HARDWOOD) — 단단한 원목 확률(flag → 확률로 해석).
static func hardwood_chance(perk: float) -> float:
	return HARDWOOD_CHANCE if perk > 0.0 else 0.0

# 수액꾼(DIM_TAP_QUALITY) — 수액 등급 계단(flag → +1 등급).
static func tap_quality(perk: float) -> int:
	return TAP_QUALITY_STEP if perk > 0.0 else 0

# ── 혼 감지 ─────────────────────────────────────────────────────────────────
# 지금 감지 반경(칸). 0 = 감지 없음(lvl3 미만) · DETECT_RANGE_ALL(-1) = 구역 전체(감지자 퍼크).
static func detect_radius(level: int, detect_perk: float) -> int:
	if clampi(level, 0, MAX_LEVEL) < DETECT_LEVEL:
		return 0
	return DETECT_RANGE_ALL if detect_perk > 0.0 else DETECT_RADIUS

# 감지 대상 선정 — origin에서 가장 가까운 채집물 칸. 없으면 NO_TARGET.
# ★결정적: ①제곱거리 최소 ②동률이면 x 오름차순 ③그래도 동률이면 y 오름차순. 입력 배열의 순서
#   (Dictionary 키 순서)에 절대 안 기댄다 — 같은 판이면 몇 번을 물어도 같은 칸이 나온다.
static func nearest_forage(origin: Vector2i, tiles: Array, radius: int) -> Vector2i:
	if radius == 0 or tiles.is_empty():
		return NO_TARGET
	var limit := -1 if radius == DETECT_RANGE_ALL else radius * radius
	var best := NO_TARGET
	var best_d := -1
	for raw in tiles:
		if typeof(raw) != TYPE_VECTOR2I:
			continue
		var t: Vector2i = raw
		var d: int = (t.x - origin.x) * (t.x - origin.x) + (t.y - origin.y) * (t.y - origin.y)
		if limit >= 0 and d > limit:
			continue
		if best_d < 0 or d < best_d \
				or (d == best_d and (t.x < best.x or (t.x == best.x and t.y < best.y))):
			best = t
			best_d = d
	return best
