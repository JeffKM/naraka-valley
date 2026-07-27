extends RefCounted
class_name FishCatalog
# ★[S3-T3 / ADR-0061 결정 3] 어종 로스터 18종 — 데이터 주도 정적 카탈로그.
#
# 목적: "무엇이 낚이는가"(어종·서식지·절기/시간 잠금·체급·가격·격투 파라미터)를 한 곳에 든다.
#       CropCatalog가 "작물이 어떻게 자라나"를, FishingSession이 "격투가 어떻게 굴러가나"를 들듯,
#       FishCatalog는 **"이 물가·이 절기·이 시각에 무엇이 걸리나"**만 든다.
#
# 설계 메모(어기면 ADR-0061 결정 3 위반):
#   - **순수 static·데이터 주도**(crop_catalog·fruit_tree_catalog·animal_catalog와 같은 결). 씬 노드가
#     아니고 세이브 상태도 아니라 헤드리스에서 FishCatalog.roll_fish(...)로 바로 굴러간다.
#   - **FishingSession을 모른다 / FishingSession도 이걸 모른다**(양방향 디커플링). 접점은 dict 하나 —
#     session_params(id)가 `CLASS_PRESETS` 위에 종별 오버라이드를 얹은 dict를 만들고, main이 그걸
#     FishingSession 생성자에 넘긴다(fishing.gd 주석 "같은 스키마 dict를 넘길 뿐 이 파일은 안 바뀐다" 이행).
#   - **절기 잠금 = 오늘 실효**(결정 3): `GameClock.season_index_for_day`(28일·4절기)가 이미 있어 신규
#     시스템 0으로 굴러간다. seasons가 빈 배열이면 전 절기(상시종), phases가 빈 배열이면 전 시간대.
#   - **날씨 태그는 스키마만**(결정 3 — 날씨 시스템 = Slice 7). `weather`는 지금 아무도 평가하지 않는다.
#     ★[S7 점등] 혼우 입질↑·잿눈 둔화가 붙을 자리다(빈 배열 = 전 날씨).
#   - **전설 2종은 일반 롤에서 빠진다**(결정 3 "선택 프레스티지 미니보스"·ADR-0030). roll_fish는 전설을
#     절대 반환하지 않고, roll_legendary만 극저확률(LEGEND_CHANCE)로 물린다. 체급 게이트(T4 낚싯대)가
#     "걸어도 못 잡는다"를 자연 처리하므로 별도 서사 게이팅은 0이다.
#   - **결정성**: 모든 롤은 *주입된* RandomNumberGenerator만 쓴다(전역 randf 금지 — 헤드리스 재현의 전제).
#   - **품질 = 퍼펙트 릴**(카탈로그 §1-D "품질 = 퍼펙트 릴 + 퀄리티 보버" 이행). FishingSession은 등급을
#     모르고 perfect_count만 넘긴다 — 등급 매핑은 여기(quality_for)가 한다. 퀄리티 보버(태클, S3-T4)는
#     bobber_bonus 인자로 들어올 자리를 열어 뒀다(기본 0.0 = 정확히 중립).
#
# 명명 결(CONTEXT [삼도천] "망자의 혼·도깨비 물고기" · [황천해]): 지상 어종 이름을 날것으로 쓰지 않고
#   저승 수식어를 붙여 합성한다(넋·잿빛·도깨비·상엿길·초롱·혼불·삿갓·만장). "저승/명계"를 직접 노출하지
#   않는 건 기존 아이템 명명(혼령초·피안화·업화석)과 같은 절제다. ★owner 큐(잠정 명명 — ADR-0061 결정 3).

# ── 서식지(무대, ADR-0061 결정 9) ────────────────────────────────────────────
# 캐스팅 무대는 삼도천 강·황천해 바다 둘뿐이다(갱도 호수 = Slice 5·나락 = 후속).
const HABITAT_RIVER := "river"   # 삼도천 강
const HABITAT_SEA := "sea"       # 황천해 바다

