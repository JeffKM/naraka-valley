# 안식 농원 데모 — 필요 에셋 목표 로스터 (required-assets)

> **목적:** "데모 1(안식 농원)을 시각적으로 완성하려면 무엇이 있어야 하는가"의 **목표 목록**.
> 위키(`wiki/`)가 이 로스터를 `game/assets/**` 실제 파일과 **디프**해 각 항목을 `✅있음 / 🟡placeholder(임시 확정본) / ❌없음`으로 배지·"남은 작업" 필터로 보여준다([ADR-0048](../adr/0048-homestead-demo-completion-pass-ui-screens-interiors.md) §6).
> 상태 열은 2026-07-02 조사 기준 **초안**이며, 실제 판정은 빌드 시 위키 디프가 자동으로 낸다.
> **범위 = 안식 농원 데모만.** 나루 마을·카페·던전 에셋은 각 슬라이스에서.

## 표기

- **키(key):** `game/assets/<카테고리>/<파일명>.png` 기준 파일 스템. 디프의 매칭 키.
- **status:** `have` ✅ / `placeholder` 🟡(Claude 임시 확정본, Gemini 교체 대기) / `missing` ❌
- **maker:** `claude`(즉시 제작 — UI·타일·절차) / `gemini`(owner 수동 생성, 스펙카드) — [ADR-0048] §5
- **규격은 스펙카드가 진실.** Gemini 교체본이 그대로 들어맞도록 크기·9-slice 여백·앵커·팔레트를 스펙카드에 박제한다([ADR-0025]).

---

## 0. 도구 (tools) — ★2026-07-05 grill 추가 (로스터 누락 해소)

> 데모에 매일 쓰이는 5 도구가 로스터에 없었다([ADR-0048] 개정 노트). 인게임은 **임시 색박스**(`item_catalog.gd` `tool_color_of`)·인벤=텍스트만. **아트 범위 = 아이콘만**(핫바·인벤). 휘두름/손든 스프라이트는 **캐릭터 시트 재생성 트랙으로 defer**(현재 도구-사용 애니·손든 렌더 슬롯 없음 — [ADR-0048] 개정 노트 §1). 5 도구가 농사+개간 공용(낫=이승의 미련·곡괭이=업화석·도끼=석화 고목).

| key | 나라카명 | status | maker | 비고 |
|---|---|---|---|---|
| `hoe` | 괭이 | ❌ missing | claude(PixelLab) | 미경작 칸 경작. `assets/tools/hoe.png` 32×32 아이콘 |
| `watering_can` | 물뿌리개 | ❌ missing | claude(PixelLab) | 심은 칸 물주기 |
| `scythe` | 낫 | ❌ missing | claude(PixelLab) | 이승의 미련(잡초) 제거·사료풀 베기 |
| `pickaxe` | 곡괭이 | ❌ missing | claude(PixelLab) | 업화석(돌) 제거 |
| `axe` | 도끼 | ❌ missing | claude(PixelLab) | 석화 고목(그루터기) 제거 |

**배선:** `main.gd` `TOOL_ICONS` 레지스트리(EXTRA_ICONS 형식) + `icons` dict 병합(id "hoe"는 crop id 불충돌) → hotbar·inv_frame `_draw_icon` CAT_TOOL 분기를 텍스처화(색박스 폴백 유지)·`_item_icon` 도구 분기(토스트 아이콘). 좌표·로직 불변.

## 1. 건물 외관 (buildings)

