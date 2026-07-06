extends CanvasLayer
class_name TitleScreen
# ★타이틀 화면(gemini-ui-identity-spec §3.4) — 부팅 첫인상. 패럴랙스 씬(title_bg) + 붓글씨
#   로고(title_logo, 동적 붉은 셰이더) + 코드 파티clemos + 메뉴 5개(새게임·이어하기·설정·
#   만든사람들·종료) + 멀티 슬롯 선택(save.gd slot_meta 소비). main이 부팅 시 실제 실행에서만
#   띄우고(테스트는 안 띄움 — current_scene 게이트), 선택 시 start_game/quit_game을 쏜다.
#
# 설계 메모:
#   - CanvasLayer(layer 128, PROCESS_MODE_ALWAYS)라 월드 위에 뜨고 get_tree().paused=true 중에도
#     동작한다(월드 시뮬 정지·입력 격리). 배경/파티클/메뉴는 자식 Control(_Canvas)의 즉시모드
#     _draw로, 로고만 셰이더가 필요해 별도 TextureRect(ShaderMaterial)로 위에 얹는다.
#   - 상태 없는 순수 로직(move_selection·activate·slot 포맷)은 GPU 없이 헤드리스로 검증 가능하게
#     그리기와 분리한다(title_test.gd). 그리기는 title_dump.gd(비-headless)로 육안 확인.
#   - 폰트·팔레트·9-slice는 HanjiUi 공용(태운 한지 톤 통일).

signal start_game(slot: int, is_new: bool)   # 슬롯을 정해 게임 시작(is_new=신규/이어하기)
signal quit_game()                            # 게임 종료
# ★ B2 설정 실동작 — 인게임 옵션 탭(inv_frame.gd)과 같은 디커플링: 타이틀은 값 표시·조작 신호만 쏘고,
#   main이 실제 적용(버스 볼륨·창모드)·영속(settings.cfg)을 수행한다. main은 옵션 탭과 *같은* 핸들러
#   (_on_music_vol_changed 등)에 이 신호들을 연결해 단일 값 원천(GameSettings)을 공유한다.
signal music_nudged(delta: float)             # 음악 볼륨 증감(설정 패널 −/+·좌우)
signal sfx_nudged(delta: float)               # 효과음 볼륨 증감(설정 패널 −/+·좌우)
signal fullscreen_nudged()                    # 전체화면 토글(설정 패널 체크박스·엔터/좌우)

const VIEW := Vector2(960.0, 540.0)           # 스트레치 뷰포트(project.godot)
const BG_TEX: Texture2D = preload("res://assets/ui/title_bg.png")

# ── ★ 패럴랙스 배경 + 직원 idle(owner-Gemini 아트 트랙 계약) ──
# 배경을 깊이 레이어로 쌓아 마우스/시간에 따라 다른 속도로 흐르게 하고(원경 느림·근경 빠름),
# 직원 레이어엔 미세 숨쉬기(bob)를 얹어 '살아 있는' 첫인상을 만든다. 레이어 PNG는 owner가 Gemini로
# 슬라이스해 res://assets/ui/에 넣는다(계약=docs/design/title-parallax-layers-spec.md). 파일이 아직
# 없으면 flat 합성본(title_bg.png)을 단일 레이어로 그리되 은은한 드리프트만 준다(fallback — 안 죽음).
#
# 레이어 계약(뒤→앞, 모두 1280×720·16:9·sky만 불투명·나머지 알파). sky가 있어야 '레이어 모드'로 간주.
#   sky=하늘/원경(가장 느림) · mid=카페 건물/가구(중간) · okja/miho/mel/bana=각 직원(근경·bob).
const LAYER_SPECS := [
	{"file": "title_layer_sky",  "depth": 0.10, "bob": false, "phase": 0.0},
	{"file": "title_layer_mid",  "depth": 0.35, "bob": false, "phase": 0.0},
	{"file": "title_layer_okja", "depth": 0.60, "bob": true,  "phase": 0.0},
	{"file": "title_layer_miho", "depth": 0.70, "bob": true,  "phase": 1.7},
	{"file": "title_layer_mel",  "depth": 0.80, "bob": true,  "phase": 3.3},
	{"file": "title_layer_bana", "depth": 0.90, "bob": true,  "phase": 4.9},
]
const OVERSCAN := 1.07            # 레이어를 뷰보다 살짝 크게 그려(양옆 여백) 흔들려도 가장자리가 안 드러나게
const PARALLAX_MOUSE := 11.0      # 마우스 좌우 시차 최대 이동(px, depth 1.0 기준·좌우가 상하보다 큼)
const PARALLAX_MOUSE_Y := 6.0     # 마우스 상하 시차 최대 이동(px)
const DRIFT_AMP := 3.0            # 마우스가 없어도 살도록 자율 드리프트 진폭(px, 느린 사인)
const DRIFT_SPEED := 0.22         # 드리프트 각속도(rad/s) — 느긋한 코지 텐포
const BOB_AMP := 2.6              # 직원 숨쉬기 상하 진폭(px, 깊이와 무관한 고유 진동)
const BOB_SPEED := 1.7            # 직원 숨쉬기 각속도(rad/s)
const LOGO_TEX: Texture2D = preload("res://assets/ui/title_logo.png")
const LOGO_SHADER: Shader = preload("res://assets/ui/title_logo.gdshader")
const FOXFIRE := Color(0.376, 0.847, 0.941)   # 파란 여우불 #60d8f0
const EMBER := Color(1.0, 0.72, 0.32)         # 따뜻한 불티
const TEALEAF := Color(0.62, 0.44, 0.28)      # 찻잎 갈색

