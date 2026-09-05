extends SceneTree
# ★[폴리시 19회차] 버그 헌트 확정분 회귀 — 배치 A(#0~#8).
#
# 렌즈: R18 diff 리뷰(#0·#1·#2) · 설명-실효 짝(#3·#4·#5) · 원장 상한 계약(#6) ·
#       도착 칸 유효성(#7·#8).
#
# 이 회차 배치 A의 태도 셋.
#   ㉠ **"한 표를 읽는다"는 선언이 아니라 재는 것이다.** #0은 R18이 «레인 배정 술어도 그 표 한 줄에
#      산다»고 커밋 본문에 적어 놓고도 두 술어가 실제로는 갈려 있던 자리다(표는 집 rect로, 걷기는
#      타일로 갈랐다). 그래서 아래 ⓐ~ⓖ는 문장을 믿지 않고 **표 전 항목을 돌며 두 답을 대조**한다.
#   ㉡ **게이트가 유일한 방어면 그 사실을 실증한다.** #1의 밑바닥(`FarmField.hoe`는 지형을 한 줄도
#      안 본다 · `_farm_aoe_tiles`는 조준 칸을 무조건 포함한다)은 그대로 두는 것이 계약이므로,
#      ②f가 게이트를 우회해 `_use_tool`을 직접 불러 **그 칸이 실제로 갈린다**는 것을 보인다 —
#      그래야 ②b의 "게이트가 닫혀 있다"가 공허하지 않다.
#   ㉢ **성역은 좌표를 옮겨 적지 않는다.** #7의 워프 칸은 RegionCatalog 표에서 파고(⑧a), 나무 폭은
#      스프라이트에서 판다(③a). 표가 움직이면 성역도 따라 움직여야 회귀가 늙지 않는다.
#
# 무엇을 보증하나(번호 = 19회차 헌트 발견 인덱스):
#   ① #0 `_road_lane_of`가 '타일 y'로 레인을 갈라, 집 rect와 문 앞 칸이 강변 문턱 양쪽으로 갈리는
#      집(주민집 8번)만 우회 표를 못 타고 강변까지 도는 ~62칸 경로가 났다(프로스티 11:00).
#   ② #1 `_orchard_dispatch_at` or-항이 괭이·씨앗 LMB까지 열어, 나무 3×3의 비-farmable 칸이
#      경작되고 밑동 안에 작물이 심겼다(프롬프트는 그 칸에 아무 안내도 안 띄웠다).
#   ③ #2 밑동↔앵커 다리·그리기 드롭이 폭 1칸만 처리해 마당 나무 **동쪽** 발치 칸이 "그림 없는 벽"
#      으로 남았다(몸은 막히는데 도끼·프롬프트·채취기 전부 0 — 서쪽 칸에서는 전부 정상).
#   ④ #3 설화 ♡2 편지가 실재 아이템 [서리동백]을 봉투에 넣었다고 말하면서 첨부가 비어 있었다.
#   ⑤ #4 채집 전문직 desc가 '모든 채집물'을 약속하는데 덤불 열매는 약초학자·채집꾼 퍼크를 전혀
#      안 탔다(같은 플레이어가 옆 빈터에서 줍는 것은 이리듐 ×2).
#   ⑥ #5 미호·바나 관계 XP 곱셈기(×1.25)가 라이브인데 화면 표면이 0이었다(`XpBoost.summary` 호출부 0).
#   ⑦ #6 알림 큐가 keep으로 가득 찬 상태에서 **평범한 한 줄이 1회성 keep 줄을 축출**했다.
#   ⑧ #7 혼의 나무 밑동을 안식 농원의 유일한 구역 워프 칸에 심을 수 있었다(제거 API 0 = 영구 봉인).
#   ⑨ #8 설치 가드 3종이 혼의 나무 밑동 칸을 몰라, 반대 방향(`_is_tree_seed_free`)만 막힌 단방향
#      가드였다 — 밑동 SOLID 칸 위에 스프링클러·업화로·결정기·레어크로우가 겹쳐 섰다.
#
# 판정: #0~#3·#5~#8 CONFIRMED(봉합) · #4 CONFIRMED(퍼크 축만 — 레벨 축 배제는 그대로).
#       REFUTED·DUP·OWNER 0건.
#
# 봉합 축(근거 전문은 커밋 본문·각 함수 머리말):
#   · #0 = `_road_lane_of`가 **문 앞 칸이면 표의 lane을 그대로** 돌려준다. 문 앞이 아닌 칸만 y
#          문턱으로 가른다(종전 갈래 보존). A*는 도입 안 함(ADR-0060 "보류" 유지).
#   · #1 = 술어를 축별로 갈라 **부르는 쪽이 고른다**(LMB=심기 축 · RMB=수확 축). R18의 취지
#          (과수 프롬프트·수확 동작)는 그대로다.
#   · #2 = `_home_tree_anchor_candidates` — 세 역매핑이 공유하는 역산 표. 폭은 스프라이트에서
#          파생하고(값 복제 0) 후보 순서가 서쪽부터라 종전 dx=0 답이 먼저 잡힌다(더하기만).
#          그리기도 같은 소스로 x를 중앙 정렬한다.
#   · #3 = `"items": [{"id": "seori_dongbaek", "n": 1}]` — mailbox.gd 머리말 계약의 이행.
#   · #4 = `_shake_bush`가 `forage_quality_floor()`·`_forage_double_drop("bush", t)`를 탄다.
#          **레벨 파생 등급(`_forage_base_quality`)은 여전히 배제**다 — 그 함수 머리말의 근거는
#          레벨 곡선에 대한 것이고, 전문직 퍼크는 L10의 한 번의 선택이라 축이 다르다.
#   · #5 = 관계 탭 effect_fn에 이어 붙인다(ADR-0008 "관계 = 명백히 우월한 가속" — 광고가 곧
#          의도된 최적 경로의 안내다). 바나 쪽 계수는 전투 XP 경로가 쓰는 그 훅에서 받는다.
#   · #6 = 앞이 전부 keep이면 **방금 민 줄부터** 본다 — 평범한 줄이면 그것을 버린다. 새 줄까지
#          keep이면 여전히 맨 앞(상한 계약 불변).
#   · #7 = `_traversal_reserved` — 워프 발동 칸·도착 칸·스폰 칸을 RegionCatalog에서 파생.
#          `_is_tree_blocked`가 그 술어를 문다(늘봄방 예정지와 같은 결의 예약).
#   · #8 = `_orchard_trunk_at` — `_tree_occupied_at`의 과수판. 배치 가드 셋에 한 줄씩(레어크로우는
#          스프링클러 상속). **밑동 한 칸만** 본다(캐노피 칸은 걸어 다닐 수 있으니 겹침이 아니다).
#
# 하중 검증(계약을 일부러 깨서 red 확인 후 원복 — 아래는 **실측 결과** 그대로다):
#   #0 `_road_lane_of`의 표 조회 루프 삭제 → ⓑ·ⓒ·ⓕ·ⓖ·ⓗ red(ⓑ가 어긋난 칸 (76,58)을 이름 ·
#      ⓕ가 2032px > 강변 레인 2016px로 남하를 잰다) ·
#   #1 LMB 게이트를 `or orchard_dispatch`로 되돌림 → ②g red · `_orchard_plant_dispatch`를
#      무조건 true로(축 좁힘 제거) → ②c red ·
#   #2 `_home_tree_anchor_candidates`의 dx 범위를 1로 → ③e·③f·③g red(③f가 동쪽 칸의 빈 종명을
#      「 — 도끼 필요」로 드러낸다) · 그리기 x 보정 삭제 → ③h red(1744 ≠ 1760px) ·
#   #3 `"items"` 행 삭제 → ④a·④b·④c red ·
#   #4 `forage_quality_floor()` → 0 · double_drop 롤 삭제 → ⑤c·⑤d·⑤e red ·
#   #5 두 effect_fn의 이어 붙임 삭제 → ⑥b·⑥c·⑥d·⑥e red ·
#   #6 새 폴백(`victim = _items.size() - 1`) 삭제 → ⑦b red(평범한 줄이 「래치 0」을 밀어낸다) ·
#   #7 `_is_tree_blocked`의 `_traversal_reserved` 행 삭제 → ⑧c·⑧d·⑧e·⑧f red ·
#   #8 세 가드의 `_orchard_trunk_at` 행 삭제 → ⑨b·⑨c·⑨d·⑨e·⑨i red.
#
# ★하중 검증에서 배운 것: **파괴가 no-op이면 초록은 아무것도 뜻하지 않는다.** #7의 첫 시도는
#   `if _traversal_reserved(t):` 다음 줄이 곧 `is_solid` 검사라고 가정한 치환이었는데 실제로는
#   그 사이에 주석 블록이 있어 치환이 조용히 실패했고, ⑧ 전체가 초록으로 남아 "하중 없음"으로
#   오독될 뻔했다. 파괴 후에는 **파괴가 실제로 먹었는지**(치환 횟수)를 먼저 확인한다.
#
# ══════════ 배치 B(#9~#17) ══════════════════════════════════════════════════
#
# 렌즈: 도착 칸 유효성(#9) · 활동 인터럽트 행렬(#10·#11) · 행사일 종결(#12·#13) ·
#       F8 재시작 잔재(#14) · 플레이어 매몰(#15·#16·#17).
#
# 이 배치의 태도 둘.
#   ㉠ **매몰 셋은 한 병이다.** #15·#16·#17이 각각 트렐리스·재스폰 debris·묘목 밑동으로 다르게
#      보이지만 원인은 하나다 — 통과 불가 칸을 세우는 창구가 **플레이어 좌표를 안 본다**. 그래서
#      술어도 하나(`_would_entrap_player`)로 두고, ⑮·⑯·⑰이 같은 술어를 서로 다른 창구에서 잰다.
#   ㉡ **"선언했다"는 "구현했다"가 아니다.** #9는 R16 주석이 «아래 배치 가드가 앞으로 막는다»고
#      적어 둔 계약인데 가드 전수에 그 좌표가 없던 자리다. ⑩은 선언을 읽지 않고 가드를 직접 태운다.
#
# 무엇을 보증하나(번호 = 19회차 헌트 발견 인덱스):
#   ⑩ #9 갱도 입구 문(24,6)·나락 아가리(32,26)를 아는 배치 가드가 없어, 그 칸에 세운 업화로가
#      [F] 사다리에서 하강을 가렸다(제련이 끝날 때까지 회수도 불가).
#   ⑪ #10·#11 릴 격투 세션 중 LMB가 게잡이통·채취기·업화로·결정기 설치로 이중 집행됐다
#      (`_use_tool` 갈래에만 있던 세션 가드가 형제 설치 갈래 넷에는 없었다).
#   ⑫ #12 더비 안내가 부스 위치를 삼도천에 없는 랜드마크("부두")로 지목했다(그 간판은 황천해의
#      것이고, 따라가면 구역 가드에 걸려 태그조차 안 붙는다).
#   ⑬ #13 비해금 테마 데이 슬롯이 날씨를 강제 평온으로 덮어, 배너도 장식도 없는 평일에 그날치
#      혼불 바람·혼우 이득만 사라졌다.
#   ⑭ #14 F8 삭제 2단 확인 래치가 모달/연출 중 감소를 멈춰, 안내는 사라졌는데 무장은 무기한
#      남았다 — 한참 뒤의 [F8] **한 번**이 곧장 삭제+재시작이었다.
#   ⑮ #15 트렐리스 작물로 자기를 4방 포위하면 탈출 동사가 0이다(늘봄방에선 영구 소프트락).
#   ⑯ #16 절기 재스폰 SOLID debris 후보에서 '플레이어가 선 칸'만 빠져 있었다.
#   ⑰ #17 묘목을 발밑 칸에 심을 수 있었다 — 제거 API가 없는 영구 SOLID 밑동.
#
# 판정: #9~#12·#14~#17 CONFIRMED(봉합) · #13 CONFIRMED(해금 주입 — 순수 갈래 기본값은 보존).
#       REFUTED·DUP·OWNER 0건. ★#17은 배치 A #7(`_traversal_reserved`)과 **겹치지 않는다**:
#       저쪽은 구역 워프·도착·스폰 칸이고 이쪽은 플레이어 좌표라 성역의 축 자체가 다르다.
#
# 봉합 축:
#   · #9  = `_f_gate_tile` — `_f_window_tile`·`_f_booth_tile`의 셋째 형제(구역·깊이 축을 직접 든다).
#   · #10·#11 = `session_lmb` 한 줄을 설치 넷 + 도구 하나가 함께 읽는다(규칙 복제 0).
#   · #12 = 랜드마크를 "강 낚시터"로 정정(배너·태그 알림 두 문구 모두 — 부스에서 가장 가까운 라벨).
#   · #13 = `Weather.weather_for_day(d, theme_open)` — 무상태는 그대로 두고 **아는 쪽이 답을 들고
#           온다**(main `_weather_on`·`_forecast_on` 단일 창구). 기본값 true = 종전 거동 보존.
#   · #14 = 래치 감소를 `_process` 맨 위(라이팅·날씨 파티클과 같은 줄)로 — "정지 주인 = 재개 주인".
#   · #15·#16·#17 = `_would_entrap_player` 하나(발밑 ∪ 마지막 4방 퇴로)를 세 창구가 읽는다.
#           #16은 `_resident_tile`까지 함께 뺀다(배치 가드가 이미 예약하던 그 표).
#
# 하중 검증(배치 B — 실측 결과 그대로):
#   #9  두 가드의 `_f_gate_tile` 행 삭제 → ⑩c·⑩d·⑩g red ·
#   #10·#11 설치 갈래 넷에서 `not session_lmb` 삭제 → ⑪a(소비처 5→1)·⑪b(4/4→0/4) red ·
#   #12 알림 문구를 "부두"로 되돌림 → ⑫b red(⑫a는 배너 쪽이라 따로 잡는다) ·
#   #13 main이 해금을 안 넘기게 되돌림 → ⑬a·⑬b red ·
#   #14 래치 감소를 조기 반환 아래로 되돌림 → ⑭a·⑭b red(⑭b가 20프레임 뒤 0.020초 잔존을 잰다) ·
#   #15 트렐리스 거절 분기 삭제 → ⑮a(3→4)·⑮b red ·
#   #16 후보 필터 삭제 → ⑯a·⑯b red · `or _resident_tile(t)`만 삭제 → ⑯c red ·
#   #17 묘목 발밑 분기 삭제 → ⑰a red.
#
# ★배치 B에서 배운 것 둘.
#   ㉠ **니들은 함수 안에서 세라.** ⑭a의 첫판은 `_line_in`(전역 첫 매치)으로 조기 반환 여섯을
#      찾았는데 `if _edit_mode:`·`if frame.is_open():`가 다른 함수에도 있어 엉뚱한 행이 잡혔고,
#      순서 비교가 조용히 무의미해졌다(`_line_in_func`로 교정).
#   ㉡ **무대가 그 갈래를 안 태우면 초록은 공허하다.** ⑯c의 첫판은 기본 무대에 후보와 겹치는
#      주민 칸이 0이라 봉합을 지워도 초록이었다 — 주민을 후보 칸에 **실제로 세운 뒤** 재도록
#      고쳤다. ⑬의 무대도 같은 이유로 "롤이 비-평온인 비해금 슬롯"으로 좁혔다.
#
# 실행: ./run_tests.sh polish_r19   (헤드리스는 반드시 game/에서 · 순차)

