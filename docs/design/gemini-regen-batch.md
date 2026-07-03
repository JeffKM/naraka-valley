# Gemini 전면 에셋 재생성 배치 — 스펙카드 + 프롬프트

> **상태:** 스펙 확정(2026-07-02), owner Gemini 수동 생성 대기.
> **근거:** [ADR-0047](../adr/0047-gemini-full-asset-regen-supersede-adr0001-scope.md)(Gemini 전 에셋 격상)·[ADR-0025](../adr/0025-asset-spec-card-gate.md)(생성 전 스펙카드 게이트)·[asset-ruleset.md](./asset-ruleset.md)(NW광원·2px청크·팔레트·피벗·footprint)·[master-palette.md](./master-palette.md)(hex).
> **워크플로우:** owner가 각 프롬프트를 Gemini에 붙여 생성 → 로컬 raw PNG → 변환 글루(§8) → `game/assets/`. Gemini 생성 부분은 코드 밖 수작업([ADR-0001] 허용 글루만 repo에).
> **자매 문서:** 이 배치는 *기존 96개 재생성*이다. 안식 농원 데모를 완성하려면 새로 그려야 하는 **신규 스프라이트**(가축·신규 작물/과수·닭장·가구 세트)는 [gemini-demo-sprites-spec.md](./gemini-demo-sprites-spec.md)([ADR-0048] F)에서 다룬다.

---

## 0. 개요

### 0.1 대상 = 96개 (위키 태그 기준)

| 카테고리 | 개수 | Gemini 난이도 | 파이프라인 |
|---|---|---|---|
| 캐릭터 (§2) | 5 | ★★★ 높음(4방향 walk 시트) | 방향/프레임 개별 생성 → `assemble_char.py` |
| 작물 (§3) | 9 | ★ 낮음(정적 소형) | 생성 → 청키화 |
| 타일 (§4) | 32 | ★★★ 높음(seamless Wang) | base 생성 → 이음새 후처리 → `.tres` 조립 |
| Props (§5) | 40 | ★ 낮음(정적 오브젝트) | 생성 → 청키화 |
| 건물 facade (§6) | 4 | ★★ 중간 | `gemini_facade_to_chunky.py`(검증됨) |
| UI 아이콘 (§7) | 6 | ★ 낮음 | 생성 → 소형 청키화 |

### 0.2 범위 밖 (이미 Gemini 완료 — 재생성 안 함)

- 대화 초상화 28(bana/mel/miho/okja × 7표정) — 파이프라인 원본
- 건물 3(house_ext·storehouse_ext·barn_ext) — §6 파이프라인 계승 원본
- 대화 UI 3(dialog_window·hanji_frame·hanji_plate)

### 0.3 진행 규칙

- **한 카테고리를 100% 끝내고 다음으로**(CLAUDE.md 개발 원칙). 난이도 낮은 것(작물·UI·props)부터 굴려 파이프라인을 검증한 뒤 캐릭터·타일(고난도)로.
- **[ADR-0025] 스펙카드 게이트:** 아래 프롬프트가 곧 승인된 스펙. 프롬프트를 벗어난 즉흥 생성 금지.
- **[§12 실배율 검증](./asset-ruleset.md):** 각 에셋 생성·변환 후 인게임 배율(640×360 내부해상도 ×2)에서 육안 확인(map_dump/home_full_dump) 후 다음으로.

---

## 1. 공통 스타일 토큰 (전 프롬프트 공유)

검증된 초상화 프롬프트([portrait-midjourney-prompts.md](./portrait-midjourney-prompts.md))와 asset-ruleset §1.1 광원·§9/§16 팔레트를 계승. 아래 **STYLE**을 모든 프롬프트에 고정하고, 카테고리별 **프레이밍**만 갈아끼운다.

**STYLE (세계 공통 — 정적 오브젝트/타일/작물/props):**
```
detailed pixel art in the style of Stardew Valley and Sun Haven, chunky visible pixels (2px blocks), crisp clean pixel edges, low detail, a warm limited palette slightly desaturated for an underworld/afterlife mood, flat 2D pixel art, light source from top-left (NW), distinct directional step-shading, 1px highlight on top and left edges, crisp dark shadows to bottom-right (SE), 2-3 color values max per material, no smooth gradients, no anti-aliasing. pixel art, 16-bit RPG.
```

**프레이밍:**
- **props/작물/debris:** `a single [OBJECT], top-down 3/4 overworld view (Stardew Valley angle), centered on a transparent background, bottom-center anchored, standing upright, no baked ground shadow (only its own form self-shadow).`
- **타일:** `a seamless tileable top-down [terrain] texture, flat, edge-to-edge, no border.`
- **건물:** 정면 facade + 남향 + 박공 + 윗면 슬랩 노출 + 문 정중앙(§6.0 전문).
- **캐릭터:** 별도(선명도 우선, §2). **UI:** 별도(§7).

**고정 팔레트 hex(프롬프트 삽입 + 생성 후 `quantize_to_palette.py` 스냅, §16):**

| 램프 | hex |
|---|---|
| 풀 warm-moss | `#2d4720 #446630 #597f3f #739952 #8fb267` |
| 흙길 warm | `#513928 #724f3b #8e634d #a87d64 #bc987c` |
| 밭흙 warm | `#332016 #472d22 #5b3a2d #725242 #896d5a` |
| 영혼빛(물·발광) | `#2068e8 → #60d8f0` |
| 외곽선(전 객체 단일) | `#401818` |
| 접지 그림자 오버레이 | `#000000 @ ~30% alpha` |
| 저승 객체 self-shadow | 차가운 청보라-슬레이트 / warm 목재 가구 = 꿀빛 목재 램프 어두운 끝 |

---

## 2. 캐릭터 (5종)

> **권위 정합:** 외형은 [portrait-spec-card.md §5](./portrait-spec-card.md) + [portrait-midjourney-prompts.md §2](./portrait-midjourney-prompts.md)와 100% 동일 인물. 안경 규칙: **옥자만 有**, 미호·멜·바나·플레이어 無.
> **선명도 우선([ADR-0047] §4):** 캐릭터는 2px 청크 캐논 예외 — high detail·crisp로 뽑아 다운스케일 최소화.

### 2.1 스프라이트 시트 규격

