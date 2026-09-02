extends SceneTree
# ★[폴리시 12회차] 버그 헌트 확정분 회귀 — 배치 A(#1~#11).
#
# 렌즈: R11 diff 리뷰 · 다중 슬롯 교차 · 트윈/타이머 생애주기 · 프레임 순서.
#
# 무엇을 보증하나(번호 = 12회차 헌트 배치 A 발견 번호):
#   ① #1  (high) R11이 세운 원자적 세이브가 **쓰기의 성패를 한 번도 안 물었다** — `store_string`·
#         `close`는 값을 안 돌려주고 `get_error()`는 어디서도 안 읽혀, 디스크가 차면 잘린 tmp가
#         rename으로 멀쩡한 슬롯을 덮고 `return true`가 났다(계약의 정반대 + 거짓 성공 보고).
#   ② #2(=#4·#10) 미뤄 둔 카페 마감 정산·마일스톤 팝업 타이머가 **취침과 F9를 넘어 살아남아**,
#         어제 밤(또는 폐기된 타임라인)의 장부가 새 아침 화면 위에 떴다. R11은 화면을 갈아엎는 세
#         경로 중 `_open_epilogue`·`_end_run` 둘에만 버리는 줄을 넣었다.
#   ③ #3  저장 실패 [종료] 2단 확인 래치가 **세우기만 하고 해제되지 않아**, 한 세션에 실패
#         에피소드가 둘이면 두 번째 [종료]가 경고 없이 나갔다(그 사이 진행이 조용히 사라진다).
#   ④ #5  점괘 거울은 **열 때 한 번만** 그날 예보를 스냅샷하는데 F9 로드가 다시 파생하지 않아,
#         20일차 운·'내일 날씨'가 3일차를 복원한 화면에 남고 프롬프트는 '덮기'라 최신인 척했다.
#   ⑤ #6  음소거 중 phase가 바뀌면 새 곡의 **페이드인 트윈이 아예 안 생겨**, 음소거를 풀어도
#         다음 전환까지 완전 무음이었다(`set_muted`는 버스만 건드리고 플레이어 볼륨은 안 본다).
#   ⑥ #7  `_close_spine_scene`이 `_sleeping`을 안 봐, R10 #6이 `_on_dialogue_finished`에서 세운
#         "취침 트윈 중엔 잠금을 안 푼다"를 그 아래 줄이 무조건 되뚫었다(암전 뒤 자유 이동).
#   ⑦ #8  `_on_sleep_done`의 해제 목록에 `_epilogue_open`·`spine_puzzle`이 빠져, 엔딩 화면이 떠
#         있는 채로 캐릭터가 패널 뒤 월드를 돌아다녔다(main엔 다시 잠글 경로가 없다).
#   ⑧ #9  `_open_epilogue`가 **취침 트윈이 일시적으로 멈춰 둔** 시계를 스냅해, 엔딩을 닫은 뒤
#         시간이 영구 정지했다(분 틱·NPC 스케줄·영업창·날씨 phase 전부 — 복구는 취침뿐).
#   ⑨ #11(=#17) 늘봄방 완공 아침이 같은 프레임에 HOME 그리드를 **두 번** 구웠다 — R11이 로드
#         경로만 접어 기본 인자 호출부에 그대로 남은 이중 굽기(실측 재빌드 1회 ≈ 2.5s가 취침
#         페이드 한가운데서 순수 낭비).
#
# 판정: ①~⑨ 전부 CONFIRMED. #4·#10은 #2와 같은 가족(같은 다섯 조각·같은 두 갈래)이라 캐노니컬
#       한 자리(`_drop_cafe_popups`)에서 함께 봉합하고 ②가 두 갈래를 모두 잰다. #17은 #11과
#       같은 결함의 두 줄(5427·5430)을 각각 가리킨 것이라 ⑨ 한 수정이 둘을 덮는다.
#
# ── 배치 B(#12~#22) ─────────────────────────────────────────────────────────
# 렌즈: 인벤 만재 계약 · 완주 후 안내 · 매 프레임 IO · 이중 굽기 · 추종자 원장.
#   ⑩ #12 개간(`reclaim.clear`)이 만재에서 칸을 영구히 굳히고 드랍을 증발시킨 채 "+N"을 알렸다 —
#         형제 창구 여섯이 지키는 「적재先」 계약의 마지막 미커버 창구(재점령 잡초 낫질도 같은 줄).
#   ⑪ #14 잡초 혼합 씨앗 롤이 `add_seed`의 bool(R2가 일부러 만든 반환)을 안 봐 거짓 획득을 알렸다.
#   ⑫ #13 야시장 씨앗·보부상 씨앗·보부상 일반 셋이 만재를 "골드 부족"으로 오보했다(두 사유를
#         한 조건에 뭉친 형태 — 형제 창구 셋은 진작 삼항으로 가르고 있었다).
#   ⑬ R5 ④i 정정 — R10이 새로 쓴 "버릴 수 없다" 안내에 고정 조사 "는"이 다시 들어와 전수 스캔이
#         baseline부터 실패 중이었다(도구 이름은 받침이 갈린다).
#   ⑭ #15 혼백관 기증대만 완주 분기가 없어, "전시 11/11"과 "들고 오자"가 한 줄에 나란히 섰다.
#   ⑮ #16 ♡MAX 뒤 선물이 실효 0인데 명목 점수를 알리고 주 2회 카운터까지 먹었다(ADR-0008 —
#         게이트를 만들지 않고 정보·소비 계약만 갈랐다).
#   ⑯ #18·#19 매대 아이콘 훅 둘이 캐시 없이 매 프레임 `ResourceLoader.exists` + `load`를 때렸다.
#   ⑰ #20 절기 첫날 밤 층 안 강제 취침이 같은 프레임에 같은 구역을 두 번 구웠다(1차 결과는 2차가
#         캐시를 비우며 통째로 버린다 — 순수 낭비).
#   ⑱ #21 방목 슬롯 선정이 설치물·프롭·[F] 창구를 안 봐 짐승이 업화로 위에 스폰되고, 그 칸 안내가
#         `has_animal_at` 갈래에서 끊겨 통째로 사라졌다(반대 방향 가드도 비어 있었다).
#   ⑲ #22 삽사리·승마만 `data.has()` 가드로 복원해, 키 없는 구세이브를 F9로 부르면 살아 있는
#         추종자 노드가 롤백되지 않았다(같은 함수의 R3 주석이 이미 금지한 형태).
#
# 판정: ⑩~⑲ 전부 CONFIRMED. #17은 배치 A #11의 DUP(6f67603이 이미 봉합 — 잔여 갈래 없음)이라
#       배치 B에 수정이 없다. #20은 같은 "이중 굽기" 계열이지만 **다른 경로**라 독립 봉합했다.

var _fail := 0
var _src: PackedStringArray = PackedStringArray()

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

func _dismiss_dialogue(m: Node) -> void:
	var guard := 0
	while m.dialogue.is_open() and guard < 60:
		m.dialogue.advance()
		guard += 1

# main.gd 소스에서 needle이 든 줄의 인덱스(-1 = 없음) — polish_r7~r11의 그 헬퍼.
func _line_of(needle: String) -> int:
	return _line_after(0, needle)

# start 이후 첫 매치 — 같은 니들이 여러 함수에 흩어져 있을 때 계약이 사는 함수 안에서 잰다.
func _line_after(start: int, needle: String) -> int:
	for i in range(maxi(start, 0), _src.size()):
		if _src[i].contains(needle):
			return i
	return -1

func _in_func(fn_needle: String, needle: String) -> bool:
	var head := _line_of(fn_needle)
	if head < 0:
		return false
	for i in range(head + 1, _src.size()):
		if _src[i].begins_with("func "):
			return false
		if _src[i].contains(needle):
			return true
	return false