enum State { MENU, SLOTS, CONFIRM_NEW, CONFIRM_QUIT, SETTINGS, CREDITS }

# 설정 패널 행(순서 = _sel 의미·_sel_count SETTINGS). 볼륨 두 줄은 좌우로 조정, 전체화면은 토글, 뒤로는 복귀.
enum SetRow { MUSIC, SFX, FULLSCREEN, BACK }

# ★ B2 Credits — 개발진·감사 명단(아래→위 자동 스크롤, gemini-ui-identity-spec §j·Steam 출시 필수).
#   순수 텍스트 데이터라 owner가 이름·역할을 자유로이 편집한다(무상태 — 조작 없음, 스크롤만).
#   kind: "title"(큰 금박)·"role"(역할 헤더)·"name"(이름)·"note"(작은 보조)·"gap"(빈 줄).
const CREDITS := [
	{"kind": "gap"}, {"kind": "gap"}, {"kind": "gap"},
	{"kind": "title", "text": "Dear My Naraka"},
	{"kind": "note", "text": "디어 마이 나라카"},
	{"kind": "gap"}, {"kind": "gap"},
	{"kind": "role", "text": "기획 · 연출"},
	{"kind": "name", "text": "JeffKM"},
	{"kind": "gap"},
	{"kind": "role", "text": "프로그래밍"},
	{"kind": "name", "text": "JeffKM"},
	{"kind": "gap"},
	{"kind": "role", "text": "도트 아트"},
	{"kind": "name", "text": "Gemini · PixelLab"},
	{"kind": "gap"},
	{"kind": "role", "text": "음악 · 사운드"},
	{"kind": "name", "text": "준비 중"},
	{"kind": "gap"}, {"kind": "gap"},
	{"kind": "role", "text": "저승 컨셉카페 식구들"},
	{"kind": "name", "text": "옥자 · 미호 · 멜 · 바나"},
	{"kind": "gap"}, {"kind": "gap"},
	{"kind": "role", "text": "함께한 도구들"},
	{"kind": "name", "text": "Godot Engine"},
	{"kind": "name", "text": "Aseprite"},
	{"kind": "gap"}, {"kind": "gap"},
	{"kind": "role", "text": "특별히"},
	{"kind": "name", "text": "이 이야기를 함께한 당신께"},
	{"kind": "gap"}, {"kind": "gap"},
	{"kind": "note", "text": "— 당신의 저승에서 —"},
	{"kind": "gap"}, {"kind": "gap"}, {"kind": "gap"},
]
const CREDITS_SPEED := 34.0   # 스크롤 속도(px/s) — 느긋한 코지 텐포

const VOL_STEP := 0.1             # 볼륨 −/+ 한 눈금(옵션 탭 inv_frame.gd과 동일 — 단일 조작 규격)

var _saver: SaveManager
var _settings: GameSettings       # ★ B2 설정 값 원천(main이 주입). null이면(테스트) 기본값 표시·조작만 신호로
var _state: State = State.MENU
var _sel := 0                     # 현재 상태의 선택 인덱스
var _t := 0.0                     # 파티클·패럴랙스 애니 시간
var _particles: Array = []        # {pos, vel, kind, size, ph}
# ★ 패럴랙스 배경 상태. _layers 비면 flat fallback(BG_TEX). _mouse_norm=화면중앙 기준 [-1,1] 마우스 위치.
var _layers: Array = []           # {tex, depth, bob, phase} — sky가 있을 때만 채워짐(레이어 모드)
var _mouse_norm := Vector2.ZERO   # 마우스 시차 입력(키보드 조작 시 0=중앙 → 드리프트/bob만)
var _hit: Array[Rect2] = []       # 현재 상태 선택 항목 히트 rect(마우스)
# ★ B2 설정 패널 세부 컨트롤 히트 rect(마우스 −/+·체크박스·뒤로 — _paint_settings가 채운다).
var _set_music_minus := Rect2()
var _set_music_plus := Rect2()
var _set_sfx_minus := Rect2()
var _set_sfx_plus := Rect2()
var _set_fs_rect := Rect2()
var _set_back_rect := Rect2()
var _credits_y := 0.0             # ★ B2 Credits 스크롤 오프셋(아래→위, _process가 증가·끝나면 루프)

