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

---

## 16. ★[S5-T9] 업화 갱도·나락 아트 패스 1 — 지형 필드 2·프롭 9·외관 2채 스펙카드 (owner Gemini 무수정 교체 대기)

> **상태:** PixelLab 생성 + 후처리로 **인게임 배선 완료**(2026-07-30). §10~§15와 같은 [ADR-0048] 교체
> 큐다 — owner가 같은 파일명·크기로 다시 뽑아 `*_raw.png`(지형은 `mine_src/*.png`)만 덮어쓰면
> **코드 0줄 수정**으로 반영된다.
>
> **후처리 글루:** [`game/tools/make_mine_art.py`](../../game/tools/make_mine_art.py)
> **raw 보관:** `game/assets/props/{mine_rock,mine_node_ore,mine_node_gem,mine_node_geode,mine_ladder,`
> `mine_chest,narak_seal,smithy_anvil,guild_weapon_rack}_raw.png` ·
> `game/assets/buildings/raw/{smithy,guild}_ext_raw.png` · `game/assets/terrain16/mine_src/*.png`
> **육안 하네스:** `godot --path game --script res://playtest/mine_dump.gd` (⚠비-headless)
> → `/tmp/mine_{surface_smithy,band_jaetgil,band_neokgol,band_eophwa,nodes,smithy_room,guild_room,`
> `narak_arena,narak_floor}.png`
>
> **PixelLab 사용량 31 gen**(tiles_pro 1회 ≈20 + map_object 11). S4-T10이 102를 쓴 뒤 owner 큐에
> 편차 확인이 올라간 것을 받아, **재사용·틴트 파생을 최우선**으로 짰다:
>   · 광맥 11종 = 원본 **3장**(광석·보석·지오드) + `_MINE_NODE_COLORS` 곱셈(§16.3)
>   · 밴드 3톤 = 신규 에셋 **0장**(그리기 시점 곱셈 — §16.5)
>   · 나락 = 갱도 지형·돌·사다리 **전량 재사용** + 톤 + 봉인석 1장
>
> **이 패스로 갱도·나락에 남은 그레이박스는 잡귀·보스 스프라이트와 업화로 화덕뿐이다**(둘 다 T10/후속).

### 16.0 공통 규약

```
전부 [ADR-0050] 32-native · [§0.1] 2px 청키 · [§1.1] NW 광원 · [§8.1] 하드 알파 ·
  [§3] 발치 bottom-flush(글루 foot_flush) · [§9] 저승 muted(종별 계수는 아래 카드).
생성: 프롭 = create_map_object(basic / high top-down / single color outline) ·
      지형 = create_tiles_pro(square_topdown / 32px / top-down / segmentation) — 팔레트 소스로만.
★리젝 기준: 3/4 각도로 옆면이 보이면 재생성 · 프레임에 지면·그림자가 구워져 있으면 재생성.
★전 종 **비-SOLID**다. 층의 통행 집합은 그리드(PATH/ROCK/WALL)와 원장이 통째로 소유하고, 이
  프롭들은 그 위에 얹는 순수 시각이다 — 돌 프롭이 사라져도(캐도) 그리드가 이미 열려 있다.
```

### 16.1 ★지형 필드 2종 `mine_floor_field` / `mine_bedrock_field` — 팔레트 상속 + 절차 합성

```
파일: game/assets/terrain16/{mine_floor_field,mine_bedrock_field}.png (각 128×128 seamless)
소스: game/assets/terrain16/mine_src/{floor_a,floor_b,floor_c,rock_a,rock_b,rock_c}.png (32×32)
배선: main._build_mine_ground() — 갱도·나락의 **층과 지상 양쪽**을 한 파이프라인으로 굽는다.
  · 층   — WALL=암반 / 나머지(PATH·ROCK)=바닥  ※ROCK도 바닥으로 굽는 게 핵심(아래 ★)
  · 지상 — ROCK(바위 노두)=암반 / GROUND(협곡 바닥)=바닥 / PATH·WATER·WALL은 투명 통과
생성 PROMPT(tiles_pro seed 5901): 1). rough cave floor of packed ash-grey dirt with scattered small
  angular stone chips and fine gravel, seen from straight above, no repeating grid, no bricks,
  no stripes 2). the same cave floor with a few larger flat rock slabs half embedded in it
  3). dark cracked bedrock cave wall stone, heavy irregular blocky mass with deep fissures
  4). dark bedrock with a scatter of loose rubble chips over it
후처리: **팔레트(명도 램프)만 취하고 구조는 절차 합성**(주기 value 노이즈 3옥타브 seamless +
  잔돌 알갱이). 바닥 sat×0.64·val×1.02 / 암반 sat×0.60·val×1.16(암반이 한 단 어둡고 결이 굵다).

★★ 왜 생성 타일을 그대로 안 깔았나 — §12.3 백사장 선례의 **재확인**(재시도 금지):
  갱도 바닥·암반은 무정형이다. 32px 변주를 모자이크로 깔면 모티프가 타일 중앙에 몰려 배치가
  통째로 32px 격자로 읽힌다. 판석(§10.3 cobble)이 통한 건 그게 원래 격자 물건이어서다.
★★ 램프는 **픽셀 백분위가 아니라 고유색 목록**에서 뽑는다(이 카드가 새로 얻은 교훈):
  저색 crisp 소스는 한 색이 화면의 80%를 먹어서, 픽셀 백분위로 자르면 12단계 램프가 실색 3종으로
  접혀 필드가 민무늬가 된다(1차 산출 실측 — 색수 3). 고유색을 명도순으로 세우고 사이를 보간해야
  램프가 램프가 된다. 팔레트(색 정체)는 소스에서, 단계(결의 세기)는 글루에서.
★ ROCK 칸까지 바닥으로 굽는 이유: 깰 수 있는 돌은 프롭으로 위에 얹으므로, 깨지는 순간 밑에서
  바닥이 드러나 **재베이크가 0**이다(원장이 바뀔 때마다 768² 이미지를 다시 굽지 않는다).
★ owner 교체 시 지킬 것: 두 장의 **명도 차**(암반이 확실히 어둡다)와 **결의 굵기 차**(암반이
  덩어리·바닥이 잔알갱이). 둘이 비슷해지면 층에서 "벽이 어디까지인지"가 안 읽힌다.
```

### 16.2 ★밴드 3톤 + 나락 톤 (아트 생성물 아님 — 그리기 시점 곱셈)

```
파일 없음. `main._MINE_BAND_TONES` / `_MINE_SURFACE_TONE` / `_NARAK_{FLOOR,ARENA}_TONE`.
  잿길(1~20)   Color(0.94, 0.90, 0.84)  마른 잿빛 — 팔레트의 기준선
  넋골(21~40)  Color(0.62, 0.72, 0.80)  청록 그림자 — "빛이 안 드는 층"
  업화(41~60)  Color(1.00, 0.66, 0.46)  달군 주홍 — 용암
  갱도 지상     Color(0.92, 0.88, 0.84)  흙먼지 한 겹(건물 아트가 물들면 안 되므로 약하게)
  나락 런 층    Color(0.58, 0.46, 0.78)  심연 자보라(갱도 3밴드 어디와도 안 겹친다)
  나락 아레나    Color(0.74, 0.64, 0.84)  한 단 옅게(봉인 고리·구멍이 읽혀야 하는 스테이징)
곱하는 대상: 타일맵(`ground.modulate`) + 지면 오버레이(`_g16_ground_tone`) + **돌 프롭 100% /
  사다리·상자 50%**(`_mine_cast`). 광맥은 **안 물들인다** — 종 식별이 최우선이다.

★★ 왜 밴드마다 필드 PNG를 안 굽나 — [S4-T9 §14.6]이 이미 폐기한 길이다(재시도 금지):
  파생 필드는 owner 교체 큐를 3배로 늘리는데 실제로 갈리는 건 톤 하나뿐이고, 곱셈은 합성
  **결과 전부**(바닥·암반·돌)에 균일하게 걸려 한 무대가 한 톤으로 잠긴다.
★ 돌 프롭에도 톤을 얹는 이유(1차 덤프 육안): 지면만 물들이면 업화 층에서 **잿빛 돌이 붉은 바닥
  위에 떠 있다**. 돌은 그 층 암반과 같은 재질이므로 같은 빛을 받아야 한다.
```

### 16.3 ★광맥 3종 = 11종의 원본 (2층 분해 + 종색 곱셈 — ★생성물 3장뿐)

```
파일: game/assets/props/mine_node_{ore,ore_vein,gem,gem_core,geode}.png (각 32×32)
      ※ 생성 raw는 3장(ore·gem·geode)이고, `_vein`/`_core`는 글루가 **쪼갠 층**이다.
배선: main._draw_node_at() — 몸통을 `종색.lerp(WHITE, 0.55)`로, 광물 층을 `종색.lerp(WHITE, 0.12)`로
      곱한다. 지오드는 광물 층이 없고 몸통만 `lerp(WHITE, 0.20)`(통짜 한 재질).
      종색의 단일 출처 = `_MINE_NODE_COLORS` + `_NARAK_NODE_COLORS`(나락철).
커버 종 11: 명동·유철·황천금·혼탄(ore) / 넋수정·명옥·염주석·명부금강(gem) / 넋알돌·업화알돌(geode)
            / 나락철(ore·나락 전용)

16.3a mine_node_ore  — PROMPT: a mine ore vein rock, a chunky grey stone boulder with four bright
  metallic nuggets embedded in its face catching the light, clearly a mineable ore node, ...
16.3b mine_node_gem  — PROMPT: a cluster of sharp faceted crystals growing out of a low grey stone
  base, three tall pointed gem shards, bright and translucent with a glowing core, ...
16.3c mine_node_geode — PROMPT: a rounded geode nodule, a lumpy potato-shaped stone with a rough
  bumpy crust and a thin bright mineral seam running around it, ...

★ 글루의 분해 규칙: 채도 ≥ 임계인 픽셀 = 광물 층(명도만 남긴 **회백**으로 정규화 — 원본 청록
  너깃 색이 남으면 곱셈이 두 색의 곱이 되어 명동이 탁한 올리브로 나온다), 나머지 = 몸통(광물
  자리는 돌 중앙값으로 메워 구멍을 없앤다).
★ 광물 마스크는 **1px 팽창**한다. 안 하면 너깃 하이라이트(채도가 낮아 돌로 분류된 밝은 점)가
  빠져 광물이 서너 점으로 쪼개지고 32px에서 종색이 안 읽힌다(1차 산출 육안 = 판정 실패).
★ 몸통까지 함께 물들이는 이유도 같다 — 광물 층만 물들이면 종이 안 읽힌다. 몸통을 흰색 쪽으로
  절반 당긴 값으로 곱하면 "구리빛 돌 / 강철빛 돌"이 된다.
★ 검증: mine_dump `nodes` — 방 한 줄에 전 종 10개를 강제로 심어 굽는다(육안 식별 전용 하네스.
  층 생성 롤은 한 줄도 안 건드리고 `_mine_layout["nodes"]` 사본만 덮어쓴다 = RNG 무접촉).
★ owner 교체 시: 3장의 **실루엣 계단**(모난 광석 상자 / 뾰족한 결정 다발 / 둥근 덩이)이 종
  부류(ore·gem·geode)의 유일한 시각 근거다. 셋이 닮아지면 색만으로는 부류가 안 갈린다.
```

### 16.4 갱도·나락 설치물 4종

```
mine_rock    32×32 (콘텐츠 28×26) 채도×0.72·명도×0.94   배선: 층·나락 남은 돌 전량
  PROMPT: a single loose breakable mine boulder, a chunky rounded grey-slate rock with angular
    chipped facets and a few pale cracks, ...
  ★칸을 꽉 채우지 않는다(28×26) — 돌이 층 바닥을 뒤덮는 물건이라 꽉 채우면 바닥이 안 보인다.
  ★광맥과 **실루엣이 갈려야** 한다(둥근 덩이 ↔ 모난 상자/결정). 같으면 "저건 캘 값이 있나"가
    곡괭이를 대 보기 전엔 안 읽힌다.
mine_ladder  32×32 (콘텐츠 18×30) 채도×0.80            배선: 내려가는/올라가는/나가는 사다리 공용
  PROMPT: an old wooden mine ladder seen from directly above, two vertical side rails with five
    horizontal rungs between them, weathered warm brown timber, running top to bottom, ...
  ★한 장으로 세 방향을 다 쓴다 — **방향은 그림이 아니라 뒤에 깔린 구덩이/벽감 색이 가른다**
    (내려감=검은 구덩이 / 올라감=밝은 벽감 / 나락 나감=청록 벽감). 사다리 그림으로는 위·아래가
    안 갈리기 때문이고, 그래서 세로로 칸을 관통하는 폭 좁은 판이어야 한다.
mine_chest   32×32 (콘텐츠 26×22) 채도×0.82·명도×0.96   배선: 10의 배수 보상 층 상자(1회성)
  PROMPT: a small closed treasure chest, dark wood body with iron corner bands and a round brass
    lock plate, lid shut, ...
narak_seal   32×32 (콘텐츠 26×24) 채도×0.86·명도×0.92   배선: 나락 아레나 봉인 고리 8세그먼트 양 끝
  PROMPT: a broken stone seal marker, a squat dark basalt block carved with a cracked circular ward
    glyph that glows faint violet through the fracture, chipped and toppling, ...
  ★이 한 장이 나락 아레나의 정체다. "깨진 봉인 고리"(CONTEXT 탈주 잡귀 누출)가 지금까지 ROCK 띠
    **배치로만** 있었고 그림으로는 그냥 바위 담이었다 — 끊긴 끝마다 금 간 봉인석이 서야 "여기가
    끊어진 자리"가 읽힌다. 금 간 원형 각인과 새어 나오는 빛이 빠지면 리젝.
```

### 16.5 건물 외관 2채 `buildings/{smithy,guild}_ext.png`

```
공통: §12.0 규약 그대로(정면 facade · 남향 문 · 박공 + 윗면 슬랩 · base 투명 · bottom-center 앵커 ·
  아트 폭 = footprint 폭 정확히 · fit_facade가 규격에 앉힘 · 3/4 각도·구운 지면 금지).
크기: 둘 다 192×160 = SMITHY_EXT_RECT(4,37,6,5) · GUILD_EXT_RECT(22,37,6,5) 폭 1:1(192)
배선: main._draw_facade_smithy() / _draw_facade_guild() — EOPHWA_MINE 지상 드로우 분기

★★ 이 두 장의 설계 규칙 = **채 간 대비**. 숲 2채(§15.4)는 구역이 갈려 대비를 구역 간에 뒀지만,
   이 둘은 남단 입구 서·동에 **한 화면에 나란히 선다**. 톤이 비슷하면 두 창구가 한 건물로 읽힌다.

16.5a 대장간 smithy_ext  채도×0.86 · 명도×0.92 (검댕 쪽으로 눌러 어둡게)
  PROMPT: a Korean underworld blacksmith forge building carved into a mine canyon, flat front
    elevation only, viewed straight on from the front so no side wall and no perspective is visible.
    Heavy dark slate stone block walls with soot stains, a low tiled gable roof with a visible flat
    roof-top slab receding behind the ridge, a tall stone chimney stack on the left breathing a faint
    ember glow, a wide double wooden door dead center at the bottom of the front wall, a hanging iron
    shop sign above the door showing a hammer and anvil, an anvil and a rack of tongs beside the door,
    the window openings glowing hot orange from the furnace inside. + [§1.1] + 배경 투명·지면 금지
  ★정체성: **불을 다루는 집**. 굴뚝 + 창에서 새는 화덕 주홍 + 망치·모루 현판이 리젝 기준이다.

16.5b 길드 guild_ext     채도×0.84 · 명도×1.02 (대장간의 정확한 반대편 — 밝은 회백)
  PROMPT: a Korean underworld adventurers guild hall carved into a mine canyon, flat front elevation
    only, ... Pale grey cut-stone walls with dark timber posts, a tiled gable roof with a visible flat
    roof-top slab, a wide double wooden door dead center, a carved stone name plaque mounted above the
    door, two crossed swords mounted on the wall as a guild emblem, a pair of stone lanterns flanking
    the doorway glowing faint pale blue, a notice board with pinned papers beside the door.
  ★정체성: **사람이 모이는 집**. 교차한 검 문장 + 석등 창백한 혼불이 리젝 기준.
  ⚠️ 1차 생성본은 간판에 **로마자 "Guild"**를 새겨 왔다(저승 세계관에 라틴 문자 금지). 글루의
    `_scrub_roman_sign`이 판 안쪽을 덮고 각자(刻字) 세 덩이로 바꿔 두었다 — owner 재생성 시엔
    프롬프트에서 글자 자체를 빼면 되고, 그러면 그 함수는 지워도 된다.

★ `greybox_rects` → `building_rects` 짝 이동(§15.7 ④)은 **여기 해당 없다**: 갱도는
  `_G16_REGION_PROFILES`에 없어 ground16 오버레이를 안 타므로 두 목록 자체가 없다. 다만 구역
  프로파일이 갱도로 확장되는 날엔 두 rect를 **building_rects에** 넣어야 한다(아트가 이미 붙었다).
```

### 16.6 실내 프롭 2종 + 방 바닥 (대장간·길드)

```
smithy_anvil       64×32 (2×1칸) 채도×0.78·명도×0.96   배선: SMITHY_UPGRADE_TILE(조준 칸 = 아트 우측 칸)
  PROMPT: a blacksmith anvil on a heavy stone block base, a black iron anvil with a pointed horn
    facing right sitting on a squat grey stone plinth, a hammer resting on it, ...
guild_weapon_rack  64×32 (2×1칸) 채도×0.80·명도×0.98   배선: 길드 서벽(GUILD_RECT 안쪽 x+1, y+1)
  PROMPT: a wall mounted weapon rack against a wall, a horizontal dark timber bar holding three
    straight swords hanging blade down side by side, plain steel blades with brass crossguards ...

★ 방 바닥 = **오버레이**(아트 생성물 아님). `_draw_mine_room_floor(rect, tint)`가 `mine_floor_field`를
  방 크기로 구워 벽 링 안쪽에 깐다. 대장간 tint (0.78,0.70,0.64) 검댕 / 길드 (0.92,0.94,0.98) 회백.
  ★왜 타일을 안 갈았나: 두 방은 집(HOUSE)·카페(CAFE) 바닥 타일을 **공유**한다. 갱도 바위방으로
    갈려면 타일 id 신설 = 그리드 변경이고, eophwa_mine_test ②c/②e가 두 방의 바닥 타일 id를
    단언한다. 순수 시각 오버레이면 그리드·충돌·세이브·테스트가 한 줄도 안 바뀐다.
  ★벽 링은 안 덮는다 — 목재 기둥·벽이 남아야 "바위를 깎아 들인 방"이 된다.
★ 대장간 **업화로 화덕은 아직 코드 드로우**(붉은 사각 + 주홍 심지)다. 이 패스가 남긴 유일한
  실내 그레이박스이고, 다음 패스나 owner Gemini의 후보다(64×32 `smithy_forge` 자리 예약).
```

### 16.7 이 패스가 바꾼 월드 렌더 (아트 생성물 아님 — 코드)

```
① `_build_mine_ground(in_floor)` 신설 + `_paint_grid` 분기 — 갱도·나락이 `_build_path_grass_fringe`
   폴백에서 전용 지면 파이프라인으로 옮겼다. ⚠**갱도·나락 지상 렌더가 바뀐다**: 협곡 바닥이
   잔디밭에서 암석으로 갈린다(1차 덤프 육안 = 갱도 한복판에 잔디 마당). 의도된 변경이며,
   HOME·나루·삼도천/황천해·숲 6구역의 지면·건물 렌더는 **픽셀 불변**이다(톤 = 흰색 = 무변화).
② `_facade_grass_backdrop` — 갱도·나락도 건너뛴다. 안 그러면 암석 협곡 위 대장간·길드 발치에만
   **초록 사각형**이 되살아난다([ADR-0054] 회귀의 갱도판).
③ `_stage_ground_tone()` 신설 — 무대 톤의 단일 출처. 타일맵·오버레이·프롭이 이 한 값을 쓴다.
④ **잠복 버그 봉합**: `_g16_ground_tone`은 `_g16_resolve_profile`(= `_build_ground16` 안)에서만
   갱신돼서, ground16 미이식 구역은 **직전 구역 톤을 물려받고 있었다**(숲 → 갱도로 워프하면 갱도
   fringe가 숲 청록으로 물들었다). 이제 `_paint_grid`의 세 분기가 전부 명시적으로 잡는다.
⑤ `_draw_{mine,narak}_floor` — 색 사각/마름모 그레이박스가 전부 프롭으로. 남은 코드 드로우는
   구덩이·벽감(사다리 방향 구분)·타수 눈금·바닥 반짝이뿐이고, 넷 다 **상태 2개 이상을 한
   텍스처로 굴려야 하는 것**이라 의도적으로 코드에 남겼다(덤불 열매 색점과 같은 판단).
⑥ `_draw_narak_mouth` — 봉인 고리 8세그먼트의 끊긴 끝마다 `narak_seal`을 세운다(순수 시각 —
   NARAK_ROCK_RECTS 좌표도 충돌도 한 칸 안 바뀐다, narak_test 단언 전량 보존).
```

---

## 17. ★[S5-T10] 잡귀·점주·아이콘 아트 패스 2 — 스프라이트 12·점주 2·아이콘 29·화덕 1 스펙카드 (owner Gemini 무수정 교체 대기)

> **상태:** PixelLab 생성 + 후처리로 **인게임 배선 완료**(2026-07-30). §10~§16과 같은 [ADR-0048] 교체
> 큐다 — owner가 같은 파일명·크기로 다시 뽑아 `*_raw.png`만 덮어쓰면 **코드 0줄 수정**으로 반영된다.
>
> **후처리 글루:** [`game/tools/make_mob_art.py`](../../game/tools/make_mob_art.py)
> **raw 보관:** `game/assets/mobs/raw/*_raw.png`(12) · `game/assets/materials/raw/*_raw.png`(14) ·
> `game/assets/fish/raw/*_raw.png`(2) · `game/assets/props/smithy_forge_raw.png` ·
> `game/assets/characters/{pulmu,mugol}_raw/{south,north,east,west}.png` · `game/assets/portraits/pulmu_raw.png`
> **육안 하네스:** `godot --path game --script res://playtest/t10_mine_icon_dump.gd`(★비-headless, 신설)
> → `/tmp/t10m_inv_{1,2,3}.png`(인벤 슬롯 실렌더) · `/tmp/t10m_portrait.png`(대화창 초상화 슬롯)
> 그리고 기존 `mob_dump.gd`·`mine_dump.gd`·`guild_dump.gd`가 그대로 이 패스의 판정면이 된다.
>
> **PixelLab 사용량 57 gen**(map_object 30 + character 2 + portrait 25). 목표 ~40·상한 60 안이고,
> 초상화 한 장이 25를 먹는 구조라 **본체 31 gen + 초상 25**로 읽는 게 맞다. 파생 우선 설계:
>   · 아이콘 29종 = 생성 raw **11장**(광석·주괴·보석 다발·브릴리언트·지오드·곧은검·굽은도 7 +
>     단품 혼탄·환약·계단·열쇠·혼정·넋가루·혼불씨 7 중 겹치는 셈 — 실제 raw 14장) + 틴트 파생 18
>   · 잡귀 12종 = 재사용 0(종마다 실루엣이 정체라 파생 불가 — 아래 ★)
>   · 위장 상태·화염구·HP 바 = 신규 에셋 **0장**(기존 프롭·코드 드로우 재사용)
>
> **이 패스로 Slice 5의 그레이박스 시각 요소가 0이 됐다** — 잡귀 색박스 12종, 광물·주괴·보석·무기
> 아이콘 색박스 27종, 대장간 화덕 붉은 사각, 점주 2인 그레이박스 몸이 전부 도트로 교체됐다.

### 17.0 공통 규약

```
전부 [ADR-0050] 32-native · [§0.1] 2px 청키 · [§1.1] NW 광원 · [§8.1] 하드 알파 · [§9] 저승 muted.
생성: 잡귀·화덕 = create_map_object(high detail / medium shading / single color outline)
      아이콘     = create_map_object(medium detail / basic shading / single color outline)
      점주       = create_character(mode=standard / n_directions=4 / **size=44** / low top-down /
                   selective outline / basic shading / high detail / tgs=11 / §11.4 공통 proportions)
      초상화     = create_portrait_character(character_to_portrait / low top-down / result_size=128)
muted 계수(3층으로 잠겨 있다 — 한 목록에 나란히 서는 것끼리 같은 값이어야 새것만 안 튄다):
  아이콘·어종 0.90/0.97(§13.0·§15.0과 **같은 값**) · 잡귀 0.90/0.98 · 점주 0.94/0.98(옹이와 같음) ·
  화덕 0.86/0.94(대장간 외관 smithy_ext와 같은 검댕 계수)
★★ 잡귀 muted를 프롭 계수(0.72~0.86)로 안 누른 이유: 몹은 **밴드 톤 곱셈 대상이 아니다**(돌·사다리와
   갈리는 지점). 업화 밴드(주홍 지면) 위에서 한 단 더 눌린 잡귀는 배경에 잠겨 "무엇이 나를 때리는지"가
   안 읽힌다 — 판정 대상은 무대색에 물들면 안 된다(광맥을 안 물들이는 §16.2 규칙과 같은 계열).
★리젝 기준: 3/4 각도로 옆면이 보이면 재생성 · 프레임에 지면·그림자가 구워져 있으면 재생성 ·
  이웃 슬롯과 실루엣이 안 갈리면 재생성(§15.0 리젝 ①).
```