| key | 나라카명 | status | maker | 비고 |
|---|---|---|---|---|
| `house_ext` | 본가 | ✅ have | gemini | Gemini facade 완료(청크) |
| `storehouse_ext` | 갈무리방(창고) | ✅ have | gemini | Gemini facade 완료 |
| `barn_ext` | 넋우릿간(대형 축사) | ✅ have | gemini | Gemini facade 완료 |
| `coop_ext` | 넋둥우리(소형 닭장) | ✅ have | gemini | Gemini facade 완료·코드 배선 완료(PR #188) |

## 2. 건물 실내 (interiors) — ★이번 패스 신규 (Track B 앞당김)

| key | 화면 | status | maker | 비고 |
|---|---|---|---|---|
| `house_floor` / `house_wall` | 집 내부 | ✅ have | claude | 기존 타일, 도색 마무리 |
| `barn_floor` / `barn_wall` | 넋우릿간 내부 | ✅ have | claude | 절차 생성(다진흙+볏짚/세로판재)·배선 완료(PR #191) |
| `coop_floor` / `coop_wall` | 넋둥우리 내부 | ✅ have | claude | 절차 생성(밝은볏짚/가로널빤지)·배선 완료(PR #191) |
| `storehouse_floor` / `storehouse_wall` | 갈무리방 내부 | ✅ have | claude | 절차 생성(돌판석/돌켜)·배선 완료(PR #191) |

## 3. 가축 (livestock) — ✅ 스프라이트 4종 완료·배선 완료 (2026-07-03)

> `animal_catalog.gd` = **2종뿐**(coop=노을닭 / barn=안개소), 산물 노을알·안개젖. **에셋 키 = 내부 id**(`honbaek_*`, 세이브 안전 위해 보존 — `animal_catalog.gd` §id 상수, 표시명≠식별자). 작물 규약(id=파일명)과 일치.
> ⚠️ **성장 단계(새끼→성체) 포함**(owner 2026-07-02 결정 — 성체+새끼 둘 다 이번 데모). 단 `livestock.gd`(Ranch)에 성장 로직이 없어 **메카닉 신규**가 딸림 = B1-b(성장티어) 앞당김. 로직은 S1-15에서 구현.

| key | 나라카명 | status | maker | 비고 |
|---|---|---|---|---|
| `honbaek_dak_baby` | 노을닭(새끼) | ✅ have | gemini | `_draw_ranch` 배선 완료 |
| `honbaek_dak_adult` | 노을닭(성체) | ✅ have | gemini | `_draw_ranch` 배선 완료 |
| `honbaek_so_baby` | 안개소(새끼) | ✅ have | gemini | `_draw_ranch` 배선 완료 |
| `honbaek_so_adult` | 안개소(성체) | ✅ have | gemini | `_draw_ranch` 배선 완료 |
| `honbaek_ran` (아이템) | 노을알 | ✅ have | gemini | 인벤 아이콘 배선(EXTRA_ICONS·PR #188) |
| `honbaek_yu` (아이템) | 안개젖 | ✅ have | gemini | 인벤 아이콘 배선(EXTRA_ICONS·PR #188) |

> 성장티어 세부 수치(며칠 만에 성체·성장 중 산물 여부)는 S1-15 착수 grill에서 잠금([track-b-livestock-rework-design] 참조).

## 4. 작물·과수 (crops)

| key | 나라카명 | status | maker | 비고 |
|---|---|---|---|---|
| `honryeongcho_{seed,sprout,mature}` | 혼령초 | ✅ have | gemini | 3단계 완비 |
| `pianhwa_{seed,sprout,mature}` | 피안화 | ✅ have | gemini | 3단계 완비 |
| `yeonghon_hobak_{seed,sprout,mature}` | 영혼 호박 | ✅ have | gemini | 3단계 완비 |
| `hwangcheon_podo_{seed,sprout,mature}` | 황천포도(트렐리스) | ✅ have | gemini | 3단계 완비·CROP_SPRITES 배선 |
| `bulsagwa_{seed,sprout,mature}` | 불사과(다절기 프레스티지) | ✅ have | gemini | 3단계 완비·CROP_SPRITES 배선(PR #188) |
| `honbaekdo_{sapling,growing,fruiting}` | 혼백도(혼의 나무 과수) | ✅ have | gemini | 3단계·ORCHARD_SPRITES 배선(PR #188). 대형·bottom-center 앵커 |

## 5. UI / HUD — ★maker C-혼합 (2026-07-05 grill, [ADR-0048] 개정 §2)

> **구조적(claude): 즉시 제작** — 9-slice 패널·슬롯·툴팁·토스트·팝업·골드 아이콘·혼력바 프레임(`hanji_frame` 팔레트 샘플로 톤 맞춤). **정체성(gemini): 스펙카드+큐** — 탭 아이콘 4·시계 위젯(첫인상·손그림 한지). 원래 "UI 전체=claude"에서 정련.

| key | 요소 | status | maker | 비고 |
|---|---|---|---|---|
| `dialog_window` | 대화창 태운 한지 | ✅ have | gemini | 계승 원본 |
| `hanji_frame` / `hanji_plate` / `panel_frame` | 한지 패널 프레임 | ✅ have | gemini | 9-slice 배선 필요 |
| `heart_full` / `heart_empty` | 하트 | ✅ have | claude | 관계 탭 재사용 |
| `ink_arrow` / `soul_moth` | 진행 화살표·나비 | ✅ have | gemini | — |
| `menu_frame_9slice` | 탭 메뉴 프레임 | ❌ missing | claude | 통합 탭 메뉴 배경 |
| `tab_icon_inventory` | 탭 아이콘: 인벤토리 | ❌ missing | **gemini** | ★C-혼합: 정체성(큐·스펙카드) |
| `tab_icon_social` | 탭 아이콘: 관계 | ❌ missing | **gemini** | ★정체성(큐) |
| `tab_icon_skill` | 탭 아이콘: 숙련 | ❌ missing | **gemini** | ★정체성(큐) |
| `tab_icon_options` | 탭 아이콘: 옵션 | ❌ missing | **gemini** | ★정체성(큐) |
| `clock_widget` | 시계 위젯(요일·날짜·시각·계절) | ❌ missing | **gemini** | ★정체성·첫인상(큐)·우상단 |
| `gold_icon` | 골드 아이콘 | ❌ missing | claude | — |
| `energy_bar_frame` | 혼력 바 프레임 | ❌ missing | claude | 우하단(체력 자리 포함) |
| `tooltip_frame` | 호버 툴팁 프레임 | ❌ missing | claude | — |
| `toast_frame` | 아이템 획득 토스트 | ❌ missing | claude | 툴바 위 |
| `popup_frame` | 좌하단 컨텍스트 팝업(초상화+글) | ❌ missing | claude | — |
| `slot_frame` | 인벤/툴바 슬롯 | 🟡 placeholder | claude | 핫바 텍스처 유무 확인 |

## 6. 전체 화면 (screens) — 리스킨/신규 (★maker C-혼합)

> 구조적 화면(정산·상자·설정 리스킨)=claude 즉시. **타이틀/시작=gemini**(정체성·첫인상·큐).

| 화면 | status | maker | 비고 |
|---|---|---|---|
| 타이틀/시작 | ❌ missing | **gemini** | ★정체성·첫인상(큐)·새 게임/이어하기 |
| 설정(볼륨·전체화면) | ❌ missing | claude | 옵션 탭이 여는 화면 |
| 하루 정산 | 🟡 placeholder | claude | RunSummary 리스킨 |
| 카페 정산 | 🟡 placeholder | claude | CafeSummaryPanel 리스킨 |
| 엔딩 | 🟡 placeholder | claude | EndingPanel 리스킨 |
| 상자(저장) UI | ❌ missing | claude | 신규 컨테이너 + inv_frame CHEST |

## 7. 가구·테마 세트 (props) — home_deco

> `home_deco_catalog.gd` 2세트(SOULFIRE·HIGANBANA) × 3레이어(바닥재·벽지·가구). 현재 placeholder 색.

| key | 세트/레이어 | status | maker | 비고 |
|---|---|---|---|---|
| `deco_soulfire_floor` | 여우불 세트 바닥재 | 🟡 placeholder | gemini | 색 placeholder |
| `deco_soulfire_wall` | 여우불 세트 벽지 | 🟡 placeholder | gemini | — |
| `deco_soulfire_furniture` | 여우불 세트 가구 | 🟡 placeholder | gemini | — |
| `deco_higanbana_floor` | 피안화 세트 바닥재 | 🟡 placeholder | gemini | — |
| `deco_higanbana_wall` | 피안화 세트 벽지 | 🟡 placeholder | gemini | — |
| `deco_higanbana_furniture` | 피안화 세트 가구 | 🟡 placeholder | gemini | — |

## 8. facade·기존 프롭 다듬기 (S1-11 흡수)

집·창고·축사 정면 facade 남향·청크 규칙 재생성([ADR-0036]·[ADR-0047])은 §1(건물)의 Gemini 재생성으로 흡수.

**자연·시스템 프롭 13종**(나무·바위·덤불·그루터기·debris 3종·넝쿨·울타리·허수아비·화분·꽃 패치)의 16px Gemini 드롭인 교체는 [prop-regen-roster.md](./prop-regen-roster.md)가 전담한다(2026-07-04 grill: 장식+개간만·단일 상태·코드 그림자 유지·정확 크기 드롭인). 프롬프트 단일 출처 = [gemini-regen-batch.md](./gemini-regen-batch.md) §5.

---

## 위키 디프 구현 메모 (Phase A)

- `wiki/lib/required-assets.json` — 이 로스터를 기계 판독 JSON으로(카테고리·key·나라카명·maker·기대 status).
- `wiki/scripts/build-manifest.mjs` — 기존 스캔 결과와 로스터를 조인: 파일 있으면 `have`, 로스터에만 있으면 `missing`, 로스터가 `placeholder`로 표시한 파일은 `placeholder`.
- `/mechanics` 또는 신규 `/assets` 페이지에 "남은 작업(missing+placeholder)" 필터.
