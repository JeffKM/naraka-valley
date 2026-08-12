extends Node2D
class_name Ken
# ★[S9b-T1 / ADR-0068 결정 3·5·6] 켄 NPC — **조연 코러스 9인 중 둘째의 풀 온보딩**.
#
# 목적: [ADR-0068] 결정 3이 정의한 "조연 1인 = 인물 층 + 서사 층 한 태스크"를 켄으로 이행한다.
#       인물 층(레코드·집·스케줄·선물·생일)은 main의 레코드 1건이 지고, **서사 층 전량은 이
#       파일이 진다** — main은 "언제 부르는가"만 알고 "무엇을 말하는가"는 한 줄도 모른다
#       ([ADR-0005] 서사 텍스트는 캐릭터에만). 훅 목록은 miho.gd와 **같은 시그니처**다:
#
#   · lines(hearts, first_today)      — 일상 대사 **4단**(♡0 / ♡1+ / ♡3+ / ♡5+)
#   · spouse_lines(day, first_today)  — 배우자 전용 **4축**(메인 8축의 절반 — 결정 5)
#   · heart_gate_lines(target)        — ♡1~4 단계 관문 발화(조연 4단 아크 본문)
#   · heart_gate_cutscene(target)     — ♡1~4 관문 컷신(연출 등급 2 · **4동사 한정**)
#   · heart_gate_letter(target)       — 관문 여진 편지 id(mailbox 테이블 행 — 다음 아침 도착)
#   · season_question(season)         — 절기 물음 1개(질문·선택지·반응 — **답은 전부 0점**)
#   · confession_lines(accepted)      — 의지 시험(♡5 고백) 수락/거절 ★휴면(아래)
#   · divorce_lines()                 — 이혼 작별(첫 줄이 토스트에 선다) ★휴면
#   · birthday_lines()                — 생일 당일 플레이버
#
# ★ 정체성([residents.md] §남요괴 2 · [narrative-bible.md] §5.2 켄):
#   · **언데드 거인**(T1 · 서양 계열 — ⚠️강시(멜)와 신화 계통·체형·분위기로 분리 · ⚠️유니버설
#     프랑켄슈타인 디자인(녹색·볼트·납작머리) 금지). 2m 거구·흉터·처진 눈매의 순한 미남.
#   · **생전 죄** = "겉모습 때문에 괴물 취급받다 단 한 번 터진 분노로 사람을 해친 죄"(일회성 폭발).
#   · **그날 밤** = 약방 뒷마당에 쓰러진 걸 주인이 안 무서워하고 치료해 준 인연으로 우직한 조수가
#     됐고, 괴력으로 기둥을 받치며 갇힌 사람을 구하려 했으나 **밖에서 잠긴 문을 못 부쉈고** 잔해에
#     깔려 죽었다. → ♡3 그날 밤 고백의 파편이 정확히 이 "못 부순 문"이다.
#   · **나라카 연결** = 은인들을 못 구한 거대한 부채감. 겉바속촉(거구인데 세상 무해·섬세 — 머신은
#     가볍게 찻잔은 조심), **식물 사랑**, 칭찬받으면 얼굴 가림.
#   · **반전 로맨스 축** = 무서운 겉 ↔ 솜사탕 속 → 결혼 = 주인공만은 괴물로 안 보고 그 힘을
#     '지킴'으로 받아 준다.
#
# ★ **조연 = 쉼터 2채널**([narrative-bible §6.1]) — 대화·선물만으로 하트가 오른다. **활동 채널도,
#   곱셈기(effect_fn)도 없다**([ADR-0008] 곱셈기는 메인 4인 독점). 그래서 이 파일에는 메카닉을
#   건드리는 코드가 한 줄도 없다(순수 대사 + 자기 몸 그리기).
#
# ★ **봉인 법칙**([ADR-0016] · [ADR-0068] 결정 6 조연 금칙어)이 이 파일의 가장 센 제약이다.
#   ㉠ ♡3 = **자기 파편 + 자기 죄책감만**. 중심 진실 4종(옥자의 희생 / 기억 봉인 / 마녀 = 연인 /
#      플레이어의 죄목)은 **한 줄도 없다**. 켄은 문 너머의 사람이 누구였는지 **끝까지 못 봤고**,
#      자기가 죽은 뒤의 일은 **모른다** — 그 두 개의 공백을 본문이 스스로 선언한다(플레이어가
#      잇는 자리를 비워 두는 것이 이 비트의 설계다).
#   ㉡ ♡4 = **자기 생전 죄까지만**. 남의 죄도, 플레이어의 죄도 겨누지 않는다.
#   ㉢ 켄은 옥자를 **"그 집 주인"**으로만 부른다 — 이름을 부르면 "이승의 약방 주인 = 지금의 카페
#      사장"이 켄의 입으로 확정돼 버린다. 잇는 것은 플레이어 몫이다([CONTEXT] 불변).
#   이 계약은 `ken_arc_test`의 금칙어 스캔(31어)이 회귀로 잠근다.
#
# ★ **선택지는 전부 0점**([ADR-0067] 결정 4). 절기 물음의 어떤 답도 호감도를 건드리지 않는다 —
#   이 파일에 Affinity 참조가 한 줄도 없는 것이 그 계약의 구현이다(반응 한 줄만 돌려준다).
#
# ★ **연애·배우자 축은 휴면 콘텐츠다**([ADR-0068] 결정 2 — 조연 연애·결혼 개통은 S9b-T6 소관).
#   `confession_lines`·`divorce_lines`·`spouse_lines`를 **지금 다 써 두되**, main의 `ROMANCE_OPEN`
#   명단은 건드리지 않는다 — T6이 명단에 "ken"을 넣는 순간 코드 0줄로 개통된다(훅 이음매의 값).

