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

### 2.5 플레이어 도구 스윙 4모션 (S1R-T10 · 2026-07-23 추가)

> **1차 생성 = PixelLab 완료**(기존 "Player v2 stardew" 캐릭터 `ce6e1f81`에 `animate_character` v3, 방향당 1젠·6프레임). 이 카드는 [ADR-0025] 스펙카드 + owner Gemini 교체용 큐 항목. 배선(.gd)은 후속 태스크.

**시트 규격(§2.1과 동일 — 드롭인):**

| 항목 | 값 |
|---|---|
| 파일 | `game/assets/characters/player_{hoe,water,scythe,harvest}.png` |
| 시트 | **480×320** = 6열 × 4행, 프레임 80×80 |
| 행=방향 | 0=down(남)·1=up(북)·2=right(동)·3=left(서) |
| 열 | 0~5 = 모션 6프레임(대기 열 없음 — 대기는 walk 시트 0열 재사용) |
| 발치 | 콘텐츠 발치 y≈76, 가로 중앙(`assemble_char.py` 규약) |

**모션 정의(각 4방향 × 6프레임):**

| 모션 | 파일 | 동작 프롬프트(영문 그대로 사용) |
|---|---|---|
| 괭이 내려찍기 | `player_hoe.png` | `raising a farming hoe overhead with both hands and swinging it down hard to strike the ground directly in front, a full downward hoe chop, ONE single long-handled hoe only` |
| 물뿌리개 뿌리기 | `player_water.png` | `holding a small teal-green metal watering can with both hands and tilting it forward to pour a stream of pale blue water downward from its spout onto the ground ahead, the can stays teal-green colored` |
| 낫 휘두르기 | `player_scythe.png` | `gripping a scythe with both hands and swinging it in a wide horizontal arc across the front, a sweeping harvest slash from one side to the other` |
| 맨손 수확 | `player_harvest.png` | `bending forward and reaching down with empty bare hands to grab and pluck something from the ground in front, then straightening back up, no tool` |

**공통 캐릭터·스타일:** §2.3 플레이어 프롬프트(무채·저채도 farmer) + §2.3 방향 지시 문구. 도구 색은 `game/assets/tools/`의 인벤토리 아이콘(hoe·watering_can·scythe)과 톤 정합(물뿌리개=teal-green, 괭이=나무자루+회색 금속날).

**Gemini 교체 방법:** 방향별 6프레임 개별 생성 → `<dir>/{south,north,east,west}/000..005.png` 구조로 저장 → `python game/tools/assemble_char.py <dir> game/assets/characters/player_<motion>.png` (§2.4 파이프라인 그대로).

**1차 생성 함정 기록(PixelLab v3, 재현 회피용):** ①north(등짝) 방향에서 도구가 양손 2개로 쪼개지거나(괭이) 색이 이탈(물뿌리개 orange화) — "ONE single …", "stays … colored" 명시로 억제(물뿌리개 north는 이 문구로 재생성 성공). ②south에서도 orange 오염 발생 사례 있음(물뿌리개 south 미해결). ③프레임0은 정지 rotation 기준이라 도구가 늦게 등장하는 모션이 있음(배선 시 fps로 흡수 가능).

