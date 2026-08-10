extends Node
class_name SeasonalEvent
# ★[S7-T7 / ADR-0065 결정 9] 절기 행사 4종 — **기존 활동 루프 위의 한정 오버레이**.
#
# 목적: CONTEXT [절기 행사] — 테마 데이(카페 이벤트 데이)가 절기당 1개라 28일 중 목적지 이벤트가
#       하나뿐인 빈약한 리듬을, *새 초상화·새 미니게임 엔진·새 장소 0*의 가벼운 층으로 채운다.
#       스타듀 축제가 겸하던 세 직무(경연·특수 상인·한정 포획)를 여기로 분리해 담는다.
#
# 설계 메모(어기면 결정 9 위반):
#   - **오버레이 전용 잠금**: 새 씬도 새 미니게임 엔진도 새 장소도 만들지 않는다. 더비는 *기존 낚시*
#     위에, 장원제는 *기존 곳간* 위에, 야시장은 *기존 매대 셸* 위에, 해파리 창은 *기존 어종 롤* 위에
#     얹힌다. 행사별 전용 미니게임(에그헌트류)은 **명시적 서랍**이다(출시 비게이트).
#   - **해금 = 처음부터**(테마 데이와 비대칭 — CONTEXT ㉢). 테마 데이는 [카페 일구기]의 *결실*이라
#     사다리에 걸지만, 절기 행사는 카페 이벤트가 아니라 *세계 절기 이벤트*라 카페 진척에 안 묶는다.
#   - **옵트인·무손실**(ADR-0008): 안 해도 게이트 0. 경연 상품·한정 어종은 그 절기 한정이지만
#     그건 *기회비용*이지 처벌이 아니다(놓치면 내년 — [물고기 도감]은 비게이트).
#   - **달력 판정은 static 순수 파생**(festival.gd·weather.gd와 같은 결). day 하나면 답이 나온다.
#     ★ 단 이 클래스는 festival과 달리 **인스턴스 노드**다: 개최 결과(더비 태그·교환 횟수·장원제
#     이력·야시장 구매)는 파생이 불가능한 *진짜 상태*라 어딘가는 들어야 한다. 그래서 **달력·표·롤은
#     전부 static**으로 두고 상태만 인스턴스가 든다(테스트가 인스턴스 없이 달력을 통째로 굴린다).
#   - 세이브는 `"seasonal_event"` 네임스페이스 **가법 키 한 조각**이다(larder·guest_pool 선례).
#     키 없는 구세이브는 빈 원장으로 시작한다 — 아무것도 안 막힌다.

# ── 행사 4종(인덱스 = 절기 인덱스 — 절기당 1행사라 인덱스가 곧 매핑이다) ──────
# Festival(테마 데이)이 같은 관례를 쓴다. 두 층은 **같은 눈금·다른 날짜**로 직교한다.
const DERBY := 0          # 피안절 — 삼도천 낚시 더비(경연)
const JELLYFISH := 1      # 유화절 — 월광 혼불해파리 창구(한정 포획)
const GRANGE := 2         # 망연절 — 곳간 장원제(경연)
const NIGHT_MARKET := 3   # 성야절 — 저승 야시장(특수 상인)
const NONE := -1

const NAMES := ["삼도천 낚시 더비", "월광 혼불해파리 창구", "곳간 장원제", "저승 야시장"]

# 각 행사의 **절기 내 일차**(잠정 레버 — ADR-0065 결정 9의 작가 배치).
# ⚠️ 테마 데이(25일)와 전부 다르다 — 한 절기에 두 이벤트가 겹치지 않게 한 배치다(12/20/16/15 vs 25).
# 절기 중반에 두는 이유: 절기 첫날(전환·사멸)과 25일(테마 데이) 사이의 빈 구간을 메운다.
const DAY_OF_SEASON := [12, 20, 16, 15]

# ── ① 삼도천 낚시 더비(피안 12일) ────────────────────────────────────────────
# 그날 **삼도천(강)** 어획마다 확률 롤 → 「금빛 태그」. 부스에서 태그 1개당 보상 교환.
# ★ **태그는 아이템이 아니라 행사 원장의 카운트다**(판단 근거): 아이템으로 만들면 ㉠백팩 슬롯을
#   먹고 ㉡ItemCatalog·아이콘·툴팁·판매가·출하함 취급이 줄줄이 따라오며 ㉢당일 소멸을 구현하려면
#   "밤에 인벤에서 특정 아이템만 지우는" 파괴 경로를 새로 열어야 한다. 하루짜리 경연 점수판에
#   그 값을 치를 이유가 없다 — 태그는 *그날의 성적*이지 물건이 아니다.
const DERBY_TAG_PERMIL := 330   # 어획당 태그 확률(33% — 잠정 레버)

