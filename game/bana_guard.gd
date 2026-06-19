extends RefCounted
class_name BanaGuard
# T6.5 — 바나 관계 보상축 = 이중 보호 축(관계 곱셈기, ADR-0008·ADR-0010 #7): 바나 호감도
#        하트 → 밤 경비의 두 손실에 대응하는 *이중* 보호. 미호=자동화(여우불)·멜=마진(카페)과
#        *종류*가 다른 세 번째 곱셈기 = **손실 방지/안전망**(같은 +% 반복 = 그라인드를 회피).
#
# 목적: ROADMAP T6.5 — "바나 ♡↑일수록 약탈 재고량↓·창고 잡귀 자동 차단↑(㉠)·카운터 빈
#       사이 손님 인내심↑(㉡)이 체감되고, ♡0에서도 밤은 base로 굴러간다"의 그 매핑을 한 곳에
#       정의한다. ADR-0010 #7의 이중 축을 그대로 옮긴다(밤의 이중 손실 — 막기 실패→재고 약탈/
#       응대 실패→현장 매출 이탈 — 에 각각 대응하는 보호).
#
# 설계 메모:
#   - foxfire.gd(Foxfire)·cafe_margin.gd(CafeMargin)와 같은 결: 이건 세이브 상태가 아니라
#     "정적 참조 규칙"이다. 보호 세기는 바나 하트에서 매번 파생되므로 자체 상태가 없다 →
#     세이브할 게 없다(SaveManager·main 세이브 불변, night_bar.gd 세이브 무상태와 일관).
#     그래서 씬 노드가 아니라 static + class_name으로 어디서든 BanaGuard.raid_amount(h) 등으로
#     읽는다. night_bar.gd는 이 값을 seam 파라미터(raid_amount·auto_block·patience_secs)로
#     받아 적용만 하고 바나 호감도를 모른다(시그널/데이터 디커플링 — main이 매 프레임 주입).
#     하트→보호 매핑은 여기 한 곳 — Foxfire.accel/reach·CafeMargin.margin이 맡는 자리의 밤판.
#   - ★ 곱셈기는 게이트가 아니라 base 위에 얹는다(ADR-0008 "평평 ≠ 막힘"): ♡0이면 세 축이
#     모두 night_bar 기본값 = 바나 잠듦(밤은 거칠지만 base로 굴러감 — 은둔 농사파도 안 막힘).
#     관계가 오르면 그 위에 *항상 명백히 우월한* 보호를 얹는다(관계 = 의도된 최적 경로의 밤판).
#   - ★ 이중 축(ADR-0010 #7 — 미호 가속/범위 이중 축과 대칭, 밤의 이중 손실에 대응):
#       ㉠ 재고 방어(미호 *범위*의 대칭 — "내가 못 가는 곳을 바나가 받쳐줌"):
#          · raid_amount: ♡↑ → 잡귀가 돌파해도 훔치는 재고량↓(단, 최소 1 — 손실 방지지 무효화
#            아님, 밤의 긴장은 유지). night_bar 기본값(거친 base)에서 줄여 내려간다.
#          · auto_block: ♡↑ → 내가 못 막은 돌파를 바나가 N마리까지 대신 막아준다(약탈 0).
#            여우불 '범위'(못 준 칸을 대신 돌봄)의 밤판 — 못 간 스폿을 바나가 받친다.
#       ㉡ 응대 보호(미호 *가속*처럼 강도 축): patience_secs — ♡↑ → 카운터를 비우고 막으러 간
#          사이 손님이 더 오래 버틴다(이탈↓). 막기↔응대 경쟁의 비용을 관계가 깎아준다.
#   - 곱셈기는 *막기 판정 위 레이어*다(ADR-0010 #8·ADR-0011 #5): HP를 직접 안 깎고 막기 해소
#     결과(약탈량·돌파 여부) 위에 얹힌다. Phase 3 전투가 막기 *구현*을 갈아껴도(같은 {격퇴,
#     약탈량} 계약) 이 매핑은 그대로 산다(㉠=그 N마리는 전투 자체가 안 일어남, ㉡=져도 동일 적용).
#   - 속죄 테마(ADR-0004): 바나의 주거침입·흡혈(남의 밤에 들어 빼앗던 손)을 *지켜서 안 빼앗기게*
#     하는 데 쓴다 — 빼앗던 손이 막는 손으로.
#   - 그레이박스 기준값이며 수치(기울기·상한·하한)는 밸런싱 서랍(Phase 2 이후). 창고 잡귀
#     자동 차단의 2층(차단 위치·잡귀 종류)·실제 전투는 후속(Phase 3).

