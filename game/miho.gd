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
#
# ── ★[S9-T4 / ADR-0067 결정 1·4·5·6·7·11·12] 미호 아크 본문 ────────────────────
# S8이 깔아 둔 placeholder 골격(관문 발화·고백·이혼·생일)에 **미호의 말**을 붓는 태스크다.
# 이 파일이 미호에 관한 서사 텍스트 전량을 소유한다 — main은 "언제 부르는가"만 알고
# "무엇을 말하는가"는 한 줄도 모른다(ADR-0005). 훅 목록(전부 main의 has_method 이음매):
#
#   · lines(hearts, first_today)      — 일상 대사 **4단**(♡0 / ♡1+ / ♡3+ / ♡5+ 연인)
#   · spouse_lines(day, first_today)  — 배우자 전용 **8축**(결혼 후 lines를 대신한다)
#   · heart_gate_lines(target)        — ♡1~4 단계 관문 발화(속죄 아크 본문)
#   · heart_gate_cutscene(target)     — ♡1~4 관문 컷신 스텝(연출 등급 2 · 4동사 한정)
#   · heart_gate_letter(target)       — 관문 여진 편지 id(mailbox 테이블 행 — 다음 아침 도착)
#   · season_question(season)         — 절기 물음 1개(질문·선택지·반응 — **답은 전부 0점**)
#   · confession_lines(accepted)      — 의지 시험(♡5 고백) 수락/거절
#   · divorce_lines()                 — 이혼 작별(첫 줄이 토스트에 선다)
#   · birthday_lines()                — 생일 당일 플레이버
#
# ★ **봉인 법칙**(ADR-0016·ADR-0067 결정 8 체크리스트)이 이 파일의 가장 센 제약이다.
#   미호는 **자기가 본 것과 자기가 한 일만** 말한다. 옥자의 마음에 대해서도 *목격 증언*까지이고,
#   "그러니까 네 죄는 ○○다"라는 **중심 평결은 어떤 줄도 말하지 않는다** — 잇는 것은 플레이어
#   몫이다(타인의 말로 봉인이 풀리면 속죄가 성립하지 않는다, CONTEXT 불변). ♡4 완전체 조각도
#   증언의 온도를 최대로 올릴 뿐 평결로 넘어가지 않는다.
# ★ **선택지는 전부 0점**(결정 4). 절기 물음의 어떤 답도 호감도를 건드리지 않는다 — 이 파일에
#   Affinity 참조가 한 줄도 없는 것이 그 계약의 구현이다(반응 한 줄만 돌려준다).

const BODY_SIZE := Vector2(16, 32)  # NPC 자리 규격(ADR-0003, 플레이어와 동일)

# 하트 0(온보딩): 밝고 해맑은 농사 멘토 + "파괴의 불 → 양육의 불" 속죄 소개.
# PackedStringArray() 생성자는 상수식이 아니라 const로 못 두므로, 상수식인 배열
# 리터럴로 두고 lines()에서 PackedStringArray로 변환해 넘긴다.
const LINES_INTRO := [
	"[smile]어, 새 식구다! 반가워~ 난 미호, 이 땅 담당이야.",
	"[talk]보다시피 오래 버려져 거칠어졌지? 잡초랑 돌, 고목부터 치워서 땅을 깨우자.",
	"[smile]치운 자리를 [좌클릭]으로 갈고 씨 심고 물 주면 돼. 돌볼수록 밭이 넓어진단다!",
	"[smile]내 여우불… 옛날엔 막 태워먹었는데, 여기선 작물 키우는 데 쓴단다. 신기하지!",
	"[talk]다 자란 건 카페 출하함에 넣어 냥을 벌고, 그 돈으로 또 씨앗을 사면 돼.",
	"[talk]아, 절기마다 심을 수 있는 게 달라. 철 지난 씨는 땅이 안 받아 주더라고.",
	"[talk]물은 아침에 주는 게 제일 좋아. 낮에 주면 반은 하늘이 가져가.",
	"[smile]힘들면 쉬어. 여긴 하루 더 산다고 뭐라 할 사람 없거든. 어차피 다들 죽었잖아!",
	"[talk]저기 카페 보이지? 저기 사장이 옥자야. 무섭게 생겼는데 안 무서워. …좀 무섭나?",
	"[talk]혹시 배고프면 카페 가 봐. 멜이 뭐라도 챙겨 줄 거야.",
	"[smile]첫날부터 다 하려고 하지 마. 밭은 도망 안 가.",
	"[smile]모르는 거 있음 언제든 불러. 난 늘 여기 있을게~",
]

