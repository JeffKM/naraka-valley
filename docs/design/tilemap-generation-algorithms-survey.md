# 타일맵 생성 알고리즘 전수 서베이 (2026-07-22)

**목적.** 「Dear My Naraka」는 스타듀밸리처럼 맵 전체가 손그림인 "자연스러움"을 목표로 한다. 매크로 레이아웃(동선·구역·건물 위치)은 결정적 손설계로 잠그고, 알고리즘은 오직 마이크로 디테일(경계 유기화·스캐터 분포·변주 배치·길/강 곡률)만 보조한다. 맵은 결정적이어야 하며(플레이마다 바뀌는 랜덤 금지, `hash(cell,zone,seed)` 기반 결정적 랜덤은 허용) 32px 픽셀 그리드 정합을 지킨다.

**방법론.** 9개 알고리즘 계열(오토타일링·셀룰러 오토마타·노이즈 마스크·스캐터 분포·구역 분할·경로/강 곡률·경계 추출·제약 기반 생성·하이브리드/최신)을 계열별 병렬 웹 리서치로 전수 조사하고, 각 기법을 「어느 자연스러움 문제를 푸는가 → 스타듀 정합성 → 채택/조건부/이미구현/기록만/기각 → 코드 훅」 축으로 평가했다. 여러 계열에서 중복 등장한 기법(도메인 워핑·Catmull-Rom·Poisson-disk)은 하나로 병합했다.

**기존 구현 기준선(비교 대상).** 손그림 Wang 16타일 잔디↔흙 전환(`_bake_grass_dirt_wang`) · CA 클럼프 마스크(`_G16_GRASS_PATCHES`, 문턱 0.68) · 구역-키드 가중 스캐터 테이블 · 밭·길 직선 사각 + `_soften_field_edges`(±2px) · 물↔흙 손그림 형태 마스크(셀별 월드위상 합성) · pseudo-Z 남향-only 절벽 오토타일러 · 남향 물 축.

**기각 확정선(재론 금지, 조사·기록만).** 지상 지형 WFC · 듀얼그리드/Godot TileMapLayer 지형 전환 · 물가 Wang base합성·절차 후처리 재시도 · 밭·길 래그드 경계.

---

## 메인 표 (verdict 순: 채택 → 조건부 → 이미구현 → 기록만 → 기각)

### 채택 (Adopt)