const MAX_HEARTS := Affinity.MAX_HEARTS  # 하트 상한(Affinity와 같은 5). 입력을 이 범위로 자름
const MIN_RAID := 1                       # 돌파당 최소 약탈량(♡5에도 1 — 손실 방지지 무효화 아님)
const PER_HEART_PATIENCE := 1.0           # 하트당 손님 인내심 증가(초). ♡0 base(7) 위에 더한다

# 입력 하트를 [0, MAX_HEARTS]로 자른다(음수·범위 초과 방어).
static func _clamp_hearts(hearts: int) -> int:
	return clampi(hearts, 0, MAX_HEARTS)

# ── ㉠ 재고 방어 ─────────────────────────────────────────────────────────────
# 잡귀 1마리 돌파 시 약탈 재고량(night_bar.raid_amount seam). night_bar 기본값(거친 base)에서
# 하트 2칸당 1씩 줄어든다(최소 1). ♡0이면 기본값 그대로(바나 잠듦).
#   하트:  0 1 2 3 4 5  →  3 3 2 2 1 1  (DEFAULT_RAID=3 기준, 하트 2칸당 -1, 하한 1).
static func raid_amount(hearts: int) -> int:
	return maxi(MIN_RAID, NightBar.DEFAULT_RAID - _clamp_hearts(hearts) / 2)

# 내가 못 막은 돌파를 바나가 대신 막아주는 최대 마리 수(night_bar.auto_block seam, 밤당).
# 여우불 '범위'(Foxfire.accel)의 밤판 — 하트 2칸당 1마리. ♡0이면 0(바나 잠듦, 다 내가 막아야).
#   하트:  0 1 2 3 4 5  →  0 0 1 1 2 2  (하트 2칸당 +1, 하트0이면 0).
static func auto_block(hearts: int) -> int:
	return _clamp_hearts(hearts) / 2

# ── ㉡ 응대 보호 ─────────────────────────────────────────────────────────────
# 바 손님 인내심(초, night_bar.patience_secs seam). night_bar 기본값(7) 위에 하트당 1초 더한다.
# ♡↑ → 카운터를 비우고 막으러 간 사이 손님이 더 오래 버팀(이탈↓). ♡0이면 기본값 그대로.
#   하트:  0 1 2 3 4 5  →  7 8 9 10 11 12  (하트당 +1초).
static func patience_secs(hearts: int) -> float:
	return NightBar.DEFAULT_PATIENCE + PER_HEART_PATIENCE * _clamp_hearts(hearts)

# 바나 보호가 깨어 있는가(세 축 중 하나라도 base 위로 작동). ♡0이면 false(잠듦).
static func is_awake(hearts: int) -> bool:
	return raid_amount(hearts) < NightBar.DEFAULT_RAID \
		or auto_block(hearts) > 0 \
		or patience_secs(hearts) > NightBar.DEFAULT_PATIENCE

# HUD 한 줄 요약(현재 바나 보호 상태). 관계→밤 보상을 눈에 보이게 한다(체감, ADR-0008).
#   잠듦: "바나 경비: 잠듦 — 바나와 친해지면 밤을 지켜준다"
#   깨어남: "바나 경비: 약탈 N개 · 자동차단 M마리 · 인내심 Ks" (자동차단 0이면 그 칸은 생략)
static func summary(hearts: int) -> String:
	if not is_awake(hearts):
		return "바나 경비: 잠듦 — 바나와 친해지면 밤을 지켜준다"
	var text := "바나 경비: 약탈 %d개" % raid_amount(hearts)
	var ab := auto_block(hearts)
	if ab > 0:
		text += " · 자동차단 %d마리" % ab
	text += " · 인내심 %ds" % int(round(patience_secs(hearts)))
	return text
