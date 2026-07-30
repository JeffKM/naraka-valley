extends RefCounted
class_name CraftCatalog
# ★[S4-T5 / ADR-0062 결정 5] 손 제작 레시피 카탈로그 — "무엇을, 무엇으로, 언제 만들 수 있나"의
# 단일 출처(정적 참조 데이터).
#
# 목적: ADR-0062 결정 5("최소 핸드크래프트 제작 시스템 신설")의 데이터 절반. 수액 채취기(결정 4)와
#       자생 씨앗(ADR-0033 #4)이 스타듀에서 둘 다 *채집 레벨 해금 제작*인데 이 코드베이스엔 제작이
#       없었다 — 그 최소 골격의 레시피 표가 여기다. 실행(재료 차감·산출 적재)은 main._craft가,
#       화면(제작 탭)은 inv_frame이 맡는다(GearCatalog 삼각 디커플링 동형).
#
# 설계 메모(어기면 ADR-0062 결정 5 위반):
#   - **이건 손 제작(즉시 완성)이다.** 투입→시간 경과→산출의 기계 가공(§2-6 미끼·비료·S6 요리)과
#     명확히 다른 시스템 — 그쪽은 각자의 슬라이스에서 *레시피만* 여기에 추가한다(그릇은 지금, 내용은
#     그때). 과욕 금지: 초기 레시피 = 야생 씨앗 4 + 희소종 모종 4 + 수액 채취기 = 9뿐.
#   - **해금 2축**: unlock_level(채집 레벨 — 스타듀 Wild Seeds lvl1/4/6/7·Tapper lvl4 상속) +
#     unlock_species(종 발견 게이트 — ADR-0033 #4 "희소종은 탐험으로 *먼저 발견*해야 씨앗 제작").
#     발견 원장(_forage_found)은 main이 세이브로 들고, unlocked()에 *주입*된다(카탈로그는 무상태).
#   - **가치 창출 금지**: 산출가가 재료가를 크게 웃돌지 않게(제작이 판매 차익 머신이 되면 ADR-0052
#     비-가치 원칙과 마찰). 야생 씨앗 10개는 "재료 3개를 다음 절기 자급 씨앗으로 바꾸는" 편의다.
#   - 여기엔 무작위가 없다(전 판정 결정적). ItemCatalog·CropCatalog만 참조한다(참조 순환 0 —
#     ItemCatalog는 CraftCatalog를 모른다).

# ── 레시피 id ───────────────────────────────────────────────────────────────
const WILD_SEEDS_PIAN := "wild_seeds_pian"
const WILD_SEEDS_YUHWA := "wild_seeds_yuhwa"
const WILD_SEEDS_MANGYEON := "wild_seeds_mangyeon"
const WILD_SEEDS_SEONGYA := "wild_seeds_seongya"
const RARE_SEED_MIHOK_NANCHO := "rare_seed_mihok_nancho"
const RARE_SEED_YURYEONGCHO := "rare_seed_yuryeongcho"
const RARE_SEED_MYEONGWOL := "rare_seed_myeongwol"
const RARE_SEED_SEORI_HONBAEK := "rare_seed_seori_honbaek"
const TAPPER := "tapper"
const FURNACE := "furnace"   # ★[S5-T3] 업화로(ADR-0063 결정 3)

