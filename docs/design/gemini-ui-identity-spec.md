# Gemini 정체성 UI 스펙카드 — 탭 아이콘 · 시계 위젯 · 타이틀 화면

> **상태:** 스펙 확정(2026-07-05, owner grill 2회 — 타이틀 형식·탭 배선 + **§7 열린 결정 5개 전부 잠금**: 게임명 `Dear My Naraka`·로고·탭툴팁·시계큐·타이틀 4직원·세이브 UX). owner Gemini 수동 생성 대기([ADR-0025] 게이트).
> **★ 게임명 확정:** 이 게임의 정식 명칭은 **Dear My Naraka**(옛 가제 "나라카 밸리" 폐기 — [CONTEXT.md](../../CONTEXT.md) 갱신). 아래 타이틀·로고는 이 이름을 쓴다.
> **근거:** [ADR-0048](../adr/0048-homestead-demo-completion-pass-ui-screens-interiors.md) §5(UI/화면 maker) + **개정 §2 C-혼합**(구조적=claude / **정체성=gemini 스펙카드+큐**, 2026-07-05 grill — [homestead-art-cleanup-pass-grill] 메모리)·[ADR-0025](../adr/0025-asset-spec-card-gate.md)(생성 전 스펙카드 게이트)·[ADR-0047](../adr/0047-gemini-full-asset-regen-supersede-adr0001-scope.md)(Gemini 1차 생성기)·[asset-ruleset.md](./asset-ruleset.md)(NW광원·2px청크·팔레트)·[master-palette.md](./master-palette.md)(hex).
> **워크플로우:** owner가 각 프롬프트를 Gemini에 붙여 생성 → 로컬 raw PNG → 변환 글루 → `game/assets/ui/`. 규격·앵커를 여기서 박제해 **owner 결과로 코드 무수정 드롭인**([ADR-0025]).
>
> **범위 = "정체성 UI" 큐 3항목.** 아트정리 패스([homestead-art-cleanup-pass-grill])에서 claude 구동분(도구 아이콘·엽전·구조적 프레임)은 완료됐고, **첫인상·브랜드 정체성**이 강한 3항목만 gemini 큐로 남았다:
> 1. **탭 아이콘 4**(§1) — 인벤/관계/숙련/옵션(현재 텍스트 라벨).
> 2. **시계 위젯 아이콘 요소**(§2) — 절기·시간대 심볼(위젯 자체는 have, 아이콘 액센트만).
> 3. **타이틀/시작 화면**(§3) — 현재 **아예 없음**(게임이 월드에서 바로 시작 — `main.gd:1423`).
>
> **자매 문서:** [gemini-demo-sprites-spec.md](./gemini-demo-sprites-spec.md)(가축·작물·home_deco·건물 = 게임플레이 스프라이트)·[gemini-regen-batch.md](./gemini-regen-batch.md)(기존 96개 재생성 — 캐릭터 5종·하트/나비 UI 아이콘 포함)·[required-assets-roster.md](./required-assets-roster.md) §5·§6(디프 소스). **home_deco 6종·캐릭터 5종은 이미 위 자매 문서에 스펙카드가 있어 여기서 재작성하지 않는다**(중복 금지 — gemini-demo-sprites §4 / gemini-regen-batch §2 참조).

---

## 0. 공통 (전 프롬프트 공유)

### 0.1 UI STYLE 토큰 — 태운 한지 정체성 (gemini-regen-batch §7 계승·확장)
전 UI는 **대화창 「태운 한지」**([dialog-ui-hanji-redesign])와 한 결이다. 아이콘/타이틀 모두 아래 톤을 공유한다.
```
crisp pixel-art UI in the burned-hanji (aged Korean mulberry paper) style of a cozy underworld/afterlife farm game, warm aged-paper cream base with scorched dark-brown edges, sumi-ink brush accents, chunky 2px blocks, clean readable silhouettes, single dark warm-brown outline (#401818), 1px highlight on top-left (NW light), crisp dark shadow to bottom-right (SE), 2-3 value steps max per material, no anti-aliasing, no smooth gradients. warm limited palette slightly desaturated for an underworld mood.
```

### 0.2 팔레트 hex (프롬프트 삽입 + 생성 후 `quantize_to_palette.py` 스냅)