| 알고리즘 | 계열 | 용도(자연스러움 문제) | 스타듀 정합성 | 채택 근거 | 코드 훅 |
|---|---|---|---|---|---|
| 외톨이 영역 제거 / 홍수채움 정리 (Isolated-region removal, flood-fill min-size cleanup) | CA | 마스크·스캐터의 '떠다니는 1셀 얼룩=노이즈 카펫' 제거(프로젝트 반복 통증) | 매우 높음(손그림엔 문맥 없는 단독 픽셀 없음) | 저비용·결정적·매크로 불변. '따로 떨어진 짙은 타일'·'2573색 노이즈 카펫' 문제의 직접 해법. 다수결 평활과 상보 | `_G16_GRASS_PATCHES`·가중 스캐터 산출 직후 min-size flood-fill 정리 패스(신규 유틸), `_soften_field_edges`와 병렬 경계-정리 단계 |
| 그래디언트 노이즈 OpenSimplex2 (gradient noise, FastNoiseLite SIMPLEX_SMOOTH) | 노이즈 | 모든 상위 노이즈 기법의 결정적·등방 원천 신호 | 높음(마스크 입력으로만 쓰면 절차티 0). **Perlin은 축정렬 줄무늬로 배제** | 순수 hash 난수와 달리 공간상관을 태생적으로 줘 '유기적 뭉침'을 반복 없이 1샘플로. Godot 내장·결정적, 도입비용 최소(ADR-0001 자작툴 금지와 정합) | 신규 공용 유틸 `_mask_noise(FastNoiseLite,x,y)` — CA·스캐터 난수 소스의 단일 진입점, seed=월드시드 |
| fBm 옥타브 합성 (Fractional Brownian Motion) | 노이즈 | 저주파 매크로 + 고주파 마이크로를 한 신호로 결합 | 높음(2~3옥타브로 절제 시). 과다 옥타브=컴퓨터 지형티 | 우리가 원하는 '매크로/마이크로 분리'가 곧 fBm의 정의. FastNoiseLite 내장(octaves·lacunarity·gain), 파라미터 노출만으로 도입 | `_mask_noise` FRACTAL_FBM(2~3옥타브) → `_harmonize_grass_variants` 인덱스·`_G16_GRASS_PATCHES` 문턱 구동 |
| 도메인 워핑 (Domain Warping, f(p+fbm(p))) — *노이즈·경계추출·하이브리드 병합* | 노이즈 | 잔디↔흙 Wang 경계·CA 패치가 격자/원형으로 규칙적인 문제를 경계 '위치'만 유기적으로 흔들어 해결 | 높음(**저진폭 ±1~2px 한정**). 강하게 걸면 기각된 '절차 후처리 손댄 느낌'이 됨 | 손그림 타일에 손대지 않고 판정 좌표만 워프 → owner가 반려한 격자 위상 불연속·손댄 느낌 회피. 우리 최대 약점(원형 CA·격자 경계)의 정면 해법. 결정적(seed) | `_bake_grass_dirt_wang` 코너 샘플·`_G16_GRASS_PATCHES` 문턱 좌표에 저진폭 fbm offset. **밭·길·확정 물가 제외** |
| 주파수대 분리 (저주파 macro / 고주파 micro band separation) | 노이즈 | 매크로 손설계 존중 + 셀마다 반복 없는 미세 다양성 | 최상(구역-키드 스캐터 철학의 노이즈판) | 새 개념 아니라 우리 지향의 정식화. 2-노이즈 저비용·결정적 | 저주파 `_macro_noise`→스캐터 가중·매크로 틴트, 고주파 `_micro_noise`→`_harmonize_grass_variants` 변종·per-cell 밝기 |
| 지터드 그리드 샘플링 (Jittered Grid / Stratified) | 스캐터 | 스캐터 좌표가 순수 랜덤이면 뭉침·공백, 순수 격자면 줄무늬 — 그 중간의 손그림 산포 | 매우 높음(변위 폭 셀 40~70%면 격자흔적 소멸) | 결정적(해시)·저비용·정합 3박자. Bridson 이웃검색 없이 블루노이즈 80% 확보하는 표준 저가 대체재. 가장 비용 대비 효과 큼 | 가중 스캐터 테이블의 셀내 좌표 결정을 `hash(cell)→jitter` 결정 변위로 교체, `_SCATTER_JITTER` 레버 |
| 군집 스캐터 Neyman-Scott / Matérn (부모-자식 점과정) | 스캐터 | 균일 분포는 '심은 티' — 나무는 숲, 꽃은 패치로 모여야 유기적 | 높음(숲·과수 나무무리·채집 꽃패치·잡초무리) | 계열 내 '군집성' 축 담당 유일 기법. 부모=손설계 앵커 또는 해시(결정적). 부모밀도=군락수·자식반경=군락크기 직관 제어. 개간 '근원지 전파' North Star와 개념 연결 | 신규 훅 + CA 마스크 보완. flower_patch·orchard/숲·reclaim `_weeds` 재점령 분포에 부모-자식 산포 |
| 밀도 마스크 결합 / 거부 샘플링 (Density-Mask multiplier) | 스캐터 | 구역-키드 테이블만으론 경계에서 밀도가 '뚝' 끊김(흙↔잔디 통증의 오브젝트층) | 높음(저주파 마스크면 절차티 없이 큰 밀도 변화만) | 다른 모든 스캐터 기법 위에 얹는 곱셈기 레이어, 충돌 없이 결합. UE PCG·biome painter 업계 표준 | 가중 스캐터 채택확률에 곱: `base×zone_weight×noise_mask×(경사/거리제약)`. CA 클럼프도 이 필드 한 항으로 일반화 |
| Poisson-disk 최소반경 리젝션 (blue-noise, Bridson) — *스캐터·구역분할·하이브리드 병합* | 스캐터 | 겹침·뭉침 없는 최소간격 보장 산포(나무·바위가 파고들지 않게) | 매우 높음(잡초·돌·나무 '겹치지 않는 산포') | **라이브=해시격자 최소반경 리젝션 필터(저비용·결정적) 채택** / 순차 stateful Bridson=대형 프롭 오프라인 프리베이크 형태로만(결정성 관리) | 신규 `_scatter_poisson_reject`(가중 테이블 배치 단계 필터). 대형 프롭은 결정적 점집합 프리컴퓨트 |
| 센트리페탈 Catmull-Rom 스플라인 (+ 가이드라인 사행) — *경로·경계·하이브리드 병합* | 경로·강 | 손설계 길/강 중심선이 직선 폴리라인이라 각짐 — 웨이포인트는 유지한 채 손그림처럼 굽힘 | 매우 높음(interpolating=웨이포인트 통과=손맛). centripetal이 loop/자기교차 방지 | 우리 원칙(매크로=손설계, 알고리즘=마이크로 곡률)과 정확 일치. 제어점만 결정적이면 곡선 전체 결정적. **밭은 직선 유지, 소로·강 중심선만** | 신규 길·강 중심선 생성기: waypoint→centripetal 곡선→폭 브러시→`_soften_field_edges` 마감 |
| Chaikin 모서리 깎기 스무딩 (corner-cutting subdivision) | 경계추출 | 연못·클럼프·강 경계가 마스크에서 계단·톱니로 나옴 — 붓 흐름처럼 매끈 | 매우 높음(노이즈 웨블 아닌 '깎기'라 손그림 붓결) | 자연 경계 유기화 핵심. 결정적. **iteration cap ≤3(과반복=특징 소실)**. 밭·길엔 절대 금지(래그드 기각) | water 손그림 마스크 생성(marching squares 추출 뒤)·CA 클럼프 윤곽. 밭·길 미적용 |
| 경계 디더링 / 프린지 스티플 밴드 (boundary dithering fringe) | 경계추출 | 잔디↔흙 전환이 칼 같은 선 — 경계밴드에 tuft/tan 픽셀 흩어 부드럽게 | 매우 높음(실제 픽셀 아티스트 손 기법, 절차티 0) | 가장 안전·정합. 기존 스캐터 테이블을 '경계밴드 가중'으로 확장(별도 시스템 불요). owner P2 재정의(경계 소멸)와 일치. Bayer보다 해시 랜덤이 tuft 유리 | 스캐터 테이블에 '경계 근접도' 가중(Wang 밴드 ±1~2px tuft/tan 확률↑). 자연 경계 전용, 결정적 해시 |

### 조건부 (Conditional)

