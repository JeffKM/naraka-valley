extends SceneTree

# ★ [S1-4 / greybox-spec §5] 작물 5아키타입 + 다절기 프레스티지 CropCatalog 격리 검증.
#
# 무엇을 보나(S1-4 = 데이터+불변식 검증만 — 성장 시뮬·트렐리스 충돌·거대화·품질은 S1-5/6):
#   ① 아키타입 커버리지 — SINGLE·REGROW·giant·trellis·다수확(yield_max>1)·multi_seasonal 각 ≥1작물.
#   ② 작물별 합성 불변식(전 작물) — growth_mode·밴드{4,7,12}·cd 공식·yield 범위·multi_seasonal 생존식.
#   ③ 하위호환 계약 — growth_days=base_growth_days 별칭·missing −1 sentinel·기존 id 상수 등재.
#   ④ 검증기 이빨(음성 mock) — 일부러 어긋난 데이터를 _violations가 잡는지(가드가 실제 작동함 증명).
#
# CropCatalog는 class_name 정적 데이터라 main.tscn 스폰 불필요(순수 데이터 검증).
# 좀비 방지: 모든 단언 뒤 quit(). run_tests.sh 워치독과 함께(자동 발견).

var _fail := 0

func _check(label: String, ok: bool) -> void:
	print(("  ✓ " if ok else "  ✗ ") + label)
	if not ok:
		_fail += 1

# ── 재사용 불변식 검증기(테스트 파일 스코프 — crops.gd는 순수 데이터 유지) ──
# 한 작물 데이터 dict의 위반 목록을 반환(빈 배열 = 합법). §5.5 규칙.
# 부분 mock도 안전하게 다루도록 .get 기본값 사용.
func _violations(d: Dictionary) -> Array:
	var v: Array = []
	var mode: String = d.get("growth_mode", "SINGLE")
	var base: int = int(d.get("base_growth_days", 0))
	var cd: int = int(d.get("regrow_cooldown", 0))
	var ymin: int = int(d.get("yield_min", 1))
	var ymax: int = int(d.get("yield_max", 1))
	var multi: bool = bool(d.get("multi_seasonal", false))
	if mode != "SINGLE" and mode != "REGROW":
		v.append("growth_mode 비정상: %s" % mode)
	if not ([4, 7, 12].has(base)):
		v.append("base_growth_days 밴드 이탈: %d" % base)
	if mode == "SINGLE" and cd != 0:
		v.append("SINGLE인데 cd!=0: %d" % cd)
	if mode == "REGROW" and not multi:
		var expect: int = maxi(2, int(round(base * 0.4)))
		if cd != expect:
			v.append("REGROW cd 공식 불일치: cd=%d 기대=%d" % [cd, expect])
	if ymin < 1 or ymax < ymin:
		v.append("yield 범위 비정상: min=%d max=%d" % [ymin, ymax])
	if multi and not (mode == "REGROW" and base == 12 and cd == 7):
		v.append("multi_seasonal 생존 불변식 위반: mode=%s base=%d cd=%d" % [mode, base, cd])
	return v

