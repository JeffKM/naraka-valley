extends RefCounted
class_name FireflySouls
# ★[S10-T7 / ADR-0069 결정 10] 반딧넋 숨은 수집 원장 — 45개의 "어디 있나 · 무엇을 주웠나 · 문이 열렸나".
#
# 무엇인가: 길을 잃어 인도받지 못한 **작은 넋**이 반딧불 형상으로 세계에 숨어 있다(CONTEXT [반딧넋]).
#   플레이어가 찾아 [혼백관]에 안치하면 비로소 제자리를 얻는다 — **줍는 행위 자체가 인도**라
#   [ADR-0004] 속죄 테마에 그대로 정합한다. 해방([ADR-0068] 척추 B7) 뒤의 코지 롱테일 축이다.
#   ⚠️ [혼불](여우불·혼불씨·혼불 바람)과 **별개**다: 저쪽은 *불*이고 이쪽은 *넋*이다(어휘 충돌을
#   피해 "반딧"을 앞세운 명명 — ADR-0069 결정 10 명명 근거).
#
# 45의 구성 = **고정 배치 30 + 활동 드랍 15**(ADR 결정 10 "전 구역 고정 배치 + 전 활동 저확률 드랍
#   혼합"의 실표). 왜 이 비율인가 — **게이트(30)가 고정분의 총수와 정확히 같다**:
#   ㉠ 지도를 남김없이 훑은 사람은 드랍을 한 번도 못 만나도 문 앞에 선다(탐험만으로 닫히지 않는다).
#   ㉡ 드랍은 그 위의 **여유**다 — 스폿 하나를 못 찾아도 드랍 하나가 그 자리를 메운다(단일 실패점 0).
#   ㉢ 남는 15는 문 뒤의 꼬리다(마일스톤 답례 35·40·45) — "게이트이면서 동시에 수집물"이라는
#      결정 10 자구가 두 구간(0~30 게이트 / 30~45 수집)으로 자연히 갈린다.
#
# 왜 Museum에 얹지 않고 별개 원장인가:
#   `Museum.claimed`가 **기증 count를 키로** 마일스톤을 잠그고 있어, 그 분모에 손을 대면 이미 받은
#   답례가 어긋난다. [S10-T2] 레어크로우 추적 진열과 [S10-T6] 명부 도감이 같은 이유로 Museum
#   바깥에 섰고, 반딧넋도 그 셋째다. **혼백관 기증 분모는 한 톨도 안 바뀐다**(firefly_soul_test가 단언).
#
# ★ 총원·게이트·구역별 개수는 전부 **표 파생**이다 — 호출부에 45도 30도 안 적는다(`total_count()`·
#   `GATE_COUNT`·`region_total()`). 표가 늘면 총원이 저절로 따라 는다(수동 목록 = 잠복 stale).
#
# 왜 인벤토리 아이템이 아닌가(★ 설계의 핵심):
#   반딧넋은 **잃을 수 없는 수집물**이다. 아이템으로 만들면 버리기·상자·출하·선물이라는 처분 경로가
#   전부 열려, 한 마리를 잃는 순간 45 완주가 영영 불가능해진다([S9-T7] 책·[S10-T2] 레어크로우가
#   "버릴 수 없다" 가드를 *덧대어* 막은 그 문제를, 여기선 아예 **아이템을 만들지 않아** 원천 차단한다).
#   그래서 줍는 즉시 이 원장에 적힌다 = 줍기와 안치가 한 동작이다(혼백관은 *보여 주는* 곳이지
#   *가져가는* 곳이 아니다).
#
# 이 파일이 모르는 것: 지형·인벤토리·혼력·알림·그리기. 좌표가 정말 걸을 수 있는 칸인지는 main의
#   실그리드가 알고(firefly_soul_test가 전 구역 실그리드로 단언한다), 안치 연출·프롬프트도 main 몫이다.
#   여기는 "어디에 무엇이 있고, 무엇을 주웠고, 문이 열렸나"만 안다(PanningSpots 순수성 1:1).

signal changed()   # 수집·마일스톤·복원 프레임(main이 듣고 필드 반짝임·혼백관 진열 갱신)

# ── 게이트 · 드랍 몫(ADR-0069 결정 10 — 잠정 수치 · owner 큐) ──────────────────
const GATE_COUNT := 30      # [명부 시련장] 개방 문턱(결정 10 "30개 = 게이트" · T8이 소비)
const DROP_COUNT := 15      # 활동 드랍 몫(고정 30 + 드랍 15 = 45)

