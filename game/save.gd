extends Node
class_name SaveManager
# T2.5 — 세이브/로드 최소 직렬화(단일 슬롯).
#
# 목적: "저장 후 게임을 껐다 켜도 날짜·밭·작물·혼력(·골드)이 그대로 복원된다"를
#       회색 UI만으로 검증한다(ADR-0001 그레이박스).
#
# 설계 메모:
#   - clock.gd·field.gd·energy.gd와 같은 결: 이 노드는 "세이브 파일 입출력"이라는
#     단일 책임만 가진다. 어떤 상태를 저장할지 고르고 각 시스템 노드에 분배하는
#     '조율'은 main.gd가 맡고(이미 모든 노드 참조를 가짐), 여기서는 Dictionary를
#     받아 파일에 쓰고/읽는 IO와 포맷(버전 래핑)만 책임진다.
#   - 직렬화는 var_to_str / str_to_var를 쓴다(JSON 아님). 밭 상태(FarmField._tiles)가
#     Vector2i를 '키'로 쓰는 Dictionary라, JSON으론 키를 문자열로 풀어내야 하지만
#     var_to_str는 Vector2i 키와 int/bool/String 값을 타입 그대로 라운드트립한다.
#     field.gd가 "순수 Dictionary로만 들고 있어 그대로 직렬화된다"고 설계해 둔 의도와
#     정확히 맞물린다(inner class를 안 쓴 이유).
#   - 단일 슬롯이다. 다중 슬롯·암호화·클라우드는 후속(ROADMAP: 범위 폭주 방지).
#   - 골드는 아직 없다(T3.1 경제). 포맷이 Dictionary라 그때 한 키만 더 끼우면 되고,
#     이 노드는 손대지 않는다(IO만 책임지므로 저장 항목이 늘어도 영향 없음).

# user:// 경로라 OS별 사용자 데이터 폴더에 저장된다(저장소·빌드와 분리).
const SAVE_PATH := "user://save.dat"
# 포맷 버전. 저장 구조가 바뀌면 올려서 옛 세이브를 안전하게 무시/이관한다.
const VERSION := 1

# 세이브 파일이 존재하는가(시작 시 자동 로드 여부 판단).
func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

# 상태 Dictionary를 버전으로 감싸 파일에 쓴다. 성공 시 true.
# data에는 직렬화 가능한 값만 담겨야 한다(Vector2i 키 Dictionary는 허용).
func save_game(data: Dictionary) -> bool:
	var wrapped := {"version": VERSION, "data": data}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("[SaveManager] 저장 실패: %s (%d)" % [SAVE_PATH, FileAccess.get_open_error()])
		return false
	f.store_string(var_to_str(wrapped))
	f.close()
	return true

# 세이브를 읽어 상태 Dictionary를 돌려준다. 없거나 깨졌으면 빈 Dictionary({}).
# 호출 측(main)은 비었으면 "새 게임"으로 다룬다.
func load_game() -> Dictionary:
	if not has_save():
		return {}
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		push_warning("[SaveManager] 읽기 실패: %s (%d)" % [SAVE_PATH, FileAccess.get_open_error()])
		return {}
	var text := f.get_as_text()
	f.close()
	var parsed: Variant = str_to_var(text)
	# 깨진 파일·옛 포맷 방어: Dictionary가 아니거나 버전이 다르면 새 게임으로.
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("[SaveManager] 세이브 손상(형식 불일치) — 새 게임으로 시작")
		return {}
	var wrapped: Dictionary = parsed
	if int(wrapped.get("version", -1)) != VERSION:
		push_warning("[SaveManager] 세이브 버전 불일치 — 새 게임으로 시작")
		return {}
	var data: Variant = wrapped.get("data", {})
	return data if typeof(data) == TYPE_DICTIONARY else {}

# 세이브 삭제(새 게임 시작·디버그용). 없으면 조용히 통과.
func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
