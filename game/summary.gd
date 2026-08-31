extends RefCounted
class_name RunSummary
# T4.2 / T7.3 — 통합 슬라이스의 경계와 마무리 화면 텍스트.
#
# 목적: ROADMAP T4.2 — "처음부터 끝까지 한 번도 막히지 않고 플레이되고, 종료 시
#       마무리 화면이 뜬다"의 그 슬라이스 경계와 끝 화면 문구를 한 곳에서 정한다.
#       Phase 1.5 통합 슬라이스(농사·카페/멜·밤/바나 직조 + 카페 마일스톤)를 닫는
#       마지막 조각이다.
#
# ★ T7.3 — 21일 확장:
#   - 슬라이스 길이를 14→21일로 늘려 "카페 1단 완료 → 2단 갈망"의 호가 슬라이스 안에
#     들어오게 했다(마일스톤 T7.2가 21일 안에서 완주되고, 후반에 동기가 남게).
#
# ★[S7-T1 → 폴리시 2회차 정정] **이 상수는 더 이상 호감도 곡선의 앵커가 아니다.** 옛 머리말은
#   "RUN_DAYS 하나만 21↔14로 바꾸면 슬라이스 길이와 곡선이 함께 되돌아간다"(손절 사다리 ①)고
#   적었으나, 그 계약은 두 번에 걸쳐 소멸했다:
#     ㉠ S7-T1이 절기 달력을 열며 **런 종료 게이트를 폐지**했다(day 22에 게임이 끝나지 않는다).
#     ㉡ S8-T4 / ADR-0066 결정 1이 `affinity.gd:POINTS_PER_HEART`의 파생식을 끊고 명시 상수 60으로
#        박았다 — 지금 affinity.gd에는 RunSummary 참조가 **코드 줄에 한 글자도 없다**
#        (activity_test ①c가 소스를 읽어 그 사실을 단언한다).
#   그래서 이 값을 14로 되돌려도 관계 곡선은 따라오지 않는다. 거짓 계약을 머리말에 남겨 두면
#   다음 사람이 곡선을 모르고 흔들게 되므로 문장을 지운다.
# ★ 다만 **죽은 상수는 아니다** — 아래 `is_over`/`days_survived`/`text`는 `main._end_run`(S9 엔딩
#   자산으로 보존)과 `tools/ending_dump.gd`가 쓰고, `playtest/playtest_bot.gd`는 이 값을 **시뮬레이션
#   길이로 실제 사용**한다(RUN_DAYS일 루프). season_calendar_test ③·activity_test ①d가 보존을
#   명시 단언하므로 값 변경·삭제는 그 두 테스트를 먼저 거쳐야 한다.
#
# 설계 메모:
#   - crops.gd(CropCatalog)·foxfire.gd(Foxfire)·flavor.gd(SoulMemory)와 같은 결:
#     이건 세이브 상태가 아니라 "정적 참조 규칙·문구"다. 슬라이스의 끝남 여부는
#     이미 저장되는 GameClock.day에서 매번 파생되므로(22일째 아침이면 끝) 자체 상태가
#     없다 → 세이브할 게 없다(SaveManager·main 세이브 불변). 그래서 씬 노드가 아니라
#     static const + class_name으로 어디서든 RunSummary.is_over(day)로 읽는다.
#   - 끝 판정·점수판 조립만 여기서 하고, 화면에 언제·어떻게 띄울지(패널 표시·이동
#     잠금·시계 정지)는 main이 맡는다(데이터/표시 디커플링 — 다른 시스템과 동일).
#   - 마무리 화면은 메인 서사(미결의 죄·옥자 인연)도 캐릭터 속죄 서사도 아닌, 이번
#     슬라이스를 닫는 메타 점수판이다. 그래서 ADR-0005의 "서사는 캐릭터에"
#     경계를 건드리지 않게, 플롯이 아니라 "며칠 살아냈고 무엇을 모았나"라는 가벼운
#     마무리 톤만 담는다(메인 플롯 비의존 — 슬라이스가 독립 완성).
#   - 그레이박스 기준값(21일)이며 더 긴 시즌·달력 확장은 Phase 3 서랍(ROADMAP).