| 알고리즘 | 계열 | 용도 | 스타듀 정합성 | 조건부 근거 | 코드 훅 |
|---|---|---|---|---|---|
| 8비트 블롭 47타일 (blob autotiling, S-V2E2) | 오토타일 | 16타일로 못 내는 넓은 곡률·복합 코너(히어로 경계) | 높음(품질), 47장 손그림 아트비용 최대 | 16타일로 충족되면 불요. owner가 특정 히어로 경계에서 '곡률 부족' 지적 시 그 경계 한정 승격. 전역 도입 반대. **승격 시 47 전 케이스 채워라(16만 넣으면 오배치 '침묵의 살인자')** | `_bake_grass_dirt_wang` 인덱싱을 코너비트→blob 47로 확장하는 히어로 경계 게이트 분기 |
| 쿼터 타일 오토타일링 (Quarter-tile, 5~20 서브타일) | 오토타일 | blob 코너 품질을 훨씬 적은 손그림 매수로 | 보통(곡률 반경 half-tile 제한·다지형 확장 난) | 신규 지형 종 다수 추가(절기별 지면 변종) 시 아트 절감 카드로만. 현재 16타일 파이프라인 도는 상황에선 재작업>이득 | 지면 합성기를 쿼터 단위 재구성(=`_bake_grass_dirt_wang` 대체 규모). 절기/신규 지형 확장 시점만 |
| 다수결 평활 패스 (Majority-vote smoothing, 1~2 pass) | CA | 절차 마스크의 지글거리는 1셀 노이즈 경계를 매끈한 곡선으로 | 매우 정합(4회+ 과평활=밋밋) | `_G16_GRASS_PATCHES`가 시드+성장만 하고 후처리 약함. 조건: 결정적 해시·1~2패스·매크로 불변 | `_G16_GRASS_PATCHES` 뒤 다수결 1패스, 물↔흙 경계 물셀 판정에도 훅 가능 |
| Life-like B/S 규칙 튜닝 (rulestring, majority B5678/S45678) | CA | 클럼프 밀도·경계 거칠기를 구역별 한 손잡이로 조율 | 정합(보수적 값만). replicator/chaotic은 절차티 강 | 새 시스템 아니라 기존 CA 문턱을 B/S 레버로 노출. 조건: majority류 안정 규칙·결정적 시드·상수 잠금 | `_G16_GRASS_PATCHES` birth/survive를 구역-키드 B/S 상수로 파라미터화 |
| 간이 침식/적하 평활 (cell-based drip smoothing) | CA | 길·강 곡률을 '흐른 듯' 부드럽게 | 정합(아주 약하게만). 본격 조형은 절차 시뮬티 | 물가 마스크엔 침식 재시도 **금지**(기각 정책). '강/길 곡률'이란 별개 문제에 최소형(저지대 향한 결정적 스무딩 1패스)만 | 신규 길·강 폴리라인 곡률 스무딩(물가 마스크 미적용, `_soften_field_edges`와 별개) |
| 노이즈 문턱 마스크 (Noise threshold mask) | 노이즈 | 패치를 '뭉치되 규칙적이지 않게' 배치(주파수/문턱 2노브) | 정합(워핑 결합 시 윤곽까지 손그림스) | CA 클럼프와 목적 겹치는 대체재. CA는 이미 owner 승인·회귀 통과라 무조건 교체 리스크. **신규 패치존(이끼·꽃밭)만 노이즈, 기존 CA는 워핑 보강. 중복 유지 금지** | `_G16_GRASS_PATCHES`·스캐터 '뭉침 확률' 입력에 `_mask_noise>threshold` |
| 재분포 / power-curve 리맵 (Redistribution) | 노이즈 | 잔디 vs 흙(72/28) 커버리지 비율을 문턱 하나로 정확히 | 중립(순수 튜닝, 절차티 0). 흙지배 flip을 재현정확화 | 단독 효과 없고 문턱마스크/fBm 채택에 종속. 흙지배 flip·밀도 등 owner 수치 지시에 실효 | `_build_ground16` 문턱 선택 직전 remap(`_G16_GRASS_THR`·72/28을 exponent+threshold로) |
| Ridged / Billow 노이즈 (abs-fold) | 노이즈 | 능선선(강 사행 가이드)·둥근 뭉치(잔디언덕 밀도) | 부적합(고도장 지형)/국소 마스크 셰이핑은 쓸모 | heightfield 지형은 pseudo-Z 손설계와 충돌→미훅. billow=둥근 패치, ridged=사행 능선의 마스크 도구로만, 실제 필요 확인 시 | 강/길 곡률 가이드에 FRACTAL_RIDGED 오프셋, 잔디언덕 문턱에 billow. **지형 고도용 미훅** |
| Mitchell 최선후보 (Best Candidate 블루노이즈) | 스캐터 | 반경 미정/점수 유동 시 블루노이즈 | 중간(룩은 지터드와 사실상 동일, 비용 O(N²)) | 라이브 도입 이유 약함(지터드가 싸게 동일 룩). 재사용 타일러블 점 스탬프 오프라인 베이크만 | 오프라인 도구(파이썬 프리베이크 리소스). 런타임 미훅 |
| BSP 재귀 분할 (Binary Space Partitioning) | 구역분할 | 손설계 넓은 밭 구역을 다양한 크기 사각 블록/두렁으로 세분 | 밭=인공물 직선 사각이라 정합. 방-복도 던전용은 즉시 절차티 | 매크로 배치용 아니라 '밭 세분 헬퍼'로 국한 시 유용·결정적. 현 밭은 손배치라 필수 아님(대형 단일밭 두렁 변주 시). 던전(추후)엔 정식 후보 | 신규: seed BSP 세분→블록 경계선을 `_soften_field_edges`에 공급 |
| Voronoi + Lloyd 완화 (centroidal Voronoi) | 구역분할 | 손배치 구역 내부를 '보이지 않는' 변종 territory로 분할 | 경계 렌더=각진 다각형티(금지)/영역 라벨·무게중심은 무해 | 경계 시각화 기각, '보이지 않는 영역 분할기'로만 채택 가치. Lloyd가 CA/스캐터 뭉침 균등화 | 스캐터 서브레이어: seed Voronoi로 territory, Lloyd 1~2회. 경계는 Wang/CA가 흡수 |
| Delaunay + MST 연결 그래프 | 구역분할 | 손설계 구역·건물 사이 '어떤 길이 자연스러운가'의 동선 위상 뼈대 | 양호(위상만 잡고 픽셀은 기존 곡률 렌더) | '경로 픽셀' 아닌 '위상 결정'에만. 앵커=손설계라 정책 무충돌. 길 대체로 손배치라 필수 아님(구역 수 증가 시) | 설계 보조: 앵커→Delaunay/MST 간선 후보→손검수→`_build_path_grass_fringe` 렌더 |
| 베지어 코너 라운딩 (Quadratic/Cubic Bezier) | 경로·강 | 길 T자·L자 교차부 각짐을 국소 라운딩 | 높음(제어점 비통과라 격자 이탈 주의) | Catmull-Rom과 상보. 전 구간=Catmull-Rom, 특정 코너만 둥글리기=베지어(국소·저렴). 좁은 1칸 복도 교차부 예외만 | 신규(선택): 중심선 폴리라인 꺾임점 국소 후처리 |
| 제약 노이즈 엣지 / 재귀 중점변위 (Noisy Edges, non-crossing) | 경로·강 | 강 경계를 굽이치되 자기·이웃 교차 안 하게 | 중간(저진폭 아니면 프랙탈 지글거림). 저자도 '해안·강엔 최선 아님' 인정 | 물가는 손그림 마스크 락(재도입 금지). '자기교차 원천 봉쇄' 원리만 Catmull-Rom 웨이포인트 검증에 차용. 저진폭≤0.25·강 축 한정 | 남향 물 축 중심선 흔들기에 제약 원리만. 손그림 물가 마스크 불가침 |
| 가중 이방성 A* 유기 라우팅 (weighted anisotropic A*) | 경로·강 | 길이 절벽·물을 부자연스레 관통 — 지형 피해 돌아가는 곡률 | 중간~높음(원시 출력 계단형→반드시 스무딩) | pseudo-Z SOLID·남향 물을 장애 비용으로 결정적 라우팅. 조건: 비용맵 손튜닝·Catmull-Rom 스무딩 필수·끝점은 사람 지정. 전면 자동생성 금지 | 신규: 절벽 SOLID·물 셀을 비용으로 경로 산출→Catmull-Rom→길 셀→`_soften_field_edges` |
| Marching Squares 컨투어 추출 | 경계추출 | CA/연못 마스크(비트맵)→벡터 폴리라인(Chaikin 입력) | Wang 16타일 전환과 위상 동형=런타임 전환은 이미구현/금지, 추출기로만 무해 | 런타임 전환 재제안=듀얼그리드 금지선. **베이크 타임 윤곽 추출기로만** 신규 가치. 결정적 | 신규 오프라인: `_G16_GRASS_PATCHES`·연못 마스크→폴리라인→water 손그림 마스크 입력 |
| Metaball / SDF blob 윤곽 | 경계추출 | 연못·꽃패치의 둥근 유기 blob을 원 몇 개로 결정적 생성 | 중간(CA보다 둥금·'고인 물'). 매끈하면 절차 blob티 | 확정 water 마스크 대체 금지(절차 물가 재시도 저촉). **손그림 마스크 없는 신규 요소(피안화 패치·여분 웅덩이) 초안 blob 생성기**로만, Chaikin+손보정 승격 | 신규 오프라인: SDF 합 문턱→blob→marching squares→Chaikin. 기존 water 미적용 |
| 프리팹·청크 스탬핑 (hand-drawn micro-patch stamping) | 하이브리드 | per-cell 절차 변주의 '균질 노이즈 카펫'을 손그림 덩어리로 | 높음(스탬프 소스가 손그림→절차티 원천 차단). 매수 적으면 반복티 | 프롭 스캐터(나무·바위)가 이미 개별 스탬프에 근접. 2~5칸 손그림 클러스터로 격상 시 뭉침이 의도된 미학. 조건: 손그림 팔레트 아트비용·결정적 위치·포아송 겹침 제어 | 신규 `_stamp_handpainted_clusters`(스캐터 상위 레이어). 에셋 로스터 여유 볼 것 |