var _fail := 0
var _src: PackedStringArray = PackedStringArray()
var _nf_src: PackedStringArray = PackedStringArray()
var _orch_src: PackedStringArray = PackedStringArray()

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

# ── 소스 스캔 헬퍼(polish_r7~r18의 그 관례) ─────────────────────────────────
func _lines_of_file(path: String) -> PackedStringArray:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return PackedStringArray()
	return f.get_as_text().split("\n")

func _line_in(lines: PackedStringArray, needle: String) -> int:
	for i in range(lines.size()):
		if lines[i].strip_edges().begins_with("#"):
			continue
		if lines[i].contains(needle):
			return i
	return -1

func _line_in_func(lines: PackedStringArray, fn_needle: String, needle: String) -> int:
	var head := -1
	for i in range(lines.size()):
		if lines[i].begins_with(fn_needle):
			head = i
			break
	if head < 0:
		return -1
	for i in range(head + 1, lines.size()):
		if lines[i].begins_with("func ") or lines[i].begins_with("static func "):
			return -1
		if lines[i].strip_edges().begins_with("#"):
			continue
		if lines[i].contains(needle):
			return i
	return -1

func _count_in(lines: PackedStringArray, needle: String) -> int:
	var n := 0
	for line in lines:
		if String(line).strip_edges().begins_with("#"):
			continue
		if String(line).contains(needle):
			n += 1
	return n

func _initialize() -> void:
	await _run_checks()

func _run_checks() -> void:
	print("══ 폴리시 R19 회귀 — 배치 A(#0~#8) ══")
	var cleaner := SaveManager.new()
	cleaner.delete_save()
	_src = _lines_of_file("res://main.gd")
	_nf_src = _lines_of_file("res://notice_feed.gd")
	_orch_src = _lines_of_file("res://orchard.gd")
	_check("무대 전제: main(%d행)·notice_feed(%d)·orchard(%d)를 읽었다(부정 단언 공허 통과 방지)"
			% [_src.size(), _nf_src.size(), _orch_src.size()],
		_src.size() > 1000 and _nf_src.size() > 50 and _orch_src.size() > 100)

	var m: Node = await _spawn_main()
	_check("무대: main이 섰다", m != null)
	if m == null:
		quit(1)
		return
	_dismiss_dialogue(m)

	_check_door_front_lane(m)
	_check_orchard_dispatch_axes(m)
	_check_tree_foot_span(m)
	await _check_camellia_attachment(m)
	_check_bush_perks(m)
	_check_xp_boost_surface(m)
	_check_notice_keep_priority(m)
	_check_warp_tile_sanctuary(m)
	_check_orchard_trunk_guards(m)

	print("══ 폴리시 R19 회귀 — 배치 B(#9~#17) ══")
	_check_gate_tile_guard(m)
	_check_session_lmb_guard(m)
	_check_derby_landmark(m)
	_check_theme_day_weather(m)
	await _check_delete_latch_lifetime(m)
	_check_trellis_entrapment(m)
	_check_respawn_player_tile(m)
	_check_sapling_underfoot(m)

	print("══ 결과: %s (실패 %d) ══" % ["PASS" if _fail == 0 else "FAIL", _fail])
	quit(1 if _fail > 0 else 0)

