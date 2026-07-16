# 안식 농원 프롭 재생성 로스터 (prop-regen-roster)

> **목적:** 안식 농원 데모를 스타듀 룩으로 완성하기 위해 **드롭인 교체할 자연·시스템 프롭 13종**의 큐레이션·추적 문서. 프롬프트는 여기 **중복하지 않는다** — 단일 출처는 [gemini-regen-batch.md](./gemini-regen-batch.md) §5. 이 문서는 *어떤 13종을·왜·어떻게 교체·검증하는가*만 담는다.
> **상태:** 시스템 범위·로스터·드롭인 규약 확정(2026-07-04 grill). owner 생성 대기.
> **★해상도(2026-07-04 개정):** [ADR-0050](../adr/0050-environment-32-native-revert-ai-source-supersede-0049.md)으로 **32px native 복귀**(ADR-0049 16px는 같은 날 supersede — AI 축소본이 손그림 스타듀보다 뭉개짐). **1칸 프롭 = 32×32 파일 네이티브**(청키화 없음). 아래 표의 "크기(2×)"·"논리(16px)" 열은 ADR-0049 시절 기록 → 32-native 기준으론 파일 크기 그대로, 내용만 32 논리.
> **근거 ADR:** [ADR-0033](../adr/0033-foraging-discovery-loop-nonskill-quality-tree-work.md)(채집·벌목=Phase 3 구역)·[ADR-0050](../adr/0050-environment-32-native-revert-ai-source-supersede-0049.md)(32px native)·[ADR-0047](../adr/0047-gemini-full-asset-regen-supersede-adr0001-scope.md)(Gemini 격상)·[ADR-0025](../adr/0025-asset-spec-card-gate.md)(스펙카드 게이트)·[ADR-0035](../adr/0035-homestead-elevation-cliff-overgrown-redesign.md)(개간).

---

## 0. 시스템 범위 결정 (2026-07-04 grill) — ★먼저 읽을 것

**질문:** "추가 시스템"(나무 벌목·바위 채광·덤불 채집·계단 다단이동)을 안식 농원 데모에 도입하는가?

**결정 = 장식 + 개간(reclaim)만. Phase 3 반복 루프는 안 끌어온다.**

- CONTEXT.md가 **채집의 집 = 저승 숲**, **벌목·수액 = 저승 숲/목공방**, **채광 = 업화 갱도**로 이미 배정([ADR-0033]·[ADR-0031]). 안식 농원의 인터랙티브 루프는 **개간(1회성 debris 제거)** + **사료풀 낫베기**(둘 다 구현 완료)뿐이다.
- 따라서 이 13종은 **나무·바위·덤불 = 순수 장식**(통과/발치 SOLID 경계벽), **debris 3종 = 개간(맞는 도구로 1회 제거)**, **계단·넝쿨 = 시각/이동 프롭**으로 남는다. main.gd:312 주석 *"채집·채광 상호작용은 Phase 3"*과 정합.
- **귀결: 13종 전부 단일 상태 아트.** 벌목→그루터기·채광→소멸·채집→picked 같은 다중 상태 프레임이 **불필요**(개간=`reclaim.is_cleared` 필터로 즉시 드로우 스킵). Gemini 생성이 크게 단순해진다.

> 벌목/채광/채집을 실제 반복 루프로 원하면 그 **구역(저승 숲·갱도)** 슬라이스에서 다루고, ADR-0033/0031 구역 배정을 개정해야 한다 — 이 데모 스코프 밖.

---

## 1. 로스터 = 13종 (안식 농원 자연·시스템 프롭)

전부 이미 파일이 있으나(구 PixelLab/P2.8 톤) **16px 스타듀 룩으로 Gemini 재생성 → 드롭인 교체** 대상. 크기·앵커·발치·충돌 프로필은 현행과 **동일**(코드 0줄 수정).