# 다른 파일 소스의 줄 배열(save.gd·audio.gd — main.gd는 _src가 든다).
func _lines_of_file(path: String) -> PackedStringArray:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return PackedStringArray()
	return f.get_as_text().split("\n")

func _index_in(lines: PackedStringArray, needle: String) -> int:
	for i in lines.size():
		if lines[i].contains(needle):
			return i
	return -1

func _wipe_slot(slot: int) -> void:
	var p := SaveManager.slot_path(slot)
	if FileAccess.file_exists(p):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	var t := p + SaveManager.TMP_SUFFIX
	if FileAccess.file_exists(t):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(t))

# ── 배치 B 공용 헬퍼 ─────────────────────────────────────────────────────────
# 마지막 알림 줄(notice_feed는 최신이 배열 끝) — polish_r9의 그 헬퍼.
func _last_notice(m: Node) -> String:
	var items: Array = m.notice_feed._items
	return "" if items.is_empty() else String(items[items.size() - 1]["text"])

func _slot_of(inv: Object, id: String) -> int:
	for i in range(inv.slots.size()):
		if inv.id_at(i) == id:
			return i
	return -1

func _select(m: Node, id: String) -> void:
	m.inventory.add_item(id, 1)   # 유니크 도구는 이미 있으면 무시(멱등)
	m.inventory.select(_slot_of(m.inventory, id))

# ★[폴리시 R2 공용 · garden_pot_test에서 인용] 백팩을 **빈 슬롯 0**으로 채운다. 슬롯에 직접 쓴다:
#   `add_item`으로 채우면 같은 (id,품질)이 스택으로 합쳐져 칸이 안 준다. keep에 든 인덱스는 비워 둔다.
func _fill_backpack_full(inv: Object, keep: Array = []) -> void:
	var pool: Array = Museum.donatable_ids()
	for i in range(inv.slots.size()):
		if keep.has(i):
			inv.slots[i] = null
			continue
		inv.slots[i] = {"id": String(pool[i]), "count": 1, "quality": 0} if i < pool.size() \
			else {"id": ItemCatalog.harvest_id(CropCatalog.PIANHWA), "count": 1,
				"quality": (i - pool.size()) % 4}
	inv.changed.emit()


func _initialize() -> void:
	print("══ 폴리시 12회차 — R11 diff · 다중 슬롯 교차 · 트윈/타이머 생애주기 · 프레임 순서(배치 A) ══")
	_src = FileAccess.open("res://main.gd", FileAccess.READ).get_as_text().split("\n")
	for s in SaveManager.SLOT_COUNT:
		_wipe_slot(s)

	_check_save_atomicity()
	await _check_audio_mute_phase()

	var m := await _spawn_main()
	_dismiss_dialogue(m)
	m._region = RegionCatalog.HOME
	m._rebuild_region(RegionCatalog.HOME)

	await _check_cafe_popups(m)
	_check_quit_latch(m)
	_check_sleep_locks(m)
	_check_epilogue_clock(m)
	_check_greenhouse_rebuild(m)

	# ── 배치 B(#12~#22) ──
	print("══ 배치 B — 인벤 만재 계약 · 완주 후 안내 · 매 프레임 IO · 이중 굽기 · 추종자 ══")
	await _check_reclaim_full_backpack(m)
	_check_mixed_seed_full(m)
	_check_retail_full_reason(m)
	_check_fixed_josa()
	_check_museum_complete(m)
	_check_gift_maxed(m)
	_check_icon_cache(m)
	_check_floor_exit_rebuild()
	_check_season_terrain_fold(m)
	_check_pasture_slots(m)
	_check_follower_rollback(m)

	print("── 결과: %s (실패 %d) ──" % ["PASS" if _fail == 0 else "FAIL", _fail])
	quit(1 if _fail > 0 else 0)


# ── ① #1 원자적 세이브가 쓰기의 성패를 묻는다 ────────────────────────────────
# 잘린 쓰기 자체는 헤드리스에서 유도할 수 없다(디스크를 채워야 한다). 그래서 재는 것은 **계약의
# 형태**다: ㉠검사가 rename보다 앞에 있고 ㉡실패 갈래가 tmp를 지우고 false를 돌리며 ㉢그 false를
# 보고 층 둘이 실제로 읽는다. 정상 경로는 종전 그대로 왕복하고 tmp를 남기지 않는다.
func _check_save_atomicity() -> void:
	print("── ① #1 원자적 세이브 — 쓰기가 실패하면 슬롯도 보고도 그것을 안다 ──")
	var sv := _lines_of_file("res://save.gd")
	var store_i := _index_in(sv, "f.store_string(var_to_str(wrapped))")
	var err_i := _index_in(sv, "var werr := f.get_error()")
	var rename_i := _index_in(sv, "DirAccess.rename_absolute(")
	_check("①a 쓰기 뒤 `get_error()`를 실제로 읽는다(save.gd:%d — 종전엔 저장소 어디에도 없던 호출)"
			% (err_i + 1),
		err_i > 0 and store_i > 0 and err_i > store_i)
	_check("①b 그 검사가 **rename보다 앞**이다(save.gd:%d < %d) — 잘린 tmp가 슬롯을 덮기 전에 멈춘다"
			% [err_i + 1, rename_i + 1],
		rename_i > 0 and err_i < rename_i)
	_check("①c 실패 갈래는 버퍼를 먼저 내려보낸다(`flush` — 잘림이 close 시점에야 드러나는 경우)",
		_index_in(sv, "f.flush()") > store_i and _index_in(sv, "f.flush()") < err_i)
	# 실패 갈래의 구성: 경고 + tmp 삭제 + false. 셋이 다 있어야 "슬롯은 직전 세이브 그대로"가 참이다.
	var branch := ""
	for i in range(err_i, mini(err_i + 6, sv.size())):
		branch += sv[i]
	_check("①d 실패 갈래가 셋을 다 한다 — 경고·tmp 삭제·false 반환(하나라도 빠지면 계약이 깨진다)",
		branch.contains("if werr != OK:") and branch.contains("push_warning(")
		and branch.contains("DirAccess.remove_absolute(") and branch.contains("return false"))
	# 보고 층 — false가 위로 올라가는 두 자리(옵션 탭 [저장] 문구 · [종료] 2단 확인).
	_check("①e `_save_game`이 그 false를 그대로 올린다(성공 문구는 그 뒤에만 뜬다)",
		_in_func("func _save_game", "if not saver.save_game(data, _active_slot")
		and _in_func("func _save_game", "_notice(\"저장됨\")"))
	_check("①f [종료] 2단 확인이 그 false를 읽는다(`not _save_game()` — 그래야 래치가 무장한다)",
		_in_func("func _on_frame_quit", "if not _save_game() and not _quit_unsaved_armed:"))

	# 정상 경로 회귀 — 계약을 세우면서 평범한 저장을 깨지 않았는가.
	var saver := SaveManager.new()
	root.add_child(saver)
	var slot: int = SaveManager.SLOT_COUNT - 1
	_wipe_slot(slot)
	var payload := {"day": 41, "note": "R12"}
	var ok := saver.save_game(payload, slot, {"day": 41})
	_check("①g 정상 저장은 여전히 true이고 그대로 읽힌다(day=41 · meta.day=41)",
		ok and saver.load_game(slot).get("day", 0) == 41
		and int(saver.slot_meta(slot).get("day", 0)) == 41)
	_check("①h 성공 뒤 임시본이 안 남는다(`%s` 없음 — rename이 자리를 옮겼다)" % SaveManager.TMP_SUFFIX,
		not FileAccess.file_exists(SaveManager.slot_path(slot) + SaveManager.TMP_SUFFIX))
	saver.free()
	_wipe_slot(slot)


