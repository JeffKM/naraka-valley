extends Node
class_name Books
# ★[S9-T7 / ADR-0067 결정 8 · ADR-0034 이행] 옥자 Books 채널 — 아이템 테이블 · 입수 롤 · 수집 원장.
#
# 목적: 옥자는 게임 중 호감도 미터가 없는 앵커라([ADR-0032]) 플레이어가 옥자를 **알아갈 능동
#       채널**이 비어 있다. [ADR-0034]가 지정한 그 채널이 이것이다 — 그날 밤 대화재로 흩어진
#       옥자의 것을 세계 곳곳에서 되찾으며 옥자·세계·조연 로어가 한 조각씩 드러난다.
#
# 두 형태(한 파이프라인 — ADR-0034 #1):
#   · **[옥자의 잃어버린 책들] 8권** = 답을 읽히는 무거운 한 챕터. 귀하고 **혼백관 전시 대상**이다.
#   · **[비밀 노트] 15장** = 질문을 흘리는 짧은 속삭임. 넓고 흔하며 **전시 대상이 아니다**
#     (떡밥은 유품이 아니다 — 전시대에 세울 물건이 아니라 주머니에 접어 넣는 종이다).
#
# 설계 메모:
#   - mailbox.gd와 **같은 결의 상태 노드**다: 단일 책임(수집 원장) + 얇은 to_save/load_save.
#     어디서 굴리는지·무엇을 대화창에 띄우는지는 전부 main이 조율하고, 이 노드는 "무엇을 주웠고
#     무엇을 읽었나"만 안다(DialogueBox·Inventory를 모른다).
#   - **텍스트는 전부 placeholder다(T8이 본문을 채운다).** 지금 여기 있는 것은 *그릇*이다 —
#     행을 고쳐 쓰는 것이 본문 반영의 전부이고 코드는 0줄 바뀐다(gift_prefs·LETTERS 규약 동형).
#   - ★ `lines`는 **평 Array**로 둔다(PackedStringArray 생성자는 const 표현식이 아니라 파스 에러).
#     변환은 `lines_of`가 한 자리에서 한다.
#   - ★ **메카닉 0**([ADR-0034] #4): 책은 영구 % 곱셈도, flat 범프도 주지 않는다. 보상은 *서사와
#     수집 자체*다. 이 파일에 XP·가격·배수 상수가 하나도 없는 것이 그 결정의 구조적 표현이다.
#     (저승 실용서 = XP 범프 트랙은 이 파일과 무관한 별 트랙이며 이번 슬라이스 밖이다.)
#   - ★ **선물 불가**(#7)·**비매**: 판정은 ItemCatalog(price 0)·GiftPrefs(CAT_BOOK 배제)가 지고
#     여기는 데이터만 든다. 되찾은 옥자의 유품 키프세이크라 남에게 건네는 것이 톤 위반이다.

# ── 텍스트 테이블 ────────────────────────────────────────────────────────────
# id → { "title": 표시명(인벤·대화창 이름판), "lines": 본문 줄들(평 Array), "note": 트리거/배치 메모 }
#
# ★ 지금 본문은 전부 **중립 placeholder 1~2줄**이다. T8이 [ADR-0067] 결정 8의 봉인 법칙
#   체크리스트(증거·공명만 / 중심 평결 금지 / 세 조각 금지 / 잇는 여지 남기기)를 통과시키며
#   이 자리에 실제 로어를 붓는다. **placeholder도 그 체크리스트를 이미 만족한다**(아무것도
#   서술하지 않으므로) — books_test의 금칙어 스캔이 그 성질을 회귀로 잠근다.
const BOOK_PREFIX := "book_okja_"
const NOTE_PREFIX := "note_secret_"

const BOOK_COUNT := 8    # [옥자의 잃어버린 책들] 권수(ADR-0067 결정 8 볼륨 — 잠정·owner 큐)
const NOTE_COUNT := 15   # [비밀 노트] 장수(같은 잠정)

