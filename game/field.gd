extends Node
class_name FarmField
# T2.1 — 밭 칸 상호작용(괭이질 → 심기 → 물주기) + T2.3 — 작물 성장(일수 경과).
#
# 목적:
#   - T2.1: 한 칸에서 괭이질→심기→물주기가 "순서대로" 되고, 칸 상태가
#     (미경작/경작/심김/젖음)으로 바뀌는지 회색 도형만으로 검증한다(ADR-0001).
#   - T2.3: 심은 작물이 날이 지나며 단계가 오르고, 다 자라면 수확 가능해진다.
#     성장 규칙은 스타듀식: "물 준 칸만 다음 날 자라고, 매일 아침 흙이 마른다."
#
# 설계 메모:
#   - clock.gd(GameClock)와 같은 결: 이 노드는 "밭 칸 상태"라는 단일 책임만 가진다.
#     화면 표시(오버레이 타일·커서)·입력은 main.gd가 맡고, 여기서는 상태와
#     tile_changed 시그널만 제공한다. main은 시그널로 디커플링되어 붙는다.
#   - 작물 정의는 CropCatalog(crops.gd, 정적 참조 데이터)에서 읽는다. 이 노드는
#     "어떤 작물이 어디에 심겼고 며칠 자랐나"라는 세이브 상태만 들고, 성장일수
#     같은 카탈로그 값은 CropCatalog로 조회한다(데이터/상태 분리).
#   - 성장 트리거: GameClock.day_advanced에 main이 advance_day()를 연결한다.
#     시계는 코드 수정 없이 이 노드를 구동한다(시그널 디커플링).
#   - T2.5 세이브/로드 — 상태를 순수 Dictionary로만 들고 있어 그대로 직렬화된다
#     (Vector2i 키, bool/String/int 값). 그래서 일부러 inner class를 쓰지 않는다.
#   - 완료기준의 "순서대로"는 각 동사(hoe/plant/water/harvest)의 사전조건이 강제한다: 경작 전엔
#     심을 수 없고(plant는 is_tilled 요구), 심기 전엔 물을 줄 수 없으며(water는 is_planted 요구),
#     다 자라기 전엔 수확할 수 없다(harvest는 is_mature 요구). ★ ADR-0024(마우스 조작 피벗) —
#     예전엔 단일 키(E)가 next_action()으로 다음 동작을 *대신 골라줬으나*, 이제 핫바에서 든 도구가
#     동사를 정하고(괭이→hoe·물뿌리개→water·씨앗→plant·맨손 RMB→harvest) main이 직접 호출한다.
#     동사 라우팅이 입력층(main)으로 올라가, 이 노드는 "이 칸에 이 동사가 되나"의 사전조건만 든다.

signal tile_changed(tile: Vector2i)  # 칸 상태가 바뀐 프레임(main이 듣고 오버레이 갱신)

# 칸 상태 저장.
#   - 키가 없음 → 미경작(맨 흙). 메모리·세이브를 아끼려 경작된 칸만 담는다.
#   - 값 Dictionary 필드:
#       planted    : 작물이 심겼는가
#       watered    : 오늘 물을 줬는가(매일 아침 advance_day에서 false로 마름)
#       crop       : 심은 작물 id(CropCatalog의 영문 id, "" = 없음)
#       grown_days : 물 주고 잔 날의 누적(성장 진행도). growth_days 도달 시 수확 가능
#       fertilizer : 뿌린 비료 아이템 id("" = 무비료). S1-6 §8.4 — 단일 필드라 XOR·overwrite 자연 성립
#                    (품질군은 수확 품질 roll을, 성장촉진군은 성숙 임계 축소를 낸다). 구세이브는 .get 방어.
var _tiles: Dictionary = {}

# ── 조회 ────────────────────────────────────────────────────────────────────
func is_tilled(t: Vector2i) -> bool:
	return _tiles.has(t)

func is_planted(t: Vector2i) -> bool:
	return is_tilled(t) and _tiles[t]["planted"]

func is_watered(t: Vector2i) -> bool:
	return is_tilled(t) and _tiles[t]["watered"]

# 심긴 작물 id("" = 없음). T2.5 세이브·T3 경제(판매가 조회)가 쓴다.
func crop_of(t: Vector2i) -> String:
	return _tiles[t]["crop"] if is_planted(t) else ""

# 누적 성장 일수(물 준 날만 쌓인다). 안 심긴 칸은 0.
func grown_days_of(t: Vector2i) -> int:
	return _tiles[t]["grown_days"] if is_planted(t) else 0

# 다 자라 수확 가능한가 = 심김 + 누적 성장일수 ≥ 유효 성숙일(성장촉진 비료 반영, §8.6).
func is_mature(t: Vector2i) -> bool:
	if not is_planted(t):
		return false
	var need := effective_growth_days(t)
	return need >= 0 and _tiles[t]["grown_days"] >= need

# 뿌린 비료 아이템 id("" = 무비료/미경작). S1-6 — HUD·roll·성장촉진 조회의 단일 입구.
func fertilizer_of(t: Vector2i) -> String:
	return str(_tiles[t].get("fertilizer", "")) if is_tilled(t) else ""

