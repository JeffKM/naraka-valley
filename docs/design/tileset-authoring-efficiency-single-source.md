# 타일맵 제작 효율 — "다출처 합성 엔진" 진단과 "단일 팔레트-락 출처" 해법

- **상태:** 설계 노트 (owner 2026-07-20 grill 산출 · ADR-0057/0058 보강)
- **정합 대상:** [ADR-0057](../adr/0057-terrain-tiles-pixellab-lowcolor-crisp-regen-supersede-0043.md)(저색 crisp base + 스캐터 디테일) · [ADR-0058](../adr/0058-overworld-terrain-scatter-stardew-authentic-no-wfc.md)(스캐터·WFC 폐기)
- **연결 메모리:** `gemini-tile-order-workflow-adr0058`, `water-dirt-shore-handpainted-mask-adr0058`, `soil-boundary-base-composite-adr0058`, `wfc-rejected-overworld-scatter-adr0058`

## 왜 이 노트가 있나

owner가 "지금 타일 제작 방식이 굉장히 비효율적 — 스타듀처럼 손그림으로 다 그린 감성에 근접하려면 요즘은 어떻게 하나"를 물으며 대안을 찾았다. 조사(2026-07-20 last30days + 웹 대조 + 코드 대조) 결과 **비효율의 원인이 흔히 지목되는 곳(오토타일 알고리즘)이 아님**이 드러나, 미래 세션이 같은 오진을 반복하지 않도록 박제한다. 두 부분: (A) 하지 말 것, (B) 할 것.

---

## A. 재제안 금지 — 듀얼 그리드 / Godot TileMapLayer 터레인 (이미 있거나 정체성과 충돌)

### A-1. 듀얼 그리드(dual-grid)는 이미 쓰고 있다

커뮤니티가 2026년 열광하는 듀얼 그리드(Oskar Stålberg, 반오프셋 표시격자로 47→16타일)의 **핵심 = 코너/정점 기반 타일 선택**은 이 프로젝트가 이미 구현했다:

- `_wang_vertex_surf(surf, vx, vy)` (`game/main.gd:3548`) — 정점에 맞닿는 **4 월드셀의 최상위 표면**을 뽑는다.
- `_corner_bits(nw, ne, sw, se)` (`main.gd:3541`) — 그 4정점으로 16타일 비트를 만든다.

이는 마칭스퀘어/듀얼 그리드의 타일-선택 로직과 **수학적으로 동형**이다. 따라서 "위상 불연속"은 타일-선택 문제가 아니라 **타일 *내용(content)* 불일치** 문제다. 코드 주석이 직접 진단한다(`main.gd:3652`): *"근원: Wang 손그림 타일이 base(`_bf_grass`)와 톤·스타일 불일치."*

진짜 듀얼 그리드가 *추가로* 주는 것은 반오프셋 **렌더** 재구성(인접 seam을 타일 선택에 내재화)뿐이고, 그것도 `_paint_shore_cell`이 이미 대부분 해결한다. 톤 불일치(내용 문제)는 배치를 바꾸는 듀얼 그리드로 **못 고친다**. → **ROI 낮음, 재제안 금지.**

### A-2. Godot 4 TileMapLayer 터레인으로 `_build_ground16` 대체 금지

`_build_ground16`(`main.gd:3865`)의 강점 전부가 프로젝트 정체성이다:

- **월드위상 타일링**(P=256, `blit_rect` 월드좌표) → 8칸 반복 격자를 죽인다. 주석(`main.gd:3746`): *"Wang 통짜 타일 blit은 base와 어긋나 옅은 격자무늬를 낳는다."*
- CA 클럼프·건물 접지 패드·절벽 pseudo-Z 오버레이·드롭섀도·접지 밴드·lip 평지화·`_soften_field_edges` = 대부분 **이미지 후처리**.