| 항목 | 값 |
|---|---|
| 파일 | `game/assets/characters/<name>.png` (miho_walk·okja·bana·mel·player_walk) |
| 시트 | **480×320** = 6열 × 4행 |
| 프레임 | **80×80** (char_sprite.gd `FRAME=Vector2i(80,80)`) |
| 행=방향 | 0=down(남)·1=up(북)·2=right(동)·3=left(서) |
| 열 | 0=idle · 1~5=walk |
| 발치 | 콘텐츠 발치 y≈76, 가로 중앙 (`FOOT_OFFSET_Y=-36`) |

- 시트엔 down/up/right/left 4행만. 대각선은 `dir_anim()`이 좌우로 흡수(생성 불요).
- left(서) = right(동) 가로 미러 허용(스타듀식).

### 2.2 Gemini 한계 + 조립 워크플로우

**한계:** Gemini는 4방향×다프레임 워크 시트를 한 장으로 못 뽑는다(프레임 간 정체성·비율·발치 흔들림). → **완성 시트 1장 생성 금지.**

**2단계 조립(Gemini=프레임 소스, 규격은 코드가 보장):**
1. **컨셉 앵커(캐릭터당 1장)** — 초상화와 동일 인물의 전신 기준 포즈를 Gemini로 뽑아 색·의상·비율 확정(참조용, 게임 미투입).
2. **방향별 개별 생성** — 앵커를 참조로 방향 하나씩. 최소 = 4방향 idle 1장(정지 NPC엔 충분). walk 필요(미호·플레이어)는 방향당 프레임 추가. Gemini가 시퀀스를 못 맞추면 idle 4방향만 확보 + walk는 Aseprite 수동 2~4프레임 보정([ADR-0001]).

### 2.3 캐릭터별 프롬프트

**공통 스타일 토큰(캐릭터 — 선명도 우선):**
```
detailed pixel-art character sprite in the style of Stardew Valley and Sun Haven — chunky visible pixels, crisp clean pixel edges, painterly pixel shading, a warm limited palette slightly desaturated for an underworld/afterlife mood, large readable silhouette, cozy dark-fantasy JRPG. flat 2D pixel art, light source from top-left (NW), distinct directional step-shading, crisp dark shadows to bottom-right (SE), no smooth gradients, no anti-aliasing. top-down 3/4 overworld view (Stardew Valley walking angle), full body standing, chibi ~2.5-3 heads tall. Transparent background. HIGH DETAIL, sharp crisp readable features — prioritize sharpness and clean facial/costume detail over blur, do NOT mush pixels together.
```

**방향 지시(같은 프롬프트에 하나씩 끼워 4번 생성):**

| 방향 | 파일 | 지시 문구 |
|---|---|---|
| down/남 | south | `faces the camera / toward the viewer (walking DOWN / south), face fully visible.` |
| up/북 | north | `faces away / seen from behind (walking UP / north), back of head and back visible, no face.` |
| right/동 | east | `faces to the RIGHT in side profile (walking EAST).` |
| left/서 | west | (east 미러 → 생략 가능) 또는 `facing LEFT in side profile.` |

> idle = `standing still, both feet together, relaxed.` / walk = `mid-stride, one leg forward one leg back, arms swinging` + 프레임마다 `left/right foot forward` 교대.

**미호 (miho_walk) — 여우·작물양육·walk 필요**
```
[공통 스타일 토큰]
CHARACTER: a warm gentle young woman, white fox ears on top of her head, dark-brown long wavy hair, large soft friendly eyes, a greyish-lavender-and-white top with a hint of a yellow skirt beneath, ONE single white fox tail (exactly one tail, steady, no sway), a small floating blue fox-fire flame beside her head. No glasses. Warm, kind expression.
[방향 지시 하나]
```
> 꼬리 반드시 1개. 워크 프레임에서 꼬리·여우귀 "steady, fixed, no flutter".

**옥자 (okja) — 카페 점주·마녀·idle 4방향(정지 NPC)**
```
[공통 스타일 토큰]
CHARACTER: a composed elegant young woman, a black witch hat with a single small burgundy feather, burgundy wavy hair, a solid burgundy dress, round thin glasses, large sharp calm eyes, cool serene demeanor.
[방향 지시 하나 — idle: standing still, calm, both feet together]
```
> 안경 有(옥자만).

**멜 (mel) — 강시·카페 운영·idle 4방향**
```
[공통 스타일 토큰]
CHARACTER: a young woman in a teal jiangshi (Chinese hopping-ghost) robe with a blue floral pattern, a matching teal jiangshi cap with a single red beaded tassel on the side, a straight blunt black bob cut, blue-grey eyes, a red prayer-bead (mala) necklace, red lips, blushing cheeks, a mandarin collar with frog buttons. No glasses.
[방향 지시 하나 — idle: standing still, arms relaxed at sides]
```

**바나 (bana) — 뱀파이어·야간 경비·idle 4방향**
```
[공통 스타일 토큰]
CHARACTER: a young woman in a purple-and-black frilled gothic-lolita dress, blonde hair with a black front-bang streak, red eyes, small vampire fangs, a frilled choker. No glasses.
[방향 지시 하나 — idle: standing still, poised]
```

**플레이어 (player_walk) — 저승 농부·walk 필요**
> 근거: [p2.0-spike-prompts.md §5.1](./p2.0-spike-prompts.md) — 플레이어=의도적 무채·저채도, 팔레트 스왑 베이스.
```
[공통 스타일 토큰]
CHARACTER: a gender-neutral young afterlife farmer, deliberately plain and unremarkable, short dark-brown hair, a simple low-saturation muted work outfit (earthy tunic or overshirt, plain trousers, sturdy boots) suitable for farming in the underworld, no distinct accessories, calm neutral face. A blank-slate protagonist designed for later palette swaps. No glasses.
[방향 지시 하나]
```

### 2.4 조립 스크립트

**`game/tools/assemble_char.py` 재사용**(입력이 "방향별 개별 PNG"라 Gemini 산출에도 호환):
- 입력: idle(옥자·멜·바나) = `<dir>/south.png north.png east.png west.png` / walk(미호·플레이어) = `<dir>/south/000.png…` 방향별 하위폴더.
- 처리: hole_fill → 방향별 공통 bbox 크롭 → 80×80 발치(y=76)·가로중앙 정렬 → 시트 저장.
- 실행: `python game/tools/assemble_char.py <입력디렉터리> game/assets/characters/miho_walk.png`
- `--targeth`=0(네이티브, 선명도 보존) 기본.
- 신규 글루 후보(승인 후 작성): `mirror_east_to_west.py`(east→west 미러), 배경 전처리(Gemini가 투명 대신 단색/체커 렌더 시 — 초상화 배경 3분기 로직 재사용).

