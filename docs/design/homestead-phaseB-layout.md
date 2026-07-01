# 안식 농원 Phase B — 80×65 재배치 빌드 스펙 (ADR-0035 구현)

> **상태:** ✅ **구현 완료(2026-06-30).** Phase A 아트(13종 라이브 임포트) 위에 Phase B 코드 빌드 완료 —
> 절벽 타일종(CLIFF_FACE/CORNER_L/CORNER_R/INNER)+충돌·고지 둘레 절벽·계단(통과)·debris 하드 게이트·
> 영혼빛 연못 WATER·5×5 스타터 패치·구불 동선 재작성·PROP_LAYOUT_HOME 전면 재배치. run_tests.sh 전체
> 통과 + home_full_dump 시각 확인 완료. 남은 것 = 개간 메카닉(파내기·해금)은 Slice 1.
> 진행 추적: 메모리 `homestead-overgrown-redesign-progress`. 회귀 맵 = 이 문서 §3(Explore 전수조사 산출).
>
> **★기하 개정([ADR-0044], 2026-07-01) — Slice 1에서 재구현:** 아래 §1~2의 **1타일 절벽**(남향 y29 1행 · 동향 x23 1열 · 넝쿨/덤불 코너 가림)은 **2행 pseudo-Z 다단**으로 격상된다 — `CLIFF_LIP`(걷기 O) → `CLIFF_FACE`/`CLIFF_FACE_BASE`(SOLID), 동향 면 신규(넝쿨핵 제거·NW광원 재보정), 코너=edge-to-edge, 계단=2행 종단([asset-ruleset §4.1]). z축 아님(2D 평면 불변). **아래 1타일 좌표는 Slice 1 재배치 때 개정**(고지 경계·충돌 행·BARN_EXT·계단 좌표 재산정). 현재 코드(1타일)는 그때까지 유효.
>
> **★★ [S1-1 grill 산출, 2026-07-01] 콤팩트 pseudo-Z 재배치 좌표표가 아래 §5로 확정됐다.** §1~2의 1타일 좌표(80×65 확장판)는 **§5가 supersede**한다 — 빌드(S1-2 타일종 / S1-3 `_build_grid` 재배치)는 **§5를 권위로** 따른다. §1~2는 역사적 기록으로 남긴다.

## 5. ★ [S1-1] 콤팩트 pseudo-Z 재배치 좌표표 (권위 · ADR-0044 H=2 구현 기준)

> **성격:** 2026-07-01 owner↔Claude grill(Q1~Q7) 산출. **저지 초반 밭 극대화 우선**으로 고지를 콤팩트화(확장판 폐기) — 창고 인접·연못 축출 충돌 0. 정규 타일명 = [ADR-0044 §1](../adr/0044-world-map-richness-pseudo-z-terrain-south-water-topology.md)(owner 스펙의 `FLOOR_HIGH`→`PLATEAU_GRASS`, `CLIFF_EDGE_E/S`→`CLIFF_LIP`/`CLIFF_FACE`/`CLIFF_FACE_BASE` 매핑).

### 5.1 고지(하늘 목장) 및 절벽 밴드 (H=2)

| 구획 | `PLATEAU_GRASS`(걷기 O·배치 O) | `CLIFF_LIP`(걷기 O) | `CLIFF_FACE`(SOLID) | `CLIFF_FACE_BASE`(SOLID·접지그림자) | 저지 시작 |
|---|---|---|---|---|---|
| **북단 주거 배후** | x0..16, y0..11 | x17 (동향) | x18..19 (동향) | — | x20 (저지 버퍼 x20..27, 창고 x28 사이) |
| **아우터 코너** | y10..12 구간 동경계 **x17→x21 청키 3×3 스텝**(직선 타파 코너 ①) | | | | |
| **남단 하늘 목장(동)** | x0..20, y12..25 | x21 (동향) | x22..23 (동향) | — | x24 (저지 평야) |
| **남단 하늘 목장(남)** | ↑ | y26 (남향) | y27 (남향) | y28 (남향·self-shadow 베이크) | y29 |

- **동향 절벽** = `Lip 1열 + Face 2열`(ADR-0044, base 분리 없음). **남향 절벽** = `Lip 1행 + Face 1행 + Face_Base 1행`(y28=접지 그림자 베이크).
- owner "최소 1~2번" 코너 = 현재 **1개**(아우터 코너 ①). S1-2 타일 저작에서 남향 면에 2번째 추가 가능(선택).

