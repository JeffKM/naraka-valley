extends SceneTree
# T4.4 — ★ 재미 게이트 플레이테스트 봇 (헤드리스 자동 플레이어).
#
# 목적: ROADMAP T4.4 — "직접 14일을 플레이테스트하고 '또 하고 싶나?'에 통과/재설계
#       결정을 근거와 함께 내린다"의 그 '근거'를 봇으로 모은다. 봇은 재미를 느낄 수
#       없으므로 재미 그 자체는 판정하지 않는다 — 대신 재미의 '전제조건'을 정량
#       검증한다: ① 14일이 한 번도 막히지 않고 굴러가는가(무막힘) ② 14일 슬라이스의
#       우상향 엔진(여우불=관계 보상)이 실제로 켜지는가 ③ 페이싱이 설계 목표
#       (miho-heart-arc: ♡1≈D5·♡2≈D10)에 맞는가 ④ 서로 다른 플레이 스타일이
#       의미 있게 다른 결과를 내는가(선택의 가치).
#
# 방식: T4.2/T4.3의 "실제 시스템 노드로 14일 풀 시뮬레이션"과 같은 결. 물리 이동·입력
#       대신 실제 게임 노드(FarmField·SoulEnergy·Wallet·Inventory·Affinity·GameClock)를
#       직접 구동하고, main.gd의 하루 루프(_try_farm_action·_on_day_advanced·카페
#       판매/구매·미호 대화/선물)를 봇 정책으로 재현한다. 노드가 진짜라 밸런스 수치
#       (호감도 곡선·여우불 매핑·작물 경제)는 게임과 동일하다.
#
# 핵심 3종 전략(페르소나):
#   1) Talker  — 매일 미호와 대화만(선물 X), 혼령초 농사. 대화 채널만으로 여우불
#                곡선이 켜지는지(설계상 ♡2까지 보장) 검증.
#   2) Gifter  — 매일 대화 + 매일 선물(여유 수확물). ♡를 빠르게 밀어 올리는 대신
#                팔 수확물을 선물로 희생하는 경제 트레이드오프를 본다.
#   3) Farmer  — 관계 보상축을 버린 대조군. 대화·선물 X, 고수익 작물(영혼 호박) 회전
#                으로 골드 극대화. 여우불이 잠든 채(순수 스타듀 성장) 농사 곡선이
#                어떻게 정체되는지 — "관계를 무시하면 성장 엔진이 안 켜진다"를 입증.
#
# 실행: godot --headless --path game --script res://playtest/playtest_bot.gd

const COST := SoulEnergy.COST_PER_ACTION       # 행동당 혼력
const ACTIONS_PER_DAY := SoulEnergy.MAX / COST # 하루 가용 행동 수(= 10)
const RUN_DAYS := RunSummary.RUN_DAYS          # 14일 슬라이스
const N_PLOTS := 16                            # 봇이 굴리는 밭 칸 풀(혼력 한도가 실제 제약)

# 하루 한 명의 행동 정책을 표현하는 가벼운 설정 묶음.
class Persona:
	var name: String
	var talk: bool                 # 매일 미호와 대화하는가
	var gift: bool                 # 매일(여유분으로) 미호에게 선물하는가
	var target_plots: int          # 동시에 굴릴 밭 칸 수(혼력 한도 안)
	var crop_for_day: Callable     # func(day, gold) -> crop_id : 그날 심을 작물 선택
	func _init(n: String, t: bool, g: bool, plots: int, crop: Callable) -> void:
		name = n; talk = t; gift = g; target_plots = plots; crop_for_day = crop


func _initialize() -> void:
	print("══════════════════════════════════════════════════════════════")
	print(" T4.4 재미 게이트 — 14일 플레이테스트 봇 (헤드리스)")
	print(" 행동/일 %d · 슬라이스 %d일 · 하트당 %d점 · 여우불=하트 파생" % [
		ACTIONS_PER_DAY, RUN_DAYS, Affinity.POINTS_PER_HEART])
	print("══════════════════════════════════════════════════════════════")

	var results: Array = []
	results.append(_run(_persona_talker()))
	results.append(_run(_persona_gifter()))
	results.append(_run(_persona_farmer()))

	_print_comparison(results)
	_print_verdict(results)
	quit()


