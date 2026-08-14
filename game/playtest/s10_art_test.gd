extends SceneTree
# ★[S10-T9 / ADR-0069 아트 스코프] 엔드게임 롱테일 아트 패스 — 헤드리스 배선 검증.
#
# 이 스위트가 재는 것은 **그림의 예쁨이 아니라 "폴백에 도달하지 않는다"**이다. 육안은 덤프
# 하네스(playtest/s10_art_dump.gd)가 맡고, 여기서는 아트 패스가 실제로 색박스를 지웠는지를
# 기계로 못 박는다 — 파일 하나가 빠지거나 이름이 어긋나면 게임은 조용히 그레이박스로 굴러가고
# (폴백이 그러라고 있는 것이다) 그 침묵을 잡을 사람이 없다.
#
# 무엇을 보증하나:
#   ① 아이템 아이콘 — S10_ICONS 전 키가 `_item_icon`에서 텍스처를 돌려준다(색박스 폴백 미도달).
#      ★ 분모는 **S10_ICONS 크기에서 파생**한다(하드코딩 15 금지 — 로스터가 늘면 따라온다).
#   ② 월드 프롭 — 이 패스가 훅을 깐 프롭 이름 전부가 `_prop_tex`에서 텍스처를 돌려준다.
#      ★ 레어크로우 프롭 이름은 **ItemCatalog.RARECROWS에서 파생**한다(같은 이유).
#   ③ 규격 — 발치 앵커·시트 프레임이 드로우가 전제하는 크기와 일치한다(어긋나면 뜨거나 잘린다).
#   ④ 시련패 화폐 아이콘 — `_trial_token_icon()`이 null이 아니다(= 엽전 폴백 미도달).
#   ⑤ 캐릭터 시트 — 동행 혼 시트가 CharSprite 규약(80×320)으로 로드된다(= 그레이박스 몸 미사용).
#   ⑥ 외관 2종 — 늘봄방·시련장 facade가 footprint 폭 안에서 성립한다.
#   ⑦ ★**상태를 아트에 굽지 않았다**의 코드 측 짝 — 아트가 있어도 상태 드로우가 살아 있는지를
#      `_draw_sapsari`의 물그릇 회귀(§24.10 ③)를 표본으로 잰다. 소스에 early return이 남으면 잡힌다.
#
# 실행: TIMEOUT=180 ./run_tests.sh s10_art   (헤드리스는 반드시 game/에서 · 순차)

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

