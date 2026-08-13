extends RefCounted
class_name Spine
# ★[S9b-T7 / ADR-0068 결정 8] 척추 해결 게이트 + B5 재구성의 **데이터·판정** 소유자.
#
# 목적: [narrative-bible §6.1]의 해결 게이트
#     `AND(세 조각 ♡4) + 공허 비트(B4) + 조연 11인 전원 ♡3 그날밤 고백`
#   을 코드로 세우고, 그 게이트가 열었을 때 §6.5의 B5 클라이맥스 시퀀스가 쓸 재료(파편 15·
#   내면 지문·별자리 배치)를 한곳에 든다.
#
# 설계 메모(deed.gd 규범 그대로 — 이 코드베이스의 확립 관례):
#   - **순수 static 판정이다.** 상태를 하나도 안 든다. 원장(하트 단계·비트 원장·척추 비트)의
#     주인은 여전히 main이고, 여기는 명단표와 비교식뿐이다. 그래서 테스트가 main 없이도
#     `Spine.gate_terms(...)`에 dict 세 개를 던져 게이트 전수를 잰다.
#   - **B4 비트 번호를 모른다.** 게이트의 둘째 항은 `void_seen: bool`로 *주입*받는다 —
#     `SPINE_B4`의 주인은 main이고(S9b-T4가 세운 원장), 여기가 그 숫자를 복사해 들면
#     비트 번호가 두 곳에 살게 된다(단일 출처 위반).
#   - **재구성 퍼즐의 상태 머신은 여기 없다** — `spine_puzzle.gd`(SpineReconstruction)가 그
#     규범(FishingSession·CutsceneRunner)을 따로 잇는다. 판정(static)과 기계(RefCounted 상태)는
#     이 코드베이스에서 늘 파일이 갈렸고(deed.gd ↔ fishing.gd), 척추도 그 결을 따른다.
#   - **화면을 모른다.** 별자리 배치는 −1..1 단위 좌표를 돌려줄 뿐이고 px 환산·색은 main이 한다
#     (CutsceneRunner가 타일 좌표만 알고 TILE을 모르는 것과 같은 분업).
#
# ── ★ 봉인의 법칙([narrative-bible §2.2] · [ADR-0016]) — 이 파일의 텍스트 제약 ──────────
# B5는 **플레이어가 스스로 잇는 장면**이지 누가 말해 주는 장면이 아니다. 그래서:
#   ㉠ 이 파일의 본문에는 **화자가 없다**(내면 지문 — B4가 main에서 그랬던 것과 같은 소유 근거).
#   ㉡ **중심 진실은 한 줄도 안 나온다** — "당신이었군요"를 비롯한 회수는 전부 **B6(S9b-T8) 소유**다.
#      B5가 하는 일은 *모양이 맞물렸다*까지고, *그 모양이 누구인가*는 다음 비트가 연다.
#   ㉢ **「옥자」가 0회** 등장한다(강림 파일과 같은 기계 프록시 — 중심 진실 4종이 전부 그 명명을
#      요구하므로, 전면 무호명이 가장 강한 가드다). spine_test가 이것을 잰다.
#   ㉣ 🟡 **확증선(§5.2 "끄덕임만")이 여기서 구현된다** — [ADR-0068] 결정 8이 그 자리를 B5로
#      배정했고 gangrim.gd 머리말 ㉣이 그것을 예약 주석으로 남겼다. 강림 파편의 지시는
#      **전부 지문**이다: 「」로 묶인 대사가 0줄이고, 그를 호명하지도 않는다("그림자"까지).
#      말을 시키는 순간 봉인의 법칙이 깨지고(타인의 말로 풀림) 그의 🔴 4종 경계도 무너진다.

