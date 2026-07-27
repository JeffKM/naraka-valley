extends RefCounted
class_name GearCatalog
# ★[S3-T4 / ADR-0061 결정 4] 낚시 기어 로스터 — 낚싯대 4티어 + 미끼 3종 + 태클 3종.
#
# 목적: "무엇을 들고 낚는가"(줄 강도·슬롯·미끼/태클 효과·가격)를 한 곳에 든다. FishCatalog가
#       "무엇이 낚이는가"를, FishingSession이 "격투가 어떻게 굴러가나"를 들듯, GearCatalog는
#       **"플레이어의 장비가 그 둘에 무엇을 주입하는가"**만 든다.
#
# 설계 메모(어기면 ADR-0061 결정 4 위반):
#   - **순수 static·데이터 주도**(fish_catalog·fertilizer_catalog·animal_catalog와 같은 결). 씬 노드도
#     세이브 상태도 아니라 헤드리스에서 GearCatalog.rod_params(...)로 바로 굴러간다.
#   - **FishingSession·FishCatalog를 모른다 / 그 둘도 이걸 모른다**(삼각 디커플링). 접점은 dict·스칼라뿐 —
#     rod_params()가 FishingSession 생성자의 rod 인자를, mods_for()가 mods 인자를, class_shift/
#     guarantee_cap/bobber_bonus가 FishCatalog 인자를 만든다. main이 그 넷을 배선한다.
#   - **아이템 정의의 단일 출처**(ItemCatalog 위임 관례 — FertilizerCatalog·FishCatalog 선례). 이름·가격·
#     색·스택 여부는 여기가 들고, ItemCatalog는 판정·표시만 빌려 간다(데이터 중복 0).
#   - **장착 UI 없음(그레이박스 단순화)**: 미끼는 인벤 보유분에서 캐스팅 시 자동 소모되고, 태클은 보유분
#     중 슬롯 수만큼 자동 적용된다. ★[owner 큐: 슬롯 "장전" UI(미끼 장전·태클 슬롯 드래그)는 아트/UX
#     패스에서 재검토 — 그때 아래 자동 우선순위(_BAIT_ORDER·_TACKLE_ORDER)는 폐기 대상이다].
#   - **획득 경로는 여기 없다**: 매대 판매·T1 증정은 S3-T5(뱃사공) 소관이다. 지금 T2~T4·미끼·태클을
#     손에 넣는 길은 디버그 지급(테스트 inventory.add_item)뿐이고, 가격은 매대가 읽을 값으로 미리 잠근다.
#   - 수치는 전부 **그레이박스 잠정값**(ADR-0028 스펙카드 잠금 대상)이며 근거를 주석에 남긴다.

# ── 체급 눈금(FishingSession.WeightClass · FishCatalog.WC_* 와 같은 0~3) ──────
# 정수 눈금만 공유한다(enum 상호참조 대신 — 순환 의존 0, fish_catalog.gd 선례 동형).
const WC_SMALL := 0
const WC_MEDIUM := 1
const WC_LARGE := 2
const WC_LEGEND := 3

# ── 아이템 id(코드·세이브용 안정 id — ItemCatalog가 그대로 재수출) ────────────
const ROD_T1 := "rod_t1"                 # 낡은 낚싯대(T1 — 증정품)
const ROD_T2 := "rod_t2"                 # 삼줄 낚싯대(T2)
const ROD_T3 := "rod_t3"                 # 놋쇠 낚싯대(T3)
const ROD_T4 := "rod_t4"                 # 만장 낚싯대(T4 — 프레스티지)
const BAIT_BASIC := "bait_basic"         # 일반 미끼
const BAIT_LURE := "bait_lure"           # 유인 미끼
const BAIT_PLEDGE := "bait_pledge"       # 보장 미끼
const TACKLE_CORK := "tackle_cork"       # 코르크 보버
const TACKLE_SINKER := "tackle_sinker"   # 납추
const TACKLE_QUALITY := "tackle_quality" # 퀄리티 보버