# ── 페르소나 정의 ────────────────────────────────────────────────────────────
func _persona_talker() -> Persona:
	# 항상 혼령초(가장 싸고 빠른 회전). 대화만으로 여우불이 켜지는지 보는 게 목적.
	return Persona.new("Talker(대화 위주)", true, false, 4,
		func(_day: int, _gold: int) -> String: return CropCatalog.HONRYEONGCHO)

func _persona_gifter() -> Persona:
	# 혼령초로 빠르게 수확물을 만들어 매일 선물에 보탠다(빠른 호감도 채널).
	return Persona.new("Gifter(선물 집중)", true, true, 4,
		func(_day: int, _gold: int) -> String: return CropCatalog.HONRYEONGCHO)

func _persona_farmer() -> Persona:
	# 경제 최적화 대조군: 관계를 안 쌓고(대화·선물 X) 밭을 더 넓게 굴린다. 작물은
	# Talker와 같은 혼령초 — 변수를 '관계 유무 + 칸 수'로 좁혀, 여우불 가속이 없을 때
	# 순수 경제 상한이 어디까지인지를 Talker와 깨끗이 대비한다(같은 작물).
	#   ※ 14일 슬라이스에서 혼령초(3일)가 유일하게 2회전 이상 도는 작물이라 사실상
	#     최적이다. 영혼 호박(8일) 단일작은 여우불 없이는 회수가 안 되는 함정이며
	#     (별도 진단 — README 참조), 그래서 '경제 최적화'의 정의에서 제외했다.
	return Persona.new("Farmer(경제 최적화)", false, false, 8,
		func(_day: int, _gold: int) -> String: return CropCatalog.HONRYEONGCHO)


