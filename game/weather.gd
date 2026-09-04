extends RefCounted
class_name Weather
# ★[S7-T3 / ADR-0065 결정 3·4] 저승 날씨 — **세이브 0인 순수 파생 롤**.
#
# 목적: "오늘 하늘이 어떤가"(평온/혼우/잿눈/혼불 바람)를 day 하나에서 파생시키고, 그 결과가
#       기존 시스템들의 *이미 열려 있던 훅*에 곱해질 배수만 든다. 이 파일은 밭도 카페도 갱도도
#       모른다 — 값을 물어보는 쪽(main)이 각 seam에 흘려넣는다.
#
# 설계 메모(어기면 ADR-0065 결정 3 위반):
#   - **무상태 static 규칙**(festival.gd·store_discount.gd·cafe_margin.gd와 같은 결). 상태 변수도
#     시그널도 세이브 키도 0이다. "오늘 날씨"는 매번 day에서 다시 계산된다 — 그래서 세이브를
#     불러도, 되감아도, 헤드리스에서 굴려도 같은 day면 같은 하늘이다.
#   - **RNG 인스턴스를 안 쓴다**(mine_floors·cafe가 쓰는 시드 RNG와 갈리는 지점). 굴릴 값이 날짜당
#     딱 하나라 순차 소비라는 개념 자체가 없다 — RNG를 세우면 "몇 번째 소비냐"라는 없어도 될
#     계약이 생긴다(스트림 어긋남 사고의 씨앗). 대신 시드 → 난수는 전역 `rand_from_seed`로 뽑는다.
#   - ⚠️ **`hash(...) % 100`을 직접 쓰지 말 것**(빌드 중 실측으로 걸러낸 함정). Godot의 문자열 해시는
#     djb2 계열이라 "weather:1"·"weather:2"처럼 **끝자리만 다른 순차 문자열**의 하위 비트가 선형으로
#     남는다. 1..112를 100으로 나눈 실측 분포가 4·7분위에 뭉치고 **6·9분위는 통째로 비어**, 확률
#     5~20%로 배정한 혼불 바람이 1년 내내 한 번도 안 나왔다. `rand_from_seed`(PCG 믹싱)를 한 겹
#     씌우면 같은 시드에서 같은 답을 주면서(결정성 불변) 분포가 균일해진다.
#   - **내일 예보가 공짜다**: forecast(d) = weather_for_day(d+1). 별도 예보 상태·미리 굴려 둔 큐가
#     없다는 뜻이라, T6 점괘 거울은 이 순수 함수를 읽기만 하면 100% 확정 예보를 띄운다.
#   - **모든 세이브가 같은 날씨 열을 본다**(ADR-0065 결정 3이 명시적으로 수용한 성질). 세이브별
#     분기가 필요해지면 시드 문자열에 키 하나를 가법으로 물리면 된다(owner 큐 — 지금은 안 연다).

# ── 날씨 타입(정수 눈금 — 어종 태그·세이브 없는 값 비교에 그대로 쓰인다) ──────
const CALM := 0        # 평온 — 아무 효과 없음(기준선)
const RAIN := 1        # 혼우(비) — 밭 자동 급수 · 낚시 입질↑
const SNOW := 2        # 잿눈 — 노지 성장 정지 · 방목 금지 · 카페 붐빔
const SOULWIND := 3    # 혼불 바람 — 던전 한정(잡귀·드랍·희귀 상향)

const NAMES := ["평온", "혼우", "잿눈", "혼불 바람"]

# ── 절기별 분포(%) — 행 = 절기 인덱스(0 피안·1 유화·2 망연·3 성야), 열 = 위 타입 눈금 ─
# 합은 각 행 100. **성야절 혼우 0**(스타듀 "겨울엔 비가 안 온다" 동형 — 그 몫이 잿눈으로 간다)이고
# **잿눈은 성야절에만** 내린다. 유화절 혼불 바람이 두꺼운 건 "여름 = 혼불이 흔들리는 절기"라는
# CONTEXT 결(던전 대목이 절기로 갈린다 = 절기가 활동 선택을 민다).
# ⚠️ 수치 전부 잠정(ADR-0065 결정 3 — owner 큐). 여기 한 표만 고치면 전 파급이 따라온다.
const DISTRIBUTION := [
	[70, 25, 0, 5],    # 피안절 — 비가 가장 흔한 절기(농사 절기)
	[70, 10, 0, 20],   # 유화절 — 혼불 바람 대목
	[65, 30, 0, 5],    # 망연절 — 비 잦음
	[55, 0, 40, 5],    # 성야절 — 잿눈의 절기(혼우 0)
]