const MENU_ITEMS := ["새 게임", "이어하기", "설정", "만든 사람들", "종료"]

var _canvas: Control              # 배경·파티클·메뉴 그리는 자식
var _logo: TextureRect            # 셰이더 로고(위에 얹음)

# ── 내부 캔버스(즉시모드 _draw를 바깥 TitleScreen으로 위임) ──
class _Canvas extends Control:
	var ts: TitleScreen
	func _draw() -> void:
		if ts != null:
			ts._paint(self)

func setup(saver: SaveManager, settings: GameSettings = null) -> void:
	_saver = saver
	_settings = settings   # ★ B2 설정 값 표시용(main이 주입). 조작 반영은 신호→main→GameSettings→다음 프레임 표시
	layer = 128
	process_mode = Node.PROCESS_MODE_ALWAYS
	_canvas = _Canvas.new()
	_canvas.ts = self
	_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_canvas)
	# 로고 — 셰이더로 붉은 기운이 흐른다(정적 PNG 위 가법). 상단 중앙.
	_logo = TextureRect.new()
	_logo.texture = LOGO_TEX
	_logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var mat := ShaderMaterial.new()
	mat.shader = LOGO_SHADER
	_logo.material = mat
	var lw := 460.0
	var lh := lw * float(LOGO_TEX.get_height()) / float(LOGO_TEX.get_width())
	_logo.position = Vector2((VIEW.x - lw) * 0.5, 18.0)
	_logo.size = Vector2(lw, lh)
	add_child(_logo)
	_load_layers()
	_seed_particles()
	_state = State.MENU
	_sel = 0

# 패럴랙스 레이어 로드 — sky가 있어야 레이어 모드로 간주(sky=불투명 베이스 없이 알파 직원만 그리면 배경이
# 뚫림). owner가 아직 안 넣었으면 _layers는 빈 채로 두고 _paint_backdrop이 flat 합성본으로 fallback.
func _load_layers() -> void:
	_layers.clear()
	var sky_path := "res://assets/ui/%s.png" % LAYER_SPECS[0].file
	if not ResourceLoader.exists(sky_path):
		return   # sky 없음 → flat fallback(BG_TEX)
	for s in LAYER_SPECS:
		var path := "res://assets/ui/%s.png" % s.file
		if ResourceLoader.exists(path):
			var tex: Texture2D = load(path)
			_layers.append({"tex": tex, "depth": s.depth, "bob": s.bob, "phase": s.phase})
			# 직원 레이어는 owner가 순차 export 중일 수 있어 없으면 그냥 건너뜀(그 직원만 안 보임).

func _seed_particles() -> void:
	_particles.clear()
	for i in 30:
		var kind := i % 3   # 0 찻잎 · 1 여우불 · 2 불티
		_particles.append({
			"pos": Vector2(randf() * VIEW.x, randf() * VIEW.y),
			"vel": Vector2(-14.0 - randf() * 20.0, 8.0 + randf() * 16.0),   # 좌하향 바람
			"kind": kind,
			"size": (2.0 + randf() * 2.0) if kind != 0 else (2.5 + randf() * 2.5),
			"ph": randf() * TAU,
		})

func _process(delta: float) -> void:
	_t += delta
	for p in _particles:
		p.pos += p.vel * delta
		# 화면 밖으로 나가면 반대편에서 다시(대각선 흐름 유지).
		if p.pos.x < -8.0:
			p.pos.x = VIEW.x + 8.0
			p.pos.y = randf() * VIEW.y
		if p.pos.y > VIEW.y + 8.0:
			p.pos.y = -8.0
			p.pos.x = randf() * VIEW.x
	# ★ B2 Credits 자동 스크롤(아래→위) — 명단이 다 지나가면 처음으로 되감아 반복(코지 무한 롤).
	if _state == State.CREDITS:
		_credits_y += CREDITS_SPEED * delta
		if _credits_y > _credits_total_h() + VIEW.y:
			_credits_y = 0.0
	if _canvas != null:
		_canvas.queue_redraw()