### 17.1 ★잡귀 스프라이트 12종 `mobs/<종 id>.png` — 프레임 크기가 곧 체급

```
파일: game/assets/mobs/{heotgeot,eodukkaebi,dalgyal,geuseundae,bulgasari,hwagwi,
                        yacha,nachal,agwi}.png (각 32×32)
      game/assets/mobs/{boss_okjol,boss_nachalwang,boss_daeagwi}.png (각 64×64)
배선: main.MOB_TEX(종 id → 텍스처) → `_draw_mine_mobs()`. 갱도 층·나락 런 층이 **같은 함수**를
  쓴다(무대가 갈려도 몹 렌더 문법은 하나 — S5-T7이 잡아 둔 구조 그대로).
  ★발치선은 그레이박스와 **한 픽셀도 안 바뀐다**(m.pos.y + TILE*0.40). 원장(접촉 피해·스윙 판정)이
    보는 값과 눈에 보이는 몸이 계속 같은 자리에 서야 "맞을 것 같았는데 안 맞았다"가 안 생긴다.

★★ **보스를 코드 배율로 키우던 규칙이 사라졌다**(그레이박스는 1.7배 사각이었다). 프레임을 64로
   뽑아 아트가 체급을 들게 했다 — 32를 1.7배로 늘리면 청키가 3.4px로 깨져 [ADR-0050]("AI 축소본
   금지")의 대칭 위반이 된다. **체급은 코드가 아니라 프레임이 든다**가 이 카드의 규약이다.
★★ 잡귀만 **틴트 파생이 0**인 이유(아이콘과 갈리는 지점): 종의 정체가 색이 아니라 **실루엣**이다.
   광석 4종은 "같은 돌덩이의 다른 금속"이라 색이 종을 가르지만, 헛것(둥근 젤리)과 그슨대(각진 석괴)를
   한 실루엣의 색 변주로 만들면 아키타입(통통 ↔ 추적)이 눈에서 사라진다. ADR-0063 결정 8이 잡귀를
   "아키타피 4 커버"로 짠 이상, 그 넷이 **몸으로** 갈려야 한다.

갱도 6종(밴드당 2):
  헛것       a small round gelatinous phantom blob monster, translucent dusty green jelly body with
             a rounded dome top, two hollow dark eye holes, a wispy pale vapor wisp curling off its back
  어둑깨비    a small dark goblin bat spirit hovering in flight with spread leathery wings, indigo black
             fur, two short horns, two glowing pale blue eyes, tiny fanged mouth
  달걀귀신    a faceless egg shaped ghost, a smooth featureless bone white oval spirit with no eyes and
             no mouth at all, carrying a cracked grey boulder shell on its back like a hermit crab
  그슨대      a tall looming shadow golem built of jointed dark slate stone slabs, heavy blocky arms and
             shoulders, no neck, two narrow glowing red eye slits in a craggy stone head, moss in the cracks
  불가사리    a chunky iron eating beast, a bulky four legged monster with dull grey riveted metal plating
             over its hide, two curved tusks, jagged scrap iron shards embedded along its spine
  화귀        a floating fire spirit ghost, a small hovering skull-like head wreathed in a mane of orange
             and yellow flame, hollow black eye sockets glowing, a thin trailing wisp of embers below it
나락 강몹 3종:
  야차   a lean red skinned yaksha demon warrior crouched low in a dashing lunge, wild black hair, two
         short curved horns, fanged snarling face, clawed hands, tattered dark loincloth
  나찰   a violet skinned rakshasa demon sorcerer standing upright, long horns curving back over its
         skull, dark purple ragged robe, one raised clawed hand holding a floating ball of dark flame
  아귀   an emaciated hungry ghost preta, a starving grey brown corpse figure with a hugely swollen round
         belly, a very thin needle neck, a gaping round mouth, long spindly arms hanging down, ribs showing
관문 보스 3기(64² · 전부 "imposing boss monster" 꼬리말):
  문지기 옥졸   a massive underworld prison guard ogre boss, brass lamellar plate armour over green grey
               skin, a horned iron helmet with a face guard, gripping a heavy studded iron mace
  업화 나찰왕   a towering rakshasa demon king boss wreathed in orange hellfire, a crown of black horns,
               molten glowing cracks running through dark red skin, ornate black and gold robe
  심연 대아귀   a colossal abyssal hungry ghost giant boss, a bloated dark violet corpse body with a
               cavernous gaping mouth full of teeth, sunken glowing white eyes, long dragging arms
후처리: 하드 알파 → muted(0.90/0.98) → 프레임 **바닥 정렬**(부유형 어둑깨비·화귀도 마찬가지 —
  부유는 그림이 맡지 프레임 여백이 맡지 않는다. 여백으로 띄우면 무대마다 발치가 어긋난다).
★ owner 교체 시 지킬 것: **아키타입 4개가 실루엣으로 갈릴 것**(둥근 젤리 / 날개 편 부유체 /
  각진 석괴·중장 / 다리 없는 불꽃). 넷이 닮아지면 "저건 쫓아오나 제자리인가"가 맞아 보기 전엔 안 읽힌다.
```

### 17.2 위장·피격 플래시 (아트 생성물 아님 — 렌더 규칙 2개)

```
① **위장(달걀귀신 ARCH_DISGUISE)** = `MINE_TEX_ROCK` + 발치 타원 그림자. 그레이박스 시절엔 "바위색
   사각"이 최선이었지만, 이제 진짜 돌 그림이 옆 칸에 서 있으므로 **완전히 같은 그림**이어야 한다.
   ★그림자를 함께 걸어야 한다(`_draw_mine_prop`이 진짜 돌마다 까는 그것). 빠뜨리면 "그림자 없는
     돌 하나"가 되어 위장이 눈으로 들킨다 — 색만 맞추던 그레이박스와 같은 실패의 재판이다.
   ★타일 좌표가 아니라 m.pos 픽셀 rect 기준이라 `_draw_prop_shadow` 헬퍼 대신 두 줄을 편다
     (몹은 픽셀 연속 위치라 프롭 문법을 못 쓴다 — 층 몹과 좌석 잡귀의 유일한 렌더 차이).
② **피격 플래시** = modulate를 1 **위로** 올린다(Color(1.9,1.9,1.9)). 그레이박스는 색을 흰색으로
   lerp 했지만 텍스처엔 그 수가 없다 — `draw_texture_rect`의 modulate는 곱셈이라 색을 *섞을* 수는
   없고 *밝힐* 수만 있다. 1 이하로 두면 "맞으면 어두워지는" 반대 신호가 된다.
③ 원거리 단서(몸통 속 주황 심지)는 **텍스처 경로에서 뺐다** — 화귀는 불꽃 몸, 나찰은 손의 암염구라
   스프라이트가 이미 원거리를 말한다. 심지를 얹으면 그림 위에 주황 사각이 겹친다. 색박스 폴백
   경로에는 그대로 남는다(로스터 확장 중 아트 미도착 종 방어).
```

### 17.3 ★아이템 아이콘 29종 = 생성 raw 14장 + 틴트 파생 18 (materials 27 · fish 2)

```
파일: game/assets/materials/<아이템 id>.png · game/assets/fish/<어종 id>.png (전부 32×32)
배선: main.MINE_ICONS → `_merge_t10_icons()`가 `icons` dict에 병합(핫바·인벤 두 곳 공통) +
  `_item_icon`(토스트). 어종 2종은 기존 `FISH_ICONS`에 얹었다.
  ★**드로우 분기 추가 0**이다 — 광물·주괴·드랍·열쇠 = CAT_MATERIAL / 무기 = CAT_TOOL /
    환약·계단 = CAT_CONSUMABLE 로 이미 전부 "텍스처 있으면 쓰고 없으면 색박스" 분기를 타고 있었다.
    (무기가 CAT_TOOL인 건 S5-T4의 "든 것이 곧 동사" 판단 — 그 결정이 여기서 배선 비용 0으로 돌아왔다.)

★★ 종색의 단일 출처 = `_MINE_NODE_COLORS`/`_NARAK_NODE_COLORS`/`WeaponCatalog.color`이고, 아이콘은
   그 색을 **틴트로 물려받는다**. 그래서 인벤 슬롯의 명동과 층 광맥의 명동과 바닥 반짝이의 명동이
   같은 붉은 구리다. 세 곳이 갈리면 "같은 광물인데 무대마다 다른 색"이 되어 플레이어가 광물 정체를
   색으로 배우지 못한다 — 61종짜리 아이템 표에서 그건 치명적이다.
   ⚠ 종색을 고칠 땐 `main._MINE_NODE_COLORS`와 `tools/make_mob_art.py`의 표를 **같이** 고친다.

틴트 규칙 3개(㉠㉡은 §15.3이 두 실패로 얻은 것, ㉢이 이 카드의 몫):
  ㉠ hue는 통째로 갈아끼운다(부분 lerp = "섞는" 게 아니라 "엉뚱한 데 멈추는" 것).
  ㉡ 어두운 외곽선은 안 건드린다(v ≤ 0.35) — 검은 테가 색 테로 바뀌면 [§1] 단일 외곽선이 깨진다.
  ㉢ ★**채도는 원본이 아니라 종색이 운전한다.** 원본(청록 결정·황금 주괴)의 채도를 그대로 곱하면
     넋수정(거의 흰색)이 청록으로 남는다. 원본 채도는 *결의 세기*로만 쓰고 절대값은 종색이 준다
     (`s = cs * (0.55 + 0.75 * s_src)`). [§16.1]이 램프를 "팔레트는 소스·단계는 글루"로 가른 것과
     같은 분업이다.

17.3a 광물 5 — ore_base 1장 + 틴트 4(명동·유철·황천금·나락철) + 단품 혼탄
  ore_base   a mine ore chunk, a single rough grey stone nugget with bright metallic mineral flecks
             embedded across its face, angular chipped facets
  혼탄        a lump of black coal, a single chunky angular piece of glossy anthracite with sharp
             fractured faces  ※검정은 틴트로 안 나온다(명도를 죽이면 실루엣이 사라진다) → 단품
17.3b 주괴 4 — ingot_base 1장 + 틴트. 광석(덩이)과 **형태 계급이 다르다**(사다리꼴 바)라
  제련 전후가 인벤에서 한눈에 갈린다. 색만 갈면 같은 돌 여덟 개가 된다.
  ingot_base a chunky rectangular cast metal ingot bar lying on its side, a thick heavy brick shaped
             bar with a broad flat top face and short bevelled sides, visible depth and thickness
  ★리젝 1건(재생성): 1차는 view="side"로 뽑아 **납작한 마름모**(두께 0)가 나왔다. 주괴는 부피가
    정체라 두께가 없으면 금박 조각으로 읽힌다. `low top-down` + "visible depth and thickness"로 해결.
17.3c 보석 5 — ★**원본이 둘**인 유일한 계열
  gem_base      a cluster of three sharp faceted gemstone crystals joined at the base, tall pointed
                translucent shards  → 넋수정(투명 백)·명옥(옥빛)·염주석(자주)
  gem_brilliant a single large cut brilliant gemstone, one solitary round faceted jewel with a flat
                table top and many triangular facets  → 명부금강(백청)·오색혼옥(프리즈마틱)
  ★★ 왜 둘인가: 넋수정(0.86,0.90,0.94)과 명부금강(0.72,0.90,0.98)은 _MINE_NODE_COLORS에서 색이
     거의 붙어 있다. 같은 다발 실루엣에 그 둘을 얹으면 32² 슬롯에서 **같은 아이콘 두 개**가 된다
     (§15.0 리젝 ① "같은 계열 두 종이 같은 실루엣"). 색으로 못 가르면 **형태 계급을 가른다** —
     원석 다발 ↔ 가공 브릴리언트. 겸사겸사 최상위 2종이 "가공된 보석"으로 격이 올라간다.
  ★오색혼옥은 **단색 틴트가 성립하지 않는 유일한 아이템**이라 세로 위치로 색상환을 한 바퀴 돌린다
   (`prismatic_tint`). 한 색으로 칠하면 "오색"이 거짓말이 되고 나머지 넷과 같은 그림이 된다.
17.3d 지오드 2 — geode_base 1장 + 틴트(넋알돌 흙빛 / 업화알돌 달군 흙빛)
  geode_base a geode nodule, a rounded lumpy potato shaped stone with a rough bumpy crust and a thin
             bright mineral seam running around its middle, unopened
  ※ 둥근 알 모양이 「알돌」 작명과 그대로 맞아떨어진다(우연이지만 유지 가치가 있다).
17.3e 무기 5 — sword_base(곧은 검) 1장 + 티어 틴트 4 · sword_dao(굽은 도) 1장 = 업화도
  sword_base a straight double edged sword pointing up and to the right diagonally, plain steel blade
             with a fuller groove, a simple crossguard, a cord wrapped grip and a round pommel
  sword_dao  a single curved single edged sabre blade pointing up and to the right diagonally, a broad
             gently curved dao blade, a round disc guard, a dark wrapped grip
  ★검은 **통짜 틴트**다(칼자루까지). 날만 물들이면 티어가 32²에서 안 읽힌다 — [§16.3]이 광맥
    몸통까지 물들여야 했던 것과 같은 이유. 그리고 **업화도만 형태부터 갈린다**: 엔드게임 한 자루는
    색이 아니라 실루엣으로 서야 한다(5티어를 한 실루엣 색 변주로 두면 최종 무기가 "네 번째 색"이 된다).
17.3f 단품 6 + 어종 2
  명부환    a small round medicine pill of dark herbal paste with a faint red sheen, sitting in an open
           folded square of white paper wrapping, a traditional east asian herbal remedy pellet
  계단      a short flight of three grey stone steps descending, a compact staircase block of cut stone
  나락 열쇠  an ornate ancient iron key with a large ring bow shaped like a cracked circular ward glyph,
           faint violet light glowing in the glyph  ※봉인석(§16.4 narak_seal)의 각인 모티프를 물려받는다
  나락혼정   a rare soul essence crystal, a smooth polished teardrop gem of deep violet with an inner
           swirling glow and a faint gold filigree band around its waist
  넋가루    a small heap of fine pale ash grey powder, a soft conical mound of ghostly bone white dust
  혼불씨    a single small floating soul flame ember, a teardrop shaped blue and orange spirit fire seed
  돌비늘치   a small stout armoured fish, a thick bodied cave fish covered in overlapping grey stone-like
           scales, blunt rounded snout  (fish/ · [S3-T10] 어획물 20종과 같은 계수)
  업화붕장어 a long slender eel curved into an S shape, smooth dark charcoal skin with glowing ember
           orange streaks along its flank  ※코일 실루엣이라 길쭉한 기존 어종 18종과 안 겹친다
★ 넋가루·혼불씨는 **스코프 밖이었다가 들어왔다**(§15.5 선례의 재판): 잡귀 드랍인데 CAT_MATERIAL
  색박스로 남아 있었고, 나락혼정 바로 옆 칸에 서면 절반만 도트라 새 아이콘 쪽이 오히려 튄다.
  이걸로 **CAT_MATERIAL 색박스 폴백이 다시 0**이 됐다.
```

### 17.4 점주 2인 `characters/{pulmu,mugol}.png` + 풀무 도트 초상화

```
파일: game/assets/characters/{pulmu,mugol}.png (각 80×320 = 프레임 80×80 · 1열 × 4행 down/up/right/left)
배선: pulmu.gd / mugol.gd의 `CharSprite.make(...)` — **이미 있던 훅, 파일만 채웠다**(코드 0줄).
  ★둘 다 상주 정지 NPC(풀무=모루 옆·무골=길드 카운터 뒤)라 walk_down 행만 재생된다 → 워크 4프레임을
    안 뽑는 게 맞다(§11.4 네오·§13.3 뱃사공·§15.6 옹이와 같은 정지 rotation 1열).
생성: create_character(standard / 4dir / size=44 / low top-down / selective outline / basic shading /
      high detail / tgs=11 / proportions {"type":"custom","head_size":1.5,"arms_length":0.75,
      "legs_length":0.9,"shoulder_width":0.72,"hip_width":0.75})
  풀무 PROMPT: chibi Korean dokkaebi goblin blacksmith, his whole face and body are rough dark reddish-
    brown ogre hide like heated iron, no human skin anywhere, one single thick horn growing straight up
    from the center of his forehead, craggy scowling face with two glowing amber eyes and small tusks,
    wild black beard, a heavy blacksmith hammer resting on his right shoulder, wearing a scorched dark
    leather apron over a bare barrel chest, thick arms, soot smudges, stocky and sturdy, standing straight
  무골 PROMPT: chibi undead skeleton warrior, his head is a bare bone white human skull with hollow black
    eye sockets and pale blue soul flames burning in them, no hair and no flesh and no human skin anywhere,
    bare bone arms and rib cage showing, wearing worn dark leather armour straps and a faded grey cloak
    over the bones, a large two handed greatsword slung diagonally across his back, calm and still
후처리: 하드 알파 → muted(0.94/0.98 — 출하 캐스트와 나란히 서므로 아주 얕게) → 80×80 발치정렬(FOOT_Y=74)
★[§15.6 교훈 이행] "재질을 몸 전체에 못 박고 tgs=11" 규칙을 처음부터 적용해 **리젝 0**이었다
  (옹이는 "bark skin"을 부드럽게 적어 1차가 초록 머리 노인 목수로 나왔다). "no human skin anywhere"가
  비인간 캐릭터의 핵심 어구다.
★[§15.6 알려진 결함이 여기선 안 났다] 옹이는 north(뒷모습) 프레임에 얼굴이 그려져 있었는데, 이 둘은
  north가 정상(풀무=뒤통수·무골=민 두개골 뒷면)이다. size=44 + selective outline 조합의 편차로 보이며,
  **교체 시에도 north를 반드시 눈으로 확인할 것**.
★알려진 결함(교체 시 고칠 것): 풀무의 **이마 외뿔이 안 나왔다** — 검은 머리 볏으로 읽힌다. 그레이박스
  실루엣 규약(pulmu.gd `_HORN_H` 주석 = "외뿔이 옹이의 갈래 뿔과의 구분점")이 아트에서 아직 미이행이다.
  지금은 붉은 살갗 + 뾰족귀 + 망치가 도깨비 대장장이를 대신 팔고 있다.

파일: game/assets/portraits/pulmu.png (raw: portraits/pulmu_raw.png 128×128) · 256×256 (raw ×2 nearest)
배선: main `r_pulmu.portrait_stem = "pulmu"`. **표정 파일은 만들지 않는다**(`_set_portrait`가 없으면
  idle로 떨어지므로 idle 한 장이 대사 전량을 덮는다 — §15.6과 같은 규약).
생성: create_portrait_character(character_to_portrait / low top-down / result_size=128) —
  위 시트 south 프레임을 **16색 양자화 P모드 PNG**로 입력.
  ★★ [S3-T10 교훈의 정정] 입력이 거부되는 원인은 "base64가 길어서 잘린다"만이 아니다. 20색 RGBA
     양자화본(b64 2588자)은 **전량 도착했는데도** 서버 PIL이 "broken data stream"으로 거부했다
     (수신 1941바이트 = 2588×3/4 = 전량). 확실한 회피는 **팔레트(P) 모드 PNG**다 — 16색 P모드는
     b64 884자에 라운드트립도 검증돼 한 번에 통과했다. 양자화는 길이가 아니라 **포맷**이 관건이다.
★★ **무골 초상화는 안 만들었다**(이 패스의 유일한 미이행 스코프). 근거 둘:
   ㉠ §15.6이 `character_to_portrait`의 **비인간 재질 → 사람 피부** 되돌림을 모델 한계로 박제했고
      (옹이 2판 동일 실패), 백골은 그 실패에 가장 불리한 입력이다(두개골 → 얼굴).
   ㉡ 초상 한 장이 **25 gen**이라, 실패 가능성이 큰 25를 더 태우면 상한 60을 넘는다(57 → 82).
   풀무 쪽은 붉은 살갗·뾰족귀·염소수염이 살아남아 **도깨비로는 읽힌다**(네오·뱃사공·옹이와 같은
   도트 스톱갭 지위). 무골은 `portrait_stem = ""`로 남아 대화창에 초상 칸이 안 뜬다 — 종전과 같다.
★★ **owner Gemini 교체 1순위 = 무골 초상화**(2×3 표정 그리드). 요구할 것: 얼굴이 **맨 두개골**일 것 ·
   안와의 창백한 혼불 · 사람 피부색 0. 2순위 = 풀무 초상화(외뿔 추가 + 사람 피부 → 도깨비 살갗).
```

### 17.5 업화로 화덕 `props/smithy_forge.png`

```
파일: game/assets/props/smithy_forge.png (64×32 = 2×1칸 · raw: props/smithy_forge_raw.png 64×48)
배선: main._draw_smithy_room() — 좌표는 그레이박스와 **같은 칸**(SMITHY_RECT +2, +1)이고 모루
  (smithy_anvil)와 같은 규격이라 드로우 문법이 하나다.
  PROMPT: a blacksmith forge hearth, a wide squat stone masonry furnace with a deep arched fire opening
    in the front glowing hot orange with burning coals, a heavy iron hood over the top, a small bellows
    nozzle at the side, dark soot stained slate blocks, wide and low
후처리: 하드 알파 → muted(0.86/0.94 — 대장간 외관 smithy_ext와 같은 검댕 계수라 안팎이 한 집으로
  읽힌다) → **높이 32에 맞춰 비례 축소** 후 64×32 프레임 바닥 정렬.
★raw를 64×48로 뽑고 32로 줄인 이유: 아치 + 후드가 세로로 서는 물건이라 그 비율로 생성해야 형태가
  나오고, 배치는 §16.6의 "**벽 링은 안 덮는다**"(목재 기둥·벽이 남아야 바위를 깎아 들인 방이 된다)를
  지켜야 한다. 늘리지 않고 줄이기만 하므로 청키는 보존된다.
★정체성 기준: **불이 보일 것**. 아치 안의 주홍 잉걸이 이 프롭의 전부다(외관 smithy_ext의 "창에서
  새는 화덕 주홍"이 안에 들어오면 이것이라는 약속의 이행). 불이 빠지면 그냥 돌 상자다.
```

### 17.6 이 패스가 바꾼 렌더 (아트 생성물 아님 — 코드)

```
① `_draw_mine_mobs` — 종별 색 3단 사각 → **MOB_TEX 텍스처**(위장 = mine_rock + 그림자 · 플래시 =
   modulate 1.9 · 보스 1.7배 배율 코드 삭제). 아이콘 없는 종은 옛 색박스로 폴백(로스터 확장 방어).
② `_draw_smithy_room` — 화덕 붉은 사각 3겹 → `SMITHY_TEX_FORGE` 한 장.
③ `MINE_ICONS` 신설 + `_merge_t10_icons`·`_item_icon`에 각 한 줄 — 핫바·인벤·매대·토스트 4경로가
   한 번에 텍스처를 집는다(두 곳에 같은 루프를 두 번 적는 S3-T10 사고의 정리판을 그대로 탄다).
④ `FISH_ICONS` +2(갱도 어종) · `r_pulmu.portrait_stem` "" → "pulmu".
★ **지상 구역 렌더 불변 확인**(T9 방식): 결정적 오프라인 합성 덤프 3면
  (`tools/{home_full_dump,village_dump,map_dump}.png` = 안식 농원·나루 마을·전체 월드맵)이 HEAD와
  **바이트 동일**. 숲 2구역(`playtest/forest_dump.gd`)은 라이브 화면 grab이라 **같은 코드로 2회
  실행해도 바이트가 갈리는 비결정 하네스**임을 실측 확인했고(캐릭터 애니 위상·시계 분), HEAD↔본 패스
  차분이 HEAD↔HEAD 노이즈와 **같은 크기대**(평균 0.0~1.7)임으로 갈음했다.
  ⚠ 미래 세션 주의: forest_dump·mine_dump류 화면 grab 덤프는 **골든 비교에 못 쓴다**(육안 전용).
    바이트 골든이 필요하면 오프라인 합성 덤프(tools/*_dump.gd)를 쓸 것.
```

---

## 18. ★[S6-T8] 카페 아트 패스 1 — 메뉴 아이콘 16·설비 프롭 2·HUD 배지 2·손님 상 6 스펙카드 (owner Gemini 무수정 교체 대기)

