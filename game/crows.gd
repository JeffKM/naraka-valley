class_name CrowRaid

# ★ [ADR-0051] 밤 까마귀(미련까마귀) 작물 습격 — 순수 결정적 로직(field·main 무의존, 헤드리스 재현).
#
#   무엇을 하나: 밤새 무방비 작물을 쪼아 *영구 소실*시킨다(스타듀 충실). 단 3중 안전장치로
#   영구 손실을 "밭 커지면 허수아비 하나 세우는 관례"로 길들인다(코지 충돌 무력화):
#     ① 작물 문턱(CROP_THRESHOLD) 미만이면 습격 없음 — 초보·소규모 밭은 안전("평평≠막힘").
#     ② 한 밤 상한(NIGHTLY_CAP) — 심은 수에 비례하되 최대 몇 개(밭 전체 하룻밤 증발 방지).
#     ③ 허수아비 반경(BASE_RADIUS) 안 작물은 보호 — 예방이 자명·저렴한 일회성 넛지.
#
#   ⚠️ 까마귀는 전투 대상이 아니다([잡귀]와 별개·비전투·바나/나락 무관). resolve는 "어느 칸이
#   없어지나"만 판정하고, 실제 밭 반영(FarmField.remove_plant)·알림은 호출 측(main)이 한다.
#   Foxfire처럼 class_name 정적 유틸 — 상태를 안 들고, day 시드로만 결정적이다(테스트 재현 가능).

const CROP_THRESHOLD := 15   # 이 수 미만 심으면 까마귀 안 옴(코지 온보딩 보존 — 스타듀 값)
const NIGHTLY_CAP := 4       # 한 밤 최대 소실 작물 수(밭 전체 증발 방지 — 스타듀 최대치)
const BASE_RADIUS := 8       # 허수아비 보호 반경(칸, 유클리드) — 스타듀 값(≈248타일 원)
const DELUXE_RADIUS := 16    # 디럭스(레어크로우 8종 완성) = 반경 2배 — B 수집 슬라이스에서 배선

# 한 칸이 어느 허수아비든 반경 안(보호됨)인가 — 유클리드 거리 ≤ radius.
static func is_protected(t: Vector2i, scarecrows: Array, radius: int) -> bool:
	for s in scarecrows:
		if Vector2(t - s).length() <= float(radius):
			return true
	return false

# 심은 수 비례 소실 마릿수(② 상한) — 문턱당 1, 최대 NIGHTLY_CAP.
#   15~29작물 → 1 / 30~44 → 2 / 45~59 → 3 / 60+ → 4.
static func nightly_count(planted_total: int) -> int:
	return clampi(planted_total / CROP_THRESHOLD, 1, NIGHTLY_CAP)

# 밤 습격 판정 — 소실될 칸 목록을 돌려준다(부수효과 없음, 순수 함수).
#   planted    = 현재 심긴 칸 전체(FarmField.planted_tiles)
#   scarecrows = 허수아비 보호 중심 칸(말뚝 밑동)
#   radius     = 보호 반경(BASE_RADIUS 또는 디럭스 DELUXE_RADIUS)
#   day        = 결정적 시드(같은 날·같은 밭·같은 허수아비 → 같은 결과, 헤드리스 재현)
static func resolve(planted: Array, scarecrows: Array, radius: int, day: int) -> Array:
	if planted.size() < CROP_THRESHOLD:              # ① 문턱 — 소규모 밭은 위협 없음
		return []
	var exposed: Array = []                          # ③ 보호 밖(무방비) 후보만 추림
	for t in planted:
		if not is_protected(t, scarecrows, radius):
			exposed.append(t)
	if exposed.is_empty():
		return []
	# 결정적 정렬(입력 순서 무관) 후 day 시드로 셔플 → 앞에서 want개(② 상한).
	exposed.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.y < b.y if a.y != b.y else a.x < b.x)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("crow:%d" % day)
	for i in range(exposed.size() - 1, 0, -1):       # Fisher–Yates(결정적)
		var j := rng.randi_range(0, i)
		var tmp: Vector2i = exposed[i]
		exposed[i] = exposed[j]
		exposed[j] = tmp
	var want := mini(nightly_count(planted.size()), exposed.size())
	return exposed.slice(0, want)