# ── ① #0 문 앞 칸의 레인을 지도 표가 정한다 ─────────────────────────────────
# 공허 통과 방지: 무대(ⓐ)가 **rect와 문 앞 칸이 강변 문턱 양쪽으로 갈리는 집이 실제로 있다**를
# 먼저 세운다 — 그런 집이 없으면 두 술어가 갈려 있어도 답이 같아 ⓑ가 헛돈다.
func _check_door_front_lane(m: Node) -> void:
	print("① #0 문 앞 칸 레인 = 지도 표")
	var region: String = RegionCatalog.NARU_VILLAGE
	var spokes: Array = m._village_door_spokes()
	var zone_y: int = m.RIVERSIDE_ZONE_Y
	var straddle: Array = []          # rect와 문 앞 칸이 문턱 양쪽으로 갈리는 집
	for e in spokes:
		var rect: Rect2i = e[0]
		var front: Vector2i = Vector2i(e[1]) + Vector2i(0, 1)
		if (rect.position.y >= zone_y) != (front.y >= zone_y):
			straddle.append(e)
	_check("ⓐ 무대: 표 %d행 중 «집 rect와 문 앞 칸이 강변 문턱(y%d) 양쪽으로 갈리는» 집이 %d채 있다"
			% [spokes.size(), zone_y, straddle.size()], spokes.size() >= 11 and straddle.size() >= 1)
	if straddle.is_empty():
		return

	# ⓑ 전수 — 표 전 항목에서 문 앞 칸의 레인 = 그 행의 lane(두 술어가 한 답을 낸다).
	var lane_mismatch: Array = []
	for e in spokes:
		var front: Vector2i = Vector2i(e[1]) + Vector2i(0, 1)
		if m._road_lane_of(front, region) != int(e[2]):
			lane_mismatch.append(front)
	_check("ⓑ 표 %d행 전수 — 문 앞 칸의 `_road_lane_of` = 그 행의 lane(어긋난 칸 %s)"
			% [spokes.size(), str(lane_mismatch)], lane_mismatch.is_empty())

	# ⓒ 갈리는 집의 우회 경유점이 실제로 선다(그 표를 못 타면 빈 배열이었다).
	var st: Array = straddle[0]
	var st_rect: Rect2i = st[0]
	var st_front: Vector2i = Vector2i(st[1]) + Vector2i(0, 1)
	var st_lane: int = int(st[2])
	var detour: Array = m._house_detour(st_front, m._road_lane_of(st_front, region), region)
	_check("ⓒ 갈리는 집(rect %s · 문 앞 %s) 우회 경유점 %s — 지도가 판 옆 열(rect.end.x=%d)로 붙는다"
			% [str(st_rect), str(st_front), str(detour), st_rect.end.x],
		detour.size() == 2 and int(detour[0].x) == st_rect.end.x
		and int(detour[1].x) == st_rect.end.x and int(detour[1].y) == st_lane)

	# ⓓ 문 앞이 아닌 강변 칸은 여전히 y 문턱으로 갈린다(종전 갈래 보존 — 세레나 스테이션 결).
	var plain_river := Vector2i(30, m.RIVERSIDE_LANE_Y)
	var is_front := false
	for e in spokes:
		if Vector2i(e[1]) + Vector2i(0, 1) == plain_river:
			is_front = true
	_check("ⓓ 문 앞이 아닌 강변 칸 %s는 여전히 강변 레인(y%d)이다 — 종전 갈래 보존"
			% [str(plain_river), m.RIVERSIDE_LANE_Y],
		not is_front and m._road_lane_of(plain_river, region) == m.RIVERSIDE_LANE_Y)

	# ⓔ 라이브 — 프로스티 11:00 전환이 강변까지 남하하지 않는다(스케줄에서 두 칸을 판다).
	var r = m._resident("frosty")
	_check("ⓔ 무대: 프로스티 스케줄 2칸 이상(집 → 광장)", r != null and r.schedule.size() >= 2)
	if r != null and r.schedule.size() >= 2:
		var home_t: Vector2i = r.schedule[0]["tile"]
		var plaza_t: Vector2i = r.schedule[1]["tile"]
		var pts: PackedVector2Array = m._road_spokes(home_t, plaza_t, region)
		var max_y := 0.0
		for p in pts:
			max_y = maxf(max_y, p.y)
		var river_px := float(m.RIVERSIDE_LANE_Y * m.TILE)
		_check("ⓕ 프로스티 %s → %s 경유점 %d개 · 최남단 %.0fpx < 강변 레인 %.0fpx(강변 우회 소멸)"
				% [str(home_t), str(plaza_t), pts.size(), max_y, river_px],
			pts.size() > 0 and max_y < river_px)
		_check("ⓖ 그 집 문 앞 칸의 레인 = 메인 복도(%d) — 표와 걷기가 같은 답이다"
				% m.MAIN_CORRIDOR_Y, m._road_lane_of(home_t, region) == m.MAIN_CORRIDOR_Y)

	# ⓗ 나머지 4인(켄·미르·루카·스칼렛)의 정상 경로 불변 — 문 앞 칸이 전부 메인 복도에 붙는다.
	var main_fronts := 0
	for e in spokes:
		var front: Vector2i = Vector2i(e[1]) + Vector2i(0, 1)
		if int(e[2]) == m.MAIN_CORRIDOR_Y and m._road_lane_of(front, region) == m.MAIN_CORRIDOR_Y:
			main_fronts += 1
	var main_rows := 0
	for e in spokes:
		if int(e[2]) == m.MAIN_CORRIDOR_Y:
			main_rows += 1
	_check("ⓗ 메인 복도에 붙는 %d행이 전부 그 답을 유지한다(%d행) — 다른 집 경로 불변"
			% [main_rows, main_fronts], main_rows > 0 and main_fronts == main_rows)

# ── ② #1 과수 디스패치가 든 물건 축으로 갈린다(라이브) ───────────────────────
func _check_orchard_dispatch_axes(m: Node) -> void:
	print("② #1 과수 디스패치 축 분리")
	m._indoor = ""
	if m._region != RegionCatalog.HOME:
		m._rebuild_region(RegionCatalog.HOME)
	var zone: Rect2i = m.ORCHARD_ZONE_RECT
	var anchor := Vector2i(-1, -1)
	for y in range(zone.position.y + 1, zone.end.y - 1):
		for x in range(zone.position.x + 1, zone.end.x - 1):
			var t := Vector2i(x, y)
			if m._is_farmable(t):
				continue                     # 밭 흙이면 기존 게이트가 이미 통과시킨다(무대 부적격)
			if m.orchard.can_plant(t, m._is_tree_blocked):
				anchor = t
				break
		if anchor.x >= 0:
			break
	_check("②a 무대: 과수원 존 안에 «밭 흙이 아니고 3×3이 비어 있는» 앵커가 있다 %s" % str(anchor),
		anchor.x >= 0)
	if anchor.x < 0:
		return

	var orchard_snap: Dictionary = m.orchard.to_save()
	var farm_snap: Dictionary = m.farm.to_save()
	var fruit: String = FruitTreeCatalog.ids()[0]
	var sapling: String = ItemCatalog.sapling_id(fruit)
	var planted: bool = m.orchard.plant(anchor, fruit, m.clock.day, m._is_tree_blocked)
	var canopy := anchor + Vector2i(-1, -1)
	m._target = canopy
	m._target_valid = m._is_farmable(canopy)
	_check("②b 무대: 나무를 심었고(%s) 캐노피 칸 %s는 `_target_valid`가 **거짓**이다(밭 흙 아님)"
			% [str(planted), str(canopy)], planted and not m._target_valid)

	# 든 것이 괭이면 심기 축이 닫힌다 — LMB 게이트가 이 칸을 안 연다.
	m.inventory.slots[m.inventory.selected_index] = {"id": ItemCatalog.HOE, "count": 1, "quality": 0}
	var hoe_plant: bool = m._orchard_plant_dispatch()
	# 씨앗도 같다(밑동 안 파종 경로).
	var seed_id: String = ItemCatalog.seed_id(CropCatalog.ids()[0])
	m.inventory.slots[m.inventory.selected_index] = {"id": seed_id, "count": 1, "quality": 0}
	var seed_plant: bool = m._orchard_plant_dispatch()
	_check("②c 든 것이 괭이(%s)·씨앗(%s)이면 심기 축이 닫힌다 — LMB 게이트가 이 칸을 안 연다"
			% [str(hoe_plant), str(seed_plant)], not hoe_plant and not seed_plant)

	# 든 것이 묘목이면 심기 축이 열린다(R18 취지 보존).
	m.inventory.slots[m.inventory.selected_index] = {"id": sapling, "count": 1, "quality": 0}
	_check("②d 든 것이 묘목(%s)이면 심기 축이 열린다 — R18이 연 그 창구는 그대로다" % sapling,
		m._orchard_plant_dispatch()
		and ItemCatalog.category_of(sapling) == ItemCatalog.CAT_SAPLING)

	# 수확 축은 든 물건과 무관하게 풋프린트에서 열린다(RMB 계약 보존).
	m.inventory.slots[m.inventory.selected_index] = {"id": ItemCatalog.HOE, "count": 1, "quality": 0}
	_check("②e 수확 축은 든 물건과 무관하게 풋프린트 칸 %s에서 열린다(RMB 계약 불변)" % str(canopy),
		m._orchard_harvest_dispatch_at(canopy) and m._orchard_harvest_dispatch_at(anchor))

	# ★ 게이트가 **유일한 방어**임을 실증한다: 우회해서 부르면 그 칸이 실제로 갈린다.
	var tilled_before: bool = m._field_at(canopy).is_tilled(canopy)
	m._target = canopy
	m._use_tool()
	var tilled_after: bool = m._field_at(canopy).is_tilled(canopy)
	_check("②f 하중: 게이트를 우회해 괭이를 쓰면 그 칸이 실제로 갈린다(%s → %s) — 게이트가 유일한 방어다"
			% [str(tilled_before), str(tilled_after)], not tilled_before and tilled_after)
	m.farm.load_save(farm_snap)          # 무대 원복 — 밭 원장을 되돌린다

	# 소스 — 두 게이트가 서로 다른 술어를 문다.
	var g_use := _line_in(_src, "or orchard_plant_dispatch) \\")
	var g_harv := _line_in(_src, "(_target_valid or pot_dispatch or orchard_dispatch)")
	var harv_bind := _line_in(_src, "var orchard_dispatch := _orchard_harvest_dispatch_at(_target)")
	_check("②g 두 게이트가 각자의 축을 문다 — LMB 심기 축(main %d행) · RMB 수확 축(%d행 · 바인딩 %d행)"
			% [g_use + 1, g_harv + 1, harv_bind + 1],
		g_use >= 0 and g_harv >= 0 and harv_bind >= 0)
	m.orchard.load_save(orchard_snap)
	m.inventory.slots[m.inventory.selected_index] = null

# ── ③ #2 마당 나무 발치가 **두 칸 다** 같은 나무다(라이브) ──────────────────
func _check_tree_foot_span(m: Node) -> void:
	print("③ #2 마당 나무 발치 2칸")
	m._indoor = ""
	if m._region != RegionCatalog.HOME:
		m._rebuild_region(RegionCatalog.HOME)
	var span: int = int(m.PROP_TREE_A.get_size().x) / int(m.TILE)
	var drop_tiles: int = int(m._tapper_home_drop()) / int(m.TILE)
	_check("③a 무대: 손저작 나무 프롭 = 가로 %d칸 · 세로 보정 %d칸(폭이 1이면 이 결함 자체가 없다)"
			% [span, drop_tiles], span >= 2 and drop_tiles > 0)
	if span < 2 or drop_tiles <= 0:
		return
	var anchors: Array = m._home_tree_anchors()
	var anchor := Vector2i(-1, -1)
	for t in anchors:
		var a: Vector2i = t
		if m.tree_ledger.is_occupied(RegionCatalog.HOME, a) \
				and not m.tree_ledger.is_occupied(RegionCatalog.HOME, a + Vector2i(0, drop_tiles)) \
				and not m.tree_ledger.is_occupied(RegionCatalog.HOME, a + Vector2i(1, drop_tiles)):
			anchor = a
			break
	_check("③b 무대: 원장이 아는 손저작 앵커(%d그루) 중 발치 두 칸이 원장에 **없는** 나무를 골랐다 %s"
			% [anchors.size(), str(anchor)], anchor.x >= 0)
	if anchor.x < 0:
		return
	var west := anchor + Vector2i(0, drop_tiles)
	var east := anchor + Vector2i(1, drop_tiles)

	# 몸이 막힌다는 사실부터 — 프롭 충돌이 두 칸을 통째로 덮는다(그래서 "그림 없는 벽"이었다).
	var west_blocked := _prop_covers(m, west)
	var east_blocked := _prop_covers(m, east)
	_check("③c 무대: 프롭 충돌이 발치 두 칸을 다 덮는다 — 서 %s / 동 %s"
			% [str(west_blocked), str(east_blocked)], west_blocked and east_blocked)

	_check("③d 서쪽 발치 %s → 앵커 %s(R18 계약 보존)" % [str(west), str(m._home_tree_ledger_tile(west))],
		m._home_tree_ledger_tile(west) == anchor)
	_check("③e **동쪽** 발치 %s → 앵커 %s(이번 봉합 — 종전엔 항등이라 도끼도 프롬프트도 0이었다)"
			% [str(east), str(m._home_tree_ledger_tile(east))],
		m._home_tree_ledger_tile(east) == anchor)
	var w_prompt: String = m._tree_prompt(m._home_tree_ledger_tile(west))
	var e_prompt: String = m._tree_prompt(m._home_tree_ledger_tile(east))
	_check("③f 두 칸의 프롬프트가 같다 — 서「%s」/ 동「%s」" % [w_prompt, e_prompt],
		w_prompt != "" and w_prompt == e_prompt)
	# 채취기 두 축도 같은 표를 탄다(세 역매핑이 한 함수를 공유한다).
	var mature: bool = m.tree_ledger.is_mature(RegionCatalog.HOME, anchor)
	_check("③g 채취기 설치 축도 동쪽 발치를 앵커로 되돌린다(성숙 %s · %s)"
			% [str(mature), str(m._tapper_place_tile(east))],
		(m._tapper_place_tile(east) == anchor) if mature else (m._tapper_place_tile(east) == east))

	# 그리기 원점이 트렁크 중앙에 선다(충돌 rect의 x 중심과 같은 값 — 소스가 하나다).
	var px: Vector2 = m._tree_ledger_draw_px(anchor)
	var draw_center := px.x + float(m.TILE) * 0.5
	var trunk_center: float = float(anchor.x * m.TILE) + m.PROP_TREE_A.get_size().x * 0.5
	_check("③h 그리기 중심 %.0fpx = 트렁크(충돌) 중심 %.0fpx — 그루터기·이끼가 반 칸 서쪽으로 안 치우친다"
			% [draw_center, trunk_center], is_equal_approx(draw_center, trunk_center))
	_check("③i 세로는 R18 그대로 밑동 행이다(%.0fpx = 앵커 + 보정 %.0fpx)"
			% [px.y, float(anchor.y * m.TILE) + m._tapper_home_drop()],
		is_equal_approx(px.y, float(anchor.y * m.TILE) + m._tapper_home_drop()))
	# 보정이 0인 자리는 그대로다(회수 가능한 것을 안 뺀다).
	var free := Vector2i(1, 1)
	_check("③j 손저작 앵커가 아닌 칸은 항등이다 — 그리기 %s · 역매핑 %s"
			% [str(m._tree_ledger_draw_px(free)), str(m._home_tree_ledger_tile(free))],
		m._tree_ledger_draw_px(free) == Vector2(free.x * m.TILE, free.y * m.TILE)
		and m._home_tree_ledger_tile(free) == free)

