# Dear My Naraka — 타일셋 생성 규칙 (Tileset Ruleset)

> **상태:** 타일셋 규칙 grill(2026-06-29) 산출물. PixelLab `create_topdown_tileset`으로 지형 타일을
> 생성할 때의 **단일 진실의 원천**이다. 설치한 마켓 스킬(`cautiouskurns-game-template-pixellab-tileset-generator`)의
> Blood & Gold 기본값(high top-down·16×16·transition 0.5)은 **무시하고 이 문서를 따른다**.
>
> **근거 문서:** [ADR-0013](../adr/0013-environment-art-32px-native.md)(32px native)·[ADR-0026](../adr/0026-stardew-art-style-pivot-slim-cast.md)(스타듀 룩)·[ADR-0025](../adr/0025-in-game-prop-placement-mode-data-externalization.md)(스펙 카드 게이트)·[p2.0-spike-prompts §4.2](./p2.0-spike-prompts.md)(마스터 팔레트)·[world-map.md](./world-map.md)(구역별 지형).

---

## 1. 잠긴 토대 (ADR/자산이 진실 — 그릴 대상 아님)

| 항목 | 값 | 출처 |
|---|---|---|
| **타일 크기** | **16×16 논리 native, 정수 4× 렌더**(온스크린 64px) | **★[ADR-0049](../adr/0049-environment-16px-logical-stardew-grain-supersede-0013.md)**(2026-07-04 16px 실험 GO) — ADR-0013 32-native를 supersede. 스타듀 청키 그레인·전 자산 16 밀도 통일. 지형 = Gemini 필드→`gemini_grass_to_field.py` 128 다운스케일 |
| **아트 룩** | 스타듀밸리식 톤 + 저승 저채도 팔레트 + **거친 레트로 도트**(포켓몬 루비/사파이어·스타듀) | ADR-0026 → ADR-0035 개정 |
| **outline** | `single color outline` (~~`lineless`~~) | **★ADR-0035 개정** — owner 다회 피드백: lineless/매끄러운 RPG메이커 그라데이션 폐기, 단색 외곽선 + 거친 도트 |
| **detail** | **`medium detail`** (~~low~~) | **★ADR-0043 재개정**(지형 한정) — owner가 스타듀 레퍼런스로 lush 요구. 풀이 꽉 차게. |
| **생성 모드** | **`mode: pro` + `raggedness ~0.4~0.45`** | **★ADR-0043** — 경계 노이즈 = 유기적 들쭉날쭉(스타듀식 들고남) |
| **shading** | `basic shading` | 기존 4세트 공통 |
| **text_guidance_scale** | `8` | 〃 |
| **체이닝** | `lower_base_tile_id`/`upper_base_tile_id`로 이음매 일치 | 기존 풀↔길↔밭흙 체인 |

**마스터 팔레트(실측 hex, §4.2):** 전경 외곽선 `#401818`(적갈, 순검정 아님) · 영혼빛 파랑 `#60d8f0`(저채도)→`#2068e8`(고채도) · 흙길/밭흙 `#684840`/`#503030` · 풀(보정 후) `#306033`(어두운 이끼).

**기존 지형 4종:** 풀(grass) · 흙길(dirt path) · 밭흙(tilled soil) · 물(water).

> ⚠️ **해상도 히스토리:** ADR-0012(16px×2) → ADR-0013(32 native) → **[ADR-0049](../adr/0049-environment-16px-logical-stardew-grain-supersede-0013.md)(16px 논리·4× 렌더, 2026-07-04 GO)**로 다시 16 논리로. 현행 32-native 자산·`.tres`(`combined_terrain_homestead` 등)는 **16px 재생성 프로그램의 대상**(ADR-0049 downstream). 팔레트 §4.2는 유효.

## 2. 파이프라인 (확정 절차)

