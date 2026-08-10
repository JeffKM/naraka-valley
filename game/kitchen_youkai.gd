extends Node2D
class_name KitchenYoukai
# ★[S6-T7 / ADR-0064 결정 8] 주방요괴 NPC — **T3 배경 직원 1인**(그레이박스 몸 + 일상 대사).
#
# 목적: CONTEXT [주방요괴]가 "카페+바 주방에서 기본 음식·음료를 생산하는 백스테이지 NPC"라고
#       정의해 둔 자리를 무대 위에 실제로 세운다. S6-T1부터 기본 메뉴는 *무재료·항시*로
#       나가고 있었는데(주방요괴가 백스테이지에서 댄다는 설정), 정작 그 백스테이지에 아무도
#       없었다 — 이 파일이 그 공백을 메운다.
#
# ★ 정체성 경계(CONTEXT [주방요괴] · ADR-0064 결정 8 — 어길 수 없는 선):
#   · **관계·서사 트랙 0.** 호감도 미터도, 선물 채널도, 하트 단계 대사도 없다(main 레코드의
#     `affinity = null` · `can_gift = false` · `plain_talk = true`가 그 규칙의 코드적 표현).
#     깊이는 메인 4인 독점이고(ADR-0005) 조연 2층 구조의 아래층이 여기다.
#   · **정체는 서랍이다.** "구체 정체는 서랍"(CONTEXT)이라 이 파일은 종족·이름·내력을 한 줄도
#     정하지 않는다 — 호칭도 「주방요괴」 그대로 쓴다(풀무·무골이 호칭을 그대로 쓰는 그 선례).
#     아래 대사도 *주방 일*과 *곁들이 창구*만 말하고 자기 과거는 안 건드린다(봉인 법칙).
#   · 그래서 하는 일도 하나뿐이다: **[F] 곁들이 한 접시**(main._make_side_dish). 매대도 서비스
#     메뉴도 없다 — 점주(T2)가 아니라 직원이다.
#
# 설계 메모:
#   - mochi.gd·pulmu.gd와 같은 결: 자기 몸을 _draw로 그리고 대사는 자기가 든다. 위치·스케줄·
#     [F] 훅은 한 줄도 여기 없다(전부 main `_setup_residents()`의 레코드 소관).
#   - 대사 시그니처가 `lines_resident()`인 건 `plain_talk = true`이기 때문이다(옥자와 같은 경로 —
#     하트·first_today 인자가 없는 일상 묶음. 프레임워크가 이 한 형태만 안다).
#   - **초상화 없음**(portrait_stem="") — 스프라이트·초상화는 S6-T9 아트 패스 소관이다. 그때까지
#     아래 그레이박스가 그려지고, 시트가 도착하면 `CharSprite.make`가 알아서 갈아끼운다.

# 대사 — 하트 단계가 없으므로 **한 묶음**이다(옥자 lines_resident와 같은 결). 주방 일과 곁들이
# 창구만 말한다. 저승 카페의 주방이라는 공기와 "네 몫도 한 접시 있다"는 안내가 전부다.
const LINES := [
	"[talk]…어, 왔어? 손 씻고 들어와. 여긴 김이 많이 나.",
	"[talk]기본 잔은 내가 계속 대고 있으니까 홀만 신경 써. 그게 네 자리야.",
	"[smile]곳간에 뭐 좀 있으면 말해. 네 몫으로 한 접시 부쳐 줄게 — 먹고 하면 좀 돌아.",
]

# 오늘 이미 말을 걸었어도 대사가 안 바뀐다 — 일일 게이팅은 관계 트랙의 장치인데 여기엔 트랙이
# 없다(옥자와 같다. 프레임워크도 plain_talk 주민에겐 first_today를 안 넘긴다).
func display_name() -> String:
	return "주방요괴"

func lines_resident() -> PackedStringArray:
	return PackedStringArray(LINES)

# P2.3② 도색 스프라이트(있으면 그레이박스 대신). 주방요괴 시트는 S6-T9 아트 패스에서 들어온다 —
# 파일이 없으면 CharSprite.make가 null을 돌려주므로 그때까진 아래 그레이박스가 그려진다.
var _sprite: AnimatedSprite2D = null

