extends RefCounted
class_name HomeDecoCatalog
# S1-9 — 집 꾸미기 테마 세트 정적 카탈로그. greybox-spec §11.3.
#
# 목적: ROADMAP S1-9 — 집 내부 3레이어(바닥재·벽지·가구) 코스메틱을 "테마 세트" 단위로 정의한다.
#       세트 1개 = 3레이어 전부를 가로질러 아이템을 공급(러그=FLOOR·벽장식=WALL·침대/탁자/화분/조명
#       =FURNITURE). 해금하면 그 세트 전체가 무한·무료 배치 팔레트(CONTEXT '집 꾸미기'). FertilizerCatalog/
#       AnimalCatalog/DebrisCatalog와 같은 결의 정적 참조 데이터(class_name, 세이브 상태 아님 — 배치·해금
#       델타는 HomeDeco 노드가 소유).
#
# 설계 메모(§11.2·§11.3):
#   - 아이템마다 `layer`(FLOOR/WALL/FURNITURE) 태그 → 세트가 3레이어를 가로지른다. 한 세트가 3레이어
#     전부에 ≥1 아이템(그 세트만 깔아도 완성된 룩). 표현 다양성은 세트 간 조합(혼불 가구 + 피안화 바닥).
#   - `is_solid`: 그레이박스는 전부 통과 가능(무충돌, §11.5)이나, 훗날 아트를 입혀 충돌을 켤 때
#     HomeDeco가 _rebuild_prop_collision 동형의 얇은 빌더로 읽을 **하류 훅**을 지금 심어 둔다(가구만 유의미).
#   - `color`: 그레이박스 placeholder 렌더 색(RGB 배열). 실제 세트 아트 = S1-11(아트 파트).
#   - 순수 코스메틱: 이 카탈로그·HomeDeco 어디에도 곱셈기·확률·XP·골드가 없다(버프0/게이트0, §11.6).

# ── 레이어 키(HomeDeco와 공유 — 아이템 layer 태그·배치 대상 dict) ──────────────
const L_FLOOR := "floor"        # 바닥재(러그 포함) — 룸 바닥 칸에 per-cell 칠
const L_WALL := "wall"          # 벽지(벽장식 포함) — 벽 밴드 칸에 per-cell 칠
const L_FURNITURE := "furniture"  # 가구(침대·탁자·화분·조명) — 배치 + 회전

# ── 테마 세트(§11.3) — 각 세트가 3레이어 전부에 ≥1 아이템 ────────────────────
# set_id → {name, price, items:{ item_key → {layer, is_solid, name, color} }}. key는 세트 안에서 고유.
#
# ★[S4-T7 / ADR-0062 결정 7 ㉡] `price` 신설 — [CONTEXT.md] [집 꾸미기] "입수 = 목공방 가구
#   카탈로그(골드)가 주"의 이행이다. **골드 단독**이고 제작 재료 게이트는 두지 않는다(CONTEXT
#   명시: "코스메틱을 노동에 묶으면 의무화"). price 0 = 비매(스타터 2세트 — 이미 무상 해금이라
#   매대에 값을 붙일 게 없다). 판매 세트는 목공방 매대에서만 산다(만물상 취급 0 — 서비스 분산).
#   ★ 가격은 잠정(owner 큐): 저승솔 3,000냥 / 잿눈 6,000냥 — 도구 티어(명동 2,000·유철 5,000)
#     밴드에 얹어 "쓸모 있는 도구 한 단계 ≈ 룩 한 벌"이 되게 잡았다(코스메틱이 필수 진척보다
#     비싸지도, 공짜로 쏟아지지도 않는 자리).
const SETS := {
	"SOULFIRE": {
		"name": "혼불", "price": 0,
		"items": {
			"sf_floor": {"layer": L_FLOOR,     "is_solid": false, "name": "혼불 바닥재", "color": [0.18, 0.32, 0.46]},
			"sf_wall":  {"layer": L_WALL,      "is_solid": false, "name": "혼불 벽지",   "color": [0.14, 0.24, 0.38]},
			"sf_bed":   {"layer": L_FURNITURE, "is_solid": true,  "name": "혼불 침대",   "color": [0.34, 0.54, 0.74]},
			"sf_lamp":  {"layer": L_FURNITURE, "is_solid": false, "name": "혼불 등불",   "color": [0.55, 0.74, 0.96]},
		},
	},
	"HIGANBANA": {
		"name": "피안화", "price": 0,
		"items": {
			"hb_floor": {"layer": L_FLOOR,     "is_solid": false, "name": "피안화 바닥재", "color": [0.40, 0.15, 0.16]},
			"hb_rug":   {"layer": L_FLOOR,     "is_solid": false, "name": "피안화 러그",   "color": [0.70, 0.24, 0.30]},
			"hb_wall":  {"layer": L_WALL,      "is_solid": false, "name": "피안화 벽지",   "color": [0.30, 0.10, 0.13]},
			"hb_table": {"layer": L_FURNITURE, "is_solid": true,  "name": "피안화 탁자",   "color": [0.62, 0.22, 0.24]},
		},
	},
	# ★[S4-T7] 목공방 판매 세트 ① 저승솔 — 옹이가 제 손으로 짠 **목재 결**. 이름은 신조어가 아니라
	#   [저승 삼목] 3종 중 하나([CONTEXT] 신설 용어)라 세계관 용어를 그대로 쓴다(용어 인플레 0).
	#   옹이의 정체성("베인 나무를 살림집으로 되살린다")이 룩으로 드러나는 첫 세트라 최저가로 둔다.
	"JEOSEUNGSOL": {
		"name": "저승솔", "price": 3000,
		"items": {
			"js_floor": {"layer": L_FLOOR,     "is_solid": false, "name": "저승솔 마루",   "color": [0.42, 0.31, 0.20]},
			"js_wall":  {"layer": L_WALL,      "is_solid": false, "name": "저승솔 판벽",   "color": [0.33, 0.24, 0.16]},
			"js_table": {"layer": L_FURNITURE, "is_solid": true,  "name": "저승솔 탁자",   "color": [0.55, 0.41, 0.26]},
			"js_shelf": {"layer": L_FURNITURE, "is_solid": true,  "name": "저승솔 책장",   "color": [0.47, 0.35, 0.22]},
		},
	},
	# ★[S4-T7] 목공방 판매 세트 ② 잿눈 — [CONTEXT] 저승 날씨의 성야절 눈. 차고 흰 룩이라 혼불(푸른)·
	#   피안화(붉은)·저승솔(갈색) 셋과 색면이 안 겹친다(세트 간 조합 다양성, §11.3). 상위가.
	"JAETNUN": {
		"name": "잿눈", "price": 6000,
		"items": {
			"jn_floor": {"layer": L_FLOOR,     "is_solid": false, "name": "잿눈 바닥재",   "color": [0.72, 0.73, 0.76]},
			"jn_wall":  {"layer": L_WALL,      "is_solid": false, "name": "잿눈 벽지",     "color": [0.58, 0.60, 0.65]},
			"jn_bed":   {"layer": L_FURNITURE, "is_solid": true,  "name": "잿눈 침대",     "color": [0.84, 0.86, 0.90]},
			"jn_lamp":  {"layer": L_FURNITURE, "is_solid": false, "name": "잿눈 등불",     "color": [0.90, 0.92, 0.97]},
		},
	},
}

