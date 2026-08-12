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
#     (ADR-0004: 도박·사채로 사람을 망침 → 돈·물자가 건강히 도는 카페를 굴림)를 대사가
#     관통한다 — 멜의 모든 애정 표현이 *계산·정산·단가*의 문법으로 나오는 것이 그 결이다.
#
# ── ★[S9-T5 / ADR-0067 결정 1·4·5·6·7·11·12] 멜 아크 본문 ────────────────────
# S8이 깔아 둔 placeholder 골격(관문 발화·고백·이혼·생일)에 **멜의 말**을 붓는 태스크다.
# miho.gd(S9-T4)와 **정확히 같은 훅 세트**를 가지되 목소리와 각도가 다르다 — 미호가 감정을
# 읽어 전하는 사람이면, 멜은 **기록을 읽어 내미는 사람**이다(바이블 §5.1 멜 = 사실의 조각).
# 훅 목록(전부 main의 has_method 이음매 — main은 "언제 부르는가"만 알고 내용을 모른다):
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
# ★ **봉인 법칙**(ADR-0016·ADR-0067 결정 8 체크리스트)이 이 파일의 가장 센 제약이고, 멜은
#   세 조각 중 **가장 위험한 화자**다 — 손에 문서를 들고 있기 때문이다. 그래서 규칙을 한 단계
#   더 조인다: 멜은 **장부에 적힌 것만** 말한다. 적혀 있지 않은 것(그 물건들이 그 다음에 어디로
#   갔는가 · 그것이 무슨 뜻인가 · 그러므로 네가 무엇을 했는가)은 **한 줄도 말하지 않는다**.
#   ♡4 완전체 조각(B2)도 사본을 내미는 데서 끝나고, 잇는 것은 플레이어 몫이다(타인의 말로
#   봉인이 풀리면 속죄가 성립하지 않는다, CONTEXT 불변).
# ★ **선택지는 전부 0점**(결정 4). 절기 물음의 어떤 답도 호감도를 건드리지 않는다 — 이 파일에
#   Affinity 참조가 한 줄도 없는 것이 그 계약의 구현이다(반응 한 줄만 돌려준다).

const BODY_SIZE := Vector2(16, 32)  # NPC 자리 규격(ADR-0003, 플레이어·미호·옥자와 동일)

# 하트 0(온보딩): 시크·건조한 강시 운영자 소개 + 역할(출하대·카페 운영) + 가벼운 속죄 암시.
# PackedStringArray() 생성자는 상수식이 아니라 const로 못 두므로, 상수식인 배열
# 리터럴로 두고 lines()에서 PackedStringArray로 변환해 넘긴다(miho.gd·okja.gd와 동일).
const LINES_INTRO := [
	"[talk]…새로 끌려온 식구로군. 난 멜. 이 카페 돈줄을 쥔 강시야.",
	"[talk]출하대가 내 담당이지. 밭에서 거둔 거, 여기로 가져오면 골드로 쳐준다.",
	"[talk]장사는 단순해. 들어온 재료로 손님 받고, 매출 올리고. 숫자는 거짓말을 안 하거든.",
	"[sad]…살아선 그 숫자로 사람 여럿 등쳐먹었어. 도박이며 사채며. 지금은 반대로 굴리는 중이고.",
	"[talk]필요한 게 있으면 카운터로 와. 친절은 기대 마라. 계산만큼은 정확히 해줄 테니까.",
	"[talk]첫 정산은 오늘 밤에 나와. 하루치는 자고 일어나면 지갑에 꽂혀 있을 거다.",
	"[talk]품질 등급 올려서 가져와. 같은 무게라도 값이 달라진다. 내가 봐주는 게 아니라 장부가 그래.",
	"[talk]사장은 옥자. 저 안쪽에 서 있는 사람 말이야. 말수 적다고 만만히 보지 마라, 여기 주인이야.",
	"[talk]미호는 밭, 바나는 밤, 나는 돈. 그게 이 집 분업이다.",
	"[sad]왜 죽었냐고는 안 묻네. …현명하군. 여기선 다들 그 얘기 하기 싫어해.",
	"[talk]가 봐. 밭 마르게 두지 말고. 마른 작물은 내 장부에서도 값이 마른다.",
]

