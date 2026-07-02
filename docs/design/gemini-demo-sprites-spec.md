# Gemini 데모 스프라이트 스펙카드 — 안식 농원 데모 완성 (ADR-0048 F)

> **상태:** 스펙 확정(2026-07-02, owner §7 전항목 승인) — Gemini 생성 대기([ADR-0025] 게이트). 렌더 훅(E·S1-11·S1-15·S1-10)은 §7 계약을 타겟.
> **근거:** [ADR-0048](../adr/0048-homestead-demo-completion-pass-ui-screens-interiors.md) §5 **F**(게임플레이 스프라이트 = 스펙카드→owner Gemini)·[ADR-0025](../adr/0025-asset-spec-card-gate.md)(생성 전 스펙카드 게이트)·[ADR-0047](../adr/0047-gemini-full-asset-regen-supersede-adr0001-scope.md)(Gemini 1차 생성기)·[required-assets-roster.md](./required-assets-roster.md)(디프 소스)·[master-palette.md](./master-palette.md)(hex)·[asset-ruleset.md](./asset-ruleset.md)(NW광원·2px청크·피벗).
>
> **범위 = 데모 신규분만.** [gemini-regen-batch.md](./gemini-regen-batch.md)는 *기존 96개 재생성* 배치다. 이 문서는 그 배치에 **없는**, 안식 농원 데모를 시각적으로 완성하려면 새로 그려야 하는 스프라이트만 다룬다(로스터에서 maker=`gemini`·status=`missing`/`placeholder`인 항목). STYLE 토큰·팔레트·프레이밍은 gemini-regen-batch §1을 **계승**하며 아래 §0에 재기재해 프롬프트를 자체 완결로 만든다.

---

## ⚠️ 렌더 훅 계약 주의 (먼저 읽을 것)

조사 결과, 이 문서가 다루는 **다수 항목은 게임 코드에 렌더 훅·앵커·성장 로직이 아직 없다.** 따라서 이 스펙카드는 두 역할을 동시에 한다:

1. **owner Gemini 프롬프트** — 지금 아트를 뽑을 수 있다.
2. **렌더 훅의 계약(contract)** — 다른 세션이 S1-11(스프라이트 훅)·S1-15(가축 성장)·E(실내·과수 렌더) 구현 시, 여기 박제한 **파일명·크기·앵커**를 타겟으로 삼는다. 규격을 여기서 먼저 고정해야 아트와 코드가 나중에 마찰 없이 맞물린다.

| 항목 | 현재 코드 상태 | 렌더 훅 담당 |
|---|---|---|
| 가축 스프라이트 | 그레이박스 색박스(`main.gd:5090` `_draw_ranch`), 텍스처 미로드 | S1-11 |
| 가축 성장(baby/adult) | 로직 없음(`livestock.gd` 나이 필드 부재) | S1-15 |
| 가축 산물 아이콘 | `crop_icons` dict가 crop id만 채움 → 흰박스 폴백 | S1-11(dict에 산물 id 주입) |
| 작물(불사과·황천포도) | 데이터 등록됨(`crops.gd`), 스프라이트 미등록(`CROP_SPRITES` 누락→skip) | preload 추가만 |
| 과수 혼백도 | 그레이박스 도형(`main.gd:5065` `_draw_orchard`), 2상태만 구별 | E/S1-10(대형 스프라이트+Y-sort) |
| coop_ext | rect/door 상수 전무, 코드 미참조 | E(barn 패턴 복제) |
| home_deco | 색 `draw_rect`만(`main.gd:2169`), 텍스처 필드 없음 | E/S1-11(텍스처 로드 훅) |

> **함의:** 아트를 먼저 뽑아도 즉시 화면엔 안 나온다(정상). 규격을 계약으로 고정하는 게 이 문서의 1차 가치다. 작물 2종만 예외로 preload 한 줄 추가하면 바로 뜬다.

---

## 0. 공통 (전 프롬프트 공유)

### 0.1 STYLE (정적 오브젝트/타일/작물/props — gemini-regen-batch §1 계승)
```
detailed pixel art in the style of Stardew Valley and Sun Haven, chunky visible pixels (2px blocks), crisp clean pixel edges, low detail, a warm limited palette slightly desaturated for an underworld/afterlife mood, flat 2D pixel art, light source from top-left (NW), distinct directional step-shading, 1px highlight on top and left edges, crisp dark shadows to bottom-right (SE), 2-3 color values max per material, no smooth gradients, no anti-aliasing. pixel art, 16-bit RPG.
```

