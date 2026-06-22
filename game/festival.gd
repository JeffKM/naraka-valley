class_name Festival
extends RefCounted
# M2.4 — 카페 이벤트 데이(축제) 규칙의 단일 출처.
#
# 목적: ROADMAP M2.4 — 특정 날(2주마다) 카페가 축제 무대가 되는 자기완결 이벤트
#       (메인 플롯 비의존, ADR-0005). 그날 메인 4인(미호·멜·바나·옥자)의 의상이 바뀌고
#       카페 내부가 축제 장식으로 바뀌며, 가벼운 축제 보너스(손님이 더 붐빔)가 얹힌다.
#
# 설계 메모:
#   - store_discount.gd·cafe_margin.gd·foxfire.gd와 같은 결: 이 클래스는 *세이브 무상태
#     static 규칙*이다. "오늘이 이벤트 데이인가"는 GameClock.day에서 매번 파생되므로
#     직렬화할 상태가 없다(SaveManager·세이브 불변). 비주얼/보너스도 모두 day에서 파생.
#   - 달력·계절·요일 시스템이 아직 없으므로(기획 미정) 트리거는 day 숫자 한 축으로만 둔다
#     — 2주마다(CYCLE=14)면 day 14·28·42…가 이벤트 데이다. 캘린더가 생기면 이 한 곳만 교체.
#   - ★ 축제 보너스 = 손님이 더 붐빈다(스폰 간격 ×SPAWN_SCALE). 이것은 '활동 곱셈기'가
#     아니다(ADR-0008/0014 구분, store_discount와 평행): 서빙 *단가*(멜 마진 축)는 건드리지
#     않고 *손님 유입*만 키운다 — "축제라 사람이 카페로 몰린다"(ADR-0014 '마을=카페로 사람이
#     오는 배경')는 시간 한정 이벤트 보너스라 관계에서 파생되지 않는다(메인 독점 곱셈기
#     불침범). 매출은 플레이어가 더 많이 *서빙해야* 오르므로 base 메카닉이 더 도는 결이다.
#   - 비주얼(의상 틴트·머리 고깔·카페 장식)도 여기 상수로 모은다 — 캐릭터 노드와 main이
#     같은 출처를 보고 그린다(그레이박스 절차 도형, 새 에셋 0 — Phase 2 경계 준수).

const CYCLE := 14                          # 2주마다 — day 14·28·42…가 이벤트 데이
const SPAWN_SCALE := 0.5                    # 축제 보너스: 손님 스폰 간격 ×0.5(2배 붐빔)

# 축제 의상 틴트(노드 modulate에 곱) — 도색 스프라이트·그레이박스 양쪽에 한 줄로 먹는
# 금빛 화사함. 평소 Color.WHITE에서 이 값으로 바뀌어 "오늘 차려입었다"가 한눈에 읽힌다.
const TINT := Color(1.18, 1.02, 0.72)

# 카페 축제 장식·머리 고깔 색(그레이박스 절차 도형). 홍·황 번갈아 = 잔치 가랜드 톤.
const BANNER_A := Color(0.86, 0.20, 0.24)  # 홍
const BANNER_B := Color(0.92, 0.74, 0.30)  # 황
const RUG := Color(0.62, 0.16, 0.20, 0.55) # 무대 카펫(반투명 — 바닥 위 덧깔기)

# 오늘이 이벤트 데이인가. day는 1부터 시작(0/음수는 무효 — 손상 방어).
static func is_event_day(day: int) -> bool:
	return day > 0 and day % CYCLE == 0

# 손님 스폰 간격 배수(이벤트일 0.5=붐빔, 평소 1.0). cafe.gd가 이 값을 SPAWN_INTERVAL에 곱한다.
static func spawn_scale(day: int) -> float:
	return SPAWN_SCALE if is_event_day(day) else 1.0

# 캐릭터 머리 위 축제 고깔(홍 삼각 + 금빛 방울). 도색·그레이박스 공통 — 캐릭터 _draw가
# 스프라이트 위에도 덧그려 "축제 의상"을 명확히 한다. top_y = 머리 꼭대기 y(발치 원점 기준).
static func draw_hat(ci: CanvasItem, top_y: float) -> void:
	ci.draw_rect(Rect2(-3, top_y - 3, 6, 3), BANNER_A)   # 고깔 밑단(넓게)
	ci.draw_rect(Rect2(-2, top_y - 5, 4, 2), BANNER_A)   # 고깔 중단
	ci.draw_rect(Rect2(-1, top_y - 7, 2, 2), BANNER_B)   # 고깔 끝 금빛 방울