TileMapLayer는 본질적으로 **격자-고정**(셀 = 고정 아틀라스 1타일)이라 월드위상 샘플링이 불가 → owner가 죽인 그 격자무늬가 정확히 재출현하고, 후처리 레이어를 전부 다시 짜야 한다. → **전면 대체 금지.** (예외: S5 던전 프리팹 스티칭·신규 실내처럼 격자 룩 허용 + pseudo-Z 없는 영역은 TileMapLayer가 오히려 정답일 수 있음.)

---

## B. 진짜 진단과 해법 — "다출처 합성 엔진" → "단일 팔레트-락 출처"

### B-1. 스타듀 감성은 알고리즘이 아니다

[ConcernedApe 인터뷰](https://mentalnerd.com/blog/getting-started-pixel-art-interview/): 타일을 **혼자·하나의 팔레트로·손으로·시행착오**로 그렸다("맨 처음 그린 게 흙 타일", 16×16을 고른 이유=아트 양 감당). 아기자기함 = ①한 손 ②한 팔레트 ③손그림 ④**변종 다수** ⑤**손 디테일 배치**. 똑똑한 오토타일이 아니다.

### B-2. 비효율의 뿌리 = 타일이 여러 출처에서 온다

지금 파이프라인이 힘든 건 오토타일 때문이 아니다(코너-비트로 이미 풀림). **타일이 서로 다른 출처(손그림 Wang · `_bf_grass`/`_bf_earth` base 필드 · Gemini 발주)에서 와 톤이 안 맞기** 때문이고, 그 불일치를 메우려고 지은 게 다음의 **절차적 픽셀 합성 엔진**이다:

- `_bake_field_wang`(`main.gd:3808`) — 2개 base 필드에서 전환 타일을 *합성*해 불일치를 수학적으로 불가능하게.
- `_paint_shore_cell`(`main.gd:3700`) + `_build_shore_masks` — 손그림 4_0의 형태만 쓰고 채움은 월드위상 base.
- 월드위상 bake — 격자 은폐.

스타듀엔 이 엔진이 **없다** — 전부 한 손·한 팔레트라 "불일치"가 발생할 수 없으니까.

### B-3. 해법 = 모든 타일을 하나의 팔레트-락 출처에서

> base + 모든 전환 엣지 + 변종을 **한 세션·한 팔레트**로 생성하면 → 톤이 *구조적으로* 일치 → 합성 엔진(`_bake_field_wang`·`_paint_shore_cell`·월드위상 bake)을 **삭제 가능**.

이것이 "덜 고생 + 스타듀 근접"의 진짜 레버다. 오토타일(코너-비트 선택기)은 그대로 재사용한다.

### B-4. 요즘 방식 (2026) — 목적별 3갈래

| 방식 | 감성 | 노동/비용 | 이 프로젝트 적합 |
|---|---|---|---|
| **A. AI로 코히어런트 세트 생성 → Aseprite 보정** | 높음(팔레트 락 시) | 낮음 | ★ 최적 (ADR-0001/0057 승인 경로) |
| **B. 손그림 통짜 시트 → 엔진 오토타일** | 최고 | 최고 | 정석이나 owner 혼자선 부담 |
| **C. 코히어런트 에셋팩 구매/외주** | 높음 | 중(라이선스 주의) | 현실적 보조 |

최신 도구(방식 A):
- **[Retro Diffusion](https://retrodiffusion.ai/) RD Tile** — 단일 타일/변종/**재질 간 전환 포함 완전 타일셋**을 팔레트 통제로. 프로덕션 1순위 후보(2026 비교에서 base 룩 우위).
- **PixelLab** `create_topdown_tileset` — **base-tile 체이닝**(water→dirt→grass)으로 코히어런스를 구조적으로 잠금. 16타일 코너 Wang = 코너-비트 선택기와 직결. ADR-0057 "베이스 지형=PixelLab"과 정합.
- 실무 콤보: base 룩=Retro Diffusion, 회전·애니=PixelLab.

### B-5. 철학 결정 (owner 몫)

지금의 월드위상 bake는 "격자를 숨기려는" 것이지만, **스타듀는 사실 타일링이 약간 보인다** — 변종 + 손배치 디테일로 가릴 뿐. 그러니 "약간의 타일링을 허용하고 변종·스캐터를 늘리는" 쪽이 **더 스타듀-정통이고 코드도 훨씬 적다**. [ADR-0058](../adr/0058-overworld-terrain-scatter-stardew-authentic-no-wfc.md) §3 변종 확대 트랙과 정합. (`soil-boundary-base-composite` "밭·길=직선 사각" 결정과 같은 결.)

### B-6. 제약

- **라이선스:** AI 생성물 상업 이용 약관은 `docs/licensing-checklist.md`로 점검(Retro Diffusion/PixelLab 각각).
- **ADR-0001:** "자체 도트화 툴 제작 금지"지 "AI 생성 + Aseprite 보정"은 명시적 허용 — 방식 A는 규칙 안.
- **크레딧:** PixelLab 유료 크레딧 소진(구독 생성만 소량 잔존). 프로덕션은 Retro Diffusion 저울질.

---

## 검증 스파이크 (2026-07-20)

이 노트의 B-3 주장("코히어런트 단일 출처 세트 → 합성 엔진 삭제 가능")을 실증하려고 PixelLab로 water→dirt→grass 연결 세트를 base-tile 체이닝으로 생성해 코너-비트 선택기에 꽂는 스파이크를 진행. 결과는 아래에 갱신한다.

- 산출물: `docs/design/tileset-single-source-spike/` (스파이크 전용, 프로덕션 반영 전 owner 육안 확인 대상)
  - `water_dirt.png`/`.json`, `dirt_grass.png`/`.json` — PixelLab `create_topdown_tileset` 16타일 코너 Wang(32px, lineless·basic·low), dirt base tile id 체이닝.
  - `eval_map.png` — water↔dirt↔grass 3지형을 코너-비트 선택으로 한 프레임에 렌더(합성 엔진 미사용).
  - `contact_sheet.png` — 두 타일시트 나란히.
- 판정 기준: 톤이 태생부터 일치해 `_paint_shore_cell`/`_bake_field_wang` 없이도 seam·격자 없이 붙는가?

### 스파이크 결과 (PASS — 조건부)

- **✅ 코히어런스 구조적 증명:** dirt 솔리드 톤이 두 세트에서 **RGB 거리 0.0**(water_dirt=`(169.3,91.4,25.2)` = dirt_grass). base-tile 체이닝이 동일 dirt를 산출 → "다출처 불일치"가 *발생 불가*.
- **✅ 합성 엔진 불요 실증:** PixelLab 16타일을 **기존 코너-비트 선택기 그대로**(`corners`→`_corner_bits`) 소비해 3지형 맵을 렌더했고, `_paint_shore_cell`/`_bake_field_wang`/월드위상 bake **없이도** seam·톤 불일치·격자 붕괴가 없다. → 코히어런트 단일 출처면 합성 레이어를 **삭제 가능**하다는 B-3 주장 성립.
- **✅ 감성:** 물가 밝은 shore 엣지·부드러운 잔디 경계 = 스타듀-ish cozy.
- **⚠️ 남은 과제(= B-5 철학 결정):** 솔리드 잔디/물에 **타일링 반복이 눈에 보임**. 이는 월드위상 bake가 숨기던 것 → 이제 **변종 수 + 스캐터 디테일**(ADR-0058 §3)로 가려야 함. "약간의 타일링 허용 + 변종↑"이 더 스타듀-정통(B-5)이나, owner가 무격자를 고수하면 변종 타일을 4~6종 생성해 per-cell 변주(기존 `_harmonize_grass_variants` 계열)를 얹어야 함.
- **판정:** 단일 팔레트-락 출처 경로는 **작동하며 코드를 크게 줄인다**. 프로덕션 채택 전 결정할 것 = (1) 변종 밀도로 타일링 은폐할지, (2) 생성 도구를 PixelLab로 갈지 Retro Diffusion(2026 base 룩 우위)로 갈지, (3) 물 톤(현재 dark teal) 등 팔레트 라이브 튜닝.