> **상태:** PixelLab 생성 + 후처리로 **인게임 배선 완료**(2026-08-10). §10~§17과 같은 [ADR-0048] 교체
> 큐다 — owner가 같은 파일명·크기로 다시 뽑아 `*_raw.png`만 덮어쓰면 **코드 0줄 수정**으로 반영된다.
>
> **후처리 글루:** [`game/tools/make_s6_art.py`](../../game/tools/make_s6_art.py)
> **raw 보관:** `game/assets/menu/raw/*_raw.png`(16) · `game/assets/props/raw/{larder,ship_bin}_raw.png` ·
> `game/assets/ui/raw/{cheki_camera,cocktail_shaker}_raw.png` ·
> `game/assets/characters/guest_raw/guest_anon_{0,1}_raw.png`
> **육안 하네스:** `godot --path game --script res://playtest/s6_art_dump.gd`(★비-headless, 신설)
> → `/tmp/s6art_{cafe_room,larder_panel,inv_menu,hud_cheki,hud_cocktail,night_bar}.png`.
> 기존 `cafe_larder_dump.gd`도 그대로 이 패스의 판정면이 된다.
>
> **PixelLab 사용량 26 gen**(create_image_pixen 26회 = 1 gen/장). 목표 ~30 안이다. 내역:
>   · 메뉴 아이콘 16종 = 19 gen(붕어빵·크림수프·스무디 3장은 1차 리젝 후 재생성 — 아래 ★리젝 기준)
>   · 설비 프롭 2 = 2 gen · HUD 배지 2 = 2 gen
>   · 익명 손님 원본 2장 = 3 gen(1장은 *서 있는* 판이 나와 폐기 — 앉은 상만 쓴다)
>   · **손님 상 6종 중 4종 = 틴트 파생 0 gen** · **명명 손님 6인 = 신규 생성 0**(주민 시트 재사용) ·
>     **밤 바 잡귀 3종 = 신규 생성 0**(S5-T10 `MOB_TEX` 재사용)
>
> **이 패스로 카페 무대의 그레이박스 시각 요소가 0이 됐다** — 메뉴 색박스 16종, 곳간 찬장·출하함
> 궤짝 절차 도형, 좌석 회색 형체(낮·밤), 밤 바 잡귀 색박스, 주문 말풍선 색 사각이 전부 도트로
> 교체됐다. 미니게임 HUD 둘은 한지 판 위에 **정체 배지**가 붙어 서로 갈린다.

### 18.0 공통 규약

```
전부 [ADR-0050] 32-native · [§1.1] NW 광원 · [§8.1] 하드 알파 · [§9] 저승 muted.
생성: 전부 create_image_pixen(single color outline / medium detail / side 또는 high top-down /
      no_background=true / seed 고정) — §17의 create_map_object 대신 pixen을 쓴 이유는
      **32² 소품이 pixen에서 더 깨끗**하고 1 gen이라 리젝-재생성이 싸기 때문이다(예산 절약의 본체).
muted 계수(한 목록에 나란히 서는 것끼리 같은 값이어야 새것만 안 튄다):
  메뉴 아이콘 0.90/0.97 (§15.0·§17.0 아이콘과 **같은 값** — 인벤 격자에서 채집물·어획물과 섞인다)
  설비 프롭   0.85/0.95 (수액 채취기 프롭과 같은 값 — 실내 가구 톤)
  HUD 배지    0.94/1.00 (어두운 한지 판 위 작은 표식이라 더 누르면 판에 묻힌다)
  익명 손님   0.90/0.97 + 혼빛 틴트(파생분)
★리젝 기준(이번에 실제로 3장 리젝):
  ① 정체가 딴것으로 읽히면 재생성 — 붕어빵 1차가 **무지개색 진짜 물고기**로 나와 어롱 아이콘과
     겹쳤다(2차는 균일한 구운 황갈로 확정). ② 시그니처 재료색이 안 실리면 재생성(크림수프 1차 =
     토마토빛). ③ 캔버스 구석에 **떨어진 얼룩**이 남으면 재생성(스무디 1차 우상단 — 작은 조각을
     휴리스틱으로 지우면 김·크림 같은 정상 분리 요소까지 지워져, 지우기보다 다시 뽑는 게 싸다).
```

### 18.1 ★메뉴 아이콘 16종 `menu/<메뉴 id>.png` (각 32×32) — 잔·접시가 곧 분류

```
파일명 = MenuCatalog의 메뉴 id 그대로 = 배선(main.MENU_ICONS가 그 id로 preload).
기본 4(무재료·항시 — 잔이 소박하다):
  menu_americano      머그의 검은 커피(김 두 줄)        menu_cold_water   얼음 든 유리컵
  menu_barley_tea     잿빛 질그릇 잔 + 볶은 보리빛      menu_hot_milk     뽀얀 우유 머그
융합 음료 7(판매 전용 — 시그니처 재료색이 잔에 든다):
  menu_honryeongcho_latte 초록 라떼(잎 라떼아트)  menu_pianhwa_ade     붉은 에이드 + 꽃잎
  menu_hobak_latte        주황 라떼 + 크림 소용돌이  menu_podo_smoothie 자보라 스무디 + 빨대
  menu_haepari_ade        옅은 청 젤리 에이드      menu_dongbaek_milktea 분홍 밀크티 + 동백
  menu_honjeong_einspanner ★굽 달린 잔 + 두꺼운 크림 뚜껑 + 금테
곁들이 요리 5(먹으면 혼력 — S6-T7 SIDE_DISHES · **접시·그릇에 담긴 것**):
  menu_bulsagwa_tart 접시 위 사과 타르트  menu_bungeo_ppang 구운 황갈 붕어빵 한 마리
  menu_domi_panini   그릴 자국 파니니     menu_songi_soup   버섯 크림수프 한 그릇
  menu_danpung_pancake 팬케이크 3단 + 호박빛 시럽
★★ **실루엣 계급이 곧 규칙의 시각화다**: "마시는 잔은 팔고 먹는 것은 든든하다"(S6-T7이 곁들이를
   가른 규칙)가 잔↔접시로 한눈에 읽힌다 — 별도 UI 설명이 필요 없다.
★  최상위 나락혼정 아인슈페너만 **굽 달린 유리잔**이다(머그·톨글라스 계급 밖) — 로스터 꼭대기가
   가격표를 안 보고도 보인다.
★  owner 메뉴판 대조(ADR-0064 결정 2 · 큐 1순위)로 이름이 바뀌어도 **그림은 그대로 쓸 수 있다** —
   아이콘은 *번안 원본*(`MenuCatalog.raw_of` = 아메리카노·에이드·타르트…)을 그린 것이지 저승
   이름을 그린 게 아니다. 재료색만 시그니처를 따라간다.
```

### 18.2 곳간 `props/larder.png` (32×64 = 세로 2칸) · 출하함 `props/ship_bin.png` (32×32)

```
곳간  = 벽에 기대선 나무 찬장(단마다 항아리·자루·절인 것). LARDER_TILE(9,88) 바닥 발치정렬 →
        위 칸(9,87 = 빈 뒷벽)으로 솟는다. 뒷벽 선반 프롭(x11·13·15)과 안 겹친다.
출하함 = 뚜껑·쇠 모서리쇠를 두른 나무 궤짝(바닥 1칸).
★ 세로 찬장 ↔ 바닥 궤짝으로 **체급과 자세를 갈랐다** — 같은 방 양 끝의 두 창구를 헷갈리면
  "팔까(출하) / 키울까(곳간)"의 선택이 사고로 갈린다(CONTEXT [곳간]).
★ 둘 다 **빈 설비만** 굽는다. 재고 표식(곳간 = 아래 단부터 차오르는 곡물빛 / 출하함 = 뚜껑 위
  밝은 점)은 코드가 스프라이트 **위에** 얹는다 — 재고가 그림에 박히면 텅 빈 곳간도 늘 차 보인다.
★ 출하함은 스코프 밖이었다가 함께 구웠다: 같은 방 반대쪽 끝의 창구 하나만 도트면 남은 쪽이
  오히려 튀어 보인다(§15.5 "한 카테고리 절반만 도트" 교훈의 재적용).
```

### 18.3 HUD 배지 2종 `ui/{cheki_camera,cocktail_shaker}.png` (각 24×24)

```
cheki_camera    = 큰 렌즈 달린 인스턴트 카메라(낮 체키)
cocktail_shaker = 뚜껑 덮인 놋쇠 셰이커(밤 칵테일)
★ **판은 처음부터 한지였다**(HanjiUi.draw_plate) — 이번에 더한 건 판 왼쪽 배지다. 체키 판과
  칵테일 판은 규격도 자리도 같아(_CHUD_*/_KHUD_* 동일) 트랙 모양만으론 두 미니게임이 안 갈렸다.
★ 판 폭이 92 → 122(=92+24+6)로 넓어지고 **트랙 폭은 그대로**다 — 판정 난이도 불변(스윗존은
  트랙 폭의 비율로 그려지므로 트랙을 줄였다면 관대함이 조용히 바뀌었을 것).
```

### 18.4 익명 손님 상 6종 `characters/guest_anon_{a0,a1,a2,b0,b1,b2}.png` (각 32×48)

```
원본 2장(★생성물 2장뿐):
  guest_anon_0_raw = 두건 쓴 창백한 혼(스툴에 앉음)   guest_anon_1_raw = 탈 쓴 작은 요괴(앉음)
파생 4 = 혼빛 틴트(make_s6_art.GUEST_TINTS — hue 완전 교체 + 채도 가산, 어두운 외곽선 제외).
  a1 서늘한 청 · a2 옅은 자보라 · b1 마른 갈금 · b2 이끼빛 청록
★ 익명은 *정체가 없는 것*이 정의라 실루엣을 6가지로 벌릴 필요가 없다 — 혼빛만 다른 무리가
  "이름 없는 손님들"로 읽힌다(씨앗 봉지 9종 §15.3과 같은 판단).
★ **명명 손님은 신규 생성 0** — `GUEST_SHEETS`가 기존 주민 시트(neo·boatman·ongi·mochi·pulmu·
  mugol)의 **남향 행 첫 프레임**을 좌석에 앉힌다. 얼굴이 보여야 "아는 사람이 왔다"가 표식 없이
  읽히므로 뒷모습(북향 행)을 쓰지 않는다. 발치를 칸 아래변에 맞춰 상반신이 카운터 위로 올라온다
  (손님은 카운터보다 남쪽 = 가까운 쪽이라 카운터를 가리는 것이 탑다운 위상상 맞다).
★ 뽑기는 **좌석·날짜로 결정적**이다(매 프레임 굴리면 깜빡인다). 낮 카페 salt=0 / 밤 바 salt=1 —
  같은 좌석에 같은 익명이 밤낮으로 앉아 있으면 "손님이 바뀌었다"가 안 읽힌다.
```

### 18.5 이 패스가 바꾼 렌더 (아트 생성물 아님 — 코드)

```
① `MENU_ICONS` 신설 + `_merge_t10_icons`·`_item_icon`에 각 한 줄 — 핫바·인벤·곳간 패널·매대·
   토스트가 한 번에 텍스처를 집는다(메뉴 = CAT_CONSUMABLE이라 드로우 분기 추가 0).
② `_draw_want_bubble` — 색 사각 8² → **한지 판 + 메뉴 아이콘 16²**. 인벤에서 본 그 잔이 손님
   머리 위에 그대로 뜬다(색만으론 12색을 못 외운다). 아이콘 없으면 옛 색 사각 폴백.
③ `_draw_guest_figure` 신설 — 좌석 회색 형체 → 명명=주민 시트 / 익명=`GUEST_ANON`. 밤 바 손님도
   같은 함수를 탄다(밤은 전원 익명 확정이라 빈 id를 넘긴다).
④ `_draw_state_bar` 신설 — 머리 위 인내심·접근 바를 그레이박스 형체에서 **떼어 냈다**. 상이
   그레이박스든 도트든 같은 바 하나를 쓴다(두 벌로 갈리면 아트 상만 바가 어긋난다).
⑤ `_draw_guest_mark` — 명명 전원 → **단골에게만**. 좌석에 진짜 얼굴이 앉은 뒤로는 "아는 얼굴"을
   사람이 말하므로, 점에 남은 일은 얼굴로 못 읽는 눈금(*몇 번 왔나*)뿐이다.
⑥ `_draw_larder`·`_draw_ship_bin` — 절차 도형 → `_prop_tex` 훅(없으면 옛 그레이박스 폴백).
⑦ `_draw_jobgui` — 색박스 → `MOB_TEX` 3종(허깨비·어둑깨비·그슨대) 결정적 뽑기. 신규 생성 0.
⑧ `_draw_hud_badge` 신설 + 체키·칵테일 판 폭 확장 · `_notice(..., icon)` 넷째 인자 개방 —
   서빙·체키·곁들이 알림이 나간 잔의 아이콘을 함께 띄운다(`_toast_item`이 쓰던 그 경로).
⑨ `inv_frame._draw_larder_top` — 재고 행 오른쪽 "융합 메뉴 이름·가격" 앞에 그 메뉴 잔 18² 한 장.
   왼쪽 재료 아이콘 ↔ 오른쪽 메뉴 아이콘이 한 줄에서 마주 본다("이 재료가 저 잔이 된다").
⚠ 이 패스의 판정면은 **화면 grab 하네스**(s6_art_dump)라 **골든 비교에 못 쓴다**(육안 전용 —
  §17.6 교훈). 카페 실내는 오프라인 합성 덤프의 대상 밖이라 바이트 골든이 원래 없었다.
```

---

## 19. ★[S6-T9] 카페 아트 패스 2 — 주방요괴 시트·손님 상 변주 2 스펙카드 (owner Gemini 무수정 교체 대기)

> **상태:** PixelLab 생성 + 후처리로 **인게임 배선 완료**(2026-08-10). §10~§18과 같은 [ADR-0048] 교체
> 큐다 — owner가 같은 파일명·크기로 다시 뽑아 `*_raw` 쪽만 덮어쓰면 **코드 0줄 수정**으로 반영된다.
>
> **후처리 글루:** [`game/tools/make_s6_art.py`](../../game/tools/make_s6_art.py) — §18의 그 파일에
> `build_kitchen_youkai()` 한 절을 더했다(새 스크립트를 안 만든다: 같은 무대의 아트가 두 글루로
> 갈리면 muted 계수가 서로 몰래 어긋난다). 매번 raw에서 새로 굽는 **멱등** 성질도 그대로다.
> **raw 보관:** `game/assets/characters/kitchen_youkai_raw/{south,north,east,west}.png`(각 64²) ·
> 익명 손님은 §18의 `guest_raw/guest_anon_{0,1}_raw.png`를 **그대로 재사용**(신규 raw 0).
> **육안 하네스:** `godot --path game --script res://playtest/s6_art_dump.gd`(★비-headless, §18 신설분
> 무수정) → `/tmp/s6art_cafe_room.png`(낮 직원 줄 = 주방요괴)·`/tmp/s6art_night_bar.png`(밤 좌석).
>
> **PixelLab 사용량 2 gen**(create_character 2회 = standard 1 gen/캐릭터). 목표 ~5 안이다. 내역:
>   · 주방요괴 시트 = 2 gen(1차 리젝 — 아래 ★리젝) · **익명 손님 변주 2종 = 0 gen**(틴트 파생) ·
>     초상화 = **0 gen**(안 만든다 — 관계 트랙 0)
>
> **이 패스로 카페 무대의 그레이박스 시각 요소가 정말 0이 됐다** — §18이 손님·설비·아이콘을 덮고
> 남긴 마지막 색박스가 주방요괴 몸통이었다. 이제 `_draw_graybox_figure`는 **낮 카페·밤 바 어디서도
> 호출되지 않는다**(§19.4 확인).

### 19.0 공통 규약

```
전부 [ADR-0050] 32-native · [§1.1] NW 광원 · [§8.1] 하드 알파 · [§9] 저승 muted.
생성: create_character(mode=standard / n_directions=4 / **size=44** / low top-down /
      selective outline / basic shading / high detail / tgs=11 / §11.4 공통 proportions)
      — §17.4 점주 2인(풀무·무골)과 **한 글자도 다르지 않은 호출**이다. 카페 직원 줄에서
      옥자·멜·미호와 어깨를 나란히 하므로, 다른 값을 쓰면 이 한 사람만 덩치·선이 튄다.
muted 계수: 주방요괴 0.94/0.98(= §17.0 점주·옹이와 같은 값 — 출하 캐스트와 나란히 서는 층) ·
      익명 손님 0.90/0.97 + 혼빛 틴트(§18.0 그대로, 새 값 0)
★리젝 기준(§18.0 3항 + 이번에 추가된 1항):
  ④ **두건이 머리카락으로 읽히면 재생성.** 1차가 "회청 살갗 + 긴 검은 머리 + 앞치마"로 나와
     주방 직원이 아니라 *기괴한 여인*으로 읽혔다(정체가 서랍인 캐릭터에서 가장 비싼 오독 —
     보는 사람이 없는 사연을 지어낸다). 2차에서 `a pale cloth headscarf tied tightly over the
     whole head hiding all hair`로 못 박아 두건이 나왔다. **머릿수건 + 앞치마 = 직업**이고
     **잿빛 살갗 + 타는 눈 = 비인간**이다 — 이 둘만 있으면 정체는 계속 서랍에 남는다.
```

### 19.1 ★주방요괴 시트 `characters/kitchen_youkai.png` (80×320 = 프레임 80² · 1열 × 4행)

```
배선: kitchen_youkai.gd `CharSprite.make("res://assets/characters/kitchen_youkai.png")` —
  **이미 있던 훅, 파일만 채웠다**(S6-T7이 깔아 둔 그 훅 = 코드 0줄. 네오·풀무·무골과 같은 결).
  자리는 KITCHEN_TILE(11,88) = 카페 직원 줄, 곳간(9,88) 바로 옆. **1열(정지 rotation)**인 이유는
  자리가 하나뿐이라 실제로 안 걷기 때문이다(워크 첫 프레임은 스트라이드라 서 있어야 할 NPC가
  걷는 듯 보인다 — §11.4 네오와 같은 판단).
  PROMPT: chibi underworld kitchen youkai cook standing straight, no human skin anywhere, ashen grey
    blue hide, a pale cloth headscarf tied tightly over the whole head hiding all hair, the face
    beneath it sunk in deep shadow with only two glowing amber lantern eyes showing, no nose and no
    mouth visible, wearing a long off-white cook's apron over dark charcoal work clothes with rolled
    up sleeves, arms straight down at the sides, stocky and sturdy, no horns and no tail,
    muted underworld palette
후처리: 하드 알파 → muted(0.94/0.98) → 80² 프레임 발치정렬(FOOT_Y=74). 실측 콘텐츠 높이 49px로
  최근 NPC(옹이 49·무골 48·뱃사공 48)와 같은 체급에 들었다.
★★ **정체를 특정하는 형태를 안 그린다**(CONTEXT [주방요괴] "구체 정체는 서랍" · [ADR-0064] 결정 8).
   프롬프트의 `no horns and no tail`이 그 규칙의 생성 측 표현이다 — 뿔·귀·꼬리가 붙는 순간 종족이
   정해지고, 종족이 정해지면 없는 서사가 딸려 온다(관계 트랙 0인 배경 직원에겐 빚이다).
   그레이박스 `kitchen_youkai.gd _draw`가 남긴 식별 토큰 둘 — **오프화이트 앞치마**와 **등불빛 눈
   한 쌍** — 이 도트에서도 그대로 살아 있다. 그레이박스가 아트의 스펙 카드였다는 뜻이다.
★  **초상화는 만들지 않는다**(portrait_stem="" 유지). 무골과 같은 자리다: 대화창 초상 칸은 하트
   단계 표정을 가진 캐릭터의 장치라, 트랙 0인 직원에게 칸을 열면 "깊이가 있는 사람"이라는 잘못된
   약속이 된다. owner 교체 큐에도 **안 올린다**(안 만드는 것이 설계다 — 미이행이 아니다).
★  north(뒷모습) 확인 완료 — 뒤통수 = 머릿수건 뒷면 + 허리끈이고 얼굴이 안 그려져 있다
   (§17.4가 "교체 시 north를 반드시 눈으로 확인할 것"으로 남긴 그 점검).
```

### 19.2 익명 손님 상 6 → 8종 `characters/guest_anon_{a3,b3}.png` (각 32×48) — 신규 생성 0

```
파생: make_s6_art.GUEST_TINTS에 두 줄(a3 = raw 0의 hue 0.72 깊은 남보라 / b3 = raw 1의 hue 0.98
  삭은 진홍). raw는 §18.4의 2장 그대로다.
배선: main.GUEST_ANON 배열에 두 preload. 뽑기가 **좌석·날짜 결정적 해시 % 배열 크기**라 배열이
  길어지는 것만으로 반영된다(추가 배선 0줄).
★ 왜 늘렸나: 낮 좌석 5석과 밤 바 좌석이 같은 날 굴러가는데 6상이면 한 화면에 같은 혼빛이 겹쳐
  앉는 일이 잦았다. 8상이면 그 확률이 눈에 띄게 준다(실루엣이 2종뿐이라 *혼빛*이 유일한 구별선인
  이상, 겹침은 곧 "복사-붙여넣기"로 읽힌다).
★ hue는 **기존 4색이 비워 둔 자리에만** 꽂았다(0.10 · 0.36 · 0.58 · 0.86 → 사이의 0.72 · 0.98).
  두 손님의 혼빛이 서로 "같은 색의 다른 명도"로 보이면 변주를 늘린 값이 그대로 사라진다.
★ 익명은 *정체가 없는 것*이 정의라 실루엣을 8가지로 벌릴 필요가 없다는 §18.4의 판단은 그대로다.
```

### 19.3 카페 실내 접지 판정 — **무변경**(손대지 않는 것이 결론)

```
곳간(32×64 찬장)·출하함(32² 궤짝)·주방요괴 자리 주변을 라이브 덤프로 확인한 결과 **부유 없음**:
찬장은 밑단 굽이 칸 아래변에 닿고, 궤짝은 바닥 칸 안에 앉아 있으며, 직원 줄 셋(멜·주방요괴·미호)의
발치선이 한 줄로 맞는다(전부 FOOT_Y=74 규약).
★ 접지 그림자를 **안 얹은 것이 규칙 준수다**: main.PROP_SHADOW_SET 주석([asset-ruleset §11])이
  "납작한 소품과 **실내 벽 가구는 제외** — 높이가 낮아 그림자가 어색하고 사인오프된 실내 배치를
  건드리지 않기 위함"으로 대상을 야외 부피 프롭에 한정해 뒀다. 곳간은 벽에 기대선 실내 가구라
  그 제외 항목에 정확히 해당한다. 실내에 타원 그림자를 하나 켜면 같은 방의 선반·액자·스툴이
  전부 안 켜진 쪽으로 남아, 없을 때보다 오히려 튄다.
```

### 19.4 잔여 그레이박스 확인 — 낮 카페·밤 바 **0**

```
`_draw_graybox_figure`의 남은 호출부는 둘뿐이고 **둘 다 도달 불가**다(폴백으로만 남는다):
  · `_draw_guest_figure` — GUEST_SHEETS(6) ⊇ GuestPool.GUEST_IDS(neo·boatman·ongi·mochi·pulmu·
    mugol) 전량 + GUEST_ANON 8상이 비어 있지 않다 → 명명·익명 어느 쪽도 폴백에 안 떨어진다.
  · `_draw_jobgui` — _BAR_JOBGUI 3종(허깨비·어둑깨비·그슨대)이 전부 MOB_TEX에 있다.
  · `kitchen_youkai.gd _draw` — CharSprite.make가 시트를 찾으면 스스로 물러난다(이번에 그렇게 됐다).
★ 폴백 자체는 **지우지 않는다**. 아트가 통째로 빠진 저장소(에셋 미임포트·부분 클론)에서도 게임이
  굴러가야 하고, 그 성질이 §18·§19를 "코드 0줄 교체 큐"로 유지시키는 바로 그 장치다.
```

### 19.5 owner Gemini 무수정 교체 큐

```
1순위 **주방요괴 정식 시트** — `kitchen_youkai_raw/{south,north,east,west}.png`(각 64² 투명배경)를
  덮어쓰고 `python3 tools/make_s6_art.py` 한 번. 요구할 것:
  ㉠ 머릿수건 + 오프화이트 앞치마(직업) ㉡ 잿빛 살갗 + 등불빛 눈 한 쌍(비인간) ㉢ **뿔·귀·꼬리 0**
     (정체는 서랍) ㉣ 사람 피부색 0 ㉤ 4방향 전부 정면 정지 자세(걷지 않는다) ㉥ north에 얼굴 금지.
  ★현행 PixelLab판의 알려진 약점: 손에 든 도구(국자)가 1차에서만 나왔고 2차엔 빠졌다 — 카운터 뒤
   상반신만 보이는 자리라 실플레이 손실은 없지만, 교체판에 국자·주걱이 들리면 "무엇을 하는 자리인가"가
   한 겹 더 읽힌다.
2순위 익명 손님 원본 2장(§18.4) 재생성 — 8상이 전부 그 2장의 파생이라 원본이 좋아지면 8상이 함께
  좋아진다. 틴트 표(GUEST_TINTS)는 그대로 쓸 수 있다.
※ 주방요괴 초상화는 **큐에 없다**(§19.1 — 안 만드는 것이 설계).
```

---

## 20. ★[S7-T9] 절기·날씨·축제 아트 패스 — 점괘 거울·행사 프롭 2·HUD 날씨 아이콘 4·절기 팔레트 12장 스펙카드 (owner Gemini 무수정 교체 대기)

