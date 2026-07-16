# Wang 경계 전환 타일 — 설계 (spec)

- 날짜: 2026-07-16
- 상태: 승인 대기 → 승인 후 writing-plans
- 관련: ADR-0057(지형 저색 crisp 재생성), ADR-0043(풀=타일 통째로 참), ADR-0056(절벽 lip/base 오버레이), ADR-0054(건물 접지), ADR-0001(런타임 글루 허용·변환엔진 금지)
- 메모리: `terrain-tiles-pixellab-lowcolor-regen-adr0057` §후속 트랙(Wang 경계)

## 1. 배경·문제

안식 농원(HOME 구역)의 실제 보이는 지면은 TileMap이 아니라 `_build_ground16()`이 한 장으로 베이크하는 이미지 오버레이(`_ground_detail_tex`)다. 이 오버레이가 TileMap의 Wang 경계(`combined_terrain_homestead.tres` + `_paint_grid`의 `set_cells_terrain_connect`)를 **완전히 덮어** Wang 경계가 화면에 보이지 않는다.

현재 오버레이의 표면 경계 처리는 `_build_ground16` ②단계(main.gd 약 3454~3493)의 **per-pixel 랜덤 지터(±`_GJIT`=5px)**다. owner 진단: 이 지터가 "쯔꾸르/노이즈" 인상을 준다.