# 프롭 충돌체가 이 칸의 중심을 덮는가(라이브 충돌 노드 순회 — "몸이 막힌다"의 근거).
func _prop_covers(m: Node, t: Vector2i) -> bool:
	if m._prop_body == null:
		return false
	var c := Vector2(t.x * m.TILE + m.TILE * 0.5, t.y * m.TILE + m.TILE * 0.5)
	for child in m._prop_body.get_children():
		if not (child is CollisionShape2D):
			continue
		var cs: CollisionShape2D = child
		if not (cs.shape is RectangleShape2D):
			continue
		var sz: Vector2 = (cs.shape as RectangleShape2D).size
		if Rect2(cs.position - sz * 0.5, sz).has_point(c):
			return true
	return false

# ── ④ #3 설화 ♡2 편지가 말한 꽃이 실제로 백팩에 들어온다(라이브) ────────────
func _check_camellia_attachment(m: Node) -> void:
	print("④ #3 서리동백 첨부")
	var lid := "seolhwa_gate2_camellia"
	var items: Array = Mailbox.attachment_items_of(lid)
	_check("④a 첨부 = 서리동백 1개(%s)" % str(items),
		items.size() == 1 and String(items[0]["id"]) == ItemCatalog.SEORI_DONGBAEK
		and int(items[0]["n"]) == 1)
	var body: PackedStringArray = Mailbox.lines_of(lid)
	var flower_ko := ItemCatalog.name_of(ItemCatalog.SEORI_DONGBAEK)
	var says := body.size() > 0 and body[0].contains(flower_ko)
	_check("④b 본문 첫 줄이 그 아이템 이름(%s)을 그대로 말한다 — 설명과 첨부가 같은 물건이다"
			% flower_ko, says and Mailbox.has_attachment(lid))

	# 라이브 — 미독을 전부 소진한 뒤 이 통만 배달·열람해 백팩 증분을 잰다.
	var guard := 0
	while m.mailbox.next_unread() != "" and guard < 60:
		m.mailbox.mark_read(m.mailbox.next_unread())
		guard += 1
	m.mailbox.send(lid)
	m.mailbox.advance_day()
	var before: int = m.inventory.count_of(ItemCatalog.SEORI_DONGBAEK)
	_check("④ 무대: 그 편지가 미독으로 도착했다(%s)" % m.mailbox.next_unread(),
		m.mailbox.next_unread() == lid)
	m._read_next_letter()
	await process_frame
	_dismiss_dialogue(m)
	_check("④c 읽으면 백팩에 실제로 들어온다 — %d → %d개"
			% [before, m.inventory.count_of(ItemCatalog.SEORI_DONGBAEK)],
		m.inventory.count_of(ItemCatalog.SEORI_DONGBAEK) == before + 1)
	_check("④d 서리동백은 등급을 싣는 채집물이다(가격이 등급에 곱해지는 품목 — 빈 첨부가 아니라 실물)",
		ItemCatalog.carries_quality(ItemCatalog.SEORI_DONGBAEK))

# ── ⑤ #4 덤불 흔들기가 채집 전문직 퍼크를 탄다(라이브) ──────────────────────
func _check_bush_perks(m: Node) -> void:
	print("⑤ #4 덤불 열매 ↔ 채집 퍼크")
	var forest: String = RegionCatalog.JEOSEUNG_FOREST
	if m._region != forest:
		m._rebuild_region(forest)
	m._indoor = ""
	m.clock.day = 16                                   # 피안절 16일 = 넋딸기 창 안
	var tiles: Array = m.bush_tiles_for(forest)
	_check("⑤a 무대: 저승 숲 덤불 %d그루 · 넋딸기는 등급을 싣는 품목이다"
			% tiles.size(),
		tiles.size() >= 2 and ItemCatalog.carries_quality(ItemCatalog.NEOK_DALGI))
	if tiles.size() < 2:
		return
	var prof_snap: Dictionary = m._professions.duplicate(true)
	var xp_snap: int = m._foraging_xp

	# ㉠ 퍼크 0 = 종전 거동 그대로(일반 등급 · 롤 자체가 없다).
	m._professions = {}
	m._foraging_xp = 0
	var t0: Vector2i = tiles[0]
	m.berry_bushes.set_berry(forest, t0, true)
	m._target = t0
	var q_plain := _shake_and_quality(m, forest, t0)
	_check("⑤b 퍼크 0 — 일반 등급(%d)이고 더블드랍 롤 자체가 없다(종전 거동 보존)" % q_plain,
		q_plain == 0 and not m._forage_double_drop("bush", t0))

	# ㉡ 약초학자 = 이리듐 하한이 실제 슬롯에 실린다.
	m._professions = {ProfessionCatalog.FORAGING: {5: "gatherer", 10: "botanist"}}
	var floor_q: int = m.forage_quality_floor()
	var t1: Vector2i = tiles[1]
	var q_perk := _shake_and_quality(m, forest, t1)
	_check("⑤c 약초학자 — 덤불 열매가 하한 등급(%d)으로 들어온다(실측 %d · desc «모든 채집물»)"
			% [floor_q, q_perk], floor_q > 0 and q_perk == floor_q)

	# ㉢ 채집꾼 = 롤이 참인 칸에서 수량이 2배다. 시드가 (창구·날·구역·칸) 결정적이라 **롤이 참인
	#    (날, 칸)을 찾아** 잰다 — 확률을 흔들지 않고 그 갈래를 정확히 태우는 유일한 길이다.
	var hit := Vector2i(-9999, -9999)
	var hit_day := -1
	for d in range(1, GameClock.DAYS_PER_SEASON * 4 + 1):
		if not BerryBushes.in_window(d):
			continue
		m.clock.day = d
		for t in tiles:
			if m._forage_double_drop("bush", t):
				hit = t
				hit_day = d
				break
		if hit_day > 0:
			break
	_check("⑤ 무대: 더블드랍 롤이 참인 (날, 칸) 조합을 찾았다 — %d일 %s"
			% [hit_day, str(hit)], hit_day > 0)
	if hit_day > 0:
		m.clock.day = hit_day
		var berry_id: String = BerryBushes.berry_for_day(hit_day)
		var lvl: int = m._skill_level(ProfessionCatalog.FORAGING)
		var base_n: int = ForageSkill.bush_yield(lvl)
		m.berry_bushes.set_berry(forest, hit, true)
		m._target = hit
		var got_before: int = m.inventory.count_of(berry_id)
		m._shake_bush(hit)
		var got: int = m.inventory.count_of(berry_id) - got_before
		_check("⑤d 채집꾼 — 롤이 참인 칸 %s에서 %s ×%d(기본 %d의 2배 — desc «20%% 확률 2배»)"
				% [str(hit), ItemCatalog.name_of(berry_id), got, base_n], got == base_n * 2)

	# 소스 — 세 줍기 창구와 **같은 두 술어**를 부른다(규칙 복제 0).
	var q_line := _line_in_func(_src, "func _shake_bush", "forage_quality_floor()")
	var d_line := _line_in_func(_src, "func _shake_bush", "_forage_double_drop(\"bush\"")
	var base_line := _line_in_func(_src, "func _shake_bush", "_forage_base_quality(")
	_check("⑤e 덤불 창구가 퍼크 두 축을 부른다(하한 %d행 · 더블드랍 %d행) — 레벨 파생 등급은 여전히 배제(%d)"
			% [q_line + 1, d_line + 1, base_line], q_line >= 0 and d_line >= 0 and base_line < 0)
	m._professions = prof_snap
	m._foraging_xp = xp_snap

# 덤불 한 번 흔들고 그 열매가 들어간 슬롯의 등급을 돌려준다(없으면 -1).
func _shake_and_quality(m: Node, region: String, t: Vector2i) -> int:
	m.berry_bushes.set_berry(region, t, true)
	m._target = t
	m._shake_bush(t)
	# 등급이 갈리면 슬롯도 갈리므로 **최고 등급 슬롯**을 본다(앞선 무대가 남긴 일반 등급 스택 방지).
	var best := -1
	for i in range(m.inventory.slots.size()):
		if m.inventory.id_at(i) == ItemCatalog.NEOK_DALGI:
			best = maxi(best, int(m.inventory.slots[i].get("quality", 0)))
	return best