### 0.2 프레이밍
- **props/작물/가축/아이콘:** `a single [OBJECT], top-down 3/4 overworld view (Stardew Valley angle), centered on a transparent background, bottom-center anchored, standing upright, no baked ground shadow or cast shadow (only its own form self-shadow), self-shadow color [SHADOW].`
- **타일(deco 바닥/벽):** `a seamless tileable top-down [surface] texture, flat, edge-to-edge, no border.`
- **건물:** [gemini-building-prompt.md](./gemini-building-prompt.md) §6.0 공통 골격 계승(§3).

### 0.3 팔레트 hex (프롬프트 삽입 + 생성 후 `quantize_to_palette.py` 스냅)

| 램프 | hex |
|---|---|
| 풀 warm-moss | `#2d4720 #446630 #597f3f #739952 #8fb267` |
| 흙길 warm | `#513928 #724f3b #8e634d #a87d64 #bc987c` |
| 밭흙 warm | `#332016 #472d22 #5b3a2d #725242 #896d5a` |
| 영혼빛(물·발광) | `#2068e8 → #60d8f0` |
| 외곽선(전 객체 단일) | `#401818` |
| self-shadow | 저승 muted 객체 = cool blue-violet slate / warm 목재 가구 = dark warm brown |

### 0.4 진행 규칙
- **[ADR-0025] 게이트:** 아래 프롬프트가 곧 승인 대상 스펙. owner 승인 전 즉흥 생성 금지. §7의 ❓ 항목은 승인 시 함께 확정.
- **한 카테고리 100% 후 다음**(CLAUDE.md). 난이도 낮은 순: **작물 2종(§2.1·2.2) → 가축(§1) → 산물 아이콘 → coop_ext(§3) → home_deco(§4) → 과수(§2.3, 렌더 훅 의존 최다)**.
- **[§12 실배율 검증]:** 각 변환 후 인게임 줌(640×360 ×2)에서 `home_full_dump`/`map_dump` 육안 후 다음.

---

## 1. 가축 (6) — ★최대 격차 (현재 스프라이트 0개)

> **정합:** 종·산물 id는 `animal_catalog.gd`가 진실 — 표시명≠식별자, **내부 id 보존**(세이브 안전). 노을닭=`honbaek_dak`(coop·소형), 안개소=`honbaek_so`(barn·대형). 산물 노을알=`honbaek_ran`, 안개젖=`honbaek_yu`.
> **성장 2단계**(owner 2026-07-02: 성체+새끼 둘 다). 로직은 S1-15 신규(`livestock.gd`에 나이 필드 없음). **에셋은 단계당 1장** = `<id>_baby.png` / `<id>_adult.png`.
> **방향:** 로스터 "정면+idle(4방향 불요)" — **단일 정면 idle 1장**이면 충분(작물처럼 정지 배치). 걷기·4방향 불요.

### 1.1 스프라이트 규격

| key | 나라카명 | 크기 | 경로 | 앵커 | 비고 |
|---|---|---|---|---|---|
| `honbaek_dak_baby` | 노을닭(새끼) | 32×32 | `assets/livestock/` | bottom-center | 소형·병아리 결 |
| `honbaek_dak_adult` | 노을닭(성체) | 32×32 | `assets/livestock/` | bottom-center | 소형 닭 |
| `honbaek_so_baby` | 안개소(새끼) | 48×48 | `assets/livestock/` | bottom-center | 송아지 |
| `honbaek_so_adult` | 안개소(성체) | 64×48 | `assets/livestock/` | bottom-center | 대형 소 |
| `honbaek_ran` | 노을알(아이템) | 32×32 | `assets/crops/` | 중앙 | 인벤 아이콘·단일 |
| `honbaek_yu` | 안개젖(아이템) | 32×32 | `assets/crops/` | 중앙 | 인벤 아이콘·단일 |

> **경로 확정(§7-1):** 가축 스프라이트 = 신규 **`assets/livestock/`**(의미 분리·`crop_icons` 오염 회피). 산물 아이콘은 인벤 dict 재사용 편의상 `assets/crops/` 유지.

