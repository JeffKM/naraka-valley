extends RefCounted
class_name Pet
# ★[S10-T4 / ADR-0069 결정 7] 코지 펫 — 삽살개 「삽사리」의 **우정 원장**.
#
# 목적: CONTEXT [삽사리]가 "쓰다듬고 물그릇을 채우며 우정을 쌓고, 다 채우면 [명부의 운]의
#       *바닥*을 한 눈금 덜어 준다"로 정의해 둔 자리를 세운다. 이 파일은 그 우정 하나만 든다.
#
# ── ⚠️ [바나] 사역마와의 **위상 분리**(결정 7이 명문화를 요구한 항목) ────────────
#   바나의 사역마(박쥐·검은고양이)와 삽사리는 겉보기에 둘 다 "곁의 짐승"이지만 층이 다르다.
#
#     ┌────────┬────────────────────────────┬────────────────────────────────┐
#     │        │ 사역마(박쥐·검은고양이)      │ 삽사리(이 파일)                 │
#     ├────────┼────────────────────────────┼────────────────────────────────┤
#     │ 소유   │ [바나]의 것 — 캐릭터 모티프  │ 플레이어의 것 — 집에 들인 곁     │
#     │ 층     │ 전투·도메인(혈귀의 권속)     │ **순수 코지**(전투 관여 0)       │
#     │ 보상   │ 바나 도메인 곱셈기 축        │ [명부의 운] **하한** 보정뿐      │
#     │ 코드   │ bana.gd의 실루엣 모티프뿐    │ 이 원장(전투 파일 참조 0)        │
#     └────────┴────────────────────────────┴────────────────────────────────┘
#
#   그래서 이 파일은 **전투 표면을 한 줄도 갖지 않는다**: Mob·PlayerHealth·CombatSkill·
#   WeaponCatalog 어느 것도 참조하지 않고, 공격력·방어·드랍에 닿는 함수도 없다. 사역마를
#   트링켓/장비로 여는 이야기는 [ADR-0069] 결정 1이 서랍에 둔 별건이고, 이 파일이 그 서랍을
#   미리 여는 일은 없어야 한다(열리는 순간 "펫 = 전투 슬롯"이 되어 코지 정체성이 무너진다).
#
# 설계 메모(Ranch 우정 축과 같은 결·다른 파일):
#   - **livestock.gd를 상속·참조하지 않는다.** 짐승은 산물을 내는 노동 엔티티고 삽사리는 아무
#     것도 안 낸다 — 우정 *문법*(FRIEND_MAX 1000 · 200/하트 · 쓰다듬 +15)만 같은 눈금을 쓴다.
#     같은 눈금을 쓰는 이유는 플레이어가 이미 그 감각을 배웠기 때문이지 같은 시스템이라서가 아니다.
#   - **하루 1회 잠금은 day 비교**다(RNG 0 · 벽시계 0). 세이브에 마지막 날만 적어 두면 껐다 켜도
#     같은 날 두 번 쓰다듬을 수 없다.
#   - **지갑·인벤·구역을 모른다.** 획득 컷신도, [F] 프롬프트도, 색박스 그리기도 전부 main이다.

# ── 획득(결정 7 "마을 이벤트 1회" — 잠정 레버·owner 큐) ──────────────────────
# 나루 마을에 들어선 아침에 만난다. ★ **잠정 7일**: 첫 주는 밭·도구·카페가 한꺼번에 들어오는
# 구간이라 그 위에 곁을 하나 더 얹으면 무엇 하나 눈에 안 들어온다. 한 주가 지나 마을 길이
# 익숙해진 뒤가 "동네 개가 따라온다"는 장면에도 맞다.
const ADOPT_MIN_DAY := 7

# ── 우정 눈금(Ranch §4.1 눈금 상속 — 잠정 레버·owner 큐) ─────────────────────
const FRIEND_MAX := 1000          # 우정 상한(200/하트 → 0~5하트)
const FRIEND_PER_HEART := 200
const F_PET := 15                 # 쓰다듬 1/일(Ranch F_PET 1:1 — 같은 손짓, 같은 값)
const F_BOWL := 8                 # 물그릇 채우기 1/일(잠정 — 쓰다듬의 절반쯤. 손이 덜 가는 돌봄)

