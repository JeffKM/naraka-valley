extends Node2D
class_name Mel
# T5.1 — 멜 NPC (카페 그레이박스 자리 + 대사).
#
# 목적: 카페 운영·경제를 쥔 멜을 카페 안에 배치하고, 말 걸면 대사를 들려준다.
#       회색 박스만(ADR-0001). 초상화 일러스트는 Phase 2.
#
# 설계 메모:
#   - miho.gd·okja.gd와 같은 결: 자기 몸(16×32 회색 자리)을 _draw로 그리고, 대사는
#     자기가 든다(ADR-0005: 서사 텍스트는 캐릭터에만). DialogueBox는 누가 말하든
#     모르는 순수 진행기라 — 여기 lines()가 그 출처다(미호·옥자와 같은 박스를 쓴다).
#   - 위치(어느 칸에 서 있나)는 main이 소유한다(TILE 규격도 main 것). main이 카페 안
#     카운터 칸 중앙으로 position을 맞추고, 상호작용 대상 판정도 main의 MEL_TILE로 한다.
#   - 강시(僵尸) 그레이박스: 미호(따뜻한 노랑)·옥자(어두움)와 한눈에 구분되게 청록색
#     기조 + 모티프 암시(이마 부적·강시 모자, CONTEXT '멜'). 회색 기조는 유지.
#   - 톤은 시크·건조(밝은 미호와 대비). 멜은 카페의 '돈줄'을 쥔 운영 담당이라(ADR-0007:
#     출하대 입고 + 손님 응대·서빙·정산) 대사에 그 역할과 돈 모티프를 깐다. 속죄 테마
#     (ADR-0004: 도박·사채로 사람을 망침 → 돈·물자가 건강히 도는 카페를 굴림)는 가볍게
#     암시하되, '봉인된 죄목의 사실 조각'(옥자=기록 각도)은 절대 안 푼다 — 그 깊이는
#     호감도 ♡4+에서 열리는 T5.2의 몫이다(미호 T3.3과 대칭, 메인 플롯 비의존).
#   - T5.2 대사 변화: 호감도(Affinity) 하트 단계가 오를수록 다른 대사 묶음을 들려준다
#     (miho.gd와 같은 틀). 하트 수치·게이팅은 Affinity가 들고, 여기서는 "어떤 줄을
#     들려줄지"만 고른다. 멜 곡선은 미호 T3.3과 대칭이되 각도가 다르다(ADR-0005):
#     ♡2–3 환대 속죄(돈으로 망침 → 환대), ♡4+ '사실 조각' 떡밥(멜=옥자의 기록 각도 —
#     봉인된 죄목의 *존재*만 암시, 죄목 내용은 폭로 X. 플레이어가 스스로 깨달아야
#     속죄가 되므로). 메인 플롯에 의존하지 않는 캐릭터발 서사다(ADR-0005).

const BODY_SIZE := Vector2(16, 32)  # NPC 자리 규격(ADR-0003, 플레이어·미호·옥자와 동일)

# 하트 0~1(인트로): 시크·건조한 강시 운영자 소개 + 역할(출하대·카페 운영) + 가벼운 속죄
# 암시. 넷째 줄이 속죄 한 토막(돈으로 망침 → 반대로 굴림)이되 죄목 '사실 조각'은 봉인.
# PackedStringArray() 생성자는 상수식이 아니라 const로 못 두므로, 상수식인 배열
# 리터럴로 두고 lines()에서 PackedStringArray로 변환해 넘긴다(miho.gd·okja.gd와 동일).
const LINES_INTRO := [
	"[talk]…새로 끌려온 식구로군. 난 멜. 이 카페 돈줄을 쥔 강시야.",
	"[talk]출하대가 내 담당이지. 밭에서 거둔 거, 여기로 가져오면 골드로 쳐준다.",
	"[talk]장사는 단순해. 들어온 재료로 손님 받고, 매출 올리고. 숫자는 거짓말을 안 하거든.",
	"[sad]…살아선 그 숫자로 사람 여럿 등쳐먹었어. 도박이며 사채며. 지금은 반대로 굴리는 중이고.",
	"[talk]필요한 게 있으면 카운터로 와. 친절은 기대 마라. 계산만큼은 정확히 해줄 테니까.",
]