# ── 체급(FishingSession.WeightClass와 같은 눈금 0~3) ─────────────────────────
# 여기 정수를 그대로 FishingSession에 넘긴다(enum 상호참조 대신 눈금 공유 — 순환 의존 0).
const WC_SMALL := 0
const WC_MEDIUM := 1
const WC_LARGE := 2
const WC_LEGEND := 3

# ── 시간대(GameClock.phase() 반환 문자열과 같은 눈금) ────────────────────────
const PHASE_MORNING := "아침"
const PHASE_DAY := "낮"
const PHASE_EVENING := "저녁"
const PHASE_NIGHT := "밤"

# ── 어종 id(코드·세이브용 안정 id — 아이템 id로도 그대로 쓰인다) ──────────────
# 삼도천 강 8종
const NEOK_BUNGEO := "neok_bungeo"                 # 넋붕어 — 상시종(강의 바닥 물량)
const JAETBIT_SONGSARI := "jaetbit_songsari"       # 잿빛송사리
const YEOUL_PIRAMI := "yeoul_pirami"               # 여울넋피라미
const CHORONG_CHI := "chorong_chi"                 # 초롱치 — 밤 전용
const SANGYEOTGIL_INGEO := "sangyeotgil_ingeo"     # 상엿길잉어
const DOKKAEBI_MEGI := "dokkaebi_megi"             # 도깨비메기
const ANGAE_SSOGARI := "angae_ssogari"             # 안개무늬쏘가리
const MEOKBIT_JANGEO := "meokbit_jangeo"           # 먹빛장어 — 강 대어
# 황천해 바다 8종
const NEOK_MYEOLCHI := "neok_myeolchi"             # 넋멸치 — 상시종(바다의 바닥 물량)
const EUNBINEUL_CHEONGEO := "eunbineul_cheongeo"   # 은비늘청어
const MULMARU_GAJAMI := "mulmaru_gajami"           # 물마루가자미
const HONBUL_HAEPARI := "honbul_haepari"           # 혼불해파리 — 밤 전용
const JEONYEOKNOL_DOMI := "jeonyeoknol_domi"       # 저녁놀도미
const SATGAT_OJINGEO := "satgat_ojingeo"           # 삿갓오징어
const MULBINEUL_NONGEO := "mulbineul_nongeo"       # 물비늘농어
const NEOUL_BEOMCHI := "neoul_beomchi"             # 너울범치 — 바다 대어
# 전설 2종(강 1·바다 1 — 일반 롤 제외)
const GEOMEUNYEOUL_DAEMEGI := "geomeunyeoul_daemegi"  # 검은여울 대메기(강 전설)
const SIMYEON_MANJANGEO := "simyeon_manjangeo"        # 심연 만장어(바다 전설)