# 유효 성숙 목표일(§8.6) = 성장촉진 계수를 먹인 임계(ceil·최소 1). 성장 루프(advance_day·_grow)는
# 안 건드리고 성숙 판정 임계만 낮춘다(깔끔한 삽입, foxfire accel과 자연 합성). 미지 작물은 base(-1) 그대로.
# ★[폴리시 R20 #4·#5·#6] 종전엔 이 값을 **호출될 때마다 현재 비료에서 다시 파생**했다(`ceili(base×f)`).
#   임계가 실시간으로 움직이니 한 뿌리에서 세 방향이 깨졌다:
#   ㉠ 다 자라기 직전 칸에 성장촉진 비료를 뿌리면 임계가 grown_days 아래로 내려앉아 **날이 안 바뀌었는데
#      그 자리에서 즉시 성숙**했다(영혼 호박 grown 9 / base 12 → 임계 ceili(12×0.75)=9). 40냥짜리
#      소모품을 '심을 때'가 아니라 '수확 직전'에 쓰는 것이 항상 우월해지고, 성장이 하루 경계 없이 뛰었다.
#   ㉡ 반대로 성장촉진 위에 품질 비료를 덮으면(quality군은 f=1.0) 임계가 base로 되돌아가 **수확 대기 중이던
#      작물이 미성숙으로 역행**했다 — 경고도 알림도 없이 물 두 번을 더 줘야 했다.
#      ★[폴리시 R22 #2] 이 항이 지키는 것은 **이미 성숙한 칸**뿐이다(아래 `_reseal_need`의 첫 가지).
#      미성숙 칸에서 품질군이 임계를 base로 되돌리는 것은 회귀가 아니라 R21이 명시 선언한 계약이다
#      («계수 1.0인 품질군은 무비료 임계로 정확히 되돌아간다 — 왕복 불변»). 그러지 않으면 하이퍼로
#      깎은 잔여에 품질군이 얹혀 «−33% 성숙 + 디럭스 품질»이 한 칸에 동시 성립해 2군 XOR가 무너진다
#      (§8.4). 두 머리말이 서로 반대되는 계약을 주장하던 자리를 여기서 가른다: **성숙 칸은 역행
#      금지 · 미성숙 칸은 계약대로 되돌림 · 그 대가는 화면이 말한다**(main의 비료 갈래 알림).
#   ㉢ REGROW 되감기는 base를 기준으로 재는데 성숙 판정만 이 유효일을 써서 두 기준이 어긋났고,
#      −25%짜리 비료가 재결실 주기를 −43%까지 깎았다(불사과 명목 7일 → 실제 4일).
#   그래서 임계는 **도포 시점에 한 번 정해 칸에 적는다**(`need_days` 스냅샷). 계산식은 카탈로그가 스스로
#   적어 둔 계약 그대로다 — "speed군의 **잔여** 성숙일 곱". 잔여에만 곱하므로 이미 지난 날은 절대 안
#   깎이고(㉠ 소멸), 계수 1.0인 품질군은 잔여를 그대로 되돌려 임계가 안 변하며(㉡ 소멸), 되감기가
#   같은 임계를 기준으로 돌아 쿨다운이 명목대로 선다(㉢ 소멸).
# ★ 구세이브 폴백: 키가 없는 칸은 종전 식으로 답한다(`load_save`가 심긴 칸에 곧 적어 넣는다).
func effective_growth_days(t: Vector2i) -> int:
	var base := CropCatalog.growth_days(crop_of(t))
	if base < 0:
		return base
	if _tiles[t].has("need_days"):
		return maxi(1, int(_tiles[t]["need_days"]))
	return _sealed_need(base, str(_tiles[t].get("fertilizer", "")))

# 심는 순간의 임계 = base 전체가 곧 잔여라 "잔여 곱"이 base 곱과 같아진다(구세이브 폴백도 이 식).
func _sealed_need(base: int, fert_id: String) -> int:
	return maxi(1, ceili(base * FertilizerCatalog.speed_factor(fert_id)))