### 이미구현 (Already Implemented — 확증)

| 알고리즘 | 계열 | 스타듀 정합성 | 판정 근거 | 코드 훅 |
|---|---|---|---|---|
| 코너 매칭 Wang 2-코너 16타일 (Corner-matching V2) | 오토타일 | 매우 높음(스타듀 손그림 트랜지션이 사실상 이 계열) | `_bake_grass_dirt_wang`이 정확히 이 방식. Boris 분류상 V2가 표현력/아트비용 최적점=업계 표준. 신규 아니라 '현 채택이 정답임을 확증' | `_bake_grass_dirt_wang` 유지 |
| 4비트 카디널 비트마스크 (marching-squares autotiling) | 오토타일 | 보통(방향 제한 선형 경계엔 충분) | 남향-only 절벽 오토타일러가 이 계열. 자유도 인위 축소로 4비트로 충분. **지형 면 경계 확장 금지**(코너 품질=corner-Wang 담당) | 절벽 남향-only 오토타일러(유지) |
| CA 시드-성장 클럼프/패치 마스크 | CA | 정합(스타듀 잔디/잡초 뭉침) | `_G16_GRASS_PATCHES`+가중 스캐터가 실체. 신규 아니라 다수결 평활·flood-fill 정리를 얹는 방향 | `_G16_GRASS_PATCHES`+스캐터(기존) |
| 구역-키드 가중 스캐터 테이블 | 스캐터 | 적합(가동 중) | '무엇을/얼마나'는 정하나 '어디에'(좌표·간격·군집·전이)는 부족→지터드/Poisson/Neyman-Scott/밀도마스크가 빈틈 채움 | 기존 장치 자체(확장 지점=위 채택 레이어들) |
| 손그림 매크로 + 절차 마이크로 하이브리드 | 하이브리드 | 최상(스타듀=전 손그림 Tiled/tIDE) | 저장소가 이미 이 철학. 스타듀 사실이 우리 아키텍처를 업계 근거로 승인. **교훈: 알고리즘을 매크로로 승격시키지 말 것** | 전 기준선 장치의 상위 원칙 |

