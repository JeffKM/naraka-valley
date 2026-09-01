extends SceneTree
# ★[S10-T8 / ADR-0069 결정 11] 명부 시련장(trial_ground.gd + main 배선) 검증 — ephemeral 헤드리스.
# "반딧넋 30으로 열린 문 뒤에서 주간 시련을 치르고 시련패로 바꾼다"가 코드로 성립하는지 본다.
#
# ★ 핵심 불변식(수락 기준 6축 + 침범 금지 2축):
#   ① 주 시드 파생 — 시련은 **상태가 아니다**. 같은 주면 몇 번을 굴려도 같고, 다른 주는 갈린다.
#      ★ 카운트만 세지 않는다: **두 유형이 실제로 등장하는지**·기한이 QuestBoard 주 계산과
#      한 톨도 안 어긋나는지를 구성 요소로 짚는다.
#   ② 납품 풀 — **ItemCatalog.MINERALS 파생**(하드코딩 목록 0). 가격 밴드 밖(돌·명부금강·
#      오색혼옥)은 구조적으로 안 실린다.
#   ③ 수락·진행·완료 — 동시 1건 · 처치 진행은 **수락 뒤에만** 세고 상한에서 멈춘다 · 납품은
#      보유량 기준 · 완료 시 시련패 적립 · 중복 완료 차단 · 기한 만료는 무페널티.
#   ④ 상점 — 잔고 게이트 · 1회성 소진 · 반복 구매 · **레어크로우 ⑧이 8슬롯의 마지막 칸**.
#   ⑤ ⚠️⚠️ **재점령 정지류 금지**([ADR-0055]) — kind 화이트리스트 · 금지 id 부재 · main 라우팅
#      문자열 대조(오타 = 클릭 무반응이라 소스로 잠근다).
#   ⑥ main 배선 — 게이트 전엔 방이 **등록조차 안 된다**(잠긴 외관) · 반딧넋 30이면 선다 ·
#      실그리드에서 문·게시판·매대가 걸어 닿는다 · 세이브 왕복 · 하위호환.
#   ⑦ ⚠️ **quest_board 불침범** — 소스에 시련 흔적 0 · 주간/일일 의뢰 파생이 시련 롤 전후로
#      **한 바이트도 안 바뀐다** · 전역 RNG 미소비(seed 고정 후 상태 불변).
#   ⑧ ⚠️ **[ADR-0019] % 곱셈 부재** — 시련장은 물건과 화폐만 다룬다(배수 필드 0).
# 실행: godot --headless --path game --script res://playtest/trial_ground_test.gd

var _fail := 0

func _check(label: String, ok: bool) -> void:
	print(("  ✓ " if ok else "  ✗ ") + label)
	if not ok:
		_fail += 1

func _spawn_main() -> Node:
	var m: Node = load("res://main.tscn").instantiate()
	root.add_child(m)
	await process_frame
	await process_frame
	return m

func _despawn(m: Node) -> void:
	m.queue_free()
	await process_frame
	await process_frame

func _read_bytes(path: String) -> PackedByteArray:
	var f := FileAccess.open(path, FileAccess.READ)
	var b := f.get_buffer(f.get_length())
	f.close()
	return b

func _write_bytes(path: String, bytes: PackedByteArray) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_buffer(bytes)
	f.close()

# 시련 dict → 비교용 지문(전 필드 — 필드가 하나라도 흔들리면 문자열이 갈린다).
func _fp(t: Dictionary) -> String:
	if t.is_empty():
		return "-"
	var keys: Array = t.keys()
	keys.sort()
	var rows := PackedStringArray()
	for k in keys:
		rows.append("%s=%s" % [str(k), str(t[k])])
	return "|".join(rows)

# 게시판 파생 지문(quest_board 불침범 골든 서명 — 12주 + 20일치를 통째로 접는다).
func _quest_signature() -> String:
	var rows := PackedStringArray()
	for w in 12:
		rows.append(_fp(QuestBoard.weekly_quest(w)))
	for d in range(1, 21):
		rows.append(_fp(QuestBoard.daily_quest(d)))
	return "||".join(rows)