# 하트 1~2(친해지는 중): 환대 속죄 한 토막 — 쥐어짜던 돈을, 돌게 두는 환대로 뒤집는다.
const LINES_WARMING := [
	"[talk]또 왔네. 단골은 손해 안 보게 해주는 게 내 신조야. …앉기나 해.",
	"[talk]장사하면서 알았어. 돈은 뜯어내는 게 아니라, 돌게 두는 거더라고.",
	"[smile]살아선 사람을 쥐어짰지. 여기선 반대야 — 따뜻한 거 한 잔 내주고, 또 오게 만드는 거.",
	"[shy]…환대. 그게 내 속죄법이야. 웃기지, 사채업자였던 내가 이런 소릴 하다니.",
	"[talk]오늘 매출 좀 봐라. 어제보다 낫지? 네 출하분이 들어와서 그래.",
	"[talk]나는 계산이 빨라. 살아서 유일하게 잘한 게 그거였으니까. 쓸모가 이제야 방향을 찾았지.",
	"[sad]강시는 심장이 안 뛰어. 그래서 흥분도 안 하고, 겁도 잘 안 나. 편한 몸이야.",
	"[talk]…편하다고 했지 좋다고는 안 했다.",
	"[talk]장부 정리할 때 말 걸어도 돼. 숫자는 안 도망가니까.",
	"[smile]네가 들어오면 손님들이 조금 더 앉아 있다 가더라. 그것도 매출이야. 계산해 뒀어.",
	"[talk]빚이란 게 웃겨. 갚아도 갚아도 남는 게 있어. 이자 말고, 얼굴이 남더라고.",
	"[talk]…무슨 소린지 모르겠으면 그냥 흘려.",
	"[talk]가끔 카운터 뒤에 서 봐. 여기서 보면 이 집이 어떻게 굴러가는지가 보인다.",
]

# 하트 3+(가까운 사이): ★바이블 §6.1 **♡3 = 씨앗** — "사장님 숨긴 장부가 있더라" 수준의
# 떡밥까지다. 봉인 칸의 *존재*만 알리고 내용은 열지 않는다(완전체 조각은 ♡4 관문 소관).
const LINES_CLOSE := [
	"[talk]너한텐 말해도 되겠다. 난 이 카페 장부를 통째로 쥐고 있거든.",
	"[talk]근데 그게 전부가 아니더라. 사장님이 따로 숨겨 둔 장부가 있어.",
	"[talk]금고 안쪽, 부적으로 봉해 놓은 칸. 장부 십수 년 만지면서 그런 건 처음 봤어.",
	"[shy]…궁금하냐. 나도 궁금해. 근데 남의 장부 여는 건 내가 끊은 짓이라서.",
	"[talk]네 계약서도 봤어. 다른 셋이랑 딱 한 군데가 달라 — '죄목' 칸.",
	"[surprised]거기만 새까맣게 봉인돼 있더라. 빈칸이 아니야. 채워 놓고 덮은 거지.",
	"[talk]옥자가 직접 봉했더군. 뭘 덮었는진 나도 몰라.",
	"[sad]대신 덮어 주는 사람 마음이 어떤 건진 알아. 나도 한 번 덮어 준 적 있거든. 부하 이름을.",
	"[talk]오늘 원가율 좀 봐라. 네 덕에 재료 회전이 빨라져서 마진이 붙었어.",
	"[smile]…칭찬이야. 내 입에서 이 정도 나오면 상당한 거다.",
	"[sad]도박 끊은 지 몇 년 됐는지 세 봤어. 죽고 나서부턴 안 세기로 했고.",
	"[talk]죽으면 끊긴다는 게 유일한 위안이더라. 웃기지.",
	"[talk]미호가 네 얘길 자주 해. 그 여우, 입이 가벼워. …나쁜 얘긴 아니었어.",
	"[talk]바나는 밤에 여기 서 있어. 그놈도 자기 방식으로 값을 치르는 중이야.",
]

# ★[S9-T5] 하트 5(연인): lines()의 넷째 단. ♡5는 의지 시험(고백)을 통과해야만 닿는 칸이라,
#   이 묶음이 서면 그 사람은 이미 멜의 연인이다. 멜의 애정은 끝까지 **회계의 문법**으로 나온다.
const LINES_LOVER := [
	"[shy]…왔어. 자리 비워 놨다. 늘 앉던 데.",
	"[talk]오늘 장부는 벌써 맞춰 놨어. 네 오는 시간 계산해서 미리 끝냈다.",
	"[shy]…그게 계산이라면 계산이고, 아니면 아닌 거고.",
	"[smile]심장이 안 뛰는 몸인데 이상하지. 네가 문 열면 뭔가가 한 번 걸려.",
	"[talk]손 차갑지? 원래 그래. 싫으면 놔.",
	"[shy]…안 놓네.",
	"[talk]내 인생 통틀어 이자 없이 받은 건 네가 처음이야.",
	"[sad]그래서 무섭다. 갚을 방법을 모르겠거든.",
	"[talk]옥자가 아무 말 안 하더라. 장부에 뭐라고 적지도 않고. 그게 그 사람 허락이야.",
	"[smile]오늘 마감 일찍 할까. 손님 두엇 놓쳐도 계산은 맞아.",
	"[shy]…계산 안 맞아도 상관없다는 소리다, 그건.",
	"[talk]밤에 카운터 불 하나만 켜 놓고 앉아 봐. 이 집에서 제일 좋은 자리야.",
	"[smile]다음 정산은 둘이 하자. 네 몫 떼는 거 보여 줄게.",
]

