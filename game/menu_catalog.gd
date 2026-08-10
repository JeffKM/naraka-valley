extends RefCounted
class_name MenuCatalog
# ★[S6-T1 / ADR-0064 결정 2] 카페 메뉴 정적 카탈로그 — 기본 메뉴 + 융합 메뉴 2단 구조.
#
# 목적: "카페가 무엇을 파는가"를 한 곳에서 정의한다. ItemCatalog가 "아이템이 무엇인가"를 들듯,
#       MenuCatalog는 "메뉴가 무엇이고 무엇을 먹고 얼마인가"(표시명·시그니처 재료·가격)를 든다.
#       CropCatalog·FishCatalog·GearCatalog와 같은 결의 정적 참조 데이터라 씬 노드가 아니다.
#
# 2단 구조(ADR-0064 결정 2 · CONTEXT [융합 메뉴] — "평평 ≠ 막힘" 보존):
#   ㉠ 기본 메뉴 — **무재료·항시 판매·정액 35냥**. 주방요괴가 백스테이지에서 대는 플레인 음료라
#      곳간이 텅 비어도 카페가 안 멈춘다(폴백 대상 — 손님은 떠나지 않는다, 결정 4).
#   ㉡ 융합 메뉴 — **시그니처 저승 산출물 1종을 1개** 곳간에서 차감하고 프리미엄가로 나간다.
#      다중 재료 레시피 트리는 만들지 않는다(ADR-0001 야크 셰이빙 회피 — ADR-0007 확정).
#
# ★ 가격 = **시그니처 산출물 기본가 × PRICE_MULT(2.5) 반올림**(결정 4). 런타임 파생이라
#   작물·어종 판매가가 바뀌면 메뉴가가 저절로 따라온다(데이터 중복 0 — 이 파일은 배수만 든다).
#   좌표 근거: 스타듀 술집 마진 ×2 와 케그 ×3 사이 = 즉석 서빙 프리미엄(ADR-0064 결정 4).
#   ⚠️ 이 파일은 ItemCatalog를 부르고 ItemCatalog는 MenuCatalog를 부른다(상호 참조). Godot 4.6에서
#      class_name 간 정적 상호 호출은 정상 동작하며(실증), 재귀는 없다 — 시그니처는 절대 메뉴가 아니다.
#
# ★ 명명은 **전부 잠정**이다(ADR-0064 결정 2 — owner 큐 1순위). 정의상 "실제 나라카 컨셉카페
#   메뉴 × 저승 번안"인데 실제 메뉴판 자료가 저장소에 없다. 그래서 각 메뉴가 **어떤 현실 메뉴를
#   번안한 것인지**를 `raw` 필드로 함께 박아 둔다 — owner가 메뉴판을 주면 `name_ko`/`raw` 두
#   문자열만 갈아끼우면 되고(코드·가격·시그니처 배선 불변), `raw`가 대조표 역할을 한다.
#
# ★ 함정(잠복 실증 — [Godot static set_* 흡수 버그]): static 메서드 이름을 `set_*`로 짓지 말 것.
#   엔진 메서드에 먹혀 조용히 null이 된다. 조회는 `name_of`/`price_of` 관례를 따른다.

# 융합 메뉴 프리미엄 배수(시그니처 기본가 → 메뉴가). *잠정* — owner 큐.
const PRICE_MULT := 2.5

# ── ★[S6-T3 / ADR-0064 결정 7] 메뉴판 슬롯(융합 메뉴 동시 게시 칸 수) ──────────
# 해금·절기·재고를 다 통과한 융합 메뉴라도 **메뉴판에 걸린 만큼만** 손님이 주문한다. 카페를
# 일구면 판이 넓어진다(2단이 여는 콘텐츠 넷 중 하나). 잠정 그레이박스 레버 — owner 결재.
# ★ 이 제약이 있어야 "무엇을 곳간에 쟁일까"가 후반에도 선택으로 남는다. 슬롯이 무한이면 해금된
#   전 로스터가 늘 걸려 있어 재고 선택이 곧 메뉴 선택이 되지 못한다(공급 선택 게임 — 결정 10).
# ★ 채우는 순서·잘라 내는 규칙은 main._cafe_order_pool이 든다(곳간 재고를 아는 쪽이라 — 이 파일은
#   재고를 모른다. 값만 여기서 든다).
const FUSION_SLOTS_STAGE1 := 4
const FUSION_SLOTS_STAGE2 := 8
# 기본 메뉴 정액가. 현행 서빙 정액가와 **같은 값 하나**에서 파생한다(cafe.gd가 값의 주인 —
# 여기서 35를 다시 박으면 두 곳이 갈라진다). 결정 4 "기본 35냥(현행 정액 유지)".
const BASE_PRICE := Cafe.BASE_PRICE

