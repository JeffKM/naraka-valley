extends SceneTree
# T4.4 / T7.3 / T7.4 — ★ 재미 게이트 플레이테스트 봇 (헤드리스 자동 플레이어).
#
# 목적: ROADMAP T4.4/T7.4 — "직접 플레이테스트하고 '또 하고 싶나?'에 통과/재설계 결정을
#       근거와 함께 내린다"의 그 '근거'를 봇으로 모은다. 봇은 재미를 느낄 수 없으므로 재미
#       그 자체는 판정하지 않는다 — 대신 재미의 '전제조건'을 정량 검증한다.
#
# ★ T7.4 — 21일 직조 슬라이스 재판정: T4.4는 농사 단일 루프만 봤다(봇 전제조건 5/5 통과,
#   그러나 사람 직접 플레이에서 "단일 루프는 평평하다 — 직조에서 재미가 드러난다"로 범위 확장
#   결론, ADR-0006). 그래서 이 봇을 *세 루프 직조*(농사+카페/멜+밤 경비/바나)와 *매크로 당김*
#   (카페 마일스톤 1단)까지 확장해, T4.4가 못 봤던 직조 전제조건을 재측정한다:
#     ① 무막힘 — 세 페르소나가 21일을 한 번도 안 막히고 완주(밤 옵트아웃·단일 루프도 안 막힘).
#     ② 우상향 엔진 — 관계 보상축(여우불)이 켜지고 ♡2+ 도달(곡선이 산다).
#     ③ 페이싱 — miho-heart-arc 목표 곡선(곡선 상수 파생 ♡1·♡2 도달일)에 부합.
#     ④ ★매크로 당김(멀티루프 요구, ADR-0009) — 직조형(Weaver)은 마일스톤 1단을 채우고,
#        단일 루프(Farmer)는 *영원히 못 채운다*(서빙 매출 0·하트 0). "왜 세 루프를 다 하지?"에
#        스타듀 번들처럼 답하는지 — T7.4가 추가한 *핵심* 신규 전제조건이다.
#     ⑤ ★평평≠막힘(밤 옵트인, ADR-0008/0010) — 밤을 한 번도 안 여는 DayWeaver가 21일을
#        완주하고 밤 손실 0(은둔 농사파 안 막힘). 옵트인하는 Weaver만 밤 매출(선택적 보상)을 번다.
#     ⑥ 후반 동기(위험 B 해소) — 가장 빠른 관계 경로조차 ♡5 만렙이 슬라이스 후반에야 닿는다.
#     ⑦ ★직조 자원 합류(§2.8) — 한 재고 풀이 카페 서빙(소모)·밤 약탈(손실)로 함께 줄고,
#        카페 매출·밤 매출이 같은 지갑으로 합류한다(밭→재고→{서빙·약탈}).
#     ⑧ 선택의 가치 — 세 페르소나가 (골드·하트·마일스톤 도달)에서 의미 있게 갈린다.
#     ⑨ 대조군 — 관계·카페·밤을 버린 Farmer는 여우불 잠듦·하트 0·마일스톤 미달.
#
# 방식: T4.2/T4.3의 "실제 시스템 노드로 슬라이스 풀 시뮬레이션"과 같은 결. 물리 이동·입력
#       대신 실제 게임 노드(FarmField·SoulEnergy·Wallet·Inventory·Affinity·GameClock와,
#       T7.4에서 추가한 Cafe·NightBar)를 직접 구동하고, main.gd의 하루 루프를 봇 정책으로
#       재현한다. 노드가 진짜라 밸런스 수치(호감도 곡선·여우불/마진/보호 매핑·작물 경제·
#       서빙가·약탈량)는 게임과 동일하다. 곱셈기·마일스톤 문구도 게임과 같은 static 규칙을 쓴다.
#
# 핵심 3종 페르소나(직조 스펙트럼):
#   1) Weaver(3루프 직조) — 농사+미호/멜 대화·선물+카페 서빙+밤 옵트인(바나 대화·서빙·막기).
#      *의도된 최적 경로*(ADR-0008). 마일스톤을 채우고 세 곱셈기를 모두 켜는지 본다.
#   2) DayWeaver(낮 2루프·밤 옵트아웃) — 농사+미호/멜 대화(선물 X)+카페 서빙, 밤은 한 번도
#      안 연다. ⑤평평≠막힘(밤 옵트아웃이 안 막힘)과 ③페이싱(미호 대화만 곡선)을 본다.
#   3) Farmer(단일 루프 대조군) — 관계·카페·밤을 버리고 고회전 농사+raw 판매만. 단일 루프로는
#      마일스톤을 못 채움(⑨대조군·④매크로 당김의 음성 대조)을 입증.
#
# ★ 봇이 *못* 보는 것(사람 몫): "또 하고 싶나"(주관 재미)·"1단 깨니 2단 갈망하나"·"낮 안
#   기회비용(밭 더 vs 카운터 vs 대화)이 긴장되나". 봇은 페르소나 *수준*의 선택만 모델링하고
#   (어떤 루프를 도는가), 매 순간의 직조 긴장은 사람이 직접 21일을 굴려 판정한다(T7.4 판정서).
#
# 실행: godot --headless --path game --script res://playtest/playtest_bot.gd

