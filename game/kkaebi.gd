extends Node2D
class_name Kkaebi
# ★[S9b-T1 / ADR-0068 결정 3·5·6] 깨비 NPC — **조연 코러스 9인의 첫 풀 온보딩**.
#
# 목적: ADR-0068 결정 3이 정의한 "조연 1인 = 인물 층 + 서사 층 한 태스크"의 첫 실행이다.
#       이 파일은 주민 프레임워크(resident.gd)가 요구하는 것(display_name·lines·walk_offset
#       블록·자기 몸 그리기)과 **깨비에 관한 서사 텍스트 전량**을 든다 — 자리·스케줄·선물·
#       세이브는 한 줄도 없다(전부 main `_setup_residents()` 레코드 소관. mochi.gd 선례).
#       main은 "언제 부르는가"만 알고 "무엇을 말하는가"는 한 줄도 모른다(ADR-0005).
#
# ★ 정체성([residents.md] §남요괴 1 · [narrative-bible.md] §5.2 깨비):
#   · **도깨비**(한국 설화). 씨름·괴력·도깨비방망이. 능글 미소·장난기 눈빛의 쾌남.
#     평소 매력 = 툭툭 장난 ↔ 힘쓰는 일엔 1등으로 달려오는 동네 오빠.
#   · **생전 죄** = "모든 걸 장난으로 만들어 진심을 한 번도 못 보인 죄"(장난→상실, 끝내 사과 못 함).
#   · **그날 밤** = 약방 뒷산 야생 도깨비(메밀묵 얻어먹던 단골). 화재 몇 시간 전 *장난으로* 마당에
#     도깨비불을 숨김 → 다른 불과 공명해 화마를 열 배로 키운 **증폭자**.
#   · **나라카 연결** = 장난이 대참사가 된 죄책감. 카페 카운터 주변을 서성이며 장난치듯 은근히 돕는다.
#   · **반전 로맨스 축** = 영원한 장난꾼 → 결혼 = 생전 처음 "진심"을 택함.
#   · ⚠️ **불은 메카닉 능력으로 쓰지 않는다**([residents.md] 가드레일 · [narrative-bible §5.2]).
#     백스토리 한정이고(미호의 양육의 불과 중복 금지), 그래서 이 파일에 effect_fn도 어떤 수치
#     보정도 없다 — 조연은 **쉼터 2채널**(대화·선물)뿐이다([narrative-bible §6.1] · ADR-0008
#     "활동 곱셈기는 메인 4인 독점").
#
# ── 훅 목록(전부 main의 has_method 이음매 — miho.gd와 **같은 시그니처**) ─────
#   · lines(hearts, first_today)   — 일상 대사 **4단**(♡0 / ♡1+ / ♡3+ / ♡5+)
#   · heart_gate_lines(1..4)       — 단계 관문 발화 4칸(♡3 = 그날 밤 고백 · ♡4 = 생전 죄 고백)
#   · heart_gate_cutscene(1..4)    — 각 관문의 컷신 스텝(연출 등급 2 · **4동사 한정**)
#   · heart_gate_letter(1..4)      — 관문 여진 편지 id(본문은 mailbox.gd LETTERS)
#   · season_question(season)      — 절기 물음 4개(**선택지 전부 0점**)
#   · birthday_lines()             — 생일 당일 플레이버(유화절 13일 — Resident.BIRTHDAYS)
#   · confession_lines / divorce_lines / spouse_lines — **휴면 콘텐츠**(아래)
#
# ★ **연애·배우자 축은 지금 휴면이다**: [ADR-0068] 결정 2가 "조연 연애·결혼을 T1 11인 전원
#   개통"으로 잡았지만 그 개통(main `ROMANCE_OPEN` 확장)은 **S9b-T6 소관**이다. 그래서 본문은
#   지금 다 써 두되 main의 명단은 이 태스크가 건드리지 않는다 — 훅이 먼저 있고 명단이 나중에
#   붙는 순서라 T6은 문자열 한 줄만 더하면 된다(콘텐츠 재작업 0).
# ★ **spouse_lines는 4축**이다([ADR-0068] 결정 5 — 메인 8축의 절반). 축을 day에서 파생하므로
#   상태가 0이고 세이브 키도 안 는다(miho.gd 규약 그대로).
#
# ★ **봉인 법칙**([ADR-0016] · [ADR-0068] 결정 6)이 ♡3·♡4의 가장 센 제약이다.
#   ㉠ **조연은 코러스다** — 깨비는 *그날 밤의 자기 파편 하나*와 *자기 죄책감*만 안다
#      ([narrative-bible §4] 코러스 모델). ♡3에서 말하는 것은 "내가 불을 숨겼고, 다른 불과
#      만나 커졌고, 나는 끌 줄 몰랐다"까지다.
#   ㉡ **중심 진실 4금지**: 옥자의 희생 · 기억 봉인 · 마녀=연인 · 플레이어의 죄목. 어느 것도
#      암시조차 하지 않는다. 그래서 깨비는 **다른 불의 주인을 지목하지 않고**("누구 건지는
#      나도 몰라"), 약방·옥자·플레이어를 그 밤의 인물로 호명하지 않는다("그 집"까지).
#      라쇼몽 구조([narrative-bible §6.1])는 조연이 서로의 파편을 대신 말하지 않아야 성립한다.
#   ㉢ ♡4는 **자기 생전 죄까지만**([ADR-0068] 결정 6). 플레이어의 죄를 겨누는 문장은 0줄이다
#      — 그건 메인 3인의 조각(B1~B3)이 독점한다([narrative-bible §6.1]).
#   이 셋은 kkaebi_arc_test의 금칙어 스캔(31어)이 회귀로 지킨다(검열이 아니라 가드다 — 나중
#   손질이 평결 문장을 흘려 넣으면 거기서 걸린다).
# ★ **선택지는 전부 0점**([ADR-0067] 결정 4). 이 파일에 Affinity 참조가 한 줄도 없는 것이
#   그 계약의 구현이다(절기 물음은 반응 한 줄만 돌려준다).

