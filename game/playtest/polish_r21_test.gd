extends SceneTree
# ★[폴리시 21회차] 버그 헌트 확정분 회귀 — 배치 A(#0~#12) + 배치 B(#13~#24).
#
# 렌즈: R20 diff 리뷰(#0·#1) · 에너지 0 경계(#2·#3·#4) · 해금 첫 프레임(#5·#6·#7·#8) ·
#       컷신/사건 재진입(#9) · 다중 로맨스 교차(#10·#11) · 좌표 키 구역 축(#12).
#
# 이 배치의 태도 셋.
#   ㉠ **직전 회차가 심은 것이 이 회차의 첫 항목이다.** #0은 R20 #4·#5가 세운 `need_days`
#      스냅샷의 계산식이 «직전 임계의 잔여»를 재파생 기준으로 삼은 자리다 — 봉합은 그 자[尺]를
#      base로 바꾸는 것뿐이고, R20이 얻은 셋(즉시 성숙·역행·쿨다운 침식)은 전부 그대로 지켜져야
#      한다. 그래서 ①은 새 결함 둘과 **옛 계약 셋**을 같은 무대에서 나란히 잰다.
#   ㉡ **거절은 반드시 이유를 남긴다.** #3·#4는 같은 규율의 두 방향이다 — 하나는 사유가 아예
#      없었고(사료풀), 하나는 **틀린 사유**를 댔다(과수). 둘 다 화면을 실제로 태워서 잰다
#      (④는 프롬프트 사슬을 `_process`로, ⑤는 `_farm_prompt` 반환값으로).
#   ㉢ **좌표를 옮겨 적지 않는다.** ①의 base는 CropCatalog에서, ②의 후보 칸은
#      `_is_tree_seed_free` 자신에게 물어서, ⑧의 문턱은 `FireflySouls.GATE_COUNT`에서,
#      ⑨의 남은 스킬 이름은 `Mastery.pending_skills` + `ProfessionCatalog.skill_name`에서 판다.
#
# 무엇을 보증하나(번호 = 21회차 헌트 발견 인덱스):
#   ① #0 `_reseal_need`가 **직전 임계의 잔여**에 새 계수를 곱해, 멱등 가드가 같은 id만 막는
#      비료 교체에서 임계가 «지금까지 뿌린 모든 계수의 곱»이 됐다 — 성장촉진·하이퍼를 번갈아
#      뿌리면 12일 작물이 3일까지 내려가고(동군 중첩), 하이퍼로 깎은 뒤 디럭스를 덮으면
#      −33% 성숙 + 디럭스 품질이 한 칸에 동시 성립했다(2군 XOR 붕괴).
#   ② #1 안식 자체 파종만 `_would_entrap_player`를 안 물어, 성숙목 반경 3칸 안 맨흙에 선 채
#      24:00을 맞으면 발밑·마지막 퇴로에 풀타일 SOLID가 돋았다(마당 원장 나무는 `_grid`를 안
#      건드려 `_restore_location`의 매몰 구제도 못 걸리고, 취침 자동 저장이 그 좌표를 굳혔다).
#   ③ #2 보장 미끼는 캐스팅 순간 체급이 확정되는데 혼력 사전 판정은 어종 무관 전역 최저(소 4)만
#      봐서, 중 체급 확정 + 혼력 4~7 구간에서 150냥 미끼가 **100% 확정 실패**로 탔다.
#   ④ #3 사료풀 낫질은 과금 동사인데 프롬프트 사슬에 갈래가 없어, 혼력이 모자라면 화면에
#      안내도 알림도 0인 채 LMB가 되돌아갔다(여물광 건초의 유일 소스 = 짐승 굶김).
#   ⑤ #4 과수·묘목 프롬프트가 **동사 성립보다 먼저** 혼력을 물어, 막을 동사가 애초에 없는
#      미성숙 나무 위에서도·3×3이 막힌 자리에서도 "혼력 부족"이라 거짓 사유를 댔다.
#   ⑥ #5 도감 완주 래치 회수가 아침 출하 정산 한 곳뿐이라, 생선가게 즉시 환전으로 마지막 한
#      종을 판 순간에는 알림도·열람대 완주 문구도·금빛 상도 서지 않았다(등재 창구는 둘이다).
#   ⑦ #6 `_run_harvested`를 올리는 세 자리 어디에도 앵커 트랙 재파생이 없어, 600번째 수확이
#      deed를 만점으로 만들어도 하트는 어제 값에 멎었다(「명부 혼례 부적」이 그날 내내 잠김).
#   ⑧ #7 명부 시련장 외관에 라벨이 없어, 잠긴 외관이 "저기 뭔가 있다"를 말하지 못했다
#      (선례로 든 나락 진입로는 게이트 조건까지 말한다).
#   ⑨ #8 [경지] 미개방 안내(㉠ 갈래)가 구현되지 않아 `Mastery.pending_skills`가 런타임 호출부
#      0인 죽은 API로 남았고, 층이 존재한다는 사실이 화면 어디에도 안 나왔다.
#   ⑩ #9 컷신을 여는 `_maybe_spine_b5`/`_maybe_resume_spine`가 `_process` 중간에 있어, 연출이
#      시작된 그 프레임의 F9·[F]·LMB가 머리 가드를 이미 지나온 뒤라 그대로 통과했다.
#   ⑪ #11 질투 알림이 루프 밖에 있어, 실제 감점이 0건(둘 다 ♡0)이어도 «서운한 기색»이 떴다.
#   ⑫ #12 `field_layer`(좌표 키 그리기 원장)에 무대 술어가 없어, 집 밖에서 날이 바뀌면 아침
#      정산의 `tile_changed`가 남의 구역 그리드 위에 안식 고랑을 찍었다(워프 전까지 잔존).
#
# 판정: #0~#9·#11·#12 CONFIRMED(전부 봉합) · **#10 = OWNER-DECISION**(앵커 이혼의 ♡0 리셋이
#   deed 파생 원장에 즉시 덮여 no-op — 대체 페널티를 정할지·앵커 재혼을 싸게 둘지가 설계
#   결정이고, owner 큐에 「앵커 재혼 비용 비대칭」으로 이미 서 있다. 코드 무수정 = 단언 없음).
#
# 봉합 축(근거 전문은 커밋 본문·각 함수 머리말):
#   · #0 = `_reseal_need`의 잔여를 **base 기준**으로 잰다(`left = base - grown`). 계수 1.0인
#          품질군은 base로 정확히 되돌아가 XOR가 회복되고, 성숙 칸은 기존 `left <= 0` 가지가
#          그대로 지킨다. need는 grown에 단조 증가라 «심을 때부터 그 비료»보다 낮아질 길이 없다.
#   · #1 = `_is_tree_seed_free`에 `_would_entrap_player(t, _tree_seed_pending_solid())` 한 줄.
#          pending은 별도 장부가 아니라 **원장 차집합**이다(ledger occupied − 이미 물리에 선 칸).
#   · #2 = `_cast_energy_need` — 화면(프롬프트)과 집행부가 **같은 함수**를 부르는 R10/R11의 계약을
#          지킨 채, 보장 미끼면 «확정 체급의 비용»을 본다. 그 체급은 rng가 아니라 풀에서 정해지므로
#          `FishCatalog.guaranteed_class`(roll_fish의 보장 가지와 같은 술어)로 **굴리지 않고** 답한다
#          = 굴림 스트림 무소비(결정성 보존). 비용식은 `FishingSession.hook_energy_for` 순수 코어.
#   · #3 = 프롬프트 사슬에 사료풀 갈래(이끼 줄과 같은 3분기 문법).
#   · #4 = 혼력 판정을 **동사가 서는 갈래 안으로** 내린다(R10이 목축에 세운 순서).
#   · #5 = `_claim_codex_trophy(day)` 헬퍼 — 등재 창구 둘이 같은 한 줄을 부른다.
#   · #6 = `_count_run_harvest()` — 점수판을 올리는 유일 창구가 트랙을 그 자리에서 다시 잰다.
#   · #7 = EOPHWA_MINE 라벨 블록에 한 줄(문턱은 `FireflySouls.GATE_COUNT` 파생).
#   · #8 = ㉠ 갈래 구현 — 첫 행 하나에만 앉히고(잔소리 경계 보존) 이름은 새 표시명 표에서 판다.
#   · #9 = 네 진입 창구 뒤 `if _transitioning or cutscene != null: return` 재검사 한 줄.
#   · #11 = 실제 감점 인원(`hit`)이 0이면 알리지 않는다(R15·R18의 「집행 0 = 무고지」).
#   · #12 = `_on_tile_changed`에 `if _region != HOME: return`(복원은 `_repaint_field_overlays`).
#
# 하중 검증(봉합을 하나씩 깨서 red를 실측하고 원복 — 아래는 **실측 결과** 그대로다):
#   #0  `_reseal_need`의 자[尺]를 `base` → `prev_need`로 되돌림          → ①c·①d red
#   #1  `_is_tree_seed_free`의 `_would_entrap_player` 행 삭제            → ②b·②e red
#   #1b `_tree_seed_pending_solid`를 빈 표로                              → ②d·②e red(pending 단독 하중)
#   #2  `_cast_energy_need`의 보장 체급 가지를 걷어 하한만 보게 함        → ③c·③d·③e red(미끼가 탄다)
#   #3  사료풀 프롬프트 갈래 무력화                                       → ④b·④c·④d red(화면 침묵)
#   #4  과수 혼력 판정을 갈래 위로 되돌림                                 → ⑤b red(거짓 사유)
#   #5  생선가게의 `_claim_codex_trophy` 행 삭제                          → ⑥c·⑥d·⑥e red
#   #6  `_count_run_harvest`의 `_refresh_okja_track()` 삭제               → ⑦b·⑦c·⑦d red(♡4에 멎는다)
#   #7  시련장 라벨 삭제                                                  → ⑧b·⑧c red
#   #8  ㉠ 갈래를 `return {}`로 되돌림                                    → ⑨b·⑨d red
#   #9  `_process`의 재검사 두 줄 삭제                                    → ⑩a·⑩b red
#   #11 `if hit <= 0: return` 삭제                                        → ⑪b red
#   #12 `_on_tile_changed`의 구역 술어 삭제                               → ⑫b red(마을에 고랑이 찍힌다)
#
# ★하중 검증에서 배운 것: **빈 문자열끼리의 일치는 공허 통과다.** ⑨d의 첫 판은 `piped == text`
#   뿐이라 ㉠ 갈래를 통째로 되돌려도 둘 다 ""가 되어 초록이었다 — 값이 비어 있지 않음을 함께
#   재야 그 배선이 실제로 하중을 받는다(R16이 «조건에서 든다»로 배운 것의 문자열 판).
#
# ★형제 스위트 계약 정정 2건(거동을 바꾼 자리라 그 스위트가 붙들고 있던 옛 문장을 함께 고쳤다):
#   · `mastery_test` ⑥b — «만렙 전엔 5행 전부 빈 dict»가 `_mastery_row` 머리말 ㉠과 정면으로
#     어긋나 있었다(그 계약을 위해 만든 `pending_skills`가 죽은 API인 이유). «첫 행 하나뿐»으로
#     조여 두 계약을 함께 세운다 — 잔소리 0의 실질(나머지 넷 침묵)은 그대로 잰다.
#   · `polish_r11` ③f·⑱c — 니들이 가리키던 **함수가 옮겨졌을 뿐** 계약은 불변이다(③f는
#     `_cast_energy_need` 한 함수를 두 자리가 부르는지, ⑱c는 `_claim_codex_trophy`가 keep 표를
#     다는지). ③f'를 더해 R11의 하한 계약이 그 함수 **안**에 살아 있음을 따로 잰다.
#
# ══ 배치 B(#13~#24) ═══════════════════════════════════════════════════════════
# 렌즈: 부재 구역 시뮬(#13·#14·#15) · 로드 첫 프레임(#16) · 에너지 0 경계(#17·#18·#19) ·
#       좌표 키 구역 축(#20·#21) · 다중 로맨스 교차(#22·#23·#24).
#
# 무엇을 보증하나:
#   ⑬ #13 = **DUP(#1) + 잔여 축 1건**. 스포너 축(발밑 파종)은 #1 봉합이 이미 닫았고, 시나리오
#      후단의 "탈출도 막혀 있다"만 남아 있었다 — `_restore_location`의 매몰 구제가 `_tile_blocked`
#      (=`_grid`) 하나만 봐서, `_grid`를 한 글자도 안 건드리는 마당 원장 나무에 묻힌 좌표를 못
#      봤다(R21 #1 이전에 굳은 세이브의 탈출구 0). 구제 술어를 진실원 `_player_blocked_at`으로.
#   ⑭ #14 숲 빈 슬롯 재출현(20%/일)과 미혹 심층 큰 그루터기(**매일 100%**)가 사람이 선 칸을
#      SOLID로 덮었다 — HOME 형제 셋이 전부 무는 매몰 가드를 이 둘만 안 물었다.
#   ⑮ #15 마당 자체 파종만 집 밖 취침에 **통째로 스킵**됐다(형제 셋은 전부 이월 표를 세운다).
#      면제 근거로 든 "결정 롤은 day 시드라 손실이 아니다"는 `_season_respawn_pending_day`
#      선언부가 이미 명시 철회한 논거였고, 실효는 마당 나무 공급(HOME_CAP)의 영구 감소였다.
#   ⑯ #16 F9 로드가 주민 보간 걷기만 안 끊어(낚시·체키·밤 바는 끊는다), 폐기된 타임라인 좌표에서
#      NPC가 수십 초간 흘러왔다 — 논리 칸과 그려진 몸이 통째로 어긋난다.
#   ⑰ #19 혼력 바의 "취침 신호" 색만 **무인자 `can_act()`**(고정 10)라, 실제 비용(팬닝 4·후킹
#      하한·숙련 감산 7)과 눈금이 어긋나 아직 할 수 있는 일이 남았는데 바가 취침을 재촉했다.
#      R6가 프롬프트 축에서 걷어낸 그 불일치이고, 그 회귀 단언은 main.gd만 읽어 이 한 자리를 놓쳤다.
#   ⑱ #20·#21 스프링클러·레어크로우 **안내 사슬만** 좌표 원장을 날로 봐(입력·배치·렌더는 전부
#      무대 술어를 쓴다), 다른 구역의 같은 좌표에서 회수 안내와 종 이름이 새고 그 칸의 뒤따르는
#      안내(승마·밭)가 통째로 가려졌다.
#   ⑲ #23 질투 감점(−30 points)의 표면이 화면 어디에도 없었다 — 근거 주석이 든 "관계 탭 하트가
#      이미 보여 준다"는 S8-T5가 stage/points를 가른 뒤로 거짓이다(그리기 경로가 hearts()만 읽는다).
#   ⑳ #24 앵커 정표 창구가 연애 슬롯을 안 봐(형제 창구는 첫 항이 그 축이다), 그 자리에서 늘
#      거절될 유일 정표를 미리 발급했다 — 백팩을 영구 점유하는 사장 아이템 + 늘 실패하는 [G].
#
# 배치 B 판정: #13 = DUP(#1)(+잔여 축 봉합) · #17 = DUP(#3) · #18 = DUP(#4) · #22 = DUP(#11) ·
#   나머지 여덟(#14·#15·#16·#19·#20·#21·#23·#24) 전부 CONFIRMED·봉합. REFUTED·OWNER 0건.
#   ※ #17/#18/#22는 시도#1 구판이라 제목만 다르고 시나리오 축·봉합 지점이 같다(각각 ④·⑤·⑪가
#     이미 그 계약을 잰다 — 구판에만 있는 추가 축은 없었다).
#
# 배치 B 봉합 축:
#   · #13 = `_restore_location`의 구제 술어 교체(`_tile_blocked` → `_player_blocked_at`).
#   · #14 = `TreeLedger.advance_day(day, free_cb, solid_ok)` — 세우기 **직전**의 거부권. 롤을
#           먼저 굴리고 거부권을 나중에 물어 그날 출목열이 안 갈린다. main 쪽 콜백은 승인한 칸을
#           pending에 적어 같은 밤의 형제 리스폰이 서로를 본다(R20 #2 규율 · 여기선 «후보 심사»가
#           아니라 «집행 직전 승인»이라 그 기록이 정확하다).
#   · #15 = `_tree_seed_pending_days`(형제 셋과 같은 표·같은 소비 자리·세이브 왕복 —
#     ★[폴리시 R24 #18]에서 스칼라 1칸 → 누적 배열로 갈렸다) +
#           `TreeLedger.catch_up_seeding`(파종 패스만 떼어낸 얇은 창구 — 성장·재출현·이끼를 두 번
#           돌리지 않는다).
#   · #16 = `_load_game`에 걷기 취소 두 줄(`_begin_cutscene`이 R7·R8에 세운 그 역연산).
#   · #19 = `VitalsHud.set_low_cost` + main의 `_lowest_action_cost()`(네 동사의 소유자에게서 파생).
#   · #20·#21 = 안내 사슬을 `_sprinkler_at`/`_rarecrow_at`(무대 술어)로.
#   · #23 = `_heart_badge`에 «서운함» 한 줄 — **새 UI 0**(이미 있는 배지 자리를 쓴다). 원장이
#           비면 배지도 사라져 "복원된 아침은 그냥 평소다" 규약과 어긋나지 않는다.
#   · #24 = `_myeongbu_quest_open`에 `_romance_partner == ""` 한 항(집행부 게이트와 같은 폭).
#
# 배치 B 하중 검증(실측):
#   #13 구제 술어를 `_tile_blocked`로 되돌림            → ⑬b red
#   #14 원장의 거부권 무력화                            → ⑭c·⑭d·⑭e red
#   #14 main 콜백을 늘 허용으로                         → ⑭a·⑭b red
#   #15 이월 표를 안 세움 / 소비처 삭제                 → ⑮c·⑮d red / ⑮d red
#   #16 로드의 걷기 취소 루프 삭제                      → ⑯b red
#   #19 바를 무인자 `can_act()`로 되돌림 / 배선 삭제    → ⑰d red / ⑰b·⑰c red
#   #20 스프링클러 안내를 원장 직행으로                 → ⑱b red
#   #21 레어크로우 안내를 원장 직행으로                 → ⑱c red
#   #23 배지 한 줄 삭제                                 → ⑲b red
#   #24 연애 슬롯 항 삭제                               → ⑳b red
# ★ ⑰만 그리기 경로를 못 태운다(헤드리스엔 draw 패스가 없다) — 대신 **화면이 읽는 그 필드**
#   (`vitals.low_cost`)를 main의 HUD 갱신으로 실제로 흘려 넣어 재고, 무인자 호출부 0을 전 파일
#   스캔으로 못 박는다(그 두 개가 이 항목의 하중이다).
#
# ★[폴리시 R21 부록] `polish_r6` ⑬e가 red였던 것은 **선재 결함이 아니라 stale 예시**였다:
#   R20 #14가 «깊이 게이트 너머의 산출은 안 낸다»를 세우며 저승삼을 정당하게 걷어냈는데, ⑬e가
#   그 종을 «사철 채집물» 증인으로 세워 두고 있었다. 두 계약은 축이 달라(절기 ↔ 깊이) 충돌하지
#   않으므로 코드는 한 줄도 안 고치고, 증인을 해변종(황천산호)으로 갈고 깊이 축을 ⑬e'로 따로
#   못 박았다(R20 #14를 되돌리면 ⑬e'가 red — 실측).
#
# 실행: ./run_tests.sh polish_r21   (헤드리스는 반드시 game/에서 · 순차)

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