# ── ① 로스터 — 안전장치 ㉑ 「로스터 고정」([narrative-bible §6.2]) ─────────────────
# ★ **박제 상수다.** main의 `CHORUS_GATE_ROSTER`(소프트 게이트 ㉠의 명단)와 지금은 같은 11인이지만
#   **자동 추종하지 않는다** — 그것이 ㉑의 목적이다. 저쪽은 "♡3 고백에 스포일러 순서를 거는 명단"이라
#   조연이 늘면 같이 늘어야 하고, 이쪽은 "엔딩이 요구하는 증거 명단"이라 **늘면 안 된다**(추후 조연을
#   더할 때마다 엔드게임 요구가 커지면 척추가 영영 안 닫힌다. §6.2 "척추 요구가 무한정 안 커지게").
#   그래서 두 배열은 지금 같은 값이고 앞으로 갈라지는 것이 정상이며, spine_test는 "박제 ⊆ 레지스트리"
#   방향으로만 정합을 잰다(같음이 아니라 부분집합 — 갈라짐을 허용하는 단언).
# ★ **점주 5인(T2 — 뱃사공·옹이·풀무·무골·주방요괴)은 요구 밖**이다. 그들에겐 그날 밤 고백 자체가
#   없다(§5.4 티어). 옥자도 밖이다 — 옥자 트랙은 B6 *후*에 열린다([ADR-0068] 결정 10).
const T1_ROSTER := ["mochi", "neo", "kkaebi", "ken", "seolhwa", "scarlet", "mir", "luca",
	"frosty", "gangrim", "serena"]
# 세 조각(B1~B3)의 주인 — 메인 3인. 조연이 *그날 밤 증거*를 대고 이쪽이 *죄의 열쇠*를 댄다(§6.1).
const MAIN_ROSTER := ["miho", "mel", "bana"]

const MAIN_STAGE := 4        # 세 조각 = ♡4 완전체 조각(♡3 씨앗으론 안 된다 — §6.1)
const CHORUS_HEART := 3      # 조연 = ♡3 그날 밤 고백(§6.2)

# ── ② 게이트 판정(순수 static) ────────────────────────────────────────────────
# 세 항을 **이름 붙여** 따로 돌려준다 — 한 bool로 접으면 "무엇이 안 찼는지"가 코드에서 사라지고,
# 테스트도 항을 하나씩 빼며 재기 어려워진다(강림 4축 가드를 축별로 나눈 것과 같은 설계).
#   main_stages : {rid: stage} — 메인 3인의 하트 칸(main이 Resident에서 떠 넘긴다)
#   void_seen   : B4 공허 비트가 섰나(비트 번호의 주인은 main — 위 머리말 참조)
#   heart_bits  : {rid: 비트마스크} — main `_heart_bits` 원장 그대로(비트 N = ♡N 관문을 봤다)
static func gate_terms(main_stages: Dictionary, void_seen: bool, heart_bits: Dictionary) -> Dictionary:
	var keys := true
	for rid in MAIN_ROSTER:
		if int(main_stages.get(rid, 0)) < MAIN_STAGE:
			keys = false
			break
	var chorus := true
	for rid in T1_ROSTER:
		if (int(heart_bits.get(rid, 0)) & (1 << CHORUS_HEART)) == 0:
			chorus = false
			break
	return {"keys": keys, "void": void_seen, "chorus": chorus}

# 세 항의 AND. 대안(OR·threshold)은 "한 명 스킵"이 생겨 §6.1이 명시적으로 기각했다.
static func gate_ok(main_stages: Dictionary, void_seen: bool, heart_bits: Dictionary) -> bool:
	var t := gate_terms(main_stages, void_seen, heart_bits)
	return bool(t["keys"]) and bool(t["void"]) and bool(t["chorus"])

# ── ③ 파편 15 — 재구성이 이을 것들(§6.5 3) ────────────────────────────────────
# **수를 쓰지 않는다.** 15는 `메인 3 + 조연 11 + 자신의 공허 1`에서 파생되고, 로스터가 바뀌면
# 파편 수도 같이 바뀐다(하드코딩 산술 금지 — 지시서 계약). 그래서 아래 어디에도 리터럴 15가 없다.
const KIND_KEY := "key"      # 메인 세 조각(♡4) — *죄의 열쇠*
const KIND_ECHO := "echo"    # 조연 11 증거(♡3) — *그날 밤 파편*
const KIND_VOID := "void"    # 자신의 공허(B4) — 다른 전부가 여기로 모인다