# 심긴 칸에 비료를 갈아 뿌린 순간 임계를 **잔여 기준으로** 다시 잠근다. prev_need = 도포 직전 임계.
# 이미 성숙한 칸(잔여 ≤ 0)은 손대지 않는다 — 어떤 비료도 다 자란 작물을 되돌리지 못한다.
# ★[폴리시 R21 #0] 잔여를 재는 자[尺]는 **직전 임계가 아니라 base**다. R20이 세운 첫 판은
#   `left = prev_need - grown`이라 새 계수가 *직전 계수가 이미 깎아 놓은 잔여*에 다시 곱해졌고,
#   `fertilize`의 멱등 가드는 **같은 id만** 막으므로(다른 비료 overwrite는 성립 — 단일 필드 XOR)
#   임계가 «현재 비료 하나에서 파생»이 아니라 «지금까지 뿌린 모든 계수의 곱»이 됐다:
#   ㉠ 동군 중첩 — 심은 날 성장촉진(0.75)·하이퍼(0.67)를 번갈아 뿌리면 12→9→7→6→5→…로
#      계속 내려가, 12일 작물이 3일이 된다(하이퍼 단독 명목은 9다).
#   ㉡ 이군 동시 적용 — 하이퍼로 9까지 내린 뒤 디럭스(품질군·계수 1.0)를 덮으면 1.0이 *깎인
#      잔여*에 곱해져 임계가 9로 남는데 `roll_quality`는 현재 필드값만 보므로 품질표는 DELUXE다.
#      **−33% 성숙 + 디럭스 품질이 한 칸에 동시 성립** = fertilizer_catalog가 §8.4에 못 박은
#      2군 XOR("밭은 한 칸에 한 비료")의 붕괴다.
#   base에서 재면 셋이 한꺼번에 닫힌다. 계약은 그대로 지켜진다:
#   · 잔여 곱이라 이미 지난 날은 안 깎인다(R20 ㉠ 소멸) — need = grown + maxi(1,…) > grown이라
#     어떤 도포도 그 자리에서 성숙시키지 못한다.
#   · 이미 성숙한 칸은 위 `left <= 0` 가지가 그대로 지킨다(R20 ㉡의 "수확 대기 중 역행" 소멸).
#   · 계수 1.0(품질군)은 `grown + (base - grown)` = base라 **무비료 임계로 정확히 되돌아간다**
#     — 왕복 불변(무비료 ↔ 품질군 어느 쪽으로 몇 번을 갈아도 늘 base).
#   · 되감기(harvest REGROW)는 여전히 `effective_growth_days` 한 기준을 쓴다(R20 ㉢ 불변).
#   · 최솟값은 g=0에서라(need는 grown에 대해 단조 증가) **"심을 때부터 그 비료였을 때"보다
#     낮은 임계를 만들 길이 없다** — 갈아 뿌리기로 얻는 이득의 상한이 명목값이다.
#   ★[폴리시 R22 #2] **되감기 사이클에는 base라는 자를 댈 수 없다.** `harvest`의 REGROW 갈래는
#     grown을 «이 칸의 임계 − cd»로 되감으므로(R20 #6의 그 한 줄) 그 순간부터 grown은 *임계의 자*로
#     적힌 값이고 base와 통약되지 않는다. 그 위에 base 잔여를 곱하면 결과가 **무비료 명목보다도
#     나빠진다**: 불사과(base 12·cd 7)를 하이퍼로 심으면 임계 9 → 수확 후 grown 2인데, 여기에
#     디럭스(계수 1.0)를 덮으면 need = 2 + (12−2) = 12로 재결실까지 10일 — 아무 비료도 안 쓴 명목
#     쿨다운 7일보다 길다. 어떤 순수 경로보다 나쁜 결과는 계약이 아니라 결함이다.
#     그래서 되감기 사이클에서는 **임계를 건드리지 않는다**. 이것이 R20 ㉢("비료의 이득은 첫
#     결실에서 이미 받았다 — 쿨다운은 비료와 무관하게 명목값")의 대칭이다: 이득이 없으니 손해도
#     없다. 첫 사이클의 거동은 한 글자도 안 변한다(㉠·㉡·XOR 회복 전부 그대로).
#   ★ 첫 사이클에서 품질군이 임계를 base로 되돌리는 것은 **계약이지 결함이 아니다**(위 ㉡ 항 ·
#     `polish_r21` ①d가 그것을 잰다). 다만 그 되돌림이 침묵이면 안 되므로, 잔여가 실제로 늘어난
#     도포만 main이 화면에 말한다(집행 0이면 알리지 않는다 — 알림 규율).
func _reseal_need(t: Vector2i, prev_need: int, fert_id: String) -> void:
	var grown: int = int(_tiles[t]["grown_days"])
	if prev_need - grown <= 0:
		_tiles[t]["need_days"] = prev_need
		return
	if bool(_tiles[t].get("regrown", false)):
		_tiles[t]["need_days"] = prev_need
		return
	var base := CropCatalog.growth_days(str(_tiles[t].get("crop", "")))
	var left: int = base - grown
	if left <= 0:
		_tiles[t]["need_days"] = prev_need   # 방어(need ≤ base 불변식상 도달 불가)
		return
	_tiles[t]["need_days"] = grown + maxi(1, ceili(left * FertilizerCatalog.speed_factor(fert_id)))

# 수확 가능한 칸이 하나라도 있는가. T4.1 온보딩이 '집에서 키우기'에서 '수확하라'
# 단계로 넘어갈 시점(취침으로 작물이 다 자란 순간)을 main이 판정하는 데 쓴다.
func any_mature() -> bool:
	for t in _tiles.keys():
		if is_mature(t):
			return true
	return false

# 작물이 심긴 칸 목록(main의 _draw_crops가 칸별 작물 스프라이트를 그릴 때 순회한다).
# 상태 노드는 화면을 모르지만(설계 메모), "어디에 작물이 있나"는 순수 상태 질의라 노출한다.
func planted_tiles() -> Array:
	var out: Array = []
	for t in _tiles.keys():
		if _tiles[t]["planted"]:
			out.append(t)
	return out

# 경작된(괭이질된) 칸 전체 목록. M1.4 — 구역을 오갈 때 밭 오버레이(field_layer)를 비웠다가
# 안식 농원으로 돌아오면 다시 칠하는 데 쓴다(작물뿐 아니라 빈 고랑까지 복원). planted_tiles와
# 같은 결의 순수 상태 질의(상태 노드는 화면을 모르지만 "어디가 경작됐나"는 질의로 노출).
func tilled_tiles() -> Array:
	return _tiles.keys()