### 기록만 (Record Only — 채택 재론 금지 또는 미채택)

| 알고리즘 | 계열 | 미채택 근거 | 재검토 여지 |
|---|---|---|---|
| 엣지 매칭 Wang (Edge-matching E2) | 오토타일 | 경계가 코너에 박혀 notch. 동일 16예산으로 corner가 명백 우월(Strout·Boris) | 선형 도로 세그먼트(별 계열이 더 적합) |
| 듀얼그리드 (Dual-grid, 오프셋 16타일) | 오토타일 | **프로젝트 기각 확정**([[tileset-single-source-coherence-spike]]: 코너비트로 이미 동형, 재제안 금지). 오프셋 표시 grid가 라이브 픽셀 합성·결정 위상과 어긋남 | 없음 |
| Godot 내장 Terrain Set 오토타일러 | 오토타일 | **기각 확정**(TileMapLayer 전환=무격자 정체성 붕괴). 라이브 셀별 월드위상 합성 포기 불가. 교훈: 47 전 케이스 안 채우면 오배치 | 없음 |
| CA 동굴 생성 4-5 rule | CA | 지상=결정적 손설계(지상 WFC 기각과 동일 논리) | **던전/광산 슬라이스** 열릴 때 |
| OBB 재귀 파셀 분할 (CityEngine식) | 구역분할 | 우리 밭=축정렬 인공물 확정→비직교 이점 불필요. BSP로 대체 | 비스듬한 유기 필지 미학 택할 시 |
| 그래프 그래머 / 방-인접 조닝 | 구역분할 | 매크로 조닝=손설계 확정(ADR-0044) 침범. 방-복도 절차티 | 손위상 그래프 명세→인접 제약 검증 린터(설계타임) |
| 컨스트레인트 레이아웃 / ASP 솔버 | 구역분할 | 런타임 배치 불필요·손맛 없음 | 손배치 무결성 검증(건물 겹침·문폭 ADR-0046) 설계타임 도구 |
| 1D 중점변위 프랙탈 라인 | 경로·강 | 밭·길=직선 확정(역행). 자연 경계=손그림 락. Noisy Edges가 상위호환 | 참고용 수식만 |
| 편향 랜덤워크 / 취보 경로 | 경로·강 | 미적 통제력이 Catmull-Rom/A*보다 열등. 지상=손설계 | 지하 던전 통로 초안 |
| 입자 수력침식 강 미앤더 시뮬 | 경로·강 | 결정성·경량성·손설계 원칙 모두 역행. 물=남향 손그림 락 | 사행 형태 레퍼런스·이론 상한 |
| Dart-throwing / Lloyd relaxation | 스캐터 | Dart=Bridson이 대체(느림). Lloyd=과-균일화로 손그림 유기감 해침 | 없음(우리는 '고른 듯 흩어진'을 원함) |
| WFC 심플 타일드 모델 | 제약 | **지상 기각 확정**(가중 스캐터 대체). 우리 손그림 Wang이 이 모델의 결정적 코너비트 축약=필요분 이미 사용 | 던전(Slice5) 방-복도 조립 옵션 |
| WFC 오버래핑 모델 | 제약 | 지상 기각. 국소 유사성만으론 매크로 손설계 침해(흐물흐물·반복 노이즈) | 없음 |
| 모델 신서시스 (Merrell) / 블록 수정 | 제약 | 지상 기각. WFC 계보 원류·스캔라인 결정성만 기록. '손설계 경계로 알고리즘 가두기'는 우리 밭 직선+경계 소프트닝이 이미 구현 | 던전·특정 구역 변주 발상 |
| MarkovJunior (패턴 재작성 문법) | 제약 | 지상 기각. 대역 구조 성장은 아티스트 제어권 높으나 지상엔 과함 | **던전(미로·연결 경로)엔 WFC보다 적합** |
| 비국소 제약 (DeBroglie: Path/Count/Separation) | 제약 | WFC 엔진 기각→통째 도입 미채택. 백트래킹=결정성·비용 문제 | Separation(min-dist)·Count 캡을 엔진 없이 결정적 스캐터에 발상 차용(스캐터 계열 몫) |
| AC-4 아크 일관성 + 백트래킹 | 제약 | 솔버 메커니즘(미학 아님). 가변·비결정 실행시간이 결정적 빌드와 상충. 코너비트 즉시 룩업이 이 비용 원천 회피 | 지상 WFC 재제안 시 결정성·비용 리스크 근거 |
| LLM 보조 저작-타임 배치 | 하이브리드 | 런타임=비결정·정규화 필요→결정성·손그림 원칙 둘 다 깸 | 저작-타임 초안(스캐터 가중·프롭 로스터 제안·Tiled 손배치 보조) |

### 기각 (Rejected)

| 알고리즘 | 계열 | 기각 근거 |
|---|---|---|
| 반응-확산 / 튜링 패턴 (Gray-Scott) | CA | 계산 비용 큼·결과 절차티 강·이산 손그림 타일 배치 감각과 상충. per-cell 변종+CA+스캐터로 이미 충분. 커버리지 차원 기록 |

---

## 계열별 뉘앙스·트레이드오프·출처