# 되찾은 책 — 무거운 한 챕터. 전시 대상(혼백관 좌대 8좌).
const BOOKS := {
	"book_okja_1": {
		"title": "옥자의 잃어버린 책 ①",
		"lines": [
			"그을린 표지의 책이다. 페이지가 서로 눌어붙어 있다.",
			"…(빛바랜 글씨 — 내용은 아직 읽히지 않는다)",
		],
		"note": "T8 본문 주입 자리 — 옥자 인물/약사 결",
	},
	"book_okja_2": {
		"title": "옥자의 잃어버린 책 ②",
		"lines": [
			"물에 한 번 젖었다 마른 책이다. 종이가 우글쭈글하다.",
			"…(빛바랜 글씨 — 내용은 아직 읽히지 않는다)",
		],
		"note": "T8 본문 주입 자리 — 세계 규칙 결",
	},
	"book_okja_3": {
		"title": "옥자의 잃어버린 책 ③",
		"lines": [
			"표지가 뜯겨 나가고 속장만 남은 책이다.",
			"…(빛바랜 글씨 — 내용은 아직 읽히지 않는다)",
		],
		"note": "T8 본문 주입 자리 — 지리/역사 결",
	},
	"book_okja_4": {
		"title": "옥자의 잃어버린 책 ④",
		"lines": [
			"실로 꿰맨 자국이 여러 번 덧대어진 책이다.",
			"…(빛바랜 글씨 — 내용은 아직 읽히지 않는다)",
		],
		"note": "T8 본문 주입 자리 — 조연 사연 결",
	},
	"book_okja_5": {
		"title": "옥자의 잃어버린 책 ⑤",
		"lines": [
			"모서리가 새까맣게 탄 책이다. 가운데는 멀쩡하다.",
			"…(빛바랜 글씨 — 내용은 아직 읽히지 않는다)",
		],
		"note": "T8 본문 주입 자리 — 그날 밤의 *세계측* 조각",
	},
	"book_okja_6": {
		"title": "옥자의 잃어버린 책 ⑥",
		"lines": [
			"낡은 끈으로 묶인 책이다. 매듭이 단단하다.",
			"…(빛바랜 글씨 — 내용은 아직 읽히지 않는다)",
		],
		"note": "T8 본문 주입 자리 — 환경적 공명",
	},
	"book_okja_7": {
		"title": "옥자의 잃어버린 책 ⑦",
		"lines": [
			"먼지가 두껍게 앉은 책이다. 손자국이 하나 남아 있다.",
			"…(빛바랜 글씨 — 내용은 아직 읽히지 않는다)",
		],
		"note": "T8 본문 주입 자리 — 옥자 생전",
	},
	# ★ ⑧은 [ADR-0034] #6의 「옥자의 잃어버린 레시피」 자리다 — 히든 융합 메뉴 1종의 해금 표적.
	#   **해금 배선 자체는 이번 슬라이스 밖**이고(발견 게이트 = ADR-0064 소관), 여기는 그 자리가
	#   실존한다는 것까지만 한다(나락 열쇠가 아이템으로 먼저 등록되고 점등은 다음 태스크가 한
	#   그 선례 동형).
	"book_okja_8": {
		"title": "옥자의 잃어버린 책 ⑧ — 조리 기록",
		"lines": [
			"약재 이름과 계량이 빼곡한 공책이다. 요리책 같기도 하다.",
			"…(빛바랜 글씨 — 내용은 아직 읽히지 않는다)",
		],
		"note": "T8 본문 주입 자리 — ADR-0034 #6 히든 융합 레시피(해금 배선은 후속)",
	},
}