# ── 낚싯대 4티어(ADR-0061 결정 4) ────────────────────────────────────────────
# 스키마:
#   name_ko      : 표시명(저승 결 — 삼줄=상엿줄 삼, 놋쇠=제기 놋, 만장=상여 만장기. ★owner 큐 잠정 명명)
#   tier         : 1~4(표시·정렬용)
#   max_class    : **줄 강도** = 허용 체급 상한(0/1/2/3). 초과 어종을 걸면 확정 끊김(FishingSession
#                  체급 게이트). 이 한 축이 4티어의 존재 이유다 — "약한 줄로 큰 놈 걸면 끊긴다"(ADR-0030).
#   bait_slots   : 미끼 슬롯 수(0/1). 0이면 미끼를 물려도 **소모되지 않고 효과도 0**(T1 = 맨몸 티어).
#   tackle_slots : 태클 슬롯 수(0/0/1/2). 보유 태클 중 이 수만큼만 적용된다(초과분 무효).
#   price        : 생선가게 매입가(결). T1 = 0(뱃사공 증정 — S3-T5).
#   color        : 그레이박스 아이콘 색(아이콘 아트는 S3-T10 — tool_color_of 폴백이 읽는다)
# 밸런스 의도: 체급 게이트가 4티어의 유일한 *필수* 축이고 슬롯은 그 위의 선택 폭이다. 그래서 T2는
#   "중 체급 + 미끼", T3은 "대 체급 + 태클 1", T4는 "전설 + 태클 2"로 한 티어에 한 가지씩만 늘린다
#   (같은 +%의 반복 금지 — ADR-0008 결). 가격 밴드 500/2,000/7,500은 스타듀 낚싯대 곡선(×4 계단)의
#   결을 따른 **잠정값**이고, 실 획득 속도는 S3-T5 매대·어가와 함께 조율한다.
const RODS := {
	ROD_T1: {
		"name_ko": "낡은 낚싯대", "tier": 1, "max_class": WC_SMALL,
		"bait_slots": 0, "tackle_slots": 0, "price": 0,
		"color": Color(0.45, 0.62, 0.66),   # 바랜 대나무 + 물빛 줄
	},
	ROD_T2: {
		"name_ko": "삼줄 낚싯대", "tier": 2, "max_class": WC_MEDIUM,
		"bait_slots": 1, "tackle_slots": 0, "price": 500,
		"color": Color(0.66, 0.58, 0.38),   # 삼(麻) 꼬임 줄
	},
	ROD_T3: {
		"name_ko": "놋쇠 낚싯대", "tier": 3, "max_class": WC_LARGE,
		"bait_slots": 1, "tackle_slots": 1, "price": 2000,
		"color": Color(0.78, 0.66, 0.32),   # 놋빛 이음쇠
	},
	ROD_T4: {
		"name_ko": "만장 낚싯대", "tier": 4, "max_class": WC_LEGEND,
		"bait_slots": 1, "tackle_slots": 2, "price": 7500,
		"color": Color(0.72, 0.42, 0.52),   # 만장기 붉은 천
	},
}

# ── 미끼 3종(소모품 · 입질 페이즈, ADR-0061 결정 4) ───────────────────────────
# 스키마:
#   wait_factor    : 입질 대기 배수(1.0 = 중립). FishingSession.mods로 주입 — cast()의 대기 시간에 곱해진다.
#   class_shift    : 체급 가중 상향 시프트(0.0 = 중립 · 1.0 = 한 계단). FishCatalog.roll_fish 인자.
#   guarantee_top  : true면 **가용 종 중 최고 체급 확정**(낚싯대 허용 체급으로 상한을 씌운다 — 아래 주석).
#   price          : 생선가게 매입가(결·1개). 소모품이라 스택된다.
# 밸런스 의도: 세 미끼가 서로 다른 *축*을 건드린다(시간 / 분포 / 확정) — 같은 "+%"의 반복 회피.
#   ① 일반 −40% 대기 = 시간당 캐스팅 수↑(가장 싸고 가장 자주 쓰는 소모품)
#   ② 유인 = 체급 분포를 한 계단 위로(중·대 빈도↑ — 값나가는 놈을 노릴 때)
#   ③ 보장 = 지금 이 물가에서 잡을 수 있는 **가장 큰 놈** 확정(의뢰·마지막 한 종을 노릴 때. "보장" 결이지
#      *어종* 각본 포획은 아니다 — 각본 포획 훅은 ADR-0030대로 별개 서랍이다).
# ★ 보장 미끼의 상한: "현 조건 가용 종 중 최고 체급"을 **낚싯대 허용 체급으로 캡**한다. 캡이 없으면
#   T2로 보장 미끼를 쓰는 순간 대어가 확정 → 확정 끊김 + 혼력만 날리는 함정 아이템이 된다(비싼 소모품이
#   손해를 확정하는 설계는 기각). ★owner 큐: 캡 없는 "도박형 보장"을 원하면 이 한 줄만 뒤집으면 된다.
const BAITS := {
	BAIT_BASIC: {
		"name_ko": "일반 미끼", "price": 20,
		"wait_factor": 0.6, "class_shift": 0.0, "guarantee_top": false,
		"color": Color(0.52, 0.42, 0.30),   # 지렁이 흙빛
	},
	BAIT_LURE: {
		"name_ko": "유인 미끼", "price": 60,
		"wait_factor": 0.8, "class_shift": 1.0, "guarantee_top": false,
		"color": Color(0.72, 0.52, 0.26),   # 미끼 깃털 주황
	},
	BAIT_PLEDGE: {
		"name_ko": "보장 미끼", "price": 150,
		"wait_factor": 0.8, "class_shift": 0.0, "guarantee_top": true,
		"color": Color(0.58, 0.36, 0.62),   # 서약(誓) 자줏빛
	},
}

