extends Control
class_name WeatherFx
# ★[S7-T8 / ADR-0065 결정 10] 날씨 파티클 오버레이 — **절차 드로잉 비·눈**(에셋 0).
#
# 목적: 하늘이 바뀐 것을 HUD 심볼·화면 틴트만이 아니라 *움직임*으로 읽히게 한다. 혼우면 빗줄기가
#       비스듬히 흐르고, 잿눈이면 눈송이가 흩날린다. 그 이상은 하지 않는다 — 이 노드는 시뮬레이션에
#       한 톨도 개입하지 않는 순수 시각층이다(밭을 적시는 것은 Weather·main의 몫).
#
# 설계 메모:
#   - notice_feed·vitals·clock_hud와 같은 결: 코드 생성 자식 Control(무상태). main이 매 프레임
#     set_weather로 "오늘 하늘 + 지금 여기가 실외인가"를 흘려넣고, 이 노드는 표시만 한다.
#   - **결정적일 필요가 없다**(다른 S7 시스템과 갈리는 지점). 날씨 롤·사멸·행사는 day에서 파생되는
#     결정값이라 세이브·헤드리스에서 재현돼야 하지만, 빗방울이 화면 어디를 지나는가는 아무것도
#     결정하지 않는다. 그래도 RNG 인스턴스는 안 쓴다 — 입자 자리를 인덱스에서 파생하면(황금각
#     분산) 상태가 0이라 프레임 간 튐도, 구역 전환 시 재시드도 없다.
#   - **기하는 순수 함수로 뽑는다**(particles). _draw는 그 배열을 그리기만 하고, 오프라인 합성
#     덤프(tools/weather_dump.gd)는 같은 함수를 불러 이미지에 찍는다 — 덤프와 라이브가 같은 한
#     출처에서 나오므로 "덤프에선 예쁜데 게임에선 다르다"가 구조적으로 불가능하다.
#   - **혼불 바람은 파티클이 없다**(결정 10). 지상에서 혼불은 *전조*라 만질 수 있는 낙하물이 아니고
#     (CONTEXT), 실효는 던전 배수에 있다 — 지상 표현은 lighting의 보랏빛 미세 틴트 한 겹뿐이다.
#   - 비용: 수십 개 선분/사각. `_process`는 활성일 때만 queue_redraw를 치고, 비활성이면 즉시 반환한다.

# ── 혼우(비) ─────────────────────────────────────────────────────────────────
# 640×360 논리 화면 기준 밀도. 스타듀급 폭우가 아니라 "비가 온다"가 읽히는 최소치 — 화면을 가리면
# 밭 상태·작물 색이 안 보인다(코지 가독성 > 기상 연출).
const RAIN_COUNT := 46
const RAIN_LEN := 11.0        # 빗줄기 길이(px)
const RAIN_SLANT := 3.0       # 아래로 내려오며 왼쪽으로 밀리는 폭(바람결)
const RAIN_SPEED := 210.0     # 낙하 속도(px/s)
const RAIN_WIDTH := 1.0
const RAIN_COL := Color(0.70, 0.84, 1.00, 0.50)

# ── 잿눈 ─────────────────────────────────────────────────────────────────────
# 눈은 비보다 느리고 성글고, 좌우로 흔들린다(같은 속도로 곧게 떨어뜨리면 비의 흰색 판이 된다).
const SNOW_COUNT := 54        # 비보다 성글되 덤프 육안에서 "흩날린다"가 읽히는 최소치
const SNOW_SPEED := 26.0      # 낙하 속도(px/s)
const SNOW_SWAY := 7.0        # 좌우 흔들림 진폭(px)
const SNOW_SWAY_HZ := 0.7     # 흔들림 주기(Hz)
const SNOW_SIZE := 2.0        # 눈송이 한 변(px — 도트 결로 사각)
const SNOW_COL := Color(0.95, 0.97, 1.00, 0.80)

var _weather := Weather.CALM
var _active := false
var _t := 0.0

func setup() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false

# main이 매 프레임 호출. suppressed = 실내·지하(던전) — 그 무대엔 하늘이 없다.
# ★ 파티클이 있는 날씨는 혼우·잿눈 둘뿐이라, 나머지는 노드가 통째로 잠든다(그리기·redraw 0).
func set_weather(weather: int, suppressed: bool) -> void:
	_weather = weather
	var act := not suppressed and has_particles(weather)
	if act == _active:
		return
	_active = act
	visible = act
	if not act:
		queue_redraw()

# 이 날씨에 낙하물이 있는가(혼우·잿눈만). 혼불 바람은 전조 틴트뿐이라 false.
static func has_particles(weather: int) -> bool:
	return weather == Weather.RAIN or weather == Weather.SNOW

func is_active() -> bool:
	return _active

func _process(delta: float) -> void:
	if not _active:
		return
	_t += delta
	queue_redraw()

func _view() -> Vector2:
	var sc := 1.0
	var par := get_parent()
	if par is CanvasLayer and par.scale.x != 0.0:
		sc = par.scale.x
	return Vector2(size.x / sc, size.y / sc)

# ── 기하(순수 함수 — 라이브 _draw와 오프라인 덤프의 단일 출처) ────────────────
# 반환: 혼우 = [{"kind":"streak","a":Vector2,"b":Vector2,"col":Color,"width":float}, …]
#       잿눈 = [{"kind":"flake","pos":Vector2,"size":float,"col":Color}, …]
# t = 흐른 초(연속). view = 논리 화면 크기.
static func particles(weather: int, t: float, view: Vector2) -> Array:
	var out: Array = []
	if view.x <= 0.0 or view.y <= 0.0:
		return out
	match weather:
		Weather.RAIN:
			for i in RAIN_COUNT:
				# 인덱스 → 자리(황금각 분산). RNG도 상태도 없이 고르게 흩어진다.
				var bx := fposmod(float(i) * 137.508, view.x)
				var by := fposmod(float(i) * 61.803, view.y + RAIN_LEN)
				var y := fposmod(by + t * RAIN_SPEED, view.y + RAIN_LEN) - RAIN_LEN
				var x := fposmod(bx - t * RAIN_SPEED * (RAIN_SLANT / RAIN_LEN), view.x)
				out.append({"kind": "streak", "a": Vector2(x, y),
					"b": Vector2(x - RAIN_SLANT, y + RAIN_LEN),
					"col": RAIN_COL, "width": RAIN_WIDTH})
		Weather.SNOW:
			for i in SNOW_COUNT:
				var sx := fposmod(float(i) * 137.508, view.x)
				var sy := fposmod(float(i) * 61.803, view.y + SNOW_SIZE)
				var fy := fposmod(sy + t * SNOW_SPEED, view.y + SNOW_SIZE) - SNOW_SIZE
				# 송이마다 흔들림 위상이 달라야 "한 덩어리로 출렁"이 안 난다(인덱스에서 파생).
				var ph := float(i) * 0.7
				var fx := fposmod(sx + sin(t * TAU * SNOW_SWAY_HZ + ph) * SNOW_SWAY, view.x)
				out.append({"kind": "flake", "pos": Vector2(fx, fy),
					"size": SNOW_SIZE, "col": SNOW_COL})
	return out

func _draw() -> void:
	if not _active:
		return
	for p in particles(_weather, _t, _view()):
		if p["kind"] == "streak":
			draw_line(p["a"], p["b"], p["col"], p["width"])
		else:
			var pos: Vector2 = p["pos"]
			var s: float = p["size"]
			draw_rect(Rect2(pos, Vector2(s, s)), p["col"])
