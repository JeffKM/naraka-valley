extends Node2D
class_name Ongi
# ★[S4-T7 / ADR-0062 결정 7 ㉢] 옹이 NPC — 저승 숲 어귀 목공방 점주(T2 · 그레이박스 몸 + 대사).
#
# 목적: ADR-0062 결정 7 "옹이 = Resident T2 등록 + 목공방 실체화"의 *캐릭터 파일 몫*이다.
#       주민 프레임워크(resident.gd)가 요구하는 세 가지(display_name·lines·walk_offset 블록) +
#       자기 몸 그리기 **만** 든다 — 자리·스케줄·매대·건축 의뢰·가구 판매는 한 줄도 여기 없다
#       (전부 main `_setup_residents()` 레코드와 매대 배선 소관. boatman.gd 선례 그대로).
#
# ★ 정체성([CONTEXT.md] '옹이' · [ADR-0062] 결정 7):
#   · **목령**(木靈 — 나무 요괴) 목수. 저승 숲 어귀 목공방에서 **건축 의뢰**(골드+원목 선불 →
#     며칠 뒤 완공, 스타듀 로빈 1:1)와 **가구·원목 매대**를 연다. ♡ → 매대 할인이 유일한 퍼크다.
#   · **결 하나**(ADR-0062 결정 7): 제가 **벌목당한 고목의 정령**이라 "베인 나무를 살림집으로
#     되살리는" 일로 제 그루터기를 위로한다. ⚠️ 이건 **T2 라이트 플레이버**이지 [속죄] 구조가
#     아니다 — 생전의 죄를 정반대로 쓰는 구조는 메인 4인 독점이다(ADR-0004·ADR-0005). 그래서
#     대사에 죄·심판·속죄의 어휘를 안 싣는다. 나무·나이테·톱밥 이야기만 한다.
#   · ★[owner 큐] **이름·설정은 서랍**이다([CONTEXT] "이름·설정은 owner 큐"). "옹이"는 나뭇결의
#     매듭(knot)에서 온 호칭이라 표시명도 그대로 "옹이"다 — 본명이 정해지면 display_name만
#     갈아끼우면 된다(레코드 id "ongi"·세이브 키는 영문이라 개명 영향 0).
#   · ⚠️ **"저승"을 날것으로 부르지 않는다** — 이 세계의 주민에게 여기는 그냥 "여기"다(뱃사공
#     톤 정합). "숲", "이 근처", "물 건너" 같은 우회로 결만 쓴다.
#
# 설계 메모:
#   - neo.gd·boatman.gd(점주 선례)와 같은 결: 점주 레이어(매대·♡ 할인)와 관계 트랙(대화·선물·
#     하트)이 **서로를 게이팅하지 않는다**(ADR-0060 결정 8). ♡0에서도 매대·건축이 다 열리고,
#     ♡가 올라도 새 프로젝트가 해금되지 않는다(할인만 깊어진다).
#   - ★ADR-0008 관계-중립 불변: 옹이 ♡은 **가게 정책(할인)뿐**이다. 대사도 "친해지면 더 빨리
#     지어 준다" 류의 *메카닉 약속*을 절대 하지 않는다 — 공기(工期)·원목 요구량에 보정 0.
#   - 초상화 없음(portrait_stem="") — 스프라이트·초상화는 S4-T9/T10 아트 패스 소관이다.

const BODY_SIZE := Vector2(16, 32)   # NPC 자리 규격(ADR-0003 — 플레이어·미호·멜·네오·뱃사공과 동일)

# 하트 0(첫 만남): 자기 소개 = 목수 + 두 창구(건축·매대). **선불·대기**라는 규칙을 첫 대사에서
# 명확히 한다(스타듀 로빈이 그렇듯, "돈을 냈는데 왜 안 서 있냐"는 혼란을 대사가 미리 막는다).
# PackedStringArray() 생성자는 상수식이 아니라 const로 못 두므로, 상수식인 배열 리터럴로 두고
# lines()에서 PackedStringArray로 변환해 넘긴다(boatman.gd·neo.gd와 동일).
const LINES_INTRO := [
	"[talk]…손님이군. 여긴 목공방일세. 나는 옹이라 부르면 되네.",
	"[talk]넓힐 데가 있으면 말하게. 값과 원목을 먼저 받고, 며칠 뒤 아침에 서 있을 걸세 — 하루에 한 채뿐이야.",
	"[smile]나무가 없으면 저기 쌓아 둔 걸 사 가도 되고. 가구 짜 둔 것도 몇 벌 있네.",
	"[talk]나무는 서두른다고 마르지 않아. 기다리게.",
]