# ── 입력(키보드 + 마우스). paused 중에도 ALWAYS라 들어온다. ──
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_UP, KEY_W:
				move_selection(-1)
			KEY_DOWN, KEY_S:
				move_selection(1)
			KEY_LEFT, KEY_A:
				adjust(-1)   # 설정 패널에서만 의미(볼륨 감소·전체화면 토글). 다른 상태는 무동작.
			KEY_RIGHT, KEY_D:
				adjust(1)
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
				activate()
			KEY_ESCAPE:
				_cancel()
	elif event is InputEventMouseMotion:
		var mp: Vector2 = _canvas.get_local_mouse_position() if _canvas != null else event.position
		# ★ 패럴랙스 시차 입력 — 화면 중앙 기준 정규화([-1,1]). _process가 매 프레임 redraw하므로 여기선 값만.
		_mouse_norm = Vector2(
			clampf((mp.x / VIEW.x - 0.5) * 2.0, -1.0, 1.0),
			clampf((mp.y / VIEW.y - 0.5) * 2.0, -1.0, 1.0))
		for i in _hit.size():
			if _hit[i].has_point(mp):
				if _sel != i:
					_sel = i
					_canvas.queue_redraw()
				break
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var mp2: Vector2 = _canvas.get_local_mouse_position() if _canvas != null else event.position
		# 설정 패널은 −/+·체크박스 세부 rect를 먼저 처리(행 전체 _hit로는 눈금 조작이 불가).
		if _state == State.SETTINGS and _settings_click(mp2):
			return
		for i in _hit.size():
			if _hit[i].has_point(mp2):
				_sel = i
				activate()
				break

# ESC/뒤로 = 하위 상태면 메뉴로, 메뉴면 종료 확인.
func _cancel() -> void:
	match _state:
		State.MENU:
			_go(State.CONFIRM_QUIT)
		_:
			_go(State.MENU)

func _sel_count() -> int:
	match _state:
		State.MENU: return MENU_ITEMS.size()
		State.SLOTS: return SaveManager.SLOT_COUNT + 1   # 슬롯 3 + 뒤로
		State.CONFIRM_NEW, State.CONFIRM_QUIT: return 2  # 예 / 아니오
		State.SETTINGS: return SetRow.size()              # 음악·효과음·전체화면·뒤로
		State.CREDITS: return 1                           # 아무 키·클릭 = 돌아가기
	return 1

func move_selection(dir: int) -> void:
	var n := _sel_count()
	_sel = (_sel + dir + n) % n
	if _canvas != null:
		_canvas.queue_redraw()

func _go(s: State) -> void:
	_state = s
	_sel = 0
	if s == State.CREDITS:
		_credits_y = 0.0   # 진입 시 명단을 맨 아래에서 다시 시작
	# 로고는 메인 메뉴에서만(서브 패널 슬롯·확인·정보 위를 가리지 않게).
	if _logo != null:
		_logo.visible = s == State.MENU
	if _canvas != null:
		_canvas.queue_redraw()

# 현재 선택 실행(상태별 라우팅). 순수 로직(그리기 무관·테스트 대상).
func activate() -> void:
	match _state:
		State.MENU:
			match _sel:
				0:   # 새 게임 — 슬롯0에 세이브 있으면 지우기 확인
					if _saver != null and _saver.has_save(0):
						_go(State.CONFIRM_NEW)
					else:
						start_game.emit(0, true)
				1:   # 이어하기 — 슬롯 선택
					_go(State.SLOTS)
				2:   # 설정 — 볼륨·전체화면 실동작 패널(★ B2)
					_go(State.SETTINGS)
				3:   # 만든 사람들 — 스크롤 명단(★ B2)
					_go(State.CREDITS)
				4:   # 종료
					_go(State.CONFIRM_QUIT)
		State.SLOTS:
			if _sel < SaveManager.SLOT_COUNT:
				var occupied := _saver != null and _saver.has_save(_sel)
				start_game.emit(_sel, not occupied)   # 있으면 이어하기·비면 신규
			else:
				_go(State.MENU)   # 뒤로
		State.CONFIRM_NEW:
			if _sel == 0:
				start_game.emit(0, true)   # 예 — 지우고 새로(main이 delete 후 신규)
			else:
				_go(State.MENU)
		State.CONFIRM_QUIT:
			if _sel == 0:
				quit_game.emit()
			else:
				_go(State.MENU)
		State.SETTINGS:
			# 엔터 = 현재 행 실행. 볼륨 두 줄은 좌우로 조정하므로 엔터는 전체화면 토글·뒤로만 의미.
			match _sel:
				SetRow.FULLSCREEN:
					fullscreen_nudged.emit()
				SetRow.BACK:
					_go(State.MENU)
		State.CREDITS:
			_go(State.MENU)   # 엔터/스페이스 = 명단 닫고 메뉴로(ESC도 _cancel 경유 동일)

# 설정 패널 좌/우(또는 −/+ 키) 조정 — 값 변경은 신호로 main에 올린다(디커플링). dir: -1 감소·+1 증가.
func adjust(dir: int) -> void:
	if _state != State.SETTINGS:
		return
	match _sel:
		SetRow.MUSIC:
			music_nudged.emit(float(dir) * VOL_STEP)
		SetRow.SFX:
			sfx_nudged.emit(float(dir) * VOL_STEP)
		SetRow.FULLSCREEN:
			fullscreen_nudged.emit()   # 체크박스 — 좌우 어느 쪽이든 토글(이진 값)
		# BACK: 조정 없음
	if _canvas != null:
		_canvas.queue_redraw()

