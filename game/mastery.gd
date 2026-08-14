extends RefCounted
class_name Mastery
# ★[S10-T8 / ADR-0069 결정 11] 경지 — 5스킬 만렙 **뒤**의 정점 층(무대 없는 UI 층).
#
# 무엇인가: 다섯 [스킬]을 전부 만렙까지 올린 뒤 열리는 정점 층이다(CONTEXT [경지]). 만렙을
#   넘겨 쌓이는 경험이 포인트가 되고, 스킬마다 **유물** 하나를 준다. ★ **새 장소가 아니다** —
#   스킬 패널(inv_frame TAB_SKILL)의 확장이라 좌표도 건물도 워프도 늘지 않는다(결정 11 자구).
#
# ★★ 어길 수 없는 가드 셋(전부 코드로 못 박고 mastery_test가 다시 단언한다):
#   ① **영구 % 곱셈 금지**([ADR-0019] · [ADR-0034] #4가 [저승 실용서]에 건 그 규칙과 동일).
#      +수율·+가치·+속도·피해감소 같은 배수는 **관계 곱셈기의 몫**이라 유물이 건드리면 두 축이
#      섞인다. 그래서 이 파일의 보상 스키마엔 배수를 담을 칸이 **아예 없다**(reward_id/n 둘뿐 —
#      "안 쓰기로 했다"가 아니라 "쓸 자리가 없다"). 표현 불가능이 가장 튼튼한 가드다.
#   ② **트링켓 슬롯 비상속**([ADR-0069] 결정 1 서랍 · 결정 11). 유물은 장착물이 아니라
#      **일회성 물건 지급**이다 — 장비 슬롯을 여는 순간 전투 grill 사안이 되고([ADR-0063]
#      결정 11 무기 서랍), 바나 사역마와의 위상 정리가 선행이라 이 슬라이스가 열 문이 아니다.
#   ③ **[ADR-0008] 평평≠막힘 무접촉** — 경지는 만렙 *뒤*에만 존재하는 **추가 층**이라 어떤 기존
#      메카닉도 이 뒤로 숨지 않는다. 유물을 하나도 안 받아도 게임의 모든 동사가 100% 가동한다.
#
# ★ 왜 유물이 전부 "물건 지급"인가(설계 판단 — 보고에 명시):
#   영구 QoL 플래그(예: "채집물 위치 상시 표시")를 얹으면 **[ADR-0052] 전문직 퍼크와 정면으로
#   겹친다**(그쪽이 이미 비-가치 4차원 = 품질·수량·효율·편의를 통째로 소유한다). 같은 차원을 두
#   시스템이 나눠 가지면 어느 쪽이 진실원인지 흐려지고 수치가 이중으로 얹힌다. 그래서 경지는
#   *차원을 건드리지 않는 축* — flat 일회성 물건 — 하나만 쓴다. [ADR-0034]의 [저승 실용서]가
#   "flat 일회성 범프 + 곱셈기-무관 편의"로 자기 자리를 잡은 그 선례 1:1이다.
#
# 이 파일이 모르는 것: XP가 어디서 쌓이는지·인벤토리·화면. 스칼라(_farming_xp 등)는 main이 들고
#   (FarmSkill↔_farming_xp 관계 그대로), 여기는 "그 XP가 만렙을 얼마나 넘겼나 → 포인트 몇 점 →
#   무엇을 줄 수 있나"만 안다. 지급은 main이 한다(FireflySouls.pending_milestones 관계 동형).

signal changed()   # 수령·복원 프레임(main이 듣고 숙련 탭을 다시 세운다)

# ── 누적 문턱 5단(결정 11 "누적 문턱 잠정 5단" · 전부 **잠정 — owner 큐**) ────────
# 단위 = **5스킬 만렙 초과 XP의 합**이다. 한 스킬만 파도 열리게 둔 이유: 만렙 뒤의 플레이는
# 이미 자기 취향으로 굳어 있어(낚시만 하는 사람·나락만 도는 사람) 스킬별 개별 문턱을 걸면
# "안 하는 축" 때문에 층이 통째로 잠긴다 — 그건 게이트가 아니라 벌칙이다([ADR-0008] 정신).
# 밴드 근거 = L9→L10 구간(1,000 XP)의 배수. 2단부터 간격이 벌어지는 누진이라 마지막 유물이
# 가장 무겁다(스킬 곡선 자체가 후반 누진인 것과 같은 결).
const THRESHOLDS := [2000, 5000, 9000, 14000, 20000]

