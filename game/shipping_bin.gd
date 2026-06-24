extends Node
class_name ShippingBin
# Phase 2.7 C2 — 무인 출하함(스타듀 출하상자 결). 멜 F 게이트를 떼고(ADR-0021 출하대 무인화)
# "넣어 두면 다음 아침에 골드로 정산"되는 대기 상자로 판매를 바꾼다.
#
# 목적: T3.1~T5.3의 *즉시 판매*(멜 앞에서 S → 그 자리에서 골드)를 *익일 정산*으로 바꾼다.
#       플레이어가 출하함에 수확물을 드롭하면 인벤토리에서 빠져 여기 '대기(pending)'로 쌓이고,
#       취침 전이면 도로 빼낼 수 있다(롤백). 다음 날 아침(day_advanced) settle()이 대기분을
#       판매가로 환산해 골드로 정산하고 상자를 비운다(ADR-0021 §Consequences "출하대 무인화").
#
# 설계 메모:
#   - wallet.gd·inventory.gd와 같은 결: "출하 대기 재고"라는 단일 책임 + changed 시그널 +
#     to_save/load_save. 골드 입금·인벤토리 차감은 호출 측(main)이 조율한다(디커플링) — 이 노드는
#     "무엇이 얼마나 대기 중인가"만 들고, 정산 금액(settle)만 돌려준다(wallet을 모른다).
#   - 가격은 ItemCatalog.price_of(수확물=sell_price)에서 파생한다(데이터 단일 출처). 마일스톤
#     누적매출(_cafe_revenue_total)엔 여전히 안 든다 — 출하함 raw 판매는 *카페를 운영한* 매출이
#     아니다(ADR-0009, milestone). main이 settle 골드를 wallet엔 넣되 마일스톤엔 안 더한다.
#   - 대기분은 세이브한다(롤백을 위해 — 취침 없이 저장·종료해도 넣어 둔 게 남아 다음 아침 정산).
#     수확물 외 아이템도 일반적으로 담을 수 있게 두되(price_of 위임), main은 수확물만 드롭한다.
#   - 손상 방어: 카탈로그에 없는 id·음수 개수는 받지 않고(add), load_save가 정제한다(inventory 결).

signal changed()  # 대기 내용이 바뀐 프레임(main이 출하함 패널·HUD 갱신)

# 출하 대기(id → 개수). 정산 전까지 여기 쌓인다. 빈 dict = 대기 없음.
var pending: Dictionary = {}

# id n개를 출하 대기에 넣는다(인벤토리 차감은 호출 측이 먼저 한다). 카탈로그에 없거나 n<=0이면 거절.
func add(id: String, n: int = 1) -> bool:
	if n <= 0 or not ItemCatalog.has_item(id):
		return false
	pending[id] = int(pending.get(id, 0)) + n
	changed.emit()
	return true

# 대기분 id를 n개까지 도로 빼낸다(취침 전 롤백). 실제로 뺀 개수를 돌려준다(보유분보다 많이 요청하면
# 보유분만큼). 0이 되면 키를 지운다. 호출 측은 반환량만큼 인벤토리에 도로 넣는다.
func take_back(id: String, n: int = 1) -> int:
	var have := int(pending.get(id, 0))
	if have <= 0 or n <= 0:
		return 0
	var moved := mini(have, n)
	var left := have - moved
	if left > 0:
		pending[id] = left
	else:
		pending.erase(id)
	changed.emit()
	return moved

# 대기분 id의 개수(없으면 0).
func count_of(id: String) -> int:
	return int(pending.get(id, 0))

# 대기 중인 id 목록(출하함 패널이 순회).
func ids() -> Array:
	return pending.keys()

# 대기분 총 개수(빈 판정·HUD).
func total() -> int:
	var sum := 0
	for id in pending:
		sum += int(pending[id])
	return sum

func is_empty() -> bool:
	return pending.is_empty()

# 지금 정산하면 받을 골드(미리보기). 각 대기분 개수 × 판매가(ItemCatalog.price_of).
func preview_gold() -> int:
	var total_gold := 0
	for id in pending:
		total_gold += int(pending[id]) * ItemCatalog.price_of(id)
	return total_gold

# 익일 정산: 대기분을 골드로 환산해 그 금액을 돌려주고 상자를 비운다(day_advanced에서 호출).
# 골드 입금은 호출 측(main → wallet.earn). 비었으면 0.
func settle() -> int:
	var gold := preview_gold()
	if not pending.is_empty():
		pending.clear()
		changed.emit()
	return gold

# ── 세이브/로드(대기 내용 직렬화 — 롤백·정산 보존) ───────────────────────────
func to_save() -> Dictionary:
	return {"pending": pending.duplicate(true)}

# 복원: 대기 dict를 정제해 갈아끼운다. 손상(dict 아님·이상 id·음수)은 걸러 안전하게(inventory 결).
func load_save(data: Dictionary) -> void:
	pending = {}
	var raw: Variant = data.get("pending", {})
	if typeof(raw) == TYPE_DICTIONARY:
		for id in raw:
			var sid := str(id)
			var n := int(raw[id])
			if n > 0 and ItemCatalog.has_item(sid):
				pending[sid] = n
	changed.emit()