# ── 태클 3종(장착·비소모 · 격투 페이즈, ADR-0061 결정 4) ─────────────────────
# 스키마(전부 "0 = 정확히 중립" — 미장착과 수치적으로 동일):
#   tension_safe_bonus : 텐션 상승 감쇠 **비율**(FishingSession rod 인자). 0.15 = 당길 때 텐션 −15%.
#   burst_damp         : 발버둥 텐션 배수 감쇠(FishingSession mods). 0.35 = burst_mult에서 뺀다.
#   bobber_bonus       : 품질 판정 축 상향(FishCatalog.quality_for 인자). 등급 계단을 위로 민다.
#   price              : 생선가게 매입가(결). 비소모라 1개면 영구.
# ★ 수치 해석 메모(태스크 스펙 "코르크 +15"의 단위): FishingSession은 tension_safe_bonus를 *비율*로
#   먹는다(rise *= 1.0 - clampf(bonus, 0, 0.9)). 그래서 "+15"는 **15% = 0.15**로 잠근다(1.5를 넣으면
#   0.9로 클램프돼 텐션이 사실상 안 오르는 무적 태클이 된다).
# ★ 퀄리티 보버 0.15의 근거: quality_for는 bobber_bonus를 "roll(0~99)을 위로 미는 비율"로 먹는다
#   (S3-T3 계약 — 확률표는 그대로 두고 판정 축만 옮긴다). 스펙 표기 "+0.5 계단 시프트"를 그 계약에
#   그대로 넣으면 +50 roll이라 **퍼펙트 0회에도 금 등급 52%**가 나와 "품질 = 퍼펙트 릴"(카탈로그 §1-D)
#   축이 무너진다. 그래서 실값은 0.15(= +15 roll · 퍼펙트 0회 기준 금 2%→17%)로 잠근다 — 등급 계단
#   한 칸의 절반쯤 되는 체감. ★owner 큐: 정확한 세기(0.10~0.25)는 어가·의뢰와 함께 조율.
const TACKLES := {
	TACKLE_CORK: {
		"name_ko": "코르크 보버", "price": 800,
		"tension_safe_bonus": 0.15, "burst_damp": 0.0, "bobber_bonus": 0.0,
		"color": Color(0.86, 0.72, 0.46),   # 코르크 살구빛
	},
	TACKLE_SINKER: {
		"name_ko": "납추", "price": 800,
		"tension_safe_bonus": 0.0, "burst_damp": 0.35, "bobber_bonus": 0.0,
		"color": Color(0.48, 0.50, 0.55),   # 납 회색
	},
	TACKLE_QUALITY: {
		"name_ko": "퀄리티 보버", "price": 1200,
		"tension_safe_bonus": 0.0, "burst_damp": 0.0, "bobber_bonus": 0.15,
		"color": Color(0.85, 0.55, 0.30),   # 주황 찌
	},
}

