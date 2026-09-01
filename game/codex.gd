extends Node
class_name Codex
# ★[S10-T6 / ADR-0069 결정 9] 명부 도감 — 혼백관 열람대의 **자동 기록** 수집 원장.
#
# 무엇인가: 스타듀의 Shipping Collection 대응이다. 혼백관이 이미 든 [기증 원장](Museum)이 "손으로
#   바쳐야 채워지는" 능동 수집이라면, 이쪽은 **살다 보면 저절로 적히는** 수동 수집이다. 플레이어가
#   따로 할 일이 없다 — 출하대에 한 번 넣은 것은 그 다음 아침에 도감에 이름이 선다.
#
# 등재 기준 = **판매 1회 이상**. 이 한 문장이 이 파일의 전부다.
#   ㉠ 선물·요리 재료 사용·상자 보관은 **미집계**다 — 판 것만 센다.
#   ★[폴리시 R8] 종전 자구는 "멜 출하대 출하 1회 이상"이었고, 그 근거로 "[ADR-0021]이 판매를
#      출하대 단일 창구로 못 박아 판매 이력 축이 코드에 하나뿐"이라고 적어 뒀다. 그 전제는 이
#      파일이 서기 전(S3-T5)부터 이미 거짓이었다 — 생선가게 즉시 환전(`main._sell_fish_n`)이 같은
#      가격 공식으로 파는 두 번째 창구이고, 그쪽 주석도 "어느 채널로 팔아도 총액이 같다 — 편의만
#      다르다"고 못 박는다. 그래서 물고기를 늘 환전 탭에서 파는 플레이어는 전 어종을 낚아 팔아도
#      어종 칸이 0으로 남아 완주가 구조적으로 불가능했다. 지금은 **두 창구가 모두 여기로 온다**.
#      ⚠️ 앞으로 판매 창구를 새로 열면 이 원장에 태우는 줄도 함께 서야 한다(등재 = 판매 이력).
#   ㉡ 기록 시점은 **정산 확정**(main._on_day_advanced의 ship_bin.settle 직전)이다. 넣는 순간(deposit)이
#      아니라서, 취침 전에 도로 빼낸 것(_on_frame_takeback)은 도감에 안 남는다 — 롤백 창이 살아 있는
#      동안은 아직 "출하한" 것이 아니라는 규약이 시점 하나로 성립한다(가드 코드 0줄).
#
# 왜 Museum에 얹지 않고 별개 원장인가:
#   Museum.claimed가 **기증 count를 키로** 마일스톤을 잠그고 있어, 그 분모에 손을 대면 이미 받은
#   답례가 어긋난다([S10-T2] 레어크로우 추적 진열이 같은 이유로 Museum 바깥에 섰다). 도감은 분모가
#   60을 넘고 앞으로도 로스터를 따라 계속 자라므로 더더욱 남의 원장에 얹을 수 없다.
#
# ★ 분모는 **전부 원천 카탈로그 파생**이다 — 이 파일에 아이템 id 목록을 한 줄도 적지 않는다.
#   로스터가 늘면 도감 분모가 저절로 따라 늘고, 사람이 동기화할 자리가 없다(수동 목록 = 잠복 stale).
#
# 완주 보상은 **연출뿐**이다([ADR-0069] 결정 1 ② — 합산 퍼센트·진엔딩 금지). 아이템도, 스탯 보정도,
#   퍼센트도 없다. 트로피는 알림 한 줄과 열람대 위 작은 상(像) 하나로 끝난다.
#   ([ADR-0034] #4 영구 % 곱셈 금지 · [ADR-0008] 관계 게이트 없음 — 이 시스템엔 관계 축이 아예 없다.)

# ── 카테고리(표시 순서 = 이 배열 순서 = 분모 우선순위) ────────────────────────
const CAT_CROP := "crop"
const CAT_FISH := "fish"
const CAT_FORAGE := "forage"
const CAT_MINERAL := "mineral"
const CAT_COOK := "cook"

