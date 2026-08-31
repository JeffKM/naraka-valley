extends Node
class_name Peddler
# ★[S10-T3 / ADR-0069 결정 5] 저승 보부상 — **상시 리듬의 랜덤 재고 오버레이**.
#
# 목적: [ADR-0034]가 적어 둔 "여행 상인 흡수" 자구의 이행처다. 세계에 *매번 다른 물건*이 흘러드는
#       창구를 하나 열어 ㉠[Books] 미보유분의 저확률 입수처 ㉡[집 꾸미기] 테마 세트 가구의 두 번째
#       입구 ㉢레어크로우 8종 수집의 다섯째 획득처를 한 무대에 겸하게 한다.
#
# ── ★ 야시장(성야 15 절기 행사)과의 역할 분리(결정 5가 명문화를 요구한 그 항목) ─────────────
#   두 무대는 같은 "임시 상인 오버레이" 아키타입을 공유한다(같은 셸·같은 매대 행 스키마·같은 [F]).
#   그런데도 중복이 아닌 이유는 **리듬과 재고의 성격이 정반대**이기 때문이다.
#
#     ┌────────┬──────────────────────────┬──────────────────────────────────┐
#     │        │ 저승 야시장(SeasonalEvent) │ 저승 보부상(이 파일)              │
#     ├────────┼──────────────────────────┼──────────────────────────────────┤
#     │ 리듬   │ 달력 고정 · **1년 1회**    │ 상시 · **7의 배수 날**(주 1회)    │
#     │ 재고   │ **한정판 고정 로스터**     │ **매번 다른 day-해시 롤**         │
#     │ 가격   │ 행사 정액 2할 **할인**     │ 보부상 **웃돈**(±변동)            │
#     │ 무대   │ 나루 광장(마을 한복판)     │ 나루 다리 남단(마을 밖 길목)      │
#     │ 정체성 │ "오늘 놓치면 내년"         │ "이번 주엔 뭘 가져왔나"           │
#     └────────┴──────────────────────────┴──────────────────────────────────┘
#
#   즉 야시장은 *희소성*(달력)을 팔고 보부상은 *변주*(롤)를 판다. 야시장에서 싸게 사는 즐거움과
#   보부상에서 비싸게라도 사는 즐거움은 서로를 대체하지 않는다. ⚠️ 그러므로 **이 파일이 절기
#   행사 달력을 참조하는 일은 없어야 하고**(SeasonalEvent 의존 0) 야시장 로스터를 재사용하지도
#   않는다 — 두 층이 코드로 얽히는 순간 리듬 분리가 무너진다.
#
# 설계 메모(seasonal_event.gd·mailbox.gd·books.gd와 같은 결):
#   - **달력·풀·롤은 전부 static 순수 파생**이다. day 하나면 "오늘 오나 / 무엇을 파나"의 답이
#     통째로 나온다(테스트가 인스턴스 없이 12주치 재고를 굴린다).
#   - 인스턴스가 드는 것은 **파생이 불가능한 진짜 상태 하나뿐**이다: 1회성 물품 구매 이력.
#     ★ 가구 세트 해금은 `HomeDeco`가, 책 입수는 `Books`가 이미 진실원이라 **여기 안 적는다**
#       (야시장이 가구 해금을 home_deco에 미루는 그 판단 1:1 — 이중 진실원 방지).
#   - **전역 `randf` 금지**: 모든 롤이 `hash("<네임스페이스>:<day>:<serial>")` → `rand_from_seed`
#     믹싱 → % N이다(weather.gd 헤더가 실증한 djb2 하위 비트 편향 회피 관례).
#   - 지갑·인벤토리·Books·HomeDeco를 **모른다**. 지급·결제·원장 갱신은 전부 main이 조율한다
#     (SeasonalEvent가 wallet을 모르는 그 디커플링 그대로).
#   - 세이브는 `"peddler"` 네임스페이스 **가법 키 한 조각**이다. 키 없는 구세이브는 빈 원장으로
#     시작한다 — 아무것도 안 막힌다(다음 7의 배수 날에 그냥 온다).