# 설정 패널 마우스 클릭 — −/+·체크박스·뒤로 세부 rect 판정. 처리했으면 true(호출부가 일반 _hit 건너뜀).
func _settings_click(mp: Vector2) -> bool:
	if _set_music_minus.has_point(mp):
		_sel = SetRow.MUSIC; music_nudged.emit(-VOL_STEP)
	elif _set_music_plus.has_point(mp):
		_sel = SetRow.MUSIC; music_nudged.emit(VOL_STEP)
	elif _set_sfx_minus.has_point(mp):
		_sel = SetRow.SFX; sfx_nudged.emit(-VOL_STEP)
	elif _set_sfx_plus.has_point(mp):
		_sel = SetRow.SFX; sfx_nudged.emit(VOL_STEP)
	elif _set_fs_rect.has_point(mp):
		_sel = SetRow.FULLSCREEN; fullscreen_nudged.emit()
	elif _set_back_rect.has_point(mp):
		_go(State.MENU)
	else:
		return false
	if _canvas != null:
		_canvas.queue_redraw()
	return true

# 슬롯 메타 → 코지 다이어리 한 줄. 순수 함수(테스트 대상).
func slot_label(slot: int) -> String:
	if _saver == null or not _saver.has_save(slot):
		return "빈 슬롯"
	var meta := _saver.slot_meta(slot)
	if meta.is_empty() or not meta.has("day"):
		return "저장됨"
	var day := int(meta.get("day", 1))
	var soul := int(meta.get("soul", 0))
	var year := (day - 1) / 112 + 1
	var season := GameClock.season_name(GameClock.season_index_for_day(day))
	var dos := (day - 1) % 28 + 1
	return "%d년차 %s %d일 · 혼력 %d" % [year, season, dos, soul]

# ── 그리기(즉시모드) — _Canvas._draw에서 위임. ──
func _paint(ci: CanvasItem) -> void:
	_hit.clear()
	_paint_backdrop(ci)
	_paint_particles(ci)
	# 하단 은은한 어둠(메뉴 가독) — 코지 인디고 비네트.
	ci.draw_rect(Rect2(0.0, VIEW.y - 250.0, VIEW.x, 250.0), Color(0.08, 0.06, 0.12, 0.28))
	# 최하단 은은한 바닥 비네트(코지 그라운딩).
	ci.draw_rect(Rect2(0.0, VIEW.y - 40.0, VIEW.x, 40.0), Color(0.05, 0.04, 0.09, 0.35))
	match _state:
		State.MENU:
			_paint_menu(ci)
		State.SLOTS:
			_paint_slots(ci)
		State.CONFIRM_NEW:
			_paint_confirm(ci, "오늘까지의 진행을 지우고\n새로 시작할까요?")
		State.CONFIRM_QUIT:
			_paint_confirm(ci, "오늘 영업을 마감하고\n안식처를 떠나시겠습니까?")
		State.SETTINGS:
			_paint_settings(ci)
		State.CREDITS:
			_paint_credits(ci)

# ★ 패럴랙스 배경 — 레이어 모드면 뒤→앞으로 깊이별 시차/숨쉬기, 아니면 flat 합성본에 은은한 드리프트.
func _paint_backdrop(ci: CanvasItem) -> void:
	if _layers.is_empty():
		# fallback — 단일 합성본. depth 0.25로 통짜 미세 드리프트/시차(살아 있게), bob 없음.
		_draw_layer(ci, BG_TEX, _layer_shift(0.25, false, 0.0))
		return
	for L in _layers:
		_draw_layer(ci, L.tex, _layer_shift(L.depth, L.bob, L.phase))

# 한 레이어의 이동량(순수 함수 — GPU 무관, title_test 대상). 마우스 시차 + 자율 드리프트(깊이 비례) +
# 직원이면 숨쉬기 bob(깊이 무관 고유 진동). 모든 항의 합은 OVERSCAN 여백 안에 머문다(가장자리 안 드러남).
func _layer_shift(depth: float, does_bob: bool, phase: float) -> Vector2:
	var sx := -_mouse_norm.x * PARALLAX_MOUSE * depth + sin(_t * DRIFT_SPEED) * DRIFT_AMP * depth
	var sy := _mouse_norm.y * PARALLAX_MOUSE_Y * depth + sin(_t * DRIFT_SPEED * 0.7 + 1.0) * DRIFT_AMP * 0.6 * depth
	if does_bob:
		sy += sin(_t * BOB_SPEED + phase) * BOB_AMP
		sx += sin(_t * BOB_SPEED * 0.5 + phase) * BOB_AMP * 0.4
	return Vector2(sx, sy)