# 시각 성장 단계(오버레이용): -1=작물없음 / 0=씨앗 / 1=새싹 / 2=수확가능.
# 작물별 stages 수와 무관한 그레이박스 3단계(외형). 속도 차이는 growth_days가 낸다.
func growth_stage(t: Vector2i) -> int:
	if not is_planted(t):
		return -1
	if is_mature(t):
		return 2
	return 0 if _tiles[t]["grown_days"] == 0 else 1

# ── 단위 동작(가능하면 수행하고 true, 이미 그 상태면 false) ─────────────────
func hoe(t: Vector2i) -> bool:
	if is_tilled(t):
		return false
	_tiles[t] = {"planted": false, "watered": false, "crop": "", "grown_days": 0, "fertilizer": ""}
	tile_changed.emit(t)
	return true

# ★ [ADR-0051] 밤 까마귀([CrowRaid])가 쪼아먹은 칸 — 작물만 제거하고 흙(경작)·비료는 남긴다(스타듀 결).
#   is_tilled = 키 존재라 키를 지우지 않고 심김 상태만 초기화 → 다음 날 바로 다시 심을 수 있다.
#   소실은 영구(씨앗·자란 날수 증발, 되돌림 없음). 안 심긴 칸이면 false.
func remove_plant(t: Vector2i) -> bool:
	if not is_planted(t):
		return false
	var fert: String = str(_tiles[t].get("fertilizer", ""))   # ★[폴리시 R3] 구세이브 방어(39행 규약)
	_tiles[t] = {"planted": false, "watered": false, "crop": "", "grown_days": 0, "fertilizer": fert}
	tile_changed.emit(t)
	return true

# ★[폴리시 R7] 경작 자체를 **되돌린다**(키를 지워 맨 흙으로). `remove_plant`가 흙을 남기는 것과
#   정반대 방향이라 이름도 반대다 — 쓰는 곳은 "이 칸이 더는 밭이 아니게 된" 이행 경로 하나다
#   (삽사리 자리 제외가 소급 적용되는 구세이브 정리 — main `_reclaim_pet_tile_farm`). 심긴 칸도
#   그대로 지우므로 호출부가 먼저 작물을 정산한다. 미경작 칸이면 false(멱등).
func untill(t: Vector2i) -> bool:
	if not is_tilled(t):
		return false
	_tiles.erase(t)
	tile_changed.emit(t)
	return true

# ★[폴리시 R23 #1] 이 칸에 이 비료를 뿌리면 **어느 축에서도 얻을 것이 없는가**(= 정직한 거절의 술어).
#   거절 자체는 `fertilize`가 집행하고, 이유를 화면에 말하는 것은 호출부(main)의 몫이라 판정을
#   공개 창구로 둔다 — 두 자리가 같은 한 술어를 봐야 «거절한 것만 말하고, 말한 것은 반드시
#   거절된다»가 성립한다(같은 조건을 main에 다시 적으면 언젠가 갈린다).
#   ★ 되감기 봉인 자체는 R22 #2의 계약이다(`_reseal_need` 머리말) — 여기서 되돌리지 않는다.
# ★[폴리시 R24 #0] **술어는 들어오는 비료의 군 하나로 정해진다.** R23의 첫 판은 «들어오는 것도
#   기존 것도 STATE_NONE»이라는 두 항의 AND였고, 그 근거 문장(아래 `fertilize`의 «품질군은 여전히
#   통과한다»)은 *들어오는 비료가 품질군일 때*만 참이다. 들어오는 것이 성장촉진군인데 칸에 이미
#   품질군이 깔려 있으면 둘째 항이 거짓이라 도포가 통과했고, 결과는 R23이 막으려던 것보다 나빴다:
#     · 속도 축 — `_reseal_need`가 `regrown` 가지에서 즉시 반환한다(봉인이라 이득 0).
#     · 품질 축 — 단일 fertilizer 필드를 덮으므로 state가 DELUXE → NONE으로 **강등**된다
#       (`roll_quality`가 현재 필드값을 읽는다). 즉 120냥짜리 등급을 100냥짜리로 지운다.
#     · 알림 — `need_after == need_before`라 R22가 붙인 «늘어난 잔여» 표면도 침묵이다.
#   되감기 칸에서 성장촉진군이 건드릴 수 있는 축은 품질 하나뿐이고 그쪽으로는 **강등밖에** 못
#   하므로, 기존 비료가 무엇이든 얻을 것이 없다 = 거절한다. 품질군은 그대로 통과한다(그 축은
#   `roll_quality`가 현재 필드값을 읽어 되감기 사이클에서도 실효한다).
func fertilize_sealed_no_op(t: Vector2i, fert_id: String) -> bool:
	if not is_planted(t) or not bool(_tiles[t].get("regrown", false)):
		return false
	return FertilizerCatalog.state_of(fert_id) == FertilizerCatalog.STATE_NONE