| 램프 | hex | 용처 |
|---|---|---|
| 태운 한지 크림 | `#e8dcc0` ~ `#f0e6cf`(밝은 종이) / `#c9b998`(중간) | 아이콘 종이 바탕·타이틀 지면 |
| 스코치 갈색 외곽선 | `#401818`(단일 외곽선) / `#5b3a2d`(그을음) | 전 객체 외곽선·번짐 |
| 먹빛 sumi-ink | `#2a2018` ~ `#1a1410` | 붓 획·글리프 |
| 여우불/영혼빛 | `#2068e8 → #60d8f0` | 냉 액센트(정체성 냉색) |
| 금박 GOLD | `#d8a838` ~ `#f0c860` | 표제·강조(HanjiUi.GOLD 정합) |
| 피안화 붉은빛 | `#8a2a2a` ~ `#c0403a` | 관계·따뜻한 액센트 |

> **정체성 색 규약:** 냉 액센트=여우불 `#60d8f0`(미호·혼력·밤), 온 액센트=피안화 붉은빛(관계·죽음), 표제=금박. 아이콘마다 **의미색 1개만** 얹어 한지 위에서 구분되게(과채색 금지).

### 0.3 진행 규칙
- **[ADR-0025] 게이트:** 아래 프롬프트가 곧 승인 대상 스펙. owner 승인 전 즉흥 생성 금지. §7의 ❓ 항목은 승인 시 함께 확정.
- **[§12 실배율 검증](./asset-ruleset.md):** 각 변환 후 인게임 배율(640×360 내부해상도 ×UI 1.5)에서 육안 확인(`hud_dump`는 GPU 폰트/스킨 필요 — `--headless` 없이) 후 다음.
- **드롭인 원칙:** 파일명·크기를 여기 고정. Gemini 결과를 경로에 넣으면 배선 코드가 무수정 렌더(없으면 현재 텍스트/색 폴백 유지).

---

## 1. 탭 아이콘 4 — 통합 메뉴 탭

> **owner 결정(2026-07-05):** **아이콘만 배선**(라벨 제거·정사각 탭). 현재 `inv_frame.gd` `_draw_menu_top`이 4탭을 `tab_w=68 × 28` 직사각 + 한글 라벨(`"인벤토리"/"관계"/"숙련"/"옵션"`)로 그린다. 아이콘 도입 시 **정사각 탭으로 축소**(라벨 draw_string 제거).

### 1.1 규격

| key | 탭 | status | 크기 | 경로 | 의미색 | 심볼 |
|---|---|---|---|---|---|---|
| `tab_icon_inventory` | 인벤토리(TAB_INV) | ❌ missing | **24×24** | `assets/ui/` | 갈색 목재 | 가방/봇짐 |
| `tab_icon_social` | 관계(TAB_REL) | ❌ missing | **24×24** | `assets/ui/` | 피안화 붉은빛 | 하트/인연 |
| `tab_icon_skill` | 숙련(TAB_SKILL) | ❌ missing | **24×24** | `assets/ui/` | 금박 | 별/새싹 숙련 |
| `tab_icon_options` | 옵션(TAB_OPTIONS) | ❌ missing | **24×24** | `assets/ui/` | 먹빛 | 톱니/붓 |

- **동일 프레임 규약:** 4장 모두 **같은 24×24 캔버스·같은 여백·같은 외곽선 두께**로 실루엣 무게를 맞춘다(한 탭 바에 나란히 서므로 — 크기 들쭉 금지). 각 아이콘은 투명 배경 중앙 정렬, self-shadow 생략(작은 아이콘).
- **on/off 1장:** 상태별 2장 만들지 않는다 — 코드가 활성 탭에 밝은 한지 plate 배경 + 비활성은 어둡게 modulate(현행 `_draw_menu_top`의 on/off 색 로직 계승). 아이콘 자체는 1장.

### 1.2 배선 계약 (코드 변경분 — 별도 세션 or 이 큐 소진 시)
`inv_frame.gd::_draw_menu_top`:
- `labels`(한글 4) draw_string **제거** → `TAB_ICONS` 레지스트리(main 주입, `crop_icons`/`TOOL_ICONS`와 동형 dict)에서 텍스처 draw.
- `tab_w := 68.0` → **정사각 `34.0`**(24 아이콘 + 좌우 5px 여백). 탭 rect `Rect2(x + i*(34+GAP), y, 34, 28)`.
- 활성 탭 = 밝은 한지 plate(`HANJI_PLATE` 9-slice) 배경 + 아이콘 풀컬러 / 비활성 = 어두운 rect + 아이콘 `modulate(0.6)`.
- 폴백: `TAB_ICONS`가 비면 현행 한글 라벨 유지(무텍스처 안전). → **아트 없이도 안 깨짐**, 파일 넣으면 아이콘화.
- 툴팁: 스타듀식 호버 시 `hud_tooltip`에 탭 한글명 표시(아이콘만이라 첫 사용자 학습 보조 — **확정 §7-b: 넣음**). `_tab_rects` 히트 rect에 마우스 호버 감지 → `hud_tooltip`에 "인벤토리/관계/숙련/옵션" 전달.

