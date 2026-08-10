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

# ★[S6-T5 / ADR-0064 결정 5] 체키 한 장이 얹는 단골화 점수(그레이박스 레버). 서빙 1회(+1)와 같은
# 눈금 위에 놓되 잘 찍은 한 장은 두 배로 남는다 — "같이 찍은 사진"이 재방문 이유가 되는 결.
# ★ 인생샷만 2점인 건 **사슬 끝까지 잘 간 날**을 기억하게 하려는 것이고, 그래도 VISIT_CAP은 그대로
#   먹는다(아래 weight_of) — 체키를 아무리 찍어도 한 단골이 좌석을 독식하지 못한다.
const CHEKI_STEP := 1           # OK·GOOD 한 장이 얹는 점수
const CHEKI_STEP_PERFECT := 2   # PERFECT(인생샷) 한 장이 얹는 점수

# 서빙 이력 {guest_id: 누적 서빙 횟수}. 한 번도 안 판 손님은 키가 없다(세이브 군더더기 0).
var _visits: Dictionary = {}
# ★[S6-T5] 체키 이력 {guest_id: 누적 단골화 점수}. **서빙과 별도 dict**인 이유: visits_of는
# "몇 잔을 냈나"라는 뜻이고 그 뜻으로 읽는 자리(단골 판정 REGULAR_AT·정산 눈금)가 이미 있다.
# 체키를 같은 칸에 더하면 "3잔 팔았다"가 거짓이 된다 — 두 이력을 나눠 두고 **가중치에서만 합산**한다.
var _chekis: Dictionary = {}

# ── 기록(서빙이 유일한 입력) ─────────────────────────────────────────────────
# 이 명명 손님에게 한 잔 냈다. 익명 손님("")·모르는 id는 조용히 흘려보낸다(원장은 이름 있는
# 사람만 센다 — 익명은 이름도 호감도도 없다는 결정 8 그대로).
# ★ 여기가 **호감도를 안 건드리는 것**이 ADR-0017 보호의 코드적 표현이다(cafe_guest_test ④가 단언).
func record_serve(id: String) -> void:
	if id == "" or not GUEST_IDS.has(id):
		return
	_visits[id] = visits_of(id) + 1

# ★[S6-T5 / ADR-0064 결정 5] 이 명명 손님과 체키 한 장을 찍었다(등급 = ChekiSession.Grade 0~2).
# record_serve와 같은 결·같은 방어(익명·모르는 id는 조용히 흘려보낸다).
# ★★ 여기도 **호감도를 한 톨도 안 올린다**(ADR-0017 보호). 체키는 서빙 사슬의 다음 단이지 대화·
#   선물이 아니다 — 사진을 아무리 찍어도 ♡는 대화·선물로만 오른다(cheki_test ⓓ가 단언).
# ★ 등급을 정수로만 받는 건 GuestPool이 ChekiSession을 몰라도 되게 하기 위해서다(cafe.record_cheki와
#   같은 접점 규약 — 미니게임 파일과 원장 파일은 등급 정수 하나로만 만난다).
func record_cheki(id: String, grade: int) -> void:
	if id == "" or not GUEST_IDS.has(id):
		return
	var step := CHEKI_STEP_PERFECT if grade >= 2 else CHEKI_STEP
	_chekis[id] = cheki_points_of(id) + step

# ── 조회 ────────────────────────────────────────────────────────────────────
func visits_of(id: String) -> int:
	return int(_visits.get(id, 0))

# ★[S6-T5] 이 손님과의 체키가 쌓아 올린 단골화 점수(장수가 아니라 *점수* — 인생샷은 2점이다).
func cheki_points_of(id: String) -> int:
	return int(_chekis.get(id, 0))

# 이 손님의 재방문 가중치(cafe.roll_guest가 익명 가중치와 나란히 놓고 추첨한다).
# 서빙 횟수에 **단조 증가**한다(같으면 같고, 늘면 는다 — cafe_guest_test ②가 단언하는 계약).
# ★[S6-T5] 체키 점수가 **같은 상한(VISIT_CAP) 아래에서** 합산된다 — 사슬을 끝까지 가면 단골이 더
#   빨리 자라되, 천장은 그대로다(서빙만 해도 결국 같은 곳에 닿는다 = 체키가 게이트가 아니라 가속).
func weight_of(id: String) -> int:
	return BASE_WEIGHT + FAMILIAR_STEP * mini(visits_of(id) + cheki_points_of(id), VISIT_CAP)

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
	return {"visits": _visits.duplicate(), "chekis": _chekis.duplicate()}

# 복원: 로스터에 없는 id·0 이하 횟수는 걸러 낸다(손상·구버전 id 방어 — inventory._sanitize 결).
# ★[S6-T5] "chekis"는 S6-T4 세이브엔 없는 신규 키다 — 없으면 빈 원장(체키를 한 번도 안 찍은 것과
#   같다 = 막힘 0). 두 이력이 같은 정화 규칙을 쓰므로 헬퍼 하나로 묶는다.
func load_save(data: Dictionary) -> void:
	_visits = _sanitized(data.get("visits", {}))
	_chekis = _sanitized(data.get("chekis", {}))

func _sanitized(raw: Variant) -> Dictionary:
	var out: Dictionary = {}
	if typeof(raw) != TYPE_DICTIONARY:
		return out
	for id in raw:
		var gid := str(id)
		if not GUEST_IDS.has(gid):
			continue
		var n := int(raw[id])
		if n <= 0:
			continue
		out[gid] = n
	return out