const COST := SoulEnergy.COST_PER_ACTION       # 행동당 혼력(노동 전용 — 카페·밤·대화는 혼력 무관)
const ACTIONS_PER_DAY := SoulEnergy.MAX / COST # 하루 가용 노동 행동 수(= 10)
const RUN_DAYS := RunSummary.RUN_DAYS          # 통합 슬라이스 길이(단일 진실원에서 파생 — 21일)
const N_PLOTS := 16                            # 봇이 굴리는 밭 칸 풀(혼력 한도가 실제 제약)

# 실제 1초당 흘러가는 게임 분(카페·밤 창을 실시간 tick으로 굴릴 때 쓴다). GameClock과 동일.
const GAME_MIN_PER_REAL_SEC := float(GameClock.END_MIN - GameClock.START_MIN) / GameClock.REAL_SECONDS_PER_DAY
const WINDOW_STEP := 0.25      # 창 시뮬 tick 간격(실제 초) — 카페 20s/밤 25s 창을 잘게 굴린다
const NIGHT_REACTION := 1.0    # 밤 한 행동(막기/응대) 사이 같은 자리 반응 시간(초).
const NIGHT_SWITCH := 2.0      # 막기(문 앞)↔응대(카운터)는 *다른 자리*라 전환 시 추가로 드는 이동
                               #   시간(초). 몸이 한 칸에만 있다는 사실(ADR-0010 #4)의 핵심 — "막으러
                               #   가면 카운터가 빈다". 막기↔응대 경쟁의 비용(못 받은 손님 = 밤 매출
                               #   억제)이 여기서 난다. ※ 그레이박스 밤(3스폿·접근 8초)은 설계상 부드러운
                               #   리스크라(진짜 전투는 Phase 3 — ADR-0010/0011), 주의 깊은 막기로 재고
                               #   약탈은 대개 0이 된다 — 경쟁 비용은 약탈이 아니라 *억제된 밤 매출*로 난다.
                               #   약탈→재고 차감 경로 자체는 weave_test(♡0·무막기)가 별도로 증명한다.

# 하루 한 명의 행동 정책을 표현하는 가벼운 설정 묶음.
class Persona:
	var name: String
	var talk: bool                 # 매일 미호(+카페면 멜) 대화하는가
	var gift: bool                 # 매일(여유분으로) 미호·멜에게 선물하는가
	var cafe: bool                 # 카페를 운영하는가(낮 서빙 — 멜 마진·재고 소모)
	var night: bool                # 밤 바를 *매일* 여는가(옵트인 — 바나 보호·밤 약탈/매출)
	var target_plots: int          # 동시에 굴릴 밭 칸 수(혼력 한도 안)
	var crop_for_day: Callable     # func(day, gold) -> crop_id : 그날 심을 작물 선택
	func _init(n: String, t: bool, g: bool, c: bool, ni: bool, plots: int, crop: Callable) -> void:
		name = n; talk = t; gift = g; cafe = c; night = ni; target_plots = plots; crop_for_day = crop


func _initialize() -> void:
	print("══════════════════════════════════════════════════════════════")
	print(" T4.4/T7.4 ★통합 재미 게이트 — %d일 직조 슬라이스 봇 (헤드리스)" % RUN_DAYS)
	print(" 행동/일 %d · 슬라이스 %d일 · 하트당 %d점 · 마일스톤 목표 영혼%d/매출%d/친밀%d" % [
		ACTIONS_PER_DAY, RUN_DAYS, Affinity.POINTS_PER_HEART,
		CafeMilestone.TARGET_HARVEST, CafeMilestone.TARGET_REVENUE, CafeMilestone.TARGET_HEARTS])
	print("══════════════════════════════════════════════════════════════")

	var results: Array = []
	results.append(_run(_persona_weaver()))
	results.append(_run(_persona_day_weaver()))
	results.append(_run(_persona_farmer()))

	_print_comparison(results)
	_print_verdict(results)
	quit()


# ── 페르소나 정의 ────────────────────────────────────────────────────────────
func _persona_weaver() -> Persona:
	# 3루프 직조: 농사+미호/멜 대화·선물+카페 서빙+밤 옵트인. 혼령초(빠른 회전)로 재고를 만들어
	# 선물·서빙·약탈에 두루 쓴다 — 한 재고 풀을 세 루프가 나눠 가지는 직조의 주체.
	return Persona.new("Weaver(3루프 직조)", true, true, true, true, 4,
		func(_day: int, _gold: int) -> String: return CropCatalog.HONRYEONGCHO)

func _persona_day_weaver() -> Persona:
	# 낮 2루프(농사+카페) + 미호/멜 대화(선물 X), 밤은 한 번도 안 연다(은둔 농사파). ⑤평평≠막힘
	# (밤 옵트아웃이 안 막힘)과 ③페이싱(미호 대화만 곡선 — 선물 없이 ♡1·♡2 도달일)을 본다.
	return Persona.new("DayWeaver(낮 2루프·밤X)", true, false, true, false, 4,
		func(_day: int, _gold: int) -> String: return CropCatalog.HONRYEONGCHO)

func _persona_farmer() -> Persona:
	# 단일 루프 대조군: 관계·카페·밤을 버리고 고회전 농사+raw 판매만. 밭을 2배(8칸)로 굴려도
	# 직조 산출물(서빙 매출·하트)이 0이라 마일스톤을 *못 채운다* — "왜 세 루프를 다 하지"의 답.
	return Persona.new("Farmer(단일 루프)", false, false, false, false, 8,
		func(_day: int, _gold: int) -> String: return CropCatalog.HONRYEONGCHO)


