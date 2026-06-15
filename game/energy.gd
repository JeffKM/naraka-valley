extends Node
class_name SoulEnergy
# T2.4 — 혼력(에너지): 행동당 소모 + 취침 회복.
#
# 목적: "행동 시 혼력이 줄고, 0이면 행동이 막히며, 취침하면 가득 찬다"를
#       회색 UI만으로 검증한다(ADR-0001 그레이박스, CONTEXT '혼력').
#
# 설계 메모:
#   - clock.gd(GameClock)·field.gd(FarmField)와 같은 결: 이 노드는 "혼력"이라는
#     단일 책임만 가진다. 화면 표시(HUD)·소모 트리거(밭 상호작용)·회복 트리거
#     (취침)는 main.gd가 맡고, 여기서는 상태(현재 혼력)와 시그널만 제공한다.
#   - 회복 트리거: GameClock.day_advanced에 main이 refill()을 연결한다(시그널
#     디커플링). 작물 성장(T2.3 advance_day)과 같은 훅에 나란히 붙는다.
#   - CONTEXT '혼력'대로 첫 슬라이스는 "행동당 고정 소모"라는 단순 규칙으로 시작한다.
#     어느 행동이 얼마를 쓰는지(또는 무료인지)의 차등·밸런싱은 후속(T4.3).
#     MAX는 COST의 배수(100 = 10×10)라, 딱 10번 행동하면 정확히 0이 되어 막힌다
#     ("0이면 행동이 막힌다"는 완료기준이 깔끔히 성립).
#   - T2.5 세이브/로드 — 상태가 정수 current 하나뿐이라 그대로 직렬화된다.

signal changed(current: int, maximum: int)  # 혼력이 바뀐 프레임(main이 HUD 갱신)
signal depleted()                            # 한 동작 비용도 못 낼 만큼 바닥남(향후 연출 훅)

const MAX := 100             # 가득 찬 혼력(하루 시작값)
const COST_PER_ACTION := 10  # 행동 한 번당 고정 소모(그레이박스 기준값, 밸런싱 후속)

var current: int = MAX

# 한 동작을 수행할 여력이 있는가(= 비용을 낼 수 있는가). false면 main이 행동을 막는다.
func can_act() -> bool:
	return current >= COST_PER_ACTION

# 한 동작분 혼력을 쓴다. 여력이 없으면 아무것도 하지 않고 false(음수 방지).
# 성공 시 changed를, 그 결과 바닥나면 depleted를 발화한다.
func spend() -> bool:
	if not can_act():
		return false
	current -= COST_PER_ACTION
	changed.emit(current, MAX)
	if not can_act():
		depleted.emit()
	return true

# 취침 회복: 혼력을 가득 채운다(GameClock.day_advanced에 연결).
func refill() -> void:
	current = MAX
	changed.emit(current, MAX)

# ── T2.5 세이브/로드 ──────────────────────────────────────────────────────
# 상태가 정수 current 하나뿐이라 그대로 직렬화된다. 복원 시 0..MAX로 잘라
# 손상된 세이브에도 안전하게 만들고, changed로 HUD를 즉시 갱신한다.
func to_save() -> Dictionary:
	return {"current": current}

func load_save(data: Dictionary) -> void:
	current = clampi(int(data.get("current", MAX)), 0, MAX)
	changed.emit(current, MAX)
