# game — 나라카 밸리 게임 본체

스타듀밸리형 본편 게임(Godot 4.6 / GL Compatibility). **학습용인 [`../godot-sandbox/`](../godot-sandbox/)·[`../godot-tutorial/`](../godot-tutorial/)와 달리 이쪽이 진짜 게임이다.** Phase 1 Sprint 1에서 시작한 본체 프로젝트.

> ⚠️ Phase 1은 **회색 도형(그레이박스)만** 쓴다. 도트·초상화·사운드는 재미 게이트 통과 후 Phase 2에서만 입힌다(ADR-0001).

## 여는 법 / 실행

```bash
godot --path game -e   # 에디터로 열기
godot --path game      # 바로 실행
```

또는 Godot 실행 → **Import** → `game/project.godot` 선택 → **F5**.

## T1.2 — 320×180 정수배 스케일 뷰포트 (현재 산출물)

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

## 파일

- `project.godot` — 뷰포트/렌더 설정(위 표).
- `main.tscn` / `main.gd` — 검증 씬(체커보드·외곽선·대각선·배율 readout). 회색 도형만.