# ── ⑥ #5 관계 XP 곱셈기가 관계 탭에 뜬다(그리기 경로를 태운다) ──────────────
func _check_xp_boost_surface(m: Node) -> void:
	print("⑥ #5 XP 곱셈기 표면")
	var r_miho = m._resident("miho")
	var r_bana = m._resident("bana")
	_check("⑥ 무대: 미호·바나 관계 트랙이 있고 효과 줄이 붙어 있다",
		r_miho != null and r_bana != null
		and r_miho.effect_fn.is_valid() and r_bana.effect_fn.is_valid())
	if r_miho == null or r_bana == null:
		return
	var miho_saved: int = r_miho.affinity.points
	var bana_saved: int = r_bana.affinity.points

	# ♡0 — 등속은 광고하지 않는다(여우불이 accel 0을 감추는 그 규율).
	r_miho.affinity.points = 0
	r_miho.affinity.stage = r_miho.affinity.points_hearts()
	var flat_line: String = String(r_miho.effect_fn.call())
	_check("⑥a ♡0 — 등속(×1.00)은 안 붙는다: 「%s」" % flat_line, not flat_line.contains("숙련 ×"))

	# ♡MAX — 실효 계수와 **같은 숫자**가 뜬다.
	r_miho.affinity.points = Affinity.MAX_POINTS
	r_miho.affinity.stage = r_miho.affinity.points_hearts()
	r_bana.affinity.points = Affinity.MAX_POINTS
	r_bana.affinity.stage = r_bana.affinity.points_hearts()
	var want_miho := "×%.2f" % XpBoost.mult(r_miho.affinity.hearts())
	var want_bana := "×%.2f" % m.narak_bana_xp_mult()
	var miho_line: String = String(r_miho.effect_fn.call())
	var bana_line: String = String(r_bana.effect_fn.call())
	_check("⑥b 미호 ♡%d 줄에 농사 숙련 %s가 뜬다 — 「%s」"
			% [r_miho.affinity.hearts(), want_miho, miho_line],
		miho_line.contains("숙련 " + want_miho) and miho_line.contains("여우불"))
	_check("⑥c 바나 ♡%d 줄에 나락 전투 숙련 %s가 뜬다(계수는 전투 XP 경로가 쓰는 그 훅) — 「%s」"
			% [r_bana.affinity.hearts(), want_bana, bana_line],
		bana_line.contains("숙련 " + want_bana) and bana_line.contains("바나 수호"))

	# 그리기 경로 — 관계 탭 레이아웃이 그 줄을 실제로 들고, 말줄임에도 살아남는다.
	var frame = m.frame
	_check("⑥ 무대: 관계 탭 프레임(InventoryFrame)을 찾았다", frame != null)
	if frame == null:
		r_miho.affinity.points = miho_saved
		r_bana.affinity.points = bana_saved
		return
	frame.context = InventoryFrame.CTX_MENU
	frame.menu_tab = InventoryFrame.TAB_REL
	frame.set_hearts(m._heart_rows())
	var rows: Array = frame._rel_layout()
	var miho_eff := ""
	var idx := 0
	for r in m._residents:
		if r.affinity == null:
			continue
		if r.id == "miho":
			break
		idx += 1
	for row in rows:
		if int(row["i"]) == idx:
			miho_eff = String(row["effect"])
	_check("⑥d 그리기 레이아웃(`_rel_layout`)이 그 줄을 든다 — 미호 행 「%s」" % miho_eff,
		miho_eff.contains("숙련 " + want_miho))
	# ★[폴리시 R15 규약] 표시 단언은 말줄임까지 태운다 — 길어진 줄이 소리 없이 잘리면 안 된다.
	var panel: Rect2 = frame._panel_rect()
	var eff_max: float = panel.size.x - InventoryFrame.PAD * 2.0 - 12.0
	var shown := HanjiUi.elide(miho_eff, 12, eff_max)
	_check("⑥e 말줄임(폭 %.0fpx) 뒤에도 그 숫자가 남는다 — 「%s」" % [eff_max, shown],
		shown.contains("숙련 " + want_miho))
	r_miho.affinity.points = miho_saved
	r_miho.affinity.stage = r_miho.affinity.points_hearts()
	r_bana.affinity.points = bana_saved
	r_bana.affinity.stage = r_bana.affinity.points_hearts()

# ── ⑦ #6 keep 줄이 평범한 알림에 안 밀린다(라이브) ──────────────────────────
func _check_notice_keep_priority(m: Node) -> void:
	print("⑦ #6 keep 축출 우선순위")
	var nf = m.notice_feed
	var cap: int = nf.MAX_ITEMS
	nf._items.clear()
	for i in range(cap):
		nf.push("래치 %d" % i, 5.0, false, null, false, Color(0, 0, 0, 0), true)
	var all_keep: bool = nf._items.size() == cap
	for it in nf._items:
		if not bool(it.get("keep", false)):
			all_keep = false
	_check("⑦a 무대: 큐가 MAX_ITEMS(%d) 전량 keep으로 찼다(하루 전환 한 프레임의 그 상태)" % cap,
		all_keep)

	nf.push("평범한 정산 한 줄", 5.0)
	var survivors: Array = []
	for it in nf._items:
		survivors.append(String(it["text"]))
	var kept_all := true
	for i in range(cap):
		if not survivors.has("래치 %d" % i):
			kept_all = false
	_check("⑦b 평범한 줄이 keep을 못 밀어낸다 — 남은 줄 %s" % str(survivors),
		kept_all and not survivors.has("평범한 정산 한 줄"))
	_check("⑦c 상한 계약 불변(%d ≤ %d)" % [nf._items.size(), cap], nf._items.size() <= cap)

	# 새 줄까지 keep이면 여전히 맨 앞이 나간다(전부 keep = 불가피 — 상한이 우선).
	nf.push("새 래치", 5.0, false, null, false, Color(0, 0, 0, 0), true)
	var texts: Array = []
	for it in nf._items:
		texts.append(String(it["text"]))
	_check("⑦d 새 줄도 keep이면 맨 앞이 나간다(불가피) — %s" % str(texts),
		texts.has("새 래치") and not texts.has("래치 0") and nf._items.size() == cap)

	# 하루 전환 한 훅이 실제로 keep 줄을 여럿 민다는 근거(이 무대가 가상이 아니다).
	var keeps := 0
	for needle in ["_notice(\"나라카 바 마감", "notice_feed.push(\"명부 도감 완주"]:
		if _line_in(_src, needle) >= 0:
			keeps += 1
	_check("⑦e 근거: 하루 전환이 미는 keep 줄 창구를 %d개 이상 확인했다(밤 바 마감·도감 트로피)"
			% keeps, keeps >= 2)
	nf._items.clear()

# ── ⑧ #7 구역 워프 칸은 나무에도 성역이다(라이브) ───────────────────────────
func _check_warp_tile_sanctuary(m: Node) -> void:
	print("⑧ #7 워프 칸 심기 봉인")
	m._indoor = ""
	if m._region != RegionCatalog.HOME:
		m._rebuild_region(RegionCatalog.HOME)
	var warps: Array = RegionCatalog.warps_of(RegionCatalog.HOME)
	var warp := Vector2i(-9999, -9999)
	for w in warps:
		if w["at"] != RegionCatalog.TILE_TBD:
			warp = Vector2i(w["at"])
			break
	_check("⑧a 무대: 안식 농원의 워프 발동 칸을 표에서 팠다 %s(출구 %d개 — 좌표 복제 0)"
			% [str(warp), warps.size()], warp.x > -9999 and warps.size() >= 1)
	if warp.x <= -9999:
		return
	# 종전 가드가 왜 못 잡았나 — 그 칸은 PATH라 비-SOLID다.
	_check("⑧b 무대: 그 칸은 비-SOLID(길)라 `is_solid` 가드에 안 걸린다 — 종전 봉인의 통로",
		not m.is_solid(m._grid[warp.y][warp.x]))
	_check("⑧c `_is_tree_blocked`가 그 칸을 막는다", m._is_tree_blocked(warp))
	_check("⑧d `orchard.can_plant`도 막고 `plant`가 실패한다(밑동 = 그 칸)",
		not m.orchard.can_plant(warp, m._is_tree_blocked)
		and not m.orchard.plant(warp, FruitTreeCatalog.ids()[0], m.clock.day, m._is_tree_blocked))
	# 9칸 전수 평가라 이웃 앵커도 막힌다(캐노피가 출구를 덮지 않는다).
	# 이웃 앵커 — **자기 칸은 멀쩡한데** 풋프린트가 워프 칸을 덮어 막히는 자리를 찾는다.
	#   (77,32)은 마을에서 들어오는 **도착 칸**이라 그 자체가 성역이다(표에서 파생 — 무대 부적격).
	var neighbor := Vector2i(-9999, -9999)
	for d in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, -1), Vector2i(-1, 1)]:
		var cand: Vector2i = warp + d
		if not m._traversal_reserved(cand) and not m._is_tree_blocked(cand):
			neighbor = cand
			break
	_check("⑧e 이웃 앵커 %s은 그 칸 자체가 성역도 막힌 칸도 아닌데 심기가 막힌다 — 3×3 풋프린트가 워프 칸을 덮기 때문(9칸 전수 평가)"
			% str(neighbor),
		neighbor.x > -9999 and Orchard.footprint_of(neighbor).has(warp)
		and not m.orchard.can_plant(neighbor, m._is_tree_blocked))
	# 스폰 칸·도착 칸도 같은 성역이다(표에서 파생).
	var spawn_t: Vector2i = RegionCatalog.spawn_of(RegionCatalog.HOME)
	_check("⑧f 스폰 칸 %s도 성역이다(도착이 밑동에 막히지 않는다)" % str(spawn_t),
		m._traversal_reserved(spawn_t) and m._is_tree_blocked(spawn_t))
	# 과잉이 아니다 — 성역 아닌 칸은 여전히 심긴다.
	var ok_anchor := Vector2i(-1, -1)
	var zone: Rect2i = m.ORCHARD_ZONE_RECT
	for y in range(zone.position.y + 1, zone.end.y - 1):
		for x in range(zone.position.x + 1, zone.end.x - 1):
			var t := Vector2i(x, y)
			if not m._traversal_reserved(t) and m.orchard.can_plant(t, m._is_tree_blocked):
				ok_anchor = t
				break
		if ok_anchor.x >= 0:
			break
	_check("⑧g 성역이 아닌 칸 %s은 여전히 심긴다(가드가 과잉이 아니다)" % str(ok_anchor),
		ok_anchor.x >= 0)
	# 봉인이 왜 영구인가 — 워프는 그 칸에 **서야만** 발동하고 orchard엔 제거 창구가 0이다.
	var stand_only := _line_in_func(_src, "func _maybe_warp_edge", "t != w[\"at\"]")
	var removers: Array = []
	for line in _orch_src:
		var s := String(line).strip_edges()
		if not s.begins_with("func "):
			continue
		if s.contains("remove") or s.contains("erase") or s.contains("uproot") or s.contains("chop"):
			removers.append(s)
	_check("⑧h 근거: 워프는 그 칸에 서야만 발동하고(main %d행) orchard의 제거 창구가 0이다(%s) — 되돌릴 길이 없다"
			% [stand_only + 1, str(removers)], stand_only >= 0 and removers.is_empty())

