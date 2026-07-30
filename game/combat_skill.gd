extends RefCounted
class_name CombatSkill
# ★[S5-T4 / ADR-0063 결정 4·5·9] 전투 숙련도(스킬 0~10) + **피해 판정** 순수 규칙 —
# MiningSkill·ForageSkill·FishSkill 대칭의 다섯째(마지막) 스킬 파일.
#
# 목적: ROADMAP Slice 5 — "검을 계속 휘두르면 *무엇이* 달라지는가"와 "한 번의 스윙이 몇 대미지인가"를
#       한 곳에 정의한다. XP는 세이브 상태라 main이 스칼라(_combat_xp)로 들고(별도 노드 없음 —
#       _farming_xp·_mining_xp 관례), 이 파일은 그 XP를 레벨·계수로 옮기고 **한 번의 타격이 얼마를
#       주는지**를 결정하는 순수 함수만 든다(mining_skill.gd와 같은 결).
#
# 설계 메모(어기면 ADR-0063 결정 4·5 / ADR-0052 / ADR-0011 위반):
#   - **XP 곡선은 5스킬 공통 기반**(ADR-0052). 곡선의 단일 출처는 FarmSkill이고 여기선 *위임*만 한다
#     (수치 복제 0 — MiningSkill/ForageSkill/FishSkill과 완전 동형).
#   - **레벨 효과 = 최대 HP +5/lv 하나뿐.** ❌피해량(무기 축) ❌크리(base 2% 고정 + 전문직 축)
#     ❌레벨 게이팅(L0도 녹슨 혼검으로 전 층 잡귀를 때릴 수 있다 — "평평≠막힘", ADR-0008).
#     Lv5/10에서 +5가 **빠지는** 이유는 그 몫이 전문직(투사 +15·수호자 +25)이기 때문이다(스타듀 1:1).
#   - **HP 자원 자체는 PlayerHealth가 소유**한다. 이 파일은 "레벨이 최대 HP에 얼마를 얹나"라는
#     *곡선*만 알고 현재 HP·시그널·세이브를 모른다(PlayerHealth → CombatSkill 단방향 의존.
#     MiningSkill → MineFloors 방향과 같다 — 원장/자원이 규칙을 읽고 규칙은 상태를 모른다).
#   - **무기 데이터는 WeaponCatalog가 단일 출처**다. 여기선 그 밴드를 *읽어* 롤·크리만 얹는다
#     (MiningSkill이 MineFloors의 노드 부류를 읽어 드랍 규칙만 가르는 것과 같은 자리).
#   - **피해 롤은 결정적**(호출 측이 넘긴 시드 하나 + **RNG 순차 소비**). 전역 randf 금지이고,
#     좌표 해시로 이웃 연속값을 뽑는 것도 금지다(미혹 안개 교훈 — ADR-0063 결정 1).
#   - **전투 행동비용 0**(ADR-0011 확정): 이 파일엔 혼력·HP 소모가 한 줄도 없다. 공격은 공짜다.
#   - **퍼크 해석은 여기, 퍼크 *보유*는 main.** ProfessionCatalog를 읽지 않는다 — main이 `_perk_value`
#     /`_perk_sum`으로 뽑은 float 하나를 넘기면 그 의미를 여기서 푼다(MiningSkill.ore_bonus 동형).

# ── 레벨 상한(FarmSkill.MAX_LEVEL과 같은 눈금 — 어긋나면 combat_test가 잡는다) ──
const MAX_LEVEL := 10

# ── 최대 HP 성장(ADR-0063 결정 4 — 스타듀 1:1) ────────────────────────────────
# 레벨당 +5. 단 **Lv5·Lv10은 제외** — 그 두 계단의 몫은 전문직이 낸다(투사 +15 · 수호자 +25).
# 그래서 Lv10 순수 성장분은 8계단 × 5 = +40이고, 전문직까지 고르면 +40이 더 붙어 최대 180이 된다.
const HP_PER_LEVEL := 5
const HP_SKIP_LEVELS := [5, 10]

# ── 크리(ADR-0063 결정 4 — 확률 2% · 배율 3 고정) ─────────────────────────────
# 이 둘이 전투의 유일한 분산원이다(데미지 밴드 롤 + 크리). 플레이어 방어·Attack 스탯은
# 장비 클러스터 서랍(반지·부츠)에 묶여 있어 **여기 없다**(ADR-0063 결정 4 명시).
const CRIT_BASE := 0.02      # base 크리 확률(레벨 무관 — 척후/결사가 유일한 변조 축)
const CRIT_MULT := 3.0       # base 크리 배율(결사가 ×2 → 6.0)