- **baby:adult 크기비:** baby는 같은 캔버스 안에서 실루엣이 확연히 작게(성체 대비 ~0.6배 몸집·큰 머리·짧은 다리 = "새끼"로 즉시 읽히게). 캔버스 크기는 위 표 고정, 콘텐츠만 축소.
- **대형 산물 아이콘 별도 없음:** `honbaek_ran_large`/`honbaek_yu_large`는 id 접미+가격×2일 뿐(`item_catalog.gd`), base 아이콘 재사용 — 별도 파일 만들지 않는다.

### 1.2 프롬프트

**노을닭 성체 (`honbaek_dak_adult`)** — 하늘 목장 "노을" 심상, 소형 닭
```
[STYLE]
a single afterlife hen (soul chicken) standing in idle pose, plump rounded body, soft feathers washed in warm sunset colors — dusky orange, rose-pink and amber gradient from head to tail like a twilight sky, a small red comb and wattle, calm gentle eye, tiny beak, standing on two small legs.
top-down 3/4 overworld view (Stardew Valley angle), centered on a transparent background, bottom-center anchored, no baked ground/cast shadow (only self-shadow), self-shadow color cool blue-violet slate. small and cozy, readable silhouette.
```

**노을닭 새끼 (`honbaek_dak_baby`)** — 병아리
```
[STYLE]
a single tiny afterlife chick (baby soul chicken), a small fluffy round ball of down feathers in soft warm sunset tones — pale peach, rose and amber, an oversized head relative to the body, big innocent eye, a tiny beak, stubby little legs, obviously a baby (about 60% the size of the adult hen).
top-down 3/4 overworld view, centered, transparent bg, bottom-center anchored, no baked shadow (self-shadow only), self-shadow cool blue-violet slate. tiny and adorable.
```

**안개소 성체 (`honbaek_so_adult`)** — "안개" 심상, 대형 소
```
[STYLE]
a single large afterlife cow (mist ox) standing in idle pose, a broad heavy bovine body, hide in soft muted misty tones — pale grey-white and cool fog-blue with a faint spirit-blue (#60d8f0) sheen as if half-made of mist, gentle dark eyes, short curved horns, a wisp of pale fog trailing from its form, calm and docile.
top-down 3/4 overworld view (Stardew Valley angle), centered on a transparent background, bottom-center anchored, no baked ground/cast shadow (self-shadow only), self-shadow color cool blue-violet slate. large and heavy, readable silhouette.
```

**안개소 새끼 (`honbaek_so_baby`)** — 송아지
```
[STYLE]
a single small afterlife calf (baby mist ox), a compact soft-bodied calf with a large head and short spindly legs, hide in pale misty grey-white and cool fog-blue with a faint spirit-blue (#60d8f0) haze, no horns yet or tiny nubs, big soft eyes, obviously a baby (about 60% the size of the adult ox).
top-down 3/4 overworld view, centered, transparent bg, bottom-center anchored, no baked shadow (self-shadow only), self-shadow cool blue-violet slate. small and endearing.
```

**노을알 (`honbaek_ran`)** — 산물 아이콘 32×32
```
[STYLE]
a single soul-hen egg icon, a smooth oval egg shell washed with a warm sunset gradient — soft amber, rose-pink and dusky orange, a faint warm inner glow, a subtle spirit-blue (#60d8f0) glint highlight.
centered on a transparent background, no shadow, clean readable inventory icon silhouette, single dark outline #401818, chunky 2px blocks.
```

**안개젖 (`honbaek_yu`)** — 산물 아이콘 32×32
```
[STYLE]
a single bottle/pail of mist-ox milk icon, a small vessel of pale misty milk with a soft cool fog-blue tint and a faint spirit-blue (#60d8f0) sheen on the surface, a wisp of pale vapor rising.
centered on a transparent background, no shadow, clean readable inventory icon silhouette, single dark outline #401818, chunky 2px blocks.
```

---

## 2. 작물·과수 신규 (3종)