# 몸 규격 — 사람형(16×32, [ADR-0003])의 약 1.4배. [residents.md] "2m 거구"의 그레이박스 환산이다
# (사람 ~1.45m 환산의 16×32 → 2m면 세로 44~46px). **논리 위치는 여전히 한 칸**이라 말 걸기 판정·
# 통행·스테이션 규약은 다른 주민과 완전히 동일하다(그레이박스는 충돌체가 아니라 그림이다).
const BODY_SIZE := Vector2(22, 46)

# ── 일상 대사 4단 ────────────────────────────────────────────────────────────
# 축 = **"무서운 겉 ↔ 솜사탕 속"**([residents.md] 반전). 네 단이 그 거리를 좁혀 간다:
#   ♡0 = 겉(놀라게 해서 미안하다) → ♡1+ = 속을 살짝(화분·이름) → ♡3+ = 부채감이 비침 →
#   ♡5 = 그 큰 몸이 통째로 상대 쪽으로 기운다.
# PackedStringArray() 생성자는 상수식이 아니라 const로 못 두므로, 상수식인 배열 리터럴로 두고
# lines()에서 변환해 넘긴다(miho.gd·mochi.gd와 동일 관례).
const LINES_INTRO := [
	"[talk]…아. 사람이다. 미안, 놀랐지.",
	"[talk]나는 켄. 동쪽 끝 집에 산다. 집이 큰 게 아니라 내가 큰 거야.",
	"[shy]악수는… 안 할래. 내 손은 아직 힘 조절이 서툴러.",
	"[talk]무거운 거 있으면 불러. 그건 내가 제일 잘한다.",
	"[smile]대신 잔은 안 나른다. 세 개 깼어.",
	"[talk]낮엔 광장 남서쪽 구석에 있어. 거기 나무 그늘이 넓거든.",
	"[shy]…겁내지 않아 줘서 고맙다. 오늘은 그거면 됐어.",
]

const LINES_WARMING := [
	"[smile]왔구나. 오늘도 안 놀라네. 좋다.",
	"[talk]내 화분 봤어? 창가에 열두 개. 이름도 다 붙였어.",
	"[shy]이름은… 안 알려줄래. 웃을 것 같아서.",
	"[talk]싹은 세게 잡으면 죽어. 그래서 손끝으로만 만진다. 이만큼만.",
	"[talk]사람들이 나를 보면 길을 비켜 줘. 친절이 아니라 비켜 주는 거야. 아는데, 괜찮아.",
	"[smile]너는 안 비키더라. 그날 나 좀 오래 서 있었어.",
	"[shy]…아니 뭐. 그냥 그랬다고.",
]

const LINES_CLOSE := [
	"[talk]오늘은 들 거 없어? 없으면 그냥 앉아 있을게.",
	"[sad]나는 잘 자. 그게 가끔 미안해. 못 잔 사람들이 있는데.",
	"[talk]손이 크면 좋은 게 하나 있어. 누가 울 때 얼굴을 다 가려 줄 수 있어.",
	"[smile]네가 준 거 심었어. 잘 자란다. 물은 아침에만 준다.",
	"[shy]…네 이야기도 언젠가 들려줘. 나는 오래 들을 수 있어. 그건 힘 안 드는 일이니까.",
	"[talk]화가 나면 나는 손을 등 뒤로 넣는다. 예전엔 그걸 몰랐어.",
	"[smile]오늘은 안 넣었네. 좋은 날이다.",
]

# ★ ♡5(연인) — 의지 시험(고백)을 통과해야 닿는 칸이라, 이 묶음이 서면 그 사람은 이미 켄의
#   연인이다. 결정 2가 조연 연애를 S9b-T6으로 미뤄 두었으므로 지금은 **휴면 상태로 대기**한다
#   (main의 ROMANCE_OPEN에 "ken"이 들어가는 순간 이 단이 살아난다).
const LINES_LOVER := [
	"[shy]…왔네. (거구가 한 뼘쯤 작아 보이게 웅크린다)",
	"[smile]앉아. 그늘은 내가 만들어 줄게. 그건 서 있기만 하면 되니까.",
	"[shy]네 손은 왜 이렇게 작아. 볼 때마다 놀라.",
	"[talk]나 요즘 잠들기 전에 하는 게 있어. 오늘 네가 웃은 횟수를 센다.",
	"[shy]…몇 번이었냐고? 안 알려줄래. 세는 게 좋아서 그러는 거야.",
	"[smile]무겁다는 말은 나한테 안 아껴도 돼. 나는 무거운 걸 드는 사람이야.",
	"[sad]가끔 무서워. 이만한 게 옆에 있어도 되나 싶어서. …그래도 있을게.",
]

