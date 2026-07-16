# 스타듀밸리 경계 타일 대조 분석 — 안식농원 지면 (2026-07-16)

> owner 라이브 확인(스크린샷 2026-07-16): 이전 세션의 PixelLab 손그림 Wang 전환 타일(main `7b98019`)이
> *여전히 스타듀와 다르다*. 이 문서는 **스타듀의 실제 지형/경계 렌더링 원리**를 근거와 함께 정리하고,
> 우리 에셋·코드의 정량 격차와 **우선순위 개선안**을 잠근다. (deep-research: 다출처 + 에셋 육안 검증)

---

## 0. 결론 먼저 (TL;DR)

라이브의 "진한 테두리 잔디 섬이 노이즈 카펫 위에 떠 있는" 인상은 **세 가지 독립 결함의 합**이다:

1. **Wang 전환 타일이 모든 지형 이음새에 강한 외곽선 링을 그린다** — 흙↔잔디는 거의 검정, 밭↔흙은 형광 주황.
   → 이것이 최대 이질감. **우리 자신의 잠금 결정 `지형=무외곽선 / 객체=outline`([[tile-system-grill]], ADR 외곽선 스코프)을 위반**한다.
2. **베이스 타일이 스타듀 원리와 다르다** — 잔디 필드는 거의 평면 단색(볼륨/블레이드 없음), 흙 필드는 고주파 반복 노이즈(8칸 타일링이 눈에 보임).
3. **스타듀 "유기적 경계"의 진짜 비결이 우리에겐 없다** — 스타듀는 경계를 *전환 타일*로 푸는 게 아니라, **타일당 4개의 잔디 술(tuft) 스프라이트가 흙 위로 삐져나와 겹치는 오버레이**로 푼다. 우리는 경계가 깔끔한 타일 컷이라 "격자 테스트 화면"처럼 읽힌다.

핵심 통찰: **스타듀의 잔디는 "베이스 타일"이 아니라 "지형 위에 얹힌 동적 피처"다.** 부드러움은 전환 타일이 아니라 *수십 개의 겹치는 블레이드 데칼*에서 나온다.

---

## 1. 근거 — 스타듀밸리는 지형/경계를 어떻게 렌더링하나

### 1.1 잔디 = 베이스가 아니라 오버레이 지형 피처 (핵심)
스타듀 위키 *Grass* / 게임 코드 참조(로컬 미러 `docs/reference/stardew-wiki/Grass.wikitext`):

- **"각 완전 성장 잔디 타일은 4개의 잔디 술(tuft)로 구성된다."** (`Grass::dayUpdate`)
- 잔디는 매일 인접한 *경작 가능한(tillable) 흙 타일*로 25% 확률 1~2 술씩 퍼진다 (`GameLocation::growWeedGrass`).
- 즉 **베이스 지면(흙/풀 타일시트) 위에, 개별 잔디 블레이드 스프라이트가 얹혀 그려진다.** 경계가 부드러운 이유 = 이 블레이드들이 타일 경계를 넘어 흙 위로 삐져나오고 서로 겹치기 때문. 하드 컷 이음새가 블레이드 데칼로 가려진다.
- 잔디 스프라이트는 회전/변주 다수 + 흔들림 애니(`'Dancing Grass'`). 겨울엔 dormant(갈변).

> 참고: 스타듀 농장 스크린샷의 넓은 초록 바닥은 "베이스 grass 타일 + 그 위 살아있는 tuft 피처"의 합성이다.
> 우리 `grass_tuft`/`flower_patch` 프롭이 이 tuft에 대응하지만, **경계 이음새를 가리는 fringe 용도로는 안 쓰이고** 있다.

### 1.2 베이스 타일시트의 이음새 = 외곽선이 아니라 디더 전이
- 스타듀 타일시트(Tiled/tIDE `.tmx`, 순수 픽셀 png)에서 grass↔dirt 이음새는 **1~2px 살짝 어두운 초록 림 + 디더 픽셀로 흙에 스며든다.** 검정/형광 외곽선이 아니다. 커뮤니티에서도 "디더링이 과하게 쓰였다"는 평이 있을 만큼 **디더가 전이의 기본 수단**이다.
- 흙(개간/경작 바닥)은 **저주파·부드러운 얼룩 + 드문드문 자갈·잔가지 데칼**로 변화를 준다. 고주파 픽셀 노이즈를 균일하게 깔지 않는다.
- 모더 생태계가 "grass-dirt transition" 타일과 커스텀 grass 스프라이트(`More Grass`, `Lumisteria`)를 대량 만드는 것 자체가, **전이/변주 타일이 룩의 핵심**임을 방증.

