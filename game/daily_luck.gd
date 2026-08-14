extends RefCounted
class_name DailyLuck
# ★[S7-T4 / ADR-0065 결정 5] 명부의 운 — **세이브 0인 순수 파생 롤**.
#
# 목적: "오늘 명부가 나를 어떻게 보는가"를 day 하나에서 파생시키고, 그 결과를 *플레이어 액션의
#       확률*에만 가법으로 얹는다. 이 파일은 갱도도 밭도 낚시터도 모른다 — 값을 물어보는 쪽
#       (main)이 각 seam에 계수를 곱해 흘려넣는다(weather.gd와 정확히 같은 결).
#
# 설계 메모(어기면 ADR-0065 결정 5 위반):
#   - **무상태 static 규칙**(weather.gd·festival.gd와 같은 결). 상태 변수도 시그널도 세이브 키도
#     0이다. "오늘의 운"은 매번 day에서 다시 계산된다 — 세이브를 불러도, 되감아도, 헤드리스에서
#     굴려도 같은 day면 같은 운이다.
#   - ⚠️ **`hash(...) % N`을 직접 쓰지 말 것** — weather.gd 헤더가 실측으로 박제한 함정이다.
#     Godot 문자열 해시는 djb2 계열이라 "luck:1"·"luck:2"처럼 끝자리만 다른 순차 문자열의 하위
#     비트가 선형으로 남아 특정 분위가 통째로 빈다. `rand_from_seed`(PCG 믹싱)를 한 겹 씌우면
#     같은 시드에서 같은 답을 주면서(결정성 불변) 분포가 균일해진다. 여기선 그 함정이 곧 "대길이
#     1년에 한 번도 안 뜬다"로 나타나므로 날씨보다 더 치명적이다.
#   - **수치는 UI에 절대 노출하지 않는다**(CONTEXT [명부의 운] "내부 연산은 숨김"). 점괘 거울이
#     읽는 표면은 `grade_of` → `grade_name`/`fortune_line`뿐이고, ±0.037 같은 값은 화면에 안 뜬다.
#     스타듀 Fortune Teller가 "정령들이 아주 기뻐한다"만 말하고 숫자를 안 보여 주는 것과 같다.
#   - **월드 결정성 침해 금지**: 배선은 *플레이어가 굴리는 액션 롤*에만 붙는다. 스폰·배치·작물
#     성장에 운을 섞으면 "그날의 층·그날의 밭"이 운에 따라 갈려 결정성 계약이 깨진다.

# ── 진폭·문턱(스타듀 Fortune Teller 동형) ───────────────────────────────────
const SPREAD := 0.10        # 롤 진폭 — 결과는 −0.10 ~ +0.10 균등
const T_GREAT := 0.07       # 대길/대흉 문턱(|v| ≥ 0.07)
const T_GOOD := 0.02        # 길/흉 문턱(|v| ≥ 0.02)

# ── 등급 눈금(오름차순 = 좋을수록 큰 수. 비교 연산이 그대로 "더 좋은 날"이 된다) ──
const TERRIBLE := 0   # 대흉
const BAD := 1        # 흉
const PLAIN := 2      # 평
const GOOD := 3       # 길
const GREAT := 4      # 대길

const GRADE_NAMES := ["대흉", "흉", "평", "길", "대길"]

# 점괘 한 줄(무녀 옥자 결 — 등급당 1문장). 등급명과 짝지어 거울에 뜬다.
# ★ 숫자를 암시하는 표현("+7%" 따위)은 넣지 않는다 — 문구가 곧 유일한 노출 표면이다.
const FORTUNE_LINES := [
	"혼들이 등을 돌린 날 — 오늘은 무리하지 않는 편이 낫겠다",
	"명부의 붓끝이 무디다 — 손에 잡히는 것이 적은 날",
	"명부는 오늘 아무 말이 없다 — 여느 날과 같다",
	"혼들이 곁에서 웃는다 — 손끝이 가벼운 날",
	"혼들이 크게 웃는 날 — 무엇을 하든 명부가 편을 든다",
]

