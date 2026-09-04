extends RefCounted
class_name XpBoost
# ★[S8-T4 / ADR-0066 결정 12] 관계 → **숙련 XP 가속** — 미호(농사)·바나(전투) 공용 규칙.
#
# 목적: ADR-0029의 도메인 당근 표와 코드 사이에 남아 있던 격차 둘을 한 규칙으로 메운다.
#   ㉠ 바나 = `main.narak_bana_xp_mult()`가 **1.0만 돌려주는 빈 함수**였다(S5-T7이 "배선은 S8"
#      이라고 적어 둔 그 예약석). 나락은 바나의 도메인(밤 경비 = 잡귀와 싸워 지켜 주는 속죄)이라
#      전투 XP 가속이 그 자리다.
#   ㉡ 미호 = ADR-0029 표엔 "농사 가속"이 있는데 코드의 여우불은 *작물 성장* 가속이지 XP가 아니다
#      (문서-코드 불일치). 성장 가속과 숙련 XP는 서로 다른 축이라 여우불이 이걸 대신 못 한다.
#
# 설계 메모:
#   - foxfire.gd·cafe_margin.gd·bana_guard.gd·store_discount.gd와 같은 결: **세이브 상태가 아니라
#     정적 참조 규칙**이다. 계수는 하트에서 매번 파생되므로 자체 상태가 0이고, 노드도 아니다
#     (static + class_name — 어디서든 XpBoost.mult(h)).
#   - **두 캐릭터가 한 파일을 공유하는 이유**: ADR-0066 결정 12가 둘을 "동형 1+0.05/♡"로 확정했다.
#     같은 식을 두 곳에 베끼면 한쪽만 튜닝됐을 때 조용히 갈린다 — 진짜로 갈라야 할 날이 오면
#     그때 상수를 캐릭터별로 나누면 된다(지금 나누는 건 앞당긴 복잡도다).
#   - ★ **게이트가 아니라 base 위에 얹는다**(ADR-0008 "평평 ≠ 막힘"): ♡0 = ×1.0이라 관계를 아예
#     안 쌓는 은둔 활동파도 숙련이 정상 속도로 오른다. 관계는 그 위의 *명백히 우월한* 가속이다.
#   - ★ **ADR-0052 경계**: 전문직 트리는 품질·수량·효율·편의만 주고 **+판매가는 관계 곱셈기 전용**
#     이다. 이건 판매가가 아니라 **XP(숙련 진행 속도)** — 전문직도 관계도 아직 안 쓰던 *빈 숫자
#     슬롯*이라 어느 쪽 경계도 침범하지 않는다. (전문직이 나중에 "XP +%" 퍽을 갖게 되면 그건
#     이 계수와 곱해지는 별개 축으로 두면 된다 — 슬롯이 갈려 있으니 충돌하지 않는다.)
#
#   - 매핑(잠정 — owner 큐):
#       계수 = BASE_FACTOR + PER_HEART × 하트 = 1.0 + 0.05 × 하트
#       하트:  0     1     2     3     4     5
#       계수:  1.00  1.05  1.10  1.15  1.20  1.25   (♡5 = 25% 빠른 숙련)
#     store_discount와 대칭인 선형 한 식(부호만 반대 — 할인율은 내리고 가속은 오른다).

const MAX_HEARTS := Affinity.MAX_HEARTS  # 하트 상한(Affinity와 같은 5). 입력을 이 범위로 자름
const BASE_FACTOR := 1.0    # ♡0 = 등속(게이트 아님 — 관계 0에서도 숙련은 정상 진행)
const PER_HEART := 0.05     # 하트당 가속 폭(♡5 = ×1.25)

# 하트 → XP 계수. 범위 밖 입력은 잘라 방어한다(손상 세이브·미등록 주민 0).
static func mult(hearts: int) -> float:
	return BASE_FACTOR + PER_HEART * float(clampi(hearts, 0, MAX_HEARTS))

# XP 정수에 하트만큼의 가속을 얹는다.
static func scaled(amount: int, hearts: int) -> int:
	return scaled_by(amount, mult(hearts))

# 이미 구한 계수로 얹는 갈래 — 바나 쪽은 예약 훅 `main.narak_bana_xp_mult()`이 계수를 들고 오므로
# (S5-T7이 "그 자리는 예약돼 있다"고 남긴 함수) 그 값을 그대로 받는 입구가 필요하다. 반올림 규칙이
# 두 갈래로 갈리지 않게 **정수화는 이 한 곳**에서 한다.
# ★ **반올림**은 main의 기존 배수 처리 관례 그대로(int(round(...)) — 혼력 비용·채광 계수가 쓰는
#   그 방식). 0 이하는 그대로 흘려보낸다(가속할 것이 없다).
static func scaled_by(amount: int, m: float) -> int:
	if amount <= 0:
		return amount
	return int(round(float(amount) * m))

# 관계 탭 한 줄(effect_fn 결).
# ★[폴리시 R19 #5] **호출부가 0이던 자리를 배선했다** — 두 곱셈기는 라이브인데(미호 ♡ → 농사 XP ·
#   바나 ♡ → 나락 전투 XP) 관계 탭이 그리는 줄은 여우불·수호뿐이라, ♡5로 숙련이 25% 빨라지는
#   사실이 게임 안 어디에도 안 떴다. ADR-0008이 관계를 "*항상 명백히 우월한* 가속"으로 규정하는
#   이상 그 우월함은 보여야 한다(광고가 곧 의도된 최적 경로의 안내다).
# ★ `scaled`/`scaled_by`와 **같은 두 갈래 꼴**을 유지한다: 바나 쪽 계수는 예약 훅
#   `main.narak_bana_xp_mult()`이 들고 오므로, 전투 XP 경로가 실제로 쓰는 그 값을 그대로 받는
#   입구가 있어야 표시와 실효가 갈리지 않는다.
static func summary(hearts: int) -> String:
	return summary_by(mult(hearts))

static func summary_by(m: float) -> String:
	return "숙련 ×%.2f" % m