const BODY_SIZE := Vector2(16, 32)   # NPC 자리 규격(ADR-0003 — 플레이어·미호·멜과 동일)

# ── 일상 대사 4단 ────────────────────────────────────────────────────────────
# 축은 **"장난 → 진심"** 하나다. 네 단이 그 축의 네 지점이다(장난만 → 손해 보는 장난 →
# 장난 뒤로 진심이 삐져나옴 → 장난을 내려놓고 말함).
# PackedStringArray() 생성자는 상수식이 아니라 const로 못 두므로, 상수식인 배열 리터럴로 두고
# lines()에서 PackedStringArray로 변환해 넘긴다(miho.gd·mochi.gd와 동일).

# 하트 0(첫 만남): 전부 장난이다. 자기 소개조차 내기로 시작한다 — 진심을 안 보이는 것이
# 이 캐릭터의 출발점이자 생전 죄의 모양이다.
const LINES_INTRO := [
	"[smile]어이! 거기 새 얼굴. 나랑 씨름 한판 안 할래?",
	"[talk]겁먹지 마. 나 힘 조절 잘해. …요즘은.",
	"[smile]난 깨비. 저 산에서 내려와 여기 눌러앉은 지 좀 됐어.",
	"[talk]하는 일? 딱히 없어. 무거운 거 드는 데 부르면 제일 먼저 가는 정도.",
	"[shy]…아니 왜 웃어. 그게 얼마나 대단한 건데.",
	"[talk]낮엔 광장에 있어. 저녁엔 카페 카운터 옆에 서 있고.",
	"[smile]또 봐! 다음엔 진짜 씨름하자. 도망가기 없기다?",
]

# 하트 1~2(친해지는 중): 축이 한 칸 움직인다 — 장난은 그대로인데 **손해 보는 쪽**이 붙는다
# (몰래 도와 놓고 생색을 안 낸다 = 진심을 여전히 안 보이지만 방향은 바뀌었다).
const LINES_WARMING := [
	"[smile]왔네! 오늘 네 신발 끈 묶어 놨는데 안 넘어졌어? 아쉽다.",
	"[talk]농담이야. …반은 진담이고.",
	"[talk]아까 네 짐 무거워 보이길래 옮겨 놨어. 누가 했냐고 물으면 모른 척해.",
	"[shy]왜 그런 짓 하냐고? 그냥. 생색내면 재미없잖아.",
	"[smile]나 힘 하나는 진짜야. 이 팔뚝 봐. 만져 봐도 되고.",
	"[talk]메밀묵 있으면 좀 줘. 나 그거 없으면 하루가 안 굴러가.",
	"[smile]다음엔 내가 먼저 장난칠 거야. 각오해.",
]

# 하트 3~4(가까운 사이): ♡3 그날 밤 고백을 **이미 본 뒤에 서는 묶음**이라, 그 이야기를 다시
# 설명하지 않는다 — 아는 사이의 말투로만 스친다(모찌 ♡3~4 규약 동형). 축이 뒤집히는 단이다:
# 장난 뒤로 진심이 삐져나오고, 본인이 그걸 자각한다.
const LINES_CLOSE := [
	"[talk]왔어. …오늘은 장난 안 칠게. 가끔은 이런 날도 있어야지.",
	"[shy]장난이 싫어진 건 아니야. 그냥 너 볼 땐 좀 다르게 하고 싶어서.",
	"[sad]나는 웃기는 건 잘하는데 진지한 건 서툴러. 연습한 적이 없거든.",
	"[talk]산에 있을 땐 아무도 나한테 진지한 걸 안 물었어. 나도 안 물었고.",
	"[smile]근데 요즘은 밤에 혼자 연습해. 뭐라고 말할지.",
	"[shy]…들키니까 좀 부끄럽네. 못 들은 걸로 해.",
	"[talk]무거운 거 있으면 언제든 불러. 그건 지금도 제일 자신 있어.",
]

# 하트 5(맥스 · 연인): 축의 도착점 — **장난을 이겨 먹으려던 자가 지는 쪽을 택한다.**
const LINES_LOVER := [
	"[smile]왔구나. 오늘은 네 발소리부터 알아들었어.",
	"[shy]나 요즘 웃기려고 애 안 써. 네가 그냥 있어도 웃어 주니까.",
	"[talk]예전엔 진심을 말하면 진 거라고 생각했어. 지는 게 제일 싫었거든.",
	"[smile]근데 너한텐 매일 져. 그것도 나쁘지 않더라.",
	"[shy]…이런 말 하고 나면 귀가 뜨거워져. 뿔까지.",
	"[talk]손 줘 봐. 아무것도 안 할게. 그냥 잡고만 있을게.",
	"[smile]장난은 나중에. 오늘은 이거면 됐어.",
]

