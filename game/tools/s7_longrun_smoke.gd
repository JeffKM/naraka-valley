extends SceneTree
# ★[S7-T10] 장기 스모크 — day 1 → 113(2년차 진입)까지 취침 체인을 실제로 굴린다.
#
# 무엇을 보나(단위검증이 아니라 *통합 주행*이다 — 단언보다 관측이 목적):
#   ① 크래시·스크립트 에러 0으로 절기 전환 4회(29 유화 · 57 망연 · 85 성야 · 113 피안/2년차)를 통과
#   ② 각 전환일의 사멸 수 · 재스폰 수(잡초/돌·고목) · 잡초 확산 누적
#   ③ 절기 행사 4종(피안 12 더비 · 유화 20 해파리 창 · 망연 16 장원제 · 성야 15 야시장) 발동
#   ④ 테마 데이(절기 25일) — 카페 비해금이면 미발동이 정상
#   ⑤ 날씨 분포(타입별 일수) · 절기 첫날 강제 평온
#   ⑥ 성야(85) 잡초 소멸 · 재스폰 0 · 2년차(113) 달력 연속성
#
# 결정성: 클록은 직진(Time.* 미사용), 전역 RNG는 고정 시드. 게임 안 롤은 전부 day 시드라
#   같은 입력이면 같은 출목이 나온다.
#
# 실행(반드시 game/에서 · 다른 헤드리스와 동시 실행 금지 — save.dat 경합):
#   godot --headless --path "$PWD" --script res://tools/s7_longrun_smoke.gd

const LAST_DAY := 113

var _errors: Array = []

func _read_bytes(path: String) -> PackedByteArray:
	var f := FileAccess.open(path, FileAccess.READ)
	var b := f.get_buffer(f.get_length())
	f.close()
	return b

func _write_bytes(path: String, bytes: PackedByteArray) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_buffer(bytes)
	f.close()

# 그 절기에 제철인 비-다절기·비-트렐리스 작물 하나(사멸이 관측되게 — 다절기는 안 죽는다).
func _seasonal_crop(season: int) -> String:
	for id in CropCatalog.ids():
		var sid := String(id)
		if CropCatalog.is_multi_seasonal(sid) or CropCatalog.is_trellis(sid):
			continue
		if CropCatalog.in_season(sid, season):
			return sid
	return ""

