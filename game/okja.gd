extends Node2D
class_name Okja
# T4.1 — 옥자 NPC (오프닝 통보 컷신용 그레이박스 자리 + 대사).
#
# 목적: 온보딩 오프닝에서 옥자가 종신계약을 통보하고 "밭 일부터"라며 떠넘긴다
#       (CONTEXT '옥자': 오프닝에 잠깐 등장). 회색 박스만(ADR-0001). 초상화는 Phase 2.
#
# 설계 메모:
#   - miho.gd와 같은 결: 자기 몸(16×32 회색 자리)을 _draw로 그리고, 대사는 자기가
#     든다(ADR-0005: 서사 텍스트는 캐릭터에만). 다만 미호가 밭에 상주하는 멘토라면
#     옥자는 "오프닝에 잠깐 등장"이라 상시 NPC가 아니다 — main이 통보 단계에만 보이게
#     하고(스폰 앞), 통보가 끝나면 숨긴다(옥자는 사라진다).
#   - 톤은 시크하지만 은근 챙기는 타입(CONTEXT '옥자'): 차갑게 통보하되 끝에 한마디
#     챙긴다. 미호의 밝음과 대비된다. 색도 미호(따뜻한 노랑)와 달리 어둡게(검은 마녀
#     모자·안경) 칠해 한눈에 구분한다.
#   - 옥자는 메인 스토리의 앵커라(CONTEXT '미결의 죄') 대사에 "옥자는 너를 알아보는데
#     너는 못 알아본다"는 떡밥을 한 줄 깐다 — 다만 죄목은 봉인한 채(스스로 깨달아야
#     속죄가 되므로) 절대 밝히지 않는다. 이는 캐릭터(앵커)에 붙는 서사라 ADR-0005를
#     지키며, 새 활동 시스템(농사)은 이 플롯에 의존하지 않고 독립 완성된다.

const BODY_SIZE := Vector2(16, 32)  # NPC 자리 규격(ADR-0003, 플레이어·미호와 동일)

# 오프닝 통보 대사. 종신계약 통보 + 밭 일 떠넘김 + 미호 소개 + 시크한 챙김 한마디.
# 넷째 줄은 '미결의 죄' 떡밥(옥자는 알아보나 플레이어는 못 알아봄) — 죄목은 안 밝힌다.
# 상수식 배열 리터럴로 두고 lines()에서 PackedStringArray로 변환한다(miho.gd와 동일).
const LINES_INTRO := [
	"[talk]…깨어났군. 여기는 나라카, 죽은 자들의 카페다. 난 옥자, 이곳의 주인이지.",
	"[talk]길게 안 한다. 넌 이제 이 카페 소속이야. 계약은 종신 — 나갈 길은 없어.",
	"[talk]죄값은 일로 치른다. 우선 밭부터. 흙 갈고, 씨 뿌리고, 물 주고, 거두면 돼.",
	"[sad]…그 얼굴로 날 멀뚱히 보는군. 넌 날 기억 못 하나 보지. 됐다, 언젠가 알게 돼.",
	"[talk]농사는 미호가 가르칠 거다. 밭에 있으니 가서 말 걸어. …굶지는 마라.",
]

# T5.6 — 통보 후 카페 상주 일상 대사. 옥자는 통보를 마치면 사라지지 않고 카페에 상주한다
# (매일 보는 사장 — CONTEXT '옥자'). 다만 미호·멜과 달리 풀 관계 트랙이 없다(호감도 동료
# 아님, ADR-0005): 점수 보상 없이 매번 같은 묶음을 들려주는 가벼운 일상이되, '미결의 죄'
# 앵커 톤은 유지한다(옥자는 너를 알아본다 — 떡밥만 잇고 죄목은 끝까지 봉인). 통보 대사
# (LINES_INTRO)와 같은 결로 캐릭터가 서사를 든다(미호 LINE_AGAIN처럼 일상은 가볍게).
const LINES_RESIDENT := [
	"[smile]장사는 좀 되나. …그 표정 보니 알 만하군. 천천히 익혀.",
	"[talk]난 늘 여기 있다. 카페가 곧 나니까. 필요한 거 있으면 말 걸어.",
	"[shy]넌 가끔 날 빤히 보더군. 기억날 듯 말 듯 한 얼굴이지? …됐다, 서두를 거 없어.",
]

# 대화창에 띄울 이름.
func display_name() -> String:
	return "옥자"

# 오프닝에서 들려줄 통보 대사 줄들. 미호처럼 캐릭터가 서사를 든다(ADR-0005).
func lines() -> PackedStringArray:
	return PackedStringArray(LINES_INTRO)

# T5.6 통보 후 카페에 상주할 때 말 걸면 들려줄 일상 대사 줄들. 호감도·선물 없는 일상이라
# 하트 인자를 받지 않는다(미호/멜의 lines(hearts,...)와 갈림 — 옥자는 관계 트랙 없음).
func lines_resident() -> PackedStringArray:
	return PackedStringArray(LINES_RESIDENT)

# P2.3② P2.1 도색 스프라이트(있으면 그레이박스 대신). 상주 NPC라 남쪽(down) 첫 프레임 정지.
var _sprite: AnimatedSprite2D = null

func _ready() -> void:
	_sprite = CharSprite.make("res://assets/characters/okja.png")
	if _sprite != null:
		add_child(_sprite)

# M2.4 — 카페 이벤트 데이엔 축제 의상으로 바뀐다(금빛 틴트 + 머리 고깔). main이 day에서
# 파생해 토글한다(miho와 같은 결 — festive 출처는 main, 캐릭터는 자기 몸만 든다).
var festive := false

func set_festive(on: bool) -> void:
	if festive == on:
		return
	festive = on
	modulate = Festival.TINT if on else Color.WHITE   # 도색·그레이박스 공통 금빛 틴트(한 줄)
	queue_redraw()                                    # 머리 고깔 덧그리기 갱신

func _draw() -> void:
	# M2.4 축제 고깔은 도색 스프라이트 위에도 덧그린다(그레이박스 가드보다 먼저).
	if festive:
		Festival.draw_hat(self, -BODY_SIZE.y)
	if _sprite != null:
		return  # 도색 스프라이트가 있으면 그레이박스는 안 그린다(폴백 전용)
	# 몸체: 발치 원점 기준 위로 16×32. 미호보다 어둡게(검은 마녀 차림)로 대비.
	var body := Rect2(-BODY_SIZE.x * 0.5, -BODY_SIZE.y, BODY_SIZE.x, BODY_SIZE.y)
	draw_rect(body, Color(0.22, 0.20, 0.26))
	# 얼굴(안경 낀 창백한 톤) 약간 밝게
	draw_rect(Rect2(body.position + Vector2(0, 4), Vector2(BODY_SIZE.x, 8)), Color(0.55, 0.53, 0.58))
	# 마녀모자 암시: 머리 위 어두운 삼각(가운데로 모이는 두 칸)
	var top := -BODY_SIZE.y
	draw_rect(Rect2(-5, top - 2, 10, 2), Color(0.12, 0.11, 0.14))
	draw_rect(Rect2(-2, top - 5, 4, 3), Color(0.12, 0.11, 0.14))
	# 빨간 리본 암시: 목께 작은 붉은 점(CONTEXT '옥자' 모티프)
	draw_rect(Rect2(-2, top + 12, 4, 2), Color(0.62, 0.18, 0.20))