# 오늘 이미 일일 대화를 한 뒤 또 말 걸었을 때(점수 없음 — 대사만 가볍게 바뀐다).
const LINE_AGAIN := "[smile]또 왔어? 뭐야, 나 보고 싶었구나. 아니라고 해도 소용없어."
const LINE_AGAIN_LOVER := "[shy]…또 왔네. 아니, 좋아서 하는 말이야. 진짜로."
const LINE_AGAIN_SPOUSE := "[smile]집에서 봤는데 또 보네. 이래도 안 질리는 게 신기해."

# ── ★[ADR-0068 결정 5] 단계 관문 발화 ♡1~4 ──────────────────────────────────
# 조연 4단 아크([narrative-bible §6.2]): ♡1~2 평소 매력 → **♡3 그날 밤 고백**(필수 세트피스) →
# ♡4 생전 죄 고백 → ♡5 연애. 앞 두 칸이 가볍고 뒤 두 칸이 무거운 기울기 자체가 아크다.

# ♡1 — 평소 매력 ①: 씨름 내기. 힘과 장난, 그리고 **일부러 져 주려다 진짜로 지는** 결.
const GATE_HEART_1 := [
	"[smile]야, 마침 잘 왔다. 저기 저 바위 보이지?",
	"[talk]내기하자. 저거 나보다 멀리 밀면 하루 종일 네 심부름 해 줄게.",
	"[shy](깨비가 팔을 걷더니, 슬쩍 힘을 빼는 게 보인다)",
	"[surprised]…어? 어어? 야, 너 뭐야. 진짜 미네?",
	"[talk]졌다 졌어. 오늘 하루 네 거다. 뭐 시킬래?",
	"[smile]…아무것도 안 시킬 거면 그냥 옆에 있을게. 그것도 심부름이니까.",
]

# ♡2 — 평소 매력 ②: 메밀묵. 도깨비 설화의 정석이면서 **그날 밤의 좌표를 처음 깔아 두는 칸**이다
# (뒷산 → 산 밑 그 집 → 밤마다 얻어먹던 접시). 여기서는 "그 집이 지금은 없다"까지만 말하고
# 이유는 ♡3으로 넘긴다 — 관문의 기울기를 만드는 유예다.
const GATE_HEART_2 := [
	"[surprised]…이거 어디서 났어? 메밀묵.",
	"[talk](깨비가 한참을 들여다본다)",
	"[sad]예전에 나 이거 얻어먹던 데가 있었어. 산 밑에.",
	"[talk]밤마다 몰래 내려가서 마당 가장자리에 앉아 있으면 한 접시씩 놔주더라.",
	"[shy]도깨비한텐 그게 큰 거야. 무서워하지도, 쫓지도 않고 그냥 놔주는 거.",
	"[sad]…그 집 지금은 없어. 왜 없어졌는지는 다음에 얘기할게.",
	"[smile]야 표정이 왜 그래. 묵이나 먹자. 반 잘라 줄게.",
]

# ♡3 — ★**그날 밤 고백**(조연 필수 세트피스 · [narrative-bible §6.2] · [ADR-0068] 결정 5).
#
# 깨비의 파편 = **증폭자**([narrative-bible §5.2]): 장난으로 숨긴 도깨비불이 다른 불과 공명해
# 화마를 열 배로 키웠다. 이 칸이 말하는 것은 정확히 그 한 조각이다.
#
# ★ 봉인 법칙 이행(이 파일에서 가장 센 제약 — [ADR-0068] 결정 6):
#   ㉠ **다른 불의 주인을 지목하지 않는다**("누구 건지는 나도 몰라"). 깨비는 담장 위에 있었고
#      안을 못 봤다 — 코러스는 자기 파편만 안다([narrative-bible §4]). 미호를 여기서 호명하면
#      조연이 다른 조연/메인의 조각을 대신 말하는 것이 되어 라쇼몽 구조가 무너진다.
#   ㉡ **그 집 안의 사람들을 호명하지 않는다.** 옥자·플레이어·약방 어느 것도 이름이 없다.
#      중심 진실 4금지(옥자 희생 / 기억 봉인 / 마녀=연인 / 플레이어 죄목) 근처에도 안 간다.
#   ㉢ **결론을 대신 내리지 않는다.** "그러니까 그 밤은 ○○였다"는 한 줄도 없다 — 잇는 것은
#      플레이어 몫이다(타인의 말로 봉인이 풀리면 속죄가 성립하지 않는다. CONTEXT 불변).
#   ㉣ 죄책감은 **자기 것**으로만 진술한다("나는 켜기만 했지 끄는 법은 배운 적이 없었다").
const GATE_HEART_3 := [
	"[talk]…아까 그 얘기, 마저 할게. 오늘 아니면 또 못 할 것 같아서.",
	"[sad]그 집 마당에서 나 마지막으로 장난을 쳤어.",
	"[talk]도깨비불 말이야. 몇 점 만들어서 마당 구석에, 장독 뒤에, 처마 밑에 숨겨 놨어.",
	"[smile]밤에 켜지면 놀라겠지, 그럼 나는 담장 위에서 배 잡고 웃겠지. 딱 그 생각뿐이었어.",
	"[sad]내 불은 안 뜨거워. 진짜야. 손에 쥐어도 안 데. 그래서 겁도 없었어.",
	"[sad]근데 그 밤에 다른 불이 하나 더 있었어. 누구 건지는 나도 몰라.",
	"[talk]내 것들이 전부 그쪽으로 고개를 돌리더라. 부르는 것처럼.",
	"[sad]…거기서부턴 내 불이 아니었어. 열 배로 커지는데 끌 수가 없었어.",
	"[talk]나는 담장 위에서 다 봤어. 내려가지도 못하고.",
	"[sad]켜는 건 배웠는데 끄는 건 안 배웠더라고. 장난이라서. 끌 일이 없을 줄 알았으니까.",
	"[shy](깨비가 손바닥을 펴 보였다가, 아무것도 없다는 듯 다시 접는다)",
	"[sad]…이 얘긴 여기까지. 미안해. 너한테 미안할 일도 아닌데 자꾸 미안하다고 하게 되네.",
]