# ── S1-6 비료(§8.4) ─────────────────────────────────────────────────────────
# 경작된 칸(심김/빈칸 무관)에 유효 비료를 뿌린다. 단일 fertilizer 필드라 다른 비료 투입 시 overwrite —
# XOR가 자연 성립(한 칸에 한 비료). 성공 시 tile_changed·true(비료 소모는 호출 측 main). 미경작·무효 비료면 false.
func fertilize(t: Vector2i, fert_id: String) -> bool:
	if not is_tilled(t) or not FertilizerCatalog.has(fert_id):
		return false
	# ★[폴리시 R9] **같은 비료 재도포는 무동작**(멱등). 이 파일의 다른 동사는 예외 없이 이 가드를
	#   드는데(`hoe`·`water`·`plant`·`sprinkle`, 그리고 `Sprinkler.place`) 비료만 빠져 있었고,
	#   하필 유일하게 값비싼 소모품이다 — 호출부(main)가 이 true를 곧바로 차감에 쓰므로 이미
	#   디럭스 비료가 깔린 칸을 한 번 더 누르면 **칸 상태가 바이트 단위로 같은 채** 120냥짜리
	#   한 개가 사라졌다. 다른 비료로의 overwrite는 그대로 성립한다(단일 필드 XOR 문법 불변).
	if str(_tiles[t].get("fertilizer", "")) == fert_id:
		return false
	# ★[폴리시 R23 #1] **아무것도 못 바꾸는 도포는 거절한다** — 위 멱등 가드의 확장이고 근거도 같다
	#   (값비싼 소모품이 칸을 한 톨도 안 바꾼 채 사라지지 않게). R22 #2가 되감기 사이클에서 임계를
	#   봉인한 뒤, 그 칸에 성장촉진군을 뿌리면 두 축이 **동시에** 아무 일도 안 한다:
	#     ㉠ 임계 — `_reseal_need`가 `regrown` 가지에서 즉시 반환한다(그 봉인은 계약이라 불가침).
	#     ㉡ 품질 — 성장촉진군은 `state`가 STATE_NONE이라 `roll_quality`가 무비료와 같은 표를 쓴다.
	#   그래서 100냥짜리 하이퍼 비료가 소모만 되고 재결실은 하루도 안 당겨졌는데, R22가 붙인 표면은
	#   *늘어난* 잔여만 말하므로(need_after > need_before) 알림조차 0인 **침묵 실패**였다.
	#   품질군은 여전히 통과한다 — 그쪽은 `roll_quality`가 현재 필드값을 읽어 되감기 사이클에서도
	#   실효하므로 거절할 이유가 없다.
	#   ★[폴리시 R24 #0] 거절 조건은 **들어오는 비료의 군 하나**다(종전의 «양쪽 다 무효»는 기존
	#     비료가 품질군인 칸을 열어 두었고, 그 칸에서는 도포가 무동작이 아니라 *등급 강등*이었다 —
	#     사유는 `fertilize_sealed_no_op` 머리말).
	if fertilize_sealed_no_op(t, fert_id):
		return false
	# ★[폴리시 R20 #4·#5] 도포 **직전** 임계를 먼저 읽는다 — 비료를 먼저 갈아끼우면 구세이브 폴백이
	#   새 계수로 답해 기준선이 오염된다. 심긴 칸이면 그 임계의 잔여에 새 계수를 곱해 다시 잠근다.
	var prev_need: int = effective_growth_days(t) if is_planted(t) else -1
	_tiles[t]["fertilizer"] = fert_id
	if prev_need >= 0:
		_reseal_need(t, prev_need, fert_id)
	tile_changed.emit(t)
	return true

# ── S1-6 품질 roll(§8.5) — 수확 시 main이 칸을 비우기 전에 호출 ─────────────────
# 칸의 비료 → 품질 상태(quality군 → BASIC/QUALITY/DELUXE · 성장촉진군/무비료 → NONE) → 등급 0..3 난수.
# 성장촉진 비료 칸은 품질 NONE(품질과 별 축, §3.1). 미경작 칸은 Q_NORMAL(안전).
# ★[폴리시 R5] `seed_tag`는 **이 수확 사건의 이름**이다(호출부가 day+구역+칸으로 짓는다). 전역
#   RNG를 쓰던 종전엔 F9 로드마다 같은 칸의 등급이 다시 굴러, 이리듐이 나올 때까지 반복하면
#   확률이 무의미해졌다(fertilizer_catalog.roll_quality_seeded 머리말). 인자에 기본값을 안 둔
#   것이 의도다 — 시드 없는 호출이 조용히 옛 거동으로 돌아가는 문을 남기지 않는다.
func roll_quality(t: Vector2i, seed_tag: String) -> int:
	if not is_tilled(t):
		return ItemCatalog.Q_NORMAL
	var state := FertilizerCatalog.state_of(str(_tiles[t].get("fertilizer", "")))
	return FertilizerCatalog.roll_quality_seeded(state, seed_tag)