# 레이어 텍스처를 뷰보다 OVERSCAN배 크게(중앙 정렬) 그린 뒤 shift만큼 민다. 1280×720·960×540 둘 다 16:9라 왜곡 없음.
func _draw_layer(ci: CanvasItem, tex: Texture2D, shift: Vector2) -> void:
	var w := VIEW.x * OVERSCAN
	var h := VIEW.y * OVERSCAN
	var pos := Vector2((VIEW.x - w) * 0.5, (VIEW.y - h) * 0.5) + shift
	ci.draw_texture_rect(tex, Rect2(pos, Vector2(w, h)), false)

func _paint_particles(ci: CanvasItem) -> void:
	for p in _particles:
		var tw := 0.55 + 0.45 * sin(_t * 2.0 + p.ph)   # 반짝임
		var col: Color
		match p.kind:
			1: col = FOXFIRE
			2: col = EMBER
			_: col = TEALEAF
		col.a = (0.30 + 0.45 * tw) if p.kind != 0 else (0.22 + 0.25 * tw)
		if p.kind == 0:
			# 찻잎 — 작은 사각(회전 생략, 값쌈).
			ci.draw_rect(Rect2(p.pos - Vector2(p.size, p.size * 0.5), Vector2(p.size * 2.0, p.size)), col)
		else:
			# 여우불·불티 — 은은한 글로우(2겹 원).
			var g := col
			g.a *= 0.4
			ci.draw_circle(p.pos, p.size * 1.9, g)
			ci.draw_circle(p.pos, p.size, col)

func _paint_menu(ci: CanvasItem) -> void:
	var fs := 26
	var gap := 40.0
	var n := MENU_ITEMS.size()
	var total := gap * n
	var x0 := VIEW.x * 0.5
	var y0 := VIEW.y - total - 40.0
	# 메뉴 뒤 은은한 한지 판(가독).
	var pw := 300.0
	HanjiUi.draw_plate(ci, Rect2(x0 - pw * 0.5, y0 - 18.0, pw, total + 20.0), 0.55)
	for i in n:
		var y := y0 + gap * i + float(fs)
		var selected := i == _sel
		var label: String = MENU_ITEMS[i]
		var col := HanjiUi.GOLD_SOFT if selected else HanjiUi.INK_LIGHT
		var w := HanjiUi.text_width(label, fs)
		var tx := x0 - w * 0.5
		if selected:
			HanjiUi.draw_text(ci, Vector2(tx - 26.0, y), "❀", fs, HanjiUi.GOLD)
		HanjiUi.draw_text(ci, Vector2(tx, y), label, fs, col)
		_hit.append(Rect2(x0 - pw * 0.5, y0 + gap * i - 4.0, pw, gap))

func _paint_slots(ci: CanvasItem) -> void:
	var fw := 560.0
	var fh := 300.0
	var rect := Rect2((VIEW.x - fw) * 0.5, (VIEW.y - fh) * 0.5, fw, fh)
	HanjiUi.draw_frame(ci, rect)
	var cx := rect.position.x + 40.0
	var right := rect.end.x - 40.0
	var y := rect.position.y + 54.0
	HanjiUi.draw_text(ci, Vector2(cx, y), "이어할 이야기를 고르세요", 22, HanjiUi.INK)
	y += 20.0
	var rowh := 52.0
	for i in SaveManager.SLOT_COUNT:
		var ry := y + rowh * i + 8.0
		var rrect := Rect2(cx - 8.0, ry, right - cx + 16.0, rowh - 8.0)
		var selected := i == _sel
		HanjiUi.draw_plate(ci, rrect, 0.85 if selected else 0.5)
		var head := "슬롯 %d" % (i + 1)
		var body := slot_label(i)
		var hc := HanjiUi.GOLD if selected else HanjiUi.INK
		HanjiUi.draw_text(ci, Vector2(cx + 4.0, ry + 22.0), head, 18, hc)
		HanjiUi.draw_text(ci, Vector2(cx + 4.0, ry + 40.0), body, 15, HanjiUi.INK_DIM)
		_hit.append(rrect)
	# 뒤로
	var by := y + rowh * SaveManager.SLOT_COUNT + 12.0
	var back_sel := _sel == SaveManager.SLOT_COUNT
	var bcol := HanjiUi.GOLD_SOFT if back_sel else HanjiUi.INK
	HanjiUi.draw_text(ci, Vector2(cx, by + 16.0), ("❀ " if back_sel else "") + "뒤로", 18, bcol)
	_hit.append(Rect2(cx - 8.0, by, 120.0, 28.0))