# 허브(자기 공허)는 **언제나 0번**이다 — 배치·퍼즐이 "가운데가 나"를 인덱스로 알아야 하는데,
# 이름으로 찾게 하면 두 파일이 문자열 하나로 묶인다.
const HUB_INDEX := 0

static func fragment_count() -> int:
	return MAIN_ROSTER.size() + T1_ROSTER.size() + 1

# 파편 표 — [{kind, rid, heart}]. rid가 빈 것이 공허(그건 사람이 아니라 나 자신이라 rid가 없다).
# heart는 그 파편이 어느 칸에서 왔는지의 **유래**다(공허는 −1 — 하트 축이 아니라 척추 비트에서 왔다).
static func fragments() -> Array:
	var out: Array = []
	out.append({"kind": KIND_VOID, "rid": "", "heart": -1})   # ★ 0번 = 허브
	for rid in MAIN_ROSTER:
		out.append({"kind": KIND_KEY, "rid": String(rid), "heart": MAIN_STAGE})
	for rid in T1_ROSTER:
		out.append({"kind": KIND_ECHO, "rid": String(rid), "heart": CHORUS_HEART})
	return out

# ── ④ 별자리 배치(순수 수학 — 단위 좌표 −1..1) ────────────────────────────────
# 허브는 한가운데, 나머지는 두 겹 고리에 고르게 앉힌다(안쪽 절반·바깥 절반, 바깥은 반 칸 어긋나게
# 돌려 두 겹이 겹쳐 보이지 않게). 결정적 순수 함수라 같은 인덱스는 언제나 같은 자리다 —
# 이 자리가 흔들리면 "그때 그 별"이라는 기억이 성립하지 않는다.
static func star_pos(i: int, count: int) -> Vector2:
	if i <= HUB_INDEX or count <= 1:
		return Vector2.ZERO
	var outer := count - 1                 # 허브를 뺀 파편 수
	var k := i - 1                         # 0..outer-1
	var inner_n: int = outer / 2           # 안쪽 고리 정원
	var on_inner := k < inner_n
	var n: int = inner_n if on_inner else outer - inner_n
	if n <= 0:
		return Vector2.ZERO
	var j: int = k if on_inner else k - inner_n
	var ang := TAU * float(j) / float(n) - TAU * 0.25   # −90° = 첫 별이 정북(밤하늘 결)
	if not on_inner:
		ang += TAU / float(n) * 0.5        # 바깥 고리를 반 칸 돌려 안쪽과 안 겹치게
	return Vector2(cos(ang), sin(ang)) * (0.46 if on_inner else 0.92)

# ── ⑤ 본문 — 전부 **화자 없는 내면 지문**(위 머리말 ㉠) ────────────────────────
# 이름판을 비우면 초상화 슬롯이 저절로 접힌다(main `_set_portrait`) — 내면에는 이름이 없다는 것을
# 이름판 한 칸으로 말한다(B4가 세운 문법 그대로).
const INNER_SPEAKER := ""

# 발동 컷신(연출 등급 2 · **4동사 한정** · npc 동사 0). §6.5 1~2단의 이행:
# 소음이 죽고(clock 정지) 시야가 한 번 들리다가(cam) 어둠이 위에서부터 덮는다(fade).
# 카메라는 암전 뒤에서만 되돌린다(컷신 규약 — 여기선 NPC가 없어 위반 여지 자체가 0이다).
const B5_CUTSCENE := [
	{"verb": "clock", "running": false},
	{"verb": "cam", "offset": Vector2(0, -12), "secs": 1.2},
	{"verb": "fade", "to": 1.0, "secs": 1.6},
	{"verb": "cam", "offset": Vector2(0, 0)},
]

