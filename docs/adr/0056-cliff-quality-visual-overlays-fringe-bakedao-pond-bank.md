# 절벽 품질 3항목 — 순수시각 오버레이 우선(fringe·baked AO·연못 뱅크 로컬 자동화)

> **Status:** accepted (2026-07-07, `grill-with-docs` + owner REV 문서(REV2~통합본) 사인오프). 유실된 Gemini 가이드(§2에서 잘림) 대신 **현 코드(`main.gd`) + 스타듀 불변식 역설계**로 진실원 재정립.
> **연관/정합:** [ADR-0013](./0013-environment-art-32px-native.md)(2D 평면·z축 아님·세이브/카메라 불변) · [ADR-0044](./0044-world-map-richness-pseudo-z-terrain-south-water-topology.md)(pseudo-Z 남향 절벽 §1·물 토폴로지 §2) · [ADR-0053](./0053-homestead-dirt-dominant-ground-overgrown-identity-sealed.md)(흙-지배 지면·순수시각 오버레이 선례) · [ADR-0055](./0055-homestead-reclamation-differential-respawn-weeds-cozy.md)(세이브-안전 오버레이 결) · [cliff-tileset-spec §10.2](../design/cliff-tileset-spec.md)(단계3 남은 품질 3항목의 발원) · [required-assets-roster](../design/required-assets-roster.md)(② baked AO 스펙 등록처).
> **불변 유지:** **데이터-안전 국소 오버레이(Data-Safe Localized Overlay)** — `_grid`·충돌 폴리곤·세이브 스키마·타일 ID 포맷을 원칙적으로 건드리지 않는다. **단 ④만 예외**(기존 뱅크 타일을 유도된 좌표로 *이동* — 새 타일종 0·좌표 동일 → 세이브 불변).

## 맥락

`main.gd`의 남향-only 3티어 절벽 오토타일러(`_autotile_south_cliffs`, [cliff-tileset-spec §10.2] 단계3)는 box-model을 폐기하고 스타듀 절벽 문법(남향 바위벽 + 잔디 립 + 곡선 코너 + front 오버행)을 이미 구축했다. 그 위에 스타듀 레퍼런스 수준의 **시각 깊이감·자연스러움**을 확보할 **품질 3항목(①②④)**이 [cliff-tileset-spec §10.2] 단계3에 "미결(owner 육안 후)"로 남아 있었다.

owner의 Gemini 초안(가이드 ID 178340…, §2에서 잘림)이 세 항목의 코드 매핑을 제시했으나 ⓐ 지목한 코드 훅이 현 아키텍처와 어긋났고(② `_g16_surface`는 절벽을 **스킵**·int 반환, §3은 **없는** Y-Sort/하프타일 콜라이더를 불변식으로 서술), ⓑ 통합 과정에서 ④가 **기하상 죽은 코드**로 흡수됐다(아래 §결정-④). 이 grill이 각 항목의 훅을 실제 코드에 접지하고, 세이브-안전 대원칙 아래 정식화한다. ([ADR-0055]가 같은 패턴 — Gemini 초안의 오류를 grill이 봉합한 — 을 밟았다.)

## 결정

**세 항목 모두 `_grid`·충돌·세이브를 보존하는 순수시각 오버레이(또는 아트 교체)로 실현하고, ④만 "기존 타일의 유도된 좌표 이동"이라는 세이브-안전 예외로 처리한다.** [ADR-0013] 2D 평면 불변식과 프로젝트 오버레이 선례(`_draw_encroach_weeds`·`_build_path_grass_fringe`·front 오버행)를 그대로 잇는다.

### ① 상단 완충 — Fringe 기술 재활용 오버레이 (A안)

- **현상:** 고지 풀(`GROUND`, 고지 마스크 내부)과 절벽 시작점(`CLIFF_LIP`)이 완충 없이 직각 격자로 맞닿아 "칼로 자른 스티커"로 읽힌다.
- **결정:** **`PLATEAU_GRASS` 같은 새 타일종을 신설하지 않는다.** 데이터상 절벽 꼭대기는 여전히 고지 풀이다. 검증된 선례 **`_build_path_grass_fringe`**(길↔풀 유기 raggedness, 순수시각·`_ground_detail_tex` 재활용) 파이프라인을 재활용해, 절벽 배치 완료 후 `_draw_cliff_fringe` 패스(가칭)로 **`CLIFF_LIP` 격자 상단 엣지에 고지 풀이 아래로 삐죽 늘어지는 Ragged 오버레이**를 얹어 그린다. 직각 seam을 비파괴로 소멸.
- **불변:** `_grid`·충돌·세이브 불변. draw-only.

