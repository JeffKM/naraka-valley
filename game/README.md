# game — 나라카 밸리 게임 본체

스타듀밸리형 본편 게임(Godot 4.6 / GL Compatibility). **학습용인 [`../godot-sandbox/`](../godot-sandbox/)·[`../godot-tutorial/`](../godot-tutorial/)와 달리 이쪽이 진짜 게임이다.** Phase 1 Sprint 1에서 시작한 본체 프로젝트.

> ⚠️ Phase 1은 **회색 도형(그레이박스)만** 쓴다. 도트·초상화·사운드는 재미 게이트 통과 후 Phase 2에서만 입힌다(ADR-0001).

## 여는 법 / 실행

```bash
godot --path game -e   # 에디터로 열기
godot --path game      # 바로 실행
```

또는 Godot 실행 → **Import** → `game/project.godot` 선택 → **F5**.

## T1.2 — 320×180 정수배 스케일 뷰포트

이후 **모든 화면 작업의 기준**이 되는 픽셀아트 뷰포트 설정(ADR-0003).

| 설정 (`project.godot`) | 값 | 이유 |
|---|---|---|
| `display/window/size/viewport_*` | 320×180 | 내부(게임) 해상도. 16:9 |
| `window_*_override` | 1280×720 | 시작 창 = ×4 |
| `window/stretch/mode` | `viewport` | 320×180을 통째로 렌더 후 확대 → 순수 픽셀룩 |
| `window/stretch/aspect` | `keep` | 비율 유지(남는 공간 레터박스) |
| **`window/stretch/scale_mode`** | **`integer`** | **★ 정수배(×2/×3/…)로만 확대 — 1.5배 같은 분수배 차단** |
| `textures/.../default_texture_filter` | `0`(Nearest) | 보간 끔 → 픽셀이 흐려지지 않음 |
| `2d/snap/snap_2d_*` | `true` | 좌표를 픽셀 격자에 스냅 |

### 완료기준 직접 확인하기

`godot --path game`로 띄운 뒤 **창을 자유롭게 늘려보라.**

1. **체커보드 16×16 칸**이 늘 정확한 정사각형 → 정수배 스케일 OK.
2. **대각선**이 흐릿한 번짐 없이 또렷한 "계단"으로 → Nearest 보간 OK.
3. **남는 공간**이 검은 레터박스로 처리되고, 좌상단 readout의 **"배율 x__"가 정수로만** 바뀜 → `scale_mode=integer` 작동 중.

분수배 + 선형보간이었다면 대각선과 1px 외곽선부터 뭉개진다. 위 3개가 모두 깨끗하면 **T1.2 완료.**

> 위 체커보드 검증 씬은 **T1.3에서 캐릭터 이동 씬으로 대체**되었다(체커보드 코드는 T1.2 커밋의 git 히스토리에 보존). 정수배 스케일 동작은 이동 씬의 16px 격자로도 동일하게 확인된다.

## T1.3 — 캐릭터 그레이박스 이동 + 충돌 (현재 산출물)

회색 캐릭터(16×32 자리)가 탑다운 4방향으로 **부드럽게** 움직이고 **벽을 통과하지 못하는지** 검증한다. 회색 도형만(ADR-0001).

| 요소 | 구현 | 메모 |
|---|---|---|
| 캐릭터 | `CharacterBody2D` + `move_and_slide()` | origin은 **발치 중앙**(탑다운 깊이 정렬·충돌 기준에 유리) |
| 이동 입력 | `Input.get_vector(ui_left/right/up/down)` | **대각선 자동 정규화** → 대각선이 더 빨라지지 않음. 현재 **방향키**(WASD는 후속) |
| 속도 | `SPEED = 80 px/s` (약 5타일/초) | 그레이박스 기준값. 밸런싱은 후속 |
| 충돌체 | 캐릭터 = 발치 14×10 박스 / 벽 = `StaticBody2D`(코드 생성) | 벽 데이터는 `main.gd`의 `_walls: Array[Rect2]` |
| 배경 | 16px 격자(이동량 가늠) + 회색 벽 + 위치/FPS readout | 임시 도형. 본격 타일맵 더미 맵은 **T1.4** |

### 완료기준 직접 확인하기

`godot --path game`로 띄운 뒤 **방향키로 움직여보라.**

1. 캐릭터가 4방향으로 **끊김 없이 부드럽게** 이동 → 이동 OK.
2. **대각선**으로 가도 상하/좌우보다 빨라지지 않음 → 정규화 OK.
3. 화면 4변 경계벽·내부 장애물에 닿으면 **멈추거나 벽을 따라 미끄러짐**(통과 불가) → 충돌 OK.

위 3개가 모두 되면 **T1.3 완료.**

## 파일

- `project.godot` — 뷰포트/렌더 설정(위 표).
- `main.tscn` / `main.gd` — 이동/충돌 검증 씬(격자 배경·벽·readout). 회색 도형만.
- `player.tscn` / `player.gd` — 플레이어(`CharacterBody2D`, 16×32 회색, 4방향 이동).
