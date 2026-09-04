extends SceneTree
# ★[S10-T8 / ADR-0069 결정 11] 경지(mastery.gd + main 배선) 검증 — ephemeral 헤드리스.
# "5스킬 만렙 뒤 넘쳐 쌓인 XP가 포인트가 되고 스킬마다 유물 하나를 준다"가 코드로 성립하는지 본다.
#
# ★ 핵심 불변식(수락 기준 5축 + 침범 금지 3축):
#   ① 로스터 완전성 — **스킬 5종 각각에** 유물 1점. ★ 카운트만 세지 않는다: 농사·채집·낚시·
#      채광·전투 **각 키의 존재를 이름으로 명시 단언**하고, 분모는 ProfessionCatalog에서 파생한다.
#   ② ⚠️⚠️ **[ADR-0019] 영구 % 곱셈 부재** — 유물 스키마에 배수·확률·지속을 담을 칸이 아예 없다
#      (허용 키 화이트리스트로 잠근다). 답례는 전부 **실존 아이템의 flat 일회성 지급**이다.
#   ③ ⚠️ **트링켓 슬롯 비상속**(결정 1 서랍 · 결정 11) — 장착·슬롯·부착 어휘가 소스에 0.
#   ④ 초과 XP·문턱 — 만렙 XP는 FarmSkill 곡선 파생(숫자 하드코딩 0) · 초과 경계 ±1 ·
#      누적 문턱 5단 경계 ±1 · **포인트 5 = 유물 5**의 파리티.
#   ⑤ 개방 — 4스킬 만렙 + 1 미달이면 닫힘 / 전부 만렙이면 열림. 남은 스킬 목록이 구성으로 뜬다.
#   ⑥ main 배선 — 만렙 전 숙련 탭엔 경지 줄이 **첫 행 하나뿐**(잔소리 0의 실질 — 나머지 넷은
#      침묵 · ★[폴리시 R21 #8] 개정), 만렙 후엔 다섯 행에 선다 · 수령이 백팩에 물건을 넣고
#      원장에 적는다 · 세이브 왕복 · 하위호환 · 미지 id 드롭.
#   ⑦ ⚠️ **[ADR-0008] 평평≠막힘** — 경지는 만렙 *뒤*의 추가 층이라 기존 스킬 계수(혼력 감산 등)를
#      한 톨도 안 건드린다(수령 전후 비교).
# 실행: godot --headless --path game --script res://playtest/mastery_test.gd

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

# 전 스킬을 만렙(+overflow)으로 만든다. main의 XP 스칼라를 직접 세운다(적립 경로는 각 스킬 테스트 소관).
func _max_all_skills(m: Node, overflow_each: int) -> void:
	var xp := Mastery.max_level_xp() + overflow_each
	m._farming_xp = xp
	m._foraging_xp = xp
	m._fishing_xp = xp
	m._mining_xp = xp
	m._combat_xp = xp
	m._refresh_max_hp()