# 하트 1~2(친해지는 중): 속죄 서사 한 토막 해금 — 방화의 과거를 살짝 연다.
const LINES_WARMING := [
	"[smile]또 왔구나! 네가 오면 이 밭이 좀 더 환해지는 것 같아.",
	"[sad]있잖아… 난 살아서 불을 너무 사랑했어. 태우는 불 말이야.",
	"[shy]여기선 그 불로 싹을 틔워. 망치던 힘을, 살리는 데 쓰는 거지. 이상하지?",
	"[talk]오늘 이랑 끝줄이 좀 말랐더라. 물 한 번 더 주고 가.",
	"[smile]싹이 흙을 밀고 올라올 때 소리가 나. 진짜야, 아주 작게.",
	"[talk]나 여기 오기 전엔 뭘 기다려 본 적이 없었어. 불은 기다릴 게 없잖아. 바로 되니까.",
	"[smile]근데 씨앗은 기다려야 하더라고. 그거 배우는 데 꽤 걸렸어.",
	"[talk]잡초 보이면 바로 뽑아. 하루 두면 두 배가 되더라니까, 진짜로.",
	"[smile]손톱 밑에 흙 낀 거 봐. 나 이거 좀 좋아해.",
	"[talk]나 여기 온 지 얼마나 됐는지 몰라. 세다가 관뒀어. 세면 슬퍼져서.",
	"[smile]근데 요즘은 다시 세고 있어. 네가 온 날부터.",
	"[shy]…아 뭐, 밭 기록 때문에 그런 거야. 작물 주기 재려고.",
	"[talk]비 오는 날엔 물 주지 마. 하늘이 대신 해 주는 걸 왜 또 해.",
	"[smile]나 여기 오고 처음 심은 게 호박이었어. 그때 진짜 열심히 봤다니까.",
]

# 하트 3+(가까운 사이): 더 깊은 속죄 토막 + 여우불 강화(T3.4) 떡밥.
const LINES_CLOSE := [
	"[shy]너랑 이렇게 얘기하는 시간이 좋아. 진짜로.",
	"[smile]내 여우불, 이젠 제법 말을 들어. 네 밭이라면 더 잘 자라게 해줄 수 있을 것 같아.",
	"[smile]속죄가 별건가… 어제보다 한 포기 더 살리면 되는 거지. 네 덕분에 그걸 배워.",
	"[talk]꼬리가 아홉이면 뭘 해. 손이 두 개인 건 너랑 똑같은데.",
	"[sad]가끔 밤에 불이 저 혼자 커질 때가 있어. 그럼 밭에 나와서 앉아 있어. 흙 냄새가 그걸 재워 주거든.",
	"[smile]너 오늘 얼굴이 좀 폈다. 밭이 잘돼서 그런가?",
	"[talk]옥자는 요즘도 늦게까지 카페에 있더라. 그 친구는 쉬는 법을 몰라.",
	"[shy]…아니 뭐, 그냥 그렇다고.",
	"[talk]멜이 그러는데 네 출하량이 늘었대. 장부 얘기 하면서 좀 웃더라.",
	"[smile]바나는 밤에만 말이 많아져. 낮엔 거의 안 하잖아, 그 친구.",
	"[sad]나 사실 아직도 내 손이 무서워. 근데 네 밭에 대면 안 무서워.",
	"[talk]죽은 다음에 배운 게 산 동안 배운 것보다 많아. 좀 억울하지?",
	"[smile]그래도 억울한 것보단 배우는 게 낫지. 안 그래?",
	"[talk]너 말 안 해도 알아. 여우는 냄새로 기분도 맡거든.",
	"[shy]…거짓말이야. 그냥 얼굴 보면 보여.",
]

# ★[S9-T4] 하트 5(연인): lines()의 넷째 단. ♡5는 의지 시험(고백)을 통과해야만 닿는 칸이라,
#   이 묶음이 서면 그 사람은 이미 미호의 연인이다 — main이 연애 상태를 따로 안 넘겨도 되는 이유다.
const LINES_LOVER := [
	"[shy]…어. 왔네. (조금 웃는다)",
	"[smile]너 오는 소리는 이제 발소리만 들어도 알아. 여우 귀 무시하지 마.",
	"[shy]손 봐. 흙 다 묻었잖아. …그래도 따뜻하다.",
	"[smile]나 요즘 불이 안 커져. 밤에도. 왜 그런지 알 것 같아서 좀 부끄러워.",
	"[talk]우리 언젠가 저 끝 이랑까지 다 채우자. 둘이면 금방일걸.",
	"[shy]…있잖아. 나 죽은 다음에 이런 게 있을 줄은 몰랐어.",
	"[smile]오늘은 일 좀 적당히 해. 내가 옆에 있을 테니까.",
	"[shy]꼬리 세는 거 그만해. 셀 때마다 간지럽단 말이야.",
	"[talk]옥자가 우리 보고 아무 말도 안 해. 그게 걔 방식의 축하야, 아마.",
	"[smile]밤에 밭에 나와 봐. 여우불 켜 놓을게. 별처럼 보인다니까.",
	"[sad]가끔 무서워. 이런 게 오래 갈 수 있나 싶어서.",
	"[smile]…그래도 오늘은 있잖아. 오늘은 확실하잖아.",
	"[talk]오늘 뭐 먹고 싶어? 내가 할게. 태우지도 않을게.",
	"[shy]자꾸 웃지 마. 나까지 웃잖아.",
]