# ── 기본 메뉴 4종(무재료·항시) ───────────────────────────────────────────────
const AMERICANO := "menu_americano"
const COLD_WATER := "menu_cold_water"
const BARLEY_TEA := "menu_barley_tea"
const HOT_MILK := "menu_hot_milk"

# 기본 메뉴 id → {name_ko(표시명·잠정), raw(번안 원본 = 현실 카페 메뉴 — owner 대조표), color(색박스)}.
# 가격은 전부 BASE_PRICE라 항목에 안 싣는다(정액이 곧 기본 메뉴의 정의 — price_of가 상수를 돌려준다).
const BASICS := {
	AMERICANO: {"name_ko": "명부 아메리카노", "raw": "아메리카노",
		"color": Color(0.28, 0.20, 0.16)},      # 검은 커피
	COLD_WATER: {"name_ko": "삼도천 냉수", "raw": "생수",
		"color": Color(0.55, 0.72, 0.80)},      # 맑은 물빛
	BARLEY_TEA: {"name_ko": "잿빛 보리차", "raw": "보리차",
		"color": Color(0.52, 0.40, 0.24)},      # 볶은 보리빛
	HOT_MILK: {"name_ko": "넋 데운 우유", "raw": "따뜻한 우유",
		"color": Color(0.90, 0.87, 0.80)},      # 뽀얀 우유빛
}

# ── 융합 메뉴 12종(시그니처 1종 1개 차감) ─────────────────────────────────────
# 로스터 구성(ADR-0064 결정 2): 작물 5 · 물고기 3 · 채집물 2 · 수액 1 · 나락혼정 1(최상위).
# 시그니처는 전부 **실존 id**다(CropCatalog·FishCatalog·ItemCatalog 로스터에서 골랐고,
# menu_catalog_test ②가 `ItemCatalog.has_item`으로 매 실행 대조한다).
const HONRYEONGCHO_LATTE := "menu_honryeongcho_latte"
const PIANHWA_ADE := "menu_pianhwa_ade"
const HOBAK_LATTE := "menu_hobak_latte"
const PODO_SMOOTHIE := "menu_podo_smoothie"
const BULSAGWA_TART := "menu_bulsagwa_tart"
const BUNGEO_PPANG := "menu_bungeo_ppang"
const DOMI_PANINI := "menu_domi_panini"
const HAEPARI_ADE := "menu_haepari_ade"
const SONGI_SOUP := "menu_songi_soup"
const DONGBAEK_MILKTEA := "menu_dongbaek_milktea"
const DANPUNG_PANCAKE := "menu_danpung_pancake"
const HONJEONG_EINSPANNER := "menu_honjeong_einspanner"

