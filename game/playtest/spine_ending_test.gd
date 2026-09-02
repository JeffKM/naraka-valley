extends SceneTree
# ★[S9b-T8 / ADR-0068 결정 9·10·11] 척추 B6 귀환 · 앵커 트랙 · B7 해방 · 에필로그 — 헤드리스 검증.
#
# 무엇을 보증하나:
#   ① `illust` 동사(결정 9) — 5동사 정규화 · **미지 동사 거절 규약 하위호환**(ADR-0067 결정 2 상속) ·
#      등장/퇴장 비대칭 · 결정성 · **에셋 훅 분기**(파일 있으면 원화 · 없으면 placeholder).
#   ② B6 발동(§6.5 5단) — B5 완료 지문이 닫히는 그 자리에서 이어 붙는다 · 비트 · 앵커 집 상시 개방 ·
#      **화자가 갈린 세 묶음**이 순서대로 선다(내면 → 앵커의 말 → 내면) · 재발동 0.
#   ③ 앵커 트랙(결정 10) — **선물·대화·활동 3채널이 전부 무효**이고 deed만 적립한다 ·
#      이혼 *경력*은 통과 · **현재 배우자가 있으면 잠금** · 세 축이 원장 파생이다.
#   ④ B7 해방(결정 10) — 궁극의 결혼 게이트 AND 전수(척추 B6 · deed ♡max · 정표 특별판 · 배우자 방) ·
#      주례는 **지문뿐**(`gangrim.gd` 무접촉) · 해방 비트.
#   ⑤ 에필로그(결정 11) — B7 직후 **1회성** · 닫으면 **코지 샌드박스 복귀**(게임 종료 아님) ·
#      하트가 **스프라이트**다(문자열 막대 아님 — S8-T10 이월 소화) · 세이브 왕복.
#   ⑥ 봉인 법칙의 **양방향** — 캐릭터 파일·B5 본문의 금칙어 가드는 그대로 살아 있고,
#      B6·B7 본문은 중심 진실을 **실제로 연다**(허용 상한 실존 — 침묵만 재면 그건 검열이다).
#      그리고 두 곳 모두 **평결 18어는 0**이다(진실은 열리되 판결은 없다 — §2.2).
#
# ★ 관례(기존 스위트 상속): 하트는 points·stage 동반 세팅 · 드레인은 컷신 재생 + 선택지
#   `has_choice → choose(0)` 동반 · 소스 스캔은 **주석을 걷어낸 뒤**(S9b-T7 교훈: 예약 주석이
#   위반으로 잡힌다) · 헤드리스는 반드시 game/에서 · 순차 실행.
#
# 실행: ./run_tests.sh spine_ending   (TIMEOUT=300 권장 — main 인스턴스 2회 + 목공 2일)

const T1 := Spine.T1_ROSTER
const MAINS := Spine.MAIN_ROSTER
# 캐릭터 파일 전수(메인 3 + T1 11) — 중심 진실이 **여기 새어 나오면 안 된다**(가드는 여전히 유효).
const CHAR_FILES := ["miho", "mel", "bana", "mochi", "neo", "kkaebi", "ken", "seolhwa",
	"scarlet", "mir", "luca", "frosty", "gangrim", "serena"]

var _fail := 0

func _check(label: String, ok: bool) -> void:
	print(("  ✓ " if ok else "  ✗ ") + label)
	if not ok:
		_fail += 1

func _new_main() -> Node:
	var m: Node = load("res://main.tscn").instantiate()
	get_root().add_child(m)
	await process_frame
	await process_frame
	return m

# 컷신만 끝까지 굴린다(대화는 안 건드린다).
func _settle(m: Node) -> void:
	var guard := 0
	while m.cutscene != null and guard < 400:
		m._tick_cutscene(0.2)
		guard += 1

# ★ 컷신과 대화가 **번갈아** 오는 구간을 통째로 비운다(척추 S등급은 한 장면이 러너 → 대화
#   → 대화 → 대화로 이어지므로, 컷신 전용 드레인만으로는 절반에서 멈춘다).
func _drain(m: Node) -> void:
	var guard := 0
	while (m.cutscene != null or m.dialogue.is_open()) and guard < 3000:
		if m.cutscene != null:
			m._tick_cutscene(0.2)
		elif m.dialogue.has_choice():
			m.dialogue.choose(0)
		else:
			m.dialogue.advance()
		guard += 1

# 지금 열린 **한 묶음만** 넘긴다. ★다음 묶음은 `_on_dialogue_finished`가 같은 프레임에 여니까
#   `while is_open()`으로 돌면 장면 전체가 한 번에 비워진다 — 화자가 바뀌는 순간 멈춰야 한다.
func _drain_one(m: Node) -> void:
	var who: String = m.dialogue.speaker()
	var guard := 0
	while m.dialogue.is_open() and m.dialogue.speaker() == who and guard < 300:
		if m.dialogue.has_choice():
			m.dialogue.choose(0)
		else:
			m.dialogue.advance()
		guard += 1

func _set_heart(r, stage: int) -> void:
	r.affinity.stage = stage
	r.affinity.points = Affinity.MAX_POINTS

func _fill_gate(m: Node) -> void:
	for rid in MAINS:
		var r = m._resident(String(rid))
		if r != null and r.affinity != null:
			_set_heart(r, Spine.MAIN_STAGE)
	m._mark_spine_bit(m.SPINE_B4)
	for rid in T1:
		m._mark_heart_bit(String(rid), Spine.CHORUS_HEART)

