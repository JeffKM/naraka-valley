extends Node2D
class_name Boatman
# ★ [S3-T5 / ADR-0061 결정 5] 뱃사공 NPC — 황천해 생선가게 점주(T2 · 그레이박스 몸 + 대사).
#
# 목적: ADR-0061 결정 5 "뱃사공 = Resident T2 등록 + 생선가게 실체화"의 *캐릭터 파일 몫*이다.
#       주민 프레임워크(resident.gd)가 요구하는 세 가지(display_name·lines·walk_offset 블록) +
#       자기 몸 그리기 **만** 든다 — 자리·스케줄·매대·환전·증정은 한 줄도 여기 없다(전부 main
#       `_setup_residents()` 레코드와 매대 배선 소관. mochi.gd 선례 그대로).
#
# ★ 정체성([CONTEXT.md] '뱃사공' · [stardew-systems-catalog.md] §1-D):
#   · **저승 물길의 사공**(카론 결). 삼도천을 건네고 황천해 부두에서 생선가게를 연다 —
#     낚시 기어 판매 + 물고기 환전의 **단일 창구**(스타듀 윌리 1:1).
#   · **속죄-중립**(ADR-0004 속죄 테마의 *바깥*): 그는 죄를 씻으러 온 망자가 아니라 물길에
#     원래부터 있던 자다. 그래서 대사에 죄·속죄·심판의 무게를 싣지 않는다 — 물때·물살·고기
#     이야기만 한다(무게는 메인 4인 독점, ADR-0005).
#   · ★[owner 큐] **본명·종은 서랍**이다([CONTEXT] "이름·종은 서랍"). "뱃사공"은 이름이 아니라
#     **호칭**이라 표시명도 그대로 "뱃사공"이다. 본명이 정해지면 display_name만 갈아끼우면 된다
#     (레코드 id "boatman"·세이브 키는 영문이라 개명 영향 0).
#   · ⚠️ **"저승"을 날것으로 부르지 않는다** — 이 세계의 주민에게 여기는 그냥 "여기"다. "물길",
#     "건너편", "돌아가지 않는 손님" 같은 우회로 결만 남긴다(기존 대사 톤 정합).
#
# 설계 메모:
#   - neo.gd(점주 선례)와 같은 결: 점주 레이어(매대·♡ 할인)와 관계 트랙(대화·선물·하트)이
#     **서로를 게이팅하지 않는다**(ADR-0060 결정 8). 그래서 대사는 ♡0에서도 "매대는 연다"를
#     말하고, ♡가 올라도 매대 해금을 약속하지 않는다(할인만 깊어진다).
#   - ★ADR-0008/ADR-0030 관계-중립 불변: 뱃사공 ♡은 **가게 정책(할인)뿐**이다. 대사도 "친해지면
#     고기가 더 문다" 류의 *메카닉 약속*을 절대 하지 않는다 — 입질·품질·혼력에 보정 0.
#   - 초상화 없음(portrait_stem="") — 스프라이트·초상화는 S3-T10 아트 패스 소관이다.

const BODY_SIZE := Vector2(16, 32)   # NPC 자리 규격(ADR-0003 — 플레이어·미호·멜·네오와 동일)

# 하트 0(첫 만남): 자기 소개 = 사공 + 가게. 물길 이야기 + **낚시 팁 한 줄**(물때 = 시간대·절기로
# 무는 놈이 갈린다 — FishCatalog의 phase/season 잠금을 대사가 자연스레 가리킨다).
# PackedStringArray() 생성자는 상수식이 아니라 const로 못 두므로, 상수식인 배열 리터럴로 두고
# lines()에서 PackedStringArray로 변환해 넘긴다(neo.gd·mochi.gd와 동일).
const LINES_INTRO := [
	"[talk]…노 젓는 사람일세. 자네를 태워 온 물길, 그 물길 끝에서 이 가게를 보고 있지.",
	"[talk]여긴 낚싯대와 미끼를 대고, 잡아 온 놈은 그 자리에서 값을 쳐 준다. 배는 공짜, 고기는 아니고.",
	"[smile]팁 하나 주지. 같은 자리라도 물때가 다르면 무는 놈이 다르네 — 아침에 안 물면 해질녘에 다시 와 보게.",
	"[talk]…물살 거스르지 말게. 낚시도 그렇고, 그 밖의 것도 그렇고.",
]

