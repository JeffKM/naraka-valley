extends SceneTree

# [S1R-T10 · 도구 스윙 애니 배선] 그레이박스 단위검증(ephemeral 헤드리스).
#
# 무엇을 보나(시각 전용 오버레이 — 헤드리스 로직 회귀엔 무영향이어야 한다):
#   Part A — 시트 규격·방향 매핑(main 불필요):
#     ⓪ 4모션 시트(hoe/water/scythe/harvest) 존재 + 480×320(6열×4행·프레임 80×80).
#     ⓪ CharSprite.tool_anim = 방향부(dir_anim)에 motion 접두사(예: DOWN→"hoe_down").
#   Part B — player·main 통합:
#     ① player가 4모션을 같은 SpriteFrames에 얹음(hoe_down… 애니 6프레임) + animation_finished 연결.
#     ② _use_tool(괭이) → 스윙 상태 진입("hoe_*" 재생) → 완료 시 워크/대기 복귀 + speed_scale 원복.
#     ③ _use_tool(물뿌리개) → "water_*" 스윙 진입·복귀 (즉발 물주기 로직은 그대로 성공).
#     ④ _try_harvest(맨손 수확) → "harvest_*" 스윙 진입·복귀 (수확 로직 그대로 성공).
#     ⑤ _swing_for_item 매핑: 낫→"scythe_*" 진입 / 곡괭이=전용 시트 없음 → 무동작 폴백(스윙 안 뜸).
#     ⑥ speed_factor 실효화: FarmSkill 레벨↑ → speed_scale↑(재생 시간↓). 직접 factor 주입도 비례.
#
# 좀비 방지: 모든 단언 뒤 quit(). run_tests.sh 워치독과 함께. 세이브 잔재는 끝에서 격리 정리.

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

# 든 아이템 선택(없으면 인벤 넣고 그 슬롯 선택 — sprinkler_test 결).
func _select(m: Node, id: String) -> void:
	if not m.inventory.has_item(id):
		m.inventory.add_item(id, 1)
	for i in range(m.inventory.slots.size()):
		if m.inventory.id_at(i) == id:
			m.inventory.select(i)
			return

# 스윙을 강제로 끝내(헤드리스는 실시간 재생 완료가 불안정 — 완료 핸들러를 직접 호출) 복귀 상태를 검증.
func _finish_swing(player: Node) -> void:
	player._on_anim_finished()

func _initialize() -> void:
	print("══ 도구 스윙 애니 배선(S1R-T10) 검증 ══")
	const SAVE := "user://save.dat"
	if FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))

	_part_a()
	await _part_b()

	print("══ 결과: %s (실패 %d) ══" % ["PASS" if _fail == 0 else "FAIL", _fail])
	if FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	quit(1 if _fail > 0 else 0)

func _part_a() -> void:
	# ⓪ 4모션 시트 규격(480×320 = 6열×4행, 프레임 80×80).
	var sheets := {
		"hoe": "res://assets/characters/player_hoe.png",
		"water": "res://assets/characters/player_water.png",
		"scythe": "res://assets/characters/player_scythe.png",
		"harvest": "res://assets/characters/player_harvest.png",
	}
	for motion in sheets:
		var path: String = sheets[motion]
		_check("⓪ %s 시트 존재" % motion, ResourceLoader.exists(path))
		var tex := load(path) as Texture2D
		_check("⓪ %s 규격 480×320" % motion,
			tex != null and tex.get_width() == 480 and tex.get_height() == 320)
	# ⓪ tool_anim = dir_anim 방향부에 motion 접두사(4방향).
	_check("⓪ tool_anim hoe·DOWN = hoe_down", CharSprite.tool_anim("hoe", Vector2.DOWN) == "hoe_down")
	_check("⓪ tool_anim hoe·UP = hoe_up", CharSprite.tool_anim("hoe", Vector2.UP) == "hoe_up")
	_check("⓪ tool_anim water·RIGHT = water_right", CharSprite.tool_anim("water", Vector2.RIGHT) == "water_right")
	_check("⓪ tool_anim scythe·LEFT = scythe_left", CharSprite.tool_anim("scythe", Vector2.LEFT) == "scythe_left")