# ── 소스 스캔 헬퍼(polish_r7~r20의 그 관례 — 니들은 반드시 함수 안에서 센다) ──
func _lines_of_file(path: String) -> PackedStringArray:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return PackedStringArray()
	return f.get_as_text().split("\n")

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

# 알림 피드에 이 조각을 담은 줄이 있나(표시 진실성 단언의 창구).
func _feed_has(m: Node, needle: String) -> bool:
	if m.notice_feed == null:
		return false
	for e in m.notice_feed._items:
		if String(e.get("text", "")).contains(needle):
			return true
	return false

func _feed_clear(m: Node) -> void:
	if m.notice_feed != null:
		m.notice_feed._items.clear()

func _initialize() -> void:
	await _run_checks()

func _run_checks() -> void:
	print("══ 폴리시 R21 회귀 — 배치 A(#0~#12) ══")
	var cleaner := SaveManager.new()
	cleaner.delete_save()
	_src = _lines_of_file("res://main.gd")
	_check("무대 전제: main(%d행)을 읽었다(부정 단언 공허 통과 방지)" % _src.size(), _src.size() > 1000)

	_check_fert_threshold()

	var m: Node = await _spawn_main()
	_check("무대: main이 섰다", m != null)
	if m == null:
		quit(1)
		return
	_dismiss_dialogue(m)

	_check_seed_entrap(m)
	_check_pledge_bait(m)
	_check_forage_prompt(m)
	_check_orchard_prompt(m)
	_check_codex_trophy(m)
	_check_okja_harvest_axis(m)
	_check_trial_label(m)
	_check_mastery_locked_row(m)
	_check_cutscene_frame_guard()
	_check_jealousy_notice(m)
	_check_field_layer_region(m)

	print("══ 폴리시 R21 회귀 — 배치 B(#13~#24) ══")
	_check_buried_restore(m)
	_check_forest_respawn_guard(m)
	_check_seed_pending_carry(m)
	_check_load_cancels_walk(m)
	_check_energy_bar_scale(m)
	_check_installation_prompt_region(m)
	_check_jealousy_badge(m)
	_check_myeongbu_slot_gate(m)

	print("══ 결과: %s (실패 %d) ══" % ["PASS" if _fail == 0 else "FAIL", _fail])
	quit(1 if _fail > 0 else 0)

