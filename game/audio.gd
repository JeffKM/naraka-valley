extends Node
class_name GameAudio
# P2.6 — 사운드 시스템(BGM 시간대 라우팅 + 이벤트 SFX + 음소거).
#
# 목적: 한 곳에서 (1) 시간대/상태에 맞는 BGM을 크로스페이드로 깔고 (2) 게임 이벤트
#       (괭이·물·수확·서빙·골드·UI·대화·막기·취침)마다 짧은 SFX를 쏜다. main은
#       이벤트가 일어난 자리에서 audio.sfx("harvest")처럼 한 줄만 부르고, "어떤 음을
#       어느 버스로 어떻게 페이드하나"는 전부 이 노드가 안다(이벤트↔사운드 디커플링,
#       field.gd가 Foxfire를 모르는 패턴).
#
# 설계 메모(lighting.gd와 같은 결):
#   - main의 코드 생성 자식 노드다($Cafe처럼 .tscn에 박지 않고 _setup_audio에서 생성 —
#     순수 노드라 에디터 설정이 필요 없고 .tscn을 안 건드린다). 무상태라 세이브 대상이
#     아니다(음소거 토글은 런타임 UX, 진행 상태 아님 — SaveManager 불변).
#   - 매핑은 순수 함수(phase_for/bgm_source/sfx_source)로 떼어 헤드리스로 단언한다
#     (audio_test.gd). 실제 재생(AudioStreamPlayer)은 그 위에 얹는 얇은 층.
#   - BGM은 .ogg를 .wav보다 먼저 찾는다 — Suno Pro 생성본(.ogg)이 같은 파일명으로
#     떨어지면 그레이박스 플레이스홀더(.wav, tools/make_sfx.py)를 *자동 교체*한다
#     (도트 그레이박스→스프라이트 드롭인과 같은 결, docs/design/p2.0-spike-prompts.md §13).
#   - 파일이 아직 없어도(미생성 BGM) 절대 죽지 않는다 — 그 버스는 조용히 비운다.

# ── 버스 ─────────────────────────────────────────────────────────────────
const MUSIC_BUS := "Music"
const SFX_BUS := "SFX"

# ── BGM 시간대(phase) ──────────────────────────────────────────────────────
# 하루를 음악으로 셋으로 나눈다(ROADMAP P2.6: ①낮 농사+카페 ②밤 바 긴장 ③엔딩).
# ★ B2: 타이틀 화면(gemini-ui-identity-spec §3.4)이 생겨 title 테마가 추가됐다 — 부팅 첫인상
# (로파이 코지)을 깐다. title은 시각에서 파생되지 않는 UI 상태라 phase_for에 넣지 않고, main이
# 타이틀을 띄울 때 set_phase(PHASE_TITLE)로 직접 건다(게임 시작 시 update_music이 farm/…로 잇는다).
# 낮은 *위치*로 둘로 갈린다: 카페 안=cafe / 밖(밭·집·길)=farm — 카페가 자기만의 공간
# 분위기를 갖는다(스타듀 술집 결). 전환 출처(지금=구역, 나중=건물 내부)는 main이 in_cafe
# 불리언으로 넘기고 audio는 그 출처를 모른다(디커플링 — Phase 3 건물 내부 전환이 와도 불변).
const PHASE_FARM := "farm"
const PHASE_CAFE := "cafe"
const PHASE_NIGHT := "night"
const PHASE_ENDING := "ending"
const PHASE_TITLE := "title"
# 밤 테마 시작 = 카페 마감 = 밤 바 영업 개시(19:00). 라이팅 등불 점등·NightBar.OPEN_MIN과
# 같은 경계라 "낮 활동이 닫히고 밤이 긴장으로 바뀌는" 한 순간에 색·빛·음악이 함께 넘어간다.
# 밤은 위치보다 우선한다 — 밤의 카페는 '나라카 바'라 카페 안이어도 밤 테마가 맞다(T6.4).
const NIGHT_THEME_MIN := 19 * 60
# phase → BGM 파일 stem(확장자 없음 — bgm_source가 .ogg→.wav 순으로 해석).
const BGM_DIR := "res://assets/audio/bgm/"
const BGM_STEM := {
	PHASE_FARM: "bgm_farm",
	PHASE_CAFE: "bgm_cafe",
	PHASE_NIGHT: "bgm_night",
	PHASE_ENDING: "bgm_ending",
	PHASE_TITLE: "bgm_title",
}
const BGM_EXTS := [".ogg", ".wav"]  # .ogg(Suno 생성본) 우선, 없으면 .wav(플레이스홀더)