# 오늘 이미 일일 대화를 한 뒤 또 말 걸었을 때(점수 없음 — 대사만 가볍게 바뀐다).
const LINE_AGAIN := "[talk]아까 봤잖아. …그래도 한 번 더 봐서 좋다."
const LINE_AGAIN_LOVER := "[shy]또 왔어? …가라는 말 아니야. 절대 아니야."
const LINE_AGAIN_SPOUSE := "[smile]지나가는 길이지? 응. 나 여기 있어."

# ── ★[ADR-0068 결정 5] 배우자 대사 **4축**(메인 8축의 절반) ──────────────────
# 축을 날(day)에서 파생하므로 상태가 0이고 세이브 키도 안 늘어난다(miho 8축과 같은 구조·절반 폭).
# 네 축: ① 아침·집 ② 화분·손 ③ 그 밤·부채 ④ 애정·미래.
# ★ 배우자 대사에도 봉인 법칙이 그대로 걸린다 — 결혼했다고 켄이 아는 것이 늘지 않는다.
const SPOUSE_AXES := [
	# ① 아침·집
	[
		"[smile]깼어? 문틀은 내가 고쳤어. 이제 안 삐걱거려.",
		"[talk]밥은 차렸는데 그릇이 다 크다. 내 손에 맞춰 산 거라 그래.",
		"[shy]네가 자는 동안 숨 쉬는 거 보고 있었어. …이상한가.",
		"[talk]추우면 말해. 나는 안 추워. 이건 죽어서 좋은 점 중 하나야.",
	],
	# ② 화분·손
	[
		"[smile]창가 화분 열둘이었는데 이제 열넷이야. 둘은 네 이름 붙였어.",
		"[talk]오늘 새 잎이 나왔어. 손끝으로만 만졌어. 진짜야.",
		"[shy]내 손 잡을 때 조심 안 해도 돼. 부서지는 쪽은 내가 아니니까.",
		"[talk]무거운 건 다 나한테 줘. 그게 내가 제일 잘하는 사랑이야.",
	],
	# ③ 그 밤·부채(★결혼해도 이 축은 안 닫힌다 — 속죄는 계속된다)
	[
		"[sad]가끔 밤에 문 두드리는 소리가 들려. 일어나 보면 바람이야.",
		"[talk]그럴 땐 우리 집 문을 다 열어 둬. 다 열어 두면 잠긴 게 없잖아.",
		"[sad]나는 그 밤을 안 잊을 거야. 잊으면 못 나온 사람들한테 미안하니까.",
		"[smile]그래도 어제는 네 얼굴 보다가 잠들었어. 그건 처음이야.",
	],
	# ④ 애정·미래
	[
		"[shy]사랑한다는 말은 잘 못 하겠어. 대신 지붕을 고쳐 놨어.",
		"[talk]너는 나를 괴물이라고 안 불러. 그거 하나로 이십 년이 갚아졌어.",
		"[smile]마당에 큰 나무 심자. 다 자란 걸 볼 순 없어도, 심는 건 지금 할 수 있잖아.",
		"[shy]…오래 있을게. 나 튼튼해.",
	],
]

# ── ★[ADR-0068 결정 5 · narrative-bible §6.2] 단계 관문 발화(조연 4단 아크) ───
# 조연의 4단은 메인의 속죄 조각(B1~B3)과 **다른 물건**이다:
#   ♡1~2 = 평소 매력(residents.md) — ♡1 힘(그가 남에게 줄 수 있는 유일한 것) / ♡2 말 돌림
#   ♡3   = **그날 밤 고백**(자기 파편 + 죄책감만) ★필수 세트피스(결정 5)
#   ♡4   = **생전 죄 고백**(자기 죄까지만 — 반전은 결혼 *후*의 몫이라 여기서 안 뒤집는다)
const GATE_HEART_1 := [
	"[talk]잠깐. 그거 나 줘 봐.",
	"[talk](켄이 손가락 두 개로 짐수레를 들어 옆으로 옮긴다)",
	"[smile]됐다. 이런 건 나한테 시켜. 진짜로.",
	"[talk]사람들은 내가 힘자랑하는 줄 알아. 아니야. 이게 내가 남한테 줄 수 있는 유일한 거라서 그래.",
	"[shy]…말이 길었다. 미안.",
	"[talk]아, 그리고. 화분 하나 줄게. 창가에 두면 산다.",
	"[smile]죽이면 또 줄게. 열두 개나 있으니까.",
]

