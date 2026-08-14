extends RefCounted
class_name Carpenter
# ★[S4-T7 / ADR-0062 결정 7 ㉠] 목공방 건축 의뢰 — 골드+원목을 미리 치르고 N일 뒤 아침에 받는 원장.
#
# 목적: 카탈로그 §1-C가 "목공방 건축 서비스·주인 = 별도 결(서랍)"로 미뤄 둔 그 결의 *원장 몫*이다.
#       스타듀 로빈 문법 1:1 — **선불(골드 + 원목) → 며칠 대기 → 아침에 완공**이고, 동시에 진행하는
#       의뢰는 **1건**뿐이다(스타듀도 로빈은 한 번에 한 채만 짓는다). 대기가 곧 가격의 일부라
#       "돈만 있으면 그날로 다 짓는" 붕괴를 막는다.
#
# 설계 메모(TapperLedger·CrabPotLedger 머리말의 디커플링 경계 그대로 — 어기면 결정 7 위반):
#   - **원장은 지갑·인벤·지형·건물을 모른다.** 지불(골드 차감·원목 차감)도, 완공 후 승격 배선
#     (Ranch 정원 확장)도 전부 main이 한다. 여기 있는 건 "무엇을 언제 짓는가" 하나뿐이다 —
#     그래서 이 파일엔 Wallet·Inventory·Ranch 참조가 한 줄도 없다(구조가 곧 불변식의 보증).
#   - **RNG가 없다.** 완공은 day 비교 하나로 결정된다(헤드리스 재현성 — 게잡이통·게시판 선례).
#   - **완공은 하루의 시작에 일어난다.** main의 day advance 훅이 새 day로 `advance_day`를 부르고,
#     원장은 예정일에 닿았는지만 본다(수액 채취기·게시판 만료와 같은 자리·같은 문법).
#   - **완공 이력을 든다**(`_done`). 같은 업그레이드를 두 번 팔지 않기 위한 최소 기억이고, 이게
#     매대 진열(완공된 건 "완공" 잠금 행)의 유일한 출처다.
#
# ★[S8-T7 / ADR-0066 결정 8] "방 = 결혼 Slice 8" 서랍의 **이행**: 「안방 확장」이 세 번째
#    프로젝트로 붙었다 — 예고대로 데이터 1건 추가뿐이고 구조 변경 0이다. building이 ""인 첫
#    프로젝트라(Ranch 승격 없음), 완공 실효(HOME 방 rect 확장·home_deco bounds 재주입)는 main의
#    완공 배선이 id 분기로 잇는다(원장은 여전히 "무엇을 언제 짓는가"만 안다).
#    주방(요리) 업그레이드는 여전히 서랍이다 — 요리 소비처(S6)가 곳간→접시 창구로 열려 있지만
#    "주방 설비" 실내 콘텐츠가 없어 지금 넣으면 소스 없는 콘텐츠가 된다(ADR-0060 결정 6 선례).

signal changed()   # 의뢰·완공·복원 프레임(main이 듣고 매대 행·알림·드로우 갱신)

# ── 프로젝트 카탈로그(정적) ──────────────────────────────────────────────────
# 초기 로스터 = **Track B B1-b 성장 티어 2건뿐**이다. B1-b는 설계 시점부터 "목공방 후행"으로
# 대기해 왔고([farm-buildings-roster.md]), 그 시점이 지금이다.
#
# ★ 수치 = 스타듀 Big Coop / Big Barn 1:1 상속(잠정 — owner 큐):
#     · 큰 넋둥우리 = Big Coop   10,000g + 목재 400   (스타듀 그대로)
#     · 큰 넋우릿간 = Big Barn   12,000g + 목재 450   (스타듀 그대로)
#     · 공기(工期) 2일도 스타듀 그대로.
#   근거: 도구 티어(tool_tier.gd 명동 2,000냥 / 유철 5,000냥)가 이미 스타듀 구리·강철 가격을
#   그대로 상속했으므로 **엽전 = 골드 1:1 스케일이 이 슬라이스의 기정 사실**이다. 건축비만 따로
#   환산하면 두 경제가 어긋난다.
const PROJ_BIG_COOP := "big_coop"
const PROJ_BIG_BARN := "big_barn"
# ★[S8-T7 / ADR-0066 결정 8] 안방 확장 — 결혼 조건 "배우자 방"의 실물. 10,000냥+원목 300·2일은
#   잠정(owner 큐 적재분). building=""(Ranch 무관 — 완공 실효는 main의 HOME 방 rect 확장 분기).
const PROJ_MASTER_ROOM := "master_room"
# ★[S10-T4 / ADR-0069 결정 6] 마구간 — **이 원장의 세 번째 항목**이다(결정 6 자구: "새 건축
#   시스템을 만들지 않는다"). 안방 확장이 그랬듯 데이터 1건 추가가 전부이고, 완공 실효(휘파람
#   증정)는 main의 완공 배선이 id 분기로 잇는다 — 원장은 여전히 "무엇을 언제 짓는가"만 안다.
#   ★ 비용 10,000냥 + 원목 100 + **유철 주괴 5** · 공기 2일은 [ADR-0069] 결정 6의 잠정치다.
const PROJ_STABLE := "stable"

