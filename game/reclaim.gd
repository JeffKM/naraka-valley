extends Node
class_name Reclaim
# S1-8 — 안식 농원 overgrown 개간(debris 치우기). 치운 좌표 델타만 소유하는 얇은 원장(ledger).
#
# 목적: ROADMAP S1-8 — 맞는 도구(낫/곡괭이/도끼)로 debris 3종을 치우면 그 자리가 열리고(통과·경작지
#       확장) 재료가 드랍되며, 세이브로 영속하는지 헤드리스로 검증한다. 설계 = greybox-spec §10.
#
# 왜 별개 노드인가(§10.1·§10.3, Orchard/Ranch 동형 완전 분리):
#   - debris 배치는 PROP_LAYOUT_HOME 시드(설계 데이터·layout.json)에 잠겨 있다. 개간은 그 위에
#     "무엇을 치웠나"라는 플레이어 세이브 델타만 얹는 것 — Reclaim은 그 델타 집합 하나만 소유하고,
#     _prop_layouts(설계 시드)는 절대 안 건드린다(layout.json 오염 방지). main이 드로우/충돌
#     skip-filter와 farmable 판정에서 이 델타를 질의한다(디커플링 — Reclaim은 화면·지형을 모른다).
#   - 치운 좌표 = 개간 완료 = 경작 가능(단일 집합). "치움"과 "reclaimed(farmable)"를 한 집합으로 둔다.
#
# 설계 메모(§10.2·§10.3):
#   - 도구↔debris 매칭·드랍은 DebrisCatalog(정적 데이터)에 위임. Reclaim은 kind를 받아 카탈로그로
#     판정만 하고, "무슨 debris가 어느 타일에" 있는지는 모른다(그건 main이 텍스처→kind로 준다).
#   - 상태 = Vector2i 키 순수 Dictionary(값은 true 플래그) → var_to_str 그대로 라운드트립(Orchard 결).
#   - advance_day 없음 — debris는 그레이박스에서 리스폰 안 한다(1회성 개간, §10.1 OUT).

signal changed()   # debris를 치운 프레임(main이 듣고 드로우/충돌 갱신)

# 치운 debris 좌표 집합. 키 = 타일(Vector2i), 값 = true. 키가 없음 = 아직 안 치움(debris 그대로).
var _cleared: Dictionary = {}

# ── 질의 ────────────────────────────────────────────────────────────────────
# 이 타일의 debris를 이미 치웠는가(드로우/충돌 skip·farmable 판정이 쓴다).
func is_cleared(t: Vector2i) -> bool:
	return _cleared.has(t)

# 치운 타일 수(검증·디버그).
func cleared_count() -> int:
	return _cleared.size()

# ── 개간(§10.3) ──────────────────────────────────────────────────────────────
# 조준 타일의 debris(kind)를 든 도구(tool_id)로 친다. 성공 시 {"drop":재료id, "count":수} 반환·
# changed.emit(). 실패(이미 치움 / 미지 kind / 도구 불일치)면 {} — 무동작(ADR-0024 §2). 멱등.
func clear(t: Vector2i, kind: String, tool_id: String) -> Dictionary:
	if _cleared.has(t):
		return {}                                   # 이미 개간됨(멱등)
	if not DebrisCatalog.has(kind):
		return {}                                   # 미지 debris(방어)
	if DebrisCatalog.tool_for(kind) != tool_id:
		return {}                                   # 틀린 도구 → 무동작
	_cleared[t] = true
	changed.emit()
	return {"drop": DebrisCatalog.drop_for(kind), "count": DebrisCatalog.drop_count(kind)}

# ── 세이브/로드(§10.6) — Orchard 패턴 계승 ────────────────────────────────────
# _cleared는 Vector2i 키 순수 Dictionary라, 키를 [x,y] 배열 목록으로 직렬화한다(var_to_str도 되지만
# JSON·구조 안정성 위해 명시 목록). 로드는 통째 재구성 후 changed로 main이 드로우/충돌을 다시 세운다.
func to_save() -> Dictionary:
	var tiles: Array = []
	for t in _cleared:
		tiles.append([t.x, t.y])
	return {"cleared": tiles}

func load_save(data: Dictionary) -> void:
	_cleared = {}
	var tiles: Variant = data.get("cleared", [])
	if typeof(tiles) == TYPE_ARRAY:
		for e in tiles:
			if typeof(e) == TYPE_ARRAY and e.size() >= 2:
				_cleared[Vector2i(int(e[0]), int(e[1]))] = true
	changed.emit()