# ── 직조 슬라이스 한 판 시뮬레이션(RUN_DAYS일) ──────────────────────────────
# 실제 게임 노드를 새 게임 상태로 세팅하고, 페르소나 정책으로 RUN_DAYS일을 굴린다. 농사 코어
# (T4.4)는 그대로 두고 그 위에 카페/밤/마일스톤/세 호감도를 직조한다.
func _run(p: Persona) -> Dictionary:
	# 새 게임 상태(main의 _ready + Inventory._ready 시작 씨앗을 그대로 모방).
	var clock := GameClock.new()
	var farm := FarmField.new()
	var energy := SoulEnergy.new()
	var wallet := Wallet.new()
	var inv := Inventory.new()
	# 세 호감도(미호 기본 선호=영혼 호박 · 멜=피안화 · 바나=혼령초 — T5.2/T6.2 선물 경제 분산).
	var miho := Affinity.new()
	var mel := Affinity.new();  mel.preferred_crop = CropCatalog.PIANHWA
	var bana := Affinity.new(); bana.preferred_crop = CropCatalog.HONRYEONGCHO
	# 카페·밤 노드(트리 밖 생성이라 _ready를 손수 불러 좌석/스폿을 채운다 — 기존 봇 관례).
	var cafe := Cafe.new();      cafe._ready()
	var night := NightBar.new(); night._ready()
	for id in Inventory.START_SEEDS:           # 새 게임 시작 씨앗(혼령초 3)
		inv.seeds[id] = Inventory.START_SEEDS[id]

	var plots: Array = []
	for i in N_PLOTS:
		plots.append(Vector2i(i, 0))

	var log: Array = []
	var softlocks := 0
	var heart_days := {}                        # 미호 하트 단계 → 처음 도달한 게임 날(페이싱·위험 B)
	var mel_heart_days := {}                     # 멜 하트 단계 → 처음 도달한 게임 날
	var foxfire_awake_day := -1                 # 여우불이 처음 깨어난 날
	# ★ 직조 누적(마일스톤 산출물 — main의 _run_harvested·_cafe_revenue_total과 같은 결).
	var harvest_cum := 0                         # 거둔 영혼 누적(농사 산출물 — 약탈로 줄지 않음)
	var serving_rev_cum := 0                     # 서빙 매출 누적(카페+밤 — raw 판매 제외, ADR-0009)
	var night_rev_cum := 0                       # 밤 응대 매출 누적(밤 옵트인 보상)
	var raid_attempt_cum := 0                    # 잡귀가 노린 약탈량 누적(바나 보호 *전*)
	var raid_actual_cum := 0                     # 실제 차감된 재고량 누적(밭→재고→약탈 — 자원 합류)
	var serve_consumed_cum := 0                  # 카페 서빙으로 소모한 재고 누적(밭→재고→서빙)
	var night_optins := 0                        # 밤 바를 연 횟수(옵트인 빈도)
	var milestone_day := -1                      # 마일스톤 1단을 처음 채운 게임 날(-1 = 미달)

	# day 1..RUN_DAYS 플레이. 각 날 끝에 취침(advance_day+refill). RUN_DAYS번째 취침이
	# day를 RUN_DAYS+1로 올려 RunSummary.is_over → 슬라이스 종료(main과 동일).
	while clock.day <= RUN_DAYS:
		var day: int = clock.day
		var harvested_today := 0
		var actions := ACTIONS_PER_DAY          # 오늘 가용 노동 행동(혼력/행동)

		# ① 미호(+카페면 멜) 대화 — 혼력 무관, 하루 1회, 느린 채널.
		if p.talk:
			miho.daily_talk(day)
			if p.cafe:
				mel.daily_talk(day)

		# ② 수확 먼저(공간 확보·재고 적재) — 다 자란 칸을 거둔다. 누적 영혼이 마일스톤 농사 산출물.
		for t in plots:
			if actions <= 0: break
			if farm.is_mature(t):
				var crop := farm.harvest(t)
				if crop != "":
					inv.add_harvest(crop)
					harvested_today += 1
					harvest_cum += 1
					actions -= 1

		# ③ 미호·멜 선물 — 혼력 무관, 하루 1회, 빠른 채널. 여유 재고 1개씩.
		if p.gift:
			if miho.can_gift(day):
				var g := _cheapest_harvest(inv)
				if g != "" and inv.take_harvest(g):
					miho.gift(g, day)
			if p.cafe and mel.can_gift(day):
				var g2 := _cheapest_harvest(inv)
				if g2 != "" and inv.take_harvest(g2):
					mel.gift(g2, day)

		# ④ 낮 카페 서빙(혼력 무관, 시간 희소성) — 재고를 소모해 서빙 매출(멜 마진 ×)을 같은 지갑에.
		#    실제 Cafe 노드를 영업창(15–19시) 동안 실시간 tick으로 굴린다(게임과 동일 경제).
		if p.cafe:
			var cres := _run_cafe(cafe, inv, mel.hearts())
			wallet.earn(cres["revenue"])
			serving_rev_cum += cres["revenue"]
			serve_consumed_cum += cres["served"]

		# ⑤ 경제: 다음 날 씨앗 확보. 단일 루프(Farmer)는 raw 전량 판매(서빙 안 함). 직조형은
		#    서빙 매출로 씨앗을 대고, 모자랄 때만 raw로 메운다(재고를 밤 약탈 대상으로 남겨 둠).
		if not p.cafe:
			_sell_all(inv, wallet)              # 단일 루프: raw 덤프(빠른 골드, 카페는 안 자람)
		var crop_today: String = p.crop_for_day.call(day, wallet.gold)
		_ensure_seed_funds(inv, wallet, crop_today)  # 씨앗 살 골드가 없으면 raw로 최소 메움(무막힘)
		_buy_seeds(inv, wallet, crop_today, p.target_plots)

		# ⑥ 밭 정비(혼력 소모): 운영 칸 물 주고, 빈 슬롯은 새로 열어 심고 물 준다.
		var wanted_progress := true
		var made_progress := false
		for t in plots:
			while actions > 0:
				var a := _next_action(farm, inv, t, crop_today, plots, p.target_plots)
				if a == "": break
				match a:
					"hoe": farm.hoe(t)
					"plant":
						farm.plant(t, crop_today); inv.take_seed(crop_today)
					"water": farm.water(t)
				made_progress = true
				actions -= 1

		# 소프트락 = 새로 심을 칸도 물 줄 작물도 없어 농사가 한 발도 못 나간 날. 슬라이스 내내 0이어야 무막힘.
		if wanted_progress and not made_progress and not _has_growing(farm, plots):
			softlocks += 1

		# ⑦ 밤 바 옵트인(혼력 무관, 시간 창 19–24시) — 바나 대화 + 밤 응대(매출) + 막기(재고 방어).
		#    못 막은 돌파는 *낮에 거둔 재고*를 약탈한다(바나 보호로 완화). 밤 매출·약탈 모두 같은
		#    재고/지갑에 합류(직조). DayWeaver/Farmer는 안 열어 밤 손실 0(평평≠막힘).
		var opted := false
		if p.night:
			opted = true
			night_optins += 1
			bana.daily_talk(day)                # 옵트인한 밤에 바나와 대화(밤 관계 채널)
			var nres := _run_night(night, inv, bana.hearts())
			wallet.earn(nres["revenue"])
			serving_rev_cum += nres["revenue"]
			night_rev_cum += nres["revenue"]
			raid_attempt_cum += nres["raid_attempted"]
			raid_actual_cum += nres["raid_actual"]

		# 일별 스냅샷(취침 직전 = 그날의 결과) + 하트 도달일·여우불 깸·마일스톤 달성일 기록.
		var hm: int = miho.hearts()
		var hl: int = mel.hearts()
		var hb: int = bana.hearts()
		if hm > 0 and not heart_days.has(hm):
			heart_days[hm] = day
		if hl > 0 and not mel_heart_days.has(hl):
			mel_heart_days[hl] = day
		if foxfire_awake_day < 0 and Foxfire.is_awake(hm):
			foxfire_awake_day = day
		var heart_sum: int = hm + hl + hb
		if milestone_day < 0 and CafeMilestone.is_complete(harvest_cum, serving_rev_cum, heart_sum):
			milestone_day = day
		log.append({
			"day": day, "gold": wallet.gold, "hm": hm, "hl": hl, "hb": hb,
			"harvested": harvested_today, "harvest_cum": harvest_cum,
			"serving_rev": serving_rev_cum, "heart_sum": heart_sum,
			"milestone_pct": int(round(CafeMilestone.overall_ratio(harvest_cum, serving_rev_cum, heart_sum) * 100.0)),
			"opted": opted,
		})

		# ⑧ 취침: 날 넘기고, 끝이 아니면 작물 성장(여우불 반영)+혼력 회복. 카페·밤은 매일 새 선택으로 리셋.
		clock.sleep()
		cafe.end_day()
		night.end_day()
		if RunSummary.is_over(clock.day):
			break
		var hgrow := miho.hearts()
		farm.advance_day(Foxfire.accel(hgrow), Foxfire.reach(hgrow))
		energy.refill()

	var final_gold: int = wallet.gold
	var final_hm: int = (log[-1]["hm"] as int) if log.size() > 0 else 0
	var final_hl: int = (log[-1]["hl"] as int) if log.size() > 0 else 0
	var final_hb: int = (log[-1]["hb"] as int) if log.size() > 0 else 0
	# SceneTree 밖에서 new()한 노드라 직접 정리한다(누수 경고 방지).
	for n in [clock, farm, energy, wallet, inv, miho, mel, bana, cafe, night]:
		n.free()
	return {
		"name": p.name,
		"log": log,
		"softlocks": softlocks,
		"heart_days": heart_days,
		"mel_heart_days": mel_heart_days,
		"foxfire_awake_day": foxfire_awake_day,
		"final_gold": final_gold,
		"final_hm": final_hm, "final_hl": final_hl, "final_hb": final_hb,
		"final_heart_sum": final_hm + final_hl + final_hb,
		"harvest_cum": harvest_cum,
		"serving_rev_cum": serving_rev_cum,
		"night_rev_cum": night_rev_cum,
		"raid_attempt_cum": raid_attempt_cum,
		"raid_actual_cum": raid_actual_cum,
		"serve_consumed_cum": serve_consumed_cum,
		"night_optins": night_optins,
		"milestone_day": milestone_day,
	}