# ── 카탈로그. 키 = 레시피 id ────────────────────────────────────────────────
# 필드:
#   name_ko        : 표시명(제작 탭 행)
#   out_item       : 산출 아이템 id / out_count: 산출 수량(야생 씨앗 = 1제작 10개, 스타듀 상속)
#   mats           : [{item, count}] 재료(전부 있어야 제작)
#   unlock_level   : 채집 레벨 해금(스타듀 lvl 계단 상속)
#   unlock_species : "" 아니면 그 채집물을 *주워 본 적*이 있어야 해금(종 발견 게이트)
static func catalog() -> Dictionary:
	return {
		WILD_SEEDS_PIAN: {"name_ko": "야생 씨앗(피안)", "out_item": ItemCatalog.seed_id(CropCatalog.WILD_PIAN),
			"out_count": 10, "unlock_level": 1, "unlock_species": "",
			"mats": [{"item": ItemCatalog.NEOK_GOSARI, "count": 1}, {"item": ItemCatalog.JAETBIT_NAENGI, "count": 1},
				{"item": ItemCatalog.JEOSEUNG_DALLAE, "count": 1}]},
		WILD_SEEDS_YUHWA: {"name_ko": "야생 씨앗(유화)", "out_item": ItemCatalog.seed_id(CropCatalog.WILD_YUHWA),
			"out_count": 10, "unlock_level": 4, "unlock_species": "",
			"mats": [{"item": ItemCatalog.JEOSEUNG_SANDALGI, "count": 1}, {"item": ItemCatalog.HONIP_BAKHA, "count": 1},
				{"item": ItemCatalog.JAETBIT_DEODEOK, "count": 1}]},
		WILD_SEEDS_MANGYEON: {"name_ko": "야생 씨앗(망연)", "out_item": ItemCatalog.seed_id(CropCatalog.WILD_MANGYEON),
			"out_count": 10, "unlock_level": 6, "unlock_species": "",
			"mats": [{"item": ItemCatalog.JAETBIT_DOTORI, "count": 1}, {"item": ItemCatalog.ANGAE_DORAJI, "count": 1},
				{"item": ItemCatalog.NEOK_SONGI, "count": 1}]},
		WILD_SEEDS_SEONGYA: {"name_ko": "야생 씨앗(성야)", "out_item": ItemCatalog.seed_id(CropCatalog.WILD_SEONGYA),
			"out_count": 10, "unlock_level": 7, "unlock_species": "",
			"mats": [{"item": ItemCatalog.EONHON_PPURI, "count": 1}, {"item": ItemCatalog.SEORI_DONGBAEK, "count": 1},
				{"item": ItemCatalog.SEONGYA_SOLBANGUL, "count": 1}]},
		RARE_SEED_MIHOK_NANCHO: {"name_ko": "미혹난초 씨앗", "out_item": ItemCatalog.seed_id(CropCatalog.WILD_MIHOK_NANCHO),
			"out_count": 3, "unlock_level": 6, "unlock_species": ItemCatalog.MIHOK_NANCHO,
			"mats": [{"item": ItemCatalog.MIHOK_NANCHO, "count": 2}]},
		RARE_SEED_YURYEONGCHO: {"name_ko": "유령초 씨앗", "out_item": ItemCatalog.seed_id(CropCatalog.WILD_YURYEONGCHO),
			"out_count": 3, "unlock_level": 6, "unlock_species": ItemCatalog.YURYEONGCHO,
			"mats": [{"item": ItemCatalog.YURYEONGCHO, "count": 2}]},
		RARE_SEED_MYEONGWOL: {"name_ko": "명월버섯 씨앗", "out_item": ItemCatalog.seed_id(CropCatalog.WILD_MYEONGWOL),
			"out_count": 3, "unlock_level": 6, "unlock_species": ItemCatalog.MYEONGWOL_BEOSEOT,
			"mats": [{"item": ItemCatalog.MYEONGWOL_BEOSEOT, "count": 2}]},
		RARE_SEED_SEORI_HONBAEK: {"name_ko": "서리혼백초 씨앗", "out_item": ItemCatalog.seed_id(CropCatalog.WILD_SEORI_HONBAEK),
			"out_count": 3, "unlock_level": 6, "unlock_species": ItemCatalog.SEORI_HONBAEKCHO,
			"mats": [{"item": ItemCatalog.SEORI_HONBAEKCHO, "count": 2}]},
		# 수액 채취기(ADR-0062 결정 4) — 아이템 산출까지가 T5. 설치·원장·주기는 S4-T6 소관.
		# 재료: 원목 40 + 석화 목재 2(스타듀 목재40+구리주괴2 대응 — 갱도 금속 미빌드 대체, 잠정·owner 큐).
		# ★[S5-T3] 명동 주괴가 실존하게 됐지만 **이 레시피는 석화 목재로 남긴다**(잠정 유지 결정):
		#   채취기는 *채집 lvl4* 해금 레시피라 재료를 주괴로 바꾸면 S4 콘텐츠가 S5 채광 사슬(갱도
		#   도달 + 업화로 제작 + 30분 제련) 뒤로 밀린다. "각 활동은 자기 축으로 완결"(ADR-0008
		#   평평≠막힘)이 상위 원칙이라 교차 게이팅을 새로 만들지 않는다. ★owner 큐(재검토 대상).
		TAPPER: {"name_ko": "수액 채취기", "out_item": ItemCatalog.TAPPER,
			"out_count": 1, "unlock_level": 4, "unlock_species": "",
			"mats": [{"item": ItemCatalog.WOOD, "count": 40}, {"item": ItemCatalog.PETRIFIED_WOOD, "count": 2}]},
		# ★[S5-T3 / ADR-0063 결정 3] 업화로 — 돌 25 + 명동 광석 20(스타듀 Furnace 1:1).
		# ★ `unlock_level: 0` = **무조건 노출**이다. 스타듀 문법은 "명동 광석 첫 획득 시 레시피 습득"
		#   이지만, 이 카탈로그의 해금 축은 *채집 레벨*(ForageSkill) 하나뿐이라 채광 레시피에
		#   채집 계단을 물리면 축이 어긋난다(제련이 채집 lvl에 인질). 그래서 그레이박스 단순화로
		#   상시 노출하고, **재료 자체가 게이트**로 남는다 — 명동 광석 20개는 갱도에 내려가야만
		#   모이므로 "광석을 처음 캔 뒤에야 만들 수 있다"는 결과는 스타듀와 같다(경로만 다르다).
		#   ★잠정(owner 큐): "종 발견" 게이트(unlock_species)의 광물판을 여는 게 정석이다.
		FURNACE: {"name_ko": "업화로", "out_item": ItemCatalog.FURNACE,
			"out_count": 1, "unlock_level": 0, "unlock_species": "",
			"mats": [{"item": ItemCatalog.STONE, "count": 25}, {"item": ItemCatalog.ORE_MYEONGDONG, "count": 20}]},
	}