# 교환 보상 사다리(1번째·2번째·3번째 이후). 앞이 굵고 뒤가 잔잔한 계단 = "많이 낚을수록 좋지만
# 첫 한 마리가 가장 값지다"(코지 상한 — 하루 종일 낚아 골드를 뽑는 그라인드가 되지 않게).
# ⚠️ 값 전부 잠정(owner 큐).
const DERBY_REWARDS := [
	{"kind": "fert", "id": "fert_quality", "n": 3},   # ① 품질 비료 3
	{"kind": "seed", "id": "honhap", "n": 5},          # ② 혼합 씨앗 5
	{"kind": "gold", "id": "", "n": 120},              # ③ 이후 — 엽전 120(무한 반복분)
]

# ── ② 월광 혼불해파리 창구(유화 20일 저녁~밤) ─────────────────────────────────
# 그날 저녁·밤 **황천해** 캐스팅에서 혼불해파리 출현이 대폭 오른다. 기존 `_roll_fish_id` 결과를
# 창 안에서 가중하는 **최소 침습**이다(어종 롤 구조·가중표는 한 줄도 안 건드린다).
# ★ 창 안에서는 **저녁도 열린다** — 혼불해파리는 평소 밤 전용(FishCatalog phases=[밤])이고, 이
#   행사의 정체가 바로 "그 창이 하루만 넓어진다"는 것이다(CONTEXT "한정 포획 창구"). 행사 밖의
#   혼불해파리는 여전히 밤에만 문다(카탈로그 무수정 = 평소 규칙 불변).
const JELLY_PHASES := ["저녁", "밤"]
const JELLY_BOOST_PERMIL := 550   # 창 안 캐스팅이 해파리로 치환될 확률(55% — 잠정 레버)
const JELLY_FISH_ID := "honbul_haepari"   # FishCatalog.HONBUL_HAEPARI(문자열 진실원은 카탈로그)

# ── ③ 곳간 장원제(망연 16일) ─────────────────────────────────────────────────
# 스타듀 Fair Grange Display의 단순화판. 곳간 재고에서 최대 9종을 출품해 점수를 받는다.
# ★ **출품은 재고를 차감하지 않는다**(잠정·판단 근거): 이건 *전시*지 납품이 아니다. 차감하면
#   ㉠"좋은 걸 넣으면 잃는다"가 되어 출품 자체를 망설이게 되고(옵트인 층이 손실 판단으로 변질)
#   ㉡곳간은 융합 메뉴의 재료 창고라 하루 경연이 카페 공급망을 비우는 부작용이 생긴다. 스타듀도
#   Grange 품목은 축제가 끝나면 돌려준다 — 우리는 아예 안 가져가는 쪽으로 접었다.
const GRANGE_MAX_ENTRIES := 9
const GRANGE_DIVERSITY_PT := 2    # 종당 다양성 점수(9종 = 18점)
const GRANGE_SEASON_PT := 3       # 제철 작물 1종당 가점("이 절기의 결실"을 보이는 잔치)

# 판매가 밴드 → 점수(고가 가점). [문턱, 점수] 내림차순 — 첫 매치가 답.
const GRANGE_BANDS := [[300, 8], [150, 6], [80, 4], [30, 2], [0, 1]]

# 등급 3단 문턱·이름·보상(잠정 레버). 9종 전부 최고 밴드 + 제철이면 18+72+27 = 117점이 상한이고,
# 곳간을 성실히 채운 중간 플레이가 대략 40~60점에 앉는다.
const GRANGE_TIER_SCORES := [12, 30, 55]
const GRANGE_TIER_NAMES := ["입선", "우수", "장원"]
const GRANGE_TIER_GOLD := [300, 800, 1500]
const GRANGE_CHAMPION_FERT := 5   # 장원 추가 보상 — 품질 비료 5

