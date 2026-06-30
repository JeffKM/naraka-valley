# 지형 타일 재생성 = lush full-grass + pro raggedness 유기적 경계 (오버레이 모델 폐기)

owner가 인게임([ADR-0042] 증분1~2 결과)에서 두 가지를 지적(2026-06-30):
1. 풀의 생동감을 **작은 tuft 오버레이**로 낸 게 "타일 가운데 대충 박아놓은 느낌" — 풀은 *타일이 통째로 차서 옆 칸과 쭉 연결*돼야 한다.
2. 길↔잔디 **경계가 매번 똑같은 직선** — 레퍼런스(스타듀)처럼 "같은 경계라도 들고나는" 유기적 변주 시스템이 없다.

[ADR-0042]의 *부드럽게 + 변종* 방향은 맞았으나, **수단(기존 타일 후처리 + tuft 오버레이)이 틀렸다**. 본 ADR로 수단을 교정한다.

## 1. 오버레이 모델 폐기 — 생동감은 *베이스 타일*에 굽는다

- 지면 디테일을 칸 위 작은 스프라이트로 흩뿌리는 `_build_ground_details()` **오버레이 호출 비활성**.
- 풀의 풍성함·연결감은 **풀로 꽉 찬 lush 베이스 타일**(타일끼리 seamless)로 낸다. debris/forage(점적 장식)는 본 시스템이 아니라 **Phase 3 게임플레이 오브젝트**로(설계 [ground-composition.md](../design/ground-composition.md) §5).

## 2. 타일셋 *재생성* (기존 4세트 폐기) — PixelLab pro 모드

- 안식 농원 지형(`grass · dirt path · tilled soil · water`) 체인을 **`create_topdown_tileset(mode=pro)`**로 재생성. 기존 에셋 재사용 안 함(owner 승인).
- 파라미터: **medium detail**([ADR-0035]의 'low detail 청키'를 *지형 한정* 개정 — 보여준 스타듀 레퍼런스가 더 lush·디테일) · `view low top-down` · `single color outline` · `basic shading` · `transition_size 0.0` · **`raggedness ~0.4~0.45`**(경계 노이즈 = 유기적 들쭉날쭉) · `text_guidance 8` · 32×32.
- 풀 프롬프트 핵심: "lush dense ground-covering meadow grass, blades filling the entire tile, warm muted Stardew farm palette, NOT sparse, NOT bare". 체이닝: 모든 풀 세트가 같은 `grass base id`를 물려받아 결 일관.
- terrain id 순서 **길0·풀1·밭2·물3** 보존(컨버터 인자 순서 + 공유 terrain 문자열 dedup).

## 3. 풀 톤 정규화 = *런타임 한 곳*에 일원화 (ADR-0001 글루)

- 세 grass 세트(grass_path·soil_grass·water_grass)는 각자 다른 런이라 풀 톤이 어긋난다(특히 water_grass 노랑 → 필드 체커 + 연못 둘레 밝은 링). 소스 PNG 색보정은 물 픽셀 오염 등으로 취약 → **색 로직을 `main.gd::_harmonize_grass_variants()` 런타임 보정으로 통합**(소스 PNG는 vivid 원본 유지·재유도 가능).
  - **패스 A:** source 0의 *모든 풀(녹색 hue 60~158) 픽셀*을 warm-moss 기준 hue로 수렴 + 채도 캡(candy→muted). 갈색(길·밭)·청록 물·soul-blue(>158)는 hue로 제외 보존. 명도 유지 → lush 결 보존. → water_grass 노랑·연못 링·candy 채도 일괄 정리.
  - **패스 B:** base all-grass 3변종의 *평균색*만 공통 톤(채널별 중앙값)으로 평행이동 → 잔여 *명도 체커* 제거(텍스처 보존).

## 4. 입체 클럼프 그라스 + per-cell 변종 (owner 2차 지적 — "무늬만 있고 입체감 없음")

