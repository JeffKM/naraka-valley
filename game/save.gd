extends Node
class_name SaveManager
# T2.5 → ★멀티 슬롯(gemini-ui-identity-spec §3.4·§7-g) — 세이브/로드 직렬화(3 슬롯).
#
# 목적: "저장 후 게임을 껐다 켜도 날짜·밭·작물·혼력(·골드)이 그대로 복원된다"를
#       검증하되, 타이틀 [Load Game]이 3개의 독립 슬롯을 고를 수 있게 한다.
#
# 설계 메모:
#   - clock.gd·field.gd·energy.gd와 같은 결: 이 노드는 "세이브 파일 입출력"이라는
#     단일 책임만 가진다. 어떤 상태를 저장할지 고르고 각 시스템 노드에 분배하는
#     '조율'은 main.gd가 맡고(이미 모든 노드 참조를 가짐), 여기서는 Dictionary를
#     받아 파일에 쓰고/읽는 IO와 포맷(버전 래핑)만 책임진다.
#   - 직렬화는 var_to_str / str_to_var를 쓴다(JSON 아님). 밭 상태(FarmField._tiles)가
#     Vector2i를 '키'로 쓰는 Dictionary라, JSON으론 키를 문자열로 풀어내야 하지만
#     var_to_str는 Vector2i 키와 int/bool/String 값을 타입 그대로 라운드트립한다.
#   - ★슬롯 = 3개(0·1·2). **slot 0은 레거시 단일 슬롯 경로(user://save.dat)를 그대로**
#     쓴다 — 기존 세이브를 자동 승계하고, save.dat를 백업/복원하는 전 회귀 테스트가
#     무수정으로 통과한다(하위호환). slot 1·2만 신규 파일(save1.dat·save2.dat).
#   - ★meta = 슬롯 선택 UI(코지 다이어리 [N년차 절기 D일 / 혼력])가 **전체 로드 없이**
#     날짜·혼력만 읽도록 세이브 헤더에 얹는 경량 조각이다. main이 저장 시 넘기고
#     (SaveManager는 도메인을 모른 채 불투명 blob으로 보관), slot_meta가 헤더만 판다.
#     meta 키가 없는 옛 세이브도 안전하다(get 기본 {}). 구조가 가법적이라 VERSION 불변.

# slot 0 = 레거시 경로(하위호환). slot 1·2 = 신규 파일.
const LEGACY_PATH := "user://save.dat"
const SLOT_COUNT := 3
# 포맷 버전. 저장 구조가 바뀌면 올려서 옛 세이브를 안전하게 무시/이관한다.
const VERSION := 1

# 슬롯 → user:// 경로. 잘못된(범위 밖) 슬롯은 slot 0으로 클램프(깨진 호출 방어).
static func slot_path(slot: int) -> String:
	if slot <= 0:
		return LEGACY_PATH
	return "user://save%d.dat" % slot

# 세이브 파일이 존재하는가(시작 시 자동 로드 여부·슬롯 점유 판단).
func has_save(slot: int = 0) -> bool:
	return FileAccess.file_exists(slot_path(slot))

# 어느 슬롯에든 세이브가 하나라도 있는가(부팅/타이틀 판단 보조).
func any_save() -> bool:
	for s in SLOT_COUNT:
		if has_save(s):
			return true
	return false

# 상태 Dictionary를 버전·메타로 감싸 슬롯 파일에 쓴다. 성공 시 true.
# data에는 직렬화 가능한 값만 담겨야 한다(Vector2i 키 Dictionary는 허용).
# meta = 슬롯 UI가 읽을 경량 헤더(예: {"day": 34, "soul": 85}) — 없으면 {}.
func save_game(data: Dictionary, slot: int = 0, meta: Dictionary = {}) -> bool:
	var wrapped := {"version": VERSION, "meta": meta, "data": data}
	var path := slot_path(slot)
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_warning("[SaveManager] 저장 실패: %s (%d)" % [path, FileAccess.get_open_error()])
		return false
	f.store_string(var_to_str(wrapped))
	f.close()
	return true

# 슬롯 세이브를 읽어 상태 Dictionary를 돌려준다. 없거나 깨졌으면 빈 Dictionary({}).
# 호출 측(main)은 비었으면 "새 게임"으로 다룬다.
func load_game(slot: int = 0) -> Dictionary:
	var wrapped := _read_wrapped(slot)
	if wrapped.is_empty():
		return {}
	var data: Variant = wrapped.get("data", {})
	return data if typeof(data) == TYPE_DICTIONARY else {}

# 슬롯의 경량 메타(코지 다이어리 표시용)만 읽는다 — 전체 data는 파싱해도 분배하지 않는다.
# 없거나 깨졌거나 버전 불일치면 {}(타이틀은 "빈/불러올 수 없는 슬롯"으로 다룬다).
func slot_meta(slot: int = 0) -> Dictionary:
	var wrapped := _read_wrapped(slot)
	if wrapped.is_empty():
		return {}
	var meta: Variant = wrapped.get("meta", {})
	return meta if typeof(meta) == TYPE_DICTIONARY else {}

# 세이브 삭제(슬롯 비우기·새 게임 시작·디버그용). 없으면 조용히 통과.
func delete_save(slot: int = 0) -> void:
	if has_save(slot):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(slot_path(slot)))

# 슬롯 파일을 읽어 검증된 {version, meta, data} 래퍼를 돌려준다(공유 헬퍼). 실패 시 {}.
func _read_wrapped(slot: int) -> Dictionary:
	if not has_save(slot):
		return {}
	var path := slot_path(slot)
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_warning("[SaveManager] 읽기 실패: %s (%d)" % [path, FileAccess.get_open_error()])
		return {}
	var text := f.get_as_text()
	f.close()
	var parsed: Variant = str_to_var(text)
	# 깨진 파일·옛 포맷 방어: Dictionary가 아니거나 버전이 다르면 새 게임으로.
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("[SaveManager] 세이브 손상(형식 불일치) — 무시")
		return {}
	var wrapped: Dictionary = parsed
	if int(wrapped.get("version", -1)) != VERSION:
		push_warning("[SaveManager] 세이브 버전 불일치 — 무시")
		return {}
	return wrapped