# 비밀 노트 — 짧은 속삭임. 세계 전체의 텍스처이고 **전시 대상이 아니다**.
const NOTES := {
	"note_secret_1": {"title": "비밀 노트 ①", "lines": ["접힌 자국이 깊은 쪽지다.", "…(글씨가 번져 아직 읽히지 않는다)"], "note": "T8 주입 자리"},
	"note_secret_2": {"title": "비밀 노트 ②", "lines": ["귀퉁이가 찢긴 쪽지다.", "…(글씨가 번져 아직 읽히지 않는다)"], "note": "T8 주입 자리"},
	"note_secret_3": {"title": "비밀 노트 ③", "lines": ["누군가 급히 적은 듯한 쪽지다.", "…(글씨가 번져 아직 읽히지 않는다)"], "note": "T8 주입 자리"},
	"note_secret_4": {"title": "비밀 노트 ④", "lines": ["뒷면에 숫자만 몇 개 적힌 쪽지다.", "…(글씨가 번져 아직 읽히지 않는다)"], "note": "T8 주입 자리"},
	"note_secret_5": {"title": "비밀 노트 ⑤", "lines": ["물기에 눌린 자국이 남은 쪽지다.", "…(글씨가 번져 아직 읽히지 않는다)"], "note": "T8 주입 자리"},
	"note_secret_6": {"title": "비밀 노트 ⑥", "lines": ["재가 묻은 쪽지다.", "…(글씨가 번져 아직 읽히지 않는다)"], "note": "T8 주입 자리"},
	"note_secret_7": {"title": "비밀 노트 ⑦", "lines": ["실로 묶였던 구멍이 남은 쪽지다.", "…(글씨가 번져 아직 읽히지 않는다)"], "note": "T8 주입 자리"},
	"note_secret_8": {"title": "비밀 노트 ⑧", "lines": ["반듯하게 잘린 쪽지다.", "…(글씨가 번져 아직 읽히지 않는다)"], "note": "T8 주입 자리"},
	"note_secret_9": {"title": "비밀 노트 ⑨", "lines": ["봉투 안쪽을 뜯어 쓴 쪽지다.", "…(글씨가 번져 아직 읽히지 않는다)"], "note": "T8 주입 자리"},
	"note_secret_10": {"title": "비밀 노트 ⑩", "lines": ["가장자리가 눌어붙은 쪽지다.", "…(글씨가 번져 아직 읽히지 않는다)"], "note": "T8 주입 자리"},
	"note_secret_11": {"title": "비밀 노트 ⑪", "lines": ["두 번 접어 넣어 둔 쪽지다.", "…(글씨가 번져 아직 읽히지 않는다)"], "note": "T8 주입 자리"},
	"note_secret_12": {"title": "비밀 노트 ⑫", "lines": ["잉크가 한쪽으로 쏠린 쪽지다.", "…(글씨가 번져 아직 읽히지 않는다)"], "note": "T8 주입 자리"},
	"note_secret_13": {"title": "비밀 노트 ⑬", "lines": ["손바닥만 한 얇은 쪽지다.", "…(글씨가 번져 아직 읽히지 않는다)"], "note": "T8 주입 자리"},
	"note_secret_14": {"title": "비밀 노트 ⑭", "lines": ["말려 있던 자국이 그대로 남은 쪽지다.", "…(글씨가 번져 아직 읽히지 않는다)"], "note": "T8 주입 자리"},
	"note_secret_15": {"title": "비밀 노트 ⑮", "lines": ["끝줄만 유난히 진하게 눌러 쓴 쪽지다.", "…(글씨가 번져 아직 읽히지 않는다)"], "note": "T8 주입 자리"},
}

# ── 입수 원천(플레이 부산물 — ADR-0067 결정 8) ────────────────────────────────
# **한 활동에 몰지 않는 이유**: 어떤 플레이 스타일이든 로어를 만나게 하기 위해서다. 농사만
# 짓는 사람도, 갱도만 파는 사람도, 낚시만 하는 사람도 같은 이야기에 닿아야 한다.
const SRC_MINE := "mine"        # 갱도 채굴 — 광맥/돌을 부순 사건마다
const SRC_FISH := "fish"        # 낚시 — 포획 성공마다(인양 롤 다음 가지)
const SRC_FORAGE := "forage"    # 미혹의 숲 희소 채집 — 미혹 구역 채집 줍기마다
const SRC_DEBRIS := "debris"    # 농장 debris — 개간 한 칸마다