### 1. 오토타일링 계열
핵심 좌표: Boris Kravchenko의 타일셋 분류(Cell-Identification-Symmetry-Restriction). 우리 자연스러움 문제의 답은 corner-matching(V2) vs edge-matching(E2) × 타일수/표현력/아트비용 3축에서 정리된다. 결론: 손그림 Wang 16타일이 정확히 V2(업계 표준 최적점)이며, edge·dual-grid·Godot terrain set은 우리 아키텍처와 상충하거나 기각 확정. 신규 여지는 (1) 히어로 경계 47-blob 승격, (2) quarter-tile 아트 절감 — 둘 다 조건부, 16타일로 충족되면 불요. 스타듀 자체가 손그림 corner V2 계열이라 방향 일치.
- Wang 2-Corner Tiles (Joe Strout): https://dev.to/joestrout/wang-2-corner-tiles-544k
- Classification of Tilesets (BorisTheBrave): https://www.boristhebrave.com/2021/11/14/classification-of-tilesets/
- Autotiling Interactive Guide (Red Blob): https://www.redblobgames.com/articles/autotile/claude/
- Quarter-Tile Autotiling: https://www.boristhebrave.com/2023/05/31/quarter-tile-autotiling/
- dual-grid-tilemap-system-godot (Jess Hammer): https://github.com/jess-hammer/dual-grid-tilemap-system-godot
- terrain-autotiler (dandeliondino): https://github.com/dandeliondino/terrain-autotiler

### 2. 셀룰러 오토마타 계열
실익 3: (1) **채택=외톨이 영역 제거(flood-fill)** — 반복 통증 '짙은 타일·노이즈 카펫'의 저비용·결정적 직접 해법. (2) **조건부=다수결 평활 1~2패스 + life-like B/S 튜닝** — `_G16_GRASS_PATCHES` 경계 노이즈 매끈화·구역별 밀도 노브. (3) 기존 CA 클럼프는 이미구현이라 위 후처리를 얹는 방향. 침식은 물가 마스크 금지·길/강 곡률 최소형만 조건부. 지상 CA 동굴=던전 재검토, 반응-확산=기각. 모든 제안 결정적 해시·매크로 불변 전제.
- Cellular Automata Cave (RogueBasin): https://www.roguebasin.com/index.php/Cellular_Automata_Method_for_Generating_Random_Cave-Like_Levels
- CA Cave Generation (gridbugs): https://www.gridbugs.org/cellular-automata-cave-generation/
- Mapgen CA (Cogmind): https://www.gridsagegames.com/blog/2014/06/mapgen-cellular-automata/
- Life-like CA (LifeWiki): https://conwaylife.com/wiki/Life-like_cellular_automaton
- Reaction-Diffusion Playground: https://jasonwebb.github.io/reaction-diffusion-playground/

### 3. 노이즈 마스크 계열
최대 기여=**도메인 워핑(채택)**: 기각 목록(물가 Wang base합성·절차후처리)과 축이 다르다 — 손그림 타일에 손대지 않고 경계 '위치 선택'만 유기적으로 흐트러뜨려 owner가 반려한 '손댄 느낌/격자 위상 불연속'을 회피. 최대 이점: Godot 4 FastNoiseLite에 OpenSimplex2·FBM·Ridged·DomainWarp 전부 내장→자작엔진 없이 파라미터 노출만으로 도입(ADR-0001 정합). **Perlin/구형 value는 축정렬 줄무늬로 배제, SIMPLEX_SMOOTH 사용.** 노이즈 문턱은 CA와 중복 유지 금지. Ridged 고도장은 pseudo-Z 절벽 원칙과 충돌(heightfield 미훅).
- OpenSimplex noise (Wikipedia): https://en.wikipedia.org/wiki/OpenSimplex_noise
- Godot FastNoiseLite: https://github.com/godotengine/godot/blob/master/modules/noise/doc_classes/FastNoiseLite.xml
- Red Blob — Making maps with noise: https://www.redblobgames.com/maps/terrain-from-noise/
- Inigo Quilez — Domain Warping: https://iquilezles.org/articles/warp/
- Book of Shaders — fBm: https://thebookofshaders.com/13/
- libnoise Tutorial 5 (Ridged): https://libnoise.sourceforge.net/tutorials/tutorial5.html

### 4. 스캐터 분포 계열
계열은 상호배타가 아니라 레이어드 결합: **[무엇=가중테이블] × [어디=지터드/Poisson] × [군집=Neyman-Scott] × [밀도전이=마스크]**. 권고 3줄: (1) 즉시 채택=지터드 그리드(순수 랜덤 좌표→해시 변위). (2) 다음 축=군집성 Neyman-Scott(부모=손설계 앵커/해시). (3) 그 위에 density-mask 곱셈기(구역 경계 밀도 뚝끊김=흙↔잔디 통증의 오브젝트층). Bridson=대형 프롭 오프라인 프리베이크만. Mitchell/Lloyd/dart-throwing=라이브 미도입. 모든 랜덤 `hash(cell,zone,seed)`.
- Stratified Sampling (pbr-book): https://pbr-book.org/3ed-2018/Sampling_and_Reconstruction/Stratified_Sampling
- Bridson Fast Poisson Disk (SIGGRAPH 2007): https://www.cs.ubc.ca/~rbridson/docs/bridson-siggraph07-poissondisk.pdf
- Neyman–Scott process (Wikipedia): https://en.wikipedia.org/wiki/Neyman%E2%80%93Scott_process
- Biome Painter (Narkowicz): https://knarkowicz.wordpress.com/2019/08/11/biome-painter-populating-massive-worlds/
- Mitchell's Best Candidate (demofox): https://blog.demofox.org/2017/10/20/generating-blue-noise-sample-points-with-mitchells-best-candidate-algorithm/

