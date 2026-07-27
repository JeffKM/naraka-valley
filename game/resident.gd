extends RefCounted
class_name Resident
# ★ [S2-T7 / ADR-0060 결정 7] 주민 1인의 **등록 레코드** — 주민 프레임워크의 데이터 축.
#
# 목적: NPC 1인을 늘릴 때 main.gd 15곳을 고치던 하드배선을 없앤다. 이제 1인 추가 =
#       ㉠ 개별 캐릭터 파일 1개(대사·몸 그리기 — miho.gd 결) + ㉡ 여기 레코드 1건 등록
#       (main `_setup_residents`)이 전부다. facing 판정·컨텍스트 팝업·프롬프트·입력 분기
#       (우클릭 대화·G 선물·F 훅)·대화 묶음·선물·스테이션 스케줄·초상화·세이브가 전부
#       이 레코드 한 장에서 파생된다.
#
# 설계 메모:
#   - 이 클래스는 **순수 데이터 + 조회**다. 노드를 만들지도, 그리지도, 게임 상태를 바꾸지도
#     않는다(affinity.gd가 "수치"만 들고 트리거·HUD를 main에 맡기는 것과 같은 결). 실제
#     배치·입력·세이브 조율은 main이 이 레코드를 훑으며 한다.
#   - **과일반화 금지**(ADR-0060 결정 7): 캐릭터마다 진짜로 다른 특수 거동(옥자 통보 단계·
#     네오 매대·바나 밤 경비 옵트인)은 전부 일반 필드로 욱여넣지 않고 *Callable 훅*으로
#     뺐다(`station_gate`·`visible_rule`·`shop_key`·`prompt_extra`·`facing_gate`). 프레임워크는
#     "언제 부를지"만 알고 "무엇을 하는지"는 모른다 — 특수 로직을 뒤틀지 않기 위한 이음매다.
#   - ★ [ADR-0060 결정 8] 점주 겸직 규칙: 점주 레이어(`shop_key` — 매대·할인)와 관계 트랙
#     레이어(`affinity` — 대화·선물·하트)는 **이 레코드 안에서도 서로 독립 필드**다. 어느 쪽도
#     상대를 게이팅하지 않는다 — 할인이 늘어도 하트 이벤트가 열리지 않고, ♡0이어도 매대는
#     정상 동작한다(네오 선례를 규칙으로 승격). T1이 가게를 가져도 이 두 필드를 같이 채울 뿐이다.

# ── 정체성 ────────────────────────────────────────────────────────────────
var id := ""                   # 코드·세이브용 영문 id(예: "miho"). 레지스트리 조회 키.
var display_name := ""         # 대화창·팝업에 뜨는 이름. 캐릭터 노드 display_name()과 일치시킨다.
var node: Node2D = null        # 몸(miho.gd 등). 위치·가시성·walk_offset을 프레임워크가 다룬다.
# ★ 노드를 레코드가 직접 낳는 옵션 — **main.tscn을 안 고치고** 주민을 늘리기 위한 이음매다.
#   node를 비운 채 script_path를 채우면 `_register_resident`가 그 스크립트로 몸을 만들어 붙이고,
#   needs_affinity면 관계 트랙(Affinity) 노드도 함께 만들어 물린다. 기존 5인은 이미 main.tscn에
#   노드가 있어 이 경로를 안 탄다(거동 불변) — 신규 주민만 이 길로 온다.
var script_path := ""
var needs_affinity := false

# ── 관계 트랙(없으면 null — 옥자처럼 호감도 없는 서사 앵커) ────────────────
var affinity: Affinity = null
var save_key := ""             # 세이브 딕셔너리 키. ★하위호환: 기존 키를 그대로 쓴다
                               #   (미호="affinity" · 멜="mel_affinity" · …). 절대 개명 금지.
var rel_text := ""             # affinity가 null일 때 컨텍스트 팝업에 띄울 관계 한 줄.
var can_gift := false          # G 선물 채널을 받는가(네오·옥자는 false — 풀 T1 트랙은 후속).
# 선물 알림 문구의 이름 조각. "" = 이름 없이("… 선물 +N 호감도"), 아니면 "멜에게 …" 꼴.
# ★ 미호만 이름이 빠진 건 T3.3 원문 그대로다(멜·바나는 T5.2/T6.2에서 이름을 붙였다) —
#   거동 불변이 최우선이라 문구 통일은 하지 않고 데이터로 보존한다.
var gift_target_ko := ""
# 관계 탭(메뉴) 하트 행의 "곱셈기 효과" 한 줄을 돌려주는 훅(미호=여우불 · 멜=마진 · 바나=경비 ·
# 네오=할인). ★ADR-0008 "곱셈기는 캐릭터마다 *종류*가 다르다"가 여기 훅으로 드러난다 — 프레임워크는
# 효과가 무엇인지 모르고 한 줄 문자열만 받는다. 유효하지 않으면 그 주민은 관계 탭에 안 뜬다.
var effect_fn := Callable()

