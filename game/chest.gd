extends Node
class_name StorageChest
# ADR-0048 Phase D(S1-14) — 저장 상자(순수 보관 컨테이너, CONTEXT [저장 상자]).
#
# 목적: 출하함(ShippingBin=넣으면 익일 판매)·매대(구매)와 구분되는 *경제 0*의 순수 보관함이다.
#       집·창고에 두고 백팩이 찰 때 아이템을 옮겨 두는 스타듀 상자 결 — 넣어도 팔리지 않고,
#       골드도 마일스톤도 안 건드린다(재고를 다른 그릇으로 옮길 뿐). inv_frame의 CTX_CHEST가
#       이 슬롯을 상단에 그리고, 클릭으로 백팩↔상자를 오간다(bin 드롭과 같은 UI 결, 방향만 양방향).
#
# 설계 메모:
#   - inventory.gd·shipping_bin.gd와 같은 결: 단일 책임(보관 슬롯) + changed 시그널 + to_save/load_save.
#     골드·판매를 모른다(디커플링) — main이 백팩과의 아이템 이동만 조율한다.
#   - 슬롯 모델은 Inventory와 동일한 {id, count, quality}. Inventory를 *상속하지 않는다* — Inventory는
#     _ready에서 새 게임이면 START_KIT(도구·씨앗)를 채우므로, 상속하면 빈 상자가 도구로 차 버린다.
#     그래서 필요한 슬롯 연산(add/remove_at/move/접근자)만 lean하게 이식한다(품질 스택 키 = (id,quality)).
#   - CHEST_SIZE는 그레이박스 수치(용량 튜닝은 후속) — 백팩과 같은 6×2 그리드로 프레임 상단에 맞춘다.
#     칸을 늘리려면 이 상수만 키운다(슬롯 위치·세이브 라운드트립 불변, Inventory.SIZE와 같은 결).
#   - 손상 방어: 카탈로그에 없는 id·음수 개수는 받지 않고(add), load_save가 정제한다(inventory 결).

signal changed()  # 보관 내용이 바뀐 프레임(main이 상자 패널 갱신)

const SIZE := 12   # 그레이박스 보관 칸(= 6×2, 프레임 상단 컨텍스트 영역에 맞춤). 용량 확장은 이 값만 키운다.

# 슬롯 배열. 각 원소 = null(빈칸) 또는 {"id": String, "count": int, "quality": int}. 위치 고정(자동 압축 X).
var slots: Array = []

func _init() -> void:
	slots.resize(SIZE)   # null로 채워진다(_ready 전 접근 방어 — Inventory와 같은 결)

# ── 슬롯 접근자(inv_frame 그리기·히트테스트가 질의) ────────────────────────────
func id_at(i: int) -> String:
	if i < 0 or i >= slots.size() or slots[i] == null:
		return ""
	return slots[i]["id"]

func count_at(i: int) -> int:
	if i < 0 or i >= slots.size() or slots[i] == null:
		return 0
	return int(slots[i]["count"])

func quality_at(i: int) -> int:
	if i < 0 or i >= slots.size() or slots[i] == null:
		return 0
	return int(slots[i].get("quality", 0))

# 이 id를 몇 개 보관 중인가(품질 무관 합산 — 백팩 `Inventory.count_of`와 같은 시그니처·같은 뜻).
# ★[폴리시] "세상 어딘가에 그 물건이 있는가"를 파생으로 묻는 판정(레어크로우 8종 소유)이 상자를
#   못 보면 상자에 넣는 순간 그 물건이 없어진 것으로 읽힌다 — 상자는 카테고리 필터가 없어 무엇이든
#   받으므로(store), 그런 판정이 볼 수 있게 접근자를 연다(보관 규칙은 한 줄도 안 바뀐다).
func count_of(id: String) -> int:
	var n := 0
	for s in slots:
		if s != null and s["id"] == id:
			n += int(s["count"])
	return n

func is_empty() -> bool:
	for s in slots:
		if s != null:
			return false
	return true

# ── 슬롯 연산(백팩↔상자 이동 = main 핸들러가 호출) ─────────────────────────────
# 첫 빈 슬롯 인덱스(-1 = 가득 참).
func _first_empty() -> int:
	for i in slots.size():
		if slots[i] == null:
			return i
	return -1

# 이 id가 든 첫 슬롯 인덱스(품질 무관 · -1 = 없음). 유니크 중복 거절이 쓴다(Inventory._find_id의 상자판).
func _find_id(id: String) -> int:
	for i in slots.size():
		if slots[i] != null and slots[i]["id"] == id:
			return i
	return -1

# (id, quality) 정확 일치 스택 인덱스(-1 = 없음). add가 합칠 스택을 찾는다.
func _find_stack(id: String, quality: int) -> int:
	for i in slots.size():
		var s: Variant = slots[i]
		if s != null and s["id"] == id and int(s.get("quality", 0)) == quality:
			return i
	return -1