# ♡4 — **생전 죄 고백**([narrative-bible §6.2] "조연이 자기 생전 죄를 털어놓는 것까지만").
# 죄 = "모든 걸 장난으로 만들어 진심을 한 번도 못 보인 죄"([residents.md]) — 장난→상실, 끝내
# 사과 못 함. ★ **반전은 여기서 오지 않는다**(반전 로맨스의 페이오프는 결혼 *후*다 — §6.2).
# ★ 첫 줄이 "불 때문이 아니다"로 시작하는 것이 설계다: 생전 죄(저승에 온 이유)와 그날 밤 역할은
#   [residents.md] 개정 노트의 **2층 구조**라 서로를 대신하지 않는다.
const GATE_HEART_4 := [
	"[talk]내가 여기 온 이유, 물어본 적 없지. 오늘은 내가 먼저 말할게.",
	"[shy]…불 때문이 아니야. 그건 나중 얘기고, 나는 그 전부터 여기 올 놈이었어.",
	"[sad]나는 뭐든 장난으로 만들었어. 좋은 것도, 아픈 것도.",
	"[talk]누가 울면 웃겨 줬어. 위로하는 법을 몰라서 웃기는 걸로 때웠어.",
	"[sad]그러다 한 명을 잃었어. 산 아래 살던 애였는데, 나한테 진지한 걸 딱 한 번 물었어.",
	"[talk]나는 그때도 농담을 했어. 걔가 웃었으니까 됐다고 생각했어.",
	"[sad]…안 됐더라. 다시 볼 기회가 없었어. 사과는 끝내 못 했고.",
	"[shy]그래서 나 사과를 잘 못 해. 연습을 한 번도 못 해 봤거든.",
	"[talk]지금 하는 건 사과가 아니야. 그냥… 너한텐 처음부터 진지하게 시작하고 싶어서.",
	"[smile]…어우, 낯간지러워. 야, 이 얘기 아무한테도 하지 마.",
]

# ── ★[ADR-0067 결정 2 / ADR-0068 결정 5] 관문 컷신 ♡1~4(연출 등급 2 · 4동사 한정) ──
# cutscene.gd 포맷 그대로다. **다섯 번째 동사는 없다**(npc/cam/fade/clock).
#
# ★ **npc 동사를 쓰지 않는다** — 모찌(mochi.gd CUTSCENE_HEART_3)와 같은 근거이고, 깨비에겐 더
#   강하게 적용된다: 깨비는 하루에 **세 구역-자리**(집 앞 → 광장 → 카페 실내)를 도는데 훅에는
#   구역 인자가 없다. 어느 좌표를 적어도 나머지 두 자리에서 관문이 열리면 그림이 순간 이동하고,
#   특히 카페 자리는 **실내**라 야외 좌표를 적으면 벽 너머로 튄다. NPC를 안 움직이면 "컷신 중
#   NPC 이동은 암전 뒤에서만" 규약을 위반할 여지 자체가 0이다.
#   ([ADR-0068] 결정 5가 "관문 4개 체제에선 npc 0이 비현실적"이라 본 것은 *고정 자리* 조연 기준의
#    일반론이고, 구역을 도는 인물에는 모찌 선례가 그대로 우선한다. 구역 인지 훅은 owner 큐.)
# ★ 네 칸의 **호흡을 다르게** 준다 — 등급 2의 표현력은 결국 암전 길이와 카메라 거리뿐이다:
#   ♡1 = 암전 없음(가장 가볍다) / ♡2 = 짧은 그늘 / ♡3 = 가장 긴 암전(세트피스) / ♡4 = 중간 암전 + 근접.

# ♡1 — 씨름 내기. 암전 0, 카메라가 한 번 물러났다 붙는다("판이 벌어진다" 결).
const CUTSCENE_HEART_1 := [
	{"verb": "clock", "running": false},
	{"verb": "cam", "offset": Vector2(0, -18), "secs": 0.45},
	{"verb": "cam", "offset": Vector2(0, 0), "secs": 0.35},
	{"verb": "clock", "running": true},
]