# ── 초상화 ────────────────────────────────────────────────────────────────
# 대화창·컨텍스트 팝업 초상화 파일 stem(assets/portraits/<stem>.png · 표정은 <stem>_<expr>.png).
# ""면 초상화 없음(네오 — 팝업은 이름만, ADR-0003 "표정=별도 일러스트 초상화"의 미제작분).
var portrait_stem := ""

# ── 대화 ──────────────────────────────────────────────────────────────────
# 대사 묶음은 캐릭터가 든다(ADR-0005). 프레임워크는 "어떤 시그니처로 부를지"만 안다:
#   · plain_talk=false → node.lines(hearts, first_today)  (미호·멜·바나·네오)
#   · plain_talk=true  → node.lines_resident()            (옥자 — 호감도·일일 게이팅 없는 일상)
var plain_talk := false

# ── 상호작용 판정(facing) ─────────────────────────────────────────────────
var require_indoor := ""       # ""=검사 안 함. 값이 있으면 그 실내에서만 말 걸 수 있다(네오="만물상").
var require_visible := false   # true면 node.visible일 때만(옥자·바나 — 시간·단계로 나타났다 사라진다).
var facing_gate := Callable()  # 추가 게이트(옥자 = 통보를 지났는가). 유효하지 않으면 통과.

# ── 스테이션(시간대별 자리) ───────────────────────────────────────────────
# schedule = [{"from_min": int, "tile": Vector2i, "region": String}, …] — from_min 오름차순.
# 현재 시각(분) 이하인 마지막 항목이 지금 자리다. region이 ""면 가시성을 구역으로 가르지
# 않는다(카페·만물상 방처럼 카메라로 격리된 자리 — 멜·네오는 애초에 visible을 안 건드린다).
var schedule: Array = []
var station_gate := Callable() # false면 스테이션 갱신 자체를 건너뛴다 — ★특수 훅: 옥자는 통보
                               #   단계 동안 배치를 통보 흐름이 소유하므로 프레임워크가 손대지 않는다.
var visible_rule := Callable() # 유효하면 가시성을 이 훅이 결정한다(바나 밤 창·옥자 상주).
                               #   없으면 스케줄 region 규칙, region도 ""면 가시성 미터치.

# ── 프롬프트·입력 훅 ──────────────────────────────────────────────────────
var prompt_extra := Callable() # 하단 프롬프트 꼬리 한 조각을 돌려준다(바나 = 바 열기/영업 중).
var shop_key := Callable()     # [F] 키 훅(네오 = 매대 프레임 · 바나 = 나라카 바 옵트인).
                               # ★결정 8: 이 필드는 affinity와 완전히 독립이다(상호 게이팅 없음).

# ── 런타임 상태(프레임워크가 갱신 — 세이브 안 함, 시각·단계에서 매번 파생) ──
const UNPLACED := Vector2i(-9999, -9999)
var tile: Vector2i = UNPLACED  # 지금 서 있는 칸(논리 위치 — facing 판정·테스트가 보는 값).
var tile_region := ""          # 그 칸이 속한 구역(스케줄에서 파생). 걷기가 "같은 구역인가"를 볼 때 쓴다.
var walk: ResidentWalk = null  # 보간 걷기(시각 전용). null이면 이 주민은 걷기 연출을 안 쓴다.

# 현재 시각(분)에 해당하는 스케줄 항목. 스케줄이 비면 빈 딕셔너리.
func station_at(minutes: int) -> Dictionary:
	var picked := {}
	for e in schedule:
		if minutes >= int(e.get("from_min", 0)):
			picked = e
	# 첫 항목보다 이른 시각이면(from_min이 0이 아닌 스케줄) 마지막 항목으로 감싼다 —
	# 하루는 순환하므로 자정 전 자리가 새벽까지 이어지는 게 자연스럽다.
	if picked.is_empty() and not schedule.is_empty():
		picked = schedule[schedule.size() - 1]
	return picked

# 지금 자리의 칸(스케줄이 비면 UNPLACED).
func station_tile(minutes: int) -> Vector2i:
	var e := station_at(minutes)
	return e.get("tile", UNPLACED)

# 지금 자리가 속한 구역 id("" = 구역으로 가시성을 가르지 않음).
func station_region(minutes: int) -> String:
	return String(station_at(minutes).get("region", ""))

# 하트 단계(관계 트랙 없는 주민은 0).
func hearts() -> int:
	return affinity.hearts() if affinity != null else 0