# ── 출현 주기(결정 5 — 잠정 레버·owner 큐) ────────────────────────────────────
# **7의 배수 날**(7·14·21·28 …). 절기가 28일이라 절기당 정확히 4회 서고, 절기 경계를 넘어도
# 리듬이 끊기지 않는다(28 → 35 → 42 …). ★ 테마 데이(25일)·절기 행사(12/20/16/15) 어느 날짜와도
# 겹치지 않는다 — 겹치면 하루에 매대가 둘 서서 "오늘 어디를 가나"가 흐려진다(peddler_test ①f가 잠근다).
const APPEAR_MODULUS := 7

# ── 재고 구성(결정 5: "day-해시 결정적 10슬롯 + 가구 1 + 희귀 1") ────────────────
const STOCK_SLOTS := 10      # 일반 슬롯 수
const SLOT_DECO := 10        # 가구 슬롯 인덱스(가격 롤 시드의 serial — 일반 슬롯과 안 겹치게 이어 붙였다)
const SLOT_RARE := 11        # 희귀 슬롯 인덱스
const TOTAL_ROWS := STOCK_SLOTS + 2   # 매대 총 행수(10 + 가구 1 + 희귀 1 = 12)

# ── 행 종류(main의 구매 라우팅 키 — 야시장 "fest_*" 접두 관례의 형제) ────────────
const KIND_ITEM := "ped_item"   # 스택 아이템 소매(재료·채집물·광물 — 대량 구매 가능)
const KIND_SEED := "ped_seed"   # 씨앗 소매(스택 소모품 — 대량 구매 가능)
const KIND_DECO := "ped_deco"   # 가구 세트(1회성 해금 — 진실원은 HomeDeco)
const KIND_RARE := "ped_rare"   # 레어크로우 ⑤(1회성 — 진실원은 이 노드의 bought)
const KIND_BOOK := "ped_book"   # 책·비밀 노트(1회성 — 진실원은 Books 원장)

# ── 가격(전부 잠정 레버 — owner 큐) ───────────────────────────────────────────
# 보부상은 **웃돈을 받는다**(스타듀 여행 상인 1:1 — 편의의 값). 야시장이 2할 *싼* 것과 정확히
# 대칭이라, 두 무대의 가격표만 봐도 정체성이 갈린다.
#   · 기준 = 정가 ×2.2 · 슬롯마다 ±25% 변동("이번 주엔 이게 싸네"가 성립할 최소 폭)
#   · 변동은 (day, slot)에 결정적이라 같은 날 다시 열어도 값이 안 흔들린다(재열람 어뷰징 0)
const MARKUP_PERMIL := 2200
const JITTER_PERMIL := 250

# ── 희귀 슬롯(결정 5 · 결정 4 획득처 ⑤) ───────────────────────────────────────
# 희귀 슬롯 하나가 세 얼굴을 돌려 쓴다. 우선순위 롤 한 번(0..999)으로 결정적으로 갈린다:
#   ① 레어크로우 ⑤ — 미구매일 때만(1회성 — 사고 나면 영영 안 뜬다)
#   ② [Books] 미보유분 — 저확률 입수처(결정 5 자구의 이행). 책이 다 모이면 이 가지도 닫힌다
#   ③ 폴백 = 일반 풀 최고가 상위에서 한 점(귀물 좌판이 **비는 날이 없게** — 빈 슬롯은 결함으로 읽힌다)
# ★ ①이 소진되면 그 확률이 ②로 흘러간다(가지가 죽는 게 아니라 옆으로 넘어간다). 수집이 끝날수록
#   좌판이 조용해지는 대신, 남은 것이 뜰 확률은 오히려 오른다.
const RARE_CROW_PERMIL := 200    # 레어크로우 ⑤ 출현(20%)
const RARE_BOOK_PERMIL := 150    # Books 미보유분 출현(15% — "저확률" 자구)
const RARE_FALLBACK_TOP := 8     # 폴백 후보 = 일반 풀 최고가 상위 N

# ★[ADR-0069 결정 4 획득처 ⑤] 레어크로우 ⑤ — **아이템 등재는 T2 소유**다(레어크로우 ③~⑧ 6종을
#   한 워커가 단독으로 ItemCatalog에 넣는다 — 공유 카탈로그 단일 소유 규약). 여기는 **id를
#   참조만** 하고, 미등재 상태에서는 `ItemCatalog.has_item` 게이트가 후보를 조용히 건너뛴다
#   (나락 열쇠가 "등록만 먼저·점등은 다음 태스크" 였던 그 선례의 거울상 — 등재되는 순간 코드
#   0줄로 살아난다).
const RARECROW_ID := "rarecrow_5"
const RARECROW_PRICE := 3000     # 정가(잠정 — 야시장 ② 2,500의 웃돈 자리. 표시가는 여기에 마크업이 또 얹힌다)