# 하트 1~2(낯 익음): 단골로 알아본다 + 할인이 *가게 정책*임을 명시(관계-중립 — 메카닉 약속 없음).
const LINES_WARMING := [
	"[smile]또 왔군. 자네 발소리는 물 위에서도 들려.",
	"[talk]단골에겐 값을 깎아 준다. 그뿐일세 — 내가 친하다고 고기가 더 물어 주진 않아. 그건 자네 손이 하는 일이지.",
	"[talk]줄이 자꾸 끊긴다면 놈이 자네 낚싯대보다 큰 걸세. 대를 바꾸든지, 작은 놈부터 익히든지.",
]

# 하트 3~4(가까운 사이): 사공의 자리에 대한 한 줄 — 건네주기만 하는 자의 무심한 다정.
# ★ 속죄-중립 유지: 그는 죄를 씻는 중이 아니다. 다만 오래 봐서 아는 것들을 말할 뿐이다.
const LINES_CLOSE := [
	"[talk]나는 태워 줄 뿐이라 아무것도 묻지 않네. 묻지 않아서 오래 하는 일이기도 하고.",
	"[smile]자네처럼 노 대신 낚싯대를 쥐고 물가에 붙어 있는 손님은 드물어. 나쁘지 않은 일이야.",
	"[talk]깊은 물에는 이름 붙은 놈들이 산다. 만나면 알게 될 걸세 — 줄이 먼저 알려 주니까.",
]

# 하트 5(맥스): 사공이 손님에게 자리를 내주는 결. 여전히 무게를 안 싣고, 물 이야기로 마무리한다.
const LINES_BOND := [
	"[smile]내 배 뱃머리 자리, 자네 몫으로 비워 두겠네. 앉든 말든 자유고.",
	"[talk]값은 이미 깎을 만큼 깎았어. 더 깎으면 노를 팔아야 해.",
	"[talk]…언젠가 자네도 건너편으로 갈 테지. 그때까진 잘 낚게. 물은 안 도망가니 서두르지 말고.",
]

# 오늘 이미 일일 대화를 한 뒤 또 말 걸었을 때(점수 없음 — 대사만 가볍게 바뀐다).
const LINE_AGAIN := "[talk]아까 봤잖은가. 살 게 있거든 매대를 부르게."

# ★ T1 낚싯대 증정 대사(ADR-0061 결정 4 "T1 = 뱃사공 첫 대화 증정"). main의 레코드 훅
# (`talk_intro`)이 **첫 대화 1회**만 이 줄을 앞세우고 실제 지급을 수행한다 — 대사는 여기(캐릭터)가
# 들고, 지급·플래그·세이브는 main이 든다(ADR-0005 텍스트/로직 분리).
const LINES_ROD_GIFT := [
	"[talk]…맨손으로 물가에 서 있었나. 그래서야 구경만 하다 하루가 가지.",
	"[smile]자, 낡은 낚싯대일세. 값은 안 받아 — 물가에 사람이 있어야 가게도 돌지.",
	"[talk]작은 놈부터 익히게. 큰 놈은 그 대로는 줄이 끊겨.",
]

# 대화창에 띄울 이름. ★호칭 그대로(본명·종 = 서랍, owner 큐).
func display_name() -> String:
	return "뱃사공"

# 말 걸었을 때 들려줄 대사 줄들. hearts = 현재 하트 단계, first_today = 오늘 첫 대화인가
# (neo.gd·mochi.gd와 같은 시그니처 — 프레임워크는 이 한 형태만 안다).
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

# P2.3② 도색 스프라이트(있으면 그레이박스 대신). 뱃사공 시트는 S3-T10 아트 패스에서 들어온다 —
# 파일이 없으면 CharSprite.make가 null을 돌려주므로 그때까진 아래 그레이박스가 그려진다.
var _sprite: AnimatedSprite2D = null

func _ready() -> void:
	_sprite = CharSprite.make("res://assets/characters/boatman.png")
	if _sprite != null:
		add_child(_sprite)

# ★ [S2-T7] 보간 걷기 시각 오프셋(ResidentWalk가 채운다 — resident_walk.gd). 논리 위치(position)는
# 스테이션 칸으로 즉시 스냅하고(말 걸기 판정·헤드리스 테스트가 보는 값 불변), *그림만* 이만큼 뒤로
# 민다. 주민 프레임워크 공통 규약이라 새 주민 캐릭터 파일도 이 블록을 그대로 복사한다(mochi.gd 동형).
# ★ 뱃사공은 상시 한 자리(생선가게 앞)라 실제로 걷지는 않는다 — 규약만 갖춘다(네오와 같은 상태).
var walk_offset := Vector2.ZERO

