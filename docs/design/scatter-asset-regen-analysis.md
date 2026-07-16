# 지면 스캐터 에셋 재생성 분석 — 픽셀아트 규칙·스타듀 팔레트 정합 (2026-07-16)

> owner: "잡초만이 아니라 나뭇가지·돌맹이 등 여러 변주를 빽빽하게 흩뿌리기로 했었다. 그리고 지형 타일을
> 스타듀에 맞춰 다시 뽑은 것처럼, 이 에셋들도 픽셀아트 기본 규칙 + 팔레트·규격에 맞춰 재생성해야 한다."
> deep-research(다출처 + 에셋 육안·색수 감사)로 **재생성 대상·근거·스펙**을 잠근다. P2 프로토타입([[../design/stardew-boundary-tile-analysis.md]] P2)의 후속.

---

## 0. 결론 먼저 (TL;DR)

1. **스캐터 에셋이 두 화풍으로 갈라져 있다.**
   - **Style A (크리스프·양호):** `rock`·`debris_ember_stone`·`debris_petrified_stump`·`debris_weeds`(및 v2/v3) — 또렷한 외곽선, 타이트 팔레트(22~27색), NW 음영. **이미 스타듀/프로젝트 스펙 부합.**
   - **Style B (소프트·재생성 필요):** `ground_grass1/2/3`·`ground_weed_under`·`ground_weed_dry`·`ground_flower`·`ground_pebble`·`ground_gravel`·`ground_embed`·`ground_crack`·`grass_tuft` — **뭉개진 블러·외곽선 없음·고색수(33~88색)**. 확산모델/축소본 특유. **픽셀아트 기본 규칙 위반.**
2. **원인:** Style B는 프로젝트가 이미 정의한 재생성 스펙(gemini-regen-batch §1 고정 팔레트 + 단일 외곽선 `#401818` + `quantize_to_palette.py` 스냅)을 **안 거친 pre-spec 블롭**이다. `prop-regen-roster.md` §5.6이 이미 이 세트를 재생성 대상으로 지목했으나 **미실행**.
3. **추가 격차 — 스캐터 다양성 부족.** 스타듀 초기 농장 스캐터는 **잡초(변주 여럿)+나뭇가지(twig)+돌맹이(stone)**를 빽빽이 섞는다. 그러나 현재 `_GD_TABLES[GROUND]`는 풀/잡초/꽃/잔돌만 있고 **나뭇가지·돌맹이 스캐터가 없다**(그건 개간 debris로만 존재). 밀도도 여백 위주(`GD_CLUSTER_CUT=0.60`).

**할 일:** ①Style B 9종을 스펙(팔레트·외곽선·크리스프)으로 재생성 ②스캐터 테이블에 twig·stone **소형 변주** 추가(빽빽 스캐터) ③기존 Style A 크리스프 debris를 기준 룩으로 삼아 통일.

---

## 1. 근거 — 픽셀아트 기본 규칙 (Style B가 위반하는 것)

| 규칙 | 내용 | Style B 위반 |
|---|---|---|
| **외곽선(readability)** | 1px 외곽선(검정 또는 sel-out=인접색 어두운 버전)이 배경 위에서 실루엣을 살린다. 게임 스프라이트 표준. | Style B는 **외곽선 전무** → tan 위에서 뭉개져 흐릿 |
| **AA/블러 회피** | 픽셀아트는 하드 엣지가 미학. 과한 안티에일리어싱은 작은 크기에서 "흐리고 지저분"하게 만든다. | Style B 전부 **블러 덩어리**(축소/확산 잔재) |
| **제한 팔레트** | 색은 한 줌만, 각 색이 제 몫을 해야. 색 수↓ = 결정력↑. | `ground_grass3`=88색·`ground_dirt`=87색·`grass_tuft`=53색 (Style A는 22~27) |
| **풀 = "tuft" 전략** | 풀은 개별로 못 그리니 *tuft 뭉치*로. **4색조**(하이라이트=tuft 끝, 그림자=밑동)로 입체. | Style B 풀은 4색조 tuft 구조가 아니라 다색 블러 |