### ② FACE 원근 AO — 아트 에셋 베이크 트랙 이관 (2안)

- **현상:** `cliff_s_face.png`가 y축으로 단순 반복돼 수직 벽면 깊이감이 없다.
- **결정(코드 변경 0):** 남향 벽이 **H=2 고정**(Face 1행 + Base 1행)이고 아트가 이미 Face↔Base 2단 톤을 가지므로, 코드 단 픽셀 세로 감쇄는 **텍스처 뭉개짐 + 렌더 오버헤드**만 유발한다. AO를 **'순수 아트 자산 교체' 트랙**으로 재분류하고, 스펙만 [required-assets-roster]에 등록한다.
- **베이크 규칙(아트 재생성 시):**
  - `cliff_s_face.png` — 상단 0px는 고원 광원 원본 톤(Opacity 1.0), 하단 16px로 갈수록 은은한 감쇄 음영 베이크.
  - `cliff_s_base.png` — 상단 0px는 face 하단 어둠을 이어받아 한 단계 더 어둡게 시작, 마당 맨흙(~72% Base) 접지 하단 16px에 드롭 섀도우 띠(Opacity ~0.65).
- **⚠️ 이중 그림자 금지(정합):** `cliff_s_base.png`는 **이미 [cliff-tileset-spec §10.2] 단계1·2에서 "검정 반투명 접지 그림자"를 구워둔 상태**다(t13 + 그림자 베이크). 위 규칙은 **신규 베이크가 아니라 그 기존 접지 그림자를 "상단 이어받기 → 하단 0.65 드롭섀도우"로 정밀화**하는 것이다 — 그림자를 두 번 얹지 않는다(발치 뭉갬 방지).

### ④ 수변/통로 — 연못 Rect 기반 로컬 Sibling 자동화 (A안)

- **현상:** 연못 북단 뱅크가 `_build_home`의 하드코딩 2행(`SPIRIT_POND_RECT.y-1`=`CLIFF_FACE` 흙 뱅크 / `.y`=`CLIFF_BANK` 돌 레지)에 의존 → 지형 확장 시 유지보수 불가.
- **Full 일반화(B안) 기각:** 물/길 교차 감지·`cliff_bank_water` 전이 타일·코너 롤 = [cliff-tileset-spec §8]이 이미 **S2/S3(나루·삼도천·황천해)로 연기**했고, 전이 아트도 미존재. 연못 하나뿐인 지금 과설계(YAGNI).
- **결정:** 하드코딩을 걷어내되 **전체 맵 스캔이 아닌 `SPIRIT_POND_RECT` 북단 경계선 기반 로컬 sibling 함수 `_autotile_pond_siblings`**를 신설한다. 연못 rect가 확정되면 북단 변(Top Boundary) 좌표 배열을 추출해 y-1행=`CLIFF_FACE`(흙 뱅크)·y행=`CLIFF_BANK`(돌 레지)를 자동 피딩. `_build_cliffs` 결로 매 HOME 재빌드 실행.

- **★ 통합본 §④의 기하 오류 봉합(이 grill의 핵심 교정):** 통합 초안은 ④를 *"`_autotile_south_cliffs` 연산 시 인접 셀이 물이면 국소 IF"* 로 흡수했으나 이는 **절대 발화하지 않는 죽은 코드**다:

  | 요소 | 좌표 |
  |---|---|
  | 고지 마스크(is_hi) = 남향 오토타일러 스캔 영역 | x0..20, y0..26 (`HIGHLAND_E=20`·`HIGHLAND_S=26`) |
  | 영혼빛 연못 | x26..33, y34..40 (`SPIRIT_POND_RECT`) |

  연못은 고지 동단(x20)보다 **동쪽** + 남단(y26)보다 **남쪽**이라 고지 마스크와 전혀 겹치지 않는다 → `_autotile_south_cliffs`는 연못 셀을 스캔조차 하지 않는다. 그래서 **REV4의 별도 `_autotile_pond_siblings`(연못 rect 기반)만이 기하상 유효**하다.