# ── ⑨ #8 설치 가드 3종이 밑동 칸을 안다(라이브) ─────────────────────────────
func _check_orchard_trunk_guards(m: Node) -> void:
	print("⑨ #8 밑동 위 설치 금지")
	m._indoor = ""
	if m._region != RegionCatalog.HOME:
		m._rebuild_region(RegionCatalog.HOME)
	var orchard_snap: Dictionary = m.orchard.to_save()
	# 무대: **설치가 원래 되던 빈 칸**을 고른다 — 안 그러면 다른 가드가 막아 ⑨b가 헛돈다.
	var anchor := Vector2i(-1, -1)
	var zone: Rect2i = m.ORCHARD_ZONE_RECT
	for y in range(zone.position.y + 1, zone.end.y - 1):
		for x in range(zone.position.x + 1, zone.end.x - 1):
			var t := Vector2i(x, y)
			if m._can_place_sprinkler(t) and m._can_place_furnace(t) and m._can_place_crystalarium(t) \
					and m.orchard.can_plant(t, m._is_tree_blocked):
				anchor = t
				break
		if anchor.x >= 0:
			break
	_check("⑨a 무대: 설치 셋이 **원래 되던** 빈 칸이자 나무를 심을 수 있는 칸 %s" % str(anchor),
		anchor.x >= 0)
	if anchor.x < 0:
		return
	_check("⑨ 무대: 그 칸에 혼의 나무를 심었다",
		m.orchard.plant(anchor, FruitTreeCatalog.ids()[0], m.clock.day, m._is_tree_blocked))
	# 그 칸에 이미 놓인 스프링클러는 나무가 서도 회수 가능해야 한다(새 배치만 막는다).
	# ★[폴리시 R23 #19] 순서가 뒤집혔다 — 이제 `_is_tree_blocked`가 `_installation_at`을 물어
	#   **설치물 위에는 애초에 못 심으므로**(그쪽이 유일하게 비가역인 방향이라 막았다) 「먼저 설치
	#   → 그 위에 심기」는 성립하지 않는다. 그 상태가 남아 있을 수 있는 것은 가드 이전 구세이브뿐이고,
	#   ⑨h가 재는 것도 정확히 그 구세이브의 탈출구다. 그래서 나무를 먼저 세우고, 스프링클러는
	#   배치 가드를 지나지 않는 **원장 직행**으로 얹어 그 옛 상태를 재현한다.
	var canopy := anchor + Vector2i(1, 0)
	var pre_placed := false
	if not m._sprinkler_at(canopy):
		m.sprinkler._tiles[canopy] = Sprinkler.TIER_1
		pre_placed = m._sprinkler_at(canopy)
	_check("⑨b 스프링클러가 밑동 칸에 못 선다", not m._can_place_sprinkler(anchor))
	_check("⑨c 업화로가 밑동 칸에 못 선다", not m._can_place_furnace(anchor))
	_check("⑨d 결정기가 밑동 칸에 못 선다", not m._can_place_crystalarium(anchor))
	_check("⑨e 레어크로우도 못 선다(스프링클러 규칙 상속 — 한 술어가 넷을 막는다)",
		not m._can_place_rarecrow(anchor))
	_check("⑨f 반대 방향은 이미 막혀 있었다 — `_is_tree_seed_free`(자체 파종)도 밑동 칸을 거절한다",
		not m._is_tree_seed_free(RegionCatalog.HOME, anchor, {}))
	# 밑동 **한 칸만** 막는다 — 캐노피 칸은 걸어 다닐 수 있으니 겹침이 아니다.
	var free_canopy := Vector2i(-9999, -9999)
	for ft in Orchard.footprint_of(anchor):
		if ft != anchor and m._can_place_sprinkler(ft):
			free_canopy = ft
			break
	_check("⑨g 캐노피 칸 %s은 여전히 설치된다(밑동 한 칸만 성역 — 가드가 과잉이 아니다)"
			% str(free_canopy), free_canopy.x > -9999)
	# 이미 놓인 것은 회수 가능(새 배치만 막고 놓인 것은 걷는다 — R15/R17 규율).
	if pre_placed:
		_check("⑨h 나무가 선 뒤에도 **이미 놓인** 스프링클러 %s는 원장에 남아 회수 갈래가 산다"
				% str(canopy), m._sprinkler_at(canopy))
		m.sprinkler.remove(canopy)
	# 소스 — 세 가드가 같은 술어 이름을 문다(규칙 복제 0).
	var guards := 0
	for fn in ["func _can_place_sprinkler", "func _can_place_furnace", "func _can_place_crystalarium"]:
		if _line_in_func(_src, fn, "_orchard_trunk_at(t)") >= 0:
			guards += 1
	_check("⑨i 배치 가드 3종이 전부 `_orchard_trunk_at`를 문다(%d/3 — 레어크로우는 상속)" % guards,
		guards == 3)
	m.orchard.load_save(orchard_snap)

# ══════════ 배치 B(#9~#17) ══════════════════════════════════════════════════

# ── ⑩ #9 지하 진입 문 칸에 기계를 못 세운다(라이브) ─────────────────────────
func _check_gate_tile_guard(m: Node) -> void:
	print("⑩ #9 갱도 문·나락 아가리 배치 가드")
	m._indoor = ""
	m._mine_floor = 0
	m._narak_depth = 0
	if m._region != RegionCatalog.EOPHWA_MINE:
		m._rebuild_region(RegionCatalog.EOPHWA_MINE)
	var door: Vector2i = m.DUNGEON_GATE_DOOR
	# 종전 가드가 왜 못 잡았나 — 문 칸은 PATH(비-SOLID)이고 기존 [F] 좌표 술어 둘은 무대가 갈린다.
	_check("⑩a 무대: 갱도 입구 문 %s은 비-SOLID(길)이고 기존 [F] 좌표 술어 둘 다 false다(창구 %s·부스 %s)"
			% [str(door), str(m._f_window_tile(door)), str(m._f_booth_tile(door))],
		not m.is_solid(m._grid[door.y][door.x])
		and not m._f_window_tile(door) and not m._f_booth_tile(door))
	_check("⑩b `_f_gate_tile`이 그 칸을 안다", m._f_gate_tile(door))
	_check("⑩c 업화로가 문 칸에 못 선다", not m._can_place_furnace(door))
	_check("⑩d 결정기가 문 칸에 못 선다", not m._can_place_crystalarium(door))
	# 과잉이 아니다 — 문이 아닌 이웃 빈 칸에는 여전히 선다.
	var near := Vector2i(-9999, -9999)
	for d in [Vector2i(0, 1), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(1, 1), Vector2i(-1, 1)]:
		var cand: Vector2i = door + d
		if m._can_place_furnace(cand):
			near = cand
			break
	_check("⑩e 문이 아닌 이웃 칸 %s에는 여전히 선다(가드가 과잉이 아니다)" % str(near),
		near.x > -9999)
	# 층 안에서는 같은 좌표라도 성역이 아니다(무대 축을 술어가 직접 든다).
	m._mine_floor = 1
	var in_floor: bool = m._f_gate_tile(door)
	m._mine_floor = 0
	_check("⑩f 층 안(`_mine_floor`>0)에서는 같은 좌표가 성역이 아니다(다른 그리드다) — %s" % str(in_floor),
		not in_floor)

	# 나락 아가리도 동형이다.
	if m._region != RegionCatalog.NARAK:
		m._rebuild_region(RegionCatalog.NARAK)
	m._narak_depth = 0
	var shaft: Vector2i = m.NARAK_SHAFT_TILE
	_check("⑩g 나락 아가리 %s도 동형이다 — 비-SOLID(%s)이고 업화로(%s)·결정기(%s) 둘 다 거절"
			% [str(shaft), str(not m.is_solid(m._grid[shaft.y][shaft.x])),
				str(m._can_place_furnace(shaft)), str(m._can_place_crystalarium(shaft))],
		not m.is_solid(m._grid[shaft.y][shaft.x]) and m._f_gate_tile(shaft)
		and not m._can_place_furnace(shaft) and not m._can_place_crystalarium(shaft))
	# 근거: [F] 실행 사다리에서 기계가 문보다 **앞에서 return**한다(그래서 하강이 가려졌다).
	var f_furnace := _line_in(_src, "_furnace_at(_target) and Input.is_action_just_pressed(\"shop_toggle\")")
	var f_gate := _line_in(_src, "if _at_dungeon_gate():")
	var f_mouth := _line_in(_src, "if _at_narak_mouth() and Input.is_action_just_pressed(\"shop_toggle\")")
	_check("⑩h 근거: [F] 사다리에서 화덕(main %d행)이 갱도 문(%d행)·나락 아가리(%d행)보다 앞에서 잡는다"
			% [f_furnace + 1, f_gate + 1, f_mouth + 1],
		f_furnace > 0 and f_gate > f_furnace and f_mouth > f_furnace)