# ★ 만점까지의 최단 일수 = ceil(1000 / 23) = 44일. 절기 하나 반쯤 되는 거리라 "엔드게임 롱테일"
#   (ADR-0069 ㉠)의 눈금에 맞고, 하루라도 거르면 그만큼 뒤로 밀린다(매일의 돌봄 라임).

# ── 상태 ────────────────────────────────────────────────────────────────────
var _adopted := false
var _friend := 0
var _pet_day := 0        # 마지막으로 쓰다듬은 날(0 = 없음)
var _bowl_day := 0       # 마지막으로 물그릇을 채운 날(0 = 없음)

# ── 질의 ────────────────────────────────────────────────────────────────────
func is_adopted() -> bool:
	return _adopted

func friendship() -> int:
	return _friend

func hearts() -> int:
	return _friend / FRIEND_PER_HEART

func max_hearts() -> int:
	return FRIEND_MAX / FRIEND_PER_HEART

func is_maxed() -> bool:
	return _friend >= FRIEND_MAX

# 오늘 쓰다듬을 수 있는가 / 물그릇을 채울 수 있는가(프롬프트 문구의 유일한 입력).
func can_pet(day: int) -> bool:
	return _adopted and _pet_day != day

func can_fill_bowl(day: int) -> bool:
	return _adopted and _bowl_day != day

# ★ 만점 보상 = [명부의 운] **하한** 보정(결정 7). 평균을 올리는 게 아니라 바닥을 덜 아프게
#   하는 방향이라 [ADR-0019] +% 금지와 충돌하지 않는다 — 이 함수가 그 계약의 유일한 표면이고,
#   실제 보정은 DailyLuck.floor_luck이 순수 함수로 한다(이 파일은 운을 계산하지 않는다).
func luck_floor_active() -> bool:
	return _adopted and is_maxed()

# 이 날에 마을 이벤트가 설 수 있는가(획득 전 · 잠정 문턱 이후).
func adopt_ready(day: int) -> bool:
	return not _adopted and day >= ADOPT_MIN_DAY

# ── 전이 ────────────────────────────────────────────────────────────────────
# 입양(마을 이벤트 1회). 이미 들였으면 false — **2호는 없다**(최대 1).
func adopt(day: int) -> bool:
	if not adopt_ready(day):
		return false
	_adopted = true
	return true

# 쓰다듬 — 하루 1회. 새로 섰으면 true(오른 우정은 friendship()으로 읽는다).
func pet_today(day: int) -> bool:
	if not can_pet(day):
		return false
	_pet_day = day
	_friend = mini(FRIEND_MAX, _friend + F_PET)
	return true

# 물그릇 — 하루 1회.
func fill_bowl(day: int) -> bool:
	if not can_fill_bowl(day):
		return false
	_bowl_day = day
	_friend = mini(FRIEND_MAX, _friend + F_BOWL)
	return true

# 우정 한 줄 요약(프롬프트·정보 패널용). 미입양이면 "".
func summary() -> String:
	if not _adopted:
		return ""
	return "삽사리 — 우정 %d/%d" % [hearts(), max_hearts()]

# ── 세이브/로드(Carpenter·Mount 규약 계승) — 슬라이스 키 "pet" ───────────────
func to_save() -> Dictionary:
	return {"adopted": _adopted, "friend": _friend, "pet_day": _pet_day, "bowl_day": _bowl_day}

func load_save(data: Dictionary) -> void:
	# 키 없는 구세이브 = 미입양·우정 0(하위호환 — 아무것도 안 막힌다. 문턱 날에 그냥 만난다).
	_adopted = bool(data.get("adopted", false))
	_friend = clampi(int(data.get("friend", 0)), 0, FRIEND_MAX)   # 손상 세이브 방어
	_pet_day = maxi(0, int(data.get("pet_day", 0)))
	_bowl_day = maxi(0, int(data.get("bowl_day", 0)))