# 하트 1~2(낯 익음): 단골로 알아본다 + 할인이 *가게 정책*임을 명시(관계-중립 — 메카닉 약속 없음).
const LINES_WARMING := [
	"[smile]또 왔나. 자네 걸음은 마룻널 울리는 소리로 알겠어.",
	"[talk]자주 오는 손님껜 값을 깎아 주네. 그뿐일세 — 친하다고 대패가 빨라지진 않아. 날이 하는 일이지.",
	"[talk]원목이 모자라면 먼저 베어 오게. 도끼 날이 무디면 나무만 상하네.",
]

# 하트 3~4(가까운 사이): 목령의 결 한 줄 — **벌목당한 고목의 정령**이라는 플레이버가 여기서
# 처음 비친다. ★무게를 안 싣는다(속죄 어휘 금지) — 담담한 직업인의 말로 흘린다.
const LINES_CLOSE := [
	"[talk]나도 한때는 서 있었네. 저 북쪽 어디쯤에, 꽤 굵게.",
	"[smile]베인 게 억울하진 않아. 다만 그루터기로 남는 건 심심해서 — 이렇게 남의 집을 짜고 있지.",
	"[talk]나이테는 못 속이네. 급하게 자란 해는 성기고, 견딘 해는 촘촘해. 집도 그렇고.",
]

# 하트 5(맥스): 목수가 손님에게 제 몫의 나무를 내주는 결. 여전히 가볍게, 나무 이야기로 닫는다.
const LINES_BOND := [
	"[smile]자네 집 대들보는 내 결 좋은 놈으로 골라 두겠네. 아껴 둔 게 하나 있어.",
	"[talk]값은 깎을 만큼 깎았어. 더 깎으면 대패를 팔아야 하네.",
	"[talk]…언젠가 이 숲도 자네가 심은 나무로 채워지겠지. 그때 한 그루쯤은 안 베고 둬 주게.",
]

# 오늘 이미 일일 대화를 한 뒤 또 말 걸었을 때(점수 없음 — 대사만 가볍게 바뀐다).
const LINE_AGAIN := "[talk]아까 봤잖은가. 지을 게 있거든 매대를 부르게."

# 대화창에 띄울 이름. ★호칭 그대로(본명·설정 = 서랍, owner 큐).
func display_name() -> String:
	return "옹이"

# 말 걸었을 때 들려줄 대사 줄들. hearts = 현재 하트 단계, first_today = 오늘 첫 대화인가
# (boatman.gd·neo.gd와 같은 시그니처 — 프레임워크는 이 한 형태만 안다).
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

# P2.3② 도색 스프라이트(있으면 그레이박스 대신). 옹이 시트는 S4-T9/T10 아트 패스에서 들어온다 —
# 파일이 없으면 CharSprite.make가 null을 돌려주므로 그때까진 아래 그레이박스가 그려진다.
var _sprite: AnimatedSprite2D = null

func _ready() -> void:
	_sprite = CharSprite.make("res://assets/characters/ongi.png")
	if _sprite != null:
		add_child(_sprite)

# ★ [S2-T7] 보간 걷기 시각 오프셋(ResidentWalk가 채운다 — resident_walk.gd). 논리 위치(position)는
# 스테이션 칸으로 즉시 스냅하고(말 걸기 판정·헤드리스 테스트가 보는 값 불변), *그림만* 이만큼 뒤로
# 민다. 주민 프레임워크 공통 규약이라 새 주민 캐릭터 파일도 이 블록을 그대로 복사한다(boatman.gd 동형).
# ★ 옹이는 상시 한 자리(목공방 카운터 뒤)라 실제로 걷지는 않는다 — 규약만 갖춘다(네오와 같은 상태).
var walk_offset := Vector2.ZERO

func set_walk_offset(v: Vector2) -> void:
	if walk_offset == v:
		return
	walk_offset = v
	if _sprite != null:
		_sprite.position = v   # 도색 스프라이트는 자식 노드 → 자식 위치로 민다
	queue_redraw()             # 그레이박스는 _draw의 draw_set_transform으로 민다