---

## 3. 작물 (9)

**규격:** 각 32×32, 투명, `game/assets/crops/<name>_{seed,sprout,mature}.png`.
**성장 3단계(CONTEXT §199-203):** seed=심은 직후 밭흙 위 발아 전, sprout=새싹, mature=수확기.
**★단계 간 일관성:** 세 프레임 동일 팔레트·NW광원·bottom-center 발치. 위로만 자람(가로폭 타일 경계 안, §5). seed 밭흙색 = §1 밭흙 램프. mature = 밭흙 대비 더 밝거나 영혼빛(§17 dark-on-dark 회피)·외곽선 `#401818`.

### 3.1 혼령초 (honryeongcho) — 魂靈草, 빛나는 영혼 풀 (유화절/여름, 빠름·입문)
- **seed** — `[STYLE] a single small crop plant, top-down 3/4 view, centered, transparent bg, freshly planted seed on dark tilled soil, tiny pale blue-green sprout tip just breaking the dark soil #332016, one or two faint spirit-blue #60d8f0 pixels of glow. a wispy spirit herb.`
- **sprout** — `[STYLE] … a small young herb seedling, a few thin upright blades of pale teal-green grass, faint soul-blue #60d8f0 glow along the leaf edges, on dark soil. a glowing spirit grass.`
- **mature** — `[STYLE] … a harvest-ready small tuft of tall wispy grass blades glowing with cool spirit-blue light #60d8f0 to #2068e8, ghostly ethereal herb, brighter than the dark soil. luminous soul grass ready to harvest.`

### 3.2 편화 / 피안화 (pianhwa) — 彼岸花 red spider lily (피안절/봄, 중간)
- **seed** — `[STYLE] … a freshly planted bulb on dark tilled soil #332016, a single dark-red sprout tip emerging. a red spider lily bulb.`
- **sprout** — `[STYLE] … a young lily shoot, a slender bare crimson-green stalk rising from dark soil, no bloom yet, a hint of deep red at the tip. a red spider lily stem sprouting.`
- **mature** — `[STYLE] … a blooming red spider lily (higanbana), one radial cluster of thin spidery deep-crimson petals and long curling stamens on a tall dark stalk, an ominous otherworldly funeral flower, muted blood-red against dark soil. the flower of the far shore in bloom.`

### 3.3 영혼호박 (yeonghon_hobak) — 얼굴이 비치는 저승 호박 (성야절, 느림·고수익)
- **seed** — `[STYLE] … a large pumpkin seed pressed into dark tilled soil #332016, a small pale sprout curl emerging. a soul pumpkin seed.`
- **sprout** — `[STYLE] … a young pumpkin seedling, two broad low green leaves and a curling vine tendril spreading over dark soil, close to the ground. a pumpkin vine sprouting.`
- **mature** — `[STYLE] … one plump ripe muted-orange pumpkin resting on the ground with a green stem and leaves, a faint ghostly soul face dimly glowing through the pumpkin skin (subtle spirit-blue #60d8f0 inner light, NOT a carved jack-o-lantern), eerie afterlife squash. a soul pumpkin ready to harvest.`

---

## 4. 타일 (32)

> ⚠️ **Wang/오토타일 seamless는 Gemini 최대 약점 → §4.5 후처리 필수.** base 텍스처만 뽑고 전이/이음새는 후처리 보정.
>
> ⚠️ **2026-07-04 grill 개정 — §4.2 스펙 일부 stale.** 아래 §4.0 "16px 베이스 룩 실험"의 **판정(GO/NO-GO)이 §4.2를 덮어쓴다**. 특히 ①베이스 지형은 **무외곽선·소프트·저대비**로 전환(Q1 스코프 분리 — 외곽선은 *분리 객체* 전용, 걸어다니는 베이스 지형엔 금지), ②논리 해상도 **16 vs 32는 실험 판정 대기**(현행 §4.2의 128×128=32-native·`single dark outline`·`chunky 2px`는 GO 시 폐기). 실험 전까지 지형 Wang 아틀라스 생성 보류.

**타일 STYLE 접두:** `[STYLE] a seamless tileable top-down [terrain] texture, flat, edge-to-edge, no border.`

### 4.0 16px 베이스 룩 실험 (판정 대기 — 2026-07-04 grill)

> **목표:** "16px 논리 해상도 + 무외곽선·소프트 베이스"가 현행 32-native보다 인게임에서 나은지 **눈으로 판정**. GO면 전 라이브러리 16px 재생성 착수(ADR-0013 supersede), NO-GO면 32-native 유지 + Q1 소프트 베이스만 32px에 적용.
>
> **왜 실험부터:** 16px 전환은 타일뿐 아니라 **캐릭터(480×320→240×160)·건물·나무·바위 전부**를 절반 밀도로 재생성해야 픽셀 그레인이 안 섞임(되돌리기 매우 비쌈). 값싼 base 텍스처 몇 장으로 선판단.

**owner가 Gemini로 생성할 것 (최소 셋):**
- **grass base ×2~3 변종** (서로 다른 시드 — per-cell 랜덤용)
- **dirt path base ×1**
- (선택) **grass 위에 흙길 패치가 지나가는 1장** — 경계 룩 즉시 확인용. 정식 Wang 전이는 Claude 후처리(§4.5·§8.2 2px 디더 마진).

**실험 STYLE 접두 (16px·무외곽선·소프트 — §4.2와 다름):**
```
[STYLE] a seamless tileable top-down [terrain] texture at 16px logical resolution, warm inviting farm palette like Stardew Valley slightly muted for underworld mood (not candy-bright), soft LOW-contrast tonal variation, tiny soft blended tufts (NOT big chunky high-contrast clumps), NO outline / lineless base ground, gentle soft shading, edge-to-edge, no border.
```
- `[terrain]=lush grass` (warm-moss `#2d4720..#8fb267`) — 변종은 클럼프 배치만 다르게.
- `[terrain]=warm dirt path` (흙길 `#513928..#bc987c`).