### 1.3 프롬프트
**공통 접두 = [UI STYLE](§0.1) + `a single crisp 24x24 pixel-art UI tab icon, clean bold readable silhouette at tiny size, transparent background, centered, single dark outline #401818.`**

- **`tab_icon_inventory`** — `[공통] a small woven traveler's satchel / cloth bindle bag (봇짐) with a folded flap and a tie cord, warm honey-brown leather-and-cloth, a hint of aged straw texture. reads instantly as "bag / inventory".`
- **`tab_icon_social`** — `[공통] a single warm rose-red heart (관계/인연) with a faint foxfire-blue (#60d8f0) glint at its center, echoing the relationship hearts, warm peony-red #c0403a fill, dark outline. reads as "bonds / relationships".`
- **`tab_icon_skill`** — `[공통] a four-point sparkle star (숙련) over a tiny green sprout, gold-leaf star #f0c860 with a small warm-moss sprout at its base, suggesting mastery growing from practice. reads as "skill / proficiency".`
- **`tab_icon_options`** — `[공통] a simple gear/cog (톱니) rendered as a sumi-ink brush stamp on paper, dark ink #2a2018 with a warm-brown edge, chunky teeth, plain and utilitarian. reads as "settings / options".`

> ★ 4장을 한 시트로 생성하지 말 것(정체성·크기 흔들림 — gemini-regen-batch §2.2 교훈). 하나씩 생성 → 개별 후처리.

---

## 2. 시계 위젯 아이콘 요소 — 우상단 클러스터 액센트