# ── 14일 한 판 시뮬레이션 ────────────────────────────────────────────────────
# 실제 게임 노드를 새 게임 상태로 세팅하고, 페르소나 정책으로 14일을 굴린다.
# 반환: { name, days:[일별 스냅샷...], heart_days:{1:일,2:일,...}, softlocks:int, ... }
func _run(p: Persona) -> Dictionary:
	# 새 게임 상태(main의 _ready + Inventory._ready 시작 씨앗을 그대로 모방).
	var clock := GameClock.new()
	var farm := FarmField.new()
	var energy := SoulEnergy.new()
	var wallet := Wallet.new()
	var inv := Inventory.new()
	var aff := Affinity.new()
	for id in Inventory.START_SEEDS:           # 새 게임 시작 씨앗(혼령초 3)
		inv.seeds[id] = Inventory.START_SEEDS[id]

	var plots: Array = []
	for i in N_PLOTS:
		plots.append(Vector2i(i, 0))

	var log: Array = []
	var softlocks := 0
	var heart_days := {}                        # 하트 단계 → 처음 도달한 게임 날
	var foxfire_awake_day := -1                 # 여우불이 처음 깨어난 날

	# day 1..RUN_DAYS 플레이. 각 날 끝에 취침(advance_day+refill). 14번째 취침이
	# day를 15로 올려 RunSummary.is_over → 슬라이스 종료(main과 동일).
	while clock.day <= RUN_DAYS:
		var day: int = clock.day
		var harvested_today := 0
		var planted_today := 0
		var actions := ACTIONS_PER_DAY          # 오늘 가용 행동(혼력/행동)

		# ① 미호 대화(혼력 무관, 하루 1회) — 호감도 느린 채널.
		if p.talk:
			aff.daily_talk(day)

		# ② 수확 먼저(공간 확보) — 다 자란 칸을 거둔다.
		for t in plots:
			if actions <= 0: break
			if farm.is_mature(t):
				var crop := farm.harvest(t)
				if crop != "":
					inv.add_harvest(crop)
					harvested_today += 1
					actions -= 1

		# ③ 미호 선물(혼력 무관, 하루 1회) — 여유 수확물 1개를 빠른 채널로.
		if p.gift and aff.can_gift(day):
			var g := _pick_gift(inv)
			if g != "":
				inv.take_harvest(g)
				aff.gift(g, day)

		# ④ 카페 경제(혼력 무관): 남은 수확물 전량 판매 → 다음 날 심을 씨앗 확보.
		_sell_all(inv, wallet)
		var crop_today: String = p.crop_for_day.call(day, wallet.gold)
		_buy_seeds(inv, wallet, crop_today, p.target_plots)

		# ⑤ 밭 정비(혼력 소모): 운영 칸을 물 주고, 빈 슬롯은 새로 열어 심고 물 준다.
		#    한 칸당 hoe→plant→water가 같은 날 이어질 수 있다(혼력 한도 안에서).
		var wanted_progress := true             # 오늘 농사 진행을 원했는가(소프트락 판정용)
		var made_progress := false
		for t in plots:
			while actions > 0:
				var a := _next_action(farm, inv, t, crop_today, plots, p.target_plots)
				if a == "": break
				match a:
					"hoe": farm.hoe(t)
					"plant":
						farm.plant(t, crop_today); inv.take_seed(crop_today)
						planted_today += 1
					"water": farm.water(t)
				made_progress = true
				actions -= 1

		# 소프트락 = 오늘 새로 심을 칸도 없고(씨앗·골드 없음) 물 줄 작물도 없어 농사가
		# 한 발도 못 나간 날. 14일 내내 0이어야 무막힘(완료기준).
		if wanted_progress and not made_progress and not _has_growing(farm, plots):
			softlocks += 1

		# 일별 스냅샷(취침 직전 = 그날의 결과).
		var hearts: int = aff.hearts()
		if hearts > 0 and not heart_days.has(hearts):
			heart_days[hearts] = day
		if foxfire_awake_day < 0 and Foxfire.is_awake(hearts):
			foxfire_awake_day = day
		log.append({
			"day": day, "gold": wallet.gold, "hearts": hearts, "points": aff.points,
			"harvested": harvested_today, "planted": planted_today,
			"accel": Foxfire.accel(hearts), "reach": Foxfire.reach(hearts),
			"actions_used": ACTIONS_PER_DAY - actions,
		})

		# ⑥ 취침: 날 넘기고(day+1), 끝이 아니면 작물 성장(여우불 반영)+혼력 회복.
		clock.sleep()
		if RunSummary.is_over(clock.day):
			break
		var h := aff.hearts()
		farm.advance_day(Foxfire.accel(h), Foxfire.reach(h))
		energy.refill()

	# 누적 통계.
	var total_harvest := 0
	for d in log:
		total_harvest += d["harvested"]
	var final_gold: int = wallet.gold
	var final_points: int = aff.points
	# SceneTree 밖에서 new()한 노드라 직접 정리한다(누수 경고 방지).
	for n in [clock, farm, energy, wallet, inv, aff]:
		n.free()
	return {
		"name": p.name,
		"log": log,
		"softlocks": softlocks,
		"heart_days": heart_days,
		"foxfire_awake_day": foxfire_awake_day,
		"final_gold": final_gold,
		"final_hearts": (log[-1]["hearts"] as int) if log.size() > 0 else 0,
		"final_points": final_points,
		"total_harvest": total_harvest,
	}


# ── 밭 정책 헬퍼 ────────────────────────────────────────────────────────────
# 이 칸에서 다음에 할 유용한 행동("" = 없음). main의 흐름과 같은 우선순위:
# 물주기 > 심기 > (목표 미달 시)괭이질. 수확은 위 ②에서 따로 처리한다.
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

# 선물할 수확물 하나 고른다(선호 작물 우선, 없으면 아무거나). "" = 선물할 게 없음.
func _pick_gift(inv: Inventory) -> String:
	if inv.harvest_count(Affinity.PREFERRED_CROP) > 0:
		return Affinity.PREFERRED_CROP
	for id in inv.harvested:
		return id
	return ""

# 수확물 전량을 판매가로 환산해 골드로(main._sell_all과 동일).
func _sell_all(inv: Inventory, wallet: Wallet) -> void:
	var total := 0
	for id in inv.harvested:
		total += inv.harvest_count(id) * CropCatalog.sell_price(id)
	if total > 0:
		inv.clear_harvest()
		wallet.earn(total)

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
	print("\n┌─ %s " % r["name"] + "─".repeat(max(0, 50 - r["name"].length())))
	print("│ Day │ 골드 │ 하트 │ 점수 │ 수확 │ 여우불(가속/범위) │ 혼력")
	for d in r["log"]:
		print("│ %3d │ %4d │ %d/%d  │ %3d  │  %d   │   %d칸 / +%d        │ %d/%d" % [
			d["day"], d["gold"], d["hearts"], Affinity.MAX_HEARTS, d["points"],
			d["harvested"], d["reach"], d["accel"], d["actions_used"] * COST, SoulEnergy.MAX])
	print("└" + "─".repeat(52))

