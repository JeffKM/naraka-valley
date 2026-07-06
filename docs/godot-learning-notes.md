# Godot 학습 노트 — T1.1 길잡이

> **목적:** ROADMAP `T1.1 — Godot 설치 + 첫 튜토리얼 완주`를 빠르고 확실하게 끝내기 위한 길잡이.
> **완료기준(ROADMAP):** 공식 입문 튜토리얼 게임이 실행되고, **노드·시그널·`_process`의 역할을 본인 말로 설명**할 수 있다.
> **제약:** 에셋 제작 금지(ADR-0001), 학습용 코드만. Godot/GDScript이므로 웹 규칙(`.claude/rules/`)은 적용 안 함(ADR-0002).

---

## 0. 환경 (이미 완료됨)

- Godot **4.6.3 stable** 설치됨 (`/Applications/Godot.app`, brew cask `godot`).
- 터미널에서 `godot --version` → `4.6.3.stable...` 확인 가능.
- 별도 설치 작업 불필요. 바로 튜토리얼로 진입한다.

---

## 1. 공식 튜토리얼: "Your first 2D game" (Dodge the Creeps)

Godot 공식 입문 튜토리얼. 떨어지는 적을 피하는 2D 미니게임을 처음부터 만든다.
**입문에 가장 권장되는 코스이며, 노드·시그널·`_process`가 전부 등장**한다.

- 공식 문서: https://docs.godotengine.org/en/stable/getting_started/first_2d_game/index.html
- 분량: 집중하면 2~4시간. 하루 안에 완주 가능.
- ⚠️ 튜토리얼은 자체 에셋(아트/사운드)을 다운로드해 쓴다. 이건 **학습 목적의 튜토리얼 에셋**이라 ADR-0001(우리 게임 에셋 제작 금지)과 무관하다. Dear My Naraka 본체에 그 에셋을 가져다 쓰지만 않으면 된다.

### 단계별 체크리스트

- [ ] 0. 프로젝트 생성 + 튜토리얼 에셋(art/) 임포트, 320×180 무관하게 일단 기본값
- [ ] 1. **Player** 씬 만들기 — `Area2D` 루트 + `AnimatedSprite2D` + `CollisionShape2D`
- [ ] 2. Player에 `_process`로 키 입력→이동 코드 작성 (이동 벡터 정규화 포함)
- [ ] 3. Player의 `body_entered` **시그널**을 코드에 연결 (적과 충돌 감지)
- [ ] 4. **Mob**(적) 씬 만들기 — `RigidBody2D` 기반, 화면 밖에서 생성
- [ ] 5. **Main** 씬에서 `Timer`로 적을 주기적으로 스폰 (Timer의 `timeout` 시그널)
- [ ] 6. **HUD**(점수/메시지) — `CanvasLayer` + `Label` + `Button`, 버튼 `pressed` 시그널
- [ ] 7. 게임 오버/재시작 흐름 연결, 점수 누적
- [ ] 8. (선택) 배경음/효과음, 최종 실행 확인
- [ ] ✅ **F5로 실행해서 끝까지 플레이된다** → 튜토리얼 완주

> 막히면: 각 페이지 하단에 "완성된 스크립트 전체"가 있다. 베껴 넣고 **돌아가는 걸 먼저 본 뒤**, 한 줄씩 왜 그런지 되짚는 게 입문 단계에선 효율적이다.

---

## 2. 핵심 개념 — 노드 · 시그널 · `_process`

완료기준의 "본인 말로 설명"을 위한 재료. **읽고 이해한 뒤, 아래 §3 self-check에 자기 말로 답할 수 있으면 통과.**

### 2-1. 노드 (Node) — "게임을 이루는 레고 블록"

- Godot의 모든 것은 **노드**다. 노드 하나 = **기능 하나를 가진 부품**.
  예: `Sprite2D`(그림 표시), `CollisionShape2D`(충돌 영역), `Timer`(시간 재기), `AudioStreamPlayer`(소리 재생).
- 노드들을 **부모-자식 트리**로 쌓으면 의미 있는 덩어리가 된다. 이 덩어리를 저장한 게 **씬(Scene)**.
  예: Player 씬 = `Area2D`(몸통·충돌 판정) ─ 자식으로 `AnimatedSprite2D`(겉모습) + `CollisionShape2D`(충돌 모양).
- **씬은 다시 다른 씬의 노드로 들어갈 수 있다.** Main 씬 안에 Player 씬, Mob 씬을 인스턴스로 넣는다. → 재사용·조립의 단위.
- 한 줄 정의: **노드는 단일 기능 부품, 트리로 조립하면 씬, 씬을 다시 부품처럼 재사용한다.**