# ── ① #0 성숙 임계는 «현재 비료 하나»에서만 파생된다 ─────────────────────────
# 무대 좌표·수치를 한 톨도 안 적는다: 작물은 CropCatalog에서 **가장 긴 것**을 뽑고(교체 계수의
# 차이가 정수 임계에서 실제로 보이려면 base가 커야 한다), 명목값도 카탈로그 계수에서 판다.
func _check_fert_threshold() -> void:
	print("① #0 비료 임계 = 현재 비료 파생(중첩·XOR)")
	var crop := ""
	var base := -1
	for id in CropCatalog.ids():
		var g := CropCatalog.growth_days(String(id))
		if g > base:
			base = g
			crop = String(id)
	var fs := FertilizerCatalog.speed_factor(FertilizerCatalog.FERT_SPEED)
	var fh := FertilizerCatalog.speed_factor(FertilizerCatalog.FERT_HYPER)
	_check("①a 무대: 가장 긴 작물 %s(base %d일) · 성장촉진 ×%.2f · 하이퍼 ×%.2f(둘 다 1.0 미만)"
			% [CropCatalog.name_of(crop), base, fs, fh],
		base >= 8 and fs < 1.0 and fh < 1.0 and fh < fs)

	var t := Vector2i(3, 3)
	var f := FarmField.new()
	f.hoe(t)
	f.plant(t, crop)
	_check("①b 심은 직후 임계는 base 그대로다(%d일)" % f.effective_growth_days(t),
		f.effective_growth_days(t) == base)

	# 동군 중첩 — 성장촉진 → 하이퍼로 갈아 뿌린다. 봉합 전엔 잔여에 계수가 겹쳐 곱해졌다.
	f.fertilize(t, FertilizerCatalog.FERT_SPEED)
	var after_speed := f.effective_growth_days(t)
	f.fertilize(t, FertilizerCatalog.FERT_HYPER)
	var after_hyper := f.effective_growth_days(t)
	var nominal_speed := maxi(1, ceili(base * fs))
	var nominal_hyper := maxi(1, ceili(base * fh))
	# 여덟 번을 더 번갈아 뿌려도 명목값에서 한 칸도 안 내려간다(중첩의 부재를 반복으로 잰다).
	for i in range(4):
		f.fertilize(t, FertilizerCatalog.FERT_SPEED)
		f.fertilize(t, FertilizerCatalog.FERT_HYPER)
	var after_churn := f.effective_growth_days(t)
	_check("①c 교체 임계는 **그 비료의 명목값**이다 — 성장촉진 %d(명목 %d) · 하이퍼 %d(명목 %d) · 8회 더 갈아 뿌려도 %d(중첩 0)"
			% [after_speed, nominal_speed, after_hyper, nominal_hyper, after_churn],
		after_speed == nominal_speed and after_hyper == nominal_hyper and after_churn == nominal_hyper)

	# 이군 XOR — 품질 비료를 덮으면 성숙 이득이 사라지고 품질표만 남는다(둘 중 하나뿐).
	f.fertilize(t, FertilizerCatalog.FERT_DELUXE)
	var after_deluxe := f.effective_growth_days(t)
	var state := FertilizerCatalog.state_of(f.fertilizer_of(t))
	_check("①d 2군 XOR 회복 — 디럭스를 덮으면 임계가 base(%d)로 돌아가고 품질표만 %s다(«−%d%% 성숙 + 디럭스» 동시 성립 불가)"
			% [after_deluxe, state, int(round((1.0 - fh) * 100.0))],
		after_deluxe == base and state == FertilizerCatalog.STATE_DELUXE)

	# R20 ㉠ 보존 — 다 자라기 직전 칸에 성장촉진을 뿌려도 그 자리에서 성숙하지 않는다.
	var t2 := Vector2i(4, 3)
	f.hoe(t2)
	f.plant(t2, crop)
	f._tiles[t2]["grown_days"] = base - 1
	f.fertilize(t2, FertilizerCatalog.FERT_HYPER)
	_check("①e R20 ㉠ 보존: grown %d/base %d 칸에 하이퍼를 뿌려도 임계 %d > grown이라 즉시 성숙이 없다"
			% [base - 1, base, f.effective_growth_days(t2)],
		f.effective_growth_days(t2) > base - 1 and not f.is_mature(t2))

	# R20 ㉡ 보존 — 이미 수확 대기 중인 칸은 어떤 비료를 덮어도 미성숙으로 역행하지 않는다.
	var t3 := Vector2i(5, 3)
	f.hoe(t3)
	f.plant(t3, crop)
	f.fertilize(t3, FertilizerCatalog.FERT_SPEED)
	f._tiles[t3]["grown_days"] = f.effective_growth_days(t3)
	var need_mature := f.effective_growth_days(t3)
	f.fertilize(t3, FertilizerCatalog.FERT_DELUXE)
	_check("①f R20 ㉡ 보존: 수확 대기 칸(임계 %d·grown %d)에 디럭스를 덮어도 임계 %d 그대로·성숙 유지"
			% [need_mature, int(f._tiles[t3]["grown_days"]), f.effective_growth_days(t3)],
		f.effective_growth_days(t3) == need_mature and f.is_mature(t3))

	# 구세이브 백필 불변 — 키 없는 칸은 종전 식(현재 비료의 base 곱) 그대로 굳는다.
	var g := FarmField.new()
	g.load_save({"tiles": {t: {"planted": true, "watered": false, "crop": crop,
		"grown_days": 2, "fertilizer": FertilizerCatalog.FERT_HYPER}}})
	_check("①g 구세이브 백필 불변: `need_days` 없는 칸은 종전 식 %d로 굳는다(진행 중 작물 손해 0)"
			% g.effective_growth_days(t), g.effective_growth_days(t) == nominal_hyper)
	f.free()
	g.free()

# ── ② #1 자체 파종도 매몰 가드를 문다 ───────────────────────────────────────
# 무대는 판정 자신에게 물어서 고른다(좌표 상수 0) — 플레이어를 멀리 둔 채 «네 이웃까지 전부
# 파종 가능»한 칸을 찾고, 거기 서서 같은 질문을 다시 한다.
func _check_seed_entrap(m: Node) -> void:
	print("② #1 자체 파종 매몰 가드")
	m._indoor = ""
	if m._region != RegionCatalog.HOME:
		m._rebuild_region(RegionCatalog.HOME)
	m.player.global_position = m._tile_center_px(m.SPAWN_TILE)
	var occ: Dictionary = m._home_occupied_tiles()
	var spot := Vector2i(-1, -1)
	var dirs := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	for y in range(m._outdoor_h):
		for x in range(m._grid_w):
			var c := Vector2i(x, y)
			if c == m._player_tile() or not m._is_tree_seed_free(RegionCatalog.HOME, c, occ):
				continue
			var all_free := true
			for d in dirs:
				if not m._is_tree_seed_free(RegionCatalog.HOME, c + d, occ):
					all_free = false
					break
			if all_free:
				spot = c
				break
		if spot.x >= 0:
			break
	_check("②a 무대: 안식 그리드의 %s는 **네 이웃까지 전부 파종 가능**한 빈 여백이다(성역 여덟 겹 통과)"
			% str(spot), spot.x >= 0)
	if spot.x < 0:
		return
	# 발밑 — 좌표는 한 칸도 안 옮기는 24:00 강제 취침이 만드는 바로 그 상태.
	m.player.global_position = m._tile_center_px(spot)
	occ = m._home_occupied_tiles()
	_check("②b 그 칸에 선 순간 파종 후보에서 빠진다(발밑 = 즉시 매몰)",
		m._player_tile() == spot and not m._is_tree_seed_free(RegionCatalog.HOME, spot, occ))
	# 대조 — 한 칸 옆으로 물러나면 같은 칸이 곧바로 다시 후보가 된다(막는 것은 새로 세우는 것뿐이고,
	# 퇴로가 셋 남아 있으면 이웃 칸도 여전히 통과한다 = 과잉 거절 0).
	m.player.global_position = m._tile_center_px(spot + dirs[0])
	occ = m._home_occupied_tiles()
	_check("②c 대조: 사람이 한 칸 물러나면 그 칸은 다시 후보다(퇴로 셋이 남은 이웃 칸도 그대로 통과)",
		m._is_tree_seed_free(RegionCatalog.HOME, spot, occ) \
			and m._is_tree_seed_free(RegionCatalog.HOME, spot + dirs[1], occ))
	m.player.global_position = m._tile_center_px(spot)
	occ = m._home_occupied_tiles()
	# 배치 누적 — 이 밤이 이미 심어 둔 씨앗 셋은 아직 물리에 안 섰다(충돌 재구성은 배치 끝에 온다).
	var last: Vector2i = spot + dirs[3]
	var seeded: Array = []
	for i in range(3):
		var n: Vector2i = spot + dirs[i]
		m.tree_ledger._put(RegionCatalog.HOME, n, {"species": "", "stage": 1, "hp": 1,
			"stump": false, "moss": false})
		seeded.append(n)
	var unseen := 0
	for n in seeded:
		if not m._prop_blocked_tiles.has(n):
			unseen += 1
	var pending: Dictionary = m._tree_seed_pending_solid()
	_check("②d 무대: 그 셋은 원장엔 섰지만 `_prop_blocked_tiles`엔 아직 없다(%d/3) — pending이 정확히 그 셋을 판다(%d칸)"
			% [unseen, pending.size()],
		unseen == 3 and pending.size() == 3 and pending.has(seeded[0]) and pending.has(seeded[2]))
	var blind: bool = m._would_entrap_player(last, {})
	var seeing: bool = m._would_entrap_player(last, pending)
	_check("②e 마지막 퇴로 %s — 스냅샷 한 장으론 «퇴로가 남는다»(%s)지만 pending을 실으면 매몰로 본다(%s) · 파종 판정도 그것을 따른다"
			% [str(last), str(blind), str(seeing)],
		blind == false and seeing == true \
			and not m._is_tree_seed_free(RegionCatalog.HOME, last, occ))
	for n in seeded:
		m.tree_ledger._trees[RegionCatalog.HOME].erase(n)
	m.player.global_position = m._tile_center_px(m.SPAWN_TILE)
	_check("②f 원복: 원장을 비우고 사람이 물러나면 그 칸들은 다시 후보다(과잉 거절 0)",
		m._is_tree_seed_free(RegionCatalog.HOME, last, m._home_occupied_tiles()))