# 책·노트 정가(잠정). ItemCatalog상 책은 **비매(price 0)** 라 판매가에서 파생할 수가 없다 —
# 그건 "팔 수 없다"는 뜻이지 "값이 없다"는 뜻이 아니므로, 사들이는 쪽 값은 여기서 따로 매긴다.
# 책 : 노트 = 무거운 한 챕터 : 짧은 속삭임의 위계를 **값으로도** 읽히게 갈랐다(Books 헤더 ⑥ 결).
const BOOK_PRICE := 2000
const NOTE_PRICE := 600

# ── 일반 풀에서 빼는 것들(게이트 우회 방지) ───────────────────────────────────
# 판매가만 보고 풀을 짜면 **깊이 게이트 너머의 산출이 돈으로 사지는** 사고가 난다. 셋을 뺀다:
#   · 오색혼옥   — [ADR-0063] 초희귀 지위(결정 2 "일반 스캐터 밖"). 결정 2가 결정기 복제까지 막은 물건이다
#   · 나락철 광석 — 나락 전용 산출이자 **도구 4티어의 최종 재료**. 사지면 채광 깊이 곡선이 통째로 무의미해진다
#   · 나락혼정   — 관문 보스 확정 드랍. 보스를 안 잡고 얻는 경로가 되면 [ADR-0063] 결정 7이 깨진다
# ★ 레어크로우 ①②(및 T2가 얹을 ③~⑧)는 **price 0**이라 아래 `price > 0` 필터가 이미 걸러 낸다
#   (수집물이 일반 좌판에 흘러나오지 않는다 — 필터가 곧 규칙이다).
const POOL_EXCLUDE := [
	"gem_osaek_honok",     # ItemCatalog.GEM_OSAEK_HONOK
	"ore_narakcheol",      # ItemCatalog.ORE_NARAKCHEOL
	"narak_honjeong",      # ItemCatalog.NARAK_HONJEONG
]

# ★[폴리시 R4] 위 셋은 **손으로 적은 목록**이라 같은 사유(깊이 게이트)의 넷째 부류를 놓쳤다:
#   미혹 심층 존 산출(불사과·저승삼)이다. 그 존은 큰 통나무 2칸 = 유철 도끼 티어 너머라 걸어
#   닿는 것 자체가 보상인데, 둘 다 price/seed_cost > 0이라 필터를 그냥 통과했다. 특히 불사과는
#   **씨앗 루프**로 들어와(seed_cost 200) 다절기 REGROW 프레스티지 작물을 440냥에 무한 재배할 수
#   있게 했다 — crops.gd가 "씨앗은 미판매라 재배 익스플로잇 경로가 없다"고 못 박은 그 자구가
#   코드상 거짓이었다. 손 목록을 늘리는 대신 **로스터에서 파생**한다(심층종이 늘면 0줄로 따라온다).
static func pool_excluded(id: String) -> bool:
	return POOL_EXCLUDE.has(id) or ForageSpawns.is_deep_gated(id)

# ── 달력(day만 아는 순수 파생 — SeasonalEvent.event_for_day와 같은 결) ──────────
# 오늘 보부상이 서는가. day는 1부터(0·음수는 false — 손상 방어).
static func is_open_day(d: int) -> bool:
	return d > 0 and d % APPEAR_MODULUS == 0

# 오늘 이후(오늘 포함) 가장 가까운 출현일. 안내 문구·점괘 결의 예고가 쓴다.
static func next_open_day(d: int) -> int:
	var base := maxi(d, 1)
	if is_open_day(base):
		return base
	return base + (APPEAR_MODULUS - posmod(base, APPEAR_MODULUS))

# 오늘부터 며칠 뒤에 오나(0 = 오늘). 표시 전용.
static func days_until(d: int) -> int:
	return next_open_day(d) - maxi(d, 1)

# ── 롤(결정적 — 프로젝트 관례: hash → rand_from_seed 믹싱 → % N) ───────────────
static func _roll(ns: String, day: int, serial: int, modulo: int) -> int:
	return absi(rand_from_seed(hash("%s:%d:%d" % [ns, day, serial]))[0]) % maxi(modulo, 1)