**출처:** [Derek Yu — Pixel Art Tutorial](https://www.derekyu.com/makegames/pixelart.html) · [Make Games — Pixel Art Tutorial](https://makegames.tumblr.com/post/42648699708/pixel-art-tutorial) · [Pixel Art Fundamentals — Sprite-AI](https://www.sprite-ai.art/guides/pixel-art-fundamentals) · [OpenGameArt Ch.8 — A world of tiles](https://opengameart.org/content/chapter-8-a-world-of-tiles) · [Grass — Stardew Wiki](https://stardewvalleywiki.com/Grass)(잔디=4 tuft/타일) · [SDV sprite 규격 — Forums](https://forums.stardewvalley.net/threads/sprite-sizes-character-sheets-pixel-art.5597/)(16×16 기본)

## 1.2 스타듀 초기 농장 스캐터 = 다종 혼합 (레퍼런스)
owner 스크린샷(Standard Farm 전경)·와이드 샷 확대: tan 바닥에 **잡초 십자 클럼프(꽃 있는 변주 포함)·갈색 나뭇가지(X자·외가지)·회색 돌맹이(단·무리)**가 나무·덤불과 함께 빽빽. 초록만이 아니라 **갈색 twig·회색 stone이 밀도의 핵심**(색 대비로 tan을 깬다).

---

## 2. 에셋 감사 (game/assets/props, 육안 + 색수)

| 에셋 | 크기 | 불투명 색수 | 화풍 | 판정 |
|---|---|---|---|---|
| `rock.png` | 64² | 27 | A | 유지(기준 룩) |
| `debris_ember_stone`(+v2/3) | 32² | 24 | A | 유지 |
| `debris_petrified_stump`(+v2/3) | 32² | 22~24 | A | 유지 |
| `debris_weeds`(+v2/3) | 32² | 23 | A- | 유지(톤만 점검·형광 억제) |
| `grass_tuft` | 32² | **53** | B | **재생성** |
| `ground_grass1` | 16² | 33 | B | **재생성** |
| `ground_grass2` | 24×20 | **64** | B | **재생성** |
| `ground_grass3` | 26×28 | **88** | B | **재생성** |
| `ground_weed_under` | 16×18 | **47** | B | **재생성** |
| `ground_weed_dry` | 20×16 | 27 | B | **재생성** |
| `ground_flower` | 13×15 | 18(블러) | B | **재생성** |
| `ground_pebble` | 18×14 | 11(블러) | B | **재생성** |
| `ground_gravel` | 22×14 | 20(블러) | B | **재생성** |
| `ground_embed` | 14×9 | 4(스머지) | B | **재생성** |
| `ground_crack` | 24×16 | **0(불투명 없음=깨짐)** | B | **재생성/제거** |

> 크기 불균일(13×15·24×20·26×28…)도 문제 — 32-native 규격([ADR-0050]) 기준으로 정리 필요.

---

## 3. 개선안

### 🔴 A. Style B 9종 재생성 (기존 스펙에 태우기)
- **스펙(이미 존재 — gemini-regen-batch §1·§5.4·§16):** 고정 팔레트 hex(풀 warm-moss `#2d4720…#8fb267`·흙 램프·단일 외곽선 `#401818`) 프롬프트 삽입 → 생성 → **`quantize_to_palette.py` 스냅**. debris §5.4 크리스프 프롬프트(`single [OBJECT], top-down 3/4, transparent, self-shadow만`)와 동일 결.
- **목표 룩 = Style A debris와 동일 규율:** 1px 외곽선·타이트 램프(≤~16색)·NW 하이라이트/SE 그림자·블러 0·풀은 4색조 tuft(끝 하이라이트·밑동 그림자).
- **생성 트랙:** [ADR-0057] 지형은 PixelLab 저색이 정답이었으나, **작은 오브젝트 스프라이트는 외곽선/실루엣이 핵심**이라 debris를 뽑은 트랙(PixelLab `create_map_object`/Gemini+quantize) 재사용. 지형(seamless)과 달리 확산모델도 가능하나 **quantize 스냅 필수**.
- **규격 통일:** 전부 32-native 캔버스에 bottom-center 앵커(작은 것은 여백 투명). 크기 제각각 정리.

### 🔴 B. 스캐터 다양성 = twig·stone **소형 변주** 추가
- **무엇:** 개간용 큰 debris(ember_stone·petrified_stump)와 별개로, **밟고 지나가는 장식용 소형 나뭇가지·돌맹이 스캐터**를 신규 생성(스타듀 twig/stone처럼 1칸 이하, 통과 O, 개간 대상 아님).
- **배선:** `_GD_TABLES[GROUND]`에 twig·stone 변주 항목 추가(가중치 낮게). 그러면 P2 스캐터가 초록만이 아니라 **갈색 twig·회색 stone까지 빽빽**해져 스타듀 밀도·색대비 재현.
- **변주:** 각 종류 3변주(좌표해시 회전/반전) — 반복 티 방지(기존 debris도 v1/v2/v3 방식).

### 🟠 C. 밀도 튜닝 (재생성 후)
- Style B가 크리스프해지면 밀도를 올려도 지저분하지 않다. `GD_CLUSTER_CUT`↓ 또는 GROUND 테이블 가중 재배분으로 스타듀식 빽빽 스캐터. **재생성 완료 후** 라이브로 조정(지금 올리면 블러가 더 도드라짐).

---

## 4. 로스터 (재생성 대상)

| 종류 | 대상 파일 | 스펙 | 변주 |
|---|---|---|---|
| 풀 tuft (단/중/대) | `ground_grass1/2/3`, `grass_tuft` | 풀 램프·4색조·외곽선 sel-out | 각 좌우반전 |
| 잡초(습/건) | `ground_weed_under`, `ground_weed_dry` | 풀+마른 램프·십자 클럼프 | 3변주 |
| 들꽃 | `ground_flower` | 풀 램프 + 꽃 액센트 1~2색 | 색 변주 |
| 잔돌·자갈 | `ground_pebble`, `ground_gravel`, `ground_embed` | 흙/슬레이트 램프·외곽선 | 3변주 |
| 갈라짐 | `ground_crack`(깨짐) | 흙 램프 얕은 결 | — 또는 제거 |
| **[신규] twig** | `scatter_twig_{a,b,c}` | 목재 램프·X자/외가지·외곽선 | 3 |
| **[신규] stone** | `scatter_stone_{a,b,c}` | 슬레이트 램프·소형·외곽선 | 3 |

## 5. 스코프·다음 액션
- **아트 생성은 owner 트랙**(Gemini/PixelLab 수동, [ADR-0047]) — 이 문서는 스펙·로스터·근거. 생성물은 드롭인 교체(코드 최소).
- 배선(신규 twig/stone을 `_GD_TABLES`에 추가·크기 통일)은 코드 소작업 — 재생성물 도착 후.
- **제안 순서:** ①owner가 로스터대로 재생성(§4) → ②`quantize_to_palette.py` 스냅·색수 검증 → ③드롭인 교체 + twig/stone 테이블 배선 → ④P2 밀도 튜닝(§C) 라이브 확인.
- 관련: [[stardew-boundary-tile-analysis]](P2 스캐터 모델)·`prop-regen-roster.md` §5.6·`gemini-regen-batch.md` §1/§5.4/§16·[ADR-0057](저색 재생성)·[ADR-0047](Gemini 격상).