# ── ③ #2 보장 미끼는 확정 체급의 비용으로 판정한다 ──────────────────────────
func _check_pledge_bait(m: Node) -> void:
	print("③ #2 보장 미끼 사전 판정")
	m.fishing = null
	m.inventory.add_item(GearCatalog.BAIT_PLEDGE, 12)
	var floor_cost: int = FishingSession.min_hook_energy(m._fishing_mods())
	# 낚싯대는 «확정 체급이 전역 최저를 넘는» 첫 티어를 쓴다 — 어떤 로스터에서도 무대가 서게
	# 카탈로그에서 뽑는다(체급 수치·어종 id를 한 톨도 안 적는다).
	var rod := ""
	var real_cost := -1
	var cls_first := -1
	for cand in [GearCatalog.ROD_T2, GearCatalog.ROD_T4]:
		m.inventory.add_item(String(cand), 1)
		var slot := -1
		for i in range(m.inventory.HOTBAR_SLOTS):
			if m.inventory.id_at(i) == String(cand):
				slot = i
				break
		if slot < 0:
			continue
		m.inventory.select(slot)
		m.energy.current = m.energy.MAX
		m.fishing = null
		m._start_fishing(Vector2i(10, 10))
		if m.fishing != null and m.fishing.energy_cost() > floor_cost:
			rod = String(cand)
			real_cost = m.fishing.energy_cost()
			cls_first = m.fishing.weight_class()
			m.fishing = null
			break
		m.fishing = null
	_check("③a 무대: 보장 미끼 %d개 + %s(허용 %d체급)로 확정 체급 %d를 뽑았다 · 전역 최저 후킹 비용 %d"
			% [m.inventory.count_of(GearCatalog.BAIT_PLEDGE), ItemCatalog.name_of(rod),
				GearCatalog.max_class_of(rod), cls_first, floor_cost],
		rod != "" and floor_cost > 0 and cls_first >= 0)
	if rod == "":
		return
	m._start_fishing(Vector2i(11, 12))
	var cls_second: int = m.fishing.weight_class() if m.fishing != null else -2
	var cost_second: int = m.fishing.energy_cost() if m.fishing != null else -2
	m.fishing = null
	_check("③b 보장 미끼는 캐스팅마다 같은 체급을 확정한다(%d ↔ %d · 비용 %d ↔ %d)이고 그 비용이 전역 최저 %d를 넘는다"
			% [cls_first, cls_second, real_cost, cost_second, floor_cost],
		cls_first == cls_second and real_cost == cost_second and real_cost > floor_cost)
	# 종전 하한(전역 최저)만 낼 수 있는 혼력 — 여기서 미끼가 탔다.
	var before: int = m.inventory.count_of(GearCatalog.BAIT_PLEDGE)
	m.energy.current = real_cost - 1
	_feed_clear(m)
	m._start_fishing(Vector2i(12, 13))
	_check("③c 확정 비용 %d를 못 내면 **미끼를 안 태우고** 물러난다(잔량 %d → %d · 세션 미개시)"
			% [real_cost, before, m.inventory.count_of(GearCatalog.BAIT_PLEDGE)],
		m.fishing == null and m.inventory.count_of(GearCatalog.BAIT_PLEDGE) == before)
	_check("③d 거절 사유가 **필요량까지** 말한다(피드에 «필요 %d»)" % real_cost,
		_feed_has(m, "필요 %d" % real_cost))
	# 낼 수 있으면 종전 그대로 던진다(막는 게이트가 아니라 확정 실패만 걷는다 — ADR-0008).
	m.energy.current = real_cost
	m._start_fishing(Vector2i(12, 14))
	_check("③e 낼 수 있으면 그대로 던진다(세션 개시 · 미끼 1개 소모 %d → %d)"
			% [before, m.inventory.count_of(GearCatalog.BAIT_PLEDGE)],
		m.fishing != null and m.inventory.count_of(GearCatalog.BAIT_PLEDGE) == before - 1)
	m.fishing = null
	m.energy.current = m.energy.MAX

# ── ④ #3 사료풀 낫질에도 사유가 뜬다(프롬프트 사슬을 실제로 태운다) ─────────
func _check_forage_prompt(m: Node) -> void:
	print("④ #3 사료풀 프롬프트")
	m._indoor = ""
	if m._region != RegionCatalog.HOME:
		m._rebuild_region(RegionCatalog.HOME)
	var t := Vector2i(-1, -1)
	for c in m.forage.all_tiles():
		if m.forage.is_grown(c):
			t = c
			break
	# 헤드리스 커서는 화면에 고정돼 있고 카메라가 사람을 따라가므로 조준 칸은 «발 칸 + 고정
	# 오프셋»이다(`_update_target`의 인접 1칸 클램프). 그 오프셋을 **실측해서** 겨눈다 —
	# 방향을 손으로 적으면 카메라 규격이 바뀌는 날 이 무대가 조용히 어긋난다.
	if t.x >= 0:
		m.player.global_position = m._tile_center_px(t)
		m._process(0.0)
		var aim_off: Vector2i = m._target - m._player_tile()
		m.player.global_position = m._tile_center_px(t - aim_off)
	m._process(0.0)
	_check("④a 무대: 다 자란 사료풀 %s를 겨눴다(조준 칸 %s)" % [str(t), str(m._target)],
		t.x >= 0 and m._target == t and m.forage.is_grown(m._target))
	if t.x < 0 or m._target != t:
		return
	var scythe_slot := -1
	for i in range(m.inventory.HOTBAR_SLOTS):
		if m.inventory.id_at(i) == ItemCatalog.SCYTHE:
			scythe_slot = i
			break
	# ㉠ 낫을 안 들었을 때 — 무엇이 필요한지 말한다(혼력과 무관한 안내).
	m.inventory.select(0 if scythe_slot != 0 else 1)
	m.energy.current = m.energy.MAX
	m._process(0.0)
	var p_tool: String = m.interact_prompt.text
	_check("④b 낫을 안 들면 필요한 도구를 말한다 — 「%s」" % p_tool,
		m.interact_prompt.visible and p_tool.contains("낫"))
	if scythe_slot < 0:
		_check("④c/④d 무대 없음: 인벤토리에 낫이 없다", false)
		return
	# ㉡ 낫 + 혼력 부족 — 종전엔 화면도 알림도 0이었다.
	m.inventory.select(scythe_slot)
	m.energy.current = m._farming_energy_cost() - 1
	m._process(0.0)
	var p_low: String = m.interact_prompt.text
	_check("④c 낫을 들고 혼력이 모자라면 사유가 뜬다 — 「%s」(형제 과금 동사와 같은 문구)" % p_low,
		m.interact_prompt.visible and p_low.contains("혼력 부족"))
	# ㉢ 낫 + 혼력 충분 — 동사와 그 결과(여물광)를 함께 말한다.
	m.energy.current = m.energy.MAX
	m._process(0.0)
	var p_ok: String = m.interact_prompt.text
	_check("④d 벨 수 있으면 동사가 뜬다 — 「%s」" % p_ok,
		m.interact_prompt.visible and p_ok.contains("[좌클릭]") and p_ok.contains("사료풀"))

