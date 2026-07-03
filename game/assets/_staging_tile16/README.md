# 16px 베이스 룩 실험 — 입력 스테이징

> 2026-07-04 grill 산출(스펙: `docs/design/gemini-regen-batch.md §4.0`). 이 폴더는 **owner가
> Gemini로 뽑은 16px 베이스 텍스처를 떨구는 곳**이다. 하네스 `tools/tile16_experiment.gd`가
> 여기서 읽어 판정 이미지를 굽는다.

## 넣을 파일 (파일명 고정)

| 파일 | 규격 | 필수 |
|---|---|---|
| `grass_a.png` | **16×16**, 잔디 base 변종 1 | ✅ |
| `grass_b.png` | 16×16, 잔디 base 변종 2 (클럼프 배치만 다르게) | ✅ |
| `grass_c.png` | 16×16, 잔디 base 변종 3 | 선택 |
| `dirt.png` | 16×16, 흙길 base | ✅ |

> 파일이 없으면 하네스가 **절차 placeholder**로 대신 실행된다(파이프라인·스케일 선검증용).
> 실물이 들어오면 자동으로 그걸 쓴다. 콘솔이 `실물[…] placeholder[…]`로 무엇을 썼는지 보고한다.
> 16×16이 아니면 nearest로 리사이즈하지만, **원본을 16×16으로 뽑는 게 정확**하다.

## Gemini STYLE 접두 (§4.0 — 무외곽선·소프트)

```
[STYLE] a seamless tileable top-down [terrain] texture at 16px logical resolution,
warm inviting farm palette like Stardew Valley slightly muted for underworld mood
(not candy-bright), soft LOW-contrast tonal variation, tiny soft blended tufts
(NOT big chunky high-contrast clumps), NO outline / lineless base ground,
gentle soft shading, edge-to-edge, no border.
```
- 잔디: `[terrain]=lush grass` (warm-moss `#2d4720..#8fb267`)
- 흙길: `[terrain]=warm dirt path` (`#513928..#bc987c`)

## 실행

```bash
cd game && ./run_tile16.sh
```
→ `tools/tile16_experiment.png` (4× 업스케일, 온스크린 타일 64px = 스타듀 정합) 를
owner의 스타듀 레퍼런스와 나란히 놓고 **GO/NO-GO** 판정.

⚠️ 이 폴더의 PNG는 실험 입력이므로 커밋 대상이 아니다(`.gitignore` 처리). README만 버전관리.