# 융합 메뉴 id → {name_ko, raw, signature(차감 아이템 id 1종), color}.
# 가격은 signature에서 파생하므로 여기 없다(price_of 참조 — 단일 출처).
const FUSIONS := {
	# 작물 5 — 밭에서 길러 메뉴가 되는 "농사 그리고 카페"의 본체(CONTEXT [융합 메뉴]).
	HONRYEONGCHO_LATTE: {"name_ko": "혼령초 라떼", "raw": "말차 라떼",
		"signature": CropCatalog.HONRYEONGCHO, "color": Color(0.44, 0.60, 0.42)},
	PIANHWA_ADE: {"name_ko": "피안화 에이드", "raw": "자몽 에이드",
		"signature": CropCatalog.PIANHWA, "color": Color(0.82, 0.28, 0.32)},
	HOBAK_LATTE: {"name_ko": "영혼 호박 라떼", "raw": "단호박 라떼",
		"signature": CropCatalog.YEONGHON_HOBAK, "color": Color(0.85, 0.58, 0.24)},
	PODO_SMOOTHIE: {"name_ko": "황천포도 스무디", "raw": "청포도 스무디",
		"signature": CropCatalog.HWANGCHEON_PODO, "color": Color(0.52, 0.36, 0.66)},
	BULSAGWA_TART: {"name_ko": "불사과 타르트", "raw": "애플 타르트",
		"signature": CropCatalog.BULSAGWA, "color": Color(0.78, 0.32, 0.26)},
	# 물고기 3 — 상시종(넋붕어)으로 초반 진입점을 열고, 중·야간종으로 위를 벌린다.
	BUNGEO_PPANG: {"name_ko": "넋붕어빵", "raw": "붕어빵",
		"signature": FishCatalog.NEOK_BUNGEO, "color": Color(0.72, 0.55, 0.34)},
	DOMI_PANINI: {"name_ko": "저녁놀도미 파니니", "raw": "파니니",
		"signature": FishCatalog.JEONYEOKNOL_DOMI, "color": Color(0.80, 0.46, 0.36)},
	HAEPARI_ADE: {"name_ko": "혼불해파리 젤리 에이드", "raw": "젤리 에이드",
		"signature": FishCatalog.HONBUL_HAEPARI, "color": Color(0.46, 0.66, 0.78)},
	# 채집물 2 — 숲에서 주워 오는 축(줍기=품질의 축이라 메뉴는 품질 무차원으로 받는다).
	SONGI_SOUP: {"name_ko": "넋송이 크림수프", "raw": "머시룸 크림수프",
		"signature": ItemCatalog.NEOK_SONGI, "color": Color(0.74, 0.68, 0.56)},
	DONGBAEK_MILKTEA: {"name_ko": "서리동백 밀크티", "raw": "밀크티",
		"signature": ItemCatalog.SEORI_DONGBAEK, "color": Color(0.86, 0.62, 0.62)},
	# 수액 1 — 채취기가 벌어다 주는 패시브 산출의 소비처(S4-T6이 "팔리기만 하던" 것을 잇는다).
	DANPUNG_PANCAKE: {"name_ko": "명단풍꿀 팬케이크", "raw": "메이플 팬케이크",
		"signature": ItemCatalog.MYEONGDANPUNG_KKUL, "color": Color(0.88, 0.72, 0.40)},
	# 나락혼정 1 — 로스터 최상위. S5-T7이 "소비처는 S6"으로 넘긴 그 자리다(ADR-0063 결정 7).
	HONJEONG_EINSPANNER: {"name_ko": "나락혼정 아인슈페너", "raw": "아인슈페너",
		"signature": ItemCatalog.NARAK_HONJEONG, "color": Color(0.34, 0.26, 0.40)},
}

