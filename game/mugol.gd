extends Node2D
class_name Mugol
# ★[S5-T6 / ADR-0063 결정 6] 무골 NPC — 업화 갱도 모험가 길드 점주(T2 · 그레이박스 몸 + 대사).
#
# 목적: ADR-0063 결정 6 "길드 점주 = 백골 무사 「무골(武骨)」"의 *캐릭터 파일 몫*이다. 주민 프레임워크
#       (resident.gd)가 요구하는 세 가지(display_name·lines·walk_offset 블록) + 자기 몸 그리기 **만**
#       든다 — 자리·스케줄·매대·증정은 한 줄도 여기 없다(전부 main `_setup_residents()` 레코드와
#       길드 매대 배선 소관. pulmu.gd·ongi.gd·boatman.gd 선례 그대로).
#
# ★ 정체성([ADR-0063] 결정 6):
#   · **백골 무사**. 갱도 남단 모험가 길드에서 **검 5종**(깊이 게이팅 — 결정 5)과 **명부환**
#     (회복 소모품)을 판다. 스타듀 말론(Marlon) 대응.
#   · **결 하나**: 살은 다 삭고 뼈만 남도록 갱도를 오르내린 늙은 무사 — 이제 자기가 내려가는 대신
#     내려갈 사람에게 쇠를 쥐여 준다. ⚠️ 이건 **T2 라이트 플레이버**이지 [속죄] 구조가 아니다 —
#     생전의 죄를 정반대로 쓰는 구조는 메인 4인 독점이다(ADR-0004·ADR-0005). 그래서 대사에 죄·
#     심판·속죄의 어휘를 안 싣는다. 깊이·칼·상처 이야기만 한다.
#   · ★[owner 큐] **이름·설정은 서랍**이다([CONTEXT] "이름·설정은 owner 큐"). "무골(武骨)"은 뼈만
#     남은 무사라는 호칭이라 표시명도 그대로 "무골"이다 — 본명이 정해지면 display_name만 갈아
#     끼우면 된다(레코드 id "mugol"·세이브 키는 영문이라 개명 영향 0).
#   · ⚠️ **"저승"을 날것으로 부르지 않는다** — 이 세계의 주민에게 여기는 그냥 "여기"다(뱃사공·옹이·
#     풀무 톤 정합). "아래", "굴", "바닥" 같은 우회로 결만 쓴다.
#
# 설계 메모:
#   - neo.gd·boatman.gd·ongi.gd·pulmu.gd(점주 선례)와 같은 결: 점주 레이어(매대)와 관계 트랙
#     (대화·선물·하트)이 **서로를 게이팅하지 않는다**(ADR-0060 결정 8). ♡0에서도 매대가 다 열리고,
#     ♡가 올라도 새 무기가 해금되지 않는다(해금 축은 **도달 깊이 하나뿐** — ADR-0031 결정 2).
#   - ★ADR-0008 관계-중립 불변: 무골 ♡은 **아무 메카닉 보정도 주지 않는다**(풀무와 동형 — 할인 0).
#     뱃사공·옹이·네오가 ♡→매대 할인을 먹는 것과 갈리는 근거는 풀무와 같다: 무기 가격은 깊이
#     게이팅과 한 몸인 **경제 곡선**이라 관계로 흔들리면 곡선 자체가 무의미해진다. 대사도
#     "친해지면 싸게 해 준다"를 절대 약속하지 않는다.
#   - **토벌 게시판은 여기 없다**(ADR-0063 결정 6 "위상만 예약" — 보상이 전부 반지·모자라 장비
#     클러스터 서랍 의존). 대사도 의뢰를 약속하지 않는다.
#   - 초상화 없음(portrait_stem="") — 스프라이트·초상화는 S5-T9/T10 아트 패스 소관이다.

const BODY_SIZE := Vector2(16, 32)   # NPC 자리 규격(ADR-0003 — 플레이어·미호·멜·옹이·풀무와 동일)

# 하트 0(첫 만남): 자기 소개 = 길드 + 두 물건(검·환약). **깊이가 매대를 연다는 규칙**을 첫 대사에서
# 못 박는다(스타듀 말론이 그렇듯 "돈은 있는데 왜 안 보이냐"는 혼란을 대사가 미리 막는다).
# PackedStringArray() 생성자는 상수식이 아니라 const로 못 두므로, 상수식인 배열 리터럴로 두고
# lines()에서 PackedStringArray로 변환해 넘긴다(pulmu.gd·ongi.gd와 동일).
const LINES_INTRO := [
	"[talk]…살아 있는 발소리군. 오랜만일세. 무골이라 하네, 여긴 길드고.",
	"[talk]파는 건 둘뿐이야. 벨 것과, 베인 뒤에 삼킬 것.",
	"[talk]칼은 **내려간 만큼** 꺼내 놓네. 아직 못 본 깊이의 물건은 여기 안 걸려 있어.",
	"[smile]명부환은 늘 있네. 백오십 냥. 아껴 두면 아까운 물건이지 — 죽고 나서 남기면 그게 더 아깝고.",
]