# 하트 2~3(친해지는 중): 환대 속죄 한 토막 — 쥐어짜던 돈을, 돌게 두는 환대로 뒤집는다.
const LINES_WARMING := [
	"[talk]또 왔네. 단골은 손해 안 보게 해주는 게 내 신조야. …앉기나 해.",
	"[talk]장사하면서 알았어. 돈은 뜯어내는 게 아니라, 돌게 두는 거더라고.",
	"[smile]살아선 사람을 쥐어짰지. 여기선 반대야 — 따뜻한 거 한 잔 내주고, 또 오게 만드는 거.",
	"[shy]…환대. 그게 내 속죄법이야. 웃기지, 사채업자였던 내가 이런 소릴 하다니.",
]

# 하트 4+(가까운 사이): '사실 조각' 떡밥 — 멜은 카페 장부를 쥐어 옥자가 봉인한 죄목의
# *존재*를 안다(CONTEXT '메인 스토리' 멜=기록 각도). 내용은 모르고, 폭로하지 않는다.
const LINES_FACT := [
	"[talk]너한텐 말해도 되겠다. 난 이 카페 장부를 통째로 쥐고 있거든.",
	"[talk]네 계약서… 봤어. 다른 셋이랑 딱 한 군데가 달라.",
	"[surprised]'죄목' 칸. 거기만 새까맣게 봉인돼 있더라. 장부 십수 년 만지면서 그런 건 처음 봤어.",
	"[talk]옥자가 직접 봉했더군. 뭘 덮었는진 나도 몰라. 그치만 거기 *뭔가* 있다는 건 확실해.",
	"[talk]언젠간 네가 직접 알게 되겠지. 난 그저, 그 칸이 빈칸이 아니란 걸 일러주는 것뿐이야.",
]

# 오늘 이미 일일 대화를 한 뒤 또 말 걸었을 때(점수 없음 — 대사만 가볍게 바뀐다).
const LINE_AGAIN := "[smile]오늘 장사는 너랑 한 걸로 충분해. 또 보자고."

# 대화창에 띄울 이름.
func display_name() -> String:
	return "멜"

# 말 걸었을 때 들려줄 대사 줄들. hearts = 현재 하트 단계, first_today = 오늘 첫 대화인가
# (miho.gd와 같은 시그니처). 오늘 두 번째 이후면 짧은 인사 한 줄(일일 보상은 Affinity가
# 막음). 첫 대화면 하트 단계 묶음 — ♡4+ 사실 조각 / ♡2–3 환대 속죄 / 그 외 인트로.
func lines(hearts: int = 0, first_today: bool = true) -> PackedStringArray:
	if not first_today:
		return PackedStringArray([LINE_AGAIN])
	if hearts >= 4:
		return PackedStringArray(LINES_FACT)
	if hearts >= 2:
		return PackedStringArray(LINES_WARMING)
	return PackedStringArray(LINES_INTRO)

# P2.3② P2.1 도색 스프라이트(있으면 그레이박스 대신). 상주 NPC라 남쪽(down) 첫 프레임 정지.
var _sprite: AnimatedSprite2D = null

func _ready() -> void:
	_sprite = CharSprite.make("res://assets/characters/mel.png")
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
	# 몸체: 발치 원점 기준 위로 16×32. 청록(강시 의상)으로 미호·옥자와 한눈에 구분.
	var body := Rect2(-BODY_SIZE.x * 0.5, -BODY_SIZE.y, BODY_SIZE.x, BODY_SIZE.y)
	draw_rect(body, Color(0.28, 0.50, 0.50))
	# 얼굴(창백한 강시 톤) 약간 밝게
	var top := -BODY_SIZE.y
	draw_rect(Rect2(body.position + Vector2(0, 4), Vector2(BODY_SIZE.x, 8)), Color(0.62, 0.70, 0.70))
	# 이마 부적 암시: 얼굴 가운데 작은 누런 세로 띠(강시 모티프, CONTEXT '멜')
	draw_rect(Rect2(-1, top + 5, 2, 4), Color(0.86, 0.80, 0.52))
	# 강시 모자 암시: 머리 위 납작한 챙(청 관모) — 옥자의 뾰족 마녀모자와 대비되는 평평한 띠
	draw_rect(Rect2(-7, top - 2, 14, 2), Color(0.16, 0.30, 0.30))