> **코드 상태:** `clock_hud.gd`는 이미 **동적 태운 한지 플레이트**로 완성(절기·일차·시각·때·골드·마일스톤을 우측 정렬 텍스트로). 골드는 엽전 아이콘화 완료(PR#213). 남은 **정체성 아이콘화 = 절기·시간대 심볼**을 텍스트 옆에 얹는 것(위젯 재설계 아님).
> **★ 확정 §7-c: 이번 큐 포함**(owner 2026-07-05 — 정체성 완성도 우선). 절기4·시간대4 = 8장을 탭·타이틀과 함께 생성. 단 생성 순서는 탭·타이틀보다 뒤(가장 작은 액센트).

### 2.1 규격 — 절기 심볼 4 + 시간대 심볼 4

| 세트 | key | 크기 | 값(코드 정합) |
|---|---|---|---|
| 절기(계절) | `season_icon_pianhwa`(피안절·봄) · `season_icon_yuhwa`(유화절·여름) · `season_icon_mangyeon`(망연절·가을) · `season_icon_seongya`(성야절·겨울) | **16×16** | `clock.gd:32 SEASON_NAMES = ["피안절","유화절","망연절","성야절"]` (index 0..3) |
| 시간대 | `time_icon_morning`(아침) · `time_icon_day`(낮) · `time_icon_evening`(저녁) · `time_icon_night`(밤) | **16×16** | phase 문자열 4(아침·낮·저녁·밤) |

- 모두 16×16 투명·중앙 정렬·의미색 1개. 절기=식물/자연 심볼(피안절=붉은 상피안화 봉오리, 유화절=혼령초 새싹, 망연절=포도/낙엽, 성야절=서리/영혼호박), 시간대=하늘(아침=여명, 낮=해, 저녁=노을, 밤=여우불 달).
- **배선 계약:** `clock_hud.gd::_draw`의 date 줄(`_draw_right(_date …)`) 좌측에 `season_icon` 16px, time 줄 좌측에 `time_icon` 16px를 draw(플레이트 폭 산출 `wmax`에 +16 반영). main이 `clock.season_index()`·phase로 인덱싱해 `ClockHud`에 텍스처 배열 주입. 폴백=아이콘 없이 현행 텍스트(무텍스처 안전).

### 2.2 프롬프트 (§0.1 STYLE + `a single crisp 16x16 pixel-art HUD icon, tiny readable silhouette, transparent bg, centered, single dark outline #401818.`)
**절기 4**
- `season_icon_pianhwa` — `[공통] a single deep-crimson red spider lily (higanbana) bud/bloom (피안절/spring), muted blood-red #c0403a spidery petals, ominous funeral flower.`
- `season_icon_yuhwa` — `[공통] a glowing spirit-herb sprout (유화절/summer), pale teal-green blades with a faint soul-blue #60d8f0 glow, luminous.`
- `season_icon_mangyeon` — `[공통] a small cluster of dark netherworld grapes with a curling vine leaf (망연절/autumn), muted plum #3a1a4a, harvest tone.`
- `season_icon_seongya` — `[공통] a frost-rimed soul pumpkin or a pale frost crystal (성야절/winter), cool grey-white frost with a faint spirit-blue #60d8f0 inner glow, wintry afterlife.`

**시간대 4**
- `time_icon_morning` — `[공통] a soft dawn sun cresting a horizon line (아침), pale warm amber-rose glow, gentle.`
- `time_icon_day` — `[공통] a bright warm midday sun (낮), full amber-gold disk with short rays.`
- `time_icon_evening` — `[공통] a low dusk sun sinking into a warm sunset band (저녁), deep amber-orange, long horizon.`
- `time_icon_night` — `[공통] a slim crescent moon with a small foxfire-blue (#60d8f0) will-o-wisp beside it (밤), deep ink night, cool glow.`

---

## 3. 타이틀 / 시작 화면 — 첫인상 (신규 화면)

> **owner 결정(2026-07-05, [Dear_My_Naraka_Cozy_Title_Spec] 기획서 채택):** 풀 **패럴랙스 씬** — **"스산한 외곽(붉은 달·지옥문) + 따뜻한 중심(카페·농장·4직원)"의 뚜렷한 대비**로 코지를 극대화. 앞선 "카페 야경+전경 4직원"을 owner 제공 Cozy Ver.로 정련. **다크판타지 HUD·전사 캐릭터(대검)·핏빛 톤·RPG 레벨은 반려**(ADR-0002 코지·ADR-0005 무퀘스트 정합). **톤 = 타이틀만 서정·미스터리, 게임 안은 코지(의도된 대비 — owner 확정).**
> **메뉴 5개:** Game Start · Load Game(멀티 3슬롯 신규) · Settings(에센셜) · Credits · Quit.
> **⚠️ 정합 규약:** 4직원 = 초상화 28장 참조 앵커 · **무기 없음**(전사 이미지 금지) · **여우불 = 파란 `#60d8f0`**(노란빛은 카페 등불/모닥불 담당, 혼동 금지) · 붉은 달 = **파스텔 부드러운 붉은빛**(날카롭지 않게) · 지옥문 = 인디고/딥퍼플로 가라앉힌 신비 실루엣(위협 아님). 4인 = 옥자(마녀모자·안경·버건디) / 미호(여우귀·꼬리1·파란여우불·안경無) / 멜(청록 강시복·검은단발) / 바나(고딕롤리타·금발+검은앞머리·송곳니).
> **코드 상태:** 타이틀 화면 **없음** — `main.gd:1423 saver.has_save()` 분기로 월드에 바로 진입. 타이틀 = **신규 씬 신설**(배선 세션 S1-11~17, [ADR-0048] §6). 이 스펙은 ①아트 규격 ②배선 계약을 박제. **★멀티 슬롯은 `save.gd` 단일→멀티 재설계가 딸린 중간 규모 코드 작업(아트 아님).**

### 3.1 아트 규격 (패럴랙스 씬 + 로고)

| key | 요소 | 크기 | 경로 | 비고 |
|---|---|---|---|---|
| `title_bg` | 배경+중경 통합 씬 | **1280×720**(16:9·2×) | `assets/ui/` | 붉은달·지옥문(원경) + 카페·농장·4직원(중경). **청크 캐논 예외**(대형 씬 선명도, [ADR-0047] §4). 코드 cover |
| `title_logo` | 로고 | **~360×140**(투명) | `assets/ui/` | 분리 레이어·상단 중앙 |

- **전경 파티클 = 코드 생성(아트 불요):** 찻잎(tea leaves) + **파란 여우불 `#60d8f0`** + 따뜻한 노란 불티, 바람 타고 대각선 흩날림·일부 카메라 근접(픽셀 아웃포커싱). 도트 파티클.
- **패럴랙스(선택):** MVP = `title_bg` 통합 1장 + 코드 파티클. 배선 세션이 깊이감을 원하면 `title_bg`를 **far**(붉은달·지옥문·하늘) / **mid**(카페·농장·4직원) 2장으로 분리 생성해 시차 스크롤(옵션 — 각 1280×720).
- **4직원 idle 애니(후속):** MVP = **정적 4직원**. idle 루프(옥자 찻잔김·미호 꼬리살랑·멜 졸다깨기·바나 망토 펄럭·머리칼 바람)는 후속 애니 트랙(캐릭터 스프라이트와 얽힘 — 정적 먼저).
- **버튼·프레임 = 코드 스킨**(`inv_frame` 한지 plate 9-slice 재사용). Gemini가 그릴 건 **`title_bg` + `title_logo` 2장뿐.** 로고(상단 중앙)·메뉴(중앙 하단 or 좌/우 한쪽) 안전영역 디테일 과밀 금지.

### 3.2 배경+중경 씬 프롬프트 (`title_bg`)
> **청크 캐논 예외:** 대형 씬 일러스트라 2px 강제 청크화하면 뭉갠다 — `enforce_chunk.py` **미적용**. high detail·crisp로 뽑아 다운스케일 최소.
```
detailed pixel-art title-screen illustration for a cozy underworld/afterlife farming & cafe game titled "Dear My Naraka" (Stardew Valley / Sun Haven title-art style, warm and cozy). A PARALLAX SCENE with a clear contrast between a bleak outer background and a warm cozy center. BACKGROUND (far): a deep starry night sky over a desolate afterlife valley, a large soft PASTEL red moon glowing gently (not harsh), and the distant silhouette of a great hell-gate sunk into soft indigo / deep-purple tones — mysterious and serene, NOT threatening, faint emissive pixels glimmering through the gate. MIDGROUND (the warm heart): a small cozy timber cafe-and-farmstead with warm amber/orange light spilling from its windows and a lantern, white smoke puffing from the chimney, a little farm plot beside it; in the front yard the FOUR cafe family gathered in a peaceful evening moment, stable triangular composition — Okja (witch cafe-owner: black witch hat, burgundy wavy hair, round glasses) sitting on a small chair cupping a steaming teacup, smiling warmly; Miho (white fox ears, ONE fox tail, a small BLUE foxfire flame #60d8f0, no glasses) sitting by the field gathering cute crops into a basket, tail wagging; Mel (teal jiangshi robe and cap with a yellow talisman, black bob) dozing by a small campfire with arms stretched out; Bana (purple-black gothic-lolita dress, blonde hair with a black front-bang streak, small fangs) leaning relaxed by the cafe door with a broom, watching the others fondly. Warm CENTER light from the cafe windows and campfire wraps the cast; shadows in cozy INDIGO / deep-purple (NOT black). chibi ~2.5-3 heads tall, match their established portrait designs, NO weapons. warm honey-amber and cream palette, soft pastel-red moon, cool indigo accents, one blue foxfire accent by Miho. flat 2D pixel art, painterly pixel shading. Leave the TOP-CENTER calmer/darker for a logo and keep a calmer band (center-bottom or one side) for menu text. 16:9 aspect, high detail crisp readable pixels.
```
> 정합: 생성 시 옥자·미호·멜·바나 **초상화 참조 첨부**. idle 포즈(Cozy 기획서 §2): 옥자=찻잔 감싸쥐고 미소 / 미호=밭가 작물 바구니·꼬리 살랑 / 멜=모닥불가 졸다 부적 만지작 / 바나=문가 빗자루·동료 바라봄. 얼굴 뭉개지면 개별 생성 후 합성(Aseprite) 폴백. **여우불=파랑, 무기 없음.**

### 3.3 로고 프롬프트 (`title_logo`)
> **owner 결정(§7-a): 영문 주 "Dear My Naraka" + 한글 독음 "디어 마이 나라카" 보조 · 자형=Gemini 직접 생성 + 사후 Aseprite 미세조정.** 게임명이 영문이라 자형 리스크가 낮아(한글 조판 부담 소멸) Gemini 직생으로 전환. 붓글씨(sumi-ink) + 여우불 액센트 = 게임 정체성.
```
a pixel-art game LOGO wordmark on a transparent background, the main title "Dear My Naraka" as large bold sumi-ink brush calligraphy strokes (warm-dark-brown #401818 to ink-black, thick confident brush lettering), with a small foxfire-blue (#60d8f0) will-o-wisp flame accent nestled by the letters, and a smaller Korean phonetic subtitle "디어 마이 나라카" beneath in a clean chunky pixel typeface. warm aged-hanji-paper feel, a faint scorched-edge glow behind the strokes, crisp readable pixels, single dark outline, centered, transparent bg. cozy afterlife farm game branding.
```
> ⚠️ 영문 자형은 Gemini가 잘 뽑지만 **한글 독음("디어 마이 나라카") 자형은 여전히 틀릴 수 있다** — 독음 줄만 사후 Aseprite/폰트로 교정([ADR-0001] 허용 글루). 영문 주 타이틀은 Gemini 산출을 크게 손대지 않아도 됨. 최종 커닝/스코치 액센트는 Aseprite 미세조정.

### 3.4 배선 계약 (신규 씬 — 배선 세션 S1-11~17)
- 신규 `title_screen.gd`(Control, CanvasLayer 최상위) — 부팅 시 `main` 위 오버레이(또는 별도 씬 → main 진입).
- `title_bg` cover + `title_logo` 상단 중앙 + **코드 파티클**(찻잎·파란여우불·노란불티) + **메뉴 5개**(한지 plate 세로 정렬, 중앙 하단 or 좌/우 한쪽·선택 항목 노란빛 강조 + 찻잔/새싹 포인터 픽셀 아이콘).
- **진입 시퀀스(Cozy 기획서 §3):** 0~1.5s 페이드인 → 밤하늘·붉은달·지옥문 + **카페 창·가로등 "톡톡" 점등** / 1.5~2.5s 4직원 선명(idle 시작 = 후속) / 2.5s~ 파티클 감돌기 + 메뉴 페이드인. **BGM = 로파이**(어쿠스틱 기타/칼림바 — `audio.gd:28` "타이틀 없음" 주석 해소·곡 하나 타이틀 승격).
- **메뉴 라우팅:**
  - **Game Start** = 새 농장 시작. `has_save()` 있으면 **§7-e 2단 확인**("오늘까지의 진행을 지우고 새로 시작?") → 예 시 `_delete_save_and_restart`(F8 2단 무장 재사용) / 없으면 바로 신규(프롤로그 자리).
  - **Load Game [★신규 개발]** = **멀티 3슬롯**. ⚠️ `save.gd` 단일→멀티 재설계(중간 규모 코드): 슬롯별 파일(`save0/1/2.dat`)·슬롯 선택 UI. 각 슬롯 = **코지 다이어리 [N년차 M월 D일(day) / 혼력 수치]**(RPG 레벨 아님 — `clock`·`soul_energy` 파생·도트 아이콘). 빈 슬롯 = 새 시작. 세이브 없으면 슬롯 전부 빈칸.
  - **Settings [에센셜]** = **그래픽**(해상도·전체화면/창) · **오디오**(마스터·BGM·SFX 슬라이더) · **언어**(선택 UI 자리만 — **§7-f: 한국어 구동, 영어 로컬라이제이션은 후속**). 나무 표지판 톤 팝업. 기존 옵션탭(`inv_frame`) 볼륨/전체화면 로직 재사용 가능.
  - **Credits** = 개발진·감사 명단 **아래→위 스크롤**(신규 화면·텍스트 데이터). Steam 출시 필수.
  - **Quit** = **"오늘 영업을 마감하고 안식처를 떠나시겠습니까?"** [예/아니오] 도트 팝업 → `get_tree().quit()`.
- 현행 `main.gd:1422~1461`(has_save 자동복원·intro)를 타이틀 선택 뒤로 미룬다(부팅 직행 → 타이틀 대기).
- 폴백: 씬 미신설 시 현행 직행 유지(아트만 넣고 배선 안 하면 무영향).

---

## 4. 변환 파이프라인

| 스크립트 | 용도 | 대상 |
|---|---|---|
| `game/tools/process_chunky_phaseC.py` | 소형 in-place 청키화(÷2 BOX→알파임계→×2) | 탭 아이콘·절기/시간대 아이콘·로고 |
| `game/tools/quantize_to_palette.py` | 마스터 팔레트 nearest 스냅 | 전 아이콘·로고 |
| (미적용) `enforce_chunk.py` | 2px 청크 캐논 | **title_bg 제외**(대형 씬 선명도 예외) |

- **아이콘(24/16px)·로고:** `process_chunky_phaseC.py` MANIFEST에 `(key, dst, w, h, mode)` 추가 → §0.1 하드알파·2px 검증.
- **title_bg:** 청크화 없이 16:9 크롭·다운스케일 글루만(신규 후보 `tools/fit_title_bg.py` — 승인 후 작성). 다운스케일 최소로 선명도 보존.
- **공통 마무리:** 각 변환 후 `cd game && godot --headless --import` → `game/run_tests.sh` 회귀 → 인게임 육안(`hud_dump`).

---

## 5. 배선 계약 요약 (누가·무엇을 고치나)

| 항목 | 아트(gemini) | 코드 배선(별도 세션) | 폴백(아트 전) |
|---|---|---|---|
| 탭 아이콘 4 | `tab_icon_*` 24×24 | `inv_frame::_draw_menu_top` 정사각 탭+`TAB_ICONS` | 현행 한글 라벨 유지 |
| 절기/시간대 아이콘 8 | `season_icon_*`·`time_icon_*` 16×16 | `clock_hud::_draw` 텍스트 좌측 아이콘 draw | 현행 텍스트만 |
| 타이틀 화면 | `title_bg`(패럴랙스 씬)+`title_logo` | 신규 `title_screen.gd` · 메뉴 5개 · 코드 파티클 · **멀티슬롯 `save.gd` 재설계** · Credits 스크롤 · Settings 팝업 · main 진입 미룸 | 현행 월드 직행 |

> **핵심:** 세 항목 모두 **아트 없이도 게임이 안 깨진다**(라벨/텍스트/직행 폴백). 파일을 경로에 넣고 배선 세션이 계약대로 훅을 연결하면 정체성이 얹힌다.
> **★ 타이틀 배선은 규모 큼:** 다른 두 항목(탭·시계)은 아이콘 draw 한 줄이지만, 타이틀은 신규 씬 + **멀티 세이브 슬롯(save.gd 재설계)** + Credits/Settings 화면이 딸린다 — S1-11~17 화면군의 독립 슬라이스로 잡는다(아트 선행·배선 후행).

---

## 6. 추적표 (owner Gemini 생성 진행)
범례: ⬜ 미생성 · 🟡 생성됨(변환 전) · ✅ 변환·적용 완료

### 탭 아이콘 (4) — ✅ claude PixelLab 완료(PR#214, 트랙 변경)
- ✅ tab_icon_inventory ✅ tab_icon_social ✅ tab_icon_skill ✅ tab_icon_options

### 시계 위젯 아이콘 (8, §7-c 이번 큐 포함) — ✅ claude PixelLab 완료(트랙 변경 — 탭 아이콘 선례)
- 절기: ✅ season_icon_pianhwa ✅ season_icon_yuhwa ✅ season_icon_mangyeon ✅ season_icon_seongya
- 시간대: ✅ time_icon_morning ✅ time_icon_day ✅ time_icon_evening ✅ time_icon_night
- 생성=`create_map_object`(128² side 뷰·low detail·basic shading·single outline)→`tab_icon_crop.py`(16px·pad1) 변환. 배선=`clock_hud.gd`(절기·시각 줄 좌측 16px 심볼·`SEASON_ICONS`/`TIME_ICONS` preload·문자열→인덱스 매핑). 회귀 51개 통과. ★피안화는 봉오리(4px 얇음)→활짝 핀 꽃 재생성으로 실루엣 보강.

### 타이틀 (2) — ✅ 생성·배선 완료(owner Gemini 아트 + claude 배선, PR#217)
- ✅ title_bg(패럴랙스 씬·1280×720·구운 체커/"MENU TEXT" 제거) ✅ title_logo(먹 나비 붓글씨·투명·**동적 붉은 셰이더**)
- 배선=`title_screen.gd`(메뉴 5·멀티슬롯 선택 UI가 `slot_meta` 소비·확인/정보 패널·코드 파티클) + main 부팅 지연(`_begin_game` 추출·`current_scene` 게이트). ★로고 파란 여우불 대신 owner 지시로 **글자에 붉은 기운이 흐르는 셰이더**(`title_logo.gdshader`). Settings·Credits·BGM·idle애니는 stub/후속(B2).

---

## 7. 확정 결정 (owner grill 2026-07-05 — [ADR-0025] 게이트 통과)

정체성 큐 5결정(a~e) + 타이틀 Cozy Ver. 재설계(f~j, 2차 grill) 확정. 각 §에 인라인 반영.

- **a. 게임명·로고 ✅** — **게임명 = `Dear My Naraka`**(옛 가제 "나라카 밸리" 전면 폐기, CONTEXT.md 갱신). 로고 = **영문 주 "Dear My Naraka" + 한글 독음 "디어 마이 나라카"**(§3.3). 자형 = **Gemini 직접 생성**(영문이라 리스크↓) + 사후 Aseprite 미세조정(독음 줄·커닝). ※옛 권장(Aseprite 손조판)은 한글 게임명 전제였고, 영문 전환으로 변경.
- **b. 탭 툴팁 ✅** — **넣음**(§1.2). 호버 시 `hud_tooltip`에 탭 한글명. 스타듀 정합·저비용.
- **c. 시계 아이콘 ✅** — **이번 큐 포함**(§2). 절기4·시간대4 = 8장. 단 생성 순서는 탭·타이틀 뒤(가장 작은 액센트).
- **d. 타이틀 캐릭터 ✅** — **전경 4직원 단체(코지 idle)**(옥자 중앙·미호·멜·바나, §3.2). 전경 대형 유지하되 전투 태세가 아니라 **카페 마감 후 휴식하는 코지 일상**(옥자 찻잔·미호 꼬리·멜 졸기·바나 문가). **무기 없음·여우불 파랑**. 정합 완화 = 초상화 28장 참조·개별 생성 후 합성 폴백.
- **e. 세이브 UX ✅** — **[새 게임] 2단 확인 다이얼로그**(§3.4). 기존 `_delete_save_and_restart`(F8 2단 무장) 재사용.
- **f. 타이틀 화면 재설계 ✅(Cozy Ver.)** — owner 제공 [Dear_My_Naraka_Cozy_Title_Spec] 채택. **패럴랙스 씬**(스산한 외곽 붉은달·지옥문 + 따뜻한 중심 카페·농장·4직원, 대비로 코지 극대화)·**메뉴 5개**. **다크판타지 인게임 HUD(§4)·전사 캐릭터(대검)·핏빛 톤·RPG 레벨·퀘스트 매니저는 반려**(ADR-0002 코지·0005 무퀘스트). 붉은달=파스텔·지옥문=인디고 신비.
- **g. 세이브 슬롯 ✅** — **멀티 3슬롯**(§3.4). `save.gd` 단일→멀티 재설계 = **중간 규모 코드 작업**(배선 세션). 슬롯 표시 = **[N년차 M월 D일 / 혼력]** 코지 다이어리(RPG 레벨 아님).
- **h. 설정 범위 ✅** — **에센셜 셋**(그래픽·오디오·언어). 조작법 키 리바인드 = **후속 태스크**.
- **i. 언어 ✅** — **(A) 언어 선택 UI 자리만·한국어 구동.** 영어 로컬라이제이션(전 텍스트 번역)은 **후속 大작업**. 현행 "한국어 고정"에서 UI 슬롯만 선반영.
- **j. Credits ✅** — **넣음**(메뉴 5개째). 개발진·감사 명단 아래→위 스크롤. Steam 출시 필수.

### 후속(배선 세션 정련 — 아트와 무관)
- **★멀티 세이브 슬롯 = `save.gd` 재설계** — **백엔드 완료(PR#216, 워크트리 save-multislot).** 단일 → **3 슬롯**(`SaveManager`: `slot_path`·`has_save/save_game/load_game/delete_save(slot)`·`slot_meta`(코지 다이어리 헤더)·`any_save`). ★**slot 0 = 레거시 `user://save.dat`**로 매핑(하위호환·save.dat 백업하는 전 회귀 테스트 무수정 통과·기존 세이브 자동 승계), slot 1·2 = `save1/2.dat`. main에 `_active_slot`(기본 0) 배선(저장·로드·삭제·부팅 4곳)+저장 시 `meta={day,soul}` 헤더. `save_slot_test.gd` 신규(30+ 단언). **남은 = 슬롯 선택 UI**(타이틀 [Load Game]이 `slot_meta`로 [N년차 절기 D일 / 혼력] 표시·슬롯 골라 `_active_slot` 심기)=타이틀 씬 증분.
- Credits 화면(스크롤)·Settings 팝업(그래픽/오디오/언어 UI)·Quit 확인 팝업 신설.
- 세이브 확인창·Quit 문구 카피·다이얼로그 스킨(한지 plate).
- 타이틀 BGM 로파이 승격(audio.gd:28) · 4직원 idle 애니(후속) · 패럴랙스 레이어 분리(선택).
- 탭 툴팁 지연/위치 튜닝.