# 오늘 이미 일일 대화를 한 뒤 또 말 걸었을 때(점수 없음 — 대사만 가볍게 바뀐다).
const LINE_AGAIN := "[smile]오늘 장사는 너랑 한 걸로 충분해. 또 보자고."
# 연인·배우자에게는 같은 자리에 다른 온도의 한 줄이 선다(같은 규칙, 다른 목소리).
const LINE_AGAIN_LOVER := "[shy]또 왔어? …장부는 두 번 안 봐도 되는데. 너는 봐도 되고."

# ── ★[S9-T5 / ADR-0067 결정 12] 배우자 대사 8축 ──────────────────────────────
# 결혼 후에는 이 묶음이 lines()를 **대신한다**(main이 spouse_id로 갈라 부른다). 축을 날(day)에서
# 파생하므로 상태가 0이고, 세이브 키도 늘지 않는다(miho.gd와 같은 규약).
#
# 여덟 축: ① 아침·집 ② 카페 일 ③ 옛 빚·그 불 ④ 옥자·동료 ⑤ 절기·날씨 ⑥ 장난 ⑦ 애정 ⑧ 미래.
# ★ 배우자 대사에도 봉인 법칙이 그대로 걸린다 — 결혼했다고 멜이 읽을 수 있는 것이 늘지 않는다.
const SPOUSE_AXES := [
	# ① 아침·집
	[
		"[talk]일어났냐. 나는 안 자. 강시는 눕기만 해.",
		"[talk]밥은 차려 놨다. 원가 계산해서 만든 거라 맛은 보장 못 해.",
		"[shy]…거짓말이야. 네 입에 맞추느라 세 번 고쳤어.",
		"[talk]집 살림도 장부를 매겨 봤는데 우리 적자더라. 근데 이 적자는 안 메울 거다.",
		"[smile]나가기 전에 얼굴 한 번 보고 가. 그게 오늘 첫 수입이야.",
	],
	# ② 카페 일
	[
		"[talk]오늘 재료 회전 빠르다. 네가 아침에 채워 준 덕이지.",
		"[talk]손님 응대는 내가 해. 너는 앉아서 마셔. 그림이 그게 더 좋아.",
		"[talk]마감 정산은 같이 하자. 둘이 하면 실수가 준다더라. …실은 그냥 같이 있고 싶은 거고.",
		"[talk]단골 명단에 네 이름을 못 적겠어. 손님이 아니니까.",
		"[smile]대신 표지 안쪽에 적어 놨다. 맨 앞장에.",
	],
	# ③ 옛 빚·그 불
	[
		"[sad]가끔 손끝에 돈자루 감촉이 남아 있어. 마지막으로 쥔 게 그거였으니까.",
		"[talk]놓고 나왔으면 살았을까. 그건 계산이 안 되는 문제더라.",
		"[sad]밤에 탄 냄새 같은 게 날 때가 있어. 이 집엔 아궁이도 없는데.",
		"[talk]그럴 땐 장부를 펴. 숫자는 안 타거든.",
		"[shy]…네가 옆에 있으면 안 펴도 되고.",
	],
	# ④ 옥자·동료
	[
		"[talk]옥자가 우리 혼례 비용을 장부에 안 적었어. 그 사람 방식의 축의금이지.",
		"[smile]미호는 사흘 내내 울더라. 좋아서 우는 건 처음 봤어.",
		"[talk]바나는 그날 밤 근무를 혼자 다 섰어. 말은 한 마디도 안 하고.",
		"[talk]이 집 사람들, 표현이 죄다 이상해. 나 포함이고.",
		"[sad]…나쁜 무리는 아니야. 죽어서 만난 것치곤.",
	],
	# ⑤ 절기·날씨
	[
		"[talk]절기 바뀐다. 메뉴 원가도 같이 바뀌어. 장부는 계절을 알거든.",
		"[talk]비 오는 날은 손님이 오래 앉아 있어. 매출은 그런 날 붙는다.",
		"[talk]겨울엔 재고를 미리 쌓아. 밭이 자는 동안에도 카페는 안 자니까.",
		"[smile]더운 날엔 물 좀 마셔. 나는 안 마셔도 되는 몸이고 너는 아니야.",
		"[talk]눈 오면 문 앞은 내가 쓸어 놓을게. 미끄러져 다치면 그게 제일 큰 손해다.",
	],
	# ⑥ 장난
	[
		"[talk]부적 떼지 마라. 진짜로 뻣뻣해진다.",
		"[shy]…한 번은 봐줬잖아. 두 번은 안 돼.",
		"[smile]내기할까. 오늘 매출 맞히기. 진 사람이 마감 청소.",
		"[talk]…내가 이겼다. 매일 세는 놈한테 걸면 어떡하냐.",
		"[smile]져 주는 법을 배워야 하는데, 그것만 안 배워지네.",
	],
	# ⑦ 애정
	[
		"[shy]나 같은 게 옆에 있어도 되나 싶은 날이 있어. 오늘은 아니고.",
		"[talk]사랑을 잘 아냐고? 몰라. 근데 손해 보는 건 안다. 너한텐 계속 손해 보고 싶더라.",
		"[smile]그 정도면 꽤 정확한 정의 아니냐.",
		"[shy]…웃지 마. 나 이런 말 하루치 다 썼어.",
		"[talk]이리 와. 잠깐만 이러고 있자. 계산은 나중에.",
	],
	# ⑧ 미래
	[
		"[talk]가게 하나 더 낼까 생각 중이야. 농담이고. …반은 진심이고.",
		"[talk]우리 이름으로 된 장부 한 권 만들자. 매출 말고 날짜만 적는 걸로.",
		"[smile]오래 걸리는 걸 하나쯤 같이 하고 싶어. 나는 시간이 많거든.",
		"[sad]영원히 일한다는 계약, 예전엔 형벌인 줄 알았어.",
		"[smile]지금은 그냥 근무 조건이야. 같이 서는 거면.",
	],
]