owner가 스타듀 레퍼런스와 비교: 우리 풀은 *균일한 빗금 무늬 = 평평*, 스타듀는 *작은 클럼프(tuft)가 입체적*(밝은 윗면+그늘 밑동, 클럼프 사이 그림자). 두 결정:

- **(a) 입체 클럼프로 재생성.** 풀 프롬프트를 "many small distinct tufts and clumps, brighter sunlit top + darker shaded base, soft shadows between clumps, bumpy volumetric depth, NOT a flat uniform pattern"로. 깊이 검증: 휘도 std 17→**27.7**(클럼프 볼륨). ⚠️ `medium shading`은 서버에서 자주 멈춤 → **`basic shading` + 깊이 프롬프트**로 충분(shading 파라미터보다 *프롬프트*가 깊이를 만든다).
- **(b) per-cell 변종 = 같은 전이쌍을 *여러 시드* 생성 → Godot terrain alternative.** 단일 클럼프 타일을 깔면 클럼프가 격자로 반복된다. 같은 terrain 문자열로 시드 2~3벌 생성해 컨버터에 함께 넘기면 **컨버터가 terrain 문자열 dedup**으로 변종 타일을 같은 peering bit에 등록 → `set_cells_terrain_connect`이 칸마다 랜덤 선택. **컨버터 코드 수정 불필요**(인자에 세트만 추가). 확보: all-grass **7변종**·g↔path 3·g↔soil 2·g↔water 2 → 클럼프 격자 소멸 + "같은 경계 들고남".

## 5. 차분함 조정 + 길 경계 (owner 3차: "정신없다·길 경계 예전 그대로·길 너무 깨끗")

균일 랜덤으로 7변종을 깔면 고대비 클럼프가 칸마다 제멋대로라 산만하다("아기자기·깔끔" 상실). 결론 = **패턴 고정(인위적)도 확률 난수도 아니고, *아트 대비를 낮춰 차분하게* + 길 경계는 전환 타일을 실제로 쓰게**:

- **(a) 클럼프 대비 감쇠** — `_harmonize_grass_variants` 패스 B에서 base 변종의 *국소 편차(클럼프 대비)를 ~42% 감쇠*(`_GD_CLUMP_DAMP`). 평균 톤은 공통 타깃으로, 깊이는 일부만 남겨 차분·아기자기하게. 변종은 유지(격자 방지)하되 노이즈만 죽인다. (값으로 입체감↔차분함 튜닝.)
- **(b) 길 경계 유기화 — *보류*(성능).** 길은 base 직접 칠이라 grass↔길 전환·raggedness가 적용 안 됨(하드 직선). 하이브리드(path를 terrain-connect→인접 풀칸 전환→길칸만 base 덮기)로 유기화는 되나, 마을의 거대 길 corridor에서 `set_cells_terrain_connect` 비용이 커 워프 시 **구역 빌드가 ~2s로 튀어 전환 연출(테스트 `_settle` 2000ms 워치독)이 간헐 실패**. 프로젝트 원칙(끝까지 플레이 > 예쁨) — **보류**, 빌드 최적화(경계만 connect) 후 재도입.
- **(c) 타일 배치 규칙 — "규칙 있을 곳엔 규칙, 없어도 되는 곳엔 임의"(owner 4차).** 균일 랜덤 변종은 *구조적 맥락*(경계·건물 옆)에서 "아무거나" 배치된 느낌을 준다. Wang은 전환 타일을 config로 규칙대로 고르지만 *같은 config 변종*을 어디서나 랜덤으로 뽑는 게 문제. → **2단계(`_apply_placement_rules`):** 전환/경계 config는 **결정적**(중복 변종 `probability=0`, config당 1개 = 규칙적·의도적 경계), **빈 들판 all-grass만 변종 랜덤**(`probability=1`, 자연 변화). = 경계·구조는 일관되게, 자연 변화는 빈 땅에만.
## 6. 길 중앙 텍스처 + facade 블렌드 (owner 5차 진행 요청)