# 오늘 이미 일일 대화를 한 뒤 또 말 걸었을 때(점수 없음 — 대사만 가볍게 바뀐다).
const LINE_AGAIN := "[smile]오늘은 아까 봤잖아~ 그래도 얼굴 보니 좋네."
# 연인·배우자에게는 같은 자리에 다른 온도의 한 줄이 선다(같은 규칙, 다른 목소리).
const LINE_AGAIN_LOVER := "[shy]또 왔어? …싫다는 거 아니야. 진짜 아니야."

# ── ★[S9-T4 / ADR-0067 결정 12] 배우자 대사 8축 ──────────────────────────────
# 결혼 후에는 이 묶음이 lines()를 **대신한다**(main이 spouse_id로 갈라 부른다). 축이 여덟인
# 이유는 "매일 다른 말"을 만들려는 게 아니라 **한 주 반을 겹치지 않고 도는 최소 주기**이기
# 때문이다 — 축을 날(day)에서 파생하므로 상태가 0이고, 세이브 키도 늘지 않는다.
#
# 여덟 축: ① 아침·집 ② 밭일 ③ 옛 불 ④ 옥자·카페 ⑤ 절기·날씨 ⑥ 장난 ⑦ 애정 ⑧ 미래.
# ★ 배우자 대사에도 봉인 법칙이 그대로 걸린다 — 결혼했다고 미호가 아는 것이 늘지 않는다.
const SPOUSE_AXES := [
	# ① 아침·집
	[
		"[smile]잘 잤어? 나 아까부터 깨서 네 자는 거 봤어. 안 무섭지?",
		"[talk]아궁이 불은 내가 봤어. 그건 내가 제일 잘하는 거니까.",
		"[talk]밥은 차려 놨는데 맛은 장담 못 해. 나 불 조절만 잘하지 간은 못 봐.",
		"[shy]우리 집에서 나는 냄새가 좋아. 탄 냄새가 아니라 밥 냄새라서.",
		"[smile]이불 개는 건 네 담당이야. 어제 그렇게 정했잖아.",
	],
	# ② 밭일
	[
		"[smile]오늘 나 서쪽 이랑 맡을게. 너 동쪽 해.",
		"[talk]호미 날 나갔더라. 만물상 가면 하나 사 와. 내 돈으로 사도 되는데 네가 골라야 손에 붙어.",
		"[talk]씨앗 통 정리해 뒀어. 절기 지난 건 따로 뺐고.",
		"[smile]둘이 하니까 반나절이 남네. 남는 반나절은 뭐 하지?",
		"[shy]같이 일하는 게 이렇게 좋은 건지 몰랐어. 혼자 할 땐 그냥 일이었는데.",
	],
	# ③ 옛 불
	[
		"[sad]가끔 아직도 손끝이 뜨거워질 때가 있어. 그럼 네 손 잡아. 금방 식어.",
		"[talk]무섭진 않아. 이젠 어디로 갈지 아니까.",
		"[sad]어젯밤에 꿈에서 그 밭을 또 봤어. 근데 이번엔 안 타더라.",
		"[shy]너한텐 한 번도 안 옮겨붙었지? …그거 매일 확인해. 미안.",
		"[smile]괜찮아. 진짜 괜찮아. 확인하는 게 습관이 된 거지 겁먹은 건 아니야.",
	],
	# ④ 옥자·카페
	[
		"[talk]옥자가 오늘도 늦게까지 있대. 그 친구는 문 닫는 법을 몰라.",
		"[smile]내가 결혼했다니까 옥자가 딱 한 마디 하고 말더라. \"잘됐네.\" 그게 걔한텐 긴 문장이야.",
		"[talk]카페 나갈 때 네 몫 하나 챙겨 놨어. 식기 전에 와.",
		"[talk]멜이 우리 얘기로 장부에 낙서를 해 놨더라. 옥자한테 걸려서 혼났어.",
		"[smile]바나가 축의금 대신 나락 광석을 줬어. 그 친구답지?",
	],
	# ⑤ 절기·날씨
	[
		"[talk]바람 냄새가 바뀌었어. 절기 넘어가려나 봐.",
		"[smile]비 오는 날은 물 안 줘도 되니까 좋아. 게으를 핑계가 하늘에서 오잖아.",
		"[talk]밤에 서리 내릴 것 같아. 어린 싹은 덮어 두고 자자.",
		"[talk]오늘 하늘 좀 봐. 저승 하늘도 가끔은 곱더라.",
		"[shy]절기가 도는 게 좋아. 도는 건 다시 온다는 뜻이잖아.",
	],
	# ⑥ 장난
	[
		"[smile]꼬리 몇 개까지 셌어? 아직 다 안 보여줬는데.",
		"[shy]야, 귀 만지지 마. …한 번만.",
		"[smile]오늘은 내가 먼저 잘 거야. 자리 뺏기면 마루에서 자는 거다?",
		"[smile]내기할래? 오늘 누가 더 많이 거두나. 진 사람이 물 다 주기.",
		"[shy](여우불로 네 이름을 허공에 쓰다 말고 얼른 껐다)",
	],
	# ⑦ 애정
	[
		"[shy]나 아직도 네가 옆에 있는 게 안 익숙해. 좋은 쪽으로.",
		"[smile]불 말고 다른 걸로 뜨거워질 수 있다는 거, 너 만나고 알았어.",
		"[shy]…사랑한다는 말은 아직 하루에 한 번만 할래. 아끼는 거야.",
		"[talk]오늘 좀 지쳐 보인다. 이리 와. 잠깐만 이러고 있자.",
		"[smile]네가 나 부를 때 그 목소리 있잖아. 그거 하루 종일 생각나.",
	],
	# ⑧ 미래
	[
		"[talk]저 끝 묵정밭 말이야. 내년엔 저기까지 가 보자.",
		"[smile]우리 나무 한 그루 심자. 오래 걸리는 걸 하나쯤 같이 갖고 싶어.",
		"[talk]영원히 일한다는 계약, 너랑 같이면 그렇게 나쁘지도 않네.",
		"[shy]언젠가 네 이야기도 다 듣고 싶어. 급한 건 아니고. 나 기다리는 거 배웠잖아.",
		"[smile]우린 시간 많잖아. 그건 저승의 몇 안 되는 장점이지.",
	],
]