0. **★ADR-0043 — 풀 톤 정규화는 *런타임*에 일원화.** 여러 grass 세트가 각자 다른 런이라 풀 톤이 어긋나면(특히 water_grass 노랑), 소스 PNG 색보정(desaturate류)은 물 픽셀 오염·base/경계 불일치로 취약하다. → 색 로직을 `main.gd::_harmonize_grass_variants()`(패스 A: 모든 풀 픽셀 hue/채도 warm-moss 수렴 / 패스 B: base 변종 명도 정합)로 통합하고 소스 PNG는 **vivid 원본 유지**(재유도 가능). desaturate_grass.py식 소스 보정은 단일 세트일 때만.
1. **생성** — `create_topdown_tileset`(아래 규칙 파라미터로, `mode=pro`). 인접 지형은 이전 세트의 base tile id를 `lower_base_tile_id`/`upper_base_tile_id`로 넘겨 체이닝(풀 결 일관). pro 메타데이터도 `tiles[].corners`+`bounding_box`라 컨버터 호환.
   - **★ADR-0043 입체감:** 풀은 *클럼프/그림자 프롬프트*("small distinct tufts and clumps, sunlit top + shaded base, soft shadows between clumps, volumetric depth, NOT flat uniform pattern")로 입체감을 낸다(shading 파라미터보다 프롬프트가 핵심; `medium shading`은 서버 stall 잦음 → `basic shading`로).
   - **★ADR-0043 per-cell 변종:** 같은 전이쌍을 **여러 시드**로 생성하고 *동일 terrain 문자열*로 컨버터에 함께 넘기면(dedup) 변종 타일이 같은 peering bit에 등록돼 Godot이 칸마다 랜덤 선택 → 클럼프 격자·직선 경계 반복 제거("같은 경계 들고남"). **컨버터 코드 수정 불필요** — 인자에 세트만 추가.
2. **다운로드** — `get_topdown_tileset`의 `download_png`/`download_metadata`는 302 redirect(backblaze) → **`curl -L` 필수**(없으면 0바이트). 파일명 = `*_image.png` / `*_metadata.json`.
3. **색보정**(필요 시) — `tools/desaturate_grass.py`류 PIL hue 선택 보정(ADR-0001 허용 = Aseprite 보정). 원본은 `*_raw.png`로 1회 백업(idempotent).
4. **합성** — `tools/pixellab_tileset_converter.gd`(PixelLab 공식, 벤더링)로 Wang 세트들을 단일 `.tres`로. **인자 순서가 terrain id를 고정**(기존: 0=길·1=풀·2=밭).
5. **Godot terrain 함정**(필수):
   - `set_cells_terrain_connect(cells, set, terrain, ignore_empty_terrains=false)` — **4번째 인자 반드시 `false`**(true면 빈 캔버스 첫 칠이 한 칸도 안 됨).
   - 로드 후 `set_terrain_set_mode(0, TERRAIN_MODE_MATCH_CORNERS)` 강제(컨버터는 mode=0으로 나오나 Wang은 코너만).
   - 칠 순서: 풀 단일 칠 → 전환 얹기 → 단색(HOUSE/CAFE/WALL) 맨 나중.
   - 1칸 폭 길은 corner 전환이 풀에 묻히므로 base 직접 `set_cell`.

## 3. 그릴로 정하는 규칙 (진행 중)

> 아래 항목을 grill로 하나씩 확정해 채운다.

