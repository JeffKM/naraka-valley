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

const VIEW := Vector2(960.0, 540.0)           # 스트레치 뷰포트(project.godot)
const BG_TEX: Texture2D = preload("res://assets/ui/title_bg.png")
const LOGO_TEX: Texture2D = preload("res://assets/ui/title_logo.png")
const LOGO_SHADER: Shader = preload("res://assets/ui/title_logo.gdshader")
const FOXFIRE := Color(0.376, 0.847, 0.941)   # 파란 여우불 #60d8f0
const EMBER := Color(1.0, 0.72, 0.32)         # 따뜻한 불티
const TEALEAF := Color(0.62, 0.44, 0.28)      # 찻잎 갈색

enum State { MENU, SLOTS, CONFIRM_NEW, CONFIRM_QUIT, INFO }

var _saver: SaveManager
var _state: State = State.MENU
var _sel := 0                     # 현재 상태의 선택 인덱스
var _info_text := ""              # INFO 패널 문구(설정·만든사람들 stub)
var _t := 0.0                     # 파티클 애니 시간
var _particles: Array = []        # {pos, vel, kind, size, ph}
var _hit: Array[Rect2] = []       # 현재 상태 선택 항목 히트 rect(마우스)

const MENU_ITEMS := ["새 게임", "이어하기", "설정", "만든 사람들", "종료"]

var _canvas: Control              # 배경·파티클·메뉴 그리는 자식
var _logo: TextureRect            # 셰이더 로고(위에 얹음)

# ── 내부 캔버스(즉시모드 _draw를 바깥 TitleScreen으로 위임) ──
class _Canvas extends Control:
	var ts: TitleScreen
	func _draw() -> void:
		if ts != null:
			ts._paint(self)

func setup(saver: SaveManager) -> void:
	_saver = saver
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
	_seed_particles()
	_state = State.MENU
	_sel = 0

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
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
				activate()
			KEY_ESCAPE:
				_cancel()
	elif event is InputEventMouseMotion:
		var mp: Vector2 = _canvas.get_local_mouse_position() if _canvas != null else event.position
		for i in _hit.size():
			if _hit[i].has_point(mp):
				if _sel != i:
					_sel = i
					_canvas.queue_redraw()
				break
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var mp2: Vector2 = _canvas.get_local_mouse_position() if _canvas != null else event.position
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
		State.INFO: return 1                              # 확인
	return 1

func move_selection(dir: int) -> void:
	var n := _sel_count()
	_sel = (_sel + dir + n) % n
	if _canvas != null:
		_canvas.queue_redraw()

func _go(s: State) -> void:
	_state = s
	_sel = 0
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
				2:   # 설정(stub — B2)
					_show_info("설정은 다음 업데이트에서 준비 중입니다.\n(그래픽·오디오·언어)")
				3:   # 만든 사람들(stub — B2)
					_show_info("Dear My Naraka\n\n만든 사람들 — 준비 중")
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
		State.INFO:
			_go(State.MENU)

func _show_info(text: String) -> void:
	_info_text = text
	_go(State.INFO)

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
	# 배경(1280×720 → 960×540 균일 스케일).
	ci.draw_texture_rect(BG_TEX, Rect2(Vector2.ZERO, VIEW), false)
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
		State.INFO:
			_paint_info(ci)

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

func _paint_info(ci: CanvasItem) -> void:
	var fw := 480.0
	var fh := 220.0
	var rect := Rect2((VIEW.x - fw) * 0.5, (VIEW.y - fh) * 0.5, fw, fh)
	HanjiUi.draw_frame(ci, rect)
	var lines := _info_text.split("\n")
	var y := rect.position.y + 56.0
	for line in lines:
		var w := HanjiUi.text_width(line, 18)
		HanjiUi.draw_text(ci, Vector2(rect.position.x + (fw - w) * 0.5, y), line, 18, HanjiUi.INK)
		y += 26.0
	var back_sel := _sel == 0
	var bc := HanjiUi.GOLD_SOFT if back_sel else HanjiUi.INK
	var bw := HanjiUi.text_width("확인", 20)
	HanjiUi.draw_text(ci, Vector2(rect.position.x + (fw - bw) * 0.5, rect.end.y - 30.0), "확인", 20, bc)
	_hit.append(Rect2(rect.position.x, rect.end.y - 48.0, fw, 34.0))