# ── 효과 배수(잠정 — ADR-0065 결정 4의 수치가 여기 한 곳에만 있다) ────────────
const RAIN_BITE := 1.25          # 혼우 낚시 입질 +25%
const SNOW_BITE := 0.85          # 잿눈 낚시 입질 −15%
const SNOW_CAFE_GUESTS := 1.5    # 잿눈 카페 손님 +50%("추워서 카페로 든다")
const SOULWIND_MOB := 1.5        # 혼불 바람 던전 잡귀 스폰 ×1.5
const SOULWIND_DROP := 1.5       # 혼불 바람 던전 드랍 확률 ×1.5
const SOULWIND_RARE := 2.0       # 혼불 바람 던전 희귀 드랍 확률 ×2

# ── 롤 ────────────────────────────────────────────────────────────────────────
# 이 날의 날씨. day는 1부터(0·음수는 평온 — 손상 방어, Festival.is_event_day와 같은 결).
#
# 강제 평온 2종은 분포보다 **먼저** 걸린다(오버라이드):
#   ㉠ 절기 첫날 — 전환일엔 사멸·재스폰이 이미 한 판 벌어지므로 하늘까지 겹치지 않게 비운다.
#   ㉡ 테마 데이 — 축제 당일은 맑아야 무대가 선다.
#
# ★[폴리시 R19 #13] `theme_open` = **그날 테마 데이가 실제로 열리는가**(해금까지 통과했는가).
#   왜 인자로 받나: 종전엔 달력 **슬롯**만 보고 덮었는데(해금 무관) 비해금 슬롯은 플레이어에게
#   완전한 평일이다 — 배너 0·장식 0·프리미엄 전부 1.0. 그런데 하늘만 확률표에서 빠져,
#   혼불 바람 20%(몹 1.5·드랍 1.5·희귀 2.0)와 혼우 10%(밭 자동 급수·입질 1.25)가 절기마다
#   하루씩 통째로 사라졌다. 이 파일과 festival.gd가 나란히 적어 둔 «부작용도 없다 — 누구도 손해
#   보지 않는 무해한 잉여»는 그 세 배수가 존재하는 한 사실이 아니었고, 표시 층도 그 손실을
#   설명하지 못한다(점괘 거울은 "평온"만 확정 통보하고 달력 칸은 비해금 표시 "?"만 찍는다).
#   ★ 무상태는 그대로다 — 이 파일은 여전히 세이브를 모르고, **아는 쪽이 답을 들고 온다**
#     (호출 측 주입 = festival.is_unlocked가 stage·revenue를 인자로 받는 그 문법 1:1).
#   ★ 기본값 true = 종전 거동("슬롯이면 개최로 친다"). 해금 정보를 못 구하는 호출부(순수 파생만
#     쓰는 회귀·도구)는 한 글자도 안 바뀌고, 손실이 실제로 나는 라이브 경로(main)만 참값을 넘긴다.
static func weather_for_day(d: int, theme_open: bool = true) -> int:
	if d <= 0:
		return CALM
	if GameClock.is_season_first_day(d) or (theme_open and _is_theme_day(d)):
		return CALM
	var dist: Array = DISTRIBUTION[GameClock.season_index_for_day(d)]
	var r := absi(rand_from_seed(hash("weather:%d" % d))[0]) % 100
	var acc := 0
	for w in dist.size():
		acc += int(dist[w])
		if r < acc:
			return w
	return CALM   # 분포 합이 100 미만인 표를 넣었을 때의 방어(현 표에선 도달 불가)

# ★[S7-T6 / ADR-0065 결정 8] 오늘이 테마 데이(메이드·바캉스·힙합·크리스마스) 자리인가 — 그날은
#   분포를 무시하고 평온으로 못 박는다("당일 강제 평온"). T3의 스텁이 여기서 Festival 위임으로
#   실효화됐다.
#
# ★ **달력 슬롯만 본다**(Festival.is_theme_slot — 해금 무관). 해금은 세이브 상태에 걸려 있는데
#   이 파일은 세이브를 모르는 순수 파생 롤이라, 슬롯 판정만 여기 두고 **개최 여부는 위
#   `weather_for_day`가 인자로 받는다**(폴리시 R19 #13).
# ⚠️ 종전 주석이 «부작용은 없다 … 손해 보는 것이 없다»고 단정했는데 **사실이 아니었다**: 아래
#   SOULWIND_* 셋과 혼우의 `waters_field`·RAIN_BITE가 실효 이득이라, 비해금 슬롯을 덮으면
#   절기마다 하루씩 그 이득이 사라졌다. 그 오판이 이 파일 안에서 다시 인용되지 않게 남긴다.
# ⚠️ 방향이 한쪽이다: Weather → Festival → GameClock. Festival이 Weather를 되짚어 참조하면
#   순환이 되므로 축제 쪽에 날씨 조건을 붙이지 말 것(테마 데이는 어차피 항상 평온이라 필요도 없다).
static func _is_theme_day(d: int) -> bool:
	return Festival.is_theme_slot(d)

