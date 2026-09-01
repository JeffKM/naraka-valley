extends Node
class_name Museum
# ★ [S2-T5 / ADR-0060 결정 5] 혼백관(박물관) 전시 인프라 — 기증 원장 + 수집 트래커 + 마일스톤 보상.
#
# 구조(Reclaim/Sprinkler 델타 원장 패턴 계승):
#   · donated  = 기증된 아이템 id → 기증 day (아이템당 1회 — 스타듀 기증 중복 불가 규약)
#   · claimed  = 지급 완료 마일스톤 count 목록 (보상 이중 지급 방지)
#   · 전시는 기증 사실의 *파생*이다 — 좌표·배치 상태 없음(그레이박스 진열은 main이 원장에서 그림).
# 기증 대상 = 유품(CAT_RELIC, ItemCatalog.RELICS) + ★[S9-T7] **책**([옥자의 잃어버린 책들] 8권).
#   예고대로 category 판정만 넓혔고 원장·마일스톤 구조는 한 줄도 안 바뀌었다(가법 확장).
#   ★ **비밀 노트는 기증 대상이 아니다**: 노트는 떡밥이라 전시대에 세울 유품이 아니라 주머니에
#     접어 넣는 종이다(ADR-0034 #1 "노트=넓음·흔함 / 책=귀함·옥자 앵커"). 그래서 CAT_BOOK
#     전체가 아니라 `Books.is_book`으로 가른다.
# 유품 소스 = 안식 괭이질 저확률 발굴(relic_roll — 스타듀 Artifact Spot 대응, ADR-0060 결정 5 잠정).
#
# 봉인 법칙([ADR-0034]) 준수: 이 모듈은 수집 메카닉만 안다 — 서사 텍스트(유품의 사연·책 내용)는
#   Slice 9 authoring 소관이라 여기 없다.

# ── 마일스톤 보상 테이블(그레이박스 — 씨앗·비료·레어크로우·보석) ────────────────
# count 도달 시 1회 지급. 레어크로우 ①([ADR-0051] B 수집 트랙의 최초 획득처 — 여기서 열린다).
#
# ★[S9-T7] **책 합류에 맞춘 사다리 연장**(재설계 — ADR-0067 결정 8 "마일스톤 테이블 재설계").
#   ㉠ 분모가 유품 3 → 유품 3 + 책 8 = **11**로 늘었는데 사다리 꼭대기가 3이면, 책을 몇 권을
#      되찾든 답례가 없어 트래커가 3점에서 죽는다. 그래서 5·8·11 세 칸을 **위로** 얹는다.
#   ㉡ **기존 1·2·3 행은 바이트 그대로 둔다**(구세이브의 claimed 목록이 count 값을 키로 들고
#      있어, 기존 문턱을 옮기면 이미 받은 답례가 다시 pending으로 뜨거나 영영 묻힌다).
#   ㉢ 책 기증은 `donated_count()`가 유품과 **한 통에 세므로** 배선 0줄로 산입된다 — 책 한 권이
#      유품 한 점과 같은 무게라는 뜻이기도 하다(둘 다 "되찾은 망자의 것"이다).
#   ㉣ 보상은 전부 **아이템**이다: [ADR-0034] #4가 영구 % 곱셈을 금지했으므로 답례가 배수를
#      건드리는 일은 없다(꼭대기 답례도 초희귀 보석 1개 = 일회성 물건).
#   ★ 수치·품목 전부 **잠정(owner 큐)**.
const MILESTONES := [
	{"count": 1, "reward_id": "honryeongcho_seed", "n": 5},
	{"count": 2, "reward_id": "fert_quality", "n": 3},
	{"count": 3, "reward_id": "rarecrow_1", "n": 1},
	{"count": 5, "reward_id": "fert_deluxe", "n": 3},              # ★S9-T7
	{"count": 8, "reward_id": "gem_myeongbu_geumgang", "n": 1},    # ★S9-T7 명부금강 1개
	{"count": 11, "reward_id": "gem_osaek_honok", "n": 1},         # ★S9-T7 완주 답례(오색혼옥)
]

# 발굴 확률(퍼밀·0..1000 해시 대비) — 30 = 3%. 괭이질 1회당 1롤(결정적 — 같은 날·같은 칸 = 같은 결과).
const DIG_ROLL_PERMIL := 30

var donated: Dictionary = {}   # id(String) → day(int)
var claimed: Array = []        # 지급 완료 마일스톤 count(int) 목록