# ── 고정 배치 표(★ 이 태스크에서 잠근다 — 좌표는 세이브 간 불변) ────────────────
# 전 구역(도달 가능 8구역) 분산. 각 좌표는 **그 구역 스폰에서 걸어 닿는 GROUND/PATH 칸**이고,
# 워프 트리거·건물 문·채집 존·팬닝 존을 전부 비껴간다(선정 자체가 실그리드 flood-fill로 뽑혔고,
# firefly_soul_test ②가 매 실행마다 그 성질을 다시 검증한다 — 맵이 흔들리면 테스트가 먼저 운다).
# id는 **세이브 키**라 좌표가 바뀌어도 절대 안 바꾼다(바꾸면 그 넋이 미수집으로 되돌아간다).
const FIXED := [
	# 안식 농원(4) — 밭 바깥 마당 네 구획(경작 가능 칸은 애초에 후보에서 뺐다: 괭이질 자리와
	#   반딧넋 자리가 겹치면 [F]와 LMB가 같은 칸을 두고 다툰다)
	{"id": "ff_home_1", "region": "home", "tile": Vector2i(21, 16)},
	{"id": "ff_home_2", "region": "home", "tile": Vector2i(60, 16)},
	{"id": "ff_home_3", "region": "home", "tile": Vector2i(20, 49)},
	{"id": "ff_home_4", "region": "home", "tile": Vector2i(60, 48)},
	# 나루 마을(5) — 허브(100×72)라 하나 더 많다
	{"id": "ff_naru_1", "region": "naru_village", "tile": Vector2i(17, 18)},
	{"id": "ff_naru_2", "region": "naru_village", "tile": Vector2i(50, 18)},
	{"id": "ff_naru_3", "region": "naru_village", "tile": Vector2i(84, 18)},
	{"id": "ff_naru_4", "region": "naru_village", "tile": Vector2i(18, 54)},
	{"id": "ff_naru_5", "region": "naru_village", "tile": Vector2i(50, 54)},
	# 삼도천(4)
	{"id": "ff_samdo_1", "region": "samdocheon", "tile": Vector2i(14, 10)},
	{"id": "ff_samdo_2", "region": "samdocheon", "tile": Vector2i(42, 10)},
	{"id": "ff_samdo_3", "region": "samdocheon", "tile": Vector2i(14, 28)},
	{"id": "ff_samdo_4", "region": "samdocheon", "tile": Vector2i(42, 28)},
	# 황천해(4)
	{"id": "ff_hwang_1", "region": "hwangcheonhae", "tile": Vector2i(16, 11)},
	{"id": "ff_hwang_2", "region": "hwangcheonhae", "tile": Vector2i(48, 11)},
	{"id": "ff_hwang_3", "region": "hwangcheonhae", "tile": Vector2i(16, 27)},
	{"id": "ff_hwang_4", "region": "hwangcheonhae", "tile": Vector2i(49, 27)},
	# 저승 숲(4)
	{"id": "ff_forest_1", "region": "jeoseung_forest", "tile": Vector2i(15, 11)},
	{"id": "ff_forest_2", "region": "jeoseung_forest", "tile": Vector2i(45, 14)},
	{"id": "ff_forest_3", "region": "jeoseung_forest", "tile": Vector2i(15, 33)},
	{"id": "ff_forest_4", "region": "jeoseung_forest", "tile": Vector2i(47, 33)},
	# 미혹의 숲(4)
	{"id": "ff_mihok_1", "region": "mihok_forest", "tile": Vector2i(16, 11)},
	{"id": "ff_mihok_2", "region": "mihok_forest", "tile": Vector2i(48, 11)},
	{"id": "ff_mihok_3", "region": "mihok_forest", "tile": Vector2i(16, 32)},
	{"id": "ff_mihok_4", "region": "mihok_forest", "tile": Vector2i(48, 33)},
	# 업화 갱도(3) — **지상 무대만**이다. 갱도 *내부* 층은 day-한정 원장이라(MineFloors) 매일 판이
	#   갈리는데, 고정 배치는 "늘 거기 있는 것"이라 그 위에 설 자리가 없다.
	{"id": "ff_mine_1", "region": "eophwa_mine", "tile": Vector2i(16, 11)},
	{"id": "ff_mine_2", "region": "eophwa_mine", "tile": Vector2i(48, 11)},
	{"id": "ff_mine_3", "region": "eophwa_mine", "tile": Vector2i(16, 33)},
	# 나락(2) — 깨진 봉인 고리 아레나(상설 무대. 리셋 런 층은 갱도 층과 같은 이유로 제외)
	{"id": "ff_narak_1", "region": "narak", "tile": Vector2i(16, 22)},
	{"id": "ff_narak_2", "region": "narak", "tile": Vector2i(48, 22)},
]

