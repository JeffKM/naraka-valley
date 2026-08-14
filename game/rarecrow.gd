extends Node
class_name RarecrowLedger
# ★[S10-T2 / ADR-0069 결정 4 · ADR-0051 결정 5] 레어크로우 배치 원장 — 설치 좌표 + 그 칸에 선 종.
#
# 목적: [ADR-0051] 결정 5가 "8종 스킨 → 완성 시 디럭스"로 예약하고 **배치 메카닉은 서랍**으로 미뤄
#       뒀던 그 서랍을 연다. owner의 잠금 조건("획득처를 전부 구현한 뒤에만 배치한다")은 슬라이스
#       내 태스크 순서로 충족된다(ADR-0069 결정 4 — T2가 ①~④·⑥·⑦, T3이 ⑤, T8이 ⑧).
#
# 왜 별개 노드인가(Sprinkler/CrabPot/Tapper 동형 완전 분리):
#   - 배치는 **플레이어 세이브 델타**다(설계 시드가 아니다 — 프롭 허수아비는 layout.json이 들고,
#     이쪽은 플레이어가 세운 것이라 원장이 든다). 이 노드는 "어디에 무엇이 섰나"라는 좌표→종
#     매핑 하나만 소유하고, 지형·화면·인벤토리·까마귀 판정을 모른다. main이 드로우·보호 반경·
#     세이브에서 질의한다.
#   - Sprinkler와 갈리는 지점은 값 하나뿐이다: 저쪽 값은 티어(정수), 이쪽 값은 **종 id(문자열)**.
#     한 칸에 한 마리이고 같은 종은 세상에 하나뿐이라(비매·중복 입수 없음) 종이 곧 신원이다.
#
# ★ **기능은 종과 무관하다**([ADR-0051] 결정 5 "기능·반경 동일한 순수 스킨"). 그래서 이 원장은
#   보호 반경도 방어력도 안 든다 — main이 `tiles()`를 프롭 허수아비 밑동 목록에 그냥 합칠 뿐이다.
# ★ **배치 앵커 = 밑동**(보호 반경의 중심). 프롭 허수아비는 1×2 스프라이트라 main이 앵커+(0,1)로
#   밑동을 파생하는데, 여기선 플레이어가 겨눈 칸이 곧 밑동이고 그림만 위로 1칸 자란다. 겨눈 칸이
#   보호 중심이라야 "여기를 지킨다"가 조준과 일치한다(스프링클러 배치 감각과도 같다).

signal changed()   # 설치/회수/복원한 프레임(main이 듣고 드로우·보호 반경을 다시 세운다)

# 설치 원장. 키 = 밑동 타일(Vector2i), 값 = 레어크로우 아이템 id(String). 키 없음 = 미설치.
var _tiles: Dictionary = {}

# ── 로스터(분모의 단일 출처는 ItemCatalog.RARECROWS — 여기선 되비추기만) ──────────
static func roster() -> Array:
	return ItemCatalog.RARECROWS

static func roster_size() -> int:
	return ItemCatalog.RARECROWS.size()

# ── 질의 ────────────────────────────────────────────────────────────────────
func has_at(t: Vector2i) -> bool:
	return _tiles.has(t)

# 이 칸에 선 레어크로우의 종 id("" = 미설치).
func id_at(t: Vector2i) -> String:
	return String(_tiles.get(t, ""))

# 설치된 밑동 목록(드로우 · 까마귀 보호 중심 · 검증).
func tiles() -> Array:
	return _tiles.keys()

func count() -> int:
	return _tiles.size()

# 지금 밭에 서 있는 종 id 목록(중복 없음 — 종은 세상에 하나뿐이라 자연히 유일하다).
func placed_ids() -> Array:
	var out: Array = []
	for t in _tiles:
		out.append(String(_tiles[t]))
	return out

# 이 종이 어딘가에 서 있는가(수집 판정의 "배치" 쪽 절반 — 나머지 절반은 인벤 소지이고, 합집합은
# main이 낸다. 이 노드는 백팩을 모른다).
func is_placed(id: String) -> bool:
	for t in _tiles:
		if String(_tiles[t]) == id:
			return true
	return false

# ── 설치/회수 ────────────────────────────────────────────────────────────────
# 밑동 칸에 그 종을 세운다. 이미 뭔가 선 칸이거나 로스터 밖 id면 false(멱등·손상 방어).
# ★ **같은 종을 두 곳에 세울 수 없다** — 세상에 한 마리뿐인 물건이라 원장이 이 불변식을 직접 든다
#   (인벤 개수로만 막으면, 나중에 어떤 경로가 실수로 중복 지급했을 때 조용히 두 마리가 선다).
#   배치 가능 판정(지면·성역·프롭 겹침)은 main._can_place_rarecrow가 한다 — 여기는 원장만 든다.
func place(t: Vector2i, id: String) -> bool:
	if _tiles.has(t) or not ItemCatalog.is_rarecrow(id) or is_placed(id):
		return false
	_tiles[t] = id
	changed.emit()
	return true

# 밑동 칸의 레어크로우를 거둔다. 반환 = 거둔 종 id("" = 없음 — 무동작). 인벤 반환은 main이 한다.
func remove(t: Vector2i) -> String:
	if not _tiles.has(t):
		return ""
	var id := String(_tiles[t])
	_tiles.erase(t)
	changed.emit()
	return id

# ── 세이브/로드(슬라이스 키 "rarecrow" 네임스페이스 — Sprinkler 결) ─────────────────
# 좌표+종을 [x, y, id] 배열 목록으로 직렬화. 키 없는 구세이브 = 배치 0(하위호환 — 마이그레이션 0).
func to_save() -> Dictionary:
	var tiles: Array = []
	for t in _tiles:
		tiles.append([t.x, t.y, String(_tiles[t])])
	return {"tiles": tiles}

func load_save(data: Dictionary) -> void:
	_tiles = {}
	var tiles: Variant = data.get("tiles", [])
	if typeof(tiles) == TYPE_ARRAY:
		var seen: Dictionary = {}
		for e in tiles:
			if typeof(e) != TYPE_ARRAY or e.size() < 3:
				continue
			var id := String(e[2])
			# 로스터에서 사라진 종·중복 종은 조용히 버린다(Mailbox._sanitize_ids와 같은 결 —
			# 되살릴 수 없는 것을 원장에 남겨 두면 화면에 정체불명의 말뚝이 선다).
			if not ItemCatalog.is_rarecrow(id) or seen.has(id):
				continue
			seen[id] = true
			_tiles[Vector2i(int(e[0]), int(e[1]))] = id
	changed.emit()
