extends Node2D
class_name Mochi
# ★ [S2-T8 / ADR-0060 결정 7] 모찌 NPC — **첫 T1 주민**(그레이박스 몸 + 대사).
#
# 목적: 주민 프레임워크(resident.gd)가 약속한 "1인 추가 = ㉠ 캐릭터 파일 1개 + ㉡ main
#       `_setup_residents()` 레코드 1건"을 **실제로 태워 보는 첫 사례**다. 그래서 이 파일은
#       프레임워크가 요구하는 세 가지(display_name·lines·walk_offset 블록)와 자기 몸 그리기
#       **만** 든다 — 위치·스케줄·선물·세이브는 한 줄도 여기 없다(전부 main의 레코드 소관).
#
# ★ 정체성([residents.md] §비인간 요괴 1 · [CONTEXT.md] 모찌):
#   · **카페 과일/푸딩에서 흡수해 태어난 나라카-출생 비인간**(T1, 결혼 가능). 생전 죄 면제 —
#     망자가 아니라 여기서 난 존재라 속죄 서사 대신 **본성 축**을 갖는다.
#   · 본성 축 = **"흡수만 하던 존재 → 내어주는 존재로"**. 아래 대사 4묶음이 하트 단계를 따라
#     정확히 이 축을 걸어간다(삼킨다 → 물어본다 → 떼어 준다 → 다 줘도 안 줄어든다).
#   · 투명 에메랄드빛·말랑·형태 변신·머리 위 찹쌀떡·시럽 먹으면 색 변화(전부 플레이버).
#   · ⚠️ **드래곤퀘스트 슬라임 실루엣 금지**([residents.md] 명시) — 뾰족한 물방울 돔 + 넓은
#     밑동 + 큰 눈·웃는 큰 입 조합을 피한다. 여기 그레이박스는 *납작한 찹쌀떡 덩이*(가로가 더
#     넓고 윗면이 평평한 타원)로 잡아 실루엣부터 갈라 둔다.
#
# 설계 메모:
#   - miho.gd·neo.gd와 같은 결: 자기 몸을 _draw로 그리고 대사는 자기가 든다(ADR-0005 — 서사
#     텍스트는 캐릭터에만). DialogueBox는 누가 말하든 모르는 순수 진행기다.
#   - 위치(어느 칸에 서 있나)는 main이 소유한다 — 모찌의 하루(집 앞 → 마을 광장 → 카페)는
#     main `_setup_residents()`의 스케줄 3줄이고, 이 파일은 그 좌표를 알지도 못한다.
#   - **초상화 없음**(portrait_stem="") — [residents.md] "초상화=도트 눈입 표정"은 S2-T10 아트
#     패스 소관이다. 대사의 [smile]/[talk]/[shy] 태그는 그때 표정으로 붙는다(네오와 같은 상태).
#   - ⚠️ **서사 스포일러 금지**: [그날 밤] 상세는 한 줄도 안 건드린다(그 깊이는 메인 4인 독점,
#     ADR-0005 보존부). "카페에서 났다"는 [residents.md]에 이미 공개된 자기 정체성까지다.

const BODY_SIZE := Vector2(18, 18)   # 슬라임 덩이 — 사람형 16×32와 달리 **납작·가로가 넓다**

# 하트 0(첫 만남): 말랑 애교 + 자기 정체성(카페에서 났다) 소개. 본성 축의 **출발점** — 아직
# "보이면 흡수한다"가 습관이고, 참는 연습 중이라는 한 줄로 축의 방향만 심어 둔다.
# PackedStringArray() 생성자는 상수식이 아니라 const로 못 두므로, 상수식인 배열 리터럴로 두고
# lines()에서 PackedStringArray로 변환해 넘긴다(miho.gd·neo.gd와 동일).
const LINES_INTRO := [
	"[smile]…뽀글. 안녕! 나 모찌야. 방금 네 그림자 살짝 마셨어. 미안, 습관이야.",
	"[talk]난 카페에서 났대. 과일이랑 푸딩이랑, 달콤한 것들이 남긴 자리에서 뽕 하고.",
	"[smile]그래서 단 걸 보면 몸이 먼저 늘어나. 봐, 이만큼 말랑해져.",
	"[talk]앗, 근데 네 건 안 먹을게. 요즘 참는 연습 중이거든.",
]