func _print_comparison(results: Array) -> void:
	for r in results:
		_run_header(r)
	print("\n══════════════════════ 요약 비교 ══════════════════════")
	print("전략              │ 소프트락 │ 최종골드 │ 최종하트 │ 총수확 │ ♡1 │ ♡2 │ ♡3 │ 여우불깸")
	for r in results:
		var hd: Dictionary = r["heart_days"]
		print("%-17s │   %d일    │  %5d   │   %d/%d    │  %3d   │ %s │ %s │ %s │ %s" % [
			r["name"], r["softlocks"], r["final_gold"], r["final_hearts"], Affinity.MAX_HEARTS,
			r["total_harvest"], _day_str(hd, 1), _day_str(hd, 2), _day_str(hd, 3),
			("D%d" % r["foxfire_awake_day"]) if r["foxfire_awake_day"] > 0 else "잠듦"])

func _day_str(heart_days: Dictionary, h: int) -> String:
	return ("D%d " % heart_days[h]) if heart_days.has(h) else "-- "


# ── 판정 초안(전제조건 정량 체크) ────────────────────────────────────────────
# 봇은 재미를 못 느낀다 → '또 하고 싶나'는 사람 몫. 여기선 재미의 전제조건만 ✓/✗로
# 평가해, 사람이 그 위에 주관 판정을 얹을 근거를 만든다.
func _print_verdict(results: Array) -> void:
	print("\n══════════════════ 판정 초안(전제조건) ══════════════════")

	var talker: Dictionary = results[0]
	var gifter: Dictionary = results[1]
	var farmer: Dictionary = results[2]

	# ① 무막힘: 모든 전략이 14일 내내 소프트락 0.
	var no_softlock := true
	for r in results:
		if r["softlocks"] > 0:
			no_softlock = false
	_check("① 무막힘 — 세 전략 모두 14일 동안 한 번도 막히지 않음", no_softlock)

	# ② 우상향 엔진: 대화만 하는 Talker도 여우불이 14일 안에 깨어남(체감 ♡2+).
	var engine_on: bool = talker["foxfire_awake_day"] > 0 and (talker["final_hearts"] as int) >= 2
	_check("② 우상향 엔진 — 대화만으로도 여우불이 켜지고 ♡2+ 도달", engine_on)

	# ③ 페이싱: miho-heart-arc 목표(♡1≈D5, ♡2≈D10)에 근접(±2일 허용).
	var hd: Dictionary = talker["heart_days"]
	var pacing: bool = hd.has(1) and hd.has(2) and absi((hd[1] as int) - 5) <= 2 and absi((hd[2] as int) - 10) <= 2
	_check("③ 페이싱 — Talker ♡1≈D5·♡2≈D10 목표 곡선에 부합", pacing)

	# ④ 선택의 가치: 세 전략이 의미 있게 다른 결과(골드·하트가 갈림).
	var golds := [talker["final_gold"], gifter["final_gold"], farmer["final_gold"]]
	var hearts := [talker["final_hearts"], gifter["final_hearts"], farmer["final_hearts"]]
	var gold_spread: bool = (golds.max() - golds.min()) >= 100
	var heart_spread: bool = hearts.max() != hearts.min()
	_check("④ 선택의 가치 — 전략별 결과가 갈림(골드 격차≥100 & 하트 갈림)", gold_spread and heart_spread)

	# ⑤ 대조군: 관계를 버린 Farmer는 여우불이 잠든 채(엔진 꺼짐)임을 확인.
	_check("⑤ 대조군 — 관계 무시(Farmer)는 여우불이 끝까지 잠듦", farmer["foxfire_awake_day"] < 0)

	print("\n※ 위는 '재미의 전제조건'이다. 모두 ✓라도 '또 하고 싶나'(주관)는 사람이")
	print("  직접 14일을 플레이해 판정해야 한다 — 봇은 굴러가는지·곡선이 켜지는지까지만 본다.")

func _check(label: String, ok: bool) -> void:
	print(("  ✓ " if ok else "  ✗ ") + label)