# 원천별 드랍 확률(퍼밀 · 0..999 롤 대비). **잠정값 — owner 큐**(ADR-0067 결정 12 결).
# 밴드 근거는 *활동 빈도의 역수*다: 한 판에 수십 번 굴리는 채굴·개간은 낮게, 한 번이 무거운
# 낚시 포획·미혹 희소 채집은 높게 둬 **어느 축으로 놀아도 비슷한 속도로 만나게** 한다.
#   · 채광 15퍼밀(1.5%/부순 돌) — 층 하나에 돌이 수십이라 실효 조우가 가장 잦은 축
#   · 낚시 40퍼밀(4%/포획)     — 인양 롤(30퍼밀)과 같은 밴드. 낚시 한 판 = 몇 마리다
#   · 채집 70퍼밀(7%/줍기)     — 미혹 희소 채집은 하루 몇 자리뿐이라 가장 높다
#   · 개간 10퍼밀(1%/한 칸)    — 초반 개간은 수백 칸이라 가장 낮다
const DROP_PERMIL := {
	SRC_MINE: 15,
	SRC_FISH: 40,
	SRC_FORAGE: 70,
	SRC_DEBRIS: 10,
}

# 드랍이 걸린 뒤 **무엇이 나오나** — 노트가 흔하고 책이 귀하다(ADR-0034 #1 "노트=넓음·흔함 /
# 책=귀함"의 수치 표현). 700퍼밀 이상이면 책, 미만이면 노트.
const BOOK_SHARE_PERMIL := 700

# ── 원장(세이브 대상) ─────────────────────────────────────────────────────────
var acquired: Dictionary = {}     # id → 주운 day(int). 있으면 = 이미 세상에서 나왔다(중복 입수 0)
var read_ledger: Dictionary = {}  # id → true(읽음). 주운 순간 즉독이 보통이지만, 대화 중 주우면 미독으로 남는다

# ★ 책장 재읽기 커서는 **세이브하지 않는다**(휘발). 진행이 아니라 "지금 어디까지 넘겨 봤나"라
#   이어하기가 기억할 값이 아니다 — 이어하면 처음부터 다시 넘긴다(_talking_to와 같은 결).
var _shelf_cursor: int = 0

signal changed()   # 입수·열람·복원 프레임(main이 배지·전시·프롬프트를 다시 그린다)

# ── 테이블 조회(정적 — 어디서든 Books.title_of(id)) ───────────────────────────
static func is_book(id: String) -> bool:
	return BOOKS.has(id)

static func is_note(id: String) -> bool:
	return NOTES.has(id)

# 이 id가 CAT_BOOK 아이템인가(책 ∪ 노트). ItemCatalog._is_book이 이 한 술어에 위임한다.
static func has_text(id: String) -> bool:
	return BOOKS.has(id) or NOTES.has(id)

static func _row(id: String) -> Dictionary:
	if BOOKS.has(id):
		return BOOKS[id]
	if NOTES.has(id):
		return NOTES[id]
	return {}

static func title_of(id: String) -> String:
	return str(_row(id).get("title", ""))

# 본문 줄들(평 Array → PackedStringArray 변환은 여기 한 자리에서).
static func lines_of(id: String) -> PackedStringArray:
	var out := PackedStringArray()
	var raw: Variant = _row(id).get("lines", [])
	var t := typeof(raw)
	if t != TYPE_ARRAY and t != TYPE_PACKED_STRING_ARRAY:
		return out
	for ln in raw:
		out.append(str(ln))
	return out