func _stand_at_door(m: Node) -> void:
	m._rebuild_region(RegionCatalog.MIHOK_FOREST)
	m.player.global_position = m._tile_center_px(m.OKJA_HUT_DOOR)

func _file_text(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	return "" if f == null else f.get_as_text()

# 주석을 걷어낸 소스(설계 주석의 낱말이 스캔에 걸리지 않게 — spine_test `_code_only` 동형).
func _code_only(path: String) -> String:
	var out := PackedStringArray()
	for ln in _file_text(path).split("\n"):
		if not String(ln).strip_edges().begins_with("#"):
			out.append(String(ln))
	return "\n".join(out)

func _scan_words(text: String, words: Array) -> String:
	for w in words:
		if text.contains(String(w)):
			return String(w)
	return ""

func _joined(pack) -> String:
	return "\n".join(PackedStringArray(pack))

func _label_with(m: Node, needle: String) -> String:
	for lbl in m._labels:
		if lbl is Label and String((lbl as Label).text).contains(needle):
			return String((lbl as Label).text)
	return ""

func _has_verb(steps: Array, verb: String) -> bool:
	for s in steps:
		if typeof(s) == TYPE_DICTIONARY and String((s as Dictionary).get("verb", "")) == verb:
			return true
	return false

# 아이템을 손에 든다(청혼 = 든 아이템 문법 — marriage_test `_hold` 동형).
func _hold(m: Node, id: String) -> void:
	if not m.inventory.has_item(id):
		m.inventory.add_item(id, 1, ItemCatalog.Q_NORMAL)
	for i in m.inventory.slots.size():
		if m.inventory.id_at(i) == id:
			m.inventory.select(i)
			return

func _pass_day(m: Node) -> void:
	m.clock.day += 1
	m._on_day_advanced(m.clock.day)

# 안방 확장 완공(marriage_test ②가 태운 그 경로 그대로 — 공통 관문이라 여기서도 필요하다).
func _expand_home(m: Node) -> void:
	m.wallet.gold = 10000
	var have: int = m.inventory.count_of(ItemCatalog.WOOD)
	if have < 300:
		m.inventory.add_item(ItemCatalog.WOOD, 300 - have)
	m._try_order_build(Carpenter.PROJ_MASTER_ROOM)
	_pass_day(m)
	_pass_day(m)

# B5를 실제로 완주해 B6까지 몬다(컷신 → 내면 공간 → 별 잇기 → 완료 지문).
func _run_b5(m: Node) -> void:
	m._maybe_spine_b5()
	_settle(m)
	_drain_one(m)                      # 오프닝 지문
	var guard := 0
	while m.spine_puzzle != null and not m.spine_puzzle.is_done() and guard < 100:
		m.spine_puzzle.link(m.spine_puzzle.next_index())
		guard += 1
	m._tick_spine_puzzle()             # 완료 판정 → 완료 지문


func _initialize() -> void:
	await _run_checks()

func _run_checks() -> void:
	print("══ S9b-T8 척추 B6·B7 — illust · 앵커 트랙 · 해방 · 에필로그 ══")
	var cleaner := SaveManager.new()
	cleaner.delete_save()

	# ── ① `illust` 동사([ADR-0068] 결정 9) ──────────────────────────────────
	print("── ① illust 동사 ──")
	_check("①a 동사가 정확히 5개다(다섯째 = illust · 여섯째를 더하려면 또 한 번의 ADR 개정)",
		CutsceneRunner.VERBS.size() == 5 and CutsceneRunner.VERBS.has(CutsceneRunner.VERB_ILLUST))
	var r1 := CutsceneRunner.new([{"verb": "illust", "id": "zz_test", "secs": 1.0}])
	_check("①b 정규화 통과(거절 0 · 스텝 1)", r1.rejected_verbs().is_empty() and r1.step_count() == 1)
	_check("①c 재생 전엔 그림이 없다", r1.illust_id() == "" and is_zero_approx(r1.illust_alpha()))
	r1.start()
	r1.advance(0.5)
	_check("①d ★등장은 **시작 즉시**다(id는 서고 불투명도만 보간된다 — npc 가시성과 같은 비대칭)",
		r1.illust_id() == "zz_test" and r1.illust_alpha() > 0.0 and r1.illust_alpha() < 1.0)
	r1.advance(1.0)
	_check("①e 끝값이 정확히 1.0이고 재생이 끝난다", r1.is_done()
		and is_equal_approx(r1.illust_alpha(), 1.0) and r1.illust_id() == "zz_test")
	var r2 := CutsceneRunner.new([
		{"verb": "illust", "id": "zz_test"},
		{"verb": "illust", "id": "", "secs": 0.4}])
	r2.start()
	r2.advance(0.2)
	_check("①f 퇴장 중에는 그림이 **아직 서 있다**(스러지는 동안 사라지지 않는다)",
		r2.illust_id() == "zz_test" and r2.illust_alpha() < 1.0)
	r2.advance(1.0)
	_check("①g ★퇴장은 보간을 **마친 뒤** 확정된다(id가 비고 불투명도 0)",
		r2.illust_id() == "" and is_zero_approx(r2.illust_alpha()))
	# ★ 미지 동사 거절 규약(ADR-0067 결정 2)의 하위호환 — 다섯째가 열려도 여섯째는 여전히 거절된다.
	var r3 := CutsceneRunner.new([
		{"verb": "sfx", "id": "x"},
		{"verb": "illust", "id": "zz_test"},
		{"verb": "dialogue", "line": "안녕"}])
	_check("①h ★미지 동사는 여전히 **거절 기록 후 스킵**이다(둘 거절 · illust만 재생)",
		r3.rejected_verbs().size() == 2 and r3.step_count() == 1
		and Array(r3.rejected_verbs()) == ["sfx", "dialogue"])
	# 결정성 — 같은 스텝 배열 + 같은 delta 열 = 같은 전이열(러너의 계약).
	var script := [{"verb": "clock", "running": false}, {"verb": "illust", "id": "zz", "secs": 0.6},
		{"verb": "fade", "to": 0.5, "secs": 0.3}, {"verb": "illust", "id": "", "secs": 0.4}]
	var d1 := CutsceneRunner.new(script.duplicate(true)); d1.start()
	var d2 := CutsceneRunner.new(script.duplicate(true)); d2.start()
	for _i in 20:          # 총 길이 1.3초 — 넉넉히 넘겨 둘 다 종착까지 굴린다
		d1.advance(0.1)
		d2.advance(0.1)
	_check("①i 결정성 불변 — 같은 delta 열이면 전이열이 문자열로 같다",
		"|".join(d1.trace()) == "|".join(d2.trace()) and d1.is_done())
	# 4동사만 쓰는 옛 컷신은 그림을 한 번도 안 든다(하위호환의 실물).
	var old := CutsceneRunner.new(Spine.B5_CUTSCENE.duplicate(true)); old.start()
	old.advance(99.0)
	_check("①j ★4동사만 쓰는 기존 컷신은 그림을 안 든다(하위호환 — B5 발동 컷신으로 실측)",
		old.is_done() and old.illust_id() == "" and is_zero_approx(old.illust_alpha()))
	_check("①k B6·B7 컷신이 **5동사 안**이고 illust를 쓴다",
		CutsceneRunner.new(Spine.B6_CUTSCENE).rejected_verbs().is_empty()
		and CutsceneRunner.new(Spine.B7_CUTSCENE).rejected_verbs().is_empty()
		and _has_verb(Spine.B6_CUTSCENE, "illust") and _has_verb(Spine.B7_CUTSCENE, "illust"))
	_check("①l ★B6는 **즉시** 그림을 세운다(B5 암전이 한 프레임도 안 끊긴다) · B7은 암전 뒤에 세운다",
		float(Spine.B6_CUTSCENE[1].get("secs", 0.0)) == 0.0
		and _has_verb(Spine.B7_CUTSCENE, "fade"))
	_check("①m 둘 다 **npc 동사 0**이다(풀스크린이라 무대 이동이라는 개념 자체가 없다)",
		not _has_verb(Spine.B6_CUTSCENE, "npc") and not _has_verb(Spine.B7_CUTSCENE, "npc"))

	var m: Node = await _new_main()
	_drain(m)
	m.onboarding.step = Onboarding.DONE
	# 에셋 훅 분기 — 원화가 있으면 그것이 뜨고, 없으면 placeholder다. 지금은 후자이고(owner-Gemini
	# 큐 대기) **그 상태로도 장면이 완성**이라는 것이 결정 9의 요점이다.
	var has_art := ResourceLoader.exists("res://assets/cutscene/%s.png" % Spine.ILLUST_B6)
	_check("①n ★에셋 훅 = `assets/cutscene/<id>.png` 드롭인(지금은 미도착 → placeholder 경로)",
		m._illust_texture(Spine.ILLUST_B6) == null if not has_art
		else m._illust_texture(Spine.ILLUST_B6) != null)
	_check("①o ★placeholder가 **비어 있지 않다**(먹 암전만 뜨면 그건 연출이 아니라 사고다)",
		Spine.illust_title(Spine.ILLUST_B6) != "" and Spine.illust_subtitle(Spine.ILLUST_B6) != ""
		and Spine.illust_title(Spine.ILLUST_B7) != "")
	_check("①p 모르는 id는 placeholder 문구가 빈 문자열이다(방어)", Spine.illust_title("nope") == "")

	# ── ② B6 귀환(§6.5 5단 "카타르시스 전환") ────────────────────────────────
	print("── ② B6 귀환 ──")
	var r_okja: Resident = m._resident("okja")
	_check("②a ★B6 전에는 앵커에게 관계 트랙이 **아예 없다**(개통 전 거동 불변의 뿌리)",
		r_okja.affinity == null and r_okja.save_key == "" and not m._okja_track_open())
	_fill_gate(m)
	_stand_at_door(m)
	_check("②b B5 전에는 B6·B7 비트가 0이다",
		not m._spine_bit_seen(m.SPINE_B6) and not m._spine_bit_seen(m.SPINE_B7))
	_run_b5(m)
	_check("②c B5 비트가 서고 완료 지문이 돈다",
		m._spine_bit_seen(m.SPINE_B5) and m.dialogue.is_open() and not m._spine_bit_seen(m.SPINE_B6))
	_drain_one(m)                       # 완료 지문 → _close_spine_puzzle → B6 발동
	# ★[폴리시 R11] 비트가 장면 **끝**으로 옮겨갔다(#7 — 재생 도중 종료 시 §6.5가 영영 못 뜨던 구멍).
	#   그래서 여기서 잠그는 것은 "비트가 섰다"가 아니라 "장면이 실제로 이어 붙고 예약이 섰다"다.
	_check("②d ★완료 지문이 닫히는 **그 자리**에서 B6가 이어 붙는다(예약 · 재생 · 내면 공간 해제)",
		m._spine_b6_pending and not m._spine_bit_seen(m.SPINE_B6)
		and m.cutscene != null and m.spine_puzzle == null)
	_settle(m)
	_check("②e ★그림이 화면을 덮는다(S등급 — 이 위에서 대사가 돈다)",
		m._illust_id == Spine.ILLUST_B6 and m._illust_a > 0.0)
	_check("②f 첫 묶음은 **화자 없는 내면**이다(이름판 공백 — B4·B5가 세운 문법 그대로)",
		m.dialogue.is_open() and m.dialogue.speaker() == ""
		and m.dialogue.line() == String(Spine.B6_RETURN_LINES[0]))
	_check("②g 상시 HUD가 접힌다(연출 화면)", m._illust_id != "")
	_drain_one(m)
	_check("②h ★둘째 묶음에서 **앵커가 처음 입을 연다**(화자 전환 — 본문 소유는 캐릭터 파일)",
		m.dialogue.is_open() and m.dialogue.speaker() == r_okja.display_name)
	_drain_one(m)
	_check("②i 셋째 묶음이 다시 내면으로 돌아온다(내면 → 앵커 → 내면 3막)",
		m.dialogue.is_open() and m.dialogue.speaker() == ""
		and m.dialogue.line() == String(Spine.B6_CLOSE_LINES[0]))
	_drain(m)
	_check("②j ★마지막 묶음이 닫히면 그림을 거두고 세계로 돌아온다(잔류 0)",
		m._illust_id == "" and is_zero_approx(m._illust_a) and m._spine_say.is_empty()
		and m.player.is_physics_processing() and not m._epilogue_open)
	_check("②j′ ★[폴리시 R11] **비트가 서는 자리가 바로 여기다** — 예약이 소비되고 원장이 굳는다",
		m._spine_bit_seen(m.SPINE_B6) and not m._spine_b6_pending)
	_stand_at_door(m)   # 구역 재빌드 = 라벨 재배치
	_check("②k ★앵커 집이 **상시 개방**으로 바뀐다(조건 문구 자체가 걷힌다)",
		_label_with(m, "옥자 집") == "옥자 집")
	var bits_after_b6: int = m._spine_bits
	for _i in 5:
		m._fire_spine_b6()
		m._maybe_spine_b5()
	_check("②l ★재발동 0(B6도 B5도 다시 안 뜬다 — 비트가 유일한 방어선)",
		m.cutscene == null and m.spine_puzzle == null and not m.dialogue.is_open()
		and m._spine_bits == bits_after_b6 and m._spine_say.is_empty())
	_check("②m 척추 원장이 B4·B5·B6까지다(B7은 아직 — 궁극 분기를 지나야 선다)",
		m._spine_bits == ((1 << m.SPINE_B4) | (1 << m.SPINE_B5) | (1 << m.SPINE_B6)))

	# ── ③ 앵커 트랙 = deed 단독 채널([ADR-0068] 결정 10) ─────────────────────
	print("── ③ 앵커 트랙(deed 단독) ──")
	_check("③a ★B6가 트랙을 개통한다(Affinity 노드·세이브 키가 이 순간에야 생긴다)",
		r_okja.affinity != null and r_okja.save_key == "okja_affinity" and m._okja_track_open())
	_check("③b 세 축의 만점 합이 하트 만점과 **정확히 같다**(어긋나면 다 갚아도 ♡가 안 찬다)",
		Spine.okja_deed_max() == Affinity.MAX_POINTS)
	var terms := Spine.okja_deed_terms(true, 0, 11, 0)
	_check("③c 축이 **이름 붙어** 따로 보인다(망각·외면·부재)",
		terms.has("memory") and terms.has("face") and terms.has("tend")
		and int(terms["face"]) == Spine.OKJA_FACE_POINTS and int(terms["memory"]) == 0)
	_check("③d 외면 반전은 척추 비트 파생이다(B4·B5를 안 지나면 0점)",
		Spine.okja_deed_points(false, 0, 11, 0) == 0
		and Spine.okja_deed_points(true, 0, 11, 0) == Spine.OKJA_FACE_POINTS)
	_check("③e 만점은 **세 축이 다 차야** 나온다(한 축만으로는 못 채운다)",
		Spine.okja_deed_points(true, 11, 11, Spine.OKJA_TEND_HARVEST) == Affinity.MAX_POINTS
		and Spine.okja_deed_points(true, 11, 11, 0) < Affinity.MAX_POINTS
		and Spine.okja_deed_points(true, 0, 11, Spine.OKJA_TEND_HARVEST) < Affinity.MAX_POINTS)
	_check("③f 상한을 넘겨도 안 넘친다(초과 기증·초과 수확 방어)",
		Spine.okja_deed_points(true, 99, 11, 99999) == Affinity.MAX_POINTS)
	m._refresh_okja_track()
	var pts0: int = r_okja.affinity.points
	_check("③g 지금 점수는 외면 반전 한 축뿐이다(척추만 지났고 아직 아무것도 안 갚았다)",
		pts0 == Spine.OKJA_FACE_POINTS)
	# ㉠ 대화 채널 차단
	m._start_resident_dialogue(r_okja)
	_drain(m)
	m._start_resident_dialogue(r_okja)
	_drain(m)
	_check("③h ★대화 채널 무효 — 두 번을 말 걸어도 점수가 한 점도 안 오른다(일일 대화 0)",
		r_okja.affinity.points == pts0 and r_okja.affinity.last_talk_day == -1)
	# ㉡ 선물 채널 차단
	_hold(m, ItemCatalog.WEDDING_CHARM)
	var held_before: int = m.inventory.count_of(ItemCatalog.WEDDING_CHARM)
	m._try_resident_gift(r_okja)
	_check("③i ★선물 채널 무효 — 무엇을 건네도 점수 0이고 물건도 안 사라진다(무소모)",
		r_okja.affinity.points == pts0
		and m.inventory.count_of(ItemCatalog.WEDDING_CHARM) == held_before
		and r_okja.affinity.last_gift_day == -1)
	_check("③j 선물 채널 자체가 안 열려 있다(`can_gift` false — [G]는 정표 하나만 통과한다)",
		not r_okja.can_gift)
	# ㉢ 활동 채널 차단
	m._activity_credit("okja", Affinity.ACTIVITY_DAILY_CAP)
	_check("③k ★활동 채널 무효 — 배선점이 생겨도 적립이 0이다(호출부 게이트가 문을 미리 닫아 뒀다)",
		r_okja.affinity.points == pts0 and r_okja.affinity.activity_today == 0)
	# ㉣ deed 단독 적립
	for id in Museum.donatable_ids():
		m.museum.donate(String(id), m.clock.day)
	m._run_harvested = Spine.OKJA_TEND_HARVEST
	m._refresh_okja_track()
	_check("③l ★deed만이 트랙을 채운다 — 되찾고(%d) 마주하고 돌보니(%d) 만충이다"
		% [m.museum.donated_count(), m._run_harvested],
		r_okja.affinity.points == Affinity.MAX_POINTS)
	# ★ 이 트랙만은 **칸도 deed 파생**이다 — 관문 이벤트가 없다(deed가 곧 관문이고, 다른 로스터의
	#   ♡5를 여는 의지 시험은 앵커에게 존재하지 않는다. 칸을 관문에 맡기면 ♡4에서 영영 멈춘다).
	_check("③m ★칸도 함께 파생한다 — 다 갚으면 그 자리에서 ♡max다(진급 대기라는 상태가 없다)",
		r_okja.affinity.hearts() == Affinity.MAX_HEARTS
		and not r_okja.affinity.pending_promotion())
	m._start_resident_dialogue(r_okja)
	_drain(m)
	_check("③n 대화는 칸을 **안 건드린다**(관문이 없으니 진급 알림도 편지도 없다)",
		r_okja.affinity.hearts() == Affinity.MAX_HEARTS
		and r_okja.affinity.points == Affinity.MAX_POINTS)
	_check("③o 반쯤 갚은 상태는 반쯤 찬 칸이다(파생이라 눈금이 항상 정직하다)",
		Spine.okja_deed_points(true, 11, 11, 0) / Affinity.POINTS_PER_HEART
			== (Spine.OKJA_FACE_POINTS + Spine.OKJA_MEMORY_POINTS) / Affinity.POINTS_PER_HEART)
	# ㉤ 이혼 경력은 통과 · 현 배우자는 잠금(결정 10-ⓓ)
	m._ever_married["mochi"] = true
	m._refresh_okja_track()
	_check("③p ★이혼 *경력*은 진입을 안 막는다(ADR-0022 재구애 허용 — 이력이 아니라 현재 상태다)",
		m._okja_track_open() and r_okja.affinity.points == Affinity.MAX_POINTS)
	m._spouse_id = "mochi"
	m._refresh_okja_track()
	_check("③q ★현재 배우자가 있으면 **잠긴다**(ADR-0032 '미혼'의 기계 해석 = 현재 상태)",
		not m._okja_track_open() and r_okja.affinity.points == 0
		and r_okja.affinity.hearts() == 0)
	m._spouse_id = ""
	m._refresh_okja_track()
	_check("③r ★곁이 비면 그 자리에서 되돌아온다(잠금은 벌칙이 아니라 상태다 — 갚은 것은 안 사라진다)",
		m._okja_track_open() and r_okja.affinity.hearts() == Affinity.MAX_HEARTS)

	# ── ④ B7 해방 + 궁극의 결혼 분기(§6.3 · 결정 10) ─────────────────────────
	print("── ④ B7 해방 ──")
	_check("④a 정표 특별판은 **명부의 주인**이 접는다(창구가 앵커가 아니다 — §6.3)",
		ItemCatalog.name_of(ItemCatalog.MYEONGBU_CHARM) == "명부 혼례 부적"
		and m._resident("gangrim").shop_key.is_valid())
	_check("④b 배우자 방 미완공이면 의뢰는 열려도 청혼은 거절이다(게이트가 둘로 갈려 있다)",
		m._myeongbu_quest_open() and not m._home_expanded())
	m._grant_myeongbu_charm()
	_hold(m, ItemCatalog.MYEONGBU_CHARM)
	m._try_propose_okja()
	_check("④c ★방 없는 청혼 = **무소모 거절**(부적 보존 — 다른 로스터의 거절과 같은 계약)",
		m._wedding_day == 0 and m.inventory.has_item(ItemCatalog.MYEONGBU_CHARM))
	_check("④d 정표를 쥐면 의뢰가 다시 안 뜬다(세상에 하나뿐 — 열쇠·부적과 같은 결)",
		not m._myeongbu_quest_open())
	_expand_home(m)
	# ★ 연애 슬롯 배타성 — `_resolve_confession`이 지키는 그 불변식이 앵커 청혼 경로에도 서는가.
	#   앵커는 고백 문법 밖이라 청혼이 곧 고백인데, 여기서 슬롯을 말없이 덮어쓰면 기존 연인이
	#   알림 0으로 탈락한 뒤 **영구히 돌아올 수 없다**(진급은 단조 · 제안은 ♡4에서만 선다 ·
	#   `reset_hearts`는 배우자 이혼 경로 전용). 거절은 다른 가지와 같이 무소모여야 한다.
	var r_miho: Resident = m._resident("miho")
	_set_heart(r_miho, Affinity.MAX_HEARTS)
	m._romance_partner = "miho"
	_hold(m, ItemCatalog.MYEONGBU_CHARM)
	m._try_propose_okja()
	_check("④e1 ★곁에 연인이 있으면 앵커 청혼도 거절이다(슬롯 배타성 — 고백 경로와 같은 규율)",
		m._romance_partner == "miho" and m._wedding_day == 0 and m._spouse_id == "")
	_check("④e2 ★거절은 무소모·무벌칙이다(부적 보존 · 기존 연인의 칸·점수 불변)",
		m.inventory.has_item(ItemCatalog.MYEONGBU_CHARM)
		and r_miho.affinity.hearts() == Affinity.MAX_HEARTS
		and r_miho.affinity.points == Affinity.MAX_POINTS)
	m._romance_partner = ""   # 곁을 정리한 뒤에야(플레이어가 직접 할 일) 청혼이 성립한다
	_hold(m, ItemCatalog.MYEONGBU_CHARM)
	m._try_propose_okja()
	_check("④e ★네 항이 다 차면 혼례가 정해진다(척추 B6 · deed ♡max · 정표 특별판 · 배우자 방)",
		m._wedding_day == m.clock.day + m.WEDDING_WAIT_DAYS and m._romance_partner == "okja"
		and not m.inventory.has_item(ItemCatalog.MYEONGBU_CHARM))
	_check("④f 질투는 0건이다(앵커는 메인 3인 명단 밖 — [ADR-0066] 결정 7 자구 불변)",
		m._jealousy.is_empty())
	m.clock.day = m._wedding_day
	m._advance_wedding(m.clock.day)
	_check("④g 혼례가 성립하고 B7이 **예약**된다(재생은 눈을 뜨는 프레임 — B4와 같은 두 단계)",
		m._spouse_id == "okja" and m._spine_b7_armed and not m._spine_bit_seen(m.SPINE_B7))
	_check("④h 앵커와의 혼인은 트랙을 안 닫는다(잠금은 *다른* 배우자에 대한 것이다)",
		m._okja_track_open() and r_okja.affinity.hearts() == Affinity.MAX_HEARTS)
	# ★ 예약이 **한 번 접혀도** 사슬이 끊기지 않는가. `_spine_b7_armed`를 세우는 곳은 혼례 아침
	#   하나뿐이고 그 함수는 첫 줄에서 `_wedding_day`를 지워 두 번 안 돈다 — 그래서 `_fire_spine_b7`이
	#   재생 중첩·러너 거절로 한 번이라도 접히면 엔딩 연출이 통째로 사라졌다. 재개 훅이 그 자리를
	#   원장(배우자 = 앵커 · B6 기성립 · B7 미기록)에서 다시 잇는다.
	m._spine_b7_armed = false                   # = `_fire_spine_b7`이 조기 반환으로 예약만 태운 상태
	_check("④h1 pre 예약이 접혔다(옛 코드라면 여기서 엔딩이 영구 소실된다)",
		not m._spine_b7_armed and not m._spine_bit_seen(m.SPINE_B7) and m._spouse_id == "okja")
	m._maybe_resume_spine()
	_check("④h2 ★재개 훅이 해방을 되찾는다(예약 재무장 + 그 자리에서 재생 + 에필로그 예약)",
		m.cutscene != null and not m._spine_b7_armed and m._epilogue_pending)
	# ★[폴리시 R6] 비트는 **아직 안 선다** — 찍는 자리를 장면 시작에서 에필로그가 열리는 자리로
	#   옮겼다. 옛 자리에서는 혼례 아침의 자동 저장(`_on_sleep_done`의 바로 다음 줄)이 *미완의*
	#   장면을 완료로 굳혔고, 대사 열·에필로그 예약은 비영속이라 그 사이에 앱이 꺼지면 재개 훅의
	#   두 갈래가 모두 거짓이 되어 주례 지문·앵커 대사·해방 대사·에필로그가 영구 도달 불가였다.
	#   이제 그 상태는 "아직 안 왔다"로 읽혀 이 훅이 장면을 처음부터 다시 튼다(polish_r6_test ⑧).
	_check("④h3 그런데 비트는 아직 안 선다 — 끊기면 다시 이어야 하므로(서는 자리는 ⑤a 에필로그)",
		not m._spine_bit_seen(m.SPINE_B7))
	m._fire_spine_b7()
	_check("④i ★다시 불러도 장면이 겹치지 않는다(예약은 이미 소비됐다) — S등급 컷신이 그대로 돈다",
		m.cutscene != null and not m._spine_b7_armed)
	_settle(m)
	_check("④j 그림이 바뀐다(귀환 → 해방)", m._illust_id == Spine.ILLUST_B7)
	_check("④k ★주례는 **지문뿐**이다 — 첫 묶음이 화자 없이 선다(말하는 순간 §5.2가 깨진다)",
		m.dialogue.is_open() and m.dialogue.speaker() == ""
		and m.dialogue.line() == String(Spine.B7_OFFICIANT_LINES[0]))
	_drain_one(m)
	_check("④l 둘째 묶음이 앵커의 말이다", m.dialogue.speaker() == r_okja.display_name)
	_drain_one(m)
	_check("④m 셋째 묶음이 해방의 내면이다(§6.4 '머무름은 선택')",
		m.dialogue.speaker() == "" and m.dialogue.line() == String(Spine.B7_RELEASE_LINES[0]))
	_check("④n 에필로그가 예약돼 있다(아직 안 떴다 — 마지막 묶음이 닫혀야 뜬다)",
		m._epilogue_pending and not m._epilogue_open)

	# ── ⑤ 에필로그([ADR-0068] 결정 11) ───────────────────────────────────────
	print("── ⑤ 에필로그 ──")
	_drain(m)
	_check("⑤a ★해방 직후 에필로그가 뜬다(사장 정산 화면의 재목적화)",
		m._epilogue_open and m.ending_panel.visible and not m._epilogue_pending)
	_check("⑤b ★`_run_over`가 아니다 — 이건 게임의 끝이 아니다(RUN_DAYS 게이트 부활 없음)",
		not m._run_over)
	_check("⑤c 요약이 서 있다(경과일·자산·되찾은 것·곁의 사람)",
		m.ending_text.text.contains("살아낸 날") and m.ending_text.text.contains("모은 냥")
		and m.ending_text.text.contains("되찾아 세운 것")
		and m.ending_text.text.contains(r_okja.display_name))
	_check("⑤d ★하트가 **스프라이트**다(문자열 ♥ 막대가 아니다 — S8-T10 이월 소화)",
		m._epilogue_hearts != null and m._epilogue_hearts.get_child_count() > 0
		and m._epilogue_hearts.get_child(0) is HeartBar
		and not m.ending_text.text.contains("♥") and not m.ending_text.text.contains("♡"))
	var top_row := m._epilogue_hearts.get_child(0) as HeartBar
	_check("⑤e 배우자가 맨 윗줄이다(회고의 주인공)",
		top_row != null and top_row._name_label != null
		and top_row._name_label.text == r_okja.display_name)
	_check("⑤f 화면·시계·이동이 잠긴다(회고 중엔 세계가 멈춘다)",
		not m.clock.running and not m.player.is_physics_processing())
	m._on_ending_button()
	_check("⑤g ★닫으면 **코지 샌드박스로 돌아간다**(§6.4 '머무름은 선택')",
		not m._epilogue_open and not m.ending_panel.visible and m.clock.running
		and m.player.is_physics_processing() and not m._run_over)
	_check("⑤h 버튼 문구가 원래대로 돌아온다(같은 버튼의 두 얼굴)",
		m.ending_restart.text == "처음부터 다시 시작")
	m._epilogue_pending = true
	m._open_epilogue()
	m._close_epilogue()
	m._fire_spine_b7()
	_check("⑤i ★1회성 — B7은 다시 안 서고(비트) 에필로그도 스스로 다시 안 뜬다",
		not m._epilogue_open and m.cutscene == null
		and m._spine_bits == ((1 << m.SPINE_B4) | (1 << m.SPINE_B5) | (1 << m.SPINE_B6)
			| (1 << m.SPINE_B7)))
	var bits_final: int = m._spine_bits
	var okja_pts: int = r_okja.affinity.points
	m._save_game()
	m.free()
	var m2: Node = await _new_main()
	_drain(m2)
	_check("⑤j ★세이브 왕복 — 척추 원장 네 비트가 전부 보존된다(가법 키는 여전히 \"spine_bits\" 하나)",
		m2._spine_bits == bits_final and m2._spine_bit_seen(m2.SPINE_B7))
	var r2_okja: Resident = m2._resident("okja")
	_check("⑤k ★트랙도 복원된다 — 로드가 Affinity를 **먼저** 만들어 저장된 칸을 받는다",
		r2_okja.affinity != null and r2_okja.save_key == "okja_affinity"
		and r2_okja.affinity.hearts() == Affinity.MAX_HEARTS
		and r2_okja.affinity.points == okja_pts)
	_check("⑤l 로드 직후 연출 상태는 언제나 0이다(그림·묶음 열·예약 — 세이브 대상이 아니다)",
		m2._illust_id == "" and m2._spine_say.is_empty() and not m2._spine_b7_armed
		and not m2._epilogue_open and not m2._epilogue_pending)
	_check("⑤m 혼인도 복원된다(배우자 = 앵커)", m2._spouse_id == "okja")

	# ── ⑥ 봉인 법칙 — 양방향 가드 ────────────────────────────────────────────
	print("── ⑥ 봉인 법칙(양방향) ──")
	var b6_corpus := _joined(Spine.B6_RETURN_LINES) + "\n" \
		+ _joined(r2_okja.node.spine_lines("b6", false)) + "\n" + _joined(Spine.B6_CLOSE_LINES)
	var b7_corpus := _joined(Spine.B7_OFFICIANT_LINES) + "\n" \
		+ _joined(r2_okja.node.spine_lines("b7")) + "\n" + _joined(Spine.B7_RELEASE_LINES)
	# ㉠ **허용 상한 실존** — B6는 중심 진실을 실제로 연다(침묵만 재면 그건 가드가 아니라 검열이다).
	_check("⑥a ★축① 희생이 **실제로 열린다**(나 대신 셈을 치른 사람)",
		b6_corpus.contains("대신 셈을 치른") and b6_corpus.contains("대신 묶여야"))
	_check("⑥b ★축② 기억 봉인이 **실제로 열린다**(지워진 게 아니라 가라앉혀졌다)",
		b6_corpus.contains("가라앉") and b6_corpus.contains("기억"))
	_check("⑥c ★축③ 마녀 = 연인이 **실제로 열린다**(묶는 법을 배운 내력 + 그 전의 손)",
		b6_corpus.contains("마녀") and b6_corpus.contains("손을 잡던"))
	_check("⑥d ★§6 자구의 그 한 줄이 본문에 서 있다(\"아, 당신이었군요\")",
		b6_corpus.contains("당신이었군요"))
	_check("⑥e ★B7이 종신계약의 해제를 명시한다(§6 \"종신계약 강제 해제·머무름은 선택\")",
		b7_corpus.contains("종신") and b7_corpus.contains("선택"))
	# ㉡ **씁쓸한 축복**(§6.4 A) — 다른 이와 맺어진 경로의 본문이 실존하고, §6.4 자구를 그대로 든다.
	var blessing := _joined(r2_okja.node.spine_lines("b6", true))
	_check("⑥f ★씁쓸한 축복이 별도 본문으로 서 있다(경로에 따라 톤이 갈린다 — §6.4)",
		blessing != _joined(r2_okja.node.spine_lines("b6", false)))
	_check("⑥g ★§6.4가 본문으로 못 박은 그 문장이 그대로 있다",
		blessing.contains("누구를 보고 사랑할 줄 아는") or blessing.contains("사랑할 줄 아는 사람이 됐다면"))
	_check("⑥h 축복 경로도 **진실은 똑같이 연다**(보는 것은 결혼과 독립 — §6.4 대전제)",
		blessing.contains("당신이었군요") == false and blessing != ""
		and _joined(r2_okja.node.spine_lines("b6", true)).contains("축하한다"))
	# ㉢ **평결은 여전히 0** — 진실은 열리되 판결은 없다(§2.2).
	var v6 := _scan_words(b6_corpus, VERDICT)
	var v7 := _scan_words(b7_corpus, VERDICT)
	_check("⑥i ★B6 본문에 평결 %d어가 0이다%s" % [VERDICT.size(),
		"" if v6 == "" else " · 걸린 낱말: " + v6], v6 == "")
	_check("⑥j ★B7 본문에도 0이다%s" % ("" if v7 == "" else " · 걸린 낱말: " + v7), v7 == "")
	# ㉣ **캐릭터 파일의 가드는 그대로 살아 있다** — 진실이 새어 나간 파일이 하나도 없어야 한다.
	var leak := ""
	for rid in CHAR_FILES:
		var src := _code_only("res://%s.gd" % rid)
		if src.contains("당신이었군요") or src.contains("가라앉혀") or src.contains("대신 묶여야"):
			leak = String(rid)
	_check("⑥k ★중심 진실이 캐릭터 파일 14개 어디에도 없다(B5까지의 가드 불변)%s"
		% ("" if leak == "" else " · 샌 파일: " + leak), leak == "")
	_check("⑥l ★`gangrim.gd`가 척추를 여전히 한 글자도 안 든다(⑩h 불변 — 주례도 지문이라 안 샌다)",
		not _code_only("res://gangrim.gd").contains("SPINE")
		and not _code_only("res://gangrim.gd").contains("spine"))
	_check("⑥m ★주례 전 줄이 지문이다(「」·따옴표 0 — 그는 B7에서도 말하지 않는다)",
		not _joined(Spine.B7_OFFICIANT_LINES).contains("「")
		and not _joined(Spine.B7_OFFICIANT_LINES).contains("\""))
	_check("⑥n ★`spine.gd`의 「옥자」 무호명이 유지된다(내면은 그를 \"당신\"이라 부른다)",
		not _code_only("res://spine.gd").contains("옥자"))
	_check("⑥o B5 본문은 여전히 중심 진실을 선점하지 않는다(가드의 앞쪽 절반 불변)",
		not _joined(Spine.B5_DONE_LINES).contains("당신이었군요")
		and not _joined(Spine.B5_OPEN_LINES).contains("마녀"))
	m2.free()

	cleaner.delete_save()
	cleaner.free()

	if _fail == 0:
		print("══ spine_ending_test 전체 통과 ══")
	else:
		print("══ spine_ending_test 실패 %d건 ══" % _fail)
	quit(1 if _fail > 0 else 0)


# ── 평결 18어 — 플레이어의 죄목을 **대신 명명**하는 문장(§2.2) ────────────────────
# ★ 조연 31어 중 이 18어만 B6·B7에 상속된다. 나머지 13어(그날 밤 판독 결론 5 + 중심 진실 8)는
#   **B6가 열기로 예정된 바로 그것**이라 여기서 금지하면 게임에 결말이 없다 — 그것이
#   "가드의 방향이 뒤집힌다"의 정확한 내용이다(위 ⑥a~⑥e가 반대 방향으로 잰다).
const VERDICT := [
	"네 죄는", "너의 죄는", "네가 지은 죄", "네 죄목", "그러니까 네가",
	"너 때문에 옥자", "네가 옥자를", "너는 외면했", "네가 외면한",
	"너는 잊었", "네가 잊은 죄", "네가 버린 죄", "그게 네 죄", "네가 태워 없앤",
	"네가 방치했", "네가 버려둔", "네가 지키지 않아", "네가 없었기 때문",
]