# 배우자에게 오늘 두 번째 이후로 말 걸었을 때.
const LINE_AGAIN_SPOUSE := "[smile]바쁘신가 봐~ 그래도 지나갈 때마다 얼굴 보여 줘."

# ── ★[S9-T4 / ADR-0067 결정 5·11] 단계 관문 발화(♡1~4 속죄 아크) ─────────────
# miho-heart-arc.md의 `[P]` 골격이 여기서 본문이 된다. 골격이 정한 온도를 그대로 지킨다:
#   ♡1 = 능력(속죄의 밝은 표면 — 죄는 아직 안 비침)
#   ♡2 = 사고 암시(디테일 0 · 말 돌림)
#   ♡3 = 첫 고백(악의가 아니라 못 다뤄서) + **옥자 감정 씨앗 한 톨**
#   ♡4 = 감정의 조각 완전체(B1) — 미호가 *본 것*의 증언. 평결은 없다.
const GATE_HEART_1 := [
	"[smile]잠깐만. 이거 보여 주고 싶었어.",
	"[talk](미호가 손바닥을 펴자 파란 불꽃이 조용히 올라온다)",
	"[smile]봐. 안 뜨겁지? 손 대 봐도 돼.",
	"[smile]불은 태우기만 하는 게 아니야 — 봐, 이렇게 *키울* 수도 있어!",
	"[talk](불꽃이 어린 싹 위로 내려앉자 잎이 한 뼘 펴진다)",
	"[smile]여우불 점화, 성공! 하루 한 번은 이렇게 밀어 줄 수 있어.",
	"[shy]…이거 아무한테나 보여 주는 거 아니야. 그러니까, 뭐.",
	"[talk]불이 싹을 안 태우는 이유? 나도 몰라. 태우려는 마음이 없으면 안 태우더라고.",
	"[smile]앞으로도 밭에서 보자!",
]

const GATE_HEART_2 := [
	"[talk]오늘 불이 잘 붙더라. 네 밭이라 그런가.",
	"[smile]나 이 정도면 꽤 잘 다루지? 아홉 꼬리 값은 한다고 봐.",
	"[sad]…있잖아.",
	"[sad]나, 예전엔 불을 잘 못 다뤘거든.",
	"[talk](미호가 잠깐 말을 멈추고 손끝을 본다)",
	"[shy]아— 아니야. 별 얘기 아니야. 지난 얘기고.",
	"[talk]…언제 한 번은 할게. 오늘은 아니고.",
	"[smile]자, 물이나 주자! 서쪽 끝줄이 목말라 있더라.",
]

