extends RefCounted
class_name FishSkill
# ★[S3-T6 / ADR-0061 결정 6] 낚시 숙련도(스킬 0~10) 순수 규칙 — FarmSkill·ForageSkill 대칭.
#
# 목적: ROADMAP Slice 3 — "낚시를 반복하면 릴 격투가 *어떻게* 쉬워지는가"를 한 곳에 정의한다.
#       XP는 세이브 상태라 main이 스칼라(_fishing_xp)로 들고(별도 노드 없음 — _farming_xp 관례),
#       이 파일은 그 XP를 레벨·계수로 옮기는 순수 함수만 든다(skill.gd·foxfire.gd와 같은 결).
#
# 설계 메모(어기면 ADR-0061 결정 6 / ADR-0008 위반):
#   - **XP 곡선은 5스킬 공통 기반**(ADR-0052 — 채집이 이미 FarmSkill 곡선을 공유한다). 곡선의 단일
#     출처는 FarmSkill이고 여기선 *위임*만 한다(수치 복제 0 — 어긋날 여지 자체를 없앤다).
#   - **레벨 효과 = 카탈로그 ⓐ정량 3종만**(§1-D "릴 텐션 윈도우↑ · 혼력 절감 · 퍼펙트 릴"):
#     ㉠ tension_safe_bonus(줄 끊김↓) ㉡ energy_factor(후킹 혼력 절감) ㉢ perfect_window_add(퍼펙트 창↑).
#     ❌품질 직접 보정(품질 = 퍼펙트 릴 + 기어 + 전문직 — 스킬이 등급을 *직접* 밀면 축이 겹친다)
#     ❌+판매가(ADR-0052 §1 — 관계 곱셈기 전용) ❌레벨 게이팅(L0도 전 동작 100% 가동, "평평≠막힘").
#   - **관계 곱셈기 0**(ADR-0030 결정 1 / ADR-0008): 낚시는 관계 가속을 하나도 안 받는 유일한 노동
#     루프다. 이 파일에 호감도·여우불이 들어오면 그 정체성이 깨진다.
#   - **주입 경로**: 세 계수는 전부 FishingSession의 `rod`/`mods` dict로 들어간다(main._fishing_mods).
#     FishingSession은 스킬을 모른다 — 중립 기본값(1.0/0.0) 위에 얹히는 dict 하나가 유일한 접점이다.

# ── 레벨 상한(FarmSkill.MAX_LEVEL과 같은 눈금 — 어긋나면 fishing_skill_test ⓐ가 잡는다) ──
const MAX_LEVEL := 10

# ── 포획 XP(ADR-0061 결정 6 잠정값: 소 10·중 20·대 40·전설 100) ────────────────
# 체급 비례 = "큰 놈일수록 배운다". 전설이 100인 건 평생 몇 번 없는 사건이라 한 번에 L1을 채워도 되는
# 규모다(임계 100 = L1). 소 10 → L1까지 10마리 = 첫 레벨이 한 세션 안에 닿는다(초반 체감).
const CATCH_XP := [10, 20, 40, 100]
# 퍼펙트 릴 1회당 보너스 XP(잠정) — "잘 잡으면 더 배운다"의 작은 손맛. 체급 XP를 넘지 않게 소량.
const PERFECT_XP := 2

# ── 레벨당 효과(전부 그레이박스 잠정 — ADR-0028 스펙카드 잠금 대상) ────────────
# ㉠ 텐션 안전 보너스: 레벨당 +0.01 → L10 = 0.10. S3-T4 코르크 보버(0.15)와 같은 눈금이라
#   "만렙 스킬 ≒ 코르크 보버 2/3"으로 읽힌다(스킬이 기어를 대체하지도, 무의미하지도 않은 지점).
const TENSION_SAFE_PER_LEVEL := 0.01
# ㉡ 혼력 절감: 레벨당 −3% → L10 = 0.70. FarmSkill.energy_factor와 **완전 동형**(활동 간 체감 통일).
const ENERGY_PER_LEVEL := 0.03
# ㉢ 퍼펙트 릴 창 가산: 레벨당 +0.02s → L10 = +0.2s(기본 PERFECT_WINDOW 0.3 → 0.5, 약 1.67배).
#   창이 커질수록 크리를 *의도적으로* 노릴 수 있게 된다(카탈로그 ⓐ㉢ "품질↑ 확률"의 실효 경로).
const PERFECT_WINDOW_PER_LEVEL := 0.02

# ★[S3-T7 / ADR-0061 결정 7] 게잡이통 구매 해금 레벨(스타듀 Crab Pot 레시피 lvl3 1:1 — 잠정).
#   여기 두는 건 "낚시 스킬이 무엇을 해금하는가"가 스킬의 소관이기 때문. 소비는 S3-T7(매대 게이트).
const CRAB_POT_LEVEL := 3

# ── 조회(XP → 레벨) ─────────────────────────────────────────────────────────
# 누적 XP → 레벨(0..10). ★곡선은 FarmSkill이 단일 출처(ADR-0052 "5스킬 공통 기반") — 여기선 위임만
# 한다. 수치를 복제하면 두 곡선이 조용히 어긋날 수 있고, 숙련 탭(_skill_row)도 FarmSkill 임계로 진행바를
# 그리므로 위임이 곧 정합이다.
static func level_for_xp(xp: int) -> int:
	return FarmSkill.level_for_xp(xp)

# 레벨 임계 배열(숙련 탭·테스트 조회용 — 공통 곡선 재수출).
static func xp_thresholds() -> Array:
	return FarmSkill.XP_THRESHOLDS

# ── 레벨 효과(FishingSession rod/mods 주입값) ───────────────────────────────
# ㉠ 텐션 상승 감쇠 비율(rod.tension_safe_bonus에 *가산*된다 — 기어 보너스 위에 얹힘).
static func tension_safe_bonus(level: int) -> float:
	return TENSION_SAFE_PER_LEVEL * float(clampi(level, 0, MAX_LEVEL))

# ㉡ 후킹 혼력 배수(mods.energy_factor). L0 = 1.0(정확히 중립) · L10 = 0.70.
static func energy_factor(level: int) -> float:
	return 1.0 - ENERGY_PER_LEVEL * float(clampi(level, 0, MAX_LEVEL))

# ㉢ 퍼펙트 릴 창 가산(초, mods.perfect_window_add). L0 = 0.0(정확히 중립).
static func perfect_window_add(level: int) -> float:
	return PERFECT_WINDOW_PER_LEVEL * float(clampi(level, 0, MAX_LEVEL))

# ── 포획 XP 산정 ────────────────────────────────────────────────────────────
# 체급(0~3) + 퍼펙트 릴 횟수 → 이번 포획의 XP. 놓친 격투(ESCAPED)는 0이다 — 호출 측(main)이
# 포획 분기에서만 부른다("리스크는 혼력으로 이미 냈다, 배움은 성공에만").
static func xp_for_catch(weight_class: int, perfect_count: int) -> int:
	return int(CATCH_XP[clampi(weight_class, 0, CATCH_XP.size() - 1)]) \
		+ PERFECT_XP * maxi(perfect_count, 0)