# ── ★[S6-T7 / ADR-0064 결정 9] 곁들이 — 플레이어가 먹으면 혼력이 도는 융합 메뉴 ──────
# ADR 원문은 "융합 메뉴 **일부**는 플레이어 소비 시 혼력 회복"이다. 그 *일부*를 가르는 규칙:
#   **마시는 잔은 팔고, 먹는 것은 든든하다** — 로스터 12종 중 요리 5종(타르트·붕어빵·파니니·
#   수프·팬케이크)만 곁들이고, 음료 7종(라떼·에이드·스무디·밀크티·아인슈페너)은 판매 전용이다.
#   근거: ㉠ 규칙이 이름만 봐도 읽힌다(별도 UI 설명이 필요 없다) ㉡ 최상위 나락혼정 아인슈페너를
#   판매 전용으로 남겨 "로스터 꼭대기 = 매출의 정점"이 흐려지지 않는다.
#
# ★ 회복량은 **명시 표**다(가격 파생 아님). 가격은 시그니처를 따라 80~1500냥으로 19배 벌어지는데
#   혼력은 MAX가 100이라 같은 비율로 못 펴진다 — 파생식을 쓰면 팬케이크 한 장이 하루치를 넘긴다.
#   그래서 값싼 잔이 아래, 비싼 잔이 위인 **순서만** 가격을 따르고 폭은 손으로 좁혔다.
# ★ 밴드 좌표: `SoulEnergy.COST_PER_ACTION`(10) = 행동 한 번 → 표는 "행동 1.5~3회분"이다.
#   상한 30은 `ItemCatalog.MYEONGBUHWAN_HEAL`(40) **아래**로 잡았다 — 취침으로 공짜 풀회복되는
#   혼력이 150냥 주고 사는 HP보다 후해지면 갱도 회복 소모품의 자리가 없어진다.
# ★ 경제적으로 곁들이는 **비싼 연료**다(타르트 1500냥어치를 30 혼력으로 태운다). 의도적이다 —
#   싸면 "밭 갈기 전에 한 장 굽고 나간다"가 지배 전략이 되어 곳간의 선택(팔까/키울까)이 죽는다.
#   곁들이는 *하루를 조금 늘리는 사치*이지 상시 연료가 아니다.
# ★ 전부 **잠정 그레이박스 레버**(owner 큐 — 메뉴판 대조 때 로스터·수치 함께 재검토).
const SIDE_DISHES := {
	BUNGEO_PPANG: 15,        # 넋붕어(상시종) — 초반부터 구울 수 있는 진입 한 접시
	DOMI_PANINI: 20,         # 저녁놀도미(중 체급·시간 잠금)
	SONGI_SOUP: 20,          # 넋송이(망연절 채집)
	DANPUNG_PANCAKE: 25,     # 명단풍꿀(채취기 9일 패시브)
	BULSAGWA_TART: 30,       # 불사과(미혹 심층 — 로스터 최고 재료가) = 곁들이 상한
}

# ── 판정 ────────────────────────────────────────────────────────────────────
# 이 메뉴를 플레이어가 먹을 수 있나(= 곁들이인가). 기본 메뉴는 전부 false — 카페 판매 전용이다.
static func is_side_dish(id: String) -> bool:
	return SIDE_DISHES.has(id)

# 먹었을 때 차는 혼력(0 = 곁들이가 아니다 — 판매 전용 메뉴·기본 메뉴·비-메뉴 전부 0).
# ★ `ItemCatalog.potion_heal`과 같은 조회 결이다(회복 수치의 단일 출처는 위 표 하나).
static func restore_of(id: String) -> int:
	return int(SIDE_DISHES.get(id, 0))

# 곁들이 목록(주방요괴 창구가 순회 — 정렬은 dict 선언 순 = 회복량 오름차순).
static func side_dish_ids() -> Array:
	return SIDE_DISHES.keys()

static func is_basic(id: String) -> bool:
	return BASICS.has(id)

static func is_fusion(id: String) -> bool:
	return FUSIONS.has(id)

# 카탈로그에 있는 메뉴인가(ItemCatalog._is_menu가 이걸 본다 — FishCatalog.has 관례 동형).
static func has(id: String) -> bool:
	return is_basic(id) or is_fusion(id)

# ── 조회 ────────────────────────────────────────────────────────────────────
static func name_of(id: String) -> String:
	if is_basic(id):
		return BASICS[id]["name_ko"]
	if is_fusion(id):
		return FUSIONS[id]["name_ko"]
	return ""

# 번안 원본(현실 카페 메뉴명) — owner 메뉴판 대조용. 게임 안에는 안 나온다(대조표 전용).
static func raw_of(id: String) -> String:
	if is_basic(id):
		return BASICS[id]["raw"]
	if is_fusion(id):
		return FUSIONS[id]["raw"]
	return ""

# 이 메뉴가 곳간에서 차감하는 시그니처 산출물 id("" = 기본 메뉴 = 무재료).
static func signature_of(id: String) -> String:
	return String(FUSIONS[id]["signature"]) if is_fusion(id) else ""