# ── ⑤ #4 과수 프롬프트는 동사가 설 때만 혼력을 탓한다 ───────────────────────
func _check_orchard_prompt(m: Node) -> void:
	print("⑤ #4 과수·묘목 프롬프트 순서")
	m._indoor = ""
	if m._region != RegionCatalog.HOME:
		m._rebuild_region(RegionCatalog.HOME)
	var zone: Rect2i = m.ORCHARD_ZONE_RECT
	var anchor := Vector2i(-1, -1)
	for y in range(zone.position.y + 1, zone.end.y - 1):
		for x in range(zone.position.x + 1, zone.end.x - 1):
			var a := Vector2i(x, y)
			if m.orchard.can_plant(a, m._is_tree_blocked):
				anchor = a
				break
		if anchor.x >= 0:
			break
	var fruit: String = FruitTreeCatalog.ids()[0]
	var planted: bool = anchor.x >= 0 and m.orchard.plant(anchor, fruit, m.clock.day, m._is_tree_blocked)
	m._target = anchor
	m._target_valid = false
	var low: int = m._farming_energy_cost() - 1
	_check("⑤a 무대: %s에 %s 묘목을 심었다(오늘 심어 미성숙 · 결실 0)"
			% [str(anchor), FruitTreeCatalog.name_of(fruit)],
		planted and m.orchard.has_tree(anchor) and not m.orchard.is_mature(anchor, m.clock.day))
	if not planted:
		return
	m.energy.current = low
	var p_low: String = m._farm_prompt()
	m.energy.current = m.energy.MAX
	var p_full: String = m._farm_prompt()
	_check("⑤b 거둘 것이 없는 나무 위에서는 혼력이 낮아도 **조용하다** — 저혼력 「%s」 / 만혼력 「%s」(둘이 같다)"
			% [p_low, p_full], p_low == "" and p_full == "")
	# 묘목 갈래 — 못 심는 자리에서는 진짜 사유가, 심을 수 있는 자리에서는 혼력이 뜬다.
	var sap_id: String = ItemCatalog.sapling_id(fruit)
	m.inventory.add_sapling(fruit)
	var sap_slot := -1
	for i in range(m.inventory.HOTBAR_SLOTS):
		if m.inventory.id_at(i) == sap_id:
			sap_slot = i
			break
	if sap_slot < 0:
		_check("⑤c/⑤d 무대 없음: 묘목을 인벤토리에 못 넣었다", false)
		return
	m.inventory.select(sap_slot)
	# 무대는 판정에게 물어 고른다: ㉠ 어느 나무의 3×3에도 안 들면서 ㉡ 3×3이 막힌 칸(진짜 사유가
	# 나와야 하는 자리) · ㉢ 심을 수 있는 칸(혼력 게이트가 그대로 남아야 하는 자리).
	var blocked_spot := Vector2i(-1, -1)
	var free_spot := Vector2i(-1, -1)
	for y2 in range(zone.position.y, zone.end.y):
		for x2 in range(zone.position.x, zone.end.x):
			var b := Vector2i(x2, y2)
			if m.orchard.tree_at(b) != Orchard.TREE_NONE:
				continue
			if m.orchard.can_plant(b, m._is_tree_blocked):
				if free_spot.x < 0:
					free_spot = b
			elif blocked_spot.x < 0:
				blocked_spot = b
	m._target = blocked_spot
	m.energy.current = low
	var blocked_low: String = m._farm_prompt()
	_check("⑤c 3×3이 막힌 자리 %s에서는 저혼력이어도 **진짜 사유**를 댄다 — 「%s」"
			% [str(blocked_spot), blocked_low],
		blocked_spot.x >= 0 and blocked_low.contains("못 심음"))
	m._target = free_spot
	var open_low: String = m._farm_prompt()
	m.energy.current = m.energy.MAX
	var open_full: String = m._farm_prompt()
	_check("⑤d 심을 수 있는 자리에서는 혼력 게이트가 그대로 남는다 — 저혼력 「%s」 / 만혼력 「%s」"
			% [open_low, open_full],
		free_spot.x >= 0 and open_low.contains("혼력 부족") and open_full.contains("묘목 심기"))

# ── ⑥ #5 완주 트로피는 등재한 그 자리에서 선다 ──────────────────────────────
func _check_codex_trophy(m: Node) -> void:
	print("⑥ #5 도감 완주 래치")
	var last_fish := ""
	for id in m.codex.tracked_ids():
		if FishCatalog.has(String(id)):
			last_fish = String(id)
			break
	var pre_left := 0
	for id in m.codex.tracked_ids():
		if String(id) == last_fish:
			pre_left += 1
			continue
		m.codex.record(String(id), m.clock.day)
	_check("⑥a 무대: 마지막 한 종(%s)만 남기고 전부 등재했다(%d/%d)"
			% [ItemCatalog.name_of(last_fish), m.codex.shipped_count(), Codex.total_count()],
		last_fish != "" and pre_left == 1 and not m.codex.is_complete() and not m.codex.has_trophy())
	m.inventory.add_item(last_fish, 1, 0)
	_feed_clear(m)
	var res: Dictionary = m._sell_fish_n(last_fish, 0, 1, true)
	_check("⑥b 무대: 생선가게 즉시 환전으로 그 한 종을 팔았다(%d개 · 등재 %d/%d)"
			% [int(res.get("count", 0)), m.codex.shipped_count(), Codex.total_count()],
		int(res.get("count", 0)) == 1 and m.codex.is_complete())
	_check("⑥c 그 순간 트로피가 선다(취침을 안 기다린다) — has_trophy %s · trophy_pending %s"
			% [str(m.codex.has_trophy()), str(m.codex.trophy_pending())],
		m.codex.has_trophy() and not m.codex.trophy_pending())
	_check("⑥d 완주 알림도 그 프레임에 뜬다(피드에 «완주»)", _feed_has(m, "완주"))
	# 1회성 래치는 그대로다 — 아침 정산 창구가 다시 물어도 두 번 뜨지 않는다.
	_feed_clear(m)
	m._claim_codex_trophy(m.clock.day)
	_check("⑥e 래치는 1회성이다 — 아침 창구가 다시 물어도 알림이 두 번 뜨지 않는다",
		not _feed_has(m, "완주"))

# ── ⑦ #6 누적 수확이 앵커 트랙을 그 자리에서 움직인다 ───────────────────────
func _check_okja_harvest_axis(m: Node) -> void:
	print("⑦ #6 앵커 deed — 수확 축 라이브")
	m._mark_spine_bit(m.SPINE_B4)
	m._mark_spine_bit(m.SPINE_B5)
	m._mark_spine_bit(m.SPINE_B6)
	m._open_okja_track()
	for id in Museum.donatable_ids():
		m.museum.donate(String(id), m.clock.day)
	var r = m._resident(m.OKJA_RID)
	var donatable: int = Museum.donatable_ids().size()
	# 만점에 딱 못 미치는 자리 — 남은 몫이 «수확 축 하나»가 되게 잡는다(값은 판정식에서 판다).
	var short_h := Spine.OKJA_TEND_HARVEST
	while short_h > 0 and Spine.okja_deed_points(true, m.museum.donated_count(), donatable, short_h) \
			>= Affinity.MAX_POINTS:
		short_h -= 1
	m._run_harvested = short_h
	m._refresh_okja_track()
	_check("⑦a 무대: 트랙 개통 · 혼백관 만점(%d/%d) · 누적 수확 %d에서 점수 %d(만점 %d 미만 · 남은 몫은 수확 축 하나)"
			% [m.museum.donated_count(), donatable, m._run_harvested, r.affinity.points,
				Affinity.MAX_POINTS],
		m._okja_track_open() and r != null and r.affinity != null \
			and m.museum.donated_count() == donatable and short_h > 0 \
			and r.affinity.points < Affinity.MAX_POINTS \
			and r.affinity.hearts() < Affinity.MAX_HEARTS)
	var before_hearts: int = r.affinity.hearts()
	var steps := Spine.OKJA_TEND_HARVEST - short_h
	for i in range(steps):
		m._count_run_harvest()
	var expected: int = Spine.okja_deed_points(true, m.museum.donated_count(), donatable,
		m._run_harvested)
	_check("⑦b 수확 %d번을 세는 동안 점수가 원장에서 다시 파생된다(%d → %d · 판정식 값 %d)"
			% [steps, Affinity.MAX_POINTS - 1, r.affinity.points, expected],
		r.affinity.points == expected and expected == Affinity.MAX_POINTS)
	_check("⑦c 하트도 같은 프레임에 따라온다(♡%d → ♡%d) — 관계 탭이 자기모순을 그리지 않는다"
			% [before_hearts, r.affinity.hearts()],
		r.affinity.hearts() == Affinity.MAX_HEARTS and r.affinity.stage == r.affinity.points_hearts())
	_check("⑦d 그 자리에서 「명부 혼례 부적」 창구가 열린다(다 갚은 그날 잠겨 보이지 않는다)",
		m._myeongbu_quest_open())

# ── ⑧ #7 잠긴 외관이 이름과 게이트를 말한다 ─────────────────────────────────
func _check_trial_label(m: Node) -> void:
	print("⑧ #7 명부 시련장 라벨")
	m._indoor = ""
	m._rebuild_region(RegionCatalog.EOPHWA_MINE)
	var locked_text := ""
	for lbl in m._labels:
		if String(lbl.text).contains("시련장"):
			locked_text = String(lbl.text)
			break
	_check("⑧a 무대: 반딧넋 %d/%d로 문은 아직 닫혀 있다"
			% [m.fireflies.collected_count(), FireflySouls.GATE_COUNT], not m.trial_ground_open())
	_check("⑧b 잠긴 외관이 이름과 문턱을 말한다 — 「%s」" % locked_text,
		locked_text != "" and locked_text.contains(str(FireflySouls.GATE_COUNT)))
	# 문턱을 넘기면 같은 라벨이 위상을 바꾼다(나락 진입로 점등과 같은 문법).
	var day: int = m.clock.day
	for id in FireflySouls.all_ids():
		if m.fireflies.collected_count() >= FireflySouls.GATE_COUNT:
			break
		m.fireflies.collect(String(id), day)
	m._rebuild_region(RegionCatalog.EOPHWA_MINE)
	var open_text := ""
	for lbl in m._labels:
		if String(lbl.text).contains("시련장"):
			open_text = String(lbl.text)
			break
	_check("⑧c 문턱(반딧넋 %d)을 넘기면 같은 라벨이 위상을 바꾼다 — 「%s」"
			% [FireflySouls.GATE_COUNT, open_text],
		m.trial_ground_open() and open_text != "" and open_text != locked_text)
	m._rebuild_region(RegionCatalog.HOME)

# ── ⑨ #8 [경지] 미개방 안내가 화면에 선다 ───────────────────────────────────
func _check_mastery_locked_row(m: Node) -> void:
	print("⑨ #8 [경지] 미개방 안내")
	var first := String(ProfessionCatalog.SKILLS[0])
	var levels: Dictionary = m._skill_level_map()
	var pending: Array = Mastery.pending_skills(levels)
	_check("⑨a 무대: 아직 만렙이 아닌 스킬이 %d개 남았다(층 미개방)" % pending.size(),
		not Mastery.is_open(levels) and pending.size() > 0)
	var row: Dictionary = m._mastery_row(first)
	var text := String(row.get("text", ""))
	var named := 0
	for s in pending:
		if text.contains(ProfessionCatalog.skill_name(String(s))):
			named += 1
	_check("⑨b 첫 행에 «무엇이 남았나»가 뜬다 — 「%s」(남은 %d개 중 이름이 실린 것 %d개)"
			% [text, pending.size(), named], text != "" and named == pending.size())
	var others := 0
	for i in range(1, ProfessionCatalog.SKILLS.size()):
		if not m._mastery_row(String(ProfessionCatalog.SKILLS[i])).is_empty():
			others += 1
	_check("⑨c 나머지 네 행은 그대로 조용하다(잔소리 경계 보존 — 줄이 서는 행 %d개)" % others,
		others == 0)
	# 그리기 입력까지 실린다 — main이 프레임에 넘기는 그 payload에 이 줄이 들어 있다.
	m.frame.set_skills(m._skill_rows())
	var piped := String(m.frame._skill_rows[0].get("mastery", {}).get("text", ""))
	# ★ 빈 문자열끼리의 일치는 **공허 통과**다(줄이 아예 없으면 둘 다 "") — 비어 있지 않음을 함께 잰다.
	_check("⑨d 그 줄이 숙련 탭 렌더 입력까지 실린다(`set_skills` → 「%s」)" % piped,
		piped != "" and piped == text)
	# 5스킬 만렙이면 ㉠ 줄은 사라지고 종전 세 상태로 돌아간다(가법 확장 · 거동 불변).
	var prev := [m._farming_xp, m._foraging_xp, m._fishing_xp, m._mining_xp, m._combat_xp]
	var cap: int = int(FarmSkill.XP_THRESHOLDS[FarmSkill.MAX_LEVEL - 1])
	m._farming_xp = cap
	m._foraging_xp = cap
	m._fishing_xp = cap
	m._mining_xp = cap
	m._combat_xp = cap
	var open_row: Dictionary = m._mastery_row(first)
	_check("⑨e 5스킬 만렙이 되면 그 줄이 사라지고 종전 상태 줄로 갈린다 — 「%s」"
			% String(open_row.get("text", "")),
		Mastery.is_open(m._skill_level_map()) and not String(open_row.get("text", "")).contains("잠김"))
	m._farming_xp = prev[0]
	m._foraging_xp = prev[1]
	m._fishing_xp = prev[2]
	m._mining_xp = prev[3]
	m._combat_xp = prev[4]