const CATEGORIES := [CAT_CROP, CAT_FISH, CAT_FORAGE, CAT_MINERAL, CAT_COOK]

const CATEGORY_NAMES := {
	CAT_CROP: "작물",
	CAT_FISH: "어종",
	CAT_FORAGE: "채집물",
	CAT_MINERAL: "광물",
	CAT_COOK: "요리",
}

# 미등재 자리 표기(도감의 빈칸 — 이름을 아직 모른다).
const UNKNOWN_MARK := "???"

# ── 원장 ────────────────────────────────────────────────────────────────────
var shipped: Dictionary = {}   # 추적 대상 id(String) → 첫 출하 확정 day(int)
var trophy_day: int = -1       # 완주 트로피를 세운 day(-1 = 아직. 1회성 래치 — 재정산 중복 발화 차단)

signal changed                 # 등재·트로피·복원 프레임(main이 듣고 열람대 진열 갱신)

# ── 분모(원천 카탈로그 파생 — 하드코딩 0) ─────────────────────────────────────
# 카테고리 하나의 추적 id 목록. 각 줄이 그 카테고리의 **단일 출처**를 그대로 가리킨다.
static func category_ids(cat: String) -> Array:
	match cat:
		CAT_CROP:
			# 작물군 id가 아니라 **수확물 아이템 id**로 바꿔 담는다(출하대에 들어오는 것이 수확물이다).
			# 지금은 harvest_id가 항등이지만, 그 사실에 기대지 않고 변환을 통과시킨다(단일 출처 준수).
			var crops: Array = []
			for cid in CropCatalog.ids():
				crops.append(ItemCatalog.harvest_id(String(cid)))
			return crops
		CAT_FISH:
			return FishCatalog.ids()
		CAT_FORAGE:
			return ItemCatalog.FORAGEABLES.keys()
		CAT_MINERAL:
			return ItemCatalog.MINERALS.keys()
		CAT_COOK:
			# ★ 융합 메뉴 중 **곁들이만**이다. 두 번 좁힌 자리라 근거도 둘이다.
			#   ㉠ 기본 메뉴 4종(아메리카노·냉수…) 제외 — 카페가 원래 파는 물건이라 "모으는" 축이
			#      아니다(그래서 MenuCatalog.ids()가 아니다).
			#   ㉡ 판매 전용 음료 7종 제외 — **획득 경로가 없다.** 메뉴 아이템이 인벤토리에 들어오는
			#      길은 주방요괴 창구(main._make_side_dish) 하나뿐이고 그것은 SIDE_DISHES만 굽는다.
			#      음료는 카페 서빙으로 곳간 재고에서 곧장 냥이 될 뿐 플레이어 손에 쥐어지지 않으므로,
			#      출하대에 넣을 수도 도감에 올릴 수도 없다. 그 7종을 분모에 세워 두면 요리 칸이
			#      5/12에서 영영 멎어 **완주가 원리적으로 불가능**해진다(트로피 = 도달 불가 죽은 코드).
			#   ★ 분모는 여전히 원천 카탈로그 파생이다 — 여기 id를 적지 않고 `side_dish_ids()`를
			#     그대로 쓴다. 곁들이 로스터가 바뀌면 도감 분모가 저절로 따라간다(수동 동기화 0).
			#     "먹는 것은 모으고 마시는 잔은 판다"가 곧 [ADR-0064 결정 9]의 그 가름선이다.
			return MenuCatalog.side_dish_ids()
	return []

# 추적 대상 전 id(카테고리 선언 순 · 중복 없음). 겹치는 id가 생기면 **먼저 나온 카테고리가 갖는다**
# (표시가 두 곳에 서면 분모 합이 총계와 어긋나므로 소속은 항상 한 곳).
static func tracked_ids() -> Array:
	var out: Array = []
	var seen := {}
	for cat in CATEGORIES:
		for id in category_ids(String(cat)):
			var sid := String(id)
			if seen.has(sid):
				continue
			seen[sid] = true
			out.append(sid)
	return out