**출처:** [Grass — Stardew Valley Wiki](https://stardewvalleywiki.com/Grass) · [Modding:Maps](https://stardewvalleywiki.com/Modding:Maps) · [Grass — The Spriters Resource](https://www.spriters-resource.com/pc_computer/stardewvalley/asset/223916/) · [Natural grass tiles — SDV Forums](https://forums.stardewvalley.net/threads/natural-looking-i-e-grass-tiles-paths.5014/) · [More Grass — Nexus](https://www.nexusmods.com/stardewvalley/mods/5398) · [Lumisteria Tilesheets — Nexus](https://www.nexusmods.com/stardewvalley/mods/10448) · [Lospec: Stardew Tileset Tutorial](https://lospec.com/pixel-art-tutorials/create-a-pixel-texture-stardew-valley-tileset-tutorial-1-by-etosurvival)

---

## 2. 우리 에셋 육안 검증 (game/assets/terrain16, 6× 확대)

| 에셋 | 관찰 | 스타듀 대비 |
|---|---|---|
| `wang/0_1_image.png` (흙↔잔디) | 잔디 가장자리에 **거의 검정 외곽선** + 짧은 블레이드 스파이크, 그다음 하드 컷 | 스타듀는 무외곽선·디더 전이 |
| `wang/3_0_image.png` (밭↔흙) | 두 갈색 재질 사이 **형광 주황 외곽선** + 세로 골판지 줄무늬 | 이질감 최대 |
| `grass_field.png` (128²) | 거의 **평면 단색 초록**, 아주 옅은 십자 스펙만. 볼륨·블레이드 없음 | 스타듀 grass는 2~3톤 얼룩 + tuft |
| `dirt_field.png` (128²) | **고주파 반복 노이즈 카펫**, 좌우 미러 반복(8칸 타일링 노출) | 스타듀 흙은 저주파·부드러움 |

코드 확인(`game/main.gd`):
- `_build_ground16()` ② 단계가 경계 셀에 Wang 타일을 **통째로 blit** → 외곽선이 그대로 라이브에 나온다.
- `_mute_grass_pixels(img, sat_mul=0.74, sat_cap=0.38)`로 잔디를 somber하게 채도↓ → **어두운 잔디 + 어두운 외곽선 = 무거운 섬**.
- `_G16_GRASS_THR=0.66` → 마당은 흙 ~72% / 잔디 ~28%(흙 지배 flip, [[homestead-dirt-dominant-ground-flip]]).

---

## 3. 정량 격차 → 우선순위 개선안

### 🔴 P1 — 지형 이음새의 외곽선 제거 (최대 효과·자기 규칙 위반 교정)
- **무엇:** `0_1`, `2_1`, `3_0`, `4_0` Wang 타일에서 재질↔재질 경계의 검정/주황 contour를 없앤다. 상위 재질 가장자리를 **1px 어두운 동일계열 톤 + 디더 2~3px**로 흙에 스며들게.
- **어떻게(택1):**
  - (a) **런타임 후처리** — Wang 타일 blit 후 경계 픽셀 중 "저명도·저채도(=외곽선)" 픽셀을 인접 상위재질 톤으로 대체하는 결정적 패스. 에셋 재생성 없이 즉시 검증 가능. (ADR-0001 준수: 변환 엔진 아님, 톤 보정 글루)
  - (b) **PixelLab 재생성** — 프롬프트에 "no dark outline, soft dithered edge, terrain blend" 명시. 근본적이나 왕복 비용.
- **권장:** (a) 먼저 라이브 톤 확인 → 만족 시 종결, 부족 시 (b). `_mute_grass_pixels`와 같은 단일 소스 패스로.

### 🔴 P2 — [정정·강화] 흙↔잔디 채움 패치를 없애고 tan 위 오브젝트 스캐터로 (스타듀 농장의 실제 모델)
> **owner 지적 + 와이드 샷(2026-07-16 10:14) 확대 검증으로 P5 철회 후 재정의.**
> 스타듀 Standard Farm 시작 화면 와이드 샷을 확대하니: **농장 안쪽 바닥은 거의 전부 tan 흙이고, 초록은 전부 tan 위에 흩뿌려진 오브젝트**(잡초 십자 스프라이트·잔디 술·나무·덤불·돌·잔가지)다. **채워진 잔디 바닥 패치도, 잔디↔흙 경계선도 아예 없다.** 부드러움의 정체 = 경계가 존재하지 않음.
- **무엇:** `_g16_is_grass_patch`로 셀을 grass_field로 통째 채우는 **잔디 패치 자체를 줄이거나 없앤다.** 대신 tan 바닥 위에 **개별 잡초/tuft 오브젝트 스프라이트를 흩뿌린다**(스타듀 잡초/tuft 모델).
- **재료:** 기존 `debris_weeds`·`grass_tuft`·`flower_patch` 프롭 재활용(이미 있음·`_mute_grass_pixels` 공유).
- **효과:** **흙↔잔디 Wang 경계(0_1)·외곽선 문제가 통째로 소멸.** 하드 타일 컷 없음 → 스타듀 농장과 동일 구조.
- **주의:** `_g16_cluster_cleanup`·`_g16_near_building` 잔디억제패드 등이 잔디 패치 전제로 짜여 있어 스캐터 모델로 갈 땐 이 로직 정리 동반. 우선 패치를 대폭 줄이는 레버(`_G16_GRASS_THR`↑)부터 시제로 라이브 확인 권장.

### 🟠 P3 — 베이스 타일 리톤 (평면 잔디·노이즈 흙)
- **잔디:** `grass_field.png`에 2~3톤 저주파 얼룩 + 미세 블레이드 힌트 추가(단색 탈피). 재생성 or 결정적 후처리.
- **흙:** `dirt_field.png` 고주파 노이즈를 **저주파·저대비 얼룩 + 드문 자갈/잔가지 데칼**로 교체. 타일링 주기↑(현재 8칸=256px 노출) 또는 데칼로 반복 깨기. [[terrain-tiles-pixellab-lowcolor-regen-adr0057]] 저색 crisp 재생성 방향과 정합.

### 🟡 P4 — 잔디 mute 강도 재검토
- `_mute_grass_pixels` sat_mul=0.74가 베이스 필드까지 어둡게 → 외곽선과 겹쳐 무거움. **베이스 잔디(`_bf_grass`)는 mute를 완화**하고(더 밝은 mid-green), 프롭/목본만 강하게 유지하는 분리 검토. owner "somber" 의도 vs 라이브 murky 사이 레버 재조정 — owner 톤 확인 필요.

### ~~🔵 P5 — 흙 vs 잔디 비율~~ (철회 — owner 지적으로 오판 확인)
> **철회.** 초판에서 "스타듀 농장은 잔디 지배, tan은 개간존"이라 추정했으나, owner가 제시한 **Standard Farm 시작 와이드 샷(2026-07-16 10:14)** 확대 검증 결과 **정반대**였다: 농장 바닥은 tan 흙 지배가 맞고, 초록은 전부 tan 위 오브젝트다. **흙 지배 flip([[homestead-dirt-dominant-ground-flip]])은 정확했다.** 초판의 스크린샷 2·3 판독(잔디 많은 숲가/부분개간 확대)이 오도. 이 교정이 P2를 "패치 제거+오브젝트 스캐터"로 재정의하게 함(상단 P2 참조).

---

## 4. 스코프·제약
- P1~P3은 **순수 시각 오버레이/에셋 톤 보정** — `_grid`·충돌·세이브 불변, 회귀는 선별([[regression-scoped-not-full]] `building_grounding`·`reclaim`).
- ADR-0001 준수: 변환 엔진 제작 금지, 에셋은 PixelLab 생성 + 결정적 글루 후처리만.
- 착수 시 워크트리 격리([[worktree-isolation-rule]]) — 이 문서는 분석(문서 편집)이라 예외.

## 5. 다음 액션 (제안, P2 재정의 반영)
1. **P2 시제(권장 선행)** — `_G16_GRASS_THR`↑로 잔디 채움 패치를 대폭 줄이고 tan 위 잡초/tuft 오브젝트 스캐터를 늘려 → 라이브로 "스타듀 농장식 tan+오브젝트" 확인. 흙↔잔디 경계가 사라지는지 검증.
2. **P1(a)** — 남는 경계(길·밭 3_0·물 4_0)의 외곽선 제거 런타임 패스.
3. **P3 베이스 리톤**(tan 매끈화·잡초 데칼)은 위 결과 본 뒤 필요분만.
4. **P4는 owner 톤 레버 확인** 후. (~~P5 철회~~)