# ── ⑩ #9 연출을 연 프레임은 거기서 끝난다 ───────────────────────────────────
# 이 항목만 **소스 순서 단언**이다: 봉합이 "상태를 바꾼 직후의 재검사"라 잴 대상이 값이 아니라
# 자리다(컷신 진입은 게이트 셋을 실제로 채워야 열리므로 라이브 재현이 이 스위트의 몫을 넘는다).
# 니들은 반드시 `_process` 안에서 세고, **순서**까지 잰다 — 재검사가 F9 분기보다 앞이어야 뜻이 산다.
func _check_cutscene_frame_guard() -> void:
	print("⑩ #9 컷신 진입 프레임 가드")
	var b5 := _line_in_func(_src, "func _process", "_maybe_spine_b5()")
	var resume := _line_in_func(_src, "func _process", "_maybe_resume_spine()")
	var guard := _line_in_func(_src, "func _process", "if _transitioning or cutscene != null:")
	var f9 := _line_in_func(_src, "func _process", "Input.is_action_just_pressed(\"load_game\")")
	_check("⑩a 무대: `_process` 안에 네 자리가 다 있다(b5 %d행 · resume %d행 · 재검사 %d행 · F9 %d행)"
			% [b5 + 1, resume + 1, guard + 1, f9 + 1],
		b5 > 0 and resume > 0 and guard > 0 and f9 > 0)
	_check("⑩b 재검사가 **두 진입 창구 뒤·F9 분기 앞**에 선다(연출을 연 프레임이 거기서 끝난다)",
		guard > b5 and guard > resume and guard < f9)

# ── ⑪ #11 집행이 0이면 알리지 않는다 ────────────────────────────────────────
func _check_jealousy_notice(m: Node) -> void:
	print("⑪ #11 질투 알림 — 0건 무고지")
	var roster: Array = m.JEALOUSY_ROSTER
	var chosen := String(roster[0])
	for rid in roster:
		var r = m._resident(String(rid))
		if r != null and r.affinity != null:
			r.affinity.points = 0
			r.affinity.stage = 0
	m._jealousy.clear()
	_feed_clear(m)
	m._apply_jealousy(chosen)
	_check("⑪a 무대: 나머지 둘이 ♡0이라 실제 감점이 0건이다(원장 %d건)" % m._jealousy.size(),
		m._jealousy.is_empty())
	_check("⑪b 아무도 안 깎였으면 «서운한 기색»도 안 뜬다(관계 탭에 보여 줄 변화가 0건이다)",
		not _feed_has(m, "서운한"))
	# 대조 — 한 사람이라도 실제로 깎이면 종전 그대로 한 줄이 뜬다.
	var other = m._resident(String(roster[1]))
	if other != null and other.affinity != null:
		other.affinity.points = m.JEALOUSY_HIT * 2
	_feed_clear(m)
	m._apply_jealousy(chosen)
	_check("⑪c 대조: 실제로 깎인 사람이 있으면 종전대로 한 줄이 뜬다(원장 %d건)" % m._jealousy.size(),
		m._jealousy.size() == 1 and _feed_has(m, "서운한"))
	for rid in roster:
		var r2 = m._resident(String(rid))
		if r2 != null and r2.affinity != null:
			r2.affinity.points = 0
			r2.affinity.stage = 0
	m._jealousy.clear()

# ── ⑫ #12 밭 오버레이는 안식에서만 칠해진다 ─────────────────────────────────
func _check_field_layer_region(m: Node) -> void:
	print("⑫ #12 field_layer 구역 축")
	m._indoor = ""
	if m._region != RegionCatalog.HOME:
		m._rebuild_region(RegionCatalog.HOME)
	var t := Vector2i(-1, -1)
	for c in m.farm.tilled_tiles():
		t = c
		break
	if t.x < 0:
		var patch: Rect2i = m.STARTER_PATCH_RECT
		t = patch.position
		m.farm.hoe(t)
	_check("⑫a 무대: 안식에서 경작한 칸 %s에 오버레이가 칠해져 있다(source %d)"
			% [str(t), m.field_layer.get_cell_source_id(t)],
		m.field_layer.get_cell_source_id(t) >= 0)
	# 집 밖에서 날이 바뀌는 상황 — 아침 정산이 칸마다 쏘는 tile_changed 그대로.
	m._rebuild_region(RegionCatalog.NARU_VILLAGE)
	m.farm._tiles[t]["watered"] = true
	m.farm.advance_day()
	var leaked: int = m.field_layer.get_cell_source_id(t)
	_check("⑫b 마을에 선 채 하루가 지나도 그 좌표에 고랑이 안 찍힌다(source %d = 비었음)" % leaked,
		leaked < 0)
	# 복원 경로 — 안식으로 돌아오면 원장에서 통째로 다시 칠한다(상태 손실 0).
	m._rebuild_region(RegionCatalog.HOME)
	_check("⑫c 안식으로 돌아오면 원장에서 다시 칠해진다(source %d) — 미룬 것은 그림뿐이다"
			% m.field_layer.get_cell_source_id(t),
		m.field_layer.get_cell_source_id(t) >= 0 and m.farm.is_tilled(t))

# ── ⑬ #13 매몰 구제가 **프롭 충돌 원장까지** 본다(=#1의 잔여 축) ──────────────
# #13의 스포너 축(발밑 파종)은 #1 봉합이 이미 닫았다 = DUP. 남은 것은 시나리오 후단의
# "탈출도 막혀 있다" — 그 구세이브를 열 길이다.
func _check_buried_restore(m: Node) -> void:
	print("⑬ #13 로드 매몰 구제(잔여 축 · 스포너 축은 DUP(#1))")
	m._indoor = ""
	if m._region != RegionCatalog.HOME:
		m._rebuild_region(RegionCatalog.HOME)
	# 무대 = R21 #1 **이전에 굳은 세이브**: 발밑에 원장 나무가 선 좌표.
	var t := Vector2i(-1, -1)
	var occ: Dictionary = m._home_occupied_tiles()
	for y in range(m._outdoor_h):
		for x in range(m._grid_w):
			var c := Vector2i(x, y)
			if m._is_tree_seed_free(RegionCatalog.HOME, c, occ) and not m.tree_ledger.has_slot(RegionCatalog.HOME, c):
				t = c
				break
		if t.x >= 0:
			break
	if t.x < 0:
		_check("⑬ 무대 없음: 빈 파종 칸을 못 찾았다", false)
		return
	m.tree_ledger._put(RegionCatalog.HOME, t, {"species": TreeLedger.SP_PINE, "stage": 1,
		"hp": TreeLedger.HP_SAPLING, "stump": false, "moss": false})
	m._rebuild_prop_collision()
	_check("⑬a 무대: %s에 원장 나무가 서서 **풀타일 충돌**이 걸렸다 — 그런데 `_grid` 축(`_tile_blocked`)은 그것을 못 본다(%s) · 진실원(`_player_blocked_at`)은 본다(%s)"
			% [str(t), str(m._tile_blocked(t)), str(m._player_blocked_at(t))],
		m._prop_blocked_tiles.has(t) and not m._tile_blocked(t) and m._player_blocked_at(t))
	# 그 좌표를 실은 세이브를 연다 — 종전 구제는 `_tile_blocked`만 봐서 그대로 벽 안에 세웠다.
	m._restore_location({"region": RegionCatalog.HOME, "indoor": "", "player_tile": t})
	var landed: Vector2i = m._player_tile()
	_check("⑬b 그 좌표로 복원하면 **구제된다** — %s가 아니라 %s(구역 스폰)에 선다"
			% [str(t), str(landed)],
		landed != t and landed == m.SPAWN_TILE and not m._player_blocked_at(landed))
	m.tree_ledger.clear_slot(RegionCatalog.HOME, t)
	m._rebuild_prop_collision()
	_check("⑬c 대조: 나무를 치우면 같은 좌표가 다시 정상 복원된다(과잉 구제 0)",
		not m._player_blocked_at(t))

