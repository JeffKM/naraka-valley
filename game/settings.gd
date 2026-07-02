extends Node
class_name GameSettings
# ADR-0048 Phase D(S1-14) — 게임 설정(볼륨·전체화면). UX 환경설정이지 게임 진행이 아니다.
#
# 목적: 옵션 탭 설정 본체(음악·효과음 볼륨, 전체화면)의 값을 한 곳에서 들고, 세이브(save.dat)와
#       *분리된* user://settings.cfg에 영속한다 — 진행 상태가 아니라 기기별 환경설정이라(음소거 토글이
#       세이브 대상이 아닌 것과 같은 결, audio.gd 메모), 새 게임·이어하기와 무관하게 유지된다.
#
# 설계 메모:
#   - audio.gd·DisplayServer를 *모른다*(디커플링) — 값만 들고 to/from ConfigFile만 한다. 실제 적용
#     (버스 볼륨·창 모드)은 main이 조율한다(데이터/적용 분리, RunSummary·설정 노드 결). 그래서 헤드리스
#     단위검증이 파일 IO 없이 값·클램프만 본다.
#   - 언어는 한국어 고정(ADR-0048 §2) — 설정 항목이 아니라 표시만. 볼륨은 0..1 선형(0=무음), main이 dB로 변환.

const PATH := "user://settings.cfg"
const SECTION := "settings"

# 기본값(첫 실행). 볼륨은 0..1 선형.
var music_volume := 0.8
var sfx_volume := 0.9
var fullscreen := false

# 디스크에서 읽어 값을 채운다(없으면 기본값 유지). 손상·범위 밖은 클램프로 방어(세이브 결).
func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	music_volume = clampf(float(cfg.get_value(SECTION, "music_volume", music_volume)), 0.0, 1.0)
	sfx_volume = clampf(float(cfg.get_value(SECTION, "sfx_volume", sfx_volume)), 0.0, 1.0)
	fullscreen = bool(cfg.get_value(SECTION, "fullscreen", fullscreen))

# 현재 값을 디스크에 쓴다(볼륨·전체화면 바뀔 때마다 main이 호출 — 즉시 영속).
func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value(SECTION, "music_volume", music_volume)
	cfg.set_value(SECTION, "sfx_volume", sfx_volume)
	cfg.set_value(SECTION, "fullscreen", fullscreen)
	cfg.save(PATH)

# 볼륨을 delta만큼 증감(0..1 클램프). 옵션 탭 [−]/[+] 버튼이 부른다. 실제 변화가 있으면 true.
func nudge_music(delta: float) -> bool:
	var v := clampf(music_volume + delta, 0.0, 1.0)
	if is_equal_approx(v, music_volume):
		return false
	music_volume = v
	return true

func nudge_sfx(delta: float) -> bool:
	var v := clampf(sfx_volume + delta, 0.0, 1.0)
	if is_equal_approx(v, sfx_volume):
		return false
	sfx_volume = v
	return true

# 전체화면 상태를 지정한다(F11 토글·옵션 탭 체크박스가 값을 맞춘다). 실제 변화가 있으면 true.
func set_fullscreen(on: bool) -> bool:
	if on == fullscreen:
		return false
	fullscreen = on
	return true