func _ready() -> void:
	_sprite = CharSprite.make("res://assets/characters/kitchen_youkai.png")
	if _sprite != null:
		add_child(_sprite)

# ★[S2-T7] 보간 걷기 시각 오프셋(ResidentWalk가 채운다). 주민 프레임워크 공통 규약이라 새 캐릭터
# 파일도 이 블록을 그대로 복사한다(mochi.gd 동형). 주방요괴는 자리가 하나뿐이라 실제로는 안 걷는다.
var walk_offset := Vector2.ZERO

func set_walk_offset(v: Vector2) -> void:
	if walk_offset == v:
		return
	walk_offset = v
	if _sprite != null:
		_sprite.position = v
	queue_redraw()

# 그레이박스 몸 — 발치 원점(y=0) 기준 위로 세운다(캐릭터 공통 접지선 규약). 실루엣은 **김에 가린
# 앞치마 덩이**로 잡는다: 카운터 뒤에 반쯤 묻혀 서 있는 배경 직원이라, 손님(CUST 사각)·메인 4인과
# 한눈에 갈리는 게 첫 요건이다. 정체가 서랍이므로 종족을 특정하는 형태(뿔·귀·꼬리)는 안 그린다.
const _BODY := Vector2(16.0, 26.0)          # 몸통 폭×높이(사람형 16×32보다 낮고 뭉툭 — 카운터에 묻힌 결)
const _COL_BODY := Color(0.30, 0.33, 0.38)  # 그을린 회청(주방 그늘)
const _COL_APRON := Color(0.86, 0.84, 0.78) # 오프화이트 앞치마(주방 직원의 유일한 식별 토큰)
const _COL_STEAM := Color(0.88, 0.90, 0.92, 0.45)  # 김 — 반투명이라 뒤 선반이 비쳐 보인다
const _COL_EYE := Color(0.95, 0.86, 0.52)   # 등불빛 눈 한 쌍(저승 결 — 비인간 신호는 여기까지만)

func _draw() -> void:
	draw_set_transform(walk_offset)
	if _sprite != null:
		return  # 도색 스프라이트가 있으면 그레이박스는 안 그린다(폴백 전용)
	var half := _BODY.x * 0.5
	# 몸통 — 발치(y=0)에서 위로.
	draw_rect(Rect2(-half, -_BODY.y, _BODY.x, _BODY.y), _COL_BODY)
	# 앞치마 — 몸통 하단 2/3를 덮는 밝은 사각(NW 광원 규약대로 좌상단에 얇은 하이라이트 한 줄).
	draw_rect(Rect2(-half + 2.0, -_BODY.y * 0.62, _BODY.x - 4.0, _BODY.y * 0.62 - 1.0), _COL_APRON)
	draw_rect(Rect2(-half + 2.0, -_BODY.y * 0.62, 2.0, _BODY.y * 0.62 - 1.0),
		Color(0.96, 0.95, 0.90))
	# 눈 한 쌍 — 그늘 속에서 이것만 보인다.
	draw_rect(Rect2(-5.0, -_BODY.y + 6.0, 3.0, 2.0), _COL_EYE)
	draw_rect(Rect2(2.0, -_BODY.y + 6.0, 3.0, 2.0), _COL_EYE)
	# 머리 위 김 세 덩이 — 위로 갈수록 작아지고 옅어진다(백스테이지 = 늘 뭔가 끓고 있다).
	draw_rect(Rect2(-6.0, -_BODY.y - 5.0, 12.0, 4.0), _COL_STEAM)
	draw_rect(Rect2(-4.0, -_BODY.y - 9.0, 8.0, 3.0), Color(_COL_STEAM.r, _COL_STEAM.g,
		_COL_STEAM.b, 0.30))
	draw_rect(Rect2(-2.0, -_BODY.y - 12.0, 4.0, 2.0), Color(_COL_STEAM.r, _COL_STEAM.g,
		_COL_STEAM.b, 0.18))