### 5.2 돌계단 및 2대 게이트 (동향 절개)

| 요소 | 좌표 | 통과 | 역할 |
|---|---|---|---|
| `STAIRS` | x21..23, y14..15 (2행 폭, 동향 절개) | O (SOLID 일시 해제) | 저지(x24)↔남단 고지(x20) 유일 연결 |
| **debris 하드게이트** | x24, y14..15 (계단 발치·저지측) | 개간 전 X | `업화석`(곡괭이)+`석화고목`(도끼) 해금 온보딩 (CONTEXT·ADR-0035, "평평≠막힘"=저지 무게이트·고지만 도구 게이트) |
| **animal gate** | x21, y14..15 (계단 탑·고지측) | 플레이어 O·**가축 X** | 혼의 짐승 AI Navigation 경계(단일 perimeter 틈 봉인) |

### 5.3 축사 (하늘 목장, Enterable)

- `BARN_EXT_RECT = (3, 14, 4, 3)` = **x3..6 / y14..16** (논리 4×3).
- `BARN_EXT_DOOR ≈ (5, 16)` — 하변 중앙, **남향**(ADR-0036) → 하부 방목지(y17+)로 열림. (±1 S1-3 시각확인.)
- **Enterable 승격** — 실내 밴드(y65+)에 축사 독립 룸 ID·좌표 **예약**(집·창고 병렬). 내부 레이아웃 = S1-7.

### 5.4 방목지 · 펜스

- **남단 고지 전체(x0..20, y12..25) = 단일 방목 Zone**. 혼의 짐승 AI는 `CLIFF_LIP` 내부 평면에 confined(절벽 perimeter + 계단 animal gate = 천연 펜, 울타리 비용 0).
- **펜스·게이트 = 옵션 빌드 콘텐츠**(S1-7 펜스 시스템 — 계단 틈 봉인·구획·장식용, 수동 배치). ADR-0035 "절벽=천연 울타리" 위에 *추가* 레이어(강제 아님).

### 5.5 저지 자산 (원위치 고정 — 코드 무결성 보존)

- **본가** `HOUSE_EXT_RECT (40,2,9,8)` door(44,9) · **창고** `STOREHOUSE_EXT_RECT (28,3,6,6)` door(30,8) — 유지.
- **영혼빛 연못** `SPIRIT_POND_RECT (26,34,8,7)` = x26..33/y34..40 — **원위치 사수**(확장판의 동쪽 이전 폐기).
- **스타터 패치** `STARTER_PATCH_RECT (40,12,5,5)` — 유지, 넓어진 저지 평야로 유효 경작 공간 극대화.
- **seam 불변식(보존):** SPAWN **(40,60)** · 동워프 at **(78,32)**/dest(3,36) · NARU→HOME dest **(77,32)** · `OKJA_INTRO_TILE (40,58)`. (owner 스케치의 "스폰 y40"은 도식 축약 — 실좌표 (40,60) 유지.)
- **debris overgrown 밭:** 넓어진 저지 평야(x20/x24 동편 전체)에 `debris_weeds`(낫)·`업화석`·`석화고목` 산포. 밀도 = **S1-8 밸런싱 변수**.

### 5.6 이연 항목 (S1-1 밖)

- `_carve_paths` 동선 재작성 → **S1-3** · 아우터 코너 세부 타일·2번째 코너 → **S1-2** · debris 밭 밀도 → **S1-8** · 축사 내부 레이아웃·펜스 시스템·목축 루프 → **S1-7**.

### 5.7 ★ [S1-2 착수 grill 산출, 2026-07-01] pseudo-Z 원시어휘 잠금 (권위)

> **성격:** owner↔Claude grill(Q1~Q5, `grill-with-docs`). **ADR-0044 §1 하위 구현 세부**라 CONTEXT/신규 ADR 불요(pseudo-Z=구현). §5.1~5.5 좌표는 불변, 여기서는 그걸 코드로 옮기는 **타일종+충돌 원시어휘**를 확정한다. 빌드(S1-2 실구현)는 이 §5.7을 권위로 따른다.