# ── 로스터(18종) ────────────────────────────────────────────────────────────
# 스키마(ADR-0061 결정 3):
#   name_ko      : 표시명(인벤·토스트·출하 정산)
#   habitat      : HABITAT_RIVER / HABITAT_SEA
#   weight_class : 0~3(소·중·대·전설) — 릴 격투 강도 + 낚싯대 줄 게이트의 축
#   seasons      : 절기 인덱스 배열(0 피안·1 유화·2 망연·3 성야). **빈 배열 = 전 절기(상시종)**
#   phases       : 시간대 문자열 배열. **빈 배열 = 전 시간대**
#   weather      : ★[S7 점등] 날씨 태그(빈 배열 = 전 날씨). 지금은 아무도 평가하지 않는다
#   price        : 기준 판매가(일반 등급). 품질 배수는 ItemCatalog.price_of가 얹는다
#   fight        : CLASS_PRESETS 위 종별 오버라이드(소량 — 같은 체급 안에서 손맛을 가른다)
#
# 밸런스 의도:
#   ① 각 서식지·각 절기에 **최소 3종**(잠금이 사막을 만들지 않게 — 상시종 2종이 바닥을 깐다).
#   ② 체급 = 소 8 · 중 6 · 대 2 · 전설 2(소~중 위주 — T1 낚싯대만 있는 초반에 루프가 돌아야 한다).
#   ③ 시간 잠금은 소수만(밤 전용 2종 = 초롱치·혼불해파리 + 반나절 잠금 6종). 나머지는 종일 가용.
const FISH := {
	# ── 삼도천 강(8) ───────────────────────────────────────────────────────
	NEOK_BUNGEO: {
		"name_ko": "넋붕어", "habitat": HABITAT_RIVER, "weight_class": WC_SMALL,
		"seasons": [], "phases": [], "weather": [], "price": 32,
		"fight": {},   # 기준 소 체급 그대로 — 이 종이 "표준 손맛"의 원점이다
	},
	JAETBIT_SONGSARI: {
		"name_ko": "잿빛송사리", "habitat": HABITAT_RIVER, "weight_class": WC_SMALL,
		"seasons": [2, 3], "phases": [], "weather": [], "price": 36,
		"fight": {"stamina": 20.0, "distance": 26.0},   # 더 작고 빨리 끝난다(추위철 잔챙이)
	},
	YEOUL_PIRAMI: {
		"name_ko": "여울넋피라미", "habitat": HABITAT_RIVER, "weight_class": WC_SMALL,
		"seasons": [0, 1], "phases": [PHASE_MORNING, PHASE_DAY], "weather": [], "price": 44,
		"fight": {"burst_period": 2.4, "tension_rise": 23.0},   # 잔발버둥이 잦다(여울 물살)
	},
	CHORONG_CHI: {
		"name_ko": "초롱치", "habitat": HABITAT_RIVER, "weight_class": WC_SMALL,
		"seasons": [], "phases": [PHASE_NIGHT], "weather": [], "price": 52,
		"fight": {"slack_rate": 4.5},   # 등불처럼 흔들리며 거리를 잘 되찾는다
	},
	SANGYEOTGIL_INGEO: {
		"name_ko": "상엿길잉어", "habitat": HABITAT_RIVER, "weight_class": WC_MEDIUM,
		"seasons": [0, 2], "phases": [], "weather": [], "price": 78,
		"fight": {"stamina": 46.0, "burst_period": 3.1},   # 느리고 묵직(상여 행렬의 걸음)
	},
	DOKKAEBI_MEGI: {
		"name_ko": "도깨비메기", "habitat": HABITAT_RIVER, "weight_class": WC_MEDIUM,
		"seasons": [1, 3], "phases": [PHASE_EVENING, PHASE_NIGHT], "weather": [], "price": 96,
		"fight": {"burst_mult": 3.1, "burst_period": 2.3},   # 심술궂은 발버둥(도깨비 결)
	},
	ANGAE_SSOGARI: {
		"name_ko": "안개무늬쏘가리", "habitat": HABITAT_RIVER, "weight_class": WC_MEDIUM,
		"seasons": [2, 3], "phases": [PHASE_DAY, PHASE_EVENING], "weather": [], "price": 112,
		"fight": {"tension_rise": 38.0, "stamina": 48.0},
	},
	MEOKBIT_JANGEO: {
		"name_ko": "먹빛장어", "habitat": HABITAT_RIVER, "weight_class": WC_LARGE,
		"seasons": [1, 2], "phases": [PHASE_EVENING, PHASE_NIGHT], "weather": [], "price": 190,
		"fight": {"slack_rate": 5.5, "burst_len": 1.5},   # 미끄덩 — 풀면 쑥쑥 달아난다
	},
	# ── 황천해 바다(8) ─────────────────────────────────────────────────────
	NEOK_MYEOLCHI: {
		"name_ko": "넋멸치", "habitat": HABITAT_SEA, "weight_class": WC_SMALL,
		"seasons": [], "phases": [], "weather": [], "price": 30,
		"fight": {"stamina": 21.0},   # 바다의 바닥 물량 — 가장 가볍다
	},
	EUNBINEUL_CHEONGEO: {
		"name_ko": "은비늘청어", "habitat": HABITAT_SEA, "weight_class": WC_SMALL,
		"seasons": [0, 3], "phases": [], "weather": [], "price": 40,
		"fight": {"pull_rate": 9.0},
	},
	MULMARU_GAJAMI: {
		"name_ko": "물마루가자미", "habitat": HABITAT_SEA, "weight_class": WC_SMALL,
		"seasons": [0, 1], "phases": [PHASE_MORNING, PHASE_DAY], "weather": [], "price": 48,
		"fight": {"stamina": 27.0, "tension_rise": 22.0},   # 바닥에 납작 붙어 버틴다
	},
	HONBUL_HAEPARI: {
		"name_ko": "혼불해파리", "habitat": HABITAT_SEA, "weight_class": WC_SMALL,
		"seasons": [], "phases": [PHASE_NIGHT], "weather": [], "price": 55,
		"fight": {"tension_fall": 34.0, "burst_period": 3.8},   # 물결처럼 순하다(밤바다 등불)
	},
	JEONYEOKNOL_DOMI: {
		"name_ko": "저녁놀도미", "habitat": HABITAT_SEA, "weight_class": WC_MEDIUM,
		"seasons": [0, 2], "phases": [PHASE_EVENING, PHASE_NIGHT], "weather": [], "price": 88,
		"fight": {"stamina": 40.0, "pull_rate": 8.5},
	},
	SATGAT_OJINGEO: {
		"name_ko": "삿갓오징어", "habitat": HABITAT_SEA, "weight_class": WC_MEDIUM,
		"seasons": [2, 3], "phases": [PHASE_NIGHT], "weather": [], "price": 104,
		"fight": {"slack_rate": 4.8, "burst_len": 1.3},   # 먹물 뿌리듯 물러난다
	},
	MULBINEUL_NONGEO: {
		"name_ko": "물비늘농어", "habitat": HABITAT_SEA, "weight_class": WC_MEDIUM,
		"seasons": [1, 2], "phases": [], "weather": [], "price": 120,
		"fight": {"stamina": 47.0, "tension_rise": 38.0},
	},
	NEOUL_BEOMCHI: {
		"name_ko": "너울범치", "habitat": HABITAT_SEA, "weight_class": WC_LARGE,
		"seasons": [0, 1], "phases": [PHASE_DAY, PHASE_EVENING], "weather": [], "price": 230,
		"fight": {"stamina": 76.0, "burst_mult": 3.4},   # 너울처럼 크게 한 번씩 쳐올린다
	},
	# ── 전설 2(강 1·바다 1 — 일반 롤 제외·roll_legendary 전용) ──────────────
	GEOMEUNYEOUL_DAEMEGI: {
		"name_ko": "검은여울 대메기", "habitat": HABITAT_RIVER, "weight_class": WC_LEGEND,
		"seasons": [2], "phases": [], "weather": [], "price": 720,
		"fight": {"stamina": 118.0, "burst_period": 1.9},   # 망연절 강의 주인
	},
	SIMYEON_MANJANGEO: {
		"name_ko": "심연 만장어", "habitat": HABITAT_SEA, "weight_class": WC_LEGEND,
		"seasons": [1], "phases": [], "weather": [], "price": 860,
		"fight": {"stamina": 124.0, "slack_rate": 6.0},   # 유화절 바다의 조등(弔燈)
	},
}

