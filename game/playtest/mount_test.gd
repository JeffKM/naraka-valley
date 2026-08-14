extends SceneTree
# ★[S10-T4 / ADR-0069 결정 6] 탈것(마구간 → 휘파람 → 먹갈기) 검증(ephemeral).
#
# 무엇을 지키나(어기면 ADR-0069 결정 6 위반):
#   ① 마구간 = **목공방 건축 원장의 세 번째 항목**(새 건축 시스템 0) · 비용·공기 잠정치
#      · 주괴 필드가 기존 3건을 한 톨도 안 건드린다(옵션 필드의 하위호환)
#   ② 휘파람 등재 — KEYS(비매·유니크·스택 불가·선물 불가)
#   ③ 승마 판정(static) — 야외만 · 실내/컷신/전투 무대(나락·나락 층) 배제
#   ④ 전이 — 소환·하차·강제 하차·속도 계수(안 타면 정확히 1.0)
#   ⑤ 세이브 왕복 — 원장 · 하위호환(키 없는 구세이브)
#   ⑥ 라이브 건축 사슬 — 주문(골드·원목·주괴 전액 지불) → 완공 아침 → **휘파람 증정**
#      · 자재 부족 시 **부분 결제 0**(아무것도 안 소모)  · 재지급 멱등
#   ⑦ 라이브 승마 — [F] 소환 → player.speed_scale 실효 → 실내 진입 자동 하차 → 재부팅 왕복
#   ⑧ ⚠️ **노동·전투 자원 아님**(CONTEXT [먹갈기]) — 소환·하차가 혼력·시간을 한 톨도 안 쓴다
# 실행: ./run_tests.sh mount   (헤드리스는 반드시 game/에서 · 순차)

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

# 그 아이템이 든 슬롯을 핫바 선택으로 만든다(플레이어가 손에 쥔 것과 같은 상태).
func _select_item(m: Node, id: String) -> bool:
	for i in m.inventory.slots.size():
		if m.inventory.id_at(i) == id:
			m.inventory.selected_index = i
			return true
	return false