**(1) 산출물 경계 — S1-2 vs S1-3.** S1-2 = ① 타일종 상수 ② 재사용 원시함수 ③ 전용 격리 테스트만. **라이브 home맵의 옛 1타일 `_build_cliffs`(y29 행·x23 열)는 그대로 둔다(회귀 0).** §5.1~5.5 좌표로의 실제 재배치(`_build_cliffs` 전면 재작성)는 **S1-3**. 즉 S1-2는 "어휘·문법"을, S1-3이 "문장"을 쓴다.

**(2) 타일종 = 3 의미형만.** `CLIFF_LIP`(걷기 O — 충돌 루프 제외) · `CLIFF_FACE`(SOLID, **기존 상수·`cliff_face.png` 유지**) · `CLIFF_FACE_BASE`(SOLID, 신규). **방향(N/S/E/W)·코너 아트 변종은 S1-10**(그레이박스는 평면색이라 방향 무의미). 옛 `CLIFF_CORNER_L/R/INNER`는 S1-2 동안 유지, **S1-3이 `_build_cliffs` 재작성 시 제거**.

**(3) 그레이박스 색.** `CLIFF_FACE` = `cliff_face.png` 유지(라이브 시각 불변 = 회귀 0) · `CLIFF_LIP` = 밝은 하이라이트 톤(`COLORS`) · `CLIFF_FACE_BASE` = 어두운 접지 톤(`COLORS`). 3티어 명암 차로 pseudo-Z가 헤드리스 덤프에서 읽히게. S1-10이 3종 전부 NW광원 재보정 도트로 교체.

**(4) 원시함수 4종(북/서 불요 — 맵 경계가 막음).**
- `_lay_south_band(x0, x1, y)` — 남향: `y`=Lip행 / `y+1`=Face행 / `y+2`=Face_Base행(접지 그림자). (ADR-0044 §1 남향 = Lip1+Face1+Base1.)
- `_lay_east_band(x, y0, y1)` — 동향: `x`=Lip열 / `x+1..x+2`=Face 2열, **base 없음**(ADR-0044 "높이의 가로 치환" = Lip1열+Face2열). NW광원 재보정은 아트(S1-10).
- `_lay_corner_step(...)` — 외부 코너 L을 `CLIFF_FACE`로 edge-to-edge 채움 + 상단 `CLIFF_LIP` 1칸. **대각 solid-solid 접점 0**(풀 새어나옴·대각 틈 방지). §5.1 아우터 코너 ①(x17→x21 청키 3×3 스텝).
- `_carve_stair_notch(...)` — 밴드 단면의 SOLID를 일시 해제 → walkable + `STAIRS` 프롭. **노치 폭 = 밴드 깊이**(남향=2행 종단 / 동향=3열 종단). ★ADR-0044 §1 "2폭"과 §5.2 "3열"의 표기 충돌은 이 규칙으로 정합(뚫는 방향의 밴드 단면 전체를 연다).

**(5) animal gate = S1-7로 미룸.** S1-2 노치는 순수 플레이어 walkable. 가축 차단(NavigationRegion)은 혼의 짐승 AI가 도착하는 S1-7. §5.2 x21 계단 탑은 "animal gate 예약" 주석만.

**(6) 검증 = 정준 predicate + `cliff_test.gd`.** `main.gd`에 단일 진실원 `WORLD_SOLID_TILES`(+ `is_solid(id)`)를 두고 `_build_tileset` 충돌 루프가 이걸 참조(중복 제거). 신규 `playtest/cliff_test.gd`: 스크래치 사각형에 원시 4종 배치 → ⓐ 타일종 패턴 단언 ⓑ `is_solid`로 LIP=walk·FACE/BASE=solid 단언 ⓒ **8이웃(대각 포함) BFS leak 단언**(고지 walkable ↔ 저지 walkable = 오직 노치 경유, 대각 인접 시 fail). `home_expansion_test._walkable`의 CLIFF 하드코딩 → `is_solid` 마이그레이션은 **S1-3**(맵 변경과 동반, 회귀 0 유지). **물리 corner-squeeze(CharacterBody2D 대각 틈) 최종확인 = S1-3 bot/`map_dump` 육안**(격자 BFS는 물리 틈을 못 잡음 — 알려진 한계).

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