# ── 스윙 판정 범위(ADR-0063 결정 5 "검 스윙 = LMB 호(arc) 판정 하나") ──────────
# 정면 2칸(찌르기 사거리) + 1칸 앞의 좌우 대각 2칸 = **4칸 부채꼴**. 몹이 대각으로 붙어도
# 맞고, 뒤·옆은 안 맞는다(방향이 의미를 갖는다). *잠정* — 단검/둔기 계열이 서랍에서 나오면
# 계열마다 다른 arc를 갖는 자리가 여기다(그때 이 상수가 계열별 표로 갈린다).
const ARC_REACH := 2         # 정면 관통 칸 수
const ARC_WING := 1          # 좌우 날개가 붙는 전방 거리(1칸 앞의 양 대각)

# ── 조회(XP → 레벨) ─────────────────────────────────────────────────────────
# 누적 XP → 레벨(0..10). ★곡선은 FarmSkill이 단일 출처(ADR-0052 "5스킬 공통 기반") — 위임만 한다.
static func level_for_xp(xp: int) -> int:
	return FarmSkill.level_for_xp(xp)

# 레벨 임계 배열(숙련 탭·테스트 조회용 — 공통 곡선 재수출).
static func xp_thresholds() -> Array:
	return FarmSkill.XP_THRESHOLDS

# ── 레벨 → 최대 HP 가산 ─────────────────────────────────────────────────────
# Lv0 = 0(가산 없음 — base 100으로 전 층을 걸어 들어갈 수 있다). Lv5·Lv10 계단은 건너뛴다.
static func hp_bonus(level: int) -> int:
	var lv := clampi(level, 0, MAX_LEVEL)
	var steps := 0
	for l in range(1, lv + 1):
		if not l in HP_SKIP_LEVELS:
			steps += 1
	return steps * HP_PER_LEVEL

# ── 크리 계수(전문직 변조) ──────────────────────────────────────────────────
# 척후(DIM_CRIT_CHANCE) — 확률 배수. 1.0 = 중립(미선택), 1.5 = 2% → 3%.
static func crit_chance(chance_mult: float = 1.0) -> float:
	return clampf(CRIT_BASE * maxf(chance_mult, 1.0), 0.0, 1.0)

# 결사(DIM_CRIT_MULT) — 배율의 배수. 1.0 = 중립(×3), 2.0 = ×6.
static func crit_mult(power_mult: float = 1.0) -> float:
	return CRIT_MULT * maxf(power_mult, 1.0)

# 투사·광전사(DIM_DAMAGE_BONUS) — 피해 배수. 0.0 = 중립, 0.25(=0.10+0.15 합산) = +25%.
# ★ 합산인 이유: 광전사는 투사를 선행으로 요구하므로 두 값이 늘 함께 존재한다(main._perk_sum).
static func damage_factor(bonus: float) -> float:
	return 1.0 + maxf(bonus, 0.0)

# ── 플레이어 → 몹 피해 판정(순수·결정적) ────────────────────────────────────
# 반환 = {"damage": int, "crit": bool, "base": int}("base" = 크리·퍼크 전 밴드 롤 원값 — 로그·테스트용).
#   weapon_id  = 장착 전환된 검(미상 id면 damage 0 = 무동작. "맨손 기본 피해"는 없다 — 무기가 축이다)
#   seed_value = 호출 측이 만든 결정적 시드(main은 스윙 카운터를 쓴다 — 좌표 해시 금지)
#   dmg_bonus  = 투사·광전사 합산 퍼크(0.0 = 중립)
#   crit_ch_mult / crit_pow_mult = 척후·결사 퍼크(1.0 = 중립)
# ★ RNG 순차 소비: ①밴드 롤 → ②크리 롤. 순서를 바꾸면 같은 시드가 다른 답을 내므로 고정이다.
static func resolve_hit(weapon_id: String, seed_value: int, dmg_bonus: float = 0.0,
		crit_ch_mult: float = 1.0, crit_pow_mult: float = 1.0) -> Dictionary:
	if not WeaponCatalog.has(weapon_id):
		return {"damage": 0, "crit": false, "base": 0}
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("combat_hit:%s:%d" % [weapon_id, seed_value])
	var base := WeaponCatalog.roll_damage(weapon_id, rng)
	var crit := rng.randf() < crit_chance(crit_ch_mult)
	var dmg := float(base) * damage_factor(dmg_bonus)
	if crit:
		dmg *= crit_mult(crit_pow_mult)
	# 최소 1 — 밴드 하한이 1 이상이라 도달하지 않는 방어값(무기가 등록됐으면 늘 때린다).
	return {"damage": maxi(int(dmg), 1), "crit": crit, "base": base}