func _initialize() -> void:
	print("▶ crop_catalog_test (S1-4)")
	var ids: Array = CropCatalog.ids()

	# ── ① 아키타입 커버리지(접근자 경유 — 접근자도 함께 검증) ──
	var has_single := false
	var has_regrow := false
	var has_giant := false
	var has_trellis := false
	var has_multi_yield := false
	var has_multiseasonal := false
	for id in ids:
		match CropCatalog.growth_mode(id):
			"SINGLE": has_single = true
			"REGROW": has_regrow = true
		if CropCatalog.giant_capable(id):
			has_giant = true
		if CropCatalog.is_trellis(id):
			has_trellis = true
		if CropCatalog.yield_range(id).y > 1:
			has_multi_yield = true
		if CropCatalog.is_multi_seasonal(id):
			has_multiseasonal = true
	_check("① SINGLE 아키타입 존재", has_single)
	_check("① REGROW 아키타입 존재", has_regrow)
	_check("① 거대(giant_capable) 존재", has_giant)
	_check("① 트렐리스(is_trellis) 존재", has_trellis)
	_check("① 다수확(yield_max>1) 존재", has_multi_yield)
	_check("① 다절기(multi_seasonal) 존재", has_multiseasonal)

	# ── ② 작물별 합성 불변식(전 작물 순회, 위반 0) ──
	for id in ids:
		var viol: Array = _violations(CropCatalog.get_crop(id))
		_check("② %s 불변식 통과%s" % [id, "" if viol.is_empty() else " — " + str(viol)], viol.is_empty())

	# 로스터가 5작물·6아키타입을 실제로 채웠는지(회귀 가드 — 실수로 작물이 사라지면 잡힘)
	_check("② 로스터 5작물", ids.size() == 5)
	# 황천포도 = 트렐리스+재성장+다수확 합성 확인(스펙 §2.1 정준 예시)
	_check("② 황천포도 = 트렐리스+REGROW+다수확 합성", \
		CropCatalog.is_trellis(CropCatalog.HWANGCHEON_PODO) \
		and CropCatalog.growth_mode(CropCatalog.HWANGCHEON_PODO) == "REGROW" \
		and CropCatalog.yield_range(CropCatalog.HWANGCHEON_PODO) == Vector2i(2, 3))
	# 불사과 = 다절기 프레스티지 고정값(§2.3)
	_check("② 불사과 = multi_seasonal·REGROW·12·cd7", \
		CropCatalog.is_multi_seasonal(CropCatalog.BULSAGWA) \
		and CropCatalog.growth_days(CropCatalog.BULSAGWA) == 12 \
		and CropCatalog.regrow_cooldown(CropCatalog.BULSAGWA) == 7)

	# ── ③ 하위호환 계약(§5.2 회귀 가드) ──
	var alias_ok := true
	for id in ids:
		if CropCatalog.growth_days(id) != int(CropCatalog.get_crop(id)["base_growth_days"]):
			alias_ok = false
	_check("③ growth_days = base_growth_days 별칭 일치", alias_ok)
	_check("③ growth_days(없는id) = -1 sentinel", CropCatalog.growth_days("__nonexistent__") == -1)
	_check("③ seed_cost(없는id) = -1 sentinel", CropCatalog.seed_cost("__nonexistent__") == -1)
	_check("③ sell_price(없는id) = 0 sentinel", CropCatalog.sell_price("__nonexistent__") == 0)
	_check("③ 기존 id 상수 등재 보존", \
		CropCatalog.has_crop(CropCatalog.HONRYEONGCHO) \
		and CropCatalog.has_crop(CropCatalog.PIANHWA) \
		and CropCatalog.has_crop(CropCatalog.YEONGHON_HOBAK))
	# 리튠 확정값(밴드만, 경제 원형 보존)
	_check("③ 밴드 리튠 4/7/12 + 경제 원형", \
		CropCatalog.growth_days(CropCatalog.HONRYEONGCHO) == 4 \
		and CropCatalog.growth_days(CropCatalog.PIANHWA) == 7 \
		and CropCatalog.growth_days(CropCatalog.YEONGHON_HOBAK) == 12 \
		and CropCatalog.seed_cost(CropCatalog.HONRYEONGCHO) == 10 \
		and CropCatalog.sell_price(CropCatalog.YEONGHON_HOBAK) == 160)

	# ── ④ 검증기 이빨(음성 mock — 가드가 위반을 실제로 잡는가) ──
	var mock_single_cd := {"growth_mode": "SINGLE", "base_growth_days": 4, "regrow_cooldown": 5,
		"yield_min": 1, "yield_max": 1, "multi_seasonal": false}
	var mock_multi_base := {"growth_mode": "REGROW", "base_growth_days": 7, "regrow_cooldown": 3,
		"yield_min": 1, "yield_max": 1, "multi_seasonal": true}
	var mock_yield_flip := {"growth_mode": "SINGLE", "base_growth_days": 7, "regrow_cooldown": 0,
		"yield_min": 3, "yield_max": 2, "multi_seasonal": false}
	_check("④ mock[SINGLE+cd5] 위반 검출", not _violations(mock_single_cd).is_empty())
	_check("④ mock[multi_seasonal+base7] 위반 검출", not _violations(mock_multi_base).is_empty())
	_check("④ mock[yield_max<yield_min] 위반 검출", not _violations(mock_yield_flip).is_empty())
	# 검증기가 합법 데이터엔 오검출 안 하는지(대칭 — 이빨이 지나치게 물지 않음)
	_check("④ 합법 데이터엔 무위반", _violations(CropCatalog.get_crop(CropCatalog.HWANGCHEON_PODO)).is_empty())

	print("══ 결과: %s (실패 %d) ══" % ["PASS" if _fail == 0 else "FAIL", _fail])
	quit(1 if _fail > 0 else 0)