# id → {name_ko, gold, wood, days, building(Ranch 건물 id — "" = 건물 무관), desc}
#   + ★[S10-T4] ingot/ingot_id(주괴 자재 — 키 없으면 0/"" = 요구 없음. 기존 3건은 무영향).
#     원목 하나로 끝나던 자재 축에 주괴가 붙은 이유는 마구간이 **금속 부재를 쓰는 첫 건축**이기
#     때문이다(경첩·재갈·편자). 필드를 옵션으로 둔 덕에 기존 프로젝트의 직렬화·매대·결제 경로가
#     한 줄도 안 바뀐다(Ranch 티어가 `_tiers` 빈 dict로 구세이브를 흡수한 그 결).
const PROJECTS := {
	PROJ_BIG_COOP: {
		"name_ko": "큰 넋둥우리", "gold": 10000, "wood": 400, "days": 2,
		"building": "넋둥우리",
		"desc": "둥우리를 넓혀 더 많은 넋을 들인다",
	},
	PROJ_BIG_BARN: {
		"name_ko": "큰 넋우릿간", "gold": 12000, "wood": 450, "days": 2,
		"building": "넋우릿간",
		"desc": "우릿간을 넓혀 더 많은 넋을 들인다",
	},
	PROJ_MASTER_ROOM: {
		"name_ko": "안방 확장", "gold": 10000, "wood": 300, "days": 2,
		"building": "",
		"desc": "본가에 두 사람의 방을 들인다",
	},
	PROJ_STABLE: {
		"name_ko": "마구간", "gold": 10000, "wood": 100, "days": 2,
		"ingot": 5, "ingot_id": ItemCatalog.INGOT_YUCHEOL,
		"building": "",
		"desc": "저승 말이 머물 자리를 짓는다",
	},
}

# ── 상태 ────────────────────────────────────────────────────────────────────
# 진행 중 의뢰(동시 1건 — 스타듀 로빈 1:1). {} = 없음. {"id": String, "due_day": int}
var _active: Dictionary = {}
# 완공 이력. key = 프로젝트 id, 값 = true. 같은 업그레이드를 두 번 팔지 않기 위한 기억.
var _done: Dictionary = {}

# ── 카탈로그 조회(static — 매대 진열·테스트가 원장 없이도 읽는다) ─────────────
static func ids() -> Array:
	return PROJECTS.keys()

static func has_project(id: String) -> bool:
	return PROJECTS.has(id)

static func get_project(id: String) -> Dictionary:
	return PROJECTS[id] if PROJECTS.has(id) else {}

static func name_of(id: String) -> String:
	return String(PROJECTS[id]["name_ko"]) if PROJECTS.has(id) else ""

static func desc_of(id: String) -> String:
	return String(PROJECTS[id]["desc"]) if PROJECTS.has(id) else ""

# 정가(골드). ♡ 할인은 *가게 정책*이라 소비처(main)가 StoreDiscount로 얹는다 — 여기선 정가만.
static func gold_cost(id: String) -> int:
	return int(PROJECTS[id]["gold"]) if PROJECTS.has(id) else 0

# 원목 요구량. ★자재는 할인 대상이 아니다 — 할인은 *값을 깎는* 정책이지 나무를 덜 쓰게 하는
# 마법이 아니다(그리고 자재까지 깎으면 ♡가 자재 경제 곱셈기가 되어 ADR-0008에 걸린다).
static func wood_cost(id: String) -> int:
	return int(PROJECTS[id]["wood"]) if PROJECTS.has(id) else 0

static func build_days(id: String) -> int:
	return int(PROJECTS[id]["days"]) if PROJECTS.has(id) else 0

# ★[S10-T4] 주괴 요구량(0 = 요구 없음). 원목과 같은 이유로 **할인 대상이 아니다** — 할인은 값을
#   깎는 정책이지 쇠를 덜 쓰게 하는 마법이 아니다(wood_cost 주석과 같은 결).
static func ingot_cost(id: String) -> int:
	return int(PROJECTS[id].get("ingot", 0)) if PROJECTS.has(id) else 0