func set_walk_offset(v: Vector2) -> void:
	if walk_offset == v:
		return
	walk_offset = v
	if _sprite != null:
		_sprite.position = v   # 도색 스프라이트는 자식 노드 → 자식 위치로 민다
	queue_redraw()             # 그레이박스는 _draw의 draw_set_transform으로 민다

# 그레이박스 실루엣 = **삿갓 + 노**. 다른 주민(멜 관모·네오 태엽키·옥자 뾰족모자·모찌 떡)과
# 머리 위 실루엣부터 갈라 둔다(asset-ruleset §실루엣 구분). 몸은 짙은 물빛 도롱이 결이라
# 백자(네오)·노랑(미호)과도 색으로 구분된다. 진짜 아트는 S3-T10.
const _HAT_W := 26.0    # 삿갓 챙 폭(몸 16보다 넓게 — 위에서 눌러쓴 실루엣)
const _HAT_H := 5.0
const _OAR_LEN := 30.0  # 노 길이(어깨 위로 비스듬히 솟는 사선 — 뱃사공 표식)

func _draw() -> void:
	draw_set_transform(walk_offset)   # ★ [S2-T7] 보간 걷기: 그레이박스 그림 전체를 오프셋만큼 민다
	if _sprite != null:
		return  # 도색 스프라이트가 있으면 그레이박스는 안 그린다(폴백 전용)
	var top := -BODY_SIZE.y
	# 노(몸 뒤) — 왼쪽 아래에서 오른쪽 위로 비스듬한 장대 + 끝의 물갈퀴. 몸보다 먼저 그려 뒤에 둔다.
	var oar_a := Vector2(-9.0, -2.0)
	var oar_b := oar_a + Vector2(_OAR_LEN * 0.55, -_OAR_LEN)
	draw_line(oar_a, oar_b, Color(0.45, 0.33, 0.22), 2.0)
	draw_colored_polygon(PackedVector2Array([
		oar_a + Vector2(-2.0, 1.0), oar_a + Vector2(2.5, 0.0), oar_a + Vector2(1.0, 5.0),
	]), Color(0.38, 0.28, 0.19))   # 물갈퀴(노깃)
	# 몸통: 발치 원점 기준 위로 16×32. 짙은 물빛 도롱이(어두운 청록 — 저승 물길 결).
	var body := Rect2(-BODY_SIZE.x * 0.5, top, BODY_SIZE.x, BODY_SIZE.y)
	draw_rect(body, Color(0.20, 0.29, 0.32))
	# NW 광원(asset-ruleset §NW): 왼쪽 어깨선에 밝은 띠 한 줄.
	draw_rect(Rect2(body.position.x, top + 10.0, 3.0, BODY_SIZE.y - 10.0), Color(0.28, 0.39, 0.42))
	# 얼굴 면(삿갓 그늘 아래라 어둡게) + 도트 눈 둘. 눈이 챙 밑에서 겨우 보이는 결.
	draw_rect(Rect2(body.position + Vector2(2.0, 5.0), Vector2(BODY_SIZE.x - 4.0, 6.0)), Color(0.30, 0.28, 0.26))
	draw_rect(Rect2(-4.0, top + 7.0, 2.0, 2.0), Color(0.88, 0.86, 0.80))
	draw_rect(Rect2(2.0, top + 7.0, 2.0, 2.0), Color(0.88, 0.86, 0.80))
	# 삿갓 — 넓은 챙(사다리꼴) + 낮은 꼭지. 머리 위 실루엣의 주인공이라 몸보다 넓고 밝다.
	var brim_y := top + 4.0
	draw_colored_polygon(PackedVector2Array([
		Vector2(-_HAT_W * 0.5, brim_y), Vector2(_HAT_W * 0.5, brim_y),
		Vector2(_HAT_W * 0.28, brim_y - _HAT_H), Vector2(-_HAT_W * 0.28, brim_y - _HAT_H),
	]), Color(0.72, 0.63, 0.40))
	draw_rect(Rect2(-3.0, brim_y - _HAT_H - 2.0, 6.0, 2.0), Color(0.62, 0.54, 0.34))   # 꼭지
	# 허리끈(도롱이 여밈) — 몸 가운데 가로 한 줄로 상·하체를 나눠 납작한 색면을 깬다.
	draw_rect(Rect2(body.position.x, top + 19.0, BODY_SIZE.x, 2.0), Color(0.46, 0.36, 0.24))