> **상태:** PixelLab 생성 + 오프라인 리톤 베이크로 **인게임 배선 완료**(2026-08-11). §10~§19와 같은
> [ADR-0048] 교체 큐다 — owner가 같은 파일명·크기로 다시 뽑아 `*_raw.png`만 덮어쓰면 **코드 0줄
> 수정**으로 반영된다.
>
> **후처리 글루 2종(역할이 갈린다 — 한 파일로 합치지 않는다):**
> · [`game/tools/make_s7_art.py`](../../game/tools/make_s7_art.py) — *생성물* 후처리(하드 알파·muted·앵커).
>   규칙은 `make_s6_art.py`와 **같은 값**을 쓴다(새 규칙 0).
> · [`game/tools/retone_seasons.py`](../../game/tools/retone_seasons.py) — *기존 필드*의 절기 변주
>   베이크(색보정만·생성 0). `retone_pianjeol.py`의 직계 후속이다.
>
> **raw 보관:** `game/assets/props/raw/{fortune_mirror,derby_booth,night_market}_raw.png` ·
> `game/assets/ui/raw/weather_icon_{calm,rain,snow,soulwind}_raw.png`
>
> **육안 하네스:** `godot --headless --path game -s res://tools/season_ground_dump.gd`(신설) →
> `game/tools/season_ground_{pianhwa,yuhwa,mangyeon,seongya}.png` + `season_ground_sheet.png`(2×2 대조).
> 기존 `home_full_dump.gd`·`weather_dump.gd`도 그대로 이 패스의 판정면이다.
>
> **PixelLab 사용량 8 gen**(create_image_pixen 8회 = 1 gen/장, 리젝 0). 내역:
>   · 점괘 거울 1 · 행사 프롭 2 · HUD 날씨 아이콘 4 · **메이드 초상 화풍 프로브 1**(생성물은 폐기 —
>     §20.5의 판단 근거로만 씀) · **절기 팔레트 12장 = 0 gen**(전부 기존 필드의 색보정 파생)
>
> **이 패스가 지운 그레이박스:** 점괘 거울 절차 도형(테·유리·광택선), 더비 부스·야시장 매대 절차
> 도형, HUD 날씨 평면 청크 글리프 4. **남긴 그레이박스:** 테마 데이 의상(§20.5 — 의도적 유지).

### 20.0 공통 규약

```
전부 [ADR-0050] 32-native · [§1.1] NW 광원 · [§8.1] 하드 알파 · [§9] 저승 muted · [§3] 발치 앵커.
생성: create_image_pixen(selective outline 또는 single color black outline / low detail /
      no_background=true / seed 고정) — §18.0이 세운 그 호출이다(32² 안팎 소품은 pixen이 가장
      깨끗하고 1 gen이라 리젝-재생성이 싸다).
muted 계수(한 자리에 나란히 서는 것끼리 같은 값이라야 새것만 안 튄다):
  월드 프롭 0.85/0.95 (= §18.2 곳간·출하함과 **같은 값** — 같은 실내·야외 프롭 층)
  HUD 아이콘 0.94/1.00 (= §18.0 미니게임 배지와 같은 값 — 어두운 한지 판 위 작은 표식)
★청키화(enforce_chunk)는 **걸지 않는다**: 현행 shipping 프롭의 2×2 블록비가 larder 0.068 ·
  ship_bin 0.136이라 이번 3장(0.10~0.11)과 같은 결이다. 여기만 2px로 굳히면 실내 한 벽에서
  이 하나만 굵어진다 — [§0.1] 캐논보다 "한 화면 한 그레인"이 우선인 자리(S6 패스가 그은 선).
```

### 20.1 ★점괘 거울 `props/fortune_mirror.png` (32×64 = 세로 2칸) — 예보 매개체의 얼굴

```
배선: main._draw_fortune_mirror의 `_prop_tex("fortune_mirror")` 훅 — T4가 미리 깔아 둔 훅이다.
  자리 = MIRROR_TILE(17,68) 집 실내 **북벽 flush**, 책장(15..16)과 화분(18) 사이.
★앵커 교정 1건(T9에서 훅을 한 줄 고쳤다 — "코드 0줄"이 안 된 유일한 프롭):
  T4의 아트 분기가 `oy + TILE - h`(oy에 `WALL_PROP_LIFT` -18 포함)로 적혀 있었는데, 그 리프트는
  높이 48짜리 *그레이박스 도형*을 벽 띠 안으로 밀어 넣던 보정값이다. 32×64 아트에 그대로 먹이면
  거울 관이 **벽 위 방 밖(타일이 없는 검은 띠)으로 18px 솟는다**(T9 배치 덤프에서 적발).
  집 북벽 띠는 **y67·68 두 줄 = 정확히 64px**이라, 리프트 없이 타일 하단(y68 bottom)에 발치정렬하면
  아트 상단이 벽 상단과 저절로 맞는다 → [§3] "북벽 = art 바텀을 벽 띠 하단 모서리에" 그대로.
  ⇒ **교체판도 반드시 32×64**로 뽑을 것. 높이가 달라지면 이 flush가 깨진다.
  PROMPT: tall vertical oval fortune-telling mirror hanging on a wall, dark ink-stained wood frame
    wrapped with pale hanji paper strips, faint ghostly blue divination glow inside the oval glass,
    small carved wooden base at the bottom, korean afterlife shrine object, [§1.1 광원 세트],
    muted somber palette   (view=side / selective outline / low detail / seed 70901)
후처리: 하드 알파 → muted(0.85/0.95) → 32×64 발치정렬.
★★ **세로 타원 + 한지 감은 테**가 정체의 전부다 — 무녀 옥자의 점술 결이지 라디오·TV가 아니다
   (ADR-0065 결정 6이 "점괘 거울"로 이름을 정한 그 이유의 그림판).
★  **오늘의 운 등급 색은 굽지 않는다.** 그레이박스가 거울면에 깔던 등급 틴트(대흉 잿빛 → 대길 금박)는
   날마다 바뀌는 상태라 아트에 박으면 늘 같은 운이 된다 — 재고 표식을 스프라이트에 안 굽는 곳간·
   출하함(§18.2)과 **완전히 같은 규율**이다. 지금 아트판은 틴트를 얹지 않고 `return`하므로,
   교체판에 등급을 얹고 싶으면 그때 코드가 위에 그린다(아트는 빈 거울만).
★  거울 안의 푸른 빛은 **정체(점괘)**이지 상태가 아니라 구워도 된다 — 늘 켜져 있는 것이니까.
```

### 20.2 행사 프롭 2종 `props/derby_booth.png` · `props/night_market.png` (각 32×48) — 오버레이의 얼굴

```
배선: main._draw_derby_booth / _draw_night_market의 `_prop_tex(…)` 훅(신설 2줄씩). 자리 =
  DERBY_BOOTH_TILE(강변 산책로) · NIGHT_MARKET_TILE(광장). 발치정렬로 차양이 위 칸으로 솟는다.
더비 부스 = 판자 좌판 + **다홍 차양 + 금빛 띠**(Festival.BANNER_A/B와 같은 색계 = "잔치"). 피안 12일.
  PROMPT: small festival market booth stall, wooden plank counter table with two legs, crimson red
    cloth awning canopy with gold trim stripe, festive fishing derby prize stand, korean afterlife
    festival, [§1.1 광원 세트], muted somber palette (view=low top-down / seed 70902)
야시장 매대 = 짙은 남빛 좌판 + 검붉은 차일 + **등롱 두 알**. 성야 15일.
  PROMPT: small night market vendor stall, dark indigo wooden counter table, deep crimson cloth
    canopy, two glowing warm paper lanterns hanging from the canopy poles, korean afterlife night
    bazaar, [§1.1 광원 세트], muted somber palette (view=low top-down / seed 70903)
★★ **행사일이 아니면 한 픽셀도 안 그린다** — 두 `_draw_*`가 첫 줄에서 반환한다. 오버레이 전용
   (ADR-0065 결정 9 "맵 잠금 0")이라는 정체성이 렌더 층에도 그대로 있다: 잔치가 끝나면 무대에
   흔적이 0이다. 타일·충돌은 애초에 안 건드리므로 지울 상태도 없다.
★  더비 부스 위 **금빛 태그 점**(지금 든 태그가 있을 때)은 코드가 아트 **위에** 얹는다 — 상자
   "보관 중" 점·곳간 재고와 같은 규율(상태는 굽지 않는다).
★  등롱 빛은 굽는다(늘 켜진 정체) — 거울의 푸른 빛과 같은 기준.
★★ **교체 시 고칠 것(현행 PixelLab판의 알려진 약점):** 두 매대 모두 **측면 벽이 살짝 보이는
   3/4 결**로 나왔다(특히 야시장 매대의 우측면). [ADR-0036] §2 "측면 벽 렌더 금지·정면 facade"는
   건물 규칙이라 1칸 소품엔 강제되지 않고, 행사일에만 서는 임시 프롭이라 이번엔 통과시켰다.
   다만 같은 무대의 다른 프롭이 전부 정면 평면이므로 **교체판은 정면 평면으로 뽑는 편이 낫다**
   (프롬프트에 `front-facing, flat front elevation, NOT isometric, NOT angled`를 더할 것).
```

### 20.3 HUD 날씨 아이콘 4종 `ui/weather_icon_{calm,rain,snow,soulwind}.png` (각 16×16)

```
배선: clock_hud.WEATHER_ICONS 배열(인덱스 = Weather.CALM/RAIN/SNOW/SOULWIND 0..3) →
  `_draw_weather_glyph`가 draw_texture_rect 한 줄로 찍는다. **레이아웃·호출부는 T8 그대로**
  (icon_x 계산·ICON_PX=16 불변).
  평온 calm  = 창백한 해 원반 + 짧은 빛살(muted warm gold)
  혼우 rain  = 잿빛 구름 + 빗방울 세 줄기(muted blue grey)
  잿눈 snow  = 재로 된 6방 눈송이(회백 결정)
  혼불 soulwind = 보랏빛 도깨비불 + 흰 심지
  PROMPT 공통 꼬리: flat 2D pixel art, light source from top-left, distinct step-shading,
    no smooth gradients, dark outline, centered single object (view=side / black outline / seed 7091x)
후처리: 하드 알파 → muted(0.94/1.00) → 16² 중앙정렬.
★★ **왜 생성했나(스킵하지 않은 근거):** 이 심볼은 절기 심볼(`ui/season_icon_*.png` 16²)과 **같은
   HUD 줄에 나란히** 선다. 절기 쪽은 음영 있는 생성 아트인데 날씨만 평면 2색 절차 청크라 한 줄
   안에서 결이 갈렸다 — ADR-0065 결정 10이 처음부터 "절기 아이콘 선례 동형"이라 적은 자리다.
★  T8의 절차 청크 표 `ClockHud.weather_chunks`는 **지우지 않았다**: 오프라인 합성 덤프
   (`tools/weather_dump.gd`)가 그 표를 읽어 이미지에 찍는다(화면 grab 불가 = 덤프는 표를 공유해야
   한다). 아트 교체는 HUD 렌더만 갈아탄 것이지 데이터를 버린 게 아니다.
```

### 20.4 ★절기 팔레트 파생 12장 `terrain16/seasons/{yuhwa,mangyeon,seongya}/*.png` — 생성 0, 색보정 파생

```
소스(런타임이 실제로 읽는 파일과 1:1 — 지금 _TERRAIN_SINGLE_SOURCE=true):
  single_source/grass_field.png(_bf_grass) · single_source/dirt_field.png(_bf_earth 마당 맨흙) ·
  single_source/path_field.png(_bf_dirt 흙길) · soil_field.png(_bf_soil 갈아엎은 밭흙)
산출: 위 4장 × 3절기 = 12장. **피안절은 0장**(원본 그대로 = 경로 분기만 = 기존 골든 덤프 불변).
배선: main._big_field 첫 줄의 `_seasonal_path(path)` — 단일출처든 shipping이든 밭흙 직접 로드든
  **한 관문**에서 절기가 걸린다. 절기 전환·세이브 재개는 `_refresh_season_terrain(true)`가 base
  필드 + 파생 캐시(Wang 전환 타일·물가 마스크·데칼 틴트)를 버리고 구역을 한 번 다시 굽는다.
레버(retone_seasons.PROFILES — [색상목표°, 당김, 채도, 명도, R·G·B 캐스트]):
  유화 grass [108, 0.58, 1.32, 0.89, 1.02/1.01/0.94] · earth [32, 0.35, 1.12, 1.02, 1.04/1.00/0.93]
  망연 grass [ 34, 0.82, 1.14, 1.04, 1.04/1.00/0.92] · earth [22, 0.45, 1.00, 0.94, 1.03/0.99/0.93]
  성야 grass [  –,    0, 0.22, 0.96, 0.94/0.98/1.10] · earth [ –,    0, 0.34, 0.88, 0.95/0.98/1.08]
  (밭흙 soil은 계열마다 더 얕게 — 밭은 "방금 판 젖은 검은 흙"이 정체라 크게 물들이면 갈아엎은
   칸과 안 갈아엎은 칸의 구분이 흐려진다.)
★★ **색수 증가 0**(ADR-0057 저색 crisp 보존): 변환이 픽셀값→픽셀값 순수 함수라 출력 색수는 입력을
   넘을 수 없다. 스크립트가 매번 in/out 색수를 찍는다 — 실측 13→13 · 11→11 · 9→9 · 45→45(성야만
   충돌로 13→10 · 11→9 · 9→7로 **줄었다**).
★  성야에 hue를 안 쓰는 이유: 갈색(35°)을 파랑(215°)으로 lerp하면 최단호가 초록을 지나 흙이
   이끼색으로 착지한다. 한랭은 **채도를 걷고 쿨 캐스트를 얹어** 낸다.
★  물·모래·포석·판자는 **안 굽는다**(결정 11 "최소 세트") — 물은 얼지 않고 마을 포석·백사장은
   안식 마당 밖이다. seasons/에 파일이 없으면 자동으로 원본 폴백이라 코드 분기가 필요 없다.
★★ **owner 교체 경로:** 이 12장은 손대지 마라. 베이스 필드(single_source/*)를 새로 뽑아 넣고
   `python3 tools/retone_seasons.py` 한 번 돌리면 3절기가 통째로 따라온다 — 절기 변주를 사람이
   4벌 그리는 게 아니라 **한 벌만 그리면 나머지가 파생**되는 구조다(이 패스의 최대 절약).
★  지면 스캐터 데칼(잡초·tuft·잔돌)만 코드가 틴트한다(main._season_tint_decal) — 셀마다 골라
   합성하는 것이라 갈아 끼울 파일이 없다. 레버 수치는 위 PROFILES와 **같은 값**이고, 수치가
   둘인 유일한 자리다(한쪽을 고치면 다른 쪽도 고친다).
```

### 20.5 메이드 데이 초상 변형 — **미생성 확정**(그레이박스 유지 · Gemini 큐로 이관)

```
ADR-0065 결정 12가 "메이드 데이 초상 변형만 시도"라 적은 축이다. **시도했고, 중단했다.**
근거(정량 실측 — PixelLab 프로브 1 gen, 생성물은 폐기):
  현행 초상 assets/portraits/*.png = 320×320 · 고유색 35,521~45,628 · 부드러운 회화풍 음영(Gemini)
  PixelLab 프로브(create_image_pixen 128², 메이드 버스트) = 128×128 · **고유색 52** · 경성 도트 엣지
  → 해상도 2.5배 차 · 색수 ~900배 차. `create_portrait_character`의 상한 160으로 올려도 이 간극은
    좁혀지지 않는다(모델 자체가 픽셀아트 산출이다).
  테마 데이 **하루만** 이 그림으로 갈아 끼우면 그날만 딴사람이 된다 — 없느니만 못한 교체다.
표준 결정과의 정합: [ADR-0047] / 메모리 [gemini-full-regen-batch](owner 2026-07-02)가 캐릭터·초상
  트랙을 **Gemini 전담**으로 이미 못 박았다. S6-T9도 같은 이유로 주방요괴 초상을 안 만들었다.
  이 판단은 그 결정의 재확인이지 새 결정이 아니다.
유지되는 그레이박스: 테마 데이 의상 = `_refresh_festival` → `set_festive(true)` (월드 스프라이트
  Festival.TINT + 모자). **초상은 평시 그대로**다. 코드는 손대지 않았다.
★owner Gemini 큐(1순위) — 메이드 데이 초상 5장:
  파일: assets/portraits/{okja,miho,mel,bana}_maid.png + player 몫 1장, 각 320² 투명.
  요구: ㉠ 평시 초상과 **같은 얼굴·같은 채색 결**(같은 시트에서 뽑는 게 안전) ㉡ 의상만 메이드
     (프릴 헤드밴드 + 앞치마) ㉢ 표정은 중립 1장부터(5표정 세트는 그 다음) ㉣ 배경 투명.
  배선 예정: 테마 데이 당일에만 초상 stem을 `_maid`로 갈아 끼우는 스왑 1자리(Festival이 이미 당일을
     아는 유일 관문이라 분기 지점은 하나다). **아트가 오기 전엔 배선도 넣지 않았다** — 빈 훅은
     "곧 온다"는 약속만 남기고 검증할 것이 없다.
```

---

## 21. ★[S8-T9] 관계 심화 아트 패스 — 혼례 부적 아이콘·2인용 침대 프롭 2종 스펙카드 (owner Gemini 무수정 교체 대기)

> **상태:** PixelLab 생성 + 후처리로 **인게임 배선 완료**(2026-08-11). §10~§20과 같은 [ADR-0048]
> 교체 큐다 — owner가 같은 파일명·크기로 다시 뽑아 `*_raw.png`만 덮어쓰고
> `cd game && python3 tools/make_s8_art.py`를 한 번 돌리면 **코드 0줄 수정**으로 반영된다.
>
> **후처리 글루:** [`game/tools/make_s8_art.py`](../../game/tools/make_s8_art.py) — 규칙·계수는
> `make_s6_art.py`와 **같은 값**을 쓴다(새 규칙 0 · 하드 알파 → muted → 앵커 재정렬).
>
> **raw 보관:** `game/assets/materials/raw/wedding_charm_raw.png` ·
> `game/assets/props/raw/house_bed_double_raw.png`
>
> **PixelLab 사용량 3 gen**(create_image_pixen — 부적 1 · 침대 v1 1<내려앉음으로 폐기> · 침대 v2 1).
>
> **이 패스가 지운 색박스·그레이박스:** 혼례 부적 인벤/핫바 색박스 폴백 1종. **아트 없이 끝낸
> 나머지 항목**(에셋 0 · 절차 드로잉·색 분화로 해결): 관계 탭 상태 배지 색, 달력 생일 마커 ♥,
> 선물 토스트 tier 색 — 전부 16px 미만 UI 표식이라 생성물이 아니라 코드가 그리는 편이 선명하다.

### 21.0 공통 규약

```
전부 [ADR-0050] 32-native · [§1.1] NW 광원 · [§8.1] 하드 알파 · [§9] 저승 muted · [§3] 발치 앵커.
생성: create_image_pixen(selective outline / low detail / no_background=true / seed 고정) —
      §18.0·§20.0이 세운 그 호출이다(32² 안팎 소품은 pixen이 가장 깨끗하고 1 gen이라 싸다).
muted 계수(한 자리에 나란히 서는 것끼리 같은 값이라야 새것만 안 튄다):
  아이콘      0.90/0.97 (= §18.1 메뉴 아이콘·§17 광물 아이콘과 **같은 값** — 같은 인벤 격자)
  월드 프롭   0.85/0.95 (= §18.2 곳간·§20.1 점괘 거울과 **같은 값** — 같은 실내 가구 층)
★청키화(enforce_chunk)는 걸지 않는다 — §20.0이 그은 선 그대로(현행 실내 프롭 그레인과 정합).
```

### 21.1 ★혼례 부적 `materials/wedding_charm.png` (32×32 아이콘) — 청혼의 매개체

```
배선: main.MINE_ICONS에 한 줄(`ItemCatalog.WEDDING_CHARM: preload(...)`) — 나락 열쇠 바로 옆이다.
  부적은 CAT_MATERIAL이라 인벤 슬롯·핫바·토스트가 이미 "텍스처 있으면 쓰고 없으면 색박스" 분기를
  타고 있었다 → dict 한 줄로 세 자리가 동시에 낫는다(_merge_t10_icons·_item_icon 공용 경로).
정체성: 옥자가 5,000냥에 혼(魂)을 엮어 접어 주는 **접힌 한지 부적**이다. 스타듀 인어 펜던트의
  저승판이지만 보석이 아니라 **종이와 매듭**이라야 한다 — 무녀의 물건이지 장신구가 아니다.
  PROMPT: folded korean hanji paper talisman charm, pale cream folded paper packet, red cinnabar
    seal glyph brushed on the front, crimson silk cord tied in a knot around it with tassel ends,
    tiny brass bell hanging from the cord, korean shamanic wedding amulet, [§1.1 광원 세트],
    muted somber palette   (view=side / selective outline / low detail / seed 80801)
후처리: 하드 알파 → muted(0.90/0.97) → 32² 중앙정렬. 현행판 고유색 38.
★★ **붉은 끈 매듭**이 이 물건의 실루엣이다 — 32²에서 종이 몸통만 남으면 인벤에서 편지·씨앗 봉지와
   구분이 안 된다(같은 격자에 실제로 그 둘이 있다). 교체판도 끈을 몸통 밖으로 흘릴 것.
★  **하트·반지 도상은 쓰지 않는다** — 이 세계의 혼례 문법은 서양 결혼이 아니라 무속 의례다
   (ADR-0004 저승 정체성). 붉은색은 매듭·인장에만 쓰고 형태로는 쓰지 않는다.
★  **소유 상태는 굽지 않는다**(세상에 하나뿐인 물건이지만 아이콘은 늘 같다) — 곳간 재고·점괘
   등급을 아트에 안 굽는 §18.2·§20.1과 같은 규율.
```

### 21.2 ★2인용 침대 `props/house_bed_double.png` (32×64 = 세로 2칸) — 안방의 얼굴

```
배선: main.HOME_EXPANSION_PROPS 한 줄 → `_home_prop_entries()`가 **`_home_expanded()`일 때만**
  얹는다(미확장 세이브는 빈 배열 = 거동 바이트 불변 — 그 방 자체가 아직 VOID다).
  자리 = (22,68) 안방 북벽 밴드 한가운데. 바로 아래가 배우자 자리 SPOUSE_HOME_TILE(22,71)이다.
  lift = 다른 북벽 가구와 같은 `WALL_PROP_LIFT`(-18, 크림 트림 밀착).
★  **반드시 32×64**로 뽑을 것 — 1인 침대(`props/house_bed.png`)와 같은 규격이라야 발치·lift·
   그림자·Y-split 계산이 그대로 유효하다. 높이가 달라지면 벽 flush가 깨진다(§20.1이 겪은 그 함정).
정체성: 같은 방에 1인 침대가 **나란히 남아 있다**(옛 침대는 안 치운다 — 취침 판정이 거기 있다).
  그래서 이 침대는 1인 침대와 **같은 목재·같은 이불 결**이되 폭이 아니라 **베개 두 개**로 "둘"을
  말해야 한다(32px 폭 안에서 폭을 늘릴 수 없다 — 한 칸이 규격이다).
  PROMPT: cozy double bed seen from a low top-down view, dark stained wood headboard and footboard,
    two white pillows side by side at the head, deep muted crimson plaid quilt blanket with warm
    gold stitching, folded cream sheet at the foot, korean afterlife farmhouse bedroom furniture,
    **tall sprite filling the entire canvas from top edge to bottom edge** (풀캔버스 지시 — v2가
    이 구절로 내려앉음을 해소했다), [§1.1 광원 세트], muted somber palette
    (view=high top-down / single color black outline / medium detail / seed 80803)
후처리: 하드 알파 → muted(0.85/0.95) → 32×64 발치정렬. 현행판(v2) 고유색 54.
★★ **베개 둘 + 붉은 이불**이 전부다 — 이 방에서 "결혼했다"를 말하는 유일한 그림이라 실루엣이
   1인 침대와 확실히 갈려야 한다(혼례 연출은 배너 한 줄뿐이다 — 등급 연출은 S9).
★  **SOLID_PROPS 편입 = 통과 불가**(오케스트레이터 확정 2026-08-11 — 같은 방에 물리가 갈린
   침대 둘이면 규칙이 거짓말이 된다. 1인 침대와 정합·확장 시에만 그려져 미확장 세이브 영향 0).
★  `_prop_layouts`/layout.json **밖**에 산다(조건부 항목이라 넣으면 직렬화가 확장 여부에 따라
   갈려 시드-동등 불변식이 깨진다) — 상자·거울이 레이아웃 밖에 사는 것과 같은 결.
★★ **v2로 재생성 완료(seed 80803 — 현행 raw):** v1(seed 80802)은 콘텐츠 실높이 46px이라
   발치정렬 후 머리판이 벽 상단에 안 닿았다(1인 침대는 ~56px — 검수 합성에서 내려앉음 확인).
   v2는 프롬프트에 "filling the entire canvas from top edge to bottom edge"를 박아 64px 풀캔버스로
   해소. **교체판도 콘텐츠가 캔버스 세로를 채울 것**(캔버스 32×64 · 후처리 불변).
```

### 21.3 에셋 없이 끝낸 관계 UI 3종 (생성 0 — 절차 드로잉·색 분화)

