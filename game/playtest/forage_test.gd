extends SceneTree

# ★ [B1-a.3] 사료풀(Forage) 낫 채집·재생·겨울정지·세이브 격리 검증.
#
# 무엇을 보나(B1-a.3 = 낫 풀베기 → 여물광 건초):
#   ① 시드·다 자람 — seed 등록 / 멱등(재시드 중복 없음) / is_grown.
#   ② 베기 — 다 자란 것만 cut / 벤 뒤 재베기 거부 / 미시드 타일 거부.
#   ③ 재생 — REGROW_DAYS 미달=정지, 도달=다시 자람(겨울 아님).
#   ④ 겨울(잿눈) 정지 — 겨울엔 재생 안 함 / 겨울 지나면 재개(Q7 굶음 긴장).
#   ⑤ 세이브 왕복 — 벤/재생 상태(cut_day) 보존 + 세이브 후 재생 타이머 연속.
#
# 순수 Forage 단위(main 불필요). 좀비 방지: 끝에 quit(). run_tests 워치독.

var _fail := 0

func _check(label: String, ok: bool) -> void:
	print(("  ✓ " if ok else "  ✗ ") + label)
	if not ok:
		_fail += 1

func _initialize() -> void:
	print("▶ forage_test (B1-a.3)")
	var f := Forage.new()
	var t := Vector2i(13, 21)

	# ── ① 시드·다 자람 ──
	_check("① 시드 전 사료풀 아님", not f.has_forage(t) and not f.is_grown(t))
	f.seed(t)
	_check("① 시드 후 다 자람", f.has_forage(t) and f.is_grown(t))
	f.seed(t)   # 재시드
	_check("① 재시드 멱등(중복 없음)", f.grown_count() == 1)

	# ── ② 베기 ──
	_check("② 다 자란 풀 베기 성공", f.cut(t, 5) and not f.is_grown(t))
	_check("② 벤 뒤 재베기 거부", not f.cut(t, 5))
	_check("② 미시드 타일 베기 거부", not f.cut(Vector2i(99, 99), 5))

	# ── ③ 재생(겨울 아님) ──
	f.advance_day(5 + Forage.REGROW_DAYS - 1, false)   # 아직 미달
	_check("③ REGROW 미달 재생 안 함", not f.is_grown(t))
	f.advance_day(5 + Forage.REGROW_DAYS, false)        # 도달
	_check("③ REGROW 도달 재생", f.is_grown(t))

	# ── ④ 겨울(잿눈) 성장정지 ──
	f.cut(t, 10)
	f.advance_day(10 + Forage.REGROW_DAYS + 5, true)    # 겨울(is_winter=true) → 정지
	_check("④ 겨울 재생 정지(잿눈)", not f.is_grown(t))
	f.advance_day(10 + Forage.REGROW_DAYS + 5, false)   # 봄 복귀 → 재생
	_check("④ 겨울 지나면 재생 재개", f.is_grown(t))

	# ── ⑤ 세이브 왕복 ──
	f.cut(t, 20)
	var f2 := Forage.new()
	f2.load_save(f.to_save())
	_check("⑤ 세이브 왕복 사료풀 존재·벤 상태 보존", f2.has_forage(t) and not f2.is_grown(t))
	f2.advance_day(20 + Forage.REGROW_DAYS, false)
	_check("⑤ 세이브 후 재생 타이머 연속", f2.is_grown(t))
	# 구버전(빈) 세이브 방어.
	var f3 := Forage.new()
	f3.load_save({})
	_check("⑤ 빈 세이브 로드 방어(사료풀 0)", f3.all_tiles().is_empty())

	print("══ 결과: %s (실패 %d) ══" % ["PASS" if _fail == 0 else "FAIL", _fail])
	quit(1 if _fail > 0 else 0)