static func book_ids() -> Array:
	return BOOKS.keys()

static func note_ids() -> Array:
	return NOTES.keys()

# 전 id(책 먼저·선언 순). ItemCatalog.ids_in_category·수집 트래커 분모가 쓴다.
static func all_ids() -> Array:
	var out: Array = BOOKS.keys()
	out.append_array(NOTES.keys())
	return out

# ── 입수 롤(순수 — 결정적) ────────────────────────────────────────────────────
# ★ 프로젝트 관례: `hash("<네임스페이스>:<day>:<serial>")` → **`rand_from_seed` 믹싱** → % N.
#   해시값을 바로 %로 접으면 djb2 하위 비트 편향으로 특정 분위가 통째로 비는 사고가 있었다
#   (weather.gd 헤더의 그 실증 — S7). 네임스페이스가 원천마다 달라 네 축이 서로 안 얽힌다.
static func _roll(ns: String, day: int, serial: int, modulo: int) -> int:
	return absi(rand_from_seed(hash("%s:%d:%d" % [ns, day, serial]))[0]) % maxi(modulo, 1)

# 이 원천의 드랍 확률(퍼밀). 모르는 원천은 0 = 절대 안 나옴(오타 방어).
static func permil_of(source: String) -> int:
	return int(DROP_PERMIL.get(source, 0))

# **무엇이 나오는가**(순수 함수 — 원장을 인자로 받는다). "" = 이번엔 없음.
#   ㉠ 게이트 롤: 원천별 퍼밀 미만이면 통과
#   ㉡ 종류 롤: 책이냐 노트냐(BOOK_SHARE_PERMIL)
#   ㉢ 지목 롤: **아직 안 주운 것들 중에서만** 뽑는다(중복 입수 0 — 같은 책이 두 번 나오면
#      수집이 아니라 버그로 읽힌다. mailbox.send의 멱등과 같은 판단)
#   ㉣ 고른 종류가 이미 동나면 **다른 종류로 넘어간다**(막힘 0 — 책을 다 모은 사람에게도
#      노트는 계속 나오고, 그 반대도 같다). 둘 다 동나면 "".
static func peek_drop(source: String, day: int, serial: int, owned: Dictionary) -> String:
	var permil := permil_of(source)
	if permil <= 0:
		return ""
	if _roll("book:" + source, day, serial, 1000) >= permil:
		return ""
	var want_book := _roll("bookkind:" + source, day, serial, 1000) >= BOOK_SHARE_PERMIL
	var pool := _remaining(BOOKS.keys() if want_book else NOTES.keys(), owned)
	if pool.is_empty():
		pool = _remaining(NOTES.keys() if want_book else BOOKS.keys(), owned)
	if pool.is_empty():
		return ""
	return str(pool[_roll("bookpick:" + source, day, serial, pool.size())])

# 아직 안 주운 id만 추린다(선언 순 보존 — 뽑기 인덱스가 결정적이려면 순서가 안정해야 한다).
static func _remaining(ids: Array, owned: Dictionary) -> Array:
	var out: Array = []
	for id in ids:
		if not owned.has(id):
			out.append(id)
	return out

# 인스턴스 창구 — 지금 원장으로 이번 롤의 결과를 본다(적재는 아직 안 한다).
# ★ **지목과 적재를 가른** 이유: 인벤이 가득이면 주울 수 없는데, 원장에 먼저 적으면 그 책이
#   세상에서 영영 사라진다(수집 완주 불가 = 치명). main은 add_item이 성공한 뒤에만 acquire한다.
func pending_drop(source: String, day: int, serial: int) -> String:
	return peek_drop(source, day, serial, acquired)

# ── 원장 ──────────────────────────────────────────────────────────────────────
# 주웠다고 적는다. 이미 있는 id·테이블에 없는 id는 false(멱등).
func acquire(id: String, day: int) -> bool:
	if not has_text(id) or acquired.has(id):
		return false
	acquired[id] = day
	changed.emit()
	return true