# 정가 → 그날 그 슬롯의 표시가(웃돈 + ±변동). 최소 1냥(공짜 물건이 좌판에 서지 않게).
static func priced(day: int, slot: int, base: int) -> int:
	if base <= 0:
		return 0
	var jitter := _roll("peddler:price", day, slot, JITTER_PERMIL * 2 + 1) - JITTER_PERMIL
	return maxi(1, int(round(float(base) * float(MARKUP_PERMIL + jitter) / 1000.0)))

# ── 일반 재고 풀(로스터 파생 — 하드코딩 목록 0) ────────────────────────────────
# **분모를 손으로 안 적는다**: 작물이 늘거나 채집물이 붙으면 좌판이 저절로 넓어진다(테스트도 이
# 함수에서 분모를 받아 stale 하드코딩 함정을 피한다 — S9b가 반복해 데인 그 자리).
# 반환 = [{kind, buy_id, base}] (선언 순 — 뽑기 인덱스가 결정적이려면 순서가 안정해야 한다).
static func stock_pool() -> Array:
	var out: Array = []
	# 씨앗 — 작물군 파생(매입가 = 씨앗 원가). 여행 상인이 철 지난 씨앗을 파는 그 자리.
	for cid in CropCatalog.ids():
		var sid_crop := str(cid)
		if pool_excluded(sid_crop):
			continue                     # ★[폴리시 R4] 심층 채집 전용 작물(불사과) — 씨앗을 팔지 않는다
		var seed_cost := int(CropCatalog.seed_cost(sid_crop))
		if seed_cost > 0:
			out.append({"kind": KIND_SEED, "buy_id": sid_crop, "base": seed_cost})
	# 스택 아이템 — 채집물·재료·광물·통용물·수액. 전부 {id: {price}} 스키마라 한 루프로 접힌다.
	var tables: Array = [ItemCatalog.FORAGEABLES, ItemCatalog.MATERIALS, ItemCatalog.MINERALS,
		ItemCatalog.POT_GOODS, ItemCatalog.SAP_GOODS]
	for t in tables:
		var src: Dictionary = t
		for id in src:
			var sid := str(id)
			if pool_excluded(sid):
				continue
			var row: Dictionary = src[id]
			var price := int(row.get("price", 0))
			if price > 0:
				out.append({"kind": KIND_ITEM, "buy_id": sid, "base": price})
	return out

# ── 일반 10슬롯(day-해시 결정적 · 같은 날 중복 0) ──────────────────────────────
# ★ 뽑기 방식 = **해시 키 부분 선택**이다. 후보마다 결정적 키를 한 번 굴려 두고 **가장 작은 10개**를
#   집는다 — 결과는 "그날의 순열 앞 10개"와 같고 중복이 구조적으로 불가능하다.
#   ⚠️ "인덱스를 굴리고 중복이면 다시"는 안 쓴다: 재롤 횟수가 풀 크기에 의존해 분포가 미묘하게
#      기울고, 최악의 경우 슬롯이 덜 차는 상한 함정이 생긴다.
#   ⚠️ `sort_custom`(Callable)도 안 쓴다: 이 함수는 **static**이고 매대가 열려 있는 동안 매 프레임
#      불린다. 키를 한 번만 굴려 두고(풀 크기만큼) 10회 선택하면 롤 횟수도 최소가 된다.
static func general_rows(day: int) -> Array:
	var pool := stock_pool()
	if pool.is_empty():
		return []
	var keys: Array = []
	for i in pool.size():
		keys.append(_roll("peddler:pick", day, i, 1 << 30))
	var taken: Dictionary = {}
	var out: Array = []
	for s in mini(STOCK_SLOTS, pool.size()):
		var best := -1
		for i in pool.size():
			if taken.has(i):
				continue
			# 키 동률은 인덱스가 작은 쪽이 이긴다(선택 순서 = 결정성의 전제).
			if best < 0 or int(keys[i]) < int(keys[best]):
				best = i
		taken[best] = true
		var src: Dictionary = pool[best]
		var row := src.duplicate()
		row["slot"] = s
		row["price"] = priced(day, s, int(row["base"]))
		out.append(row)
	return out