# ── ⑤ #6 음소거 중 phase 전환이 페이드인을 건너뛰지 않는다 ───────────────────
# 결함의 형태가 "트윈이 **아예 안 생긴다**"라 그 자리를 직접 잰다. 종전엔 `if not _muted:`가
# incoming 페이드를 통째로 건너뛰어 새 곡이 SILENT_DB에 박혔고, `set_muted(false)`는 버스만
# 열어 다음 phase 전환까지 무음이었다.
func _check_audio_mute_phase() -> void:
	print("── ⑤ #6 음소거 중 곡이 바뀌어도 볼륨은 서 있다(버스만 닫혀 있을 뿐) ──")
	var au := _lines_of_file("res://audio.gd")
	_check("⑤a `set_phase`에서 페이드인의 음소거 게이트가 사라졌다(소스 — 코드 줄 `if not _muted:` 0회)",
		_index_in(au, "\tif not _muted:") < 0)
	_check("⑤b 음소거의 주인은 여전히 버스 하나다(`set_muted`는 플레이어 볼륨을 안 건드린다)",
		_index_in(au, "AudioServer.set_bus_mute") > 0)

	var A := GameAudio.new()
	get_root().add_child(A)
	await process_frame
	A.update_music(12 * 60, false, false)          # 낮(farm)으로 한 곡 깔고
	await process_frame
	A.set_muted(true)                              # M으로 음소거 — 버스만 닫힌다
	A.set_phase(GameAudio.PHASE_NIGHT)             # 19:00 경계를 넘어 밤으로 전환
	var incoming: AudioStreamPlayer = A._music_a if A._music_on_a else A._music_b
	var tw: Tween = A._music_tweens.get(incoming.get_instance_id())
	_check("⑤c 음소거 중 전환에도 새 곡에 페이드인 트윈이 걸린다(종전엔 이 트윈이 아예 없었다)",
		tw != null and tw.is_valid())
	_check("⑤d 그 곡이 실제로 밤 테마다(엉뚱한 플레이어를 재고 있지 않다)",
		incoming.stream != null and incoming.stream.resource_path.get_file().begins_with("bgm_night"))
	if tw != null and tw.is_valid():
		tw.pause()
		tw.custom_step(GameAudio.CROSSFADE_SECS + 0.1)
	_check("⑤e 페이드가 끝나면 볼륨이 FULL_DB다(%.1f) — 해제하는 순간 소리가 돌아온다"
			% GameAudio.FULL_DB,
		is_equal_approx(incoming.volume_db, GameAudio.FULL_DB))
	A.set_muted(false)
	_check("⑤f 해제는 버스만 연다 — 볼륨은 이미 서 있어 다음 전환을 기다리지 않는다",
		not AudioServer.is_bus_mute(AudioServer.get_bus_index(GameAudio.MUSIC_BUS))
		and is_equal_approx(incoming.volume_db, GameAudio.FULL_DB))
	A.set_muted(false)
	A.free()


# ── ② #2(=#4·#10) 카페 팝업 셋이 취침·F9를 못 넘는다 ─────────────────────────
func _check_cafe_popups(m: Node) -> void:
	print("── ② #2(=#4·#10) 미뤄 둔 마감 정산이 새 아침·복원된 아침 위로 뜨지 않는다 ──")
	# 먼저 이 결함이 왜 성립했는지를 소스로 못 박는다 — 두 타이머 틱에 `_sleeping` 가드가 없어
	# 1.1초 암전 트윈 동안에도 계속 깎이고, F9 폴링은 팝업이 모달이 아니라 그대로 도달한다.
	var tick_i := _line_of("\tif _milestone_popup_secs > 0.0:")
	var tick_block := ""
	for i in range(tick_i, mini(tick_i + 9, _src.size())):
		tick_block += _src[i]
	_check("②a-pre 무대: 마일스톤 타이머 틱에는 `_sleeping` 가드가 없다(main.gd:%d — 취침 갈래의 뿌리)"
			% (tick_i + 1),
		tick_i > 0 and not tick_block.contains("_sleeping")
		and tick_block.contains("_show_cafe_summary(pending)"))
	_check("②a2-pre 무대: F9 폴링은 팝업 가시성을 안 본다(로드 갈래의 뿌리 — 두 팝업은 모달이 아니다)",
		_in_func("func _process", "Input.is_action_just_pressed(\"load_game\")"))

	# 다섯 조각을 전부 세운다(미룬 본문 + 두 타이머 + 두 패널).
	var pending_text := "매출  1234냥\n서빙한 손님  7명"
	m._cafe_summary_pending = pending_text
	m._cafe_summary_secs = m.CAFE_SUMMARY_SECS
	m._milestone_popup_secs = m.MILESTONE_POPUP_SECS
	m.cafe_summary_panel.visible = true
	m.milestone_panel.visible = true
	_check("②b-pre 무대: 다섯 조각이 실제로 서 있다(미룬 본문·정산 타이머·팝업 타이머·패널 둘)",
		m._cafe_summary_pending == pending_text and m._cafe_summary_secs > 0.0
		and m._milestone_popup_secs > 0.0
		and m.cafe_summary_panel.visible and m.milestone_panel.visible)

	# ㉠취침 갈래 — 한 자리(`_drop_cafe_popups`)가 다섯을 다 버린다.
	m._drop_cafe_popups()
	_check("②c 버리는 자리가 다섯을 **전부** 비운다 — 본문 \"\" · 타이머 둘 0 · 패널 둘 숨김",
		m._cafe_summary_pending == "" and m._cafe_summary_secs == 0.0
		and m._milestone_popup_secs == 0.0
		and not m.cafe_summary_panel.visible and not m.milestone_panel.visible)
	_check("②d 취침이 그 자리를 부른다(세션 셋 폐기와 같은 줄 — `_do_sleep`)",
		_in_func("func _do_sleep", "_drop_cafe_popups()"))
	_check("②e 로드도 같은 자리를 부른다(밤 바 폐기와 같은 줄 — `_load_game`)",
		_in_func("func _load_game", "_drop_cafe_popups()"))
	_check("②f 형제 두 경로는 종전대로 미룬 본문을 버린다(계약의 출처 — 화면을 갈아엎는 세 경로)",
		_in_func("func _open_epilogue", "_cafe_summary_pending = \"\"")
		and _in_func("func _end_run", "_cafe_summary_pending = \"\""))

	# ㉡F9 갈래 — 실제 로드 왕복으로 잰다(소스가 아니라 거동으로).
	m._save_game()
	m._cafe_summary_pending = pending_text
	m._cafe_summary_secs = m.CAFE_SUMMARY_SECS
	m._milestone_popup_secs = m.MILESTONE_POPUP_SECS
	m.cafe_summary_panel.visible = true
	m.milestone_panel.visible = true
	# ④ #5 — 같은 로드가 점괘 거울 스냅샷도 덮는지 함께 잰다(둘 다 "로드가 안 되감던 조회 패널").
	m._open_mirror()
	var mirror_before: String = m.mirror_text.text
	_check("④a-pre 무대: 거울이 열렸고 본문이 그날 예보로 채워졌다(빈 문자열이 아니다)",
		m.mirror_panel.visible and mirror_before != "")
	var loaded: bool = m._load_game()
	await process_frame
	_check("②g-pre 무대: 로드가 실제로 성공했다(공회전 단언 방지)", loaded)
	_check("②g F9 뒤 다섯 조각이 전부 비었다 — 폐기된 타임라인의 장부가 복원된 아침에 안 뜬다",
		m._cafe_summary_pending == "" and m._cafe_summary_secs == 0.0
		and m._milestone_popup_secs == 0.0
		and not m.cafe_summary_panel.visible and not m.milestone_panel.visible)
	_check("④b F9 뒤 점괘 거울이 덮인다 — 로드 전 날짜의 운·'내일 날씨'가 화면에 안 남는다",
		not m.mirror_panel.visible)
	_check("④c 자동 접기는 여전히 자리 조건뿐이다(집 안에서 찍은 세이브엔 안 걸린다 — 로드가 필요한 이유)",
		_in_func("func _process", "if mirror_panel.visible and (_indoor != \"집\" or _sleeping):"))
	_check("④d 대조: 같은 조회 패널인 달력은 매 프레임 값을 다시 흘려넣어 이 문제가 없다",
		_line_of("calendar_panel.set_state(clock.day, _cafe_stage(), _cafe_revenue_total)") > 0)