# 배우자에게 오늘 두 번째 이후로 말 걸었을 때.
const LINE_AGAIN_SPOUSE := "[talk]바쁘냐. 가 봐. 계산은 내가 맞춰 놓을 테니까."

# ── ★[S9-T5 / ADR-0067 결정 5·11] 단계 관문 발화(♡1~4 속죄 아크) ─────────────
# miho.gd가 확립한 온도 곡선을 멜의 각도로 옮긴다(감정 → 기록):
#   ♡1 = 능력(속죄의 밝은 표면 — 마진 곱셈기를 장부로 보여 준다. 죄는 아직 안 비침)
#   ♡2 = 사고 암시(디테일 0 · 말 돌림)
#   ♡3 = 첫 고백(도박 → 사채 → 장부 소각하러 간 그날 밤) + **옥자 씨앗 한 톨**(숨긴 장부)
#   ♡4 = 사실의 조각 완전체(B2) — 사본을 내밀고, 뜻은 안 말한다.
const GATE_HEART_1 := [
	"[talk]잠깐 서 봐. 보여 줄 게 있어.",
	"[talk](멜이 카운터 밑에서 두꺼운 장부를 꺼내 편다)",
	"[talk]네 출하분 단가야. 여기, 이 줄. 오늘부터 다시 매겼다.",
	"[smile]같은 물건인데 값이 올랐지? 내가 붙일 수 있는 마진을 네 쪽으로 돌린 거야.",
	"[talk]사기 아니다. 손님한테 더 받는 것도 아니고. 회전이 빨라지면 그만큼 생기는 몫이 있어.",
	"[talk]그걸 나 혼자 먹느냐 나눠 쓰느냐 — 살아선 전자였고, 여기선 후자다.",
	"[shy]…아무한테나 이러는 거 아니야. 장부 펴 보이는 건 옷 벗는 거랑 비슷해서.",
	"[talk]친해질수록 네 단가는 계속 오른다. 계산은 내가 해.",
	"[talk]가 봐. 물건이나 더 가져오고.",
]

const GATE_HEART_2 := [
	"[talk]오늘 정산 깔끔하더라. 네 몫 올려 놨어.",
	"[talk]나 이 정도면 괜찮은 회계 아니냐. 죽어서 얻은 직업치곤.",
	"[sad]…살아서도 숫자를 만졌지. 종류가 좀 달랐을 뿐이고.",
	"[sad]나는, 남의 장부를 태우려고 한 적이 있어.",
	"[talk](멜이 책장을 넘기다 말고 손을 멈춘다)",
	"[talk]…아니다. 오늘 할 얘기는 아니야.",
	"[talk]언젠간 할게. 나도 정리가 좀 필요해서.",
	"[talk]가라. 재료 떨어지기 전에 밭 한 바퀴 돌고 와.",
]

