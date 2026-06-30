# 안식 농원 Phase B — 80×65 재배치 빌드 스펙 (ADR-0035 구현)

> **상태:** ✅ **구현 완료(2026-06-30).** Phase A 아트(13종 라이브 임포트) 위에 Phase B 코드 빌드 완료 —
> 절벽 타일종(CLIFF_FACE/CORNER_L/CORNER_R/INNER)+충돌·고지 둘레 절벽·계단(통과)·debris 하드 게이트·
> 영혼빛 연못 WATER·5×5 스타터 패치·구불 동선 재작성·PROP_LAYOUT_HOME 전면 재배치. run_tests.sh 전체
> 통과 + home_full_dump 시각 확인 완료. 남은 것 = 개간 메카닉(파내기·해금)은 Slice 1.
> 진행 추적: 메모리 `homestead-overgrown-redesign-progress`. 회귀 맵 = 이 문서 §3(Explore 전수조사 산출).

## 0. 구현 결과 요약 (실제 좌표 — 코드 기준)

- **타일종 추가:** `CLIFF_FACE/CORNER_L/CORNER_R/INNER`(SOLID_TILES·SOLID_TEX·COLORS·_build_tileset 충돌).
- **고지(하늘 목장):** x0..22, y0..28 걷기 가능 풀 / 동향 절벽 x23(y0..28) + 남향 절벽 y29(x0..23, 코너 양끝) /
  계단 틈 x10,x11(GROUND) / 축사 `BARN_EXT_RECT=Rect2i(3,22,6,4)` door(6,25) 비-enterable.
- **계단·게이트(PROP):** `STAIRS`(10,28) 통과 O / `DEBRIS_EMBER`(9,30)·`DEBRIS_STUMP`(11,30) 통과 X 하드 게이트.
- **저지:** 본가 `HOUSE_EXT_RECT=(40,2,9,8)` door(44,9) / 창고 `STOREHOUSE_EXT_RECT=(28,3,6,6)` door(30,8) /
  스타터 패치 `STARTER_PATCH_RECT=(40,12,5,5)` SOIL·`MIHO_FIELD_TILE=(42,14)` / 연못 `SPIRIT_POND_RECT=(26,34,8,7)` WATER /
  `OKJA_INTRO_TILE=(40,58)`·`LANTERN_TILES_HOME=[(39,17),(45,17)]` / overgrown debris 산포.
- **동선(_carve_paths):** 스파인 x38(y10..60)·본가 레인 y10·창고 갈래 y20/x30·동워프 레인 y32(→78,32).
- **보존:** SPAWN(40,60)·동워프 at(78,32)/dest(3,36)·NARU→HOME dest(77,32)·실내 밴드 불변.
- **삭제:** `FARM_RECT` → `STARTER_PATCH_RECT`로 대체(중앙 대형 밭 폐지).
- **테스트 회귀:** world_test ⑥d/⑥o 프로브를 카페 외관 내부 칸(+0,3)으로(축사 우연 겹침 회피) /
  home_expansion_test `_walkable`에 CLIFF_* 제외 / weave·home_expansion FARM_RECT→STARTER_PATCH / prop_layout 등불 단언.

## 1. 핵심 제약 (먼저 읽을 것)

- **절벽 face 타일 = 남향(south-facing).** 고지의 *남쪽 가장자리*가 E-W 절벽면으로 읽혀야 자연. → **고지=북서(NW)**, 남쪽 모서리가 주 절벽면, 동쪽 모서리는 corner+넝쿨로 감싸 처리.
- **높이 = 2D평면 + 절벽 충돌(통과X) + 계단(통과O)**, z축 아님([ADR-0035]). 고지 표면은 걷기 가능하되 절벽+맵경계로 둘러싸여 **계단으로만** 진입.
- **절벽 코너 틈 = 타일 수정·재도트 없이 넝쿨(vine)·덤불(bush) Y-Sort 덮개로 가린다**(owner 결정, 데모 검증). 식생 5종은 마스터 스타일 재생성·desaturate 완료.
- **보존(구역 seam 불변):** SPAWN(40,60)·동워프 at(78,32)/dest(3,36)·NARU→HOME dest(77,32)·실내 밴드 y65+.
- **삭제:** `FARM_RECT` 중앙 직사각형 밭(→ overgrown debris 밭으로 대체).

