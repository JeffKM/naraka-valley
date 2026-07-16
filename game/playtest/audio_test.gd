extends SceneTree
# P2.6 사운드 단위검증(ephemeral) — audio.gd의 매핑 계약(phase·BGM·SFX)을 헤드리스로
# 단언하고, 실제 노드를 트리에 붙여 버스 조립·재생 호출이 죽지 않는지 스모크한다.
# lighting_test(순수 함수)와 bana_test(트리 인스턴스화)를 합친 결.
# 실행: godot --headless --path game --script res://playtest/audio_test.gd

var _fail := 0

func _check(label: String, ok: bool) -> void:
	print(("  ✓ " if ok else "  ✗ ") + label)
	if not ok:
		_fail += 1

# bgm_source(phase)가 그 stem의 실제 파일(.ogg 또는 .wav)로 해석되고 파일이 존재하는가.
func _resolves(A: GameAudio, phase: String, stem: String) -> bool:
	var p := A.bgm_source(phase)
	return p.get_file().begins_with(stem) and FileAccess.file_exists(p)

const NOON := 12 * 60       # 낮 테마
const CAFE_OPEN := 15 * 60  # 카페 영업창(여전히 낮)
const DUSK := 18 * 60 + 30  # 18:30 — 아직 낮 테마(밤 경계 직전)
const NIGHT_OPEN := 19 * 60 # 밤 테마 시작(= 밤 바 영업·등불 점등 경계)
const DEEP_NIGHT := 23 * 60 # 깊은 밤

func _initialize() -> void:
	print("══ P2.6 audio.gd 단위검증 ══")
	_pure_checks()
	await _smoke_checks()
	print(("══ 통과 ══" if _fail == 0 else "══ 실패 %d건 ══" % _fail))
	quit(_fail)