# 반딧넋 원장을 n개 안치한 상태로 만든다(고정 배치 앞에서부터 — main 훅을 안 거치는 직접 주입).
func _fill_fireflies(m: Node, n: int) -> void:
	var save := {"collected": {}, "claimed": []}
	var ids := FireflySouls.all_ids()
	for i in mini(n, ids.size()):
		save["collected"][String(ids[i])] = 1
	m.fireflies.load_save(save)

# 그 주에 그 유형이 걸리는 첫 주 인덱스(-1 = 범위 안에 없음).
func _find_week(kind: String, limit: int) -> int:
	for w in limit:
		var t := TrialGround.weekly_trial(w)
		if not t.is_empty() and String(t["kind"]) == kind:
			return w
	return -1

func _initialize() -> void:
	print("══ S10-T8 명부 시련장 검증 ══")

	# ── ⑦-pre quest_board 골든 서명(시련 코드를 한 번도 안 부른 상태에서 먼저 뜬다) ──
	var quest_before := _quest_signature()

	# ── ① 주 시드 파생(결정성·유형 구성) ──
	print("── ① 주 시드 파생 ──")
	var t0a := TrialGround.weekly_trial(0)
	var t0b := TrialGround.weekly_trial(0)
	_check("①a 같은 주 = 같은 시련(전 필드 동일)", not t0a.is_empty() and _fp(t0a) == _fp(t0b))
	var sigs: Dictionary = {}
	var kinds: Dictionary = {}
	for w in 24:
		var t := TrialGround.weekly_trial(w)
		if t.is_empty():
			continue
		sigs[_fp(t)] = true
		kinds[String(t["kind"])] = int(kinds.get(String(t["kind"]), 0)) + 1
	_check("①b 24주에 서로 다른 시련이 여럿 나온다(고정 반복 0 — 서로 다른 %d종)" % sigs.size(),
		sigs.size() >= 8)
	_check("①c ★유형 **둘 다** 등장 — 처치 %d주 · 납품 %d주(둘 중 하나가 0이면 실패)"
			% [int(kinds.get(TrialGround.KIND_SLAY, 0)), int(kinds.get(TrialGround.KIND_DELIVER, 0))],
		int(kinds.get(TrialGround.KIND_SLAY, 0)) > 0 and int(kinds.get(TrialGround.KIND_DELIVER, 0)) > 0)
	_check("①d 유형 키가 정확히 둘뿐이다(미지 kind 0)", kinds.size() == 2)
	var bad_due := 0
	var bad_count := 0
	for w2 in 24:
		var t2 := TrialGround.weekly_trial(w2)
		if t2.is_empty():
			continue
		if int(t2["due_day"]) != QuestBoard.week_last_day(w2):
			bad_due += 1
		var lo := TrialGround.SLAY_MIN if String(t2["kind"]) == TrialGround.KIND_SLAY else TrialGround.DELIVER_MIN
		var hi := TrialGround.SLAY_MAX if String(t2["kind"]) == TrialGround.KIND_SLAY else TrialGround.DELIVER_MAX
		if int(t2["count"]) < lo or int(t2["count"]) > hi:
			bad_count += 1
	_check("①e 기한 = QuestBoard.week_last_day(주 계산의 단일 출처 — 어긋난 주 %d)" % bad_due, bad_due == 0)
	_check("①f 수량이 유형별 밴드 안(처치 %d~%d · 납품 %d~%d — 벗어난 주 %d)" % [
			TrialGround.SLAY_MIN, TrialGround.SLAY_MAX,
			TrialGround.DELIVER_MIN, TrialGround.DELIVER_MAX, bad_count], bad_count == 0)
	_check("①g 손상 방어 — 음수 주는 빈 시련", TrialGround.weekly_trial(-1).is_empty())
	_check("①h 주 인덱스도 QuestBoard 파생(day 1~7 = 0주 · 8 = 1주)",
		TrialGround.week_of(1) == 0 and TrialGround.week_of(7) == 0 and TrialGround.week_of(8) == 1)

	# ── ② 납품 풀(로스터 파생) ──
	print("── ② 납품 풀 ──")
	var pool := TrialGround.deliver_pool()
	var expect_pool: Array = []
	for id in ItemCatalog.MINERALS:
		var pr := int(ItemCatalog.MINERALS[id].get("price", 0))
		if pr >= TrialGround.DELIVER_PRICE_MIN and pr <= TrialGround.DELIVER_PRICE_MAX:
			expect_pool.append(String(id))
	expect_pool.sort()
	_check("②a 풀 = MINERALS 가격 밴드 파생(하드코딩 목록 0 — %d종)" % pool.size(),
		pool == expect_pool and not pool.is_empty())
	_check("②b ★구성 명시 — 넋수정·명옥·업화알돌이 들어 있다",
		pool.has(ItemCatalog.GEM_NEOKSUJEONG) and pool.has(ItemCatalog.GEM_MYEONGOK)
		and pool.has(ItemCatalog.GEODE_EOPHWA))
	_check("②c ★밴드 밖은 구조적으로 없다 — 돌(지천)·명부금강/오색혼옥(초희귀)",
		not pool.has(ItemCatalog.STONE) and not pool.has(ItemCatalog.GEM_MYEONGBU_GEUMGANG)
		and not pool.has(ItemCatalog.GEM_OSAEK_HONOK))
	var off_pool := 0
	for w3 in 40:
		var t3 := TrialGround.weekly_trial(w3)
		if not t3.is_empty() and String(t3["kind"]) == TrialGround.KIND_DELIVER \
				and not pool.has(String(t3["item_id"])):
			off_pool += 1
	_check("②d 40주 동안 풀 밖 아이템을 요구한 적 0회", off_pool == 0)

	# ── ③ 수락·진행·완료(순수 원장 — main 없이) ──
	print("── ③ 수락·진행·완료 ──")
	var led := TrialGround.new()
	var wk_slay := _find_week(TrialGround.KIND_SLAY, 40)
	var wk_del := _find_week(TrialGround.KIND_DELIVER, 40)
	_check("③a 두 유형의 표본 주를 찾았다(처치 %d주 · 납품 %d주)" % [wk_slay, wk_del],
		wk_slay >= 0 and wk_del >= 0)
	var st := TrialGround.weekly_trial(wk_slay)
	var sday := wk_slay * 7 + 1
	_check("③b 수락 전 처치는 안 센다(계약 밖의 전투는 시련이 아니다)", not led.note_kill(sday))
	_check("③c 수락 성공 · 동시 1건(둘째 수락 거절)",
		led.accept(st, sday) and not led.accept(st, sday) and led.is_active())
	for _i in int(st["count"]):
		led.note_kill(sday)
	_check("③d 처치 진행이 요구 수까지 찬다(%d/%d)" % [led.progress(), led.required_count()],
		led.progress() == int(st["count"]))
	_check("③e ★상한에서 멈춘다(초과 처치가 진행에 안 쌓임)", not led.note_kill(sday))
	_check("③f 처치형은 인벤 보유량을 안 본다(have=0이어도 완료 성립)", led.can_complete(sday, 0))
	var done := led.complete(sday, 0)
	_check("③g 완료 — 시련패 +%d 적립 · 원장 이력 1건 · active 비움" % TrialGround.TOKEN_REWARD,
		not done.is_empty() and led.tokens == TrialGround.TOKEN_REWARD
		and led.completed_count() == 1 and not led.is_active())
	_check("③h 같은 주 중복 수락 차단(완료 이력이 게시를 막는다)", led.offer(sday).is_empty())
	# 납품형
	var dt := TrialGround.weekly_trial(wk_del)
	var dday := wk_del * 7 + 1
	_check("③i 납품형 수락", led.accept(dt, dday) and led.required_item() == String(dt["item_id"]))
	_check("③j 보유량 부족 = 완료 불가 / 충족 = 가능",
		not led.can_complete(dday, int(dt["count"]) - 1) and led.can_complete(dday, int(dt["count"])))
	var tok_before := led.tokens
	led.complete(dday, int(dt["count"]))
	_check("③k 납품 완료 — 시련패가 또 한 번 적립(%d → %d)" % [tok_before, led.tokens],
		led.tokens == tok_before + TrialGround.TOKEN_REWARD and led.completed_count() == 2)
	# 만료(무페널티)
	var led2 := TrialGround.new()
	var wk2 := 3
	var t_exp := TrialGround.weekly_trial(wk2)
	led2.accept(t_exp, wk2 * 7 + 1)
	led2.tokens = 5
	var dropped := led2.advance_day(int(t_exp["due_day"]) + 1)
	_check("③l 기한 만료 — 조용히 버린다 · **시련패 불변**(무페널티 · ADR-0008)",
		not dropped.is_empty() and not led2.is_active() and led2.tokens == 5
		and led2.completed_count() == 0)

	# ── ④ 상점(잔고·1회성·레어크로우 ⑧) ──
	print("── ④ 시련패 상점 ──")
	var rows := TrialGround.shop_rows()
	var by_kind: Dictionary = {}
	for r in rows:
		by_kind[String(r["kind"])] = int(by_kind.get(String(r["kind"]), 0)) + 1
	_check("④a ★구성 명시 — 수집 스킨 %d · 장식 %d · 편의 %d(셋 다 1개 이상)" % [
			int(by_kind.get(TrialGround.SHOP_RARECROW, 0)),
			int(by_kind.get(TrialGround.SHOP_DECO, 0)),
			int(by_kind.get(TrialGround.SHOP_ITEM, 0))],
		int(by_kind.get(TrialGround.SHOP_RARECROW, 0)) >= 1
		and int(by_kind.get(TrialGround.SHOP_DECO, 0)) >= 1
		and int(by_kind.get(TrialGround.SHOP_ITEM, 0)) >= 1)
	_check("④b ★레어크로우 ⑧ = ItemCatalog.RARECROW_8 이고 **8슬롯의 마지막 칸**(분모 파생 — %d종 중 %d번째)"
			% [ItemCatalog.RARECROWS.size(), ItemCatalog.RARECROWS.size()],
		not TrialGround.shop_row(ItemCatalog.RARECROW_8).is_empty()
		and String(ItemCatalog.RARECROWS[ItemCatalog.RARECROWS.size() - 1]) == ItemCatalog.RARECROW_8)
	var led3 := TrialGround.new()
	_check("④c 잔고 0 = 아무것도 못 산다", not led3.can_buy(ItemCatalog.RARECROW_8)
		and led3.spend(ItemCatalog.RARECROW_8) == 0)
	led3.tokens = 999
	var crow_price := TrialGround.price_of(ItemCatalog.RARECROW_8)
	_check("④d 1회성 결제 — 잔고 차감 · 이력 기록",
		led3.spend(ItemCatalog.RARECROW_8) == crow_price
		and led3.tokens == 999 - crow_price and led3.has_bought(ItemCatalog.RARECROW_8))
	_check("④e 1회성 재구매 차단(세상에 한 마리뿐)", not led3.can_buy(ItemCatalog.RARECROW_8)
		and led3.spend(ItemCatalog.RARECROW_8) == 0)
	var tok3 := led3.tokens
	var item_price := TrialGround.price_of(ItemCatalog.FERT_DELUXE)
	_check("④f 반복 구매(편의 소모품)는 이력을 안 남기고 계속 산다",
		led3.spend(ItemCatalog.FERT_DELUXE) == item_price
		and led3.spend(ItemCatalog.FERT_DELUXE) == item_price
		and led3.tokens == tok3 - item_price * 2 and not led3.has_bought(ItemCatalog.FERT_DELUXE))
	_check("④g 표에 없는 id는 값 0(결제 불성립 — 매대 밖 구매 구멍 차단)",
		TrialGround.price_of("존재하지_않는_id") == 0 and not led3.can_buy("존재하지_않는_id"))

	# ── ⑤ ⚠️ 재점령 정지류 금지 가드([ADR-0055]) ──
	print("── ⑤ ⚠️ 재점령 정지류 금지 가드 ──")
	var off_kind: Array = []
	var banned_hit: Array = []
	var effect_field: Array = []
	# ★[폴리시 R4] 금지 목록은 이제 카탈로그 파생이다(옛 하드코딩 배열은 5개 중 3개가 유령 id라
	#   ⑤b가 사실상 "scythe" 한 줄만 지켰다). 여기서 **구성 요소를 명시 대조**해 파생이 실제로
	#   실물 id를 담고 있는지부터 잠근다 — 카운트만 세면 같은 함정을 되밟는다.
	var banned: Array = TrialGround.reclaim_banned_ids()
	var banned_must: Array = [ItemCatalog.SCYTHE, DebrisCatalog.WEEDS, DebrisCatalog.EMBER,
		DebrisCatalog.STUMP, ItemCatalog.SOUL_FIBER, ItemCatalog.EMBER_SHARD,
		ItemCatalog.PETRIFIED_WOOD]
	var banned_missing: Array = []
	for want in banned_must:
		if not banned.has(want):
			banned_missing.append(str(want))
	_check("⑤b0 ★금지 목록이 실물 id를 전부 담는다 — 낫·debris kind 3·그 드랍 3(누락: %s)"
		% str(banned_missing), banned_missing.is_empty())
	for r2 in rows:
		var row: Dictionary = r2
		var k := String(row["kind"])
		if not TrialGround.SHOP_KINDS.has(k):
			off_kind.append(k)
		if banned.has(String(row["buy_id"])):
			banned_hit.append(String(row["buy_id"]))
		# ★[ADR-0019] 배수·확률·지속 효과를 담을 칸이 **행 스키마에 아예 없다**.
		for key in row.keys():
			if not ["kind", "buy_id", "price", "once"].has(String(key)):
				effect_field.append("%s.%s" % [String(row["buy_id"]), String(key)])
	_check("⑤a kind 화이트리스트 밖 0(발견: %s)" % str(off_kind), off_kind.is_empty())
	_check("⑤b ★재점령 도메인 id 0 — 낫·잡초 드랍·debris 계열을 안 판다(발견: %s)" % str(banned_hit),
		banned_hit.is_empty())
	_check("⑤c ★[ADR-0019] 행 스키마에 배수·확률·지속 칸이 없다(발견: %s)" % str(effect_field),
		effect_field.is_empty())
	# main 라우팅 문자열 대조(오타 = 클릭 무반응 — peddler_test ⑫가 연 그 클래스를 같이 닫는다)
	var main_src := FileAccess.open("res://main.gd", FileAccess.READ).get_as_text()
	var miss_route: Array = []
	for k2 in TrialGround.SHOP_KINDS:
		if not main_src.contains("\"%s\"" % String(k2)):
			miss_route.append(String(k2))
	_check("⑤d main 구매 라우팅에 3종 kind 전부 존재(누락 %s)" % str(miss_route), miss_route.is_empty())
	var frame_src := FileAccess.open("res://inv_frame.gd", FileAccess.READ).get_as_text()
	var allow_line := ""
	for ln in frame_src.split("\n"):
		var s2 := String(ln).strip_edges()
		if s2.begins_with("#"):
			continue
		if s2.contains("\"sapling\"") and s2.ends_with(":"):
			allow_line = s2
			break
	var miss_allow: Array = []
	for k3 in TrialGround.SHOP_KINDS:
		if not allow_line.contains("\"%s\"" % String(k3)):
			miss_allow.append(String(k3))
	_check("⑤e ★프레임 kind 허용 목록에 3종 전부(빠지면 클릭이 조용히 죽는다 — 누락 %s)"
			% str(miss_allow), allow_line != "" and miss_allow.is_empty())

	# ── ⑥ main 배선(게이트·무대·세이브) ──
	print("── ⑥ main 배선 ──")
	var SAVE := "user://save.dat"
	var BAK := "user://save.dat.trialbak"
	var had_save := FileAccess.file_exists(SAVE)
	if had_save:
		_write_bytes(BAK, _read_bytes(SAVE))
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))

	var m: Node = await _spawn_main()
	_check("⑥a 부팅 — 시련장·경지 원장이 섰다(시련패 0 · 수락 0)",
		m.trial != null and m.mastery != null and m.trial.tokens == 0 and not m.trial.is_active())
	_check("⑥b ★게이트 전 — 문이 닫혀 있고 방은 **카탈로그에 등록조차 안 된다**(잠긴 외관)",
		not m.trial_ground_open() and not m._buildings.has("시련장"))
	# ★[폴리시] 게이트가 열리는 프레임은 **건물 카탈로그를 통째로 다시 세운다** — 그 재구성이 집
	#   실내 카메라의 안방 확장분을 날려 먹던 결함의 자리다(잘린 안방·화면 밖으로 걸어 나감). 먼저
	#   안방을 확장해 두고, 아래 ⑥d에서 문이 열린 *뒤*에 카메라가 살아남는지 잰다.
	m.carpenter.load_save({"done": [Carpenter.PROJ_MASTER_ROOM]})
	m._refresh_home_expansion()
	_check("⑥b-1 전제 — 안방 확장 완공 · 집 카메라가 확장 rect",
		m._home_expanded() and m._buildings["집"]["cam"] == m.HOME_HOUSE_CAM_RECT_EXPANDED)
	_fill_fireflies(m, FireflySouls.GATE_COUNT - 1)
	m._refresh_trial_gate()
	_check("⑥c 문턱 −1(반딧넋 %d) — 여전히 닫힘(경계 단언)" % (FireflySouls.GATE_COUNT - 1),
		not m.trial_ground_open() and not m._buildings.has("시련장"))
	_fill_fireflies(m, FireflySouls.GATE_COUNT)
	m._refresh_trial_gate()
	_check("⑥d 문턱 도달(반딧넋 %d) — 열리고 방이 카탈로그에 선다" % FireflySouls.GATE_COUNT,
		m.trial_ground_open() and m._buildings.has("시련장"))
	# ★[폴리시] 문이 열려도 **집 카메라의 안방 확장분이 살아 있다** — 카탈로그는 이제 상수 대신
	#   `home_house_cam_rect()`를 파생해 담으므로, 어느 재구성 경로를 타든 확장분이 안 날아간다.
	#   방 rect와 짝이 맞는지도 함께 본다(카메라만 좁으면 안방 동쪽이 화면 밖으로 잘린다).
	_check("⑥d-1 ★게이트 갱신이 집 실내 카메라의 안방 확장분을 안 지운다",
		m._buildings["집"]["cam"] == m.HOME_HOUSE_CAM_RECT_EXPANDED)
	_check("⑥d-2 카메라가 확장 방 rect를 통째로 담는다(잘린 안방 0)",
		(m._buildings["집"]["cam"] as Rect2i).encloses(m.home_house_rect()))
	# 미확장 세이브에선 같은 경로가 원본 rect를 낸다(파생이 확장을 *발명*하지 않는다는 대조군).
	m.carpenter.load_save({"done": []})
	m._build_building_catalog()
	_check("⑥d-3 대조군 — 미확장이면 카탈로그가 원본 카메라 rect를 낸다",
		not m._home_expanded() and m._buildings["집"]["cam"] == m.HOME_HOUSE_CAM_RECT)
	m.carpenter.load_save({"done": [Carpenter.PROJ_MASTER_ROOM]})
	m._refresh_home_expansion()
	var b: Dictionary = m._buildings["시련장"]
	_check("⑥e 방 레코드 — 갱도 구역 · kind=trial · 2칸 문(외관·실내 모두)",
		String(b["region"]) == RegionCatalog.EOPHWA_MINE and String(b["kind"]) == "trial"
		and b.has("ext_door2") and b.has("door2"))
	# 실그리드 — 갱도로 옮겨 외관 문·곁가지가 이어졌는지, 방 안 두 창구가 바닥인지 본다.
	m._rebuild_region(RegionCatalog.EOPHWA_MINE)
	var C: Dictionary = m.get_script().get_script_constant_map()
	var ext_door: Vector2i = C["TRIAL_EXT_DOOR"]
	var ext_door_e: Vector2i = C["TRIAL_EXT_DOOR_E"]
	var board_t: Vector2i = C["TRIAL_BOARD_TILE"]
	var shop_t: Vector2i = C["TRIAL_SHOP_TILE"]
	var in_t: Vector2i = C["TRIAL_IN_TILE"]
	var room: Rect2i = C["TRIAL_RECT"]
	_check("⑥f 외관 문 2칸이 PATH이고 곁가지(y7)와 이어진다",
		m._grid[ext_door.y][ext_door.x] == m.PATH and m._grid[ext_door_e.y][ext_door_e.x] == m.PATH
		and m._grid[7][ext_door.x] == m.PATH and m._grid[7][ext_door_e.x] == m.PATH)
	_check("⑥g ⚠️ 나락 진입로·던전 입구 좌표 불변(침범 0)",
		m._grid[(C["NARAK_GATE_DOOR"] as Vector2i).y][(C["NARAK_GATE_DOOR"] as Vector2i).x] == m.PATH
		and m._grid[(C["DUNGEON_GATE_DOOR"] as Vector2i).y][(C["DUNGEON_GATE_DOOR"] as Vector2i).x] == m.PATH)
	_check("⑥h 두 창구가 방 안 실내 바닥이고 진입 착지 칸과 겹치지 않는다",
		room.has_point(board_t) and room.has_point(shop_t) and room.has_point(in_t)
		and board_t != shop_t and board_t != in_t and shop_t != in_t
		and not m.is_solid(m._grid[board_t.y][board_t.x])
		and not m.is_solid(m._grid[shop_t.y][shop_t.x]))
	_check("⑥i 카메라 둘레가 길드 방과 안 겹친다(방끼리 안 새는 격리)",
		not (C["TRIAL_CAM_RECT"] as Rect2i).intersects(C["GUILD_CAM_RECT"] as Rect2i))
	# 게시판 [F] — 실제 수락·완료 사다리를 main 경로로 굴린다.
	m._indoor = "시련장"
	m.clock.day = wk_slay * 7 + 1
	m._use_trial_board()
	_check("⑥j 게시판 [F] — 이번 주 시련을 수락했다", m.trial.is_active())
	var need: int = m.trial.required_count()
	if m.trial.kind_of_active() == TrialGround.KIND_SLAY:
		for _k in need:
			m._note_trial_kill()
	else:
		m.inventory.add_item(m.trial.required_item(), need)
	m._use_trial_board()
	_check("⑥k 게시판 [F] — 완료 · 시련패 %d 적립" % m.trial.tokens,
		not m.trial.is_active() and m.trial.tokens == TrialGround.TOKEN_REWARD)
	# 매대 — 레어크로우 ⑧을 실제로 산다(획득처 ⑧의 종단 검증).
	m.trial.tokens = 999
	var crow_before: int = m.inventory.count_of(ItemCatalog.RARECROW_8)
	m._try_buy_trial_item(ItemCatalog.RARECROW_8)
	_check("⑥l ★획득처 ⑧ — 시련패로 레어크로우 ⑧을 백팩에 받았다",
		m.inventory.count_of(ItemCatalog.RARECROW_8) == crow_before + 1
		and m.trial.has_bought(ItemCatalog.RARECROW_8))
	var rows_ui: Array = m._trial_shop_items()
	var locked_crow := false
	for r3 in rows_ui:
		if String((r3 as Dictionary)["buy_id"]) == ItemCatalog.RARECROW_8:
			locked_crow = bool((r3 as Dictionary).get("locked", false))
	_check("⑥m 매대 행이 즉시 '구입함'으로 잠긴다(%d행 진열)" % rows_ui.size(),
		locked_crow and not rows_ui.is_empty())
	# 세이브 왕복
	m._indoor = ""
	m._rebuild_region(RegionCatalog.HOME)
	var tok_live: int = m.trial.tokens
	var comp_live: int = m.trial.completed_count()
	m._save_game()
	await _despawn(m)
	var m2: Node = await _spawn_main()
	_check("⑥n 재부팅 복원 — 시련패 %d · 완료 이력 %d · 1회성 구매 · **문 열린 채**"
			% [tok_live, comp_live],
		m2.trial.tokens == tok_live and m2.trial.completed_count() == comp_live
		and m2.trial.has_bought(ItemCatalog.RARECROW_8)
		and m2.trial_ground_open() and m2._buildings.has("시련장"))
	m2.trial.load_save({})
	_check("⑥o 하위호환 — 키 없는 구세이브는 빈 원장(막히는 것 0)",
		m2.trial.tokens == 0 and m2.trial.completed_count() == 0 and m2.trial.bought.is_empty()
		and not m2.trial.is_active())
	m2.trial.load_save({"bought": ["사라진_품목", "", ItemCatalog.RARECROW_8], "tokens": -5})
	_check("⑥p 손상 방어 — 표에서 사라진 id·빈 id 드롭 · 음수 잔고는 0으로",
		m2.trial.bought.size() == 1 and m2.trial.has_bought(ItemCatalog.RARECROW_8)
		and m2.trial.tokens == 0)
	# 실내 _draw 크래시 없음(그레이박스 렌더가 실무대에서 돈다)
	m2._rebuild_region(RegionCatalog.EOPHWA_MINE)
	m2._indoor = "시련장"
	m2.queue_redraw()
	await process_frame
	await process_frame
	_check("⑥q 시련장 실내 _draw 크래시 없음(게시판·매대 그레이박스)", true)
	await _despawn(m2)

	# ── ⑦ ⚠️ quest_board 불침범 ──
	print("── ⑦ ⚠️ quest_board 불침범 ──")
	var qb_src := FileAccess.open("res://quest_board.gd", FileAccess.READ).get_as_text()
	_check("⑦a quest_board.gd 소스에 시련 흔적 0(파일을 안 건드렸다)",
		not qb_src.contains("Trial") and not qb_src.contains("trial") and not qb_src.contains("시련"))
	# 시련 롤을 대량으로 굴린 **뒤** 게시판 파생이 그대로인가(시드 네임스페이스 분리의 실증).
	# ★ 전역 RNG 미소비도 같은 자리에서 잰다: 같은 seed를 두 번 심고, 한쪽은 그냥 뽑고 다른 쪽은
	#   시련 롤 200회 *뒤에* 뽑는다. 시련장이 전역 수열을 한 톨이라도 쓰면 두 값이 갈린다.
	seed(20260815)
	var rng_probe_before := randi()
	seed(20260815)
	for w4 in 200:
		TrialGround.weekly_trial(w4)
		TrialGround.shop_rows()
	var rng_probe_after := randi()
	_check("⑦b ★게시판 12주 + 20일치 파생이 시련 롤 200회 전후로 **한 바이트도 안 바뀐다**",
		_quest_signature() == quest_before)
	_check("⑦c ★전역 RNG 미소비 — 같은 seed에서 뽑은 첫 난수가 동일(rand_from_seed 순수 해시)",
		rng_probe_after == rng_probe_before)
	var tg_src := FileAccess.open("res://trial_ground.gd", FileAccess.READ).get_as_text()
	_check("⑦d 시련장 소스에 전역 랜덤 호출 0(randi(·randf(·randi_range( 부재)",
		not tg_src.contains("randi(") and not tg_src.contains("randf(")
		and not tg_src.contains("randi_range("))

	if had_save:
		_write_bytes(SAVE, _read_bytes(BAK))
		DirAccess.remove_absolute(ProjectSettings.globalize_path(BAK))
	elif FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))

	print("══ 결과: %s ══" % ("PASS (실패 0)" if _fail == 0 else "FAIL (실패 %d)" % _fail))
	quit(1 if _fail > 0 else 0)