**생성 상태(2026-07-24 완결 — PR#264): 4시트 × 4방향 전원 ✅.** 방향별 소스 그룹/애니 구성(캐릭터 `ce6e1f81-5b7a-4b67-a080-5e8b8a66e990`, 재조립 재현용):

| 시트 | south | north | east | west |
|---|---|---|---|---|
| player_hoe | `4a7b7482`/2756015f(0..5) | **v3 `8b46c6c8`**/5103f27c(7f→1..6) | `4a7b7482`/b8ae1b9d(0..5) | `4a7b7482`/55d1ab7b(0..5) |
| player_water | **v3 `5dd76a04`**(7f→1..6) | v2 `496d40c9`/dd9065fd(0..5) | `fb6d8f52`/07eaf1ef(0..5) | `fb6d8f52`/25d38d05(0..5) |
| player_scythe | `29093773` 4방향(0..5) | 〃 | 〃 | 〃 |
| player_harvest | `a7b83565`/74749e2a(0..5) | `a7b83565`/7d99d7d6(0..5) | **신규**/b2a24eed(7f→1..6) | **신규** `a7b83565` 추가(7f→1..6) |

> 프레임 규약: v1 그룹=6프레임 전부(0..5), 재발주분=7프레임에서 프레임 0(정지 참조) 폐기·1..6을 000..005로. 추출은 download ZIP 권장(개별 URL 불요). 배선=PR#264(char_sprite `add_tool_motion`·player `swing_tool`·main `_swing_for_item`).

**추가 함정 기록(2026-07-24):** ④**v3 잡이 95%에서 산출물 없이 드롭**되는 현상 2회 재현(hoe north 1차 재생성 그룹 `12b4aa59` 서버에서 소멸·water south/harvest west 1차 재발주 동일) — pending 목록에서 사라져도 download ZIP에 프레임이 없으면 드롭이다. 같은 프롬프트 재발주로 해결(단, 완료된 동일 프롬프트·방향이 있으면 dedupe로 "already complete" 스킵되므로 문구를 미세 변형해 새 그룹 발주). ⑤검수·판정 시 `load()` 경로 덤프는 **임포트 캐시 STALE** 주의 — 시트 교체 후 `--headless --import` 1회 없이 렌더하면 교체 전 프레임이 나온다.

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

### 4.0 16px 베이스 룩 실험 (★GO — 2026-07-04, [ADR-0049](../adr/0049-environment-16px-logical-stardew-grain-supersede-0013.md))

> **판정 결과 = GO.** owner가 실물 렌더(필드 128·grass_a·무외곽선 소프트)를 스타듀 레퍼런스와 비교 → 16px 청키 그레인이 32-native보다 스타듀답다고 확정. → **환경/전 아트 16px 논리 전환(ADR-0049, ADR-0013 supersede)**. 전 라이브러리 16px 재생성 프로그램 개시(①지형→②캐릭터·프롭·건물).
>
> **왜 실험부터:** 16px 전환은 타일뿐 아니라 **캐릭터(480×320→240×160)·건물·나무·바위 전부**를 절반 밀도로 재생성해야 픽셀 그레인이 안 섞임(되돌리기 매우 비쌈). 값싼 base 텍스처 몇 장으로 선판단.

**owner가 Gemini로 생성할 것:**
- **grass 필드 텍스처** — 베이스(민무늬) + 클럼프 변종 (2026-07-04: grass_a/b/c 3장 생성 완료).
- **dirt 필드 텍스처 ×1** (완료).

> ★2026-07-04 실물 반영: Gemini는 **고해상(2048²) 지형 필드 텍스처**를 뽑는다(16×16 단위 타일 아님).
> 그래서 "16px 청키감"은 **다운스케일 배율**로 만든다 — 글루 `tools/gemini_grass_to_field.py`가
> 워터마크 제거(우하단 sparkle 고정박스) + **필드 128px BOX 다운스케일**(grill 확정 청키감).
> **베이스 = grass_a만**(Q5: grass_b/c의 큰 클럼프를 베이스에 박으면 타일링 격자 반복 → 스캐터 프롭 별도 추출).

**실험 STYLE 접두 (무외곽선·소프트·seamless):**
```
[STYLE] a seamless tileable top-down [terrain] texture, warm inviting farm palette like Stardew Valley slightly muted for underworld mood (not candy-bright), soft LOW-contrast tonal variation, tiny soft blended tufts (NOT big chunky high-contrast clumps), NO outline / lineless base ground, gentle soft shading, edge-to-edge, no border.
```
- `[terrain]=lush grass` (warm-moss `#2d4720..#8fb267`)  ·  `[terrain]=warm dirt` (`#513928..#bc987c`).

**파이프라인 (구현 완료 — 하네스):**
1. 원본 `_staging_tile16/raw/{grass_a,grass_b,grass_c,dirt}.png` → 글루 → `{name}_field.png`(128²).
2. `tools/tile16_experiment.gd` — 필드를 **월드좌표 모듈로 타일링**(단위 셀 반복 아님·격자 반복 0) +
   굽은 흙길 + **지터 디더 유기적 경계** + **4× nearest 업스케일**(온스크린 64px = 스타듀 정합, 거짓 NO-GO 방지).
3. ⚠️ **렌더 스케일 유효성:** 4× 렌더로 owner 스타듀 스크린샷(≈64px/타일)과 물리 크기를 맞춘다.
4. `./run_tile16.sh` → `tools/tile16_experiment.png` → owner가 스타듀 레퍼런스(2026-07-04 제공)와 나란히 → GO/NO-GO.

**클럼프 모델(확정, Q5):** A(베이스 변종)→**타일** / B(풀 클럼프 = grass_b/c)→**스캐터 프롭**(`_build_ground_details`, 작게·부드럽게) / C(흙 전이)→**Wang 타일**. 실험 베이스엔 클럼프 미포함.

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
- **stump_log** (64×32, 통과·장식) — `a fallen tree stump and log on its side, weathered grey-brown deadwood, visible ring on the cut face, muted bark` · `cool blue-violet slate`. ※debris 아님(치울 수 없음). **★SUPERSEDED(2026-07-04):** owner가 이 1종 드롭인 대신 **PixelLab 통나무 5종 재설계**로 전환 — [prop-regen-roster.md §5.3](./prop-regen-roster.md) 참조(긴/짧은/세워진/대각2, `PROP_LOG_*`).

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

---

## 10. ★[S2-T9] 나루 마을 환경 아트 — 신규 4종 스펙카드 (owner Gemini 무수정 교체 대기)

> **상태:** PixelLab 생성 + 후처리로 **인게임 배선 완료**(2026-07-27). 아래 카드는 [ADR-0048] 원칙
> ("Claude 제작물 = Gemini 고품질본으로 무수정 교체 가능")에 따른 **교체 큐**다. 파일명·크기·앵커·
> 팔레트 규약이 이 카드에 잠겨 있으므로, owner가 같은 규격으로 다시 뽑아 덮어쓰면 **코드 0줄 수정**으로
> 반영된다(`game/tools/make_naru_art.py`가 raw→규격 정규화를 담당 — raw만 갈아끼워도 된다).
>
> **후처리 글루:** [`game/tools/make_naru_art.py`](../../game/tools/make_naru_art.py)
> **raw 보관:** `game/assets/terrain16/naru_raw/`(지형) · `game/assets/**/*_raw.png`(프롭·facade)

### 10.1 벚꽃 나무 `village_tree_cherry`

```
파일: game/assets/props/village_tree_cherry.png
크기: 64×128 (2×4칸, 32-native / ADR-0050)   앵커: bottom-center(발치 = 프레임 하단 flush)
충돌: 밑행 1칸만 SOLID(TREE_FOOT_H) · 수관 통과 O + occlusion fade — FOOT_BAR_PROPS·FADE_PROPS
그림자: 굽지 않는다(PROP_SHADOW_SET 코드 타원이 발치에 깖 — asset-ruleset §11)
정체성: 나루 마을 전용. 안식 농원의 저승 봄나무(침엽 TREE_A·활엽 TREE_B)와 **수종이 달라야** 구역이 갈린다.
PROMPT: a single cherry blossom tree, dark slender twisted trunk with two low branches, wide soft
  canopy of pale dusty-pink blossoms in distinct clumps, top-down 3/4 overworld view (Stardew Valley
  angle), centered on a transparent background, bottom-center anchored, standing upright, no baked
  ground shadow, only its own form self-shadow. + [§1 STYLE 공통 꼬리]
후처리: bbox 크롭 → 발치 bottom-flush 재배치 · 밑둥(V<0.42)은 자주빛→목재 갈색 hue 이동 ·
        수관은 채도 ×0.72·명도 ×0.92(캔디 억제, 벚꽃 분홍 정체색은 보존) · 하드 알파
```

### 10.2 돌담 `village_stone_wall`

```
파일: game/assets/props/village_stone_wall.png
크기: 32×32 (1×1칸)   앵커: farm_fence 관례(가로 0..32 꽉 참 · 발치 y=28)
충돌: 풀타일 SOLID(울타리 계보 — 경계벽). 광장 남북 테두리에만 두르고 동서·남북 진입은 비운다.
PROMPT: a low dry-stone garden wall, one straight run of rounded irregular grey fieldstones stacked
  two courses high with a flat capstone row on top, spanning the full width edge to edge so a row of
  them joins into one continuous wall, transparent above and below, no end posts, no gate.
  + [§1 STYLE 공통 꼬리] + 슬레이트 청회(§16 저승 객체 램프)
후처리: 좌우 edge-extend(가로 런 이음매 제거) · 발치 정렬 · 하드 알파
★재생성 시 개선점: 현행본은 "벽돌 벽 스와치"에 가깝다 — 둥근 야면석·불규칙 크기를 더 밀 것.
```

### 10.3 자갈 광장 base 필드 `cobble_field`

```
파일: game/assets/terrain16/single_source/cobble_field.png
크기: 128×128 seamless(단일출처 규약 — 런타임 ×2=256이 월드 타일링 주기)   색수: 53(ADR-0057 ~45 목표대)
배선: 지면 표면 종류 5 · 구역 프로파일 "plaza_rects"(순수 시각 — _grid·충돌·세이브 불변)
생성: create_tiles_pro(square_topdown / tile_size 32 / top-down / outline_mode=segmentation / seed 7)
  PROMPT: 1). old worn flagstone paving: flat irregular grey-tan stone slabs of clearly different
    sizes and shapes fitted together like a jigsaw puzzle, thin dark earth gaps between them, seen
    from straight above, no repeating grid, no bricks, no stripes 2). the same flagstone paving with
    a few slabs missing showing warm tan dirt beneath 3). warm tan packed dirt, plain 4). warm tan
    packed dirt with scattered small pebbles
후처리: 판석 4변주 + 마모 2변주를 결정적 해시로 4×4 배치(32px 반복 격자 소거) · flip 금지(거울쌍
        나비 무늬) · 채도 ×0.90·명도 ×0.97(§9 살짝 가라앉힌 warm)
★폐기 기록: create_topdown_tileset 2회 시도 전부 실패 — 세로 줄무늬 격자(v1)·기계적 벽돌 격자(v2).
  [ADR-0057] "확산 모델 지형 배제"와 별개로, **topdown_tileset도 포장면에선 격자를 뽑는다**.
  포장·판석류는 tiles_pro segmentation + 변종 모자이크가 정답(이 카드가 그 선례).
```

### 10.4 다리 목판 base 필드 `plank_field`

```
파일: game/assets/terrain16/single_source/plank_field.png
크기: 128×128 seamless   배선: 지면 표면 종류 6 · 구역 프로파일 "plank_rects"(다리 데크 + 남단 부두)
생성: create_topdown_tileset(lower="dark teal river water" / upper=아래 / 32px / high top-down /
      low detail / selective outline / basic shading / transition_size 0) → 순수 upper base 타일 추출
  upper PROMPT: wooden bridge deck of weathered grey-brown planks laid crosswise side by side,
    visible plank seams, flat walkable surface, no railing, no border
후처리: 90° 회전(판자가 남북 통행 방향에 **직교** — 실제 교량 데크 문법) · 자홍/보라 기미를 목재
        갈색으로 hue 이동(blend 0.85) · 채도 ×0.80 · 32→128 self-tile
★재생성 시 개선점: 현행본은 판자 *끝단(이음매)*이 없는 무한 줄무늬다. 널판 마디를 넣으면 더 다리답다.
```

### 10.5 곁들여 처리한 기존 에셋

```
cafe_ext.png — 알파가 전부 255고 배경이 #8c8681 회색으로 구워져 있어 마을에 서면 건물 둘레에 회색
  사각형이 떴다([asset-ruleset §1.3] "건물 base = 투명" 위반). 테두리 flood-fill로 배경만 걷어내고
  원본은 cafe_ext_raw.png로 백업(idempotent). 29,347px 투명화 — 재생성 아님, 트림만.
  ★owner가 cafe_ext를 재생성할 땐 **배경을 투명으로** 뽑을 것(그러면 이 트림 자체가 불필요).
```

---

## 11. ★[S2-T10] 나루 마을 아트 패스 2 — 건물 외관·NPC 6종 스펙카드 (owner Gemini 무수정 교체 대기)

> **상태:** PixelLab 생성 + 후처리로 **인게임 배선 완료**(2026-07-27). §10과 같은 [ADR-0048] 교체
> 큐다 — owner가 같은 파일명·크기로 다시 뽑아 `*_raw.png`만 덮어쓰면 **코드 0줄 수정**으로 반영된다.
>
> **후처리 글루:** [`game/tools/make_naru_art2.py`](../../game/tools/make_naru_art2.py)
> **raw 보관:** `game/assets/buildings/*_raw.png` · `game/assets/characters/neo_raw/` ·
> `game/assets/characters/mochi_raw.png` · `game/assets/portraits/neo_raw.png`
>
> **이 패스로 나루 마을에 그레이박스 건물이 0이 됐다** — 야외 16채 전부 외관 아트를 갖는다.
> 그 짝으로 `main._VILLAGE_GREYBOX_RECTS`가 비었고 "만물상"·"주민 집 N" 라벨을 뗐다(외관으로 식별).

### 11.0 공통 규약 (건물 4종)

```
[asset-ruleset §2/ADR-0036] 정면 facade · 남향 문 · 박공(gable) 지붕 + **윗면 슬랩 노출 필수**
  (정면 삼각형만 있고 윗면 0이면 리젝). 생성 파라미터 view="low top-down".
[§1.1] 광원 프롬프트 세트 그대로: light source from top-left (NW), distinct directional
  step-shading, 1px highlight on top and left edges, crisp dark shadows to bottom-right (SE),
  2-3 color values max, no smooth gradients.
[§1.3] **base 투명 필수** — 지면·잔디를 굽지 말 것(접지 그림자는 엔진이 런타임에 깐다).
[§3] 앵커 = bottom-center(`_blit_facade_anchored`) — art 바텀 = footprint 하단 경계.
★치수 불변식: **아트 폭 = footprint 폭 정확히**, 아트 높이 ≥ footprint 높이(지붕은 위로 솟음).
  PixelLab은 캔버스 대비 콘텐츠 여백이 생성마다 0.80~0.96로 흔들려 캔버스로는 못 맞춘다 →
  글루 `fit_facade()`가 half-res(16논리px) 격자에서 NEAREST로 맞춘 뒤 ×2(=§0.1 2px 청키 보장).
  **그래서 raw는 여백이 있어도 된다** — 콘텐츠 비율만 대략 맞으면 글루가 규격에 앉힌다.
```

### 11.1 만물상 외관 `store_ext`

```
파일: game/assets/buildings/store_ext.png   (raw: store_ext_raw.png)
크기: 192×160 = STORE_EXT_RECT Rect2i(58,14,6,5)와 1:1   문: 하단 정중앙 2칸(x60·61 = STORE_EXT_DOOR)
배선: main._draw_facade_store() — NARU_VILLAGE 드로우 분기
생성: create_map_object(120×108 / low top-down / medium detail / basic shading / single color outline)
  PROMPT: Korean underworld general store shop building, front elevation facade, wide and low shop.
    Hanok tiled gable roof (triangular pitch) with a visible flat roof-top slab receding behind the
    ridge so the roof depth is seen from slightly above. Muted slate blue-grey roof tiles, warm
    honey-brown wood plank walls, a wide double wooden sliding door dead center at the bottom of the
    front wall, a hanging shop sign board above the door, two small paper lanterns, stacked crates and
    clay jars beside the door. + [§1.1 광원 세트] + 배경 투명·지면 금지
후처리: fit_facade(6,5) → 채도 ×0.88·명도 ×0.96(§9 저승 muted 소폭)
★리젝 기준: **간판(sign board)이 없으면 재생성** — 점포임을 읽히게 하는 유일한 요소다(생성 3회 중
  간판 있는 판본을 골랐다). 기와 박공 + 윗면 슬랩 노출은 §11.0 공통 필수.
```

### 11.2 주민 집 공용 변주 `village_house_a` / `_b` (한옥 재도색 2종)

```
파일: game/assets/buildings/village_house_a.png · village_house_b.png
크기: 각 128×128 = 주민 집 4×4 풋프린트와 1:1
출처: **생성 0** — 기존 `miho_house_ext.png`(한옥)의 지붕 hue만 돌린 재도색이다
  ([residents.md] "기존 집 에셋 재사용 → 본체 제작 시 외관 재도색", [ADR-0014] 점진 추가 비용 방어).
  a = 따뜻한 테라코타 기와(hue 18°, 채도 ×0.75) · b = 이끼 청록 기와(hue 150°, 채도 ×0.50)
후처리: 지붕 hue 밴드(195~255°)와 처마밑 호박 밴드(5~30°)를 **원본 hue 기준으로 한 번에** 분기
  (순차 적용하면 옮긴 지붕이 호박 밴드에 재차 걸려 테라코타가 올리브로 뭉개진다) → fit_facade(4,4)
★owner 교체 시: 누가 사는 집인지는 **아직 미배정**이다([ADR-0060] 결정 2 "배정은 본체 제작 시").
  캐릭터색을 넣지 말 것 — 본체 제작 때 그 캐릭터 전용 재도색으로 **한 채씩** 교체하는 것이 계획이다.
```

### 11.3 주민 집 초가 변주 `village_house_c` / `village_house_wide`

```
파일: game/assets/buildings/village_house_c.png(128×128) · village_house_wide.png(160×144)
      (raw 공용: village_cottage_raw.png — 한 raw에서 4칸·5칸 두 폭을 굽는다)
크기: c = 4×4 풋프린트 1:1 / wide = 5×4 풋프린트(RESIDENT_HOUSE_RECTS[0]) 폭 1:1·높이 +16 오버행
배선: main._draw_facade_resident_houses() — 폭 5 이상이면 wide, 아니면 [a,b,c] 고리를 index로 순환
생성: create_map_object(89×84 / low top-down / medium detail / basic shading / single color outline)
  PROMPT: small Korean village cottage house, front elevation facade, wide and low. Straw thatched
    hipped roof with a visible flat roof-top slab receding behind the ridge so the roof depth is seen
    from slightly above. Warm ochre straw roof, pale clay plaster walls with dark timber posts, a
    single wooden plank door dead center at the bottom of the front wall, one small paper window on
    each side of the door glowing warm amber, a low stone foundation strip. + [§1.1] + 배경 투명
후처리: fit_facade(4,4) / fit_facade(5,4) → 채도 ×0.88·명도 ×0.96
```

### 11.4 네오 스프라이트 `neo` (만물상 점주 — 상주 정지 NPC)

```
파일: game/assets/characters/neo.png   (raw: characters/neo_raw/{south,east,north,west}.png)
크기: 80×320 = 프레임 80×80 · **1열**(정지 rotation) × 4행(down/up/right/left)
  ★상주 NPC는 워크 시트 frame0이 아니라 **rotation idle**을 쓴다([p2.0-spike §10.12] 미호 교훈 —
   워크 첫 프레임은 스트라이드라 서 있어야 할 NPC가 걷는 듯 보인다).
배선: neo.gd `CharSprite.make("res://assets/characters/neo.png")` — 이미 있던 훅, 파일만 채웠다
생성: create_character(mode=standard / n_directions=4 / **size=44** / low top-down /
      selective outline / basic shading / high detail /
      proportions {"type":"custom","head_size":1.5,"arms_length":0.75,"legs_length":0.9,
                   "shoulder_width":0.72,"hip_width":0.75})
  PROMPT: chibi porcelain automata doll shopkeeper standing straight, off-white glazed porcelain
    skin, smooth pale porcelain head with a large brass wind-up key sticking straight up out of the
    top of the head, two small round dark dot eyes and a tiny calm mouth, thin dark seam lines at the
    shoulder and elbow ball joints, dark slate grey buttoned shopkeeper vest with a small brass gear
    on the chest, dark trousers, arms straight down at the sides, slim chibi build, beautiful clean
    face, large evenly-spaced eyes, muted underworld palette
★★ size=44인 이유(문서 정정): [ADR-0012]/스파이크 §10.8은 "size=56, 콘텐츠 ~58~70px"이라고 적었지만
  **출하된 캐스트 5종 실측은 41~46px**(mel 43·okja 46·bana 43·miho 42·player 41, 전부 발치 y=74)이다.
  size=56으로 뽑으면 신규 NPC만 30% 커져 나란히 섰을 때 따로 논다 → **size=44가 실측 정합값**이다.
  신규 캐릭터는 이 값에서 출발할 것(문서의 56은 stale).
후처리(글루가 정체성 보정 — [p2.0-spike §10.11] "face 디테일은 프롬프트보다 후처리가 확실"):
  ① 살빛(h 10~60°)을 **백자 오프화이트**(233,231,226)로 치환(명도 계조 보존 = 계단식 음영 유지)
  ② 머리 꼭대기 중앙에 **태엽 키**(놋쇠 세로 줄기 + 가로 챙) 2px 블록 스탬프
  — PixelLab standard가 3회 시도 전부 "살빛 민머리 + 키 없음"으로 구웠다(키가 44px 스케일에 안 박힘).
★owner 교체 시: 위 ①②가 프롬프트로 나오면 후처리를 지워도 된다. 백자·태엽 키·이모티콘 눈은
  [residents.md §2.2]가 정한 **정체성 불가침 3요소**다.
```

### 11.5 모찌 스프라이트 `mochi` (슬라임 — 걷는 T1 주민)

```
파일: game/assets/characters/mochi.png   (raw: characters/mochi_raw.png, 32×32 한 장)
크기: 80×320 = 프레임 80×80 · 1열 × 4행. 콘텐츠 25×26(≈0.8칸 — 사람형 16×32와 달리 납작·가로가 넓다)
배선: mochi.gd `CharSprite.make(...)` — 이미 있던 훅, 파일만 채웠다
생성: create_map_object(32×32 / low top-down / low detail / basic shading / single color outline)
  ※ 비인간이라 create_character(휴머노이드 골격)를 안 쓴다. 32px 목표라 half-res 생성 불가 →
    [§0] "≤32px 소형은 동일 크기 생성 후 ÷2→×2 청키화" 경로.
  PROMPT: tiny translucent emerald green jelly slime creature, a squat flattened rounded blob wider
    than it is tall with a flat pressed top, NOT a pointed teardrop dome, two simple dark dot eyes
    and a tiny short smiling dot mouth on the front, a small off-white round rice cake resting on top
    of its head, glossy highlight on the upper left. + [§1.1] + 배경 투명
후처리: 방향 4행을 **얼굴만 옮겨** 만든다 — 덩이 실루엣·NW 하이라이트·머리 위 찹쌀떡은 제자리
  (좌우 미러를 쓰면 [§1] 광원이 뒤집힌다). north=얼굴 숨김(뒷모습) · east/west=얼굴 ±3px 이동.
  얼굴 픽셀 판정은 **얼굴 띠**(콘텐츠 x 20~80%, y 50~80%) 안의 어두운 내부 픽셀 + 분홍 볼홍조로
  한정한다(전역으로 "어두운 픽셀"을 잡으면 덩이 내부 윤곽·찹쌀떡 밑그늘까지 얼굴로 오인한다).
★리젝 기준([residents.md] 명시): **드래곤퀘스트 슬라임 실루엣 금지** — 뾰족한 물방울 돔 + 넓은
  밑동 + 큰 눈 + 웃는 큰 입 조합을 피할 것. 머리 위 찹쌀떡이 실루엣 꼭대기를 갈라 주는 핵심 장치다.
★미완: 걷기 애니 없음(정지 1프레임 × 4방향). 모찌는 스케줄이 있어 실제로 이동하는 첫 주민이라
  후속에서 워크 시트가 오면 열이 늘어난다(char_sprite가 열 수를 파일에서 읽으므로 코드 무수정).
```

### 11.6 네오 대화 초상화 `portraits/neo`

```
파일: game/assets/portraits/neo.png   (raw: portraits/neo_raw.png 160×160)
크기: 320×320 투명 PNG([portrait-spec-card.md] §4 출력 규격) — 슬롯 124×124 논리(×1.5=186px)
배선: main `r_neo.portrait_stem = "neo"`(""→"neo") — 주민 레코드 한 줄
생성: create_portrait_character(direction=character_to_portrait / low top-down / result_size=160)
  입력 = 위 11.4 네오 south 프레임(백자 보정·태엽 키 포함) → 정체성이 스프라이트에서 그대로 승계된다
후처리: 하드 알파 → ×2 nearest(160→320)
★★ **화풍 불일치 — 교체 1순위:** 기존 4인(미호·멜·바나·옥자)은 owner-Gemini **소프트 일러스트**
  버스트인데 이건 **도트 버스트**다. "얼굴 없음"을 메우는 스톱갭으로 넣었을 뿐이니, owner가
  [portrait-spec-card.md] §1 헤드&체스트 버스트 규격으로 다시 뽑아 덮으면 된다.
★미완: **표정 5종 없음**(`neo_talk/_smile/_shy/_sad/_surprised`). 네오 대사의 [smile]/[shy] 태그는
  `_set_portrait`의 누락 폴백을 타 기본 stem으로 떨어진다(대사·코드 무개정으로 나중에 추가 가능).
```

---

## 12. ★[S3-T9] 삼도천·황천해 아트 패스 1 — 지형·건물·프롭 9종 스펙카드 (owner Gemini 무수정 교체 대기)

> **상태:** PixelLab 생성 + 후처리로 **인게임 배선 완료**(2026-07-28). §10·§11과 같은 [ADR-0048] 교체
> 큐다 — owner가 같은 파일명·크기로 다시 뽑아 `*_raw.png`만 덮어쓰면 **코드 0줄 수정**으로 반영된다.
>
> **후처리 글루:** [`game/tools/make_s3_art.py`](../../game/tools/make_s3_art.py)
> **raw 보관:** `game/assets/buildings/{museum,fishshop}_ext_raw.png` ·
> `game/assets/props/{rowboat,pier_post,beach_shell,beach_seaweed}_raw.png` ·
> `game/assets/terrain16/s3_raw/sand_tile_raw_*.png`
> **육안 하네스:** `godot --headless --path game -s res://tools/fishing_region_dump.gd`
> → `game/tools/{samdo,hwang}_dump.png`
>
> **이 패스로 삼도천·황천해에 그레이박스 건물이 0이 됐다** — 외관이 붙어 "혼백관"·"생선가게" 라벨을 뗐다
> (S2-T10 마을 컨벤션과 같은 판단: 도트 외관으로 식별되면 라벨 없음).

### 12.0 공통 규약

```
건물 2종은 §11.0 공통 규약을 그대로 따른다(정면 facade · 남향 문 · 박공 지붕 + 윗면 슬랩 노출 ·
  base 투명 · bottom-center 앵커 · 아트 폭 = footprint 폭 정확히 · fit_facade가 규격에 앉힘).
★[§1.3] 추가 리젝 기준: **지면을 구워 오면 안 된다.** PixelLab이 건물 밑에 모래/흙 타원을 굽는 일이
  잦아(생선가게 1차 판) 글루에 `trim_baked_ground()`(바깥에서 실측 지면 팔레트 ±34 flood-fill)를 뒀다.
  구운 지면은 ㉠실제 지형이 안 비치고 ㉡bbox가 아래로 늘어 **문 정렬이 밀린다**(치명).
★리젝 기준: **3/4 각도 금지.** 생성물이 옆벽이 보이는 반-아이소로 나오면 재생성한다
  (1차 생선가게가 그랬다 — 프롬프트에 "flat front elevation only, viewed straight on from the front"
   를 명시하면 정면으로 나온다).
```

### 12.1 혼백관 외관 `museum_ext`

```
파일: game/assets/buildings/museum_ext.png   (raw: museum_ext_raw.png 140×126)
크기: 224×200 = MUSEUM_EXT_RECT Rect2i(6,8,7,6) 폭 1:1(224) · 높이는 지붕이 위로 솟음
배선: main._draw_facade_museum() — SAMDOCHEON 드로우 분기
생성: create_map_object(140×126 / low top-down / medium detail / basic shading / single color outline)
  PROMPT: Korean underworld memorial shrine hall for the souls of the dead, front elevation facade,
    solemn and wide. Hanok tiled gable roof (triangular pitch) with a visible flat roof-top slab
    receding behind the ridge so the roof depth is seen from slightly above. Dark slate roof tiles,
    pale grey stone walls with dark timber posts, a wide double wooden door dead center at the bottom
    of the front wall, a carved stone name plaque mounted above the door, two stone soul lanterns
    flanking the doorway glowing faint pale blue, a low stone foundation strip.
    + [§1.1 광원 세트] + 배경 투명·지면 금지
후처리: trim_baked_ground → fit_facade(7,6) → 채도 ×0.88·명도 ×0.96
★정체성 기준: **장사가 아니라 사당**이다 — 간판(상호) 대신 **석조 현판**, 문 양옆 **석등**,
  어두운 슬레이트 기와. 만물상·생선가게와 톤이 겹치면(나무 간판·등롱) 재생성.
```

### 12.2 생선가게 외관 `fishshop_ext`

```
파일: game/assets/buildings/fishshop_ext.png   (raw: fishshop_ext_raw.png 140×126)
크기: 224×192 = FISHSHOP_EXT_RECT Rect2i(8,20,7,6) 폭 1:1
배선: main._draw_facade_fishshop() — HWANGCHEONHAE 드로우 분기
생성: create_map_object(140×126 / low top-down / medium detail / basic shading / single color outline)
  PROMPT: Korean underworld seaside fish shop building, flat front elevation only, viewed straight on
    from the front so no side wall and no perspective is visible, wide and low shop. Hanok tiled gable
    roof ... Weathered blue-grey roof tiles, salt-bleached driftwood plank front wall, a wide double
    wooden sliding door dead center at the bottom of the front wall, a hanging wooden shop sign board
    above the door with a fish silhouette carved on it, fishing nets draped on the front wall, stacked
    crates and a barrel beside the door, two small paper lanterns.
    + [§1.1] + 배경 투명·지면 금지
후처리: trim_baked_ground(673px 제거) → fit_facade(7,6) → 채도 ×0.88·명도 ×0.96
★리젝 기준: **물고기 현판이 없으면 재생성**(§11.1 만물상 간판 기준 동형 — 점포임을 읽히게 하는 요소).
```

### 12.3 백사장 base 필드 `sand_field` / `sand_wet_field`

```
파일: game/assets/terrain16/single_source/sand_field.png · sand_wet_field.png (각 128×128 seamless)
배선: main._bf_sand / _bf_sand_wet — 표면코드 7(모래) · 프로파일 sand_rects/shore_sand가 켠다
생성: create_tiles_pro(square_topdown / top-down / 32px / segmentation, seed 3901)
  PROMPT: 1). smooth dry pale beach sand 2). beach sand with scattered tiny pebbles
          3). beach sand with faint wind ripple marks 4). damp darker packed sand near the waterline
후처리: **팔레트만 취하고 구조는 절차 합성**(3옥타브 주기 노이즈 seamless + 미세 그레인 + 극희소 모래알)
★★ 왜 타일을 그대로 안 붙였나(폐기 기록·재시도 금지):
  자갈 광장(§10.3 cobble_field) 문법대로 32px 변주 12장을 4×4로 깔아 봤고 **육안 리젝**했다 —
  변주마다 모티프(물결선·해칭·다이아 메시)가 타일 **중앙에** 몰려 있어 배치가 통째로 **32px 격자**로
  읽힌다(타일 평균 레벨을 맞춰 톤 체커를 지워도 모티프 격자는 남는다). 판석은 원래 격자 물건이라
  통했지만 모래는 무정형이라 안 통한다. 기준선 `dirt_field`(무정형 저주파 얼룩)의 구조를 맞추려면
  절차 합성이 정배다(`make_terrain_fields.py`의 soil·water 선례와 같은 층위).
★ 진폭을 작게 잡는다 — 백사장이 9행 × 전 폭이라 결이 세면 필드 주기(256px = 8칸)가 반복 얼룩으로 뜬다.
★ `sand_wet_field`는 **물가 테두리 전용**이다. 손그림 4_0 shore 마스크의 테두리 클래스는 연못·강용
  **붉은 흙빛** 반사라, 백사장에 그대로 쓰면 바다 경계에 **붉은 줄**이 그어진다(1차 덤프 육안).
  owner 교체 시 두 장의 **톤 차이(젖은 쪽이 한 단 어둡고 채도 조금 높음)** 를 유지할 것.
```

### 12.4 나룻배 `rowboat`

```
파일: game/assets/props/rowboat.png (64×96 = 2×3칸)   (raw: rowboat_raw.png)
배선: PROP_ROWBOAT — layout.json SAMDO_OUTDOOR(12,28)·HWANG_OUTDOOR(34,22)
생성: create_map_object(64×96 / high top-down / medium detail / basic shading / single color outline)
  PROMPT: small old wooden rowboat ferry beached on sand, seen from above at an angle, empty hull with
    two bench seats and a pair of oars laid inside, weathered warm brown planks, dark waterline stain,
    a coil of rope at the bow. + [§1.1] + 배경 투명·물/모래 금지
후처리: 발치 bottom-flush(64×96 프레임) → 채도 ×0.85·명도 ×0.95
★**비-SOLID**다(장식만). 삼도천·황천해는 동선이 한 줄 스파인(잔교·부두)뿐이라 물가에 충돌을 얹으면
  flood-fill 도달성이 깨질 위험이 크다. 물리적 가둠이 필요해지면 그때 SOLID_PROPS로 승격한다.
```

### 12.5 잔교 말뚝 `pier_post`

```
파일: game/assets/props/pier_post.png (32×32 = 1×1칸)   (raw: pier_post_raw.png)
배선: PROP_PIER_POST — 잔교(x28) 양옆 물 위 x27/x29에 세 쌍(삼도천)·네 쌍(황천해)
생성: create_map_object(32×32 / low top-down / medium detail / basic shading / single color outline)
  PROMPT: single short wooden mooring piling post standing in water, weathered dark timber stump with
    a flat sawn top, a rope loop wrapped near the top, green algae and barnacles at the base.
    + [§1.1] + 배경 투명·물 금지
후처리: 발치 bottom-flush → 채도 ×0.85·명도 ×0.95
★역할: 1칸 폭 잔교가 "물 위에 홀로 뜬 판자"로 보이던 것을 **말뚝에 얹힌 다리**로 읽히게 한다
  (통행 폭을 넓히지 않고 부피감만 준다 — 충돌·동선 불변).
```

### 12.6 백사장 지면 데칼 `beach_shell` / `beach_seaweed`

```
파일: game/assets/props/beach_shell.png · beach_seaweed.png (각 32×32 프레임, 콘텐츠 폭 16px)
배선: GD_SHELL / GD_SEAWEED — `_GD_BEACH` 테이블(모래 표면 전용 스캐터, 프로파일 beach_density)
생성: create_map_object(32×32 / high top-down / low detail / basic shading / selective outline)
  조개: tiny flat cluster of three pale seashells lying on sand, viewed straight from above, very
        small and flat decal, one spiral shell and two clam shells, cream and faint pink.
  해초: tiny flat tangle of dried dark seaweed washed up on a beach, viewed straight from above,
        very small and flat decal, muted olive and dusty brown strands.
후처리: 콘텐츠 폭 16px로 축소 + 발치 정렬(기존 ground_pebble 14×6 · ground_weed_dry 18×12 관례) →
  조개 채도 ×0.80·명도 ×0.94 / 해초 채도 ×0.72·명도 ×0.92
★모래 위엔 풀 tuft·나뭇가지 계보를 **일절 뿌리지 않는다**(해변이 잔디밭으로 읽힌다). 이 둘 + 잔돌
  (GD_PEBBLE)·슬레이트(GD_STONE2)만으로 백사장 결을 낸다.
★해초는 현재 판본이 "검은 성게"처럼 읽히는 기미가 있다 — 교체 1순위(가닥이 옆으로 눕는 실루엣이 정답).
```

---

## 13. ★[S3-T10] 낚시 아트 패스 2 — 아이템 아이콘 32종·뱃사공·릴 격투 HUD 스펙카드 (owner Gemini 무수정 교체 대기)

> **상태:** PixelLab 생성 + 후처리로 **인게임 배선 완료**(2026-07-28). §10~§12와 같은 [ADR-0048] 교체
> 큐다 — owner가 같은 파일명·크기로 다시 뽑아 `*_raw.png`만 덮어쓰면 **코드 0줄 수정**으로 반영된다.
>
> **후처리 글루:** [`game/tools/make_s3_icons.py`](../../game/tools/make_s3_icons.py)
> **raw 보관:** `game/assets/fish/raw/*_raw.png`(21) · `game/assets/gear/raw/*_raw.png`(11) ·
> `game/assets/characters/boatman_raw/{south,north,east,west}.png` · `game/assets/portraits/boatman_raw.png`
> **육안 하네스:** `godot --path game -s res://tools/fishing_art_dump.gd`(★비-헤드리스 — GPU 실캡처)
> → `game/tools/s3_{inv_fish,inv_gear,inv_tackle,hud_wait,hud_bite,hud_fight,hud_burst,boatman,crabpot,portrait}.png`
>
> **이 패스로 낚시 슬라이스에 그레이박스 아이템 아이콘이 0이 됐다** — 어획물의 흰 박스 폴백,
> 낚싯대·태클·미끼의 색 박스, 게잡이통 실루엣이 전부 도트로 교체됐다.

### 13.0 공통 규약 (아이콘 32종)

```
크기: 전부 32×32 투명 PNG **32-native**([ADR-0050] — 축소본 금지). 슬롯이 통째로 늘려 그리므로
  콘텐츠는 후처리에서 32² 안에 **가운데 정렬**한다(여백이 한쪽에 몰리면 옆 슬롯과 눈금이 어긋난다).
생성: create_map_object(32×32 / medium detail / basic shading / **single color outline**)
  · 어획물·기어 = view "side"(옆모습이 실루엣을 가장 잘 낸다 — 스타듀 어획물 아이콘 문법)
  · 게잡이통·게·조개·소라 = view "high top-down"(바닥에 놓이는 물건)
공통 꼬리말(전 프롬프트에 붙임):
  centered on transparent background, no ground shadow, RPG inventory item icon,
  stardew valley pixel art, muted underworld palette, light from top-left
후처리: 하드 알파 → [§9] muted(채도 ×0.90 · 명도 ×0.97 — 프롭 0.85/0.95보다 **얕게**. 슬롯 안에서
  32종이 서로 구분돼야 하므로 정체색을 덜 누른다) → 32² 가운데 정렬
★리젝 기준 3(실제로 리젝하고 재생성한 것들):
  ① **흰 외곽선 금지** — 1차 전설 메기가 두꺼운 흰 테로 나와 [§1] 단일 외곽선 규약을 깼다.
  ② **분리된 조각 금지** — 낚싯대에 "a hook hanging from the tip"을 넣으면 모서리에 **떠 있는 파편**이
     생긴다. `one connected object with no floating separate pieces`를 넣고 갈고리 문구를 빼면 낫는다.
  ③ **뭉갠 형태 금지** — 32²에 디테일을 욱여넣으면(1차 안개무늬쏘가리) 진흙이 된다. "clean simple
     stout body shape" 같은 형태 지시를 넣어 재생성.
```

### 13.1 어획물 아이콘 21종 `fish/<id>.png`

```
파일: game/assets/fish/<어종 id>.png — id = FishCatalog 상수 = 아이템 id(파일명이 곧 배선)
배선: main.FISH_ICONS → `icons` dict 병합(핫바 `_setup_hotbar` · 인벤 `_setup_inv_frame`) +
  `_item_icon`(토스트). CAT_HARVEST라 `_draw_crop_tex`가 id로 바로 집는다(카테고리 분기 추가 0).
  ★ 릴 격투 HUD의 트랙 물고기도 **이 텍스처**를 쓴다(16×16 = 32²의 정확히 1/2).
목록(전부 "whole fish seen in side profile facing left" 고정 — 방향이 섞이면 슬롯이 어지럽다):
  강 8  넋붕어 pale ghostly crucian carp / 잿빛송사리 tiny ash-grey minnow killifish /
        여울넋피라미 slender river dace with a bold dark lateral stripe /
        초롱치 deep-sea lantern fish with glowing light spots and a lantern lure /
        상엿길잉어 plump bronze carp with barbels / 도깨비메기 goblin catfish with one blunt horn /
        안개무늬쏘가리 mandarin fish with three pale grey cloud blotches /
        먹빛장어 thick glossy black eel curved in a wide S
  바다 8 넋멸치 tiny silver anchovy / 은비늘청어 silver herring / 물마루가자미 flatfish flounder /
        혼불해파리 glowing translucent jellyfish bell with trailing tentacles /
        저녁놀도미 sea bream with dusty rose and sunset orange scales /
        삿갓오징어 squid whose mantle is shaped like a conical straw hat /
        물비늘농어 sea bass with cool grey-blue scales / 너울범치 bulky scorpionfish with a fanned spiny fin
  전설 2 검은여울 대메기 giant catfish, dark slate blue-grey, one large pale glowing eye /
        심연 만장어 ribbon eel with a pale cream banner-like fin like a funeral streamer
  통용물 3 넋게 pale ghostly crab (top-down) / 혼조개 ribbed clam shell / 잿빛소라 spiral conch shell
★정체성 기준: 저승 결은 **이름과 톤**이 지고 형태는 실존 어류를 따른다(도감이 아니라 인벤 아이콘 —
  16px로 줄어도 "무슨 물고기인지" 실루엣으로 읽혀야 한다). 발광 요소(초롱치·혼불해파리·전설 2종)만
  영혼빛 액센트를 허용한다.
★교체 시 유지할 것: **왼쪽을 보는 옆모습** · 32² 가운데 정렬 · 밝은 어종/어두운 어종의 대비
  (HUD 트랙 물빛 `#33454f` 위에서 어두운 어종이 안 묻히게).
```

### 13.2 낚시 기어 아이콘 11종 `gear/<id>.png`

```
파일: game/assets/gear/<기어 id>.png — id = GearCatalog 상수(+ crab_pot = ItemCatalog.CRAB_POT)
배선: main.GEAR_ICONS → `icons` dict 병합 + `_item_icon`. 카테고리별 슬롯 분기:
  · 낚싯대·태클 = CAT_TOOL(기존 텍스처 분기 재사용)
  · 미끼 = CAT_CONSUMABLE  · 게잡이통 = CAT_PLACEABLE  ← ★이 둘은 색 박스만 그리던 칸이라
    inv_frame·hotbar_hud `_draw_icon`에 **텍스처 우선 분기를 이번에 얹었다**(폴백은 남겨 둠).
  · ★게잡이통 텍스처는 **월드 설치물과 공유**한다(`_draw_crab_pots` — 상태 표식만 그 위에 얹힘).
낚싯대 4티어(★티어가 한눈에 오르는 게 이 넷의 존재 이유 — 같은 막대 4개면 실패다):
  T1 낡은 낚싯대  old worn bamboo pole, pale cracked shaft with node rings, cloth-wrapped grip
  T2 삼줄 낚싯대  dark wooden rod with a thick braided tan hemp rope grip and a coil of hemp line
  T3 놋쇠 낚싯대  polished wood shaft, three brass guide rings, a round brass reel at the grip
  T4 만장 낚싯대  glossy black lacquered shaft, gold bands, a crimson cloth banner tied near the tip
  ※ 넷 다 `lying diagonally from the lower left corner to the upper right corner` 고정(대각 통일).
미끼 3(실루엣이 서로 완전히 다르게 — 주머니 / 루어 / 부적):
  일반  coarse brown sackcloth pouch tied with twine, damp earth and two earthworms poking out
  유인  teardrop metal spoon lure in warm amber with a feather tuft and two treble hooks
  보장  folded pale yellow ritual paper talisman with dark purple ink, knotted with red string
태클 3(공 / 더미 / 찌 — 셋의 실루엣이 겹치지 않게):
  코르크 보버  ball shaped cork float in warm apricot tan with a metal eyelet at the bottom
  납추        three dull grey teardrop lead sinker weights in a little pile
  퀄리티 보버  egg shaped float, bright orange top half and cream bottom half, glossy lacquer
게잡이통  woven bamboo crab trap basket, squat barrel cage of pale split bamboo strips,
          dark round funnel opening on the front, rope handle loop on top (high top-down)
★owner 교체 시: 낚싯대 4종은 **한 장에 몰아 그리지 말고 각각** 32²로. 슬롯에서 나란히 봤을 때
  T1→T4로 재료가 (대나무 → 삼 → 놋쇠 → 흑칠+붉은 천) 오르는 게 읽히면 성공이다.
```

### 13.3 뱃사공 스프라이트 `boatman`

```
파일: game/assets/characters/boatman.png  (raw: characters/boatman_raw/{south,east,north,west}.png)
크기: 80×320 = 프레임 80×80 · **1열**(정지 rotation) × 4행(down/up/right/left) — §11.4 네오와 동형
배선: boatman.gd `CharSprite.make("res://assets/characters/boatman.png")` — 이미 있던 훅, 파일만 채웠다
생성: create_character(mode=standard / n_directions=4 / **size=44** / low top-down /
      selective outline / basic shading / high detail /
      proportions {"type":"custom","head_size":1.5,"arms_length":0.75,"legs_length":0.9,
                   "shoulder_width":0.72,"hip_width":0.75})
  ★ size=44 = 출하 캐스트 실측 정합값(§11.4 문서 정정 참조 — ADR-0012의 56은 stale).
  PROMPT: chibi underworld ferryman boatman standing straight, wearing a very wide conical woven
    straw hat pulled low over the eyes, only two small dark dot eyes visible under the hat brim,
    a dark teal-green straw rain cape over the shoulders, a plain dark indigo tunic and trousers
    underneath, a rope belt at the waist, holding a long wooden oar upright at his right side with
    both hands, calm quiet posture, slim chibi build, beautiful clean face, large evenly-spaced
    eyes, muted underworld palette
후처리: 하드 알파 → muted(채도 ×0.94·명도 ×0.98 — 캐스트와 나란히 서므로 아주 얕게) →
  80² 프레임 발치정렬(**y=74**) → ★**east/west 프레임에 노 스탬프**
★★ 노 스탬프가 왜 있나(네오 태엽 키와 같은 사례): PixelLab standard가 south/north엔 노를 굽고
  **east/west엔 안 굽는다**. 노는 삿갓과 함께 뱃사공의 **정체성 실루엣 2요소**(boatman.gd 그레이박스가
  정한 것)라 빠지면 옆모습이 "삿갓 쓴 행인"이 된다 → 뒤쪽 어깨에 자루+노깃을 손으로 얹는다.
  ★ 실루엣에 **붙여** 세울 것(2px라도 떼면 옆에 세워 둔 말뚝으로 읽힌다 — 1차 판 육안 리젝).
★owner 교체 시: ①삿갓 ②노 ③짙은 물빛 도롱이가 정체성 3요소다(4방향 전부에 노가 있으면 후처리를
  지워도 된다). ★[CONTEXT] 본명·종은 서랍이라 얼굴은 특징 없는 중년 사공이면 족하다.
★미완: 걷기 애니 없음(정지 1프레임 × 4방향). 뱃사공은 상시 한 자리라 당장 필요 없다
  (char_sprite가 열 수를 파일에서 읽으므로 워크 시트가 오면 코드 무수정으로 늘어난다).
```

### 13.4 뱃사공 대화 초상화 `portraits/boatman`

```
파일: game/assets/portraits/boatman.png  (raw: portraits/boatman_raw.png 128×128)
크기: 256×256 투명 PNG — 슬롯이 KEEP_ASPECT_COVERED로 앉히므로 네이티브 크기는 자유롭다
배선: main `r_boatman.portrait_stem = "boatman"`(""→"boatman") — 주민 레코드 한 줄
생성: create_portrait_character(direction=character_to_portrait / low top-down / **result_size=128**)
  입력 = 위 13.3 뱃사공 south 프레임(노 스탬프 전) → 정체성이 스프라이트에서 그대로 승계된다
  ※ result_size=160은 character_to_portrait에 스타일이 없어 거부된다(128이 상한 실측).
  ※ 입력 base64가 길면 MCP가 조용히 잘라 먹는다 — **옥트리 20색 양자화 PNG**로 줄여 넣을 것.
후처리: 하드 알파 → ×2 nearest(128→256)
★★ **화풍 불일치 — 교체 1순위:** 기존 4인(미호·멜·바나·옥자)은 owner-Gemini **소프트 일러스트**
  버스트인데 이건 §11.6 네오와 같은 **도트 버스트**다. "얼굴 없음"을 메우는 스톱갭이니 owner가
  [portrait-spec-card.md] §1 헤드&체스트 버스트 규격으로 다시 뽑아 덮으면 된다.
★미완: 표정 5종 없음(`boatman_talk/_smile/_shy/_sad/_surprised`). 대사의 [smile] 태그는
  `_set_portrait`의 누락 폴백을 타 기본 stem으로 떨어진다(대사·코드 무개정으로 나중에 추가 가능).
```

### 13.5 릴 격투 HUD 스킨 (아트 생성물 아님 — 코드 드로우)

```
파일 없음. main.gd `_draw_fishing_hud()` — [HanjiUi] 판·먹빛·금박으로 그리는 즉시모드 위젯이다.
  (owner Gemini 교체 대상이 아니라 **문법 기록**이다 — 나중에 손댈 사람이 의도를 알게.)
문법(스타듀 낚시 UI 이식): **세로 트랙 하나 + 좌우 바 둘**. 가로 바 세 줄을 쌓으면 눈이 세 번
  움직이지만, 세로 트랙에 물고기를 넣고 좌우에 바를 세우면 한 점만 보면 된다.
  ① 가운데 트랙(16 폭) — 물빛 `#33454f` 바탕. **어종 아이콘 16×16**이 distance_ratio로 오르내린다
     (위 = 먼 물속 · 아래 = 내 손). 밑 5px 금박 띠 = 착지대(닿으면 포획).
  ② 오른쪽 바(5 폭) — 텐션. 아래에서 차오르고 위 20%가 붉은 위험대. 채움 초록→노랑→빨강.
  ③ 왼쪽 바(5 폭) — 물고기 스태미나(남은 힘).
  ④ 발버둥: 예고 = 판 위 금박 느낌표 / 진행 중 = 판 둘레 붉은 테.
  ⑤ 퍼펙트: 창 = 금박 테 / 성공 = 흰 굵은 플래시 / 누적 = 판 아래 금박 눈금(최대 5).
  ⑥ 격투 **전**(캐스팅·대기·입질) = 큰 판이 아니라 **26×30 작은 배지**(찌 하나). 잴 것이 없는데
     큰 판을 세우면 빈 판이 화면을 가린다(1차 판 육안 리젝). 입질이면 찌가 붉게 잠기고 금박 파문 2줄.
치수: 판 48×88(한지 판 9-slice 테두리 12가 살아 있는 최소치) · 안쪽 여백 11 · 플레이어 오른쪽 +22px.
★ 물고기 아이콘은 **32²의 정확히 1/2인 16px**로 줄인다(14 같은 어중간한 축소는 nearest에서 열·행이
  불규칙하게 빠져 뭉갠다 — 1차 판 육안 리젝).
★ 이 HUD는 CanvasLayer가 아니라 **월드 좌표**(main._draw)에 있어 시간대 조명 틴트를 같이 받는다
  (새벽엔 푸르게). 그레이박스 때부터의 성질이고 작물·프롭과 같은 결이라 그대로 뒀다.
  ★[owner 큐] 조명 무관 HUD를 원하면 CanvasLayer Control로 옮기는 별도 작업이 된다.
★ 로직 불변: FishingSession은 한 줄도 안 건드렸다(같은 네 수치를 다른 문법으로 그릴 뿐).
```

---

## 14. ★[S4-T9] 저승 숲·미혹의 숲 아트 패스 1 — 나무 3폼·장식·덤불 12종 스펙카드 (owner Gemini 무수정 교체 대기)

> **상태:** PixelLab 생성 + 후처리로 **인게임 배선 완료**(2026-07-30). §10~§13과 같은 [ADR-0048] 교체
> 큐다 — owner가 같은 파일명·크기로 다시 뽑아 `*_raw.png`만 덮어쓰면 **코드 0줄 수정**으로 반영된다.
>
> **후처리 글루:** [`game/tools/make_forest_art.py`](../../game/tools/make_forest_art.py)
> **raw 보관:** `game/assets/props/{tree_forest_dark,tree_mid,tree_sapling,tree_stump,forest_berry_bush,`
> `forest_moss,forest_mushroom,forest_fern,mihok_dead_snag,mihok_rare_mushroom,large_stump,large_log}_raw.png`
> **육안 하네스:** `godot --path game --script res://playtest/forest_dump.gd` (⚠비-headless)
> → `/tmp/forest_{jeoseung_clearing1,jeoseung_woodshop,jeoseung_growth,jeoseung_forms,jeoseung_bush,`
> `mihok_pond,mihok_deep,mihok_clearing}.png`
>
> **PixelLab 사용량 13 gen**(ADR-0062 결정 10 천장 ~13 준수). 12종 채택 + 이끼 1회 재생성.
> 나무는 **Slice 1/2 기생성 2종(`tree_spirit_a`·`tree_spirit_b`)을 그대로 재사용**하고 신규는 짙은
> 변형 1종뿐이다(결정 10 ㉡ "중복 생성 0"). 통나무 5종·풀 뭉치도 기존 자산 재사용.
>
> **이 패스로 숲 2구역에 그레이박스 나무가 0이 됐다** — 다만 **외관 2건(목공방·옥자 집)은 여전히
> 그레이박스 WALL 박스**다(T10 소관). 그래서 두 rect는 프로파일 `greybox_rects`에 들어가 지면
> 오버레이를 투명 통과시킨다 — 여기 빠지면 건물이 통째로 지면에 삼켜진다(1차 덤프에서 실측).

### 14.0 공통 규약

```
전부 [ADR-0050] 32-native · [§0.1] 2px 청키(글루가 ÷2→×2로 강제, 판정 척도 = enforce_chunk와 동일
  stride 2) · [§1.1] NW 광원 · [§8.1] 하드 알파 · [§3] 발치 bottom-flush(글루 foot_flush) ·
  [§9] 저승 muted(종별 계수는 아래 카드).
생성: create_map_object(basic 모드 / high top-down / 단색 외곽선). 지면·그림자를 굽지 않는다
  (§11 접지 그림자는 코드 타원이 깖).
★**전 종 비-SOLID**다. 숲의 통행 집합은 TREE 그리드 타일과 `tree_ledger`가 통째로 소유하고, 이
  프롭들은 그 위에 얹는 순수 시각이다. 부피 프롭(성숙목·중간목·고목·통나무·그루터기)은 **발치 칸이
  이미 TREE(SOLID)이거나 원장이 든 칸**에만 세운다(황천해 고지 수풀 문법 상속) → 통행 가능 집합이
  한 칸도 안 바뀐다. 납작한 바닥 소품(버섯·고사리·이끼)만 걷는 칸에 놓인다.
★리젝 기준: 3/4 각도로 옆면이 보이면 재생성 · 프레임에 지면·그림자가 구워져 있으면 재생성
  (bbox가 늘어 발치 앵커가 밀린다).
```

### 14.1 ★나무 3폼 + 그루터기 — 데이터 5단계 ↔ 아트 3폼 매핑표 (잠금)

```
`TreeLedger`는 성장 **5단계**(+그루터기·큰 장애물)를 들고, 아트는 **3폼**뿐이다. 에셋 폭발을
억제하면서(ADR-0062 결정 3) "자라는 중"이 읽히게 하는 매핑을 여기 잠근다.

  원장 상태                     아트                     프레임      배선
  ─────────────────────────────────────────────────────────────────────────────
  stage 1 ~ 2                   tree_sapling            32×32  (1칸)  PROP_TREE_SAPLING
  stage 3 ~ 4                   tree_mid                64×64  (2×2)  PROP_TREE_MID
  stage 5 (성숙)                 캐노피 믹스              64×128 (2×4)  _CANOPY_MIX_*
  stump = true                  tree_stump              32×32  (1칸)  PROP_TREE_STUMP
  large = large_stump           large_stump             32×32  (1칸)  PROP_LARGE_STUMP
  large = large_log             large_log               32×32  (1칸)  PROP_LARGE_LOG
  stage 0 · stump false (빈 슬롯) 없음(재성장 대기)        —          —

★**세 폼의 키 계단(1칸 / 2칸 / 4칸)이 이 매핑의 유일한 시각 근거다.** 프레임 치수를 흔들면
  한 화면에 셋이 서도 "자라는 중"이 안 읽힌다 → 교체 시 치수 고정.
★큰 장애물 2종은 **보통 그루터기와의 대비**가 곧 "도끼 티어가 필요하다"의 신호다. 그래서 글루가
  콘텐츠를 칸에 꽉 채우고(32×28 / 32×24) 보통 그루터기는 작게 눌러 둔다(22×16).
★검증: forest_dump `jeoseung_forms` — 빈터 한 줄에 stage1·2·3·4·5·5+이끼·그루터기·큰그루터기·
  큰통나무를 나란히 심어 굽는다(육안 매핑 확인 전용 하네스).
```

```
14.1a  tree_forest_dark   64×128 (2×4칸) · 채도 ×0.78 · 명도 ×0.86
  배선: PROP_TREE_FOREST — 경계 밴드 캐노피 + 원장 성숙목
  PROMPT: a single tall dark underworld forest conifer tree, very dark desaturated blue-green
    needled canopy in three heavy layered tiers tapering to a point, thick dark twisted trunk with
    two low bare branches, top-down 3/4 overworld view (Stardew Valley angle), standing upright,
    centered, transparent background, no baked ground shadow, only its own form self-shadow.
    + [§1.1 광원 세트]
  ★정체성: 안식 농원의 저승 봄나무(`tree_spirit_a` 침엽·`tree_spirit_b` 활엽)보다 **한참 어둡다**.
    캐노피 믹스가 8:1:1인 이유가 이것 — 3:1:1로 섞었더니 밝은 안식 2종이 소수인데도 화면을
    지배해 "서리 낀 침엽림"으로 읽혔다(1차 덤프 육안). 밝은 쪽은 액센트 몫이다.

14.1b  tree_mid           64×64 (2×2칸) · 채도 ×0.80 · 명도 ×0.88
  PROMPT: a half-grown young underworld conifer tree, a short slim dark blue-green needled canopy
    in two tiers, thin dark straight trunk, clearly smaller and thinner than a full grown tree, ...
  ★성숙목과 **같은 수종으로 읽혀야** 한다(자란 결과가 저것이므로). 활엽으로 뽑으면 안 됨.

14.1c  tree_sapling       32×32 (콘텐츠 20×22) · 채도 ×0.84 · 명도 ×0.92
  PROMPT: a tiny young tree sapling, one slender pale stem with three or four small leaves at the
    top, very small, standing upright in bare soil, ...
  ★"뽑으면 씨앗만 나오는 유목"이라 **연약해 보여야** 한다(굵은 줄기면 벌목 대상으로 읽힌다).

14.1d  tree_stump         32×32 (콘텐츠 22×16) · 채도 ×0.86 · 명도 ×0.92
  PROMPT: a freshly cut tree stump, a low round trunk base sawn flat on top showing pale concentric
    growth rings, dark rough bark on the sides, a couple of chopped wood chips at its foot, ...
  ★**통행 불가 상태**의 시각 신호다(그루터기를 마저 치워야 자리가 열린다) — 납작한 그루가 아니라
    "아직 뽑아야 할 밑동"으로 보이게.
```

### 14.2 ★채집 덤불 `forest_berry_bush` — 능선 SOLID 덤불과의 실루엣 분리 (필수 요구)

```
파일: game/assets/props/forest_berry_bush.png (32×32, 콘텐츠 28×18)  채도 ×0.82 · 명도 ×0.98
배선: PROP_FOREST_BUSH — main._draw_berry_bushes(). 자리는 FOREST_BUSH_TILES·MIHOK_BUSH_TILES(7그루)
PROMPT: a low wide round berry bush, a squat dome of small rounded leaves sitting close to the
  ground, much wider than it is tall, soft billowy outline with no sharp spiky leaves, no berries, ...

★★ **이 카드의 존재 이유 = 역할 분리**(owner 큐 2026-07-30 · 카탈로그 §2-2 덤불 3역할).
   능선 SOLID 덤불(`bush.png` 64×64)과 **같은 그림이면 안 된다** — 같으면 "저 벽도 흔들 수 있나"로
   읽혀 [흔드는 채집 대상] ↔ [통행 벽]의 분리가 시각에서 무너진다. 분리 축 셋을 전부 지킬 것:
     ㉠ 크기  = 32×32 (능선 덤불의 **1/4 면적**, 1칸 vs 2×2칸)
     ㉡ 실루엣 = 매끈한 **낮고 넓은 반구**(능선 덤불 = 어둡고 넓은 **톱니** dome)
     ㉢ 톤    = 한 단 **밝은** 초록(능선 덤불은 어둡다)
   ⚠️ 능선 덤불엔 **열매가 이미 구워져 있다**(어두운 붉은 점) — 그게 애초 혼동의 근원이라, 이쪽은
     열매 없는 판으로 뽑고 열매는 코드가 얹는다.

★열매 = **코드 색점**(아트 아님). 절기마다 종이 갈리고(넋딸기 피안절 / 잿빛복분자 망연절) 유·무
  2상태가 한 텍스처로 굴러야 해서, 열매를 구우면 텍스처가 4장 필요해진다(에셋 폭발).
  `_draw_berry_bushes`가 `_BERRY_COLORS`로 4점을 찍고 어두운 1px 테를 두른다.
```

### 14.3 저승 숲 장식 (5종 — 신규 2 · 재사용 3)

```
forest_mushroom  32×32 (콘텐츠 20×18) · 채도 ×0.86 · 명도 ×0.94   ← 신규
  PROMPT: a small cluster of three pale ghostly forest mushrooms growing from the ground, rounded
    caps with darker gills underneath, thin stalks, muted bone-white and dusty grey, ...
forest_fern      32×32 (콘텐츠 26×20) · 채도 ×0.80 · 명도 ×0.90   ← 신규
  PROMPT: a small forest fern plant, a low rosette of four or five arching feathery fronds
    spreading outward close to the ground, muted deep green, ...
그루터기 = §14.1d tree_stump 재사용 / 통나무 = PROP_LOG_UPRIGHT·PROP_LOG_DIAG_A/B 재사용(#202)
덤불 = §14.2 재사용

★배치 규칙(코드): 장식은 **두 계급**으로 갈린다 — 이게 배치의 유일한 설계 규칙이다.
   · **밴드 장식**(통나무·그루터기·고목) = **이미 SOLID인 TREE 칸**에만. 걷는 칸에 두면 "통나무인데
     지나가진다"가 되어, 능선 통나무가 SOLID인 안식과 규칙이 어긋난다.
   · **바닥 장식**(버섯·고사리·풀) = 걷는 칸(GROUND)에. 원래 통행 O인 납작한 소품이라 오독이 없다.
   · 채집물 스폰존·덤불 칸·건물 발치는 비운다(그림이 상호작용 표식을 가리면 안 된다).
```

### 14.4 미혹의 숲 장식 (4종 — 신규 2 · 재사용 1 · 절차 1)

```
mihok_dead_snag      64×96 (2×3칸) · 채도 ×0.72 · 명도 ×0.84      ← 신규
  PROMPT: a tall dead bare tree snag, a leafless pale grey weathered trunk with a few broken jagged
    branches reaching up, bark peeling away, hollow dark knot hole, no leaves at all, ...
  ★밴드 장식(발치 두 열이 다 TREE일 때만 선다 — 한쪽 발치가 빈터로 삐져나오면 뜬다).
mihok_rare_mushroom  32×32 (콘텐츠 18×22) · 채도 ×1.00 · 명도 ×1.00  ← 신규
  PROMPT: a pair of rare glowing mushrooms, tall slender stalks with bell shaped caps that emit a
    soft cyan bioluminescent glow, bright spirit-blue light against a dark stalk, clearly magical, ...
  ★**유일하게 톤을 안 죽인다** — [asset-ruleset §17] 게임플레이 pop. 미혹 지면이 가장 어두워
    저채도로 뭉개면 안 보인다. 영혼빛 램프(§16 `#60d8f0→#2068e8`) 정합.
이끼 = §14.5 forest_moss 재사용
안개 = **절차**(생성물 0) — main._draw_mihok_fog

★안개 문법: 시드 RNG로 70덩이 자리를 구역 빌드 때 굳히고(`_rebuild_fog_patches`), 덩이마다
  동심 9겹을 겹당 알파 _FOG_ALPHA/9로 깔아 **누적**으로 감쇠를 만든다. 프롭보다 **위**에 그린다
  (`_front_props`) — 프롭 뒤에 깔면 "바닥 얼룩"으로 읽힌다.
  ⚠️폐기 기록(재시도 금지): ①`hash("fogx:%d" % i)`로 자리를 뽑았더니 GDScript hash가 이웃 문자열에
    거의 연속된 값을 돌려줘 70덩이가 반경 몇 px 안에 겹쳐 쌓였다(안개가 통째로 안 보였다 —
    실측 c=(1539,836)/(1540,837)/(1541,838)). **좌표 해시는 칸마다 다른 salt가 있을 때만** 쓸 수 있다.
    ②겹 3장에 알파를 크게 주면 동심원 테두리가 "보케 원반"으로 읽힌다 → 겹을 늘리고 겹당 알파를 낮춘다.
```

### 14.5 이끼 `forest_moss` (32×32, 콘텐츠 24×12) · 채도 ×0.88 · 명도 ×0.96

```
배선: PROP_FOREST_MOSS — `tree_ledger.has_moss()`인 성숙목의 **밑동 오버레이**(낫 1회 채취 대상)
PROMPT: a flat irregular stain of moss growing on the ground, seen from straight above, completely
  flat with zero height and no dome or ball shape, a ragged blotchy splatter of teal-green fuzzy
  texture with torn uneven edges and two smaller separate specks beside it, like lichen spreading
  on bark, top-down flat decal, ... (flat shading / lineless)
★**납작해야** 한다 — 부피 있는 덩이로 나오면 채집 덤불과 헷갈린다(1차 생성이 그래서 재생성했고,
  글루가 24×12로 한 번 더 눌러 못 박는다). 이 한 겹이 "이 나무엔 지금 낫질할 게 있다"의 유일한 신호다.
★렌더 배선의 함정: 이끼는 그림자를 안 지지만(납작) **자기가 앉은 성숙목과 같은 Y-split 패스를
  타야** 한다 — 나무가 앞 패스로 가고 이끼만 뒤에 남으면 수관에 가려 신호가 사라진다. 그래서
  `SPLIT_PROPS`(= PROP_SHADOW_SET + 이끼)를 두고 앞/뒤 판정만 그 집합으로 한다(그림자는 종전 집합).
  정렬 키에 +0.5 bump를 줘 같은 발치에서 나무보다 **나중에** 그려지게 한다.
```

### 14.6 구역 지면 톤 (아트 생성물 아님 — 프로파일 값)

```
파일 없음. `main._G16_REGION_PROFILES`의 `ground_tone`(그리기 시점 곱셈) + `leaf_density`(낙엽 결).
  저승 숲 = Color(0.60, 0.69, 0.56) · leaf 0.16   — 어두운 잔디 + 낙엽 결
  미혹의 숲 = Color(0.42, 0.54, 0.58) · leaf 0.06 — 한 단 더 짙고 **차갑게**(청록) + 안개
★★ 왜 필드 PNG를 갈아끼우지 않고 **곱셈**인가(폐기 기록 — 재시도 금지):
   구역별 파생 필드(forest_grass_field 등 6장)를 구워 `_g16_field`만 갈아끼우는 1차 안을 만들었고
   **육안 리젝**했다. 이유 둘:
     ① `_wang_tiles`(잔디↔흙 전환 타일)가 **전역 1회 캐시**라, 먼저 방문한 구역의 톤이 다른 구역까지
        물든다(구역 오염).
     ② 물가 shore 셀별 합성·길 갓길·스캐터 데칼이 각자 다른 경로로 base를 직접 읽어, 한 군데만
        갈아끼우면 **경계에만 원톤이 남는다** — 연못 둘레와 길 옆이 형광 tan으로 떴다(실측).
   곱셈 한 번(`draw_texture(tex, pos, tone)`)은 합성 **결과 전부**에 균일하게 걸리고, 흰색이면
   무변화라 HOME·나루·삼도천·황천해가 픽셀 동일이다.
★낙엽 색은 **밑에 깔린 지면 픽셀에서 파생**한다(붉은 쪽 lerp 0.55 + 명도 소폭 down). 고정 팔레트를
  뿌렸더니 어두운 숲 바닥 위에서 형광 주황 색종이로 읽혔다(1차 덤프 육안). 2px 블록 = [§0.1] 캐논.
```

---

## 15. ★[S4-T10] 숲 아트 패스 2 — 아이템 아이콘 48종·외관 2채·옹이 스펙카드 (owner Gemini 무수정 교체 대기)

> **상태:** PixelLab 생성 + 후처리로 **인게임 배선 완료**(2026-07-30). §10~§14와 같은 [ADR-0048] 교체
> 큐다 — owner가 같은 파일명·크기로 다시 뽑아 `*_raw.png`만 덮어쓰면 **코드 0줄 수정**으로 반영된다.
>
> **후처리 글루:** [`game/tools/make_t10_icons.py`](../../game/tools/make_t10_icons.py)
> **raw 보관:** `game/assets/forage/raw/*_raw.png`(24) · `game/assets/materials/raw/*_raw.png`(16) ·
> `game/assets/buildings/raw/{woodshop,okja_hut}_ext_raw.png` ·
> `game/assets/characters/ongi_raw/{south,north,east,west}.png` · `game/assets/portraits/ongi_raw.png`
> **육안 하네스:** `godot --path game --script res://playtest/t10_icon_dump.gd`(★비-헤드리스)
> → `/tmp/t10_inv_{1,2,3}.png`(인벤 슬롯 실렌더) · `/tmp/t10_portrait.png`(대화창 초상화 슬롯)
> 그리고 `forest_dump.gd`에 3면 추가 → `/tmp/forest_{jeoseung_forage_icons,jeoseung_tapper,mihok_okja_hut}.png`
>
> **이 패스로 Slice 4의 그레이박스 아이템 아이콘이 0이 됐다** — 채집물 22종의 흰 박스, 원목·수액·
> 씨앗의 색 박스, 수액 채취기의 색 사각형이 전부 도트로 교체됐고, **곁들여 기존 슬라이스가 남긴
> CAT_MATERIAL 색박스 5종(건초·개간 드랍 3·삭은 그물)까지 닫았다**(§15.5).

### 15.0 공통 규약 (아이콘 48종)

```
크기: 전부 32×32 투명 PNG **32-native**([ADR-0050] — 축소본 금지). 슬롯이 통째로 늘려 그리므로
  콘텐츠는 후처리에서 32² 안에 **가운데 정렬**한다.
생성: create_map_object(32×32 / medium detail / basic shading / **single color outline**)
  · 식물·자재·씨앗 = view "side"   · 조개/산호/성게/이끼 = view "high top-down"(바닥에 놓이는 물건)
공통 꼬리말(전 프롬프트에 붙임 — §13.0 어획물 꼬리말에 ③을 상시화한 판):
  centered on transparent background, no ground shadow, RPG inventory item icon,
  stardew valley pixel art, muted underworld palette, light from top-left,
  one connected object with no floating separate pieces
후처리: 하드 알파 → [§9] muted(채도 ×0.90 · 명도 ×0.97 — §13.0 어획물과 **같은 계수**라 낚시
  아이콘과 나란히 놓여도 톤이 안 튄다) → 32² 가운데 정렬
★리젝 기준(실제로 리젝하고 재생성한 5건 — 전부 **"이웃과 안 갈린다"** 한 축이다):
  ① **같은 계열 두 종이 같은 실루엣** — 1차 잿빛냉이가 혼잎박하와 똑같은 "가는 초록 잔가지"로
     나왔다. 32²에서 잎사귀 종류는 안 읽힌다. **형태 계급을 바꿔** 풀었다(냉이 = 끈으로 묶은
     **다발**, 박하 = 가는 **가지**). 색이 아니라 실루엣으로 가른다.
  ② **부피가 없어 뭉갬** — 1차 넋고사리가 줄기 한 가닥이라 16px에서 사라졌다. "bundle of three,
     bold chunky readable shape"로 재생성.
  ③ **정체 오독** — 1차 언혼뿌리가 접시 위 흰 원뿔(아이스크림)로 나왔다. "long parsnip shaped
     taproot with a tapering tip"처럼 **실존 채소 형태를 지정**하면 잡힌다.
  ④ **디테일이 안 실림** — 1차 넋성게가 가시 없는 보라 공이었다. "many long sharp radiating
     spines, spiky star silhouette"로 실루엣을 말로 그려 주면 나온다.
  ⑤ **형태 없는 덩어리** — 1차 유령초가 흰 얼룩이었다. "bending over at the top into a single
     drooping bell flower"로 구조를 지정.
★교체 시 유지할 것: 32² 가운데 정렬 · **한 절기 안에서 세 종의 실루엣 계급이 다를 것**
  (잎다발 / 뿌리 / 열매·꽃처럼) — 이게 22종을 인벤에서 가르는 유일한 축이다.
```

### 15.1 채집물 아이콘 24종 `forage/<id>.png`

```
파일: game/assets/forage/<채집물 id>.png — id = ItemCatalog 상수 = 아이템 id(파일명이 곧 배선)
배선: main.FORAGE_ICONS → `_merge_t10_icons()`가 `icons` dict에 병합(핫바·인벤 두 곳 공통) +
  `_item_icon`(토스트). 전부 CAT_HARVEST(이끼만 CAT_MATERIAL)라 기존 분기가 그대로 집는다.
  ★ **월드 렌더도 이 텍스처를 쓴다**(`_draw_forage_spawns` — 게잡이통이 아이콘↔설치물을 공유한 결).
    빈터에 뭐가 돋았는지가 줍기 *전에* 눈으로 갈린다(색점 시절엔 22종이 전부 "동그란 것"이었다).
저승 숲 일반 12(절기당 3 — ★한 절기 안에서 잎/뿌리/열매로 계급을 갈라 뒀다):
  피안 넋고사리 bundle of three fiddlehead fern shoots, coiled crozier heads /
       잿빛냉이 bundle of wild greens tied with straw twine, white roots /
       저승달래 wild garlic chive bunch, one round white bulb with long stalks
  유화 저승산딸기 sprig of wild raspberries, three dusky red berries /
       혼잎박하 sprig of mint, pale blue-green oval leaves in opposite pairs /
       잿빛더덕 knobby bellflower taproot, pale beige forked root
  망연 잿빛도토리 cluster of three grey-brown acorns joined at their caps /
       안개도라지 balloon flower, five pointed violet-blue star petals /
       넋송이버섯 pine mushroom matsutake, thick cream stem, domed tan cap
  성야 언혼뿌리 frost covered parsnip shaped taproot with frosted leaf tuft /
       서리동백 camellia, deep crimson bloom with golden center, glossy leaves /
       성야솔방울 large pine cone with open scales + sprig of pine needles
미혹 희소 4(절기당 1 — 전부 **창백·발광 액센트**로 일반종과 계급을 가른다):
  미혹난초 rare orchid, pale violet bloom with a spotted lip /
  유령초 ghost pipe, bone white stalk drooping into one bell flower /
  명월버섯 glowing moon mushroom, luminous blue-white cap /
  서리혼백초 frost herb, silvery feathery leaves rimmed with ice crystals
미혹 심층 1  저승삼 wild ginseng root, pale forked taproot with fine whiskers
  ※ 심층 2종 중 나머지 **불사과는 생성하지 않는다** — 작물 3프레임 아트가 이미 있어
    `CROP_SPRITES`의 mature 프레임이 인벤 아이콘으로 재사용된다(중복 생성 0).
황천해 해변 4(절기 무관 · high top-down):
  황천산호 branching coral, dusty rose fading to bone white /
  넋성게 sea urchin, long sharp radiating spines /
  유리고둥 glassy translucent spiral shell (side) /
  물비늘조개 fan shaped scallop, pearly cream with pale blue ridges
덤불 열매 2 + 이끼 1:
  넋딸기 cluster of four amber orange salmonberries on a leafy stem /
  잿빛복분자 cluster of four glossy dark purple blackberries on a leafy stem /
  저승 이끼 low rounded cushion of muted grey-green moss (high top-down)
  ※ 덤불 열매 둘은 **같은 프롬프트 뼈대에 색만 다르다** — 같은 상호작용(bush-shake)의 절기
    변주라 계열로 읽혀야 한다(위 "실루엣을 가르라"의 의도적 예외).
```

### 15.2 자재·수액·씨앗 아이콘 `materials/<id>.png`

```
파일: game/assets/materials/<아이템 id>.png (씨앗 봉지만 **작물 id** — 아래 참조)
배선: main.MATERIAL_ICONS / SEED_PACKET_ICONS → `_merge_t10_icons()` + `_item_icon`
벌목 산출 3(★원목 두 종은 **한눈에 갈려야 한다** — 건축 의뢰·제작 재료창에서 헷갈리면 비싼 경목을
  잘못 쓴다. 밝은 tan ↔ 짙은 적갈로 명도를 벌려 놨다):
  원목        stack of three cut logs bound together, warm tan, growth rings on sawn ends
  단단한 원목  stack of three dense hardwood logs, deep reddish brown, very tight rings
  수액        one thick translucent amber resin droplet with a glossy highlight
수액 3(채취기 산출 — 셋 다 "덩어리"가 되지 않게 **재질을 갈랐다**):
  솔넋진      lump of pale pine resin, milky translucent cream-white crystalline
  넋수지      lump of dark oak resin, deep glossy brown, wet sheen
  명단풍꿀    small round glass jar of maple syrup, amber liquid, cloth-tied lid
나무 씨앗 3(★대응 채집물과 안 겹치게 어긋냈다 — 잿빛도토리=**셋 다발**/넋참나무 도토리=**싹 튼 하나**,
  성야솔방울=**솔잎 달린 큰 열린 방울**/저승솔 방울=**작고 닫힌 방울**):
  저승솔 방울   small slender closed pine cone, dark tight scales
  명단풍 씨     pair of winged maple samara seeds joined at the base, V shape
  넋참나무 도토리 single sprouting acorn, pale root curling out, two seedling leaves