# ── 가구 슬롯 1(테마 세트 두 번째 입구 — 결정 5 자구) ──────────────────────────
# 정가는 **HomeDecoCatalog가 진실원**이고(중복 표 0) 여기선 그날 어느 세트가 실리나만 굴린다.
# ★ 이미 해금한 세트가 뽑혀도 **행은 그대로 선다**(잠긴 채) — 뽑기를 해금 상태로 편향시키면
#   "오늘 뭘 가져왔나"가 플레이어 상태에 따라 달라져 day-해시 결정성이 깨진다(표시만 잠근다).
static func deco_row(day: int) -> Dictionary:
	var ids: Array = HomeDecoCatalog.purchasable_ids()
	if ids.is_empty():
		return {}
	var pick := str(ids[_roll("peddler:deco", day, 0, ids.size())])
	var base := int(HomeDecoCatalog.price_of(pick))
	return {"kind": KIND_DECO, "buy_id": pick, "slot": SLOT_DECO,
		"base": base, "price": priced(day, SLOT_DECO, base)}

# ── 희귀 슬롯 1(레어크로우 ⑤ / Books 미보유분 / 고가 폴백) ─────────────────────
# 순수 함수 — 원장을 **인자로 받는다**(Books.peek_drop이 owned를 받는 그 문법 1:1). 인스턴스가
# 없어도 "그날 무엇이 설까"를 통째로 굴릴 수 있어야 테스트가 40주치를 훑는다.
#   bought_ids  = 1회성 구매 이력 id 배열(이 노드의 원장). ★ 인스턴스 멤버 `bought`와 이름을
#                 갈라 둔다 — static 함수라 멤버에 못 닿고, 같은 이름이면 읽는 사람이 헷갈린다.
#   owned_books = 이미 주운 책·노트 id → 아무 값(Books.acquired 그대로 넘긴다)
static func rare_row(day: int, bought_ids: Array, owned_books: Dictionary) -> Dictionary:
	var r := _roll("peddler:rare", day, 0, 1000)
	# ① 레어크로우 ⑤ — 미등재(T2 대기)면 게이트에 걸려 조용히 ②로 흘러간다.
	if r < RARE_CROW_PERMIL and ItemCatalog.has_item(RARECROW_ID) and not bought_ids.has(RARECROW_ID):
		return {"kind": KIND_RARE, "buy_id": RARECROW_ID, "slot": SLOT_RARE,
			"base": RARECROW_PRICE, "price": priced(day, SLOT_RARE, RARECROW_PRICE)}
	# ② Books 미보유분 — 남은 것이 없으면 ③으로.
	if r < RARE_CROW_PERMIL + RARE_BOOK_PERMIL:
		var pool := remaining_books(owned_books)
		if not pool.is_empty():
			var bid := str(pool[_roll("peddler:book", day, 0, pool.size())])
			var base := BOOK_PRICE if Books.is_book(bid) else NOTE_PRICE
			return {"kind": KIND_BOOK, "buy_id": bid, "slot": SLOT_RARE,
				"base": base, "price": priced(day, SLOT_RARE, base)}
	# ③ 폴백 — 일반 풀 최고가 상위에서 한 점(귀물 좌판이 비는 날 0).
	return _fallback_row(day)

# 아직 안 주운 책·노트(선언 순 보존 — Books._remaining과 같은 규율).
static func remaining_books(owned_books: Dictionary) -> Array:
	var out: Array = []
	for id in Books.all_ids():
		if not owned_books.has(str(id)):
			out.append(str(id))
	return out