const RUN_DAYS := 21   # ★ 통합 슬라이스 분량(날 수) — 정산 화면과 봇 시뮬레이션 길이의 단일 진실원.
                       #   호감도 곡선은 여기서 파생되지 않는다(위 정정 참조).

# ── 슬라이스 경계 ────────────────────────────────────────────────────────────
# 슬라이스가 끝났는가. 취침으로 날이 넘어가 'RUN_DAYS+1일째 아침'(day > RUN_DAYS)이
# 되면 더 진행하지 않고 마무리 화면을 띄운다. 끝 상태가 day에서 파생되므로(저장되는
# 값) 별도의 finished 플래그가 필요 없다 — 이어받은 세이브가 이미 넘겼으면 시작 시
# 바로 마무리 화면이 뜬다(재현·재개 안전).
static func is_over(day: int) -> bool:
	return day > RUN_DAYS

# 실제로 살아낸 날 수(점수판 표시용). RUN_DAYS+1일째 아침이면 RUN_DAYS일을 살아낸 것.
# 진행 중에 불러도 안전하게 [0, RUN_DAYS]로 자른다.
static func days_survived(day: int) -> int:
	return clampi(day - 1, 0, RUN_DAYS)

# ── 마무리 화면 점수판 ───────────────────────────────────────────────────────
# 슬라이스를 닫는 점수판 한 장. 수치는 main이 각 시스템에서 모아 넘긴다(디커플링) —
# 며칠 살아냈는지·미호와 얼마나 가까워졌는지(하트 막대)·모은 골드·거둔 영혼(수확 총수).
static func text(day: int, gold: int, heart_bar: String, hearts: int, max_hearts: int, harvested: int) -> String:
	return "\n".join([
		"─────  %d일을 살아냈다  ─────" % days_survived(day),
		"",
		"저승 컨셉카페에서의 첫 %d일이 저물었다." % RUN_DAYS,
		"",
		"미호와의 사이   %s  (%d/%d)" % [heart_bar, hearts, max_hearts],
		"모은 골드       %d" % gold,
		"거둔 영혼       %d" % harvested,
		"",
		"[ 그레이박스 수직 슬라이스 · Phase 1 ]",
	])

# ── ★[S9b-T8 / ADR-0068 결정 11] 엔딩 에필로그 ──────────────────────────────
# 위 `text()`(옛 21일 런 정산)와 **성격이 정반대**인 화면이다: 저건 런이 끝났다는 통보였고 이건
# 척추가 닫힌 뒤의 **회고 한 장**이며, 닫으면 코지 샌드박스로 돌아간다(§6.4 "머무름은 선택").
# 그래서 `RUN_DAYS`도 `is_over`도 안 쓴다 — 이 화면은 날짜 게이트와 아무 관계가 없다(게이트 부활
# 금지). 여기 남는 것은 "며칠을 살았고 무엇을 되찾았나"뿐이다.
#
# ★ **하트 막대가 이 문자열에 없다.** 관계는 스프라이트 하트 행이 따로 진다(main `_build_epilogue_hearts`
#   — HeartBar 재사용). neodgm.ttf에 ♥ 글리프가 없어 문자열 막대가 두부(□)로 뜨던 S8-T10 이월의
#   소화이고, 그래서 이 함수는 `heart_bar` 인자를 아예 안 받는다.
static func epilogue_text(day: int, gold: int, harvested: int,
		donated: int, donatable: int, spouse_name: String) -> String:
	var rows := [
		"─────  머무름은 이제 선택이다  ─────",
		"",
		"살아낸 날      %d일" % maxi(day - 1, 0),
		"모은 냥        %d" % gold,
		"거둔 영혼      %d" % harvested,
		"되찾아 세운 것  %d / %d" % [donated, donatable],
	]
	rows.append("곁에 있는 이    %s" % (spouse_name if spouse_name != "" else "— (혼자 걷는 길)"))
	rows.append("")
	return "\n".join(rows)