# ── SFX 9종 ────────────────────────────────────────────────────────────────
# 키 = main이 이벤트 자리에서 부르는 이름(ROADMAP P2.6 목록과 1:1).
const SFX_DIR := "res://assets/audio/sfx/"
const SFX_STEM := {
	"hoe": "hoe",            # 괭이질(경작)
	"water": "water",        # 물주기
	"harvest": "harvest",    # 수확(영혼 거둠)
	"serve": "serve",        # 카페·밤 손님 서빙
	"gold": "gold",          # 골드 획득(판매·정산)
	"ui": "ui",              # 메뉴 토글·작물 순환·세이브 등 UI
	"dialogue": "dialogue",  # 대사 한 줄 진행
	"block": "block",        # 잡귀 막기(밤 경비)
	"sleep": "sleep",        # 취침(하루 닫기)
}

# ── 페이드/볼륨 ────────────────────────────────────────────────────────────
const FULL_DB := 0.0
const SILENT_DB := -40.0
const CROSSFADE_SECS := 1.0
const SFX_VOICES := 8  # 동시 SFX 보이스 풀(겹쳐 나도 끊기지 않게)

var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _music_on_a := true          # 지금 들리는 쪽(A/B 교대 크로스페이드)
var _current_phase := ""         # 현재 깔린 phase(같으면 재페이드 안 함)
var _sfx_pool: Array[AudioStreamPlayer] = []
var _sfx_next := 0               # 라운드로빈 인덱스
var _muted := false
# 헤드리스(--headless 단위검증·부팅 테스트)에선 실제 play()를 건너뛴다 — 더미 오디오
# 드라이버는 재생 중인 playback을 종료 시 해제하지 못해 "resources still in use" 누수
# 경고를 낸다(프로젝트 '경고 0' 바). phase/스트림 배정·버스·음소거 등 상태와 매핑은
# 헤드리스에서도 그대로 도므로 단위검증은 온전하고, 실제 소리는 인게임(윈도우)에서만 난다.
var _silent := false


# ── 순수 매핑(헤드리스 단언 대상) ──────────────────────────────────────────
# 시각(분)·슬라이스 종료·위치(카페 안인가)에서 BGM phase를 파생한다. 무상태 — 이 셋만
# 보면 결정된다(lighting.tint_for와 같은 결). 우선순위: 엔딩(마무리 화면, 시각·위치 무관) >
# 밤(19시+, 카페 안이어도 '나라카 바'라 밤) > 낮은 위치로 분기(카페 안=cafe / 밖=farm).
func phase_for(minutes: float, run_over: bool, in_cafe: bool) -> String:
	if run_over:
		return PHASE_ENDING
	if minutes >= NIGHT_THEME_MIN:
		return PHASE_NIGHT
	return PHASE_CAFE if in_cafe else PHASE_FARM

# phase → 실제 존재하는 BGM 파일 경로(.ogg 우선). 아직 없으면 ""(그 버스는 비운다).
func bgm_source(phase: String) -> String:
	var stem: String = BGM_STEM.get(phase, "")
	if stem == "":
		return ""
	for ext in BGM_EXTS:
		var p: String = BGM_DIR + stem + ext
		if FileAccess.file_exists(p):
			return p
	return ""

# 이벤트 이름 → SFX 파일 경로. 없으면 ""(조용히 무시 — 미정의 이벤트로 안 죽는다).
func sfx_source(event: String) -> String:
	var stem: String = SFX_STEM.get(event, "")
	if stem == "":
		return ""
	var p: String = SFX_DIR + stem + ".wav"
	return p if FileAccess.file_exists(p) else ""


# ── 셋업 ───────────────────────────────────────────────────────────────────
func _ready() -> void:
	_silent = DisplayServer.get_name() == "headless"
	# ★ B2: 트리 일시정지(타이틀 오버레이 get_tree().paused=true) 중에도 BGM이 계속 재생·크로스페이드
	#   되도록 ALWAYS로 둔다 — pausable이면 타이틀에서 곡이 멎고 페이드 트윈도 멈춘다. 자식 플레이어는
	#   INHERIT라 이 값을 따른다(음악은 정지 메뉴에서도 이어지는 게 자연스럽다).
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_buses()
	_music_a = _make_player(MUSIC_BUS)
	_music_b = _make_player(MUSIC_BUS)
	for i in SFX_VOICES:
		_sfx_pool.append(_make_player(SFX_BUS))