> **규약(작물):** 각 **32×32**, 투명, `assets/crops/<id>_{seed,sprout,mature}.png` **3프레임 고정**. `crops.gd`의 `stages`(2/3/4) 값은 성장 *틱 수*이지 아트 프레임 수가 아니다 — **아트는 항상 3프레임**(seed/sprout/mature), 코드가 0/1/2로 clamp. 세 프레임 동일 팔레트·NW광원·bottom-center 발치. 위로만 자람(가로 타일 경계 안). seed 밭흙색 = §0.3 밭흙 램프. mature = 밭흙 대비 밝게·외곽선 `#401818`.
>
> ⚠️ **작물 공통 framing 규칙(2026-07-03 첫 생성 사이클 교훈, 위키 `cropF`에 박제):**
> 1. **top-down 3/4 정면** — isometric·회전 다이아몬드/마름모 타일 금지(Gemini가 "top-down"을 아이소로 과해석하는 사례 발생).
> 2. **전체 흙판/지면 타일 그리지 말 것** — 작물은 게임 밭흙 타일 위에 얹힘(이중 렌더 방지). 투명 배경 위에 **식물 + 발치 작은 두둑만**.
> 3. **흙 두둑 = warm 갈색**(`#332016`~`#5b3a2d`) — 보라/마젠타/차가운 톤 금지(밭흙 타일 warm과 톤 일치). ★작물은 팔레트 자동 스냅이 없으므로(`quantize_to_palette`=타일 전용) 흙색은 **프롬프트+육안**이 유일 게이트.
> 4. **단계별 크기 차등** — seed(흙 뚫은 작은 tip) < sprout(잎 몇 장) < mature. seed가 이미 무성하면 안 됨.

### 2.1 황천포도 (`hwangcheon_podo`) — 트렐리스·재성장·다수확 (망연절/가을)
> 黃泉葡萄, 저승 넝쿨 포도. **트렐리스는 렌더가 아니라 충돌만 다르다** — 코드에 트렐리스 덩굴 전용 파일 슬롯이 **없다**. 덩굴·격자 느낌은 **mature 프레임 안에서** 표현(별도 파일 안 만듦). 여전히 32×32 SOIL 1칸.
- **seed** — `[STYLE] a single small crop plant, top-down 3/4 view, centered, transparent bg, a freshly planted grape seed on dark tilled soil #332016, a tiny pale green sprout tip breaking the dark soil. a grapevine seed.`
- **sprout** — `[STYLE] … a young grapevine seedling, a slender green vine tendril curling upward from dark soil with two or three small leaves, no fruit yet, reaching up as if toward a trellis. a climbing vine sprouting.`
- **mature** — `[STYLE] … a mature underworld grapevine on a small wooden lattice trellis, green vine leaves climbing thin wooden slats, two or three heavy clusters of deep purple-black netherworld grapes (황천 dark plum #3a1a4a to muted violet) with a faint spirit sheen, ripe and ready to pick. a trellised nether-grape vine.`

### 2.2 불사과 (`bulsagwa`) — 다절기 프레스티지 (미혹의 숲 채집 전용)
> 不死果, "죽지 않는 혼의 작물". 절기 전환 사멸을 넘어 살아남는 고대 열매. 만물상 미판매(채집). `stages`=4지만 **아트 3프레임**.
- **seed** — `[STYLE] a single small crop plant, top-down 3/4 view, centered, transparent bg, an ancient apple seed pressed into dark tilled soil #332016, a small resilient sprout tip with a faint warm ember glow, refusing to wither. a deathless seed.`
- **sprout** — `[STYLE] … a young apple sapling shoot, a small sturdy woody stem with a few deep-green leaves edged in faint ember-orange, unnaturally hardy, on dark soil. an undying seedling.`
- **mature** — `[STYLE] … a harvest-ready ancient apple plant bearing one or two glossy deep-crimson apples that glow faintly from within with a warm undying ember light (a hint of spirit-blue #60d8f0 at the core), rich dark-green leaves, an eerie immortal fruit. the fruit of no-death, ripe.`

### 2.3 혼백도 (`honbaekdo`) — 혼의 나무 과수 (피안절/봄 결실)
> 魂魄桃, 저승 복숭아. [혼의 나무] 그레이박스 정준 1종. **3×3 영속 엔티티(96×96 풋프린트)**, 밑동 앵커 1칸만 SOLID·bottom-center 접지, 수관은 위/옆 통과 가능. Y-sort pivot=앵커 중심선(배선 S1-10).
> ⚠️ **현재 orchard는 그레이박스 도형만 그리고 2상태(sapling/mature)만 구별.** **단계 수 = 3 확정(§7-3, sapling→growing→fruiting)** — `_draw_orchard`에 growing/fruiting 렌더 훅 신설(E/S1-10 담당). 열매 아이콘도 미등록.