const GATE_HEART_2 := [
	"[talk]오늘 저 문짝 고쳐 놨어. 걸쇠가 헐거웠더라.",
	"[sad]…문은 좀. 내가 좀 그래.",
	"[talk](켄이 자기 손을 한참 내려다본다)",
	"[sad]나, 문 앞에서 못 한 게 있어.",
	"[shy]아니— 됐다. 오늘 말고.",
	"[talk]언젠간 할게. 도망가는 거 아니야. 아직 말이 안 모여서 그래.",
	"[smile]자, 다른 거 뭐 들어 줄까. 그건 지금 할 수 있어.",
]

# ★ ♡3 = **그날 밤 고백**([ADR-0068] 결정 5 "♡3 = 필수 세트피스"). 봉인 법칙 최고 난도 구간이라
#   규칙을 다시 적어 둔다:
#   ㉠ 켄은 **자기가 한 일과 자기 손이 실패한 것**만 말한다. 문 너머의 사람이 누구였는지는
#      **끝까지 못 봤다**(문이 안 열렸으니까) — 이 공백이 코러스 모델의 핵심이다.
#   ㉡ 자기 옆을 지나 불 속으로 들어간 사람에 대해서도 **본 것만**이다: 이름도, 이유도, 그 뒤에
#      무슨 일이 있었는지도 안 말한다("나는 거기서 끝났거든").
#   ㉢ "그러니까 네 죄는 ○○다"·"그 사람이 너를 위해 ○○했다"는 **한 줄도 없다**. 잇는 것은
#      플레이어 몫이다([narrative-bible §4] 라쇼몽 구조).
const GATE_HEART_3 := [
	"[talk]…앉아. 오래 걸릴 거야.",
	"[sad]살아 있을 때 나는 어느 약방에서 일했어. 뒷마당에 쓰러져 있던 나를 그 집 주인이 안 무서워하고 고쳐 줬거든.",
	"[talk]그 집에서 내 몫은 무거운 거였어. 약장, 물독, 절구. 그것만 잘하면 됐어.",
	"[sad]그날 밤에 불이 났어.",
	"[talk]기둥은 받쳤어. 그건 됐어. 천장은 안 내려왔으니까.",
	"[sad]근데 안쪽 방문이 안 열렸어. 밖에서 잠겨 있더라.",
	"[talk]문 너머에 사람이 있었어. 숨소리가 났어. 두드리는 소리도.",
	"[sad]나는 이 손으로 수레도 한 손에 든다. 그 문 하나를 못 부쉈어.",
	"[sad]그게 누구였는지는 끝까지 못 봤어. 문이 안 열렸으니까.",
	"[sad](켄이 편 손바닥을 한참 들여다본다)",
	"[talk]내가 아직 문을 붙들고 있을 때, 누가 내 옆을 지나서 불 속으로 들어갔어. 잡을 손이 없었어. 두 손 다 문에 있었으니까.",
	"[sad]그다음은 나는 몰라. 나는 거기서 끝났거든. 그 뒤는 내가 본 게 아니야.",
	"[shy]…오늘은 여기까지만 할게. 미안.",
]

# ★ ♡4 = **생전 죄 고백**([narrative-bible §6.2] "조연이 자기 생전 죄를 털어놓는 것까지만").
#   [residents.md] 켄의 죄 = "겉모습 때문에 괴물 취급받다 단 한 번 터진 분노로 사람을 해친 죄"
#   (일회성 폭발 — 만성 통제 불능인 루카와 분리). 반전(그 힘을 '지킴'으로 받아 줌)은 **결혼 후**의
#   몫이라 여기서 미리 뒤집지 않는다.
const GATE_HEART_4 := [
	"[talk]저번 얘기 말고, 그 앞의 얘기를 할게. 내가 왜 여기 있는지.",
	"[sad]나는 살아서 사람을 하나 해쳤어.",
	"[talk]평생 딱 한 번이었어. 그게 변명이 안 되는 것도 알아.",
	"[sad]어릴 때부터 나는 괴물이었어. 그렇게 불렀고, 그렇게 대했어. 나는 그냥 웃었어. 웃으면 덜 무서워하니까.",
	"[talk]이십 년쯤 웃었어. 그러다 어느 날 한 번 안 웃었어.",
	"[sad]딱 한 번 손을 뻗었는데, 그 사람이 다시 못 일어났어.",
	"[talk]그때 알았어. 사람들이 무서워한 게 틀린 게 아니었구나.",
	"[sad]그래서 아직도 손을 등 뒤로 넣어. 화가 안 나도 넣어.",
	"[shy]…이 얘기 하면 다들 반 걸음 물러서. 물러서도 돼. 나 안 서운해.",
	"[talk]그래도 말해야 한다고 생각했어. 네가 나를 잘못 알고 있으면 안 되니까.",
]