# ── ③ #3 [종료] 2단 확인 래치가 저장 성공에 풀린다 ───────────────────────────
func _check_quit_latch(m: Node) -> void:
	print("── ③ #3 저장이 성공하면 [종료] 경고 래치가 다시 선다 ──")
	m._quit_unsaved_armed = true
	var ok: bool = m._save_game()
	_check("③a-pre 무대: 이 환경에서 저장은 실제로 성공한다(공회전 단언 방지)", ok)
	_check("③b 성공한 저장이 래치를 푼다 — 선언부 머리말의 논증이 비로소 참이 된다",
		not m._quit_unsaved_armed)
	_check("③c 해제가 **성공 갈래 안**에 있다(실패하면 여전히 무장한 채다 — 실패 시 return false가 먼저)",
		_in_func("func _save_game", "_quit_unsaved_armed = false")
		and _line_after(_line_of("func _save_game"), "if not saver.save_game(data, _active_slot")
			< _line_after(_line_of("func _save_game"), "_quit_unsaved_armed = false"))
	_check("③d 형제 둘도 각자 해제 경로를 갖는다(F8 = 시간 만료 · 이혼 [F] 2타 = 시선을 떼면 접힘)",
		_in_func("func _process", "_delete_armed_secs -= delta")
		and _in_func("func _process", "_divorce_armed = false"))


# ── ⑥ #7 · ⑦ #8 취침 트윈 뒤에서 잠금이 안 풀린다 ────────────────────────────
func _check_sleep_locks(m: Node) -> void:
	print("── ⑥ #7 척추 장면 종료가 취침 암전 뒤에서 이동을 안 푼다 ──")
	m._run_over = false
	m._epilogue_open = false
	m._sleeping = true
	m.player.set_physics_process(false)
	m._close_spine_scene()
	_check("⑥a 취침 중이면 `_close_spine_scene`이 물리를 안 켠다(R10 #6 불변식을 안 되뚫는다)",
		not m.player.is_physics_processing())
	m._sleeping = false
	m._close_spine_scene()
	_check("⑥b 대조: 깨어 있으면 종전대로 켠다 — 가드가 잠금을 통째로 죽인 게 아니다",
		m.player.is_physics_processing())
	_check("⑥c 조건 네 항이 다 있다(`_run_over`·`_epilogue_open`·`spine_puzzle`·`_sleeping`)",
		_in_func("func _close_spine_scene",
			"if not _run_over and not _epilogue_open and spine_puzzle == null and not _sleeping:"))

	print("── ⑦ #8 눈뜨는 프레임이 엔딩 화면·내면 공간 뒤에서 이동을 안 푼다 ──")
	m._epilogue_open = true
	m.player.set_physics_process(false)
	m._on_sleep_done()
	_check("⑦a 엔딩 화면이 떠 있으면 `_on_sleep_done`이 물리를 안 켠다(회고 뒤 자유 이동 0)",
		not m.player.is_physics_processing())
	m._epilogue_open = false
	m.player.set_physics_process(false)
	m._on_sleep_done()
	_check("⑦b 대조: 화면이 없으면 종전대로 켠다(평범한 아침이 잠긴 채로 시작하지 않는다)",
		m.player.is_physics_processing())
	_check("⑦c 목록에 내면 공간(`spine_puzzle`)도 함께 들었다 — 걸어 다니는 곳이 아니다",
		_in_func("func _on_sleep_done", "and not _epilogue_open and spine_puzzle == null:"))
	_check("⑦d 다시 켜는 자리는 두 화면이 닫히는 그곳이다(`_close_epilogue`·`_close_spine_scene`)",
		_in_func("func _close_epilogue", "player.set_physics_process(true)")
		and _in_func("func _close_spine_scene", "player.set_physics_process(true)"))


# ── ⑧ #9 엔딩이 취침으로 멈춘 시계를 스냅하지 않는다 ─────────────────────────
func _check_epilogue_clock(m: Node) -> void:
	print("── ⑧ #9 엔딩을 닫은 뒤 시간이 다시 흐른다 ──")
	m._run_over = false
	m._epilogue_open = false
	# 취침 트윈의 첫 0.4초 구간 재현 — `_do_sleep`이 running=false를 세웠고 `clock.sleep`은 아직이다.
	m._sleeping = true
	m.clock.running = false
	m._open_epilogue()
	_check("⑧a 취침 중 스냅은 true다 — 기억할 값은 '연출이 끝나면 시계가 어떤 상태여야 하는가'다",
		m._epilogue_clock_prev == true)
	m._close_epilogue()
	m._sleeping = false
	_check("⑧b 그래서 엔딩을 닫으면 시간이 다시 흐른다(종전엔 여기서 영구 정지했다)",
		m.clock.running == true)
	# 대조 — 취침이 아닌 이유로 멈춰 있던 시계는 여전히 되살리지 않는다(컷신의 그 규율 보존).
	m._epilogue_open = false
	m.clock.running = false
	m._open_epilogue()
	_check("⑧c 대조: 취침이 아니면 종전대로 멈춘 상태를 그대로 뜬다(컷신 규율은 안 넓어졌다)",
		m._epilogue_clock_prev == false)
	m._close_epilogue()
	_check("⑧d 그때는 닫아도 멈춘 채다 — 이 수정이 시계를 무조건 켜는 것이 아니다",
		m.clock.running == false)
	m.clock.running = true


# ── ⑨ #11(=#17) 늘봄방 완공 아침의 HOME 이중 굽기 ────────────────────────────
# 재빌드는 `_rebuild_region` 끝의 Y-split 캐시 무효화(`_last_player_tile_y = -9999`)를 남기므로,
# 그 표식으로 "이 호출이 실제로 구웠는가"를 잰다(polish_r11 ㉓의 그 기법).
func _check_greenhouse_rebuild(m: Node) -> void:
	print("── ⑨ #11(=#17) 완공 아침이 같은 HOME 그리드를 두 번 굽지 않는다 ──")
	_check("⑨a `_refresh_greenhouse`가 안쪽 호출에 **언제나 false**를 넘긴다(굽기는 자기 세 줄이 한다)",
		_in_func("func _refresh_greenhouse", "_refresh_home_expansion(false)")
		and not _in_func("func _refresh_greenhouse", "_refresh_home_expansion(rebuild)"))
	_check("⑨b 두 함수 모두 굽기를 `rebuild` 게이트 뒤에 둔다(인자가 실제로 굽기를 가른다)",
		_in_func("func _refresh_greenhouse", "if rebuild:")
		and _in_func("func _refresh_home_expansion", "if rebuild:"))

	m._region = RegionCatalog.HOME
	m._indoor = ""
	# 안쪽 호출과 **같은 인자**로 불렀을 때 스스로는 안 굽는다(그래서 이중이 사라진다).
	m._last_player_tile_y = 12345
	m._refresh_home_expansion(false)
	_check("⑨c `false`로 부른 안방 확장은 무대를 안 굽는다(Y-split 표식 12345가 그대로)",
		m._last_player_tile_y == 12345)
	_check("⑨d 그래도 집 카메라 둘레는 다시 주입된다(`false`가 접는 것은 굽기뿐)",
		m._buildings["집"]["cam"] == m.home_house_cam_rect())

	# 완공 아침 경로 회귀 — 늘봄방을 원장에 박고 기본 인자로 부른다(그 아침이 하는 그 일 그대로).
	m.carpenter.load_save({"active": [], "done": [Carpenter.PROJ_GREENHOUSE]})
	_check("⑨e-pre 무대: 늘봄방이 완공으로 섰다(안 그러면 `_refresh_greenhouse`가 첫 줄에서 반환)",
		m._greenhouse_built())
	m._last_player_tile_y = 12345
	m._refresh_greenhouse()
	_check("⑨f 완공 아침은 여전히 HOME을 세운다 — 굽기를 통째로 죽인 게 아니다(표식 무효화됨)",
		m._last_player_tile_y == -9999)
	_check("⑨g 그리고 늘봄방이 실제로 카탈로그에 섰다(구운 결과가 화면 원장에 반영됐다)",
		m._buildings.has("늘봄방"))