func _paint_confirm(ci: CanvasItem, msg: String) -> void:
	var fw := 480.0
	var fh := 220.0
	var rect := Rect2((VIEW.x - fw) * 0.5, (VIEW.y - fh) * 0.5, fw, fh)
	HanjiUi.draw_frame(ci, rect)
	var lines := msg.split("\n")
	var y := rect.position.y + 60.0
	for line in lines:
		var w := HanjiUi.text_width(line, 20)
		HanjiUi.draw_text(ci, Vector2(rect.position.x + (fw - w) * 0.5, y), line, 20, HanjiUi.INK)
		y += 28.0
	# 예 / 아니오
	var labels := ["예", "아니오"]
	var by := rect.end.y - 44.0
	var slotw := fw * 0.5
	for i in 2:
		var selected := i == _sel
		var col := HanjiUi.GOLD_SOFT if selected else HanjiUi.INK
		var w := HanjiUi.text_width(labels[i], 22)
		var bx := rect.position.x + slotw * i + (slotw - w) * 0.5
		HanjiUi.draw_text(ci, Vector2(bx, by + 18.0), (("❀ " if selected else "") + labels[i]), 22, col)
		_hit.append(Rect2(rect.position.x + slotw * i, by, slotw, 34.0))

# ★ B2 설정 패널 — 음악·효과음 볼륨(−/+·트랙바) + 전체화면 체크박스 + 뒤로. 값은 _settings(GameSettings)에서
#   읽어 표시만 하고(무상태), 조작은 신호로 main에 올려 실제 적용·영속을 맡긴다(옵션 탭 inv_frame.gd과 동형).
func _paint_settings(ci: CanvasItem) -> void:
	var fw := 520.0
	var fh := 320.0
	var rect := Rect2((VIEW.x - fw) * 0.5, (VIEW.y - fh) * 0.5, fw, fh)
	HanjiUi.draw_frame(ci, rect)
	# 제목.
	var tw := HanjiUi.text_width("설정", 24)
	HanjiUi.draw_text(ci, Vector2(rect.position.x + (fw - tw) * 0.5, rect.position.y + 50.0), "설정", 24, HanjiUi.INK)
	var x := rect.position.x + 46.0
	# 값(_settings 없으면 기본값 — 테스트/GPU-무 경로).
	var mv: float = _settings.music_volume if _settings != null else 0.8
	var sv: float = _settings.sfx_volume if _settings != null else 0.9
	var fsv: bool = _settings.fullscreen if _settings != null else false
	# 음악 볼륨.
	var my := rect.position.y + 110.0
	var mr := _paint_vol_row(ci, x, my, "음악 볼륨", mv, _sel == SetRow.MUSIC)
	_set_music_minus = mr[0]; _set_music_plus = mr[1]
	_hit.append(Rect2(rect.position.x + 20.0, my - 22.0, fw - 40.0, 32.0))
	# 효과음 볼륨.
	var sy := my + 46.0
	var sr := _paint_vol_row(ci, x, sy, "효과음 볼륨", sv, _sel == SetRow.SFX)
	_set_sfx_minus = sr[0]; _set_sfx_plus = sr[1]
	_hit.append(Rect2(rect.position.x + 20.0, sy - 22.0, fw - 40.0, 32.0))
	# 전체화면 체크박스.
	var fy := sy + 52.0
	var fs_sel := _sel == SetRow.FULLSCREEN
	_set_fs_rect = Rect2(x, fy - 15.0, 20.0, 20.0)
	ci.draw_rect(_set_fs_rect, HanjiUi.INSET)
	ci.draw_rect(_set_fs_rect, HanjiUi.GOLD_SOFT if fs_sel else HanjiUi.BORDER, false, 1.0)
	if fsv:
		ci.draw_rect(_set_fs_rect.grow(-4.0), HanjiUi.GOLD)
	var fcol := HanjiUi.GOLD_SOFT if fs_sel else HanjiUi.INK
	HanjiUi.draw_text(ci, Vector2(x + 30.0, fy), ("❀ " if fs_sel else "") + "전체화면", 16, fcol)
	HanjiUi.draw_text(ci, Vector2(x + 150.0, fy), "(F11)", 13, HanjiUi.INK_DIM)
	_hit.append(Rect2(rect.position.x + 20.0, fy - 22.0, fw - 40.0, 32.0))
	# 언어(한국어 고정 — 표시만, ADR-0048 §2).
	HanjiUi.draw_text(ci, Vector2(x, fy + 34.0), "언어  한국어 (고정)", 13, HanjiUi.INK_DIM)
	# 뒤로.
	var by := fy + 66.0
	var back_sel := _sel == SetRow.BACK
	var bcol := HanjiUi.GOLD_SOFT if back_sel else HanjiUi.INK
	HanjiUi.draw_text(ci, Vector2(x, by), ("❀ " if back_sel else "") + "뒤로", 18, bcol)
	_set_back_rect = Rect2(x - 8.0, by - 20.0, 120.0, 30.0)
	_hit.append(_set_back_rect)