**Claude 후처리·검증 (owner 생성 후, EnterWorktree 격리에서):**
1. crop/tileable 봉합 → 최소 `combined_terrain_experiment16.tres` 조립.
2. ⚠️ **렌더 스케일 유효성:** 16px 타일을 현행 32-cell 월드에 2×로 넣으면 화면상 32px = 스타듀 대비 절반 크기 → **거짓 NO-GO**. 테스트 씬은 **4× 렌더**(온스크린 타일 ≈64px)로 owner 스타듀 레퍼런스와 물리 크기를 맞춘다.
3. 굽은 흙길이 잔디를 통과하는 소구역 페인트 → `home_full_dump`로 스크린샷.
4. owner가 스타듀 레퍼런스(2026-07-04 제공)와 나란히 비교 → GO/NO-GO.

**클럼프 모델(확정, Q5):** A(베이스 변종)→**타일**(terrain alternative) / B(풀 클럼프)→**스캐터 프롭**(`_build_ground_details`, 작게·부드럽게) / C(흙 전이)→**Wang 타일**. 실험엔 클럼프 타일 **생성 불요**(스캐터 프롭 재활용).

### 4.1 다단 절벽 세트 (17개, 각 32×32) — `cliff_*.png`
> asset-ruleset §4.1 + [ADR-0044]. 2행 pseudo-Z: `Lip(걷기O 밝은 상단) → Face(SOLID) → Base(SOLID·self-shadow) → 저지`. 재질 = 차가운 슬레이트 청회 암석 + 상단 풀 오버행.
> **★NW 광원 재보정(단순 flip 금지):** 동면(`cliff_e_*`)↔서면(`cliff_w_*`)은 거울대칭 아님 — 밝은 1px 하이라이트가 항상 좌상단(NW)에 오게 개별 셰이딩.

공통 접두:
```
[STYLE] a seamless tileable top-down cliff tile, cold desaturated slate blue-grey rock, 3 value steps only, single dark outline #401818, cool blue-violet slate self-shadow, chunky 2px blocks, edge-to-edge no border.
```
- **cliff_s_face** — `…the vertical south-facing rock wall face, seen straight on, horizontal strata, top edge lit (NW), lower body in shadow.`
- **cliff_s_base** — `…the base row of a south-facing cliff where the wall meets lower ground, self-shadow baked at the foot, darkest along the bottom.`
- **cliff_s_lip** — `…the top lip: bright sunlit grass overhang edge (warm-moss #739952/#8fb267) with a 1px highlight, rock edge just below, walkable plateau rim.`
- **cliff_n_lip** — `…the far (north) top lip, grass plateau meeting the rock edge, viewed from above, top-left lit.`
- **cliff_e_face** — `…an east-facing vertical cliff wall, height turned sideways into 2 columns of rock, RIGHT (east) side turned away from NW light so it reads darker toward SE, recompute shading — do NOT mirror the west face.`
- **cliff_e_lip** — `…the east lip column, narrow grass overhang rim on the east side, top-left light preserved.`
- **cliff_w_face** — `…a west-facing vertical cliff wall, 2 columns of rock, LEFT (west) side catching NW light with a bright 1px highlighted edge, recompute shading — do NOT mirror the east face.`
- **cliff_w_lip** — `…the west lip column, narrow grass overhang rim on the west side, brightly lit top-left edge.`
- **외부 코너 cliff_out_{nw,ne,sw,se}** — `…an OUTER (convex) corner tile for the [NW/NE/SW/SE] corner, grass plateau overhang wrapping the corner over slate rock, fully filled edges (no green bleed), NW light consistent.` (flip 금지·광원 재보정)
- **내부 코너 cliff_in_{nw,ne,sw,se}** — `…an INNER (concave) corner tile for the [NW/NE/SW/SE] inside corner, plateau grass tucking into the notch, rock face on two adjacent sides, edge-to-edge fill, NW light.`
- **cliff_bank** — `…a river-bank cliff face where a rock/earth bank drops one step down to spirit-water, water line at the base tinted spirit-blue #2068e8→#60d8f0, cool slate rock above, ≥1 row of vertical bank face for pseudo-Z between plateau grass and low water.`

### 4.2 지형 Wang 아틀라스 (9개, 128×128) — `game/assets/tiles/`
> ⚠️ **진짜 seamless가 핵심 → base만 생성, 전이 슬롯 Gemini에 안 맡김(§4.5).**

warm 베이스 지형 프롬프트:
```
[STYLE] a seamless tileable top-down [terrain] texture, warm inviting farm palette like Stardew Valley slightly muted (not candy-bright), tonal variation, small distinct tufts/clumps with sunlit tops and shaded bases, volumetric depth NOT flat uniform pattern, single dark outline #401818, chunky 2px blocks, edge-to-edge, no border.
```
- `gpv2_image`, `gpv3_image` — `[terrain]=lush grass`(warm-moss `#2d4720..#8fb267`), 서로 다른 클럼프 배치(per-cell 변종).
- `sgv2_image` — `soil` 변종 / `wgv2_image` — `grass beside spirit-water` 변종.
- `grass_path_image` — `grass meeting a warm dirt path`(흙길 `#513928..#bc987c`).
- `path_soil_image` — `dirt path meeting dark tilled farm soil`(밭흙 `#332016..#896d5a`).
- `soil_grass_image` — `tilled soil meeting grass`.
- `water_grass_image` — `grass edge meeting spirit-river water`(물 픽셀만 영혼빛 `#2068e8→#60d8f0`, 풀/흙 warm 유지).

### 4.3 대형 결합 아틀라스 (1개) — `combined_terrain_homestead_atlas` (160×512)
> 정석은 §4.2 개별 지형을 `pixellab_tileset_converter.gd`로 합성. Gemini 직생성 시:
```
[STYLE] a top-down terrain tile atlas sheet, 5 columns wide, warm Stardew-like farm palette slightly muted for underworld mood, rows of seamless grass / dirt-path / tilled-soil / grass-path-transition / soil variants, each cell a chunky 2px-block tileable texture, single dark outline #401818.
```
- 각 행=한 지형, 열=전이 코너. **전이 열은 §4.5 후처리로 정합**(Gemini 배치는 초안).