- [x] **3.1 뷰 각도 = `low top-down`.** 기존 타일 4종·캐릭터 5종이 모두 low top-down → 한 화면 시점 일치 강제. 스킬의 high top-down 권장은 무시.
- [x] **3.2 전이 크기 = `transition_size: 0.0`.** 코너 대각선 또렷한 경계(스타듀 정합 + 지형 가독성). 전이 *모양*은 Godot Wang 코너 오토타일이 책임지므로 0.0이 하드 경계를 뜻하지 않음. 0.0~0.5 모두 16타일이라 컨버터 무수정.
- [x] **3.3 디테일 등급 = `detail: low`.** ⚠️ **★ADR-0035 개정** — 당초 medium으로 정했으나, owner 다회 피드백으로 안식 마스터 스타일을 **`single color outline` + `low detail` + 거친 레트로 도트**(루비/사파이어·스타듀)로 잠금. lineless·highly detail·매끄러운 그라데이션(RPG메이커 룩) 폐기. → **확정 스타일 = `outline:single color outline` + `shading:basic` + `detail:low` + `text_guidance_scale:8` + `transition_size:0.0`.** (이 스타일이 절벽·계단·debris·facade·나무·바위 등 모든 후속 환경 에셋의 앵커.)
  - **★★2026-07-04 grill 개정 — 외곽선 = 스코프 분리(Q1).** owner가 스타듀 실물 스크린샷 + Gemini 잔디 가이드로 재지적: 스타듀는 잔디에 검은 외곽선이 **없고** 나무·울타리엔 **있다**. 따라서 `single color outline`은 **분리된 객체 전용**(나무·바위·건물·debris·클럼프 프롭)이고, **걸어다니는 베이스 지형(풀·흙길·밭흙·자갈·모래·숲바닥)은 무외곽선·저대비·소프트**(Gemini 룰1·스타듀 문법). asset-ruleset §9의 객체/베이스 분리선을 외곽선까지 확장. → 베이스 지형 STYLE = `NO outline / lineless, soft LOW-contrast tonal variation, tiny soft blended tufts (NOT big chunky clumps)`. (객체는 기존 청키+outline 유지.)
  - **★논리 해상도 16 vs 32 = 실험 판정 대기.** owner가 16px 논리(스타듀 밀도) 전환 검토 → 되돌리기 비싼 결정(전 라이브러리 재생성)이라 **값싼 base 룩 실험 먼저**([gemini-regen-batch.md §4.0](./gemini-regen-batch.md)). GO 시 ADR-0013 supersede, NO-GO 시 32-native 유지 + 위 소프트 베이스만 32px 적용. **판정 전까지 §1 "32px native"는 잠정 유지.**
  - **★클럼프 모델(Q5 확정):** Gemini 3카테고리 → 기존 3메커니즘 매핑 = A(베이스 변종)→**타일**(terrain alternative) / B(풀 클럼프)→**스캐터 프롭**(ground-composition §4) / C(흙 전이)→**Wang 타일**. Gemini "클럼프=타일" 반려(디컴파일: 스타듀 tuft=작고 부드러운 런타임 오버레이).
- [x] **3.4 팔레트 규율 = 공유 꼬리 + 선택적 영혼빛 액센트.**
  - **(a) 공유 꼬리 — ★2026-06-30 개정(따뜻한 베이스 + 저승 에셋, asset-ruleset §9).** 더는 "전부 muted"가 아니라 **둘로 분리**:
    - **객체용**(건물·나무·바위·debris·가구·작물): `muted desaturated low-saturation underworld palette, somber graveyard tone, rough chunky retro pixel dithering, single color dark outline, NOT smooth gradient, NOT lineless RPG-maker style`
    - **베이스 지형용**(풀·흙길·밭흙·자갈·모래·숲바닥 = 걸어다니는 땅): `warm inviting farm palette like Stardew Valley, slightly muted/toned-down (not candy-bright), tonal variation, rough chunky retro pixel dithering, single color dark outline, NOT smooth gradient`
    - **물**(연못·강·바다)은 베이스 아님 = 저승 영혼빛 액센트(아래 b).
  - **(b) 선택적 영혼빛 파랑(`#60d8f0`)** — 테마상 맞는 곳에만(물=혼의 강 푸른 윤슬·잿눈=차가운 푸른 기·영혼 풀 가장자리). **흙길·모래·돌·밭흙은 흙빛 중립 유지**(파랑 강제 금지). 저승색 본체 = "저채도·음울", 파랑 = *영혼 깃든 곳을 짚는 악센트*.
  - **(c) 후보정** — 형광으로 나오면 `desaturate_grass.py`식 hue 선택 채도 하향(ADR-0001 허용), 원본 `*_raw.png` 백업.