# ── ⑪ #10·#11 LMB 세션 중엔 설치가 안 나간다 ────────────────────────────────
func _check_session_lmb_guard(m: Node) -> void:
	print("⑪ #10·#11 세션 LMB ↔ 설치 겹침")
	# 술어와 다섯 소비처(설치 넷 + 도구 하나)가 **한 줄**을 읽는다.
	var decl := _line_in(_src, "var session_lmb := cheki != null or cocktail != null or fishing != null")
	var users := _count_in(_src, "not session_lmb")
	_check("⑪a 세션 술어가 셋을 모두 들고(main %d행) 소비처가 다섯이다(설치 넷 + 도구 하나 — 실측 %d)"
			% [decl + 1, users], decl > 0 and users >= 5)
	var branches := 0
	for needle in ["not session_lmb and holding_pot", "not session_lmb and holding_tapper",
			"not session_lmb and holding_furnace", "not session_lmb and holding_crystalarium"]:
		if _line_in(_src, needle) > decl:
			branches += 1
	_check("⑪b 설치 갈래 넷이 전부 술어 **뒤에서** 그것을 문다(%d/4 — 게잡이통·채취기·업화로·결정기)"
			% branches, branches == 4)
	# 왜 필요했나 — 세션 분기는 return을 안 해서 같은 프레임이 아래 디스패치까지 흘러간다.
	# ★[폴리시 R24 #12] **전제가 뒤집혔다(그것이 봉합이다).** 종전 이 항은 「릴 틱이 술어 선언보다
	#   위」를 근거로 들었는데, 바로 그 배치 때문에 «세션을 끝낸 그 LMB»가 닫는 프레임에만 술어를
	#   false로 만들어 여섯 가드를 통째로 무력화했다. 이제 선언이 세 틱보다 **위**다 — 재는 계약은
	#   그대로("틱은 return을 안 하므로 게이트가 유일한 방어다")이고, 그 방어가 성립하려면 선언이
	#   틱보다 앞이어야 한다는 것이 R24가 더한 절반이다.
	var tick := _line_in(_src, "if fishing != null and not _sleeping:")
	var users_after := 0
	for needle2 in ["var on_refill := not _sleeping and not session_lmb",
			"not session_lmb and holding_pot", "not session_lmb and holding_crystalarium"]:
		if _line_in(_src, needle2) > tick:
			users_after += 1
	_check("⑪c 근거: 릴 틱 분기(main %d행)는 return이 없고 소비처가 전부 그 아래인데(%d/3), 술어 선언(%d행)은 그 **위**다 — 닫는 프레임에도 게이트가 산다"
			% [tick + 1, users_after, decl + 1],
		tick > 0 and decl > 0 and decl < tick and users_after == 3)
	# 겹침이 구조적이라는 실증: 캐스팅이 성립하는 무대에서 네 배치 술어가 함께 참인 칸이 있다.
	m._indoor = ""
	if m._region != RegionCatalog.SAMDOCHEON:
		m._rebuild_region(RegionCatalog.SAMDOCHEON)
	var overlap := Vector2i(-9999, -9999)
	var size: Vector2i = RegionCatalog.size_of(RegionCatalog.SAMDOCHEON)
	for y in range(1, size.y - 1):
		for x in range(1, size.x - 1):
			var t := Vector2i(x, y)
			if m._can_place_crab_pot(t) and m._can_place_furnace(t) and m._can_place_crystalarium(t):
				overlap = t
				break
		if overlap.x > -9999:
			break
	_check("⑪d 낚시 무대(삼도천)에서 게잡이통·업화로·결정기가 **함께** 서는 칸 %s이 있다 — 겹침이 우연이 아니라 구조적이다"
			% str(overlap), overlap.x > -9999)

# ── ⑫ #12 더비 안내가 실존 랜드마크를 가리킨다(그리기 경로를 태운다) ────────
func _check_derby_landmark(m: Node) -> void:
	print("⑫ #12 더비 부스 랜드마크")
	var banner: String = SeasonalEvent.banner_text(SeasonalEvent.DERBY)
	_check("⑫a 아침 배너가 «강 낚시터»를 말하고 «부두»를 말하지 않는다 — 「%s」" % banner,
		banner.contains("강 낚시터") and not banner.contains("부두"))
	# 태그 알림은 **그 창구를 실제로 태워** 받는다(문구를 옮겨 적지 않는다).
	m._indoor = ""
	if m._region != RegionCatalog.SAMDOCHEON:
		m._rebuild_region(RegionCatalog.SAMDOCHEON)
	var derby_day := -1
	for d in range(1, GameClock.DAYS_PER_SEASON * 4 + 1):
		if SeasonalEvent.event_for_day(d) == SeasonalEvent.DERBY:
			derby_day = d
			break
	var tag_line := ""
	if derby_day > 0:
		m.clock.day = derby_day
		m.notice_feed._items.clear()
		# 태그는 어획당 1/3 롤이라(SeasonalEvent.roll_tag) 붙을 때까지 창구를 반복해 태운다.
		for _i in range(40):
			m._note_derby_catch()
			for it in m.notice_feed._items:
				if String(it["text"]).contains("금빛 태그"):
					tag_line = String(it["text"])
			if tag_line != "":
				break
		m.notice_feed._items.clear()
	_check("⑫b 태그 알림도 같은 이름을 말한다(더비일 %d · 라이브 창구) — 「%s」" % [derby_day, tag_line],
		tag_line.contains("강 낚시터") and not tag_line.contains("부두"))
	# 라이브 라벨 — 삼도천 화면에 "부두"는 하나도 없다(그리기 경로가 만든 노드를 센다).
	var labels: Array = []
	for lbl in m._labels:
		labels.append(String(lbl.text))
	_check("⑫c 삼도천 라벨 %s에 «부두»가 없다(그 간판은 옆 구역 황천해의 것이다)" % str(labels),
		not labels.is_empty() and not labels.has("부두"))
	# 부스에서 가장 가까운 라벨이 그 이름이다(좌표에서 파생 — 이름을 옮겨 적지 않는다).
	var booth_px: Vector2 = m._tile_center_px(m.DERBY_BOOTH_TILE)
	var best := ""
	var best_d := 1.0e20
	for lbl in m._labels:
		var d2: float = (lbl.position + lbl.size * 0.5).distance_to(booth_px)
		if d2 < best_d:
			best_d = d2
			best = String(lbl.text)
	_check("⑫d 부스 %s에서 가장 가까운 라벨이 「%s」다(%.0fpx) — 안내가 가리키는 그 이름"
			% [str(m.DERBY_BOOTH_TILE), best, best_d], best == "강 낚시터")
	# 코드가 삼도천에서 "부두"라 부르는 것(SAMDO_DOCK_RECT)은 부스에서 멀다.
	var dock_far: int = absi(m.SAMDO_DOCK_RECT.position.y - m.DERBY_BOOTH_TILE.y)
	_check("⑫e 코드의 삼도천 «부두»(SAMDO_DOCK_RECT y%d)는 부스에서 %d칸 북쪽이다 — 따라가면 못 찾는다"
			% [m.SAMDO_DOCK_RECT.position.y, dock_far], dock_far >= 20)

# ── ⑬ #13 비해금 테마 슬롯이 하늘을 안 덮는다 ───────────────────────────────
func _check_theme_day_weather(m: Node) -> void:
	print("⑬ #13 비해금 테마 슬롯 ↔ 날씨")
	# 무대: 달력 슬롯이면서 **지금 세이브로는 안 열리는** 날을 찾는다.
	# ★ 무대를 **롤이 비-평온인** 비해금 슬롯으로 고른다 — 어차피 평온이 나오는 날에서 재면
	#   봉합을 지워도 답이 같아 ⑬a·⑬d가 헛돈다(공허 통과 방지).
	var slot_day := -1
	for d in range(1, GameClock.DAYS_PER_SEASON * 4 + 1):
		if not Festival.is_theme_slot(d) or m._theme_open_on(d) or GameClock.is_season_first_day(d):
			continue
		if Weather.weather_for_day(d, false) != Weather.CALM:
			slot_day = d
			break
	_check("⑬ 무대: 달력 슬롯이지만 해금이 안 됐고 **롤이 비-평온**인 날 %d일을 찾았다(배너 0·장식 0·프리미엄 1.0인 평일)"
			% slot_day, slot_day > 0)
	if slot_day < 0:
		return
	_check("⑬a 그날 main의 하늘 = 분포 롤이다(강제 평온 해제) — %s ≠ 평온"
			% Weather.NAMES[m._weather_on(slot_day)],
		m._weather_on(slot_day) == Weather.weather_for_day(slot_day, false)
		and m._weather_on(slot_day) != Weather.CALM)
	# 공허 통과 방지: 슬롯 넷 중 적어도 하나는 실제로 비-평온이 나와야 "이득이 돌아왔다"가 성립한다.
	var non_calm := 0
	var locked_slots := 0
	for d in range(1, GameClock.DAYS_PER_SEASON * 4 + 1):
		if not Festival.is_theme_slot(d) or m._theme_open_on(d) or GameClock.is_season_first_day(d):
			continue
		locked_slots += 1
		if m._weather_on(d) != Weather.CALM:
			non_calm += 1
	_check("⑬b 비해금 슬롯 %d일 중 %d일이 실제로 비-평온으로 돌아왔다(잃던 하루가 실재한다)"
			% [locked_slots, non_calm], locked_slots > 0 and non_calm > 0)
	_check("⑬c 해금되면 다시 덮인다(축제 무대는 맑아야 한다 — 계약 보존)",
		Weather.weather_for_day(slot_day, true) == Weather.CALM)
	_check("⑬d 예보와 실제가 안 갈린다 — 전날 예보 %s = 그날 하늘 %s"
			% [Weather.NAMES[m._forecast_on(slot_day - 1)], Weather.NAMES[m._weather_on(slot_day)]],
		m._forecast_on(slot_day - 1) == m._weather_on(slot_day))
	_check("⑬e 순수 1인자 갈래의 기본값은 종전 그대로다(해금 정보를 못 구하는 호출부 거동 불변)",
		Weather.weather_for_day(slot_day) == Weather.CALM)
	# 손실이 실재였다는 근거 — 종전 주석의 "부작용 0"을 반증하는 배수들.
	_check("⑬f 근거: 혼불 바람 배수 셋(%.2f·%.2f·%.2f)과 혼우 입질 %.2f·자동 급수(%s)가 실효 이득이다"
			% [Weather.SOULWIND_MOB, Weather.SOULWIND_DROP, Weather.SOULWIND_RARE,
				Weather.RAIN_BITE, str(Weather.waters_field(Weather.RAIN))],
		Weather.SOULWIND_MOB > 1.0 and Weather.SOULWIND_DROP > 1.0 and Weather.SOULWIND_RARE > 1.0
		and Weather.RAIN_BITE > 1.0 and Weather.waters_field(Weather.RAIN))

# ── ⑭ #14 F8 삭제 래치가 모달 중에도 만료된다(라이브) ───────────────────────
func _check_delete_latch_lifetime(m: Node) -> void:
	print("⑭ #14 F8 삭제 2단 래치 수명")
	# 소스 — 감소가 `_process`의 **모든 조기 반환보다 위**에 선다(정지 주인 = 재개 주인).
	# ★ 니들은 **`_process` 안에서만** 센다 — 같은 문자열이 다른 함수에도 있어(전역 `_line_in`은
	#   엉뚱한 행을 잡는다) 순서 비교가 조용히 무의미해진다.
	var dec := _line_in_func(_src, "func _process", "_delete_armed_secs -= delta")
	var gates: Array = []
	for needle in ["if _edit_mode:", "if _deco_mode:", "if _transitioning:", "if cutscene != null:",
			"if dialogue.is_open():", "if frame.is_open():"]:
		gates.append(_line_in_func(_src, "func _process", needle))
	var above := true
	for g in gates:
		if int(g) <= dec:
			above = false
	_check("⑭a 래치 감소(main %d행)가 조기 반환 여섯 %s보다 **위**에 선다"
			% [dec + 1, str(gates)], dec > 0 and above)
	# 라이브 — 메뉴를 연 채로도 래치가 만료된다(문구를 거두는 NoticeFeed와 같은 수명).
	m._delete_armed_secs = 0.02
	m.frame.open(InventoryFrame.CTX_MENU)
	var opened: bool = m.frame.is_open()
	for _i in range(20):
		await process_frame
	var left: float = m._delete_armed_secs
	if opened:
		m._close_frame()
	m._delete_armed_secs = 0.0
	_check("⑭b 메뉴가 열린 채(%s)로 20프레임을 돌려도 래치가 만료된다(남은 %.3f초) — 안내와 같은 수명"
			% [str(opened), left], opened and left <= 0.0)
	# 실행 분기는 그 값 하나만 본다 = 만료가 곧 안전이다.
	var arm := _line_in_func(_src, "func _arm_or_confirm_delete", "if _delete_armed_secs > 0.0:")
	_check("⑭c 근거: 확인 분기(main %d행)가 그 값 하나만 본다 — 얼어붙은 래치는 곧 즉시 삭제였다"
			% (arm + 1), arm > 0)