# 요구 주괴의 아이템 id("" = 요구 없음). 종을 데이터에 두는 이유는 다음 건축이 다른 주괴를
# 쓸 수 있어서다 — 소비처(main)가 종을 하드코딩하면 그때 또 분기가 는다.
static func ingot_id_of(id: String) -> String:
	return String(PROJECTS[id].get("ingot_id", "")) if PROJECTS.has(id) else ""

# 이 프로젝트가 승격시키는 Ranch 건물 id("" = 건물과 무관한 프로젝트).
static func building_of(id: String) -> String:
	return String(PROJECTS[id].get("building", "")) if PROJECTS.has(id) else ""

# ── 질의 ────────────────────────────────────────────────────────────────────
func is_active() -> bool:
	return not _active.is_empty()

# 진행 중 의뢰 id("" = 없음).
func active_id() -> String:
	return String(_active.get("id", ""))

# 완공 예정일(0 = 진행 중 의뢰 없음).
func due_day() -> int:
	return int(_active.get("due_day", 0))

# 오늘(day) 기준 남은 날(0 = 없거나 이미 예정일 도달).
func days_left(day: int) -> int:
	return maxi(0, due_day() - day) if is_active() else 0

func is_done(id: String) -> bool:
	return _done.has(id)

func done_ids() -> Array:
	return _done.keys()

# 지금 이 프로젝트를 주문할 수 있는가(*지불 능력은 안 본다* — 그건 main 소관).
#   ㉠ 아는 프로젝트여야 하고 ㉡ 이미 지은 것이 아니어야 하며 ㉢ 진행 중 의뢰가 없어야 한다.
func can_order(id: String) -> bool:
	return has_project(id) and not is_done(id) and not is_active()

# ── 주문/완공 ────────────────────────────────────────────────────────────────
# 의뢰를 건다. 성공 시 true(진행 1건 점유). 지불은 호출 측(main)이 *먼저* 끝내고 부른다 —
# 원장은 지갑을 모르므로 여기서 실패하면 돈이 새는 순서가 된다. 그래서 main은 반드시
# `can_order` → 지불 → `order` 순으로 부르고, 이 함수도 같은 가드를 다시 본다(이중 방어).
func order(id: String, day: int) -> bool:
	if not can_order(id):
		return false
	_active = {"id": id, "due_day": day + build_days(id)}
	changed.emit()
	return true

# 하루의 시작. 진행 중 의뢰가 예정일에 닿았으면 완공하고 그 id를 돌려준다("" = 완공 없음).
# ★완공 후 실효(Ranch 정원 확장·건물 외형 갱신)는 main이 돌려받은 id로 배선한다 — 원장은
#   "다 지어졌다"까지만 안다(TapperLedger가 인벤을 모르는 것과 같은 경계).
func advance_day(day: int) -> String:
	if not is_active() or day < due_day():
		return ""
	var id := active_id()
	_active = {}
	_done[id] = true
	changed.emit()
	return id

# 진행 중 의뢰 한 줄 요약(프롬프트·알림·매대 헤더용). 없으면 "".
func summary(day: int) -> String:
	if not is_active():
		return ""
	var left := days_left(day)
	if left <= 0:
		return "%s — 내일 아침 완공" % name_of(active_id())
	return "%s — %d일 남음" % [name_of(active_id()), left]

# ── 세이브/로드(TapperLedger·CrabPotLedger 규약 계승) — 슬라이스 키 "carpenter" ──
# 진행 의뢰는 [id, due_day] 2항 배열, 완공 이력은 id 문자열 배열로 얇게 직렬화한다.
func to_save() -> Dictionary:
	var act: Array = []
	if is_active():
		act = [active_id(), due_day()]
	return {"active": act, "done": _done.keys()}

func load_save(data: Dictionary) -> void:
	_active = {}
	_done = {}
	var raw: Variant = data.get("active", [])   # 키 없는 구세이브 = 진행 의뢰 0(하위호환)
	if typeof(raw) == TYPE_ARRAY:
		var a: Array = raw
		if a.size() >= 2 and has_project(String(a[0])):   # 모르는 프로젝트 id는 조용히 버린다
			_active = {"id": String(a[0]), "due_day": int(a[1])}
	var raw_done: Variant = data.get("done", [])
	if typeof(raw_done) == TYPE_ARRAY:
		for id in raw_done:
			if has_project(String(id)):
				_done[String(id)] = true
	# 완공 이력에 있는 걸 또 짓고 있는 손상 세이브 방어(진행분을 버린다 — 이미 서 있는 건물이 답).
	if is_active() and is_done(active_id()):
		_active = {}
	changed.emit()