# 그레이박스 실루엣 = **어깨 위 잔가지 뿔 + 옹이(매듭) 무늬**. 다른 주민(멜 관모·네오 태엽키·
# 옥자 뾰족모자·모찌 떡·뱃사공 삿갓)과 머리 위 실루엣부터 갈라 둔다(asset-ruleset §실루엣 구분).
# 몸은 젖은 나무껍질 톤(짙은 갈색+이끼 초록)이라 색으로도 구분된다. 진짜 아트는 S4-T9/T10.
const _BRANCH_H := 9.0    # 머리에서 솟은 잔가지 높이(목령 표식 — 뿔처럼 갈라진다)
const _KNOT_R := 3.0      # 가슴팍 옹이(매듭) 반지름 — 이름의 유래를 몸에 박아 둔다

func _draw() -> void:
	draw_set_transform(walk_offset)   # ★ [S2-T7] 보간 걷기: 그레이박스 그림 전체를 오프셋만큼 민다
	if _sprite != null:
		return  # 도색 스프라이트가 있으면 그레이박스는 안 그린다(폴백 전용)
	var top := -BODY_SIZE.y
	# 몸통: 발치 원점 기준 위로 16×32. 젖은 나무껍질(짙은 갈색).
	var body := Rect2(-BODY_SIZE.x * 0.5, top, BODY_SIZE.x, BODY_SIZE.y)
	draw_rect(body, Color(0.32, 0.23, 0.15))
	# NW 광원(asset-ruleset §NW): 왼쪽 결에 밝은 띠 한 줄.
	draw_rect(Rect2(body.position.x, top + 9.0, 3.0, BODY_SIZE.y - 9.0), Color(0.44, 0.33, 0.21))
	# 세로 나뭇결 두 줄(껍질 결 — 납작한 색면을 깬다).
	draw_rect(Rect2(-2.0, top + 12.0, 1.0, BODY_SIZE.y - 14.0), Color(0.24, 0.17, 0.11))
	draw_rect(Rect2(3.0, top + 14.0, 1.0, BODY_SIZE.y - 16.0), Color(0.24, 0.17, 0.11))
	# 얼굴 면(껍질 갈라진 틈) + 도트 눈 둘. 나무 옹이 구멍에서 내다보는 결.
	draw_rect(Rect2(body.position + Vector2(2.0, 4.0), Vector2(BODY_SIZE.x - 4.0, 7.0)), Color(0.26, 0.19, 0.13))
	draw_rect(Rect2(-4.0, top + 6.0, 2.0, 2.0), Color(0.86, 0.80, 0.52))
	draw_rect(Rect2(2.0, top + 6.0, 2.0, 2.0), Color(0.86, 0.80, 0.52))
	# 가슴팍 옹이(매듭) — 이름표. 밝은 테두리 원 + 짙은 심(나이테 단면).
	draw_circle(Vector2(0.0, top + 18.0), _KNOT_R, Color(0.50, 0.37, 0.23))
	draw_circle(Vector2(0.0, top + 18.0), _KNOT_R - 1.5, Color(0.22, 0.15, 0.10))
	# 머리 위 잔가지 뿔 — 갈라진 두 가지 + 끝의 이끼 잎(목령 표식·머리 실루엣의 주인공).
	var head_y := top + 2.0
	draw_line(Vector2(-3.0, head_y), Vector2(-6.0, head_y - _BRANCH_H), Color(0.38, 0.28, 0.18), 2.0)
	draw_line(Vector2(3.0, head_y), Vector2(6.5, head_y - _BRANCH_H + 2.0), Color(0.38, 0.28, 0.18), 2.0)
	draw_rect(Rect2(-8.0, head_y - _BRANCH_H - 2.0, 4.0, 3.0), Color(0.38, 0.55, 0.32))   # 이끼 잎(좌)
	draw_rect(Rect2(5.0, head_y - _BRANCH_H + 0.0, 4.0, 3.0), Color(0.34, 0.50, 0.29))    # 이끼 잎(우)
	# 앞치마(목수) — 허리 아래 밝은 천 + 허리끈. 직업을 몸에서 읽히게 한다.
	draw_rect(Rect2(body.position.x + 1.0, top + 21.0, BODY_SIZE.x - 2.0, 9.0), Color(0.58, 0.50, 0.36))
	draw_rect(Rect2(body.position.x, top + 19.0, BODY_SIZE.x, 2.0), Color(0.40, 0.30, 0.19))
