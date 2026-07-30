extends Node2D
class_name Pulmu
# ★[S5-T3 / ADR-0063 결정 6] 풀무 NPC — 업화 갱도 대장간 점주(T2 · 그레이박스 몸 + 대사).
#
# 목적: ADR-0063 결정 6 "대장간 점주 = 도깨비 「풀무」"의 *캐릭터 파일 몫*이다. 주민 프레임워크
#       (resident.gd)가 요구하는 세 가지(display_name·lines·walk_offset 블록) + 자기 몸 그리기 **만**
#       든다 — 자리·스케줄·도구 업그레이드·지오드 개봉은 한 줄도 여기 없다(전부 main
#       `_setup_residents()` 레코드와 대장간 배선 소관. ongi.gd·boatman.gd 선례 그대로).
#
# ★ 정체성([ADR-0063] 결정 6):
#   · **도깨비** 대장장이. 업화 갱도 남단 대장간에서 **도구 업그레이드**(골드 + 주괴 5 — 결정 3)와
#     **지오드 개봉**(개당 25냥)을 맡는다. S4의 무인 업그레이드대가 이 얼굴로 승격했다.
#   · **결 하나**: 설화의 쇠를 다루는 도깨비 — 방망이 대신 망치를 들고, 남의 것을 빼앗는 대신
#     남의 것을 벼려 준다. ⚠️ 이건 **T2 라이트 플레이버**이지 [속죄] 구조가 아니다 — 생전의 죄를
#     정반대로 쓰는 구조는 메인 4인 독점이다(ADR-0004·ADR-0005). 그래서 대사에 죄·심판·속죄의
#     어휘를 안 싣는다. 불·쇠·망치·물때 이야기만 한다.
#   · ★[owner 큐] **이름·설정은 서랍**이다([CONTEXT] "이름·설정은 owner 큐"). "풀무"는 화덕에
#     바람을 넣는 그 풀무에서 온 호칭이라 표시명도 그대로 "풀무"다 — 본명이 정해지면
#     display_name만 갈아끼우면 된다(레코드 id "pulmu"·세이브 키는 영문이라 개명 영향 0).
#   · ⚠️ **"저승"을 날것으로 부르지 않는다** — 이 세계의 주민에게 여기는 그냥 "여기"다(뱃사공·
#     옹이 톤 정합). "이 아래", "굴", "산" 같은 우회로 결만 쓴다.
#
# 설계 메모:
#   - neo.gd·boatman.gd·ongi.gd(점주 선례)와 같은 결: 점주 레이어(업그레이드·개봉)와 관계 트랙
#     (대화·선물·하트)이 **서로를 게이팅하지 않는다**(ADR-0060 결정 8). ♡0에서도 대장간이 다 열리고,
#     ♡가 올라도 새 티어가 해금되지 않는다.
#   - ★ADR-0008 관계-중립 불변: 풀무 ♡은 **아무 메카닉 보정도 주지 않는다**. 옹이·네오·뱃사공이
#     ♡→매대 할인을 먹는 것과 달리 대장간엔 매대가 없고(가격은 도구 티어 계단 = 경제 곡선), 할인을
#     붙이면 도구 티어 곡선이 관계로 흔들린다. 대사도 "친해지면 싸게 해 준다"를 절대 약속하지 않는다.
#   - 초상화 없음(portrait_stem="") — 스프라이트·초상화는 S5-T9/T10 아트 패스 소관이다.

const BODY_SIZE := Vector2(16, 32)   # NPC 자리 규격(ADR-0003 — 플레이어·미호·멜·옹이와 동일)

# 하트 0(첫 만남): 자기 소개 = 대장장이 + 두 창구(벼리기·알돌). **재료가 골드만이 아니라는 규칙**을
# 첫 대사에서 못 박는다(스타듀 클린트가 그렇듯 "돈은 있는데 왜 안 되냐"는 혼란을 대사가 미리 막는다).
# PackedStringArray() 생성자는 상수식이 아니라 const로 못 두므로, 상수식인 배열 리터럴로 두고
# lines()에서 PackedStringArray로 변환해 넘긴다(ongi.gd·boatman.gd와 동일).
const LINES_INTRO := [
	"[talk]…사람이 내려왔군. 여긴 화덕일세. 나는 풀무라 하네.",
	"[talk]자루를 바꿔 주지. 값과 **주괴 다섯**을 놓고 가게 — 돈만으론 쇠가 안 붙어.",
	"[smile]주괴는 저 위 업화로에 광석 다섯에 혼탄 하날 넣고 기다리면 되네. 내 몫이 아니야.",
	"[talk]알돌은 깨 주지. 스물다섯 냥. 안에 든 게 뭔지는 나도 몰라.",
]