**규격(권장):** 대형 단일 스프라이트, 캔버스 **96×128**(가로 3칸=96, 세로는 밑동 96 접지 + 수관이 위로 솟는 여유 32). bottom-center 앵커 = 밑동이 캔버스 하단 중앙, 수관이 위로.

- **sapling(묘목)** — `[STYLE] a single small peach tree sapling, top-down 3/4 overworld view, centered on a transparent bg, bottom-center anchored, a slender dark bare trunk with a few small tender leaves at the top, freshly planted, no blossoms or fruit, self-shadow cool blue-violet slate. a young spirit peach sapling.`
- **growing(성장)** — `[STYLE] a medium underworld peach tree, top-down 3/4 view, centered, transparent bg, bottom-center anchored, a fuller rounded canopy of muted blue-green and soft pink leaves on a dark trunk, a few pale pink spirit blossoms, not yet fruiting, self-shadow cool blue-violet slate. a growing spirit peach tree.`
- **fruiting(결실)** — `[STYLE] a large mature underworld peach tree, top-down 3/4 view, centered, transparent bg, bottom-center anchored, a full rounded canopy of muted blue-green leaves with soft pink spirit-blossoms, several ripe pale-pink-and-cream afterlife peaches (魂魄桃) hanging with a faint spirit-blue #60d8f0 glow, a thick dark trunk at the base, ethereal and cozy, self-shadow cool blue-violet slate. a fruiting spirit peach tree.`
- **혼백도 과일 아이콘(`honbaekdo`, 32×32)** — `[STYLE] a single spirit peach fruit icon, a plump ripe peach in pale pink and cream with a soft cleft, a faint spirit-blue (#60d8f0) glow at the core, single dark outline #401818, centered on transparent bg, no shadow, clean inventory icon. an afterlife peach.`

---

## 3. 건물 외관 — coop_ext (넋둥우리, 소형 닭장)

> **파이프라인 계승:** [gemini-building-prompt.md](./gemini-building-prompt.md) §6.0 공통 골격 + `gemini_facade_to_chunky.py`. 넋우릿간(`barn_ext`, 4×3칸·대형)과 **구분되는 소형**.
> **코드 상태:** `coop_ext` rect/door 상수 전무. barn 패턴(`main.gd`: `BARN_EXT_RECT`/`BARN_EXT_DOOR`/`_draw_facade_barn`) 복제로 신설(E 담당). 앵커 = **bottom-center**(문 트리거 정렬), target_w=footprint폭×32, 48색.

### 3.1 footprint·문 (확정, §7-4)
| 건물 | footprint | 문 폭 | target_w | 근거 |
|---|---|---|---|---|
| `barn_ext`(기존/대형) | 4×3 | 2칸 | 128 | 안개소·대형 |
| **`coop_ext`(신규/소형)** | **3×2** | **2칸(중앙 straddle)** | **96** | 노을닭·소형, barn보다 작게 |

> 문 폭 규약([ADR-0046]): 짝수폭 footprint → 2칸 문. coop = **3×2·중앙 2칸 straddle 문 확정**(barn과 문 규약 통일).

### 3.2 프롬프트 (§6.0 골격의 `[[BUILDING]]`/`[[DOOR]]`/`[[PALETTE_ACCENT]]` 치환)
- `[[BUILDING]]` = `a small cozy afterlife chicken coop, a low single-story timber hut with a gently pitched gable roof, a small round coop window, a low fenced run hint, and a little perch under the eaves; clearly smaller and humbler than a big barn`
- `[[DOOR]]` = `a modest wooden coop door (~2 tiles wide, low)`
- `[[PALETTE_ACCENT]]` = `warm honey-brown timber walls with a warm-toned roof, straw-yellow accents at the eaves, and a tiny warm sunset-orange glow at the coop window echoing the 노을닭 (sunset hen) it houses. Keep it warm and cozy, small-scale.`
- **emit(선반영, 코드 미사용):** 창 앰버 = `coop_ext_emit.png`(§6.3 파이프라인 동일 크기 통과). Phase 3+ 야간 조명 도입 시 자동 활용.