```
전부 16px 미만의 UI 표식이라 **생성물보다 코드가 선명하다**(§20.3이 HUD 날씨 아이콘을 생성한
기준의 반대편 — 그건 옆에 생성 아트가 나란히 서는 자리였고, 이 셋은 아니다).
① 관계 탭 상태 배지 색(inv_frame.HEART_BADGE_COLORS) — 부부=진홍 (0.85,0.35,0.42) ·
   혼례 준비 중=연한 진홍 (0.88,0.55,0.58) · 연애 중=연분홍 (0.78,0.42,0.62 = 달력 MARK_BIRTHDAY
   와 같은 값) · 진급 대기=금박(현행 유지). 키 = main._heart_badge()가 만드는 문자열 그대로.
② 달력 생일 마커 ♥(calendar_panel._draw_heart_mark) — 원 2개 + 아래 삼각, 폭 ~7px. 범례가
   "♥ %d일 — %s 생일"이라 마커도 하트라야 둘이 같은 물건으로 읽힌다.
③ 선물 토스트 tier 색(main.GIFT_TIER_TINTS → notice_feed.push의 가법 `tint` 인자) —
   선호=금박 · 좋아함=연초록 (0.62,0.78,0.45) · 무난=무틴트 · 시큰둥=회색 (0.62,0.62,0.62) ·
   질색=탁적 (0.78,0.40,0.34). 생일(×8)은 tier 색 그대로(문구가 "(생일!)"로 배율을 말한다).
★ owner 교체 대상 아님(파일이 없다) — 값이 마음에 안 들면 위 상수 한 줄씩이 레버다.
```

---

## 22. ★[S9-T9] T1 2인 슬라이스 아트 패스 — 우편함·책 아이콘·혼백관 좌대·편지지 4종 스펙카드 (owner Gemini 무수정 교체 대기)

> **상태:** PixelLab 생성 + 후처리로 **인게임 배선 완료**(2026-08-13). §10~§21과 같은 [ADR-0048]
> 교체 큐다 — owner가 같은 파일명·크기로 다시 뽑아 `*_raw.png`만 덮어쓰고
> `cd game && python3 tools/make_s9_t9_art.py`를 한 번 돌리면 **코드 0줄 수정**으로 반영된다.
> (PNG를 갈아 끼운 뒤에는 `cd game && godot --headless --import` 1회 — 임포트 캐시가 소스가
> 아니라 `.godot/imported/*.ctex`를 읽는다.)
>
> **후처리 글루:** [`game/tools/make_s9_t9_art.py`](../../game/tools/make_s9_t9_art.py) — 규칙·계수는
> `make_s8_art.py`와 **같은 값**을 쓴다(새 규칙 0 · 하드 알파 → muted → 앵커 재정렬). 새로 는
> 것은 `crop_bottom`(생성물이 구워 온 접지 그림자 걷어내기) 하나뿐이다.
>
> **raw 보관:** `game/assets/props/raw/mailbox_raw.png` · `game/assets/props/raw/museum_shelf_raw.png` ·
> `game/assets/books/raw/book_icon_raw.png` · `game/assets/books/raw/note_icon_raw.png`
> (§22.4 편지지는 raw가 없다 — 생성물이 아니라 `assets/ui/dialog_window.png` 파생물이다.)
>
> **PixelLab 사용량 5 gen**(create_image_pixen — 우편함 1 · 책 1 · 노트 1 · 좌대 v1 1〈투명
> 체커를 **불투명 픽셀로 그려 와** 폐기〉 · 좌대 v2 1). **초상화 신규 0**(모찌·네오 초상화는
> 이 패스 범위 밖 — 여전히 `portrait_stem=""`/도트 버스트다).
>
> **이 패스가 지운 색박스·그레이박스:** ①우편함 draw_rect 4장 ②CAT_BOOK 23종 인벤/핫바 색박스
> ③혼백관 서가 좌대 8좌 draw_rect. **아트 없이 끝낸 항목:** 집 책장(`props/house_bookshelf.png`
> 64×64)은 **이미 아트가 있다** — 새로 굽지 않고 교체 후보로만 아래 §22.5에 적어 둔다.

### 22.0 공통 규약

```
전부 [ADR-0050] 32-native · [§1.1] NW 광원 · [§8.1] 하드 알파 · [§9] 저승 muted · [§3] 발치 앵커.
생성: create_image_pixen(selective outline / low detail / no_background=true / seed 고정) —
      §18.0·§20.0·§21.0이 세운 그 호출이다(32² 안팎 소품은 pixen이 가장 깨끗하고 1 gen이라 싸다).
muted 계수(한 자리에 나란히 서는 것끼리 같은 값이라야 새것만 안 튄다):
  아이콘        0.90/0.97 (= §18.1 메뉴·§21.1 부적과 **같은 값** — 같은 인벤 격자)
  월드 프롭     0.85/0.95 (= §18.2 곳간·§20.1 점괘 거울과 **같은 값** — 같은 야외/실내 기물 층)
  혼백관 좌대   0.62/0.90 (**이 패스만 예외** — 생성물이 붉은 칠 목재로 나왔는데 그 방의 기존
                좌대는 어두운 갈색 draw_rect다. 같은 방 같은 줄에 서므로 붉음을 눌러 합류시킨다)
★청키화(enforce_chunk)는 걸지 않는다 — §20.0·§21.0이 그은 선 그대로.
★★ 상태를 아트에 굽지 않는다: 우편함 미독 깃발·전시된 책등·되찾은 권수는 전부 코드가 그린다.
```

### 22.1 ★우편함 `props/mailbox.png` (32×32 프롭) — 편지가 오는 자리

```
배선: **코드 0줄.** `main._draw_mailbox`가 이미 `_prop_tex("mailbox")` 우선 분기라, 파일을
  `game/assets/props/`에 놓는 것이 배선의 전부다(없으면 draw_rect 그레이박스로 자동 폴백).
  자리 = HOME 야외 MAILBOX_TILE (46,10) 한 칸, 집 외관(y9) 바로 아래.
정체성: 편지·관문 여진이 도착하는 **집 앞 함**이다(S9-T3 편지 채널의 유일한 물리 창구).
  한옥 결의 어두운 판재 함 + 짧은 기둥 + 작은 기와 갓 + 한지 투입구. 서양 아메리칸 메일박스의
  둥근 아치통이 아니라 **각진 나무 함**이라야 한다.
  PROMPT: a single small korean traditional wooden mailbox letter box mounted on a short weathered
    post, dark hanok timber planks with a pale hanji paper letter slot on the front, small tiled
    roof cap over the box, thin cord wrapped around the post, [§1.1 광원 세트],
    muted somber palette   (view=low top-down / selective outline / low detail / seed 90901)
후처리: 하드 알파 → muted(0.85/0.95) → 32² bottom 앵커. 현행판 고유색 56.
★★ **붉은 깃발을 굽지 마라.** 미독 배지(붉은 부적 깃발)는 `_draw_mailbox`가 상태를 보고 절차로
   덧그린다(`ox+TILE*0.74, oy+TILE*0.1` 자리). 아트에 구우면 다 읽은 뒤에도 깃발이 남아 배지가
   거짓말을 한다 — 상태를 아트에 안 굽는 §18.2·§21.1과 같은 규율이다.
★★ **세로 32를 넘기지 마라.** 발치 앵커(`oy + TILE - h`)라 넘기면 위로 솟고, 솟은 함 몸통이
   깃발 자리를 덮어 미독을 못 읽는다.
★  붉은색은 **끈·매듭에만** 쓴다(깃발과 색이 겹치면 둘이 한 덩어리로 읽힌다).
```

### 22.2 ★책 아이콘 `books/book_icon.png` · 노트 아이콘 `books/note_icon.png` (각 32×32) — CAT_BOOK 2종

```
배선: main.BOOK_ICON/NOTE_ICON(preload) → `_merge_book_icons`(인벤·핫바 dict) + `_item_icon`
  (토스트). **23 id가 이 두 장을 공유한다**(책 8권 + 비밀 노트 15장) — 키 목록의 단일 출처는
  Books.book_ids()/note_ids()라 권수가 바뀌어도 이 파일들은 안 바뀐다.
정체성: [옥자의 잃어버린 책] = 불에서 건진 **무거운 한 챕터** / [비밀 노트] = 누가 급히 접어 둔
  **짧은 속삭임**. 두 장이 필요한 유일한 이유는 **인벤 격자에서 그 둘을 한눈에 가르는 것**이고,
  어느 권인지는 툴팁·제목·즉독 대화창이 이미 말한다(권별 아트를 굽지 않는 근거).
  PROMPT(책): a single closed thick old hardcover book lying at a slight angle, scorched dark navy
    indigo cover, a gold gilt band along the spine, charred blackened page edges, a thin faded
    ribbon bookmark, an inventory item icon, [§1.1 광원 세트], muted somber palette
    (view=side / selective outline / low detail / seed 90902)
  PROMPT(노트): a single small folded scrap of paper note, pale faded cream hanji paper, one deep
    fold crease across it, one torn ragged corner, a few illegible smudged ink strokes, an
    inventory item icon, [§1.1 광원 세트], muted somber palette
    (view=side / selective outline / low detail / seed 90903)
후처리: 하드 알파 → muted(0.90/0.97) → 32² 중앙정렬. 현행판 고유색 책 44 · 노트 33.
★★ **두 장의 실루엣이 갈려야 한다** — 책 = 두껍고 각짐(직육면체) / 노트 = 얇고 찌그러짐(구겨진
   평면). 32²에서 색만 다르고 형태가 닮으면 인벤에서 구분이 안 된다(23칸이 한 격자에 쌓인다).
★  색 언어는 폴백 색박스를 잇는다: 책 = 그을린 남색 `#47403d`~`#3d3450` + 금박 띠 /
   노트 = 바랜 종이 `#c7b894`. 이 두 색은 `item_catalog.tool_color_of`가 이미 쓰고 있다.
★  **글씨를 읽히게 그리지 마라.** 본문은 대화창이 말한다 — 표지에 판독 가능한 문자를 넣으면
   32²에서 노이즈가 되고, 로어를 아트에 굽는 것이 된다(봉인 법칙 정합).
```

### 22.3 ★혼백관 서가 좌대 `props/museum_shelf.png` (32×12 프롭) — 되찾은 책 8좌

```
배선: `main._draw_museum_room`의 서가 루프에 `_prop_tex("museum_shelf")` 분기(신규 3줄).
  8좌가 **40px 간격**으로 늘어서고, 좌대는 슬롯 기준점 `bp`에서 좌우 6px씩 흘러 가운데 맞춘다.
정체성: 유품 진열장(위 줄) 아래에 놓인 **되찾은 책 서가**. 어두운 목재 선반 널 + 앞면 구름 무늬
  + 아래 받침 브래킷 둘. 벽 서가라 발밑 그림자가 없다.
  PROMPT: a single wide low dark walnut wooden bookshelf ledge board filling the whole width of the
    image, a thick horizontal plank with a carved korean cloud motif strip along its front face and
    two stout brackets below it, museum display shelf, front view, solid opaque wood,
    [§1.1 광원 세트], muted somber palette
    (view=side / selective outline / low detail / seed 90914)
후처리: 하드 알파 → muted(0.62/0.90) → 접지 그림자 3줄 crop → 32×12 **top 앵커**. 현행판 고유색 38.
★★ **폭 40 초과 금지.** 좌대 간격이 40px이고 8좌 오른쪽 끝이 방(x8..19) 우측 벽과 52px밖에 안
   떨어져 있다 — 넘기면 옆 좌대와 겹치고 벽을 뚫는다.
★★ **위로 자라지 마라(top 앵커·높이 12).** 좌대 윗면(`bp.y`)이 꽂힌 책등(8×14)이 **서는 바닥**
   이다. 아트가 그 선 위로 올라오면 책등을 가려 "전시됨"이 안 읽힌다.
★  **꽂힌 책을 굽지 마라.** 책등 8좌는 기증 원장(Museum.is_donated)이 칸마다 그린다 — 좌대에
   책을 구우면 기증 전에도 차 있는 것으로 보인다(§22.1 깃발과 같은 규율).
★  붉은 칠 목재로 나오면 muted를 더 눌러 방의 어두운 갈색에 합류시킬 것(계수 §22.0).
```

### 22.4 ★편지지 대화창 `ui/letter_window.png` (1400×405) — 편지·책 전용 두 번째 종이

```
배선: main.DLG_LETTER_TEX + `_set_dialogue_skin("letter")`(편지 열람·책 즉독·책장 재읽기 3곳에서
  start 직전 호출) + `_on_dialogue_finished`에서 자동 복귀. 스킨 파일이 없으면 무동작이다.
정체성: **같은 창의 다른 종이**다. S9-T3이 "읽기 UI = 대화창 재사용"으로 못박았으므로 새 UI를
  세우면 그 결정이 무효가 된다 — 위젯·조작·내부 칸을 전부 그대로 두고 종이만 바꾼다:
  그을린 한지(사람이 말할 때) → 갓 접힌 편지지(글이 말할 때) + 3등분 접은 자국 두 줄.
★ **생성물이 아니다.** `tools/make_s9_t9_art.py`가 `assets/ui/dialog_window.png`에서 파생한다
  (muted 0.74/1.06 = 덜 붉고 한 단 밝게 · 접힌 골 0.86 / 능선 1.07). owner가 새로 그리려면
  **dialog_window.png와 같은 원본 프레임에서** 출발해야 한다.
★★ **1400×405를 절대 바꾸지 마라.** main의 DLG_F_TEXT / DLG_F_PORT / DLG_F_NAME은 창 크기 대비
   **비율 상수** 한 벌이고 두 스킨이 그 한 벌을 공유한다 — 크기가 갈리는 순간 편지지 쪽에서
   초상화 칸·이름판이 프레임 밖으로 샌다.
★  **프레임 장식(그을린 테두리·먹 나비·모서리 못)은 그대로 둔다.** 창이 바뀐 게 아니라 종이가
   바뀐 것으로 읽혀야 한다 — 프레임까지 갈면 플레이어가 "다른 UI"로 오독하고, T3의 "새 조작을
   배울 것이 없다"는 이점이 사라진다.
```

### 22.5 집 책장 `props/house_bookshelf.png` (64×64) — 이 패스가 **안 만든** 것

```
★ 생성 0. 이미 아트가 있다(4단 선반에 책이 꽂힌 64×64 벽 가구 · HOME 실내 x15..16 · SOLID).
  S9-T7이 신규 기물을 안 세우고 이 프롭에 [F](책 재읽기)만 얹었으므로, T9가 할 아트 작업이
  구조적으로 없다 — 그래서 **교체 후보로만** 적어 둔다.
교체 시: 같은 파일명·**같은 64×64**로 덮어쓰면 코드 0줄. 크기가 바뀌면 발치·WALL_PROP_LIFT(-18)·
  Y-split·충돌 칸 수(`_rebuild_prop_collision`이 size/TILE로 센다)가 한꺼번에 어긋난다.
★ **미결(owner 큐):** "되찾은 책이 꽂혀 간다"는 시각 피드백이 없다(수집 진행은 알림 문구로만
  읽힌다). 우편함 깃발과 같은 절차 오버레이로 얹을 수 있지만, 현행 아트가 이미 책으로 가득 찬
  4단 선반이라 그 위에 표식을 덧그리면 그림이 지저분해진다 — **빈 선반 판본으로 다시 그리고
  칸이 채워지는 연출**을 함께 가는 편이 낫다는 판단이라 아트 결정과 묶어 미룬다.