# ── ⑭ #14 숲 재출현·큰 그루터기도 사람이 선 칸은 안 덮는다 ───────────────────
func _check_forest_respawn_guard(m: Node) -> void:
	print("⑭ #14 숲 재출현·큰 그루터기 매몰 가드")
	# ㉠ main이 넣는 거부권 콜백 자체 — 발밑은 거절, 먼 칸은 허용, 그리고 **배치 누적**을 든다.
	m._indoor = ""
	if m._region != RegionCatalog.HOME:
		m._rebuild_region(RegionCatalog.HOME)
	m.player.global_position = m._tile_center_px(m.SPAWN_TILE)
	var here: Vector2i = m._player_tile()
	var cb: Callable = m._tree_respawn_ok_cb()
	var foot_ok: bool = cb.call(m._region, here)
	var far_ok: bool = cb.call(m._region, here + Vector2i(0, -6))
	var other_region_ok: bool = cb.call(RegionCatalog.JEOSEUNG_FOREST, here)
	_check("⑭a 거부권 콜백: 발밑 %s는 거절(%s) · 먼 칸은 허용(%s) · 사람이 없는 무대는 그대로 허용(%s)"
			% [str(here), str(foot_ok), str(far_ok), str(other_region_ok)],
		foot_ok == false and far_ok == true and other_region_ok == true)
	# 배치 누적 — 네 이웃을 차례로 승인해 나가면 마지막 하나에서 «퇴로 0»이 되어 거절된다.
	var dirs := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	var approved: Array = []
	var denied: Array = []
	for d in dirs:
		var n: Vector2i = here + d
		if m._player_blocked_at(n):
			continue
		if bool(cb.call(m._region, n)):
			approved.append(n)
		else:
			denied.append(n)
	_check("⑭b 같은 밤의 배치가 누적된다 — 승인 %s · 마지막 퇴로에서 거절 %s(스냅샷 한 장이면 전부 통과했다)"
			% [str(approved), str(denied)],
		approved.size() >= 1 and denied.size() == 1)
	# ㉡ 원장이 실제로 그 거부권을 문다 — 독립 원장에 숲 빈 슬롯 하나만 두고 굴린다.
	var led := TreeLedger.new()
	var forest := RegionCatalog.JEOSEUNG_FOREST
	var ft := Vector2i(5, 5)
	led._put(forest, ft, {"species": "", "stage": TreeLedger.STAGE_EMPTY, "hp": 0,
		"stump": false, "moss": false})
	var deny := func(_r: String, _t: Vector2i) -> bool: return false
	var regrow_day := -1
	for d in range(1, 400):
		if not led.advance_day(d, Callable(), deny)["regrown"].is_empty():
			regrow_day = d
			break
	_check("⑭c 거부권을 늘 false로 주면 %d일을 굴려도 빈 슬롯이 한 번도 안 살아난다(stage %d 유지)"
			% [399, led.stage_at(forest, ft)],
		regrow_day < 0 and led.stage_at(forest, ft) == TreeLedger.STAGE_EMPTY)
	# 같은 원장·같은 날들을 **허용**으로 다시 굴리면 살아난다 = ⑭c가 공허하지 않다.
	var allow_day := -1
	for d in range(1, 400):
		if not led.advance_day(d)["regrown"].is_empty():
			allow_day = d
			break
	_check("⑭d 대조: 허용이면 %d일에 되살아난다(stage %d) — 거부권이 유일한 차이"
			% [allow_day, led.stage_at(forest, ft)],
		allow_day > 0 and led.stage_at(forest, ft) == TreeLedger.REGROW_STAGE)
	# 큰 그루터기(확률 없는 매일 100% 부활)도 같은 거부권을 문다.
	var led2 := TreeLedger.new()
	var lt := Vector2i(7, 7)
	led2._put(forest, lt, {"species": "", "stage": 0, "hp": 0, "stump": false, "moss": false,
		"large": TreeLedger.KIND_LARGE_STUMP, "gone": true})
	var blocked_out: Dictionary = led2.advance_day(9, Callable(), deny)
	var freed_out: Dictionary = led2.advance_day(9)
	_check("⑭e 큰 그루터기(매일 100%% 부활)도 거절되면 안 서고(%d건) 허용이면 그 자리에서 선다(%d건)"
			% [blocked_out["large_respawned"].size(), freed_out["large_respawned"].size()],
		blocked_out["large_respawned"].is_empty() and freed_out["large_respawned"].size() == 1)

# ── ⑮ #15 집 밖에서 잔 밤의 마당 파종은 **이월**된다 ─────────────────────────
func _check_seed_pending_carry(m: Node) -> void:
	print("⑮ #15 자체 파종 이월 표")
	m._indoor = ""
	if m._region != RegionCatalog.HOME:
		m._rebuild_region(RegionCatalog.HOME)
	m.player.global_position = m._tile_center_px(m.SPAWN_TILE)
	# ★[폴리시 R24 #18] 표가 스칼라 1칸 → 누적 배열이 됐다(연속 강제 취침이 앞 밤을 덮던 자리).
	#   이 무대가 재는 계약(«집 밖 밤은 표가 서고, 귀가 첫 프레임이 그 밤을 한 번만 집행한다»)은
	#   그대로고 담는 그릇만 갈렸다.
	m._tree_seed_pending_days = []
	# 파종이 **실제로 나는 밤**을 찾는다(0건인 밤을 무대로 쓰면 뒤 단언이 공허하다). 찾은 뒤
	# 원장을 그 자리에서 원복해 무대를 되돌린다.
	var cb: Callable = m._tree_seed_free_cb()
	var seed_day := -1
	var dry: Array = []
	for d in range(2, 200):
		var got: Array = m.tree_ledger.catch_up_seeding(d, cb)
		if not got.is_empty():
			seed_day = d
			dry = got
			for e in got:
				m.tree_ledger.clear_slot(RegionCatalog.HOME, e["tile"])
			break
	_check("⑮a 무대: %d일 밤은 마당 파종이 %d그루 나는 밤이다(원복 완료 — 지금 원장엔 없다)"
			% [seed_day, dry.size()],
		seed_day > 0 and not dry.is_empty()
		and not m.tree_ledger.has_slot(RegionCatalog.HOME, dry[0]["tile"]))
	if seed_day < 0:
		return
	# 그 밤을 **마을에서** 맞는다 — 판정 콜백이 무효라 원장은 파종 블록을 건너뛴다.
	m._rebuild_region(RegionCatalog.NARU_VILLAGE)
	_check("⑮b 무대: 안식 밖에서는 파종 판정 콜백이 무효다(안식 그리드를 물어볼 수 없다)",
		not m._tree_seed_free_cb().is_valid())
	var before: int = m.tree_ledger.occupied_count(RegionCatalog.HOME)
	m._on_day_advanced(seed_day)
	var after_night: int = m.tree_ledger.occupied_count(RegionCatalog.HOME)
	var before_tiles: Dictionary = {}
	for t in m.tree_ledger.tiles(RegionCatalog.HOME):
		if m.tree_ledger.is_occupied(RegionCatalog.HOME, t):
			before_tiles[t] = true
	_check("⑮c 그 밤엔 파종이 0그루지만(%d → %d) **표가 선다**(밀린 밤 %s)"
			% [before, after_night, str(m._tree_seed_pending_days)],
		after_night == before and str(m._tree_seed_pending_days) == str([seed_day]))
	# 귀가 프레임이 그 밤만 따로 집행한다 — 좌표까지 그날 결과 그대로다.
	m._rebuild_region(RegionCatalog.HOME)
	m.player.global_position = m._tile_center_px(m.SPAWN_TILE)
	m._process(0.0)
	# 그 프레임에 **새로 선 칸**을 원장 차집합으로 판다(카운트가 아니라 칸 목록으로 잰다).
	#   ★ dry-run 집합과의 좌표 일치는 요구하지 않는다: 사이에 아침 훅이 성장·잡초를 돌려
	#     성숙목·성역이 달라질 수 있고, 이 단언이 재는 것은 «그 밤이 집행됐는가»다.
	var fresh: Array = []
	for t in m.tree_ledger.tiles(RegionCatalog.HOME):
		if m.tree_ledger.is_occupied(RegionCatalog.HOME, t) and not before_tiles.has(t):
			fresh.append(t)
	var not_free_before := 0
	for t in fresh:
		if before_tiles.has(t):
			not_free_before += 1
	_check("⑮d 안식에 다시 선 첫 프레임이 그 밤을 집행한다 — 표 소비(%s) · 그 프레임에 새로 선 칸 %s(전부 직전엔 비어 있던 자리 · 겹침 %d)"
			% [str(m._tree_seed_pending_days), str(fresh), not_free_before],
		m._tree_seed_pending_days.is_empty() and not fresh.is_empty() and not_free_before == 0)
	var after_catch: int = m.tree_ledger.occupied_count(RegionCatalog.HOME)
	m._process(0.0)
	_check("⑮e 표는 한 번만 소비된다 — 다음 프레임에 두 번째 파종이 없다(%d 그대로)" % after_catch,
		m.tree_ledger.occupied_count(RegionCatalog.HOME) == after_catch)
	for t in fresh:
		m.tree_ledger.clear_slot(RegionCatalog.HOME, t)

# ── ⑯ #16 F9 로드가 주민 보간 걷기를 끊는다 ──────────────────────────────────
func _check_load_cancels_walk(m: Node) -> void:
	print("⑯ #16 로드 ↔ 주민 걷기")
	# `Resident.walk`는 **첫 스테이션 전환에서** main이 만든다(`_begin_resident_walk`) — 부팅
	# 직후엔 null이라, 그 자리에서 같은 인스턴스를 세워 «걷는 중»을 재현한다(로드 경로가 보는 것은
	# 인스턴스 하나뿐이라 무대가 실물과 같다).
	var r = null
	for rr in m._residents:
		if rr.node != null:
			r = rr
			break
	if r == null:
		_check("⑯ 무대 없음: 몸이 있는 주민이 없다", false)
		return
	if r.walk == null:
		r.walk = ResidentWalk.new()
	m._save_or_warn()
	var from_px: Vector2 = m._tile_center_px(Vector2i(10, 10))
	var path := PackedVector2Array([m._tile_center_px(Vector2i(40, 40))])
	r.walk.start(from_px, path)
	if r.node.has_method("set_walk_offset"):
		r.node.set_walk_offset(r.walk.offset())
	_check("⑯a 무대: %s가 보간 걷기 중이다(남은 거리 %.0fpx — 화면의 몸이 논리 칸 밖에 있다)"
			% [r.display_name, r.walk.remaining_px()],
		r.walk.is_walking() and r.walk.remaining_px() > 0.0)
	var loaded: bool = m._load_game()
	_check("⑯b F9 로드가 그 세션을 버린다(로드 %s · 걷는 중 %s) — 낚시·체키·밤 바와 같은 줄"
			% [str(loaded), str(r.walk.is_walking())],
		loaded and not r.walk.is_walking())