func _initialize() -> void:
	seed(20260811)
	print("══ S7-T10 장기 스모크 (day 1 → %d) ══" % LAST_DAY)

	const SAVE := "user://save.dat"
	const BAK := "user://save.dat.s7_t10_bak"
	var had_save := FileAccess.file_exists(SAVE)
	if had_save:
		_write_bytes(BAK, _read_bytes(SAVE))
	if FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))

	var m: Node = load("res://main.tscn").instantiate()
	get_root().add_child(m)
	await process_frame
	await process_frame

	# 밭 준비 — 스타터 패치 5×5를 갈아 둔다(사멸·확산 파괴가 실제로 관측되도록).
	var cmap: Dictionary = m.get_script().get_script_constant_map()
	var rect: Rect2i = cmap["STARTER_PATCH_RECT"]
	var patch: Array = []
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			var t := Vector2i(x, y)
			m.farm.hoe(t)
			patch.append(t)
	print("밭 준비: 경작 %d칸(스타터 패치)" % patch.size())

	# 관측 누적치
	var weather_days := [0, 0, 0, 0]
	var transitions: Array = []      # 전환일 관측 레코드
	var events_fired: Array = []     # 절기 행사 발동일
	var themes_fired: Array = []     # 테마 데이 발동일
	var spread_total := 0            # 비-전환일 잡초 증가 누적(확산 + 밤 재점령)
	var crop_loss_total := 0         # 비-전환일 작물 소실 누적(잡초 삼킴 + 까마귀)
	var planted_total := 0

	var prev_weeds: int = m.reclaim.weed_count()
	var prev_debris: int = m.reclaim.respawned_debris_count()

	for d in range(2, LAST_DAY + 1):
		var season_start: bool = GameClock.is_season_first_day(d)
		var new_season := GameClock.season_index_for_day(d)
		var w := Weather.weather_for_day(d)
		weather_days[w] += 1
		if season_start and w != Weather.CALM:
			_errors.append("day %d 절기 첫날인데 날씨가 %s(강제 평온 위반)" % [d, Weather.name_of(w)])

		# 전환 직전 상태 스냅샷
		var planted_before: int = m.farm.planted_tiles().size()
		var expect_wither := 0
		if season_start:
			for pt in m.farm.planted_tiles():
				var pc: String = m.farm.crop_of(pt)
				if not (CropCatalog.is_multi_seasonal(pc) or CropCatalog.in_season(pc, new_season)):
					expect_wither += 1

		m.clock.day = d
		m._on_day_advanced(d)
		await process_frame

		var weeds_now: int = m.reclaim.weed_count()
		var debris_now: int = m.reclaim.respawned_debris_count()
		var planted_after: int = m.farm.planted_tiles().size()
		var d_weeds := weeds_now - prev_weeds
		var d_debris := debris_now - prev_debris

		if season_start:
			transitions.append({
				"day": d, "season": GameClock.season_name(new_season),
				"withered": expect_wither, "planted_before": planted_before,
				"planted_after": planted_after,
				"weeds_before": prev_weeds, "weeds_after": weeds_now,
				"d_weeds": d_weeds, "d_debris": d_debris,
			})
			if planted_before - planted_after != expect_wither:
				_errors.append("day %d 사멸 수 불일치(기대 %d · 실제 %d)"
					% [d, expect_wither, planted_before - planted_after])
		else:
			if d_weeds > 0:
				spread_total += d_weeds
			if planted_after < planted_before:
				crop_loss_total += planted_before - planted_after

		# 절기 행사 · 테마 데이 발동 관측(아침 배너 = 순수 파생 — 알림 큐를 안 뒤진다)
		var ev := SeasonalEvent.event_for_day(d)
		if ev != SeasonalEvent.NONE:
			var lines: Array = m._seasonal_morning_notices()
			events_fired.append("day %d(%s %d일) %s · 배너 %d줄"
				% [d, GameClock.season_name(new_season), GameClock.day_of_season(d),
					SeasonalEvent.name_of(ev), lines.size()])
			if lines.is_empty():
				_errors.append("day %d 행사일인데 아침 배너 0줄" % d)
		var th: int = m._festival_theme()
		if th != Festival.NONE:
			themes_fired.append("day %d %s" % [d, Festival.name_of(th)])

		# 런 종료 게이트가 되살아나지 않았는지(절기 전환의 전제)
		if m._run_over:
			_errors.append("day %d에서 런이 종료됨(_run_over true — 게이트 부활)" % d)
			break

		# 절기 2일차마다 그 절기 작물을 빈 경작칸에 심는다 → 다음 전환에 사멸이 관측된다.
		if GameClock.day_of_season(d) == 2:
			var crop := _seasonal_crop(new_season)
			var n := 0
			if crop != "":
				for t: Vector2i in patch:
					if m.farm.is_tilled(t) and not m.farm.is_planted(t):
						if m.farm.plant(t, crop):
							n += 1
			planted_total += n
			print("  day %3d [%s %2d일] 파종 %s ×%d"
				% [d, GameClock.season_name(new_season), GameClock.day_of_season(d),
					CropCatalog.name_of(crop), n])

		prev_weeds = weeds_now
		prev_debris = debris_now

	# ── 결과 ────────────────────────────────────────────────────────────────
	print("\n── ① 절기 전환 관측 ──")
	for r: Dictionary in transitions:
		print("  day %3d → %s | 사멸 %d포기(밭 %d→%d) | 잡초 %d→%d(Δ%+d) | 재스폰 debris Δ%+d"
			% [r["day"], r["season"], r["withered"], r["planted_before"], r["planted_after"],
				r["weeds_before"], r["weeds_after"], r["d_weeds"], r["d_debris"]])
	print("  전환 횟수: %d회" % transitions.size())

	print("\n── ② 잡초 확산·작물 소실 누적(비-전환일) ──")
	print("  잡초 증가 누적 %d칸 · 작물 소실 누적 %d포기 · 총 파종 %d포기"
		% [spread_total, crop_loss_total, planted_total])
	print("  최종 잡초 %d칸 · 재스폰 debris %d칸" % [m.reclaim.weed_count(),
		m.reclaim.respawned_debris_count()])

	print("\n── ③ 절기 행사 발동 ──")
	for line: String in events_fired:
		print("  " + String(line))
	print("  발동 %d건" % events_fired.size())

	print("\n── ④ 테마 데이 ──")
	if themes_fired.is_empty():
		print("  발동 0건 — 카페 단계 %d · 누적 서빙 매출 %d냥이라 비해금(정상)"
			% [m._cafe_stage(), m._cafe_revenue_total])
	else:
		for line: String in themes_fired:
			print("  " + String(line))

	print("\n── ⑤ 날씨 분포(day 2..%d · %d일) ──" % [LAST_DAY, LAST_DAY - 1])
	for i in range(4):
		print("  %-10s %3d일 (%.1f%%)" % [Weather.name_of(i), weather_days[i],
			100.0 * float(weather_days[i]) / float(LAST_DAY - 1)])

	print("\n── ⑥ 최종 상태 ──")
	print("  day %d · %s %d일 · 절기 인덱스 %d · _run_over=%s · clock.running=%s"
		% [m.clock.day, GameClock.season_name(m.clock.season_index()),
			GameClock.day_of_season(m.clock.day), m.clock.season_index(),
			str(m._run_over), str(m.clock.running)])
	print("  HUD 날짜 문자열: %s" % m._inv_date_string())

	m.queue_free()
	await process_frame
	await process_frame

	if had_save:
		_write_bytes(SAVE, _read_bytes(BAK))
		DirAccess.remove_absolute(ProjectSettings.globalize_path(BAK))
	elif FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))

	print("\n══ %s ══" % ("스모크 이상 없음" if _errors.is_empty()
		else "이상 %d건" % _errors.size()))
	for e: String in _errors:
		print("  ✗ " + String(e))
	quit(1 if not _errors.is_empty() else 0)