# ♡2 — 메밀묵. 짧은 그늘 한 번(들여다보는 정적) 뒤 밝아진다.
const CUTSCENE_HEART_2 := [
	{"verb": "clock", "running": false},
	{"verb": "cam", "offset": Vector2(0, -8), "secs": 0.4},
	{"verb": "fade", "to": 0.4, "secs": 0.5},
	{"verb": "fade", "to": 0.0, "secs": 0.5},
	{"verb": "cam", "offset": Vector2(0, 0), "secs": 0.3},
	{"verb": "clock", "running": true},
]

# ♡3 — 그날 밤 고백. **가장 긴 완전 암전**(≈2.4초). 미호 CUTSCENE_HEART_4가 같은 문법의 선례다.
const CUTSCENE_HEART_3 := [
	{"verb": "clock", "running": false},
	{"verb": "fade", "to": 1.0, "secs": 0.8},
	{"verb": "cam", "offset": Vector2(0, -24)},
	{"verb": "fade", "to": 0.0, "secs": 1.0},
	{"verb": "cam", "offset": Vector2(0, 0), "secs": 0.6},
	{"verb": "clock", "running": true},
]

# ♡4 — 생전 죄 고백. 반쯤 어두워졌다 돌아오고, 카메라가 눈높이까지 내려와 머문다.
const CUTSCENE_HEART_4 := [
	{"verb": "clock", "running": false},
	{"verb": "fade", "to": 0.7, "secs": 0.6},
	{"verb": "cam", "offset": Vector2(0, -14), "secs": 0.5},
	{"verb": "fade", "to": 0.0, "secs": 0.7},
	{"verb": "cam", "offset": Vector2(0, 0), "secs": 0.4},
	{"verb": "clock", "running": true},
]

# ── ★[ADR-0067 결정 7 / ADR-0068 결정 5] 관문 여진 편지 ─────────────────────
# 관문이 성사된 날 큐에 들어가 **다음 날 아침** 우편함에 꽂힌다(mailbox.gd의 큐 규약).
# 본문은 mailbox.gd LETTERS 행이 들고, 이 파일은 **어느 칸이 어느 편지를 부르는가**만 안다.
# 중복 발송 방어는 mailbox.send가 이미 진다(같은 id는 두 번 안 온다 — 재구애에도 안전).
#
# ★ **3통이다**([ADR-0068] 결정 5 "여진 편지 2~3통" 상한). ♡1은 편지가 없다 — 그 칸은 그 자리에서
#   웃고 끝나는 가벼운 비트라 여진이 남지 않는다(볼륨은 상한이지 목표치가 아니다).
# ★ 편지의 몫은 **여진**이다: 관문에서 이미 한 말을 되풀이하지 않고 그 대화 뒤에 남은 한 자락만 쓴다.
const GATE_LETTERS := {
	2: "kkaebi_gate2_muk",
	3: "kkaebi_gate3_hands",
	4: "kkaebi_gate4_sorry",
}

# ── ★[ADR-0067 결정 6] 절기 물음 ─────────────────────────────────────────────
# 주 첫날의 첫 대화에 깨비가 **묻는다**. 절기당 하나(피안절·유화절·망연절·성야절).
#
# ★ **답은 전부 0점이다**([ADR-0067] 결정 4). 반응은 인-픽션 한 줄이고, 어떤 선택도 호감도·
#   플래그·아이템을 건드리지 않는다.
# ★ 형식: {"line": 질문 한 줄, "options": 선택지(2~4지 — DialogueBox 상한), "replies": 반응}.
#   options와 replies는 같은 길이다(index가 곧 짝).
# ★ 깨비의 물음은 전부 **겨루기·장난·진심**의 축이다(캐릭터마다 묻는 결이 달라야 같은 주에
#   여럿에게 물어도 지루하지 않다 — 미호=땅/기다림, 네오=수치/효율, 모찌=맛/나눔, 깨비=내기/진심).
const SEASON_QUESTIONS := [
	# 0 피안절(봄결) — 시작의 절기
	{
		"line": "[smile]새로 시작하는 절기잖아. 나랑 내기 하나 걸면 뭐로 겨룰래?",
		"options": ["힘 겨루기", "누가 더 오래 참나", "안 겨뤄"],
		"replies": [
			"[smile]좋지! 그거야말로 정정당당이지. 나 봐준다는 말 안 한다?",
			"[talk]어… 그건 내가 질 것 같은데. 나 참는 거 제일 못해.",
			"[shy]…재미없다. 근데 그런 사람이 제일 오래 남더라.",
		],
	},
	# 1 유화절(여름결) — 밤이 짧고 다들 밖으로 나오는 절기
	{
		"line": "[talk]여름밤엔 다들 밖에 나오잖아. 넌 밤에 뭐 해?",
		"options": ["돌아다녀", "그냥 앉아 있어", "일찍 자"],
		"replies": [
			"[smile]우리 잘 맞겠다. 나도 밤이 제일 신나거든.",
			"[talk]그것도 좋지. 앉아 있는 사람 옆엔 앉아 있어 주는 게 예의고.",
			"[shy]…착실하네. 나는 밤에 자는 법을 아직도 몰라.",
		],
	},
	# 2 망연절(가을결) — 거두고 셈하는 절기
	{
		"line": "[talk]거두는 절기라 다들 바쁘지. 넌 도와 달란 말 잘 해?",
		"options": ["잘 해", "혼자 하는 게 편해", "미안해서 못 해"],
		"replies": [
			"[smile]잘한다! 부르면 내가 제일 먼저 갈게. 진짜로.",
			"[talk]나도 그랬어. 근데 혼자 하다 놓치는 게 꼭 하나씩 있더라.",
			"[sad]…그 마음 알아. 근데 미안한 건 부탁이 아니라 안 부르는 쪽이야.",
		],
	},
	# 3 성야절(겨울결) — 밤이 가장 긴 절기
	{
		"line": "[sad]밤이 길어졌지. 넌 긴 밤에 뭐가 제일 무서워?",
		"options": ["어두운 거", "조용한 거", "안 무서워"],
		"replies": [
			"[talk]어두운 건 괜찮아. 내가 밝히는 건 잘하니까. …잘했었으니까.",
			"[sad]나도 그거. 시끄러운 게 좋아. 조용하면 생각이 나거든.",
			"[smile]멋있다. 그럼 무서운 건 내가 맡을게. 하나쯤은 나눠 가져야지.",
		],
	},
]