# 레시피 id 목록(카탈로그 정의 순서 = 제작 탭 표시 순서 — 해금 레벨 오름 결).
static func ids() -> Array:
	# ★ 업화로가 맨 앞 = 해금 레벨 0(오름 결 보존 — 상시 노출이라 목록 첫 줄이 자연스럽다).
	return [FURNACE, WILD_SEEDS_PIAN, TAPPER, WILD_SEEDS_YUHWA, WILD_SEEDS_MANGYEON,
		RARE_SEED_MIHOK_NANCHO, RARE_SEED_YURYEONGCHO, RARE_SEED_MYEONGWOL, RARE_SEED_SEORI_HONBAEK,
		WILD_SEEDS_SEONGYA]

static func has(id: String) -> bool:
	return catalog().has(id)

static func get_recipe(id: String) -> Dictionary:
	return catalog().get(id, {})

# 해금됐는가 = 채집 레벨 + (있다면) 종 발견. found = main의 발견 원장 {species_id: true}.
static func unlocked(id: String, forage_level: int, found: Dictionary) -> bool:
	if not has(id):
		return false
	var r := get_recipe(id)
	if forage_level < int(r["unlock_level"]):
		return false
	var sp := String(r["unlock_species"])
	return sp == "" or found.get(sp, false)

# 재료가 전부 있는가. counts = Callable(item_id) -> int (인벤 보유량 조회 주입 — 카탈로그는 인벤 무지).
static func can_craft(id: String, counts: Callable) -> bool:
	if not has(id):
		return false
	for m in get_recipe(id)["mats"]:
		if int(counts.call(String(m["item"]))) < int(m["count"]):
			return false
	return true

# 재료 요약 문자열("넋고사리 1 · 잿빛냉이 1 · 저승달래 1") — 제작 탭 행 표시용.
static func mats_text(id: String) -> String:
	if not has(id):
		return ""
	var parts: Array = []
	for m in get_recipe(id)["mats"]:
		parts.append("%s %d" % [ItemCatalog.name_of(String(m["item"])), int(m["count"])])
	return " · ".join(parts)