func _part_b() -> void:
	var m: Node = await _spawn_main()
	var player: Node = m.player
	_check("부팅 = 안식 농원", m._region == RegionCatalog.HOME)
	m.energy.refill()

	# ── ① player 시트프레임에 4모션 얹힘 + 신호 연결 ──
	_check("① 도색 스프라이트 존재(시트 로드 성공)", player._sprite != null)
	var sf: SpriteFrames = player._sprite.sprite_frames
	_check("① hoe_down 애니 등록", sf.has_animation("hoe_down"))
	_check("① water_right 애니 등록", sf.has_animation("water_right"))
	_check("① scythe_up 애니 등록", sf.has_animation("scythe_up"))
	_check("① harvest_left 애니 등록", sf.has_animation("harvest_left"))
	_check("① 도구 애니 6프레임(6열)", sf.get_frame_count("hoe_down") == 6)
	_check("① 스윙은 루프 아님(1회)", not sf.get_animation_loop("hoe_down"))
	_check("① 워크는 루프 유지", sf.get_animation_loop("walk_down"))
	_check("① animation_finished 신호 연결", player._sprite.animation_finished.is_connected(player._on_anim_finished))
	_check("① 초기 스윙 상태 아님", not player.is_swinging())

	# ── ② _use_tool(괭이) → 스윙 진입·복귀 ──
	var t_hoe := Vector2i(50, 45)
	_select(m, ItemCatalog.HOE)
	m._target = t_hoe
	m._use_tool()
	_check("② 괭이질 즉발 로직 성공(경작됨 — 로직 불변)", m.farm.is_tilled(t_hoe))
	_check("② 스윙 상태 진입", player.is_swinging())
	_check("② hoe 모션 재생", String(player._sprite.animation).begins_with("hoe_"))
	_check("② 재생 중(is_playing)", player._sprite.is_playing())
	_finish_swing(player)
	_check("② 완료 후 스윙 해제", not player.is_swinging())
	_check("② 완료 후 워크/대기 복귀", String(player._sprite.animation).begins_with("walk_"))
	_check("② 완료 후 speed_scale 원복(1.0)", is_equal_approx(player._sprite.speed_scale, 1.0))

	# ── ③ _use_tool(물뿌리개) → 스윙 진입·복귀 (즉발 물주기 로직 그대로) ──
	var t_wat := Vector2i(51, 45)
	m.farm.hoe(t_wat)
	m.farm.plant(t_wat, CropCatalog.HONRYEONGCHO)
	m._can_water = 5
	_select(m, ItemCatalog.WATERING_CAN)
	m._target = t_wat
	m._use_tool()
	_check("③ 물주기 즉발 로직 성공(젖음 — 로직 불변)", m.farm.is_watered(t_wat))
	_check("③ 스윙 상태 진입", player.is_swinging())
	_check("③ water 모션 재생", String(player._sprite.animation).begins_with("water_"))
	_finish_swing(player)
	_check("③ 완료 후 워크/대기 복귀", not player.is_swinging() and String(player._sprite.animation).begins_with("walk_"))

	# ── ④ _try_harvest(맨손 수확) → 스윙 진입·복귀 (수확 로직 그대로) ──
	var t_har := Vector2i(52, 45)
	m.farm.hoe(t_har)
	m.farm.plant(t_har, CropCatalog.HONRYEONGCHO)
	var guard := 0
	while not m.farm.is_mature(t_har) and guard < 30:
		m.farm.water(t_har)
		m.farm.advance_day()
		guard += 1
	_check("④pre 작물 성숙", m.farm.is_mature(t_har))
	m._target = t_har
	var harvested_before: int = m._run_harvested
	m._try_harvest()
	_check("④ 수확 즉발 로직 성공(점수판 +1 — 로직 불변)", m._run_harvested == harvested_before + 1)
	_check("④ 스윙 상태 진입", player.is_swinging())
	_check("④ harvest 모션 재생", String(player._sprite.animation).begins_with("harvest_"))
	_finish_swing(player)
	_check("④ 완료 후 워크/대기 복귀", not player.is_swinging() and String(player._sprite.animation).begins_with("walk_"))

	# ── ⑤ _swing_for_item 매핑(낫 진입 / 곡괭이·전용 시트 없음 → 무동작 폴백) ──
	m._swing_for_item(ItemCatalog.SCYTHE)
	_check("⑤ 낫 → scythe 스윙 진입", player.is_swinging() and String(player._sprite.animation).begins_with("scythe_"))
	_finish_swing(player)
	m._swing_for_item(ItemCatalog.PICKAXE)
	_check("⑤ 곡괭이 = 전용 시트 없음 → 스윙 안 뜸(폴백)", not player.is_swinging())

	# ── ⑥ speed_factor 실효화(FarmSkill 레벨↑ → speed_scale↑ · 직접 factor 주입도 비례) ──
	m._farming_xp = 0                              # L0 → speed_factor 1.0
	m._swing_for_item(ItemCatalog.HOE)
	var scale_l0: float = player._sprite.speed_scale
	_finish_swing(player)
	m._farming_xp = 99999                          # L10 → speed_factor 0.70(더 빠름)
	m._swing_for_item(ItemCatalog.HOE)
	var scale_l10: float = player._sprite.speed_scale
	_finish_swing(player)
	_check("⑥ L0 speed_scale = 1.0", is_equal_approx(scale_l0, 1.0))
	_check("⑥ 숙련↑ → speed_scale↑(재생 빠름)", scale_l10 > scale_l0)
	# 재생 시간(= 프레임수/(fps×scale))은 숙련↑일수록 짧아진다.
	var dur_l0 := 6.0 / (CharSprite.TOOL_FPS * scale_l0)
	var dur_l10 := 6.0 / (CharSprite.TOOL_FPS * scale_l10)
	_check("⑥ 숙련↑ → 스윙 재생 시간↓", dur_l10 < dur_l0)
	# 직접 factor 주입: 0.5 → speed_scale 2.0(1/factor), 1.0 → 1.0.
	player.swing_tool("hoe", 1.0)
	var s_full: float = player._sprite.speed_scale
	_finish_swing(player)
	player.swing_tool("hoe", 0.5)
	var s_half: float = player._sprite.speed_scale
	_finish_swing(player)
	_check("⑥ factor 1.0 → speed_scale 1.0", is_equal_approx(s_full, 1.0))
	_check("⑥ factor 0.5 → speed_scale 2.0(= 1/factor)", is_equal_approx(s_half, 2.0))

	await _despawn(m)
