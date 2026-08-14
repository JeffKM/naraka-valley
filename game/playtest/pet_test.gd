extends SceneTree
# ★[S10-T4 / ADR-0069 결정 7] 코지 펫 「삽사리」 검증(ephemeral).
#
# 무엇을 지키나(어기면 ADR-0069 결정 7 위반):
#   ① 획득 = **마을 이벤트 1회** · 최대 1(2호 없음) · 문턱 전에는 안 선다
#   ② 쓰다듬 **하루 1회 잠금** · 물그릇 하루 1회 · 우정 누적(상한 clamp)
#   ③ 만점 보상 = [명부의 운] **하한** 보정 — ⚠️ *바닥만* 올린다(평균 불변)
#      · 대흉 날만 흉으로 오르고 흉·평·길·대길은 **한 톨도 안 바뀐다**(전수 스캔)
#      · [ADR-0019] "영구 % 곱셈 금지"와 충돌 0(위로 가는 길이 구조적으로 없다)
#   ④ ⚠️ **[바나] 사역마와 위상 분리** — 펫은 전투 관여 0(전투 표면 소스 스캔)
#   ⑤ 세이브 왕복 · 하위호환(키 없는 구세이브) · 손상 방어
#   ⑥ 라이브 — 마을 진입 이벤트 → 집 앞 [F] 쓰다듬/물그릇 → 운 하한 배선 → 재부팅 왕복
#   ⑦ 자리 실그리드 — 삽사리·물그릇 칸이 걸을 수 있고 다른 창구 칸과 안 겹친다
# 실행: ./run_tests.sh pet   (헤드리스는 반드시 game/에서 · 순차)

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

# 이 칸이 실그리드에서 걸을 수 있는가(막힌 지형 = false) — panning_test의 같은 헬퍼.
func _walkable(m: Node, t: Vector2i) -> bool:
	if t.x < 0 or t.y < 0 or t.x >= m._grid_w or t.y >= m._outdoor_h:
		return false
	return not m.is_solid(m._grid[t.y][t.x])

# 우정을 만점까지 채운다(날을 하루씩 넘기며 쓰다듬 + 물그릇 — 실제 플레이 경로와 같은 채널).
func _fill_friendship(p: Pet, from_day: int) -> int:
	var d := from_day
	var guard := 0
	while not p.is_maxed() and guard < 500:
		p.pet_today(d)
		p.fill_bowl(d)
		d += 1
		guard += 1
	return d

# 1..SCAN_DAYS 안에서 그 등급이 뜨는 첫 날(0 = 없음) — 단언이 표본을 스스로 찾게 한다.
const SCAN_DAYS := 2000

func _first_day_of_grade(g: int) -> int:
	for day in range(1, SCAN_DAYS + 1):
		if DailyLuck.grade_for_day(day) == g:
			return day
	return 0

# 주석(#로 시작하는 줄 · 줄 끝 주석)을 걷어 낸 **코드만** 돌려준다 — 소스 스캔 단언의 전처리다.
func _strip_comments(src: String) -> String:
	var out := ""
	for raw in src.split("\n"):
		var line := String(raw)
		var hash_at := line.find("#")
		if hash_at >= 0:
			line = line.substr(0, hash_at)
		if line.strip_edges() != "":
			out += line + "\n"
	return out

# 미입양 원장에는 어떤 손짓도 서지 않는다.
func _fresh_pet_inert(day: int) -> bool:
	var q := Pet.new()
	return not q.can_pet(day) and not q.pet_today(day) \
		and not q.can_fill_bowl(day) and not q.fill_bowl(day)

# 기본 인자(mitigated 생략)가 옛 거동과 바이트 단위로 같은가 — 기존 회귀 불변의 근거.
func _default_arg_is_identity() -> bool:
	for day in range(1, 500):
		if not is_equal_approx(DailyLuck.luck_for_day(day), DailyLuck.luck_for_day(day, false)):
			return false
		if DailyLuck.bonus_for_day(day, DailyLuck.W_LADDER) \
				!= DailyLuck.luck_for_day(day) * DailyLuck.W_LADDER:
			return false
	return true

