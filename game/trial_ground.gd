extends RefCounted
class_name TrialGround
# ★[S10-T8 / ADR-0069 결정 11] 명부 시련장 — 주간 시련 원장 + [시련패] 잔고 + 전용 상점표.
#
# 무엇인가: [나락] 심층에 열리는 **엔드게임 챌린지 보드**다(CONTEXT [명부 시련장]). 해방
#   ([ADR-0068] 척추 B7) 뒤의 코지 롱테일에서 "만렙 이후 할 일"을 잇는 두 축 중 하나이고,
#   나머지 하나가 [경지](mastery.gd)다. 서사가 아니라 **기량**을 재는 층이라 호감도·척추와
#   한 줄도 안 얽힌다([ADR-0016] 봉인 법칙 무접촉).
#
# 개방 게이트 = [반딧넋] 30([ADR-0069] 결정 10 · T7이 개통). ★ **그 술어를 여기서 다시 만들지
#   않는다** — `FireflySouls.gate_open()`(카운트 파생·저장 플래그 0)을 main이 그대로 소비하고,
#   이 파일은 문이 열렸는지조차 모른다(원장은 무대를 모른다 — QuestBoard가 게시판 좌표를 모르는 결).
#
# ★ 왜 `quest_board.gd`를 고치지 않고 새 파일인가([ADR-0069] 결정 11 "중기 의뢰 프레임 재사용"의
#   해석): 재사용하는 것은 **문법**이지 파일이 아니다. 게시판의 주 시드 수열은 이미 세이브를 타고
#   살아 있는 골든 서명이라, 거기에 시련 유형을 얹으면 기존 플레이어의 이번 주 의뢰가 바뀐다.
#   그래서 ㉠주 인덱스·기한 계산은 `QuestBoard.week_of`·`week_last_day`를 **호출**해 단일 출처를
#   지키고 ㉡롤 시드는 "trial:"로 시작하는 전용 네임스페이스만 쓴다(문자열이 갈리면 수열이 갈린다).
#   결과: quest_board.gd는 이 태스크에서 **한 바이트도 안 바뀐다**(trial_ground_test ⑦이 단언).
#
# 설계 메모(QuestBoard·Peddler·FireflySouls와 같은 결):
#   - 시련 자체는 **상태가 아니다** — 주 인덱스 시드에서 매번 결정적으로 파생한다. 원장이 드는 것은
#     수락 중 1건·완료 이력·시련패 잔고·1회성 구매 이력뿐이다.
#   - **전역 RNG 금지**: 모든 롤이 `hash("<네임스페이스>:<주>") → rand_from_seed` 믹싱 → % N이다
#     (weather.gd 헤더가 실증한 djb2 하위 비트 편향 회피 관례).
#   - 인벤토리·지갑·몹·화면을 **모른다**. 아이템 차감·처치 집계 호출·상점 지급은 전부 main이 조율한다.
#
# ★ [시련패]는 **인벤토리 아이템이 아니다**(반딧넋과 같은 판단 · CONTEXT [시련패] "냥과 교환되지
#   않는다"). 아이템으로 만들면 버리기·상자·출하·선물이라는 처분 경로가 전부 열려 전용 화폐라는
#   정의가 무너진다 — 아예 등재하지 않아 그 경로들이 **구조적으로 없다**(T7이 반딧넋에서 얻은 교훈).

signal changed()   # 수락/완료/만료/지급/구매/복원 프레임(main이 듣고 매대·프롬프트를 다시 세운다)

# ── 주기(주 1건 — [ADR-0069] 결정 11 "주간 시련 1건") ──────────────────────────
# ⚠️ 주 길이는 `QuestBoard.WEEK_DAYS`가 단일 출처다. const 초기화식에서 타 클래스 상수를 안 읽는
#   프로젝트 관례(MINE_ROCK_COST 주석) 탓에 숫자를 다시 적지 않고, 주 계산 자체를 QuestBoard 함수에
#   위임한다(아래 `week_of`·`due_day_of`). 그래서 여기엔 주 길이 상수가 아예 없다.

# ── 시련 유형(전부 **실존 활동**에서만 파생 — 소스 없는 콘텐츠 0) ─────────────────
# [ADR-0060] 결정 6이 처치형을 뺐던 사유("그 활동 자체가 없어")는 Slice 5가 전투를 실장하며
# 소멸했다. 시련장은 나락 심층의 무대라 **처치형이 이 층의 제 얼굴**이고, 납품형은 그 짝이다.
const KIND_SLAY := "trial_slay"        # 처치형 — 잡귀 N마리(진행은 원장이 센다 — 인벤에 안 남는 사건)
const KIND_DELIVER := "trial_deliver"  # 납품형 — 심층 광물 N개(보유량 기준 — QuestBoard.can_complete 결)