## 2. 확정 좌표 (80×65, x:0–79 y:0–64 외부, 북=상단)

> ⚠️ 정확 칸은 구현 중 `home_full_dump`로 시각 검증하며 ±2칸 미세조정. 건물↔계단 인접·연못 윤곽은 육안 1회 반복 예정(아래 ◎).

### 고지 (하늘 목장, NW, 1단 위)
- **고지 블록:** x0..23, y0..28 (걷기 가능 풀, 계단으로만 진입).
- **남향 절벽면(E-W):** y29 행, x0..23 = `cliff_face` 타일 + 충돌(통과X). 양 끝 corner.
- **동향 모서리:** x23 열, y0..29 = 절벽 충돌 + `cliff_corner`/넝쿨 덮개(side, 깔끔한 face 아님).
- **축사 BARN_EXT:** 고지 남서끝 x3..8, y22..25 (절벽면 위 풀, 비-enterable — 카탈로그 미등록 유지).
- **천연 울타리:** 절벽 단면이 방목 울타리 대체(울타리 PROP 면제).

### 계단 (고지↔저지 유일 연결, 통과O)
- **돌계단 stairs:** 남향 절벽면 절개 x10..11, y28..30 (2폭). 통과 가능(충돌 제외).
- **하드 게이트 debris(저지측 계단 발치):** `debris_ember_stone`(업화석·곡괭이)·`debris_petrified_stump`(석화고목·도끼)를 계단 입구 x9..12 y30..31에 배치. ※개간 메카닉(부수기·해금)은 Slice 1 — 지금은 *배치만*(통과불가 SOLID 객체로 길막음).

### 저지 (동·남, 나머지 전체)
- **본가 HOUSE_EXT:** 북중앙 x40..48, y2..9 (HOUSE_EXT_DOOR ≈ (44,9)). ◎
- **창고 STOREHOUSE_EXT:** 본가 왼쪽 병렬 x28..33, y3..8 (자재 동선·"창고 왼쪽=서쪽이 계단/고지 방향"). STOREHOUSE_EXT_DOOR ≈ (30,8). ◎
- **5×5 스타터 패치(SOIL, debris 0%·즉경작):** 본가/창고 남쪽 x40..44, y12..16. `MIHO_FIELD_TILE`을 이 패치 안(예: (42,14))으로 이동 — `_is_farmable`이 SOIL 기준이라 자동 추종, 단 미호 제외칸이 패치 안이어야 유효.
- **영혼빛 연못(WATER, 비정형):** 중앙-약간서 x26..33, y34..40. 물뿌리개 수급+낚시 앵커(메카닉 Slice 3). ◎
- **동워프:** at(78,32) 유지 — 동편 레인에서 닿음.
- **스폰:** (40,60) 유지.
- **overgrown debris 밭:** 저지에서 건물·스타터패치·연못·동선·계단 제외한 풀밭에 `debris_weeds`(이승의미련·낫)·`debris_ember_stone`·`debris_petrified_stump` 산포(밀도는 Phase 3 밸런싱 변수, 지금은 시각 overgrown). weeds=통과O 장식, 돌·고목=통과X SOLID.

### 동선 (_carve_paths 재작성 — 구불 흙길)
- 스폰(40,60) → 북 본가/창고 + 스타터패치로 구불 흙길. 동워프(78,32)로 동편 갈래. 계단(10,30)까지 서편 갈래. GROUND/SOIL 열려 도달성 자동(길=시각 안내).

### 절벽 틈 덮개 (PROP, Y-Sort)
- `vine`(넝쿨 32×64)을 남향 절벽면 이음매(face 타일 경계마다)에 드리움.
- `bush`(덤불 64×64)을 절벽 corner·east 모서리 틈에 배치.

## 3. 회귀 갱신 체크리스트 (Explore 전수조사 — 빠짐없이)

