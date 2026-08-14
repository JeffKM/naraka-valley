extends Node
class_name GardenPot
# ★[S10-T5 / ADR-0069 결정 8] 화분(최소형) — 실내 1×1 컨테이너 재배 원장.
#
# 목적: 카탈로그 §2-6이 "화분 #2 defer"로 미뤄 두고 해제 조건을 "온실 슬라이스 시점"으로 적어 둔
#       그 자리의 이행이다. 온실(늘봄방)이 *면적*을 여는 보상이라면, 화분은 **면적 없이 한 칸을
#       들여놓는** 소품이다 — 집 안에 작물 한 포기가 서는 것이 이 시스템의 전부다.
#
# 온실과의 차별 자구 넷(ADR-0069 결정 8) — 넷 다 **구조로** 성립한다(런타임 가드가 아니다):
#   ㉠ **절기 무시** — 절기 사멸 패스는 `farm`(노지 밭)만 순회한다. 이 원장은 그 순회에 없다.
#   ㉡ **매일 손 물주기** — `advance_day`가 아침마다 전 화분을 말린다(watered=false). 젖은 화분만
#      그날 자라므로, 하루라도 안 주면 그날 성장이 없다.
#   ㉢ **스프링클러 불가** — 급수 사슬(main의 아침 정산)이 `FarmField.sprinkle`만 부른다. 이 원장엔
#      sprinkle에 해당하는 API가 **아예 없다** — 스프링클러가 화분을 적실 경로가 코드에 존재하지 않는다.
#   ㉢' 혼우(비)·여우불도 같은 이유로 화분에 닿지 않는다. 화분은 실내 소품이고, 손이 유일한 물이다.
#   ㉣ **[혼의 나무] 불가** — `plant`가 CropCatalog만 검증한다(FruitTreeCatalog 참조 0). 묘목은
#      애초에 이 API를 통과할 수 없고, main의 묘목 분기도 실내를 배제한다.
#
# 왜 FarmField가 아니라 별개 원장인가:
#   - FarmField를 재사용하면 위 넷이 전부 *예외 분기*가 된다(젖음을 안 옮기는 sprinkle 가드,
#     사멸 순회에서 화분 칸을 빼는 필터…). 예외로 지키는 규칙은 다음 슬라이스에서 새는 규칙이다.
#     상태 필드가 겹쳐 보여도(작물·젖음·자란 날) **적용되는 규칙 집합이 다르면 다른 시스템**이다.
#   - 비료·품질 롤·트렐리스·다수확도 없다(최소형 — ADR 자구 "1×1 컨테이너 최소형"). 수확 품질은
#     노지와 같은 문법을 쓰되 *비료가 없으므로* 무비료 등급이 자연스럽게 나온다(main이 roll한다).
#   - Sprinkler·Reclaim과 같은 결의 얇은 노드다: 지형·화면·인벤·혼력을 모른다. 배치 가능 판정도
#     main이 하고(실내 판정은 main만 안다), 여기 있는 건 "어느 칸에 화분이 있고 무엇이 자라나"뿐이다.

signal changed()   # 배치·철거·심기·물주기·수확·복원 프레임(main이 듣고 드로우 갱신)

# 화분 원장. 키 = 놓인 타일(Vector2i), 값 = Dictionary:
#   crop       : 심은 작물 id("" = 빈 화분)
#   watered    : 오늘 물을 줬는가(매일 아침 advance_day가 말린다)
#   grown_days : 물 주고 잔 날의 누적(FarmField와 같은 눈금)
var _pots: Dictionary = {}

# ── 질의 ────────────────────────────────────────────────────────────────────
func has_at(t: Vector2i) -> bool:
	return _pots.has(t)

func tiles() -> Array:
	return _pots.keys()

func count() -> int:
	return _pots.size()

# 심긴 작물 id("" = 빈 화분/화분 없음).
func crop_of(t: Vector2i) -> String:
	return String(_pots[t]["crop"]) if has_at(t) else ""

func is_planted(t: Vector2i) -> bool:
	return crop_of(t) != ""

func is_watered(t: Vector2i) -> bool:
	return has_at(t) and bool(_pots[t]["watered"])

func grown_days_of(t: Vector2i) -> int:
	return int(_pots[t]["grown_days"]) if is_planted(t) else 0

# 다 자랐나 = 심김 + 누적 성장일수 ≥ 작물 성숙일. 비료가 없으므로 FarmField의 성장촉진 축(유효
# 성숙일 축소)이 여기엔 없다 — 화분은 늘 base 속도다(최소형).
func is_mature(t: Vector2i) -> bool:
	if not is_planted(t):
		return false
	var need := CropCatalog.growth_days(crop_of(t))
	return need >= 0 and grown_days_of(t) >= need

# 시각 성장 단계(-1=빈 화분 / 0=씨앗 / 1=새싹 / 2=수확가능) — FarmField.growth_stage와 같은 눈금.
func growth_stage(t: Vector2i) -> int:
	if not is_planted(t):
		return -1
	if is_mature(t):
		return 2
	return 0 if grown_days_of(t) == 0 else 1