# ── 배선 계수(ADR-0065 결정 5의 6지점 — 수치가 여기 한 곳에만 있다) ──────────
# 읽는 법: 각 지점의 확률에 `luck_for_day(day) * 계수`를 **가산**한다(곱이 아니다). 계수 0.5 =
# 대길 날 +5%p·대흉 날 −5%p. 사다리만 1.0인 건 스타듀가 운을 사다리 확률에 원배율로 얹기 때문이고,
# 그 지점이 "운 좋은 날엔 깊이가 술술 내려간다"는 체감의 주인공이라서다.
# ⚠️ 수치 전부 *잠정*(ADR-0065 결정 5 — owner 큐).
const W_LADDER := 1.0     # ① 갱도·나락 사다리 발견
const W_GEODE := 0.5      # ② 지오드 개봉 2배
const W_MOB_DROP := 0.5   # ③ 잡귀 드랍
const W_CHOP := 0.5       # ④ 벌목 보너스(단단한 원목·씨앗)
const W_SALVAGE := 0.5    # ⑤ 낚시 인양
const W_CROP := 0.5       # ⑥ 작물 다수확 yield

# ── ★[S10-T4 / ADR-0069 결정 7] 하한 보정 — [삽사리] 만점 보상의 유일한 이음매 ──────
# CONTEXT [삽사리]: "다 채우면 [명부의 운]의 *바닥*을 한 눈금 덜어 준다(대흉 완화)."
#
# ★ **평균을 올리지 않는다**는 것이 이 훅의 계약이고, 그래서 [ADR-0019] "영구 % 곱셈 금지"에
#   안 걸린다. 구현이 그 계약을 **구조로** 보증한다:
#     · 대흉이 아닌 날 → **early return v**(등급 판정 한 번 뒤 원값 그대로 — 비교조차 안 한다)
#     · 대흉 날만 → 하한 눈금으로 올려 **흉**이 된다(바닥이 덜 아프다)
#   즉 보정이 닿는 구간은 대흉 등급 하나뿐이고, 좋은 날은 좋아지지 않는다.
#   ⚠️ `maxf(v, FLOOR)` 한 줄로 쓰면 안 된다 — 이미 흉인 날 중 값이 하한보다 살짝 낮은 것들이
#      **함께 끌려 올라가** 평균이 미세하게 오른다(pet_test ③d가 2,000일 전수로 이 구멍을 잡았다).
#      "등급을 한 눈금 올린다"는 계약은 값 비교가 아니라 **등급 분기**로 써야 정확하다.
# ★ 하한값을 `−T_GREAT + FLOOR_EPS`로 잡은 이유: `grade_of`의 대흉/흉 경계가 `v > −T_GREAT`
#   (위쪽이 가져간다)라, 정확히 −T_GREAT을 주면 여전히 대흉으로 떨어진다. 눈금 하나만큼 넘긴다.
# ★ **무상태 static 규칙 불변**: 삽사리 원장을 참조하지 않는다 — 소비처(main)가 그 원장의
#   `luck_floor_active()`를 읽어 bool 하나만 흘려넣는다(weather.gd가 밭을 모르는 그 결).
const FLOOR_EPS := 0.001
const FLOOR_MITIGATED := -T_GREAT + FLOOR_EPS    # = −0.069(흉의 가장 아래 눈금)

# 값에 하한을 얹는다(mitigated == false면 항등 함수 — 기본 거동은 한 줄도 안 바뀐다).
static func floor_luck(v: float, mitigated: bool) -> float:
	if not mitigated or grade_of(v) != TERRIBLE:
		return v
	return FLOOR_MITIGATED

