extends RefCounted
class_name SalvageTable
# ★[S3-T6 / ADR-0061 결정 6 "보물잡이 표적 재해석"] 인양물 동반 롤 — 순수 결정적 테이블.
#
# 왜 있나(문서 충돌 해소): 카탈로그 §1-D는 "보물상자 확률"을 릴 격투에서 **제외**했다(격투 중 난입이
#   어색). 그런데 ADR-0052 보물잡이(Pirate) 퍼크는 "낚시 보물 2배"라 표적이 공중에 떠 있었다.
#   ADR-0061 결정 6이 이를 **포획 성공 시 저확률 동반 인양 롤**로 재조준했다 — 격투에 *난입하지 않고*
#   (LANDED 이후 1회 롤·팝업 1줄), 잡동사니/재료 위주 + 유품 극저확률(혼백관 기증 소스와 연결).
#   그래서 제외 취지(난입 어색)와 퍼크 존치가 양립한다.
#
# 설계 메모:
#   - **순수 static·무상태**(Museum.relic_roll 선례 동형). 씬 노드도 세이브 상태도 아니다.
#   - **결정적**: 같은 시드 = 같은 결과(전역 randf 금지 — 헤드리스 재현의 전제). main은 캐스팅 시드에서
#     갈라 넘긴다(어종 롤·품질 롤과 다른 가지).
#   - **보물잡이 = 확률 2배의 정직한 구현**: 게이트가 `해시 mod 1000 < permil`이라 permil을 2배로
#     올리면 통과 집합이 **기존 집합의 초집합**이다(원래 나오던 인양물이 사라지지 않고 늘기만 한다).
#   - **신규 아이템 최소**(ADR-0001 큐레이션): 인양 테이블은 기존 재료(혼백 섬유·석화 목재·업화석
#     조각)와 기존 유품 3종을 재사용하고, **신설은 「삭은 그물」 1종뿐**이다(잡동사니 — 낚시엔 잡동사니가
#     있어야 인양이 인양답다. ★S3-T7 게잡이통 잡동사니 표적으로도 그대로 재사용된다 = 1종이 2군데 봉사).
#     그 id·이름·가격의 단일 출처는 **ItemCatalog.MATERIALS**다(여긴 분포만 든다 — 데이터 중복 0).
#   - **물고기는 인양물이 아니다**: 어획물은 격투의 산물이고, 인양물은 그 곁다리다(축 분리).

# ── 기본 확률(퍼밀 — 0..1000 해시 대비) ─────────────────────────────────────
# 30 = 3%(잠정). Museum.DIG_ROLL_PERMIL(괭이질 유품 발굴)과 같은 눈금·같은 체감으로 잡았다 —
# "가끔 딸려 온다"가 목표지, 인양이 낚시의 주 수입이 되면 안 된다(어획물이 주인공).
const BASE_PERMIL := 30
# 보물잡이(Pirate, lvl10) — ADR-0052 "2배". 6%.
const PIRATE_MULT := 2

# ── 인양 테이블(가중 합 = 1000) ─────────────────────────────────────────────
# 읽는 법: 인양 롤에 *걸린 뒤* 무엇이 나오는가의 분포. 잡동사니 45% · 재료 53% · 유품 2%.
#   → 유품 실확률 = 3% × 2% = **0.06%/포획**(보물잡이면 0.12%). "극저확률"(결정 6)의 실값이다.
#     낚시가 유품의 *보조* 소스가 되되(혼백관 기증 진행이 괭이질 하나에 묶이지 않게), 괭이질
#     발굴(3%)을 대체하지는 않는 세기다.
# ★ 정적 const 배열 대신 static func인 이유: 항목 id의 단일 출처가 ItemCatalog이고(데이터 중복 0),
#   const 초기화식에서 타 클래스 상수를 참조하는 건 이 코드베이스가 피하는 형태다(gear_catalog의
#   체급 눈금 복제 주석 참조). 호출 비용은 무시할 수준이고, 대신 id가 어긋날 여지가 0이 된다.
static func table() -> Array:
	return [
		{"id": ItemCatalog.ROTTEN_NET, "weight": 450},        # 잡동사니 — 팔면 푼돈(5G)
		{"id": ItemCatalog.SOUL_FIBER, "weight": 250},        # 혼백 섬유 — 개간 드랍과 같은 재료
		{"id": ItemCatalog.PETRIFIED_WOOD, "weight": 200},    # 석화 목재 — 물에 잠긴 고목(유목 결)
		{"id": ItemCatalog.EMBER_SHARD, "weight": 80},        # 업화석 조각 — 가장 귀한 일반 인양물
		{"id": ItemCatalog.RELIC_BINYEO, "weight": 7},        # 유품 — 혼백관 기증 소스(극저확률)
		{"id": ItemCatalog.RELIC_SPOON, "weight": 7},
		{"id": ItemCatalog.RELIC_KKOTSIN, "weight": 6},
	]

# ── 해시(결정적 혼합) ───────────────────────────────────────────────────────
# 캐스팅 시드는 연속값(day·타일·분·일련번호의 선형 합)이라 단순 XOR+mod는 편향이 남는다. 곱셈·시프트
# 혼합으로 하위 비트까지 흩어 3%가 실제로 3%가 되게 한다(fishing_skill_test ⓔ가 경험 빈도를 검증).
static func _mix(v: int, salt: int) -> int:
	var h := (v ^ salt) * 2654435761
	h = (h ^ (h >> 13)) * 1274126177
	return h ^ (h >> 16)

# ── 롤(이 파일의 주 API) ────────────────────────────────────────────────────
# 이번 포획에 인양물이 딸려 왔나. 걸리면 아이템 id, 아니면 ""(대부분). permil ≤ 0이면 항상 "".
static func roll(seed_value: int, permil: int = BASE_PERMIL) -> String:
	if permil <= 0:
		return ""
	if int(posmod(_mix(seed_value, 0x5bd1e995), 1000)) >= permil:
		return ""
	var t := table()
	var total := 0
	for e in t:
		total += int(e["weight"])
	var pick := int(posmod(_mix(seed_value, 0x27d4eb2f), total))
	var acc := 0
	for e in t:
		acc += int(e["weight"])
		if pick < acc:
			return String(e["id"])
	return String(t[t.size() - 1]["id"])   # 부동/잔차 방어(도달 불가)

# 보물잡이 퍼크 반영 확률(퍼밀). doubled = 보물잡이 보유(ADR-0052 "인양 2배").
static func permil_for(doubled: bool) -> int:
	return BASE_PERMIL * (PIRATE_MULT if doubled else 1)

# 이 id가 유품 인양분인가(안내 문구·테스트 편의).
static func is_relic(id: String) -> bool:
	return ItemCatalog.category_of(id) == ItemCatalog.CAT_RELIC