# ── ★[ADR-0067 결정 2 · ADR-0068 결정 5] 관문 컷신(연출 등급 2 — 4동사 한정) ──
# cutscene.gd 포맷 그대로다. **다섯 번째 동사는 없다**(npc/cam/fade/clock).
#
# ★ 좌표 규약: NPC 스텝의 tile은 **켄의 낮 스테이션(나루 마을 광장 남서 구석) 좌표계**다. 훅에
#   구역 인자가 없으므로(구역 인지 훅 미도입 — owner 큐), 켄이 집 앞이나 카페에 있을 때 관문이
#   열리면 그림이 순간 이동한다. 그래서 **NPC 스텝이 있는 컷신은 반드시 완전 암전(fade 1.0) 뒤에서만
#   자리를 잡고, 그 뒤로도 화면을 완전히 밝히지 않는다**([ADR-0068] 결정 5 "암전 은폐로 완화").
#   재생이 끝나면 main이 원 위치와 화면을 복원한다(_end_cutscene) — 발화는 그 뒤에 선다.
# ★ ♡1·♡2는 아예 npc 동사를 안 쓴다(카메라·페이드만) — 가벼운 비트에 순간이동 위험을 살 이유가 없다.
#   무거운 ♡3·♡4만 npc를 쓰고, 그 둘은 화면이 어두운 채로 끝난다(그 밤의 결과도 맞는다).
const CUTSCENE_HEART_1 := [
	{"verb": "clock", "running": false},
	{"verb": "cam", "offset": Vector2(0, -28), "secs": 0.6},   # 거인을 올려다보는 시선
	{"verb": "cam", "offset": Vector2(0, 0), "secs": 0.4},
	{"verb": "clock", "running": true},
]

const CUTSCENE_HEART_2 := [
	{"verb": "clock", "running": false},
	{"verb": "cam", "offset": Vector2(0, -14), "secs": 0.5},
	{"verb": "fade", "to": 0.40, "secs": 0.5},                 # 말이 끊기는 자리의 그늘
	{"verb": "fade", "to": 0.0, "secs": 0.5},
	{"verb": "cam", "offset": Vector2(0, 0), "secs": 0.4},
	{"verb": "clock", "running": true},
]

# ★ 그날 밤 고백 — 가장 긴 암전으로 내려갔다가 **끝까지 다 안 밝힌다**(fade 0.75 유지).
const CUTSCENE_HEART_3 := [
	{"verb": "clock", "running": false},
	{"verb": "fade", "to": 1.0, "secs": 0.8},                            # 완전 암전 = 그 밤으로
	{"verb": "npc", "id": "ken", "tile": Vector2i(49, 39)},              # 암전 뒤에서 자리 잡기
	{"verb": "cam", "offset": Vector2(0, -26)},
	{"verb": "fade", "to": 0.75, "secs": 0.9},                           # 반만 밝아진다(어둠 유지)
	{"verb": "npc", "id": "ken", "tile": Vector2i(48, 39), "secs": 0.8},  # 한 걸음 다가온다(보간)
	{"verb": "cam", "offset": Vector2(0, -18), "secs": 0.5},
	{"verb": "clock", "running": true},
]

# ★ 생전 죄 고백 — 같은 문법, 조금 더 밝다(그 밤이 아니라 그 앞의 이야기라 무대가 다르다).
const CUTSCENE_HEART_4 := [
	{"verb": "clock", "running": false},
	{"verb": "fade", "to": 1.0, "secs": 0.7},
	{"verb": "npc", "id": "ken", "tile": Vector2i(48, 38)},
	{"verb": "cam", "offset": Vector2(0, -22)},
	{"verb": "fade", "to": 0.55, "secs": 0.8},
	{"verb": "cam", "offset": Vector2(0, -12), "secs": 0.5},
	{"verb": "clock", "running": true},
]

# ── ★[ADR-0067 결정 7 · ADR-0068 결정 5] 관문 여진 편지(2~3통 중 3통) ─────────
# 관문이 성사된 그날 밤 큐에 들어가 **다음 날 아침** 우편함에 꽂힌다(mailbox.gd의 큐 규약).
# 본문은 mailbox.gd LETTERS 테이블 행이 들고, 이 파일은 **어느 칸이 어느 편지를 부르는가**만 안다.
# ★ ♡2엔 편지를 안 붙인다 — ♡2는 "말을 못 꺼낸" 칸이라 편지까지 오면 그 침묵이 깨진다.
# ★ 켄의 편지는 **물건이 먼저 오고 글이 나중**인 결이다(화분·잠금·누름꽃). 중복 발송 방어는
#   mailbox.send가 이미 진다(같은 id는 두 번 안 온다 — 재구애에도 안전).
const GATE_LETTERS := {
	1: "ken_gate1_pot",
	3: "ken_gate3_door",
	4: "ken_gate4_hand",
}