# ── ①~③ 순수 매핑(트리 불필요 — 분리 인스턴스로 직접 호출) ──────────────────
func _pure_checks() -> void:
	var A := GameAudio.new()

	# ① phase: 낮은 위치로 farm/cafe 분기, 밤(19시+)은 night, 슬라이스 종료는 엔딩(최우선).
	#    phase_for(분, run_over, in_cafe) — 우선순위 ending > night > (in_cafe?cafe:farm).
	_check("① 낮(12:00) 카페 밖 = farm", A.phase_for(NOON, false, false) == GameAudio.PHASE_FARM)
	_check("①b 낮(12:00) 카페 안 = cafe", A.phase_for(NOON, false, true) == GameAudio.PHASE_CAFE)
	_check("①c 카페 영업창(15:00)도 밖이면 farm", A.phase_for(CAFE_OPEN, false, false) == GameAudio.PHASE_FARM)
	_check("①d 황혼 직전(18:30) 카페 안 = cafe", A.phase_for(DUSK, false, true) == GameAudio.PHASE_CAFE)
	_check("② 밤 경계(19:00)는 카페 밖이면 night", A.phase_for(NIGHT_OPEN, false, false) == GameAudio.PHASE_NIGHT)
	_check("②b 밤(19시+)은 카페 안이어도 night(밤=나라카 바, 위치보다 우선)", A.phase_for(DEEP_NIGHT, false, true) == GameAudio.PHASE_NIGHT)
	_check("③ 슬라이스 종료면 시각·위치 무관 ending(낮 카페 안에서도)", A.phase_for(NOON, true, true) == GameAudio.PHASE_ENDING)
	_check("③b 종료면 밤에도 ending", A.phase_for(DEEP_NIGHT, true, false) == GameAudio.PHASE_ENDING)
	_check("②c 밤 경계는 NightBar 영업 개시(19:00)와 같은 시각", GameAudio.NIGHT_THEME_MIN == 19 * 60)

	# ② BGM 해석: 네 phase(farm·cafe·night·ending) 모두 실제 파일(.ogg Suno 생성본 또는
	#    .wav 플레이스홀더)로 해석되고, .ogg가 .wav보다 우선이다(자동 교체 계약). 확장자에
	#    무관하게 안정적이도록 stem 일치 + 파일 존재로 단언한다(어느 phase가 .ogg로 교체돼도 green).
	_check("④ farm BGM 실제 파일로 해석", _resolves(A, GameAudio.PHASE_FARM, "bgm_farm"))
	_check("④b cafe BGM 실제 파일로 해석", _resolves(A, GameAudio.PHASE_CAFE, "bgm_cafe"))
	_check("④c night BGM 실제 파일로 해석", _resolves(A, GameAudio.PHASE_NIGHT, "bgm_night"))
	_check("④d ending BGM 실제 파일로 해석", _resolves(A, GameAudio.PHASE_ENDING, "bgm_ending"))
	# ★ B2 타이틀 테마 — 로파이 코지 플레이스홀더(.wav)로 해석. Suno .ogg가 떨어지면 자동 교체.
	_check("④d① title BGM 실제 파일로 해석", _resolves(A, GameAudio.PHASE_TITLE, "bgm_title"))
	_check("④d② BGM stem 5종(farm·cafe·night·ending·title)", GameAudio.BGM_STEM.size() == 5)
	# title은 UI 상태라 phase_for(시각·종료·위치)에서는 절대 나오지 않는다(main이 set_phase로 직접 건다).
	_check("④d③ title은 phase_for에서 안 나옴(UI 상태)",
		A.phase_for(NOON, false, false) != GameAudio.PHASE_TITLE
		and A.phase_for(DEEP_NIGHT, false, true) != GameAudio.PHASE_TITLE
		and A.phase_for(NOON, true, false) != GameAudio.PHASE_TITLE)
	_check("④e .ogg(Suno)가 .wav(플레이스홀더)보다 우선", GameAudio.BGM_EXTS[0] == ".ogg" and GameAudio.BGM_EXTS[1] == ".wav")
	# 같은 stem에 .ogg·.wav가 같이 있으면 .ogg가 잡힌다(실제 드롭인 검증 — farm이 그 경우).
	for phase in [GameAudio.PHASE_FARM, GameAudio.PHASE_CAFE, GameAudio.PHASE_NIGHT, GameAudio.PHASE_ENDING, GameAudio.PHASE_TITLE]:
		var stem: String = GameAudio.BGM_STEM[phase]
		if FileAccess.file_exists(GameAudio.BGM_DIR + stem + ".ogg") and FileAccess.file_exists(GameAudio.BGM_DIR + stem + ".wav"):
			_check("④f [%s] .ogg·.wav 공존 시 .ogg 우선(드롭인 교체)" % phase, A.bgm_source(phase).ends_with(".ogg"))
	_check("④g 모르는 phase는 빈 경로(빈 버스)", A.bgm_source("nope") == "")

	# ③ SFX 해석: ROADMAP P2.6 9종이 모두 실제 파일로 해석되고, 모르는 이벤트는 ""(무시).
	var events := ["hoe", "water", "harvest", "serve", "gold", "ui", "dialogue", "block", "sleep"]
	var all_ok := true
	for e in events:
		if not A.sfx_source(e).ends_with("/" + e + ".wav"):
			all_ok = false
	_check("⑤ SFX 9종 전부 실제 파일로 해석", all_ok)
	_check("⑤b 매핑 키도 정확히 9종(ROADMAP 목록과 1:1)", GameAudio.SFX_STEM.size() == 9)
	_check("⑤c 모르는 이벤트는 빈 경로(조용히 무시)", A.sfx_source("explode") == "")
	_check("⑤d 빈 문자열 이벤트도 안전", A.sfx_source("") == "")

	A.free()

