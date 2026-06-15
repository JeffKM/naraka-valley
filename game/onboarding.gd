extends Node
class_name Onboarding
# T4.1 — 온보딩 흐름 단계 머신(도착 → 옥자 통보 → 미호 멘토 → 튜토리얼 → 첫 수확).
#
# 목적: "신규 시작 시 도착부터 첫 수확까지 안내가 끊김 없이 이어진다"를 회색 UI만으로
#       검증한다(ADR-0001 그레이박스, CONTEXT '온보딩').
#
# 설계 메모:
#   - affinity.gd·energy.gd와 같은 결: 이 노드는 "지금 온보딩 어느 단계인가"라는
#     단일 책임만 가진다. 옥자 컷신 트리거·미호 대화·밭 동작·안내 배너 표시는
#     main이 맡고, 여기서는 단계 상태와 changed 시그널·안내 문구만 제공한다.
#   - 단계는 밭의 강제 순서(괭이질 → 심기 → 물주기 → 성장 → 수확, field.next_action)에
#     자연히 매핑된다. 그래서 각 사건(on_X)은 "지금 그 단계일 때만" 다음으로 넘기면
#     되고(순서·멱등 안전 — 같은 동작을 두 번 해도, 다른 칸을 먼저 갈아도 흔들리지
#     않는다), 플레이어 행동을 막지 않고 안내만 따라간다("끊김 없이 이어진다").
#   - 서사 텍스트(옥자 통보 대사)는 캐릭터(okja.gd)가 든다(ADR-0005). 여기의 안내
#     문구는 서사가 아니라 조작 가이드라 단계 머신이 들고 있어도 경계를 어기지 않는다.
#   - T2.5 세이브/로드 — 단계 하나(정수)만 직렬화한다. 보존하므로 튜토리얼이 재생되지
#     않고(완료 후), 중도에 끄면 그 단계부터 재개된다. 복원 시 [NOTICE, DONE]로 자른다.

signal changed(step: int)  # 단계가 바뀐 프레임(미래 훅; 현재 main은 _process로 폴링)

# 단계(밭 강제 순서에 매핑). 익명 enum이라 Onboarding.NOTICE처럼 클래스 상수로 쓴다.
enum { NOTICE, MEET_MIHO, TILL, PLANT, WATER, GROW, HARVEST, DONE }

var step: int = NOTICE

# ── 조회 ──────────────────────────────────────────────────────────────────
# 온보딩이 아직 진행 중인가(DONE 전). main이 배너 표시·옥자 컷신 판정에 쓴다.
func is_active() -> bool:
	return step < DONE

# 지금이 옥자 통보(오프닝 컷신) 단계인가. main이 신규 시작·NOTICE 복원 시 자동으로
# 옥자 대화를 띄울지 판정한다(CONTEXT '온보딩': 옥자는 오프닝에 잠깐 등장).
func is_intro() -> bool:
	return step == NOTICE

# 현재 단계의 안내 배너 문구("" = 배너 숨김). NOTICE는 옥자 대화가 화면을 채우고,
# DONE은 온보딩이 끝나 배너가 사라진다. 그 사이 단계만 조작 가이드를 보여준다.
func guidance() -> String:
	match step:
		MEET_MIHO:
			return "▶ 밭(위쪽)으로 올라가 미호에게 [E]로 말을 걸어라"
		TILL:
			return "▶ 밭 흙을 바라보고 [E]로 괭이질하라"
		PLANT:
			return "▶ 경작한 칸에 [E]로 혼령초 씨앗을 심어라"
		WATER:
			return "▶ 심은 칸에 [E]로 물을 주어라"
		GROW:
			return "▶ 집(왼쪽)에서 [Enter]로 잠들어 작물을 키워라 (마르면 다시 물 주기)"
		HARVEST:
			return "▶ 다 자란(황금) 작물을 [E]로 수확하라"
	return ""

# ── 단계 전진 ──────────────────────────────────────────────────────────────
# 각 사건은 "지금 그 단계일 때만" 다음으로 넘긴다(순서·멱등 안전). 잘못된 단계에서
# 들어온 호출은 조용히 무시된다 — 다른 칸을 먼저 갈거나 같은 동작을 반복해도 안전.
func _advance_from(expected: int) -> void:
	if step == expected:
		step += 1
		changed.emit(step)

func notice_seen() -> void:    # 옥자 통보 대화를 끝까지 봤다
	_advance_from(NOTICE)

func talked_to_miho() -> void: # 미호에게 말을 걸어 멘토 대화를 끝냈다
	_advance_from(MEET_MIHO)

func tilled() -> void:         # 흙을 갈았다(괭이질)
	_advance_from(TILL)

func planted() -> void:        # 씨앗을 심었다
	_advance_from(PLANT)

func watered() -> void:        # 물을 줬다
	_advance_from(WATER)

func crop_ready() -> void:     # 물 준 작물이 다 자라 수확 가능해졌다(취침으로 하루 경과)
	_advance_from(GROW)

func harvested() -> void:      # 첫 수확을 했다 → 온보딩 완료(DONE)
	_advance_from(HARVEST)

# ── T2.5 세이브/로드 ──────────────────────────────────────────────────────
# 단계 하나만 직렬화한다. 복원 시 [NOTICE, DONE]로 잘라 손상 세이브에 방어한다.
func to_save() -> Dictionary:
	return {"step": step}

func load_save(data: Dictionary) -> void:
	step = clampi(int(data.get("step", NOTICE)), NOTICE, DONE)
	changed.emit(step)