const GATE_HEART_3 := [
	"[talk]…오늘은 좀 앉아서 얘기해도 될까.",
	"[sad]저번에 하다 만 얘기. 내가 불을 못 다뤘다고 한 거.",
	"[sad]살아서, 내가 밭 하나를 태웠어. 호박밭이었어.",
	"[talk]무서운 게 있었고, 놀랐고, 그래서 불이 나갔어. 그게 다야.",
	"[sad]미워서 그런 게 아니었어. 그냥… 내 걸 내가 못 잡았어.",
	"[talk]사람들은 여우가 홀렸다고 했어. 나는 홀린 적 없어. 못 다룬 거지.",
	"[shy]그래서 나한테는 영혼 호박이 좀 특별해. 내가 태운 자리에 다시 심는 기분이라서.",
	"[smile]…이 얘기 처음 해. 너한테.",
	"[talk]무겁게 듣지는 마. 나 이제 그 얘기 하면서도 손이 안 떨려.",
	"[talk]아, 그리고. 옥자 말인데.",
	"[sad]그 친구, 요즘 밤에 우는 것 같아.",
	"[shy]…아냐, 됐다. 내가 할 말은 아니지.",
	"[smile]가자. 해 지겠다.",
]

# ★ ♡4 = **감정의 조각(B1) 완전체**. 봉인 법칙 최고 난도 구간이라 규칙을 다시 적어 둔다:
#   미호는 **목격한 것**(옥자가 무엇을 하고 있었는가·어떤 얼굴이었는가)만 말한다. "그것이
#   무엇을 뜻하는가"·"그러므로 너는 무엇을 했는가"는 **한 줄도 쓰지 않는다** — 그 자리를
#   비워 두는 것이 이 조각의 설계다(플레이어가 스스로 잇는 여지 = ADR-0016).
const GATE_HEART_4 := [
	"[sad]…오늘은 웃으면서 말 못 하겠다. 미안.",
	"[talk]어제 카페 문 닫고 옥자가 안 나오길래 들어가 봤거든.",
	"[sad]장부를 보고 있는 줄 알았는데, 네 출하 영수증 뭉치였어.",
	"[talk]한 장씩 넘기면서 울고 있었어. 소리도 안 내고.",
	"[sad]나 그 얼굴 알아. 살아 있을 때 딱 한 번 봤거든. 같은 얼굴이었어.",
	"[talk]내가 뭐라고 물어봤는데, 옥자가 그러더라. \"괜찮아. 늦은 것도 아니야.\"",
	"[sad]근데 나한테 한 말이 아니었어. 나 안 보고 있었거든.",
	"[shy]…나는 마음을 읽는 재주밖에 없어. 그게 무슨 뜻인지는 나도 몰라.",
	"[sad]그냥… 너는 알 것 같아서. 그래서 얘기해.",
	"[talk](미호가 소매로 얼굴을 문지르고 억지로 웃는다)",
	"[shy]미안. 이런 얘기 하려고 부른 건 아니었는데.",
	"[smile]자, 이제 진짜 밭 얘기만 할 거야. 오늘 물 안 줬지!",
]

# ── ★[S9-T4 / ADR-0067 결정 2] 관문 컷신 스텝(연출 등급 2 — 4동사 한정) ───────
# cutscene.gd 포맷 그대로다. **다섯 번째 동사는 없다**(npc/cam/fade/clock).
#
# ★ 좌표 규약: NPC 스텝의 tile은 **안식 농원 밭 좌표계**다(미호의 아침 스테이션
#   MIHO_FIELD_TILE (42,14) 언저리 = 스타터 패치 (40,12,5,5) 안). 컷신 러너는 구역을 모르고
#   훅에도 구역 인자가 없으므로, 미호가 카페 자리에 있을 때 관문이 열리면 그림이 순간
#   이동한다 — 그래서 **NPC 스텝이 있는 컷신은 반드시 암전 뒤에서만 움직인다**(페이드가 이동을
#   덮는다). 재생이 끝나면 main이 원 위치를 복원한다(_end_cutscene). 구역 인지 훅은 잠정 미도입
#   (owner 큐 — S9b 연출 작업에서 재평가).
# ★ 길이는 짧게 잡는다(관문당 1.5~2.5초). 관문 발화가 본체이고 컷신은 그 앞의 숨 고르기다.
const CUTSCENE_HEART_1 := [
	{"verb": "clock", "running": false},
	{"verb": "fade", "to": 1.0, "secs": 0.35},
	{"verb": "npc", "id": "miho", "tile": Vector2i(43, 17)},   # 암전 뒤에서 자리 잡기
	{"verb": "fade", "to": 0.0, "secs": 0.35},
	{"verb": "npc", "id": "miho", "tile": Vector2i(42, 15), "secs": 0.9},   # 밭을 가로질러 온다
	{"verb": "cam", "offset": Vector2(0, -20), "secs": 0.5},
	{"verb": "cam", "offset": Vector2(0, 0), "secs": 0.3},
	{"verb": "clock", "running": true},
]

const CUTSCENE_HEART_2 := [
	{"verb": "clock", "running": false},
	{"verb": "cam", "offset": Vector2(0, -12), "secs": 0.6},   # 살짝 당겨 붙는 시선
	{"verb": "fade", "to": 0.35, "secs": 0.5},                 # 말이 끊기는 자리의 그늘
	{"verb": "fade", "to": 0.0, "secs": 0.5},
	{"verb": "cam", "offset": Vector2(0, 0), "secs": 0.4},
	{"verb": "clock", "running": true},
]

