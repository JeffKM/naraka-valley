extends Node
class_name QuestBoard
# ★ [S2-T6 / ADR-0060 결정 6] 게시판 의뢰 — 일일 + 중기(Special Orders 대응) 통합 원장.
#
# 구조(Museum 기증 원장 패턴 계승):
#   · 의뢰 자체는 **상태가 아니다** — day(또는 주 인덱스) 시드에서 매번 *결정적으로 파생*한다.
#     같은 날이면 언제 조회해도 같은 의뢰가 나오므로 "오늘 걸린 의뢰"를 세이브할 필요가 없다
#     (Festival.is_event_day·StoreDiscount와 같은 무상태 파생 결).
#   · 원장이 드는 상태는 셋뿐 — active(수락 중 1건)·completed(완료 이력)·_paid(지급 기록).
#   · 아이템 소모·골드 지급·호감도 가산은 전부 호출자(main) 소관이다. 이 노드는 "무엇을 몇 개,
#     누구에게, 언제까지, 얼마에"라는 계약 사실만 안다(디커플링 — Museum.donate와 같은 결).
#
# 스코프([ADR-0060] 결정 6): **납품형만**. 처치 유형은 그 활동 자체가 없어(Slice 5) 소스 없는
#   콘텐츠가 되므로 넣지 않는다. 대상 아이템 풀은 실존 소스에서 파생한다 —
#   작물(CropCatalog 전 작물) + 채집물(ItemCatalog.FORAGEABLES = 피안화). 하드코딩 목록 없음.
#   ★ [S3-T8 / ADR-0061 결정 8] 낚시 루프가 실존하게 되어(Slice 3) **물고기 납품 유형을 점등**했다
#   — ADR-0060 결정 6의 "낚시는 Slice 3에서 확장" 예고 이행. 아래 낚시 의뢰 갈래 참조.

const KIND_DAILY := "daily"     # 일일 의뢰 — 매일 1건, 기한 2일
const KIND_WEEKLY := "weekly"   # 중기 의뢰 — 주당 1건, 그 주 끝까지

# ── 보상 공식([ADR-0060] 결정 6 = 스타듀 공식) ────────────────────────────────
const REWARD_MULT := 3          # 보상 골드 = 일반품질(Q_NORMAL) 판매가 × 3 × 수량
# 호감도 보상 — 일일 = 선물 1회급(Affinity.GIFT_POINTS와 같은 눈금), 중기 = 그 2배.
#   ★ 잠정(owner 큐): "선물급 근방"이라는 결정 6 서술을 선물 상수 그대로 채택했다. 게시판이
#   선물 채널보다 세거나 약해야 한다는 판단이 서면 이 두 줄만 바꾸면 된다(다른 곳에 안 샌다).
const DAILY_AFFINITY := Affinity.GIFT_POINTS
const WEEKLY_AFFINITY := DAILY_AFFINITY * 2

# ── 수량·기한 ────────────────────────────────────────────────────────────────
const DAILY_COUNT_MIN := 1
const DAILY_COUNT_MAX := 3
# ★ 잠정(owner 큐): 중기 수량 5~8 — "같은 납품형이되 수량 큼"의 그레이박스 값. 보상이 수량 비례라
#   이 폭이 곧 중기 의뢰의 체감 무게다(밸런싱은 Phase 3 레버).
const WEEKLY_COUNT_MIN := 5
const WEEKLY_COUNT_MAX := 8
const DAILY_SPAN_DAYS := 2      # 일일 기한 = 게시일 포함 2일(due_day = post_day + 1)
const WEEK_DAYS := 7            # 한 주 = 7일(중기 기한 = 그 주 마지막 날)

# 의뢰인 후보 = affinity 인스턴스를 가진 NPC(미호·멜·바나·네오). 표시명이 곧 id다 — main이
# 이 이름으로 자기 affinity 노드를 찾아 준다(_quest_client_affinity 다리, foxfire/museum 결).
const CLIENTS := ["미호", "멜", "바나", "네오"]