- **(a) 길 중앙 텍스처(`_build_path_detail_source`).** 길 base가 평면 갈색이라 "너무 깨끗". 길 base 톤에서 절차적 다짐 결(가로 rut)+저주파 mottle+작은 잔자갈을 입힌 변종 `PATH_VARIANTS`(3)개를 별도 source(`PATH_SRC_ID`)에 두고, 길 칸을 *결정적 해시*로 변종 선택(그리드 반복 방지·임의 아님). 충돌 없음.
- **(b) 건물 둘레 갈색 "path 링" 제거 — 핵심 버그.** 진단: 건물 footprint(WALL)는 terrain 미할당("빈 코너")이고 `set_cells_terrain_connect`가 **빈 코너를 기본값 terrain 0(=PATH)** 로 처리 → 건물·VOID 둘레마다 grass↔path 전환(갈색) 링. (facade 아트가 아니라 **터레인 빈코너 아티팩트**였음 — 기존부터 잠재.) 해결: 솔리드 칸을 전부 풀 base로 terrain-connect에 넣으면 정확하나 7200셀 솔버가 무거워져 빌드가 튀므로(위 (b) 성능), **건물 외벽 솔리드(WALL·HOUSE·CAFE·*_WALL)의 인접 GROUND 칸만 all-grass base 타일로 직접 덮는다**(`_RING_FIX_ENABLED`, 솔버 없는 set_cell·나무/바위 제외 = 싸다). 건물 둘레가 평범한 풀로 이어진다.
- **(c) facade 투명부 회색 WALL 비침 제거(`_facade_grass_backdrop`).** facade 아트는 footprint보다 작아 투명 가장자리로 회색 WALL이 비친다. 충돌·grid·테스트(=WALL)는 그대로 두고, facade 그리기 *직전*에 footprint를 풀 베이스로 덮어(시각 전용) 투명부가 풀로 비치게 한다. dump(home_full_dump)도 동일 backdrop 재현.
- 검증: 창고·집이 풀 위에 자연스럽게 안착(해자·회색 프레임 소멸). 회귀 — 낮은 부하에서 interior_test 3/3 + world·warp·building·전 구역 통과.
  > **⚠️ 성능/테스트 취약성(별도 과제):** 구역 빌드(`_paint_grid`)가 마을 7200칸 `set_cells_terrain_connect`로 **~1.6s**(변종 수 무관·*기존부터*). 전환 연출의 `_indoor` 콜백이 fade(0.22s)+빌드(~1.6s)≈1.8s에 실행되는데 테스트 `_settle` 워치독이 2000ms라 **헤드룸 ~180ms** → 고부하/순차실행 시 interior_test 만물상 진입이 간헐 실패(**클린도 동일** — 내 회귀 아님). 근본 해결 = 빌드 최적화("경계 칸만 terrain-connect + 내부는 직접 채우기"). 게임플레이로도 워프 ~1.6s 프리즈라 우선순위.

## 결과/이행

- `assets/tiles/`: 핵심 4세트(grass_path·path_soil·soil_grass·water_grass) + 변종 4세트(gpv2·gpv3·sgv2·wgv2) 이미지/메타. `combined_terrain_homestead.tres` = 8세트 합성(인자 순서로 id 0길1풀2밭3물 보존, 변종은 뒤).
- `main.gd`: `_build_ground_details()` 호출 비활성, `_harmonize_grass_variants()` = 패스 A(풀 hue/채도 수렴)+B(base 변종 명도 정합). N개 base 변종 자동 처리.
- 검증: `home_full_dump` 인게임(입체 클럼프 풀 + per-cell 변종으로 격자 깨짐 + 일관 톤 + 유기 경계) + 회귀 통과(전 구역 빌드 포함).
- 단일 출처: [ground-composition.md](../design/ground-composition.md) §1.5, [tileset-ruleset.md](../design/tileset-ruleset.md).
- **운영 메모:** PixelLab 서버 혼잡 시 생성이 수십 분 stall 가능(특히 medium shading). 변종은 시드별 stochastic — 일부 stall돼도 완료된 세트만으로 빌드 가능(변종은 추가 folding).
