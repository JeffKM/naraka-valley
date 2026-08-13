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

# ── ★[S8-T3 / ADR-0066 결정 3] 생일 달력 — 관계 트랙 보유 9인의 단일 출처 ──
# 값 = [절기 인덱스(0 피안·1 유화·2 망연·3 성야), 절기 내 일차(1..28)].
#
# ★ **static 테이블인 이유**: 소비자가 인스턴스 밖에도 있다 — 달력 패널(CalendarPanel)은 무상태
#   조회자라 레지스트리를 모르고 GameClock·Festival·SeasonalEvent를 static으로 읽는다. 생일만
#   인스턴스 필드로 두면 그 패널이 main을 거쳐야 하고, 진실원이 "레코드"와 "달력"으로 갈린다.
#   그래서 레코드·달력·선물 경로가 전부 이 dict 하나를 읽는다.
# ★ **회피일**(달력 충돌 0): 각 절기 25일(테마 데이 고정 슬롯 — Festival.DAY_OF_SEASON)과 절기
#   행사일(SeasonalEvent.DAY_OF_SEASON = 피안12·유화20·망연16·성야15). 28일 중 26일이 비어 있어
#   9인을 흩어 놓아도 남는다. gift_test가 이 무충돌을 전수로 다시 단언한다(테이블이 바뀌어도 잡힌다).
# ★ **전부 잠정**이다 — 실제 인물 생일 차용은 owner 협의 큐(ADR-0066 Consequences). 배치 근거는
#   각 줄 주석의 캐릭터 결이고, 바꿀 땐 이 dict 한 줄만 고치면 달력·선물·대사가 함께 따라온다.
const BIRTHDAYS := {
	# 피안절(봄결) — 물이 풀리고 새순이 나는 절기.
	"ongi": [0, 4],       # 옹이 = 목령. 나무가 그해 첫 나이테를 두르는 무렵(가장 이른 봄자리)
	"boatman": [0, 11],   # 뱃사공 = 물길의 사공. 언 물이 풀려 배가 다시 뜨는 무렵
	"neo": [0, 19],       # 네오 = 태엽 인형. 멈췄던 것이 다시 감기는 절기(시작의 결)
	"ken": [0, 23],       # ★[S9b-T1] 켄 = 언데드 거인. 어린 싹이 다 올라오는 늦봄 —
	                      #   겨울처럼 생긴 자가 봄에 난다는 거울이 곧 "무서운 겉 ↔ 솜사탕 속"
	                      #   ([residents.md] 반전 축). 회피일(25일·피안 행사 12일)과 기존
	                      #   피안절 배정(4·11·19)을 전부 비껴간다.
	# 유화절(여름결) — 불볕과 결실의 절기.
	"miho": [1, 7],       # 미호 = 여우불. 불의 성질이 가장 센 절기, 그걸 양육으로 뒤집는 자리(ADR-0004)
	"kkaebi": [1, 13],    # ★S9b-T1 깨비 = 도깨비. 도깨비가 가장 자주 난다는 **한여름 밤**(밤이 짧아 다들 밖에 있는 절기)
	"luca": [1, 15],      # ★[S9b-T3] 루카 = 늑대인간. 28일 절기의 한복판 15일 = **보름** —
	                      #   자기를 묶어 두는 그 하루가 곧 생일이라는 어긋남이 캐릭터다
	                      #   ([narrative-bible §5.2] "보름달 본능 억누르기"). 유화절인 이유는
	                      #   여름 달이 낮게 떠 가장 크게 보이기 때문. 회피일(25일·유화 행사 20일)과
	                      #   기존 유화절 배정(미호 7·깨비 13·모찌 26)을 전부 비껴간다.
	"mir": [1, 17],       # ★[S9b-T3] 미르 = 이무기. 이무기가 승천을 노리는 때는 **한여름 폭우**다
	                      #   (용오름 설화) — 불볕과 소나기의 절기가 그대로 날짜가 된다. 17일 =
	                      #   절기 후반(소나기가 가장 잦은 무렵). 회피일(25일·유화 행사 20일)과
	                      #   기존 유화절 배정(미호 7·깨비 13·모찌 26)을 전부 비껴간다.
	"mochi": [1, 26],     # 모찌 = 카페 과일에서 난 존재. 과일이 가장 단 늦여름
	# 망연절(가을결) — 거두고 셈하는 절기.
	"mel": [2, 8],        # 멜 = 카페의 돈줄. 한 해를 셈하는 절기의 초입(장부의 계절)
	"scarlet": [2, 12],   # ★[S9b-T2] 스칼렛 = 메두사·옛 간판 타짜. 망연절은 **거두고 셈하는**
	                      #   절기 — 판이 끝나고 셈이 시작되는 자리가 곧 타짜의 결이고, 생일을
	                      #   "한 해치가 또 얹히는 셈"으로 싫어하는 인물에 맞는다. 12일 = 절기
	                      #   한복판(셈이 가장 바쁜 때). 회피일(25일·망연 행사 16일)과 기존 망연절
	                      #   배정(멜 8·무골 21)을 전부 비껴간다.
	"mugol": [2, 21],     # 무골 = 백골 무사. 살이 스러지고 뼈만 남는 결의 늦가을
	# 성야절(겨울결) — 밤이 가장 긴 절기.
	"pulmu": [3, 6],      # 풀무 = 도깨비 대장장이. 화덕 불이 가장 반가워지는 초겨울
	"seolhwa": [3, 14],   # ★[S9b-T2] 설화 = 설녀. 밤이 가장 깊은 절기의 **한복판**(28일의 절반) —
	                      #   "태어난 날이라기보다 내가 제일 나다운 날"이라는 자기 규정이 그대로
	                      #   날짜가 된다([narrative-bible §5.3]). 회피일(25일·성야 행사 15일)과
	                      #   기존 성야절 배정(풀무 6·바나 27)을 전부 비껴간다.
	"bana": [3, 27],      # 바나 = 밤의 경비. 밤이 가장 긴 한겨울 끝자락
}