# ★ [S3-T8 / ADR-0061 결정 8] 낚시 의뢰 갈래 — 납품형 풀에 물고기 유형을 얹는다.
#   기존 작물/채집 의뢰의 day 시드 수열은 **한 바이트도 안 바뀐다**: 타입 롤이 *전용 시드*
#   ("<kind>_fish_day:<n>")로 물고기 날을 고르고, 물고기 날만 전용 생성기(_make_fish, 시드
#   "<kind>_fish:<n>")로 파생한다. 아닌 날은 기존 _make 경로를 무수정으로 탄다(테스트 ①k가 못 박음).
const FISH_KIND_DIE := 3            # 타입 롤 주사위 — 평균 1/3이 물고기 의뢰 날(잠정·owner 큐)
# 물고기 의뢰인 풀 = 기존 4인 + 뱃사공(낚시의 자연 의뢰인 — Resident 등록·affinity 보유라 다리 성립).
# 기존 CLIENTS엔 안 넣는다(작물/채집 의뢰 시드 결과 보존 + 뱃사공이 작물을 청하는 건 결이 안 맞음).
const FISH_CLIENTS := ["미호", "멜", "바나", "네오", "뱃사공"]
# ★ 잠정(owner 큐): 중기 물고기 수량 4~6 — 작물 중기(5~8)보다 낮춤. 낚시는 입질 롤이 종을 고르는
#   확률 소스라 같은 수량이면 특정 종 다수 납품의 체감 그라인드가 작물 재배보다 훨씬 크다.
const WEEKLY_FISH_COUNT_MIN := 4
const WEEKLY_FISH_COUNT_MAX := 6

var active: Dictionary = {}     # 수락 중인 의뢰 1건({} = 없음). 계약 스냅샷이라 통째 직렬화한다.
var completed: Array = []       # 완료한 의뢰 key 목록(같은 의뢰 중복 완료 방지)
var paid_gold: int = 0          # 지급 누적 골드(정보·검증용 지급 기록)
var paid_affinity: int = 0      # 지급 누적 호감도 포인트

signal changed                  # 수락/완료/만료/복원(프롬프트·진열 갱신 훅)

# ── 의뢰 생성(순수 함수 — day/주 시드에서 결정적 파생) ──────────────────────────
# 대상 아이템 풀. 실존 소스만 — 작물 5종 + 채집물(피안화). 카탈로그 파생이라 작물·채집물이 늘면
# 자동 따라온다(하드코딩 0). 정렬해 사전순으로 고정한다(Dictionary 키 순서에 의존 안 함 = 결정성).
static func item_pool() -> Array:
	var out: Array = CropCatalog.ids() + ItemCatalog.FORAGEABLES.keys()
	out.sort()
	return out

# 시드 문자열 → 결정적 RNG. 같은 문자열이면 항상 같은 수열이라, 같은 day는 몇 번을 조회해도
# 같은 의뢰가 나온다(비결정 랜덤·Time 계열 금지 — 헤드리스가 정확히 재현한다).
static func _rng(tag: String) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = hash(tag)
	return r

# day가 속한 주 인덱스(1~7일 = 0주, 8~14일 = 1주 …). 중기 의뢰의 시드이자 기한 기준.
static func week_of(day: int) -> int:
	return (maxi(day, 1) - 1) / WEEK_DAYS

# 그 주의 마지막 날(중기 기한). 0주 → 7일, 1주 → 14일 …
static func week_last_day(week: int) -> int:
	return (week + 1) * WEEK_DAYS

# 공통 생성기 — 시드에서 아이템·수량·의뢰인을 뽑고 보상까지 파생해 계약 dict를 만든다.
static func _make(kind: String, seed_n: int, post_day: int, due_day: int,
		count_min: int, count_max: int, affinity_points: int) -> Dictionary:
	var pool := item_pool()
	if pool.is_empty():
		return {}
	var r := _rng("%s:%d" % [kind, seed_n])
	var item_id: String = String(pool[r.randi() % pool.size()])
	var count: int = count_min + int(r.randi() % (count_max - count_min + 1))
	var client: String = String(CLIENTS[r.randi() % CLIENTS.size()])
	return {
		"key": "%s:%d" % [kind, seed_n],
		"kind": kind,
		"item_id": item_id,
		"count": count,
		"client": client,
		"post_day": post_day,
		"due_day": due_day,
		"gold": reward_gold(item_id, count),
		"affinity": affinity_points,
	}

# ★ [S3-T8] 타입 롤 — 그 시드가 물고기 의뢰 날인가. 전용 시드라 기존 의뢰 수열과 완전 독립.
static func _is_fish_day(kind: String, seed_n: int) -> bool:
	return _rng("%s_fish_day:%d" % [kind, seed_n]).randi() % FISH_KIND_DIE == 0