# ── 카페 영업창 한 번 시뮬(실제 Cafe 노드, 15–19시 = 실제 20초) ───────────────
# 영업창을 WINDOW_STEP 간격으로 굴리며, 기다리는 손님이 있고 재고가 있으면 즉시 서빙한다
# (재고 1개 소모 → BASE_PRICE × 멜마진 매출). 스폰이 3초 간격이라 처리량은 재고·스폰에 막힌다.
# 반환: { served:서빙수(=재고 소모), revenue:서빙 매출(멜 마진 반영, 게임과 동일) }.
func _run_cafe(cafe: Cafe, inv: Inventory, mel_hearts: int) -> Dictionary:
	cafe.margin = CafeMargin.margin(mel_hearts)  # ♡0 ×1.0 base → ♡5 ×2.0(게임과 동일 매핑)
	var served := 0
	var revenue := 0
	var minutes := float(Cafe.OPEN_MIN)
	while minutes < float(Cafe.CLOSE_MIN):
		cafe.tick(WINDOW_STEP, minutes)
		for seat in Cafe.N_SEATS:
			if cafe.is_waiting(seat) and inv.total_harvest() > 0:
				var c := _cheapest_harvest(inv)
				if c != "" and inv.take_harvest(c):   # 밭→재고→서빙: 재고 1개 소모
					revenue += cafe.serve(seat)
					served += 1
		minutes += WINDOW_STEP * GAME_MIN_PER_REAL_SEC
	cafe.tick(0.0, float(Cafe.CLOSE_MIN))            # 마감 전이(좌석 정리)
	return {"served": served, "revenue": revenue}