# ══ 배치 B(#12~#22) ══════════════════════════════════════════════════════════

# 인벤을 통째로 비운다(창구별 무대가 서로를 안 오염시키게 — 만재 셋업이 여럿 이어진다).
func _clear_inventory(inv: Object) -> void:
	for i in range(inv.slots.size()):
		inv.slots[i] = null
	inv.changed.emit()

# 그리드에서 그 종류의 debris가 선 첫 칸(하드코딩 좌표 대신 지금 무대에서 찾는다 — 레이아웃이
# 바뀌어도 니들이 안 낡는다). 없으면 (-1,-1).
func _debris_tile_of(m: Node, kind: String) -> Vector2i:
	for y in range(m._grid.size()):
		for x in range(m._grid[y].size()):
			var t := Vector2i(x, y)
			if m._debris_kind_at(t) == kind:
				return t
	return Vector2i(-1, -1)


# ── ⑩ #12 개간이 만재에서 칸을 굳히고 드랍을 증발시키지 않는다 ────────────────
# `reclaim.clear`는 `_cleared[t] = true`로 그 칸을 영구히 개간 완료로 굳히는 **비가역·멱등** 동사인데
# `add_item`의 반환을 안 봐서, 백팩이 가득하면 드랍이 어디에도 안 들어가고 바로 다음 줄의 토스트가
# 조건 없이 "+N"을 알렸다 — 화면은 받았다 하고 원장엔 없으며 그 그루터기는 다시 못 친다.
func _check_reclaim_full_backpack(m: Node) -> void:
	print("── ⑩ #12 만재에서 개간이 칸을 굳히지 않는다(적재 선검사) ──")
	m._region = RegionCatalog.HOME
	m._rebuild_region(RegionCatalog.HOME)
	var kind := DebrisCatalog.EMBER
	var t := _debris_tile_of(m, kind)
	var drop_id: String = DebrisCatalog.drop_for(kind)
	var drop_n: int = DebrisCatalog.drop_count(kind)
	var tool_id: String = DebrisCatalog.tool_for(kind)
	_check("⑩a-pre 무대: %s이 선 칸 %s · 도구 %s · 드랍 %s ×%d(전부 카탈로그 파생)"
			% [kind, str(t), tool_id, drop_id, drop_n],
		t != Vector2i(-1, -1) and drop_id != "" and drop_n > 0)
	if t == Vector2i(-1, -1):
		return

	# 만재 셋업 — 슬롯 0만 남겨 도구를 꽂고, 나머지 15칸을 서로 다른 종으로 채운다.
	_fill_backpack_full(m.inventory, [0])
	m.inventory.slots[0] = {"id": tool_id, "count": 1, "quality": 0}
	m.inventory.select(0)
	m.energy.refill()
	var e_before: int = m.energy.current
	_check("⑩b-pre 무대: 든 것이 맞는 도구이고 그 드랍은 들어갈 자리가 없다",
		m.inventory.selected_id() == tool_id and not m.inventory.can_add(drop_id, drop_n))

	m._target = t
	m._use_tool()
	_check("⑩c 그 칸이 개간 완료로 굳지 않았다 — 다시 칠 수 있다(멱등 가드가 영구히 삼키지 않는다)",
		not m.reclaim.is_cleared(t) and m._debris_kind_at(t) == kind)
	_check("⑩d 드랍도 안 생겼고 혼력도 안 나갔다(무동작 — 화면만 받은 척하지 않는다)",
		m.inventory.count_of(drop_id) == 0 and m.energy.current == e_before)
	_check("⑩e 이유를 말한다 — '%s'" % _last_notice(m),
		_last_notice(m).contains("백팩이 가득"))

	# 자리를 비우면 **그 자리에서** 성사된다(가드가 칸을 영구히 죽인 게 아니다).
	m.inventory.slots[m.inventory.slots.size() - 1] = null
	m.inventory.changed.emit()
	m._target = t
	m._use_tool()
	_check("⑩f 한 칸을 비우자 같은 칸이 개간되고 드랍 %d개가 실제로 들어온다" % drop_n,
		m.reclaim.is_cleared(t) and m.inventory.count_of(drop_id) == drop_n)
	await process_frame


# ── ⑪ #14 잡초 혼합 씨앗 롤이 만재에서 획득을 거짓 보고하지 않는다 ────────────
# `add_seed`는 R2에서 일부러 bool을 돌려주게 바뀌었는데(inventory.gd 머리말) 이 호출부만 안 봤다.
# 롤 시드는 (날·칸) 결정적이라 같은 무대에서 두 번 굴려도 결과가 같다 — 그래서 "가득일 때"와
# "한 칸 비웠을 때"를 **같은 칸·같은 날**로 비교할 수 있다(무작위가 아니라 계약을 잰다).
func _check_mixed_seed_full(m: Node) -> void:
	print("── ⑪ #14 만재에서 혼합 씨앗 롤이 거짓 획득을 알리지 않는다 ──")
	# 그날 롤이 맞는 칸을 찾는다(공식·확률 모두 main에서 읽는다 — 수치 복제 0).
	var hit := Vector2i(-1, -1)
	for y in range(0, 48):
		for x in range(0, 48):
			var rng := RandomNumberGenerator.new()
			rng.seed = hash("mixdrop:%d:%d:%d" % [m.clock.day, x, y])
			if rng.randf() < m.MIXED_SEED_DROP_CHANCE:
				hit = Vector2i(x, y)
				break
		if hit != Vector2i(-1, -1):
			break
	_check("⑪a-pre 무대: day %d에 롤이 맞는 칸 %s를 찾았다" % [m.clock.day, str(hit)],
		hit != Vector2i(-1, -1))
	if hit == Vector2i(-1, -1):
		return

	var seed_id: String = ItemCatalog.seed_id(CropCatalog.MIXED)
	_fill_backpack_full(m.inventory)
	_check("⑪b-pre 무대: 혼합 씨앗이 들어갈 자리가 없다",
		not m.inventory.can_add(seed_id, 1) and m.inventory.count_of(seed_id) == 0)
	m._roll_mixed_seed_drop(hit)
	_check("⑪c 씨앗이 안 들어왔고 획득 보고도 없다 — 대신 흩어졌다고 말한다('%s')" % _last_notice(m),
		m.inventory.count_of(seed_id) == 0 and _last_notice(m).contains("흩어졌"))

	m.inventory.slots[0] = null
	m.inventory.changed.emit()
	m._roll_mixed_seed_drop(hit)
	_check("⑪d 같은 칸·같은 날인데 자리가 생기자 씨앗이 실제로 들어온다(롤을 막은 게 아니다)",
		m.inventory.count_of(seed_id) == 1)