# ★[ADR-0068 결정 5] 생일 — 유화절 13일(Resident.BIRTHDAYS "kkaebi": [1, 13]).
# ★ **잠정**이다(owner 큐 — Resident.BIRTHDAYS 머리말의 "전부 잠정" 규약 그대로). 배치 근거는
#   설화 결: 도깨비가 가장 자주 나타난다는 **한여름 밤**이다(밤이 짧아 다들 밖에 나와 있는 절기 —
#   깨비의 유화절 물음과 같은 좌표). 회피일(각 절기 25일 · 유화 20일)과 기존 배정을 전부 비껴간다.
const BIRTHDAY := [
	"[smile]야, 오늘 무슨 날인 줄 알아? 맞혀 봐. 세 번 기회 줄게.",
	"[talk]…못 맞히네. 내 생일이야. 아니 사실 나도 정확한 건 몰라.",
	"[shy]도깨비는 태어난 날 같은 거 안 세거든. 그래서 제일 밤 짧은 때로 정해 뒀어.",
	"[smile]축하해 줄 거면 씨름으로 해 줘. 오늘은 봐줄게. 조금만.",
]

# ── ★[ADR-0068 결정 2·5] 휴면 콘텐츠 — 연애·이혼·배우자 ─────────────────────
# 본문은 지금 다 있지만 main의 `ROMANCE_OPEN`에 깨비가 들어가는 것은 **S9b-T6**이다(이 태스크는
# main의 그 명단을 건드리지 않는다). 훅이 먼저 서 있으면 T6은 id 한 줄만 더하면 되고, 그 순간
# 이 본문 전부가 그대로 개통된다 — 콘텐츠 재작업 0.

# 수락. ★ **반전 로맨스의 시작점**([narrative-bible §5.2] "결혼 = 생전 처음 진심을 택함")이다.
#   그래서 이 장면에서 깨비는 처음으로 **농담을 실패한다** — 웃기려다 못 웃기고, 그냥 말한다.
const CONFESSION_ACCEPT := [
	"[surprised]…어. 어어.",
	"[shy](깨비가 뭔가 웃긴 말을 하려다 입을 다문다)",
	"[talk]…미안. 지금 농담 하나 준비했는데, 안 할래.",
	"[sad]나 평생 이런 순간마다 농담으로 도망쳤거든. 한 번은 안 도망가 보려고.",
	"[shy]나도 좋아해. 진심이야. 이 말 하는 데 백 년 걸렸다.",
	"[smile]…자, 다 했다! 이제 웃어도 돼. 나 지금 얼굴 빨간 거 알아.",
]

# 거절(슬롯 점유 = 이미 다른 사람이 있다). [ADR-0022] 결: 적대 없음·무벌칙.
# 깨비는 화내는 대신 **농담으로 물러난다** — 그게 이 캐릭터가 상처를 다루는 유일한 방식이고,
# 동시에 아직 축이 다 안 뒤집혔다는 표시다(재구애가 씁쓸하지 않게 남는다).
const CONFESSION_REJECT := [
	"[surprised]…어? 잠깐만.",
	"[talk]야, 너 옆에 이미 사람 있잖아. 나 그 정도는 봐.",
	"[shy]…아 뭐야, 나 지금 좀 멋있게 물러나는 중이거든? 방해하지 마.",
	"[smile]농담이야. 진짜 괜찮아. 나 원래 지는 거 잘해. 요즘 배웠어.",
	"[talk]가서 잘해 줘. 무거운 거 있으면 그래도 나 불러도 되고.",
]

# 이혼 작별 — **첫 줄이 토스트로 나간다**(main._divorce_farewell_line). 그래서 첫 줄은 혼자
# 서도 완결되는 한 문장이어야 한다.
const DIVORCE_FAREWELL := [
	"[sad]원망 안 해. 나 원래 붙잡는 거 못 하잖아.",
	"[talk]…이번엔 농담 안 할게. 그게 내가 할 수 있는 제일 진지한 거야.",
	"[shy]무거운 거 있으면 그래도 불러. 그건 우리 사이랑 상관없는 일이니까.",
	"[smile]잘 지내. 넘어지지 말고. 신발 끈은 이제 안 묶어 놓을게.",
]

