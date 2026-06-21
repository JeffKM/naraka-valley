# P2.0 스파이크 에셋 드롭 폴더

PixelLab(MCP/API)·Aseprite가 만든 **완성 PNG**를 여기에 아래 이름 그대로 넣으면,
`asset_preview.tscn`(F6 실행)이 320×180 정수배 화면에 적용해 미리보기한다.
파일이 없으면 그레이박스 폴백으로 떨어져 *지금도* 실행된다.

## 파일 이름·규격 (asset_preview.gd 상수와 일치해야 함)

| 파일 | 규격 | 내용 | 외곽선(P2.0 잠금) |
|---|---|---|---|
| `miho_walk.png` | 16×32 프레임 시트 (행=방향, 열=프레임) | 미호 4방향 워크 | 전경 = **어두운 계열색 외곽선** |
| `honryeong_seed.png` | 16×16 | 혼령초 1단계(씨앗/심김) | 전경 외곽선 |
| `honryeong_sprout.png` | 16×16 | 혼령초 2단계(새싹) | 전경 외곽선 |
| `honryeong_mature.png` | 16×16 (또는 16×32) | 혼령초 3단계(수확가능) | 전경 외곽선 |
| `tile_ground.png` | 16×16 | 풀밭 | 배경 = **외곽선 없음**(격자 떡짐 방지) |
| `tile_path.png` | 16×16 | 흙길 | 배경 무외곽선 |
| `tile_soil.png` | 16×16 | 밭흙 | 배경 무외곽선 |

## 시트 그리드가 다르면

PixelLab `create_character` + `animate_character` 출력의 행/열 배치가 위 가정과 다르면
`asset_preview.gd` 상단 상수만 조정한다(`CHAR_DIRS` 행 순서, `CHAR_FRAMES_PER_DIR` 열 수, `CHAR_FPS`).
"AI 출력 포맷을 보고 그리드를 잠그는 것"도 스파이크의 산출물이다.

## PASS 4기준 (이 화면에서 판정)

1. **가독성** — @2x/3x/4x로 키워도 안 뭉개짐
2. **톤 결합** — 전경(미호·혼령초, 외곽선 O)이 배경(타일, 외곽선 X) 위에 색·명도가 붙음
3. **정체성** — 여우귀·한복으로 미호임이 16×32에서 읽힘
4. **비용** — 이 3종을 만드는 데 든 실제 시간(생성+Aseprite 보정)을 기록 → 매니페스트로 외삽 → 천장 4~6주 안

> 이 폴더의 PNG는 추적해도 무방(에셋은 산출물). 단 PixelLab **API 키는 절대 여기 두지 말 것**
> (키는 `.claude/settings.local.json`, gitignore됨).