# ── ⑫ #13 소매 3창구가 만재를 '골드 부족'으로 오보하지 않는다 ─────────────────
# 형제 창구(`_buy_store_generic_n`·만물상 씨앗·스프링클러)는 진작 사유를 가르는데 야시장 씨앗·
# 보부상 씨앗·보부상 일반 셋만 두 사유를 한 조건에 뭉쳐, 냥이 만 단위로 남아도 "골드 부족"이 떴다.
func _check_retail_full_reason(m: Node) -> void:
	print("── ⑫ #13 야시장·보부상 소매가 만재와 냥 부족을 가른다 ──")
	var day0: int = m.clock.day
	var gold0: int = m.wallet.gold
	m.wallet.gold = 999999

	# ㉠ 야시장 씨앗 — 성야절 야시장 날로 시계를 옮긴다(날짜는 카탈로그에서 찾는다).
	var nm_day := -1
	for d in range(1, 500):
		if SeasonalEvent.event_for_day(d) == SeasonalEvent.NIGHT_MARKET:
			nm_day = d
			break
	_check("⑫a-pre 무대: 야시장이 서는 날 %d를 찾았다" % nm_day, nm_day > 0)
	if nm_day > 0:
		m.clock.day = nm_day
		var crop: String = CropCatalog.PIANHWA
		_fill_backpack_full(m.inventory)
		m._try_buy_market_seed(crop, 1)
		var nm_notice := _last_notice(m)
		_check("⑫b 야시장 — 냥이 999999인데 자리가 없다고 말한다('%s')" % nm_notice,
			nm_notice.contains("자리가 없다") and not nm_notice.contains("골드 부족"))
		# 대조: 자리가 있는데 냥이 없으면 종전 문구 그대로다(사유가 뒤바뀐 게 아니다).
		_clear_inventory(m.inventory)
		m.wallet.gold = 0
		m._try_buy_market_seed(crop, 1)
		_check("⑫c 대조 — 자리가 있고 냥이 0이면 여전히 '골드 부족'이다('%s')" % _last_notice(m),
			_last_notice(m).contains("골드 부족"))
		m.wallet.gold = 999999

	# ㉡㉢ 보부상 씨앗·일반 — 좌판이 서는 날의 실제 재고 행에서 id를 뽑는다.
	# 봇짐 구성은 날마다 갈리므로(day 해시 뽑기) 씨앗 행·일반 행이 **둘 다** 선 개장일을 찾는다 —
	# 하루만 보고 "행이 없다"로 넘어가면 두 창구 중 하나가 조용히 안 재진다.
	var ped_day := -1
	var seed_id := ""
	var item_id := ""
	var probe: int = m.clock.day
	for _i in 30:
		probe = Peddler.next_open_day(probe + 1)   # +1 — `next_open_day`는 오늘이 개장일이면 오늘을 준다
		var s_id := ""
		var i_id := ""
		for row in m.peddler.rows_for(probe, {}):
			var k := str(row.get("kind", ""))
			if s_id == "" and k == Peddler.KIND_SEED:
				s_id = str(row["buy_id"])
			elif i_id == "" and k == Peddler.KIND_ITEM:
				i_id = str(row["buy_id"])
		if s_id != "" and i_id != "":
			ped_day = probe
			seed_id = s_id
			item_id = i_id
			break
	_check("⑫d-pre 무대: day %d 봇짐에서 씨앗행 '%s' · 일반행 '%s'를 둘 다 뽑았다" % [ped_day, seed_id, item_id],
		ped_day > 0 and seed_id != "" and item_id != "")
	if ped_day > 0:
		m.clock.day = ped_day
		_fill_backpack_full(m.inventory)
		m._try_buy_peddler_seed(seed_id, 1)
		_check("⑫e 보부상 씨앗 — 만재를 만재라고 말한다('%s')" % _last_notice(m),
			_last_notice(m).contains("자리가 없다") and not _last_notice(m).contains("골드 부족"))
		_fill_backpack_full(m.inventory)
		m._try_buy_peddler_item(item_id, 1)
		_check("⑫f 보부상 일반 — 만재를 만재라고 말한다('%s')" % _last_notice(m),
			_last_notice(m).contains("자리가 없다") and not _last_notice(m).contains("골드 부족"))
		# 대조 — 두 창구 다 냥이 0이면 종전 문구 그대로다(사유가 뒤바뀐 게 아니다).
		_clear_inventory(m.inventory)
		m.wallet.gold = 0
		m._try_buy_peddler_seed(seed_id, 1)
		_check("⑫g 대조 — 보부상 씨앗도 자리가 있고 냥이 0이면 '골드 부족'이다('%s')" % _last_notice(m),
			_last_notice(m).contains("골드 부족"))
		m._try_buy_peddler_item(item_id, 1)
		_check("⑫h 대조 — 보부상 일반도 마찬가지('%s')" % _last_notice(m),
			_last_notice(m).contains("골드 부족"))

	m.clock.day = day0
	m.wallet.gold = gold0
	_clear_inventory(m.inventory)


# ── ⑬ R5 ④i 잔존 정정 — 런타임 이름 옆 고정 조사 0곳 ─────────────────────────
# R5가 세운 전수 스캔이 baseline에서 실패 중이었다: R10이 "버릴 수 없다" 안내를 새로 쓰며 고정
# "는"이 다시 들어왔다(도구 이름은 받침이 갈리므로 "괭이는"/"저승 낚싯대는"이 한 식에서 나와야 한다).
func _check_fixed_josa() -> void:
	print("── ⑬ R5 ④i 정정 — main.gd에 런타임 이름 옆 고정 조사가 없다 ──")
	var name_srcs := ["name_of(", "title_of(", "species_name(", "display_name", "name_ko", "large_name("]
	var josa_re := RegEx.create_from_string("%s ?(를|을|는|은|가|이|와|과)([^가-힣]|$)")
	var leftovers: Array = []
	for i in _src.size():
		var w := ""
		for k in range(i, mini(i + 3, _src.size())):
			w += _src[k] + " "
		if josa_re.search(w) == null:
			continue
		for s in name_srcs:
			if w.contains(String(s)):
				leftovers.append(i + 1)
				break
	_check("⑬a 고정 조사 잔존 0곳(잔존 줄: %s)" % str(leftovers), leftovers.is_empty())
	_check("⑬b 그 자리가 실제로 받침을 가른다 — '괭이는' / '저승 낚싯대는'이 한 식에서",
		HanjiUi.with_eun(ItemCatalog.name_of(ItemCatalog.HOE))
			== ItemCatalog.name_of(ItemCatalog.HOE) + HanjiUi.josa_eun(ItemCatalog.name_of(ItemCatalog.HOE)))