# ── 롤 가중(체급 파생, ADR-0061 결정 3) ──────────────────────────────────────
# S3-T2 임시 분포(소 80 / 중 15 / 대 4 / 전설 1)의 *체감*을 잇는다. 다만 여기선 **체급 단위 몫**을 고정하고
# 그 몫을 그 체급의 가용 종끼리 균등 분배한다 — 로스터가 늘어도 "소가 대부분"이 흔들리지 않는다(전설은
# 일반 롤에서 몫 0이고, 대신 roll_legendary가 LEGEND_CHANCE로 따로 물린다).
const CLASS_WEIGHT := [80.0, 15.0, 5.0, 0.0]

# ★[S3-T4 / ADR-0061 결정 4] 유인 미끼의 체급 가중 시프트.
# 읽는 법: shift = 1.0이면 각 체급이 **한 계단 아래 체급의 몫을 물려받는다**(중 15→80 · 대 5→15 ·
#   소는 자기 몫 유지). 0.0이면 정확히 중립(CLASS_WEIGHT 그대로 — 무보정 호출과 수치 동일).
#   0~1 사이는 그 사이를 선형 보간한다(미끼 세기 조절 여지). 전설 몫은 **항상 0**으로 못 박는다 —
#   시프트로 전설이 일반 롤에 새면 결정 3("전설은 roll_legendary 전용")이 깨진다.
static func class_weights(shift: float) -> Array:
	var s := clampf(shift, 0.0, 1.0)
	if s <= 0.0:
		return CLASS_WEIGHT.duplicate()
	var out: Array = []
	for c in CLASS_WEIGHT.size():
		var up: float = CLASS_WEIGHT[maxi(c - 1, 0)]   # 한 계단 아래 체급의 몫(= 위로 밀린 가중)
		out.append(lerpf(float(CLASS_WEIGHT[c]), up, s))
	out[WC_LEGEND] = 0.0
	return out