# ── 몹 → 플레이어 피해 판정 ─────────────────────────────────────────────────
# 몹별 **고정 데미지**(변동 롤 생략 — ADR-0063 결정 4). 플레이어 방어 스탯은 장비 클러스터 서랍이라
# 지금은 감산 축이 없다. 이 함수가 존재하는 이유는 그 서랍이 열릴 때 손댈 자리가 **한 곳**이라는 것.
# ★ 몹 로스터·HP·데미지 값 자체는 S5-T5 소관이다(여기선 "받은 고정값을 어떻게 처리하나"만).
static func incoming_damage(mob_damage: int) -> int:
	return maxi(mob_damage, 0)

# ── 스윙 부채꼴(순수 기하 — 그리드·충돌을 모른다) ──────────────────────────
# 바라보는 방향으로 정면 ARC_REACH칸 + 1칸 앞의 좌우 대각. facing은 축 정렬 단위 벡터를 기대하고
# (player.get_facing()이 그걸 준다) 어긋나면 우세 축으로 스냅한다. 벽 관통 여부는 호출 측의 몫이다
# (main이 SOLID 칸에서 자른다 — 이 파일은 지형을 모른다).
static func swing_arc(origin: Vector2i, facing: Vector2i) -> Array[Vector2i]:
	var f := _snap_axis(facing)
	var out: Array[Vector2i] = []
	if f == Vector2i.ZERO:
		return out
	var perp := Vector2i(-f.y, f.x)
	for d in range(1, ARC_REACH + 1):
		out.append(origin + f * d)
	out.append(origin + f * ARC_WING + perp)
	out.append(origin + f * ARC_WING - perp)
	return out

# 임의 방향 → 축 정렬 단위 벡터(우세 축 승). (0,0)은 그대로 (0,0).
static func _snap_axis(v: Vector2i) -> Vector2i:
	if v == Vector2i.ZERO:
		return Vector2i.ZERO
	if absi(v.x) >= absi(v.y):
		return Vector2i(signi(v.x), 0)
	return Vector2i(0, signi(v.y))

# ── 몹 겹침 검사(★S5-T5 훅 — 지금은 빈 배열 폴백) ──────────────────────────
# arc 칸들과 겹치는 몹을 골라 준다. mobs = [{"tile": Vector2i, ...}] 형태의 **불투명 레코드 배열**이라
# 이 파일은 몹의 HP·아키타입·스프라이트를 하나도 모른다(엔티티 프레임워크 = S5-T5 소관).
# ★ 지금 라이브 경로는 항상 mobs=[]를 넘기므로 반환도 빈 배열이다 — 죽은 코드가 아니라 T5가
#   `_mobs_on_floor()` 하나만 채우면 실효되는 접점이다(MiningSkill의 미배선 퍼크 인자와 같은 자리).
static func hits_in_arc(arc: Array, mobs: Array) -> Array:
	var out: Array = []
	if arc.is_empty() or mobs.is_empty():
		return out
	for m in mobs:
		if typeof(m) != TYPE_DICTIONARY:
			continue
		if arc.has(m.get("tile", Vector2i(-1, -1))):
			out.append(m)
	return out

# ── 퍼크 해석(main._perk_value/_perk_sum가 뽑은 float → 의미) ───────────────
# ★ 채광 트리와 달리 **전투 트리는 이 태스크에서 값까지 인코딩됐다**(ProfessionCatalog COMBAT perks).
#   그래서 아래 넷은 실제로 0/중립이 아닌 값을 받는다 — 곡예사(특수기 쿨다운)만 예약 퍼크다.
static func max_hp_bonus(perk: float) -> int:      # 투사 +15 · 수호자 +25(합산 = 40)
	return int(maxf(perk, 0.0))

static func damage_bonus(perk: float) -> float:    # 투사 +10% · 광전사 +15%(합산 = 0.25)
	return maxf(perk, 0.0)

static func crit_chance_mult(perk: float) -> float:  # 척후 ×1.5
	return maxf(perk, 1.0)

static func crit_power_mult(perk: float) -> float:   # 결사 ×2
	return maxf(perk, 1.0)

# 곡예사(DIM_SPECIAL_COOLDOWN) — **예약 퍼크**. 무기 특수동작(RMB)이 장비 클러스터 서랍에 묶여
# 있어 소비처가 아예 없다(ADR-0063 결정 9 "선택은 가능하되 효과 보류 명시"). 이 함수는 그 사실을
# 코드로 못 박아 두는 자리다 — 서랍이 열리면 여기 반환값이 쿨다운 계수가 된다.
static func special_cooldown_factor(_perk: float) -> float:
	return 1.0   # ★예약: 지금은 무슨 값이 와도 중립(효과 보류)