# ── 활동 드랍(ADR 결정 10 "전 활동 저확률" · Books 채널 문법 1:1 상속) ────────────
# **한 활동에 몰지 않는 이유**는 Books와 같다: 어떤 플레이 스타일이든 넋을 만나게 하기 위해서다.
# 다만 Books가 *로어*의 배달이라면 이쪽은 *수집물*의 배달이라, 몫이 15로 유한하고 동나면 멈춘다.
const SRC_HARVEST := "harvest"   # 수확 — 밭 한 포기를 거둘 때마다(화분 제외 — main 훅 주석 참조)
const SRC_CHOP := "chop"         # 벌목 — 도끼가 나무·그루터기에 닿을 때마다
const SRC_MINE := "mine"         # 채광 — 광맥/돌을 부순 사건마다(★[폴리시 R4] 갱도·나락 두 무대 공통)
const SRC_FISH := "fish"         # 낚시 — 포획 성공마다

# 원천별 드랍 확률(퍼밀 · 0..999 롤 대비). **잠정값 — owner 큐**(ADR-0069 결정 1 폴리시 이월).
# 밴드 근거 = **활동 빈도의 역수**(Books.DROP_PERMIL과 같은 규율): 한 판에 수십 번 굴리는 채굴은
# 낮게, 한 번이 무거운 낚시 포획은 높게 둬 어느 축으로 놀아도 비슷한 속도로 만나게 한다.
#   · 채광 5퍼밀(0.5%/부순 돌) — 층 하나에 돌이 수십이라 실효 조우가 가장 잦은 축
#   · 수확 8퍼밀(0.8%/수확)    — 밭이 크면 하루 수십 번
#   · 벌목 12퍼밀(1.2%/타)     — 나무 한 그루에 여러 타라 채굴 다음으로 잦다
#   · 낚시 25퍼밀(2.5%/포획)   — 한 판에 몇 마리뿐이라 가장 높다
const DROP_PERMIL := {
	SRC_MINE: 5,
	SRC_HARVEST: 8,
	SRC_CHOP: 12,
	SRC_FISH: 25,
}

# ── 안치 마일스톤 답례(전부 **잠정 — owner 큐**) ───────────────────────────────
# ★ 게이트(30) *위*에만 건다 — 결정 10의 "잔여 15는 안치 마일스톤 보상"이 가리키는 구간이 거기다.
#   30 이하에 답례를 얹으면 게이트가 답례 사다리에 묻혀 "문"으로 안 읽힌다.
# ★ 보상은 전부 **일회성 물건**이다: [ADR-0019]·[ADR-0034] #4가 영구 % 곱셈을 금지하므로 답례가
#   배수·확률·속도를 건드리는 일은 없다(Museum.MILESTONES가 같은 가드 아래 선 것과 1:1).
# ★ **오색혼옥은 안 준다** — 혼백관 완주 답례가 이미 그 자리에 서 있고, 초희귀는 들어오는 길이
#   좁아야 한다([ADR-0063] 결정 2). 그래서 꼭대기도 명부금강 3개로 끝낸다.
const MILESTONES := [
	{"count": 35, "reward_id": "fert_deluxe", "n": 5},
	{"count": 40, "reward_id": "gem_myeongbu_geumgang", "n": 1},
	{"count": 45, "reward_id": "gem_myeongbu_geumgang", "n": 3},
]

# ── 원장(세이브 대상) ────────────────────────────────────────────────────────
var collected: Dictionary = {}   # 반딧넋 id(String) → 안치한 day(int)
var claimed: Array = []          # 지급 완료 마일스톤 count(int) 목록(이중 지급 방지 — Museum 결)

# ── 표 파생(하드코딩 0) ───────────────────────────────────────────────────────
static func fixed_count() -> int:
	return FIXED.size()

