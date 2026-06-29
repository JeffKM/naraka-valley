# 나라카 밸리 — 타일셋 생성 규칙 (Tileset Ruleset)

> **상태:** 타일셋 규칙 grill(2026-06-29) 산출물. PixelLab `create_topdown_tileset`으로 지형 타일을
> 생성할 때의 **단일 진실의 원천**이다. 설치한 마켓 스킬(`cautiouskurns-game-template-pixellab-tileset-generator`)의
> Blood & Gold 기본값(high top-down·16×16·transition 0.5)은 **무시하고 이 문서를 따른다**.
>
> **근거 문서:** [ADR-0013](../adr/0013-environment-art-32px-native.md)(32px native)·[ADR-0026](../adr/0026-stardew-art-style-pivot-slim-cast.md)(스타듀 룩)·[ADR-0025](../adr/0025-in-game-prop-placement-mode-data-externalization.md)(스펙 카드 게이트)·[p2.0-spike-prompts §4.2](./p2.0-spike-prompts.md)(마스터 팔레트)·[world-map.md](./world-map.md)(구역별 지형).

---

## 1. 잠긴 토대 (ADR/자산이 진실 — 그릴 대상 아님)

| 항목 | 값 | 출처 |
|---|---|---|
| **타일 크기** | **32×32 native, 1:1 렌더**(×2 업스케일 금지) | ADR-0013 (ADR-0012의 16px×2를 환경 한정 개정) |
| **아트 룩** | 스타듀밸리식 소프트·둥근 톤 + 저승 저채도 팔레트 | ADR-0026 |
| **outline** | `lineless` | 기존 4세트 메타데이터 공통 |
| **shading** | `basic shading` | 〃 |
| **text_guidance_scale** | `8` | 〃 |
| **체이닝** | `lower_base_tile_id`/`upper_base_tile_id`로 이음매 일치 | 기존 풀↔길↔밭흙 체인 |

**마스터 팔레트(실측 hex, §4.2):** 전경 외곽선 `#401818`(적갈, 순검정 아님) · 영혼빛 파랑 `#60d8f0`(저채도)→`#2068e8`(고채도) · 흙길/밭흙 `#684840`/`#503030` · 풀(보정 후) `#306033`(어두운 이끼).

**기존 지형 4종:** 풀(grass) · 흙길(dirt path) · 밭흙(tilled soil) · 물(water).

> ⚠️ **stale 주의:** `p2.0-spike-prompts.md` §3·§4·§11은 아직 `tile_size=16×16`·`TILE_ART=16`으로 적혀 있다(ADR-0012 시절 잔재). **ADR-0013이 환경 아트를 32px native로 뒤집었고 실제 자산 메타데이터도 32×32다** — 타일 크기는 이 문서(32px)가 진실. 팔레트 §4.2만 스파이크 문서를 참조.

## 2. 파이프라인 (확정 절차)

1. **생성** — `create_topdown_tileset`(아래 규칙 파라미터로). 인접 지형은 이전 세트의 base tile id를 `lower_base_tile_id`로 넘겨 체이닝.
2. **다운로드** — `get_topdown_tileset`의 `download_png`/`download_metadata`는 302 redirect(backblaze) → **`curl -L` 필수**(없으면 0바이트). 파일명 = `*_image.png` / `*_metadata.json`.
3. **색보정**(필요 시) — `tools/desaturate_grass.py`류 PIL hue 선택 보정(ADR-0001 허용 = Aseprite 보정). 원본은 `*_raw.png`로 1회 백업(idempotent).
4. **합성** — `tools/pixellab_tileset_converter.gd`(PixelLab 공식, 벤더링)로 Wang 세트들을 단일 `.tres`로. **인자 순서가 terrain id를 고정**(기존: 0=길·1=풀·2=밭).
5. **Godot terrain 함정**(필수):
   - `set_cells_terrain_connect(cells, set, terrain, ignore_empty_terrains=false)` — **4번째 인자 반드시 `false`**(true면 빈 캔버스 첫 칠이 한 칸도 안 됨).
   - 로드 후 `set_terrain_set_mode(0, TERRAIN_MODE_MATCH_CORNERS)` 강제(컨버터는 mode=0으로 나오나 Wang은 코너만).
   - 칠 순서: 풀 단일 칠 → 전환 얹기 → 단색(HOUSE/CAFE/WALL) 맨 나중.
   - 1칸 폭 길은 corner 전환이 풀에 묻히므로 base 직접 `set_cell`.

## 3. 그릴로 정하는 규칙 (진행 중)

> 아래 항목을 grill로 하나씩 확정해 채운다.