# ── ★[ADR-0067 결정 6] 절기 물음 ─────────────────────────────────────────────
# 주 첫날의 첫 대화에 켄이 **묻는다**. 절기당 하나(피안절·유화절·망연절·성야절).
#
# ★ **답은 전부 0점이다**([ADR-0067] 결정 4). 반응은 인-픽션 한 줄이고, 어떤 선택도 호감도·
#   플래그·아이템을 건드리지 않는다.
# ★ 형식: {"line": 질문 한 줄, "options": 선택지(2~4지 — DialogueBox 상한), "replies": 반응}.
#   options와 replies는 같은 길이다(index가 곧 짝).
# ★ 켄의 물음은 전부 **힘·돌봄·참는 것**의 축이다(캐릭터마다 묻는 결이 달라야 같은 주에 여럿에게
#   물어도 지루하지 않다 — 미호=땅/기다림 · 모찌=맛/나눔 · 켄=힘/조심).
const SEASON_QUESTIONS := [
	# 0 피안절(봄결) — 어린 것이 나는 절기
	{
		"line": "[talk]싹이 나기 시작했어. 넌 어린 게 있으면 어떻게 해?",
		"options": ["가까이서 지켜봐", "손 안 대고 둬", "울타리를 쳐"],
		"replies": [
			"[smile]나도 그래. 근데 나는 좀 떨어져서 봐. 그림자가 크거든.",
			"[talk]그것도 돌보는 거야. 안 만지는 게 제일 어려운 돌봄이더라.",
			"[shy]…나 그거 잘해. 뭐든 막아 서는 건 잘해.",
		],
	},
	# 1 유화절(여름결) — 더위에 다들 예민해지는 절기(★그의 죄가 분노라 이 물음이 제일 그답다)
	{
		"line": "[talk]더운 날엔 다들 예민해지더라. 넌 화나면 어떻게 해?",
		"options": ["소리를 지른다", "혼자 걷는다", "참는다"],
		"replies": [
			"[talk]그게 나을 때도 있어. 소리는 아무도 안 다치게 하니까.",
			"[smile]나도 걸어. 멀리 가서 나무를 좀 본다. 나무는 안 놀라거든.",
			"[sad]…참는 거 오래 하면 한 번에 나와. 그건 내가 잘 알아.",
		],
	},
	# 2 망연절(가을결) — 거두고 나르는 절기
	{
		"line": "[talk]무거운 걸 나르는 절기야. 넌 못 들 것 같으면 어떻게 해?",
		"options": ["그래도 든다", "나눠 든다", "누굴 부른다"],
		"replies": [
			"[sad]…그러다 등이 나가. 나는 등이 나가도 안 죽지만 너는 아니잖아.",
			"[smile]그게 맞아. 반씩 들면 둘 다 안 다쳐.",
			"[shy]불러. 내가 있잖아. 그러라고 이렇게 큰 거야.",
		],
	},
	# 3 성야절(겨울결) — 밤이 가장 긴 절기
	{
		"line": "[sad]밤이 길지. …넌 잠 안 오는 밤엔 뭘 해?",
		"options": ["불을 켠다", "그냥 누워 있는다", "누굴 생각한다"],
		"replies": [
			"[talk]…불은. 나는 켜 놓고 못 자. 미안, 그건 내 사정이야.",
			"[smile]나도 그래. 천장 보고 있으면 아침이 와.",
			"[shy]나도 요즘 그래. 누군지는 안 말할래.",
		],
	},
]

# ── 의지 시험(♡5 고백)·이혼·생일 ─────────────────────────────────────────────
# ★ 고백·이혼은 **휴면 콘텐츠**다(위 머리말 — ROMANCE_OPEN 확장은 S9b-T6 소관). 본문을 지금 써 두는
#   이유는 T6이 명단 한 줄만 고치면 되게 하기 위함이다(코드 0줄 개통).
const CONFESSION_ACCEPT := [
	"[surprised]…….",
	"[shy](켄이 대답 대신 두 손을 등 뒤로 넣었다가, 다시 꺼낸다)",
	"[talk]나 이 말 할 준비를 오래 했어. 근데 막상 하려니까 한 마디밖에 안 나온다.",
	"[shy]…좋아. 나도.",
	"[smile]손 줘. 세게 안 잡을게. 연습 많이 했어.",
]

# 거절(슬롯 점유 = 이미 다른 사람이 있다). [ADR-0022] 결: 적대 없음·무벌칙. 켄은 화내지 않고
# 기다리겠다고 한다 — 그 온도가 재시도(이혼 후 재구애)를 씁쓸하지 않게 남긴다.
const CONFESSION_REJECT := [
	"[surprised]…잠깐.",
	"[sad]고마워. 진심이야. 근데 지금 네 옆엔 이미 사람이 있잖아.",
	"[talk]그 사람 얼굴도 알아. 이 마을은 좁으니까.",
	"[shy]…괜찮아. 나는 기다리는 거 잘해. 원래 큰 건 느리거든.",
]

