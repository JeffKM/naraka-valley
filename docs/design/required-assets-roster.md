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
> **★2026-07-05 실상태 정정:** 아래 status는 2026-07-02 초안이었으나 그 뒤 HUD 폴리시 PR들이 **구조적 UI를 대부분 이미 완성**(`clock_hud`·`vitals_hud`·`hud_tooltip`·`notice_feed`·`context_popup`·`inv_frame` 4탭·전역 한지 Panel 테마 = `clock_hud.gd` "화면에 raw 패널 0" 달성). 실제 코드 대조로 ✅have 정정. **남은 진짜 gap = ①`gold_icon`(◈ 글리프→엽전, claude·이 슬라이스) ②탭 아이콘 4·시계는 위젯 완성이나 텍스트/글리프라 아이콘화만 gemini 정체성 큐.** 시계 위젯 자체는 have(정체성 아이콘 얹기만 큐).
> **★ 정체성 큐 스펙카드 = [gemini-ui-identity-spec.md](./gemini-ui-identity-spec.md)**(2026-07-05 — 탭 아이콘 4·시계 위젯 아이콘 8·타이틀 화면).
> **★2026-07-05 진행:** 탭 아이콘 4 = **claude PixelLab로 완료**(트랙 변경·PR#214, 정사각탭·툴팁). 시계 8·타이틀은 owner-Gemini 대기. **곁들여 백팩 그레이박스 소거**(§0 도구에 이어 **비료 5종**[삼베포대3·영혼빛병2]·**혼백도 묘목 1**을 PixelLab 아이콘화·PR#214 — 시작 인벤 색박스 0). + 최소 창크기 960×540 fix.

| key | 요소 | status | maker | 비고 |
|---|---|---|---|---|
| `dialog_window` | 대화창 태운 한지 | ✅ have | gemini | 계승 원본 |
| `hanji_frame` / `hanji_plate` / `panel_frame` | 한지 패널 프레임 | ✅ have | gemini | 9-slice 배선 필요 |
| `heart_full` / `heart_empty` | 하트 | ✅ have | claude | 관계 탭 재사용 |
| `ink_arrow` / `soul_moth` | 진행 화살표·나비 | ✅ have | gemini | — |
| `menu_frame_9slice` | 탭 메뉴 프레임 | ✅ have | claude | **★실상태 정정**: `inv_frame` 4탭(한지 9-slice)·`c2_frame_dump` |
| `tab_icon_inventory` | 탭 아이콘: 인벤토리 | ✅ have | **claude**(PixelLab) | 봇짐·정사각탭·툴팁(PR#214) |
| `tab_icon_social` | 탭 아이콘: 관계 | ✅ have | **claude**(PixelLab) | 하트+파란 여우불 글린트(PR#214) |
| `tab_icon_skill` | 탭 아이콘: 숙련 | ✅ have | **claude**(PixelLab) | 별+새싹(PR#214) |
| `tab_icon_options` | 탭 아이콘: 옵션 | ✅ have | **claude**(PixelLab) | 톱니(PR#214) |
| `clock_widget` | 시계 위젯(절기·일차·시각·골드) | ✅ have | claude | **★정정**: `clock_hud.gd`. 정체성 아이콘 8(절기/시간대)만 [스펙카드](./gemini-ui-identity-spec.md) §2 큐(❓후속) |
| `gold_icon` | 골드 아이콘(엽전) | 🟡 placeholder | claude | 현재 `◈` 글리프 → 엽전 아이콘 교체(이 슬라이스) |
| `energy_bar_frame` | 혼력 바 프레임 | ✅ have | claude | **★정정**: `vitals_hud.gd` |
| `tooltip_frame` | 호버 툴팁 프레임 | ✅ have | claude | **★정정**: `hud_tooltip.gd` |
| `toast_frame` | 아이템 획득 토스트 | ✅ have | claude | **★정정**: `notice_feed.gd` |
| `popup_frame` | 좌하단 컨텍스트 팝업(초상화+글) | ✅ have | claude | **★정정**: `context_popup.gd` |
| `slot_frame` | 인벤/툴바 슬롯 | ✅ have | claude | **★정정**: HanjiUi 스킨(hotbar·inv_frame `_draw_nine`) |

## 6. 전체 화면 (screens) — 리스킨/신규 (★maker C-혼합)

> 구조적 화면(정산·상자·설정 리스킨)=claude 즉시. **타이틀/시작=gemini**(정체성·첫인상·큐).

| 화면 | status | maker | 비고 |
|---|---|---|---|
| 타이틀/시작 | ❌ missing | **gemini** | ★정체성·첫인상(큐) — [스펙카드](./gemini-ui-identity-spec.md) §3(Cozy Ver.: 패럴랙스 씬 `title_bg` 1280×720 + `title_logo`, 4직원 코지 idle·붉은달/지옥문 서정 대비). **배선=메뉴 5개·멀티 3슬롯(save.gd 재설계)·Credits·Settings** — 큰 슬라이스 |
| 설정(볼륨·전체화면) | ✅ have | claude | **★정정**: 옵션 탭 내장(inv_frame 음악/효과음 볼륨·전체화면 토글) |
| 하루 정산 | ✅ have | claude | **★정정**: 전역 한지 Panel 테마 적용(RunSummary) |
| 카페 정산 | ✅ have | claude | **★정정**: 전역 한지 Panel 테마(CafeSummaryPanel) |
| 엔딩 | ✅ have | claude | **★정정**: 한지 Card 리스킨(EndingPanel/Card·먹빛 본문) |
| 상자(저장) UI | ✅ have | claude | **★정정**: `inv_frame` CHEST 컨텍스트(`chest.gd`·set_chest) |

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

> ★ **2026-07-06([ADR-0054]) facade 지면 리컬러 대기:** `house_ext`·`storehouse_ext`·`barn_ext`·`coop_ext` facade 스프라이트에 **초록 잔디 지면이 구워져** 있어, 흙-지배 마당([ADR-0053]) 위에서 초록 사각으로 튄다. **재출력 시 파사드 하단 지면을 tan(맨흙)/투명으로 리컬러**해 근본 접지. 그 전까지는 코드 오버랩 트릭([ADR-0054] Option C)으로 완화(다음 슬라이스).

**자연·시스템 프롭 13종**(나무·바위·덤불·그루터기·debris 3종·넝쿨·울타리·허수아비·화분·꽃 패치)의 16px Gemini 드롭인 교체는 [prop-regen-roster.md](./prop-regen-roster.md)가 전담한다(2026-07-04 grill: 장식+개간만·단일 상태·코드 그림자 유지·정확 크기 드롭인). 프롬프트 단일 출처 = [gemini-regen-batch.md](./gemini-regen-batch.md) §5.

### 8.1 절벽 FACE 원근 AO 베이크 (★[ADR-0056] ② — 코드 0·아트 트랙)

남향 절벽 벽면(H=2 고정)의 깊이감을 **코드가 아니라 아트 베이크**로 해결한다([ADR-0056] ②). `cliff_s_face/base.png` 재생성 시 아래 음영을 픽셀 단위로 구워 넣는다(드롭인 교체·배선/타일종 불변):

| 파일 | 베이크 규칙 |
|---|---|
| `cliff_s_face.png` | 상단 0px = 고원 광원 원본 톤(Opacity 1.0) → 하단 16px로 은은한 감쇄 음영 |
| `cliff_s_base.png` | 상단 = face 하단 어둠 이어받아 한 단계 더 어둡게 → 마당 맨흙(~72% Base) 접지 하단 16px = 드롭 섀도우 띠(Opacity ~0.65) |

> ⚠️ **이중 그림자 금지:** `cliff_s_base.png`엔 [cliff-tileset-spec §10.2] 단계1·2에서 **접지 그림자가 이미 베이크됨** → 위는 *신규*가 아니라 그 그림자의 **정밀화**다(발치 뭉갬 방지).

---

## 위키 디프 구현 메모 (Phase A)

- `wiki/lib/required-assets.json` — 이 로스터를 기계 판독 JSON으로(카테고리·key·나라카명·maker·기대 status).
- `wiki/scripts/build-manifest.mjs` — 기존 스캔 결과와 로스터를 조인: 파일 있으면 `have`, 로스터에만 있으면 `missing`, 로스터가 `placeholder`로 표시한 파일은 `placeholder`.
- `/mechanics` 또는 신규 `/assets` 페이지에 "남은 작업(missing+placeholder)" 필터.