수액 채취기(★인벤 아이콘과 월드 설치물이 **다른 텍스처**다 — 게잡이통(§13.2)이 한 장을 공유한 것과
  갈리는 지점. 채취기는 *나무에 박히는* 물건이라 월드 판엔 줄기가 있어야 "박혔다"가 읽히고,
  그 줄기가 인벤 슬롯에선 군더더기다):
  materials/sap_tapper.png  small wooden bucket with metal hoops and a curved spile on its rim (인벤)
  props/sap_tapper.png      metal spile driven into bark with a bucket hanging from it (월드·발치 flush)
```

### 15.3 씨앗 봉지 9종 = 원본 2장의 절기 틴트 파생 (★생성물 2장뿐)

```
파일: game/assets/materials/<**작물 id**>.png — honhap · yasaeng_{pian,yuhwa,mangyeon,seongya} ·
  {mihok_nancho,yuryeongcho,myeongwol_beoseot,seori_honbaekcho}_wild
배선: main.SEED_PACKET_ICONS. ★키가 아이템 id가 아니라 **작물 id**인 이유: 씨앗은 인벤에서
  `_draw_crop_tex(ItemCatalog.crop_of(id))`로 조회된다 — 아이템 id로 얹으면 영원히 안 잡힌다.
생성 raw 2장:
  seed_packet   folded paper seed packet, coarse tan paper pouch tied with twine, seeds in the fold
  seed_pouch_rare  small silk drawstring bag in bone white cloth, gold cord, red wax seal, glowing sprout