func _make_player(bus: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = bus
	p.volume_db = SILENT_DB
	add_child(p)
	return p

# Master 밑에 Music·SFX 버스를 런타임 조립한다(멱등 — 이미 있으면 건너뜀). project.godot
# 수동 편집/별도 .tres 대신 코드로 — main의 TileSet·입력 액션 런타임 조립과 같은 결.
func _ensure_buses() -> void:
	for bus in [MUSIC_BUS, SFX_BUS]:
		if AudioServer.get_bus_index(bus) == -1:
			var idx := AudioServer.bus_count
			AudioServer.add_bus(idx)
			AudioServer.set_bus_name(idx, bus)
			AudioServer.set_bus_send(idx, "Master")


# ── BGM ────────────────────────────────────────────────────────────────────
# 시각·종료·위치에서 파생한 phase로 BGM을 맞춘다(main이 매 프레임 호출 — 같은 phase면 즉시 반환).
func update_music(minutes: float, run_over: bool, in_cafe: bool) -> void:
	set_phase(phase_for(minutes, run_over, in_cafe))

func set_phase(phase: String) -> void:
	if phase == _current_phase:
		return
	_current_phase = phase
	var src := bgm_source(phase)
	var incoming := _music_b if _music_on_a else _music_a
	var outgoing := _music_a if _music_on_a else _music_b
	if src == "":
		# 곡이 아직 없다(미생성 BGM) — 들리던 걸 페이드아웃하고 빈 채로 둔다(죽지 않음).
		_fade(outgoing, SILENT_DB, true)
		return
	var stream := load(src) as AudioStream
	if stream == null:
		_fade(outgoing, SILENT_DB, true)
		return
	_enable_loop(stream)
	incoming.stream = stream
	incoming.volume_db = SILENT_DB
	if not _silent:
		incoming.play()
	_music_on_a = not _music_on_a
	# 크로스페이드: 새 곡 올리고 옛 곡 내린다. 음소거 중이면 둘 다 무음 유지(상태만 교대).
	if not _muted:
		_fade(incoming, FULL_DB, false)
	_fade(outgoing, SILENT_DB, true)

func _enable_loop(stream: AudioStream) -> void:
	if stream is AudioStreamWAV:
		# loop_end는 *프레임* 단위라 -1이 아니라 전체 길이를 줘야 끝까지 돌고 처음으로 잇는다
		# (그레이박스 .wav 플레이스홀더용 — 길이×믹스레이트로 총 프레임 산출).
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		var frames := int(stream.get_length() * stream.mix_rate)
		if frames > 0:
			stream.loop_end = frames
	elif stream is AudioStreamOggVorbis:
		stream.loop = true  # Suno 생성본(.ogg) — 단순 bool 루프

# 볼륨을 dB로 보간한다. 트리 밖(헤드리스 단언)이거나 트윈을 못 만들면 즉시 적용한다.
# 트윈은 player.create_tween()으로 만들어 *그 플레이어에 묶는다* — 페이드 도중 플레이어가
# 해제되면 트윈도 함께 죽어 매달린 트윈(누수·orphan)이 남지 않는다. 또 같은 플레이어에 새
# 페이드가 걸리면 이전 트윈이 자동 무효화돼 볼륨이 튀지 않는다(크로스페이드 재진입 안전).
func _fade(player: AudioStreamPlayer, to_db: float, stop_after: bool) -> void:
	if not player.is_inside_tree():
		player.volume_db = to_db
		if stop_after:
			player.stop()
		return
	var tw := player.create_tween()
	tw.tween_property(player, "volume_db", to_db, CROSSFADE_SECS)
	if stop_after:
		tw.tween_callback(player.stop)


# ── SFX ────────────────────────────────────────────────────────────────────
# 이벤트 SFX를 쏜다. 풀에서 다음 보이스를 돌려 써 겹쳐 나도 끊기지 않는다. 음소거면 무시.
func sfx(event: String) -> void:
	if _muted:
		return
	var src := sfx_source(event)
	if src == "":
		return
	var stream := load(src) as AudioStream
	if stream == null:
		return
	var p := _sfx_pool[_sfx_next]
	_sfx_next = (_sfx_next + 1) % _sfx_pool.size()
	p.stream = stream
	p.volume_db = FULL_DB
	if not _silent:
		p.play()


# ── 음소거 ─────────────────────────────────────────────────────────────────
func toggle_mute() -> bool:
	set_muted(not _muted)
	return _muted

func set_muted(m: bool) -> void:
	_muted = m
	var mi := AudioServer.get_bus_index(MUSIC_BUS)
	var si := AudioServer.get_bus_index(SFX_BUS)
	if mi != -1:
		AudioServer.set_bus_mute(mi, m)
	if si != -1:
		AudioServer.set_bus_mute(si, m)

func is_muted() -> bool:
	return _muted

# ── ★ ADR-0048 Phase D 볼륨(설정 화면) ───────────────────────────────────────
# 음악·효과음 버스 볼륨을 0..1 선형으로 받아 dB로 적용한다(설정 GameSettings 값 → main이 이 API로 적용).
# 버스 볼륨은 크로스페이드(플레이어별 volume_db)·음소거(bus mute)와 직교라 서로 안 싸운다(카테고리 마스터).
# 0(또는 근사)이면 무음 바닥(SILENT_DB)으로 내려 완전히 죽인다(linear_to_db(0)=-inf 방어).
func set_music_volume(v01: float) -> void:
	_set_bus_volume(MUSIC_BUS, v01)

func set_sfx_volume(v01: float) -> void:
	_set_bus_volume(SFX_BUS, v01)

func _set_bus_volume(bus: String, v01: float) -> void:
	var idx := AudioServer.get_bus_index(bus)
	if idx == -1:
		return
	var v := clampf(v01, 0.0, 1.0)
	AudioServer.set_bus_volume_db(idx, SILENT_DB if v <= 0.001 else linear_to_db(v))