# 유물 하나의 값(포인트). 문턱 5단 × 1점 = 유물 5점이라 **정확히 전부 받을 수 있다**(남거나
# 모자라는 포인트가 없다 — 5스킬 × 유물 1점이라는 결정 11의 대칭을 수치로도 지킨다).
const ARTIFACT_COST := 1

# ── 유물 로스터(★ 이 태스크에서 잠근다 — 스킬당 1점 · 명명·수량 전부 잠정 · owner 큐) ──
# 키 = ProfessionCatalog 스킬 id. **분모를 손으로 안 적는다** — 스킬이 늘면 `missing_skills()`가
# 즉시 그 사실을 알린다(mastery_test ②가 매 실행마다 두 로스터를 대조한다).
#
# 답례 품목은 전부 **그 스킬 도메인의 소모품**이다. 셋 다 이미 다른 창구에서 냥으로 팔리거나
# 나오는 물건이라 **새 힘이 0**이고(값만 다른 길), 스택 소모품이라 flat 일회성이 자명하다.
#   · 농사 → 최고급 비료 (밭 품질 편의)
#   · 채집 → 단단한 원목 (채집 스킬이 **벌목 XP도 든다** — main._gain_forage_xp가 도끼 훅에서도
#            불린다. 그래서 이 축의 도메인 재화는 자재다)
#   · 낚시 → 보장 미끼   (어획 편의)
#   · 채광 → 업화알돌    (개봉하는 재미 = 편의. 산출은 지오드 표가 정한다)
#   · 전투 → 명부환      (회복 편의)
const ARTIFACTS := {
	"farming": {"id": "art_heulk", "name": "흙의 기억",
		"desc": "갈아 온 흙이 손을 기억한다", "reward_id": "fert_deluxe", "n": 20},
	"foraging": {"id": "art_gilnun", "name": "길눈 초롱",
		"desc": "숲이 먼저 길을 내어 준다", "reward_id": "hardwood", "n": 50},
	"fishing": {"id": "art_mulddae", "name": "물때 수첩",
		"desc": "물이 언제 입을 여는지 적혀 있다", "reward_id": "bait_pledge", "n": 30},
	"mining": {"id": "art_bulssi", "name": "불씨 부적",
		"desc": "바위 속 불씨가 스스로 드러난다", "reward_id": "geode_eophwa", "n": 15},
	"combat": {"id": "art_wipae", "name": "무명 무사의 위패",
		"desc": "이름 없이 스러진 이들이 곁에 선다", "reward_id": "myeongbuhwan", "n": 15},
}

# ── 원장(세이브 대상 — 파생 불가능한 것 하나뿐) ───────────────────────────────
# 수령한 유물의 **스킬 id** 목록. 포인트 잔량은 여기서 파생한다(적립 포인트 − 쓴 포인트)이라
# 별도 스칼라를 안 든다 — 두 수가 어긋날 자리를 구조적으로 없앤다(FireflySouls.gate_open 정신).
var claimed: Array = []

# ── 로스터 파생(하드코딩 0) ──────────────────────────────────────────────────
# 유물이 걸린 스킬 목록 = **ProfessionCatalog.SKILLS 순서 그대로**(선언 순 = 숙련 탭 행 순서).
static func skills() -> Array:
	var out: Array = []
	for s in ProfessionCatalog.SKILLS:
		if ARTIFACTS.has(String(s)):
			out.append(String(s))
	return out

# 유물이 아직 안 배정된 스킬(정상 상태 = 빈 배열). 스킬이 늘었는데 로스터를 안 채우면 여기 뜬다.
static func missing_skills() -> Array:
	var out: Array = []
	for s in ProfessionCatalog.SKILLS:
		if not ARTIFACTS.has(String(s)):
			out.append(String(s))
	return out

static func artifact_of(skill: String) -> Dictionary:
	return ARTIFACTS.get(skill, {})

static func artifact_count() -> int:
	return skills().size()

# 만렙 XP(레벨 곡선의 마지막 임계). ★ FarmSkill이 곡선의 단일 출처다 — 5스킬이 전부 그 곡선을
#   되비추므로(fish_skill.gd:54 등 `xp_thresholds()`가 FarmSkill을 그대로 돌려준다) 여기서도
#   그 한 곳만 읽는다. 숫자 5,500을 어디에도 안 적는다.
static func max_level_xp() -> int:
	var t: Array = FarmSkill.XP_THRESHOLDS
	return int(t[t.size() - 1]) if not t.is_empty() else 0

# 한 스킬의 **만렙 초과 XP**(만렙 미만이면 0). 결정 11 "포인트 = 만렙 초과 XP 적립"의 정의다.
static func overflow_of(xp: int) -> int:
	return maxi(xp - max_level_xp(), 0)