const GATE_HEART_3 := [
	"[talk]…문 닫고 앉아라. 오늘은 좀 길다.",
	"[sad]저번에 하다 만 얘기. 남의 장부를 태우려 했다고 한 거.",
	"[sad]나 도박에 미쳐 있었어. 그러다 돈 빌려주는 쪽으로 넘어갔고. 이자 계산이 제일 재밌더라.",
	"[talk]빌려 간 사람 중에 약방이 하나 있었어. 약재 팔아서 갚겠다던 사람.",
	"[sad]독촉 장부에 내 이름이 남는 게 싫었어. 그래서 부하들 끌고 갔지. 장부만 태우면 없던 일이 될 줄 알고.",
	"[sad]…그날 밤 그 집이 탔다. 나는 돈자루부터 챙겼고.",
	"[talk]그래서 이 꼴이야. 제일 먼저 탔고, 제일 오래 남았지.",
	"[shy]…이 얘기 처음 한다. 너한테.",
	"[talk]동정은 됐어. 계산이 맞으니까 여기 있는 거야.",
	"[talk]아, 그리고. 사장님 말인데.",
	"[talk]금고 안쪽에 숨긴 장부가 있어. 부적으로 봉해서.",
	"[shy]…아니다. 됐어. 내가 열 자격은 없지.",
	"[talk]가 봐. 오늘 매출은 내가 맞춰 놓을게.",
]

# ★ ♡4 = **사실의 조각(B2) 완전체**. 봉인 법칙 최고 난도 구간이라 규칙을 다시 적어 둔다:
#   멜은 **장부에 적힌 것**(무엇이 얼마에 · 누구 부담으로 · 무엇이 건네졌는가)만 읽는다.
#   "그 다음에 그것들이 어디로 갔는가"·"그것이 무슨 뜻인가"·"그러므로 너는 무엇을 했는가"는
#   **한 줄도 쓰지 않는다** — 그 자리를 비워 두는 것이 이 조각의 설계다(ADR-0016). 멜 스스로
#   "그건 내 장부 밖이다"라고 선을 긋는 것이 그 공백의 인-픽션 근거다.
const GATE_HEART_4 := [
	"[talk]…앉아. 오늘은 물건 얘기 아니다.",
	"[talk]금고 안쪽 장부, 결국 봤어. 사장님 자리 비운 새에 필사만 떴다. 원본은 그대로 뒀고.",
	"[sad]내 죄는 나중에 계산하기로 하고, 일단 이것부터 봐.",
	"[talk](멜이 얇은 사본 한 장을 카운터 위로 밀어 놓는다)",
	"[talk]네 이름이 있어. 약값 내역이야. 이승 쪽 기록.",
	"[talk]햇수로 몇 년치다. 탁기 다스리는 약, 매일 한 첩. 값은 전부 '본인 부담'으로 처리돼 있고.",
	"[sad]근데 그 '본인'이 너는 아니야. 네 칸엔 한 푼도 안 적혀 있어.",
	"[talk]그 아래는 물건 목록이다. 판 게 아니라 건넨 것들. 노트 한 권, 깎아 만든 나무 조각 몇, 그런 거.",
	"[talk]장부는 건넨 데까지만 적어. 그 다음은 안 적혀 있어.",
	"[sad]그건 내 장부 밖이다. 나는 거기까지야.",
	"[talk]마지막 장에 봉인 칸이 하나 더 있어. 네 계약서 죄목 칸이랑 같은 부적이야. 같은 손이 봉했다는 뜻이지.",
	"[shy]…숫자는 읽어 줄 수 있어도 뜻은 못 읽는다. 그건 내 일이 아니야.",
	"[talk]가져가. 사본은 네 거다. 원본은 제자리에 뒀어.",
]