# ── ⑭ #15 혼백관 기증대가 완주를 안다 ────────────────────────────────────────
# 로스터는 `donatable_ids()`(유품 3 + 책 8)로 고정이라 종점이 있다. 다 바친 뒤에도 기증대만
# "들고 오자"를 반복해, "전시 11/11"과 도달 불가 지시가 한 줄에 나란히 섰다(형제 둘은 진작 분기가 있다).
func _check_museum_complete(m: Node) -> void:
	print("── ⑭ #15 기증대가 완주 분기를 갖는다 ──")
	var roster: Array = Museum.donatable_ids()
	_check("⑭a-pre 무대: 완주 전에는 완주가 아니다", not m._museum_complete())
	for id in roster:
		m.museum.donate(String(id), m.clock.day)
	_check("⑭b 로스터를 다 바치면 완주다 — 분모는 `donatable_ids()` 파생이다(수 하드코딩 0)",
		m._museum_complete() and m.museum.donated_count() == roster.size())

	# 빈손으로 [F] — 완주 뒤에는 죽은 지시를 반복하지 않는다. 밀린 답례를 먼저 소비해 둔다:
	# `_try_donate_selected`는 R2 규약대로 답례 정산을 앞에 두므로, 안 비우면 그 갈래가 먼저 먹는다.
	_clear_inventory(m.inventory)
	var guard := 0
	while m._claim_museum_milestones() and guard < 20:
		guard += 1
	_clear_inventory(m.inventory)
	_select(m, ItemCatalog.HOE)   # 기증감이 아닌 것을 든다(빈손과 같은 갈래)
	m._try_donate_selected()
	_check("⑭c [F]가 완주를 말한다 — '%s'" % _last_notice(m),
		_last_notice(m).contains("모두 전시") and not _last_notice(m).contains("들어야 한다"))

	# 프롬프트도 같은 분기를 갖는다(_process 안이라 줄 순서로 잰다 — 완주 갈래가 '들고 오자'보다 먼저).
	var done_i := _line_of("elif _museum_complete():")
	var beg_i := _line_of("혼백관 기증대 — 유품이나 되찾은 책을 들고 오자")
	_check("⑭d 프롬프트 사슬에서 완주 갈래가 '들고 오자'보다 먼저 온다(%d < %d)" % [done_i, beg_i],
		done_i > 0 and beg_i > 0 and done_i < beg_i)


# ── ⑮ #16 ♡MAX 선물이 명목 점수를 알리지도, 주간 횟수를 먹지도 않는다 ─────────
# `_add`가 MAX_POINTS에서 clamp하므로 실효는 정확히 0인데 `gift()`는 명목을 돌려주고, 비생일
# 경로는 주 2회 카운터까지 소모했다 — 아이템 1개 + 그 주 기회 1회를 먹고 "+40 호감도"라 보고.
# ADR-0008: 선물 자체는 안 막는다. 정보(문구)와 소비 계약(카운터)만 가른다.
func _check_gift_maxed(m: Node) -> void:
	print("── ⑮ #16 만점 상대의 선물이 사실을 말한다 ──")
	var day := 10
	var maxed := Affinity.new()
	maxed.points = Affinity.MAX_POINTS
	var normal := Affinity.new()
	normal.points = 0
	_check("⑮a-pre 무대: 하나는 천장에 닿았고 하나는 아니다",
		maxed.is_maxed() and not normal.is_maxed())

	var got_max := maxed.gift(40, day)
	var got_normal := normal.gift(40, day)
	_check("⑮b 만점 쪽은 점수가 한 톨도 안 올랐다(실효 0 — clamp가 이미 그랬다)",
		maxed.points == Affinity.MAX_POINTS and got_max == 40)
	_check("⑮c 그런데 **주간 카운터를 안 먹었다** — 예산은 올릴 수 있을 때만 쓴다",
		maxed.gifts_used_in_week(day) == 0
		and maxed.gifts_left_in_week(day) == Affinity.GIFTS_PER_WEEK)
	_check("⑮d 대조: 만점이 아닌 쪽은 종전대로 카운터를 쓰고 점수도 오른다(계약이 안 넓어졌다)",
		normal.points == got_normal and got_normal == 40
		and normal.gifts_used_in_week(day) == 1)
	_check("⑮e 하루 1회 리듬은 양쪽 다 그대로 소모된다(그건 예산이 아니라 날짜다)",
		not maxed.can_gift(day) and not normal.can_gift(day))
	maxed.free()
	normal.free()

	# 화면 문구 — 만점이면 명목 점수 대신 사실을 말한다(선물 창구가 그 술어를 실제로 본다).
	_check("⑮f 선물 창구가 건네기 **전에** 천장을 기억하고 문구를 가른다",
		_line_of("var was_maxed: bool = r.affinity.is_maxed()") > 0
		and _line_of("호감도는 이미 가득하다") > 0
		and _line_of("var was_maxed: bool = r.affinity.is_maxed()")
			< _line_of("var gained := r.affinity.gift("))


# ── ⑯ #18·#19 매대 아이콘 훅이 매 프레임 디스크를 안 두드린다 ─────────────────
# 두 훅의 호출부는 전부 `_process`가 매 프레임 돌리는 매대 행 조립기다(목공방·야시장·보부상·시련패).
# 값이 변하는 사건은 실행 중에 없으므로 세션 수명 캐시가 맞다 — `_prop_tex`가 이미 그 형태다.
func _check_icon_cache(m: Node) -> void:
	print("── ⑯ #18·#19 매대 아이콘 훅에 1회 조회 캐시가 섰다 ──")
	m._ui_tex_cache.clear()
	var sets: Array = HomeDecoCatalog.purchasable_ids()
	_check("⑯a-pre 무대: 매대에 설 가구 세트가 있다(%d종)" % sets.size(), not sets.is_empty())
	if sets.is_empty():
		return
	var sid := String(sets[0])
	var first: Texture2D = m._deco_icon(sid)
	var keys_after_first: int = m._ui_tex_cache.size()
	var second: Texture2D = m._deco_icon(sid)
	_check("⑯b 두 번째 조회가 캐시에서 나온다 — 키가 안 늘고 같은 값을 돌려준다(없음=null도 캐시)",
		m._ui_tex_cache.size() == keys_after_first and second == first)
	_check("⑯c 그 캐시가 실제로 그 경로를 들고 있다(조회한 파일 = 담긴 키)",
		m._ui_tex_cache.has("res://assets/ui/deco_%s.png" % sid.to_lower()))

	m._ui_tex_cache.clear()
	var tok: Texture2D = m._trial_token_icon()
	_check("⑯d 시련패 아이콘도 같은 캐시를 탄다(값 보존 — 실제 파일이라 non-null)",
		m._ui_tex_cache.has(m.TRIAL_TOKEN_ICON_PATH) and tok != null
		and m._trial_token_icon() == tok)
	# 두 훅 본문에 날 조회가 안 남았다(`_illust_texture` 주석이 금지한 그 형태).
	_check("⑯e 두 훅 본문에 `ResourceLoader.exists` 날 조회가 없다 — 공용 `_ui_tex` 하나만 부른다",
		not _in_func("func _deco_icon", "ResourceLoader.exists")
		and not _in_func("func _trial_token_icon", "ResourceLoader.exists")
		and _in_func("func _deco_icon", "_ui_tex(")
		and _in_func("func _trial_token_icon", "_ui_tex("))


# ── ⑰ #20 층 탈출과 절기 지형이 같은 구역을 두 번 굽지 않는다 ─────────────────
# 절기 첫날 밤 층 안에서 24:00 쓰러짐으로 날이 넘어가면 `_on_day_advanced`가 한 프레임에
# `_rebuild_region(_region)`을 두 번 불렀다(층 탈출 1차 + 절기 지형 2차). 1차 결과는 2차가 캐시를
# 비우며 통째로 버리므로 순수 낭비였다. 처방 = 굽기 **전에** 캐시를 버려 한 번의 굽기가 곧 새 절기다.
func _check_floor_exit_rebuild() -> void:
	print("── ⑰ #20 층 탈출 재빌드가 절기 굽기와 겹치지 않는다 ──")
	# 갱도·나락 두 블록 모두 정리(false)를 굽기보다 앞에 둔다.
	var mine_i := _line_of("_clear_mine_mobs()   # ★[S5-T5]")
	var mine_pre := _line_after(mine_i, "_refresh_season_terrain(false)")
	var mine_bake := _line_after(mine_i, "_rebuild_region(_region)")
	_check("⑰a 갱도 층 탈출 — 캐시 정리(%d)가 굽기(%d)보다 앞이다" % [mine_pre, mine_bake],
		mine_i > 0 and mine_pre > 0 and mine_bake > 0 and mine_pre < mine_bake)
	# 니들은 나락 블록에만 있는 문구로 잡는다 — `narak_floors.begin_run()`은 진입 경로에도 있어
	# 첫 매치가 그쪽으로 새면 뒤의 두 줄 번호가 엉뚱한 함수에서 잡힌다.
	var narak_i := _line_of("이번 런 기록 소멸")
	var narak_pre := _line_after(narak_i, "_refresh_season_terrain(false)")
	var narak_bake := _line_after(narak_i, "_rebuild_region(_region)")
	_check("⑰b 나락 런 종료 — 같은 순서다(%d < %d · 두 블록이 안 갈렸다)" % [narak_pre, narak_bake],
		narak_i > 0 and narak_pre > 0 and narak_bake > 0 and narak_pre < narak_bake)