# ── ④ 저승 야시장(성야 15일) ─────────────────────────────────────────────────
# 나루 광장 임시 매대. 가구 세트 2종(목공방과 중복돼도 무방 — *두 번째 입구*가 이 행사의 직무다)
# + 한정 물품(레어크로우 ②) + 씨앗 소량.
const MARKET_DISCOUNT := 0.8      # 행사 할인 20%
const MARKET_RARECROW := "rarecrow_2"       # ★[ADR-0051 B 수집 축] 한정 물품 — 1회 한정
const MARKET_RARECROW_PRICE := 2500         # 정가(잠정 — 할인 후 2,000냥)
const MARKET_SEED_CROP := "honhap"          # 혼합 씨앗(제작 전용 씨앗의 야시장 소매 — 잠정)
const MARKET_DECO_SETS := ["JEOSEUNGSOL", "JAETNUN"]

# ── 달력(day만 아는 순수 파생 — Festival.theme_slot_for_day와 같은 결) ────────
# 이 날 열리는 행사(NONE = 평일). day는 1부터(0·음수는 NONE — 손상 방어).
# ★ 해금 판정이 **없다**는 것이 Festival과 갈리는 지점이다(CONTEXT ㉢ "처음부터"). 그래서 슬롯과
#   개최를 가를 이유도 없고, 이 함수 하나가 달력의 전부다.
static func event_for_day(d: int) -> int:
	if d <= 0:
		return NONE
	var s := GameClock.season_index_for_day(d)
	return s if GameClock.day_of_season(d) == int(DAY_OF_SEASON[s]) else NONE

static func is_event_day(d: int) -> bool:
	return event_for_day(d) != NONE

# 표시명("" = 범위 밖·평일). GameClock.season_name·Weather.name_of와 같은 관례.
static func name_of(ev: int) -> String:
	return NAMES[ev] if ev >= 0 and ev < NAMES.size() else ""

# ── 예고·배너 문구(main이 아침 알림·점괘 거울에 띄운다 — Festival 문법 1:1) ────
# 당일 아침 배너. "오늘 어디서 무엇이 열리는가" + 무엇을 하면 되는가 한 줄.
static func banner_text(ev: int) -> String:
	match ev:
		DERBY:
			return "오늘은 %s — 삼도천에서 낚으면 금빛 태그가 붙는다(부두 곁 부스에서 교환)" % name_of(ev)
		JELLYFISH:
			return "오늘은 %s — 저녁부터 황천해에 혼불해파리가 몰린다" % name_of(ev)
		GRANGE:
			return "오늘은 %s — 카페 곳간에서 출품할 수 있다(재고는 그대로)" % name_of(ev)
		NIGHT_MARKET:
			return "오늘은 %s — 나루 광장에 임시 매대가 선다(전 품목 2할 할인)" % name_of(ev)
	return ""

# D-1 예고 배너(전날 아침). 예고 = 알림 그 자체가 아니라 *준비할 시간을 주는 것*이다
# (곳간을 채워 두거나 미끼를 쟁이거나 엽전을 남겨 두는 하루).
static func preview_text(ev: int) -> String:
	match ev:
		DERBY:
			return "내일은 %s — 미끼를 챙겨 두자" % name_of(ev)
		JELLYFISH:
			return "내일은 %s — 저녁에 황천해로 나가 보자" % name_of(ev)
		GRANGE:
			return "내일은 %s — 곳간을 채워 두자" % name_of(ev)
		NIGHT_MARKET:
			return "내일은 %s — 엽전을 남겨 두자" % name_of(ev)
	return ""

# 점괘 거울 한 줄("3일 뒤: 저승 야시장"). days_ahead 0=오늘·1=내일. Festival.upcoming_text와 동형.
static func upcoming_text(ev: int, days_ahead: int) -> String:
	if ev == NONE:
		return ""
	var when := "오늘" if days_ahead <= 0 else ("내일" if days_ahead == 1 else "%d일 뒤" % days_ahead)
	return "%s: %s" % [when, name_of(ev)]

# ── ① 더비 — 태그 롤(결정 롤) ────────────────────────────────────────────────
# 그날 n번째 어획이 태그를 붙이는가. ⚠️ **`rand_from_seed` 믹싱 관례**(weather.gd 헤더의 그 함정):
# `hash("...") % 1000`을 직접 쓰면 순차 문자열의 하위 비트 선형성 때문에 저확률 출목이 통째로
# 사라진다. PCG를 한 겹 씌우면 결정성은 그대로고 분포만 균일해진다.
# ★ 시드 네임스페이스가 날씨·운·카페와 갈려 있어(접두사 "derby:") 기존 출목은 한 톨도 안 변한다.
static func roll_tag(d: int, nth: int) -> bool:
	return absi(rand_from_seed(hash("derby:%d:%d" % [d, nth]))[0]) % 1000 < DERBY_TAG_PERMIL