- [x] **3.5 구역별 지형 셋 + 체이닝 그래프** (아래 §4).
- [x] **3.6 `.tres` = 구역별 분할.** 전이 세트 소스 `<지형A>_<지형B>_image.png`/`_metadata.json`/`_raw.png`(기존 패턴). 구역 합성본 `combined_terrain_<region>.tres` + `_atlas.png`(예: `_homestead`·`_village`). 구역별 terrain id 순서는 tres 헤더 주석에 명시. **기존 `combined_terrain.tres` → `combined_terrain_homestead.tres`로 이름 통일**(농원 재생성 시 `main.gd` 로드 경로 동시 변경).
- [x] **3.7 스펙 카드 게이트(ADR-0025) 연동** (아래 §5).

---

## 4. 마스터 지형 목록 + 체이닝 그래프

**마스터 지형 목록(8구역 청사진):**

| 지형 | 영문 키 | 쓰이는 구역 | 영혼빛 액센트 |
|---|---|---|---|
| 풀 | `grass` (음울한 이끼녹) | 농원·마을·숲 | 옅게 |
| 흙길 | `dirt path` | 전 구역 동선 | ✗ |
| 밭흙 | `tilled soil`(고랑) | 농원 | ✗ |
| 자갈/돌광장 | `cobblestone` | 마을 | ✗ |
| 강물 | `river water` | 삼도천·마을 | ✓ |
| 바닷물 | `sea water` | 황천해 | ✓ |
| 모래 | `sand` | 황천해 | ✗ |
| 숲바닥 | `forest floor`(낙엽) | 저승 숲·미혹(더 어둡게) | ✗ |
| 암반/동굴바닥 | `rock` | 갱도 | ✗ |
| 심연바닥 | `abyss`(업화·봉인) | 나락 | ✓ |

> 강물/바닷물은 **별도 지형으로 유지**(어종·무대가 다르고 색·결도 다름 — 통합 안 함).

**체이닝 규칙 — "두 앵커(풀 + 흙길)" 모델:**
- **풀**(자연 바탕)과 **흙길**(전 구역 가로지르는 동선)이 두 연결 조직.
- 새 지형은 *물리적으로 맞닿는 앵커*에 `lower_base_tile_id`로 체이닝:
  - `tilled soil`→흙길 · `cobblestone`→흙길 · `rock`→흙길 (동선에 붙음)
  - `river water`→풀 · `forest floor`→풀 (바탕에 붙음)
  - `sand`→바닷물 + `sand`→풀 (해변은 물·뭍 둘 다 접함)
  - `abyss`→암반 (갱도 끝이 나락으로)
- **생성 순서:** 앵커 `grass` base 먼저 → `흙길↔풀` → 나머지가 앵커 base id를 물려받음.

**빌드 순서(ADR-0015 "한 구역씩"):** 청사진은 전체 정의, 생성은 구역별. **1순위 = 안식 농원**(`grass`·`dirt path`·`tilled soil` — 기존 4세트를 새 스타일로 **재생성**만).

---

## 5. 스펙 카드 게이트 (ADR-0025 — 생성 전 필수 승인)

PixelLab 생성 전, 아래 카드를 채워 **승인받고 생성**한다(메모리 `asset-spec-gate-before-generate`). 여러 셋이면 카드 묶음으로.

```
구역: <region>           목표 tres: combined_terrain_<region>.tres
전이쌍: <lower> ↔ <upper>
lower_description: "<...>" + [§3.4(a) 공유 꼬리]
upper_description: "<...>" + [§3.4(a) 공유 꼬리]   (영혼빛 액센트는 §3.4(b) 해당 시만)
파라미터: tile_size 32×32 / view low top-down / transition_size 0.0 /
         detail medium / outline lineless / shading basic / text_guidance_scale 8
체이닝: lower_base_tile_id = <앵커 base id 출처, 없으면 신규 앵커>
후보정: <desaturate 필요 예상 여부>
예상 비용: ~1.25 gen/타일 (셋당 2~3 gen)
```