파생(tools/make_t10_icons.py의 SEED_TINTS/RARE_TINTS): 혼합=무채 / 피안=붉음 / 유화=초록 /
  망연=짙은 황갈 / 성야=청백 · 희귀 4 = 자보라·청록·달빛파랑·금빛
★왜 9장을 따로 안 그렸나: ㉠ 스타듀 야생 씨앗도 전부 같은 봉지 실루엣의 절기색 변주다(문법 상속)
  ㉡ 아홉을 각자 생성하면 실루엣이 흔들려 오히려 "한 계열"로 안 읽힌다 ㉢ [ADR-0001] 큐레이션.
★★ 틴트 함수의 규칙 2개(두 번의 실패에서 얻음 — 교체 시에도 유효):
  ㉠ **hue lerp는 1.0이어야 한다.** 0.5로 두면 tan(0.09)→청록(0.56)의 중간인 **초록**에 착지해
     성야(청백)와 유화(초록)가 같은 색이 됐다. 부분 lerp는 "섞는" 게 아니라 "엉뚱한 데 멈추는" 것.
  ㉡ **sat_add 없이는 흰 비단 주머니가 안 물든다.** 채도 0 픽셀은 hue를 어디로 돌려도 흰색이라
     희귀 4종이 전부 같은 흰 주머니로 나왔다. 단 **어두운 외곽선은 제외**(v>0.35) — 안 그러면
     검은 테가 색 테로 바뀌어 [§1] 단일 외곽선 규약이 깨진다.