# ⑰의 라이브 짝 — `_refresh_season_terrain(false)`가 캐시만 버리고 굽지 않으며, 그 뒤의 `true`
# 호출이 스스로 no-op이 되는지(그래야 이중 굽기가 실제로 사라진다). 굽기 여부는 `_rebuild_region`이
# 무효화하는 Y-split 표식으로 잰다(polish_r11 ㉓·배치 A ⑨c의 그 기법).
func _check_season_terrain_fold(m: Node) -> void:
	var before: int = m._bf_season
	m._season_field_override = (before + 1) % 4
	_check("⑰c-pre 무대: 절기가 어긋났다(%d ≠ %d — 이 순간이 곧 리로드가 필요한 순간)"
			% [m._season_field_index(), before],
		m._season_field_index() != before)
	m._last_player_tile_y = 12345
	m._refresh_season_terrain(false)
	_check("⑰d `false`는 캐시만 버리고 안 굽는다(표식 12345가 그대로) — 굽기는 층 탈출이 한 번에 한다",
		m._last_player_tile_y == 12345 and m._wang_tiles.is_empty() and m._field_paint.is_empty())
	_check("⑰e 그러면서 새 절기를 새겼다 — 뒤따르는 `true` 호출이 no-op이 될 근거다",
		m._bf_season == m._season_field_index())
	m._refresh_season_terrain(true)
	_check("⑰f 그래서 하루 정산 맨 끝의 `true` 호출이 스스로 아무것도 안 굽는다(이중 굽기 소멸)",
		m._last_player_tile_y == 12345)
	m._season_field_override = -1
	m._bf_season = -1


# ── ⑱ #21 방목 슬롯이 설치물·프롭·[F] 창구를 피한다 ──────────────────────────
# `_free_pasture_tiles`의 후보 판정이 `is_solid` 한 줄뿐이라, 방목지 첫 줄에 세운 업화로 칸이
# 라운드로빈 slots[0]이 돼 첫 마리가 그 위에 섰다. 그러면 프롬프트 사슬이 `has_animal_at`에서
# 먼저 끊겨 제련 진행을 읽을 수단이 그날 0이 된다([F]는 여전히 먹히므로 화면과 동작이 갈린다).
func _check_pasture_slots(m: Node) -> void:
	print("── ⑱ #21 방목 슬롯과 설치물이 서로를 피한다 ──")
	m._region = RegionCatalog.HOME
	m._indoor = ""
	var base: Array = m._free_pasture_tiles()
	_check("⑱a-pre 무대: 방목 슬롯이 하나 이상 있다(%d칸)" % base.size(), base.size() > 0)
	if base.is_empty():
		return
	var t: Vector2i = base[0]

	# ㉠ 설치물 → 슬롯에서 빠진다.
	m.furnace.place(m._region, t)
	var after: Array = m._free_pasture_tiles()
	_check("⑱b 업화로를 세운 칸 %s가 슬롯 목록에서 정확히 하나 빠졌다" % str(t),
		not (t in after) and after.size() == base.size() - 1)
	m.furnace.remove(m._region, t)
	_check("⑱c 걷어내면 그 칸이 그대로 돌아온다(가드가 방목지를 영구히 죽이지 않는다)",
		(t in m._free_pasture_tiles()) and m._free_pasture_tiles().size() == base.size())

	# ㉡ 반대 방향 — 짐승이 선 칸에는 설치물을 못 세운다.
	var anchors: Array = m.ranch.animal_tiles()
	_check("⑱d-pre 무대: 스타터 짐승이 있다(%d마리)" % anchors.size(), anchors.size() > 0)
	if anchors.is_empty():
		return
	_check("⑱e-pre 무대: 짐승이 서기 전에는 그 칸에 업화로를 세울 수 있었다",
		m._can_place_furnace(t))
	m.ranch.send_to_pasture(anchors[0], t)
	_check("⑱f 짐승이 선 칸에는 업화로·결정기·스프링클러 어느 것도 못 선다(안내 사슬이 안 끊긴다)",
		m.ranch.has_animal_at(t) and not m._can_place_furnace(t)
		and not m._can_place_crystalarium(t) and not m._can_place_sprinkler(t))
	# 이미 나가 있는 짐승 칸을 빼는 것은 **R8이 `_release_open_buildings`에 세운 두 번째 필터**다
	# (`occupied_pasture_tiles`) — 여기 새 가드와 합쳐져야 "설치물도 짐승도 안 겹친다"가 성립한다.
	_check("⑱g 그 칸은 R8 필터가 잡는다 — 새 가드와 합쳐 다음 방출이 같은 칸을 다시 안 집는다",
		m.ranch.occupied_pasture_tiles().has(t)
		and _in_func("func _release_open_buildings", "ranch.occupied_pasture_tiles()"))


# ── ⑲ #22 F9 로드가 삽사리·승마 상태를 되감는다 ──────────────────────────────
# 로드 경로가 `data.has(...)` 가드를 달고 있어, 키 없는 구세이브를 세션 중에 F9로 부르면
# `load_save`가 아예 안 불려 **살아 있는 노드가 롤백되지 않았다**. 같은 함수의 R3 주석이 아이템
# 원장 넷에 대해 이미 금지한 형태다 — Pet·Mount만 그 처방을 안 받았다.
func _check_follower_rollback(m: Node) -> void:
	print("── ⑲ #22 키 없는 구세이브가 추종자 상태를 되감는다 ──")
	_check("⑲a 로드 경로가 두 원장을 **무조건** 부른다(`.get`으로 빈 dict 폴백)",
		_in_func("func _load_game", "mount.load_save(data.get(\"mount\", {}))")
		and _in_func("func _load_game", "pet.load_save(data.get(\"pet\", {}))"))
	_check("⑲b 그리고 `has` 가드가 남아 있지 않다(부분 수정 방지)",
		not _in_func("func _load_game", "data.has(\"pet\")")
		and not _in_func("func _load_game", "data.has(\"mount\")"))

	# 빈 dict가 실제로 롤백인가 — 살아 있는 노드에 입양·승마를 새겨 놓고 되감아 본다.
	m.pet._adopted = true
	m.pet._friend = 5
	m.mount._mounted = true
	m.pet.load_save({})
	m.mount.load_save({})
	_check("⑲c 빈 dict = '미입양·안 탄 상태' — 구세이브의 뜻과 정확히 같다",
		not m.pet.is_adopted() and m.pet.hearts() == 0 and not m.mount.is_mounted())
	m._sync_mount()
	_check("⑲d 속도 계수도 함께 되감긴다(로드 직후 ×1.5가 다시 실리지 않는다)",
		is_equal_approx(m.player.speed_scale, m.mount.speed_scale()))