# 폴백 = 일반 풀의 **정가 상위 N**에서 한 점(로스터 파생 — 고가 목록 하드코딩 0).
# general_rows와 같은 이유로 sort_custom을 안 쓰고 부분 선택으로 상위 N만 집는다(동률은 id 사전순).
#
# ★[폴리시 R3] **오늘 일반 10슬롯에 이미 선 종은 후보에서 뺀다.** 안 빼면 같은 buy_id가 두 행에
#   서고, 두 행의 값은 `priced`의 jitter 시드가 slot별이라 서로 다르다 — 그런데 `price_for`는
#   buy_id로 **첫 매치**를 돌려주고 일반 슬롯(0..9)이 희귀 슬롯(11)보다 앞이라, 귀물 좌판 행을
#   눌러도 일반 슬롯 값이 청구된다(프레임은 slot을 안 실어 보내 어느 행인지 구분할 수단조차 없다).
#   머리말이 "표시가와 결제가가 각자 계산되면 언젠가 어긋난다"고 못 박은 그 상황이라, 값 조회를
#   고치는 대신 **중복 자체를 구조로 없앤다**(id가 매대에서 유일하면 id 키 조회가 다시 안전해진다).
#   day 순수 함수라 결정성도 그대로다 — 제외된 자리는 다음 고가 종이 올라와 후보 수가 안 준다.
static func _fallback_row(day: int) -> Dictionary:
	var pool := stock_pool()
	if pool.is_empty():
		return {}
	var listed: Dictionary = {}
	for r in general_rows(day):
		listed[str((r as Dictionary)["buy_id"])] = true
	var top := mini(RARE_FALLBACK_TOP, pool.size())
	var taken: Dictionary = {}
	var picks: Array = []
	for _s in top:
		var best := -1
		for i in pool.size():
			if taken.has(i) or listed.has(str((pool[i] as Dictionary)["buy_id"])):
				continue
			if best < 0:
				best = i
				continue
			var cand: Dictionary = pool[i]
			var cur: Dictionary = pool[best]
			var pc := int(cand["base"])
			var pb := int(cur["base"])
			if pc > pb or (pc == pb and str(cand["buy_id"]) < str(cur["buy_id"])):
				best = i
		if best < 0:
			break                      # 후보 고갈(풀이 일반 슬롯보다 작은 극단) — 음수 인덱스 방어
		taken[best] = true
		picks.append(best)
	if picks.is_empty():
		return {}                      # 오늘 세울 수 있는 폴백이 없다 = 귀물 좌판이 비는 날
	var src: Dictionary = pool[int(picks[_roll("peddler:fallback", day, 0, picks.size())])]
	var row := src.duplicate()
	row["slot"] = SLOT_RARE
	row["price"] = priced(day, SLOT_RARE, int(row["base"]))
	return row

# ── 그날의 매대 전체(10 + 가구 1 + 희귀 1) ─────────────────────────────────────
# 출현일이 아니면 **빈 배열**이다 — 좌판이 없는 날엔 팔 것도 없다(달력이 곧 재고의 전제).
static func stock_rows(day: int, bought_ids: Array, owned_books: Dictionary) -> Array:
	if not is_open_day(day):
		return []
	var out := general_rows(day)
	var deco := deco_row(day)
	if not deco.is_empty():
		out.append(deco)
	var rare := rare_row(day, bought_ids, owned_books)
	if not rare.is_empty():
		out.append(rare)
	return out

# ── 상태(여기서부터 인스턴스 — 파생 불가능한 것만 든다) ───────────────────────
# 1회성 물품 구매 이력. ★ 지금 실효 원소는 레어크로우 ⑤ 하나뿐이다 — 가구는 HomeDeco가, 책은
#   Books가 각자 진실원이라 여기 안 적는다(야시장 `market_bought`와 같은 최소 원장).
var bought: Array = []

# ★ 그날 희귀 슬롯을 가져갔는가(day + 그때 산 id). **하루 한 점** 규칙의 진실원이다.
#   ⚠️ 이 두 값이 없으면 실제로 뚫리는 구멍이 있었다(peddler_test ⑨e가 잡아낸 것):
#      희귀 슬롯의 책은 `remaining_books`(미보유분)에서 뽑히므로, 한 권을 사는 순간 그 권이
#      풀에서 빠지고 **같은 날 같은 슬롯이 다른 책으로 즉시 다시 찬다**. 연타하면 하루에
#      23권을 통째로 사 버릴 수 있었다 — [ADR-0034]가 "저확률 입수처"로 잡아 둔 채널이
#      "엽전만 있으면 하루에 완주"가 되는 것이라 수집 축이 통째로 무너진다.
#   ★ 일반 10슬롯·가구 슬롯엔 이 잠금이 없다: 일반은 애초에 무제한 소매고, 가구 뽑기는
#     해금 상태를 안 보므로(deco_row 주석) 사고 나도 같은 세트가 잠긴 채 그대로 선다.
var rare_day := 0    # 희귀 슬롯을 가져간 day(0 = 없음)
var rare_id := ""    # 그때 가져간 id(그 자리에 그대로 세워 두려고 든다)

signal changed()   # 구매·복원 프레임(main이 매대 행·좌판 표식을 다시 그린다)