# 5스킬 초과 XP의 합. xps = {skill_id: xp}(main의 스칼라 다섯을 그대로 담아 넘긴다).
static func total_overflow(xps: Dictionary) -> int:
	var sum := 0
	for s in ProfessionCatalog.SKILLS:
		sum += overflow_of(int(xps.get(String(s), 0)))
	return sum

# ── 개방 판정(5스킬 **전부** 만렙 — 결정 11 "5스킬 만렙 후 개방") ────────────────
# levels = {skill_id: level}. 하나라도 만렙 미만이면 닫힘. ★ 스킬 목록은 레지스트리 파생이라
#   스킬이 늘면 조건이 저절로 빡빡해진다(수동 목록 = 잠복 stale — S9b가 반복해 데인 그 자리).
static func is_open(levels: Dictionary) -> bool:
	for s in ProfessionCatalog.SKILLS:
		if int(levels.get(String(s), 0)) < FarmSkill.MAX_LEVEL:
			return false
	return true

# 아직 만렙이 아닌 스킬 목록(안내 문구용 — "무엇이 남았나"가 자명해야 층이 게이트로 읽힌다).
static func pending_skills(levels: Dictionary) -> Array:
	var out: Array = []
	for s in ProfessionCatalog.SKILLS:
		if int(levels.get(String(s), 0)) < FarmSkill.MAX_LEVEL:
			out.append(String(s))
	return out

# ── 포인트(전부 파생 — 저장 상태 0) ──────────────────────────────────────────
# 누적 초과 XP가 넘긴 문턱 수 = 적립 포인트.
static func earned_points(overflow: int) -> int:
	var n := 0
	for t in THRESHOLDS:
		if overflow >= int(t):
			n += 1
		else:
			break
	return n

# 다음 문턱까지 남은 초과 XP(0 = 더 없음 = 5단 전부 통과).
static func next_threshold(overflow: int) -> int:
	for t in THRESHOLDS:
		if overflow < int(t):
			return int(t)
	return 0

func spent_points() -> int:
	return claimed.size() * ARTIFACT_COST

func available_points(overflow: int) -> int:
	return maxi(earned_points(overflow) - spent_points(), 0)

func has_claimed(skill: String) -> bool:
	return claimed.has(skill)

# 지금 이 스킬의 유물을 받을 수 있나 = 층이 열렸고 · 로스터에 있고 · 미수령 · 포인트 충족.
func can_claim(skill: String, levels: Dictionary, overflow: int) -> bool:
	if not ARTIFACTS.has(skill) or claimed.has(skill):
		return false
	if not is_open(levels):
		return false
	return available_points(overflow) >= ARTIFACT_COST

# 유물을 수령 처리한다(원장만 — 물건 지급은 main이 백팩에 넣는다). 성공 시 유물 행, 실패 {}.
# ★ **적재 먼저·기록 나중**이 아니라 그 반대다: main이 `can_claim` → `inventory.add_item` →
#   여기 `claim`의 순서로 부르므로(백팩이 가득이면 아예 안 부른다) 답례가 증발할 자리가 없다.
func claim(skill: String) -> Dictionary:
	if not ARTIFACTS.has(skill) or claimed.has(skill):
		return {}
	claimed.append(skill)
	changed.emit()
	return ARTIFACTS[skill]

func claimed_count() -> int:
	return claimed.size()

func is_complete() -> bool:
	for s in skills():
		if not claimed.has(String(s)):
			return false
	return true

# ── 세이브/로드(슬라이스 키 "mastery" — 조각 하나 · 하위호환) ──────────────────
# 키 없는 구세이브 = 수령 0(경지는 새 층이라 잃을 것이 없다 — 초과 XP는 이미 저장된 스킬 XP에서
# 다시 파생되므로 포인트도 그대로 되살아난다. **저장할 것이 수령 이력 하나뿐**인 이유가 이것이다).
func to_save() -> Dictionary:
	return {"claimed": claimed.duplicate()}

# 복원: **로스터에 있는 스킬 id만 받는다**(미지 id 드롭 — 옛 로스터의 id가 포인트를 갉아먹어
# "쓴 적 없는 점수가 사라진" 상태가 되는 사고 차단. FireflySouls.load_save와 같은 규율).
func load_save(data: Dictionary) -> void:
	claimed = []
	var raw: Variant = data.get("claimed", [])
	if typeof(raw) == TYPE_ARRAY:
		for s in raw:
			var sid := String(s)
			if ARTIFACTS.has(sid) and not claimed.has(sid):
				claimed.append(sid)
	changed.emit()
