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

## 1. 건물 외관 (buildings)

| key | 나라카명 | status | maker | 비고 |
|---|---|---|---|---|
| `house_ext` | 본가 | ✅ have | gemini | Gemini facade 완료(청크) |
| `storehouse_ext` | 갈무리방(창고) | ✅ have | gemini | Gemini facade 완료 |
| `barn_ext` | 넋우릿간(대형 축사) | ✅ have | gemini | Gemini facade 완료 |
| `coop_ext` | 넋둥우리(소형 닭장) | ❌ missing | gemini | 신규 — 넋우릿간과 구분되는 소형 |

## 2. 건물 실내 (interiors) — ★이번 패스 신규 (Track B 앞당김)

| key | 화면 | status | maker | 비고 |
|---|---|---|---|---|
| `house_floor` / `house_wall` | 집 내부 | ✅ have | claude | 기존 타일, 도색 마무리 |
| `barn_floor` / `barn_wall` | 넋우릿간 내부 | ❌ missing | claude | 실내 타일 + 진입 워프·pathing |
| `coop_floor` / `coop_wall` | 넋둥우리 내부 | ❌ missing | claude | 실내 타일 + 진입 워프·pathing |
| `storehouse_floor` / `storehouse_wall` | 갈무리방 내부 | ❌ missing | claude | 실내 타일 + 진입 워프 |

## 3. 가축 (livestock) — ★전부 신규 (현재 스프라이트 0)

> `animal_catalog.gd` = **2종뿐**(coop=노을닭 / barn=안개소), 산물 노을알·안개젖. **에셋 키 = 내부 id**(`honbaek_*`, 세이브 안전 위해 보존 — `animal_catalog.gd` §id 상수, 표시명≠식별자). 작물 규약(id=파일명)과 일치.
> ⚠️ **성장 단계(새끼→성체) 포함**(owner 2026-07-02 결정 — 성체+새끼 둘 다 이번 데모). 단 `livestock.gd`(Ranch)에 성장 로직이 없어 **메카닉 신규**가 딸림 = B1-b(성장티어) 앞당김. 로직은 S1-15에서 구현.

| key | 나라카명 | status | maker | 비고 |
|---|---|---|---|---|
| `honbaek_dak_baby` | 노을닭(새끼) | ❌ missing | gemini | 성장 1단계 |
| `honbaek_dak_adult` | 노을닭(성체) | ❌ missing | gemini | 정면+idle(4방향 불요) |
| `honbaek_so_baby` | 안개소(새끼) | ❌ missing | gemini | 성장 1단계 |
| `honbaek_so_adult` | 안개소(성체) | ❌ missing | gemini | 대형 |
| `honbaek_ran` (아이템) | 노을알 | ❌ missing | gemini | 인벤 아이콘 |
| `honbaek_yu` (아이템) | 안개젖 | ❌ missing | gemini | 인벤 아이콘 |

> 성장티어 세부 수치(며칠 만에 성체·성장 중 산물 여부)는 S1-15 착수 grill에서 잠금([track-b-livestock-rework-design] 참조).

## 4. 작물·과수 (crops)

| key | 나라카명 | status | maker | 비고 |
|---|---|---|---|---|
| `honryeongcho_{seed,sprout,mature}` | 혼령초 | ✅ have | gemini | 3단계 완비 |
| `pianhwa_{seed,sprout,mature}` | 피안화 | ✅ have | gemini | 3단계 완비 |
| `yeonghon_hobak_{seed,sprout,mature}` | 영혼 호박 | ✅ have | gemini | 3단계 완비 |
| `hwangcheon_podo_{seed,sprout,mature}` | 황천포도(트렐리스) | ❌ missing | gemini | 3단계 + 트렐리스 덩굴 (id=`hwangcheon_podo`) |
| `bulsagwa_{seed,sprout,mature}` | 불사과(다절기 프레스티지) | ❌ missing | gemini | 3단계 |
| `honbaekdo_{sapling,growing,fruiting}` | 혼백도(혼의 나무 과수) | ❌ missing | gemini | 대형·Y-sort·나이별. 단계 수는 orchard.gd 렌더 훅 확정 시(잠정 3) |

## 5. UI / HUD — ★Claude 즉시 제작 (한지 스킨)

| key | 요소 | status | maker | 비고 |
|---|---|---|---|---|
| `dialog_window` | 대화창 태운 한지 | ✅ have | gemini | 계승 원본 |
| `hanji_frame` / `hanji_plate` / `panel_frame` | 한지 패널 프레임 | ✅ have | gemini | 9-slice 배선 필요 |
| `heart_full` / `heart_empty` | 하트 | ✅ have | claude | 관계 탭 재사용 |
| `ink_arrow` / `soul_moth` | 진행 화살표·나비 | ✅ have | gemini | — |
| `menu_frame_9slice` | 탭 메뉴 프레임 | ❌ missing | claude | 통합 탭 메뉴 배경 |
| `tab_icon_inventory` | 탭 아이콘: 인벤토리 | ❌ missing | claude | — |
| `tab_icon_social` | 탭 아이콘: 관계 | ❌ missing | claude | — |
| `tab_icon_skill` | 탭 아이콘: 숙련 | ❌ missing | claude | — |
| `tab_icon_options` | 탭 아이콘: 옵션 | ❌ missing | claude | — |
| `clock_widget` | 시계 위젯(요일·날짜·시각·계절) | ❌ missing | claude | 우상단 |
| `gold_icon` | 골드 아이콘 | ❌ missing | claude | — |
| `energy_bar_frame` | 혼력 바 프레임 | ❌ missing | claude | 우하단(체력 자리 포함) |
| `tooltip_frame` | 호버 툴팁 프레임 | ❌ missing | claude | — |
| `toast_frame` | 아이템 획득 토스트 | ❌ missing | claude | 툴바 위 |
| `popup_frame` | 좌하단 컨텍스트 팝업(초상화+글) | ❌ missing | claude | — |
| `slot_frame` | 인벤/툴바 슬롯 | 🟡 placeholder | claude | 핫바 텍스처 유무 확인 |

## 6. 전체 화면 (screens) — 리스킨/신규

| 화면 | status | maker | 비고 |
|---|---|---|---|
| 타이틀/시작 | ❌ missing | claude | 새 게임/이어하기 |
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

집·창고·축사 정면 facade 남향·청크 규칙 재생성([ADR-0036]·[ADR-0047])은 §1(건물)의 Gemini 재생성으로 흡수. 기존 프롭(울타리·허수아비·planter 등)은 도색 마무리 대상(별도 로스터 항목 아님, 육안 사인오프로 처리).

---

## 위키 디프 구현 메모 (Phase A)

- `wiki/lib/required-assets.json` — 이 로스터를 기계 판독 JSON으로(카테고리·key·나라카명·maker·기대 status).
- `wiki/scripts/build-manifest.mjs` — 기존 스캔 결과와 로스터를 조인: 파일 있으면 `have`, 로스터에만 있으면 `missing`, 로스터가 `placeholder`로 표시한 파일은 `placeholder`.
- `/mechanics` 또는 신규 `/assets` 페이지에 "남은 작업(missing+placeholder)" 필터.