### 4.4 실내 바닥/벽 (5개, 각 32×32)
```
[STYLE] a seamless tileable top-down interior [surface] texture, warm muted wood/stone, single dark outline #401818, chunky 2px blocks, edge-to-edge no border.
```
- `cafe_floor` — `[surface]=cafe wooden plank floor, warm honey-brown boards, subtle grain`.
- `cafe_wall` — `[surface]=cafe interior wall, warm plaster/wood paneling, top edge lit`.
- `house_floor` — `[surface]=cozy house wooden floorboards, warm brown`.
- `house_wall` — `[surface]=house interior lower wall, warm plaster with a baseboard`.
- `house_wall_upper` — `[surface]=house interior upper wall row, warm plaster, top-left lit, tiles above house_wall`.
- `wall` — `[surface]=generic stone/wood wall block, cold slate for underworld structures, top edge lit NW`.

### 4.5 ★seamless 한계 + 이음새 후처리 (asset-ruleset §8.2)
1. **base 생성** — 각 지형 단일 텍스처(중심 fill)만. 전이 코너 슬롯을 Gemini에 안 그리게 함.
2. **4-way tileable 봉합** — `np.roll` 반칸 오프셋 후 seam 라인을 픽셀 페인트/미러 스티치. 반복 타일링 미리보기로 티어링 확인.
3. **전이(Wang) 후처리** — 인접 지형 경계 외곽 1~2 논리px에 2px 체커(디더) 하드알파 마진(§8.2). `pixellab_tileset_converter.gd`/`_harmonize_grass_variants()`에 태워 Wang `.tres` 조립·base id 체이닝.
4. **팔레트 스냅** — `quantize_to_palette.py` nearest로 §1 램프 미디엄 양자화.
5. **절벽 면** — `cliff_*`도 외곽 1~2px 디더 마진, 코너 edge-to-edge로 초록 새어나옴 0.
6. **런타임 풀 톤 정합** — grass 변종 소스는 vivid 원본 유지([ADR-0043]), 톤 수렴은 `main.gd::_harmonize_grass_variants()`(소스 desaturate 금지).
7. **검증(§12)** — 인게임 줌에서 이음새·풀 톤·작물 대비 육안 확인.

---

## 5. Props (40)

> **공통 규칙:** 접지 그림자 굽지 말 것(§11 별도 오버레이 — "no baked ground/cast shadow"). self-shadow만 구움. 그림자색 = **warm 목재 가구→dark warm brown / 저승 muted 객체→cool blue-violet slate**(§1.3, warm에 보라 금지). 피벗 = 바닥 프롭 bottom-center, 벽 부착 가구 wall:N. 코드 귀속 `main.gd:204~254`.

**프레이밍 (F):** `a single [OBJECT], top-down 3/4 overworld view (Stardew Valley angle), centered on a transparent background, bottom-center anchored, standing upright, no baked ground shadow or cast shadow (only its own form self-shadow), self-shadow color [SHADOW].` — 각 프롬프트 = **[STYLE] + F**.

### 5.1 농장 (6)
- **bush** (64×64, 통과) — `[OBJECT]=a rounded underworld hedge bush, dense muted moss-green foliage in a chunky dome, a few small dark spirit-berries, slightly withered afterlife tone` · `[SHADOW]=cool blue-violet slate`.
- **farm_fence** (32×32) — `a short weathered wooden farm fence segment, two horizontal rails on posts, aged warm timber, honey-wood grain, tileable side view flat as a boundary rail` · `dark warm brown`. 좌우 seam flat 연속(3/4 분리 패널 금지).
- **farm_planter** (32×32) — `a small warm terracotta farm planter box with dark soil and a tiny muted afterlife sprout` · `dark warm brown`.
- **farm_scarecrow** (32×64, 1×2) — `a farm scarecrow on a single wooden post, straw-stuffed body, burlap head with a stitched face, tattered muted cloth, a small crow motif` · `dark warm brown`. 발치만 좁게.
- **rock** (64×64, SOLID) — `a large mossy underworld boulder, chunky faceted grey-slate stone with muted moss patches, solid and heavy` · `cool blue-violet slate`. 발치 충돌·머리 통과.
- **stump_log** (64×32, 통과·장식) — `a fallen tree stump and log on its side, weathered grey-brown deadwood, visible ring on the cut face, muted bark` · `cool blue-violet slate`. ※debris 아님(치울 수 없음).

### 5.2 카페 가구 (7) — 어두운 우드+버건디 앤틱, 충돌 없음, SHADOW=dark warm brown
- **cafe_cabinet** (64×64) — `an antique wine cabinet, dark carved wood with glass doors, rows of muted bottles and glassware, burgundy accents`.
- **cafe_clock** (32×64) — `a tall antique grandfather pendulum clock, dark carved wood case, round pale face, brass pendulum`.
- **cafe_counter** (32×32) — `a cafe bar counter segment, dark polished wood front with a warm countertop, burgundy trim, tileable to form a bar`. 좌우 flat seam 연속.
- **cafe_frame** (32×32, **wall:N**) — `a small framed picture on a wall, ornate dark-wood frame, muted afterlife portrait, hangs flat against a wall`. 벽 부착.
- **cafe_shelf** (32×32, **wall:N**) — `a wall-mounted cafe shelf, dark wood plank with small muted jars, cups and a bottle, flat against the back wall`.
- **cafe_stool** (32×32) — `a round cafe bar stool, dark wood seat on a slender turned-wood/metal leg`.
- **cafe_table** (32×32) — `a small round cafe table, dark wood top on a central pedestal leg, burgundy tone`.

### 5.3 집 가구 (5) — warm 가구, 충돌 없음, SHADOW=dark warm brown
- **house_bed** (32×64) — `a cozy single bed, top-down 3/4 angle, warm wooden headboard and footboard, soft muted quilt with a pillow`.
- **house_bookshelf** (64×64) — `a tall wooden bookshelf filled with muted-colored books, a few trinkets and a small pot, warm homely wood`.
- **house_fireplace** (64×64, **emit 분리**) — `a stone-and-brick fireplace with a warm amber glowing fire inside, wooden mantel with ornaments`. 발광부(불꽃·앰버)는 `*_emit` 마스크 분리(§8.3).
- **house_rug** (96×64, 바닥 오버레이) — `a rectangular woven floor rug lying flat, muted warm pattern with a woven border, top-down completely flat like a carpet, no thickness, no upright form`. 그림자 생략.
- **house_table** (32×32) — `a small square wooden dining table, warm timber with grain, sturdy legs`.