# 이혼 작별 — **첫 줄이 토스트로 나간다**(main._divorce_farewell_line). 그래서 첫 줄은 혼자 서도
# 완결되는 한 문장이어야 한다(뒷줄은 대화창 승격 시 쓰인다).
const DIVORCE_FAREWELL := [
	"[sad]원망 안 해. 나한테 화낼 자격이 있는 사람은 나뿐이야.",
	"[talk]짐은 내가 다 옮겨 줄게. 그건 마지막까지 내 몫이니까.",
	"[shy]무거운 거 생기면 불러. 그건 우리 일이 아니라 그냥 힘 쓰는 일이잖아.",
	"[smile]잘 지내. 화분은 계속 살려 놓을게.",
]

# ★ 생일 — 피안절 23일(Resident.BIRTHDAYS "ken": [0, 23]). 겨울처럼 생긴 자가 늦봄에 난다는
#   거울이 곧 "무서운 겉 ↔ 솜사탕 속"이다(배정 근거는 resident.gd 그 줄의 주석에도 남겼다).
const BIRTHDAY := [
	"[shy]오늘? …어떻게 알았어.",
	"[talk]나는 생일에 아무것도 안 해. 축하받으면 사람들이 곤란해하더라고.",
	"[smile]근데 네가 오니까 좀 다르네. 오늘은 좀 크게 웃어도 되나.",
	"[shy]…선물은 안 줘도 돼. 진짜야. 화분은 좋고.",
]

# ── 훅 구현(전부 main의 has_method 이음매 — miho.gd와 같은 시그니처) ────────────
# 대화창에 띄울 이름.
func display_name() -> String:
	return "켄"

# 말 걸었을 때 들려줄 대사 줄들. hearts = 현재 하트 단계, first_today = 오늘 첫 대화인가.
func lines(hearts: int = 0, first_today: bool = true) -> PackedStringArray:
	if not first_today:
		return PackedStringArray([LINE_AGAIN_LOVER if hearts >= 5 else LINE_AGAIN])
	if hearts >= 5:
		return PackedStringArray(LINES_LOVER)
	if hearts >= 3:
		return PackedStringArray(LINES_CLOSE)
	if hearts >= 1:
		return PackedStringArray(LINES_WARMING)
	return PackedStringArray(LINES_INTRO)

# 배우자 전용 묶음(main이 spouse_id == "ken"일 때 lines() 대신 부른다 — S9b-T6 개통 시).
# 축은 **day에서 파생**한다 — 어제 무슨 축이 나왔는지 기억하지 않으므로 상태·세이브 키가 0이다.
func spouse_lines(day: int = 1, first_today: bool = true) -> PackedStringArray:
	if not first_today:
		return PackedStringArray([LINE_AGAIN_SPOUSE])
	if SPOUSE_AXES.is_empty():
		return PackedStringArray()
	var axis: int = abs(day) % SPOUSE_AXES.size()
	return PackedStringArray(SPOUSE_AXES[axis])

# 단계 관문 발화(♡1~4). 범위 밖 칸은 빈 배열 = main의 placeholder 폴백.
func heart_gate_lines(target: int) -> PackedStringArray:
	match target:
		1: return PackedStringArray(GATE_HEART_1)
		2: return PackedStringArray(GATE_HEART_2)
		3: return PackedStringArray(GATE_HEART_3)
		4: return PackedStringArray(GATE_HEART_4)
	return PackedStringArray()

# 관문 컷신 스텝(♡1~4). 빈 배열 = 컷신 없이 대화만(하위호환 경로 그대로).
func heart_gate_cutscene(target: int) -> Array:
	match target:
		1: return CUTSCENE_HEART_1.duplicate(true)
		2: return CUTSCENE_HEART_2.duplicate(true)
		3: return CUTSCENE_HEART_3.duplicate(true)
		4: return CUTSCENE_HEART_4.duplicate(true)
	return []

# 관문 여진 편지 id("" = 이 칸엔 편지 없음). 발송·중복 방어는 mailbox가 진다.
func heart_gate_letter(target: int) -> String:
	return String(GATE_LETTERS.get(target, ""))

# 절기 물음(season = GameClock의 절기 인덱스 0..3). 빈 dict = 이 절기엔 물음 없음.
# 반환 dict는 **읽기 전용으로 다뤄라** — 원본 const를 넘기지 않고 얕은 사본을 준다.
func season_question(season: int) -> Dictionary:
	if season < 0 or season >= SEASON_QUESTIONS.size():
		return {}
	var q: Dictionary = SEASON_QUESTIONS[season]
	return {
		"line": String(q.get("line", "")),
		"options": PackedStringArray(q.get("options", [])),
		"replies": PackedStringArray(q.get("replies", [])),
	}

# 의지 시험 결과 발화(accepted = 슬롯이 비어 수락됐는가). ★휴면 — S9b-T6 개통.
func confession_lines(accepted: bool) -> PackedStringArray:
	return PackedStringArray(CONFESSION_ACCEPT if accepted else CONFESSION_REJECT)