signal changed                 # 기증/보상 변화(그레이박스 진열 redraw 훅)

# ── 기증 ─────────────────────────────────────────────────────────────────────
# 기증 가능 = 기증 대상(유품 ∪ 책)이고 아직 기증 안 됨. ★[S9-T7] 책이 합류했다.
func can_donate(id: String) -> bool:
	return is_donatable(id) and not donated.has(id)

# 이 물건이 애초에 전시대에 설 물건인가(원장 상태와 무관한 순수 판정 — 프롬프트·테스트가 쓴다).
static func is_donatable(id: String) -> bool:
	return ItemCatalog.category_of(id) == ItemCatalog.CAT_RELIC or Books.is_book(id)

# 기증한다(아이템 소모는 호출자=main 소관 — 원장은 사실만 기록). 성공 시 true.
func donate(id: String, day: int) -> bool:
	if not can_donate(id):
		return false
	donated[id] = day
	changed.emit()
	return true

func donated_count() -> int:
	return donated.size()

func is_donated(id: String) -> bool:
	return donated.has(id)

# 기증 대상 전체(수집 트래커 분모 = 전시대 좌대 순서). ★[S9-T7] 유품 3 + 책 8 = 11.
# 순서를 유품 먼저로 고정한 이유: 진열 좌대가 이 배열 인덱스로 서므로(main._draw_museum_room),
# 순서가 흔들리면 이미 채워진 좌대가 옆으로 밀린다.
static func donatable_ids() -> Array:
	var out: Array = ItemCatalog.RELICS.keys()
	out.append_array(Books.book_ids())
	return out

# ── 마일스톤 보상 ─────────────────────────────────────────────────────────────
# 도달했지만 아직 안 받은 마일스톤 행 목록(낮은 count부터). main이 지급 후 claim()으로 잠근다.
func pending_milestones() -> Array:
	var out: Array = []
	for m in MILESTONES:
		if donated_count() >= int(m["count"]) and not claimed.has(int(m["count"])):
			out.append(m)
	return out

func claim(count: int) -> void:
	if not claimed.has(count):
		claimed.append(count)
		changed.emit()

# ── 유품 발굴(순수 함수 — 결정적 해시) ─────────────────────────────────────────
# 괭이질(첫 경작) 시 호출. (day, tile)의 정수 믹싱 해시로 0..999 롤 → DIG_ROLL_PERMIL 미만이면
# 유품 id, 아니면 "". 결정적이라 헤드리스 테스트가 경계를 정확히 검증한다(같은 입력 = 같은 결과).
static func relic_roll(day: int, tile: Vector2i) -> String:
	var h := int(posmod(day * 73856093 ^ tile.x * 19349663 ^ tile.y * 83492791, 1000))
	if h >= DIG_ROLL_PERMIL:
		return ""
	var ids := ItemCatalog.RELICS.keys()
	return ids[h % ids.size()]

# ── 세이브/로드(슬라이스 키 "museum" 네임스페이스 — Sprinkler 결) ──────────────────
func to_save() -> Dictionary:
	return {"donated": donated.duplicate(), "claimed": claimed.duplicate()}

func load_save(data: Dictionary) -> void:
	donated = {}
	# ★[폴리시 R9] **분모 밖 id는 안 싣는다.** 형제 원장 셋(`Codex.load_save`의 `is_tracked`·
	#   `FireflySouls.load_save`의 `is_valid_id`·`Mastery.load_save`의 `ARTIFACTS.has`)이 전부
	#   막아 둔 자리가 여기만 비어 있었다. 로스터가 한 번이라도 갈리면(유품 id 개명·`Books.book_ids()`
	#   에서 한 권 제외) 이미 기증해 둔 세이브의 죽은 키가 그대로 남아 `donated_count()`가 실제
	#   전시 수를 넘기고, 그 값이 ㉠`pending_milestones()`를 통해 11칸 완주 답례를 **11점을 채우기
	#   전에** 지급하고 ㉡`Spine.okja_deed_points(...)`로 앵커 트랙 deed까지 부풀리며 ㉢표시가
	#   "전시 12/11"을 낸다. 분자와 분모가 같은 로스터에서 나오게 한다.
	var valid: Dictionary = {}
	for id in donatable_ids():
		valid[String(id)] = true
	for k in data.get("donated", {}):
		var sid := String(k)
		if valid.has(sid):
			donated[sid] = int(data["donated"][k])
	claimed = []
	for c in data.get("claimed", []):
		claimed.append(int(c))
	changed.emit()
