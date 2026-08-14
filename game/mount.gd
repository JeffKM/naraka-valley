extends RefCounted
class_name Mount
# ★[S10-T4 / ADR-0069 결정 6] 탈것 — 저승 말 「먹갈기」의 **승마 상태 원장**.
#
# 목적: CONTEXT [먹갈기]가 "타면 야외 이동이 빨라진다(실내·컷신에서는 내린다)"로 정의해 둔
#       그 한 문장을 코드 한 장으로 세운다. 이 파일이 아는 것은 **지금 타고 있는가** 하나뿐이고,
#       그 bool 하나에서 속도 계수와 하차 강제가 전부 파생된다.
#
# ── 경계(Carpenter·TapperLedger 머리말의 디커플링 규약 그대로) ────────────────
#   - **지갑·인벤·플레이어·구역을 모른다.** 마구간을 짓는 일(Carpenter 원장)도, 휘파람을 쥐여
#     주는 일(main의 완공 배선)도, 속도를 실제로 곱하는 일(player.speed_scale)도 전부 밖이다.
#     여기 있는 건 "탔다/내렸다"와 "탈 수 있는 자리인가"의 판정뿐이다.
#   - **RNG 0 · 벽시계 0.** 같은 입력이면 같은 답이라 헤드리스가 통째로 결정적이다.
#   - **세이브는 bool 하나**다(`"mount"` 조각). 키 없는 구세이브 = 안 탄 상태로 시작한다.
#
# ⚠️ **노동·전투 자원이 아니다**(CONTEXT [먹갈기] 마지막 문장). 승마는 혼력을 아끼지 않고,
#    도구를 대신 휘두르지 않으며, 전투 무대(나락)에는 아예 들어가지 않는다(BLOCKED_REGIONS).
#    ×1.5는 **이동 편의**라 [ADR-0019]의 "영구 % 곱셈 = 관계 곱셈기 전용" 금지에 안 걸린다 —
#    ADR-0069 결정 6이 명시적으로 허용한 그 예외다(산출·확률·경제에는 한 톨도 안 닿는다).

# ── 이동 계수(결정 6 — 잠정 레버·owner 큐) ───────────────────────────────────
# ×1.5. 스타듀 말이 대략 이 배율이고, 두 배로 올리면 코지-와이드 맵(80×65)이 좁아 보여
# 세계가 작아진다. 걸어 다니는 맛을 지우지 않는 최소 눈금이 이 값이다.
const SPEED_SCALE := 1.5

# ── 탈 수 없는 자리 ──────────────────────────────────────────────────────────
# ★[전투 무대 배제] 나락은 리셋 런 아레나라 이동 속도가 곧 전투 이점이 된다. CONTEXT가 못 박은
#   "전투 자원이 아니다"를 지키는 유일한 코드적 표현이 이 명단이다(업화 갱도는 채광 무대라
#   지상 이동과 같은 결로 두되, 나락 *층*은 아래 `ride_allowed`가 depth로 막는다).
const BLOCKED_REGIONS := [RegionCatalog.NARAK]

# ── 상태 ────────────────────────────────────────────────────────────────────
var _mounted := false

# ── 판정(static — main·테스트가 원장 없이도 읽는다) ──────────────────────────
# 지금 이 자리가 말에 탈 수 있는 자리인가. 세 가드의 AND다:
#   ㉠ **야외**(`indoor == ""`) — 실내는 방이 좁아 말이 설 자리가 없다(결정 6 "실내 불가")
#   ㉡ **컷신 아님** — 연출 중에는 카메라·NPC 배치가 러너 소유라 탈것이 끼면 그림이 깨진다
#   ㉢ **전투 무대 아님** — BLOCKED_REGIONS + 나락 층(depth > 0)
static func ride_allowed(indoor: String, region: String, in_cutscene: bool,
		narak_depth: int = 0) -> bool:
	if indoor != "" or in_cutscene:
		return false
	if BLOCKED_REGIONS.has(region) or narak_depth > 0:
		return false
	return true

# ── 질의 ────────────────────────────────────────────────────────────────────
func is_mounted() -> bool:
	return _mounted

# player.speed_scale에 그대로 흘려넣을 계수(안 탔으면 1.0 = 무영향).
func speed_scale() -> float:
	return SPEED_SCALE if _mounted else 1.0

# ── 전이 ────────────────────────────────────────────────────────────────────
# 휘파람 — 부르면 온다. 이미 탄 상태이거나 못 타는 자리면 false(무동작).
# ⚠️ **휘파람 보유 검사는 여기 없다**(인벤을 모른다 — 머리말의 경계). main이 먼저 본다.
func mount_up(indoor: String, region: String, in_cutscene: bool, narak_depth: int = 0) -> bool:
	if _mounted or not ride_allowed(indoor, region, in_cutscene, narak_depth):
		return false
	_mounted = true
	return true

# 내린다(휘파람 두 번째 · 강제 하차 공용). 이미 내려 있으면 false.
func dismount() -> bool:
	if not _mounted:
		return false
	_mounted = false
	return true

# 매 프레임 자리 검사 — 탈 수 없는 자리로 들어갔으면 **말없이 내린다**(문을 열면 말이 밖에
# 남는 스타듀 결). 강제 하차가 일어났을 때만 true를 돌려주므로, main이 그때만 알림을 띄운다.
func enforce(indoor: String, region: String, in_cutscene: bool, narak_depth: int = 0) -> bool:
	if not _mounted or ride_allowed(indoor, region, in_cutscene, narak_depth):
		return false
	_mounted = false
	return true

# ── 세이브/로드(Carpenter 규약 계승) — 슬라이스 키 "mount" ──────────────────
func to_save() -> Dictionary:
	return {"mounted": _mounted}

func load_save(data: Dictionary) -> void:
	_mounted = bool(data.get("mounted", false))   # 키 없는 구세이브 = 안 탄 상태