# 메뉴 판매가. 기본 = 정액 BASE_PRICE / 융합 = 시그니처 기본가 × PRICE_MULT 반올림.
# ★ 시그니처 기본가는 **일반 등급(Q_NORMAL)** 기준이다 — 메뉴는 품질 무차원이라(catalog §1-B)
#   은/금 재료를 넣어도 메뉴가가 안 오른다(품질은 raw 판매·선물 쪽 축).
static func price_of(id: String) -> int:
	if is_basic(id):
		return BASE_PRICE
	if is_fusion(id):
		return int(round(ItemCatalog.price_of(signature_of(id)) * PRICE_MULT))
	return 0

# 그레이박스 아이콘 색(CAT_CONSUMABLE 색박스 폴백이 읽는다 — 명부환·계단과 같은 경로).
static func color_of(id: String) -> Color:
	if is_basic(id):
		return BASICS[id]["color"]
	if is_fusion(id):
		return FUSIONS[id]["color"]
	return Color.WHITE

# ── ★[S6-T2 / ADR-0064 결정 2] 절기 창(판매 로테이션) ────────────────────────
# 이 메뉴를 이 절기에 주문할 수 있나. ★ **별도 달력 데이터를 만들지 않는다** — 판매 창은
# *시그니처 재료의 절기 창*에서 파생된다("작물 사멸이 곧 메뉴 로테이션", 결정 2). 그래서 이 함수는
# 판정을 하지 않고 재료 종류별 주인에게 위임만 한다(어종=FishCatalog·채집물=ForageSpawns).
#
# 분기 순서는 menu_catalog_test ①의 구성 집계와 같은 순서다(작물 → 어종 → 수액 → 채집물 → 그 외).
# ★[S7-T2 / ADR-0065 결정 2] 작물도 이제 자기 절기를 든다(예약돼 있던 [S7 훅] 이행) — 어종·채집물과
#   **완전 대칭**으로 CropCatalog에 위임한다. 사멸이 곧 메뉴 로테이션이라, 밭에서 스러진 작물의
#   시그니처 메뉴는 같은 날 메뉴판에서도 내려간다. 이 파일엔 여전히 달력이 없다(위임만).
#   다절기 작물(불사과)은 seasons가 빈 배열이라 사철로 떨어진다 — 판정은 CropCatalog가 든다.
# ★ 수액·나락혼정·기본 메뉴 = 사철(패시브 채취·던전 산출·무재료라 하늘을 안 본다).
static func in_season(id: String, season_idx: int) -> bool:
	if is_basic(id):
		return true
	if not is_fusion(id):
		return false
	var sig := signature_of(id)
	if CropCatalog.has_crop(sig):
		return CropCatalog.in_season(sig, season_idx)  # ★[S7-T2] 작물 절기 = 사멸 창 그대로
	if FishCatalog.has(sig):
		return FishCatalog.in_season(sig, season_idx)
	if ItemCatalog.SAP_GOODS.has(sig):
		return true                                   # 수액 = 채취기 패시브(절기 무관)
	if ItemCatalog.FORAGEABLES.has(sig):
		var s := ForageSpawns.season_of(sig)
		return s < 0 or s == season_idx               # -1 = 사철(심층·해변종)
	return true                                       # 나락혼정 등 자재 시그니처 = 사철

# ── 열거(주문 롤·메뉴판 UI가 순회 — 정렬은 dict 선언 순서 그대로) ──────────────
static func basic_ids() -> Array:
	return BASICS.keys()

static func fusion_ids() -> Array:
	return FUSIONS.keys()

static func ids() -> Array:
	var out: Array = BASICS.keys()
	out.append_array(FUSIONS.keys())
	return out

# 시그니처 산출물 → 그걸 먹는 융합 메뉴 id("" = 그 재료를 쓰는 메뉴 없음). 곳간 재고에서
# "이걸 쟁여 두면 무슨 메뉴가 되나"를 역참조한다(주문 롤·곳간 툴팁 — T2 소관의 입력).
# ★ 시그니처 : 메뉴 = 1:1이다(한 재료를 두 메뉴가 먹으면 재고 경합이 생겨 "무엇을 기를까"의
#   선택이 흐려진다 — menu_catalog_test ④가 중복 0을 단언한다).
static func menu_for_signature(item_id: String) -> String:
	for mid in FUSIONS:
		if String(FUSIONS[mid]["signature"]) == item_id:
			return mid
	return ""
