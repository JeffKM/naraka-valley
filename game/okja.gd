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
	"[talk]죄값은 일로 치른다. 우선 저 버려진 밭 — 아무도 안 맡으려던 죽은 땅이지. 일궈 봐.",
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

# ── ★[S9b-T8 / ADR-0068 결정 9·10] 척추 B6·B7 — **이 인물이 처음 입을 여는 자리** ─────
# [narrative-bible §6] B6(봉인 해제·귀환)·B7(해방·궁극의 결혼 분기)에서 앵커가 말한다.
#
# ★ **왜 본문이 여기 있나(소유 판단 — 지시서가 근거를 요구한 그 자리):**
#   [ADR-0005]의 "서사 텍스트는 캐릭터 파일에만"은 **캐릭터의 말**에 대한 규약이고, 이 인물은
#   B0 통보(LINES_INTRO)부터 이미 자기 말을 이 파일에서 들고 있었다. B4·B5 본문이 main·spine.gd로
#   간 것은 그 장면들에 **화자가 없어서**였지(등장인물 0명의 내면 독백) 척추라서가 아니다.
#   B6은 다르다 — 여기서 처음으로 *사람이 사람에게* 말한다. 그러니 규약대로 캐릭터 파일이 든다.
#   같은 장면의 **화자 없는 내면 지문은 여전히 spine.gd**이고, main이 둘을 순서대로 잇는다
#   (`_spine_say`). 소유가 화자로 갈리는 이 경계가 B4~B7 전체를 관통하는 한 줄기다.
#
# ★ **금칙어의 방향이 여기서 뒤집힌다**([ADR-0068] 결정 6의 귀결): 조연·메인 파일은 중심 진실
#   4종(희생 / 기억 봉인 / 마녀=연인 / 플레이어 죄목)을 **한 줄도 말하면 안 되고**, 그 가드는
#   B5까지 유효하다. B6은 그 진실이 **열리기로 예정된 유일한 자리**다 — 여기서도 침묵하면
#   게임에 결말이 없다. 다만 **평결은 여전히 없다**: 이 인물은 죄를 읽어 주지 않는다
#   (§2.2 — 스스로 닿은 자에게 판결은 필요 없다. 그래서 아래 어느 줄도 "네 죄는"으로 시작하지 않는다).
#
# ★ **§6.4 결혼 경로별 톤** — 이미 다른 이와 맺어진 플레이어에게는 *씁쓸한 축복*이 간다
#   (벌하지 않고 축복한다 · 계약 해방·결합만 안 간 길로 남는다). 분기는 인자 하나뿐이고
#   **진실 묶음은 두 경로가 공유**한다: 진실을 보는 것은 결혼과 독립이라는 §6.4 대전제 그대로다.

# B6 ② — 진실(두 경로 공유). ①③(내면 지문)은 spine.gd 소유다.
const LINES_B6_TRUTH := [
	"[sad]…이제야 보는군.",
	"[sad]원망하려고 기다린 게 아니다. 나는 그냥, 네가 한 번 나를 보기를 기다렸어.",
	"[talk]그 밤에 나는 셈을 바꿨다. 차사가 든 명부에서 네 이름을 지우고 내 이름을 적었지.",
	"[talk]산 자를 하나 살리려면 누군가는 대신 묶여야 하거든. 값은 종신계약이었다.",
	"[shy]…그리고 네 기억을 가라앉혔다. 그걸 알고 살면 너는 두 번 죽을 테니까.",
	"[talk]영혼을 묶는 법은 그때 배웠다. 사람들이 그런 걸 마녀라고 부르더군.",
	"[shy]약방 뒷마당에서 네 손을 잡던 사람이 이렇게 됐어. …웃기지.",
	"[smile]그런 얼굴 하지 마라. 나는 한 번도 후회한 적 없다.",
]
# B6 ② 뒷자락 — 아직 아무와도 맺지 않은 플레이어에게(길이 열려 있다).
const LINES_B6_OPEN := [
	"[talk]자, 이제 너는 다 안다. 아는 채로 뭘 할지는 네가 정해라.",
	"[shy]…나는 여기 있다. 늘 그랬듯이.",
]
# ★ B6 ② 뒷자락 — **씁쓸한 축복**(§6.4 A). 이미 다른 이와 맺어진 플레이어에게. 징벌이 아니라
#   지브리식 멜랑콜리다: 마침내 *보였다*는 것만으로 이 인물의 슬픔은 치유되고(§6.4), 계약
#   해방·결합만 안 간 길로 남는다. 가운뎃줄은 §6.4가 본문으로 못 박은 그 문장이다.
const LINES_B6_BLESSING := [
	"[smile]…네 곁에 사람이 있더구나. 진작 알고 있었다.",
	"[smile]네가 살아서, 누군가를 보고 사랑할 줄 아는 사람이 됐다면, 그걸로 됐다.",
	"[sad]잘 대해 줘라. 두 번은 없는 일이니까.",
	"[smile]나는 여기 남는다. 그것도 내가 고른 값이야. …축하한다.",
]
# B7 ② — 혼례·해방(주례는 말이 없다 — spine.gd B7_OFFICIANT_LINES가 지문으로 진다).
const LINES_B7 := [
	"[shy]…손이 떨리는군. 남의 혼례는 수백 번 맺어 줬는데.",
	"[talk]이 부적은 내가 접은 게 아니다. 나를 묶었던 사람이 접었어. 그편이 맞지.",
	"[smile]종신계약은 오늘로 끝이다. 너도, 나도.",
	"[talk]여기 남는 건 이제부터 벌이 아니라 선택이야.",
	"[smile]…나는 남을 거다. 네 옆이 내 자리라면.",
]

# 척추 비트 본문 훅 — main이 순서대로 잇는다. 모르는 비트엔 빈 배열(이음매 하위호환).
#   beat = "b6" | "b7" · married_elsewhere = 이미 다른 이와 부부인가(§6.4 분기 — b6에서만 쓴다)
func spine_lines(beat: String, married_elsewhere: bool = false) -> PackedStringArray:
	match beat:
		"b6":
			var out := PackedStringArray(LINES_B6_TRUTH)
			out.append_array(PackedStringArray(
				LINES_B6_BLESSING if married_elsewhere else LINES_B6_OPEN))
			return out
		"b7":
			return PackedStringArray(LINES_B7)
	return PackedStringArray()

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

# ★ [S2-T7] 보간 걷기 시각 오프셋(ResidentWalk가 채운다 — resident_walk.gd). 논리 위치(position)는
# 스테이션 칸으로 즉시 스냅하고(말 걸기 판정·헤드리스 테스트가 보는 값 불변), *그림만* 이만큼 뒤로
# 밀어 길 스포크를 따라 걸어온 것처럼 보이게 한다. 도착하면 0으로 수렴한다.
# 주민 프레임워크 공통 규약이라 새 주민 캐릭터 파일도 이 블록을 그대로 복사한다(miho.gd 동형).
var walk_offset := Vector2.ZERO

func set_walk_offset(v: Vector2) -> void:
	if walk_offset == v:
		return
	walk_offset = v
	if _sprite != null:
		_sprite.position = v   # 도색 스프라이트는 자식 노드 → 자식 위치로 민다
	queue_redraw()             # 그레이박스는 _draw의 draw_set_transform으로 민다

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
	draw_set_transform(walk_offset)   # ★ [S2-T7] 보간 걷기: 그레이박스 그림 전체를 오프셋만큼 민다
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