# 이혼 작별. main은 **첫 줄만** 토스트에 쓴다. ★휴면 — S9b-T6 개통.
func divorce_lines() -> PackedStringArray:
	return PackedStringArray(DIVORCE_FAREWELL)

# 생일 당일 플레이버(평소 묶음 앞에 선다).
func birthday_lines() -> PackedStringArray:
	return PackedStringArray(BIRTHDAY)

# ── 몸(그레이박스 · 도색 시트가 오면 폴백) ────────────────────────────────────
# P2.3② 도색 스프라이트(있으면 그레이박스 대신). 켄 시트·초상은 **S9b-T9 아트 패스** 소관이라
# 지금은 파일이 없다 — CharSprite.make가 null을 돌려주므로 아래 그레이박스가 그려진다.
var _sprite: AnimatedSprite2D = null

func _ready() -> void:
	_sprite = CharSprite.make("res://assets/characters/ken.png")
	if _sprite != null:
		add_child(_sprite)

# ★[S2-T7] 보간 걷기 시각 오프셋(ResidentWalk가 채운다 — resident_walk.gd). 논리 위치(position)는
# 스테이션 칸으로 즉시 스냅하고(말 걸기 판정·헤드리스 테스트가 보는 값 불변), *그림만* 이만큼 뒤로
# 밀어 길 스포크를 따라 걸어온 것처럼 보이게 한다. 주민 프레임워크 공통 규약이라 새 캐릭터 파일도
# 이 블록을 그대로 복사한다(miho.gd·mochi.gd 동형).
var walk_offset := Vector2.ZERO

func set_walk_offset(v: Vector2) -> void:
	if walk_offset == v:
		return
	walk_offset = v
	if _sprite != null:
		_sprite.position = v   # 도색 스프라이트는 자식 노드 → 자식 위치로 민다
	queue_redraw()             # 그레이박스는 _draw의 draw_set_transform으로 민다

# 그레이박스 팔레트 — **언데드 창백**(푸른 기 도는 회백). [residents.md] "유니버설 프랑켄슈타인
# (녹색·볼트·납작머리) 금지"라 초록을 안 쓰고, 대신 **넓은 어깨 + 긴 팔 + 큰 키**의 실루엣으로
# 다른 그레이박스(사람형 16×32)와 한눈에 갈린다.
const _SKIN := Color(0.60, 0.65, 0.70)        # 창백한 회청 몸
const _SKIN_LIT := Color(0.72, 0.77, 0.81)    # NW 광원(asset-ruleset §NW) — 좌상단이 밝다
const _DARK := Color(0.16, 0.18, 0.22)        # 처진 눈매
const _SCAR := Color(0.44, 0.38, 0.42)        # 흉터(살짝 — "흉터 살짝" residents.md)

func _draw() -> void:
	draw_set_transform(walk_offset)   # ★[S2-T7] 보간 걷기: 그레이박스 그림 전체를 오프셋만큼 민다
	if _sprite != null:
		return  # 도색 스프라이트가 있으면 그레이박스는 안 그린다(폴백 전용)
	var w := BODY_SIZE.x
	var h := BODY_SIZE.y
	# 몸통 — 발치 원점 기준 위로(다른 주민과 같은 접지선 규약).
	draw_rect(Rect2(-w * 0.5, -h, w, h), _SKIN)
	# 어깨 — 몸통보다 좌우로 2px씩 더 넓다. 거인의 실루엣은 키보다 **어깨 폭**이 먼저 읽힌다.
	draw_rect(Rect2(-w * 0.5 - 2.0, -h + 14.0, w + 4.0, 9.0), _SKIN_LIT)
	# 팔 — 어깨 밖으로 내려오는 긴 두 줄(손이 무릎께까지 온다 = 큰 손의 암시).
	draw_rect(Rect2(-w * 0.5 - 3.0, -h + 15.0, 3.0, 22.0), _SKIN)
	draw_rect(Rect2(w * 0.5, -h + 15.0, 3.0, 22.0), _SKIN)
	# 머리 — 몸통보다 좁게(납작머리 금지: 세로가 가로보다 짧지 않게 잡는다).
	draw_rect(Rect2(-7.0, -h, 14.0, 14.0), _SKIN_LIT)
	# 처진 눈매 — 바깥쪽 눈꼬리가 한 픽셀 내려간다(순한 인상의 최소 신호).
	draw_rect(Rect2(-5.0, -h + 6.0, 3.0, 2.0), _DARK)
	draw_rect(Rect2(2.0, -h + 7.0, 3.0, 2.0), _DARK)
	# 흉터 — 왼쪽 이마에서 볼로 내려오는 계단 두 칸(살짝).
	draw_rect(Rect2(-6.0, -h + 3.0, 1.0, 3.0), _SCAR)
	draw_rect(Rect2(-5.0, -h + 6.0, 1.0, 3.0), _SCAR)