# 전설 입질 확률(가용 조건 충족 시). 1% 미만 = "평생 몇 번 보는 사건"(ADR-0061 결정 3 극저확률 특수 입질).
const LEGEND_CHANCE := 0.008

# ── 품질 매핑(퍼펙트 릴 → 등급, 카탈로그 §1-D "품질 = 퍼펙트 릴 + 퀄리티 보버") ──
# 행 = 퍼펙트 릴 횟수(0 / 1 / 2 / 3+), 열 = 등급 확률[일반, 은, 금, 이리듐] 각 행 합 = 100.
# 읽는 법은 FertilizerCatalog.QUALITY_TABLE과 같다(누적 컷 — roll 0..99가 위에서부터 걸린다).
# 계단 의도: 0회 = 일반 위주(88%) · 1회부터 은이 주력 · 2회에 금 급증 · 3회 이상에서만 이리듐이 열린다
#   (작물의 디럭스 비료 자리 = 낚시에선 "퍼펙트를 세 번 딴 격투" — 스킬이 품질을 만든다).
const QUALITY_TABLE := [
	[88, 10, 2, 0],
	[55, 33, 12, 0],
	[25, 40, 30, 5],
	[8, 32, 45, 15],
]

# ── 조회 ────────────────────────────────────────────────────────────────────
static func has(id: String) -> bool:
	return FISH.has(id)

static func ids() -> Array:
	return FISH.keys()

static func name_of(id: String) -> String:
	return String(FISH[id]["name_ko"]) if FISH.has(id) else ""

static func habitat_of(id: String) -> String:
	return String(FISH[id]["habitat"]) if FISH.has(id) else ""

static func weight_class_of(id: String) -> int:
	return int(FISH[id]["weight_class"]) if FISH.has(id) else WC_SMALL

static func price_of(id: String) -> int:
	return int(FISH[id]["price"]) if FISH.has(id) else 0

static func is_legendary(id: String) -> bool:
	return FISH.has(id) and int(FISH[id]["weight_class"]) == WC_LEGEND

# 절기 인덱스 → 표시명(GameClock에 위임 — 절기 이름의 단일 출처는 시계다).
static func season_name(idx: int) -> String:
	return GameClock.season_name(idx)

# ── 가용 판정(절기·시간 잠금) ────────────────────────────────────────────────
# 이 어종이 지금 이 무대·절기·시각에 물릴 수 있나. seasons/phases가 빈 배열이면 그 축은 무제한이다.
# ★ 날씨는 평가하지 않는다(★[S7 점등] — 결정 3 "날씨 태그는 스키마만").
static func is_available(id: String, habitat: String, season_idx: int, phase: String) -> bool:
	if not FISH.has(id):
		return false
	var f: Dictionary = FISH[id]
	if String(f["habitat"]) != habitat:
		return false
	var seasons: Array = f["seasons"]
	if not seasons.is_empty() and not seasons.has(season_idx):
		return false
	var phases: Array = f["phases"]
	if not phases.is_empty() and not phases.has(phase):
		return false
	return true

