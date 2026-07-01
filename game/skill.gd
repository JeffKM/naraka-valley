extends RefCounted
class_name FarmSkill
# S1-6 — 농사 숙련도(스킬 0~10) 순수 규칙. greybox-spec §3.2·§8.9 · ADR-0019(2축)/ADR-0027(AoE=도구).
#
# 목적: ROADMAP S1-6 — "농사 숙련 곡선이 혼력 감산으로 실효되는지"를 한 곳에서 정의한다.
#       XP는 세이브 상태라 main이 스칼라(_farming_xp)로 들고(별도 노드 없음, Q4), 이 파일은
#       그 XP를 레벨·감산 계수로 옮기는 순수 함수만 든다(foxfire.gd와 같은 결 — 파생 규칙, 무상태).
#
# 설계 메모(§3.2 불변식 — 어기면 ADR-0019/0027 위반):
#   - 농사 스킬 = 혼력 감산 + 작업 속도 두 축만. ❌AoE(도구 티어) ❌+%가치(멜) ❌품질(비료)
#     ❌혼력 풀 크기(행동당 감산만) ❌레벨 게이팅("평평≠막힘", L0도 전 동작 100% 가동).
#   - energy_factor/speed_factor는 대칭 곡선(레벨당 −3%, L10→0.70). 지금 작업 속도는 즉시라
#     speed_factor는 계산만 두고 실효 단축은 S1-10 애니 도입 시(§8.9 no-op). 혼력 감산만 실효.
#   - 미호 관계 레이어(농사 XP 가속)는 이 곡선 *위에* 후행으로 곱해진다(ADR-0019 — 이 파일 밖).

# ── XP 임계(L1..L10) — greybox-spec §3.2 ────────────────────────────────────
# level_for_xp가 "이 임계 이하를 몇 개 넘겼나"로 레벨을 센다. 곡선은 후반 가파른 누진(스타듀 결).
const XP_THRESHOLDS := [100, 300, 600, 1000, 1500, 2100, 2800, 3600, 4500, 5500]  # L1..L10
const MAX_LEVEL := 10

# ── 조회(XP → 레벨/감산 계수) ─────────────────────────────────────────────────
# 누적 XP → 레벨(0..10). 임계를 넘긴 개수 = 레벨. cap 10(그 이상은 XP만 쌓임, 레벨 정체).
static func level_for_xp(xp: int) -> int:
	var lv := 0
	for threshold in XP_THRESHOLDS:
		if xp >= threshold:
			lv += 1
		else:
			break
	return lv

# 혼력 감산 계수(실효 축). 레벨당 −3% → L0=1.0 · L10=0.70. 행동당 비용에 곱한다(main 주입).
static func energy_factor(level: int) -> float:
	return 1.0 - 0.03 * float(clampi(level, 0, MAX_LEVEL))

# 작업 속도 계수(계산만, no-op — §8.9). 대칭 곡선. S1-10 애니 도입 시 실효 단축에 소비.
static func speed_factor(level: int) -> float:
	return 1.0 - 0.03 * float(clampi(level, 0, MAX_LEVEL))