# ── 밤 바 한 번 시뮬(실제 NightBar 노드, 19–24시 = 실제 25초) ─────────────────
# 바나 보호(약탈량↓·자동차단↑·인내심↑)를 주입한 뒤 옵트인하고, 막기↔응대를 *한 번에 하나만*
# (반응 시간 NIGHT_REACTION 간격, 몸이 한 칸에만 있음 — ADR-0010 #4) 한다. 정책 = *가장 급한
# 하나*(접근/인내심 잔량 비율이 가장 낮은 대상)를 막거나 응대한다 — 막기 우선이 아니라 진짜
# 경쟁: 손님을 응대하는 사이 잡귀가 차고, 잡귀를 막는 사이 손님이 떠난다(직조 긴장). 그래서 못
# 막은 돌파는 약탈로(바나 보호로 완화), 못 받은 손님은 이탈로 새어 *이중 손실*이 실제로 난다.
# 반환: { served, revenue, raid_attempted:노린 약탈량, raid_actual:실제 재고 차감 }.
func _run_night(night: NightBar, inv: Inventory, bana_hearts: int) -> Dictionary:
	night.raid_amount = BanaGuard.raid_amount(bana_hearts)    # ♡↑ → 약탈량↓(하한 1)
	night.auto_block = BanaGuard.auto_block(bana_hearts)      # ♡↑ → 못 막은 돌파 N마리 대신 막음
	night.patience_secs = BanaGuard.patience_secs(bana_hearts)  # ♡↑ → 손님 인내심↑(이탈↓)
	night.open_bar(float(NightBar.OPEN_MIN))
	var served := 0
	var revenue := 0
	var minutes := float(NightBar.OPEN_MIN)
	var cooldown := 0.0
	var last_kind := ""           # 직전 행동 자리("block"=문 / "serve"=카운터) — 전환 이동비 판정
	while minutes < float(NightBar.CLOSE_MIN):
		night.tick(WINDOW_STEP, minutes)
		cooldown -= WINDOW_STEP
		if cooldown <= 0.0:
			# 가장 급한 하나를 고른다(접근/인내심 잔량 비율 최소). 막기·응대가 한 행동 슬롯을 다툼.
			var best_kind := ""       # "block" | "serve"
			var best_idx := -1
			var best_ratio := 2.0
			for spot in NightBar.N_SPOTS:
				if night.is_threat(spot):
					var ar := night.approach_ratio(spot)
					if ar < best_ratio:
						best_ratio = ar; best_kind = "block"; best_idx = spot
			for seat in NightBar.N_SEATS:
				if night.is_waiting(seat):
					var pr := night.patience_ratio(seat)
					if pr < best_ratio:
						best_ratio = pr; best_kind = "serve"; best_idx = seat
			if best_kind != "":
				# 자리를 옮기면(막기↔응대) 이동 시간이 더 든다 — 그 사이 다른 쪽이 새어 이중 손실.
				var spent := NIGHT_REACTION + (NIGHT_SWITCH if (last_kind != "" and best_kind != last_kind) else 0.0)
				if best_kind == "block":
					night.block(best_idx)
				else:
					revenue += night.serve(best_idx); served += 1
				cooldown = spent
				last_kind = best_kind
		minutes += WINDOW_STEP * GAME_MIN_PER_REAL_SEC
	# 못 막은 돌파가 노린 약탈량(바나 자동차단·약탈량↓ 반영된 값). main처럼 낮 재고에서 그만큼 차감.
	var attempted: int = night.tonight_raided()
	var actual := _deduct_raid(inv, attempted)
	return {"served": served, "revenue": revenue, "raid_attempted": attempted, "raid_actual": actual}