# 아이템을 상자에 n개 넣는다(품질 보존). 같은 (id,quality) 스택에 합치거나 빈 슬롯에. 유니크(도구)는
# stackable=false라 항상 새 슬롯(1개)로 들어간다. 카탈로그에 없거나 n<=0이거나 상자가 가득이면 거절.
# 넣은 개수를 돌려준다(0 = 못 넣음). main이 백팩에서 그만큼만 뺀다(가득 부분 이동 안전).
func store(id: String, n: int = 1, quality: int = 0) -> int:
	if n <= 0 or not ItemCatalog.has_item(id):
		return 0
	var q := clampi(quality, 0, 3) if ItemCatalog.category_of(id) == ItemCatalog.CAT_HARVEST else 0
	if not ItemCatalog.stackable_of(id):
		# ★[폴리시 R6] **유니크는 한 상자에 하나뿐이다.** 적재에는 이 거절이 없었는데(Inventory.add_item의
		#   `if _find_id(id) >= 0: return false`가 여기엔 없었다) 복원은 `seen_unique`로 둘째 슬롯을
		#   버린다 — 즉 **적재가 허용하는 상태를 복원이 삭제**해, 값을 치른 태클·검이 세이브 왕복에서
		#   알림 없이 사라졌다. 두 방향의 규약을 load_save 쪽으로 맞춘다(그쪽이 유니크의 정의다).
		#   ★ 애초에 같은 유니크를 두 개 갖게 되던 입구(상자에 넣으면 매대 보유 판정이 풀리던 자리)는
		#     main의 `_stored_anywhere` 배선이 함께 막는다 — 여기는 그 마지막 방벽이다.
		if _find_id(id) >= 0:
			return 0
		var e := _first_empty()
		if e < 0:
			return 0
		slots[e] = {"id": id, "count": 1, "quality": 0}
		changed.emit()
		return 1
	var i := _find_stack(id, q)
	if i >= 0:
		slots[i]["count"] += n
		changed.emit()
		return n
	var empty := _first_empty()
	if empty < 0:
		return 0
	slots[empty] = {"id": id, "count": n, "quality": q}
	changed.emit()
	return n

# ★[폴리시 R6] 이 물건을 n개 받을 수 있는가 — **상태는 한 톨도 안 건드리고** 묻는다(store와 같은
#   판정을 그대로 복창한다). 되돌릴 수 없는 걷기를 하기 *전에* 둘 자리를 확인해야 하는 회수 사다리
#   (main._reclaim_can_store)가 쓴다. Inventory.can_add의 상자판이라 두 그릇의 질문이 같아진다.
func can_store(id: String, n: int = 1, quality: int = 0) -> bool:
	if n <= 0 or not ItemCatalog.has_item(id):
		return false
	if not ItemCatalog.stackable_of(id):
		return _find_id(id) < 0 and _first_empty() >= 0   # ★[폴리시 R6] store의 유니크 거절을 그대로 복창
	var q := clampi(quality, 0, 3) if ItemCatalog.category_of(id) == ItemCatalog.CAT_HARVEST else 0
	return _find_stack(id, q) >= 0 or _first_empty() >= 0

# 상자 슬롯 index를 통째로 빼내 그 내용을 돌려준다({id,count,quality} 또는 빈 dict). main이 백팩에
# 넣고, 실제로 들어간 만큼만 되돌린다(백팩 가득 부분 이동 = remove_at으로 정확히 차감).
func peek(index: int) -> Dictionary:
	if index < 0 or index >= slots.size() or slots[index] == null:
		return {}
	return slots[index].duplicate()

# 상자 슬롯 index에서 n개 제거(그 슬롯의 (id,quality)를 그대로 소진). 0이 되면 빈칸으로 남는다. 모자라면 false.
func remove_at(index: int, n: int = 1) -> bool:
	if index < 0 or index >= slots.size() or slots[index] == null:
		return false
	if n <= 0 or int(slots[index]["count"]) < n:
		return false
	slots[index]["count"] -= n
	if int(slots[index]["count"]) <= 0:
		slots[index] = null
	changed.emit()
	return true

# ── 세이브/로드(보관 내용 직렬화 — inventory와 같은 정제 방어) ──────────────────
func to_save() -> Dictionary:
	return {"slots": slots.duplicate(true)}

# 복원: 슬롯 배열을 정제해 갈아끼운다. 손상(배열 아님·이상 슬롯·이상 id·음수)은 빈칸으로 방어하고,
# 유니크(도구)는 개수 1로 자르고 중복 슬롯은 버린다(inventory._sanitize와 같은 결). 항상 SIZE칸.
func load_save(data: Dictionary) -> void:
	var clean: Array = []
	clean.resize(SIZE)
	var raw: Variant = data.get("slots", [])
	if typeof(raw) == TYPE_ARRAY:
		var seen_unique := {}
		for i in mini(raw.size(), SIZE):
			var s: Variant = raw[i]
			if typeof(s) != TYPE_DICTIONARY:
				continue
			var id: String = str(s.get("id", ""))
			var n := int(s.get("count", 0))
			if not ItemCatalog.has_item(id) or n <= 0:
				continue
			var q := clampi(int(s.get("quality", 0)), 0, 3) if ItemCatalog.category_of(id) == ItemCatalog.CAT_HARVEST else 0
			if not ItemCatalog.stackable_of(id):
				if seen_unique.has(id):
					continue
				seen_unique[id] = true
				n = 1
				q = 0
			clean[i] = {"id": id, "count": n, "quality": q}
	slots = clean
	changed.emit()