# 하트 1~2(낯 익음): 단골로 알아본다 + **할인이 없음**을 명시(관계-중립 — 메카닉 약속 0).
const LINES_WARMING := [
	"[smile]또 왔나. 자네 발소리는 자갈 밟는 결이 다르군.",
	"[talk]값은 못 깎네. 쇠값은 쇠가 정하지 내가 정하는 게 아니야 — 친하다고 무르지도 않아.",
	"[talk]대신 물때는 봐 주지. 담금질을 서두르면 날이 무르다네.",
]

# 하트 3~4(가까운 사이): 도깨비의 결 한 줄 — 방망이 대신 망치를 든 이야기가 여기서 처음 비친다.
# ★무게를 안 싣는다(속죄 어휘 금지) — 담담한 직업인의 말로 흘린다.
const LINES_CLOSE := [
	"[talk]나도 한때는 방망이를 들었네. 두드리면 뭐든 나온다고 믿었지.",
	"[smile]지금은 남의 것만 두드려. 나오는 건 없고 단단해지기만 하는데, 그게 더 재미있어.",
	"[talk]불은 정직하다네. 덜 달구면 안 붙고 더 달구면 녹아. 흥정이 안 되는 게 편하지.",
]

# 하트 5(맥스): 대장장이가 손님의 연장을 제 것처럼 챌기는 결. 여전히 가볍게, 쇠 이야기로 닫는다.
const LINES_BOND := [
	"[smile]자네 자루는 내가 봐 둔 쇠로 감아 두겠네. 결이 곧은 걸 하나 아껴 뒀어.",
	"[talk]주괴가 모자라면 기다리게. 화덕은 서두른다고 빨라지지 않아 — 밤에도 도니 자고 오면 되네.",
	"[talk]…연장은 쓴 사람 손을 닮는다네. 자네 것은 꽤 얌전해졌어.",
]

# 오늘 이미 일일 대화를 한 뒤 또 말 걸었을 때(점수 없음 — 대사만 가볍게 바뀐다).
const LINE_AGAIN := "[talk]아까 봤잖은가. 벼릴 게 있거든 모루에 놓고, 알돌은 들고 오게."

# 대화창에 띄울 이름. ★호칭 그대로(본명·설정 = 서랍, owner 큐).
func display_name() -> String:
	return "풀무"

# 말 걸었을 때 들려줄 대사 줄들. hearts = 현재 하트 단계, first_today = 오늘 첫 대화인가
# (ongi.gd·boatman.gd·neo.gd와 같은 시그니처 — 프레임워크는 이 한 형태만 안다).
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

# P2.3② 도색 스프라이트(있으면 그레이박스 대신). 풀무 시트는 S5-T9/T10 아트 패스에서 들어온다 —
# 파일이 없으면 CharSprite.make가 null을 돌려주므로 그때까진 아래 그레이박스가 그려진다.
var _sprite: AnimatedSprite2D = null

func _ready() -> void:
	_sprite = CharSprite.make("res://assets/characters/pulmu.png")
	if _sprite != null:
		add_child(_sprite)

# ★ [S2-T7] 보간 걷기 시각 오프셋(ResidentWalk가 채운다 — resident_walk.gd). 논리 위치(position)는
# 스테이션 칸으로 즉시 스냅하고(말 걸기 판정·헤드리스 테스트가 보는 값 불변), *그림만* 이만큼 뒤로
# 민다. 주민 프레임워크 공통 규약이라 새 주민 캐릭터 파일도 이 블록을 그대로 복사한다(ongi.gd 동형).
# ★ 풀무는 상시 한 자리(모루 옆)라 실제로 걷지는 않는다 — 규약만 갖춘다(네오·옹이와 같은 상태).
var walk_offset := Vector2.ZERO