# ── ★[S9-T5 / ADR-0067 결정 2] 관문 컷신 스텝(연출 등급 2 — 4동사 한정) ───────
# cutscene.gd 포맷 그대로다. **다섯 번째 동사는 없다**(npc/cam/fade/clock).
#
# ★ 좌표 규약: NPC 스텝의 tile은 **카페 실내 좌표계**다(멜의 스테이션 MEL_TILE (13,88) =
#   카페 방 CAFE_RECT(8,86,13,10) 안 직원 줄). 컷신 러너는 구역을 모르고 훅에도 구역 인자가
#   없으므로, **NPC 스텝이 있는 컷신은 반드시 암전(fade) 뒤에서만 움직인다**(페이드가 이동을
#   덮는다). 재생이 끝나면 main이 원 위치를 복원한다(_end_cutscene). 미호와 같은 규약이다.
# ★ 길이는 짧게 잡는다(관문당 1.5~2.5초). 관문 발화가 본체이고 컷신은 그 앞의 숨 고르기다.
const CUTSCENE_HEART_1 := [
	{"verb": "clock", "running": false},
	{"verb": "fade", "to": 1.0, "secs": 0.35},
	{"verb": "npc", "id": "mel", "tile": Vector2i(13, 88)},   # 암전 뒤에서 카운터 안쪽 제자리
	{"verb": "fade", "to": 0.0, "secs": 0.35},
	{"verb": "npc", "id": "mel", "tile": Vector2i(13, 89), "secs": 0.8},   # 카운터 밖으로 한 걸음
	{"verb": "cam", "offset": Vector2(0, -16), "secs": 0.5},
	{"verb": "cam", "offset": Vector2(0, 0), "secs": 0.3},
	{"verb": "clock", "running": true},
]

const CUTSCENE_HEART_2 := [
	{"verb": "clock", "running": false},
	{"verb": "cam", "offset": Vector2(0, -10), "secs": 0.5},   # 카운터 쪽으로 살짝 붙는 시선
	{"verb": "fade", "to": 0.3, "secs": 0.45},                 # 손이 멈추는 자리의 그늘
	{"verb": "fade", "to": 0.0, "secs": 0.45},
	{"verb": "cam", "offset": Vector2(0, 0), "secs": 0.4},
	{"verb": "clock", "running": true},
]

const CUTSCENE_HEART_3 := [
	{"verb": "clock", "running": false},
	{"verb": "fade", "to": 1.0, "secs": 0.5},
	{"verb": "npc", "id": "mel", "tile": Vector2i(12, 90)},   # 문 닫고 마주 앉는 자리(홀 쪽)
	{"verb": "fade", "to": 0.0, "secs": 0.6},
	{"verb": "cam", "offset": Vector2(0, -14), "secs": 0.6},
	{"verb": "cam", "offset": Vector2(0, 0), "secs": 0.4},
	{"verb": "clock", "running": true},
]

const CUTSCENE_HEART_4 := [
	{"verb": "clock", "running": false},
	{"verb": "fade", "to": 1.0, "secs": 0.7},                 # 가장 긴 암전 = 가장 무거운 비트
	{"verb": "npc", "id": "mel", "tile": Vector2i(13, 89)},
	{"verb": "cam", "offset": Vector2(0, -24)},
	{"verb": "fade", "to": 0.0, "secs": 0.9},
	{"verb": "cam", "offset": Vector2(0, 0), "secs": 0.6},
	{"verb": "clock", "running": true},
]

# ── ★[S9-T5 / ADR-0067 결정 7] 관문 여진 편지 ────────────────────────────────
# 관문이 성사된 **그날 밤** 큐에 들어가 **다음 날 아침** 우편함에 꽂힌다(mailbox.gd의 큐 규약).
# 본문은 mailbox.gd LETTERS 테이블 행이 들고, 이 파일은 **어느 칸이 어느 편지를 부르는가**만 안다.
# 중복 발송 방어는 mailbox.send가 이미 진다(같은 id는 두 번 안 온다 — 재구애에도 안전).
const GATE_LETTERS := {
	1: "mel_gate1_margin",
	2: "mel_gate2_ash",
	3: "mel_gate3_ledger",
	4: "mel_gate4_copy",
}