func has_acquired(id: String) -> bool:
	return acquired.has(id)

func acquired_count() -> int:
	return acquired.size()

# 주운 책 수 / 노트 수(수집 트래커 표기 — 두 형태를 따로 센다).
func acquired_book_count() -> int:
	var n := 0
	for id in acquired:
		if is_book(str(id)):
			n += 1
	return n

func acquired_note_count() -> int:
	return acquired_count() - acquired_book_count()

# 읽음 처리. 주운 적 없는 id는 무시한다(늦은 입력·손상 호출 방어). 이미 읽었으면 조용히 false.
func mark_read(id: String) -> bool:
	if not acquired.has(id) or read_ledger.has(id):
		return false
	read_ledger[id] = true
	changed.emit()
	return true

func is_read(id: String) -> bool:
	return read_ledger.has(id)

func unread_count() -> int:
	var n := 0
	for id in acquired:
		if not read_ledger.has(str(id)):
			n += 1
	return n

# 주운 순서대로 나열한다(day 오름차순 → 같은 날이면 선언 순). 책장 재열람·트래커가 쓴다.
func acquired_ids() -> Array:
	var out: Array = []
	for id in all_ids():
		if acquired.has(id):
			out.append(id)
	out.sort_custom(func(a, b): return int(acquired[a]) < int(acquired[b]))
	return out

# ── 책장 재읽기(HOME 집 책장 [F]) ─────────────────────────────────────────────
# **미독이 있으면 미독을 먼저**(대화 중에 주워 놓친 것이 여기서 회수된다), 전부 읽었으면 커서를
# 한 칸씩 돌리며 차례로 다시 펼친다(연타 = 다음 권). 주운 것이 없으면 "".
# ★ 즉독(주운 자리)과 **같은 데이터 위**에 서는 두 번째 창구일 뿐이다 — 별도 상태가 없다.
func next_reread() -> String:
	var ids := acquired_ids()
	if ids.is_empty():
		return ""
	for id in ids:
		if not read_ledger.has(id):
			return str(id)
	var pick := str(ids[posmod(_shelf_cursor, ids.size())])
	_shelf_cursor = posmod(_shelf_cursor + 1, ids.size())
	return pick

# ── 세이브/로드 ───────────────────────────────────────────────────────────────
# 가법 키 두 축(입수 원장 · 기독 원장). ★ 키 자체가 없는 **구세이브는 main이 load_save를 아예
# 안 불러 빈 원장으로 시작**한다(우편함·곳간·상자가 쓰는 그 하위호환 관례 — 마이그레이션 0).
func to_save() -> Dictionary:
	return {"acquired": acquired.duplicate(), "read": read_ledger.duplicate()}

# 복원 = 정제하며 갈아끼운다(mailbox.load_save의 결 그대로):
#   · 테이블에서 사라진 옛 id는 조용히 버린다(본문 없는 책은 펼칠 수 없어 빈 대화창 함정이 된다)
#   · 기독 원장은 **입수 원장에 있는 id만** 든다(주운 적 없는 것의 기독 기록은 의미가 없고,
#     남겨 두면 나중에 실제로 주웠을 때 미독 표시 없이 묻힌다)
func load_save(data: Dictionary) -> void:
	acquired = {}
	var raw_acq: Variant = data.get("acquired", {})
	if typeof(raw_acq) == TYPE_DICTIONARY:
		for k in raw_acq:
			var sid := str(k)
			if has_text(sid):
				acquired[sid] = int(raw_acq[k])
	read_ledger = {}
	var raw_read: Variant = data.get("read", {})
	if typeof(raw_read) == TYPE_DICTIONARY:
		for k in raw_read:
			var sid2 := str(k)
			if acquired.has(sid2) and bool(raw_read[k]):
				read_ledger[sid2] = true
	_shelf_cursor = 0
	changed.emit()
