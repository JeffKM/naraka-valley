extends Node
class_name Larder
# ★[S6-T1 / ADR-0064 결정 3] 곳간 — 카페 융합 메뉴의 재고 적재처.
#
# 목적: 활동 산출물을 *출하대로 팔지(즉시 골드·낮음)* 아니면 *곳간에 쟁일지(고마진 융합 메뉴
#       재료·나중)* 를 손에 잡히는 선택으로 만든다(CONTEXT [곳간] — "같은 영혼 호박을 팔 것인가
#       메뉴로 키울 것인가"). 서빙 시 NPC 직원이 여기서 재고를 자동 차감한다(차감 배선 = T2).
#
# 설계 메모:
#   - shipping_bin.gd 문법을 그대로 복제한다: 단일 책임 재고 + `changed` 시그널 + 얇은
#     to_save/load_save. 골드·인벤토리 조율은 호출 측(main)이 맡고 이 노드는 "무엇이 얼마나
#     쟁여져 있나"만 든다(wallet을 모른다 — 출하함과 같은 디커플링).
#   - ★ **품질 무차원 평 dict `{id: count}`**다(출하함의 `{id: {quality: count}}` 중첩과 갈린다).
#     근거: 메뉴는 품질 무영향(catalog §1-B 확정)이라 은/금을 나눠 들 이유가 없다 — 나눠 들면
#     차감 시 "어느 등급을 먹일까"라는 무의미한 판정이 하나 더 생긴다. 등급을 실어 넣어도
#     여기서는 등급이 지워진다(add가 quality를 아예 안 받는다 = 계약이 그 사실을 말한다).
#   - ★ **스타듀 냉장고의 "인벤+저장고 가상 연결"은 비채택**(ADR-0064 결정 3). 곳간에 *명시적으로
#     적재하는 행위* 자체가 출하 vs 곳간 선택의 텍스처라, 인벤토리를 자동 참조하면 그 선택이 지워진다.
#   - 용량은 **총 개수** 상한이다(종수가 아니라). 30 = *잠정 레버*(ADR-0064 결정 3·7 — 카페
#     마일스톤 2단에서 50으로 여는 그 값). 넘치는 분은 거절하되 들어갈 만큼은 받는다(부분 적재 —
#     "다 안 들어가니 하나도 못 넣는다"는 코지 톤에 어긋난다).
#   - 손상 방어: 카탈로그에 없는 id·음수 개수는 받지 않고(add), load_save가 정제한다(출하함 결).

signal changed()   # 재고가 바뀐 프레임(main이 곳간 패널·HUD 갱신)

# 재고 상한(총 개수). ★ 잠정 레버 — 카페 일구기 2단이 이 값을 연다(ADR-0064 결정 7).
const CAPACITY := 30

# 적재 재고 {id: count}. 품질 무차원 평 dict(위 설계 메모). 빈 dict = 곳간 빔. 0이 된 id는 즉시 제거.
var stock: Dictionary = {}

# id를 n개까지 적재하고 **실제로 들어간 개수**를 돌려준다(용량 초과분은 거절 — 부분 적재).
# 인벤토리 차감은 호출 측이 실제 적재량만큼 한다(0이면 아무 일도 일어나지 않는다).
# 품질 인자가 없는 것이 계약이다 — 곳간은 등급을 안 든다(위 설계 메모).
func add(id: String, n: int = 1) -> int:
	if n <= 0 or not ItemCatalog.has_item(id):
		return 0
	var moved := mini(n, free_space())
	if moved <= 0:
		return 0
	stock[id] = int(stock.get(id, 0)) + moved
	changed.emit()
	return moved

# 적재분 id를 n개까지 도로 빼낸다(회수 — "잘못 쟁였네"). 실제로 뺀 개수 반환. 0이 되면 키를 지운다.
func take_back(id: String, n: int = 1) -> int:
	if n <= 0 or not stock.has(id):
		return 0
	var have := int(stock[id])
	var moved := mini(have, n)
	var left := have - moved
	if left > 0:
		stock[id] = left
	else:
		stock.erase(id)
	if moved > 0:
		changed.emit()
	return moved

# ★[S6-T2 / ADR-0064 결정 4] 서빙이 시그니처 재료를 **먹어 없앤다**. take_back과 갈리는 건 의도다 —
# 회수는 물건이 백팩으로 돌아가지만(호출 측이 인벤에 넣는다) 소비는 메뉴가 되어 사라진다. 원자적:
# 재고가 n보다 적으면 **한 개도 안 건드리고 0**을 돌려준다(호출 측은 그걸 보고 기본 메뉴로 폴백한다 —
# 부분 차감이 되면 "재료를 먹었는데 기본 메뉴가 나가는" 손실 경로가 생긴다).
func consume(id: String, n: int = 1) -> int:
	if n <= 0 or count_of(id) < n:
		return 0
	return take_back(id, n)

# ── 조회(서빙 차감·패널 렌더가 쓴다) ─────────────────────────────────────────
func count_of(id: String) -> int:
	return int(stock.get(id, 0))

func has_stock(id: String) -> bool:
	return count_of(id) > 0

# 적재된 id 목록(곳간 패널이 순회). 선언 순이 아니라 넣은 순이다(dict 삽입 순서).
func ids() -> Array:
	return stock.keys()

# 적재 총 개수(용량 판정·HUD).
func total() -> int:
	var sum := 0
	for id in stock:
		sum += int(stock[id])
	return sum

func free_space() -> int:
	return maxi(0, CAPACITY - total())

func is_full() -> bool:
	return free_space() <= 0

func is_empty() -> bool:
	return stock.is_empty()

# ── 세이브/로드(적재 재고 직렬화) ────────────────────────────────────────────
func to_save() -> Dictionary:
	return {"stock": stock.duplicate(true)}

# 복원: 재고 dict를 정제해 갈아끼운다. 손상(dict 아님·이상 id·음수·용량 초과)은 걸러 안전하게
# (출하함·인벤토리 결). ★ 세이브 키 자체가 없는 구버전은 main이 이 함수를 아예 안 불러 빈 곳간으로
# 시작한다(하위호환 — 출하함·상자가 쓰는 그 관례).
func load_save(data: Dictionary) -> void:
	stock = {}
	var raw: Variant = data.get("stock", {})
	if typeof(raw) == TYPE_DICTIONARY:
		for id in raw:
			var sid := str(id)
			if not ItemCatalog.has_item(sid):
				continue
			var c := int(raw[id])
			if c <= 0:
				continue
			# 용량은 로드 때도 지킨다 — CAPACITY를 낮추는 밸런싱 후 옛 세이브를 열어도 상한이 선다.
			var room := free_space()
			if room <= 0:
				break
			stock[sid] = int(stock.get(sid, 0)) + mini(c, room)
	changed.emit()