const CUTSCENE_HEART_3 := [
	{"verb": "clock", "running": false},
	{"verb": "fade", "to": 1.0, "secs": 0.5},
	{"verb": "npc", "id": "miho", "tile": Vector2i(41, 16)},   # 밭머리에 나란히 앉는 자리
	{"verb": "fade", "to": 0.0, "secs": 0.6},
	{"verb": "cam", "offset": Vector2(0, -16), "secs": 0.6},
	{"verb": "cam", "offset": Vector2(0, 0), "secs": 0.4},
	{"verb": "clock", "running": true},
]

const CUTSCENE_HEART_4 := [
	{"verb": "clock", "running": false},
	{"verb": "fade", "to": 1.0, "secs": 0.7},                  # 가장 긴 암전 = 가장 무거운 비트
	{"verb": "npc", "id": "miho", "tile": Vector2i(42, 16)},
	{"verb": "cam", "offset": Vector2(0, -24)},
	{"verb": "fade", "to": 0.0, "secs": 0.9},
	{"verb": "cam", "offset": Vector2(0, 0), "secs": 0.6},
	{"verb": "clock", "running": true},
]

# ── ★[S9-T4 / ADR-0067 결정 7] 관문 여진 편지 ────────────────────────────────
# 관문이 성사된 **그날 밤** 큐에 들어가 **다음 날 아침** 우편함에 꽂힌다(mailbox.gd의 큐 규약).
# 본문은 mailbox.gd LETTERS 테이블 행이 들고, 이 파일은 **어느 칸이 어느 편지를 부르는가**만
# 안다 — 편지도 미호의 말이지만 그릇(테이블)은 프레임워크 것이라 매핑만 캐릭터가 진다.
# 중복 발송 방어는 mailbox.send가 이미 진다(같은 id는 두 번 안 온다 — 재구애에도 안전).
const GATE_LETTERS := {
	1: "miho_gate1_seed",
	2: "miho_gate2_sorry",
	3: "miho_gate3_pumpkin",
	4: "miho_gate4_okja",
}

# ── ★[S9-T4 / ADR-0067 결정 6] 절기 물음 ─────────────────────────────────────
# 주 첫날의 첫 대화에 미호가 **묻는다**. 절기당 하나(피안절·유화절·망연절·성야절).
#
# ★ **답은 전부 0점이다**(결정 4). 반응은 인-픽션 한 줄이고, 어떤 선택도 호감도·플래그·
#   아이템을 건드리지 않는다. "말 걸어 점수 버는 주간 루틴"이 되는 순간 대사가 자원이 되고
#   일일 대화 채널과 위상이 겹친다 — 그래서 이 테이블에는 점수 칸 자체가 없다.
# ★ 형식: {"line": 질문 한 줄, "options": 선택지(2~4지 — DialogueBox 상한), "replies": 반응}.
#   options와 replies는 같은 길이다(index가 곧 짝). main은 이 dict를 읽어 선택지를 세우기만 한다.
const SEASON_QUESTIONS := [
	# 0 피안절(봄결) — 시작의 절기
	{
		"line": "[smile]올해 첫 씨앗 말이야. 넌 뭘 보고 골라?",
		"options": ["배부를 걸로", "예쁜 걸로", "아직 못 정했어"],
		"replies": [
			"[smile]맞아, 그게 정답이지. 배부른 게 최고야.",
			"[shy]…나도 그래. 밭이 예쁘면 하루가 길어도 안 힘들거든.",
			"[talk]괜찮아. 땅도 아직 안 정했을걸. 같이 걸으면서 정하자.",
		],
	},
	# 1 유화절(여름결) — 해가 긴 절기
	{
		"line": "[talk]해가 길어졌지? 남는 시간엔 넌 뭘 해?",
		"options": ["밭에 더 있어", "물가에 앉아 있어", "그냥 자"],
		"replies": [
			"[smile]역시. 우린 좀 닮았다니까.",
			"[talk]좋다 그거. 물소리 들으면 불이 조용해지더라.",
			"[smile]잘한다! 여름엔 자는 것도 일이야.",
		],
	},
	# 2 망연절(가을결) — 거두는 절기
	{
		"line": "[talk]거두는 거랑 심는 거, 둘 중에 하나만 하라면 넌 뭐 할래?",
		"options": ["거두는 거", "심는 거", "둘 다 못 고르겠어"],
		"replies": [
			"[smile]솔직해서 좋아. 손에 쥐어지는 게 있어야 힘이 나지.",
			"[shy]…나도 심는 쪽. 태운 사람은 심는 걸 더 좋아하게 되나 봐.",
			"[talk]그럼 둘 다 해. 어차피 밭은 그렇게 돌아가.",
		],
	},
	# 3 성야절(겨울결) — 땅이 자는 절기
	{
		"line": "[sad]땅이 자는 절기야. …넌 겨울이 무섭진 않아?",
		"options": ["좀 무서워", "쉬어서 좋아", "겨울도 봄이야"],
		"replies": [
			"[talk]응. 나도 그래. 그래도 봄이 온다는 건 알잖아. 그거면 돼.",
			"[smile]잘한다. 쉬는 것도 돌보는 거야.",
			"[shy]…너 가끔 무서운 말 해. 좋은 쪽으로.",
		],
	},
]