# 총원 = 고정분 + 드랍 몫. **여기가 45의 유일한 출처다.**
static func total_count() -> int:
	return fixed_count() + DROP_COUNT

# 고정 배치 id 전량(표 선언 순).
static func fixed_ids() -> Array:
	var out: Array = []
	for row in FIXED:
		out.append(String(row["id"]))
	return out

# 드랍 몫 id 전량(파생 — 표에 안 적는다. 몫이 바뀌면 id 목록이 저절로 따라 바뀐다).
static func drop_ids() -> Array:
	var out: Array = []
	for i in range(1, DROP_COUNT + 1):
		out.append("ff_drop_%d" % i)
	return out

# 45개 전 id(고정 → 드랍 순). 중복은 구조적으로 불가능하다(접두가 갈린다).
static func all_ids() -> Array:
	var out: Array = fixed_ids()
	out.append_array(drop_ids())
	return out

static func is_valid_id(id: String) -> bool:
	return all_ids().has(id)

static func is_drop_id(id: String) -> bool:
	return drop_ids().has(id)

# 고정 배치가 있는 구역 목록(표 등장 순 · 중복 제거).
static func regions() -> Array:
	var out: Array = []
	for row in FIXED:
		var r := String(row["region"])
		if not out.has(r):
			out.append(r)
	return out

# 그 구역의 고정 배치 행 목록(표 순).
static func spots_in(region: String) -> Array:
	var out: Array = []
	for row in FIXED:
		if String(row["region"]) == region:
			out.append(row)
	return out

static func region_total(region: String) -> int:
	return spots_in(region).size()

# 이 구역·이 칸의 반딧넋 id("" = 없음). 수집 여부와 무관한 **표 질의**다.
static func spot_id_at(region: String, t: Vector2i) -> String:
	for row in FIXED:
		if String(row["region"]) == region and Vector2i(row["tile"]) == t:
			return String(row["id"])
	return ""

# ── 질의(원장) ───────────────────────────────────────────────────────────────
func is_collected(id: String) -> bool:
	return collected.has(id)

func collected_count() -> int:
	return collected.size()

# 안치한 day(-1 = 미수집).
func day_of(id: String) -> int:
	return int(collected[id]) if collected.has(id) else -1

# 고정분 중 안치한 수(분자 — 구성 요소 표시용).
func collected_fixed_count() -> int:
	var n := 0
	for id in fixed_ids():
		if collected.has(String(id)):
			n += 1
	return n

func collected_drop_count() -> int:
	var n := 0
	for id in drop_ids():
		if collected.has(String(id)):
			n += 1
	return n

func region_collected(region: String) -> int:
	var n := 0
	for row in spots_in(region):
		if collected.has(String(row["id"])):
			n += 1
	return n

# 지금 **아직 안 주운** 반딧넋이 이 칸에 있나 → id("" = 없음). 필드 렌더·[F] 디스패치의 단일 술어.
func live_spot_at(region: String, t: Vector2i) -> String:
	var id := spot_id_at(region, t)
	return "" if id == "" or collected.has(id) else id

# 이 구역에서 아직 안 주운 고정 배치 칸 목록(그레이박스 반짝임 렌더용 — 표 순).
func live_tiles(region: String) -> Array:
	var out: Array = []
	for row in spots_in(region):
		if not collected.has(String(row["id"])):
			out.append(Vector2i(row["tile"]))
	return out

func is_complete() -> bool:
	for id in all_ids():
		if not collected.has(String(id)):
			return false
	return true

# ── ★ 게이트 술어([명부 시련장] 개방 — S10-T8이 소비하는 공개 API) ───────────────
# **저장 플래그를 따로 두지 않는다.** 열림은 언제나 카운트의 파생이라, 원장과 플래그가 어긋날
# 자리가 구조적으로 없다(세이브 손상·구버전 복원에도 답이 하나다 — narak_key_found처럼 별 플래그를
# 세웠다면 "카운트는 30인데 문은 닫힘"이 가능해진다).
func gate_open() -> bool:
	return collected_count() >= GATE_COUNT

# 문이 열리기까지 남은 수(0 = 이미 열림 — 프롬프트·안내가 쓴다).
func remaining_to_gate() -> int:
	return maxi(GATE_COUNT - collected_count(), 0)

