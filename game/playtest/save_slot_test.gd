extends SceneTree
# ★멀티 슬롯 세이브 검증(gemini-ui-identity-spec §3.4·§7-g) — SaveManager 순수 IO 단위검증.
#
# 무엇을 보나:
#   ① 슬롯 경로 — slot 0 = 레거시 user://save.dat(하위호환), slot 1·2 = 신규 파일. 음수 클램프.
#   ② 슬롯 격리 — 0·1·2에 서로 다른 data를 저장하면 각 슬롯이 자기 것만 돌려주고,
#      한 슬롯 삭제가 다른 슬롯을 안 건드린다(독립 3 슬롯).
#   ③ 메타 헤더 — 저장 시 얹은 경량 meta를 slot_meta가 전체 로드 없이 읽는다(코지 다이어리 UI 입력).
#   ④ 하위호환 — meta 없는 옛 포맷({version,data})도 load_game이 data를 돌려주고 slot_meta는 {}.
#   ⑤ 손상/버전 방어 — 깨진 파일·버전 불일치는 load_game·slot_meta 모두 {}.
#   ⑥ any_save — 어느 슬롯에든 있으면 true, 다 비면 false.
#
# 실행: godot --headless --path game --script res://playtest/save_slot_test.gd
#
# 메모: 3 슬롯 경로를 모두 공유하므로(실제 개발 세이브), 시작 시 백업하고 끝에 복원한다(테스트 격리).
# main을 스폰하지 않는 순수 IO 테스트라 GPU·save.dat 경합과 무관(빠르고 결정적).

var _fail := 0

func _check(label: String, ok: bool) -> void:
	print(("  ✓ " if ok else "  ✗ ") + label)
	if not ok:
		_fail += 1

func _read_bytes(path: String) -> PackedByteArray:
	var f := FileAccess.open(path, FileAccess.READ)
	var b := f.get_buffer(f.get_length())
	f.close()
	return b

func _write_bytes(path: String, bytes: PackedByteArray) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_buffer(bytes)
	f.close()

func _rm(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

# 손상 세이브를 심는다(str_to_var가 Dictionary로 안 푸는 문자열).
func _write_raw(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()

func _initialize() -> void:
	print("══ 멀티 슬롯 세이브(SaveManager) 검증 ══")
	var sm := SaveManager.new()

	# ── 3 슬롯 경로 백업(테스트 격리) ──
	var paths := [SaveManager.slot_path(0), SaveManager.slot_path(1), SaveManager.slot_path(2)]
	var baks := {}
	for p in paths:
		if FileAccess.file_exists(p):
			baks[p] = _read_bytes(p)
		_rm(p)   # 깨끗한 상태에서 시작

	# ── ① 슬롯 경로 ──
	_check("①a slot 0 = 레거시 save.dat", SaveManager.slot_path(0) == "user://save.dat")
	_check("①b slot 1 = save1.dat", SaveManager.slot_path(1) == "user://save1.dat")
	_check("①c slot 2 = save2.dat", SaveManager.slot_path(2) == "user://save2.dat")
	_check("①d 음수 슬롯은 slot 0으로 클램프", SaveManager.slot_path(-5) == "user://save.dat")

	# ── ② 슬롯 격리(서로 다른 data 저장 → 각자 것만 복원) ──
	_check("②pre 전 슬롯 비어 있음(시작 청소)", not sm.any_save())
	sm.save_game({"who": "slot0", "n": 10}, 0, {"day": 1, "soul": 100})
	sm.save_game({"who": "slot1", "n": 20}, 1, {"day": 34, "soul": 85})
	sm.save_game({"who": "slot2", "n": 30}, 2, {"day": 200, "soul": 40})
	_check("②a slot 0 has_save", sm.has_save(0))
	_check("②b slot 1 has_save", sm.has_save(1))
	_check("②c slot 2 has_save", sm.has_save(2))
	_check("②d slot 0 로드 = 자기 것", sm.load_game(0).get("who", "") == "slot0")
	_check("②e slot 1 로드 = 자기 것", sm.load_game(1).get("who", "") == "slot1")
	_check("②f slot 2 로드 = 자기 것", sm.load_game(2).get("who", "") == "slot2")
	_check("②g slot 1 data 정확(n=20)", int(sm.load_game(1).get("n", 0)) == 20)

	# ── ③ 메타 헤더(전체 로드 없이 날짜·혼력) ──
	_check("③a slot 1 메타 day=34", int(sm.slot_meta(1).get("day", -1)) == 34)
	_check("③b slot 1 메타 soul=85", int(sm.slot_meta(1).get("soul", -1)) == 85)
	_check("③c slot 2 메타 day=200", int(sm.slot_meta(2).get("day", -1)) == 200)
	_check("③d 메타는 헤더만(전체 data 미포함)", not sm.slot_meta(1).has("who"))

	# ── ④ 삭제 격리(slot 1만 지워도 0·2는 온전) ──
	sm.delete_save(1)
	_check("④a slot 1 삭제됨", not sm.has_save(1))
	_check("④b slot 0 온전", sm.has_save(0) and sm.load_game(0).get("who", "") == "slot0")
	_check("④c slot 2 온전", sm.has_save(2) and sm.load_game(2).get("who", "") == "slot2")
	_check("④d 삭제 슬롯 로드 = {}", sm.load_game(1).is_empty())
	_check("④e 삭제 슬롯 메타 = {}", sm.slot_meta(1).is_empty())

	# ── ⑤ 하위호환: meta 없는 옛 포맷({version,data}) ──
	sm.delete_save(1); sm.delete_save(2)
	_write_raw(SaveManager.slot_path(1),
		var_to_str({"version": SaveManager.VERSION, "data": {"who": "legacy", "n": 7}}))
	_check("⑤a 옛 포맷 load = data 복원", sm.load_game(1).get("who", "") == "legacy")
	_check("⑤b 옛 포맷 slot_meta = {} (관대)", sm.slot_meta(1).is_empty())

	# ── ⑥ 손상/버전 방어 ──
	_write_raw(SaveManager.slot_path(2), "not a dictionary at all")
	_check("⑥a 손상 파일 load = {}", sm.load_game(2).is_empty())
	_check("⑥b 손상 파일 meta = {}", sm.slot_meta(2).is_empty())
	_write_raw(SaveManager.slot_path(2),
		var_to_str({"version": 999, "meta": {"day": 5}, "data": {"who": "future"}}))
	_check("⑥c 버전 불일치 load = {}", sm.load_game(2).is_empty())
	_check("⑥d 버전 불일치 meta = {}", sm.slot_meta(2).is_empty())

	# ── ⑦ any_save ──
	sm.delete_save(0); sm.delete_save(1); sm.delete_save(2)
	_check("⑦a 전 슬롯 비면 any_save=false", not sm.any_save())
	sm.save_game({"x": 1}, 2)
	_check("⑦b 한 슬롯이라도 있으면 any_save=true", sm.any_save())

	# ── 정리: 테스트가 만든 슬롯 삭제 + 개발 세이브 복원 ──
	sm.free()
	for p in paths:
		_rm(p)
		if baks.has(p):
			_write_bytes(p, baks[p])

	if _fail == 0:
		print("══ 통과 ══")
		quit(0)
	else:
		print("══ 실패 %d ══" % _fail)
		quit(1)