# n번째 교환(1-기반)의 보상. 3번째 이후는 마지막 행(엽전)이 무한 반복된다.
static func derby_reward(nth: int) -> Dictionary:
	if nth <= 0:
		return {}
	return DERBY_REWARDS[mini(nth, DERBY_REWARDS.size()) - 1]

# ── ② 해파리 창 ──────────────────────────────────────────────────────────────
# 지금이 창 안인가(그날 + 저녁/밤). 무대 판정(황천해)은 호출 측이 한다 — 이 클래스는 구역을 모른다.
static func is_jelly_window(d: int, phase: String) -> bool:
	return event_for_day(d) == JELLYFISH and JELLY_PHASES.has(phase)

# 이번 캐스팅이 해파리로 치환되는가(결정 롤 — 캐스팅 시드에서 파생).
static func roll_jelly(seed_value: int) -> bool:
	return absi(rand_from_seed(seed_value ^ 0x6a17d3e5)[0]) % 1000 < JELLY_BOOST_PERMIL

# ── ③ 장원제 — 채점(간이 Grange 문법) ────────────────────────────────────────
# 판매가 → 밴드 점수.
static func band_points(price: int) -> int:
	for row in GRANGE_BANDS:
		if price >= int(row[0]):
			return int(row[1])
	return 0

# 출품 채점. entries = [{"price": int, "in_season": bool}, …] (id는 호출 측 표시용 — 여기선 안 본다).
# 점수 = 다양성(2/종) + 밴드 합 + 제철 가점(3/종). 9종 초과분은 잘라 낸다(상한 = 규칙의 일부).
static func score_entries(entries: Array) -> int:
	var n := mini(entries.size(), GRANGE_MAX_ENTRIES)
	var sum := n * GRANGE_DIVERSITY_PT
	for i in n:
		var e: Dictionary = entries[i]
		sum += band_points(int(e.get("price", 0)))
		if bool(e.get("in_season", false)):
			sum += GRANGE_SEASON_PT
	return sum

# 점수 → 등급 인덱스(0 입선·1 우수·2 장원 · -1 = 미달). 미달이어도 **잃는 것은 없다**(옵트인 무손실).
static func grange_rank(score: int) -> int:
	var rank := -1
	for i in GRANGE_TIER_SCORES.size():
		if score >= int(GRANGE_TIER_SCORES[i]):
			rank = i
	return rank

static func grange_rank_name(rank: int) -> String:
	return GRANGE_TIER_NAMES[rank] if rank >= 0 and rank < GRANGE_TIER_NAMES.size() else "선외"

static func grange_gold(rank: int) -> int:
	return int(GRANGE_TIER_GOLD[rank]) if rank >= 0 and rank < GRANGE_TIER_GOLD.size() else 0

# ── ④ 야시장 — 매대 품목표 ───────────────────────────────────────────────────
# 행사 할인가(20% 오프 — 정수 반올림).
static func market_price(base: int) -> int:
	return int(round(float(base) * MARKET_DISCOUNT))

# 매대 진열 로스터. 반환 = [{kind, buy_id, base}] — 표시명·아이콘·보유 판정은 main이 붙인다
# (이 클래스는 인벤토리도 해금 원장도 모른다 — Festival이 진척을 주입받는 것과 같은 디커플링).
# ★ 가구 세트는 목공방과 **중복 판매**다(결정 9가 명시 허용): 죽은 창구였던 가구 판매에 두 번째
#   입구를 내는 것이 이 행사의 직무라, 중복이 결함이 아니라 목적이다(게다가 여기가 2할 싸다).
static func market_rows() -> Array:
	var rows: Array = []
	for set_id in MARKET_DECO_SETS:
		rows.append({"kind": "fest_deco", "buy_id": set_id,
			"base": HomeDecoCatalog.price_of(set_id)})
	rows.append({"kind": "fest_item", "buy_id": MARKET_RARECROW, "base": MARKET_RARECROW_PRICE})
	rows.append({"kind": "fest_seed", "buy_id": MARKET_SEED_CROP,
		"base": CropCatalog.seed_cost(MARKET_SEED_CROP)})
	return rows

