extends RefCounted
class_name ResidentWalk
# ★ [S2-T7 / ADR-0060 결정 7] 주민 **경량 보간 걷기** — 순간이동 스테이션 전환을 "걸어가는" 것처럼
#   보이게 하는 시각 레이어.
#
# 목적: 시각이 바뀌어 주민이 다음 자리로 옮길 때, 예전엔 position이 한 프레임에 순간이동했다.
#       여기서는 **길 스포크**(도로 그래프의 정해진 경유점 — main `_road_spokes`가 만든다)를 따라
#       일정 속도로 보간해, 주민이 길을 따라 걸어간 것처럼 보이게 한다.
#
# ★ 설계의 핵심 = **시각 레이어 한정**(ADR-0060 결정 7 "보간을 시각 레이어에 한정하는 설계도 허용"):
#   - 주민의 **논리 위치**(Resident.tile · node.position)는 전환 순간 목적지로 **즉시 스냅**한다.
#     말 걸기(facing) 판정·농사 제외·헤드리스 테스트가 보는 값이 전부 그 논리 위치라, 걷는 도중에도
#     게임플레이 판정은 "이미 도착"으로 굳는다(기존 npc_station_test의 위치 단언 불변).
#   - 이 클래스는 그 논리 위치 **대비 오프셋**(offset())만 돌려준다. main이 캐릭터 노드의
#     `set_walk_offset()`에 얹으면 *그림만* 뒤에서 따라온다. 걷기가 끝나면 오프셋 0으로 수렴한다.
#   - 그래서 이 컴포넌트가 통째로 죽어도(오프셋 항상 0) 게임은 오늘과 완전히 같이 굴러간다.
#
# ★ A* 등 범용 경로탐색은 도입하지 않는다(ADR-0060 대안 검토 "보류" — 재론 금지). 여기 들어오는
#   경로는 이미 결정된 경유점 목록이고, 이 클래스는 그 위를 등속으로 훑을 뿐이다.
#
# 결정적: 같은 시작점·같은 경로·같은 delta 시퀀스면 항상 같은 위치를 지난다(난수·프레임 의존 없음).

const SPEED_PX := 56.0   # 걷기 속도(px/s). 타일 32px 기준 ≈ 1.75칸/초 — 플레이어보다 느긋한 주민 걸음.

var _path: PackedVector2Array = PackedVector2Array()  # 남은 경유점(마지막 원소 = 목적지)
var _pos := Vector2.ZERO      # 지금 그림이 있는 자리(절대 px)
var _dest := Vector2.ZERO     # 목적지(= 논리 위치. 오프셋은 이 값 기준)
var _walking := false

# 걷기를 시작한다. from_px = 떠나온 자리, path_px = 경유점들(마지막이 목적지).
# 경로가 비었거나 이미 목적지면 아무 일도 없다(= 즉시 도착 · 오프셋 0 · 종전 순간이동과 동일).
func start(from_px: Vector2, path_px: PackedVector2Array) -> void:
	if path_px.is_empty():
		_walking = false
		_path = PackedVector2Array()
		return
	_pos = from_px
	_path = path_px.duplicate()
	_dest = _path[_path.size() - 1]
	_walking = not _pos.is_equal_approx(_dest)
	if not _walking:
		_path = PackedVector2Array()

# 한 프레임분 진행한다. 남은 예산으로 경유점을 순서대로 소비하고, 다 쓰면 걷기가 끝난다.
func advance(delta: float) -> void:
	if not _walking or delta <= 0.0:
		return
	var budget := SPEED_PX * delta
	while budget > 0.0 and not _path.is_empty():
		var next := _path[0]
		var to_next := next - _pos
		var d := to_next.length()
		if d <= budget:
			_pos = next
			_path.remove_at(0)
			budget -= d
		else:
			_pos += to_next / d * budget
			budget = 0.0
	if _path.is_empty():
		_pos = _dest
		_walking = false

# 논리 위치(목적지) 대비 시각 오프셋. 걷는 중이 아니면 0(그림 = 논리 위치).
func offset() -> Vector2:
	return _pos - _dest if _walking else Vector2.ZERO

func is_walking() -> bool:
	return _walking

# 남은 경로 길이(px). 테스트·디버그용.
func remaining_px() -> float:
	if not _walking:
		return 0.0
	var total := 0.0
	var p := _pos
	for q in _path:
		total += p.distance_to(q)
		p = q
	return total

# 경유점 목록의 총 길이(px). from_px에서 출발해 순서대로 밟았을 때의 거리 — 테스트가
# "보간이 경로를 실제로 훑는가"를 재는 기준으로 쓴다.
static func path_length(from_px: Vector2, path_px: PackedVector2Array) -> float:
	var total := 0.0
	var p := from_px
	for q in path_px:
		total += p.distance_to(q)
		p = q
	return total