```

---

## 23. ★[S9b-T9] 조연 코러스 9인 + 척추 아트 패스 — 워크 시트 9·도트 초상 5·부적 아이콘 1 스펙카드 (owner Gemini 무수정 교체 대기)

> **상태:** PixelLab 생성 + 후처리로 **인게임 배선 완료**(2026-08-14). §10~§22와 같은 [ADR-0048]
> 교체 큐다 — owner가 같은 파일명·크기로 다시 뽑아 `*_raw/` · `*_raw.png`만 덮어쓰고
> `cd game && python3 tools/make_s9b_t9_art.py`를 한 번 돌리면 **코드 0줄 수정**으로 반영된다.
> (PNG를 갈아 끼운 뒤에는 `cd game && godot --headless --import` 1회 — 임포트 캐시가 소스가
> 아니라 `.godot/imported/*.ctex`를 읽는다.)
>
> **후처리 글루:** [`game/tools/make_s9b_t9_art.py`](../../game/tools/make_s9b_t9_art.py) — 규칙·계수는
> `make_s6_art.py`(주방요괴 시트)와 **같은 값**이다(새 규칙 0 · 하드 알파 → muted → 80² 발치정렬).
> 새로 는 것은 둘: `erase_north_face`(뒷모습 얼굴 지우기 — 아래 ★★) · `recolor_skin`(§11.4 네오의
> 살빛 치환을 세레나에 재사용).
>
> **육안 하네스:** `godot --headless --path game -s res://tools/s9b_chorus_dump.gd`
> → `game/tools/s9b_chorus_dump.png`(위 = 마을 광장에 선 8인 · 아래 = 9인 × 4방향 격자).
> 이 하네스는 배선을 **기계로도** 잰다 — 각 노드의 `_sprite`가 null이면 그레이박스 색박스가
> 그려지는 중이라는 뜻이라, 콘솔에 `색박스 잔존: 0 / 9`가 찍히는 것이 이 패스의 합격선이다.
>
> **raw 보관:** `game/assets/characters/{kkaebi,ken,seolhwa,scarlet,mir,luca,frosty,gangrim,serena}_raw/`
> (각 `{south,north,east,west}.png`) · `game/assets/portraits/{kkaebi,seolhwa,scarlet,gangrim,serena}_raw.png`
> (각 128²) · `game/assets/materials/raw/myeongbu_charm_raw.png`
>
> **PixelLab 사용량 136 gen**(상한 300 — create_character standard 8 · create_map_object 1 ·
> create_character v3 회전 1 · create_image_pixen 1 · create_portrait_character 5×25=125).
> ⚠ 이 세션에 `Generation failed due to heavy load` 7건이 났고(스칼렛·미르·루카·프로스티×2·강림×2)
> **실패는 과금되지 않았다**(실측 — 잔량 차분이 성공분과 정확히 일치). 병렬 8발은 부하를 타므로
> **2~3발씩 끊어 쏘는 편이 빠르다**.
>
> **이 패스가 지운 그레이박스:** 조연 9인 전원의 색박스 실루엣(`<id>.gd _draw()`) + 명부 혼례
> 부적 인벤/핫바 색박스 1종. **이 패스가 안 만든 것:** 비인간 4인(켄·미르·루카·프로스티) 초상 —
> 미이행이 아니라 **결정**이다(§23.3 ①).

### 23.0 공통 규약

```
전부 [ADR-0050] 32-native · [§1.1] NW 광원 · [§8.1] 하드 알파 · [§9] 저승 muted · [§3] 발치 앵커.
시트 규격: 80×320 = 프레임 80×80 · **1열**(정지 rotation) × 4행(down/up/right/left)
  — §11.4 네오 · §15.6 옹이 · §17.4 점주 2인 · §19.1 주방요괴와 **동형**.
  ★1열인 이유는 "안 걸어서"가 아니다(조연 9인은 셋 다 자리를 옮기는 스케줄이다). **워크 4프레임이
    이 패스 밖**이기 때문이고, char_sprite가 열 수를 파일에서 읽으므로 나중에 워크 시트가 오면
    **코드 무수정**으로 열이 는다(모찌가 서 있는 그 자리).
생성(휴머노이드 8인): create_character(mode=standard / n_directions=4 / low top-down /
  selective outline / basic shading / high detail / tgs=11 / §11.4 공통 proportions
  {"type":"custom","head_size":1.5,"arms_length":0.75,"legs_length":0.9,
   "shoulder_width":0.72,"hip_width":0.75})
  — §17.4·§19.1과 **한 글자도 다르지 않은 호출**이다. 마을 광장에서 출하 캐스트와 어깨를
    나란히 하므로, 다른 값을 쓰면 이 아홉만 덩치·선이 튄다.
★ **size는 두 값뿐이다** — 사람 규격 7인 = **44**(§11.4가 실측으로 세운 정합값. 콘텐츠 45~51px로
  출하 캐스트 41~46과 같은 체급) / **거인 2인(켄·프로스티) = 56**(콘텐츠 61~65px).
  56을 고른 근거는 그레이박스가 이미 그렇게 말하고 있어서다: `ken.gd`·`frosty.gd`의
  BODY_SIZE는 22×46·22×44로 사람형 16×32보다 한 뼘 크다. 그 비(46/32≈1.44)를 그대로 쓰면
  size 63이라 캔버스(≈size×1.4)가 프레임 80을 넘는다 → **56이 프레임에 들어가는 최댓값**이다.
muted 계수: 전원 0.94/0.98 (= §17.0 점주·§19.0 주방요괴와 **같은 값** — 출하 캐스트와 나란히
  서는 층이라 아주 얕게. 다른 값을 쓰면 새로 온 아홉만 색이 죽는다)
후처리: 하드 알파 → muted → (세레나만 살빛 치환) → (프로스티 north만 얼굴 지움) →
  80² 프레임 발치정렬(FOOT_Y=74)
★ **정체성의 단일 출처는 각 `<id>.gd`의 그레이박스 `_draw()`다**(+ [narrative-bible §5]).
  아래 PROMPT는 전부 그 실루엣 설계(㉠~㉤ 범례)를 영어로 옮긴 것이고, 리젝 판정도 거기서 나온다 —
  그레이박스가 아트의 스펙 카드라는 §19.1의 결이 아홉 번 반복됐다.
★리젝 기준(§17.4·§19.0에서 이어받은 것 + 이 패스가 실증한 것):
  ① **재질을 몸 전체에 못 박는다** — 비인간은 "no human skin anywhere"가 핵심 어구고 tgs=11이다
     (옹이가 "bark skin"을 부드럽게 적어 초록 머리 노인으로 나온 그 실패의 예방). 이 패스는
     루카·미르·프로스티·깨비에 그대로 걸어 **재질 리젝 0**이었다.
  ② **금지 도상을 이름으로 적는다** — residents.md의 분리 가드레일은 프롬프트에 부정형으로
     박아야 지켜진다: 켄 `NOT green, no neck bolts and no flat square head`(프랑켄슈타인 금지) ·
     프로스티 `NOT a snowman`(눈사람 연상 금지) · 깨비 `no fire and no flames anywhere`
     (불 = 백스토리 한정 · 미호 여우불과 중복 금지). 셋 다 1차에서 지켜졌다.
  ③ **north(뒷모습)를 반드시 눈으로 확인한다** — 아래 ★★.
★★ **north 결함이 이 패스에서 처음으로 "고쳐야 하는 것"이 됐다.** §15.6이 옹이에서 박제한
   "north 프레임에 얼굴이 그려진다"는 결함을 그때는 **정지 NPC라 walk_down 행만 뜬다**는 이유로
   넘겼다. 조연 9인은 아침(집 앞)→낮(광장)→저녁(카페)으로 **실제로 이동**해서 뒷모습이 화면에
   든다. 9종을 전수 육안 검수한 결과:
   · **8인은 정상** — 뒤통수가 머리카락(깨비·켄·설화·스칼렛·미르·세레나)·귀 달린 뒤통수(루카)·
     갓 챙(강림)으로 갈려서, 모델이 얼굴을 그릴 자리가 없었다.
   · **프로스티만 결함** — 앞뒤가 같은 흰 털이라 뒷면에도 눈·눈썹·주둥이가 그려졌다.
     → `make_s9b_t9_art.erase_north_face(0.34, 200)`로 지운다: 머리 띠(콘텐츠 높이의 위 34%) 안의
     **내부 픽셀**(외곽선 제외) 중 몸보다 어두운 것을 이웃 털색으로 반복 충전한다. 모찌 글루
     (`make_naru_art2._move_face(hide=True)`)와 **같은 연산**이고, 털이 앞뒤 한 색인 인물에서만
     성립하는 처방이라 나머지 8인에겐 안 건다.
   ⚠ 교체판도 **north를 반드시 눈으로 확인할 것**. 위 하네스의 아래쪽 격자 2행이 그 판정면이다.
```

### 23.1 ★조연 9인 워크 시트 `characters/<id>.png` (각 80×320)

```
배선: **전원 코드 0줄.** 각 `<id>.gd`의 `CharSprite.make("res://assets/characters/<id>.png")`가
  S9b-T1~T6이 깔아 둔 훅이라, 파일을 놓는 것이 배선의 전부다(없으면 그레이박스 `_draw()`로
  자동 폴백 — 네오·풀무·무골·주방요괴와 같은 결).

── ① 깨비 `kkaebi` (size 44 · 콘텐츠 49px) — 도깨비 ─────────────────────────────
  실루엣 출처: kkaebi.gd ㉠ 넓은 어깨 / ㉡ 외뿔 하나 / ㉢ 어깨에 걸친 방망이 / ㉣ 불 색 금지
  PROMPT: chibi Korean dokkaebi goblin trickster standing straight, his whole face and body are
    warm earthen clay brown ogre hide, no human skin anywhere, ONE single short horn growing up
    and tilted from the left side of his forehead, broad grinning face with narrow mischievous
    slit eyes and a wide sly smile, wild dark hair, very broad shoulders much wider than his hips,
    a thick knobbly wooden club resting on his right shoulder, wearing a dark teal green korean
    hanbok jeogori jacket with an earth brown sash belt, sturdy and playful, no fire and no flames
    anywhere, muted underworld palette
★알려진 결함(교체 시 고칠 것): **이마 외뿔이 안 나왔다** — 뾰족귀 + 헝클어진 머리가 그 자리를
  대신 팔고 있다. §17.4 풀무가 겪은 것과 **똑같은 실패**(44px 스케일에 뿔이 안 박힌다)라,
  이제 "standard·size 44에서 작은 뿔은 안 나온다"를 규칙으로 봐야 한다. 지금은 흙빛 살갗 +
  뾰족귀 + 방망이 + 능글 미소가 도깨비를 판다. ㉣(불 색 0)은 지켜졌다 — 몸은 청록이다.

── ② 켄 `ken` (size 56 · 콘텐츠 62~64px) — 언데드 거인 ──────────────────────────
  실루엣 출처: ken.gd _SKIN 창백한 회청 / 넓은 어깨 / 긴 팔 / 처진 눈매 / 왼 이마 흉터
  PROMPT: chibi undead giant standing straight, a towering broad shouldered figure, his whole face
    and body are pale cold grey blue undead skin, no human skin anywhere, NOT green, no neck bolts
    and no flat square head, a gentle rounded head with sad drooping downturned eyes and a small
    closed mouth, a thin faint scar running down the left side of his forehead and cheek, short
    dark hair, extremely broad shoulders and very long heavy arms hanging down past his knees,
    wearing a simple worn dark brown labourer tunic and rough trousers, huge and calm and gentle,
    muted underworld palette
★[residents.md §남요괴 2] "유니버설 프랑켄슈타인(녹색·볼트·납작머리) ✕"가 프롬프트의 부정형
  셋으로 이행됐고 1차에서 지켜졌다. **거인은 키로 팔린다** — 광장에 서면 사람 규격 7인보다
  머리 하나가 크다(하네스 위쪽 장면의 판정면).
★알려진 결함: 어깨 폭이 그레이박스 ㉠("키보다 어깨 폭이 먼저 읽힌다")만큼 극단적이지 않다.
  교체판은 어깨를 더 벌릴 것.

── ③ 설화 `seolhwa` (size 44 · 콘텐츠 49~50px) — 설녀 ───────────────────────────
  실루엣 출처: seolhwa.gd ㉠ 가장 세로로 긴 실루엣 / ㉡ 긴 백발 두 갈래 / ㉢ 정수리 서리 결정 /
    ㉣ 따뜻한 색 한 점도 금지
  PROMPT: chibi Korean snow woman yokai standing straight, a tall slender vertical silhouette,
    pale blue white icy skin, no warm colours anywhere, long straight snow white hair falling in
    two strands past her waist, a small pale ice crystal star resting on the very top of her head,
    downcast narrow serene eyes and a small closed mouth, wearing a long pale indigo blue korean
    jangot robe falling straight to her feet with a silver white sash, cold and aloof and elegant,
    frost, muted underworld palette
★[residents.md] "디자인 지브리 베끼기 ✕" — 프롬프트에 특정 작품을 안 적는 것으로 지킨다.
★알려진 결함: 서리 결정이 **정수리가 아니라 이마 머리띠 위치**에 붙었다(㉢의 "도깨비 뿔 자리에
  대응하는 종족 표식"이라는 의도가 절반만 이행). 장옷은 남빛보다 보랏빛으로 나왔지만 muted가
  눌러 로스터 안에서는 합류한다. ㉣(난색 0)은 지켜졌다.

── ④ 스칼렛 `scarlet` (size 44 · 콘텐츠 45~49px) — 메두사 ───────────────────────
  실루엣 출처: scarlet.gd ㉠ 머리 위 뱀 세 가닥 / ㉡ 긴 소매로 덮인 손 / ㉢ 주홍 *비단*(불 아님) /
    ㉣ 가늘고 붉은 눈 · 입 안 그림
  PROMPT: chibi medusa gorgon woman standing straight, pale cool skin, THREE dark green snakes
    rising from the top of her head instead of hair and splitting left centre and right, each snake
    with a tiny head, narrow sharp crimson red eyes and a flat unsmiling mouth, wearing a deep
    crimson scarlet silk korean robe with very long wide draping sleeves that completely hide both
    hands, a black silk sash at the waist, poised and cold and glamorous, muted underworld palette
★뱀은 **세 가닥이 아니라 두 가닥**이 머리를 감싸며 내려오는 형태로 나왔다. 다만 실루엣 상단이
  다른 주민(둥근 머리)과 확실히 갈리므로 ㉠의 목적은 성립한다 — 교체판에서 셋으로.
★㉢이 지켜졌다: 붉음이 **옷감**이지 빛이 아니라, 미호의 여우불·깨비 백스토리의 불과 안 겹친다.

── ⑤ 미르 `mir` (size 44 · 콘텐츠 50~51px) — 이무기 ─────────────────────────────
  실루엣 출처: mir.gd ㉠ 뒤로 누운 뿔 둘 / ㉡ 목까지 여민 옷깃 / ㉢ 짙은 남청(깨비 청록보다
    어둡게) / ㉣ 옷자락 아래 비늘 꼬리 한 자락
  PROMPT: chibi imugi serpent lord standing straight, his face and hands are pale cold grey blue
    reptile skin with fine scales, no human skin anywhere, TWO dark horns sweeping backwards flat
    against the back of his head and not upward, narrow golden serpent eyes with vertical slit
    pupils and a flat unsmiling mouth, long dark hair, wearing a dark navy teal scaled robe with a
    high stiff collar closed all the way up to the chin hiding his neck, a gold band at the waist,
    one short blue green scaled serpent tail tip peeking out from under the hem near his feet,
    proud and still, muted underworld palette
★**꼬리(㉣)가 이 시트의 성공작이다** — 청록 비늘 꼬리가 옷자락 밖으로 크게 휘어 나와, 사람
  형상인데 사람이 아님이 실루엣 하나로 읽힌다. ㉡ 높은 옷깃·금띠도 나왔다.
★알려진 결함: ㉠ 뿔이 "뒤로 눕지" 않고 짧은 돌기로 섰다(깨비 외뿔과의 방향 대비가 약해졌다) ·
  눈이 금빛 세로 동공이 아니라 옅은 청색이다. 둘 다 교체판 1순위 교정점.

── ⑥ 루카 `luca` (size 44 · 콘텐츠 49~52px) — 늑대인간 ──────────────────────────
  실루엣 출처: luca.gd ㉠ 뾰족 귀 둘 / ㉡ **낮게** 늘어진 꼬리 / ㉢ 잿빛 갈색(무채색에 가깝게) /
    ㉣ 노란 눈 한 쌍 / ㉤ 손목의 밧줄 자국 두 줄
  PROMPT: chibi werewolf man standing straight, his whole face and body are covered in ash grey
    brown wolf fur, no human skin anywhere, a wolf muzzle and TWO tall pointed wolf ears standing
    up on his head, sharp bright yellow eyes and a firmly closed mouth, a bushy tail hanging LOW
    and down behind his right leg and not raised, wearing a plain dark grey worn shirt with rolled
    up sleeves and dark trousers, two pale rope burn scar bands around each wrist, lean and quiet
    and watchful, muted underworld palette
★㉠~㉤이 **전부** 나온 유일한 시트다(늑대 주둥이 + 선 귀 + 내린 꼬리 + 노란 눈 + 손목 띠).
  "LOW and down ... not raised"처럼 **방향을 대문자와 부정형으로 함께** 적은 것이 주효했다 —
  쳐든 꼬리는 활기찬 개가 되고, 내린 꼬리라야 ㉡의 "억누르는 인물"이 된다.
★사소한 결함: 손목 띠가 창백한 밧줄색이 아니라 푸른빛으로 나왔다(㉤의 '자국'보다 '팔찌'로 읽힐
  여지). 교체판은 살빛에 가까운 흉터색으로.

── ⑦ 프로스티 `frosty` (size 56 · 콘텐츠 61~65px) — 예티 ────────────────────────
  실루엣 출처: frosty.gd ㉠ 로스터 최대 덩치 / ㉡ 둥근 어깨·**없는 목** / ㉢ 거의 흰 눈빛 털
    (무채색 최상단 = 강림의 정확한 반대편) / ㉣ 큰 눈망울 + 처진 눈썹 · **입 없음** /
    ㉤ 가슴 한가운데의 빈 자국
  PROMPT: chibi giant yeti snow beast standing straight, an enormous rounded mass of soft snow
    white shaggy fur covering the entire body, no human skin anywhere, NOT a snowman, the head sunk
    directly into the round shoulders with no neck at all, two very large dark round eyes and two
    short drooping sad eyebrows, NO mouth at all, short thick fur arms hanging at the sides and
    wide flat feet, a small dark hollow dent in the very centre of its chest, huge and soft and
    gentle, muted underworld palette
★㉠~㉤ **전부 이행**. 특히 ㉣의 "입은 그리지 않는다"(말 못 하는 인물이라 그릴 이유가 없다)와
  ㉤의 가슴 홈이 도트에서도 살아 있다 — ♡3 관문이 그 자리를 가리키므로 아트가 대사를 받친다.
★★ **north 얼굴 결함 1건 = 후처리로 해소**(위 §23.0 ★★). raw에는 뒷면에도 얼굴이 있으니
   `*_raw/north.png`를 그대로 다른 용도에 쓰지 말 것.

── ⑧ 강림 `gangrim` (size 44 · 콘텐츠 48px) — 폐직 차사 ─────────────────────────
  실루엣 출처: gangrim.gd ㉠ 넓은 갓 챙(실루엣 상단이 로스터에서 유일하게 가로로 넓다) /
    ㉡ 검은 도포(무채색 최하단) / ㉢ 가슴께 흰 띠 / ㉣ 갓 그늘 아래 무채색 눈 / ㉤ 품에 낀 빈 명부
  PROMPT: chibi Korean grim reaper jeoseung saja standing straight, wearing a wide brimmed black
    korean gat hat with a low crown, the brim wider than his shoulders casting deep shadow over the
    upper face, a narrow pale face beneath with faint colourless grey white eyes and a flat closed
    mouth, wearing a long black korean dopo robe with a single white sash band across the chest, a
    black worn ledger book tucked under his left arm, severe and still and colourless, muted
    underworld palette
★**갓 챙이 어깨보다 넓게** 나와 ㉠이 성립했다 — 광장에서 실루엣만으로 그를 찾을 수 있다.
  ㉤ 명부도 팔 밑에 있다. 뒷모습이 갓으로 완전히 갈려 north 결함이 구조적으로 안 난다.
★알려진 결함: 명부가 검정이 아니라 갈색 표지로 나왔다 · ㉢ 가슴 흰 띠가 남향에서 약하다
  (북향에선 허리 띠로 보인다). 둘 다 교체판 교정점.

── ⑨ 세레나 `serena` (v3 회전 · 콘텐츠 34~36px) — 인어 ──────────────────────────
  실루엣 출처: serena.gd ㉠ **발이 없다**(로스터에서 유일) / ㉡ 앉은 자세라 키가 낮다 /
    ㉢ 긴 머리 한 덩이 / ㉣ **두 색**(하반신 짙은 청록 / 상반신 창백한 물빛) / ㉤ 입을 그린다
  ★★ **create_character(휴머노이드 골격)를 못 쓴다** — 다리가 없기 때문이다(§11.5 모찌가 세운
     그 갈림길). 그런데 모찌 경로(단일 뷰 + 얼굴 이동)도 안 맞는다: 모찌는 방향에 무관한 덩이라
     얼굴만 옮기면 됐지만, 인어는 꼬리 방향이 돌아야 한다. 그래서 **2단 생성**을 썼다.
     ㉠ create_map_object(48×48 / low top-down / selective outline / basic shading / high detail)로
       남향 한 장을 뽑고 → ㉡ 그 결과를 create_character(mode=v3 / reference_image_url=그 오브젝트의
       다운로드 URL / size=48 / low top-down)로 **8방향 회전**시켜 south·north·east·west만 쓴다.
     ⚠ v3 참조 입력은 **base64보다 URL이 안전하다**(MCP가 긴 base64를 무음 절단한다 — §17.4 교훈의
       회전판). map_object 다운로드 URL이 무인증이라 그대로 넣으면 된다(8시간 내 사용).
     ★결과가 좋다: 앉은 인어가 **네 방향 모두 꼬리·머리 덩이가 제대로 돌았고**, north는 머리
       한 덩이만 보여 얼굴이 없다. 콘텐츠 34~36px = 사람 규격 49px의 0.70으로, 그레이박스
       ㉡(_SIT_H 21 / BODY_SIZE.y 32 = 0.66)과 거의 같은 비다 — **앉은 키가 우연이 아니라 규격이다**.
  PROMPT(㉠ map_object): a small mermaid sitting on the ground seen from a low three quarter view,
    her lower body is a wide deep teal fish tail curled to the side with a broad fanned tail fin
    resting flat on the ground, NO legs at all, pale watery blue white skin on her slender upper
    body, very long flowing teal green hair falling in one single mass past her shoulders, a small
    delicate face with dark teal eyes and a small open singing mouth, a simple pale shell top,
    calm and languid, muted underworld palette
  PROMPT(㉡ v3 회전 — 회전 안내용이라 짧게): a small mermaid sitting on the ground, her lower body
    is a wide deep teal fish tail with a broad fanned tail fin resting flat on the ground, no legs
    at all, pale watery blue white skin, very long flowing teal green hair, calm and languid
후처리 추가 1건 — **살빛 치환**(`recolor_skin`, §11.4 네오의 그 연산):
  v3 회전본이 상반신을 **따뜻한 갈색 살빛**으로 구워 왔다. 그레이박스 ㉣이 "두 색"을 정체성으로
  못 박았고(강림의 무채색 최하단과 반대편에 서는 근거) 난색이 들어오면 로스터에서 세레나만
  따뜻해진다 → 난색 창(h 5~40° · s>0.12)만 잡아 h=188°(그레이박스 상반신 Color(0.76,0.84,0.86)의
  색상) · s×0.40 · v×1.06으로 옮긴다. **명도 계조는 보존**하므로 계단식 음영이 살아 있다.
  ★청록 머리·꼬리(h≈160~180°)는 창 밖이라 안 건드린다 — 이 분리가 성립하는 것이 처방의 전제다.
★교체 시: 위 2단 생성을 안 쓰고 owner가 4방향을 직접 그려 `serena_raw/`에 넣어도 된다.
  글루는 폴더만 읽으므로 **출처를 안 가린다**.
```

### 23.2 ★도트 대화 초상화 5인 `portraits/{kkaebi,seolhwa,scarlet,gangrim,serena}.png` (각 256×256)

```
배선: main `r_<id>.portrait_stem` "" → "<id>" — 주민 레코드 **한 줄씩 5줄**이 전부다.
생성: create_portrait_character(direction=character_to_portrait / low top-down / result_size=128) —
  입력 = 위 §23.1 시트의 **south 프레임을 16색 P모드 PNG로 양자화**한 것(§17.4 풀무 경로 그대로).
  ★★ [§17.4 교훈 재확인] 입력 거부를 피하는 확실한 길은 길이가 아니라 **포맷**이다 — 16색
     팔레트(P) 모드 PNG는 b64 724~932자로 5장 전부 **한 번에 통과**했다(RGBA 양자화본은 전량
     도착해도 서버 PIL이 "broken data stream"으로 거부한다).
후처리: 하드 알파 → ×2 nearest(128→256). §15.6 옹이·§17.4 풀무와 같은 규격이다.
★ **표정 파일은 만들지 않는다**(`<id>_talk/_smile/_shy/_sad/_surprised` 0장) — `_set_portrait`가
  없는 파일을 만나면 idle로 떨어지므로 **idle 한 장이 대사 전량을 덮는다**. 조연 대사의
  [smile]/[shy] 태그는 지금도 그 폴백을 타고 있고, 나중에 표정이 오면 **대사·코드 무개정**으로
  붙는다(네오·뱃사공·옹이·풀무와 같은 규약).
★ **다섯 다 정체성이 살아남았다**(§15.6 옹이가 겪은 "비인간 재질 → 사람 피부 되돌림"이 안 났다).
  깨비=뾰족귀·흙빛 살갗·방망이·능글 미소 / 설화=백발·창백한 냉기·서리 머리띠 / 스칼렛=주홍 비단·
  붉은 눈·머리를 감는 어두운 코일 / 강림=갓·백면·무채색(이 패스 최고 산출물 — 갓 챙과 흰 얼굴의
  대비가 도트 버스트에서 오히려 강해졌다) / 세레나=청록 머리·물빛 살갗·주근깨.
  ★공통 원인 분석: 이 다섯은 **사람 형상 + 비인간 *표식*** 조합이라(뿔·백발·뱀·갓·인어) 변환이
  지울 것이 표식뿐이고 얼굴 자체는 사람이다. 옹이·무골처럼 **얼굴 재질 자체가 비인간**인 쪽이
  실패한다 — 이것이 §23.3 ①의 판단 근거다.
★★ **화풍 불일치 — 교체 대기:** 메인 4인(미호·멜·바나·옥자)은 owner-Gemini **소프트 일러스트**
   버스트인데 이 다섯은 **도트 버스트**다. "얼굴 없음"을 메우는 스톱갭이라는 지위는 네오·뱃사공·
   옹이·풀무와 같다 — owner가 [portrait-spec-card.md] §1 규격으로 다시 뽑아 덮으면 된다.
```

### 23.3 ★owner-Gemini 전용 큐 (PixelLab로 만들지 않는 것)

```
── ① 비인간 4인 초상 — **미생성이 결정이다**(2×3 표정 그리드로 요구) ─────────────
대상: 켄 · 미르 · 루카 · 프로스티 (`portrait_stem = ""` 유지 · 대화창에 초상 칸이 안 뜬다).
안 만든 근거 둘(§17.4 무골 초상을 안 만든 그 판단의 4인판):
  ㉠ §15.6이 `character_to_portrait`의 **비인간 재질 → 사람 피부 되돌림**을 모델 한계로 박제했고
     (옹이 2판 동일 실패), 이 넷은 그 실패에 가장 불리한 입력이다 — 얼굴 재질 자체가 비인간이다
     (언데드 살갗 / 비늘 / 늑대 주둥이 / 털뭉치). §23.2가 성공한 다섯은 반대로 얼굴이 사람이었다.
  ㉡ 한 장이 25 gen이라, 실패 가능성이 큰 100 gen을 더 태우면 이 패스가 236 → 상한을 위협한다.
  ⚠ **미이행이 아니라 결정이다** — 각 `*_arc_test.gd` ①d가 그 결정을 단언으로 들고 있다.
2×3 표정 그리드(정본: idle / talk / smile / shy / sad / surprised)로 요구할 것.
**정체성 불가침 요소**(각 인물 파일·바이블이 정한 것 — 이걸 잃으면 다시 뽑아야 한다):
  · **켄** = 창백한 회청 살갗(사람 살빛 0) · **처진 눈매**(순한 인상이 얼굴의 전부) · 왼 이마에서
    볼로 내려오는 **옅은 흉터** · 큰 머리인데 **각지게**(프로스티의 둥근 덩이와 반대편) ·
    ⚠ 녹색·목 볼트·납작머리 **금지**(프랑켄슈타인 회피 — residents.md 명시).
  · **미르** = 청회색 **비늘 살갗** · **세로 동공의 금빛 눈** · **목까지 여민 높은 옷깃**(가리는
    인물의 얼굴 — ♡2·♡3·spouse가 전부 이 옷깃을 쓴다) · **뒤로 누운 뿔 둘**(위로 뻗지 않는다 =
    "아직 용이 아님") · 안 웃는 입.
  · **루카** = **늑대 주둥이가 있는 얼굴**(사람 얼굴에 귀만 붙이지 말 것) · 잿빛 갈색 털 ·
    **노란 눈 한 쌍**(얼굴에서 유일하게 채도가 높다) · 다문 입 · 사람 피부색 0.
  · **프로스티** = 얼굴 전체가 **눈빛 흰 털** · **목이 없다**(머리가 어깨에 잠긴 한 덩이) ·
    **아주 큰 눈망울 + 처진 눈썹**(이 둘이 표정 전부다) · **입을 그리지 않는다**(말 못 하는
    인물이라 그릴 이유가 없다 — 표정 6칸을 **눈과 눈썹만으로** 갈라야 한다) ·
    ⚠ 눈사람 연상 **금지**.

── ② 인간형 초상 5인 교체본 ────────────────────────────────────────────────────
§23.2의 도트 버스트를 [portrait-spec-card.md] §1 헤드&체스트 버스트(소프트 일러스트)로 교체.
같은 파일명(`portraits/<id>.png` 256²)이면 **코드 0줄**. 우선순위는 대사량 순: 강림 > 스칼렛 >
설화 > 깨비 > 세레나. 각 인물의 불가침 요소는 §23.1 실루엣 출처 줄이 단일 출처다.
표정 6칸을 함께 그리면 `<id>_talk` 등 파일명만 맞춰 놓으면 되고 역시 코드 0줄이다.

── ③ ★★S등급 원화 2장 `assets/cutscene/{b6_return,b7_release}.png` ─────────────
⚠ **PixelLab로 생성하지 않는다**([ADR-0068] 결정 9 — 인스타툰체 풀스크린 원화는 owner-Gemini
  전용이다. 도트로 구우면 이 게임에서 딱 두 번 뜨는 화면이 나머지 화면과 같은 급이 된다).
배선: **코드 0줄 드롭인.** `cutscene.gd`의 다섯째 동사 `illust`가 이미 `assets/cutscene/<id>.png`를
  찾고, 없으면 main이 placeholder(먹 암전 + 세로 대형 붓글씨 제목 + 가로 부제)를 세운다.
  파일을 놓는 순간 placeholder가 원화로 바뀐다.
규격: 내부해상도 640×360(ADR-0012)의 **풀스크린**이라 그 비(16:9)를 지킬 것. 불투명도만 보간되므로
  (러너가 id와 알파만 안다) **가장자리까지 그려 채울 것** — 투명 여백을 남기면 암전이 비친다.
장면 요구(본문에서 도출 — `spine.gd` B6_RETURN_LINES · B7_OFFICIANT_LINES · B7_RELEASE_LINES):

 ㉠ `b6_return` — 제목 「귀환」 / 부제 「봉인이 풀리다」
   그려야 하는 것: **불이 번지던 밤, 플레이어를 끌어안고 밖으로 나온 팔이 다시 안으로 들어가는
   그 등**. 본문의 핵("나를 끌어안고 나온 팔이 있었다. 그 팔은 다시 안으로 들어갔다")이 이 한 컷이다.
   ⚠ **얼굴을 보여 주지 않는다** — 본문이 끝까지 「옥자」를 0회로 두고 "당신"이라고만 부른다.
     뒷모습·역광의 실루엣까지다. 얼굴을 그리면 본문이 참은 것을 그림이 말해 버린다.
   결: 약방 뒷마당의 마른 약초 · 번지는 불빛 · 문지방을 넘어 *안으로* 향하는 발.
   ★두 번째 층(선택): 명부의 한 줄에 그어진 붉은 선 위로 겹쳐 적힌 두 이름 — 본문 6번째 줄이
     그것이라, 화면 어딘가에 종이 한 장으로 겹쳐 두면 두 문장이 한 그림에 든다.

 ㉡ `b7_release` — 제목 「해방」 / 부제 「머무름은 선택이 되다」
   그려야 하는 것: **명부의 「종신(終身)」 줄 위에 붉은 선이 그어지는 순간**, 그리고 그 옆에
   **두 이름이 나란히 적히는 붓끝**. 계약으로 묶던 손이 사랑으로 묶는 거울이 이 장면의 전부다.
   ⚠ **주례(갓 쓴 이)의 얼굴도 보여 주지 않는다** — 본문이 그를 전부 지문으로만 쓴다
     ("갓 아래 그림자가 붓을 든다" · "말할 수 없는 사람이다"). 갓 챙과 붓을 든 손까지다.
   결: 소리 없는 잔치 — 밖에서 폭죽 대신 **여우불**이 터진다(본문 6번째 줄). 죽은 자들의 혼례라
     환호가 없다. 붉은 선 · 먹 · 여우불의 푸른빛, 세 색이면 충분하다.
   ★이 그림은 **엔딩의 마지막 얼굴**이다(이어서 에필로그로 넘어간다) — 밝게 끝낼 것.
```

### 23.4 ★명부 혼례 부적 `materials/myeongbu_charm.png` (32×32 아이콘) — 앵커 청혼의 정표

```
배선: main.MINE_ICONS에 한 줄(`ItemCatalog.MYEONGBU_CHARM: preload(...)`) — [S8-T9] 혼례 부적
  (`wedding_charm`) **바로 옆**이다. 부적은 CAT_MATERIAL이라 인벤 슬롯·핫바·토스트가 이미
  "텍스처 있으면 쓰고 없으면 색박스" 분기를 타고 있었다 → dict 한 줄로 세 자리가 동시에 낫는다.
정체성: **접는 손이 다르다.** 일반 혼례 부적은 앵커(무녀)가 5,000냥에 접어 주는 크림빛 한지지만,
  자기 혼례 부적을 자기가 접을 수는 없다 — [narrative-bible §6.3]이 "앵커 본인의 혼례는 차사가
  맺어 준다"고 못 박아, 이건 **명부의 주인이 명부장을 찢어 접는 것**이다(창구 = 강림 [F] ·
  값은 냥이 아니다 — 명부에 이름을 올리는 일은 사고팔 수 없다).
  그래서 종이가 **먹빛**이고, 그 위에 **두 이름이 흰 붓글씨로 나란히** 적히고, 그 두 줄을
  가로질러 **주사(朱砂) 인장**이 찍힌다. 붉은 끈 매듭만 일반 부적과 공유한다(혼례의 문법).
  PROMPT: folded korean hanji paper talisman made from a page torn out of a black ledger book of
    the dead, deep ink black folded paper packet, two short vertical columns of white brush written
    names side by side on the front, a vermilion cinnabar seal stamped across both columns, a
    crimson silk cord tied in a knot around it with tassel ends hanging off the side, korean
    shamanic wedding amulet, [§1.1 광원 세트], muted somber underworld palette
    (create_image_pixen / view=side / selective outline / low detail / no_background / seed 90901)
후처리: 하드 알파 → muted(0.90/0.97 = §21.1 혼례 부적과 **같은 아이콘 값** — 같은 인벤 격자에서
  둘이 한 집으로 읽혀야 한다) → 32² 중앙정렬.
★★ **명도가 두 부적을 가른다** — 혼례 부적은 크림빛(밝음), 명부판은 먹빛(어두움)이다. 32² 격자에서
   색상이나 장식이 아니라 **값**으로 갈리는 것이 가장 확실하다(둘이 실제로 같은 가방에 함께 들 수
   있는 물건은 아니지만, 도상이 같은 계열이라 한눈에 "혼례 문법의 다른 판본"으로 읽혀야 한다).
★  §21.1의 두 금기를 그대로 승계한다: **하트·반지 도상 금지**(이 세계의 혼례 문법은 서양 결혼이
   아니라 무속 의례다 — ADR-0004) · **붉은 끈 매듭을 몸통 밖으로 흘릴 것**(종이 몸통만 남으면
   편지·씨앗 봉지와 구분이 안 된다).
★  **상태를 굽지 않는다** — 세상에 하나뿐인 물건이지만 아이콘은 늘 같다(§18.2·§20.1·§21.1 규율).
```

### 23.5 이 패스가 바꾼 렌더 (아트 생성물 아님 — 코드)

```
① 조연 9인 `_draw()` 그레이박스 → **도색 스프라이트**. 코드 변경 0줄이다 — 각 파일의 `_draw()`
   첫 줄이 `if _sprite != null: return`이라, 시트가 로드되는 순간 색박스가 스스로 물러난다.
   ★그레이박스 코드는 **지우지 않는다**(폴백 유지). 시트를 못 읽는 상황에서 마을이 텅 비는 것이
   색박스가 서 있는 것보다 나쁘다 — 네오·모찌 이래의 규약이다.
② main `r_{kkaebi,seolhwa,scarlet,gangrim,serena}.portrait_stem` "" → "<id>" (5줄) ·
   `r_{ken,mir,luca,frosty}.portrait_stem`은 ""를 **유지하되 주석을 갱신**(4줄 — "아직 없음"이
   아니라 "미생성 확정 + Gemini 큐"로. 결정과 미이행은 다른 것이고, 주석이 그것을 말해야 한다).
③ main.MINE_ICONS +1(명부 혼례 부적).
④ 각 `*_arc_test.gd` ①d 단언 갱신(9줄) — 이 단언들은 원래 `portrait_stem == ""`를 "시트·초상 =
   S9b-T9 아트 패스 소관"이라는 **예약**으로 들고 있었다. 이 패스가 그 자리를 채웠으므로 다섯은
   stem 값을 재고, 넷은 **미생성이 결정임**을 잰다. ★예약 주석을 남긴 태스크가 그 예약을
   회수하는 것까지가 한 태스크다(S9b-T7이 "예약 주석이 소스 스캔에 위반으로 잡힌다"로 배운 결).
⑤ 신규 하네스 `tools/s9b_chorus_dump.gd`(육안 + `_sprite` null 기계 판정).
★ **회귀 18스위트 통과**: resident · gift · {kkaebi,ken,seolhwa,scarlet,mir,luca,frosty,gangrim,
  serena}_arc · spine_ending · inventory · npc_station · marriage · romance · s9_narrative_smoke ·
  village. 아트만 바뀐 패스에서 arc 9종을 전부 돈 이유는 ④ 때문이다(단언이 실제로 바뀐다).
```

---

## 24. ★[S10-T9] 엔드게임 롱테일 아트 패스 — 프롭 17·아이콘 3·시트 2·외관 2 스펙카드 (owner Gemini 무수정 교체 대기)

> **상태:** PixelLab 생성 + 후처리로 **인게임 배선 완료**(2026-08-15). §10~§23과 같은 [ADR-0048]
> 교체 큐다 — owner가 같은 파일명·크기로 다시 뽑아 `*_raw.png`만 덮어쓰고
> `cd game && python3 tools/make_s10_t9_art.py`를 한 번 돌리면 **코드 0줄 수정**으로 반영된다.
> (외관 둘만 별도: `python3 tools/facade_halfres_x2.py assets/buildings/raw/<x>_src.png assets/buildings/<x>.png`.)
> (PNG를 갈아 끼운 뒤에는 `cd game && godot --headless --import` 1회 — 임포트 캐시가 소스가
> 아니라 `.godot/imported/*.ctex`를 읽는다.)
>
> **후처리 글루:** [`game/tools/make_s10_t9_art.py`](../../game/tools/make_s10_t9_art.py) — 규칙·계수는
> `make_s9_t9_art.py`·`make_s9b_t9_art.py`와 **같은 값**을 쓴다(새 규칙 0 · 하드 알파 → muted →
> 앵커 재정렬). 새로 는 것은 셋뿐이다: `hue_to`(스프링클러 티어 틴트 파생) · `largest_blob`
> (생성물이 캔버스 구석에 흘린 워터마크 부스러기 제거) · 레어크로우 아이콘 crop(생성 0 파생).
>
> **★raw 보관 — 덮어쓸 파일의 정확한 이름**(글루가 읽는 것이 이 목록의 전부다. ⚠️ 재생성한 셋은
> `_v2_` 이름을 그대로 쓴다 — 폐기한 1차 raw도 옆에 남아 있으니 **이름을 정확히 보고 덮어쓸 것**):
>
> | 산출 | 덮어쓸 raw |
> |---|---|
> | `props/{codex_stand,firefly_stand,sapsari,pet_bowl,garden_pot,panning_spot,sprinkler,firefly_soul}.png` | `game/assets/props/raw/<같은 이름>_raw.png` |
> | `props/crystalarium.png` | `game/assets/props/raw/`**`crystalarium_v2_raw.png`** ⚠️ |
> | `props/trial_board.png` | `game/assets/props/raw/`**`trial_board_v2_raw.png`** ⚠️ |
> | `props/peddler_stall.png` | `game/assets/props/raw/`**`peddler_stall_v2_raw.png`** ⚠️ |
> | `props/trial_stall.png` | `game/assets/props/raw/trial_stall_raw.png` |
> | `props/rarecrow_{1..8}.png` (+ `_icon` 자동 파생) | `game/assets/props/raw/rarecrow_{1..8}_raw.png` |
> | `props/sprinkler_t{1,2,3}.png` (틴트 자동 파생) | `game/assets/props/raw/sprinkler_raw.png` **한 장** |
> | `props/mount_horse.png` | `game/assets/props/raw/mount_horse_raw/{south,north,east,west}.png` |
> | `characters/soul_child.png` | `game/assets/characters/`**`soul_child_v2_raw/`**`{south,north,east,west}.png` ⚠️ |
> | `ui/trial_token.png` | `game/assets/ui/raw/trial_token_raw.png` |
> | `materials/{crystalarium_part,mount_whistle}.png` | `game/assets/materials/raw/<같은 이름>_raw.png` |
> | `buildings/{greenhouse,trial}_ext.png` | `game/assets/buildings/raw/{greenhouse,trial}_ext_src.png` (half-res) |
>
> 폐기 1차 raw(참고용 잔존 · 글루가 안 읽는다): `props/raw/crystalarium_raw.png`(안에 결정) ·
> `props/raw/trial_board_raw.png`(순검정) · `props/raw/panning_spot_v2_raw.png`(배경 불투명) ·
> `props/raw/peddler_stall_raw.png`(어두운 얼룩) · `characters/soul_child_raw/`(머리카락·옷) ·
> `buildings/raw/`의 시련장 1차는 `trial_ext_src.png`를 **덮어썼다**(폭 156판 미보존).
>
> **PixelLab 사용량 32 gen**(create_image_pixen 18 · create_image_pixflux 9〈레어크로우 img2img〉 ·
> create_character 3〈동행 혼 v1 폐기·v2 채택 · 먹갈기 4방향〉 · 그중 폐기 4 = 결정기 v1〈안에
> 결정을 구워 왔다〉·팬닝 v2〈배경 불투명〉·시련 게시판 v1〈순검정 실루엣〉·동행 혼 v1〈머리카락·
> 옷을 그려 와 설정선 위반〉). **생성 0으로 얻은 것 12장**: 스프링클러 상위 2티어(틴트) ·
> 레어크로우 아이콘 8종(월드 스프라이트 위 절반 crop) · 화분/결정기 인벤 아이콘(월드 프롭 공용).
>
> **이 패스가 지운 색박스·그레이박스 17종:** 팬닝 스폿 · 결정기 · 스프링클러 3티어(월드+인벤) ·
> 레어크로우 8종(밭+인벤) · 보부상 좌판 · 삽사리 · 물그릇 · 먹갈기 · 화분 · 도감 열람대 ·
> 반딧넋 안치대 · 반딧넋 · 시련 게시판 · 시련패 매대 · 시련패 화폐 아이콘 · 결정기 부품 ·
> 먹갈기 휘파람 · 동행 혼 · 늘봄방 외관 · 시련장 외관.
>
> **이 패스가 안 만든 것(이월 — §24.9):** 마구간 외관 · 늘봄방 실내 유리 룩 · 경지 유물 5종 아이콘.

### 24.0 공통 규약

```
전부 [ADR-0050] 32-native · [§1.1] NW 광원 · [§8.1] 하드 알파 · [§9] 저승 muted · [§3] 발치 앵커.
생성: create_image_pixen(selective outline / low detail / no_background=true / seed 고정) —
      §18.0·§20.0·§21.0·§22.0이 세운 그 호출이다.
muted 계수(한 자리에 나란히 서는 것끼리 같은 값이라야 새것만 안 튄다):
  아이콘        0.90/0.97 (= §18.1 메뉴·§21.1 부적·§22.2 책과 **같은 값**)
  월드 프롭     0.85/0.95 (= §18.2 곳간·§20.1 점괘 거울·§22.1 우편함과 **같은 값**)
  캐릭터 시트   0.94/0.98 (= §23.0 조연 9인과 **같은 값**)
  혼백관 창구   0.68/0.88 (**이 패스 예외** — §22.0이 museum_shelf에 0.62/0.90을 건 그 판단 1:1.
                그 방의 기존 좌대·진열장이 draw_rect 어두운 갈색이라 밝은 목재·이끼 초록이 튄다)
  레어크로우    0.74/0.90 (**이 패스 예외** — 8기가 한 밭에 나란히 선다. 종별 소품 색<등롱 금빛·
                볏단 노랑·탈 붉음>을 생성물 그대로 두면 그 둘만 형광이라 "순수 스킨"이 아니라
                등급으로 읽힌다. 기존 프롭 허수아비의 어두운 갈색에 8종을 통째로 합류시킨다)
  반딧넋        **muted 안 걸음(1.0/1.0)** — [혼불](따뜻한 주홍)과 갈리는 차가운 넋빛이 정체
                그 자체다. [§9] "물·영혼빛은 저승 액센트로 muted에서 제외" 조항의 이행.
★청키화(enforce_chunk)는 걸지 않는다 — §20.0·§21.0·§22.0이 그은 선 그대로.
★★ 상태를 아트에 굽지 않는다(이 패스가 가장 많이 적용한 규율 — 아래 개별 카드의 ★★가 전부 이것):
   결정기 속 보석 · 화분 속 작물 · 물그릇 속 물 · 게시판 쪽지 · 매대 잔고 · 등롱 불빛 · 눈금 ·
   완주 트로피 · 게이트 표식. 전부 원장 파생 코드가 아트 **위에** 그린다.
★ 실루엣 계열 보존 규칙(이 패스가 새로 실증): 기능이 같은 N종은 **개별 생성 금지**다.
   레어크로우 8종 = 기존 farm_scarecrow.png를 init 이미지로 삼은 img2img(strength 160·tgs 13) ·
   스프링클러 3티어 = 한 장의 종색 틴트. 실루엣이 갈리면 플레이어가 성능 차이로 오독한다.
   ⚠️ init strength 240은 **액세서리가 아예 안 붙는다**(레어크로우 ① 1차 실측). 160이 하한 검증값.
```

### 24.1 ★혼백관 두 창구 `props/{codex_stand,firefly_stand}.png` (각 32×27) — 같은 줄 세 창구의 둘

```
배선: **코드 0줄.** `_draw_museum_room`이 이미 `_prop_tex("codex_stand")`/`_prop_tex("firefly_stand")`
  우선 분기다(T6·T7이 깔아 둔 훅). 자리 = 기증대(x13)와 한 줄, 열람대 동편 (17,46)·안치대 서편 (9,46).
★★ **높이 32가 아니라 27이다.** 두 창구 모두 타일 **좌상단**에 그려지고(`draw_texture(tex, cpx)`),
   진행 눈금 막대가 타일 하단 y27..30에 깔린다. 32를 다 쓰면 눈금이 아트를 가로질러 "여기까지
   찼다"가 아니라 "받침에 그은 금"으로 읽힌다 — 그레이박스 도형도 y26에서 끝났다(같은 기하).
정체성(열람대): 혼백관 서고의 **경사 독서대**. 어두운 호두목 상판에 명부 장부가 펼쳐져 있다.
  PROMPT: a single small korean wooden lectern reading stand holding one open ledger book of the
    dead, slanted dark walnut writing desk top, a pale hanji paper page spread open on it with faint
    ink columns, a small brass ink stone beside it, temple archive furniture, [§1.1 광원 세트],
    muted somber palette   (view=low top-down / selective outline / low detail / seed 101001)
정체성(안치대): 넋을 눕히는 **돌 대좌 + 빈 등롱**. 석등(石燈) 실루엣이라 "바치는 자리"로 읽힌다.
  PROMPT: a single small stone pedestal altar with a korean hanging lantern frame on top, dark grey
    slate base block, a slender teal metal lantern cage with empty glass panes, no light inside,
    a thin rope hanging from the frame, shrine offering stand, [§1.1 광원 세트], muted somber palette
    (view=low top-down / selective outline / low detail / seed 101002)
후처리: 하드 알파 → muted(0.68/0.88) → 32×27 bottom 앵커. 안치대만 crop_bottom=2(접지 그림자).
★★ **등롱에 불을 켜지 마라.** 안치한 넋의 수만큼 뜨는 불빛은 `_draw_museum_room`이 원장에서
   파생해 y8 자리에 그린다(한 점 = 다섯 넋) — 구우면 0개일 때도 켜져 있다.
★★ **독서대에 진행 눈금·트로피를 굽지 마라.** 등재율 막대도 완주 상(像)도 전부 원장 파생이다.
★ 판독 가능한 글씨를 넣지 마라(§22.2와 같은 이유 — 32px에서 노이즈 + 로어를 아트에 굽는 것).
```

### 24.2 ★저승 보부상 좌판 `props/peddler_stall.png` (32×48) — 7의 배수 날의 얼굴

```
배선: **코드 0줄.** `_draw_peddler`가 이미 `_prop_tex("peddler_stall")` 우선 분기다(T3의 훅).
  자리 = 나루 다리 남단 부두 PEDDLER_TILE 한 칸. 야시장 매대(props/night_market.png)와
  **완전 동형**이다 — 같은 32×48·같은 발치 앵커·같은 "임시 오버레이" 층.
정체성: 지게(A자 운반대)에 봇짐을 지고 와 보자기를 펼친 **떠돌이 장수의 좌판**.
★ **보부상 본인을 좌판에 함께 굽는다**(이 패스의 판단 — owner 큐): 대사 노드가 없는 임시
  오버레이라 NPC 시트를 따로 두면 서 있기만 하는 몸이 하나 늘고, 그 몸은 스케줄도 초상도
  하트도 없어 "말 없는 사람"이 된다(주민 레지스트리에 안 든 인물이 광장에 서는 첫 사례가 된다).
  PROMPT: a korean peddler sitting behind a market ground stall, a large pale straw mat spread flat
    on the ground taking the lower half, three clearly separated round bundles wrapped in cloth
    resting on the mat, behind them a seated figure in a dark hemp jacket wearing a very large pale
    conical straw hat that reads as a wide bright disc, simple bold shapes, strong contrast between
    the pale straw and the dark goods, uncluttered, readable at small size, [§1.1 광원 세트],
    muted somber palette   (view=low top-down / selective outline / low detail / seed 101023)
후처리: 하드 알파 → muted(0.85/0.95) → 32×48 bottom 앵커.
★★ ⚠️ **1차(seed 101003)는 어두워서 폐기했다.** 지게(A자 운반대)+봇짐+사람을 다 그려 넣었더니
   32×48에서 **한 덩이 검은 얼룩**이 됐고, 무대가 하필 **어두운 판자 부두**라 dark-on-dark로
   완전히 뭉갰다([asset-ruleset §17] "게임플레이 오브젝트는 명도로 구분" 위반 · 1차 덤프 실측).
   ⇒ 교체판의 절대 요구는 **명도 대비**다: 밝은 삿갓 원반 + 밝은 짚 자리 두 조각이 어두운 봇짐·
   몸을 사이에 끼워 형태를 판다. 디테일을 늘리지 말고 **덩어리 셋(삿갓/몸/자리)** 로 단순화할 것.
★ 야시장 매대와 **한눈에 갈려야 한다**: 야시장 = 등롱 걸린 천막(절기 한정판) / 보부상 = 지게와
  땅에 편 보자기(상시 리듬). [ADR-0069] 결정 5의 역할 분리를 실루엣이 말한다.
```

### 24.3 ★코지 펫 둘 `props/{sapsari,pet_bowl}.png` (각 32×32) — 집 앞 마당

```
배선: **코드 0줄**(삽사리·물그릇 둘 다 T4가 `_prop_tex` 훅을 깔아 뒀다). 단 물그릇은 **드로우
  경로를 1줄 고쳤다** — §24.10 ③ 참조(아트가 상태 표식을 삼키던 회귀 봉합).
정체성(삽사리): 귀신 쫓는 **삽살개**. 털이 길고 다리가 짧아 낮고 둥글넓적하며, 앞머리가 눈을 덮는다.
  PROMPT: a single small shaggy long haired korean sapsali dog sitting facing the viewer, thick
    tangled dusty tan and brown fur covering its whole body, very short legs hidden under the coat,
    a long fringe of hair completely covering its eyes, a small dark nose, calm and cozy, a farmyard
    pet, [§1.1 광원 세트], muted somber palette
    (view=low top-down / selective outline / low detail / seed 101004)
정체성(물그릇): 낮은 **질그릇 개밥그릇**. 두툼한 테두리 · 안은 말라 바닥이 보인다.
  PROMPT: a single small empty shallow ceramic dog water bowl standing on the ground, dark grey
    brown glazed stoneware, a thick rounded rim, completely empty and dry inside showing the bare
    bottom of the bowl, no water, [§1.1 광원 세트], muted somber palette
    (view=low top-down / selective outline / low detail / seed 101005)
후처리: 하드 알파 → muted(0.85/0.95) → 32² bottom 앵커.
★★ **그릇에 물을 굽지 마라.** 채운 물 띠는 `_draw_sapsari`가 `pet.can_fill_bowl(day)`를 보고
   덧그린다 — 구우면 안 채운 날에도 차 보이고, 그러면 "오늘 몫을 했나"가 눈으로 안 읽힌다.
★ ⚠️ 바나 사역마(박쥐·검은고양이)와 **위상이 다르다**([ADR-0069] 결정 7) — 전투 결의 검은 짐승이
  아니라 순수 코지 존재다. 어둡고 날카롭게 그리면 그 분리가 무너진다.
```

### 24.4 ★팬닝·결정기 `props/{panning_spot,crystalarium}.png` (각 32×32) — T1의 두 얼굴

```
배선: **신규 3줄씩**(`_draw_panning_spots`·`_draw_crystalariums`에 `_prop_tex` 분기 — T1은 훅을
  안 깔았다). 상태 드로우는 그대로 아트 위에 얹힌다.
정체성(팬닝 스폿): 물가에 그날 반짝이는 **젖은 자갈 웅덩이**. 주울 물건이 아니라 "여기를 일면
  뭔가 나온다"는 **표식**이라 종을 보여 줄 것이 없다(무엇이 나오는지는 일어야 안다).
  PROMPT: a flat shallow patch of wet river gravel seen from directly above, a rounded pool of dark
    damp pebbles and coarse grey sand lying flush on the ground, scattered tiny bright gold flecks
    glinting among the stones, completely flat with no height, a riverbed panning spot,
    [§1.1 광원 세트], muted somber palette
    (view=high top-down / selective outline / low detail / seed 101008)
정체성(결정기): 보석을 **불려 내는 빈 유리 상자**. 네 다리 철제 프레임 + 맑은 유리 + 평평한 뚜껑.
  PROMPT: an empty transparent glass terrarium box on four thin dark iron legs, bare clear glass
    panes on all sides showing straight through to the other side, a plain flat dark metal lid on
    top, absolutely nothing inside the box, hollow and vacant, no crystals, no gems, no contents,
    [§1.1 광원 세트], muted somber palette
    (view=low top-down / selective outline / low detail / seed 101016)
후처리: 하드 알파 → muted(0.85/0.95) → 팬닝 = 32² **center** 앵커 / 결정기 = 32² bottom 앵커.
★★ **결정기 안을 비워 굽는다.** 든 보석·여문 정도·남은 일수 눈금은 전부 원장 파생이다
   (1차 생성 seed 101006은 유리 안에 결정을 구워 와 **폐기**했다 — 빈 기계도 찬 것으로 보였다).
★★ **팬닝은 center 앵커다**(발치 앵커 아님). 부피 있는 물건이 아니라 바닥에 깔린 표식이라
   높이가 0이고, 따라서 [§11] 접지 그림자도 없다. 금빛 알갱이 한 점만 코드가 위에 남긴다.
   ⚠️ 1차 재생성(seed 101018, lineless)은 **강둑 장면을 배경째 그려 와 폐기**했다 — 데칼은
   `no_background`가 실제로 먹혔는지(투명 bbox가 캔버스보다 작은지) 반드시 확인할 것.
```

### 24.5 ★화분 `props/garden_pot.png` (32×32) — 실내 1×1 경작 컨테이너

```
배선: **신규 4줄**(`_draw_garden_pots`에 `_prop_tex` 분기). 이 한 장이 **월드 설치물과 인벤
  아이콘을 공용**한다([asset-ruleset §15] — 인벤에서 든 그것이 방에 선 그것과 같은 그림).
정체성: **마른 빈 테라코타 화분.** 굽지 않은 붉은 점토 · 두툼하게 만 테두리 · 안은 맨 흙.
  PROMPT: a single small round terracotta flower pot filled with plain dark dry soil, an unglazed
    reddish brown clay planter with a thick rolled rim, the soil surface is flat bare and empty,
    nothing planted in it, no sprout, no plant, no flower, [§1.1 광원 세트], muted somber palette
    (view=low top-down / selective outline / low detail / seed 101007)
후처리: 하드 알파 → muted(0.85/0.95) → 32² bottom 앵커.
★★ **심은 것도 젖은 흙도 굽지 마라.** 작물 스프라이트는 화분 입구 위로 코드가 얹고(org+(0,-8)),
   젖은 흙 띠는 오늘 물 준 칸에만 그린다 — **매일 손 물주기**가 화분의 정체([ADR-0069] 결정 8
   차별 자구 4개 중 둘)라 그 상태를 아트에 구우면 차별이 눈에서 사라진다.
★ 늘봄방 경작면(SOIL 타일)과 **혼동되면 안 된다**: 화분은 놓인 그릇이라 칸 경계가 남게 그린다.
```

### 24.6 ★스프링클러 3티어 `props/sprinkler_t{1,2,3}.png` (각 32×32) — 생성 1 · 틴트 파생 3

```
배선: **신규 5줄**(`_draw_sprinklers`에 `_prop_tex("sprinkler_t%d")` 분기). 세 장 전부 **월드
  설치물과 인벤 아이콘 공용**(S10_ICONS).
★ **한 실루엣의 종색 셋**이다(개별 생성 금지 — §24.0 실루엣 계열 보존). 근거는 결정 3 그 자체다:
  티어 차이는 이미 **급수 범위 크기**가 말하고(4/8/24칸 하이라이트) 색은 거드는 신호다. 실루엣을
  셋으로 갈라 생성하면 "다른 기계 셋"으로 오독된다.
★ 세 색의 단일 출처 = `main._draw_sprinklers`의 그레이박스 몸통 색이다(청록 → 남빛 → 금빛).
  글루가 그 세 RGB에서 hue를 뽑아 쓰므로(SPRINKLER_HUES) 그레이박스와 아트가 같은 신호를 판다.
  PROMPT: a single small farm sprinkler device standing on the ground, a squat verdigris teal bronze
    cylinder base with a rounded spout head on top and three short nozzle arms fanning out sideways,
    dry and not spraying, no water jets, no droplets, an irrigation machine, [§1.1 광원 세트],
    muted somber palette   (view=low top-down / selective outline / low detail / seed 101013)
후처리: 하드 알파 → muted(0.85/0.95) → hue_to(티어색, 채도 0.15 미만 픽셀은 불변) → 32² bottom.
★★ **물을 뿌리는 모습을 굽지 마라.** 급수 십자/사각 하이라이트는 코드가 원장의 `targets_of`에서
   파생해 그린다 — 구우면 범위가 티어와 어긋나고, 밭 위에 물이 늘 뿌려져 있는 그림이 된다.
★ 외곽선을 물들이지 마라: 글루가 채도 0.15 미만(무채 선·하이라이트)은 안 건드린다. 생성물이
  선까지 청록으로 칠해 오면 틴트 후 세 티어가 탁하게 뭉친다.
```

### 24.7 ★레어크로우 8종 `props/rarecrow_{1..8}.png` (각 32×64) + `_icon.png` (각 32×32)

```
배선: **신규 5줄**(`_draw_rarecrows`에 `_prop_tex(id)` 분기 — 파일명이 곧 아이템 id라 종이 늘어도
  이 함수는 안 고친다) + S10_ICONS 8줄(인벤).
★★ **8종은 img2img 파생이다**(개별 생성 금지). init = 기존 프롭 허수아비 `props/farm_scarecrow.png`,
   create_image_pixflux(init_image_strength=160 · text_guidance_scale=13 · view=low top-down ·
   selective outline · low detail). 근거 = [ADR-0051] 결정 5 "기능·반경 동일한 **순수 스킨**":
   실루엣이 갈리면 플레이어가 성능 차이로 오독한다.
   ⚠️ **strength 240은 액세서리가 아예 안 붙는다**(① 1차 실측 — 원본이 그대로 나왔다). 160이
   "몸은 남고 소품은 붙는" 검증된 하한이다. 그보다 낮추면 몸이 흔들린다.
★ 아이콘은 **생성 0** — 월드 스프라이트의 위 절반 crop이다(글루 `build_rarecrows`). 종을 가르는
  것은 머리에 얹거나 문 소품 한 조각이고 그건 전부 위 절반에 있다. 32×64를 32²로 통째로
  욱여넣으면(세로 압축) 8종이 다 같은 갈색 막대가 된다 — 형태가 아니라 압축이 정체를 지운다.
공통 프롬프트 뼈대(소품 절만 갈아 끼운다):
  "a straw scarecrow <소품 절>, burlap sack head, ragged brown coat, mounted on a single post,
   muted somber underworld palette"
  ① seed 102011 `wearing a very wide brimmed black korean gat horsehair hat sitting on top of its
     burlap sack head, big round black hat brim`
  ② seed 102012 `holding up a glowing paper lantern on a stick beside its head, a round warm amber
     korean paper lantern hanging from the raised arm`
  ③ seed 102013 `wearing a thick shaggy straw rain cape dorongi draped over its shoulders and back,
     long loose straw fringes hanging all around its body`
  ④ seed 102014 `with a big white folded letter envelope clamped in the mouth slit of its head,
     a bright pale cream envelope with a red wax seal held between its jaws`
  ⑤ seed 102015 `with a big bulging cloth bundle pack tied high on its back and rising above its
     shoulders, a fat knotted wrapping cloth bojagi bundle strapped on`
  ⑥ seed 102016 `holding a long thin bamboo fishing rod that leans diagonally far up past its head,
     a taut fishing line running from the rod tip`
  ⑦ seed 102017 `balancing a fat golden sheaf of harvested rice straw on top of its head, a thick
     pale yellow bundle of grain stalks carried on the head and tied with cord`
  ⑧ seed 102018 `with a bright red and white painted korean hahoe wooden festival mask covering the
     whole front of its head, a grinning carved mask face with black eye holes`
후처리: 하드 알파 → muted(0.74/0.90 — §24.0 계열 톤) → 32×64 bottom 앵커 → 위 32 crop = 아이콘.
★알려진 결함(교체 시 고칠 것):
  · **⑥ 낚싯대가 약하다** — 대각 획이 붉은 띠와 섞여 "낚싯대"로 안 읽힌다. 대를 머리 위로 더
    길게, 색을 몸과 갈라 뽑을 것.
  · **⑦ 볏단이 금발 머리로 읽힌다** — 머리 위 다발의 윤곽이 두피에 붙었다. 다발을 한 뼘 띄우고
    묶은 끈을 굵게.
  · **④ 편지가 작다** — 32폭에서 봉투가 손·입 어디에 있는지 모호하다. 가슴 앞으로 크게 들 것.
  · ①의 갓이 서양 페도라 챙에 가깝다(정통 갓 = 원통 crown + 넓고 평평한 챙).
```

### 24.8 ★반딧넋 · 시련장 두 프롭 · 아이콘 3종

```
── 반딧넋 `props/firefly_soul.png` (32×32 · center 앵커) ──────────────────────
배선: **신규 4줄**(`_draw_firefly_souls`). ★ **몸만 굽는다** — 둘레 할로는 코드가 반투명 원으로
  먼저 깔고 그 위에 이 스프라이트를 얹는다([§8.1] 하드 알파 스프라이트에 번짐을 구울 수 없고,
  발광은 런타임 몫이라는 [§8.3]의 결).
  PROMPT: a single tiny lost soul wisp shaped like a firefly, a small pale mint white glowing core
    with a soft rounded teal aqua body and two faint wing veils, a slender curved tail of light
    trailing under it, cold spirit light, not fire, no orange, no flame, luminous teal spirit palette
    (view=side / lineless / low detail / seed 101014)
★★ **muted를 걸지 않는다**(1.0/1.0 — §24.0). [혼불](따뜻한 주홍 여우불)과 갈리는 **차가운 넋빛**이
   정체 그 자체다(CONTEXT [반딧넋] "불이 아니라 넋이 주어다"). 채도를 누르면 그 색 언어가 죽는다.
★ 기존 `ui/soul_moth.png`(대화창 먹 나비)와 **같은 결의 나방**이라 세계관 어휘가 이어진다.

── 시련 게시판 `props/trial_board.png` (32×32) · 시련패 매대 `props/trial_stall.png` (32×22) ──
배선: **신규 6줄씩**(`_draw_trial_room`). ⚠️ `quest_board.gd`는 한 바이트도 안 건드렸다(T8 계약).
  PROMPT(게시판): a small empty notice board standing on two short legs, a wide charcoal grey
    weathered wood plank panel with visible plank seams and a pale bone grey carved frame border
    around it, the board face is bare and blank with no paper and no writing, mid grey and dark grey
    two tone, clearly readable shape, [§1.1 광원 세트], muted somber palette
    (view=low top-down / selective outline / low detail / seed 101019)
  PROMPT(매대): a small empty dark stone counter shop stall, a low slab topped trading table of grey
    purple slate with a plain apron below it, the counter top is completely bare and empty, no goods,
    no coins, no wares on it, an underworld exchange counter, [§1.1 광원 세트], muted somber palette
    (view=low top-down / selective outline / low detail / seed 101010)
후처리: 하드 알파 → muted(0.85/0.95) → 게시판 32² bottom · 매대 32×22 bottom(그레이박스 몸통
  y10..32와 같은 기하 — 잔고 패가 그 위 y8에 뜬다).
★★ **판면·상판을 비워 굽는다.** 걸린 시련 쪽지·수락 중 붉은 도장·시련패 잔고는 전부 원장 파생이다.
★ ⚠️ 1차 게시판(seed 101009, "ink black lacquered")은 **순검정 실루엣**으로 나와 폐기했다 —
  저승 톤이라도 판면에 명도 2단은 있어야 32px에서 형태가 산다.

── 아이콘 3종 `ui/trial_token.png` · `materials/{crystalarium_part,mount_whistle}.png` (각 32×32) ──
배선: 시련패 = `_trial_token_icon()`(T8이 깐 훅 — 파일만 놓으면 엽전 폴백이 물러난다) ·
  나머지 둘 = S10_ICONS(인벤·핫바·토스트 한 경로).
  PROMPT(시련패): a single small rectangular wooden tally tag token, a pale bone coloured narrow
    plaque with a rounded top and a small hole drilled through it, a short dark red cord knotted
    through the hole, one bold vermilion ink seal stamp pressed on its face, an inventory item icon,
    [§1.1 광원 세트], muted somber palette   (view=side / selective outline / low detail / seed 101011)
  PROMPT(결정기 부품): a single small tarnished brass machine part lying flat, a toothed cog wheel
    fused to a short bracket with a tiny cracked lens set in it, silt and grit still clinging to it,
    a salvaged apparatus component, an inventory item icon, [§1.1 광원 세트], muted somber palette
    (view=side / selective outline / low detail / seed 101012)
  PROMPT(휘파람): a single small carved bone whistle hanging from a braided dark cord, a short pale
    ivory tube with two finger holes and a mouthpiece end, a small horsehair tassel tied at one end,
    an inventory item icon, [§1.1 광원 세트], muted somber palette
    (view=side / selective outline / low detail / seed 101015)
후처리: 하드 알파 → muted(0.90/0.97) → 32² center 앵커.
★★ **시련패는 엽전(ui/gold_coin.png)과 한눈에 갈려야 한다** — 그것이 이 아이콘의 존재 이유다.
   시련패 상점은 만물상 셸을 빌려 쓰므로, 값 옆 아이콘 하나가 "이건 냥이 아니다"를 말한다
   ([ADR-0069] 결정 11 "시련패는 냥과 바꿀 수 없다"의 시각 이행). 둥근 금화 실루엣 금지.
★ 결정기 부품이 **물에서 건진 것**으로 보여야 한다(팬닝 산출) — 진흙·녹이 정체의 절반이다.
```

### 24.9 ★동행 혼 시트 · 먹갈기 승마 시트 · 외관 둘

```
── 동행 혼 `characters/soul_child.png` (80×320 = 프레임 80² · 1열 × 4행) ────────
배선: **코드 0줄.** `soul_child.gd`가 `CharSprite.make("res://assets/characters/soul_child.png")`
  훅을 이미 깔아 뒀다(§23.1 조연 9인과 같은 결 — 파일을 놓는 것이 배선의 전부).
생성: create_character(mode=standard / n_directions=4 / low top-down / selective outline /
  flat shading / low detail / tgs=14 / §11.4 공통 proportions / **size 24**)
★ **size 24인 이유 = 그레이박스가 스펙이다**: `soul_child.gd`의 `_BODY`가 사람형 16×32의 **절반
  키**(12×16)라 "한눈에 작다"가 실루엣의 전부다. 사람 규격 44(§23.0)의 절반이 24다.
정체성(CONTEXT [동행 혼] · [ADR-0069] 결정 12 — 어길 수 없는 설정선):
  ⚠️ **성별·종족을 특정하는 형태를 그리지 마라**(머리 모양·옷·귀). 결속에서 깃든 혼이라 성별·
  생물학과 무관하고(동성 부부 포함 전 부부 동일), "형상을 아직 다 얻지 못했다"가 실루엣의 전부다.
  PROMPT: a small featureless spirit wisp in vague child height human shape, its entire body is one
    smooth pale bluish white glowing substance with a softly blurred edge, completely bald with no
    hair at all, entirely naked of any clothing with no dress no robe no garment no belt and no
    shoes, no ears, no nose, no mouth, no hands detail, no gender markers of any kind, the only
    feature anywhere is a pair of tiny dark grey dot eyes, a shape not yet finished forming,
    muted somber underworld palette
★★ ⚠️ **1차(seed 무지정 · tgs 11 · basic shading)는 단발머리와 원피스를 그려 와 폐기했다** —
   위 설정선 정면 위반이다. 부정형을 **낱개로 나열**(no dress / no robe / no garment / no belt /
   no shoes / no hair at all)하고 tgs를 14로 올려야 지켜진다(§23.0 리젝 기준 ② "금지 도상을
   이름으로 적는다"의 재실증).
후처리: 하드 알파 → muted(0.94/0.98) → 80² 프레임 발치정렬(FOOT_Y=74).
★알려진 결함(교체 시 고칠 것): **north 프레임의 머리가 남면보다 넓은 쐐기꼴**이라 뒤에서 보면
  두건을 쓴 것처럼 읽힌다(§23.0 ★★ "north를 반드시 눈으로 확인" 규율의 이번 적발분). 다만 이
  존재는 집 안에 상주하고 이동 스케줄이 없어 실플레이 노출은 낮다.

── 먹갈기 승마 시트 `props/mount_horse.png` (48×192 = 프레임 48² · 1열 × 4행) ──
배선: **신규 8줄**(`_draw_mount` — 단일 텍스처 → 행 선택). [ADR-0069] 결정 6이 "승마 합성 시트는
  아트 패스(T9)"로 넘긴 그 시트다. 행 순서 = `CharSprite.DIRS`(down/up/right/left)와 **같고**,
  방향 판정도 `CharSprite.dir_anim(player.get_facing())`을 그대로 빌린다 — 규칙이 사람과 말에서
  갈리면 몸통과 탈것이 같은 자리에서 서로 다른 데를 본다.
생성: create_character(body_type=quadruped / template=horse / mode=standard / n_directions=4 /
  low top-down / selective outline / basic shading / low detail / tgs=11 / size 40)
  PROMPT: a small sturdy underworld pony horse with an ink black flowing mane and tail, its coat is
    dark charcoal grey, a simple leather saddle and bridle fitted on it, calm and stocky, short legs,
    no rider, muted somber underworld palette
★ **프레임 48인 이유**: east/west 콘텐츠가 42px라 32에 안 들어가고, 캐릭터 규격 80을 쓰면 시트가
  필요 이상으로 커진다(말은 사람보다 옆으로 넓다). 프레임 하단 = 말굽 = 플레이어 발치.
★★ **탄 사람을 그리지 마라**(`no rider`). 플레이어 스프라이트가 이 위에 그려진다 —
   구우면 사람이 둘이 된다.
★ ⚠️ 생성물 south 프레임 좌상단에 워터마크 부스러기가 붙어 왔다 → 글루 `largest_blob`이 가장 큰
  연결 성분만 남긴다(교체판도 같은 처리를 거치므로 owner가 지울 필요는 없다).

── 늘봄방 외관 `buildings/greenhouse_ext.png` (250×216 · half-res 128×112 생성) ──
── 명부 시련장 외관 `buildings/trial_ext.png` (188×144 · half-res 96×80 생성) ──
배선: **신규 함수 2개 + 호출 2줄**(`_draw_facade_greenhouse`·`_draw_facade_trial`). T5·T8이
  `_build_facade`로 WALL 박스만 세워 둔 자리를 이 두 장이 덮는다.
생성: create_image_pixen(view=low top-down / selective outline / low detail / no_background) —
  [§2] 규약 그대로 **half-res 네이티브**로 뽑아 `tools/facade_halfres_x2.py`(×2 nearest)로 굳힌다.
  `place_facade.py`(÷2 청키화)는 **금지**(기와·판자를 뭉갠다 — §2 자구).
  PROMPT(늘봄방): a front elevation of a wide korean timber and glass greenhouse building facing the
    camera, symmetrical front wall of many small pale green glass panes held in a dark weathered wood
    lattice frame, a gable triangular pitched roof of dark clay tiles with the flat roof top slab
    receding visibly behind the ridge, one wide double door of two panels dead centre in the front
    wall, a low stone foundation course, front-facing facade, facing camera, NOT isometric, NOT
    angled, symmetrical front elevation, [§1.1 광원 세트], muted somber palette   (seed 103001)
  PROMPT(시련장): a front elevation of a wide grim stone gatehouse hall **that fills the entire image
    from the far left edge to the far right edge**, symmetrical front wall of dark violet grey hewn
    stone blocks spanning the full width, a broad gable triangular pitched roof of black tiles whose
    eaves reach both image edges, the flat roof top slab receding visibly behind the ridge, one wide
    double door of two dark iron banded panels dead centre in the front wall, two small barred
    windows flanking the door, a low stone step course along the whole base, carved stern trial hall,
    front-facing facade, facing camera, NOT isometric, NOT angled, symmetrical front elevation,
    no surrounding rocks, no ground, [§1.1 광원 세트], muted somber palette   (seed 103012)
★★ ⚠️ **1차(seed 103002)는 폭이 156이라 폐기했다.** 건물을 바위에 박아 넣은 실루엣으로 나와
   footprint 폭(6칸=192)보다 36px 좁았고, 그 차이만큼 **`_build_facade`가 세운 WALL 박스가
   좌우로 노출돼 건물이 청회색 판때기 위에 얹힌 것처럼 보였다**(1차 덤프 실측). 같은 줄에 선
   대장간·길드가 **정확히 192×160**인 것이 기준이다 — 갱도 건물은 footprint 폭을 꽉 채워야 한다.
   ⇒ 교체판도 **폭 ≥ 188(≒192)** 을 지킬 것. 프롬프트의 "fills the entire image from the far left
   edge to the far right edge" + "no surrounding rocks, no ground"가 그 강제어다.
★★ **문은 2칸 폭 · 정중앙**([ADR-0046]): 늘봄방 8칸폭 → 문 x67·68 / 시련장 6칸폭 → 문 x46·47.
   둘 다 짝수폭이라 2칸 문이 중앙 seam을 straddle한다 — 아트 문도 정확히 가운데여야 한다.
★★ **지붕 윗면 슬랩이 노출돼야 한다**([§2] 필수 검증 — 삼각 실루엣만 있으면 리젝). 둘 다 통과.
★ ⚠️ 늘봄방 rect를 `_HOME_BUILDING_RECTS`에 **넣지 않았다**: 그 배열은 조건 없는 const라 등록하는
  순간 짓기 전에도 x64..71에 잔디억제 맨흙 패드가 깔린다(빈 들에 건물 자국이 미리 생긴다).
  발치 패드를 잃는 대신 그 회귀를 산다 — HOME은 ground16이라 풀 백드롭도 어차피 건너뛴다.
★ 시련장 art 폭 188은 footprint 192에 4px 모자란다(양옆 2px) — 대장간·길드의 192 정합 안이다.
```

### 24.10 이 패스가 바꾼 렌더 (아트 생성물 아님 — 코드)

```
① `_prop_tex` 드롭인 분기 **신규 7곳**: 결정기 · 팬닝 스폿 · 스프링클러(티어별) · 레어크로우
   (id별) · 화분 · 시련 게시판 · 시련패 매대 · 반딧넋. 전부 "있으면 쓰고 없으면 그레이박스"라
   **그레이박스 코드를 지우지 않는다**(§23.5 ①과 같은 규약 — 폴백이 사라지면 텍스처 로드 실패가
   빈 화면이 된다).
② main.S10_ICONS 신설(15키) + `_merge_t10_icons` 2줄 + `_item_icon` 2줄 — 핫바·인벤·매대·토스트
   네 자리가 같은 한 경로를 쓰므로 여기 한 번이면 넷이 동시에 낫는다(§22.2와 같은 결).
③ ★**회귀 봉합 1건**: `_draw_sapsari`의 물그릇 분기가 텍스처를 그린 뒤 **즉시 return**해서,
   아트를 넣는 순간 "오늘 물을 채웠나" 표식이 함께 사라지고 있었다(아트 도입이 상태 판독을
   지우는 회귀). 물 띠를 두 분기 **뒤**로 옮겨 한 번만 그리게 고쳤다 — "상태를 아트에 굽지
   않는다"는 규율은 **"코드가 계속 그린다"까지가 한 짝**이라는 것이 이 봉합의 교훈이다.
   ⚠️ 앞으로 `_prop_tex` 훅을 새로 깔 때 **early return 뒤에 상태 드로우가 남아 있지 않은지**
   반드시 확인할 것(같은 형태의 잠복이 다른 프롭에도 생길 수 있다).
④ `_draw_mount` 단일 텍스처 → 4행 시트 행 선택(§24.9).
⑤ FACADE_GREENHOUSE·FACADE_TRIAL preload 2줄 + `_draw_facade_{greenhouse,trial}` 2함수 + 호출 2줄.
⑥ 신규 글루 `tools/make_s10_t9_art.py`.
★ **판정·시드·원장 로직 0줄** — 이 패스는 드로우 경로와 아이콘 테이블만 만졌다. 특히
  `quest_board.gd`는 한 바이트도 안 건드렸고(T8 불침범 계약), 전역 RNG 소비도 안 바뀌었다
  (골든 지문 보호 — 회귀가 확인한다).
```

### 24.11 이 패스가 **안 만든** 것 (이월 — 사유를 남긴다)

```
① **마구간 외관** — 아트 문제가 아니라 **무대가 없다**. `carpenter.gd`의 마구간은 완공하면
   휘파람을 주는 원장 항목이고, 맵에 footprint(EXT rect)가 한 칸도 없다. 외관을 세우려면 WALL
   박스·문·진입로·통행 집합을 새로 깔아야 하는데 그건 아트 패스의 권한 밖이다(레이아웃 변경 =
   SOLID·pathing 회귀 면). **T10 또는 후속 폴리시에서 rect를 먼저 정하고 그 다음이 아트다.**
② **늘봄방 실내 유리 룩** — 현재 갈무리방 타일(돌 판석/돌켜)을 빌려 쓴다(T5의 명시 선택).
   유리 온실 실내를 만들려면 **새 타일 id**를 열어야 하고(바닥·벽 2종 + SOLID 등록 + 타일셋
   빌드), 그건 tileset-ruleset 트랙이지 프롭 교체가 아니다. 외관만 이번에 세웠다.
③ **경지 유물 5종 아이콘** — **필요 없다**(생성 0이 결론). `mastery.gd`의 유물 보상은
   `reward_id`가 전부 **기존 아이템**(fert_deluxe·hardwood·bait_pledge·geode_eophwa·myeongbuhwan)
   이라 아이콘이 이미 다 있다. 유물 자체는 인벤에 들어가는 물건이 아니라 **수령 이벤트의 이름**
   이고(ADR-0019 % 금지를 스키마로 못 박은 그 구조), 숙련 탭은 이름·설명 텍스트만 띄운다.
   T9 로스터의 "유물 아이콘 5종"은 코드 감사 결과 **실체가 없는 항목**이었다.
④ **우편함** — 로스터에 "이월"로 적혀 있었으나 **이미 아트가 있다**(§22.1, S9-T9에서 생성·배선
   완료). 재생성하지 않았다.
⑤ **먹갈기 north(뒷모습) 승마 합성** — 시트는 4방향 다 있지만, 북향 프레임의 말은 콘텐츠 폭이
   14px(정면에서 본 엉덩이)라 **플레이어 스프라이트(≈16px)에 완전히 가려진다**(T9 덤프 실측 —
   down/right/left 셋은 정상). 근본 해법은 말·기수를 **한 장에 함께 구운 승마 시트**이고, 그건
   플레이어 의상까지 아트에 굽는 결정이라 이 패스의 권한 밖이다. 지금은 북향으로 달릴 때만
   말이 안 보인다(속도 버프·이동은 정상).
```

### 24.12 육안 판정면 (덤프 하네스)

```
`game/playtest/s10_art_dump.gd` — 비-headless 화면 grab 15장(s6_art_dump·s9b_chorus_dump 결).
  실행: cd game && godot --path . --script res://playtest/s10_art_dump.gd  → /tmp/s10art_*.png
  ① home_farm(레어크로우 8기 한 줄 + 스프링클러 3티어 급수 범위) ② home_yard(삽사리·물그릇·우편함)
  ③ greenhouse_ext ④ home_indoor(화분 3상태 + 동행 혼) ⑤ museum_room(열람대·안치대 + 눈금·등롱)
  ⑥ riverside(팬닝 스폿 2 + 결정기) ⑦ peddler ⑧ trial_ext ⑨ trial_room(게시판 쪽지·매대 잔고 패)
  ⑩ trial_shop(화폐 아이콘) ⑪ inv_icons ⑫~⑮ mount 4방향.
★ 하네스가 판정면을 세우며 배운 것 넷(교체판 검수 때도 그대로 필요하다):
  ㉠ 삽사리는 **7일차 이후**라야 입양된다(`Pet.ADOPT_MIN_DAY`) — 1일차로 부르면 마당이 빈다.
  ㉡ 시련장 실내는 **반딧넋 30(게이트)** 을 넘겨야 건물 카탈로그에 등재된다 — 안 그러면 실내
     카메라가 갱도 암반을 비춘다(문이 없는 방에는 카메라도 못 들어간다).
  ㉢ 팬닝 스폿은 day-해시라 **"그날 0개"가 정상**이다(25%) — 판정면은 원장에 직접 세운다.
  ㉣ 보부상 좌판은 맵 최남단이라 카메라가 물려 **핫바 뒤로 내려간다** — 북쪽으로 물러서서 잡는다.

★ 기계 판정(색박스 0)은 `game/playtest/s10_art_test.gd`가 든다 — 63단언. "그림이 예쁜가"가 아니라
  **"폴백에 도달하지 않는가"**를 잰다: 파일 하나가 빠지면 게임은 조용히 그레이박스로 굴러가고
  (폴백이 그러라고 있다) 그 침묵을 잡을 사람이 없다. 분모는 전부 레지스트리 파생이다
  (S10_ICONS 크기 · ItemCatalog.RARECROWS · CharSprite.DIRS — 하드코딩 15/8/4 금지).
```
