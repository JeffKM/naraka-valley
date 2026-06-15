extends Node
class_name Wallet
# T3.1 — 골드 지갑(카페 출하대 경제의 화폐).
#
# 목적: "수확물을 팔아 골드를 얻고 그 골드로 씨앗을 사서 다시 심는 한 바퀴"가
#       돌게 하는 경제의 화폐 단위를 담는다(ROADMAP T3.1, ADR-0001 그레이박스).
#
# 설계 메모:
#   - clock.gd·energy.gd와 같은 결: 이 노드는 "골드 잔액"이라는 단일 책임만 가진다.
#     화면 표시(HUD)·획득/지출 트리거(카페 출하대)는 main.gd가 맡고, 여기서는
#     상태(현재 골드)와 changed 시그널만 제공한다. main은 시그널로 디커플링해 붙는다.
#   - SoulEnergy가 음수 방지(can_act→spend)를 둔 것과 같은 결로, spend()는 잔액이
#     모자라면 아무것도 하지 않고 false를 돌려 골드가 음수로 가지 않게 한다.
#   - START_GOLD는 0이다. 첫 사이클의 종잣돈은 골드가 아니라 시작 씨앗으로 준다
#     (Inventory.START_SEEDS). 그래서 "첫 수확 → 첫 판매"로 골드가 처음 생기고,
#     그 골드로 씨앗을 재구매하는 순환이 자연스럽게 닫힌다.
#   - CONTEXT상 카페 경제·회계는 멜의 속죄 영역(예정)이지만, 지금은 NPC 없이
#     화폐만 그레이박스로 둔다. 공식 화폐명이 정해지기 전까지 표시는 "골드".
#   - T2.5 세이브/로드 — 상태가 정수 gold 하나뿐이라 그대로 직렬화된다.

signal changed(gold: int)  # 골드가 바뀐 프레임(main이 HUD 갱신)

const START_GOLD := 0  # 새 게임 시작 잔액(종잣돈은 시작 씨앗으로 대신 지급)

var gold: int = START_GOLD

# 이 비용을 낼 여력이 있는가(= 씨앗을 살 수 있는가). false면 호출 측이 구매를 막는다.
func can_afford(cost: int) -> bool:
	return gold >= cost

# 골드를 번다(수확물 판매). 음수 금액은 무시한다(잘못된 호출 방어).
func earn(amount: int) -> void:
	if amount <= 0:
		return
	gold += amount
	changed.emit(gold)

# 골드를 쓴다(씨앗 구매). 잔액이 모자라면 아무것도 하지 않고 false(음수 방지).
func spend(cost: int) -> bool:
	if cost <= 0 or not can_afford(cost):
		return false
	gold -= cost
	changed.emit(gold)
	return true

# ── T2.5 세이브/로드 ──────────────────────────────────────────────────────
# 상태가 정수 gold 하나뿐이라 그대로 직렬화된다. 복원 시 음수면 0으로 잘라
# 손상된 세이브에도 안전하게 만들고, changed로 HUD를 즉시 갱신한다.
func to_save() -> Dictionary:
	return {"gold": gold}

func load_save(data: Dictionary) -> void:
	gold = maxi(0, int(data.get("gold", START_GOLD)))
	changed.emit(gold)