# 하트 1~2(낯 익음): 단골로 알아본다 + **할인이 없음**을 명시(관계-중립 — 메카닉 약속 0).
const LINES_WARMING := [
	"[smile]또 왔군. 아직 붙어 있구먼, 팔다리가.",
	"[talk]값은 못 깎네. 쇠값은 깊이가 정하지 내가 정하는 게 아니야 — 친하다고 무르지도 않아.",
	"[talk]대신 하나 일러 두지. 몰려들거든 등을 벽에 붙이게. 뒤에서 오는 걸 못 보면 끝이야.",
]

# 하트 3~4(가까운 사이): 백골 무사의 결 한 줄 — 자기가 내려가던 시절이 여기서 처음 비친다.
# ★무게를 안 싣는다(속죄 어휘 금지) — 담담한 늙은 직업인의 말로 흘린다.
const LINES_CLOSE := [
	"[talk]나도 한때는 저 아래를 오르내렸네. 살이 다 삭도록.",
	"[smile]지금은 여기 앉아 있지. 무릎이 없어서 그런 건 아니고… 뭐, 반쯤은 그것도 맞네.",
	"[talk]깊이는 정직해. 얕은 데선 아무도 안 죽고, 깊은 데선 아무나 죽지 — 흥정이 안 되는 게 편하다네.",
]

# 하트 5(맥스): 노병이 후배에게 자리를 넘기는 결. 여전히 가볍게, 칼 이야기로 닫는다.
const LINES_BOND := [
	"[smile]자네 몫으로 한 자루 닦아 두겠네. 결이 곧은 걸로 골라 뒀어.",
	"[talk]바닥까지 가거든 거기 놓인 걸 열어 보게. 나는 못 열었네 — 그때 무릎이 먼저 갔거든.",
	"[talk]…칼은 쥔 사람 손을 닮는다네. 자네 것은 꽤 침착해졌어.",
]

# 오늘 이미 일일 대화를 한 뒤 또 말 걸었을 때(점수 없음 — 대사만 가볍게 바뀐다).
const LINE_AGAIN := "[talk]아까 봤잖은가. 살 게 있거든 매대를 부르게."

# ★ 첫 방문 증정 대사(ADR-0063 결정 5 "첫 무기 = 길드 첫 방문 증정" — 말론 Rusty Sword 1:1).
# main의 레코드 훅(`talk_intro`)이 **첫 대화 1회**만 이 줄을 앞세우고 실제 지급을 수행한다 —
# 대사는 여기(캐릭터)가 들고, 지급·플래그·세이브는 main이 든다(뱃사공 T1 낚싯대 증정 1:1).
const LINES_SWORD_GIFT := [
	"[talk]…맨손인가. 그 꼴로 내려가면 첫 층에서 잡귀 밥일세.",
	"[smile]자, 녹슨 물건이지만 날은 서 있네. 값은 안 받아 — 빈손을 내려보내는 게 더 손해라서.",
	"[talk]얕은 데서 손에 익히게. 깊이 가려거든 그때 다시 오고.",
]

# 대화창에 띄울 이름. ★호칭 그대로(본명·설정 = 서랍, owner 큐).
func display_name() -> String:
	return "무골"

# 말 걸었을 때 들려줄 대사 줄들. hearts = 현재 하트 단계, first_today = 오늘 첫 대화인가
# (pulmu.gd·ongi.gd·boatman.gd와 같은 시그니처 — 프레임워크는 이 한 형태만 안다).
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

# P2.3② 도색 스프라이트(있으면 그레이박스 대신). 무골 시트는 S5-T9/T10 아트 패스에서 들어온다 —
# 파일이 없으면 CharSprite.make가 null을 돌려주므로 그때까진 아래 그레이박스가 그려진다.
var _sprite: AnimatedSprite2D = null

func _ready() -> void:
	_sprite = CharSprite.make("res://assets/characters/mugol.png")
	if _sprite != null:
		add_child(_sprite)

# ★ [S2-T7] 보간 걷기 시각 오프셋(ResidentWalk가 채운다 — resident_walk.gd). 논리 위치(position)는
# 스테이션 칸으로 즉시 스냅하고(말 걸기 판정·헤드리스 테스트가 보는 값 불변), *그림만* 이만큼 뒤로
# 민다. 주민 프레임워크 공통 규약이라 새 주민 캐릭터 파일도 이 블록을 그대로 복사한다(pulmu.gd 동형).
# ★ 무골은 상시 한 자리(길드 카운터 뒤)라 실제로 걷지는 않는다 — 규약만 갖춘다(네오·옹이·풀무와 같은 상태).
var walk_offset := Vector2.ZERO