| # | key | 나라카명 | 크기(2×) | 논리(16px) | 카테고리 | 통과 | 코드 그림자 | 배치 프롬프트 |
|---|---|---|---|---|---|---|---|---|
| 1 | `tree_spirit_a` | 저승 봄나무(침엽) | 64×96 | 32×48 | 장식 | 발치바 SOLID | ✅ 타원 | §5.5 |
| 2 | `tree_spirit_b` | 저승 봄나무(활엽) | 96×96 | 48×48 | 장식 | 발치바 SOLID | ✅ 타원 | §5.5 |
| 3 | `rock` | 바위 | 64×64 | 32×32 | 장식 | 발치바 SOLID | ✅ 타원 | §5.1 |
| 4 | `bush` | 덤불 | 64×64 | 32×32 | 장식(능선) | 통과 O | ✅ 타원 | §5.1 |
| 5 | `stump_log` | 그루터기·통나무 | 64×32 | 32×16 | 장식 | 통과 O | ✅ 타원 | §5.1 |
| 6 | `debris_weeds` | 이승의 미련(잡초) | 32×32 | 16×16 | 개간=낫 | 통과 O | — | §5.4 |
| 7 | `debris_ember_stone` | 업화석 | 64×64 | 32×32 | 개간=곡괭이 | SOLID | ✅ 타원 | §5.4 |
| 8 | `debris_petrified_stump` | 석화 고목 | 64×64 | 32×32 | 개간=도끼 | SOLID | ✅ 타원 | §5.4 |
| 9 | `vine` | 넝쿨(절벽 덮개) | 32×64 | 16×32 | 시각 장벽 | 통과 O | — | §5.5 |
| 10 | `farm_scarecrow` | 허수아비 | 32×64 | 16×32 | 농경 장식 | 통과 O | ✅ 타원 | §5.1 |
| 11 | `farm_fence` | 울타리 | 32×32 | 16×16 | 농경 장식 | 통과 O | — | §5.1 |
| 12 | `farm_planter` | 화분 | 32×32 | 16×16 | 농경 장식 | 통과 O | — | §5.1 |
| 13 | `spirit_flower_patch` | 꽃 패치(피안화) | 32×32 | 16×16 | 농경 장식 | 통과 O | — | §5.5 |

**코드 그림자 세트(`PROP_SHADOW_SET`, main.gd:338):** #1·2·3·4·5·7·8·10 (8종). Gemini는 **접지 그림자를 굽지 않는다** — 코드 `_draw_prop_shadow`가 런타임 반투명 타원을 발치에 깐다(asset-ruleset §11). 스프라이트엔 self-shadow만.

### 로스터에서 제외된 것 (왜 13인가)

- **`grass_tuft`** — 손배치 폐기, 절차 지면 디테일(`GD_GRASS*`)이 대체(main.gd:342). 재생성 대상이지만 프롭 아님 → 지면 디테일 배치(§5.6)에서 다룸.
- **`stairs_east`** — S1-10에서 동향 돌계단으로 이미 정식 재생성(별도 파이프라인). 배치 §5.5에 프롬프트는 있으나 이 데모 교체 로스터엔 불요.

---

## 2. 드롭인 교체 규약 (코드 불변 보장)

Gemini 교체본이 **그대로 들어맞아** 코드·layout.json·좌표를 건드리지 않도록:

1. **정확한 픽셀 크기 유지** — 위 표 "크기(2×)" 그대로. 13종 전부 16px 논리의 깨끗한 배수라 재정규화 불필요.
2. **투명 배경·bottom-center 앵커** — 발치(ground-contact) 밑단선이 현행 프레임과 **같은 y**에 오게(충돌 발치바·코드 타원 정렬). 프레임 상하 여백을 옛 파일과 맞춘다.
3. **접지 그림자 미포함** — §0/§1 확정. self-shadow만.
4. **외곽선 = 객체 단일 외곽선**(`#401818`, asset-ruleset). 16px 실험 락: 베이스 지형=무외곽선 / **객체=outline**([tile-system-grill-16px-experiment]) — 13종 전부 객체이므로 outline 유지.
5. **debris는 kind 역인 텍스처**(main.gd:329 `DEBRIS_KIND`) — 파일명·크기 고정. 실루엣은 개간 도구를 읽히게(#6 잡초=낫·#7 업화 크랙=곡괭이·#8 석화=도끼). #8 석화 고목 ↔ #5 통나무는 실루엣 구분(돌화·험상).

## 3. 검증 워크플로 (교체 후)

각 교체본을 넣은 뒤:

1. `game/run_tests.sh` — 회귀(발치충돌·Y-split·개간 디스패치·drop) 전부 통과 확인(좌표·충돌 불변이므로 0 회귀 기대).
2. **인게임 육안** — `home_full_dump`(안식 농원 합성)로 640×360 ×2 실배율에서 확인([region-tile-visual-check-workflow]). 발치 접지·Y-Sort(캐릭터가 나무·바위 뒤로 가려짐)·톤 통일 점검.
3. 위키 매니페스트(`npm run manifest`)가 status를 `have`로 갱신 → required-assets 디프 반영.

## 4. 우선순위

owner Gemini 생성 순서 권장(난이도·데모 임팩트):

1. **debris 3종(#6·7·8)** — 개간 온보딩 첫 인상, 남향 게이트 가시성.
2. **나무 2종·바위(#1·2·3)** — 맵 프레이밍·부피감(발치 Y-Sort 검증).
3. **농경 장식 4종(#10·11·12·13)** — 스타터 패치 곁 "농장" 읽힘.
4. **덤불·통나무·넝쿨(#4·5·9)** — 능선·절벽 이음매 마감.

> 프롬프트 본문은 [gemini-regen-batch.md](./gemini-regen-batch.md) §5.1/§5.4/§5.5에서 복사 → Gemini. 이 문서는 그 배치의 *안식 농원 데모 뷰*일 뿐이다.

## 5. debris 3종 — PixelLab 1칸·3변주 재설계 (2026-07-04, owner 방향)

owner가 스타듀 실물 + "Farm Cleanup Asset Set" 레퍼런스와 대조해 debris를 **배치 §5.4와 다르게** 재설계했다(이 부분은 배치를 가리키지 않고 여기서 확정):

- **1칸으로 축소:** 업화석·석화 고목을 64×64(2×2) → **32×32(1칸)**. 스타듀 debris가 전부 1칸이라 정합. `debris_weeds`는 이미 1칸. → **코드 배선 딸림**(충돌 footprint 2×2→1×1·PROP_LAYOUT 좌표·발치바·SOLID 판정) = 별도 워크트리 후행.
- **타입당 3변주(총 9):** ①**이승의 미련**=위에서 본 꽉 찬 잎 로제트(한 칸 채움) ②**업화석**=단일 볼더 1 + 3조각·4조각 자갈 무더기 2 ③**석화 고목**=대각선 통나무(왼쪽 대각 2 + 오른쪽 대각 1, 굵은 원통·자른 단면).
- **생성=PixelLab `create_1_direction_object`**(owner 지시 — 배치의 Gemini 트랙과 별개). 레퍼런스 팔레트 추출(통나무 `#a86024/#905424/#542418`·바위 taupe `#907878/#846c6c/#543c48`·잎 초록 `#0c6024/#005430`)로 양자화.
- **해상도=32-native([ADR-0050]):** 처리 파이프라인 `tools/_debris16_build_v6.py`(64→32 BOX·가벼운 양자화·부드러움 우선, 하드청키/과양자화 금지). 통나무 대각선은 32-native라 읽힘(16px에선 굵은 대각선 불가였음).
- **staging:** `game/assets/props/_debris16_staging/`(raw·중간본·대조 시트). 실 에셋 배치·배선은 owner 사인오프 후 워크트리에서.

### 5.1 ★art 확정 (owner 사인오프 2026-07-04)

9종 최종본 = `_debris16_staging/debris_{weeds,ember_stone,petrified_stump}_v{1,2,3}.png` (전부 **32×32**). 잡초=꽉 찬 잎 로제트 / 업화석=볼더+3조각·4조각 무더기 / 석화 고목=**두툼한 나뭇가지**(통나무 아님 — 갈래·offshoot·antler, owner 재확정 2026-07-04). **아트 잠금 완료, 배선 대기.**

### 5.2 배선 build 스펙 (워크트리 후행 — 코드 변경)

1. **에셋 배치:** 9종을 `assets/props/`로. 단일 텍스처(`debris_weeds.png` 등) → **kind별 3변주 배열**로 확장.
2. **크기 1칸화:** `PROP_DEBRIS_EMBER`·`PROP_DEBRIS_STUMP` 64×64 → **32×32**. `PROP_DEBRIS_WEEDS`는 이미 32×32.
3. **충돌:** 업화석·석화 고목 SOLID footprint **2×2 → 1×1**(`SOLID_PROPS`·`_rebuild_prop_collision`). 발치바 무관(debris는 풀타일 SOLID).
4. **변주 선택:** `DEBRIS_KIND` 역인 + PROP_LAYOUT 좌표별 결정적 변주 인덱스(예: 좌표 해시 % 3) — 같은 kind가 맵에서 3형태로 다양.
5. **좌표:** `PROP_LAYOUT_HOME`의 debris 좌표는 1×1 기준으로 재점검(2×2 시절 배치가 겹치지 않게).
6. **회귀:** `run_tests.sh`(개간 디스패치·drop·is_cleared skip 불변) + `home_full_dump` 육안.

## 5.3 통나무(logs) 5종 — PixelLab 재설계·배선 완료 (PR #202, 2026-07-04~05, owner 방향)

로스터 #5 `stump_log`(단일 그루터기, 맵 미배치)를 owner 레퍼런스(스타듀 "Logs & Branches")로 **5종 재설계**했다. 배치 §5.1의 "현행 크기 드롭인"과 별개 — debris·나무와 같은 PixelLab `create_1_direction_object` 트랙.

**5종(전부 32-native, ★통과 불가 SOLID 장애물 — owner 2026-07-05 "통나무는 통과 안 됨"):**

| key | 크기(칸) | 형태 |
|---|---|---|
| `PROP_LOG_LONG` | 96×32 (3×1) | ㅡ자 긴 통나무(수평) |
| `PROP_LOG_SHORT` | 64×32 (2×1) | 짧은 통나무(수평) |
| `PROP_LOG_UPRIGHT` | 32×32 (1×1) | 세워진 그루터기(위 나이테 단면) |
| `PROP_LOG_DIAG_A` | 32×32 (1×1) | 대각 통나무 밝은(honey, ＼) |
| `PROP_LOG_DIAG_B` | 32×32 (1×1) | 대각 통나무 어두운(walnut, ／ — A와 대칭) |

**아트 파이프라인(`tools/_logs_build.py`):** raw(정사각) → 최대 연결덩어리만 남겨 부스러기 제거 → (필요 시)회전 보정(diag_b −45° 대각) → 목표 박스 fit(long=stretch 96×32·나머지 contain) → bottom-center 정렬.
- **★긴 통나무 ㅡ자 교훈(owner 2026-07-05):** 회전 보정본은 *실루엣*만 수평이고 **나뭇결이 대각으로 흘러** 여전히 기울어 보였다(중심선 0°여도 owner "아직 기울어"). → **나뭇결이 수평인 후보로 재생성**(프롬프트 "grain lines running straight horizontal")해 회전 불필요(rot 0)·결까지 수평. 실루엣 각도는 픽셀 중심선 회귀로 정량 검증(중심 −0.1°·상단 0.1°·하단 −0.4°). 원본 aspect도 ~3.2:1이라 stretch 왜곡 최소.

**배선 스펙(모두 `main.gd`):**
1. **preload 5종**(옛 `PROP_STUMP`·`stump_log.png`/`_raw.png` 폐기 — 맵 미배치라 안전).
2. **레지스트리·팔레트:** `PROP_TEX_REGISTRY`(`LOG_LONG`…)·`_EDIT_PALETTE`·`_EDIT_PAL_NAMES` 5키. `PROP_SHADOW_SET`에 5종(부피 바닥 프롭).
3. **★통과 불가(SOLID):** `SOLID_PROPS`에 5종(**풀타일 장애물** — `FOOT_BAR_PROPS`·`FADE_PROPS` 미포함=낮은 프롭이라 발치바/occlusion fade 없이 스프라이트 footprint 전체 충돌). 크기가 3종이라 debris식 변주배열이 아닌 **개별 프롭**(발치·Y-Sort·충돌 footprint가 크기 파생).
4. **배치:** `PROP_LAYOUT_HOME` 16곳(나무 클러스터 곁·빈 가장자리, "벌목 숲" 프레이밍). 라이브 검증 `tools/logs_place_check.gd`(SOLID·기존 프롭·건물 EXT·연못·패치·방목 겹침 0). `layout.json` 시드 재생성 필수(삭제 후 헤드리스 1회).
5. **테스트:** `prop_ysort_test` ② 그림자 단언 PROP_STUMP→통나무 5종 갱신. `run_tests.sh` 48개 전체 통과·회귀 0(SOLID 전환 soft-lock 0). `home_full_dump` 육안(접지·그림자·톤·대칭·수평 확인).