# ── 인스턴스 창구(원장을 붙여 static을 부른다) ────────────────────────────────
# ★ static `stock_rows` 위에 **하루 한 점 잠금**만 얹는다: 오늘 희귀 슬롯을 이미 가져갔으면
#   그 자리에 *산 물건을 그대로* 세운다(다른 물건으로 갈아 끼우지 않는다). 그러면
#   ㉠ 즉시 재충전 구멍이 닫히고 ㉡ "오늘 뭘 샀는지"가 좌판에 남아 읽힌다. 잠금 표시는
#   main이 붙인다 — 이미 `books.has_acquired`·`has_bought`가 true라 기존 판정에 그대로 걸린다.
func rows_for(day: int, owned_books: Dictionary) -> Array:
	var out := stock_rows(day, bought, owned_books)
	if out.is_empty() or not rare_taken_on(day):
		return out
	var frozen := _taken_rare_row(day)
	if not frozen.is_empty():
		out[out.size() - 1] = frozen   # 희귀 슬롯은 늘 마지막 행(stock_rows 조립 순서)
	return out

# 오늘 희귀 슬롯을 이미 가져갔나.
func rare_taken_on(day: int) -> bool:
	return day > 0 and rare_day == day and rare_id != ""

# 희귀 슬롯 취득 기록(책·레어크로우 ⑤ 결제 성공 직후 main이 부른다).
# ⚠️ **폴백 행(일반 아이템)은 안 부른다** — 그건 무제한 소매지 하루 한 점짜리 귀물이 아니다.
func record_rare(day: int, id: String) -> void:
	if day <= 0 or id == "":
		return
	rare_day = day
	rare_id = id
	changed.emit()

# 가져간 귀물을 그 자리에 세우는 행. 값은 취득 당시와 같은 규칙으로 다시 파생한다(별도 저장 0).
func _taken_rare_row(day: int) -> Dictionary:
	if rare_id == RARECROW_ID:
		return {"kind": KIND_RARE, "buy_id": rare_id, "slot": SLOT_RARE,
			"base": RARECROW_PRICE, "price": priced(day, SLOT_RARE, RARECROW_PRICE)}
	if Books.has_text(rare_id):
		var base := BOOK_PRICE if Books.is_book(rare_id) else NOTE_PRICE
		return {"kind": KIND_BOOK, "buy_id": rare_id, "slot": SLOT_RARE,
			"base": base, "price": priced(day, SLOT_RARE, base)}
	return {}

# 그날 이 물건의 표시가(0 = 오늘 안 파는 물건). ★ main이 결제 직전에 **행에서 값을 되찾는**
#   창구다: 표시가와 결제가가 각자 계산되면 언젠가 어긋나고, 오늘 재고에 없는 id를 사는 구멍도
#   같이 막힌다(매대에 안 선 물건은 값이 0이라 결제가 성립하지 않는다).
func price_for(day: int, owned_books: Dictionary, buy_id: String) -> int:
	for r in rows_for(day, owned_books):
		var row: Dictionary = r
		if str(row["buy_id"]) == buy_id:
			return int(row["price"])
	return 0

func has_bought(id: String) -> bool:
	return bought.has(id)

func record_bought(id: String) -> void:
	if id != "" and not bought.has(id):
		bought.append(id)
		changed.emit()

# ── 세이브/로드(가법 키 한 조각 — 구세이브는 빈 원장) ─────────────────────────
func to_save() -> Dictionary:
	return {"bought": bought.duplicate(), "rare_day": rare_day, "rare_id": rare_id}

# 복원 = 정제하며 갈아끼운다(seasonal_event.load_save의 결 그대로 — 손상·타입 불일치는 조용히 버린다).
# ★ 하루 한 점 잠금도 왕복시킨다: 안 그러면 사고 저장하고 이어하면 그날 슬롯이 되살아난다
#   (세이브-스컴이 아니라 **정상 이어하기**로 뚫리는 구멍이라 반드시 저장 대상이다).
func load_save(data: Dictionary) -> void:
	bought = []
	var raw: Variant = data.get("bought", [])
	if typeof(raw) == TYPE_ARRAY:
		for id in raw:
			var sid := str(id)
			if sid != "" and not bought.has(sid):
				bought.append(sid)
	rare_day = maxi(int(data.get("rare_day", 0)), 0)
	rare_id = str(data.get("rare_id", ""))
	if rare_day <= 0 or (rare_id != RARECROW_ID and not Books.has_text(rare_id)):
		rare_day = 0      # 손상·구세이브·사라진 id → 잠금 없음(막히는 쪽이 아니라 열리는 쪽으로)
		rare_id = ""
	changed.emit()