지면 base field 4종(`terrain16/grass_field·dirt_field·soil_field·water_field.png`)은 세션2(PR #248)에서 PixelLab 저색으로 이미 crisp 재생성됐으므로 **손대지 않는다**. 문제는 경계뿐이다.

## 2. 목표 (owner 3원칙)

1. **crisp** — per-pixel 랜덤 지터 제거
2. **변주 많은 자연 경계** — 손그림 Wang 16타일 전환(코너/변 여러 변주, 격자 반복 없음, 스타듀식)
3. **오버행** — 경계에서 위계 높은 표면이 낮은 표면 위로 볼록하게 자람(풀이 흙 위로)

owner 확정 결정:
- 방식 = **PixelLab 손그림 전환 타일**(절차적 실루엣 아님)
- 범위 = **잔디↔흙뿐 아니라 실제 발생하는 모든 경계쌍**
- 오버행 위계 = **잔디 > 흙 > 길 > 밭 > 물**
- 에셋 = **공통 팔레트 재생성(chaining) + 기존 완성분 재활용**

## 3. 비목표 (YAGNI)

- 접근 B(combined_terrain 전면 재생성 + 오버레이 폐기 + Godot terrain이 지면·경계 전담)는 채택하지 않음 — 흙지배·건물접지·잔디억제·프롭디테일·절벽 lip/base 로직을 전부 이전해야 하는 대공사·고리스크.
- HOME 외 구역(마을 등) 확산은 이 spec 범위 밖(잔여 트랙 ⑤). 이 spec은 HOME `_build_ground16` 경로만 다룬다.
- `_grid`/충돌/세이브/TileMap terrain 구조 변경 없음.

## 4. 표면 모델 (현행)

`_g16_surface(x,y)` 반환값:

| 값 | 표면 | field (`_g16_field`) |
|----|------|------|
| 0 | 맨흙(earth) | `_bf_earth` |
| 1 | 잔디(grass) | `_bf_grass` |
| 2 | 길(path/dirt) | `_bf_dirt` |
| 3 | 밭(soil) | `_bf_soil` |
| 4 | 물(water) | `_bf_water` |
| -1 | 건물바닥/절벽 | (투명 skip) |

현행 지터는 soft 표면(0·1·2)끼리만 처리하고 밭(3)·물(4)은 하드 경계였다. 본 spec은 **발생하는 모든 쌍**을 전환 타일로 처리한다(밭 furrow·수면 가독은 §7.4 참조).

위계 함수 `_surf_rank(s)`: 잔디(1)=4 > 흙(0)=3 > 길(2)=2 > 밭(3)=1 > 물(4)=0. (건물/절벽 -1은 경계 대상 밖.)

## 5. 렌더 통합 (접근 A)

### 5.1 교체 범위
`_build_ground16`에서 **②경계 지터 밴드 블록(약 3454~3493)만** 삭제하고 Wang 전환 blit으로 교체한다. 그 앞뒤 로직 — ①셀 base blit, 절벽 LIP 상단 평지화, BASE 발치 접지 그림자, 코너 컨텍스트 필, `_g16_cluster_cleanup`, `_g16_near_building` 잔디억제 — 은 **전부 그대로 보존**한다.

### 5.2 코너(vertex) 표면 산출
Wang은 셀 4코너(꼭짓점)의 terrain으로 타일을 고른다. 셀 단위 `surf` 격자에서 각 꼭짓점 V는 그 꼭짓점을 공유하는 최대 4개 셀의 표면 중 **위계 최댓값**으로 정한다(`_surf_rank` 최대). 건물/절벽(-1) 셀은 이 후보에서 제외한다.

셀 (x,y)의 4코너 = {(x,y),(x+1,y),(x,y+1),(x+1,y+1)} 꼭짓점.

### 5.3 전환 타일 선택
- 셀 4코너 표면이 **모두 동일** → 순수 셀. 지금처럼 base field blit(§5.1 ①이 이미 처리) — 전환 blit 없음.
- 4코너에 **정확히 2종** 표면(A=하위, B=상위 위계) → 그 쌍의 Wang 16타일 세트에서 코너 비트패턴에 맞는 타일을 blit. 상위 위계 B가 upper(오버행).
- 4코너에 **3종 이상**(삼중점) → 위계 상위 2종만 쌍으로 취하고, 나머지 하위 표면 코너는 그 상위 쌍의 lower로 흡수(스타듀 폴백). 드물게 발생.

전환 타일 이미지는 시작 시 각 경계쌍마다 **16타일**(4코너×2값=16 표준 Wang; 25타일 변형은 절벽 wall-continuation용이라 평지 경계인 여기선 16 사용)로 슬라이스해 캐시한다. blit은 셀당 1회(경계 셀만) — 성능은 현행 band 지터와 동등 이하.

### 5.4 자기 표면 유지(하드 경계 없음)
현행 지터가 "밭·물로 튀면 자기 표면 유지"로 하드 경계를 지키던 로직은 불필요해진다 — 모든 쌍에 전환 타일이 있으므로 하드컷이 없다.

## 6. 에셋 파이프라인

### 6.1 canonical base tile ID (톤 단일 소스)
표면 5종에 canonical base tile ID를 고정하고, 모든 전환 쌍을 그 base로(=`lower_base_tile_id`/`upper_base_tile_id`) 생성해 톤 100% 일치를 강제한다.

- 흙(earth) = `a2f59b0e-252e-4a83-a6e4-b080f2290d36` (8ffcb621 lower)
- 잔디(grass) = `60dcdf27-d238-44ae-95c8-5cb6b04f4c46` (8ffcb621 upper)
- 길(path) = **흙과 동일 `a2f59b0e` dirt 소스**. 세션2 메모리상 마당 흙(`_bf_earth`)은 길 dirt(`_bf_dirt`, 8ffcb621 lower)를 `_retone_earth`한 것이라 둘은 톤차만 있는 같은 지형이다. → **흙↔길 전환은 톤차가 미미하면 §7.1 스캔 후 생성 스킵**(경계가 사실상 안 보임). 필요하면 retone 차만큼의 얕은 전환을 재활용 슬라이스로 처리.
- 밭(soil) = `90d8a650` lower, 물(water) = `8d56f11b` lower (구현 1단계 `get_topdown_tileset`으로 base ID 최종 확정)

주의: 세션2 잔디는 `c4e187ab`에서 뽑았으나 canonical은 `8ffcb621`의 잔디(`60dcdf27`)로 통일한다(흙↔잔디 완성 전환을 그대로 재활용하기 위함). 두 잔디의 톤 차이가 크면 §6.4 mute로 흡수하거나 canonical을 재조정한다.

### 6.2 재활용
- **흙↔잔디 = `8ffcb621` 그대로 재활용** (이미 완성된 golden-tan dirt → muted green grass 16타일 Wang, 오버행 방향 = 잔디 upper. owner 목적과 정확히 일치).

### 6.3 재생성 (실발생 쌍만)
구현 1단계 맵 인접 스캔으로 확정된 나머지 쌍을 `create_topdown_tileset`으로 생성한다.
- 파라미터: `tile_size=32`, `detail="low detail"`, `outline="selective outline"`, `shading="basic shading"`, `view="high top-down"` (세션2 base와 동일 결)
- `lower_base_tile_id`/`upper_base_tile_id` = §6.1 canonical (위계 낮은 쪽=lower, 높은 쪽=upper)
- `transition_size` = 오버행 높이 레버(0.25~0.5부터 시험, owner 육안으로 조정)
- `transition_description` = 경계 블렌드 묘사(예: 물가 = "wet muddy shore")

### 6.4 톤 후처리
잔디가 포함된 전환 타일은 세션2 `_mute_grass_pixels`(sat_mul·sat_cap·hue lerp)를 잔디 픽셀에 동일 적용해 형광을 막는다(목본 완화 규칙과 동일 소스). 흙/길/물 픽셀은 대상 밖.

### 6.5 저장·임포트
슬라이스 원본은 `game/assets/terrain16/wang/<pair>.png`로 저장. 새 PNG는 첫 헤드리스 실행 전 `godot --headless --import` 재임포트 필요([[godot-import-cache-stale-asset-edit]]).

## 7. 세부·엣지 케이스

### 7.1 경계쌍 스캔 (구현 1단계)
`_grid`/`_g16_surface`로 전 셀을 훑어 상하좌우 인접 표면쌍(위계 정규화, A<B)을 집합으로 모은다. 이 집합이 생성해야 할 tileset 목록이다. 로그로 출력해 owner가 크레딧 소요를 사전 확인.

### 7.2 절벽·건물 경계
절벽/건물 셀은 surf=-1이라 코너 후보에서 빠지고, 기존 LIP/BASE/컨텍스트필 오버레이가 그 위를 덮는다 — 전환 blit과 충돌하지 않는다(순서: 전환 blit → 그 뒤 절벽 오버레이).

### 7.3 잔디억제 패드·클러스터
`_g16_cluster_cleanup`과 `_g16_near_building`(건물 발치 맨흙 강제)은 전환 blit **이전에** surf를 확정하므로 그대로 상류에서 동작한다. 건물 발치는 맨흙↔잔디 전환이 자연스럽게 사라진다.

### 7.4 밭·물 furrow/수면 가독
밭 이랑(furrow)·수면은 전환 폭이 크면 가독을 해칠 수 있다. `transition_size`를 밭·물 쌍에서 작게(0.25) 잡아 얇은 전환대로 유지한다. 결과가 나쁘면 해당 쌍만 하드 경계로 폴백하는 예외를 둔다(구현 시 육안 판정).

### 7.5 삼중점 빈도
저지 마당은 흙 지배 + 잔디 패치라 대부분 흙↔잔디 2종 경계다. 삼중점(길/물/밭이 겹치는 코너)은 드물다. §5.3 폴백으로 충분.

## 8. 불변식 (반드시 보존)

- `_grid`·`ground` TileMap·충돌 WALL·세이브(`user://save.dat`) 전부 불변. 본 작업은 `_ground_detail_tex` 픽셀만 바꾸는 **순수 시각 오버레이**.
- `_paint_grid`의 terrain-connect·솔리드·길 직칠 로직 불변.
- 절벽 lip/base/코너 오버레이, 건물 접지 그림자, 잔디억제 패드 불변.

## 9. 검증

- **회귀(선별)**: `game/run_tests.sh building_grounding` + `reclaim` PASS([[regression-scoped-not-full]]). 전체 회귀는 bana_test flaky 오탐이라 지양.
- **육안 하네스**: `game/tools/home_pilot_dump.gd` 재작성 — 경계 영역 크롭 렌더로 지터(before) → Wang 전환(after) 대비. `home_full_dump.gd`로 실제 지면+프롭 합성 확인.
- **정량**: 전환대 픽셀이 결정적(재빌드·재진입 동일, 깜빡임 0)인지 — 같은 셀 두 번 빌드해 해시 비교.
- owner 라이브 확인(코드 아님) — 경계쌍/오버행/톤 육안 최종.

## 10. 작업 순서 (writing-plans에서 상세화)

1. 맵 인접 스캔 스크립트로 실발생 경계쌍 확정 + canonical base ID 확정(§6.1) → owner에 생성 목록·크레딧 보고
2. 흙↔잔디는 `8ffcb621` 재활용 슬라이스, 나머지 쌍 `create_topdown_tileset` 생성(비동기 ~100s/개)
3. 전환 타일 로더·슬라이서·코너 인덱서 구현(캐시)
4. `_build_ground16` ②지터 블록을 Wang 전환 blit으로 교체
5. mute 후처리(§6.4)·`transition_size` 튜닝
6. `home_pilot_dump.gd` 재작성 + 선별 회귀
7. owner 라이브 확인

## 11. 워크트리 규칙

구현(2~6)은 코드·에셋 수정이므로 `EnterWorktree`로 격리 워크트리에서 진행([[worktree-isolation-rule]]). 새 워크트리는 첫 헤드리스 전 `godot --headless --import` 1회. 본 spec 문서 작성·커밋은 문서 예외라 현재 워크트리에서 진행.