# ── ⑮ #15 트렐리스로 자기를 가두지 못한다(라이브) ───────────────────────────
func _check_trellis_entrapment(m: Node) -> void:
	print("⑮ #15 트렐리스 자기 포위")
	m._indoor = ""
	if m._region != RegionCatalog.HOME:
		m._rebuild_region(RegionCatalog.HOME)
	var trellis := ""
	for c in CropCatalog.ids():
		if CropCatalog.is_trellis(c):
			trellis = c
			break
	var rect: Rect2i = m.STARTER_PATCH_RECT
	var here := Vector2i(rect.position.x + 2, rect.position.y + 2)
	_check("⑮ 무대: 트렐리스 작물(%s) · 스타터 밭 한복판 %s" % [trellis, str(here)],
		trellis != "" and rect.has_point(here))
	if trellis == "":
		return
	var farm_snap: Dictionary = m.farm.to_save()
	m.player.global_position = m._tile_center_px(here)
	var seed_id: String = ItemCatalog.seed_id(trellis)
	m.inventory.slots[m.inventory.selected_index] = {"id": seed_id, "count": 99, "quality": 0}
	var dirs := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	var planted := 0
	for i in range(dirs.size()):
		var t: Vector2i = here + dirs[i]
		m._field_at(t).hoe(t)
		m._target = t
		m._target_valid = m._is_farmable(t)
		m.notice_feed._items.clear()
		m._use_tool()
		if m.farm.is_planted(t):
			planted += 1
	_check("⑮a 네 방향 중 **셋만** 심겼다(넷째가 마지막 퇴로라 거절) — 실측 %d" % planted,
		planted == 3)
	var last: Vector2i = here + dirs[3]
	m._target = last
	m._target_valid = m._is_farmable(last)
	m.notice_feed._items.clear()
	m._use_tool()
	var told := ""
	for it in m.notice_feed._items:
		told = String(it["text"])
	_check("⑮b 마지막 칸 %s은 심기지 않고 **왜 거절인지 말한다** — 「%s」" % [str(last), told],
		not m.farm.is_planted(last) and told.contains("갇힌다"))
	_check("⑮c 술어가 그 칸을 지목한다 — `_would_entrap_player(%s)` %s · 셋 심긴 뒤 퇴로가 하나뿐이다"
			% [str(last), str(m._would_entrap_player(last))], m._would_entrap_player(last))
	# 과잉이 아니다 — 퇴로가 둘 이상이면 여전히 심긴다.
	m.farm.load_save(farm_snap)
	m._target = here + dirs[0]
	m._field_at(m._target).hoe(m._target)
	m._target_valid = m._is_farmable(m._target)
	m._use_tool()
	_check("⑮d 사방이 트인 상태에서는 여전히 심긴다(첫 칸 %s) — 가드가 과잉이 아니다"
			% str(m._target), m.farm.is_planted(m._target))
	# 왜 거절이 정배인가 — 걷어내는 플레이어 입력이 저장소에 0이다.
	var removers := 0
	for line in _src:
		var ln := String(line)
		if ln.strip_edges().begins_with("#"):
			continue
		if ln.contains("remove_plant("):
			removers += 1
	_check("⑮e 근거: `remove_plant` 호출부 %d곳이 전부 자동 사건(까마귀·절기 사멸·잡초 확산·삽사리)이고 플레이어 입력이 0이다 — 탈출 동사가 없다"
			% removers,
		removers > 0 and _line_in_func(_src, "func _use_tool", "remove_plant(") < 0)
	m.farm.load_save(farm_snap)
	m.inventory.slots[m.inventory.selected_index] = null

# ── ⑯ #16 절기 재스폰이 사람 선 칸을 비켜 간다(라이브) ──────────────────────
func _check_respawn_player_tile(m: Node) -> void:
	print("⑯ #16 재스폰 후보 ↔ 사람 선 칸")
	m._indoor = ""
	if m._region != RegionCatalog.HOME:
		m._rebuild_region(RegionCatalog.HOME)
	# 사람을 옮기기 **전** 후보 목록에서 한 칸을 고른다(그 칸이 원래 후보였음이 무대 전제다).
	var base: Array = m._encroach_candidates()
	_check("⑯ 무대: 재점령 후보가 %d칸 있다(공허 통과 방지)" % base.size(), base.size() >= 2)
	if base.size() < 2:
		return
	var stand: Vector2i = base[0]
	var other: Vector2i = base[1]
	var saved_pos: Vector2 = m.player.global_position
	m.player.global_position = m._tile_center_px(stand)
	var after: Array = m._encroach_candidates()
	_check("⑯a 사람이 선 칸 %s이 후보에서 빠진다(종전엔 발밑에 32×32 SOLID가 섰다)" % str(stand),
		not after.has(stand) and after.has(other))
	# 가드가 좌표를 실제로 따라간다 — 옮기면 그 칸이 다시 후보가 된다.
	m.player.global_position = m._tile_center_px(other)
	var moved: Array = m._encroach_candidates()
	_check("⑯b 한 칸 옮기면 %s이 후보로 돌아오고 %s이 대신 빠진다(좌표를 따라가는 성역)"
			% [str(stand), str(other)], moved.has(stand) and not moved.has(other))
	m.player.global_position = saved_pos
	# 주민 칸도 함께 빠진다 — 배치 가드가 이미 예약하던 그 표를 읽는다.
	# 주민 축 — 기본 무대에는 후보와 겹치는 주민 칸이 없으므로(그대로 재면 공허) **주민을 후보
	#   칸에 실제로 세운 뒤** 잰다. `_resident_tile`은 배치 가드가 이미 그 자리를 시간 축까지
	#   포함해 예약하던 그 표다(R16 #14 · R18 #12).
	var res = m._resident("miho")
	var res_tile: Vector2i = base[2] if base.size() > 2 else other
	var saved_tile: Vector2i = res.tile if res != null else Vector2i.ZERO
	if res != null:
		res.tile = res_tile
	var with_res: Array = m._encroach_candidates()
	var res_ok: bool = res != null and m._resident_tile(res_tile) and not with_res.has(res_tile)
	if res != null:
		res.tile = saved_tile
	var back: Array = m._encroach_candidates()
	_check("⑯c 주민이 선 칸 %s도 후보에서 빠진다(비키면 %s 복귀) — 배우자 안방 스테이션에 바위가 안 선다"
			% [str(res_tile), str(back.has(res_tile))], res_ok and back.has(res_tile))
	var final_list: Array = back
	# 굴림이 세우는 것이 실제로 32×32 풀타일 충돌이다(그래서 발밑에 서면 못 나온다).
	var solid_kinds := 0
	for tex in m.DEBRIS_KIND.keys():
		var kind: String = String(m.DEBRIS_KIND[tex])
		if kind != DebrisCatalog.EMBER and kind != DebrisCatalog.STUMP:
			continue
		if tex in m.SOLID_PROPS and not (tex in m.FOOT_BAR_PROPS):
			solid_kinds += 1
	_check("⑯d 근거: 굴림의 2/3 가중치인 업화석·석화 고목이 SOLID_PROPS이고 FOOT_BAR_PROPS 밖이다(풀타일 충돌 %d종)"
			% solid_kinds, solid_kinds >= 2)

# ── ⑰ #17 묘목을 발밑에 못 심는다(라이브) ───────────────────────────────────
func _check_sapling_underfoot(m: Node) -> void:
	print("⑰ #17 묘목 발밑 심기")
	m._indoor = ""
	if m._region != RegionCatalog.HOME:
		m._rebuild_region(RegionCatalog.HOME)
	var orchard_snap: Dictionary = m.orchard.to_save()
	var zone: Rect2i = m.ORCHARD_ZONE_RECT
	var spot := Vector2i(-1, -1)
	for y in range(zone.position.y + 1, zone.end.y - 1):
		for x in range(zone.position.x + 1, zone.end.x - 1):
			var t := Vector2i(x, y)
			if m.orchard.can_plant(t, m._is_tree_blocked):
				spot = t
				break
		if spot.x >= 0:
			break
	_check("⑰ 무대: 3×3이 비어 있는 앵커 %s" % str(spot), spot.x >= 0)
	if spot.x < 0:
		return
	var fruit: String = FruitTreeCatalog.ids()[0]
	var sapling: String = ItemCatalog.sapling_id(fruit)
	m.inventory.slots[m.inventory.selected_index] = {"id": sapling, "count": 5, "quality": 0}
	var before: int = m.inventory.count_of(sapling)
	# 발밑을 겨눈다 — `_target` 오프셋 (0,0)은 실제로 허용된다.
	m.player.global_position = m._tile_center_px(spot)
	m._target = spot
	m.notice_feed._items.clear()
	m._use_tool()
	var told := ""
	for it in m.notice_feed._items:
		told = String(it["text"])
	_check("⑰a 발밑 %s에는 안 심긴다 + 왜인지 말한다 — 「%s」" % [str(spot), told],
		not m.orchard.has_tree(spot) and told.contains("발밑")
		and m.inventory.count_of(sapling) == before)
	_check("⑰b 술어가 그 칸을 지목한다 — `_would_entrap_player(%s)`" % str(spot),
		m._would_entrap_player(spot))
	# 과잉이 아니다 — 한 칸 물러서면 그대로 심긴다.
	m.player.global_position = m._tile_center_px(spot + Vector2i(0, 2))
	m._target = spot
	m._use_tool()
	_check("⑰c 한 칸 물러서서 겨누면 그대로 심긴다(가드가 과잉이 아니다) — 묘목 %d → %d"
			% [before, m.inventory.count_of(sapling)],
		m.orchard.has_tree(spot) and m.inventory.count_of(sapling) == before - 1)
	m.orchard.load_save(orchard_snap)
	m.inventory.slots[m.inventory.selected_index] = null
