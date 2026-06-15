extends Node
class_name Affinity
# T3.3 — 호감도(하트): 미호와의 관계 수치.
#
# 목적: "일일 대화(하루 1회 소폭)와 선물(영혼 호박 선호)로 호감도가 오르고,
#       하트 단계가 UI에 반영된다"를 회색 UI만으로 검증한다
#       (ADR-0001 그레이박스, CONTEXT '호감도').
#
# 설계 메모:
#   - energy.gd·wallet.gd와 같은 결: 이 노드는 "미호 호감도 수치"라는 단일 책임만
#     가진다. 대화/선물 트리거(말걸기)·HUD 표시·여우불 연동(T3.4)은 main이 맡고,
#     여기서는 상태(누적 점수·마지막 행동 날)와 changed 시그널만 제공한다.
#   - 두 채널로 오른다 — ㉠ 일일 대화(하루 1회 소폭, 느린 채널) ㉡ 선물(선호 작물 큰
#     폭, 빠른 채널). 둘 다 "하루 1회" 리듬에 맞춰 게임 날짜로 게이팅한다(같은 날
#     중복 보상 방지). 무엇이 '오늘'인지의 트리거 값(GameClock.day)은 main이 넘긴다.
#   - 하트 = 점수 / POINTS_PER_HEART(내림). MAX_HEARTS에서 멈춘다. CONTEXT '호감도'의
#     이중 보상(농사 효율↑ = 여우불 강화 T3.4 / 서사↑ = 미호 대사 변화)이 이 하트
#     단계 위에 얹힌다(여기서는 단계 값만 제공, 보상 연결은 각 시스템이 맡음).
#   - 선호 작물은 영혼 호박(CONTEXT '영혼 호박' — 미호 호박밭 떡밥과 이어지는 상징
#     작물). 데이터는 CropCatalog id를 그대로 쓴다(코드·세이브용).
#   - T2.5 세이브/로드 — 상태가 정수 셋(점수·마지막 대화날·마지막 선물날)뿐이라
#     그대로 직렬화된다. 복원 시 점수는 [0, MAX_POINTS]로 잘라 손상 세이브에 방어한다.

signal changed(points: int, hearts: int)  # 호감도가 바뀐 프레임(main이 HUD 갱신)

const MAX_HEARTS := 5             # 그레이박스 하트 단계 수(밸런싱은 후속)
const POINTS_PER_HEART := 50      # 하트 한 칸을 채우는 데 필요한 점수
const MAX_POINTS := MAX_HEARTS * POINTS_PER_HEART  # 만렙 점수(여기서 멈춤)

const DAILY_TALK_POINTS := 5         # 일일 대화 1회 소폭(느린 채널)
const GIFT_POINTS := 15              # 일반 작물 선물
const GIFT_PREFERRED_POINTS := 40    # 선호 작물 선물(빠른 채널)
const PREFERRED_CROP := CropCatalog.YEONGHON_HOBAK  # 영혼 호박 선호

var points: int = 0
var last_talk_day: int = -1   # 마지막으로 일일 대화 보상을 받은 게임 날(-1 = 아직 없음)
var last_gift_day: int = -1   # 마지막으로 선물한 게임 날(-1 = 아직 없음)

# ── 조회 ──────────────────────────────────────────────────────────────────
# 현재 하트 단계(0..MAX_HEARTS). 점수를 칸당 점수로 나눈 내림값, 만렙에서 멈춘다.
func hearts() -> int:
	return mini(points / POINTS_PER_HEART, MAX_HEARTS)

# 채운 하트 + 빈 하트 막대(HUD용). 예: 3/5 → "♥♥♥♡♡".
func heart_bar() -> String:
	var h := hearts()
	return "♥".repeat(h) + "♡".repeat(MAX_HEARTS - h)

# 이 작물이 미호의 선호 선물인가(선호면 선물 점수가 크다).
func is_preferred(crop_id: String) -> bool:
	return crop_id == PREFERRED_CROP

# ── 일일 대화(하루 1회 소폭) ────────────────────────────────────────────────
# 오늘(이 게임 날) 아직 대화 보상을 안 받았으면 줄 수 있다.
func can_daily_talk(day: int) -> bool:
	return day != last_talk_day

# 일일 대화 보상을 적용한다. 오늘 이미 받았으면 false(점수 변화 없음 — 대사만 바뀐다).
# 성공 시 last_talk_day를 갱신하고 소폭 점수를 더한 뒤 true.
func daily_talk(day: int) -> bool:
	if not can_daily_talk(day):
		return false
	last_talk_day = day
	_add(DAILY_TALK_POINTS)
	return true

# ── 선물(선호 작물 큰 폭) ──────────────────────────────────────────────────
# 오늘 아직 선물하지 않았으면 줄 수 있다(하루 1회).
func can_gift(day: int) -> bool:
	return day != last_gift_day

# 선물 1회를 적용한다. 오늘 이미 했으면 0(획득 없음). 성공 시 얻은 점수를 반환한다
# (선호 작물이면 큰 폭). 선물 작물의 소모는 호출 측(main+Inventory)이 책임진다.
func gift(crop_id: String, day: int) -> int:
	if not can_gift(day):
		return 0
	last_gift_day = day
	var gained := GIFT_PREFERRED_POINTS if is_preferred(crop_id) else GIFT_POINTS
	_add(gained)
	return gained

# 점수를 더하고 [0, MAX_POINTS]로 잘라 changed를 발화한다(음수·만렙 초과 방지).
func _add(n: int) -> void:
	points = clampi(points + n, 0, MAX_POINTS)
	changed.emit(points, hearts())

# ── T2.5 세이브/로드 ──────────────────────────────────────────────────────
# 상태가 정수 셋뿐이라 그대로 직렬화된다. 복원 시 점수를 잘라 손상 세이브에 방어한다.
func to_save() -> Dictionary:
	return {
		"points": points,
		"last_talk_day": last_talk_day,
		"last_gift_day": last_gift_day,
	}

func load_save(data: Dictionary) -> void:
	points = clampi(int(data.get("points", 0)), 0, MAX_POINTS)
	last_talk_day = int(data.get("last_talk_day", -1))
	last_gift_day = int(data.get("last_gift_day", -1))
	changed.emit(points, hearts())
