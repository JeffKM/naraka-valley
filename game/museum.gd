extends Node
class_name Museum
# ★ [S2-T5 / ADR-0060 결정 5] 혼백관(박물관) 전시 인프라 — 기증 원장 + 수집 트래커 + 마일스톤 보상.
#
# 구조(Reclaim/Sprinkler 델타 원장 패턴 계승):
#   · donated  = 기증된 아이템 id → 기증 day (아이템당 1회 — 스타듀 기증 중복 불가 규약)
#   · claimed  = 지급 완료 마일스톤 count 목록 (보상 이중 지급 방지)
#   · 전시는 기증 사실의 *파생*이다 — 좌표·배치 상태 없음(그레이박스 진열은 main이 원장에서 그림).
# 기증 대상 = 유품(CAT_RELIC, ItemCatalog.RELICS) + 책([ADR-0034] 그릇 — 책 아이템은 Slice 9에서
#   합류하며 그때 category 판정만 넓히면 원장·마일스톤이 그대로 받는다).
# 유품 소스 = 안식 괭이질 저확률 발굴(relic_roll — 스타듀 Artifact Spot 대응, ADR-0060 결정 5 잠정).
#
# 봉인 법칙([ADR-0034]) 준수: 이 모듈은 수집 메카닉만 안다 — 서사 텍스트(유품의 사연·책 내용)는
#   Slice 9 authoring 소관이라 여기 없다.

# ── 마일스톤 보상 테이블(그레이박스 — 씨앗·비료·레어크로우) ──────────────────────
# count 도달 시 1회 지급. 레어크로우 ①([ADR-0051] B 수집 트랙의 최초 획득처 — 여기서 열린다).
# 유품 3종 시대의 시드 테이블 — 종수가 늘면 행을 늘린다(스타듀 5/10/15... 결).
const MILESTONES := [
	{"count": 1, "reward_id": "honryeongcho_seed", "n": 5},
	{"count": 2, "reward_id": "fert_quality", "n": 3},
	{"count": 3, "reward_id": "rarecrow_1", "n": 1},
]

# 발굴 확률(퍼밀·0..1000 해시 대비) — 30 = 3%. 괭이질 1회당 1롤(결정적 — 같은 날·같은 칸 = 같은 결과).
const DIG_ROLL_PERMIL := 30

var donated: Dictionary = {}   # id(String) → day(int)
var claimed: Array = []        # 지급 완료 마일스톤 count(int) 목록

signal changed                 # 기증/보상 변화(그레이박스 진열 redraw 훅)

# ── 기증 ─────────────────────────────────────────────────────────────────────
# 기증 가능 = 기증 대상 카테고리(유품)이고 아직 기증 안 됨. 책은 Slice 9에서 카테고리 합류.
func can_donate(id: String) -> bool:
	return ItemCatalog.category_of(id) == ItemCatalog.CAT_RELIC and not donated.has(id)

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

# 기증 대상 전체(수집 트래커 분모). 지금=유품 3종, 책 합류 시 늘어난다.
static func donatable_ids() -> Array:
	return ItemCatalog.RELICS.keys()

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
	for k in data.get("donated", {}):
		donated[String(k)] = int(data["donated"][k])
	claimed = []
	for c in data.get("claimed", []):
		claimed.append(int(c))
	changed.emit()