# 내면 공간이 열리는 지문. **§6.5 2단이 요구한 그 순서**(소음 소거 → 적막 → 공허 → 암전)를
# 텍스트가 한 번 더 밟는다 — 연출 4동사로는 "소리가 사라졌다"를 말할 수 없기 때문이다.
# 마지막 줄이 이 장면의 계약이다: **아무도 이어 주지 않는다**(§2.2 봉인의 법칙의 인-픽션 선언).
const B5_OPEN_LINES := [
	"(문 앞에 서자, 소리가 한 겹씩 벗겨진다)",
	"바람이 멎고, 벌레 울음이 멎고, 마침내 내 발소리마저 멎는다.",
	"…들리는 것이 하나도 없다.",
	"(가슴 한가운데의 빈자리가 천천히 벌어진다. 그 아침에 이름 붙이지 못한 그 자리다)",
	"어둠이 위에서부터 내려와 눈앞을 덮는다. 이상하게도 무섭지 않다.",
	"(빈자리 안쪽에, 그동안 받아 든 것들이 하나씩 떠오른다. 밤하늘처럼)",
	"세 사람이 건넨 열쇠. 열한 사람이 흘린 조각. 그리고 한가운데, 나 자신의 구멍.",
	"…아무도 이어 주지 않는다. 이건 내 손으로 해야 한다.",
]

# ★ 🟡 확증선 — **강림 안전장치**(§6.5 4 · [ADR-0068] 결정 8 · gangrim.gd 머리말 ㉣의 예약).
# 소프트락 방지책이되 그 형식이 이 세계의 규칙에 묶여 있다: 그는 전부 알지만 **입을 열 수 없다.**
#   · 전 줄이 **지문**이다 — 「」로 묶인 대사가 0줄(있으면 그 순간 봉인의 법칙이 깨진다).
#   · **호명하지 않는다** — "그림자"까지다. 이름을 부르면 이 지문이 강림의 발화로 읽힌다.
#   · 정보를 주지 않는다 — 지시하는 것은 *다음 한 점*뿐이고, 그것도 시선과 끄덕임으로만 한다
#     (무엇을·왜는 말하지 않는다. 그건 플레이어가 잇는 것이다).
# 무입력이 이어질 때마다 순서대로 돌려 쓴다(결정적 — 아래 hint_line 참조).
const B5_HINT_LINES = [
	"(빈자리 한편에, 낯익은 그림자가 미동도 없이 서 있다)",
	"(그림자가 고개를 아주 조금 끄덕인다. 시선이 한 점에 머문다)",
	"(입은 열리지 않는다. 열릴 수 없다는 것을 그림자도 알고 있는 얼굴이다)",
	"(시선이 다시 같은 점으로 돌아온다. 그것이 그가 할 수 있는 전부다)",
]

# n번째 지시(0부터)의 지문. 결정적 순환 — 벽시계도 난수도 안 탄다.
static func hint_line(n: int) -> String:
	if B5_HINT_LINES.is_empty():
		return ""
	return String(B5_HINT_LINES[posmod(n, B5_HINT_LINES.size())])

# 마지막 선이 이어진 뒤. **여기서 멈춘다** — 모양이 맞물렸다까지고, 그 모양이 누구인지는
# B6(S9b-T8)가 S등급 컷신으로 연다(위 머리말 ㉡). 마지막 줄이 B6로 넘기는 이음매다:
# §6.4의 대전제 **"본다"가 속죄**를 플레이어의 다음 동사로 세워 둔다.
const B5_DONE_LINES := [
	"(마지막 선이 이어지자, 빈자리가 소리도 없이 갈라진다)",
	"떨어져 있던 것들이 하나의 모양으로 맞물린다. 처음부터 이 모양이었다.",
	"(가라앉아 있던 것이 바닥에서부터 천천히 떠오르기 시작한다)",
	"…아직 이름은 떠오르지 않는다. 그러나 이제 이 자리가 무엇을 잃은 자리인지 안다.",
	"(그림자가 마지막으로 한 번 끄덕이고, 어둠 속으로 물러난다)",
	"…이제, 볼 차례다.",
]