# ── 수량(전부 **잠정 — owner 큐** · ADR-0069 결정 1 폴리시 이월) ──────────────────
# 밴드 근거 = "한 주를 통째로 쓰진 않되 하루엔 안 끝난다". 게시판 중기(작물 5~8)보다 무겁게 잡은
# 것은 시련장이 **만렙 이후의 층**이라 같은 수량이면 체감이 없기 때문이다.
const SLAY_MIN := 12
const SLAY_MAX := 20
const DELIVER_MIN := 5
const DELIVER_MAX := 9

# 한 시련의 보상 [시련패](잠정 — owner 큐). 유형 무관 정액이다: 두 유형의 무게를 수량으로 이미
# 갈라 놨는데 보상까지 갈리면 "이번 주는 손해"가 생겨 주간 리듬이 눈치 게임이 된다.
const TOKEN_REWARD := 3

# ── 납품 풀(로스터 파생 — 하드코딩 목록 0) ────────────────────────────────────
# 심층 광물 밴드 = 정가 50~300냥. 위아래를 다 자르는 이유가 각각 있다:
#   · 하한 50 — 돌·명동 광석 같은 지천의 것을 요구하면 "시련"이 아니라 심부름이 된다
#   · 상한 300 — 명부금강(750)·오색혼옥(2000)은 들어오는 길이 좁아야 하는 물건이라([ADR-0063]
#     결정 2) 주간 의무 납품의 표적이 되면 그 희소성이 통째로 무너진다
# ★ 분모를 손으로 안 적는다 — `ItemCatalog.MINERALS`가 늘면 풀이 저절로 넓어진다.
const DELIVER_PRICE_MIN := 50
const DELIVER_PRICE_MAX := 300

# ── 상점표(결정 11 "품목은 레어크로우 ⑧·장식·편의 한정") ─────────────────────────
const SHOP_RARECROW := "trial_shop_rarecrow"   # 수집 스킨 1회성(획득처 ⑧ — 결정 4)
const SHOP_DECO := "trial_shop_deco"           # 장식 1회성(가구 세트 해금 — 진실원은 HomeDeco)
const SHOP_ITEM := "trial_shop_item"           # 편의 소모품(반복 구매 — 스택 아이템)

# ⚠️⚠️ **재점령 정지류 금지**([ADR-0055] · CONTEXT [시련패]) — 이 표에 "잡초가 안 돋게 한다",
#   "밤 재점령을 끈다", "성역 범위를 넓힌다" 류의 상품을 **절대 넣지 않는다**. 매일의 돌봄 라임이
#   곧 차등 재점령의 정체성이라, 그것을 돈으로 끄는 상품은 시스템을 부정한다. 아래 세 kind 말고는
#   어떤 kind도 없고(=효과를 파는 칸이 구조적으로 없다), trial_ground_test ⑤가 이 성질을
#   ㉠kind 화이트리스트 ㉡아이템 카테고리 ㉡낫·잡초·개간 계열 id 부재로 삼중 단언한다.
const SHOP_KINDS := [SHOP_RARECROW, SHOP_DECO, SHOP_ITEM]

# ★ 재점령을 멈추는 상품이 아님을 **코드로** 못 박는 금지 목록(테스트가 이 배열과 상점표를 대조).
#   여기 적힌 것은 "팔면 안 되는 물건"이 아니라 **"팔면 안 되는 축"의 표본**이다 — 개간·잡초
#   도메인에 속한 어떤 id도 상점표에 못 선다는 뜻이다(DebrisCatalog 계열 · 낫 · 혼백섬유).
const RECLAIM_BANNED_IDS := [
	"scythe",            # ItemCatalog.SCYTHE — 낫(잡초 대응 도구)
	"honbaek_seomyu",    # 잡초 드랍(혼백섬유) — 재점령 도메인의 산출
	"weeds",             # DebrisCatalog.WEEDS
	"eophwaseok",        # DebrisCatalog 업화석
	"petrified_stump",   # DebrisCatalog 석화 고목
]