# 하트 1~2(친해지는 중): 축이 **한 칸** 움직인다 — 삼키기 전에 물어보게 됐다(무단 흡수 → 동의).
const LINES_WARMING := [
	"[smile]또 왔다! 오늘 나 좀 노란빛이지? 아침에 시럽 한 방울 얻어먹었거든.",
	"[talk]예전엔 눈에 보이는 건 다 흡수했어. 그게 사는 방식인 줄 알았어.",
	"[shy]근데 요즘은… 삼키기 전에 한 번 물어보게 돼. '이거 네 거야?' 하고.",
]

# 하트 3~4(가까운 사이): 축이 **뒤집힌다** — 처음으로 자기 조각을 떼어 내어 준다.
const LINES_CLOSE := [
	"[smile]손 내밀어 봐. …자, 여기. 내 안에서 제일 동그란 조각 하나.",
	"[talk]떼어 내면 좀 시원해. 없어지는 게 아니라 네게 옮겨 가는 거니까 괜찮아.",
	"[shy]흡수만 하던 게 내어주는 걸 배우면, 그것도 자라는 거래. 나 자라는 중인가 봐.",
]

# 하트 5(맥스): 축의 **도착점** — 다 내어줘도 줄지 않는다. 붙잡는 사랑(옛 흡수)에서 곁을
# 지키는 사랑으로. ★ 서약·결혼 연출(표면 홍조·발목 감싸기)은 관계 서브시스템 소관이라 여기선
# 대사로만 여운을 남긴다(ADR-0032 — 이 슬라이스는 대화·선물 채널까지).
const LINES_BOND := [
	"[smile]오늘도 왔구나. 나 요즘 네 발소리를 제일 먼저 알아들어.",
	"[talk]예전의 나였으면 널 통째로 안아서 안 놔줬을 거야. 지금은… 그냥 옆에 있을게.",
	"[shy]대신 하나만. 힘든 날엔 여기 기대. 말랑한 건 그럴 때 쓰라고 있는 거야.",
	"[smile]…뽀글. 다 내어줘도 나는 안 줄어들더라. 신기하지?",
]

# 오늘 이미 일일 대화를 한 뒤 또 말 걸었을 때(점수 없음 — 대사만 가볍게 바뀐다).
const LINE_AGAIN := "[smile]뽀글… 아까 봤잖아~ 그래도 한 번 더 말랑해질래?"

# 대화창에 띄울 이름.
func display_name() -> String:
	return "모찌"

# 말 걸었을 때 들려줄 대사 줄들. hearts = 현재 하트 단계, first_today = 오늘 첫 대화인가
# (miho.gd·neo.gd와 같은 시그니처 — 프레임워크가 이 한 형태만 안다).
# 오늘 두 번째 이후면 짧은 인사 한 줄(일일 보상은 이미 받음 → Affinity가 막는다).
# 첫 대화면 하트 단계 묶음 — ♡5 맥스 / ♡3~4 가까움 / ♡1~2 친해지는 중 / ♡0 첫 만남.
# 네 묶음이 "흡수만 하던 존재 → 내어주는 존재로" 축의 네 지점이다(위 각 묶음 주석).
func lines(hearts: int = 0, first_today: bool = true) -> PackedStringArray:
	if not first_today:
		return PackedStringArray([LINE_AGAIN])
	if hearts >= 5:
		return PackedStringArray(LINES_BOND)
	if hearts >= 3:
		return PackedStringArray(LINES_CLOSE)
	if hearts >= 1:
		return PackedStringArray(LINES_WARMING)
	return PackedStringArray(LINES_INTRO)

# P2.3② 도색 스프라이트(있으면 그레이박스 대신). 모찌 시트는 S2-T10 아트 패스에서 들어온다 —
# 파일이 없으면 CharSprite.make가 null을 돌려주므로 그때까진 아래 그레이박스가 그려진다.
var _sprite: AnimatedSprite2D = null

func _ready() -> void:
	_sprite = CharSprite.make("res://assets/characters/mochi.png")
	if _sprite != null:
		add_child(_sprite)

# ★ [S2-T7] 보간 걷기 시각 오프셋(ResidentWalk가 채운다 — resident_walk.gd). 논리 위치(position)는
# 스테이션 칸으로 즉시 스냅하고(말 걸기 판정·헤드리스 테스트가 보는 값 불변), *그림만* 이만큼 뒤로
# 밀어 길 스포크를 따라 걸어온 것처럼 보이게 한다. 도착하면 0으로 수렴한다.
# 주민 프레임워크 공통 규약이라 새 주민 캐릭터 파일도 이 블록을 그대로 복사한다(miho.gd·neo.gd 동형).
# ★ [S2-T8] 모찌가 이 규약의 **첫 실사용자**다 — 집 앞 → 마을 광장 전환이 같은 구역(나루 마을)이라
#   프레임워크의 보간 걷기가 실제로 도는 첫 동선이다(기존 5인은 전부 걷지 않는 배치였다).
var walk_offset := Vector2.ZERO