# 그 사람의 생일([절기, 일차] — 없으면 빈 배열).
static func birthday_of(rid: String) -> Array:
	return Array(BIRTHDAYS.get(rid, []))

# 그 날이 그 사람의 생일인가. day는 절대 날짜(1부터) — 절기·일차로 풀어 비교한다(해마다 돌아온다).
static func is_birthday(rid: String, day: int) -> bool:
	var b := birthday_of(rid)
	if b.size() != 2 or day < 1:
		return false
	return GameClock.season_index_for_day(day) == int(b[0]) \
		and GameClock.day_of_season(day) == int(b[1])

# 그 날이 생일인 주민 id("" = 없음). 달력 마커·대사 훅이 쓰는 역방향 조회.
# ★ 하루에 두 명을 두지 않았으므로 첫 매치 하나면 된다(무충돌은 테스트가 지킨다).
static func birthday_on_day(day: int) -> String:
	if day < 1:
		return ""
	for rid in BIRTHDAYS:
		if is_birthday(String(rid), day):
			return String(rid)
	return ""

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

# ★ [S3-T5 / ADR-0061 결정 4] 대화 시작 **직전 1회** 불리는 훅 — 이 대화에 *앞세울* 대사 줄들
# (PackedStringArray)을 돌려준다. 빈 배열이면 아무 일도 없다(유효하지 않은 Callable도 동일).
# 용도 = "첫 대화 이벤트": 뱃사공의 T1 낚싯대 증정이 여기 붙는다 — 훅이 지급·1회 플래그까지
# 수행하고 증정 대사를 돌려주면, 프레임워크는 그 줄들을 평소 묶음 앞에 붙여 한 대화로 이어 준다.
# ★과일반화 금지 규약 그대로: 프레임워크는 "언제 부를지"만 알고 "무엇을 주는지"는 모른다.
var talk_intro := Callable()

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

# ★[S8-T3] 오늘이 이 사람의 생일인가(레코드에서 바로 묻는 편의 창구 — 판정은 static 테이블 소관).
func is_birthday_on(day: int) -> bool:
	return is_birthday(id, day)