# 상점표 — **선언 순이 곧 진열 순**이다(레어크로우 → 장식 → 편의: 희소한 것이 위).
# 값은 전부 [시련패] 단위이고 **잠정 — owner 큐**다. 밴드 근거:
#   · 주 1건 × 3패 = 주당 3패라, 12패 = 4주(한 절기의 절반)가 레어크로우 ⑧의 값이다
#   · 20패 = 7주 — 장식 한 세트를 시련패로 사는 길은 "냥으로도 살 수 있는 것의 대안"이지
#     지름길이 아니어야 한다(목공방 3,000냥·야시장·보부상과 경쟁하되 이기지 않는다)
#   · 소모품 1~2패 = 매주 한 줌씩 챙겨 가는 편의(반복 구매라 값이 낮아야 리듬이 산다)
const SHOP := [
	# ★[ADR-0069 결정 4 획득처 ⑧] 레어크로우 ⑧ — 8슬롯의 **마지막 칸**이다(T2가 ①~④·⑥·⑦,
	#   T3이 ⑤를 채웠고 여기가 닫는 자리). id 상수의 진실원은 ItemCatalog.RARECROW_8.
	{"kind": SHOP_RARECROW, "buy_id": "rarecrow_8", "price": 12, "once": true},
	# 장식 — 가구 세트 「잿눈」. ★ 해금 진실원은 **HomeDeco**다(야시장·보부상이 지키는 그 규율
	#   1:1 — 이중 진실원 0). 여기선 "무엇을 얼마에 파나"만 안다.
	{"kind": SHOP_DECO, "buy_id": "JAETNUN", "price": 20, "once": true},
	# 편의 소모품 — 셋 다 **이미 다른 창구에서 냥으로 팔리는 물건**이다(새 힘 0). 시련패는
	#   "다른 값으로 사는 길"을 열 뿐이고, 어느 것도 배수·확률·속도에 영구히 손대지 않는다.
	{"kind": SHOP_ITEM, "buy_id": "fert_deluxe", "price": 1, "once": false},    # ItemCatalog.FERT_DELUXE
	{"kind": SHOP_ITEM, "buy_id": "myeongbuhwan", "price": 1, "once": false},   # ItemCatalog.MYEONGBUHWAN
	{"kind": SHOP_ITEM, "buy_id": "bait_pledge", "price": 2, "once": false},    # GearCatalog.BAIT_PLEDGE
]

# ── 원장(세이브 대상 — 파생 불가능한 것만) ────────────────────────────────────
var active: Dictionary = {}   # 수락 중인 시련 1건({} = 없음). 계약 스냅샷이라 통째 직렬화한다.
var completed: Array = []     # 완료한 시련 key 목록(같은 주 중복 완료 방지 — QuestBoard.completed 결)
var tokens: int = 0           # [시련패] 잔고(전용 화폐 — 냥과 교환되지 않는다)
var earned_tokens: int = 0    # 누적 획득 시련패(정보·검증용 지급 기록 — QuestBoard.paid_gold 결)
var bought: Array = []        # 1회성 상점 구매 이력(레어크로우 ⑧·가구 세트)

# ── 주 계산(QuestBoard에 위임 — 주 길이의 단일 출처 보존) ──────────────────────
static func week_of(day: int) -> int:
	return QuestBoard.week_of(day)

# 그 주 시련의 기한 = 그 주 마지막 날(중기 의뢰와 같은 문법).
static func due_day_of(week: int) -> int:
	return QuestBoard.week_last_day(week)

# ── 롤(결정적 · 전역 RNG 0 — 프로젝트 관례: hash → rand_from_seed 믹싱 → % N) ────
# ★ 네임스페이스가 전부 "trial"로 시작해 QuestBoard("daily:"·"weekly:"·"*_fish_day:"·"*_fish:")·
#   Peddler("peddler:*")·FireflySouls("firefly*")의 어느 스트림과도 안 얽힌다.
static func _roll(ns: String, seed_n: int, modulo: int) -> int:
	return absi(rand_from_seed(hash("%s:%d" % [ns, seed_n]))[0]) % maxi(modulo, 1)

# ── 납품 풀(로스터 파생) ─────────────────────────────────────────────────────
# 반환 = 광물 id 배열(정렬 — 사전순 고정. Dictionary 키 순서에 안 기댄다 = 결정성).
static func deliver_pool() -> Array:
	var out: Array = []
	for id in ItemCatalog.MINERALS:
		var sid := String(id)
		var price := int(ItemCatalog.MINERALS[id].get("price", 0))
		if price >= DELIVER_PRICE_MIN and price <= DELIVER_PRICE_MAX:
			out.append(sid)
	out.sort()
	return out