# ── ★[S9-T4] 의지 시험(♡5 고백)·이혼·생일 ────────────────────────────────────
# 수락: ADR-0014 "해방-결혼"의 입구다. 미호에게 연애는 *속죄가 끝났다는 증서*가 아니라
#       *속죄를 계속할 이유*라는 결로 쓴다(속죄 완료 선언 금지 — 아크는 결혼 후에도 이어진다).
const CONFESSION_ACCEPT := [
	"[surprised]…어.",
	"[shy](미호의 꼬리 끝이 한 번 크게 흔들린다)",
	"[shy]나도, 같은 마음이었어.",
	"[sad]근데 나 무서웠어. 나 같은 게 옆에 있어도 되나 싶어서.",
	"[smile]…그래도 좋아. 좋다고 할래.",
	"[talk]나 속죄 아직 안 끝났어. 그건 그거대로 계속할 거야.",
	"[smile]앞으로도 밭에서 보자. 아니— 밭 말고 다른 데서도.",
]

# 거절(슬롯 점유 = 이미 다른 사람이 있다). ADR-0022 결: 적대 없음·무벌칙. 미호는 화내지 않고
# 상대를 먼저 걱정한다 — 그 온도가 재시도(이혼 후 재구애)를 씁쓸하지 않게 남긴다.
const CONFESSION_REJECT := [
	"[surprised]…잠깐, 잠깐.",
	"[sad]마음은 기뻐. 진짜야. 근데 지금 네 곁엔 이미 다른 사람이 있잖아.",
	"[talk]나 그 사람 얼굴 알아. 매일 보는걸.",
	"[shy]…나중에 얘기하자. 그때도 내가 여기 있으면.",
	"[smile]아 뭐야, 표정이 그게 뭐야. 나 안 삐졌어. 진짜야.",
]

# 이혼 작별 — **첫 줄이 토스트로 나간다**(main._divorce_farewell_line). 그래서 첫 줄은 혼자
# 서도 완결되는 한 문장이어야 한다(뒷줄은 대화창 승격 시 S9b가 쓴다).
const DIVORCE_FAREWELL := [
	"[sad]원망 안 해. 태우고 간 것도 아닌데 뭘.",
	"[talk]밭은 계속 볼게. 그건 우리 일이 아니라 땅 일이니까.",
	"[shy]…가끔 얼굴은 보여 줘. 그 정도는 해도 되잖아.",
	"[smile]잘 지내. 물 주는 거 잊지 말고.",
]

const BIRTHDAY := [
	"[smile]오늘? 오늘 내 생일이야! 어떻게 알았어?",
	"[shy]죽고 나서도 생일을 세는 게 좀 웃기지. 근데 세면 하루가 특별해지더라고.",
	"[smile]선물은… 뭐, 알아서 해. 나 안 까다로워. (꼬리가 매우 흔들린다)",
	"[talk]호박이면 더 좋고. 아니 강요는 아니고. 참고만 하라고.",
]

# 대화창에 띄울 이름.
func display_name() -> String:
	return "미호"

# 말 걸었을 때 들려줄 대사 줄들. hearts = 현재 하트 단계, first_today = 오늘 첫 대화인가.
#   - 오늘 두 번째 이후면 짧은 인사 한 줄(일일 보상은 이미 받음 → Affinity가 막음).
#   - 첫 대화면 하트 단계에 맞는 묶음을 들려준다(높을수록 속죄 서사가 더 열린다).
# ★[S9-T4 / ADR-0067 결정 5] **4단**으로 확장됐다: ♡0 낯섦 / ♡1+ 익숙 / ♡3+ 속을 보임 /
#   ♡5 연인. 계절·축제 변주는 범위 밖이다(그 텍스처는 절기 물음이 1/10 비용으로 낸다).
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

# ★[S9-T4] 배우자 전용 묶음(main이 spouse_id == "miho"일 때 lines() 대신 부른다).
# 축은 **day에서 파생**한다 — 어제 무슨 축이 나왔는지 기억하지 않으므로 상태·세이브 키가 0이다.
# 빈 배열을 돌려주면 main이 평소 lines()로 되돌아간다(이음매 하위호환).
func spouse_lines(day: int = 1, first_today: bool = true) -> PackedStringArray:
	if not first_today:
		return PackedStringArray([LINE_AGAIN_SPOUSE])
	if SPOUSE_AXES.is_empty():
		return PackedStringArray()
	var axis: int = abs(day) % SPOUSE_AXES.size()
	return PackedStringArray(SPOUSE_AXES[axis])