func set_walk_offset(v: Vector2) -> void:
	if walk_offset == v:
		return
	walk_offset = v
	if _sprite != null:
		_sprite.position = v   # 도색 스프라이트는 자식 노드 → 자식 위치로 민다
	queue_redraw()             # 그레이박스는 _draw의 draw_set_transform으로 민다

# 그레이박스 실루엣 = **외뿔 + 어깨에 걸친 망치**. 다른 주민(멜 관모·네오 태엽키·옥자 뾰족모자·
# 모찌 떡·뱃사공 삿갓·옹이 잔가지)과 머리 위 실루엣부터 갈라 둔다(asset-ruleset §실루엣 구분).
# 몸은 달군 쇠 톤(짙은 적갈 + 숯검정)이라 색으로도 구분된다. 진짜 아트는 S5-T9/T10.
const _HORN_H := 8.0      # 이마에서 솟은 외뿔 높이(도깨비 표식 — 하나뿐이라 옹이의 갈래 뿔과 갈린다)
const _HAMMER_R := 3.0    # 어깨 망치 머리 반지름 — 직업을 몸에서 읽히게 한다

func _draw() -> void:
	draw_set_transform(walk_offset)   # ★ [S2-T7] 보간 걷기: 그레이박스 그림 전체를 오프셋만큼 민다
	if _sprite != null:
		return  # 도색 스프라이트가 있으면 그레이박스는 안 그린다(폴백 전용)
	var top := -BODY_SIZE.y
	# 몸통: 발치 원점 기준 위로 16×32. 달군 쇠 빛 도깨비 살(짙은 적갈).
	var body := Rect2(-BODY_SIZE.x * 0.5, top, BODY_SIZE.x, BODY_SIZE.y)
	draw_rect(body, Color(0.44, 0.20, 0.16))
	# NW 광원(asset-ruleset §NW): 왼쪽 결에 밝은 띠 한 줄(화덕 불빛이 왼쪽에서 온다).
	draw_rect(Rect2(body.position.x, top + 9.0, 3.0, BODY_SIZE.y - 9.0), Color(0.62, 0.30, 0.22))
	# 얼굴 면(그을린 낯) + 도트 눈 둘. 불티 튀는 화덕 앞의 붉은 눈.
	draw_rect(Rect2(body.position + Vector2(2.0, 4.0), Vector2(BODY_SIZE.x - 4.0, 7.0)), Color(0.36, 0.16, 0.13))
	draw_rect(Rect2(-4.0, top + 6.0, 2.0, 2.0), Color(0.98, 0.78, 0.34))
	draw_rect(Rect2(2.0, top + 6.0, 2.0, 2.0), Color(0.98, 0.78, 0.34))
	# 이마 외뿔 — 도깨비 표식(머리 실루엣의 주인공). 하나뿐인 게 옹이 갈래 뿔과의 구분점이다.
	draw_line(Vector2(-1.0, top + 3.0), Vector2(-3.0, top + 3.0 - _HORN_H), Color(0.86, 0.80, 0.62), 3.0)
	# 숯검정 가죽 앞치마 — 허리 아래 짙은 판 + 허리끈(대장장이).
	draw_rect(Rect2(body.position.x + 1.0, top + 19.0, BODY_SIZE.x - 2.0, 11.0), Color(0.20, 0.17, 0.16))
	draw_rect(Rect2(body.position.x, top + 17.0, BODY_SIZE.x, 2.0), Color(0.30, 0.25, 0.22))
	# 어깨에 걸친 망치 — 자루(대각선) + 쇠머리(원). 직업을 몸에서 읽히게 한다.
	draw_line(Vector2(5.0, top + 22.0), Vector2(9.5, top + 6.0), Color(0.46, 0.34, 0.21), 2.0)
	draw_circle(Vector2(10.0, top + 5.0), _HAMMER_R, Color(0.28, 0.28, 0.31))
	draw_circle(Vector2(10.0, top + 5.0), _HAMMER_R - 1.5, Color(0.44, 0.44, 0.48))
	# 가슴팍 불티 두 점 — 화덕 앞에 선 몸이라는 표식(순수 장식).
	draw_rect(Rect2(-5.0, top + 14.0, 2.0, 2.0), Color(0.98, 0.60, 0.22))
	draw_rect(Rect2(1.0, top + 16.0, 2.0, 2.0), Color(0.92, 0.44, 0.18))