### 5.4 debris — 개간 (3) — 저승 muted, SHADOW=cool blue-violet slate
- **debris_ember_stone** (64×64, SOLID, 곡괭이·업화석) — `a large jagged ember-rock boulder, dark charred grey-black stone with dim glowing ember-orange cracks like cooling hellfire, an obstacle blocking reclamation`. 앰버 크랙 소량 발광. 발치 충돌.
- **debris_petrified_stump** (64×64, SOLID, 도끼·석화고목) — `a large petrified tree stump, grey stone-turned deadwood with cracked bark and gnarled broken roots, lifeless muted tone, an obstacle`. 발치 충돌. ※stump_log와 실루엣 구분(돌화·험상).
- **debris_weeds** (32×32, 통과, 낫) — `a clump of clearable overgrown weeds, tall muted grey-green tangled stalks with dry brown tips, scraggly`.

### 5.5 저승·자연 (7) — muted + 영혼빛 액센트, SHADOW=cool blue-violet slate
- **soul_lantern** (32×32, 혼불등, **emit 분리**) — `a small underworld soul-lantern, a dark iron/stone post holding a glass lamp with a soft cool spirit-blue flame (#60d8f0) glowing inside`. 혼불 불꽃 `*_emit` 분리(§8.3).
- **spirit_flower_patch** (32×32) — `a small patch of spirit flowers, clustered muted spider-lily-like red-crimson blooms (피안화) with slender stems, low and delicate`.
- **spirit_pot** (32×32) — `a small underworld ceramic spirit-pot/urn, muted glazed slate-blue clay with a faint spirit-glow rim, holding a wisp of pale afterlife plant`.
- **tree_spirit_a** (64×96, SOLID, 침엽) — `a tall underworld spirit conifer/pine, layered muted blue-green needled canopy tapering upward, dark slender trunk`. 발치만 충돌·머리 통과(Y-Sort).
- **tree_spirit_b** (96×96, SOLID, 활엽) — `a large underworld spirit broadleaf tree, a rounded muted blue-green leafy canopy in chunky clumps, thick dark trunk, a few pale spirit-blossoms`. 발치만 충돌·머리 통과.
- **vine** (32×64, 통과, 세로 드리움) — `a hanging vine drape, muted green tangled leaves and tendrils cascading vertically downward as decorative cliff cover, top to bottom of the frame`. 절벽 면 장식.
- **stairs_east** (96×64, 통과, **동향 계단**) — `a flight of stone steps built into a cliff, ascending from the LOW east side (right) UP to the high west side (left), muted grey-slate treads receding leftward-and-up, a 3-tile-wide notch, walkable`. **NW 광원 재보정**(단순 flip 아님). 피벗 bottom-center.

### 5.6 지면 디테일 오버레이 (12) — ground-composition §3, 아주 작고 납작한 decal, 접지 그림자 생략
**프레이밍(F-ground):** `[STYLE] a single tiny [OBJECT], strict top-down view lying flat on the ground like a small decal, tiny and low-detail, low contrast so it melts into the ground, centered on a transparent background, no upright form, no baked shadow.`
- **grass_tuft** (32×32) — `a small clump of afterlife moss-grass blades, muted warm-moss green, a few short chunky tufts`.
- **ground_grass1** (16×16) — `a very small sparse tuft of short grass blades, muted warm-moss green, 2-3 tiny blades, low contrast`.
- **ground_grass2** (24×20) — `a small medium tuft of grass blades, muted warm-moss green, a modest clump`.
- **ground_grass3** (26×28) — `a taller fuller clump of grass blades, muted warm-moss green with a hint of a small dark spirit-leaf, still flat`.
- **ground_weed_under** (16×18) — `a small scraggly afterlife weed, muted grey-green tangled stalks, tiny`.
- **ground_weed_dry** (20×16) — `a small dry withered weed, muted tan and dull-yellow brittle stalks`.
- **ground_flower** (13×15) — `a single tiny spirit wildflower, a small muted spirit-blue/lavender bloom (#60d8f0 hint) on a slender stem`.
- **ground_pebble** (18×14) — `a few tiny scattered pebbles, muted grey-slate stones lying flat`.
- **ground_gravel** (22×14) — `a small patch of scattered gravel, muted grey-brown little stones flat`.
- **ground_embed** (14×9) — `a tiny half-embedded stone set flat into packed dirt, muted grey-slate, mostly flush`.
- **ground_dirt** (28×28) — `a small patch of bare warm-brown dirt with a couple of tiny soil clods, completely flat, low contrast`.
- **ground_crack** (24×16) — `a thin cracked line / wheel-rut carved into packed dirt, a shallow dark muted groove drawn flat, engraved not raised`.

---

## 6. 건물 facade (4)

> **파이프라인 계승:** 본가·창고·축사와 동일 — [gemini-building-prompt.md §1](./gemini-building-prompt.md) 공통 골격 + `[[BUILDING]]` 한 줄 치환 + `gemini_facade_to_chunky.py`.

### 6.0 공통 골격 (`[[BUILDING]]`/`[[DOOR]]`/`[[PALETTE_ACCENT]]`만 교체)
```
Top-down 3/4 view cozy farm game building sprite, Stardew Valley / Sun Haven pixel-art style. Subject: [[BUILDING]].

VIEW — front-facing facade, camera looking straight at the front wall. NOT isometric, NOT angled, NO left/right side walls. Symmetrical front elevation. The sloped ROOF TOP SURFACE must be clearly visible receding backward behind the ridge (roof depth visible from above) — a flat top slab, 1–2 tiles deep, brighter than the front slope. Do NOT draw only a flat triangle silhouette.

ROOF — simple GABLE roof (triangular pitched). Do NOT draw a curved/gambrel roof.

LIGHT — flat 2D pixel shading, single light source from top-left (NW): 1px highlight on top and left edges, crisp dark shadows to bottom-right (SE). Strict step-shading, max 2–3 value steps per material, NO smooth gradients, NO rim light, NO glow.

PIXELS — chunky retro pixel art: strong single dark outline, bold uniform blocky pixels, low detail. Hard-edged aliased pixels only. NO anti-aliasing, NO soft edges, NO blur, NO dithering gradients.

PALETTE — warm cozy farmstead base (honey/amber wood-brown walls, warm-toned roof), slightly desaturated, not candy-bright. Grey stone footing slab at the very bottom sitting flush on the ground. [[PALETTE_ACCENT]]

DOOR — [[DOOR]] centered on the front wall (south-facing entrance), dark outline on its top and left so it reads as set INTO the wall. Door height ≥ a human character (building ~6–8 characters tall).

FRAMING — single standalone building, centered. Fully TRANSPARENT background (no ground, no grass, no cast shadow baked in). The building bottom must end cleanly at the stone footing.

Output: high-resolution, clean, single sprite, transparent PNG.
```

