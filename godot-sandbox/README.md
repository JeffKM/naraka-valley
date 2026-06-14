# godot-sandbox — T1.1 학습용 교보재

공식 튜토리얼 *Dodge the Creeps*를 **회색 도형만으로** 재현한 미니게임.
떨어지는 빨간 네모를 피하며 점수를 쌓는다. **노드·시그널·`_process`가 전부 들어 있다.**

> ⚠️ 이건 **학습용 샌드박스**다. 나라카 밸리 **게임 본체가 아니다**(본체는 Phase 1 Sprint 1에서 별도 프로젝트로 시작). 에셋 없이 그레이박스만 쓴다(ADR-0001 정신).

## 여는 법 / 실행

```bash
# 에디터로 열기 (노드 트리를 눈으로 보며 공부하는 걸 권장)
godot --path godot-sandbox -e

# 바로 실행
godot --path godot-sandbox
```

또는 Godot 실행 → **Import** → `godot-sandbox/project.godot` 선택 → 열린 뒤 **F5**.

**조작:** 방향키 = 회색 네모 이동 · 게임오버 후 Enter/Space = 재시작.

## 세 개념이 어디에 있나 (코드 읽기 가이드)

| 개념 | 어디서 보나 |
|------|------------|
| **노드/씬** | `player.tscn`·`mob.tscn` = `Area2D`(몸통) + `Polygon2D`(겉모습) + `CollisionShape2D`(충돌)의 트리. `main.tscn`이 Player 씬을 **인스턴스로 재사용**하고 Timer·Label을 조립. |
| **시그널** | `main.gd` `_ready()`의 `.connect(...)` 3줄: Timer `timeout`→스폰, Player 커스텀 `hit`→게임오버. `player.gd`의 `signal hit` 선언과 `hit.emit()` 방출. |
| **`_process(delta)`** | `player.gd`의 입력→이동(`position += direction * speed * delta`), `mob.gd`의 낙하. **`delta`를 곱하는 이유**가 주석에 있음. |

## 직접 만져보며 이해하기 (이게 핵심)

1. `player.gd`의 `position += direction * speed * delta`에서 **`* delta`를 지워보라.** 왜 움직임이 이상해지는지 = `_process`/`delta`를 체감으로 이해.
2. 인스펙터에서 Player의 `speed`, Mob의 `fall_speed`, MobTimer의 `wait_time`을 바꿔보라.
3. `main.gd`에서 `$Player.hit.connect(...)` 줄을 주석 처리해보라. 부딪혀도 게임오버가 안 된다 = **시그널을 "듣지 않으면" 아무 일도 안 일어난다**(느슨한 결합 체감).

→ 다 해봤으면 [`../docs/godot-learning-notes.md`](../docs/godot-learning-notes.md)의 **Self-check 4문항**에 본인 말로 답해보기. 막힘없으면 T1.1 완료.