# ── 상태(여기서부터 인스턴스 — 파생 불가능한 것만 든다) ───────────────────────
# 더비 원장은 **당일치**다: day가 바뀌면 통째로 0으로 되감긴다(태그 이월 없음 — 잠정. 이월을 열면
# "며칠 모아 한 번에 교환"이 최적이 되어 그날의 경연이라는 정체성이 흐려진다).
var derby_day := 0        # 아래 세 값이 속한 날(0 = 아직 아무 날도 아님)
var derby_catches := 0    # 그날 삼도천 어획 수(태그 롤의 '어획 순번' 축)
var derby_tags := 0       # 그날 딴 금빛 태그(미교환분)
var derby_exchanges := 0  # 그날 교환 횟수(보상 사다리 위치)

# 장원제 — 하루 1회 출품. 개최 이력은 "언제 무슨 등급이었나"의 최고치만 남긴다(전량 이력은 지금
# 쓰임이 없다 — 필요해지면 가법 키를 하나 더 붙이면 된다).
var grange_day := 0       # 마지막으로 출품한 day(같은 날 재출품 차단)
var grange_best := -1     # 역대 최고 등급(-1 = 아직 없음 — 표시·후속 콘텐츠 훅)

# 야시장 — 한정 물품 구매 이력(id 배열). 가구 세트 해금은 home_deco가 이미 들고 있으므로 여기선
# **한정 물품만** 기록한다(이중 진실원 방지).
var market_bought: Array = []

# ── 더비 원장 조작 ──────────────────────────────────────────────────────────
# 날이 바뀌었으면 당일치 원장을 되감는다(모든 더비 API의 첫 줄 — 멱등).
func _roll_over(d: int) -> void:
	if derby_day == d:
		return
	derby_day = d
	derby_catches = 0
	derby_tags = 0
	derby_exchanges = 0

# 삼도천 어획 1건 기록 → 태그가 붙었으면 true. 호출 측(main)이 무대·행사일을 이미 가려서 부른다.
func note_catch(d: int) -> bool:
	_roll_over(d)
	derby_catches += 1
	if not roll_tag(d, derby_catches):
		return false
	derby_tags += 1
	return true

# 그날 미교환 태그 수(날이 다르면 0 — 당일 소멸의 표현).
func tags_on(d: int) -> int:
	return derby_tags if derby_day == d else 0

# 태그 1개를 보상으로 바꾼다. 반환 = 보상 dict(빈 dict = 태그 없음). 지급은 main이 한다
# (이 노드는 지갑도 인벤토리도 모른다 — larder가 wallet을 모르는 것과 같은 디커플링).
func exchange_tag(d: int) -> Dictionary:
	_roll_over(d)
	if derby_tags <= 0:
		return {}
	derby_tags -= 1
	derby_exchanges += 1
	return derby_reward(derby_exchanges)

# ── 장원제 원장 ─────────────────────────────────────────────────────────────
func grange_entered(d: int) -> bool:
	return grange_day == d

# 출품 기록(등급 저장 — 하루 1회). 이미 오늘 출품했으면 false.
func record_grange(d: int, rank: int) -> bool:
	if grange_entered(d):
		return false
	grange_day = d
	grange_best = maxi(grange_best, rank)
	return true

# ── 야시장 원장 ─────────────────────────────────────────────────────────────
func has_bought(id: String) -> bool:
	return market_bought.has(id)

func record_bought(id: String) -> void:
	if not market_bought.has(id):
		market_bought.append(id)

# ── 세이브/로드(가법 키 한 조각 — 구세이브는 빈 원장) ─────────────────────────
func to_save() -> Dictionary:
	return {
		"derby_day": derby_day, "derby_catches": derby_catches,
		"derby_tags": derby_tags, "derby_exchanges": derby_exchanges,
		"grange_day": grange_day, "grange_best": grange_best,
		"market_bought": market_bought.duplicate(),
	}

# 복원: 손상(음수·타입 불일치)은 걸러 안전하게(larder·출하함 결).
func load_save(data: Dictionary) -> void:
	derby_day = maxi(int(data.get("derby_day", 0)), 0)
	derby_catches = maxi(int(data.get("derby_catches", 0)), 0)
	derby_tags = maxi(int(data.get("derby_tags", 0)), 0)
	derby_exchanges = maxi(int(data.get("derby_exchanges", 0)), 0)
	grange_day = maxi(int(data.get("grange_day", 0)), 0)
	grange_best = clampi(int(data.get("grange_best", -1)), -1, GRANGE_TIER_NAMES.size() - 1)
	market_bought = []
	var raw: Variant = data.get("market_bought", [])
	if typeof(raw) == TYPE_ARRAY:
		for id in raw:
			var sid := str(id)
			if sid != "" and not market_bought.has(sid):
				market_bought.append(sid)