# ★[S9-T4] 단계 관문 발화(♡1~4). 범위 밖 칸은 빈 배열 = main의 placeholder 폴백.
func heart_gate_lines(target: int) -> PackedStringArray:
	match target:
		1: return PackedStringArray(GATE_HEART_1)
		2: return PackedStringArray(GATE_HEART_2)
		3: return PackedStringArray(GATE_HEART_3)
		4: return PackedStringArray(GATE_HEART_4)
	return PackedStringArray()

# ★[S9-T4] 관문 컷신 스텝(♡1~4). 빈 배열 = 컷신 없이 대화만(하위호환 경로 그대로).
func heart_gate_cutscene(target: int) -> Array:
	match target:
		1: return CUTSCENE_HEART_1.duplicate(true)
		2: return CUTSCENE_HEART_2.duplicate(true)
		3: return CUTSCENE_HEART_3.duplicate(true)
		4: return CUTSCENE_HEART_4.duplicate(true)
	return []

# ★[S9-T4] 관문 여진 편지 id("" = 이 칸엔 편지 없음). 발송·중복 방어는 mailbox가 진다.
func heart_gate_letter(target: int) -> String:
	return String(GATE_LETTERS.get(target, ""))

# ★[S9-T4] 절기 물음(season = GameClock의 절기 인덱스 0..3). 빈 dict = 이 절기엔 물음 없음.
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

# ★[S9-T4] 의지 시험 결과 발화(accepted = 슬롯이 비어 수락됐는가).
func confession_lines(accepted: bool) -> PackedStringArray:
	return PackedStringArray(CONFESSION_ACCEPT if accepted else CONFESSION_REJECT)

# ★[S9-T4] 이혼 작별. main은 **첫 줄만** 토스트에 쓴다(결정 9 — 대화창 승격은 S9b).
func divorce_lines() -> PackedStringArray:
	return PackedStringArray(DIVORCE_FAREWELL)

# ★[S9-T4] 생일 당일 플레이버(평소 묶음 앞에 선다).
func birthday_lines() -> PackedStringArray:
	return PackedStringArray(BIRTHDAY)

# P2.3② P2.1 도색 스프라이트(있으면 그레이박스 대신). 상주 NPC라 남쪽(down) 첫 프레임 정지.
var _sprite: AnimatedSprite2D = null

func _ready() -> void:
	_sprite = CharSprite.make("res://assets/characters/miho_walk.png")
	if _sprite != null:
		add_child(_sprite)

# ★ [S2-T7] 보간 걷기 시각 오프셋(ResidentWalk가 채운다 — resident_walk.gd). 논리 위치(position)는
# 스테이션 칸으로 즉시 스냅하고(말 걸기 판정·농사 제외·헤드리스 테스트가 보는 값 불변), *그림만*
# 이만큼 뒤로 밀어 길 스포크를 따라 걸어온 것처럼 보이게 한다. 도착하면 0으로 수렴한다.
# 주민 프레임워크 공통 규약이라 새 주민 캐릭터 파일도 이 블록을 그대로 복사한다.
var walk_offset := Vector2.ZERO

func set_walk_offset(v: Vector2) -> void:
	if walk_offset == v:
		return
	walk_offset = v
	if _sprite != null:
		_sprite.position = v   # 도색 스프라이트는 자식 노드 → 자식 위치로 민다
	queue_redraw()             # 그레이박스는 _draw의 draw_set_transform으로 민다

# M2.4 — 카페 이벤트 데이엔 축제 의상으로 바뀐다(금빛 틴트 + 머리 고깔). main이 day에서
# 파생해 토글하고(Festival.is_event_day), 멱등이라 매번 불러도 안전하다. festive 출처는 main —
# 캐릭터는 "어떻게 차려입나"만 안다(ADR-0005 결: 비주얼도 캐릭터가 자기 몸으로 든다).
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
	# 몸체: 발치 원점 기준 위로 16×32. 플레이어보다 따뜻한 톤으로 한눈에 구분.
	var body := Rect2(-BODY_SIZE.x * 0.5, -BODY_SIZE.y, BODY_SIZE.x, BODY_SIZE.y)
	draw_rect(body, Color(0.80, 0.72, 0.52))
	# 머리 약간 밝게(그레이박스 시인성)
	draw_rect(Rect2(body.position, Vector2(BODY_SIZE.x, 10)), Color(0.90, 0.82, 0.60))
	# 여우귀 암시: 머리 위 양옆 작은 뿔 두 개
	var top := -BODY_SIZE.y
	draw_rect(Rect2(-6, top - 3, 3, 3), Color(0.90, 0.82, 0.60))
	draw_rect(Rect2(3, top - 3, 3, 3), Color(0.90, 0.82, 0.60))