# ── ⑰ #19 혼력 바의 "취침 신호"가 실제 동사 비용을 눈금으로 쓴다 ─────────────
func _check_energy_bar_scale(m: Node) -> void:
	print("⑰ #19 혼력 바 눈금")
	var lowest: int = m._lowest_action_cost()
	_check("⑰a 무대: 지금 가장 싼 동사 비용은 %d로, 고정 눈금 %d보다 싸다(그 사이가 거짓말 구간이었다)"
			% [lowest, SoulEnergy.COST_PER_ACTION],
		lowest > 0 and lowest < SoulEnergy.COST_PER_ACTION)
	m._refresh_clock_hud()
	_check("⑰b HUD 갱신이 그 눈금을 바에 흘려 넣는다(vitals.low_cost = %d)" % m.vitals.low_cost,
		m.vitals.low_cost == lowest)
	# 그 눈금이 실제로 색을 가른다 — 사이 구간에서는 아직 안 식고, 최저치 아래에서 식는다.
	var mid: int = SoulEnergy.COST_PER_ACTION - 1
	m.energy.current = mid
	var lit_mid: bool = m.energy.can_act(m.vitals.low_cost)
	m.energy.current = lowest - 1
	var lit_low: bool = m.energy.can_act(m.vitals.low_cost)
	m.energy.current = m.energy.MAX
	_check("⑰c 혼력 %d에서는 아직 할 수 있는 일이 남아 바가 안 식고(%s), %d에서는 식는다(%s)"
			% [mid, str(lit_mid), lowest - 1, str(lit_low)],
		lit_mid and not lit_low)
	# 저장소 전체에서 무인자 `can_act()` 호출부가 0 — R6의 회귀 단언이 main.gd만 읽어 놓친 축이다.
	var naked: Array = []
	var dir := DirAccess.open("res://")
	if dir != null:
		for f in dir.get_files():
			if not String(f).ends_with(".gd") or String(f) == "energy.gd":
				continue   # 기본값의 **소유자**는 제외 — 그 안의 무인자 호출이 곧 depleted의 정의다
			var lines := _lines_of_file("res://" + String(f))
			for i in range(lines.size()):
				if lines[i].strip_edges().begins_with("#"):
					continue
				if lines[i].contains("can_act()"):
					naked.append("%s:%d" % [String(f), i + 1])
	_check("⑰d 소비자 쪽(energy.gd 밖)에 무인자 `can_act()` 호출부가 한 곳도 없다 — R6의 회귀 단언이 main.gd만 읽어 놓쳤던 축(잔존: %s)" % str(naked),
		naked.is_empty())

# ── ⑱ #20·#21 설치물 안내 사슬에도 무대 술어가 있다 ──────────────────────────
func _check_installation_prompt_region(m: Node) -> void:
	print("⑱ #20·#21 스프링클러·레어크로우 안내 구역 축")
	m._indoor = ""
	if m._region != RegionCatalog.HOME:
		m._rebuild_region(RegionCatalog.HOME)
	# 설치 — 원장에 좌표를 남긴다(구역 축이 없는 그 원장).
	var spot := Vector2i(-1, -1)
	for t in m.farm.tilled_tiles():
		if m._can_place_sprinkler(t):
			spot = t
			break
	if spot.x < 0:
		_check("⑱ 무대 없음: 스프링클러를 놓을 칸이 없다", false)
		return
	var spr_id := String(ItemCatalog.SPRINKLER_TIERS.keys()[0])
	var crow_id := String(ItemCatalog.RARECROWS[1])
	m.sprinkler.place(spot, ItemCatalog.sprinkler_tier_of(spr_id))
	m.rarecrow.place(spot + Vector2i(1, 0), String(ItemCatalog.RARECROWS[0]))
	m.inventory.add_item(spr_id, 1)
	m.inventory.add_item(crow_id, 1)
	var spr_slot := -1
	var crow_slot := -1
	for i in range(Inventory.SIZE):
		if m.inventory.id_at(i) == spr_id and spr_slot < 0:
			spr_slot = i
		if m.inventory.id_at(i) == crow_id and crow_slot < 0:
			crow_slot = i
	_check("⑱a 무대: 안식 %s·%s에 설치물이 서 있고 원장은 좌표만 든다(구역 축 없음) · 손에 들 %s·%s도 있다"
			% [str(spot), str(spot + Vector2i(1, 0)), ItemCatalog.name_of(spr_id),
				ItemCatalog.name_of(crow_id)],
		m.sprinkler.has_at(spot) and m.rarecrow.has_at(spot + Vector2i(1, 0))
		and m.inventory.count_of(spr_id) > 0 and m.inventory.count_of(crow_id) > 0)
	# 같은 좌표를 **다른 구역**에서 겨눈다 — 마을은 100×72라 그 칸이 실재한다.
	m._rebuild_region(RegionCatalog.NARU_VILLAGE)
	m.player.global_position = m._tile_center_px(spot)
	m._process(0.0)
	var aim_off: Vector2i = m._target - m._player_tile()
	m.player.global_position = m._tile_center_px(spot - aim_off)
	m.inventory.select(spr_slot)
	m._process(0.0)
	var spr_text: String = m.interact_prompt.text if m.interact_prompt.visible else ""
	_check("⑱b 마을에서 그 좌표를 겨누면 남의 구역 원장이 안 샌다 — 든 것 %s · 조준 %s · 안내 「%s」(회수 안내 없음)"
			% [ItemCatalog.name_of(m.inventory.selected_id()), str(m._target), spr_text],
		m.inventory.selected_id() == spr_id and m._target == spot and not spr_text.contains("회수"))
	m.player.global_position = m._tile_center_px(spot + Vector2i(1, 0) - aim_off)
	m.inventory.select(crow_slot)
	m._process(0.0)
	var crow_text: String = m.interact_prompt.text if m.interact_prompt.visible else ""
	_check("⑱c 레어크로우도 같다 — 든 것 %s · 세워 둔 **종 이름**이 다른 구역 화면에 안 샌다(「%s」)"
			% [ItemCatalog.name_of(m.inventory.selected_id()), crow_text],
		m.inventory.selected_id() == crow_id
		and not crow_text.contains(ItemCatalog.name_of(m.rarecrow.id_at(spot + Vector2i(1, 0)))))
	# 대조 — 안식으로 돌아오면 같은 칸에서 회수 안내가 그대로 선다(가드가 넓어진 게 아니다).
	m._rebuild_region(RegionCatalog.HOME)
	m.player.global_position = m._tile_center_px(spot - aim_off)
	m.inventory.select(spr_slot)
	m._process(0.0)
	var home_text: String = m.interact_prompt.text if m.interact_prompt.visible else ""
	_check("⑱d 대조: 안식에서는 회수 안내가 그대로다 — 든 것 %s · 「%s」"
			% [ItemCatalog.name_of(m.inventory.selected_id()), home_text],
		m.inventory.selected_id() == spr_id and m._target == spot and home_text.contains("회수"))
	m.sprinkler.remove(spot)
	m.rarecrow.remove(spot + Vector2i(1, 0))

# ── ⑲ #23 질투 감점에 화면 표면이 생긴다 ─────────────────────────────────────
func _check_jealousy_badge(m: Node) -> void:
	print("⑲ #23 질투 감점의 표면")
	var roster: Array = m.JEALOUSY_ROSTER
	var chosen := String(roster[0])
	var victim := String(roster[1])
	for rid in roster:
		var rr = m._resident(String(rid))
		if rr != null and rr.affinity != null:
			rr.affinity.points = 0
			rr.affinity.stage = 0
	m._jealousy.clear()
	var v = m._resident(victim)
	v.affinity.points = m.JEALOUSY_HIT * 3
	v.affinity.stage = v.affinity.points_hearts()
	var hearts_before: int = v.affinity.hearts()
	var badge_before := _badge_of(m, victim)
	m._apply_jealousy(chosen)
	var hearts_after: int = v.affinity.hearts()
	_check("⑲a 무대: %s가 %d점 깎였는데 **하트는 그대로다**(♡%d → ♡%d) — 종전엔 이 사건의 표면이 0이었다"
			% [v.display_name, m.JEALOUSY_HIT, hearts_before, hearts_after],
		m._jealousy.has(victim) and hearts_after == hearts_before)
	var badge_after := _badge_of(m, victim)
	_check("⑲b 관계 탭 행이 그 사건을 말한다 — 배지 「%s」 → 「%s」" % [badge_before, badge_after],
		badge_before == "" and badge_after != "" and badge_after != badge_before)
	# 7일 뒤 자동 복원 = 흔적 0 규약 — 배지도 함께 사라진다.
	m._advance_jealousy(m.clock.day + m.JEALOUSY_RESTORE_DAYS)
	_check("⑲c 복원되면 배지도 사라진다(「%s」) — 「복원된 아침은 그냥 평소다」 규약 보존"
			% _badge_of(m, victim),
		not m._jealousy.has(victim) and _badge_of(m, victim) == "")
	for rid in roster:
		var r2 = m._resident(String(rid))
		if r2 != null and r2.affinity != null:
			r2.affinity.points = 0
			r2.affinity.stage = 0
	m._jealousy.clear()

# 관계 탭 행에서 이 사람의 배지를 판다(그리기 입력 그대로 — main이 프레임에 넘기는 그 payload).
func _badge_of(m: Node, rid: String) -> String:
	var r = m._resident(rid)
	if r == null:
		return ""
	for row in m._heart_rows():
		if String(row.get("name", "")) == r.display_name:
			return String(row.get("badge", ""))
	return ""

# ── ⑳ #24 앵커 정표 창구가 연애 슬롯을 본다 ─────────────────────────────────
func _check_myeongbu_slot_gate(m: Node) -> void:
	print("⑳ #24 정표 발급 ↔ 연애 슬롯")
	var prev := String(m._romance_partner)
	m._romance_partner = ""
	var open_free: bool = m._myeongbu_quest_open()
	_check("⑳a 무대: 슬롯이 비어 있으면 정표 창구가 열린다(앵커 ♡%d)"
			% m._resident(m.OKJA_RID).affinity.hearts(), open_free)
	m._romance_partner = String(m.JEALOUSY_ROSTER[0])
	var open_taken: bool = m._myeongbu_quest_open()
	var propose_ok: bool = m._okja_track_open() and m._romance_partner == ""
	_check("⑳b 슬롯이 남에게 잡혀 있으면 **발급이 닫힌다**(%s) — 그 자리에서 청혼은 어차피 늘 거절이다(%s)"
			% [str(open_taken), str(propose_ok)],
		open_taken == false and propose_ok == false)
	_check("⑳c 형제 창구는 반대 방향 그대로다 — 혼례 부적은 **건넬 상대가 있을 때만** 열린다(%s)"
			% str(m._charm_quest_open()), m._charm_quest_open())
	m._romance_partner = prev