- [x] **3.1 뷰 각도 = `low top-down`.** 기존 타일 4종·캐릭터 5종이 모두 low top-down → 한 화면 시점 일치 강제. 스킬의 high top-down 권장은 무시.
- [x] **3.2 전이 크기 = `transition_size: 0.0`.** 코너 대각선 또렷한 경계(스타듀 정합 + 지형 가독성). 전이 *모양*은 Godot Wang 코너 오토타일이 책임지므로 0.0이 하드 경계를 뜻하지 않음. 0.0~0.5 모두 16타일이라 컨버터 무수정.
- [x] **3.3 디테일 등급 = `detail: medium`.** 32px 탑다운 지형은 미세 텍스처(풀잎·흙 결)가 있어야 코지 손맛(스타듀 본가도 지형 텍스처 또렷). "저디테일"(ADR-0026)의 실제 범인은 디테일 등급이 아니라 팔레트·비례라 medium이어도 안 튐. → **확정 스타일 = `outline:lineless` + `shading:basic` + `detail:medium` + `text_guidance_scale:8`.**
- [x] **3.4 팔레트 규율 = 공유 꼬리 + 선택적 영혼빛 액센트.**
  - **(a) 공유 꼬리**(모든 지형 설명에 append): `muted desaturated low-saturation underworld palette, somber graveyard tone, soft rounded stardew-style shapes, 2-3 tone shading, lineless, clean readable at 32px`
  - **(b) 선택적 영혼빛 파랑(`#60d8f0`)** — 테마상 맞는 곳에만(물=혼의 강 푸른 윤슬·잿눈=차가운 푸른 기·영혼 풀 가장자리). **흙길·모래·돌·밭흙은 흙빛 중립 유지**(파랑 강제 금지). 저승색 본체 = "저채도·음울", 파랑 = *영혼 깃든 곳을 짚는 악센트*.
  - **(c) 후보정** — 형광으로 나오면 `desaturate_grass.py`식 hue 선택 채도 하향(ADR-0001 허용), 원본 `*_raw.png` 백업.
- [x] **3.5 구역별 지형 셋 + 체이닝 그래프** (아래 §4).
- [x] **3.6 `.tres` = 구역별 분할.** 전이 세트 소스 `<지형A>_<지형B>_image.png`/`_metadata.json`/`_raw.png`(기존 패턴). 구역 합성본 `combined_terrain_<region>.tres` + `_atlas.png`(예: `_homestead`·`_village`). 구역별 terrain id 순서는 tres 헤더 주석에 명시. **기존 `combined_terrain.tres` → `combined_terrain_homestead.tres`로 이름 통일**(농원 재생성 시 `main.gd` 로드 경로 동시 변경).
- [x] **3.7 스펙 카드 게이트(ADR-0025) 연동** (아래 §5).

---

## 4. 마스터 지형 목록 + 체이닝 그래프

**마스터 지형 목록(8구역 청사진):**

| 지형 | 영문 키 | 쓰이는 구역 | 영혼빛 액센트 |
|---|---|---|---|
| 풀 | `grass` (음울한 이끼녹) | 농원·마을·숲 | 옅게 |
| 흙길 | `dirt path` | 전 구역 동선 | ✗ |
| 밭흙 | `tilled soil`(고랑) | 농원 | ✗ |
| 자갈/돌광장 | `cobblestone` | 마을 | ✗ |
| 강물 | `river water` | 삼도천·마을 | ✓ |
| 바닷물 | `sea water` | 황천해 | ✓ |
| 모래 | `sand` | 황천해 | ✗ |
| 숲바닥 | `forest floor`(낙엽) | 저승 숲·미혹(더 어둡게) | ✗ |
| 암반/동굴바닥 | `rock` | 갱도 | ✗ |
| 심연바닥 | `abyss`(업화·봉인) | 나락 | ✓ |

> 강물/바닷물은 **별도 지형으로 유지**(어종·무대가 다르고 색·결도 다름 — 통합 안 함).

**체이닝 규칙 — "두 앵커(풀 + 흙길)" 모델:**
- **풀**(자연 바탕)과 **흙길**(전 구역 가로지르는 동선)이 두 연결 조직.
- 새 지형은 *물리적으로 맞닿는 앵커*에 `lower_base_tile_id`로 체이닝:
  - `tilled soil`→흙길 · `cobblestone`→흙길 · `rock`→흙길 (동선에 붙음)
  - `river water`→풀 · `forest floor`→풀 (바탕에 붙음)
  - `sand`→바닷물 + `sand`→풀 (해변은 물·뭍 둘 다 접함)
  - `abyss`→암반 (갱도 끝이 나락으로)
- **생성 순서:** 앵커 `grass` base 먼저 → `흙길↔풀` → 나머지가 앵커 base id를 물려받음.

**빌드 순서(ADR-0015 "한 구역씩"):** 청사진은 전체 정의, 생성은 구역별. **1순위 = 안식 농원**(`grass`·`dirt path`·`tilled soil` — 기존 4세트를 새 스타일로 **재생성**만).

---

## 5. 스펙 카드 게이트 (ADR-0025 — 생성 전 필수 승인)

PixelLab 생성 전, 아래 카드를 채워 **승인받고 생성**한다(메모리 `asset-spec-gate-before-generate`). 여러 셋이면 카드 묶음으로.

```
구역: <region>           목표 tres: combined_terrain_<region>.tres
전이쌍: <lower> ↔ <upper>
lower_description: "<...>" + [§3.4(a) 공유 꼬리]
upper_description: "<...>" + [§3.4(a) 공유 꼬리]   (영혼빛 액센트는 §3.4(b) 해당 시만)
파라미터: tile_size 32×32 / view low top-down / transition_size 0.0 /
         detail medium / outline lineless / shading basic / text_guidance_scale 8
체이닝: lower_base_tile_id = <앵커 base id 출처, 없으면 신규 앵커>
후보정: <desaturate 필요 예상 여부>
예상 비용: ~1.25 gen/타일 (셋당 2~3 gen)
```

