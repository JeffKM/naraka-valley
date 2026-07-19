# Retro Diffusion 스펙 카드 — 단일출처 코히어런트 base 필드 (ADR-0025)

owner가 Retro Diffusion으로 생성 → PNG를 `game/assets/terrain16/single_source/`에 넣고
main.gd `_TERRAIN_SINGLE_SOURCE = true`로 켜면 코드가 나머지를 합성한다.

## 무엇을 생성하나 (3장, 한 세션·한 팔레트)

| 파일 | 내용 | 필수 조건 |
|---|---|---|
| `grass_field.png` | 잔디 바닥 텍스처 | **씸리스 tileable**(상하좌우 wrap 이음매 0) |
| `dirt_field.png`  | 따뜻한 황갈색 맨흙/길 텍스처 | 씸리스 tileable |
| `water_field.png` | 잔잔한 물 텍스처 | 씸리스 tileable |

## 규격
- **씸리스(seamless)가 핵심.** 이 base는 넓은 면을 반복 타일링한다(Wang 솔리드처럼 자기 반복 시 씸이 있으면 안 됨 — 그게 이번 스파이크에서 PixelLab이 막힌 지점).
- **한 팔레트 락.** 세 텍스처가 같은 팔레트(warm·저승 cozy 톤)에서 나와야 톤이 태생부터 일치 → 경계 합성이 매끄러움. 이게 이번 작업의 전부.
- **픽셀 규격:** 32-native(ADR-0050). 소스는 128×128 씸리스 권장(코드가 128로 리사이즈 후 ×2=256로 월드 타일링). 32×32 씸리스도 가능.
- **스타일:** lineless(지형 무외곽선), low-color crisp(ADR-0057), cozy Stardew 톤. RD Tile 모델 + 팔레트 통제.
- **RD 프롬프트 예:** "seamless tileable top-down grass field, cozy stardew valley farm, warm low-color pixel art, no outline" / dirt·water 동일 팔레트로.

## 넣은 뒤 (owner)
1. 파일 3장을 `game/assets/terrain16/single_source/`에 저장.
2. main.gd `const _TERRAIN_SINGLE_SOURCE := true`.
3. 흙 이중보정 방지: `_earth_val_mul := 1.0`, `_earth_val_add := 0.0`(코히어런트 dirt는 이미 톤 완성).
4. 게임 실행 → 현행과 나란히 비교. 물 톤은 `_water_*` 라이브 레버로 즉석 조절.
5. **전환 타일은 자동** — 잔디↔흙은 `_bake_field_wang`, 물↔흙은 shore가 이 base들로 합성(별도 생성 불필요).

## 나중(변종·anti-tiling)
씸리스라도 넓은 면엔 반복이 보일 수 있음 → RD로 각 지형 변종 2~4장 추가 생성 후
`_harmonize_grass_variants`류 per-cell 변주에 물리면 스타듀급. (별도 슬라이스)

## 라이선스
Retro Diffusion 상업 이용 약관을 `docs/licensing-checklist.md`에 기록 후 Steam 출시 전 확인.