```

### 15.4 건물 외관 2채 `buildings/{woodshop,okja_hut}_ext.png`

```
공통: §12.0 규약 그대로(정면 facade · 남향 문 · 박공 + 윗면 슬랩 · base 투명 · bottom-center 앵커 ·
  아트 폭 = footprint 폭 정확히 · fit_facade가 규격에 앉힘 · 3/4 각도·구운 지면 금지).
★이 두 장의 설계 규칙 = **톤을 정반대로 가르는 것**. 두 채가 한 화면에 안 서므로 대비는 구역 간이다.

15.4.1 목공방 `woodshop_ext`
파일: game/assets/buildings/woodshop_ext.png (raw: buildings/raw/woodshop_ext_raw.png 140×126)
크기: 224×202 = WOODSHOP_EXT_RECT Rect2i(6,14,7,6) 폭 1:1(224) · 지붕이 위로 솟음
배선: main._draw_facade_woodshop() — JEOSEUNG_FOREST 드로우 분기
  PROMPT: Korean underworld carpenter's woodworking workshop building, flat front elevation only,
    viewed straight on from the front so no side wall and no perspective is visible, wide and sturdy
    workshop. Hanok tiled gable roof with a triangular pitch and a visible flat roof-top slab receding
    behind the ridge. Warm honey brown timber plank front wall showing wood grain, exposed heavy beam
    posts, a wide double wooden door dead center at the bottom of the front wall, a hanging carved
    wooden shop sign board above the door showing a hand plane and a saw, a stack of sawn logs and a
    sawhorse beside the door, wood shavings and a workbench under the eaves. + [§1.1] + 지면 금지
