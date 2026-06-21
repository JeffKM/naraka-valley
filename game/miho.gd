extends Node2D
class_name Miho
# T3.2 — 미호 NPC (그레이박스 자리 + 대사).
#
# 목적: 농사 멘토 미호를 밭에 배치하고, 말 걸면 대사를 들려준다.
#       회색 박스만(ADR-0001). 초상화 일러스트는 Phase 2.
#
# 설계 메모:
#   - player.gd처럼 자기 몸(16×32 회색 자리)을 _draw로 그린다(발치 원점 규약 동일).
#     플레이어(0.70 무채색)와 구분되게 살짝 따뜻한 회색 — 노란 한복·여우불을 암시하되
#     회색 기조는 유지(그레이박스). 머리 위 작은 뿔 두 개로 여우귀를 넌지시 표현한다.
#   - 대사는 캐릭터가 든다(ADR-0005: 서사 텍스트는 캐릭터에만). DialogueBox는 순수
#     진행기라 내용을 모른다 — 여기 lines()가 그 출처다.
#   - 속죄 테마(ADR-0004: 미호 방화→양육)와 밝은 성격(CONTEXT '미호': 해맑은 농사
#     멘토)을 대사에 담되, 메인 플롯에 의존하지 않는 독립 온보딩성 안내로 닫는다.
#   - 위치(어느 칸에 서 있나)는 main이 소유한다(TILE 규격도 main 것). main이 타일
#     중앙으로 position을 맞추고, 상호작용 대상 판정도 main의 MIHO_TILE로 한다.
#   - T3.3 대사 변화: 호감도(Affinity) 하트 단계가 오를수록 다른 대사 묶음을 들려준다
#     (CONTEXT '호감도': 일일 대화로 대사 변화 + 하트 단계마다 속죄 서사 한 토막 해금).
#     하트 수치·게이팅은 Affinity가 들고, 여기서는 "어떤 줄을 들려줄지"만 고른다
#     (ADR-0005: 서사 텍스트는 캐릭터에만). main이 하트 수와 '오늘 첫 대화인가'를 넘긴다.

const BODY_SIZE := Vector2(16, 32)  # NPC 자리 규격(ADR-0003, 플레이어와 동일)

# 하트 0(온보딩): 밝고 해맑은 농사 멘토 + "파괴의 불 → 양육의 불" 속죄 소개.
# PackedStringArray() 생성자는 상수식이 아니라 const로 못 두므로, 상수식인 배열
# 리터럴로 두고 lines()에서 PackedStringArray로 변환해 넘긴다.
const LINES_INTRO := [
	"[smile]어, 새 식구다! 반가워~ 난 미호, 이 밭 담당이야.",
	"[talk]여기선 [E]로 흙 갈고, 씨앗 심고, 물 주면 돼. 쉽지?",
	"[smile]내 여우불… 옛날엔 막 태워먹었는데, 여기선 작물 키우는 데 쓴단다. 신기하지!",
	"[talk]다 자란 건 카페 출하대에 팔아 골드를 벌고, 그 돈으로 또 씨앗을 사면 돼.",
	"[smile]모르는 거 있음 언제든 불러. 난 늘 여기 있을게~",
]

# 하트 1~2(친해지는 중): 속죄 서사 한 토막 해금 — 방화의 과거를 살짝 연다.
const LINES_WARMING := [
	"[smile]또 왔구나! 네가 오면 이 밭이 좀 더 환해지는 것 같아.",
	"[sad]있잖아… 난 살아서 불을 너무 사랑했어. 태우는 불 말이야.",
	"[shy]여기선 그 불로 싹을 틔워. 망치던 힘을, 살리는 데 쓰는 거지. 이상하지?",
]

# 하트 3+(가까운 사이): 더 깊은 속죄 토막 + 여우불 강화(T3.4) 떡밥.
const LINES_CLOSE := [
	"[shy]너랑 이렇게 얘기하는 시간이 좋아. 진짜로.",
	"[smile]내 여우불, 이젠 제법 말을 들어. 네 밭이라면 더 잘 자라게 해줄 수 있을 것 같아.",
	"[smile]속죄가 별건가… 어제보다 한 포기 더 살리면 되는 거지. 네 덕분에 그걸 배워.",
]

# 오늘 이미 일일 대화를 한 뒤 또 말 걸었을 때(점수 없음 — 대사만 가볍게 바뀐다).
const LINE_AGAIN := "[smile]오늘은 아까 봤잖아~ 그래도 얼굴 보니 좋네."

# 대화창에 띄울 이름.
func display_name() -> String:
	return "미호"

# 말 걸었을 때 들려줄 대사 줄들. hearts = 현재 하트 단계, first_today = 오늘 첫 대화인가.
#   - 오늘 두 번째 이후면 짧은 인사 한 줄(일일 보상은 이미 받음 → Affinity가 막음).
#   - 첫 대화면 하트 단계에 맞는 묶음을 들려준다(높을수록 속죄 서사가 더 열린다).
func lines(hearts: int = 0, first_today: bool = true) -> PackedStringArray:
	if not first_today:
		return PackedStringArray([LINE_AGAIN])
	if hearts >= 3:
		return PackedStringArray(LINES_CLOSE)
	if hearts >= 1:
		return PackedStringArray(LINES_WARMING)
	return PackedStringArray(LINES_INTRO)

# P2.3② P2.1 도색 스프라이트(있으면 그레이박스 대신). 상주 NPC라 남쪽(down) 첫 프레임 정지.
var _sprite: AnimatedSprite2D = null

func _ready() -> void:
	_sprite = CharSprite.make("res://assets/characters/miho_walk.png")
	if _sprite != null:
		add_child(_sprite)

func _draw() -> void:
	if _sprite != null:
		return  # 도색 스프라이트가 있으면 그레이박스는 안 그린다(폴백 전용)
	# 몸체: 발치 원점 기준 위로 16×32. 플레이어보다 따뜻한 톤으로 한눈에 구분.
	var body := Rect2(-BODY_SIZE.x * 0.5, -BODY_SIZE.y, BODY_SIZE.x, BODY_SIZE.y)
	draw_rect(body, Color(0.80, 0.72, 0.52))
	# 머리 약간 밝게(그레이박스 시인성)
	draw_rect(Rect2(body.position, Vector2(BODY_SIZE.x, 10)), Color(0.90, 0.82, 0.60))
	# 여우귀 암시: 머리 위 양옆 작은 뿔 두 개
	var top := -BODY_SIZE.y
	draw_rect(Rect2(-6, top - 3, 3, 3), Color(0.90, 0.82, 0.60))
	draw_rect(Rect2(3, top - 3, 3, 3), Color(0.90, 0.82, 0.60))