### 5. 구역 분할 계열
매크로 배치는 손설계 확정(ADR-0044·안식 재설계)이라 자동 조닝 대부분 기록만/기각. 살아남는 쓰임: (1) 손설계 큰 구역 **내부**를 밭 블록(BSP)·변종 territory(Voronoi 비가시)로 미시 분할, (2) 구역 사이 동선 위상(Delaunay+MST). **함정: Voronoi 폴리곤 각진 셀티·그래프 그래머 방-복도 절차티는 경계 렌더에 직접 쓰지 말 것.** Poisson은 스캐터 계열과 중복(거기서 관리).
- BSP Map Gen (MaxGCoding): https://www.maxgcoding.com/dungeon-gen-with-bsp
- Lot Subdivision (martindevans): https://martindevans.me/game-development/2015/12/27/Procedural-Generation-For-Dummies-Lots/
- Polygon map generation (Amit Patel): https://simblob.blogspot.com/2010/09/polygon-map-generation-part-1.html
- Graph rewriting (Shaggy Dev): https://shaggydev.com/2022/11/20/graph-rewriting/
- Map Generation Speedrun with ASP (EIS): https://eis-blog.soe.ucsc.edu/2011/10/map-generation-speedrun/

### 6. 경로·강 곡률 계열
권고 파이프라인: **[손 배치 웨이포인트] → (선택)[가중 A* 지형 존중 라우팅] → [센트리페탈 Catmull-Rom 곡선화] → [폭 브러시 칠] → [`_soften_field_edges` ±2px 마감]**. 정합성 경계: 밭·길=인공물 직선(soil-boundary 확정)이라 곡률은 소로·강 중심선에만. 물↔흙 물가=손그림 형태 마스크 락→곡률로 물가 재생성 금지. 클로소이드/오일러 나선은 타일 길엔 과잉(Catmull-Rom 충분).
- Catmull-Rom Splines (Mika): https://qroph.github.io/2018/07/30/smooth-paths-using-catmull-rom-splines.html
- Procedural Generation of Roads (Galin & Peytavie): https://perso.liris.cnrs.fr/egalin/Articles/2010-roads.pdf
- Red Blob — Noisy edges: https://www.redblobgames.com/maps/noisy-edges/
- Meandering Rivers (Nick McDonald): https://nickmcd.me/2023/12/12/meandering-rivers-in-particle-based-hydraulic-erosion-simulations/

### 7. 경계 추출·유기화 계열
판정: (1) Marching squares는 손그림 Wang 전환과 위상 동형=런타임 전환은 이미구현/재제안 금지(dual-grid 금지선), 단 마스크→벡터 윤곽 '추출기'로만 조건부. (2) 즉시 채택 2건=Chaikin(자연 경계 곡선화, 밭·길 제외)·경계 디더 프린지(스캐터 테이블 경계밴드 가중, owner P2와 일치). 파이프라인 시너지: **CA/metaball 마스크 → marching squares 윤곽 → Chaikin/Catmull-Rom 스무딩 → 손그림 형태 마스크 승격 → 경계 디더 프린지**. 가드레일: owner 기각선 3개 저촉 방지 위해 자연 경계 전용 스코프 락 + 저진폭 + 결정적 해시.
- Chaikin's Algorithm (K. Joy, UC Davis): https://www.cs.unc.edu/~dm/UNC/COMP258/LECTURES/Chaikins-Algorithm.pdf
- Marching squares (Wikipedia): https://en.wikipedia.org/wiki/Marching_squares
- Metaballs / SDF blobs: https://thisisgrow.com/labs/signed-distance-blobs
- Dithering for Pixel Artists: https://pixelparmesan.com/blog/dithering-for-pixel-artists

### 8. 제약 기반 생성 계열
전 계열 verdict '기록만': 지상 지형 제약 기반 생성(특히 WFC)이 명시 기각([[wfc-rejected-overworld-scatter]])이고 매크로=손설계와 층위 충돌. 시사점 3: (1) 우리 손그림 Wang 16타일 인접표=Simple Tiled Model의 결정적 코너비트 축약→필요분 이미 구현·전파/백트래킹 가변 비용을 즉시 룩업으로 회피(격자티는 솔버 부재 아닌 위상 불연속 문제). (2) 'Modifying in Blocks'·DeBroglie Separation/Count는 엔진 없이 발상만 떼어 결정적 스캐터 마이크로 개선에 조건부 참고(스캐터 계열 몫). (3) 던전(Slice5)에선 MarkovJunior·WFC 방-복도가 재고 가치.
- WFC Explained (BorisTheBrave): https://www.boristhebrave.com/2020/04/13/wave-function-collapse-explained/
- Model Synthesis (Paul Merrell): https://paulmerrell.org/model-synthesis/
- MarkovJunior (mxgmn): https://github.com/mxgmn/MarkovJunior
- DeBroglie Constraints: https://boristhebrave.github.io/DeBroglie/articles/constraints.html
- Punch Out Model Synthesis (arXiv 2501.14786): https://arxiv.org/pdf/2501.14786

### 9. 하이브리드·최신 기법 계열
우리 철학과 가장 정합적: 스타듀가 실제로 전부 손그림 Tiled/tIDE 맵이라는 사실이 '손설계 매크로 + 알고리즘 마이크로 보조'를 업계 근거로 승인. 즉시 채택=Poisson 결정적 스캐터. 조건부 유망=프리팹 손그림 클러스터 스탬핑·저진폭 도메인 워핑·가이드라인 스플라인 사행. WFC 계열=지상 기각 유지(우리 Wang이 adjacency 손저작 버전). LLM 배치=저작-타임 도구로만. **도메인 워핑은 기각된 '절차 후처리'와 경계가 얇으니 '픽셀 출력'이 아닌 '셀 판정 입력 좌표'에만 극저진폭으로.**
- Modding:Maps (Stardew Wiki): https://stardewvalleywiki.com/Modding:Maps
- Poisson Disk (Bridson 격자법): https://a5huynh.github.io/posts/2019/poisson-disk-sampling/
- Spelunky (PCG Wiki): https://procedural-content-generation.fandom.com/wiki/Spelunky
- Meander (Robert Hodgin): https://roberthodgin.com/project/meander
- Narrative-to-Scene LLM Pipeline: https://www.researchgate.net/publication/395339432_Narrative-to-Scene_Generation_An_LLM-Driven_Pipeline_for_2D_Game_Environments