func _initialize() -> void:
	print("══ S10-T4 코지 펫(삽사리) 검증 ══")
	const SAVE := "user://save.dat"
	const BAK := "user://save.dat.s10t4_pet_bak"
	var had_save := FileAccess.file_exists(SAVE)
	if had_save:
		_write_bytes(BAK, _read_bytes(SAVE))
	if FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))

	# ── ① 획득 ──
	print("── ① 획득 = 마을 이벤트 1회 ──")
	var p := Pet.new()
	_check("①a 초기 = 미입양 · 우정 0 · 만점 보상 꺼짐",
		not p.is_adopted() and p.friendship() == 0 and not p.luck_floor_active())
	_check("①b 문턱 전에는 이벤트가 안 선다(잠정 %d일 — Pet.ADOPT_MIN_DAY 파생)"
			% Pet.ADOPT_MIN_DAY,
		not p.adopt_ready(Pet.ADOPT_MIN_DAY - 1) and not p.adopt(Pet.ADOPT_MIN_DAY - 1)
		and not p.is_adopted())
	_check("①c 문턱 날 = 이벤트가 선다 → 입양",
		p.adopt_ready(Pet.ADOPT_MIN_DAY) and p.adopt(Pet.ADOPT_MIN_DAY) and p.is_adopted())
	_check("①d ★최대 1 — 두 번째 입양은 false(2호는 서랍)",
		not p.adopt_ready(Pet.ADOPT_MIN_DAY + 10) and not p.adopt(Pet.ADOPT_MIN_DAY + 10))

	# ── ② 쓰다듬·물그릇(하루 1회 잠금) ──
	print("── ② 쓰다듬 · 물그릇 · 우정 누적 ──")
	var d := Pet.ADOPT_MIN_DAY
	_check("②a 미입양 상태에선 아무 손짓도 안 선다", _fresh_pet_inert(d))
	_check("②b 쓰다듬 1회 = +%d(원장 상수 파생)" % Pet.F_PET,
		p.can_pet(d) and p.pet_today(d) and p.friendship() == Pet.F_PET)
	_check("②c ★같은 날 두 번째 쓰다듬은 잠긴다(우정 불변)",
		not p.can_pet(d) and not p.pet_today(d) and p.friendship() == Pet.F_PET)
	_check("②d 물그릇 1회 = +%d(쓰다듬과 별개 축)" % Pet.F_BOWL,
		p.can_fill_bowl(d) and p.fill_bowl(d)
		and p.friendship() == Pet.F_PET + Pet.F_BOWL)
	_check("②e ★같은 날 두 번째 물그릇도 잠긴다",
		not p.can_fill_bowl(d) and not p.fill_bowl(d)
		and p.friendship() == Pet.F_PET + Pet.F_BOWL)
	_check("②f 날이 바뀌면 둘 다 다시 열린다",
		p.can_pet(d + 1) and p.can_fill_bowl(d + 1))
	_check("②g 하트 = 우정 / %d(Ranch 눈금 상속)" % Pet.FRIEND_PER_HEART,
		p.hearts() == p.friendship() / Pet.FRIEND_PER_HEART
		and p.max_hearts() == Pet.FRIEND_MAX / Pet.FRIEND_PER_HEART)
	var end_day := _fill_friendship(p, d + 1)
	_check("②h 매일 돌보면 만점에 닿는다 · 상한을 안 넘는다(clamp)",
		p.is_maxed() and p.friendship() == Pet.FRIEND_MAX)
	p.pet_today(end_day + 1)
	_check("②i 만점 뒤에도 상한 고정(넘치지 않는다)", p.friendship() == Pet.FRIEND_MAX)

	# ── ③ 만점 보상 = 명부의 운 하한 보정 ──
	print("── ③ 만점 보상 = [명부의 운] 하한 보정(★바닥만) ──")
	_check("③a 만점 = 하한 보정 켜짐 · 미입양 원장은 꺼짐",
		p.luck_floor_active() and not Pet.new().luck_floor_active())
	_check("③b 하한값 = 흉의 가장 아래 눈금(−T_GREAT + eps)",
		DailyLuck.FLOOR_MITIGATED > -DailyLuck.T_GREAT
		and DailyLuck.FLOOR_MITIGATED < -DailyLuck.T_GOOD
		and DailyLuck.grade_of(DailyLuck.FLOOR_MITIGATED) == DailyLuck.BAD)
	# ★ 전수 스캔 — 1..2000일 전량에서 "대흉만 오르고 나머지는 한 톨도 안 바뀐다"를 잰다.
	var raised := 0          # 대흉 → 흉으로 오른 날
	var untouched := 0       # 값이 바이트 단위로 그대로인 날
	var broke := false       # 평균이 오른 정황(대흉 아닌 날의 값이 바뀜) 또는 상승 초과
	var still_terrible := 0
	for day in range(1, SCAN_DAYS + 1):
		var raw := DailyLuck.luck_for_day(day)
		var flo := DailyLuck.luck_for_day(day, true)
		if DailyLuck.grade_of(raw) == DailyLuck.TERRIBLE:
			if DailyLuck.grade_of(flo) == DailyLuck.BAD:
				raised += 1
			else:
				still_terrible += 1
			if flo > DailyLuck.FLOOR_MITIGATED + 1e-9:
				broke = true      # 하한을 넘겨 끌어올렸다 = 평균 상향
		else:
			if is_equal_approx(raw, flo):
				untouched += 1
			else:
				broke = true      # 대흉이 아닌 날이 바뀌었다 = 평균 상향
	_check("③c 대흉 날이 전부 흉으로 오른다(잔여 대흉 0 · %d일)" % raised,
		raised > 0 and still_terrible == 0)
	_check("③d ★대흉이 아닌 날은 한 톨도 안 바뀐다(%d일 전수 — 평균 상향 0)" % untouched,
		not broke and untouched == SCAN_DAYS - raised)
	var great_day := _first_day_of_grade(DailyLuck.GREAT)
	_check("③e 좋은 날은 좋아지지 않는다(대길 표본 %d일 동일)" % great_day,
		great_day > 0 and is_equal_approx(DailyLuck.luck_for_day(great_day),
			DailyLuck.luck_for_day(great_day, true)))
	_check("③f 기본 인자(mitigated 생략) = 옛 거동 그대로(기존 회귀 불변의 근거)",
		_default_arg_is_identity())
	var bad_day := _first_day_of_grade(DailyLuck.TERRIBLE)
	_check("③g 보정된 날의 가산값도 함께 덜 아프다(6배선 전부가 같은 입구를 지난다)",
		bad_day > 0
		and DailyLuck.bonus_for_day(bad_day, DailyLuck.W_LADDER, true)
			> DailyLuck.bonus_for_day(bad_day, DailyLuck.W_LADDER, false))
	_check("③h 거울 문구도 보정된 등급을 말한다(화면 ↔ 실제 확률 일치)",
		bad_day > 0
		and DailyLuck.fortune_text(bad_day, true).contains(DailyLuck.GRADE_NAMES[DailyLuck.BAD])
		and DailyLuck.fortune_text(bad_day, false).contains(DailyLuck.GRADE_NAMES[DailyLuck.TERRIBLE]))

	# ── ④ 사역마와의 위상 분리(소스 스캔) ──
	print("── ④ ⚠️ [바나] 사역마와 위상 분리 ──")
	var src := FileAccess.get_file_as_string("res://pet.gd")
	_check("④a pet.gd 소스가 존재한다", src.length() > 0)
	# ★ 전투 표면 이름이 **코드에** 한 번도 안 나온다. ⚠️ 주석은 걷어 내고 잰다 — 머리말이
	#   "이 클래스들을 참조하지 않는다"고 *선언*하느라 이름을 적어 두었고, 그걸 위반으로 세면
	#   경고문을 쓸수록 테스트가 깨진다(spine_test가 박제한 "예약 주석이 위반으로 잡히는" 함정).
	var code := _strip_comments(src)
	var combat_tokens := ["Mob", "PlayerHealth", "CombatSkill", "WeaponCatalog", "damage",
		"attack", "MobCatalog", "BanaGuard"]
	var leaked := ""
	for tok: String in combat_tokens:
		if code.contains(tok):
			leaked = tok
	_check("④b 전투 표면 참조 0 — 주석 제외 **코드**에 %s 어느 것도 없다"
			% ", ".join(combat_tokens), leaked == "")
	_check("④c 위상 분리가 **주석으로 명문화**돼 있다(결정 7이 요구한 그 항목)",
		src.contains("사역마") and src.contains("전투 관여 0"))
	_check("④d 원장이 노출하는 보상 표면은 운 하한 하나뿐(전투 보상 함수 0)",
		p.has_method("luck_floor_active") and not p.has_method("attack_bonus")
		and not p.has_method("defense_bonus"))
	# 바나의 사역마는 여전히 **캐릭터 모티프**로만 산다(전투 원장에 편입되지 않았다).
	var bana_src := FileAccess.get_file_as_string("res://bana.gd")
	_check("④e 바나 사역마는 실루엣 모티프 그대로(펫 원장이 그쪽을 안 건드렸다)",
		bana_src.contains("사역마") and not bana_src.contains("Pet."))

	# ── ⑤ 세이브 왕복 ──
	print("── ⑤ 세이브 왕복 ──")
	var p2 := Pet.new()
	p2.load_save(p.to_save())
	_check("⑤a 왕복 — 입양·우정·오늘 잠금 전량 보존",
		p2.is_adopted() and p2.friendship() == p.friendship()
		and p2.can_pet(end_day + 1) == p.can_pet(end_day + 1)
		and p2.luck_floor_active() == p.luck_floor_active())
	var p3 := Pet.new()
	p3.load_save({})
	_check("⑤b 하위호환 — 키 없는 구세이브 = 미입양·우정 0(아무것도 안 막힌다)",
		not p3.is_adopted() and p3.friendship() == 0 and p3.adopt_ready(Pet.ADOPT_MIN_DAY))
	var p4 := Pet.new()
	p4.load_save({"adopted": true, "friend": 99999, "pet_day": -5, "bowl_day": -1})
	_check("⑤c 손상 방어 — 우정은 상한으로 자르고 음수 날은 0으로",
		p4.friendship() == Pet.FRIEND_MAX and p4.can_pet(1) and p4.can_fill_bowl(1))

	# ── ⑥ 라이브(main) ──
	print("── ⑥ 라이브 — 마을 이벤트 · 집 앞 [F] · 운 배선 ──")
	var m: Node = await _spawn_main()
	_check("⑥⓪ 원장 배선(RefCounted)", m.pet != null)
	_check("⑥a 부팅 직후 = 미입양 · 운 하한 배선 꺼짐",
		not m.pet.is_adopted() and not m._pet_luck_floor())
	# 문턱 전 마을 진입 = 이벤트 없음.
	m.clock.day = Pet.ADOPT_MIN_DAY - 1
	m._rebuild_region(RegionCatalog.NARU_VILLAGE)
	m._fire_pet_event()
	_check("⑥b 문턱 전 마을 진입 = 이벤트 안 섬", not m.pet.is_adopted())
	# 문턱 이후 마을 진입 = 예약 → 소비.
	m.clock.day = Pet.ADOPT_MIN_DAY + 3
	m._rebuild_region(RegionCatalog.HOME)
	m._rebuild_region(RegionCatalog.NARU_VILLAGE)
	_check("⑥c 마을을 세우는 프레임에 예약이 선다", m._pet_event_armed)
	m._fire_pet_event()
	_check("⑥d 워프 연출이 걷힌 뒤 소비 = 입양 · 예약은 내려간다",
		m.pet.is_adopted() and not m._pet_event_armed)
	m._rebuild_region(RegionCatalog.HOME)
	m._rebuild_region(RegionCatalog.NARU_VILLAGE)
	m._fire_pet_event()
	_check("⑥e ★두 번째 마을 진입은 아무 일도 없다(1회성 · 2호 없음)",
		m.pet.is_adopted() and m.pet.friendship() == 0)
	# 집 앞 [F] 두 창구.
	m._region = RegionCatalog.HOME
	m._indoor = ""
	m._sleeping = false
	m._target = m.PET_TILE
	_check("⑥f 삽사리 칸을 겨누면 창구가 선다", m._facing_pet())
	var e0: int = m.energy.current
	m._pet_sapsari()
	_check("⑥g [F] 쓰다듬 = 우정 +%d · 혼력 무과금(코지 리추얼)" % Pet.F_PET,
		m.pet.friendship() == Pet.F_PET and m.energy.current == e0)
	m._pet_sapsari()
	_check("⑥h 같은 날 두 번째 [F] = 무동작(안내만)", m.pet.friendship() == Pet.F_PET)
	m._target = m.PET_BOWL_TILE
	_check("⑥i 물그릇 칸 창구", m._facing_pet_bowl() and not m._facing_pet())
	m._fill_pet_bowl()
	_check("⑥j [F] 물그릇 = 우정 +%d" % Pet.F_BOWL,
		m.pet.friendship() == Pet.F_PET + Pet.F_BOWL)
	# 구역·실내 가드 — 다른 구역·실내 밴드의 같은 좌표는 무반응.
	m._indoor = "집"
	_check("⑥k 실내에서는 창구가 안 선다", not m._facing_pet_bowl())
	m._indoor = ""
	m._region = RegionCatalog.NARU_VILLAGE
	_check("⑥l 다른 구역의 같은 좌표도 무반응", not m._facing_pet_bowl())
	m._region = RegionCatalog.HOME
	# 운 하한 배선(라이브) — 만점이면 _luck_bonus가 보정판을 쓴다.
	var terrible_day := bad_day
	m.clock.day = terrible_day
	var bonus_before: float = m._luck_bonus(DailyLuck.W_LADDER)
	_check("⑥m 만점 전에는 대흉 날 감산이 그대로다",
		not m._pet_luck_floor()
		and is_equal_approx(bonus_before,
			DailyLuck.bonus_for_day(terrible_day, DailyLuck.W_LADDER)))
	m.pet.load_save({"adopted": true, "friend": Pet.FRIEND_MAX})
	_check("⑥n 만점 뒤 = 배선이 켜지고 그날 감산이 덜 아프다",
		m._pet_luck_floor() and m._luck_bonus(DailyLuck.W_LADDER) > bonus_before)
	_check("⑥o 거울 본문도 보정 등급을 말한다(라이브 문구)",
		m._mirror_forecast_text().contains(DailyLuck.GRADE_NAMES[DailyLuck.BAD]))

	# ── ⑦ 자리 실그리드 ──
	print("── ⑦ 자리 실그리드 ──")
	m._rebuild_region(RegionCatalog.HOME)
	_check("⑦a 삽사리·물그릇 칸이 둘 다 걸을 수 있다(막힌 지형 아님)",
		_walkable(m, m.PET_TILE) and _walkable(m, m.PET_BOWL_TILE))
	_check("⑦b 두 칸이 서로 다르고 나란하다(한눈에 「개와 그릇」)",
		m.PET_TILE != m.PET_BOWL_TILE
		and absi(m.PET_TILE.x - m.PET_BOWL_TILE.x) + absi(m.PET_TILE.y - m.PET_BOWL_TILE.y) == 1)
	_check("⑦c 기존 [F] 창구 칸과 겹치지 않는다(우편함·상자·거울)",
		m.PET_TILE != m.MAILBOX_TILE and m.PET_BOWL_TILE != m.MAILBOX_TILE
		and m.PET_TILE != m.CHEST_TILE and m.PET_BOWL_TILE != m.MIRROR_TILE)

	# 재부팅 왕복.
	var live_friend: int = m.pet.friendship()
	m._save_game()
	await _despawn(m)
	var m2: Node = await _spawn_main()
	_check("⑦d 재부팅 후 삽사리 복원 — 입양·우정·운 배선",
		m2.pet.is_adopted() and m2.pet.friendship() == live_friend and m2._pet_luck_floor())
	await _despawn(m2)

	if had_save:
		_write_bytes(SAVE, _read_bytes(BAK))
		DirAccess.remove_absolute(ProjectSettings.globalize_path(BAK))
	elif FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))

	print("══ 결과: %s ══" % ("PASS (실패 0)" if _fail == 0 else "FAIL (실패 %d)" % _fail))
	quit(1 if _fail > 0 else 0)