func _initialize() -> void:
	print("══ S10-T9 아트 패스 배선 검증(색박스 폴백 미도달) ══")
	var m := await _spawn_main()

	# ── ① 아이템 아이콘 ─────────────────────────────────────────────────────
	var icon_keys: Array = m.S10_ICONS.keys()
	_check("①a S10_ICONS가 비어 있지 않다 (%d종)" % icon_keys.size(), icon_keys.size() > 0)
	var missing_icon: Array = []
	for id in icon_keys:
		if m._item_icon(String(id)) == null:
			missing_icon.append(String(id))
	_check("①b 전 키가 `_item_icon`에서 텍스처를 돌려준다 (누락: %s)" % str(missing_icon),
		missing_icon.is_empty())
	# 구성 요소 명시 단언(T5 교훈 — 개수만 세면 다음 슬라이스가 항목을 얹을 때 잠복 실패한다).
	for must in [ItemCatalog.SPRINKLER, ItemCatalog.SPRINKLER_T2, ItemCatalog.SPRINKLER_T3,
			ItemCatalog.GARDEN_POT, ItemCatalog.CRYSTALARIUM, ItemCatalog.CRYSTALARIUM_PART,
			ItemCatalog.MOUNT_WHISTLE]:
		_check("①c %s 아이콘 등재" % must, m.S10_ICONS.has(must))
	for rid in ItemCatalog.RARECROWS:
		_check("①d 레어크로우 %s 아이콘 등재" % rid, m.S10_ICONS.has(String(rid)))
	# 인벤·핫바가 보는 dict에도 같은 키가 얹혔는가(병합을 한 자리에 모아 둔 것의 검증).
	var merged: Dictionary = {}
	m._merge_t10_icons(merged)
	var not_merged: Array = []
	for id in icon_keys:
		if not merged.has(id):
			not_merged.append(String(id))
	_check("①e `_merge_t10_icons`가 전 키를 얹는다 (누락: %s)" % str(not_merged), not_merged.is_empty())

	# ── ② 월드 프롭 ─────────────────────────────────────────────────────────
	# 이 패스가 아트를 놓은 프롭 이름의 **단일 출처**. 레어크로우는 로스터에서 파생한다.
	var prop_names: Array = ["codex_stand", "firefly_stand", "peddler_stall", "sapsari",
		"pet_bowl", "crystalarium", "panning_spot", "garden_pot",
		"sprinkler_t1", "sprinkler_t2", "sprinkler_t3",
		"trial_board", "trial_stall", "firefly_soul", "mount_horse"]
	for rid in ItemCatalog.RARECROWS:
		prop_names.append(String(rid))
	var missing_prop: Array = []
	for n in prop_names:
		if m._prop_tex(String(n)) == null:
			missing_prop.append(String(n))
	_check("②a 전 프롭이 `_prop_tex`에서 텍스처를 돌려준다 %d종 (누락: %s)"
		% [prop_names.size(), str(missing_prop)], missing_prop.is_empty())
	# 구성 요소 명시 — 로스터가 늘었는데 프롭 목록이 안 따라오면 여기서 잡힌다(파생의 증명).
	var crow_gap: Array = []
	for rid in ItemCatalog.RARECROWS:
		if not prop_names.has(String(rid)):
			crow_gap.append(String(rid))
	_check("②b 레어크로우 로스터 전원이 프롭 목록에 파생돼 있다 (누락: %s)" % str(crow_gap),
		crow_gap.is_empty())
	for n in ["codex_stand", "firefly_stand", "peddler_stall", "sapsari", "pet_bowl",
			"crystalarium", "panning_spot", "garden_pot", "trial_board", "trial_stall",
			"firefly_soul", "mount_horse"]:
		_check("②c %s 프롭 아트 존재" % n, m._prop_tex(String(n)) != null)

	# ── ③ 규격 ──────────────────────────────────────────────────────────────
	# 발치 앵커 프롭은 폭 32를 넘으면 옆 칸을 침범하고, 높이가 드로우 전제와 어긋나면 뜬다.
	for n in ["sapsari", "pet_bowl", "crystalarium", "panning_spot", "garden_pot",
			"sprinkler_t1", "sprinkler_t2", "sprinkler_t3", "trial_board", "firefly_soul"]:
		var sz: Vector2 = m._prop_tex(String(n)).get_size()
		_check("③a %s = 32×32" % n, sz == Vector2(32, 32))
	# 혼백관 두 창구 = 32×27(타일 하단 y27..30이 진행 눈금 자리 — §24.1).
	for n in ["codex_stand", "firefly_stand"]:
		_check("③b %s = 32×27 (눈금 자리 비움)" % n,
			m._prop_tex(String(n)).get_size() == Vector2(32, 27))
	_check("③c trial_stall = 32×22 (잔고 패 자리 비움)",
		m._prop_tex("trial_stall").get_size() == Vector2(32, 22))
	_check("③d peddler_stall = 32×48 (야시장 매대와 동형)",
		m._prop_tex("peddler_stall").get_size() == Vector2(32, 48))
	for rid in ItemCatalog.RARECROWS:
		_check("③e %s = 32×64 (1×2칸 허수아비 실루엣)" % rid,
			m._prop_tex(String(rid)).get_size() == Vector2(32, 64))
	# 먹갈기 시트 = 프레임 48 × 4행. 드로우가 `MOUNT_SHEET_FRAME`으로 행을 자르므로 둘이 어긋나면
	# 엉뚱한 행이 잘려 나온다(행 수는 CharSprite.DIRS에서 파생 — 방향이 늘면 따라온다).
	var msz: Vector2 = m._prop_tex("mount_horse").get_size()
	_check("③f 먹갈기 시트 = %d × %d×%d행" % [m.MOUNT_SHEET_FRAME, m.MOUNT_SHEET_FRAME, CharSprite.DIRS.size()],
		msz == Vector2(m.MOUNT_SHEET_FRAME, m.MOUNT_SHEET_FRAME * CharSprite.DIRS.size()))

	# ── ④ 시련패 화폐 아이콘 ────────────────────────────────────────────────
	_check("④a `_trial_token_icon()` != null (엽전 폴백 미도달)", m._trial_token_icon() != null)
	_check("④b 시련패 아이콘 = 32×32", m._trial_token_icon().get_size() == Vector2(32, 32))

	# ── ⑤ 동행 혼 시트 ──────────────────────────────────────────────────────
	var soul_spr := CharSprite.make("res://assets/characters/soul_child.png")
	_check("⑤a CharSprite.make가 시트를 읽는다(그레이박스 몸 미사용)", soul_spr != null)
	if soul_spr != null:
		_check("⑤b 4방향 워크 애니가 선다",
			soul_spr.sprite_frames.has_animation("walk_down")
			and soul_spr.sprite_frames.has_animation("walk_up")
			and soul_spr.sprite_frames.has_animation("walk_right")
			and soul_spr.sprite_frames.has_animation("walk_left"))
		soul_spr.queue_free()
	var soul_tex := load("res://assets/characters/soul_child.png") as Texture2D
	_check("⑤c 시트 = %d × %d×%d행" % [CharSprite.FRAME.x, CharSprite.FRAME.y, CharSprite.DIRS.size()],
		soul_tex.get_size() == Vector2(CharSprite.FRAME.x, CharSprite.FRAME.y * CharSprite.DIRS.size()))

	# ── ⑥ 외관 2종 ──────────────────────────────────────────────────────────
	# facade는 bottom-center 앵커라 footprint보다 **위로는** 솟아도 되지만(지붕), 가로로 넘치면
	# 옆 건물·길을 덮는다. 폭이 footprint 폭 이하인지가 이 단언의 전부다.
	var gw: float = m.FACADE_GREENHOUSE.get_size().x
	_check("⑥a 늘봄방 facade 폭 %d ≤ footprint %d" % [gw, m.GREENHOUSE_EXT_RECT.size.x * m.TILE],
		gw <= float(m.GREENHOUSE_EXT_RECT.size.x * m.TILE))
	var tw: float = m.FACADE_TRIAL.get_size().x
	_check("⑥b 시련장 facade 폭 %d ≤ footprint %d" % [tw, m.TRIAL_EXT_RECT.size.x * m.TILE],
		tw <= float(m.TRIAL_EXT_RECT.size.x * m.TILE))
	# 지붕이 위로 솟는 것이 정면 facade의 정의다([§2] 지붕 깊이 노출) — footprint 높이보다 커야 한다.
	_check("⑥c 늘봄방 facade 높이 > footprint 높이(지붕이 솟는다)",
		m.FACADE_GREENHOUSE.get_size().y > float(m.GREENHOUSE_EXT_RECT.size.y * m.TILE) * 0.9)

	# ── ⑦ 상태 드로우가 아트 뒤에 살아 있다 ─────────────────────────────────
	# §24.10 ③의 회귀 봉합을 소스에서 잰다: 물그릇 텍스처 분기가 `return`으로 끝나면 "오늘 물을
	# 채웠나" 표식이 아트와 함께 사라진다. 그 형태가 되살아나는 것을 이 단언이 막는다.
	var src := FileAccess.get_file_as_string("res://main.gd")
	var i0 := src.find("func _draw_sapsari")
	var i1 := src.find("func _draw_fortune_mirror")
	var body := src.substr(i0, i1 - i0) if i0 >= 0 and i1 > i0 else ""
	_check("⑦a `_draw_sapsari` 본문을 읽었다", body.length() > 0)
	_check("⑦b 물그릇 상태 드로우(can_fill_bowl)가 본문에 살아 있다",
		body.find("can_fill_bowl") >= 0)
	# 텍스처를 그린 뒤 곧장 return하면 그 아래 상태 드로우에 절대 도달하지 않는다.
	var bowl_at := body.find("_prop_tex(\"pet_bowl\")")
	var fill_at := body.find("can_fill_bowl")
	var ret_between := body.substr(bowl_at, fill_at - bowl_at).find("\t\treturn") if bowl_at >= 0 and fill_at > bowl_at else -1
	_check("⑦c 물그릇 아트 분기와 상태 드로우 사이에 early return이 없다", ret_between < 0)

	m.queue_free()
	await process_frame
	print("══ 결과: %s (실패 %d) ══" % ["PASS" if _fail == 0 else "FAIL", _fail])
	quit(1 if _fail > 0 else 0)