# 지금 물릴 수 있는 어종 id 목록. include_legendary=false(기본)면 전설은 빠진다 — 일반 입질 풀이다.
# 반환 순서는 FISH 선언 순(결정적 — 가중 추첨의 재현성이 여기서 나온다).
static func available_ids(habitat: String, season_idx: int, phase: String,
		include_legendary := false) -> Array:
	var out: Array = []
	for id in FISH:
		if is_legendary(id) and not include_legendary:
			continue
		if is_available(id, habitat, season_idx, phase):
			out.append(id)
	return out

# 이 무대·절기에 (시간 무관) 가용한 비-전설 종 수 — 로스터 밀도 자가검증용(테스트·밸런스 점검).
static func season_roster(habitat: String, season_idx: int) -> Array:
	var out: Array = []
	for id in FISH:
		if is_legendary(id):
			continue
		var f: Dictionary = FISH[id]
		if String(f["habitat"]) != habitat:
			continue
		var seasons: Array = f["seasons"]
		if seasons.is_empty() or seasons.has(season_idx):
			out.append(id)
	return out

# ── 입질 롤(★ 이 파일의 주 API) ──────────────────────────────────────────────
# 가용 필터(무대·절기·시간) 후 체급 가중 추첨. **전설은 절대 안 나온다**(결정 3) — 전설은 roll_legendary
# 전용이다. 가용 종이 하나도 없으면 ""(호출 측이 방어 폴백을 고른다 — 로스터 밀도상 실제로는 안 난다).
# rng는 *주입만* 쓴다(결정성 = 헤드리스 게이트의 전제 — 전역 randf 금지).
#
# ★[S3-T4] 미끼 보정 2개(둘 다 기본값이 정확히 중립 — 무인자 호출의 결과열은 한 톨도 안 변한다):
#   class_shift   : 유인 미끼의 체급 가중 상향(0.0 = 중립 · 1.0 = 한 계단. class_weights 참조).
#   guarantee_cap : 보장 미끼(−1 = 없음). 0 이상이면 **가용 종 중 체급 ≤ cap인 것들의 최고 체급**에서
#                   균등 추첨한다(= "이 낚싯대로 잡을 수 있는 가장 큰 놈" 확정). cap = 낚싯대 허용
#                   체급이라 보장 미끼가 확정 끊김 함정이 되지 않는다(GearCatalog.guarantee_cap_for).
static func roll_fish(habitat: String, season_idx: int, phase: String,
		rng: RandomNumberGenerator, class_shift: float = 0.0, guarantee_cap: int = -1) -> String:
	var pool := available_ids(habitat, season_idx, phase)
	if pool.is_empty():
		return ""
	# ★ 보장 미끼 — 가중 추첨을 건너뛰고 "cap 이하 최고 체급" 안에서 균등 추첨한다(확정의 의미 보존).
	if guarantee_cap >= 0:
		var top := -1
		for id in pool:
			var wc_g := weight_class_of(id)
			if wc_g <= guarantee_cap and wc_g > top:
				top = wc_g
		if top >= 0:
			var best: Array = []
			for id in pool:
				if weight_class_of(id) == top:
					best.append(id)
			return String(best[rng.randi() % best.size()])
		# cap 이하가 하나도 없다는 건 로스터상 있을 수 없다(상시종 = 소 체급) — 일반 롤로 떨어진다.
	# 체급별 가용 수 → 종당 가중 = 그 체급의 몫 / 그 체급의 가용 종 수(체급 몫 고정·종끼리 균등).
	var cw := class_weights(class_shift)
	var per_class := [0, 0, 0, 0]
	for id in pool:
		per_class[weight_class_of(id)] += 1
	var weights: Array = []
	var total := 0.0
	for id in pool:
		var wc := weight_class_of(id)
		var w: float = float(cw[wc]) / float(per_class[wc])
		weights.append(w)
		total += w
	if total <= 0.0:
		return String(pool[0])
	var r := rng.randf() * total
	var acc := 0.0
	for i in pool.size():
		acc += float(weights[i])
		if r < acc:
			return String(pool[i])
	return String(pool[pool.size() - 1])   # 부동소수 잔차 방어