# ── 배치/철거 ────────────────────────────────────────────────────────────────
# 화분을 놓는다(빈 화분으로 선다). 이미 있으면 false(멱등). 배치 가능 판정(실내·바닥·겹침)은
# main이 하고 여기는 원장만 든다(Sprinkler.place와 같은 경계).
func place(t: Vector2i) -> bool:
	if _pots.has(t):
		return false
	_pots[t] = {"crop": "", "watered": false, "grown_days": 0}
	changed.emit()
	return true

# 화분을 회수한다. **자라던 작물은 함께 사라진다**(되돌림 없음 — 회수는 곧 포기다). 없으면 false.
# ★ 회수한 화분 아이템의 인벤 반환은 main 소관이다(원장은 인벤을 모른다).
func remove(t: Vector2i) -> bool:
	if not _pots.has(t):
		return false
	_pots.erase(t)
	changed.emit()
	return true

# ── 단위 동작(FarmField의 동사 이름을 그대로 빌린다 — 손에 익은 문법이 같아야 한다) ──
# 빈 화분에 심는다. 카탈로그에 있는 **작물**만(묘목·과수는 이 API를 통과할 수 없다 — 차별 자구 ㉣).
# ★ 절기를 안 본다(차별 자구 ㉠) — in_season 판정이 이 파일 어디에도 없다.
func plant(t: Vector2i, crop_id: String) -> bool:
	if not has_at(t) or is_planted(t):
		return false
	if not CropCatalog.has_crop(crop_id):
		return false
	_pots[t]["crop"] = crop_id
	_pots[t]["grown_days"] = 0
	changed.emit()
	return true

# 손 물주기. 심긴·마른·미성숙 화분만(FarmField.water와 같은 사전조건).
# ★ 이 함수가 화분에 물이 드는 **유일한 경로**다(차별 자구 ㉢ — 스프링클러·비·여우불 경로 없음).
func water(t: Vector2i) -> bool:
	if not is_planted(t) or is_watered(t) or is_mature(t):
		return false
	_pots[t]["watered"] = true
	changed.emit()
	return true

# 수확. 다 자란 화분을 거두고 작물 id를 돌려준다("" = 실패). 거둔 화분은 **빈 화분으로 되돌아간다**
# (되자람 없음 — 최소형이라 REGROW 분기를 안 든다. 넝쿨 작물을 심어도 한 번 거두면 끝난다).
func harvest(t: Vector2i) -> String:
	if not is_mature(t):
		return ""
	var crop_id := crop_of(t)
	_pots[t] = {"crop": "", "watered": false, "grown_days": 0}
	changed.emit()
	return crop_id

# ── 하루 경과(취침 트리거) ───────────────────────────────────────────────────
# 젖은 화분만 +1 자라고, **모든 화분이 아침에 마른다**(차별 자구 ㉡ — 매일 손이 가야 한다).
# 여우불 가속·범위 인자를 안 받는다: 화분은 관계 곱셈기가 얹히는 밭이 아니라 실내 소품이다
# (ADR-0008 위반 아님 — 곱셈기를 *빼는* 방향이고, 밭 쪽 곱셈기는 그대로다).
func advance_day() -> void:
	for t in _pots.keys():
		var pot: Dictionary = _pots[t]
		if String(pot["crop"]) != "" and bool(pot["watered"]) and not is_mature(t):
			var need := CropCatalog.growth_days(String(pot["crop"]))
			pot["grown_days"] = mini(int(pot["grown_days"]) + 1, need)
		pot["watered"] = false
	changed.emit()

# ── 세이브/로드 — 슬라이스 키 "garden_pot" ────────────────────────────────────
# 화분 하나 = [x, y, crop, watered, grown_days] 5원소 배열(Sprinkler의 [x,y,tier] 결).
# 키 없는 구세이브 = 화분 0(하위호환 — 마이그레이션 코드 0).
func to_save() -> Dictionary:
	var pots: Array = []
	for t in _pots:
		var pot: Dictionary = _pots[t]
		pots.append([t.x, t.y, String(pot["crop"]), bool(pot["watered"]), int(pot["grown_days"])])
	return {"pots": pots}

func load_save(data: Dictionary) -> void:
	_pots = {}
	var pots: Variant = data.get("pots", [])
	if typeof(pots) == TYPE_ARRAY:
		for e in pots:
			if typeof(e) != TYPE_ARRAY or e.size() < 5:
				continue
			var crop := String(e[2])
			if crop != "" and not CropCatalog.has_crop(crop):
				crop = ""       # 모르는 작물 id는 조용히 빈 화분으로(손상 세이브 방어)
			_pots[Vector2i(int(e[0]), int(e[1]))] = {
				"crop": crop, "watered": bool(e[3]), "grown_days": maxi(int(e[4]), 0),
			}
	changed.emit()