---

---

## 부록 — 최근 30일 커뮤니티 동향 (last30days · 2026-06-22~07-22)

> 소스: Reddit 6스레드·X 35포스트·HN 1·GitHub 1 + 웹 보충(raw = `~/Documents/Last30Days/tilemap-generation-autotiling-algorithms-raw-v3.md`).

- **Wang 타일은 실전 현역** — 이번 창 최고 신호는 "파이널 판타지 IX의 바다는 Wang 타일"(Show HN, jawnston.com/wang, 2026-07-06). 상용 명작이 반복 경계를 Wang으로 푼 실증 = 우리 손그림 Wang 16타일 노선의 방증.
- **듀얼그리드 생태계 성숙(기록만)** — Godot용 TileMapDual(pablogila·dexgamedev) 실시간 노드 보급, "47타일 대신 15타일(대칭 시 6타일)" 화법이 표준화. BorisTheBrave Quarter-Tile Autotiling이 이론 근거. **우리는 듀얼그리드 전환 재론 금지 확정 — 아트 비용 논거로도 재제안하지 말 것.**
- **커뮤니티 반응은 "알고리즘"이 아니라 "완성 씬"에** — r/proceduralgeneration 인기글은 마을·숲/길 생성 쇼케이스("remind me warcraft3 editor"). 절차티가 나면 즉시 지적당함("way too slow" 류 냉정한 품질 평가) → 본 서베이의 "마이크로 보조·저진폭" 원칙을 재확인.
- **신기법 축 = 생성형 AI 보조 편집** — arXiv 2503.19793 "Instant Game Map Editing using a Generative-AI Smart Brush": 손그림 매크로 + AI 마이크로 보조 방향의 최신 연구. 본 서베이 하이브리드 계열(LLM 보조 배치)과 합류. 우리 파이프라인엔 이미 PixelLab+후처리 체계가 동형 역할.

---

## 종합 권고

### Slice 1R (안식 맵 리메이크) 즉시 적용 — 효과 대비 비용 우선순위

**티어 1 — 최고 효율(저비용·즉시·통증 직결).** 셋 다 결정적 해시·매크로 불변.
1. **외톨이 영역 제거(flood-fill 정리)** — 반복 통증 '짙은 타일·노이즈 카펫'을 직접 소거. 가장 확실한 손그림 감각 상승, 리스크 최저. `_G16_GRASS_PATCHES`·스캐터 산출 직후 min-size 정리 패스.
2. **지터드 그리드 스캐터** — 가중 테이블의 순수 랜덤 좌표를 셀당 해시 변위로. 뭉침/공백 제거, 코드 변경 국소.
3. **경계 디더 프린지** — 기존 스캐터 테이블에 '경계밴드 가중'만 추가(별도 시스템 불요). owner P2(경계 소멸) 방향과 일치.

**티어 2 — 높은 효과·중간 비용(노이즈 유틸 신설).** `_mask_noise`(FastNoiseLite OpenSimplex2, seed=월드시드) 단일 진입점을 먼저 만들고 그 위에 얹는다.
4. **도메인 워핑(±1~2px 저진폭)** — 원형 CA·격자 경계티의 정면 해법. `_bake_grass_dirt_wang` 코너·`_G16_GRASS_PATCHES` 문턱 좌표에만, 밭·길·확정 물가 제외.
5. **fBm + 주파수대 분리** — 매크로/마이크로 노이즈로 존 틴트·변종 다양성. `_harmonize_grass_variants` 구동.
6. **다수결 평활 1~2패스** — CA 클럼프 경계 노이즈 매끈화(flood-fill 정리와 상보).

**티어 3 — 자연스러움 다음 축(신규 훅·에셋/설계 의존).**
7. **Neyman-Scott 군집 스캐터 + density-mask 곱셈기** — 꽃패치·나무무리·잡초무리 군락화 + 구역 경계 밀도 전이. flower_patch·orchard·reclaim에.
8. **Catmull-Rom 강/소로 중심선** — 안식에 곡선 강/오솔길 도입 시(현재 남향 물 축은 직선이라 훅 지점 대기).

**보류(조건 충족 시).** blob 47 승격=owner가 특정 히어로 경계 곡률 부족 지적 시. 프리팹 클러스터 스탬핑=손그림 스탬프 에셋 여유 시. 노이즈 문턱 마스크=신규 패치존만(CA와 중복 유지 금지).

### 이후 슬라이스 재사용 노트
- **나루·삼도천(강/물):** Catmull-Rom 중심선 + 가중 A* 지형 존중 라우팅 + Noisy Edges 비교차 원리(저진폭). 물↔흙 물가 손그림 마스크는 불가침 — 곡률은 '중심선 경로'(마스크 상류)에만.
- **숲:** Neyman-Scott 군락(나무 grove)·density-mask가 주력. 프리팹 클러스터 스탬핑 진가 발휘.
- **갱도/던전(Slice5, 지상 기각 예외):** CA 동굴 4-5 rule·MarkovJunior(미로·연결 경로)·WFC 방-복도·BSP 방 배치가 여기서 비로소 정식 후보. Modifying-in-Blocks(손설계 경계로 알고리즘 가두기) 패러다임 채택.
- **계절/신규 지형 종:** quarter-tile 아트 절감 카드 재검토. life-like B/S 구역별 밀도 노브로 질감 차별화.
- **공통:** 마스크 파이프라인 체이닝(CA/metaball → marching squares → Chaikin/Catmull-Rom → 손그림 마스크 승격 → 경계 디더)을 오프라인 베이크 유틸로 표준화하면 전 구역 재사용 가능. 모든 랜덤 `hash(cell,zone,seed)`, 픽셀 그리드 32px 스냅 준수.