func _initialize() -> void:
	print("══ S10-T4 탈것(마구간·휘파람·먹갈기) 검증 ══")
	const SAVE := "user://save.dat"
	const BAK := "user://save.dat.s10t4_mount_bak"
	var had_save := FileAccess.file_exists(SAVE)
	if had_save:
		_write_bytes(BAK, _read_bytes(SAVE))
	if FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))

	# ── ① 마구간 = 목공방 건축 원장의 세 번째 항목 ──
	print("── ① 마구간 = 건축 원장 3번째 항목 ──")
	var sid := Carpenter.PROJ_STABLE
	_check("①a 마구간이 목공방 카탈로그에 있다(새 건축 시스템 0 — 원장 항목 1건 추가)",
		Carpenter.has_project(sid) and Carpenter.ids().has(sid))
	_check("①b 카탈로그 = 3건 → 4건(성장 2 + 안방 + 마구간)", Carpenter.ids().size() == 4)
	_check("①c 비용·공기 = ADR-0069 결정 6 잠정치(10,000냥 · 원목 100 · 유철 주괴 5 · 2일)",
		Carpenter.gold_cost(sid) == 10000 and Carpenter.wood_cost(sid) == 100
		and Carpenter.ingot_cost(sid) == 5
		and Carpenter.ingot_id_of(sid) == ItemCatalog.INGOT_YUCHEOL
		and Carpenter.build_days(sid) == 2)
	_check("①d Ranch 무관(building == \"\") — 정원 승격 분기를 안 탄다",
		Carpenter.building_of(sid) == "")
	# ★ 옵션 필드의 하위호환 — 기존 3건은 주괴 요구가 0/""이라 결제·표시 경로가 불변이다.
	var legacy_clean := true
	for pid: String in [Carpenter.PROJ_BIG_COOP, Carpenter.PROJ_BIG_BARN,
			Carpenter.PROJ_MASTER_ROOM]:
		if Carpenter.ingot_cost(pid) != 0 or Carpenter.ingot_id_of(pid) != "":
			legacy_clean = false
	_check("①e 기존 3건은 주괴 요구 0(옵션 필드 — 기존 결제·매대 경로 불변)", legacy_clean)
	_check("①f 모르는 프로젝트도 안전(0/\"\" 폴백)",
		Carpenter.ingot_cost("없음") == 0 and Carpenter.ingot_id_of("없음") == "")

	# ── ② 휘파람 등재 ──
	print("── ② 먹갈기 휘파람 등재 ──")
	var wid := ItemCatalog.MOUNT_WHISTLE
	_check("②a 등재 = 유효 아이템(이름 있음)",
		ItemCatalog.has_item(wid) and ItemCatalog.name_of(wid) != "")
	_check("②b KEYS 소속 — 비매(price 0)·스택 불가(유니크)",
		ItemCatalog.KEYS.has(wid) and ItemCatalog.price_of(wid) == 0
		and not ItemCatalog.stackable_of(wid))
	_check("②c 선물 불가(GiftPrefs가 KEYS를 배제) — 실수로 건네 잃는 경로 0",
		not GiftPrefs.giftable(wid))
	_check("②d 혼백관 기증 대상 아님 — 넣고 못 찾는 봉쇄 경로 0",
		not Museum.donatable_ids().has(wid))

	# ── ③ 승마 판정(static — 원장 없이 굴린다) ──
	print("── ③ 탈 수 있는 자리(순수 판정) ──")
	_check("③a 야외 = 탈 수 있다",
		Mount.ride_allowed("", RegionCatalog.HOME, false, 0))
	_check("③b 실내 = 불가(방이 좁아 말이 설 자리가 없다)",
		not Mount.ride_allowed("집", RegionCatalog.HOME, false, 0))
	_check("③c 컷신 중 = 불가(연출은 러너 소유)",
		not Mount.ride_allowed("", RegionCatalog.HOME, true, 0))
	_check("③d 나락 = 불가(★전투 무대 — CONTEXT 「전투 자원이 아니다」)",
		not Mount.ride_allowed("", RegionCatalog.NARAK, false, 0)
		and Mount.BLOCKED_REGIONS.has(RegionCatalog.NARAK))
	_check("③e 나락 층(depth > 0) = 불가 — 지상 갱도와 갈리는 축은 구역이 아니라 깊이다",
		not Mount.ride_allowed("", RegionCatalog.EOPHWA_MINE, false, 3)
		and Mount.ride_allowed("", RegionCatalog.EOPHWA_MINE, false, 0))
	_check("③f 계수 = ADR-0069 결정 6 잠정치 ×1.5", is_equal_approx(Mount.SPEED_SCALE, 1.5))

	# ── ④ 전이 ──
	print("── ④ 소환·하차·강제 하차 ──")
	var mo := Mount.new()
	_check("④a 초기 = 안 탄 상태 · 계수 정확히 1.0(무영향)",
		not mo.is_mounted() and is_equal_approx(mo.speed_scale(), 1.0))
	_check("④b 야외 소환 성공 → 계수가 SPEED_SCALE",
		mo.mount_up("", RegionCatalog.HOME, false, 0) and mo.is_mounted()
		and is_equal_approx(mo.speed_scale(), Mount.SPEED_SCALE))
	_check("④c 이미 탄 채로 또 부르면 false(멱등 — 상태는 그대로)",
		not mo.mount_up("", RegionCatalog.HOME, false, 0) and mo.is_mounted())
	_check("④d 야외에서는 enforce가 아무 일도 안 한다",
		not mo.enforce("", RegionCatalog.HOME, false, 0) and mo.is_mounted())
	_check("④e 실내로 들어가면 enforce가 강제 하차(true = 그 프레임에만 알림)",
		mo.enforce("집", RegionCatalog.HOME, false, 0) and not mo.is_mounted())
	_check("④f 하차 뒤 enforce는 조용하다(중복 알림 0)",
		not mo.enforce("집", RegionCatalog.HOME, false, 0))
	_check("④g 실내에서는 소환 자체가 거절",
		not mo.mount_up("집", RegionCatalog.HOME, false, 0) and not mo.is_mounted())
	mo.mount_up("", RegionCatalog.HOME, false, 0)
	_check("④h 하차 → 계수 1.0 복귀 · 두 번째 하차는 false",
		mo.dismount() and is_equal_approx(mo.speed_scale(), 1.0) and not mo.dismount())

	# ── ⑤ 세이브 왕복 ──
	print("── ⑤ 세이브 왕복 ──")
	var mo2 := Mount.new()
	mo2.mount_up("", RegionCatalog.HOME, false, 0)
	var mo3 := Mount.new()
	mo3.load_save(mo2.to_save())
	_check("⑤a 왕복 — 승마 상태 보존", mo3.is_mounted())
	var mo4 := Mount.new()
	mo4.load_save({})
	_check("⑤b 하위호환 — 키 없는 구세이브 = 안 탄 상태", not mo4.is_mounted())

	# ── ⑥ 라이브 건축 사슬(main) ──
	print("── ⑥ 라이브 건축 사슬 — 주문 → 완공 → 휘파람 ──")
	var m: Node = await _spawn_main()
	_check("⑥⓪ 두 원장 배선(RefCounted)", m.mount != null and m.carpenter != null)
	m._indoor = ""
	# 자재가 하나라도 모자라면 **아무것도 안 소모한다**(부분 결제 0 — 함수 계약).
	m.wallet.gold = 999999
	m.inventory.add_item(ItemCatalog.WOOD, 100)
	var gold_before: int = m.wallet.gold
	var ordered_no_ingot: bool = m._try_order_build(sid)
	_check("⑥a 주괴 없이 주문 = 거절 · **골드도 원목도 안 줄었다**(부분 결제 0)",
		not ordered_no_ingot and m.wallet.gold == gold_before
		and m.inventory.count_of(ItemCatalog.WOOD) == 100
		and not m.carpenter.is_active())
	m.inventory.add_item(ItemCatalog.INGOT_YUCHEOL, 5)
	var ok_order: bool = m._try_order_build(sid)
	var paid_gold: int = gold_before - m.wallet.gold
	_check("⑥b 주문 성공 — 골드·원목·주괴 전액 즉시 지불",
		ok_order and m.carpenter.is_active() and m.carpenter.active_id() == sid
		and paid_gold > 0 and m.inventory.count_of(ItemCatalog.WOOD) == 0
		and m.inventory.count_of(ItemCatalog.INGOT_YUCHEOL) == 0)
	_check("⑥c 아직 휘파람 없음(완공 전에는 안 준다)",
		not m.inventory.has_item(wid))
	# 공기 2일 — 예정일 아침에 완공되고 그 자리에서 휘파람이 온다.
	var d0: int = m.clock.day
	m._on_day_advanced(d0 + 1)
	_check("⑥d 하루째 = 아직 짓는 중 · 휘파람 없음",
		m.carpenter.is_active() and not m.inventory.has_item(wid))
	m._on_day_advanced(d0 + 2)
	_check("⑥e 완공 아침 = 원장 done + **휘파람 증정**(안방 확장과 같은 자리의 id 분기)",
		m.carpenter.is_done(sid) and not m.carpenter.is_active()
		and m.inventory.has_item(wid))
	_check("⑥f Ranch 정원은 한 칸도 안 움직였다(building == \"\" — 가축 분기 무접촉)",
		m.ranch.capacity_of("넋둥우리") == Ranch.CAP_BASE)
	var whistle_ct: int = m.inventory.count_of(wid)
	m._on_day_advanced(d0 + 3)
	_check("⑥g 재지급 멱등 — 이미 들고 있으면 두 자루가 되지 않는다",
		m.inventory.count_of(wid) == whistle_ct)
	m.inventory.remove_item(wid, whistle_ct)
	m._on_day_advanced(d0 + 4)
	_check("⑥h 잃어버린 휘파람은 다음 아침이 복구한다(진행 봉쇄 0)",
		m.inventory.has_item(wid))
	# 매대 행 이름이 주괴 요구를 말한다(요구 0인 프로젝트는 문구가 불변).
	var rows: Array = m._build_rows()
	var stable_row := ""
	var room_row := ""
	for r: Dictionary in rows:
		if String(r.get("buy_id", "")) == sid:
			stable_row = String(r["name"])
		elif String(r.get("buy_id", "")) == Carpenter.PROJ_MASTER_ROOM:
			room_row = String(r["name"])
	_check("⑥i 매대 행 = 마구간만 주괴를 적는다 · 안방 확장 문구는 옛 그대로",
		stable_row.contains(ItemCatalog.name_of(ItemCatalog.INGOT_YUCHEOL))
		and room_row == "%s (원목 %d)" % [Carpenter.name_of(Carpenter.PROJ_MASTER_ROOM),
			Carpenter.wood_cost(Carpenter.PROJ_MASTER_ROOM)])

	# ── ⑦⑧ 라이브 승마 ──
	print("── ⑦⑧ 라이브 승마 — 계수 실효 · 실내 가드 · 무과금 ──")
	m._region = RegionCatalog.HOME
	m._indoor = ""
	_select_item(m, wid)
	var e0: int = m.energy.current
	var min0: float = m.clock.minutes    # ★float다 — int로 받으면 소수부가 잘려 오탐이 난다
	m._toggle_mount()
	_check("⑦a [F] 소환 — 탔다", m.mount.is_mounted())
	_check("⑧a ⚠️ 소환이 혼력·시간을 안 쓴다(노동 자원 아님 — CONTEXT [먹갈기])",
		m.energy.current == e0 and is_equal_approx(m.clock.minutes, min0))
	m._sync_mount()
	_check("⑦b 속도 계수가 플레이어에 실렸다(×%.1f)" % Mount.SPEED_SCALE,
		is_equal_approx(m.player.speed_scale, Mount.SPEED_SCALE))
	# 실내로 들어가면 그 프레임에 말없이 내린다.
	m._indoor = "집"
	m._sync_mount()
	_check("⑦c 실내 진입 = 자동 하차 · 계수 1.0 복귀",
		not m.mount.is_mounted() and is_equal_approx(m.player.speed_scale, 1.0))
	m._toggle_mount()
	_check("⑦d 실내에서 [F]를 눌러도 안 탄다(인-픽션 거절)", not m.mount.is_mounted())
	m._indoor = ""
	m._toggle_mount()
	_check("⑦e 다시 밖 = 다시 탄다", m.mount.is_mounted())
	m._toggle_mount()
	_check("⑦f 두 번째 [F] = 내린다(같은 키 토글)", not m.mount.is_mounted())
	# 전투 무대 가드(라이브) — 나락 층으로 옮기면 강제 하차.
	m._toggle_mount()
	m._region = RegionCatalog.NARAK
	m._sync_mount()
	_check("⑦g 나락으로 옮기면 강제 하차(전투 무대 배제)", not m.mount.is_mounted())
	m._region = RegionCatalog.HOME
	# 재부팅 왕복 — 승마 상태가 세이브를 타고 살아 돌아온다.
	m._toggle_mount()
	var live_mounted: bool = m.mount.is_mounted()
	m._save_game()
	await _despawn(m)
	var m2: Node = await _spawn_main()
	_check("⑦h 재부팅 후 승마 상태 복원",
		m2.mount.is_mounted() == live_mounted and live_mounted)
	_check("⑦i 재부팅 후에도 휘파람은 인벤에 있다(KEYS 직렬화 정합)",
		m2.inventory.has_item(wid))
	await _despawn(m2)

	if had_save:
		_write_bytes(SAVE, _read_bytes(BAK))
		DirAccess.remove_absolute(ProjectSettings.globalize_path(BAK))
	elif FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))

	print("══ 결과: %s ══" % ("PASS (실패 0)" if _fail == 0 else "FAIL (실패 %d)" % _fail))
	quit(1 if _fail > 0 else 0)