func set_walk_offset(v: Vector2) -> void:
	if walk_offset == v:
		return
	walk_offset = v
	if _sprite != null:
		_sprite.position = v   # 도색 스프라이트는 자식 노드 → 자식 위치로 민다
	queue_redraw()             # 그레이박스는 _draw의 draw_set_transform으로 민다

# 덩이 실루엣 — 발치 원점 기준 위로 부푼 **납작한 타원**(가로 반지름 > 세로 반지름). 밑면은
# y=0에서 잘라 바닥에 퍼져 앉은 모양을 만든다(발치 원점 규약: 다른 캐릭터와 같은 접지선).
# ⚠️ DQ 슬라임 구분: 윗면을 뾰족하게 올리지 않고 _TOP_FLAT만큼 눌러 평평하게 둔다.
const _R := Vector2(9.0, 8.0)    # 타원 반지름(가로 9 > 세로 8 = 납작)
const _TOP_FLAT := 2.0           # 윗면을 이만큼 눌러 물방울 돔이 아닌 찹쌀떡 결로
const _BLOB_STEPS := 20          # 외곽 폴리곤 분할수(그레이박스 — 매끈함보다 값 싸게)

# 눌린 타원 한 덩이. center 기준으로 점을 만들어 바로 그린다(변환 중첩 없이 — 보간 오프셋은
# _draw 첫 줄의 draw_set_transform 하나가 이미 걸고 있다).
func _blob(center: Vector2, rx: float, ry: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in _BLOB_STEPS:
		var a := TAU * float(i) / float(_BLOB_STEPS)
		var y := sin(a) * ry              # Godot는 y가 아래로 자라므로 음수 y = 윗면
		if y < 0.0:
			y = minf(y + _TOP_FLAT * (ry / _R.y), 0.0)   # 윗면만 눌러 평평하게(돔 금지)
		pts.append(center + Vector2(cos(a) * rx, y))
	draw_colored_polygon(pts, col)

func _draw() -> void:
	draw_set_transform(walk_offset)   # ★ [S2-T7] 보간 걷기: 그레이박스 그림 전체를 오프셋만큼 민다
	if _sprite != null:
		return  # 도색 스프라이트가 있으면 그레이박스는 안 그린다(폴백 전용)
	# 몸통: 투명 에메랄드([residents.md] "투명 에메랄드빛"). 알파를 남겨 뒤 타일이 비쳐 보인다 —
	# 이 반투명이 모찌를 다른 그레이박스(불투명 사각 몸)와 한눈에 가르는 첫 신호다.
	# 중심을 (0, -_R.y)에 두면 밑면이 정확히 발치 원점 선(y=0)에 앉는다(접지선 규약 공유).
	_blob(Vector2(0.0, -_R.y), _R.x, _R.y, Color(0.36, 0.84, 0.62, 0.66))
	# NW 광원 규약(asset-ruleset §NW): 좌상단에 밝은 하이라이트 한 덩이.
	_blob(Vector2(-3.0, -_R.y - 2.0), _R.x * 0.42, _R.y * 0.40, Color(0.78, 0.98, 0.86, 0.55))
	# 도트 눈입([residents.md] "초상화=도트 눈입 표정"의 인게임 축소판). 눈 둘 + 짧은 입 한 줄.
	var eye_y := -_R.y - 1.0
	draw_rect(Rect2(-4.0, eye_y, 2.0, 2.0), Color(0.10, 0.24, 0.18))
	draw_rect(Rect2(2.0, eye_y, 2.0, 2.0), Color(0.10, 0.24, 0.18))
	draw_rect(Rect2(-1.5, eye_y + 4.0, 3.0, 1.0), Color(0.10, 0.24, 0.18))
	# 머리 위 찹쌀떡([residents.md] "어깨/머리 위 찹쌀떡") — 오프화이트 작은 덩이. 뾰족한 돔 대신
	# 이 얹힌 떡이 실루엣의 꼭대기라, DQ 슬라임과 위쪽 윤곽부터 갈린다.
	var cap_y := -_R.y * 2.0 + _TOP_FLAT
	draw_rect(Rect2(-3.0, cap_y - 3.0, 6.0, 3.0), Color(0.96, 0.95, 0.90))
	draw_rect(Rect2(-2.0, cap_y - 4.0, 4.0, 1.0), Color(0.96, 0.95, 0.90))