### 6.1 문 폭 판정 (★본가·창고와 다름 — [ADR-0046] REV4 실측)
2칸 문 = 창고·축사뿐(짝수 footprint). 이 4채는 홀수/소형 → 아트도 1칸 단문(억지 2칸 중앙문 금지). 카페만 8칸 짝수 대형 명소라 3칸 대문.

| 건물 | footprint | 문 폭 | target_w |
|---|---|---|---|
| miho_house_ext | 4×4 | 1칸(한옥 미닫이) | 128 |
| mel_house_ext | 5×5 | 1칸(홀수) | 160 |
| bana_house_ext | 4×4 | 1칸(고딕 단문) | 128 |
| cafe_ext | 8×7 | 3칸(웅장 대문) | 256 |

### 6.2 건물별 치환값 (각 집이 주인 캐릭터 반영, warm 베이스 사수·캐릭터색은 액센트)

**① miho_house_ext — 미호(한옥·여우불)**
- `[[BUILDING]]` = `a small cozy single-story Korean hanok cottage with a curved-eave tiled gable roof, warm timber-and-hanji (paper) walls, a paper-lattice sliding front door, and small fox-fire lanterns hung under the eaves`
- `[[DOOR]]` = `a NARROW single sliding paper-lattice door (~1 tile wide)`
- `[[PALETTE_ACCENT]]` = `warm honey wood and off-white hanji panels with soft yellow-ochre trim (Miho's yellow hanbok); tiny paper lanterns glowing pale foxfire-blue (#60d8f0) under the eaves as the only cool accent.`
- **emit:** 처마 여우불 등롱 + 창 = `miho_house_ext_emit.png`.

**② mel_house_ext — 멜(강시·청록·부적)**
- `[[BUILDING]]` = `a two-story wooden townhouse with a stacked gable roof, jiangshi-style Qing upturned eave corners, teal-painted timber trim, hanging paper talisman charms (fulu) beside the door, and a small coin-motif sign over the entrance`
- `[[DOOR]]` = `a single narrow wooden double-leaf door (~1 tile wide)`
- `[[PALETTE_ACCENT]]` = `warm brown timber base with muted TEAL/blue-green painted trim and eave-tips (Mel's teal outfit); pale-yellow paper talisman charms flanking the door. Teal stays desaturated so the house still reads warm.`
- **emit:** 창 앰버 + (선택) 부적 = `mel_house_ext_emit.png`.

**③ bana_house_ext — 바나(고딕·뱀파이어, 단 warm 베이스 사수)**
- `[[BUILDING]]` = `a small dark gothic cottage with a steep pointed gable roof, a single arched window with wrought-iron lattice, a bat-shape carved into the gable peak, and a wrought-iron weathervane; still warm and cozy, not a spooky mansion`
- `[[DOOR]]` = `a single arched wooden door with iron studs (~1 tile wide)`
- `[[PALETTE_ACCENT]]` = `warm dusk-brown timber walls with deep plum/charcoal roof and black wrought-iron accents (Bana's gothic dress); a faint spirit-blue (#60d8f0) glow in the arched window. Keep the wood warm — gothic accents are dark trim, NOT a cold black building.`
- **emit:** 아치창 spirit-blue = `bana_house_ext_emit.png`. 자기그림자 warm dark brown(보라 금지).

**④ cafe_ext — 나라카 컨셉카페(옥자·명소·3칸 대문)**
- `[[BUILDING]]` = `a wide two-story underworld concept-cafe building with a broad welcoming gable roof, a large front porch overhang, big warm amber-lit cafe windows, a hanging cafe sign board, and a GRAND wide central double-entrance; inviting cozy tavern-cafe feel`
- `[[DOOR]]` = `a GRAND wide central double-door entrance (~3 tiles wide)`
- `[[PALETTE_ACCENT]]` = `warm honey-amber wood and cream plaster, warm-toned roof, big glowing amber cafe windows (the warmth of a lit tavern at dusk); a hanging sign and soft foxfire-blue (#60d8f0) lantern accents at the porch. Warm and welcoming — the cosy heart of the village.`
- **emit(★가장 중요):** 앰버 카페 창들 + 포치 영혼빛 등불 = `cafe_ext_emit.png`(마을 최대 앰버 소스).

### 6.3 후처리 (4채 동일)
raw를 `game/assets/_staging_phaseC/gemini/<name>_gemini.png`에 넣고:
```
python3 game/tools/gemini_facade_to_chunky.py <src> game/assets/buildings/miho_house_ext.png 128 48
python3 game/tools/gemini_facade_to_chunky.py <src> game/assets/buildings/mel_house_ext.png  160 48
python3 game/tools/gemini_facade_to_chunky.py <src> game/assets/buildings/bana_house_ext.png 128 48
python3 game/tools/gemini_facade_to_chunky.py <src> game/assets/buildings/cafe_ext.png        256 48
```
> `target_w = footprint 타일폭 × 32`, 48색 median-cut. `*_emit.png`는 발광부만 담아 같은 스크립트로 같은 크기 통과(픽셀 정렬). 앵커 팁: 확정된 `house_ext.png`를 참조로 첨부해 "same art style/grain/palette". 육안 = `home_full_dump`/`village_dump`.

---

## 7. UI 아이콘 (6)

> **UI STYLE:** `a single crisp pixel-art UI icon, chunky 2px blocks, clean readable silhouette, [톤], transparent background, centered.` §0.1 2px·§8.1 하드알파·§1.1 NW광원. 톤: **하트=여우불/혼력**(호감도↔여우불·바나 경비 구동) · **ink_arrow/panel_frame=태운 한지 대화창 먹빛** · **soul_moth=먹 나비+영혼빛**. 소형 후처리 = `process_chunky_phaseC.py`.

### 7.1 하트 3종 (동일 실루엣, 상태만 다름)
- **heart_empty** (16×16) — `a single crisp pixel-art UI heart icon, EMPTY state — just the heart outline, chunky 2px blocks, hollow interior (transparent inside), dark warm-brown outline (#401818) with a faint dim rose fill hint, 1px NW highlight, transparent bg, centered.`
- **heart_full** (16×16) — `…FULL state — solid filled heart, warm rose-red fill with a subtle foxfire-blue (#60d8f0) inner glint at the center, dark warm-brown outline (#401818), 1px NW highlight, 2-3 value steps, transparent bg, centered.`
- **heart_full_32** (32×32) — `identical to heart_full but at 32x32 — SAME silhouette and palette (warm rose + foxfire-blue glint + #401818 outline), larger with one extra value step, chunky 2px blocks, transparent bg, centered.`
> empty/full/full_32이 같은 하트 외곽선 공유 확인.