후처리: fit_facade(7,6) → 채도 ×0.88 · 명도 ×0.96(만물상·혼백관과 같은 계수)
★정체성 기준: **일하는 집**이다 — 문 위 대패·톱 현판(간판 문법 §11.1), 옆에 통나무 더미와 톱질
  모탕, 꿀빛 나뭇결. 현판에 목공 도구가 없으면 재생성(생선가게 물고기 현판 기준 동형).
★문 정렬: footprint 7칸(홀수)이라 문은 **1칸**(x=9 = rect 중앙)이다. [ADR-0046] 짝수폭·2칸 문은
  신규 footprint 규약이고, 목공방 rect는 [ADR-0062] 결정 1이 "무이동"으로 잠갔다. 아트의 문(2짝
  여닫이)이 **가로 정중앙**에 오기만 하면 맞는다 — 좌우 비대칭 소품(모탕)이 bbox를 밀면 어긋난다.

15.4.2 옥자 집 `okja_hut_ext`
파일: game/assets/buildings/okja_hut_ext.png (raw: buildings/raw/okja_hut_ext_raw.png 160×148)
크기: 256×228 = OKJA_HUT_EXT_RECT Rect2i(54,24,8,7) 폭 1:1(256)
배선: main._draw_facade_okja_hut() — MIHOK_FOREST 드로우 분기
  PROMPT: an abandoned locked witch's hut deep in a dark underworld forest, flat front elevation only,
    viewed straight on from the front. Crooked steep thatched gable roof sagging with moss and dead
    leaves, weathered dark grey-brown timber plank walls, one narrow closed wooden door dead center at
    the bottom of the front wall barred with a heavy plank and a rusted padlock, two small shuttered
    windows boarded up, crawling vines and pale lichen creeping over the walls, a crooked stone chimney
    with no smoke, a faint cold pale blue glow leaking through one shutter slit. Lonely and sealed.
    + [§1.1] + 지면 금지