# ── 안치(줍는 즉시 = 인벤 경유 0) ─────────────────────────────────────────────
# 표에 없는 id·이미 안치한 id는 false(멱등 — 재정산·중복 입력에 두 번 안 적힌다).
func collect(id: String, day: int) -> bool:
	if not is_valid_id(id) or collected.has(id):
		return false
	collected[id] = day
	changed.emit()
	return true

# ── 활동 드랍 롤(순수 · 결정적) ───────────────────────────────────────────────
# ★ 프로젝트 관례: `hash("<네임스페이스>:<day>:<serial>")` → **`rand_from_seed` 믹싱** → % N.
#   해시를 바로 %로 접으면 djb2 하위 비트 편향으로 특정 분위가 통째로 비는 사고가 있었다
#   (weather.gd 헤더의 실증). 네임스페이스가 "firefly:"로 시작해 Books·팬닝·날씨 어느 스트림과도
#   안 얽히고, **전역 RNG를 한 톨도 안 쓴다**(rand_from_seed는 순수 함수 — 기존 골든 서명 불침범).
static func _roll(ns: String, day: int, serial: int, modulo: int) -> int:
	return absi(rand_from_seed(hash("%s:%d:%d" % [ns, day, serial]))[0]) % maxi(modulo, 1)

# 이 원천의 드랍 확률(퍼밀). 모르는 원천은 0 = 절대 안 나옴(오타 방어 — Books.permil_of 결).
static func permil_of(source: String) -> int:
	return int(DROP_PERMIL.get(source, 0))

# **이번 사건에 무엇이 나오는가**(순수 함수 — 원장을 인자로 받는다). "" = 이번엔 없음.
#   ㉠ 게이트 롤: 원천별 퍼밀 미만이면 통과
#   ㉡ 지목 롤: **아직 안 주운 드랍 몫 중에서만** 뽑는다(중복 0 · 고정분 침범 0 — 고정분은 지도의
#      몫이라 드랍이 대신 줘 버리면 그 스폿이 영영 무의미한 빈 칸으로 남는다)
#   ㉢ 드랍 몫 15가 동나면 그 뒤로는 영원히 "" — 총원이 45를 넘지 않는 구조적 보증이다
static func peek_drop(source: String, day: int, serial: int, owned: Dictionary) -> String:
	var permil := permil_of(source)
	if permil <= 0:
		return ""
	if _roll("firefly:" + source, day, serial, 1000) >= permil:
		return ""
	var pool: Array = []
	for id in drop_ids():
		if not owned.has(String(id)):
			pool.append(String(id))
	if pool.is_empty():
		return ""
	return String(pool[_roll("fireflypick:" + source, day, serial, pool.size())])

# 인스턴스 창구 — 지금 원장으로 이번 롤의 결과를 본다(적재는 아직 안 한다).
func pending_drop(source: String, day: int, serial: int) -> String:
	return peek_drop(source, day, serial, collected)

# ── 마일스톤 답례 ────────────────────────────────────────────────────────────
# 도달했지만 아직 안 받은 행 목록(낮은 count부터). main이 지급 후 claim()으로 잠근다(Museum 1:1).
func pending_milestones() -> Array:
	var out: Array = []
	for m in MILESTONES:
		if collected_count() >= int(m["count"]) and not claimed.has(int(m["count"])):
			out.append(m)
	return out

func claim(count: int) -> void:
	if not claimed.has(count):
		claimed.append(count)
		changed.emit()

# ── 세이브/로드(슬라이스 키 "fireflies" 네임스페이스 — Museum·Codex 결) ─────────
func to_save() -> Dictionary:
	return {"collected": collected.duplicate(), "claimed": claimed.duplicate()}

# 복원: **표에 있는 id만 받는다**(미지 id 드롭 — 옛 표의 id가 분자에 남아 "46/45"가 되는 사고 차단).
# 손상값·비-dict도 방어한다(Codex.load_save 결).
# ★ 하위호환: 키 없는 구세이브 = 빈 원장(전 반딧넋이 제자리에 있는 새 수집 — 무막힘).
func load_save(data: Dictionary) -> void:
	collected = {}
	var raw: Variant = data.get("collected", {})
	if typeof(raw) == TYPE_DICTIONARY:
		for k in raw:
			var sid := String(k)
			if is_valid_id(sid):
				collected[sid] = int(raw[k])
	claimed = []
	var rawc: Variant = data.get("claimed", [])
	if typeof(rawc) == TYPE_ARRAY:
		for c in rawc:
			claimed.append(int(c))
	changed.emit()