# 전설 특수 입질. 이 무대·절기·시각에 전설이 가용하고 LEGEND_CHANCE에 걸리면 그 id를, 아니면 ""를 준다.
# main은 이걸 먼저 굴리고 ""면 roll_fish로 떨어진다(전설 = 일반 풀 위에 얹힌 별개 사건).
# ★ 체급 게이트(FishingSession)가 "T4 낚싯대가 아니면 걸어도 끊긴다"를 자연 처리하므로 기어 게이팅은 0이다.
static func roll_legendary(habitat: String, season_idx: int, phase: String,
		rng: RandomNumberGenerator) -> String:
	var pool: Array = []
	for id in FISH:
		if is_legendary(id) and is_available(id, habitat, season_idx, phase):
			pool.append(id)
	if pool.is_empty():
		return ""
	if rng.randf() >= LEGEND_CHANCE:
		return ""
	return String(pool[rng.randi() % pool.size()])

# 무대별 최후 폴백(가용 종 0이라는 있어선 안 될 상태의 방어 — 상시종을 준다).
static func fallback_id(habitat: String) -> String:
	return NEOK_MYEOLCHI if habitat == HABITAT_SEA else NEOK_BUNGEO

# ── FishingSession 접속(dict 하나가 유일한 접점) ─────────────────────────────
# 어종 id → FishingSession 생성자에 넘길 fish_params. 체급만 넘겨도 CLASS_PRESETS가 채워지고,
# 여기에 종별 fight 오버라이드가 얹힌다. id를 실어 보내면 result()["fish_id"]로 되돌아온다(포획 지급의 축).
static func session_params(id: String) -> Dictionary:
	if not FISH.has(id):
		return {"weight_class": WC_SMALL}
	var out: Dictionary = {"id": id, "weight_class": int(FISH[id]["weight_class"])}
	for k in FISH[id]["fight"]:
		out[k] = FISH[id]["fight"][k]
	return out

# ── 품질(퍼펙트 릴 → 등급) ───────────────────────────────────────────────────
# 퍼펙트 릴 횟수 → 확률행 인덱스(0..3, 3+는 마지막 행으로 포화).
static func quality_row(perfect_count: int) -> Array:
	return QUALITY_TABLE[clampi(perfect_count, 0, QUALITY_TABLE.size() - 1)]

# ★ 결정적 등급 판정(roll 0..99). 경계 검증·재현이 필요한 곳은 이 순수 함수를 쓴다
#   (FertilizerCatalog.tier_for_roll 선례 — 확률과 판정을 분리해야 테스트가 이빨을 갖는다).
static func quality_for_roll(perfect_count: int, roll: int) -> int:
	var row := quality_row(perfect_count)
	var r := clampi(roll, 0, 99)
	var acc := 0
	for tier in row.size():
		acc += int(row[tier])
		if r < acc:
			return tier
	return row.size() - 1

# ★ 퍼펙트 릴 → 품질 등급(ItemCatalog.Q_NORMAL..Q_IRIDIUM). rng는 주입만 쓴다(결정성).
#   bobber_bonus = 퀄리티 보버 태클 보정(0.0 = 정확히 중립 · ★S3-T4가 0.15로 채웠다). 0~1 비율이며
#   roll을 그만큼 위로 밀어 상위 등급 쪽으로 기운다(확률행은 그대로 두고 판정 축만 옮긴다 = 표 중복 0).
#   ★ 세기 주의: roll이 99에서 클램프되므로 큰 보정(≥0.4)은 최상위 등급에 확률이 뭉친다(0.5 = 퍼펙트
#     0회에도 금 52%). "품질 = 퍼펙트 릴"(§1-D) 축을 지키려면 보정은 계단 반 칸 수준으로 —
#     GearCatalog.TACKLES 주석의 잠정 0.15가 그 근거다.
static func quality_for(perfect_count: int, rng: RandomNumberGenerator,
		bobber_bonus: float = 0.0) -> int:
	var roll := rng.randi_range(0, 99) + int(round(clampf(bobber_bonus, 0.0, 1.0) * 100.0))
	return quality_for_roll(perfect_count, roll)