후처리: fit_facade(8,7) → 채도 ×0.80 · 명도 ×0.90(**목공방보다 한 단 더 눌러** 폐가 톤)
★정체성 기준: **잠긴 집**이 그림만으로 읽혀야 한다 — 널빤지로 가로막은 문 + 녹슨 자물쇠가 리젝
  기준이다(코드는 이미 진입을 막지만, 플레이어가 "문인데 왜 안 열리지"로 읽으면 진 것이다).
  창 틈의 창백한 빛 한 줄 = "비었지만 죽지는 않은 집"([ADR-0062] 결정 1 스토리 게이트 예고).
```

### 15.5 곁들여 메운 기존 슬라이스 자재 5종 (★스코프 밖이었다가 덤프가 잡아냄)

```
파일: game/assets/materials/{petrified_wood,soul_fiber,ember_shard,hay,rotten_net}.png
왜 들어왔나: §15.2 원목 아이콘을 붙이고 인벤 덤프를 찍었더니 **바로 옆 칸**의 석화 목재·건초가
  여전히 색박스였다. 한 CAT_MATERIAL 줄에서 절반만 도트면 새 아이콘 쪽이 오히려 튄다.
  · 석화 목재  grey stone log fragment with mineralized growth rings, cracked crystalline surface
  · 혼백 섬유  pale ghostly white plant fiber threads twisted into a coil, tied at the middle
  · 업화석 조각 jagged dark charcoal rock with glowing orange cracks and faint heat glow
  · 건초      small bale of dried hay tied with two cords, golden straw
  · 삭은 그물  tangled scrap of rotten fishing net, frayed grey-green rope mesh with algae