> 우리 게임 대입: 나중에 "밭 한 칸", "미호 NPC", "플레이어"가 전부 각각의 씬이 되고, 맵 씬 안에 인스턴스로 배치된다.

### 2-2. 시그널 (Signal) — "어떤 일이 일어났다는 방송"

- 노드가 **특정 사건이 발생하면 시그널을 emit(방출)**한다. 다른 노드가 그 시그널에 **함수를 연결(connect)**해 두면, 사건이 날 때 그 함수가 자동 호출된다.
- **옵저버 패턴**이다. 방출하는 쪽은 "누가 듣는지" 몰라도 되고, 듣는 쪽은 "언제 일어나는지" 신경 안 쓴다 → **느슨한 결합**.
  - 예: `Area2D`의 `body_entered` — 다른 몸체가 들어오면 방출 → 충돌 처리 함수 호출.
  - 예: `Timer`의 `timeout` — 시간 다 되면 방출 → 적 스폰 함수 호출.
  - 예: `Button`의 `pressed` — 눌리면 방출 → 게임 시작 함수 호출.
- 연결 방법 2가지: **에디터에서 노드 도크로 드래그 연결**, 또는 **코드에서 `signal.connect(함수)`**.
- 한 줄 정의: **시그널은 "이 일이 일어났어!"라는 방송이고, 관심 있는 노드가 거기에 반응 함수를 붙인다.**

> 우리 게임 대입: "수확 완료", "날짜 +1", "혼력 0됨" 같은 사건을 시그널로 쏘면, UI·작물·관계 시스템이 각자 독립적으로 반응할 수 있다.

### 2-3. `_process(delta)` — "매 프레임 돌아가는 심장박동"

- Godot가 **매 프레임마다 자동 호출**하는 함수. 60fps면 초당 약 60번.
- 인자 `delta` = **직전 프레임 이후 흐른 시간(초)**. 프레임률이 흔들려도 `속도 * delta`로 곱하면 **움직임이 일정**해진다(프레임 독립적).
  - 예: `position += velocity * delta` → 빠른 PC든 느린 PC든 같은 속도로 이동.
- 매 프레임 검사/갱신할 것(입력 처리, 이동, 애니메이션 상태)을 여기 둔다.
- 형제 함수 `_physics_process(delta)`는 **물리 고정 간격**(기본 60Hz)으로 호출 → 물리·충돌 이동은 이쪽이 정석.
- 한 줄 정의: **`_process`는 매 프레임 호출되는 루프이고, `delta`를 곱해 프레임률과 무관하게 일정한 변화를 만든다.**

> 우리 게임 대입: 캐릭터 이동(T1.3)은 `_process`/`_physics_process`에서, 하루 시간 흐름(T1.5)도 `delta` 누적으로 잰다.

---

## 3. Self-check — 본인 말로 설명하기 (완료 판정)

아래 4문항에 **문서를 안 보고 자기 말로** 답할 수 있으면 T1.1 완료기준의 "설명" 조건 충족:

1. 노드와 씬의 관계를 한 문장으로? (부품 ↔ 조립 ↔ 재사용)
2. 시그널이 왜 "느슨한 결합"을 만드나? 방출하는 쪽과 듣는 쪽이 서로 뭘 몰라도 되나?
3. `_process`에서 이동할 때 `delta`를 곱하지 않으면 어떤 문제가 생기나?
4. 튜토리얼에서 `body_entered`(시그널), 키 입력 이동(`_process`), Player 씬(노드 트리)이 각각 어디에 쓰였는지 한 군데씩 짚을 수 있나?

> 4문항 다 막힘없이 답 → ROADMAP의 T1.1 체크박스를 닫고 **T1.2(320×180 정수배 뷰포트)**로 진행. 일부 막히면 해당 개념의 §2 항목 + 튜토리얼 그 단계만 다시.

---

## 4. 참고 링크

- 공식 입문(2D): https://docs.godotengine.org/en/stable/getting_started/first_2d_game/index.html
- 노드와 씬 개념: https://docs.godotengine.org/en/stable/getting_started/step_by_step/nodes_and_scenes.html
- 시그널: https://docs.godotengine.org/en/stable/getting_started/step_by_step/signals.html
- `_process` / 스크립트 기본: https://docs.godotengine.org/en/stable/getting_started/step_by_step/scripting_player_input.html
- GDScript 기초 문법: https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_basics.html