# 볼륨 한 줄(라벨 · [−] · 트랙바 · [+] · 백분율). [−]/[+] 히트 rect 둘을 배열로 돌려준다(옵션 탭과 동일 규격).
func _paint_vol_row(ci: CanvasItem, x: float, yy: float, label: String, v01: float, selected: bool) -> Array:
	var lcol := HanjiUi.GOLD_SOFT if selected else HanjiUi.INK
	if selected:
		HanjiUi.draw_text(ci, Vector2(x - 26.0, yy), "❀", 16, HanjiUi.GOLD)
	HanjiUi.draw_text(ci, Vector2(x, yy), label, 16, lcol)
	var minus := Rect2(x + 118.0, yy - 15.0, 22.0, 20.0)
	ci.draw_rect(minus, HanjiUi.INSET)
	ci.draw_rect(minus, HanjiUi.BORDER, false, 1.0)
	HanjiUi.draw_text(ci, Vector2(minus.position.x + 7.0, yy), "−", 18, HanjiUi.INK_LIGHT)
	var track := Rect2(x + 150.0, yy - 12.0, 150.0, 13.0)
	ci.draw_rect(track, HanjiUi.INSET)
	ci.draw_rect(track, HanjiUi.BORDER, false, 1.0)
	if v01 > 0.0:
		ci.draw_rect(Rect2(track.position, Vector2(track.size.x * clampf(v01, 0.0, 1.0), track.size.y)), HanjiUi.GOLD)
	var plus := Rect2(x + 308.0, yy - 15.0, 22.0, 20.0)
	ci.draw_rect(plus, HanjiUi.INSET)
	ci.draw_rect(plus, HanjiUi.BORDER, false, 1.0)
	HanjiUi.draw_text(ci, Vector2(plus.position.x + 6.0, yy), "+", 17, HanjiUi.INK_LIGHT)
	HanjiUi.draw_text(ci, Vector2(x + 340.0, yy), "%d%%" % roundi(v01 * 100.0), 15, HanjiUi.INK)
	return [minus, plus]

# ── ★ B2 Credits(개발진·감사 명단, 아래→위 자동 스크롤) ──
# kind별 글자 크기·색·줄높이(advance). 어두운 월드 위에 떠 있으므로 밝은 글자(INK_LIGHT)로 가독.
func _credits_style(kind: String) -> Array:
	match kind:
		"title": return [34, HanjiUi.GOLD, 48.0]
		"role":  return [20, HanjiUi.GOLD_SOFT, 34.0]
		"name":  return [17, HanjiUi.INK_LIGHT, 26.0]
		"note":  return [13, HanjiUi.INK_DIM, 22.0]
		_:       return [0, HanjiUi.INK_DIM, 24.0]   # gap(빈 줄)
	return [0, HanjiUi.INK_DIM, 24.0]

# 명단 전체 높이(줄높이 합) — 스크롤 되감기 기준(_process).
func _credits_total_h() -> float:
	var h := 0.0
	for line in CREDITS:
		h += float(_credits_style(String(line.get("kind", "gap")))[2])
	return h

func _paint_credits(ci: CanvasItem) -> void:
	# 명단 가독을 위해 화면을 은은히 어둡게 깐다(코지 인디고 암막).
	ci.draw_rect(Rect2(Vector2.ZERO, VIEW), Color(0.05, 0.04, 0.09, 0.62))
	var cx := VIEW.x * 0.5
	var y := VIEW.y - _credits_y   # 아래에서 시작해 위로 흐른다
	for line in CREDITS:
		var kind := String(line.get("kind", "gap"))
		var st := _credits_style(kind)
		var size: int = st[0]
		var col: Color = st[1]
		var adv: float = st[2]
		var text := String(line.get("text", ""))
		# 화면 안에 든 줄만 그린다(위로 벗어난 줄·하단 안내 바에 닿는 줄 컬링 — 겹침 방지).
		if size > 0 and text != "" and y > -40.0 and y < VIEW.y - 40.0:
			var w := HanjiUi.text_width(text, size)
			HanjiUi.draw_text(ci, Vector2(cx - w * 0.5, y), text, size, col)
		y += adv
	# 하단 고정 안내(스크롤과 무관 — 항상 보임).
	var hint := "아무 키 · 클릭 — 돌아가기"
	var hw := HanjiUi.text_width(hint, 13)
	ci.draw_rect(Rect2(0.0, VIEW.y - 34.0, VIEW.x, 34.0), Color(0.05, 0.04, 0.09, 0.55))
	HanjiUi.draw_text(ci, Vector2(cx - hw * 0.5, VIEW.y - 12.0), hint, 13, HanjiUi.INK_DIM)
	# 화면 아무 곳이나 클릭하면 돌아가도록 전체 히트 rect 하나(activate → 메뉴).
	_hit.append(Rect2(Vector2.ZERO, VIEW))
