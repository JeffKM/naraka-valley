extends SceneTree
# ★[S10-T4 / ADR-0069 결정 12] 동행 혼(혼례 → 14일 → 형상화) 검증(ephemeral).
#
# 무엇을 지키나(어기면 ADR-0069 결정 12 / [ADR-0022] / [ADR-0016] 위반):
#   ① 등재 — 주민 프레임 최소 등재(관계 트랙 0 · 선물 0 · 생일 0) · **주방요괴 바로 앞**
#      · 기존 인덱스 좌표 불변(무골 = 9 · 주방요괴 = 마지막)
#   ② 혼례 → **잠정 14일** 예정 · 그 아침에 예약 · 취침 프레임에 재생(B4·B7과 같은 두 단계)
#   ③ **1회성**(비트가 서면 다시 안 뜬다) · **최대 1**(재혼해도 2호 없음)
#   ④ 상호작용 1종 — 깃들기 전엔 몸도 대화도 없고, 깃든 뒤 집 안에서만 말을 건다
#   ⑤ 이혼 — **깃든 혼은 잔류**(불가역) · 아직 안 깃든 예정만 접힌다 · 재혼하면 새로 선다
#   ⑥ **옥자 혼인 경로도 같은 줄을 지난다**(분기 0이 곧 "두 경로 커버"의 구현)
#   ⑦ 세이브 왕복 · 하위호환 · 손상 방어(태어났는데 예정이 또 있는 세이브)
#   ⑧ ⚠️ **봉인 법칙** — 본문이 그날 밤·앵커·중심 진실을 한 글자도 안 말한다
# 실행: ./run_tests.sh soul_child   (헤드리스는 반드시 game/에서 · 순차)

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

# ★[폴리시 R7] 오프닝 대화를 **반드시 닫고 시작한다.** 이 하네스는 종전에 대화를 연 채로 진행했고,
#   폴리시 R2가 `_fire_soul_birth`에 `dialogue.is_open()` 가드를 얹은 뒤로는 형상화 재생이 매번
#   그 첫 줄에서 접혀 ②e·②f·③a·③b·⑦c·⑧a 여섯 단언이 **제품과 무관하게** 계속 실패했다
#   (다른 하네스는 전부 이 정리 절차를 갖고 있다 — 여기만 빠져 있었다).
func _dismiss_dialogue(m: Node) -> void:
	var guard := 0
	while m.dialogue.is_open() and guard < 60:
		m.dialogue.advance()
		guard += 1

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