# ── 롤 ────────────────────────────────────────────────────────────────────────
# 이 날의 명부의 운(−0.10 ~ +0.10 균등). day는 1부터 — 0·음수는 0.0(손상 방어, Weather와 같은 결).
# ★ 10001단계 정수 격자로 뽑아 float 나눗셈 한 번만 태운다(부동 오차가 문턱 판정을 흔들지 않게).
# ★[S10-T4] `mitigated` 기본값 false — 인자를 안 넘기는 기존 호출부는 바이트 단위로 같은 답을
#   받는다(삽사리가 없는 세이브·기존 회귀가 그대로 통과하는 근거).
static func luck_for_day(d: int, mitigated: bool = false) -> float:
	if d <= 0:
		return 0.0
	var r := absi(rand_from_seed(hash("luck:%d" % d))[0]) % 10001   # 0..10000
	return floor_luck(float(r) / 10000.0 * (SPREAD * 2.0) - SPREAD, mitigated)

# 값 → 5등급. 경계는 **위쪽이 가져간다**(v == +0.07 → 대길 · v == −0.02 → 흉). 스타듀 문턱과
# 동형이고, 어느 쪽이 먹는지를 못 박아 두면 테스트가 경계값을 그대로 단언할 수 있다.
static func grade_of(v: float) -> int:
	if v >= T_GREAT:
		return GREAT
	if v >= T_GOOD:
		return GOOD
	if v > -T_GOOD:
		return PLAIN
	if v > -T_GREAT:
		return BAD
	return TERRIBLE

# 이 날의 등급(편의 — 거울·HUD가 값을 손에 쥐지 않게 한다).
static func grade_for_day(d: int, mitigated: bool = false) -> int:
	return grade_of(luck_for_day(d, mitigated))

# 등급 표시명("" = 범위 밖). Weather.name_of·GameClock.season_name과 같은 관례.
static func grade_name(g: int) -> String:
	return GRADE_NAMES[g] if g >= 0 and g < GRADE_NAMES.size() else ""

# 등급의 점괘 한 줄("" = 범위 밖).
static func fortune_line(g: int) -> String:
	return FORTUNE_LINES[g] if g >= 0 and g < FORTUNE_LINES.size() else ""

# 거울에 뜨는 오늘의 운 두 줄("명부의 운: 대길" + 점괘). **수치 없음**이 이 함수의 계약이다.
# ★[S10-T4] 거울도 보정된 등급을 읽는다 — 삽사리가 대흉을 흉으로 덜어 준 날 거울만 "대흉"이라
#   말하면 화면과 실제 확률이 어긋난다(점괘 거울은 그날의 *실효* 운을 말하는 창구다).
static func fortune_text(d: int, mitigated: bool = false) -> String:
	var g := grade_for_day(d, mitigated)
	return "명부의 운 — %s\n%s" % [grade_name(g), fortune_line(g)]

# ★ 다수확 yield 롤의 운 바이어스(순수 함수 — ADR-0065 결정 5 ⑥).
#   이미 뽑힌 균등 롤 결과 `count`를 [lo, hi] 안에서 한 칸 밀지 말지만 정한다. 범위를 넘는 값은
#   절대 안 나온다(운이 새 산출 규칙을 만들지 않는다는 계약이 여기 한 줄로 박힌다).
#   ★ 난수 `r`(0..1)을 **인자로 받는다**: 롤을 이 안에서 굴리면 "운 0이면 소비 0"이라는 스트림
#     계약이 호출 측 눈에서 사라진다. 소비 지점은 호출 측에 남기고 판정만 여기서 한다.
static func biased_yield(count: int, lo: int, hi: int, luck: float, r: float) -> int:
	if hi <= lo or is_zero_approx(luck):
		return count                       # 단수확 작물·무운은 통째로 면제
	if luck > 0.0 and count < hi and r < luck:
		return count + 1
	if luck < 0.0 and count > lo and r < -luck:
		return count - 1
	return count

# 이 지점에 얹을 가산값(luck × 계수). 소비처가 계수 상수를 직접 곱하지 않고 이 한 줄만 부르면
# 되게 하는 얇은 표면 — 계수의 주인이 이 파일 하나로 남는다.
static func bonus_for_day(d: int, weight: float, mitigated: bool = false) -> float:
	return luck_for_day(d, mitigated) * weight
