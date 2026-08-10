extends RefCounted
class_name GuestPool
# ★[S6-T4 / ADR-0064 결정 8] 손님 풀 · 단골화 방문 가중치 원장.
#
# 목적: 낮 카페 손님을 "회색 도형 무한 익명"에서 **아는 얼굴이 섞이는 자리**로 올린다. 두 축이다:
#   ㉠ **명명 손님 풀** = 현행 주민 로스터 재사용(GUEST_IDS — 신규 캐릭터 발명 0, 결정 8).
#   ㉡ **단골화** = 서빙 이력이 재방문 확률을 올리는 얇은 원장(이 파일의 상태 전부).
#
# 설계 메모:
#   - **호감도와 완전 분리**(★ADR-0017 보호 · 결정 8 명문): 이 파일은 Affinity를 *구조적으로 모른다* —
#     import도, 참조도, 하트 입력도 없다. 서빙은 방문 가중치만 올리고 ♡는 한 톨도 안 올린다.
#     "카페에 자주 오는 것"과 "친해지는 것"은 다른 행동이다(대화·선물이 ♡의 유일한 채널).
#     그 역도 참이다 — ♡가 올라도 여기 가중치는 안 오른다(관계가 손님 유입을 게이팅하지 않는다).
#   - **누가 오는가**만 여기 있고 **얼마나 자주 오는가**(스폰 볼륨)는 없다. 볼륨은 카페 일구기
#     사다리가 `cafe.spawn_scale` 한 레버로 소유한다(main._refresh_cafe_ladder — 두 곳이 각자
#     쓰면 나중 것이 앞을 지운다). 이 원장은 그 볼륨 위에서 *정체성*만 가른다.
#   - TapperLedger·TreeLedger와 같은 결: 순수 데이터 + 조회 + 얇은 to_save/load_save. 실제 추첨은
#     cafe.roll_guest가 하고(가중치만 주입받는다), 이름·자리·그리기는 main이 맡는다(디커플링).
#   - 원장에 **감쇠가 없다**(안 오면 잊히는 규칙 0). 코지 톤 — 며칠 카페를 쉬어도 단골이 사라지지
#     않는다(방치가 손실이 아니라 정지인 채취기 결). 그래서 일일 훅(advance_day)이 없다:
#     날짜로 굴러가는 상태가 하나도 없으므로 빈 함수를 만들지 않는다. **하루 1인 1회 방문** 규칙은
#     원장이 아니라 그날의 영업(cafe._guests_today — 영업 시작마다 리셋)이 든다.

# ── 명명 손님 로스터(ADR-0064 결정 8 — 신규 캐릭터 발명 0) ────────────────────
# 현행 주민 중 **카페에 손님으로 올 수 있는** 사람들. 값은 Resident.id다.
# ★ 제외된 사람들과 그 근거:
#   · 미호·멜 = 카페 *직원*(오후 스케줄이 카페다 — 손님이 아니다)
#   · 옥자    = 사장(상주 앵커) · 바나 = 밤 무대(영업창이 겹치지 않는다)
# ★ 모찌는 로스터에 있지만 저녁 스케줄이 카페 홀이라, main의 적격 필터가 *그 시간엔* 뺀다
#   (같은 사람이 서서 + 앉아서 둘로 보이는 것을 막는다 — main._cafe_guest_pool 주석).
const GUEST_IDS := ["neo", "boatman", "ongi", "mochi", "pulmu", "mugol"]

# ── 단골화 곡선(그레이박스 레버 — ADR-0064 결정 8 "최소 구현") ────────────────
# 가중치 = BASE + STEP × min(서빙 횟수, CAP). 처음 온 손님 2 → 단골 8(4배)까지 오른다.
# ★ 상한(CAP)이 있는 이유: 무한 성장이면 한 단골이 좌석을 독식해 나머지 로스터가 죽는다.
#   "자주 보이지만 혼자 오는 건 아니다"가 코지한 카페의 결이다.
const BASE_WEIGHT := 2      # 서빙 이력 0인 명명 손님의 기본 가중치(익명 W_ANON_GUEST와 비교된다)
const FAMILIAR_STEP := 1    # 서빙 1회당 가중치 증가분
const VISIT_CAP := 6        # 가중치에 반영되는 서빙 횟수 상한(그 위로는 기록만 쌓인다)
const REGULAR_AT := 3       # 이 횟수부터 "단골"로 부른다(표시·표식 전용 — 가중치와 별개 눈금)

# 서빙 이력 {guest_id: 누적 서빙 횟수}. 한 번도 안 판 손님은 키가 없다(세이브 군더더기 0).
var _visits: Dictionary = {}

# ── 기록(서빙이 유일한 입력) ─────────────────────────────────────────────────
# 이 명명 손님에게 한 잔 냈다. 익명 손님("")·모르는 id는 조용히 흘려보낸다(원장은 이름 있는
# 사람만 센다 — 익명은 이름도 호감도도 없다는 결정 8 그대로).
# ★ 여기가 **호감도를 안 건드리는 것**이 ADR-0017 보호의 코드적 표현이다(cafe_guest_test ④가 단언).
func record_serve(id: String) -> void:
	if id == "" or not GUEST_IDS.has(id):
		return
	_visits[id] = visits_of(id) + 1

# ── 조회 ────────────────────────────────────────────────────────────────────
func visits_of(id: String) -> int:
	return int(_visits.get(id, 0))

# 이 손님의 재방문 가중치(cafe.roll_guest가 익명 가중치와 나란히 놓고 추첨한다).
# 서빙 횟수에 **단조 증가**한다(같으면 같고, 늘면 는다 — cafe_guest_test ②가 단언하는 계약).
func weight_of(id: String) -> int:
	return BASE_WEIGHT + FAMILIAR_STEP * mini(visits_of(id), VISIT_CAP)

# 단골인가(표시 눈금 — 좌석 표식·프롬프트가 쓴다). 가중치 상한과는 별개 값이다.
func is_regular(id: String) -> bool:
	return visits_of(id) >= REGULAR_AT

# 서빙 이력이 있는 손님 수(정산 요약·디버그).
func known_count() -> int:
	return _visits.size()

# 전체 누적 서빙 횟수(디버그·검증).
func total_visits() -> int:
	var sum := 0
	for id in _visits:
		sum += int(_visits[id])
	return sum

# ── 세이브/로드 — 슬라이스 키 "guest_pool" 네임스페이스 ──────────────────────
# ★ 신규 키라 **구세이브엔 없다** — main이 키 부재를 보고 이 함수를 아예 안 부른다(빈 원장 =
#   전원 처음 오는 손님 = 막힘 0. 곳간·수액 채취기가 쓰는 그 하위호환 관례 1:1).
func to_save() -> Dictionary:
	return {"visits": _visits.duplicate()}

# 복원: 로스터에 없는 id·0 이하 횟수는 걸러 낸다(손상·구버전 id 방어 — inventory._sanitize 결).
func load_save(data: Dictionary) -> void:
	_visits = {}
	var raw: Variant = data.get("visits", {})
	if typeof(raw) != TYPE_DICTIONARY:
		return
	for id in raw:
		var gid := str(id)
		if not GUEST_IDS.has(gid):
			continue
		var n := int(raw[id])
		if n <= 0:
			continue
		_visits[gid] = n