# ★ [S3-T8] 물고기 의뢰 생성기 — 현 절기 가용 어종(전설·기한 대비 과체급 배제)에서 시드 결정적으로
#   뽑는다. 절기는 post_day에서 파생하므로(주=7일·절기=28일이라 한 주가 절기를 못 걸침) 순수 함수다.
static func _make_fish(kind: String, seed_n: int, post_day: int, due_day: int) -> Dictionary:
	# 체급 상한 — 일일 = 중까지(이틀 기한에 대어 요구는 가혹·잠정) / 중기 = 소 한정(다수 납품 무게 조절).
	var max_class: int = FishCatalog.WC_MEDIUM if kind == KIND_DAILY else FishCatalog.WC_SMALL
	var pool := FishCatalog.quest_pool(GameClock.season_index_for_day(post_day), max_class)
	if pool.is_empty():
		return {}
	var r := _rng("%s_fish:%d" % [kind, seed_n])
	var item_id: String = String(pool[r.randi() % pool.size()])
	var count: int
	if kind == KIND_DAILY:
		# 수량 — 체급 반비례: 소 1~3 · 중 1~2(입질 가중상 중 체급이 6배쯤 귀하다 — S3-T3 CLASS_WEIGHT).
		var cmax: int = DAILY_COUNT_MAX if FishCatalog.weight_class_of(item_id) == FishCatalog.WC_SMALL else 2
		count = DAILY_COUNT_MIN + int(r.randi() % (cmax - DAILY_COUNT_MIN + 1))
	else:
		count = WEEKLY_FISH_COUNT_MIN + int(r.randi() % (WEEKLY_FISH_COUNT_MAX - WEEKLY_FISH_COUNT_MIN + 1))
	return {
		"key": "%s:%d" % [kind, seed_n],   # 슬롯 키는 유형 무관 동일(하루 1건·완료 이력 일원화)
		"kind": kind,
		"item_id": item_id,
		"count": count,
		"client": String(FISH_CLIENTS[r.randi() % FISH_CLIENTS.size()]),
		"post_day": post_day,
		"due_day": due_day,
		"gold": reward_gold(item_id, count),   # 보상 공식 무변경(일반품질가 ×3 ×수량)
		"affinity": DAILY_AFFINITY if kind == KIND_DAILY else WEEKLY_AFFINITY,
	}

# 그날 게시되는 일일 의뢰. 기한 = 게시일 포함 2일(수락 여부 무관 — 지나면 조용히 소멸).
# ★ [S3-T8] 물고기 날이면 물고기 계약으로 파생(풀이 비면 기존 경로 폴백 — 현 로스터엔 전 절기
#   상시종이 있어 실제로 비지 않는다).
static func daily_quest(day: int) -> Dictionary:
	if day < 1:
		return {}
	if _is_fish_day(KIND_DAILY, day):
		var fq := _make_fish(KIND_DAILY, day, day, day + DAILY_SPAN_DAYS - 1)
		if not fq.is_empty():
			return fq
	return _make(KIND_DAILY, day, day, day + DAILY_SPAN_DAYS - 1,
		DAILY_COUNT_MIN, DAILY_COUNT_MAX, DAILY_AFFINITY)

# 그 주에 걸리는 중기 의뢰. 기한 = 그 주 마지막 날까지(주당 1건). ★ [S3-T8] 물고기 갈래 동형.
static func weekly_quest(week: int) -> Dictionary:
	if week < 0:
		return {}
	if _is_fish_day(KIND_WEEKLY, week):
		var fq := _make_fish(KIND_WEEKLY, week, week * WEEK_DAYS + 1, week_last_day(week))
		if not fq.is_empty():
			return fq
	return _make(KIND_WEEKLY, week, week * WEEK_DAYS + 1, week_last_day(week),
		WEEKLY_COUNT_MIN, WEEKLY_COUNT_MAX, WEEKLY_AFFINITY)

# 보상 골드 = 일반품질 판매가 × REWARD_MULT × 수량. 품질 배수는 안 탄다(계약가는 일반품질 기준).
static func reward_gold(item_id: String, count: int) -> int:
	return ItemCatalog.price_of(item_id, ItemCatalog.Q_NORMAL) * REWARD_MULT * count

# ── 게시판 조회 ───────────────────────────────────────────────────────────────
# 오늘 그 종류로 걸린 의뢰({} = 없음 — 이미 완료했거나 미지 종류). 수락 UI·프롬프트가 쓴다.
func offer(day: int, kind: String) -> Dictionary:
	var q: Dictionary = {}
	match kind:
		KIND_DAILY:
			q = daily_quest(day)
		KIND_WEEKLY:
			q = weekly_quest(week_of(day))
		_:
			return {}
	if q.is_empty() or completed.has(String(q["key"])):
		return {}
	return q

# 오늘 게시판에 걸린 의뢰 전부(일일 → 중기 순). 완료분은 빠진다.
func offers(day: int) -> Array:
	var out: Array = []
	for kind in [KIND_DAILY, KIND_WEEKLY]:
		var q := offer(day, kind)
		if not q.is_empty():
			out.append(q)
	return out

