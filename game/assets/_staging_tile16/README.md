# 16px 베이스 룩 실험 — 입력 스테이징

> 2026-07-04 grill 산출(스펙: `docs/design/gemini-regen-batch.md §4.0`). owner가 Gemini로 뽑은
> 지형 텍스처를 떨구는 곳. 글루 `tools/gemini_grass_to_field.py`가 워터마크 제거 + 다운스케일 →
> 하네스 `tools/tile16_experiment.gd`가 판정 이미지를 굽는다.

## 워크플로우 (2장으로 확정 — 2026-07-04)

Gemini는 고해상(2048²) **지형 필드 텍스처**를 뽑는다(16×16 단위 타일이 아님). 그래서
"16px 청키감"은 **다운스케일 배율**로 만든다(grill 확정: **필드 128px**, 베이스 = `grass_a`만).

```
1) 원본 저장:  raw/{grass_a,grass_b,grass_c,dirt}.png   ← Gemini 원본(워터마크 有)
2) 글루:       cd game && python3 tools/gemini_grass_to_field.py
               → {name}_field.png (128², 워터마크 제거·BOX 다운스케일)
3) 하네스:     ./run_tile16.sh
               → tools/tile16_experiment.png (4× 업스케일, 온스크린 64px = 스타듀 정합)
```

| 파일 | 규격 | 용도 |
|---|---|---|
| `raw/grass_a.png` | 2048² 민무늬 잔디 필드 | **베이스**(하네스 사용) |
| `raw/grass_b.png` `raw/grass_c.png` | 2048² 클럼프 잔디 | 클럼프 = **스캐터 프롭**으로 추출(Q5, 하네스 미사용) |
| `raw/dirt.png` | 2048² 흙 필드 | 흙길 베이스(하네스 사용) |

> 원본이 없으면 하네스가 **절차 placeholder**로 실행(파이프라인·스케일 선검증).
> 콘솔이 `실물[…]` / `placeholder(전부)`로 무엇을 썼는지 보고한다.

## Gemini STYLE 접두 (§4.0 — 무외곽선·소프트·seamless)

```
[STYLE] a seamless tileable top-down [terrain] texture,
warm inviting farm palette like Stardew Valley slightly muted for underworld mood
(not candy-bright), soft LOW-contrast tonal variation, tiny soft blended tufts
(NOT big chunky high-contrast clumps), NO outline / lineless base ground,
gentle soft shading, edge-to-edge, no border.
```
- 잔디: `[terrain]=lush grass` (warm-moss `#2d4720..#8fb267`)
- 흙: `[terrain]=warm dirt` (`#513928..#bc987c`)

## 판정
`tools/tile16_experiment.png`을 owner 스타듀 레퍼런스와 나란히 → **GO/NO-GO**.

⚠️ 이 폴더의 PNG(raw·field)는 `.gitignore` 제외. README·글루·하네스만 버전관리.
