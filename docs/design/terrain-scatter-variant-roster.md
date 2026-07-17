# 지형 스캐터 변종 로스터 (ADR-0058 C · ADR-0025 스펙카드)

> **성격:** 병렬 아트트랙(owner 페이스·비차단). 코드 트랙(계획 Task 1~3)은 변종 슬롯을 **데이터로 이미 열어둠** — 신규 변종 PNG는 `_REGION_GD_TABLES` 엔트리에 `[GD_XXX, weight, shadow]` 한 줄 추가 + 재빌드만으로 자동 반영(엔진 변경 0).
> **근거:** [`docs/design/stardew-terrain-taxonomy.md`](./stardew-terrain-taxonomy.md) 변주 레버 #1(타일당 tuft 하위구성)·#4(변종 수). [ADR-0058](../adr/0058-overworld-terrain-scatter-stardew-authentic-no-wfc.md) §2.C.
> **생성 규격 공통:** 32-native · NW 광원 · 마스터 팔레트 remap([ADR-0057]) · 저승 muted somber 톤 · 풀 tuft는 그림자 없음(flat)·잡초/돌은 미세 그림자. 프롬프트 결은 [`gemini-regen-batch.md`](./gemini-regen-batch.md) §스캐터/§클럼프 모델 참조.

## 우선순위

| 우선 | 카테고리 | 현재 변종 | 목표 추가 | 근거(taxonomy) |
|---|---|---|---|---|
| **1** | 풀 tuft | `GD_GRASS1`(짧은)·`GD_GRASS2`(중간)·`GD_GRASS3`(덤불·현재 스캐터 미사용) | **+2~3** | 레버 #4 — 스타듀 풀=4 tuft 하위구성. 변종이 반복을 은폐 |
| **2** | 잡초 | `GD_WEED_U`(저승)·`GD_WEED_D`(마른) | **+2** | base + special + large 다종(스타듀 Weeds) |
| **3** | twig/stone | `GD_TWIG1/2`·`GD_STONE1/2` | **+1~2** | 개활지 clutter 다양화(마른 개활 밀도) |

## 스펙카드

### ① 풀 tuft +2~3 (최우선)
- **용도:** `_REGION_GD_TABLES[HOME].GROUND`의 GD_GRASS 계열 확장 — 풀무리 클러스터의 시각 반복 은폐. 안식은 이미 풀무리↑(Task 2)라 변종이 바로 체감된다.
- **규격:** ~16×16 원본(렌더 ×2)·flat(그림자 없음)·좌우반전 활용 전제. 기존 `ground_grass1/2.png`와 톤·실루엣 계열 통일(개별 blade 솟은 실루엣 + 어두운 밑동).
- **변종 방향:** (a) 더 성긴 3~4 blade tuft, (b) 한쪽으로 휜 tuft, (c) 짧은 새싹형. `GD_GRASS3`(덤불)은 현재 스캐터 테이블 미사용 — 재편입 검토(작게·부드럽게, 클럼프 중심에만).
- **배선:** 신규 상수 `GD_GRASS4/5` preload → HOME GROUND 테이블에 낮은 가중(예: 4~6)으로 추가.

### ② 잡초 +2
- **용도:** clutter 다양성. `GD_WEED_U`(저승 잡초)·`GD_WEED_D`(마른) 사이 톤·형태 변종.
- **규격:** 작게·소프트(WEED_U 계열은 `_GD_SOFT_SET`)·미세 그림자(WEED_D 계열).
- **변종 방향:** (a) 키 큰 저승 잡초 변주, (b) 씨앗 맺힌 마른 줄기.

### ③ twig/stone +1~2
- **용도:** `_GD_SPARSE`(빈 tan 개활지) 다양화 — 스타듀 개활 clutter.
- **규격:** 크리스프(mute 대상 아님)·미세 그림자(stone). twig는 flat.
- **변종 방향:** (a) 이끼 낀 잔돌, (b) 부러진 가는 가지.

## 반영 절차(아트 도착 시)
1. PNG를 `assets/props/`에 배치(마스터 팔레트 remap 확인).
2. `main.gd`에 `const GD_XXX := preload(...)` 추가.
3. 해당 구역 테이블(`_REGION_GD_TABLES` 또는 전역 `_GD_TABLES`/`_GD_SPARSE`)에 `[GD_XXX, weight, shadow]` 추가.
4. `run_tests.sh building_grounding reclaim` 회귀 + `map_dump` 육안.