### 7.2 대화 UI 2종 (한지 대화창 먹빛 통일)
- **ink_arrow** (18×16) — `a small ink-brush ARROW pointing right (dialog next/continue), chunky 2px blocks, triangular silhouette, sumi-ink black with a warm dark-brown edge (#401818) like a brush stroke on hanji, subtle tapered brush tail, 1px NW highlight, transparent bg, centered.`
- **panel_frame** (46×47, 9-slice) — `a UI PANEL FRAME (9-slice border box, hollow center) in the burned-hanji dialog style — warm aged-paper cream fill with a scorched dark-brown border (#401818) and faint burnt edges, chunky 2px blocks, symmetrical border, thin ink inner keyline, corners consistent for 9-slice tiling, 1px NW highlight, transparent bg, centered.`

### 7.3 soul_moth (24×24)
- `a SOUL MOTH (spirit moth) with open wings seen from above, chunky 2px blocks, symmetrical silhouette, sumi-ink dark body and wing outlines (#401818) like a brush-painted moth, wings washed with soft glowing foxfire/spirit-blue (#60d8f0 → #2068e8), tiny amber glint at the body core, 1px NW highlight, transparent bg, centered.`
> 대화창 좌상단 먹 나비 장식의 아이콘판 + 영혼빛 정체성.

### 7.4 UI 후처리
`python3 game/tools/process_chunky_phaseC.py <src> game/assets/ui/<name>.png` — 기존 파일 크기 유지(heart 16/16/32·ink_arrow 18×16·panel_frame 46×47·soul_moth 24×24, 코드가 전제). §8.1 하드알파·§0.1 2px 검증. panel_frame은 `_raw`→후처리 2단 계승.

---

## 8. 변환 파이프라인 인벤토리

| 스크립트 | 용도 | 카테고리 |
|---|---|---|
| `game/tools/assemble_char.py` | 방향별 PNG → 480×320 walk 시트(hole-fill·발치 정렬) | 캐릭터 |
| `game/tools/gemini_facade_to_chunky.py` | facade raw → 청키(다운스케일→48색→×2) | 건물 |
| `game/tools/process_chunky_phaseC.py` | 소형 in-place 청키화(÷2 BOX→알파임계→×2) | 작물·props·UI |
| `game/tools/quantize_to_palette.py` | 마스터 팔레트 nearest 스냅 | 타일·전 객체 |
| `game/tools/pixellab_tileset_converter.gd` | 지형 base → Wang `.tres` 조립 | 타일 |
| `enforce_chunk.py` | 2px 청크 캐논(★캐릭터 제외 — [ADR-0047] §4) | 타일·props·건물 |
| **신규 후보(승인 후)** | `mirror_east_to_west.py`(캐릭터 서면), Gemini 배경 전처리(단색/체커 제거) | 캐릭터·전반 |

**공통 마무리:** 각 카테고리 변환 후 `godot --headless --import` 1회 → `game/run_tests.sh` 회귀 → 인게임 육안(§12).

---

## 9. 추적표 (owner Gemini 생성 진행)

범례: ⬜ 미생성 · 🟡 생성됨(변환 전) · ✅ 변환·적용 완료

### 캐릭터 (5)
- ⬜ miho_walk ⬜ okja ⬜ bana ⬜ mel ⬜ player_walk

### 작물 (9)
- ⬜ honryeongcho_{seed,sprout,mature} ⬜ pianhwa_{seed,sprout,mature} ⬜ yeonghon_hobak_{seed,sprout,mature}

### 타일 (32)
- 절벽(17): ⬜ cliff_s_face ⬜ cliff_s_base ⬜ cliff_s_lip ⬜ cliff_n_lip ⬜ cliff_e_face ⬜ cliff_e_lip ⬜ cliff_w_face ⬜ cliff_w_lip ⬜ cliff_out_{nw,ne,sw,se} ⬜ cliff_in_{nw,ne,sw,se} ⬜ cliff_bank
- 지형(9): ⬜ gpv2_image ⬜ gpv3_image ⬜ sgv2_image ⬜ wgv2_image ⬜ grass_path_image ⬜ path_soil_image ⬜ soil_grass_image ⬜ water_grass_image ⬜ combined_terrain_homestead_atlas
- 실내(6): ⬜ cafe_floor ⬜ cafe_wall ⬜ house_floor ⬜ house_wall ⬜ house_wall_upper ⬜ wall

### Props (40)
- 농장(6): ⬜ bush ⬜ farm_fence ⬜ farm_planter ⬜ farm_scarecrow ⬜ rock ⬜ stump_log
- 카페(7): ⬜ cafe_cabinet ⬜ cafe_clock ⬜ cafe_counter ⬜ cafe_frame ⬜ cafe_shelf ⬜ cafe_stool ⬜ cafe_table
- 집(5): ⬜ house_bed ⬜ house_bookshelf ⬜ house_fireplace ⬜ house_rug ⬜ house_table
- debris(3): ⬜ debris_ember_stone ⬜ debris_petrified_stump ⬜ debris_weeds
- 저승·자연(7): ⬜ soul_lantern ⬜ spirit_flower_patch ⬜ spirit_pot ⬜ tree_spirit_a ⬜ tree_spirit_b ⬜ vine ⬜ stairs_east
- 지면(12): ⬜ grass_tuft ⬜ ground_grass1 ⬜ ground_grass2 ⬜ ground_grass3 ⬜ ground_weed_under ⬜ ground_weed_dry ⬜ ground_flower ⬜ ground_pebble ⬜ ground_gravel ⬜ ground_embed ⬜ ground_dirt ⬜ ground_crack

### 건물 (4)
- ⬜ miho_house_ext ⬜ mel_house_ext ⬜ bana_house_ext ⬜ cafe_ext (+ 각 `*_emit.png`)

### UI (6)
- ⬜ heart_empty ⬜ heart_full ⬜ heart_full_32 ⬜ ink_arrow ⬜ panel_frame ⬜ soul_moth