func plant(t: Vector2i, crop_id: String) -> bool:
	# 경작된 빈 칸에, 카탈로그에 있는 작물만 심는다(괭이질 → 심기 순서 강제).
	if not is_tilled(t) or is_planted(t):
		return false
	if not CropCatalog.has_crop(crop_id):
		return false
	_tiles[t]["planted"] = true
	_tiles[t]["crop"] = crop_id
	_tiles[t]["grown_days"] = 0
	# ★[폴리시 R20 #4] 성숙 임계를 이 자리에서 한 번 잠근다(스냅샷) — 이후 비료를 갈아도
	#   `_reseal_need`가 잔여 기준으로만 다시 잠그므로 임계가 뒤로 뛰거나 되돌아가지 않는다.
	_tiles[t]["need_days"] = _sealed_need(CropCatalog.growth_days(crop_id),
		str(_tiles[t].get("fertilizer", "")))
	# ★[폴리시 R22 #2] 되감기 표식은 심는 순간 늘 꺼진다 — 새로 심은 칸은 언제나 첫 사이클이다
	#   (`hoe`·`remove_plant`는 dict를 새로 만들어 이미 꺼져 있지만, 여기서도 명시해 표식이
	#    이전 작물에서 새 작물로 새는 갈래를 원천적으로 없앤다).
	_tiles[t]["regrown"] = false
	tile_changed.emit(t)
	return true

func water(t: Vector2i) -> bool:
	# 다 자라지 않은, 심은 마른 칸에만 물을 준다(심기 → 물주기 순서 강제).
	# 물 준 칸만 advance_day에서 자란다.
	if not is_planted(t) or is_watered(t) or is_mature(t):
		return false
	_tiles[t]["watered"] = true
	tile_changed.emit(t)
	return true

# ★[S8-T7 / ADR-0066 결정 9] 배우자(미호) 아침 물주기 — **미급수 심긴 미성숙 칸**을 (y,x) 정렬
#   순으로 limit개까지 적신다. 대상 선정이 여우불 범위(_foxfire_targets)와 같은 결정적 정렬이라
#   헤드리스 재현이 보장된다. ★여우불(성장 가속·main의 advance_day 인자)과는 **별축**이다 —
#   여우불은 "못 준 칸도 자라게" 하고, 이 물주기는 "칸을 실제로 적셔"(watered=true) 오늘의 손
#   노동을 대행한다(ADR-0066 결정 9 "여우불과 물주기는 별축이라 중복 아님"). 적신 칸 수 반환.
func water_dry(limit: int) -> int:
	var done := 0
	for t in _foxfire_targets(limit):
		if water(t):
			done += 1
	return done

# ★ [S1R-T9] 스프링클러 자동 급수 — 경작된 칸(심겼든 아니든)을 적신다. 손 물주기(water)와 달리 빈
#   경작 칸도 젖고(스타듀 문법 — 흙이 젖어 보임), 심긴 미성숙 칸은 그날 advance_day 성장에 반영된다.
#   혼력·물뿌리개 무관(호출 측 게이트 없음 — 스프링클러 편익은 그 두 축과 독립, ADR-0059 결정4).
#   미경작 칸이거나 이미 젖었으면 무동작(멱등). main이 아침(성장 판정 전)에 급수 대상 칸마다 부른다.
func sprinkle(t: Vector2i) -> bool:
	if not is_tilled(t) or is_watered(t):
		return false
	_tiles[t]["watered"] = true
	tile_changed.emit(t)
	return true

# 수확: 다 자란 칸을 거둔다. 거둔 작물 id를 반환("" = 실패). 다수확 count(황천포도 2~3)는
# 호출 측(main._try_harvest)이 CropCatalog.yield_range로 굴린다(범위 분리, greybox-spec §6.5).
# ★ S1-5a — 성장 모드 2분기(§6.4):
#   · SINGLE: 빈 경작 칸으로 되돌린다(기존 동작).
#   · REGROW: 넝쿨을 보존하고 grown_days를 쿨다운만큼 되감아 재결실을 준비한다(황천포도·불사과).
#     되자람은 물-구동 advance_day를 그대로 재사용한다(특수 성장 분기 0).
func harvest(t: Vector2i) -> String:
	if not is_mature(t):
		return ""
	var crop_id: String = _tiles[t]["crop"]
	if CropCatalog.growth_mode(crop_id) == "REGROW":
		# 넝쿨 보존. grown_days를 (임계−cd)로 되감아, cd일 더 물주면 다시 성숙한다.
		# (황천포도 임계7·cd3 → 4 → +3일 = 7 재성숙.) planted/crop/watered는 그대로 둔다.
		# ★[폴리시 R20 #6] 기준을 base에서 **이 칸의 성숙 임계**로 바꾼다. 되감기는 base로 재고
		#   성숙 판정만 유효 임계로 재던 탓에 위 한 줄의 약속("cd일 더 물주면")이 비료 깔린 칸에서
		#   거짓이었다 — 불사과(base 12·cd 7)에 성장촉진을 깔면 grown 5로 되감기는데 임계는 9라
		#   4일 만에 다시 열려, −25%짜리 비료가 재결실 주기만 −43% 깎았다. 한 기준으로 재면
		#   쿨다운이 비료와 무관하게 명목값 그대로 선다(비료의 이득은 첫 결실에서 이미 받았다).
		var need := effective_growth_days(t)
		var cd := CropCatalog.regrow_cooldown(crop_id)
		_tiles[t]["grown_days"] = maxi(0, need - cd)
		# ★[폴리시 R22 #2] 이 칸은 이제 **되감기 사이클**이다 — grown이 base가 아니라 임계의 자로
		#   적혔다는 표식이고, `_reseal_need`가 그 자에 base 잔여를 곱해 쿨다운을 명목보다 길게
		#   늘리는 것을 막는다(그 머리말). 표식은 `plant`·`hoe`·`remove_plant`가 끈다.
		_tiles[t]["regrown"] = true
	else:
		_tiles[t]["planted"] = false
		_tiles[t]["crop"] = ""
		_tiles[t]["grown_days"] = 0
	tile_changed.emit(t)
	return crop_id