- **세이브-안전 예외 명기:** `CLIFF_FACE`/`CLIFF_BANK`는 SOLID 그리드 타일이라 ④는 3항목 중 **유일하게 `_grid`에 쓴다**(draw 오버레이 아님). 단 **새 타일종 0 + 좌표가 하드코딩과 바이트 동일** → 세이브 포맷·연못 낚시/물뿌리개 앵커([Slice 3] 예약) 좌표 불변. 이것이 대원칙의 유일한 카브다.

## 렌더링·내비게이션 불변식 (§3 재서술 — 현 코드 기준)

통합 초안 §3의 "하프타일 콜라이더 Y:[8px,16px]"·"Y-Sort ON/OFF 레이어"는 **현 엔진에 존재하지 않는다.** 실제 불변식은:

- **충돌 = whole-tile SOLID + 타일종 결정.** 벽 타일(`CLIFF_FACE`·`CLIFF_FACE_BASE`·`CLIFF_BANK`·`CLIFF_CORNER_*`, `WORLD_SOLID_TILES`)은 타일 중심 −8..8 꽉 찬 사각 폴리곤으로 통과 불가. `CLIFF_LIP`은 걷기 O(충돌 루프 제외). **하프타일 콜라이더 신설 안 함** — [ADR-0013] "z축 아님·2D 평면" 유지.
- **front 오버행 = Godot Y-Sort가 아니라 근접 재렌더.** `_draw_front_cliff_faces`가 `_front_cliff_cells_for(플레이어 타일)`로 **같은 열·벽 밑 1~2칸** 벽면 셀을 골라 front 캔버스(z=1)에 벽 텍스처를 다시 그려 캐릭터 상체를 가린다. "3D 원근 접지감"은 **이 순수시각 재렌더**로 얻으며 충돌 기하 변경이 아니다. `_cliff_face_cells`(=`CLIFF_WALL_TILES`, Lip·Bank 제외) 캐시가 매 프레임 그리드 스캔을 없앤다.
- **★ 하얀 사각형 방지 불변식:** front 재렌더는 `CompressedTexture2D`를 `draw_texture`로 즉시모드 렌더하면 GL Compat에서 **플랫/하얀 사각형으로 깨진다**([godot-draw-texture-compressed-flat-gl] · PR#235 봉합). 절벽 벽면 텍스처는 반드시 **`ImageTexture` 변환·캐시** 후 그린다.
- **[ADR-0013] 불변:** 이 항목들 어느 것도 z축·세이브·카메라를 건드리지 않는다.

## 구현 체크리스트 (빌드 슬라이스 = ★워크트리 격리)

> ①④ 코드는 **구현 완료**(아래 §구현 결과), ② 아트 재생성·하얀사각형 라이브 검수는 후속.

- [x] **① fringe 오버레이:** `CLIFF_LIP` 상단 엣지에 ragged 풀 오버레이를 비파괴로 얹고 직각 seam 완화(`_grid`/충돌/세이브 불변). ★훅 = `_build_ground16`(아래 §구현 결과).
- [x] **② baked AO:** `cliff_s_face.png` 하단 감쇄를 **절차적 베이크**(`tools/bake_cliff_face_ao.py` — per-row 곱셈 gradient, strength 0.24·gamma 2.0). `cliff_s_base.png`는 §10.2 접지 그림자 이미 존재 → **미변경(이중 금지)**. 코드(main.gd) 변경 0. Gemini 재생성 시 스크립트 재적용 가능.
- [x] **④ 연못 뱅크 자동화:** `_build_home` 하드코딩 2행 삭제 → `_autotile_pond_siblings`가 `SPIRIT_POND_RECT` 북단에서 뱅크 2행을 유도 생성, **좌표가 하드코딩과 바이트 동일**(연못 앵커 회귀 0).
- [ ] **하얀 사각형 회귀:** 캐릭터가 절벽 밑에 밀착·좌우 이동 시 머리 위 하얀 사각형 아티팩트 0(비-헤드리스 실캡처 픽셀 검수 — 헤드리스 재현 불가). *(owner 라이브 검수)*
- [x] `game/run_tests.sh` 전체 회귀 0·부팅 클린.

## 구현 결과 (2026-07-07, 워크트리 `worktree-adr0056-cliff-fringe-pond-sibling`)

①④ 코드 구현 완료(②는 아트 트랙이라 코드 0). **★설계 대비 훅 정정:** §2 ①은 "`_build_path_grass_fringe` 재활용 `_draw_cliff_fringe` 패스"라 했으나, 실제로 **HOME은 `_build_path_grass_fringe`를 호출하지 않는다** — HOME 지면 오버레이는 흙-지배 flip의 `_build_ground16`(ADR-0053/0054)이고 `_build_path_grass_fringe`는 *그 외 구역* 전용이다(main.gd `if _region == HOME: _build_ground16() else: _build_path_grass_fringe()`). 절벽은 HOME에만 있으므로:

- **① = `_build_ground16` 인라인 fringe 블록**(별도 `_draw_cliff_fringe` 함수 불요 — 오버레이 베이크가 이미 `_build_ground16`에 있어 거기 얹는 게 DRY). `_build_path_grass_fringe`의 grass_out *기술*(신호 있는 물결 `_gd_h01`·`_FR_MAX`/`_FR_DEAD`·blade 팁 감광)만 재활용. ★**방향:** lip 자체가 이미 풀이라 lip 안으로 늘어뜨리면 안 보인다(초록 위 초록) → **`CLIFF_LIP` 위 셀(고지 마당·흙-지배 tan) 하단 픽셀을 풀로 덮어** 풀이 위로 솟구치게 한다(tan↔초록 상단 seam 완화). 풀 소스 = `_bf_grass`. `_grid`·충돌·세이브 불변(위 셀은 GROUND일 때만). home_full_dump 육안 사인오프(tan 마당으로 ragged 풀 tufts 솟음).
- **④ = `_autotile_pond_siblings()`** 신설 → `_build_home`의 하드코딩 2행(`SPIRIT_POND_RECT` 북단 `CLIFF_FACE`+`CLIFF_BANK`)을 대체. `_fill_rect(WATER)`·`_build_cliffs`(=`_cache_cliff_face_cells`) *뒤* 호출 순서 보존(뱅크 `CLIFF_FACE`가 front 오버행에서 제외되게). 좌표 바이트 동일 → 세이브 불변.
- **② = `tools/bake_cliff_face_ao.py`** 절차적 베이크(ADR-0001 glue). `cliff_s_face.png`에 per-row 곱셈 gradient(상단 1.0 → 하단 0.76, gamma 2.0로 하단 집중)로 세로 AO를 구움 — 원본은 하단이 오히려 밝았으나(anti-AO) 이제 하단으로 감쇄해 base와 부드럽게 이어짐. `cliff_s_base.png`는 §10.2 접지 그림자 이미 존재 → **미변경(이중 금지)**. main.gd 변경 0. Gemini 재생성 시 스크립트 재적용 가능(strength 튜너블). home_full_dump 육안 사인오프.
- **검증:** `cliff_test` ⑦(연못 뱅크 rect 유도·폭 전체·멱등)·⑧(fringe 후 `CLIFF_LIP` 격자 불변·오버레이 베이크) 신규 + 전체 회귀 PASS. ①②④ home_full_dump(CPU 합성·헤드리스 O) 육안 사인오프(ragged 풀 tufts·FACE 하단 감쇄·연못 뱅크).

## 결과

- **스타듀 레퍼런스 깊이감 + 세이브-안전 양립.** 세 품질 항목을 세이브 마이그레이션·구조 회귀 없이 얹는다.
- **유지보수 비용 감소:** 연못 뱅크 수동 하드코딩 의존 제거(로컬 rect 기반 자동 파생).
- **아트/코드 분업 명확화:** ②는 아트 트랙(코드 0), ①④는 코드 오버레이/로컬 자동화. Gemini 아트 재생성이 코드를 기다리지 않는다.
- **되돌리기 비용:** §3 불변식 재서술·④ 기하 교정·② 트랙 이관이 통합 초안을 개정하므로 번복 시 재혼선 큼 → ADR로 박제.
- **범위 밖(North Star 유지):** 물/길 full 오토타일 일반화·`cliff_bank_water` 전이 아트·`cliff_beach`는 [cliff-tileset-spec §8]대로 S2/S3.