# ── 자동 적용 우선순위(장착 UI 부재의 대가 — 전부 잠정) ───────────────────────
# ★ 미끼: **강한 것 먼저 소모**(보장 > 유인 > 일반). 근거: 장전 UI가 없어 플레이어가 "지금 이걸 쓰겠다"를
#   표현할 수단이 없다. 약한 것부터 태우면 비싼 미끼는 재고가 바닥날 때까지 영영 안 쓰이고(= 산 보람 0),
#   강한 것부터 태우면 적어도 "샀다 → 다음 캐스팅에 즉시 효과"라는 인과가 성립한다. 재고 관리는
#   "쓸 때만 산다"로 플레이어가 통제한다. ★owner 큐: 장전 UI가 붙으면 이 순서 자체가 폐기된다.
const _BAIT_ORDER := [BAIT_PLEDGE, BAIT_LURE, BAIT_BASIC]
# ★ 태클: **잃지 않는 것 먼저**(코르크 > 납추 > 퀄리티). 근거: 슬롯이 모자랄 때 남길 하나는 "포획 성공
#   자체"를 지키는 쪽이 낫다(끊김 = 혼력·시간 전손). 코르크(상시 텐션 감쇠) > 납추(발버둥 한정 완화) >
#   퀄리티(포획에 성공한 뒤의 보상 보정). ★owner 큐: 슬롯 드래그 UI가 붙으면 이 순서도 폐기.
const _TACKLE_ORDER := [TACKLE_CORK, TACKLE_SINKER, TACKLE_QUALITY]

# ── 판정·조회(ItemCatalog가 위임해 쓴다) ─────────────────────────────────────
static func is_rod(id: String) -> bool:
	return RODS.has(id)

static func is_bait(id: String) -> bool:
	return BAITS.has(id)

static func is_tackle(id: String) -> bool:
	return TACKLES.has(id)

# 낚시 기어(낚싯대·미끼·태클) 통칭 판정.
static func has(id: String) -> bool:
	return is_rod(id) or is_bait(id) or is_tackle(id)

static func name_of(id: String) -> String:
	if is_rod(id):
		return String(RODS[id]["name_ko"])
	if is_bait(id):
		return String(BAITS[id]["name_ko"])
	if is_tackle(id):
		return String(TACKLES[id]["name_ko"])
	return ""

# 매입가(결). ★ 파는 곳은 S3-T5 생선가게 매대 — 여기는 값의 단일 출처일 뿐이다.
static func price_of(id: String) -> int:
	if is_rod(id):
		return int(RODS[id]["price"])
	if is_bait(id):
		return int(BAITS[id]["price"])
	if is_tackle(id):
		return int(TACKLES[id]["price"])
	return 0

# 그레이박스 아이콘 색(아트 = S3-T10). 도구 색박스 폴백(tool_color_of)과 미끼 아이콘이 읽는다.
static func color_of(id: String) -> Color:
	if is_rod(id):
		return RODS[id]["color"]
	if is_bait(id):
		return BAITS[id]["color"]
	if is_tackle(id):
		return TACKLES[id]["color"]
	return Color.WHITE

# 스택 가능한가 — 미끼(소모품)만 true. 낚싯대·태클은 유니크 장착물(도구 결).
static func stackable_of(id: String) -> bool:
	return is_bait(id)

# 이 낚싯대의 줄 강도(허용 체급 상한). 미상 id는 T1로 방어(맨몸 티어).
static func max_class_of(rod_id: String) -> int:
	return int(RODS[rod_id]["max_class"]) if is_rod(rod_id) else WC_SMALL

static func bait_slots_of(rod_id: String) -> int:
	return int(RODS[rod_id]["bait_slots"]) if is_rod(rod_id) else 0

static func tackle_slots_of(rod_id: String) -> int:
	return int(RODS[rod_id]["tackle_slots"]) if is_rod(rod_id) else 0

static func tier_of(rod_id: String) -> int:
	return int(RODS[rod_id]["tier"]) if is_rod(rod_id) else 0

# ── 자동 적용 해석(장착 UI 자리를 메우는 순수 함수 — 인벤토리를 모른다) ───────
# 보유 태클 id 목록 → 실제 적용될 태클 목록(우선순위 상위 N개 · 슬롯 초과분 무효 · 중복/미상 제거).
# owned에 같은 종을 여러 개 넣어도 한 번만 센다("서로 다른 종만" — ADR-0061 결정 4).
static func active_tackles(rod_id: String, owned: Array) -> Array:
	var slots := tackle_slots_of(rod_id)
	var out: Array = []
	if slots <= 0:
		return out
	for id in _TACKLE_ORDER:
		if owned.has(id) and not out.has(id):
			out.append(id)
			if out.size() >= slots:
				break
	return out