func set_walk_offset(v: Vector2) -> void:
	if walk_offset == v:
		return
	walk_offset = v
	if _sprite != null:
		_sprite.position = v   # 도색 스프라이트는 자식 노드 → 자식 위치로 민다
	queue_redraw()             # 그레이박스는 _draw의 draw_set_transform으로 민다

# 그레이박스 실루엣 = **민 두개골 + 등에 멘 대검**. 다른 주민(멜 관모·네오 태엽키·옥자 뾰족모자·
# 모찌 떡·뱃사공 삿갓·옹이 잔가지·풀무 외뿔)과 머리 위 실루엣부터 갈라 둔다(asset-ruleset §실루엣
# 구분). 몸은 바랜 뼈 + 낡은 가죽 갑옷 톤이라 색으로도 구분된다. 진짜 아트는 S5-T9/T10.
const _SKULL_R := 5.0     # 두개골 반지름(모자·뿔 없이 **맨 뼈**가 실루엣의 주인공 — 유일한 민머리 주민)
const _BLADE_LEN := 26.0  # 등에 멘 대검 길이(어깨 위로 솟는 사선 — 뱃사공 노와 각도를 반대로 둔다)

func _draw() -> void:
	draw_set_transform(walk_offset)   # ★ [S2-T7] 보간 걷기: 그레이박스 그림 전체를 오프셋만큼 민다
	if _sprite != null:
		return  # 도색 스프라이트가 있으면 그레이박스는 안 그린다(폴백 전용)
	var top := -BODY_SIZE.y
	# 등에 멘 대검(몸 뒤) — 오른쪽 아래에서 왼쪽 위로 솟는 사선(뱃사공 노와 반대 방향) + 코등이.
	# 몸보다 먼저 그려 뒤에 둔다.
	var hilt := Vector2(7.0, top + 24.0)
	var tip := hilt + Vector2(-_BLADE_LEN * 0.42, -_BLADE_LEN)
	draw_line(hilt, tip, Color(0.62, 0.64, 0.70), 3.0)                      # 칼날
	draw_line(hilt + Vector2(-3.0, 2.0), hilt + Vector2(3.0, -2.0), Color(0.40, 0.33, 0.22), 3.0)  # 코등이
	# 몸통: 발치 원점 기준 위로 16×32. 낡은 가죽 갑옷(바랜 흙빛 회갈).
	var body := Rect2(-BODY_SIZE.x * 0.5, top, BODY_SIZE.x, BODY_SIZE.y)
	draw_rect(body, Color(0.34, 0.31, 0.28))
	# NW 광원(asset-ruleset §NW): 왼쪽 결에 밝은 띠 한 줄.
	draw_rect(Rect2(body.position.x, top + 11.0, 3.0, BODY_SIZE.y - 11.0), Color(0.46, 0.42, 0.37))
	# 갈비 흉갑 — 가죽 위로 드러난 뼈 두 줄(백골이라는 표식을 몸통에서도 읽히게).
	draw_rect(Rect2(body.position.x + 2.0, top + 14.0, BODY_SIZE.x - 4.0, 2.0), Color(0.82, 0.80, 0.72))
	draw_rect(Rect2(body.position.x + 2.0, top + 18.0, BODY_SIZE.x - 4.0, 2.0), Color(0.72, 0.70, 0.62))
	# 허리띠 — 상·하체를 나눠 납작한 색면을 깬다.
	draw_rect(Rect2(body.position.x, top + 22.0, BODY_SIZE.x, 2.0), Color(0.26, 0.21, 0.16))
	# 두개골 — 몸통 위 맨 뼈(모자 없음). 눈구멍 둘 + 이빨 한 줄.
	var skull := Vector2(0.0, top + 5.0)
	draw_circle(skull, _SKULL_R, Color(0.86, 0.84, 0.76))
	draw_rect(Rect2(skull + Vector2(-4.0, 4.0), Vector2(8.0, 3.0)), Color(0.86, 0.84, 0.76))   # 턱
	draw_rect(Rect2(skull + Vector2(-3.5, -1.5), Vector2(2.5, 3.0)), Color(0.14, 0.13, 0.12))  # 왼 눈구멍
	draw_rect(Rect2(skull + Vector2(1.0, -1.5), Vector2(2.5, 3.0)), Color(0.14, 0.13, 0.12))   # 오른 눈구멍
	for i in 3:
		draw_rect(Rect2(skull + Vector2(-3.0 + i * 2.5, 4.5), Vector2(1.5, 2.5)), Color(0.30, 0.28, 0.25))