### A. 반드시 직접 수정 (하드코딩 단언/치수)
1. `main.gd:1846-1850` `_carve_paths()` HOME 동선 5줄 → §2 구불길 재작성.
2. `main.gd:241-289` `PROP_LAYOUT_HOME` 시드(가구 y67-75 보존·울타리/허수아비/화분/테두리 나무·바위 80×65 경계 + debris/식생 신규) 전면.
3. `layout.json` `"HOME"` 블록 — 위 시드와 **바이트 동등**(`prop_layout_test.gd:61` 런타임≡시드). 시드 바꾸면 layout.json 재생성 필요(`_save_layouts` 1회 또는 삭제 후 부팅).
4. `main.gd:210` `LANTERN_TILES_HOME` + `prop_layout_test.gd:83` 단언 `[(38,48),(42,48)]` → 새 등불 좌표 동시.
5. `tools/map_dump.gd:21` 캔버스 `40*32×24*32` → 80×65 (+ :19,:54 샘플 좌표).
6. `tools/home_dump.gd:27-30` 카메라 포커스 4좌표(집·밭·창고·축사 신위치).
7. `tools/home_wide_dump.gd:22` 맵 중심.
8. `world_test.gd:36,37,159,196`·`warp_test.gd:51`·`home_expansion_test.gd:125` 단언/positioning `(80,65)`·`(40,60)`·`(78,32)`·`(77,32)`. **이 값들은 보존 대상이라 대부분 그대로 통과**(좌표 유지) — 확인만.
9. 동워프 positioning `(78,32)` 하드코딩: `festival_test.gd:136`·`interior_test.gd:137`·`store_test.gd:90`·`save_region_test.gd:76`·`building_test.gd:64` — 보존이라 그대로.

### B. 짝으로 동시 갱신 (좌표 이동 시)
10. `region.gd:66,67,73`(size/spawn/동워프) + `region.gd:101`(NARU→HOME dest 77,32) — **전부 보존이라 무변경 확인**.
11. `main.gd:361,367(본가)·453-458(창고)·466,467(축사)·427(FARM 삭제)·428(spawn 보존)·652(MIHO_FIELD_TILE→스타터패치 안)` 재배치.

### C. 자동 추종 (재컴파일만)
12. `main.gd:3578 _is_farmable`(SOIL 기준)·`_build_grid`(size_of 동적)·`tools/home_full_dump.gd`·`interior_dump.gd`·`indoor_mask_check.gd`(상수/_buildings/size_of 동적).
13. playtest 다수 `m.FARM_RECT`/`m.STOREHOUSE_*`/`m.HOUSE_EXT_DOOR` 동적 참조(home_expansion·interior·weave·building·warp 등). **단 FARM_RECT 삭제 시 이를 읽는 테스트(weave_test:202·204 등)는 새 경작 좌표로 교체 필요** — §A로 승격 확인.

### D. stale 주석 정리(기능 무관)
14. `main.gd:652`(MIHO "(24,19,32,26)")·`main.gd:1545`("(38,16)")·`warp_test.gd:49`("(38,16)").

## 4. 신규 시스템 구현 노트

- **절벽 충돌:** `_build_border`의 StaticBody 패턴 참고 — 절벽 face/corner/east 모서리 칸에 통과불가 충돌. WALL처럼 타일 blit + 별도 충돌(또는 새 CLIFF 타일종+SOLID). 계단 칸은 충돌 제외.
- **절벽 시각 blit:** WALL blit(`TEX_OVERLAY`/`SOLID_TILES` 패턴) 차용 — cliff_face/corner_l/corner_r/inner를 경계 칸에 그림.
- **연못:** WATER 타일(`_set_tile`)로 비정형 채움 — 기존 물 terrain(TR_WATER=3, water_grass Wang) 자동 전환.
- **스타터 패치:** `_fill_rect(Rect2i(40,12,5,5), SOIL)`.
- **debris/식생 PROP:** `PROP_TEX_REGISTRY`에 신규 키 등록(VINE·STAIRS·DEBRIS_WEEDS·DEBRIS_EMBER·DEBRIS_STUMP) + `SOLID_PROPS`에 ember_stone·petrified_stump 추가(통과X). PROP_LAYOUT_HOME에 좌표.
- **검증:** `game/run_tests.sh`(워치독) 전체 통과 + `tools/home_full_dump.gd`(CPU 합성, 80×65 전체) 시각 확인 → owner 시각 OK 후 Phase C.