# ★[폴리시 R15] 슬롯 파일의 상태 키 하나를 **파일 위에서** 갈아 끼운다(손상 세이브 제조).
#   save.gd의 슬롯은 `var_to_str({"version":…, "meta":…, "data":…})` 텍스트라, 래퍼를 그대로 파싱해
#   `data[key]`만 바꿔 다시 쓴다. 손상 방어가 **로드 경로에서** 성립하는지 재는 유일한 길이다.
func _doctor_save(path: String, key: String, value: Variant) -> bool:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return false
	var parsed: Variant = str_to_var(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return false
	var wrapped: Dictionary = parsed
	var d: Variant = wrapped.get("data", null)
	if typeof(d) != TYPE_DICTIONARY:
		return false
	var data: Dictionary = d
	data[key] = value
	wrapped["data"] = data
	var o := FileAccess.open(path, FileAccess.WRITE)
	if o == null:
		return false
	o.store_string(var_to_str(wrapped))
	o.close()
	return true

# 슬롯 파일에 지금 적혀 있는 상태 값(없으면 null) — 손상값이 실제로 박혔는지 되읽는 데 쓴다.
func _save_data_value(path: String, key: String) -> Variant:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return null
	var parsed: Variant = str_to_var(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return null
	var d: Variant = (parsed as Dictionary).get("data", null)
	return (d as Dictionary).get(key, null) if typeof(d) == TYPE_DICTIONARY else null

# 컷신이 서 있으면 끝까지 재생한다(뒤따르는 대화는 안 닫는다 — 첫 줄을 재야 한다).
func _settle(m: Node) -> void:
	var guard := 0
	while m.cutscene != null and guard < 400:
		m._tick_cutscene(0.2)
		guard += 1

# 판을 비운다 — 컷신 재생 → 선택지는 첫 항 → 나머지는 넘기기(플레이어와 같은 경로).
func _drain(m: Node) -> void:
	_settle(m)
	var guard := 0
	while m.dialogue.is_open() and guard < 300:
		if m.dialogue.has_choice():
			m.dialogue.choose(0)
		else:
			m.dialogue.advance()
		guard += 1

# 그 사람과 **즉시 부부로 만든다** — 청혼 사슬(정표·방·아크)은 marriage_test가 이미 재는 축이라
# 여기선 혼례 아침 훅(`_advance_wedding`)만 통과시킨다. 이 태스크가 재는 것은 그 아침 *뒤*다.
func _wed(m: Node, rid: String, day: int) -> void:
	m._romance_partner = rid
	m._wedding_day = day
	m.clock.day = day
	m._advance_wedding(day)

func _initialize() -> void:
	print("══ S10-T4 동행 혼(혼례 → 14일 → 형상화) 검증 ══")
	const SAVE := "user://save.dat"
	const BAK := "user://save.dat.s10t4_soul_bak"
	var had_save := FileAccess.file_exists(SAVE)
	if had_save:
		_write_bytes(BAK, _read_bytes(SAVE))
	if FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))

	var m: Node = await _spawn_main()
	_dismiss_dialogue(m)

	# ── ① 등재 ──
	print("── ① 주민 프레임 최소 등재 ──")
	var r: Resident = m._resident(m.SOUL_CHILD_RID)
	_check("①a 레코드가 등록돼 있다(탄생 전에도 — 총원은 세이브에 따라 안 흔들린다)",
		r != null and r.node != null)
	_check("①b 관계 트랙 0 — Affinity 없음 · 선물 없음 · 초상화 없음",
		r.affinity == null and not r.can_gift and r.portrait_stem == "")
	_check("①c 생일 테이블에 없다(관계 트랙 보유자만의 축)",
		not Resident.BIRTHDAYS.has(m.SOUL_CHILD_RID))
	_check("①d plain_talk 경로 — lines_resident() 한 묶음(하트 단계 대사 0)",
		r.plain_talk and r.node.has_method("lines_resident")
		and r.node.lines_resident().size() > 0)
	_check("①e 스케줄 없음·집 고정 — 항목 1개 · 자리 = SOUL_CHILD_TILE · 실내 가드 「집」",
		r.schedule.size() == 1 and r.schedule[0]["tile"] == m.SOUL_CHILD_TILE
		and r.require_indoor == "집")
	# ★ 조연 등재의 확립 자리 — 주방요괴 **바로 앞**(기존 인덱스 좌표 단언을 흔들지 않는다).
	var ids: Array = []
	for res in m._residents:
		ids.append(res.id)
	var soul_idx: int = ids.find(m.SOUL_CHILD_RID)
	_check("①f ★주방요괴 바로 앞에 붙었다(주방요괴는 여전히 마지막)",
		soul_idx >= 0 and soul_idx == ids.size() - 2
		and ids[ids.size() - 1] == "kitchen_youkai")
	_check("①g 기존 인덱스 좌표 불변(무골 = 9 — guild_test가 좌표로 쓰는 그 자리)",
		ids.size() > 9 and ids[9] == "mugol")
	_check("①h 관계 탭에는 안 뜬다(자격 = affinity 하나 — 파생 단언 ⑧a 무영향)", _rows_clean(m))

	# ── ② 혼례 → 14일 → 형상화 ──
	print("── ② 혼례 → %d일 → 형상화 ──" % m.SOUL_CHILD_WAIT_DAYS)
	_check("②a 부팅 직후 = 예정 없음 · 미탄생 · 몸이 안 보인다",
		m._soul_due_day == 0 and not m._soul_born and not r.node.visible)
	# ★ 깃들기 전에는 **말도 못 건다**(require_visible) — 빈 집에 대고 인사하는 경로 0.
	m._sleeping = false
	m._region = RegionCatalog.HOME
	m._indoor = "집"
	m._update_resident_stations(0.0)
	m._target = m.SOUL_CHILD_TILE
	_check("②a′ 깃들기 전엔 그 칸을 겨눠도 상대가 안 선다", m._facing_resident() == null)
	var wed_day := 40
	_wed(m, "mochi", wed_day)
	_check("②b 혼례 아침에 예정이 선다(day + %d)" % m.SOUL_CHILD_WAIT_DAYS,
		m._spouse_id == "mochi" and m._soul_due_day == wed_day + m.SOUL_CHILD_WAIT_DAYS)
	# 하루 전 아침 = 아직 예약이 안 선다.
	m._arm_soul_birth(wed_day + m.SOUL_CHILD_WAIT_DAYS - 1)
	_check("②c 하루 전 아침 = 예약 없음(기다림이 곧 값의 일부)",
		not m._soul_birth_armed and not m._soul_born)
	# 예정일 아침 = 예약만 선다(재생은 취침 프레임 — B4·B7과 같은 두 단계).
	m.clock.day = wed_day + m.SOUL_CHILD_WAIT_DAYS
	m._arm_soul_birth(m.clock.day)
	_check("②d 예정일 아침 = **예약만** 선다(아직 컷신 없음 — fade 트윈 한가운데라서)",
		m._soul_birth_armed and m.cutscene == null and not m._soul_born)
	m._fire_soul_birth()
	_check("②e 취침 프레임에 재생 — 컷신이 서고 예약은 내려간다",
		m.cutscene != null and not m._soul_birth_armed)
	_check("②f 재생 시작에 탄생이 확정된다(그 직후 자동 저장에 실린다 — B4 규약)",
		m._soul_born and m._soul_due_day == 0)
	_drain(m)
	_check("②g 컷신·대화가 정상 종료(암전이 안 남는다)",
		m.cutscene == null and not m.dialogue.is_open()
		and is_equal_approx(m.fade.modulate.a, 0.0))

	# ── ③ 1회성 · 최대 1 ──
	print("── ③ 1회성 · 최대 1 ──")
	m._arm_soul_birth(m.clock.day + 1)
	_check("③a 이미 깃들었으면 예약이 다시 안 선다(1회성)", not m._soul_birth_armed)
	m._soul_birth_armed = true
	m._fire_soul_birth()
	_check("③b 예약을 억지로 세워도 재생이 접힌다(이중 방어)", m.cutscene == null)

	# ── ④ 상호작용 1종 ──
	print("── ④ 상호작용 1종(인사) ──")
	m._region = RegionCatalog.HOME
	m._indoor = "집"
	m._update_resident_stations(0.0)
	_check("④a 깃든 뒤 = 몸이 세계에 선다", r.node.visible)
	_check("④b 자리 = 집 방 안 고정 칸", r.tile == m.SOUL_CHILD_TILE)
	m._sleeping = false
	m._target = m.SOUL_CHILD_TILE
	_check("④c 그 칸을 겨누면 말을 걸 수 있다", m._facing_resident() == r)
	m._start_resident_dialogue(r)
	_check("④d 대화가 열린다(인사 한 종 — 선물·하트 채널 0)", m.dialogue.is_open())
	_drain(m)

	# ── ⑤ 이혼 잔류 ──
	print("── ⑤ 이혼 — 깃든 혼은 잔류(불가역) ──")
	m.wallet.gold = 999999
	m._do_divorce()
	_check("⑤a 이혼 성립(배우자 슬롯이 비었다)", m._spouse_id == "")
	_check("⑤b ★깃든 혼은 잔류한다([ADR-0022] 자녀 잔류 자구 그대로)",
		m._soul_born and r.node.visible)
	_check("⑤c 재혼해도 2호는 없다(최대 1)", _remarry_no_second(m))

	await _despawn(m)

	# ── ⑥ 아직 안 깃든 예정은 이혼이 접는다 · ⑦ 옥자 혼인 경로 ──
	print("── ⑥ 미탄생 예정은 이혼이 접는다 · 재혼하면 새로 선다 ──")
	var m2: Node = await _spawn_main()
	_dismiss_dialogue(m2)
	m2.wallet.gold = 999999
	_wed(m2, "mochi", 30)
	_check("⑥a 예정이 섰다", m2._soul_due_day == 30 + m2.SOUL_CHILD_WAIT_DAYS)
	m2._do_divorce()
	_check("⑥b 깃들기 전 이혼 = 예정이 접힌다(결속에서 깃드는 존재라 결속이 풀리면 함께 풀린다)",
		m2._soul_due_day == 0 and not m2._soul_born)
	m2.clock.day = 60
	m2._arm_soul_birth(60)
	_check("⑥c 접힌 뒤에는 어느 아침도 예약을 안 세운다", not m2._soul_birth_armed)
	_wed(m2, "mochi", 70)
	_check("⑥d 재혼하면 그 혼례 아침에 새로 14일이 선다",
		m2._soul_due_day == 70 + m2.SOUL_CHILD_WAIT_DAYS)

	print("── ⑦ ★옥자 혼인 경로도 같은 줄을 지난다 ──")
	# 앵커 혼례도 `_advance_wedding` 하나를 지나므로 **분기 없이** 같은 14일이 걸린다.
	m2._soul_due_day = 0
	m2._soul_born = false
	m2._spouse_id = ""
	_wed(m2, m2.OKJA_RID, 80)
	_check("⑦a 앵커와의 혼례도 배우자가 되고", m2._spouse_id == m2.OKJA_RID)
	_check("⑦b ★같은 14일 예정이 선다(분기 0 = 두 경로 커버의 구현)",
		m2._soul_due_day == 80 + m2.SOUL_CHILD_WAIT_DAYS)
	m2._spine_b7_armed = false          # B7 예약은 척추 스위트 소관 — 여기선 걷어 두고 탄생만 잰다
	m2.clock.day = 80 + m2.SOUL_CHILD_WAIT_DAYS
	m2._arm_soul_birth(m2.clock.day)
	m2._fire_soul_birth()
	_check("⑦c 앵커 혼인에서도 형상화가 성립한다(척추 B7 *이후*의 층 — 서사 충돌 0)",
		m2._soul_born and m2.cutscene != null)
	_drain(m2)

	# ── ⑧ 세이브 왕복 ──
	print("── ⑧ 세이브 왕복 ──")
	var live_born: bool = m2._soul_born
	m2._save_game()
	await _despawn(m2)
	var m3: Node = await _spawn_main()
	_dismiss_dialogue(m3)
	_check("⑧a 재부팅 후 탄생 여부 복원 · 몸이 선다",
		m3._soul_born == live_born and live_born
		and m3._resident(m3.SOUL_CHILD_RID).node.visible)
	_check("⑧b 예약은 세이브를 안 탄다(연출은 저장 대상이 아니다)", not m3._soul_birth_armed)
	# 손상 방어 — "태어났는데 예정이 또 있는" 세이브를 **로드 경로가** 정리한다.
	# ★[폴리시 R15] 종전엔 이 자리가 main.gd `_load_game`의 정규화 세 줄을 테스트 안에서 그대로
	#   **베껴 실행한 뒤** 자기가 넣은 값을 되읽었다 — 세이브 파일도 `_load_game`도 안 타서, 실제
	#   정규화(`if _soul_born: _soul_due_day = 0`)를 지워도 ✓였다(2호가 예약된 채 초록). 이제 슬롯
	#   파일의 그 두 키를 직접 손상시키고 **재부팅으로 왕복**한다 — 판정식이 프로덕션 경로에 선다.
	await _despawn(m3)
	var doctored: bool = _doctor_save(SAVE, "soul_born", true) \
		and _doctor_save(SAVE, "soul_due_day", 999)
	_check("⑧c-pre 슬롯 파일에 손상값이 실제로 박혔다(soul_born=true · soul_due_day=%s)"
			% str(_save_data_value(SAVE, "soul_due_day")),
		doctored and int(_save_data_value(SAVE, "soul_due_day")) == 999
		and bool(_save_data_value(SAVE, "soul_born")))
	var m4: Node = await _spawn_main()
	_dismiss_dialogue(m4)
	_check("⑧c 손상 방어 — 로드가 탄생 뒤 예정을 0으로 정리(2호가 서지 않는다) · 탄생은 살아 있다",
		m4._soul_due_day == 0 and m4._soul_born)

	# ── ⑨ 봉인 법칙 ──
	print("── ⑨ ⚠️ 봉인 법칙 · 설정선 ──")
	var body := ""
	for line in SoulChild.BIRTH_LINES:
		body += String(line) + "\n"
	for line in SoulChild.LINES:
		body += String(line) + "\n"
	var sealed := ["옥자", "그날 밤", "대화재", "화재", "불길", "명부", "미결", "죄"]
	var leaked := ""
	for tok: String in sealed:
		if body.contains(tok):
			leaked = tok
	_check("⑨a 본문이 척추·앵커를 한 글자도 안 말한다(누출: %s)"
			% ("없음" if leaked == "" else leaked), leaked == "")
	# ⚠️ 생물학적 출산이 아니다(CONTEXT [동행 혼]) — 그 어휘가 본문에 없어야 한다.
	var birth_words := ["낳았", "출산", "임신", "아기를 낳", "핏줄", "닮았"]
	var bio := ""
	for tok: String in birth_words:
		if body.contains(tok):
			bio = tok
	_check("⑨b ⚠️ 출산 어휘 0 — *혼의 형상화*다(누출: %s)"
			% ("없음" if bio == "" else bio), bio == "")
	_check("⑨c 「깃들」 계열 어휘로 형상화를 말한다(설정선의 긍정 확인)",
		body.contains("형상") or body.contains("깃"))
	# 성별·생물학 무관(동성 부부 포함 전 부부 동일) — 성별 지시어가 본문에 없다.
	var gendered := ["아들", "딸", "아드님", "따님", "그녀", "사내", "계집"]
	var g_leak := ""
	for tok: String in gendered:
		if body.contains(tok):
			g_leak = tok
	_check("⑨d 성별 지시어 0(결속에서 깃들므로 성별 무관 — 입양 분기 0의 문면)", g_leak == "")
	# 컷신은 4동사만 쓴다(illust는 S등급 전용 — 이 층이 쓰면 등급 인플레).
	var verbs_ok := true
	var has_illust := false
	for step in SoulChild.BIRTH_CUTSCENE:
		var v := String(step.get("verb", ""))
		if not CutsceneRunner.VERBS.has(v):
			verbs_ok = false
		if v == CutsceneRunner.VERB_ILLUST:
			has_illust = true
	_check("⑨e 탄생 컷신 = 허용 동사만 · **illust 미사용**(S등급은 척추 전용)",
		verbs_ok and not has_illust and SoulChild.BIRTH_CUTSCENE.size() > 0)
	_check("⑨f 컷신에 NPC 이동이 없다(암전 뒤에서 일어나는 일 — 옮길 것이 없다)",
		not _has_verb(SoulChild.BIRTH_CUTSCENE, CutsceneRunner.VERB_NPC))

	await _despawn(m4)

	if had_save:
		_write_bytes(SAVE, _read_bytes(BAK))
		DirAccess.remove_absolute(ProjectSettings.globalize_path(BAK))
	elif FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))

	print("══ 결과: %s ══" % ("PASS (실패 0)" if _fail == 0 else "FAIL (실패 %d)" % _fail))
	quit(1 if _fail > 0 else 0)

func _has_verb(steps: Array, verb: String) -> bool:
	for step in steps:
		if String(step.get("verb", "")) == verb:
			return true
	return false

# 관계 탭 행에 동행 혼이 없다(자격 = affinity 하나 — 이 사람은 트랙이 없다).
func _rows_clean(m: Node) -> bool:
	for row in m._heart_rows():
		if String(row["name"]) == "동행 혼":
			return false
	return true

# 재혼해도 2호가 서지 않는다 — 이미 깃들었으면 예정 자체가 안 선다.
func _remarry_no_second(m: Node) -> bool:
	var before: bool = m._soul_born
	_wed(m, "mochi", m.clock.day + 5)
	return before and m._soul_born and m._soul_due_day == 0