# ── 수락(동시 1건) ────────────────────────────────────────────────────────────
func is_active() -> bool:
	return not active.is_empty()

# 지금 새 의뢰를 받을 수 있나 = 수락 중인 게 없다. 일일·중기를 통틀어 한 번에 하나다
# ([ADR-0060] 결정 6 "동시 1건 수락" — 스타듀 문법).
func can_accept() -> bool:
	return not is_active()

# 의뢰를 수락한다. 이미 수락 중이거나 빈/완료/기한 지난 의뢰면 false(무동작).
func accept(quest: Dictionary, day: int) -> bool:
	if not can_accept() or quest.is_empty():
		return false
	if completed.has(String(quest.get("key", ""))) or is_expired(quest, day):
		return false
	active = quest.duplicate(true)
	active["accepted_day"] = day
	changed.emit()
	return true

# ── 기한·만료(미완료 무페널티) ────────────────────────────────────────────────
static func is_expired(quest: Dictionary, day: int) -> bool:
	return not quest.is_empty() and day > int(quest.get("due_day", 0))

# 하루 경과 훅(main._on_day_advanced). 기한이 지난 수락분을 **조용히** 버린다 — 골드도 호감도도
# 건드리지 않는다([ADR-0060] 결정 6 "미완료 무페널티", ADR-0008 "평평≠막힘"). 만료된 의뢰를
# 돌려줘 main이 한 줄 알림만 띄운다(벌칙 아님). 만료 없으면 {}.
func advance_day(day: int) -> Dictionary:
	if not is_active() or not is_expired(active, day):
		return {}
	var dropped := active
	active = {}
	changed.emit()
	return dropped

# ── 납품(완료) ────────────────────────────────────────────────────────────────
# 수락 중인 의뢰의 요구 수량(없으면 0). main이 인벤토리 보유량과 견줘 진행을 보인다.
func required_count() -> int:
	return int(active.get("count", 0)) if is_active() else 0

func required_item() -> String:
	return String(active.get("item_id", "")) if is_active() else ""

# 지금 납품이 성립하나 = 수락 중 + 기한 안 + 보유량 충족. 아이템 차감은 호출자 몫이라
# 보유량(have)을 인자로 받는다(원장은 인벤토리를 모른다 — Museum.can_donate와 같은 결).
func can_complete(day: int, have: int) -> bool:
	return is_active() and not is_expired(active, day) and have >= required_count()

# 의뢰를 완료 처리한다(원장 기록만 — 아이템 소모·골드·호감도 지급은 main). 완료된 계약 dict를
# 돌려주고 active를 비운다. 성립 안 하면 {}(무동작).
func complete(day: int, have: int) -> Dictionary:
	if not can_complete(day, have):
		return {}
	var done := active
	completed.append(String(done["key"]))
	paid_gold += int(done.get("gold", 0))
	paid_affinity += int(done.get("affinity", 0))
	active = {}
	changed.emit()
	return done

func is_completed(key: String) -> bool:
	return completed.has(key)

func completed_count() -> int:
	return completed.size()

# ── 세이브/로드(슬라이스 키 "quest_board" 네임스페이스 — Museum 결) ─────────────
# 수락 상태(계약 스냅샷)·완료 이력·지급 기록만 든다. 게시 의뢰 자체는 day 파생이라 저장 대상이
# 아니다. 키 없는 구버전 세이브는 "수락 0·완료 0"으로 복원된다(하위호환).
func to_save() -> Dictionary:
	return {
		"active": active.duplicate(true),
		"completed": completed.duplicate(),
		"paid_gold": paid_gold,
		"paid_affinity": paid_affinity,
	}

func load_save(data: Dictionary) -> void:
	var a: Variant = data.get("active", {})
	active = (a as Dictionary).duplicate(true) if typeof(a) == TYPE_DICTIONARY else {}
	completed = []
	for k in data.get("completed", []):
		completed.append(String(k))
	paid_gold = int(data.get("paid_gold", 0))
	paid_affinity = int(data.get("paid_affinity", 0))
	changed.emit()

# ── 표시 도우미(프롬프트 한 줄) ────────────────────────────────────────────────
# "혼령초 ×2 — 미호 · 3일까지 · +120골드" 결의 요약 한 줄. main 프롬프트·알림이 공유한다.
static func summary(quest: Dictionary) -> String:
	if quest.is_empty():
		return ""
	return "%s ×%d — %s · %d일까지 · +%d골드" % [
		ItemCatalog.name_of(String(quest["item_id"])), int(quest["count"]),
		String(quest["client"]), int(quest["due_day"]), int(quest["gold"])]