# ── ★[ADR-0068 결정 5] 배우자 대사 **4축**(메인 8축의 절반) ─────────────────
# 결혼 후에는 이 묶음이 lines()를 대신한다(main이 spouse_id로 갈라 부른다). 축을 day에서
# 파생하므로 상태가 0이고 세이브 키도 안 는다(miho.gd 규약 그대로 · day % 4).
# 네 축: ① 아침·집 ② 힘·장난 ③ 옛 불(그날 밤의 잔재) ④ 진심·애정.
# ★ 배우자 대사에도 봉인 법칙이 그대로 걸린다 — 결혼했다고 깨비가 아는 것이 늘지 않는다.
const SPOUSE_AXES := [
	# ① 아침·집
	[
		"[smile]일어났어? 나 아까부터 깨서 천장 보고 있었어. 심심해 죽는 줄.",
		"[talk]물 길어 왔어. 두 통. 이런 건 내가 하는 게 빠르잖아.",
		"[shy]…아침에 네 얼굴 보는 거, 아직도 좀 이상해. 좋은 쪽으로 이상해.",
		"[smile]오늘 문지방 고쳐 놨어. 이제 안 삐걱거려. 밤에 몰래 나가긴 글렀네.",
	],
	# ② 힘·장난
	[
		"[smile]오늘은 뭐 옮길까? 무거울수록 좋아. 가벼운 건 재미없어.",
		"[talk]아까 지붕 올라갔다가 너한테 딱 걸렸지. 그거 놀래키려고 한 거야, 맞아.",
		"[shy]…근데 네가 진짜로 놀라니까 재미가 없더라. 앞으론 안 할게.",
		"[smile]씨름 한판? 진 사람이 저녁 차리기. 나 오늘 컨디션 좋은데.",
	],
	# ③ 옛 불(그날 밤의 잔재)
	[
		"[sad]가끔 손끝에 불이 켜지려고 해. 자다가. 그럼 얼른 주먹 쥐어.",
		"[talk]안 뜨거워. 진짜야. 근데 이젠 안 뜨거운 게 무서워.",
		"[shy]네가 옆에 있으면 안 켜지더라. 왜 그런지는 나도 몰라.",
		"[smile]괜찮아. 이제 끄는 법도 배웠어. 늦었지만 배웠어.",
	],
	# ④ 진심·애정
	[
		"[shy]야. …아니 부른 거 아니야. 그냥 이름 부르고 싶었어.",
		"[talk]나 요즘 농담 준비를 안 해. 준비 안 해도 할 말이 있더라고.",
		"[smile]평생 장난만 치고 살 줄 알았는데. 이런 것도 있네.",
		"[shy]…사랑한다는 말은 아직 어려워. 대신 매일 옆에 있을게. 그게 내 방식이야.",
	],
]

# ── 훅 구현부(전부 miho.gd와 같은 시그니처) ─────────────────────────────────

# 대화창에 띄울 이름.
func display_name() -> String:
	return "깨비"

# 말 걸었을 때 들려줄 대사 줄들. hearts = 현재 하트 단계, first_today = 오늘 첫 대화인가.
# 오늘 두 번째 이후면 짧은 인사 한 줄(일일 보상은 이미 받음 → Affinity가 막는다).
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

# 배우자 전용 묶음(main이 spouse_id == "kkaebi"일 때 lines() 대신 부른다).
# 축은 **day에서 파생**한다 — 어제 무슨 축이 나왔는지 기억하지 않으므로 상태·세이브 키가 0이다.
# 빈 배열을 돌려주면 main이 평소 lines()로 되돌아간다(이음매 하위호환).
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

# 의지 시험 결과 발화(accepted = 슬롯이 비어 수락됐는가). ★S9b-T6 개통 전까진 휴면.
func confession_lines(accepted: bool) -> PackedStringArray:
	return PackedStringArray(CONFESSION_ACCEPT if accepted else CONFESSION_REJECT)

# 이혼 작별. main은 **첫 줄만** 토스트에 쓴다.
func divorce_lines() -> PackedStringArray:
	return PackedStringArray(DIVORCE_FAREWELL)

# 생일 당일 플레이버(평소 묶음 앞에 선다).
func birthday_lines() -> PackedStringArray:
	return PackedStringArray(BIRTHDAY)

# ── 몸(그레이박스) ──────────────────────────────────────────────────────────
# ★ 정식 시트·초상화는 **S9b-T9 아트 패스** 소관이다(ADR-0068 Consequences). 파일이 없으면
#   CharSprite.make가 null을 돌려주므로 그때까진 아래 그레이박스가 그려진다(모찌 선례 동형).
var _sprite: AnimatedSprite2D = null

func _ready() -> void:
	_sprite = CharSprite.make("res://assets/characters/kkaebi.png")
	if _sprite != null:
		add_child(_sprite)