# ── ④ 스모크: 트리에 붙여 버스 조립·재생·음소거가 죽지 않는지 ────────────────
func _smoke_checks() -> void:
	var A := GameAudio.new()
	get_root().add_child(A)
	await process_frame  # _ready 실행(버스 조립·플레이어 풀 생성)

	_check("⑥ Music 버스 조립됨", AudioServer.get_bus_index(GameAudio.MUSIC_BUS) != -1)
	_check("⑥b SFX 버스 조립됨", AudioServer.get_bus_index(GameAudio.SFX_BUS) != -1)

	# 매 프레임 라우팅: 밭→카페→밤→엔딩으로 phase가 바뀌어도 죽지 않고 곡을 건다(헤드리스는
	# 실제 play() 생략 — phase 상태·스트림 배정은 그대로라 전환 계약은 검증된다). update_music은
	# (분, run_over, in_cafe).
	A.update_music(NOON, false, false)  # 낮·카페 밖
	await process_frame
	_check("⑦ 낮 카페 밖 = farm BGM", A._current_phase == GameAudio.PHASE_FARM)
	# BGM은 루프로 설정된다(끊기지 않고 돈다). 방금 깐 플레이어의 스트림이 — .wav 플레이스홀더든
	# .ogg Suno 생성본이든 — 루프로 잡혔는지 확인(WAV=LOOP_FORWARD+loop_end / Ogg=loop).
	var music := A.get_children().filter(func(n): return n is AudioStreamPlayer and n.stream != null)
	var looped := music.any(func(p):
		return (p.stream is AudioStreamWAV and p.stream.loop_mode == AudioStreamWAV.LOOP_FORWARD and p.stream.loop_end > 0) \
			or (p.stream is AudioStreamOggVorbis and p.stream.loop))
	_check("⑦① BGM 스트림이 루프로 설정됨(.wav/.ogg 공통)", looped)
	A.update_music(NOON, false, true)  # 같은 낮인데 카페 안으로 입장
	await process_frame
	_check("⑦b 카페 입장 시 cafe BGM으로 전환(위치 분기)", A._current_phase == GameAudio.PHASE_CAFE)
	A.update_music(DEEP_NIGHT, false, true)  # 밤엔 카페 안이어도 night
	await process_frame
	_check("⑦c 밤으로 phase 전환(카페 안이어도 night)", A._current_phase == GameAudio.PHASE_NIGHT)
	A.update_music(NOON, true, false)  # run_over=true → 시각·위치 무관 엔딩
	await process_frame
	_check("⑦d 슬라이스 종료 시 엔딩으로 전환", A._current_phase == GameAudio.PHASE_ENDING)
	# ★ B2 타이틀: main이 타이틀을 띄울 때 직접 거는 phase(update_music 경로 아님). 스트림이 배정되고
	#   루프로 잡힌다(pause 중 재생·페이드는 ALWAYS 덕 — 헤드리스는 play() 생략, 상태·배정은 그대로).
	A.set_phase(GameAudio.PHASE_TITLE)
	await process_frame
	_check("⑦e set_phase(title) → 타이틀 테마로 전환", A._current_phase == GameAudio.PHASE_TITLE)
	_check("⑦f 오디오 노드는 ALWAYS(pause 중에도 BGM 유지)", A.process_mode == Node.PROCESS_MODE_ALWAYS)

	# ★ 부팅 충돌 회귀(타이틀 BGM 1초 컷 버그): _setup_audio의 update_music(farm)과 _show_title의
	#   set_phase(title)이 *같은 프레임*에 연달아 일어나면, farm에서 페이드아웃+정지 예약된 플레이어가
	#   그대로 title의 incoming으로 재사용된다. _fade가 이전 트윈을 kill하지 않으면 낡은 "정지 콜백"이
	#   1초 뒤 발동해 방금 깐 title을 죽인다. → _fade가 재사용 플레이어의 낡은 트윈을 kill하는지 단언.
	var B := GameAudio.new()
	get_root().add_child(B)
	await process_frame
	B.update_music(NOON, false, false)   # farm: incoming=_music_b·outgoing=_music_a(정지 예약)
	var stale: Tween = B._music_tweens.get(B._music_a.get_instance_id())
	_check("⑦g farm 후 A(다음 incoming)에 페이드 트윈 예약됨", stale != null and stale.is_valid())
	B.set_phase(GameAudio.PHASE_TITLE)   # 같은 프레임: A를 title로 재사용
	_check("⑦h 재사용된 A의 낡은 트윈이 kill됨(정지 콜백 취소 — 1초 컷 방지)", stale == null or not stale.is_valid())
	_check("⑦i title이 A에 실림", B._music_a.stream != null and B._music_a.stream.resource_path.get_file().begins_with("bgm_title"))
	B.free()

	# SFX: 9종 + 미정의/빈 이벤트를 연달아 쏴도 풀이 죽지 않는다(라운드로빈 보이스).
	for e in ["hoe", "water", "harvest", "serve", "gold", "ui", "dialogue", "block", "sleep", "explode", ""]:
		A.sfx(e)
	_check("⑧ SFX 연속 재생 후에도 살아 있음(보이스 풀)", A._sfx_pool.size() == GameAudio.SFX_VOICES)

	# 음소거: 토글이 상태를 뒤집고 버스를 음소거하며, 음소거 중엔 SFX가 무시된다.
	var m1 := A.toggle_mute()
	_check("⑨ 음소거 토글 → true", m1 == true and A.is_muted())
	_check("⑨b 음소거 시 Music 버스 mute", AudioServer.is_bus_mute(AudioServer.get_bus_index(GameAudio.MUSIC_BUS)))
	A.sfx("harvest")  # 음소거 중 — 그냥 무시(크래시 없음)
	var m2 := A.toggle_mute()
	_check("⑨c 다시 토글 → false(원복)", m2 == false and not A.is_muted())
	_check("⑨d 음소거 해제 시 Music 버스 unmute", not AudioServer.is_bus_mute(AudioServer.get_bus_index(GameAudio.MUSIC_BUS)))

	# 종료 전 동기 해제(lighting_test가 L.free()로 닫는 결). 헤드리스에선 play()를 건너뛰어
	# 재생 중인 playback이 없으므로, free 시 자식 플레이어와 그들이 든 스트림 참조가 깨끗이
	# 풀려 누수·orphan 0으로 닫힌다.
	A.free()