# ── 시련 파생(순수 함수 — 주 시드 하나면 답이 통째로 나온다) ────────────────────
# 그 주에 걸리는 시련 1건. week < 0 = {}(손상 방어).
# ★ 유형 롤 → 유형별 전용 시드. 유형이 갈려도 **key는 같다**(주당 1건 · 완료 이력 일원화 —
#   QuestBoard가 물고기 갈래에서 key를 통일한 그 판단 1:1).
static func weekly_trial(week: int) -> Dictionary:
	if week < 0:
		return {}
	var due := due_day_of(week)
	var key := "trial:%d" % week
	if _roll("trial:kind", week, 2) == 0:
		var n := SLAY_MIN + _roll("trial:slay", week, SLAY_MAX - SLAY_MIN + 1)
		return {"key": key, "kind": KIND_SLAY, "count": n, "progress": 0,
			"week": week, "due_day": due, "tokens": TOKEN_REWARD}
	var pool := deliver_pool()
	if pool.is_empty():
		return {}
	var item_id := String(pool[_roll("trial:item", week, pool.size())])
	var cnt := DELIVER_MIN + _roll("trial:count", week, DELIVER_MAX - DELIVER_MIN + 1)
	return {"key": key, "kind": KIND_DELIVER, "item_id": item_id, "count": cnt,
		"week": week, "due_day": due, "tokens": TOKEN_REWARD}

# 오늘 걸린 시련({} = 없음 — 이미 완료한 주). 수락 UI·프롬프트가 쓴다.
func offer(day: int) -> Dictionary:
	var t := weekly_trial(week_of(day))
	if t.is_empty() or completed.has(String(t["key"])):
		return {}
	return t

# ── 수락(동시 1건 — 게시판과 같은 규율) ───────────────────────────────────────
func is_active() -> bool:
	return not active.is_empty()

func can_accept() -> bool:
	return not is_active()

static func is_expired(trial: Dictionary, day: int) -> bool:
	return not trial.is_empty() and day > int(trial.get("due_day", 0))

# 시련을 수락한다. 이미 수락 중이거나 빈/완료/기한 지난 시련이면 false(무동작).
func accept(trial: Dictionary, day: int) -> bool:
	if not can_accept() or trial.is_empty():
		return false
	if completed.has(String(trial.get("key", ""))) or is_expired(trial, day):
		return false
	active = trial.duplicate(true)
	active["accepted_day"] = day
	active["progress"] = 0        # 처치 진행은 늘 0에서 시작한다(수락 전 처치는 안 세 준다)
	changed.emit()
	return true

# ── 기한·만료(미완료 무페널티 — ADR-0008 "평평≠막힘") ─────────────────────────
# 하루 경과 훅. 기한이 지난 수락분을 **조용히** 버린다(시련패도 아무것도 안 깎는다).
# 만료된 계약을 돌려줘 main이 한 줄 알림만 띄운다. 만료 없으면 {}.
func advance_day(day: int) -> Dictionary:
	if not is_active() or not is_expired(active, day):
		return {}
	var dropped := active
	active = {}
	changed.emit()
	return dropped

# ── 진행(처치형 — 원장이 직접 센다) ──────────────────────────────────────────
func required_count() -> int:
	return int(active.get("count", 0)) if is_active() else 0

func required_item() -> String:
	return String(active.get("item_id", "")) if is_active() else ""

func kind_of_active() -> String:
	return String(active.get("kind", "")) if is_active() else ""

func progress() -> int:
	return int(active.get("progress", 0)) if is_active() else 0

# 잡귀 하나를 처치했다(main._on_mob_killed 훅). **처치형 수락 중일 때만** 센다 —
# 수락 전 처치를 소급하지 않는 것은 "시련은 받고 나서 치른다"는 계약의 뜻 그대로다.
# 상한에서 멈춘다(초과 처치가 진행에 안 쌓임 = 표시가 안 넘친다). 실제로 셌으면 true.
func note_kill(day: int) -> bool:
	if kind_of_active() != KIND_SLAY or is_expired(active, day):
		return false
	var p := progress()
	if p >= required_count():
		return false
	active["progress"] = p + 1
	changed.emit()
	return true

# ── 완료 ─────────────────────────────────────────────────────────────────────
# 지금 완료가 성립하나. `have` = 납품형일 때 그 아이템의 인벤 보유량(원장은 백팩을 모른다 —
# QuestBoard.can_complete와 같은 결). 처치형은 have를 안 본다(진행이 원장 안에 있다).
func can_complete(day: int, have: int) -> bool:
	if not is_active() or is_expired(active, day):
		return false
	if kind_of_active() == KIND_SLAY:
		return progress() >= required_count()
	return have >= required_count()