# ── 신규 게임 스타터 세트(§11.4) — main이 START로 무상 해금(상점=Slice2 하류) ──────
const STARTER_SETS := ["SOULFIRE", "HIGANBANA"]

# 유효 레이어 키인가(HomeDeco 경계 판정·검증).
static func is_layer(layer: String) -> bool:
	return layer == L_FLOOR or layer == L_WALL or layer == L_FURNITURE

# ── 조회 ────────────────────────────────────────────────────────────────────
# 유효 세트 id인가.
static func has_set(set_id: String) -> bool:
	return SETS.has(set_id)

# 전 세트 id 목록(정의 순서).
static func set_ids() -> Array:
	return SETS.keys()

# 세트 표시명("" = 미지).
# ★[S4-T7] 옛 이름 `set_name`에서 개명했다(호출부 전량 갱신). **정적 호출이 조용히 깨져 있었다**:
#   `HomeDecoCatalog.set_name(x)`가 스크립트의 이 static이 아니라 엔진 쪽 `Object.set_name` 계열로
#   흡수돼 **항상 null**을 돌려줬다(인스턴스 호출·인라인 식은 정상 — 정적 호출만). S1-9부터 잠복해
#   있다가 S4-T7 목공방 매대(이 함수의 첫 실사용처)의 육안 덤프에서 "가구 세트"만 뜨는 걸로 드러났다.
#   F10 꾸미기 안내문("세트: <null>")도 같은 원인이었다. 카탈로그 관례(ItemCatalog.name_of·
#   Carpenter.name_of·FishCatalog.name_of)와도 이제 일치한다. **`set_*` 이름의 static은 금지**.
static func name_of(set_id: String) -> String:
	return str(SETS[set_id]["name"]) if SETS.has(set_id) else ""

# ★[S4-T7] 세트 정가(냥). 0 = 비매(스타터 세트 — 무상 해금분). ♡ 할인은 소비처(main)가 얹는다.
static func price_of(set_id: String) -> int:
	return int(SETS[set_id].get("price", 0)) if SETS.has(set_id) else 0

# ★[S4-T7] 목공방 매대에 진열할 세트 id 목록(정가 > 0인 것만 — 정의 순서).
static func purchasable_ids() -> Array:
	var out: Array = []
	for sid in SETS:
		if price_of(String(sid)) > 0:
			out.append(String(sid))
	return out

# 세트에 이 아이템이 있는가.
static func has_item(set_id: String, key: String) -> bool:
	return SETS.has(set_id) and SETS[set_id]["items"].has(key)

# 아이템 데이터({} = 미지 세트/아이템). 소비처는 layer/is_solid/color 접근자를 쓴다.
static func item(set_id: String, key: String) -> Dictionary:
	if not has_item(set_id, key):
		return {}
	return SETS[set_id]["items"][key]

# 아이템이 놓이는 레이어("" = 미지).
static func layer_of(set_id: String, key: String) -> String:
	var it := item(set_id, key)
	return str(it.get("layer", "")) if not it.is_empty() else ""

# 아이템 통과 불가 여부(그레이박스=미사용, 하류 충돌 훅. 미지=false).
static func is_solid(set_id: String, key: String) -> bool:
	var it := item(set_id, key)
	return bool(it.get("is_solid", false)) if not it.is_empty() else false

# 아이템 그레이박스 placeholder 색(미지=마젠타 경고색).
static func color_of(set_id: String, key: String) -> Color:
	var it := item(set_id, key)
	if it.is_empty():
		return Color(1, 0, 1)
	var c: Array = it.get("color", [1, 0, 1])
	return Color(float(c[0]), float(c[1]), float(c[2]))

# 세트 안에서 이 레이어에 속한 아이템 key 목록(팔레트 순환용, 정의 순서).
static func items_of_layer(set_id: String, layer: String) -> Array:
	var out: Array = []
	if not SETS.has(set_id):
		return out
	for key in SETS[set_id]["items"]:
		if SETS[set_id]["items"][key]["layer"] == layer:
			out.append(key)
	return out