### 3.3 후처리
```
python3 game/tools/gemini_facade_to_chunky.py <src> game/assets/buildings/coop_ext.png 96 48
```
> 앵커 팁: 확정된 `barn_ext.png`를 참조로 첨부해 "same art style/grain/palette, but smaller and humbler". 육안 = `home_full_dump`/`village_dump`.

---

## 4. home_deco 가구·테마 세트 (2세트) — placeholder 교체

> **CONTEXT [집꾸미기]:** "테마 세트" 모델 — 세트 1개 = 전 카테고리를 한 결로. 2세트: **SOULFIRE(여우불·미호 파란 불꽃 #60d8f0)** / **HIGANBANA(피안화·붉은 상피안화)**. 3레이어: 바닥재(floor)·벽지(wall)·가구(furniture).
> **코드 상태(중요):** `home_deco_catalog.gd`는 색만 든다(텍스처 필드 없음). 렌더는 `main.gd:2169`가 `draw_rect`로 색만 칠함 — floor=반투명 32×32 풀타일, wall=불투명 32×32 풀타일, furniture=칸 중앙 ~22×22 박스(셀-센터 앵커·4방 rot). **텍스처 로드 훅은 E/S1-11 신설.**
> ⚠️ **로스터 6키 vs 코드 8아이템 불일치** — 코드 실제 아이템: SOULFIRE=`sf_floor`·`sf_wall`·`sf_bed`·`sf_lamp`, HIGANBANA=`hb_floor`·`hb_rug`·`hb_wall`·`hb_table`. **확정(§7-5): 세트당 3장(floor 타일·wall 타일·furniture 대표 1장)으로 시작** — 코드 8아이템은 furniture 시트를 잘라 매핑하거나 후속 확장(낱개 8장은 후속 서랍).

### 4.1 규격
| 레이어 | 크기 | 앵커 | 형식 |
|---|---|---|---|
| floor(바닥재) | 32×32 | — | seamless 타일(반복 깔림) |
| wall(벽지) | 32×32 | — | seamless 타일(벽 밴드 덮개) |
| furniture(가구) | 32×32(콘텐츠 ~22×22) | **셀-센터** | 오브젝트, 4방 rot 대응 대칭 실루엣 권장 |

### 4.2 프롬프트

**여우불 세트 — 바닥재 (`deco_soulfire_floor`)**
```
[STYLE] a seamless tileable top-down interior floor texture, warm dark wooden boards with faint cool foxfire-blue (#60d8f0) will-o-wisp glints embered into the grain, cozy afterlife foxfire theme, single dark outline #401818, chunky 2px blocks, edge-to-edge no border.
```
**여우불 세트 — 벽지 (`deco_soulfire_wall`)**
```
[STYLE] a seamless tileable top-down interior wall texture, warm timber paneling with a subtle pattern of small foxfire-blue (#60d8f0) flame wisps, top edge lit (NW), cozy foxfire theme, single dark outline #401818, chunky 2px blocks, edge-to-edge no border.
```
**여우불 세트 — 가구 (`deco_soulfire_furniture`)** *(대표 1장 또는 §7-5 확정 시 낱개: 침대 `sf_bed`·등불 `sf_lamp`)*
```
[STYLE] a single piece of cozy afterlife furniture in the foxfire theme, warm dark wood with soft cool foxfire-blue (#60d8f0) flame accents glowing gently, top-down 3/4 view, centered on transparent bg, bottom-center anchored, self-shadow dark warm brown, symmetrical readable silhouette. [FURNITURE: a low wooden bed with a foxfire-lit lantern headboard / a standing iron foxfire lamp].
```

**피안화 세트 — 바닥재 (`deco_higanbana_floor`)**
```
[STYLE] a seamless tileable top-down interior floor texture, warm dark wood or tatami with a subtle scattering of small deep-crimson red spider lily (higanbana) petals, muted funereal red against warm base, single dark outline #401818, chunky 2px blocks, edge-to-edge no border.
```
**피안화 세트 — 벽지 (`deco_higanbana_wall`)**
```
[STYLE] a seamless tileable top-down interior wall texture, warm plaster or paper with a repeating motif of slender red spider lilies (higanbana), muted blood-red blooms on dark stems, top edge lit (NW), single dark outline #401818, chunky 2px blocks, edge-to-edge no border.
```
**피안화 세트 — 가구 (`deco_higanbana_furniture`)** *(대표 1장 또는 §7-5 확정 시 낱개: 러그 `hb_rug`·탁자 `hb_table`)*
```
[STYLE] a single piece of afterlife furniture in the higanbana (red spider lily) theme, warm dark lacquered wood with deep-crimson red-lily carvings and muted red cushions, top-down 3/4 view, centered on transparent bg, bottom-center anchored, self-shadow dark warm brown, symmetrical readable silhouette. [FURNITURE: a low round tea table with a lily inlay / a woven floor rug with a red spider lily border laid completely flat].
```
> 러그(`hb_rug`)는 바닥 오버레이 — `house_rug` 규약대로 완전 평면·두께 없음·그림자 생략.

---

## 5. 변환 파이프라인 (기존 재사용)

| 스크립트 | 용도 | 대상 |
|---|---|---|
| `game/tools/process_chunky_phaseC.py` | 소형 in-place 청키화(÷2 BOX→알파임계→×2) | 가축·작물·아이콘·deco 가구 |
| `game/tools/gemini_facade_to_chunky.py` | facade raw → 청키(다운스케일→48색→×2) | coop_ext |
| `game/tools/quantize_to_palette.py` | 마스터 팔레트 nearest 스냅 | 전 객체·deco 타일 |
| `enforce_chunk.py` | 2px 청크 캐논 | 가축·작물·건물·deco |

**공통 마무리:** 각 카테고리 변환 후 `godot --headless --import` 1회 → `game/run_tests.sh` 회귀 → 인게임 육안(§0.4). 작물 2종은 `main.gd`의 `CROP_SPRITES`에 preload 한 줄 추가하면 즉시 렌더.

---

## 6. 추적표 (owner Gemini 생성 진행)
범례: ⬜ 미생성 · 🟡 생성됨(변환 전) · ✅ 변환·적용 완료

### 가축 (6)
- ⬜ honbaek_dak_baby ⬜ honbaek_dak_adult ⬜ honbaek_so_baby ⬜ honbaek_so_adult ⬜ honbaek_ran ⬜ honbaek_yu

### 작물·과수 (3종)
- ⬜ hwangcheon_podo_{seed,sprout,mature} ⬜ bulsagwa_{seed,sprout,mature} ⬜ honbaekdo_{sapling,growing,fruiting} ⬜ honbaekdo(과일 아이콘)

### 건물 (1)
- ⬜ coop_ext (+ coop_ext_emit)

### home_deco (2세트 × 3레이어, ❓낱개 시 8)
- 여우불: ⬜ deco_soulfire_floor ⬜ deco_soulfire_wall ⬜ deco_soulfire_furniture
- 피안화: ⬜ deco_higanbana_floor ⬜ deco_higanbana_wall ⬜ deco_higanbana_furniture

---

## 7. 확정 결정 (owner 승인 2026-07-02 — 전 항목 권장안 채택)

렌더 훅 세션(E·S1-11·S1-15·S1-10)은 아래 확정치를 계약으로 삼는다.

1. **가축 경로 ✅** — 스프라이트 = 신규 **`assets/livestock/`**(의미 분리·`crop_icons` 오염 회피). 산물 아이콘(`honbaek_ran`/`honbaek_yu`)은 인벤 dict 재사용 편의상 **`assets/crops/`** 유지.
2. **가축 캔버스 크기 ✅** — 닭 32×32 · 안개소 새끼 48×48 · 안개소 성체 64×48. baby:adult 콘텐츠 = 0.6배.
3. **과수 혼백도 단계 수 ✅** — **3단계**(sapling→growing→fruiting). `_draw_orchard`에 growing/fruiting 렌더 훅 신설(E/S1-10). 캔버스 96×128.
4. **coop_ext footprint ✅** — **3×2 · 중앙 2칸 문 · target_w=96**.
5. **home_deco 세트당 장수 ✅** — **세트당 3장**(floor 타일·wall 타일·furniture 대표 1장). 코드 8아이템은 furniture 시트 매핑/후속 확장.
6. **가축 방향 ✅** — **단일 정면 idle 1장**(4방향·걷기·목축 이동 애니는 후속 서랍).

> 전 항목 확정 완료 → §1~4 프롬프트를 그대로 Gemini에 투입 가능. 실제 화면 반영은 각 렌더 훅 세션(위)이 이 계약대로 배선하면 성립.