# ★ [S2-T7] 보간 걷기 시각 오프셋(ResidentWalk가 채운다 — resident_walk.gd). 논리 위치(position)는
# 스테이션 칸으로 즉시 스냅하고(말 걸기 판정·헤드리스 테스트가 보는 값 불변), *그림만* 이만큼 뒤로
# 밀어 길 스포크를 따라 걸어온 것처럼 보이게 한다. 주민 프레임워크 공통 규약이라 새 주민 캐릭터
# 파일도 이 블록을 그대로 복사한다(miho.gd·mochi.gd 동형).
var walk_offset := Vector2.ZERO

func set_walk_offset(v: Vector2) -> void:
	if walk_offset == v:
		return
	walk_offset = v
	if _sprite != null:
		_sprite.position = v   # 도색 스프라이트는 자식 노드 → 자식 위치로 민다
	queue_redraw()             # 그레이박스는 _draw의 draw_set_transform으로 민다

# 실루엣 설계([residents.md] "능글 미소·장난기 눈빛의 쾌남" + 씨름·괴력·방망이):
#   ㉠ **어깨가 제일 넓다** — 몸통 폭은 규격(16)을 지키되 어깨 띠를 좌우로 2px씩 내밀어 다른
#      그레이박스(마른 사각 몸)와 위쪽 윤곽부터 갈린다. 이 캐릭터의 첫인상은 힘이다.
#   ㉡ **뿔 하나**(외뿔) — 도깨비 표식. 좌상으로 비스듬해 장난기가 실루엣에 남는다.
#   ㉢ **방망이** — 몸 뒤로 어깨에 걸친 굵은 몽둥이(무골의 대검과 반대 방향 사선).
#   ㉣ ⚠️ **불 색을 안 쓴다** — [residents.md] 가드레일(불=백스토리 한정·미호 여우불과 분리)을
#      실루엣 층에서도 지킨다. 몸은 짙은 청록, 뿔·띠만 흙빛이다.
const _HORN_H := 6.0        # 뿔 길이
const _SHOULDER := 2.0      # 어깨가 몸통 밖으로 내미는 폭(좌우 각각)
const _CLUB_LEN := 20.0     # 어깨에 걸친 방망이 길이

func _draw() -> void:
	draw_set_transform(walk_offset)   # ★ [S2-T7] 보간 걷기: 그레이박스 그림 전체를 오프셋만큼 민다
	if _sprite != null:
		return  # 도색 스프라이트가 있으면 그레이박스는 안 그린다(폴백 전용)
	var top := -BODY_SIZE.y
	# 방망이(몸 뒤) — 왼쪽 아래에서 오른쪽 위로 솟는 굵은 사선 + 끝의 옹이 혹. 몸보다 먼저 그린다.
	var grip := Vector2(-6.0, top + 22.0)
	var head := grip + Vector2(_CLUB_LEN * 0.55, -_CLUB_LEN)
	draw_line(grip, head, Color(0.42, 0.32, 0.22), 4.0)
	draw_circle(head, 3.0, Color(0.50, 0.38, 0.26))
	# 몸통: 발치 원점 기준 위로 16×32. 짙은 청록 저고리(불 색 회피 — 위 ㉣).
	var body := Rect2(-BODY_SIZE.x * 0.5, top, BODY_SIZE.x, BODY_SIZE.y)
	draw_rect(body, Color(0.16, 0.34, 0.33))
	# NW 광원(asset-ruleset §NW): 왼쪽 결에 밝은 띠 한 줄.
	draw_rect(Rect2(body.position.x, top + 12.0, 3.0, BODY_SIZE.y - 12.0), Color(0.24, 0.46, 0.44))
	# 어깨 띠 — 규격 밖으로 좌우 2px씩 내밀어 "넓은 어깨" 실루엣을 만든다(㉠).
	draw_rect(Rect2(body.position.x - _SHOULDER, top + 10.0,
		BODY_SIZE.x + _SHOULDER * 2.0, 4.0), Color(0.20, 0.40, 0.38))
	# 허리띠 — 흙빛. 상·하체를 나눠 납작한 색면을 깬다.
	draw_rect(Rect2(body.position.x, top + 21.0, BODY_SIZE.x, 3.0), Color(0.46, 0.33, 0.20))
	# 머리 — 흙빛 피부의 둥근 덩이(사람형보다 큼직하게 = 우락부락).
	var head_c := Vector2(0.0, top + 5.0)
	draw_circle(head_c, 6.0, Color(0.56, 0.42, 0.32))
	# 외뿔(㉡) — 좌상으로 비스듬한 짧은 사선.
	draw_line(head_c + Vector2(-2.5, -4.5), head_c + Vector2(-4.5, -4.5 - _HORN_H),
		Color(0.34, 0.25, 0.17), 3.0)
	# 눈 둘(장난기 — 가늘게 뜬 선 눈) + 웃는 입 한 줄.
	draw_rect(Rect2(head_c + Vector2(-4.0, -1.5), Vector2(3.0, 1.5)), Color(0.12, 0.10, 0.09))
	draw_rect(Rect2(head_c + Vector2(1.0, -1.5), Vector2(3.0, 1.5)), Color(0.12, 0.10, 0.09))
	draw_rect(Rect2(head_c + Vector2(-2.5, 2.5), Vector2(5.0, 1.0)), Color(0.12, 0.10, 0.09))