# ── 밭 정책 헬퍼(T4.4 그대로) ───────────────────────────────────────────────
# 이 칸에서 다음에 할 유용한 행동("" = 없음). 물주기 > 심기 > (목표 미달 시)괭이질. 수확은 위 ②에서 처리.
func _next_action(farm: FarmField, inv: Inventory, t: Vector2i, crop: String, plots: Array, target: int) -> String:
	if farm.is_planted(t) and not farm.is_watered(t) and not farm.is_mature(t):
		return "water"
	if farm.is_tilled(t) and not farm.is_planted(t) and inv.has_seed(crop):
		return "plant"
	if not farm.is_tilled(t) and _tilled_count(farm, plots) < target and inv.has_seed(crop):
		return "hoe"
	return ""

func _tilled_count(farm: FarmField, plots: Array) -> int:
	var n := 0
	for t in plots:
		if farm.is_tilled(t):
			n += 1
	return n

# 심겨서 자라는 중인 칸이 하나라도 있는가(소프트락 오판 방지 — 진행 중이면 막힘 아님).
func _has_growing(farm: FarmField, plots: Array) -> bool:
	for t in plots:
		if farm.is_planted(t):
			return true
	return false

# 가장 싼 수확물 id(서빙·선물·약탈이 먼저 가져감 — main._cheapest_harvest와 같은 결). "" = 없음.
func _cheapest_harvest(inv: Inventory) -> String:
	var best := ""
	var best_price := 1 << 30
	for id in inv.harvested:
		var pr := CropCatalog.sell_price(id)
		if pr < best_price:
			best_price = pr
			best = id
	return best

# 잡귀가 노린 약탈량만큼 낮 재고에서 차감한다(싼 것부터). 재고가 모자라면 있는 만큼만(실제 손실).
# 반환: 실제로 차감된 개수.
func _deduct_raid(inv: Inventory, n: int) -> int:
	var removed := 0
	while removed < n:
		var c := _cheapest_harvest(inv)
		if c == "" or not inv.take_harvest(c):
			break
		removed += 1
	return removed

# 수확물 전량을 판매가로 환산해 골드로(main._sell_all과 동일 — 단일 루프 raw 덤프).
func _sell_all(inv: Inventory, wallet: Wallet) -> void:
	var total := 0
	for id in inv.harvested:
		total += inv.harvest_count(id) * CropCatalog.sell_price(id)
	if total > 0:
		inv.clear_harvest()
		wallet.earn(total)

# 씨앗 살 골드가 한 개 값도 안 되면, 재고를 최소한으로 raw 판매해 한 개라도 살 골드를 만든다
# (무막힘 안전판 — 직조형이 서빙으로 골드를 못 댔을 때만 발동, 재고는 최대한 남겨 둠).
func _ensure_seed_funds(inv: Inventory, wallet: Wallet, crop: String) -> void:
	var cost := CropCatalog.seed_cost(crop)
	if cost <= 0:
		return
	while not wallet.can_afford(cost) and inv.total_harvest() > 0:
		var c := _cheapest_harvest(inv)
		if c == "" or not inv.take_harvest(c):
			break
		wallet.earn(CropCatalog.sell_price(c))

# 목표 칸 수만큼 심을 씨앗을 골드가 되는 만큼 보충한다.
func _buy_seeds(inv: Inventory, wallet: Wallet, crop: String, target: int) -> void:
	var cost := CropCatalog.seed_cost(crop)
	if cost <= 0:
		return
	while inv.seed_count(crop) < target and wallet.can_afford(cost):
		if not wallet.spend(cost):
			break
		inv.add_seed(crop)


# ── 출력 ────────────────────────────────────────────────────────────────────
func _run_header(r: Dictionary) -> void:
	print("\n┌─ %s " % r["name"] + "─".repeat(max(0, 56 - r["name"].length())))
	print("│ Day │ 골드 │ 미호 │ 멜 │ 바나 │ 수확 │ 누적영혼 │ 서빙매출 │ 친밀합 │ 1단% │ 밤")
	for d in r["log"]:
		print("│ %3d │ %4d │ %d/%d  │ %d  │  %d   │  %d   │   %3d    │  %5d   │  %2d/%d  │ %3d  │ %s" % [
			d["day"], d["gold"], d["hm"], Affinity.MAX_HEARTS, d["hl"], d["hb"],
			d["harvested"], d["harvest_cum"], d["serving_rev"], d["heart_sum"],
			CafeMilestone.TARGET_HEARTS, d["milestone_pct"], "열림" if d["opted"] else " — "])
	print("└" + "─".repeat(58))

func _print_comparison(results: Array) -> void:
	for r in results:
		_run_header(r)
	print("\n══════════════════════════════ 요약 비교 ══════════════════════════════")
	print("전략                  │ 막힘 │ 골드 │ 미호 │ 멜 │ 바나 │ 영혼 │ 서빙매출 │ 밤매출 │ 약탈 │ 옵트인 │ 마일스톤")
	for r in results:
		print("%-21s │ %d일 │ %4d │ %d/%d │ %d/%d│ %d/%d │ %3d  │  %5d   │ %4d  │ %3d  │  %2d일  │ %s" % [
			r["name"], r["softlocks"], r["final_gold"],
			r["final_hm"], Affinity.MAX_HEARTS, r["final_hl"], Affinity.MAX_HEARTS,
			r["final_hb"], Affinity.MAX_HEARTS, r["harvest_cum"], r["serving_rev_cum"],
			r["night_rev_cum"], r["raid_actual_cum"], r["night_optins"],
			("D%d 도달" % r["milestone_day"]) if r["milestone_day"] > 0 else "미달"])