★이걸로 **CAT_MATERIAL 카테고리의 색박스 폴백이 0**이 됐다(폴백 코드는 손상 방어로 남겨 둔다).
```

### 15.6 옹이 스프라이트 `characters/ongi` + 도트 초상화 `portraits/ongi`

```
파일: game/assets/characters/ongi.png (raw: characters/ongi_raw/{south,north,east,west}.png)
크기: 80×320 = 프레임 80×80 · **1열**(정지 rotation) × 4행(down/up/right/left)
  — §11.4 네오·§13.3 뱃사공과 동형. ★옹이 스케줄은 목공방 카운터 한 칸 고정이라 실제로 걷지도
    돌지도 않는다(walk_down 행만 재생된다) → 워크 4프레임을 뽑지 않는 게 맞다.
배선: ongi.gd `CharSprite.make("res://assets/characters/ongi.png")` — 이미 있던 훅, 파일만 채웠다
생성: create_character(mode=standard / n_directions=4 / **size=44** / low top-down /
      selective outline / basic shading / high detail / text_guidance_scale=11 /
      proportions {"type":"custom","head_size":1.5,"arms_length":0.75,"legs_length":0.9,
                   "shoulder_width":0.72,"hip_width":0.75})
  ★ size=44 = 출하 캐스트 실측 정합값(§11.4 — ADR-0012의 56은 stale).
  PROMPT: chibi tree spirit woodsman, a living tree stump come to life, his whole head and body are
    carved weathered brown tree bark with deep vertical grain and a big round knot whorl on his chest,
    no human skin anywhere, craggy bark face with two glowing warm amber eyes and a beard of hanging
    pale grey-green lichen, thick mossy eyebrows, a small green leaf sprig sprouting from the top of
    his head, short stubby branch arms and root feet, wearing a dark indigo carpenter apron with tool
    pockets over the bark torso, sturdy and calm, standing straight
후처리: 하드 알파 → muted(채도 ×0.94 · 명도 ×0.98 — 캐스트와 나란히 서므로 아주 얕게) →
  80×80 프레임에 발치정렬(FOOT_Y=74)
★리젝 1건(재생성): 1차는 "wood elemental / bark skin"을 **부드럽게** 적었더니 그냥 **초록 머리
  노인 목수**가 나왔다(사람 피부·나무 요소 = 머리의 잎사귀 한 장뿐). "no human skin anywhere",
  "his whole head and body are carved weathered brown tree bark", "root feet"처럼 **재질을 몸 전체에
  못 박고** guidance를 8→11로 올려야 목령이 나온다.
★알려진 결함(교체 시 고칠 것): **north(뒷모습) 프레임에 얼굴이 그려져 있다** — PixelLab standard의
  알려진 3방향 일관성 한계다. 옹이는 정지 NPC라 walk_down 행만 화면에 들어 **인게임에선 안 보이지만**,
  시트를 다른 용도로 재사용하기 전에 반드시 고쳐야 한다.

파일: game/assets/portraits/ongi.png (raw: portraits/ongi_raw.png 128×128)
크기: 256×256 (raw ×2 nearest) — 네오·뱃사공과 같은 규격
배선: main `r_ongi.portrait_stem = "ongi"`. **표정 파일은 만들지 않는다** — `_set_portrait`가
  smile/shy/sad 파일이 없으면 idle로 떨어지므로 idle 한 장이 대사 전량을 덮는다.
생성: create_portrait_character(character_to_portrait / low top-down / result_size=128) —
  위 시트의 south 프레임을 20색 양자화해 입력(★[S3-T10 교훈] base64 과長 시 MCP 무음 절단 회피).
★★ **교체 1순위**(이 패스에서 품질이 가장 낮은 산출물이다). 스프라이트는 목령으로 나왔는데
  `character_to_portrait` 변환이 **바크 재질을 사람 피부로 되돌린다** — 초록 머리·발광 눈만 남고
  "나무"가 사라진다. seed를 바꿔 2판을 뽑았지만 둘 다 같은 성질의 실패라 **모델 한계로 판단**하고
  더 태우지 않았다(네오·뱃사공과 같은 도트 스톱갭 지위). owner-Gemini가 2×3 표정 그리드로 다시
  그릴 때 요구할 것: **얼굴이 나무껍질**일 것 · 이끼 수염 · 호박빛 눈 · 사람 피부색 0.
```

### 15.7 이 패스가 바꾼 월드 렌더 (아트 생성물 아님 — 코드)

```
① `_draw_forage_spawns` — 종 색점 → **FORAGE_ICONS 텍스처**(불사과만 CROP_SPRITES). 아이콘 없는
   종은 옛 색점으로 폴백(로스터 확장 중 임시 상태 방어).
   ⚠ 이 변경으로 **황천해 백사장 렌더가 바뀐다**(해변 채집 4종이 색점 → 조개·산호 도트). 의도된
   변경이며, 삼도천·나루·HOME 지면/건물 렌더는 불변이다.
② `_draw_tappers` — 색 사각형 두 개 → **PROP_TAPPER 텍스처 + 수거 대기 방울**. 방울만 코드 드로우로
   남긴다(유·무 2상태를 한 텍스처로 굴려야 에셋이 안 는다 — 덤불 열매 색점과 같은 판단).
③ 채취기 **Y-split** — 숲에선 플레이어보다 앞에 선 채취기를 뒤 패스에서 빼고 `_draw_tappers_front`가
   앞 패스에서 다시 그린다. [S4-T9]가 이끼를 SPLIT_PROPS에 넣어 푼 문제의 채취기판이되, 채취기는
   **상태가 매일 바뀌어 프롭 캐시(`_forest_props`)에 못 들어가므로** 같은 규칙을 손으로 적용했다.
④ `greybox_rects` → `building_rects` **짝 이동**(목공방·옥자 집). 두 목록은 뜻이 정반대라 아트와
   반드시 같이 움직여야 한다: greybox = "그림 없으니 오버레이 투명 통과", building = "facade가
   덮으니 발치 맨흙 패드". 아트를 붙이고 greybox에 남기면 오버레이가 facade를 삼킨다(T9 실측).
```