# 완료 처리(원장 기록 + **시련패 지급까지**). 아이템 차감은 main 몫이다.
# ★ 시련패만은 여기서 적립하는 이유: 인벤토리를 안 거치는 전용 화폐라 "받을 자리가 없다"가
#   구조적으로 없고, 지급을 밖에 두면 원장과 잔고가 어긋날 자리가 생긴다(FireflySouls가
#   답례를 밖에 둔 것과 반대인데, 저쪽은 물건이라 백팩 가득이 실재하기 때문이다).
# 반환 = 완료된 계약 dict({} = 무동작).
func complete(day: int, have: int) -> Dictionary:
	if not can_complete(day, have):
		return {}
	var done := active
	completed.append(String(done["key"]))
	var pay := int(done.get("tokens", TOKEN_REWARD))
	tokens += pay
	earned_tokens += pay
	active = {}
	changed.emit()
	return done

func is_completed(key: String) -> bool:
	return completed.has(key)

func completed_count() -> int:
	return completed.size()

# ── 상점(표 파생 — 잔고·구매 이력은 원장) ─────────────────────────────────────
static func shop_row(buy_id: String) -> Dictionary:
	for r in SHOP:
		if String(r["buy_id"]) == buy_id:
			return r
	return {}

static func price_of(buy_id: String) -> int:
	var r := shop_row(buy_id)
	return int(r.get("price", 0)) if not r.is_empty() else 0

static func is_once(buy_id: String) -> bool:
	var r := shop_row(buy_id)
	return not r.is_empty() and bool(r.get("once", false))

# 상점 전 행(선언 순). 잠금 표시(1회성 기구매)는 main이 `has_bought`로 붙인다.
static func shop_rows() -> Array:
	return SHOP.duplicate(true)

func has_bought(id: String) -> bool:
	return bought.has(id)

# 지금 이 품목을 살 수 있나 = 표에 있고 · 1회성이면 미구매 · 잔고 충족.
func can_buy(buy_id: String) -> bool:
	var price := price_of(buy_id)
	if price <= 0:
		return false
	if is_once(buy_id) and has_bought(buy_id):
		return false
	return tokens >= price

# 결제한다(원장만 — 물건 지급·해금은 main). 성공 시 차감된 값, 실패면 0.
# ★ **1회성은 여기서 이력을 적는다**(반복 구매는 안 적는다 — 적을 이유가 없다).
func spend(buy_id: String) -> int:
	if not can_buy(buy_id):
		return 0
	var price := price_of(buy_id)
	tokens -= price
	if is_once(buy_id) and not bought.has(buy_id):
		bought.append(buy_id)
	changed.emit()
	return price

# ── 세이브/로드(슬라이스 키 "trial_ground" 네임스페이스 — QuestBoard·Peddler 결) ──
# 키 없는 구세이브 = "수락 0 · 완료 0 · 시련패 0 · 구매 0"으로 복원된다(하위호환 · 막히는 것 0 —
# 문은 반딧넋 카운트가 여는 것이라 이 조각이 없어도 다음 주 시련이 그대로 걸린다).
func to_save() -> Dictionary:
	return {
		"active": active.duplicate(true),
		"completed": completed.duplicate(),
		"tokens": tokens,
		"earned_tokens": earned_tokens,
		"bought": bought.duplicate(),
	}

func load_save(data: Dictionary) -> void:
	var a: Variant = data.get("active", {})
	active = (a as Dictionary).duplicate(true) if typeof(a) == TYPE_DICTIONARY else {}
	completed = []
	for k in data.get("completed", []):
		completed.append(String(k))
	tokens = maxi(int(data.get("tokens", 0)), 0)
	earned_tokens = maxi(int(data.get("earned_tokens", 0)), 0)
	bought = []
	var raw: Variant = data.get("bought", [])
	if typeof(raw) == TYPE_ARRAY:
		for id in raw:
			var sid := String(id)
			# 표에서 사라진 품목은 조용히 버린다(Peddler.load_save·RarecrowLedger와 같은 결 —
			# 되살릴 수 없는 것을 원장에 남기면 매대에 정체불명의 잠금이 선다).
			if sid != "" and not bought.has(sid) and not shop_row(sid).is_empty():
				bought.append(sid)
	changed.emit()

# ── 표시 도우미(프롬프트 한 줄 — QuestBoard.summary 결) ────────────────────────
static func summary(trial: Dictionary) -> String:
	if trial.is_empty():
		return ""
	if String(trial["kind"]) == KIND_SLAY:
		return "잡귀 %d마리 처치 — %d일까지 · 시련패 +%d" % [
			int(trial["count"]), int(trial["due_day"]), int(trial.get("tokens", TOKEN_REWARD))]
	return "%s ×%d 납품 — %d일까지 · 시련패 +%d" % [
		ItemCatalog.name_of(String(trial["item_id"])), int(trial["count"]),
		int(trial["due_day"]), int(trial.get("tokens", TOKEN_REWARD))]