# ── ★[S9-T5 / ADR-0067 결정 6] 절기 물음 ─────────────────────────────────────
# 주 첫날의 첫 대화에 멜이 **묻는다**. 절기당 하나(피안절·유화절·망연절·성야절).
#
# ★ **답은 전부 0점이다**(결정 4). 반응은 인-픽션 한 줄이고, 어떤 선택도 호감도·플래그·
#   아이템을 건드리지 않는다. 그래서 이 테이블에는 점수 칸 자체가 없다.
# ★ 형식: {"line": 질문 한 줄, "options": 선택지(2~4지 — DialogueBox 상한), "replies": 반응}.
#   options와 replies는 같은 길이다(index가 곧 짝). main은 이 dict를 읽어 선택지를 세우기만 한다.
const SEASON_QUESTIONS := [
	# 0 피안절(봄결) — 시작의 절기
	{
		"line": "[talk]올해 밑천 말이야. 넌 어디다 걸겠어?",
		"options": ["씨앗에", "사람한테", "안 걸고 쥐고 있어"],
		"replies": [
			"[talk]무난하군. 땅은 배신이 늦거든.",
			"[shy]…나쁘지 않아. 회수는 느려도 이자가 이상하게 붙더라.",
			"[smile]현명해. 안 거는 것도 결정이야. 나는 그걸 못 배워서 죽었고.",
		],
	},
	# 1 유화절(여름결) — 해가 긴 절기
	{
		"line": "[talk]해가 길어. 장사도 길어지고. 넌 남는 시간에 뭘 계산해?",
		"options": ["더 벌 방법", "덜 일할 방법", "계산 안 해"],
		"replies": [
			"[smile]내 쪽 사람이군. 언제 카운터 한번 맡겨 볼까.",
			"[talk]그것도 계산이야. 오히려 어려운 쪽이지.",
			"[shy]…부럽다. 나는 그게 안 꺼져서.",
		],
	},
	# 2 망연절(가을결) — 거두는 절기
	{
		"line": "[talk]거두는 절기다. 넌 장부를 언제 덮어?",
		"options": ["딱 맞을 때", "안 맞아도 덮어", "안 덮어"],
		"replies": [
			"[smile]정확한 놈. 그렇게 살면 오래 산다. …여기선 소용없지만.",
			"[talk]그것도 능력이야. 나는 그거 배우는 데 목숨 하나 썼다.",
			"[sad]…그러다 나처럼 된다. 적당히 해.",
		],
	},
	# 3 성야절(겨울결) — 땅이 자는 절기
	{
		"line": "[sad]땅이 자는 절기야. 이런 밤엔 뭐가 제일 무섭냐.",
		"options": ["빈 지갑", "빈 가게", "안 무서워"],
		"replies": [
			"[talk]솔직하군. 그건 채우면 되는 거라 제일 쉬운 무서움이야.",
			"[sad]…나도 그래. 문 열어 놨는데 아무도 안 오는 밤이 제일 길어.",
			"[smile]거짓말. 근데 그렇게 말해 주면 나도 좀 덜 무섭다.",
		],
	},
]

# ── ★[S9-T5] 의지 시험(♡5 고백)·이혼·생일 ────────────────────────────────────
# 수락: ADR-0014 "해방-결혼"의 입구다. 멜에게 연애는 *빚을 다 갚았다는 영수증*이 아니라
#       *계속 갚아 나갈 이유*라는 결로 쓴다(속죄 완료 선언 금지 — 아크는 결혼 후에도 이어진다).
const CONFESSION_ACCEPT := [
	"[surprised]…잠깐. 지금 뭐라고 했어.",
	"[talk](멜이 들고 있던 장부를 조용히 덮는다)",
	"[shy]…나도 같은 계산을 하고 있었어. 며칠 전부터.",
	"[sad]근데 답이 자꾸 안 맞더라고. 내가 받을 자격이 있냐는 항목에서.",
	"[talk]그건 아직도 안 맞아. 그래도 받을란다.",
	"[smile]대신 약속하지. 이 관계에서 네가 손해 보는 일은 없게 한다.",
	"[talk]내가 유일하게 잘하는 게 그거니까.",
]

# 거절(슬롯 점유 = 이미 다른 사람이 있다). ADR-0022 결: 적대 없음·무벌칙. 멜은 화내지 않고
# 자기 규칙을 든다 — "남의 몫 뺏는 걸로 한 번 죽었다". 그 온도가 재시도를 씁쓸하지 않게 남긴다.
const CONFESSION_REJECT := [
	"[surprised]…거기까지.",
	"[talk]마음은 접수했어. 반품 안 한다. 근데 지금은 못 받아.",
	"[sad]네 옆에 이미 한 사람이 서 있잖아. 그건 내 장부에도 적혀 있어.",
	"[talk]나는 남의 몫 뺏는 걸로 한 번 죽었다. 두 번은 안 해.",
	"[shy]…나중에. 그때도 계산이 남아 있으면, 그때 다시 하자.",
]

