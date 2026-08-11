extends RefCounted
class_name Deed
# ★[S8-T5 / ADR-0066 결정 5] 단계 관문의 **deed 문턱 순수 판정** — "그 사람의 도메인에서
# 무엇을 이뤘는가"가 하트 진급의 AND 조건이 된다(메인 3인 한정 — ADR-0032 §1).
#
# 설계 메모:
#   - **순수 static 판정이다.** 기존 원장(수확·매출·갱도·전투)을 *읽기만* 하고, 신규 원장을
#     하나도 만들지 않는다 — 원장의 주인은 여전히 main이고, 여기는 문턱표와 비교식뿐이다
#     (CafeMilestone·XpBoost와 같은 결: 데이터는 인자로 받고 상태를 안 든다).
#   - **서브 주민은 무조건 통과다**(ADR-0066 결정 5 ④ "이벤트만 — deed 0"). 관계에 성과를
#     요구하지 않는 "쉼터" 결(서사 바이블 §6.1)을 문턱표에 이름이 없는 것으로 지킨다 —
#     명단을 두면 주민이 늘 때마다 여기를 고쳐야 한다.
#   - ♡5(연애 개시) 문턱은 여기 없다 — 그건 deed가 아니라 **의지 시험**(ADR-0066 결정 6,
#     S8-T6 소관)이다. target 5는 메인 3인도 deed 없이 통과한다(시험이 별도 관문).
#   - **수치는 전부 잠정**(ADR-0066 결정 5 명시)이다 — 밸런싱 레버는 이 상수표 하나뿐이라
#     조정이 한 파일 안에서 끝난다.
#
# 원장 키(main._deed_ledgers()가 조립해 넘긴다 — 이름은 main 필드·세이브 키와 같은 규약):
#   run_harvested / cafe_revenue_total / mine_depth / combat_xp / narak_key_found / narak_best_boss

# 미호 = 누적 수확(영혼을 거둔 손 — 방화의 힘을 양육으로 뒤집는 속죄 축과 같은 결. ADR-0004).
const MIHO_HARVEST := [30, 80, 160, 300]        # ♡1..♡4 문턱(누적 수확 수)
# 멜 = 누적 서빙 매출(카페의 돈줄 — 도박·사채의 힘을 운영으로 뒤집는 축. ADR-0007).
const MEL_REVENUE := [500, 1500, 3500, 7000]    # ♡1..♡4 문턱(누적 서빙 매출 냥)
# 바나 = 밤·전투의 축인데 **단일 수치가 아니라 진척 축 4종**이다(갱도→전투→나락 개방→보스) —
# "S8 바나 도메인이 읽을 진척 축" 예약 주석(narak_best_boss)의 이행.
const BANA_MINE_DEPTH := 10       # ♡1: 업화 갱도 10층 도달
const BANA_COMBAT_XP := 200      # ♡2: 전투 숙련 XP 200
const BANA_BEST_BOSS := 10       # ♡4: 나락 최고 격파 깊이 ≥10(첫 보스 격파)

# 그 사람의 target_heart(1..MAX) 진급에 필요한 deed를 채웠는가. 문턱표에 없는 rid는 항상 true.
static func check(rid: String, target_heart: int, ledgers: Dictionary) -> bool:
	if target_heart < 1:
		return false          # 0칸으로의 "진급"은 존재하지 않는다(방어)
	if target_heart > 4:
		return true           # ♡5 = 의지 시험 소관(deed 아님 — S8-T6)
	match rid:
		"miho":
			return int(ledgers.get("run_harvested", 0)) >= int(MIHO_HARVEST[target_heart - 1])
		"mel":
			return int(ledgers.get("cafe_revenue_total", 0)) >= int(MEL_REVENUE[target_heart - 1])
		"bana":
			match target_heart:
				1: return int(ledgers.get("mine_depth", 0)) >= BANA_MINE_DEPTH
				2: return int(ledgers.get("combat_xp", 0)) >= BANA_COMBAT_XP
				3: return bool(ledgers.get("narak_key_found", false))
				_: return int(ledgers.get("narak_best_boss", 0)) >= BANA_BEST_BOSS
	return true               # 서브 주민 = 이벤트만(deed 0 — 쉼터)