# ── S1-5a 트렐리스 통과 불가(greybox-spec §6.2) ─────────────────────────────
# 트렐리스 넝쿨이 칸을 물리적으로 점유하는가 = 통과 불가 단일 술어(진실원).
# 심긴 트렐리스 작물이면 true. REGROW 쿨다운 중에도 넝쿨은 그대로라(planted 유지) 계속 solid다
# (열매만 없을 뿐 격자는 남는다). main이 이 술어로 _trellis_body 충돌을 세운다(로직/물리 분리).
func is_crop_solid(t: Vector2i) -> bool:
	return is_planted(t) and CropCatalog.is_trellis(_tiles[t]["crop"])

# 통과 불가(트렐리스) 넝쿨이 심긴 칸 전체 목록. main의 _rebuild_trellis_collision이 순회한다
# (tilled_tiles/planted_tiles와 같은 결의 순수 상태 질의 — 상태 노드는 화면을 모르지만 질의로 노출).
func solid_crop_tiles() -> Array:
	var out: Array = []
	for t in _tiles.keys():
		if is_crop_solid(t):
			out.append(t)
	return out

# ── 하루 경과(취침 트리거) ───────────────────────────────────────────────────
# GameClock.day_advanced에 연결된다. 스타듀 규칙 + T3.4 여우불 도움:
#   1) 물 준(watered) 칸은 성장일수가 +1 된다(아직 다 자라기 전까지만).
#      T3.4: 여기에 여우불 가속(accel)을 더해 더 빨리 자란다(+1+accel).
#   2) T3.4 여우불 범위(reach): 물을 못 준 심긴 칸도 reach개까지 여우불이 대신
#      돌봐 +1 자란다('넓게'). 어느 칸을 돌볼지는 (y,x) 정렬 순으로 정해 결정적이다
#      (헤드리스 검증 재현성). 아침 마름 전 상태로 고르므로, 오늘 물 준 칸은 후보가
#      아니다(가속으로 이미 자람 — 이중 적용 방지).
#   3) 모든 경작 칸의 흙은 아침에 마른다(watered → false).
# accel/reach 기본 0 = 여우불 잠듦(순수 스타듀 성장 — 기존 동작·T2.3 그대로). 세기
# 매핑은 Foxfire(foxfire.gd)가 호감도 하트에서 파생하고, main이 값으로 넘긴다(디커플링).
# 상태가 바뀐 칸마다 tile_changed를 발화해 main이 오버레이를 갱신한다.
#
# ★[S7-T3 / ADR-0065 결정 4] `grow` = 오늘 성장 판정을 굴리는가(기본 true = 종전 동작 그대로).
#   잿눈(SNOW) 날 노지 작물이 **하루 멈추되 죽지는 않는** 규칙의 자리다. 왜 호출 자체를 스킵하지
#   않고 인자를 열었나: advance_day는 성장과 **아침 마름**을 함께 하는데, 호출을 건너뛰면 젖은
#   흙이 다음 날까지 남아 "눈 온 날 물을 준 셈"이 된다(결정 4의 "성장 정지 + 물 마름"과 정반대).
#   그래서 마름은 그대로 돌리고 성장 두 갈래(물 준 칸 +1·여우불 범위)만 끈다 — field가 날씨를
#   모른 채(Weather 참조 0) 값 하나만 받는 가법 확장이라 기존 호출부·테스트 시그니처는 불변이다.
# ★[폴리시 R23 #9] 반환 = **여우불이 실제로 돌본 칸 수**(가법 확장 — 안 읽어도 종전 그대로).
#   `water_dry`가 적신 칸 수를 돌려주는 것과 같은 이유다: reach는 비율이 아니라 «하루에 돌볼 최대
#   칸 수»라 밭이 둘이면 **한 몫을 나눠 써야** 하는데, 호출부가 얼마를 썼는지 알 길이 없었다.
func advance_day(accel: int = 0, reach: int = 0, grow: bool = true) -> int:
	# 여우불 범위 후보를 마름 전(밤 상태)에 먼저 고른다 — 물 안 준 심긴 미성숙 칸.
	var foxfire_targets := _foxfire_targets(reach) if grow else []
	# 1) 물 준 칸: 기본 +1 에 여우불 가속을 더해 자란다(성장일수는 작물 한계까지만).
	for t in _tiles.keys():
		var tile: Dictionary = _tiles[t]
		var changed := false
		if grow and tile["planted"] and tile["watered"] and not is_mature(t):
			_grow(t, 1 + maxi(accel, 0))
			changed = true
		# 흙은 아침에 마른다.
		if tile["watered"]:
			tile["watered"] = false
			changed = true
		if changed:
			tile_changed.emit(t)
	# 2) 여우불 범위: 물 못 준 칸을 reach개까지 +1 돌본다(양육의 불, ADR-0004).
	for t in foxfire_targets:
		_grow(t, 1)
		tile_changed.emit(t)
	return foxfire_targets.size()

