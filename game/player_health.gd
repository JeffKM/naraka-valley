extends RefCounted
class_name PlayerHealth
# ★[S5-T4 / ADR-0063 결정 4] 체력(HP) — 혼력과 **완전 별도**인 두 번째 자원(ADR-0011).
#
# 목적: energy.gd(SoulEnergy)의 동형 짝이다. 혼력이 *노동* 자원(괭이질·채굴마다 줄고 취침에 가득
#       차는)이라면 체력은 *생존* 자원이다 — 공격엔 한 점도 안 들고(전투 행동비용 0), 맞을 때만
#       줄고, 0이 되면 기절(무대 퇴장 + 시간 +2h)이며, 취침에 가득 찬다.
#
# 왜 SoulEnergy를 재사용하지 않는가(ADR-0011 확정 — 재론 아님):
#   두 자원의 *의미*가 다르다. 혼력이 바닥나면 **행동이 막히고**(can_act 게이트) 체력이 바닥나면
#   **무대에서 쫓겨난다**(기절). 하나로 합치면 "채굴하다 지쳐 죽는" 스타듀 이전 세대의 설계가 되고,
#   그건 ADR-0011이 번아웃 방지를 이유로 명시적으로 걷어낸 방향이다.
#
# 설계 메모(energy.gd와 다른 점만):
#   - **RefCounted**(SoulEnergy는 씬 노드 $SoulEnergy). 이 자원은 씬 트리에 설 이유가 없고 —
#     _process도 자식도 없다 — ToolTier·MineFloors와 같은 순수 원장 결이다. main이 .new()로 낳는다.
#   - **MAX가 가변**이다(SoulEnergy.MAX는 상수 100). 최대 HP = 100 + 전투 레벨 성장분 + 전문직 몫이라
#     레벨업·전문직 선택 때마다 갱신된다. 그래서 `MAX` 상수 대신 `maximum` 필드를 들고, HUD·세이브가
#     그 필드를 읽는다(VitalsHud가 SoulEnergy.MAX를 직접 읽던 것과 대비 — 여기선 인스턴스에서 읽는다).
#   - **성장 곡선은 CombatSkill이 단일 출처**다(hp_bonus). 이 파일은 base 100과 "어떻게 합치나"만
#     알고 "레벨당 몇인지·어느 레벨이 예외인지"를 모른다(PlayerHealth → CombatSkill 단방향).
#   - **세이브는 current 하나뿐**이다. maximum은 (전투 XP + 전문직 선택)에서 파생되므로 저장하면
#     두 진실원이 생긴다 — 로드 순서는 반드시 `_combat_xp` → `refresh_max` → `load_save`다.

signal changed(current: int, maximum: int)  # HP가 바뀐 프레임(main이 HUD 갱신)
signal depleted()                            # HP 0 — 기절(main이 무대 퇴장·시간 페널티를 실행)

const BASE_MAX := 100        # 전투 Lv0·전문직 0에서의 최대 체력(ADR-0063 결정 4 "기본 100")

var maximum: int = BASE_MAX
var current: int = BASE_MAX

# ── 최대 HP 산정(순수·정적) ─────────────────────────────────────────────────
# base 100 + 레벨 성장분(CombatSkill — Lv5/10 제외) + 전문직 몫(투사 15 + 수호자 25 = 합산 40).
# ★ prof_bonus를 **합산**으로 받는 이유: 수호자는 투사를 선행으로 요구하므로 두 퍼크가 늘 함께
#   존재한다(main._perk_sum가 그 합을 만든다 — max로 접으면 25만 남아 스타듀 곡선과 갈린다).
static func max_for(combat_level: int, prof_bonus: int = 0) -> int:
	return BASE_MAX + CombatSkill.hp_bonus(combat_level) + maxi(prof_bonus, 0)

# ── 최대 HP 갱신(레벨업·전문직 선택·로드 직후 호출) ─────────────────────────
# ★ 최대가 **늘면 그만큼 현재도 채운다**(줄면 상한으로 자른다). 레벨업이 즉시 체감되게 하는 선택이고
#   (스타듀도 레벨업 시 현재 체력이 함께 오른다), "최대만 늘고 현재는 그대로"면 갱도 안에서 오른
#   레벨이 그 층에선 아무 도움이 안 된다. *잠정*(owner 큐).
func refresh_max(combat_level: int, prof_bonus: int = 0) -> void:
	var next_max := max_for(combat_level, prof_bonus)
	if next_max == maximum:
		return
	var grew := next_max - maximum
	maximum = next_max
	current = clampi(current + maxi(grew, 0), 0, maximum)
	changed.emit(current, maximum)

# ── 질의 ────────────────────────────────────────────────────────────────────
func is_down() -> bool:
	return current <= 0

func ratio() -> float:
	return clampf(float(current) / float(maxi(maximum, 1)), 0.0, 1.0)

# ── 소모·회복 ───────────────────────────────────────────────────────────────
# 피해를 입는다(실제로 깎인 양 반환 — 0이면 무동작). 0에 닿으면 depleted를 발화한다.
# ★ 무적 창(피격 0.8초·하강 1초) 판정은 **여기 없다** — 그건 "누가 언제 때렸나"의 시간 축이라
#   main이 든다(자원은 시계를 모른다. SoulEnergy가 취침 훅을 모르는 것과 같은 경계).
func damage(amount: int) -> int:
	if amount <= 0 or current <= 0:
		return 0
	var dealt := mini(amount, current)
	current -= dealt
	changed.emit(current, maximum)
	if current <= 0:
		depleted.emit()
	return dealt

# 소모품 회복(명부환 등 — 아이템 자체는 S5-T6). 실제로 채워진 양 반환.
func heal(amount: int) -> int:
	if amount <= 0 or current >= maximum:
		return 0
	var healed := mini(amount, maximum - current)
	current += healed
	changed.emit(current, maximum)
	return healed

# 취침 풀회복(GameClock.day_advanced에 연결 — energy.refill과 나란히 붙는다).
# ★ 기절 직후 복귀에도 같은 함수를 쓴다: 기절의 대가는 **시간뿐**이므로(ADR-0011) HP는 온전히 돌려준다.
func refill() -> void:
	current = maximum
	changed.emit(current, maximum)

# ── 세이브/로드 ─────────────────────────────────────────────────────────────
# ★ 상태가 정수 current 하나뿐이다(maximum은 파생 — 위 클래스 주석의 로드 순서 참조).
# ★ 하위호환: 키 없는 구세이브 = 풀 HP(아래 load_save 기본값이 maximum). 전투가 없던 세이브를
#   불러와 반쯤 죽은 상태로 시작하는 일이 없다.
func to_save() -> Dictionary:
	return {"current": current}

# ★ 하한이 **1**인 이유: HP 0은 기절이고 기절은 즉시 refill로 접히므로(main._faint) 0이 저장된
#   세이브는 구조적으로 도달 불가 = 손상이다. 그런 파일을 불러와 조작 불가 상태로 얼어붙는 것보다
#   1로 되살려 걸어 나가게 하는 편이 안전하다(inventory._sanitize의 "조용히 성립하는 상태로" 결).
func load_save(data: Dictionary) -> void:
	current = clampi(int(data.get("current", maximum)), 1, maximum)
	changed.emit(current, maximum)