# 보유 미끼 id 목록 → 이번 캐스팅에 소모할 미끼("" = 맨몸). 낚싯대에 미끼 슬롯이 없으면(T1) 항상 "".
static func active_bait(rod_id: String, owned: Array) -> String:
	if bait_slots_of(rod_id) <= 0:
		return ""
	for id in _BAIT_ORDER:
		if owned.has(id):
			return id
	return ""

# ── 주입 인터페이스(FishingSession·FishCatalog가 먹는 네 조각) ────────────────
# ① FishingSession 생성자 rod 인자 — {max_class, tension_safe_bonus}. 태클(코르크)이 안전 여유를 얹는다.
static func rod_params(rod_id: String, tackles: Array = []) -> Dictionary:
	var safe := 0.0
	for t in tackles:
		if is_tackle(t):
			safe += float(TACKLES[t]["tension_safe_bonus"])
	return {"max_class": max_class_of(rod_id), "tension_safe_bonus": safe}

# ② FishingSession 생성자 mods 인자 — 중립 기본값 위에 태클(납추)·미끼(대기 단축)를 얹는다.
#    extra는 호출 측(main)의 다른 훅(낚시 스킬 energy_factor·perfect_window_add 등)을 병합할 자리다.
static func mods_for(tackles: Array = [], bait_id: String = "", extra: Dictionary = {}) -> Dictionary:
	var out := {"energy_factor": 1.0, "perfect_window_add": 0.0, "burst_damp": 0.0, "wait_factor": 1.0}
	for k in extra:
		out[k] = extra[k]
	for t in tackles:
		if is_tackle(t):
			out["burst_damp"] = float(out["burst_damp"]) + float(TACKLES[t]["burst_damp"])
	if is_bait(bait_id):
		out["wait_factor"] = float(out["wait_factor"]) * float(BAITS[bait_id]["wait_factor"])
	return out

# ③ FishCatalog.quality_for 인자 — 퀄리티 보버 품질 보정(0.0 = 정확히 중립).
static func bobber_bonus_for(tackles: Array = []) -> float:
	var out := 0.0
	for t in tackles:
		if is_tackle(t):
			out += float(TACKLES[t]["bobber_bonus"])
	return out

# ④-a FishCatalog.roll_fish 인자 — 유인 미끼의 체급 가중 상향 시프트(0.0 = 중립).
static func class_shift_for(bait_id: String) -> float:
	return float(BAITS[bait_id]["class_shift"]) if is_bait(bait_id) else 0.0

# ④-b FishCatalog.roll_fish 인자 — 보장 미끼의 "최고 체급 확정" 상한(−1 = 보장 없음).
#     상한 = 낚싯대 허용 체급(위 BAITS 주석의 함정 방지 캡).
static func guarantee_cap_for(bait_id: String, rod_id: String) -> int:
	if not is_bait(bait_id) or not bool(BAITS[bait_id]["guarantee_top"]):
		return -1
	return max_class_of(rod_id)

# ── 표시(HUD 한 줄 — 장전 UI 부재의 임시 창구) ───────────────────────────────
# "미끼: 일반 미끼 ×3 · 태클: 코르크 보버+납추" 같은 한 줄. counts = {미끼 id → 잔량}.
# ★[owner 큐] 슬롯 장전 UI가 붙으면 이 문자열 대신 슬롯 위젯이 같은 정보를 든다.
static func status_line(rod_id: String, bait_id: String, tackles: Array, counts: Dictionary) -> String:
	var parts: Array = []
	if bait_slots_of(rod_id) > 0:
		if bait_id == "":
			parts.append("미끼 없음(맨몸)")
		else:
			parts.append("미끼 %s ×%d" % [name_of(bait_id), int(counts.get(bait_id, 0))])
	if tackle_slots_of(rod_id) > 0:
		var names: Array = []
		for t in tackles:
			names.append(name_of(t))
		parts.append("태클 %s" % ("없음" if names.is_empty() else "+".join(names)))
	return " · ".join(parts)