# 한 칸의 성장일수를 n만큼 올리되 작물 성장일수(완성)까지만 잰다(가속 과성장 방지).
func _grow(t: Vector2i, n: int) -> void:
	var need := CropCatalog.growth_days(_tiles[t]["crop"])
	_tiles[t]["grown_days"] = mini(_tiles[t]["grown_days"] + n, need)

# T3.4 여우불 범위가 돌볼 칸 목록(물 못 준 심긴 미성숙 칸 중 (y,x) 정렬 순 limit개).
# 정렬로 결정적이라 헤드리스 검증이 재현 가능하다. limit ≤ 0이면 빈 배열.
func _foxfire_targets(limit: int) -> Array:
	if limit <= 0:
		return []
	var cands: Array = []
	for t in _tiles.keys():
		if _tiles[t]["planted"] and not _tiles[t]["watered"] and not is_mature(t):
			cands.append(t)
	cands.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.y < b.y if a.y != b.y else a.x < b.x)
	return cands.slice(0, limit)

# ── T2.5 세이브/로드 ──────────────────────────────────────────────────────
# 밭 상태(_tiles)는 Vector2i 키 + bool/String/int 값의 순수 Dictionary라,
# SaveManager의 var_to_str가 키 타입까지 그대로 라운드트립한다(이 노드가 inner
# class를 안 쓴 이유). 깊은 복사로 넘겨, 호출 측이 들고 있어도 상태가 새지 않게 한다.
func to_save() -> Dictionary:
	return {"tiles": _tiles.duplicate(true)}

# 복원: _tiles를 통째로 갈아끼우고, 칸마다 tile_changed를 발화해 main이 오버레이를
# 다시 그리게 한다(시각 동기화도 디커플링 유지). 로드 전 옛 오버레이 타일 제거는
# 호출 측(main) 책임이다 — 이 노드는 상태만 알고 화면 레이어를 모르기 때문.
func load_save(data: Dictionary) -> void:
	var tiles: Variant = data.get("tiles", {})
	_tiles = tiles.duplicate(true) if typeof(tiles) == TYPE_DICTIONARY else {}
	for t in _tiles.keys():
		# ★[폴리시 R3] 스키마 백필 — S1-6 이전(비료 필드 도입 전)에 괭이질된 칸은 4필드만 들고
		#   온다. `hoe()`는 *새* 칸에만 기본 dict를 만들므로 옛 칸엔 키가 영영 안 생기고, 그 칸을
		#   심었다가 제거하는 경로(절기 사멸·까마귀·잡초 확산)가 하드 인덱싱에서 멎었다.
		#   livestock.load_save의 age/location 백필과 같은 자리·같은 규율(구세이브 = 무비료).
		var c: Dictionary = _tiles[t]
		if not c.has("fertilizer"):
			c["fertilizer"] = ""
		# ★[폴리시 R9] **모르는 작물 id를 실은 칸은 빈 경작 칸으로 되돌린다**(손상 세이브 방어 —
		#   `GardenPot.load_save`가 이미 드는 그 가드의 밭판). 안 걸러 내면 그 칸이 영구 불능으로
		#   굳는다: `effective_growth_days`가 base −1을 그대로 돌려줘 `is_mature`의 `need >= 0`
		#   계약에 걸려 **절대 성숙하지 않고**, `_grow`가 need=−1로 grown_days를 −1로 밀며,
		#   절기 사멸 패스는 미지 id의 `seasons_of`가 빈 배열이라 `in_season`이 늘 참이 되어 지우지
		#   못하고, `plant`는 `is_planted`에서 막힌다. 흙·비료는 남기므로 그 자리는 곧장 다시
		#   심을 수 있다(까마귀·절기 사멸이 쓰는 `remove_plant`와 같은 되돌림 폭).
		if bool(c.get("planted", false)) and not CropCatalog.has_crop(str(c.get("crop", ""))):
			c["planted"] = false
			c["crop"] = ""
			c["grown_days"] = 0
		# ★[폴리시 R20 #4] 성숙 임계 스냅샷 백필 — R20 이전에 심긴 칸은 `need_days`를 안 들고 온다.
		#   종전 식(현재 비료의 base 곱)으로 한 번 적어 넣어 그 세이브의 임계를 **그 자리에 굳힌다**:
		#   값이 종전과 같으니 진행 중인 작물의 성숙일이 안 흔들리고(구세이브 손해 0), 그 다음부터는
		#   비료를 갈아도 임계가 뛰거나 되돌아가지 않는다. 위 손상 가드 **뒤**에 두는 것이 순서다 —
		#   미지 작물 칸은 이미 빈 경작 칸으로 내려앉아 base<0 계산에 안 들어간다.
		if bool(c.get("planted", false)) and not c.has("need_days"):
			var b := CropCatalog.growth_days(str(c.get("crop", "")))
			if b >= 0:
				c["need_days"] = _sealed_need(b, str(c.get("fertilizer", "")))
		tile_changed.emit(t)