func _day_str(heart_days: Dictionary, h: int) -> String:
	return ("D%d" % heart_days[h]) if heart_days.has(h) else "--"


# ── 판정 초안(직조 전제조건 정량 체크) ───────────────────────────────────────
# 봇은 재미를 못 느낀다 → '또 하고 싶나'는 사람 몫. 여기선 직조 재미의 전제조건만 ✓/✗로
# 평가해, 사람이 그 위에 주관 판정을 얹을 근거를 만든다.
func _print_verdict(results: Array) -> void:
	print("\n══════════════════ 판정 초안(직조 전제조건) ══════════════════")

	var weaver: Dictionary = results[0]
	var dayw: Dictionary = results[1]
	var farmer: Dictionary = results[2]

	# ① 무막힘: 모든 페르소나가 슬라이스 내내 소프트락 0(밤 옵트아웃·단일 루프도 안 막힘).
	var no_softlock := true
	for r in results:
		if r["softlocks"] > 0:
			no_softlock = false
	_check("① 무막힘 — 세 페르소나 모두 %d일 동안 한 번도 막히지 않음" % RUN_DAYS, no_softlock)

	# ② 우상향 엔진: Weaver의 미호 관계 보상축(여우불)이 깨어나고 ♡2+ 도달(곡선이 산다).
	var engine_on: bool = weaver["foxfire_awake_day"] > 0 and (weaver["final_hm"] as int) >= 2
	_check("② 우상향 엔진 — 관계 보상축(여우불)이 켜지고 미호 ♡2+ 도달", engine_on)

	# ③ 페이싱: 미호 대화만(선물 X) 채널의 ♡1·♡2 도달일이 곡선 상수 목표에 근접(±2일 허용).
	#   DayWeaver는 미호에게 선물을 안 줘 대화만(8점/일) 채널이라 ♡N은 ⌈N·하트점수/대화점수⌉일째 닿는다.
	var hd: Dictionary = dayw["heart_days"]
	var t1 := ceili(float(Affinity.POINTS_PER_HEART) / float(Affinity.DAILY_TALK_POINTS))
	var t2 := ceili(float(2 * Affinity.POINTS_PER_HEART) / float(Affinity.DAILY_TALK_POINTS))
	var pacing: bool = hd.has(1) and hd.has(2) and absi((hd[1] as int) - t1) <= 2 and absi((hd[2] as int) - t2) <= 2
	_check("③ 페이싱 — DayWeaver 미호 ♡1≈D%d·♡2≈D%d 목표 곡선에 부합 [실제 ♡1=%s·♡2=%s]" % [
		t1, t2, _day_str(hd, 1), _day_str(hd, 2)], pacing)

	# ④ ★매크로 당김(멀티루프 요구, ADR-0009): 직조형(Weaver)은 마일스톤 1단을 채우고, 단일
	#   루프(Farmer)는 *영원히 못 채운다*. "왜 세 루프를 다 하지"에 스타듀 번들처럼 답하는가.
	var weaver_done: bool = weaver["milestone_day"] > 0
	var farmer_fail: bool = farmer["milestone_day"] < 0
	_check("④ ★매크로 당김 — 직조형은 마일스톤 1단 달성(D%s)·단일 루프는 미달(세 루프 요구)" % [
		str(weaver["milestone_day"]) if weaver_done else "--"], weaver_done and farmer_fail)

	# ⑤ ★평평≠막힘(밤 옵트인, ADR-0008/0010): 밤을 한 번도 안 연 DayWeaver가 21일 완주(소프트락
	#   0)하고 밤 손실 0. 옵트인한 Weaver만 밤 매출(선택적 보상)을 번다 — 밤은 세금이 아니라 선택.
	var optout_safe: bool = dayw["night_optins"] == 0 and dayw["softlocks"] == 0 and dayw["raid_actual_cum"] == 0
	var optin_rewarded: bool = weaver["night_optins"] > 0 and (weaver["night_rev_cum"] as int) > 0
	_check("⑤ ★평평≠막힘 — 밤 옵트아웃(DayWeaver)도 완주·손실0, 옵트인(Weaver)만 밤 매출 %d" % [
		weaver["night_rev_cum"]], optout_safe and optin_rewarded)

	# ⑥ 후반 동기(위험 B 해소): 가장 빠른 관계 경로(Weaver 미호 — 대화+선물)조차 ♡5 만렙이
	#   슬라이스 후반(≥0.7×RUN_DAYS)에야 닿아 후반 동기가 산다. 임계는 RUN_DAYS에서 파생(손절 ①).
	var wh: Dictionary = weaver["heart_days"]
	var late_threshold := int(round(float(RUN_DAYS) * 0.7))
	var late_motivation: bool = wh.has(Affinity.MAX_HEARTS) and (wh[Affinity.MAX_HEARTS] as int) >= late_threshold
	var maxd_str: String = _day_str(wh, Affinity.MAX_HEARTS)
	_check("⑥ 후반 동기 — Weaver 미호 ♡%d 만렙이 슬라이스 후반(≥D%d)에 도달 [실제 %s]" % [
		Affinity.MAX_HEARTS, late_threshold, maxd_str], late_motivation)

	# ⑦ ★직조 자원 합류(§2.8): Weaver의 한 재고 풀이 카페 서빙으로 *소모*되고(밭→재고→서빙, 현재
	#   자산 환전), 카페 매출·밤 매출이 *같은 지갑*으로 합류한다. 밤은 같은 재고를 약탈로도 노리지만
	#   (밭→재고→약탈), 그레이박스 밤은 부드러운 리스크라 주의 깊은 막기로 약탈이 대개 0이 된다 —
	#   경쟁 비용은 *억제된 밤 매출*로 난다(막기 우선 = 손님 응대를 못 함). 약탈→재고 차감 경로 자체는
	#   weave_test(♡0·무막기)가 증명하므로, 봇은 21일 통합 굴림에서 '소모+매출 합류'를 확인한다.
	var cafe_rev: int = (weaver["serving_rev_cum"] as int) - (weaver["night_rev_cum"] as int)
	var weave_confluence: bool = (weaver["serve_consumed_cum"] as int) > 0 \
		and cafe_rev > 0 and (weaver["night_rev_cum"] as int) > 0
	_check("⑦ ★직조 자원 합류 — 한 재고가 카페 서빙 %d개 소모(현재 자산), 카페 매출 %d+밤 매출 %d 한 지갑" % [
		weaver["serve_consumed_cum"], cafe_rev, weaver["night_rev_cum"]], weave_confluence)

	# ⑧ 선택의 가치: 세 페르소나가 (골드·하트합·마일스톤 도달)에서 의미 있게 갈린다.
	var golds := [weaver["final_gold"], dayw["final_gold"], farmer["final_gold"]]
	var heart_sums := [weaver["final_heart_sum"], dayw["final_heart_sum"], farmer["final_heart_sum"]]
	var milestones := [weaver["milestone_day"] > 0, dayw["milestone_day"] > 0, farmer["milestone_day"] > 0]
	var gold_spread: bool = (golds.max() - golds.min()) >= 100
	var heart_spread: bool = heart_sums.max() != heart_sums.min()
	var milestone_spread: bool = milestones.has(true) and milestones.has(false)
	_check("⑧ 선택의 가치 — 골드·친밀합·마일스톤 도달이 페르소나별로 갈림", gold_spread and heart_spread and milestone_spread)

	# ⑨ 대조군: 관계·카페·밤을 버린 Farmer는 여우불 잠듦·하트 0·마일스톤 미달(단일 루프의 천장).
	var control: bool = farmer["foxfire_awake_day"] < 0 and (farmer["final_heart_sum"] as int) == 0 \
		and farmer["milestone_day"] < 0
	_check("⑨ 대조군 — 단일 루프(Farmer)는 여우불 잠듦·하트 0·마일스톤 미달", control)

	# ── 손절 사다리 참고치(NO-GO 시 어느 단계로 후퇴할지의 데이터 근거, ADR-0006·0009) ──
	# ③ 바나 빼고 농사+카페 2루프만으로 마일스톤이 닿나? = Weaver의 미호+멜 하트 합(바나 제외)이
	#   슬라이스 안에 친밀 목표(8)에 닿는지. 닿으면 손절 ③(바나 제거)이 마일스톤을 안 깨고 성립.
	var day_only_hearts_ok := false
	var day_only_day := -1
	for d in weaver["log"]:
		if (d["hm"] as int) + (d["hl"] as int) >= CafeMilestone.TARGET_HEARTS:
			day_only_hearts_ok = true
			day_only_day = d["day"]
			break
	print("\n── 손절 사다리 참고(NO-GO 시) ──")
	print("  · ① 21→14 복귀: RUN_DAYS 한 줄(현재 %d). 곡선이 함께 비례 복귀(손절 ①)." % RUN_DAYS)
	print("  · ② 마일스톤 제거: 순간 직조(자원·관계 합류 ⑦)만으로 판정 — ⑦ %s." % [
		"✓(합류 산다)" if (weaver["serve_consumed_cum"] as int) > 0 else "✗"])
	print("  · ③ 바나 제거: 미호+멜 2루프만으로 친밀 목표 %d 도달 = %s%s." % [
		CafeMilestone.TARGET_HEARTS,
		"가능" if day_only_hearts_ok else "불가",
		(" (D%d)" % day_only_day) if day_only_hearts_ok else ""])

	print("\n※ 위는 '직조 재미의 전제조건'이다. 모두 ✓라도 '또 하고 싶나'·'1단 깨니 2단 갈망하나'·")
	print("  '낮 안 기회비용이 긴장되나'(주관)는 사람이 직접 %d일을 플레이해 판정해야 한다 —" % RUN_DAYS)
	print("  봇은 슬라이스가 굴러가는지·세 곱셈기 곡선이 켜지는지·매크로 당김이 세 루프를 요구하는지까지만 본다.")

func _check(label: String, ok: bool) -> void:
	print(("  ✓ " if ok else "  ✗ ") + label)