# 내일 날씨(예보). 별도 상태가 없어 하루 앞을 그냥 굴려 보면 끝이다 — T6 점괘 거울의 입력.
# ★[폴리시 R19 #13] `theme_open`을 그대로 넘긴다 — 예보와 실제가 갈릴 자리를 안 만든다.
static func forecast(d: int, theme_open: bool = true) -> int:
	return weather_for_day(d + 1, theme_open)

# 표시명("" = 범위 밖). GameClock.season_name과 같은 관례.
static func name_of(w: int) -> String:
	return NAMES[w] if w >= 0 and w < NAMES.size() else ""

# ── 효과 조회(소비처가 값 하나만 물어보게 하는 얇은 표면) ──────────────────────
# 밭을 적시는 하늘인가 — 혼우면 아침에 밭 전 경작 칸이 젖는다(스프링클러와 멱등).
static func waters_field(w: int) -> bool:
	return w == RAIN

# 오늘 노지 작물이 자라는가 — 잿눈이면 성장이 하루 멈춘다(**죽지는 않는다** — 비살상, 결정 4).
static func grows_crops(w: int) -> bool:
	return w != SNOW

# 오늘 짐승을 방목하는가 — 잿눈만 금지다. 스타듀는 비에도 가축을 안 내보내지만, 우리 혼우는
# "밭이 젖는 고마운 비"라 실외 활동을 통째로 접게 하면 비 오는 날이 순손실만 남는다(결정 4가
# 잿눈만 지목한 이유). 눈 덮인 방목지에 짐승을 세워 두지 않는 것으로 족하다.
static func allows_grazing(w: int) -> bool:
	return w != SNOW

# 낚시 입질 대기 배수(작을수록 빨리 문다). 혼우 = 1/1.25 = 0.8배 대기 · 잿눈 = 1/0.85 ≈ 1.18배 대기.
# ★ "입질 확률"이라는 축이 FishingSession에 없다 — 입질은 *대기 시간*으로 표현된다(WAIT_MIN~MAX).
#   그래서 확률 +25%를 대기 −20%로 옮겨 싣는다(기대 입질 빈도가 같은 비율로 오른다).
static func bite_wait_factor(w: int) -> float:
	match w:
		RAIN:
			return 1.0 / RAIN_BITE
		SNOW:
			return 1.0 / SNOW_BITE
	return 1.0

# 카페 손님 스폰 **간격** 배수(작을수록 붐빔 — cafe.spawn_scale의 눈금). 잿눈이면 손님이 1.5배
# 들어오므로 간격은 그 역수다. ⚠️ 이 값은 _refresh_cafe_ladder의 **단일 곱 자리**에서만 쓴다
# (축제 × 단계 × 날씨 — 따로 대입하면 먼저 쓴 값이 지워진다. 그 사고 주석이 main에 박혀 있다).
static func cafe_spawn_scale(w: int) -> float:
	return 1.0 / SNOW_CAFE_GUESTS if w == SNOW else 1.0

# 던전 잡귀 스폰 마리 수 배수(갱도·나락 공용). 혼불 바람 = ×1.5.
static func mob_spawn_scale(w: int) -> float:
	return SOULWIND_MOB if w == SOULWIND else 1.0

# 던전 드랍 확률 배수(일반 항목). 혼불 바람 = ×1.5.
static func drop_scale(w: int) -> float:
	return SOULWIND_DROP if w == SOULWIND else 1.0

# 던전 **희귀** 드랍 확률 배수. 혼불 바람 = ×2(일반보다 더 크게 — "혼불이 부는 밤에만 나오는 것").
static func rare_drop_scale(w: int) -> float:
	return SOULWIND_RARE if w == SOULWIND else 1.0
