extends SceneTree
# ★[S7-T10] 날씨 절기별 분해 — 순수 static 롤이라 main 스폰 없이 센다(1년 = day 1..112).
# 설계 불변식 확인용: 잿눈은 성야절에만 · 성야절 혼우 0 · 절기 첫날·테마 슬롯 강제 평온.

func _initialize() -> void:
	var tally := [[0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0]]
	var forced := 0
	for d in range(1, 113):
		var s := GameClock.season_index_for_day(d)
		var w := Weather.weather_for_day(d)
		tally[s][w] += 1
		if GameClock.is_season_first_day(d) or Festival.is_theme_slot(d):
			forced += 1
			if w != Weather.CALM:
				print("  ✗ day %d 강제 평온 위반(%s)" % [d, Weather.name_of(w)])
	print("── 날씨 절기별 분해(1년차 day 1..112 · 절기당 28일) ──")
	for s in range(4):
		print("  %-5s  평온 %2d · 혼우 %2d · 잿눈 %2d · 혼불 %2d   (설계 분포 %s)"
			% [GameClock.season_name(s), tally[s][0], tally[s][1], tally[s][2], tally[s][3],
				str(Weather.DISTRIBUTION[s])])
	print("  강제 평온일(절기 첫날 4 + 테마 슬롯 4) = %d일" % forced)
	quit()