# 이혼 작별 — **첫 줄이 토스트로 나간다**(main._divorce_farewell_line). 그래서 첫 줄은 혼자
# 서도 완결되는 한 문장이어야 한다(뒷줄은 대화창 승격 시 S9b가 쓴다).
const DIVORCE_FAREWELL := [
	"[sad]원망은 안 한다. 계약은 원래 양쪽이 접을 수 있는 거야.",
	"[talk]네 출하 단가는 안 내려. 그건 우리 일이 아니라 장사 일이니까.",
	"[shy]…가끔 들르기는 해. 손님으로는 언제든 받는다.",
	"[talk]잘 지내라. 지갑 열어 놓고 다니지 말고.",
]

const BIRTHDAY := [
	"[talk]오늘? …아, 그렇군. 나도 잊고 있었어.",
	"[sad]죽은 놈 생일을 세는 게 좀 이상하지. 근데 세 주니까 하루가 특별해지긴 하네.",
	"[talk]선물은 됐어. 굳이 하겠다면 값 나가는 걸로 해라. 나 그런 놈이야.",
	"[shy]…농담이다. 얼굴 봤으면 됐어.",
]

# 대화창에 띄울 이름.
func display_name() -> String:
	return "멜"

# 말 걸었을 때 들려줄 대사 줄들. hearts = 현재 하트 단계, first_today = 오늘 첫 대화인가
# (miho.gd와 같은 시그니처). 오늘 두 번째 이후면 짧은 인사 한 줄(일일 보상은 Affinity가 막음).
# ★[S9-T5 / ADR-0067 결정 5] **4단**으로 확장됐다: ♡0 낯섦 / ♡1+ 익숙 / ♡3+ 속을 보임 /
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

# ★[S9-T5] 배우자 전용 묶음(main이 spouse_id == "mel"일 때 lines() 대신 부른다).
# 축은 **day에서 파생**한다 — 어제 무슨 축이 나왔는지 기억하지 않으므로 상태·세이브 키가 0이다.
# 빈 배열을 돌려주면 main이 평소 lines()로 되돌아간다(이음매 하위호환).
func spouse_lines(day: int = 1, first_today: bool = true) -> PackedStringArray:
	if not first_today:
		return PackedStringArray([LINE_AGAIN_SPOUSE])
	if SPOUSE_AXES.is_empty():
		return PackedStringArray()
	var axis: int = abs(day) % SPOUSE_AXES.size()
	return PackedStringArray(SPOUSE_AXES[axis])

# ★[S9-T5] 단계 관문 발화(♡1~4). 범위 밖 칸은 빈 배열 = main의 placeholder 폴백.
func heart_gate_lines(target: int) -> PackedStringArray:
	match target:
		1: return PackedStringArray(GATE_HEART_1)
		2: return PackedStringArray(GATE_HEART_2)
		3: return PackedStringArray(GATE_HEART_3)
		4: return PackedStringArray(GATE_HEART_4)
	return PackedStringArray()

# ★[S9-T5] 관문 컷신 스텝(♡1~4). 빈 배열 = 컷신 없이 대화만(하위호환 경로 그대로).
func heart_gate_cutscene(target: int) -> Array:
	match target:
		1: return CUTSCENE_HEART_1.duplicate(true)
		2: return CUTSCENE_HEART_2.duplicate(true)
		3: return CUTSCENE_HEART_3.duplicate(true)
		4: return CUTSCENE_HEART_4.duplicate(true)
	return []

# ★[S9-T5] 관문 여진 편지 id("" = 이 칸엔 편지 없음). 발송·중복 방어는 mailbox가 진다.
func heart_gate_letter(target: int) -> String:
	return String(GATE_LETTERS.get(target, ""))

# ★[S9-T5] 절기 물음(season = GameClock의 절기 인덱스 0..3). 빈 dict = 이 절기엔 물음 없음.
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

# ★[S9-T5] 의지 시험 결과 발화(accepted = 슬롯이 비어 수락됐는가).
func confession_lines(accepted: bool) -> PackedStringArray:
	return PackedStringArray(CONFESSION_ACCEPT if accepted else CONFESSION_REJECT)

# ★[S9-T5] 이혼 작별. main은 **첫 줄만** 토스트에 쓴다(결정 9 — 대화창 승격은 S9b).
func divorce_lines() -> PackedStringArray:
	return PackedStringArray(DIVORCE_FAREWELL)

# ★[S9-T5] 생일 당일 플레이버(평소 묶음 앞에 선다).
func birthday_lines() -> PackedStringArray:
	return PackedStringArray(BIRTHDAY)

# P2.3② P2.1 도색 스프라이트(있으면 그레이박스 대신). 상주 NPC라 남쪽(down) 첫 프레임 정지.
var _sprite: AnimatedSprite2D = null

func _ready() -> void:
	_sprite = CharSprite.make("res://assets/characters/mel.png")
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