func _initialize() -> void:
	print("══ S10-T8 경지 검증 ══")

	# ── ① 로스터 완전성(구성 요소 명시) ──
	print("── ① 유물 로스터 ──")
	_check("①a ★분모 파생 — 유물 수 %d = ProfessionCatalog.SKILLS %d(하드코딩 5 없음)"
			% [Mastery.artifact_count(), ProfessionCatalog.SKILLS.size()],
		Mastery.artifact_count() == ProfessionCatalog.SKILLS.size()
		and Mastery.missing_skills().is_empty())
	# ★ 각 스킬 키를 **이름으로** 짚는다(카운트만 세면 한 스킬이 두 번 들어가도 통과한다).
	var per_skill_ok := true
	var names := PackedStringArray()
	for s in [ProfessionCatalog.FARMING, ProfessionCatalog.FORAGING, ProfessionCatalog.FISHING,
			ProfessionCatalog.MINING, ProfessionCatalog.COMBAT]:
		var a := Mastery.artifact_of(String(s))
		if a.is_empty() or String(a.get("name", "")) == "" or String(a.get("reward_id", "")) == "":
			per_skill_ok = false
		else:
			names.append("%s=%s" % [String(s), String(a["name"])])
	_check("①b ★스킬별 유물 명시 — %s" % " · ".join(names), per_skill_ok)
	var ids: Dictionary = {}
	var bad_reward: Array = []
	for s2 in Mastery.skills():
		var a2 := Mastery.artifact_of(String(s2))
		ids[String(a2["id"])] = true
		if not ItemCatalog.has_item(String(a2["reward_id"])) or int(a2["n"]) <= 0:
			bad_reward.append(String(a2["reward_id"]))
	_check("①c 유물 id가 서로 다르다(%d종)" % ids.size(), ids.size() == Mastery.artifact_count())
	_check("①d 답례가 전부 **실존 아이템**이고 수량이 양수(불량 %s)" % str(bad_reward), bad_reward.is_empty())

	# ── ② ⚠️ [ADR-0019] 영구 % 곱셈 부재 ──
	print("── ② ⚠️ ADR-0019 % 곱셈 부재 ──")
	var off_key: Array = []
	for s3 in Mastery.skills():
		var a3: Dictionary = Mastery.artifact_of(String(s3))
		for k in a3.keys():
			if not ["id", "name", "desc", "reward_id", "n"].has(String(k)):
				off_key.append("%s.%s" % [String(s3), String(k)])
	_check("②a ★유물 스키마에 배수·확률·지속을 담을 칸이 **아예 없다**(발견: %s)" % str(off_key),
		off_key.is_empty())
	var src := FileAccess.open("res://mastery.gd", FileAccess.READ).get_as_text()
	var banned: Array = []
	for w in ["mult", "_pct", "percent", "bonus_rate", "multiplier"]:
		if src.contains(String(w)):
			banned.append(String(w))
	_check("②b 소스에 배수 어휘 0(발견: %s)" % str(banned), banned.is_empty())

	# ── ③ ⚠️ 트링켓 슬롯 비상속 ──
	print("── ③ ⚠️ 트링켓 슬롯 비상속 ──")
	# ★ 어휘 존재가 아니라 **API 표면 부재**로 잰다(주석에는 금지 선언이 있어야 하므로 어휘는
	#   오히려 있어야 한다). 위 ②a가 데이터 스키마를 잠갔으니 여기서는 함수·필드를 본다.
	var api_ok := not src.contains("func equip") and not src.contains("var equipped") \
		and not src.contains("slot")
	_check("③a 장착·슬롯 API가 없다(유물 = 물건 지급 · 장비 아님)", api_ok)
	_check("③b 주석에 금지 선언이 남아 있다(다음 사람이 다시 열지 않게)",
		src.contains("트링켓 슬롯 비상속"))

	# ── ④ 초과 XP·문턱·파리티 ──
	print("── ④ 초과 XP · 누적 문턱 ──")
	var cap := Mastery.max_level_xp()
	_check("④a 만렙 XP = FarmSkill 곡선의 마지막 임계 %d(숫자 하드코딩 0)" % cap,
		cap == int(FarmSkill.XP_THRESHOLDS[FarmSkill.XP_THRESHOLDS.size() - 1]) and cap > 0)
	_check("④b 초과 경계 ±1 — 만렙−1=0 · 만렙=0 · 만렙+7=7",
		Mastery.overflow_of(cap - 1) == 0 and Mastery.overflow_of(cap) == 0
		and Mastery.overflow_of(cap + 7) == 7)
	var xps: Dictionary = {}
	for s4 in ProfessionCatalog.SKILLS:
		xps[String(s4)] = cap + 100
	_check("④c 합산 = 5스킬 초과분의 합(%d)" % Mastery.total_overflow(xps),
		Mastery.total_overflow(xps) == 100 * ProfessionCatalog.SKILLS.size())
	var th: Array = Mastery.THRESHOLDS
	_check("④d ★문턱 5단이고 오름차순(누적 — %s)" % str(th),
		th.size() == 5 and int(th[0]) < int(th[1]) and int(th[3]) < int(th[4]))
	_check("④e 문턱 경계 ±1 — 1단−1=0점 · 1단=1점 · 5단=5점 · 5단+큰수=5점(상한)",
		Mastery.earned_points(int(th[0]) - 1) == 0 and Mastery.earned_points(int(th[0])) == 1
		and Mastery.earned_points(int(th[4])) == 5
		and Mastery.earned_points(int(th[4]) * 10) == 5)
	_check("④f ★파리티 — 문턱 %d단 = 유물 %d점 × 값 %d(남거나 모자라는 포인트 0)"
			% [th.size(), Mastery.artifact_count(), Mastery.ARTIFACT_COST],
		th.size() == Mastery.artifact_count() * Mastery.ARTIFACT_COST)
	_check("④g 다음 문턱 안내 — 0에서는 1단 · 5단 이후엔 0(더 없음)",
		Mastery.next_threshold(0) == int(th[0]) and Mastery.next_threshold(int(th[4])) == 0)

	# ── ⑤ 개방(5스킬 전부 만렙) ──
	print("── ⑤ 개방 판정 ──")
	var lv_full: Dictionary = {}
	for s5 in ProfessionCatalog.SKILLS:
		lv_full[String(s5)] = FarmSkill.MAX_LEVEL
	_check("⑤a 전부 만렙 = 열림", Mastery.is_open(lv_full) and Mastery.pending_skills(lv_full).is_empty())
	var lv_one: Dictionary = lv_full.duplicate()
	lv_one[ProfessionCatalog.COMBAT] = FarmSkill.MAX_LEVEL - 1
	_check("⑤b ★한 스킬만 −1이어도 닫힘 · 남은 스킬이 **이름으로** 뜬다(%s)"
			% str(Mastery.pending_skills(lv_one)),
		not Mastery.is_open(lv_one)
		and Mastery.pending_skills(lv_one) == [ProfessionCatalog.COMBAT])
	_check("⑤c 빈 입력(손상 방어) = 닫힘 · 전 스킬이 남는다",
		not Mastery.is_open({}) and Mastery.pending_skills({}).size() == ProfessionCatalog.SKILLS.size())

	# ── ⑥ main 배선 ──
	print("── ⑥ main 배선 ──")
	var SAVE := "user://save.dat"
	var BAK := "user://save.dat.mstbak"
	var had_save := FileAccess.file_exists(SAVE)
	if had_save:
		_write_bytes(BAK, _read_bytes(SAVE))
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))

	var m: Node = await _spawn_main()
	_check("⑥a 부팅 — 경지 원장이 섰고 층은 닫혀 있다(신규 세이브 = 전 스킬 L0)",
		m.mastery != null and not m.mastery_open() and m.mastery.claimed_count() == 0)
	var rows0: Array = m._skill_rows()
	var lines0 := 0
	var first_line := ""
	for i in range(rows0.size()):
		var mst0: Dictionary = (rows0[i] as Dictionary).get("mastery", {})
		if mst0.is_empty():
			continue
		lines0 += 1
		if i == 0:
			first_line = String(mst0.get("text", ""))
	# ★[폴리시 R21 #8] 계약 개정: 종전 단언은 «5행 전부 빈 dict»였는데, 그러면 `_mastery_row`
	#   머리말이 계약으로 적은 ㉠("미개방 — 무엇이 남았나까지 말해 준다")이 영영 구현되지 않고
	#   그 안내를 위해 만든 `Mastery.pending_skills`가 런타임 호출부 0인 죽은 API로 남는다.
	#   ㉠을 **첫 행 하나에만** 앉혀 두 계약을 함께 지킨다 — 이 단언이 재는 것은 그 실질이다:
	#   층은 게임에 하나뿐이니 줄도 하나이고, 나머지 넷은 종전대로 침묵한다(잔소리 0).
	_check("⑥b ★만렙 전 경지 줄은 **첫 행 하나뿐**이다(%d행 중 %d줄) · 그 줄이 무엇이 남았는지 이름으로 말한다 — 「%s」"
			% [rows0.size(), lines0, first_line],
		lines0 == 1 and first_line != "" and rows0.size() == ProfessionCatalog.SKILLS.size()
		and first_line.contains(ProfessionCatalog.skill_name(ProfessionCatalog.COMBAT)))
	# ⚠️ [ADR-0008] 기준선 — 경지가 열리기 전의 스킬 계수(혼력 감산)를 적어 둔다.
	_max_all_skills(m, 0)
	var energy_before: int = m._farming_energy_cost()
	_check("⑥c 전 스킬 만렙 — 층이 열린다(초과 XP 0이라 포인트는 아직 0)",
		m.mastery_open() and m.mastery_overflow() == 0)
	var rows1: Array = m._skill_rows()
	var lines := 0
	var claimable0 := 0
	for r2 in rows1:
		var mst: Dictionary = (r2 as Dictionary).get("mastery", {})
		if not mst.is_empty():
			lines += 1
			if bool(mst.get("claimable", false)):
				claimable0 += 1
	_check("⑥d 만렙 후 다섯 행 전부에 경지 줄이 선다(%d행) · 포인트 0이라 수령 버튼은 0개" % lines,
		lines == ProfessionCatalog.SKILLS.size() and claimable0 == 0)
	# 포인트 1점을 만든다(1단 문턱을 한 스킬 초과분으로 넘긴다).
	m._farming_xp = cap + int(th[0])
	_check("⑥e 1단 문턱 도달 — 적립 1점 · 가용 1점",
		m.mastery_overflow() >= int(th[0])
		and Mastery.earned_points(m.mastery_overflow()) == 1
		and m.mastery.available_points(m.mastery_overflow()) == 1)
	var art := Mastery.artifact_of(ProfessionCatalog.FARMING)
	var rid := String(art["reward_id"])
	var before: int = m.inventory.count_of(rid)
	m._on_frame_mastery(ProfessionCatalog.FARMING)
	_check("⑥f ★수령 — %s ×%d 가 백팩에 들어오고 원장에 적힌다"
			% [ItemCatalog.name_of(rid), int(art["n"])],
		m.inventory.count_of(rid) == before + int(art["n"])
		and m.mastery.has_claimed(ProfessionCatalog.FARMING))
	_check("⑥g 포인트를 다 썼으니 둘째 유물은 못 받는다(가용 0)",
		m.mastery.available_points(m.mastery_overflow()) == 0
		and not m.mastery.can_claim(ProfessionCatalog.COMBAT, m._skill_level_map(), m.mastery_overflow()))
	var before2: int = m.inventory.count_of(rid)
	m._on_frame_mastery(ProfessionCatalog.FARMING)
	_check("⑥h 재수령 무동작(멱등 — 물건도 원장도 안 는다)",
		m.inventory.count_of(rid) == before2 and m.mastery.claimed_count() == 1)
	_check("⑥i ⚠️ [ADR-0008] 경지가 기존 스킬 계수를 한 톨도 안 건드렸다(혼력 감산 %d 불변)"
			% energy_before, m._farming_energy_cost() == energy_before)
	# 나머지 4점을 채워 전부 수령(파리티 실증).
	m._farming_xp = cap + int(th[4])
	var claimed_all := true
	for s6 in ProfessionCatalog.SKILLS:
		if m.mastery.has_claimed(String(s6)):
			continue
		m._on_frame_mastery(String(s6))
		if not m.mastery.has_claimed(String(s6)):
			claimed_all = false
	_check("⑥j ★5단까지 채우면 유물 %d점을 **전부** 받는다(파리티 — 남는 포인트 %d)"
			% [Mastery.artifact_count(), m.mastery.available_points(m.mastery_overflow())],
		claimed_all and m.mastery.is_complete()
		and m.mastery.available_points(m.mastery_overflow()) == 0)
	# 세이브 왕복
	var claimed_live: Array = m.mastery.claimed.duplicate()
	m._save_game()
	await _despawn(m)
	var m2: Node = await _spawn_main()
	_check("⑥k 재부팅 복원 — 수령 이력 %d건 · 층 열린 채 · 포인트가 XP에서 다시 파생된다"
			% claimed_live.size(),
		m2.mastery.claimed.size() == claimed_live.size() and m2.mastery.is_complete()
		and m2.mastery_open() and m2.mastery_overflow() >= int(th[4]))
	m2.mastery.load_save({})
	_check("⑥l 하위호환 — 키 없는 구세이브는 수령 0(막히는 것 0 · 포인트는 그대로 파생)",
		m2.mastery.claimed_count() == 0
		and Mastery.earned_points(m2.mastery_overflow()) == 5)
	m2.mastery.load_save({"claimed": ["사라진_스킬", "", ProfessionCatalog.MINING,
		ProfessionCatalog.MINING]})
	_check("⑥m 손상 방어 — 로스터 밖 id·빈 id·중복을 드롭한다(남은 %d건)" % m2.mastery.claimed_count(),
		m2.mastery.claimed_count() == 1 and m2.mastery.has_claimed(ProfessionCatalog.MINING))
	await _despawn(m2)

	if had_save:
		_write_bytes(SAVE, _read_bytes(BAK))
		DirAccess.remove_absolute(ProjectSettings.globalize_path(BAK))
	elif FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))

	print("══ 결과: %s ══" % ("PASS (실패 0)" if _fail == 0 else "FAIL (실패 %d)" % _fail))
	quit(1 if _fail > 0 else 0)