# 이 id가 속한 도감 카테고리("" = 추적 대상 아님 — 유품·책·자재·도구·씨앗 등).
static func category_of(id: String) -> String:
	for cat in CATEGORIES:
		if category_ids(String(cat)).has(id):
			return String(cat)
	return ""

static func is_tracked(id: String) -> bool:
	return category_of(id) != ""

# 카테고리 분모(그 칸의 전체 수). 없는 카테고리는 0.
static func category_total(cat: String) -> int:
	return category_ids(cat).size()

# 도감 전체 분모.
static func total_count() -> int:
	return tracked_ids().size()

static func category_name(cat: String) -> String:
	return String(CATEGORY_NAMES.get(cat, cat))

# ── 등재 ────────────────────────────────────────────────────────────────────
# 출하 확정분 하나를 도감에 올린다. 추적 대상이 아니거나 이미 올라 있으면 false(첫 날만 남는다).
func record(id: String, day: int) -> bool:
	if not is_tracked(id) or shipped.has(id):
		return false
	shipped[id] = day
	changed.emit()
	return true

func is_shipped(id: String) -> bool:
	return shipped.has(id)

# 첫 출하 확정 day(-1 = 미등재).
func first_day_of(id: String) -> int:
	return int(shipped[id]) if shipped.has(id) else -1

func shipped_count() -> int:
	return shipped.size()

# 카테고리 안에서 등재된 수(분자).
func category_shipped(cat: String) -> int:
	var n := 0
	for id in category_ids(cat):
		if shipped.has(String(id)):
			n += 1
	return n

# 카테고리 안 등재된 이름들(표시 순 = 카탈로그 순).
func category_names_shipped(cat: String) -> Array:
	var out: Array = []
	for id in category_ids(cat):
		var sid := String(id)
		if shipped.has(sid):
			out.append(ItemCatalog.name_of(sid))
	return out

# ── 완주 · 트로피(연출만) ─────────────────────────────────────────────────────
# 전 분모가 등재됐나. **shipped.size() 비교가 아니라 전수 확인**이다 — 구세이브가 지금은 로스터에서
# 빠진 id를 들고 있어도(load_save가 걸러 내지만) 개수 일치로 완주를 오인하는 길을 아예 막는다.
func is_complete() -> bool:
	for id in tracked_ids():
		if not shipped.has(String(id)):
			return false
	return true

# 지금 트로피를 세울 순간인가(완주했는데 아직 안 세움). main이 정산 직후 1회만 묻는다.
func trophy_pending() -> bool:
	return trophy_day < 0 and is_complete()

func has_trophy() -> bool:
	return trophy_day >= 0

# 트로피 래치를 건다(1회성 — 이미 서 있으면 false. 재정산·재로드에도 중복 발화 없음).
func claim_trophy(day: int) -> bool:
	if trophy_day >= 0:
		return false
	trophy_day = day
	changed.emit()
	return true

# ── 세이브/로드(슬라이스 키 "codex" 네임스페이스 — Museum 결) ──────────────────
func to_save() -> Dictionary:
	return {"shipped": shipped.duplicate(), "trophy_day": trophy_day}

# 복원: 추적 대상 id만 받는다(로스터에서 빠진 미지 id는 드롭 — 분모 밖 항목이 분자에 남아
# "61/60"이 되는 사고 차단). 손상값·비-dict도 방어한다(ShippingBin.load_save 결).
func load_save(data: Dictionary) -> void:
	shipped = {}
	var raw: Variant = data.get("shipped", {})
	if typeof(raw) == TYPE_DICTIONARY:
		for k in raw:
			var sid := String(k)
			if is_tracked(sid):
				shipped[sid] = int(raw[k])
	trophy_day = int(data.get("trophy_day", -1))
	changed.emit()
