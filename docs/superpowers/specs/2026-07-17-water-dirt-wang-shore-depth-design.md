# 물↔흙(4_0) Wang 물가 = 스타듀식 단차 (안식 3면 물가) — 설계

> ADR-0058 확장 트랙(지상 지형 스타듀化)의 마지막 손그림 Wang pair 정합.
> owner 2026-07-17 라이브 비교(안식 연못 vs 스타듀 광산 연못) 산출. 접근 **C**(4_0만·강둑 분리) 확정.

## Goal

안식 농원 연못·강 등 **물↔흙 경계(Wang pair `4_0`)** 를, 손그림 Wang 원본 blit에서
**base 픽셀 합성 + 스타듀식 수직 단차**로 승격한다. 목표 룩 = "흙은 둔덕처럼 높고, 물은 그 안으로
움푹 파인 웅덩이"(owner: "물이 흙보다 아래에 있는 느낌").

## Background — 왜 이 작업인가

Wang 경계 4쌍 중 손그림 원본을 base 픽셀로 재합성해 **톤·스타일 불일치를 없애는 처리**를
받은 것은 3쌍이다. `4_0`(물↔흙)만 아직 **PixelLab 손그림 타일을 그대로 blit** 한다:

| pair | 경계 | 현재 처리 | 상태 |
|---|---|---|---|
| `0_1` | 흙↔잔디 | `_bake_grass_dirt_wang` → `_bake_field_wang` 유기 base 합성 | ✅ f1f151b |
| `3_0` | 밭↔흙 | Wang 스킵 → base blit 사각 + `_soften_field_edges` | ✅ f48a24a |
| `2_1` | 길↔잔디 | 밭·길 스킵 규칙에 흡수(base blit) | ✅ f48a24a |
| **`4_0`** | **물↔흙** | ❌ 손그림 Wang 원본 blit (`_wang_tiles[40]` 그대로) | **본 작업** |

렌더 ② 루프(`main.gd` ~3849)의 스킵 조건은 `up_s==2 or lo_s==2 or up_s==3 or lo_s==3`(밭·길)이라
물↔흙(surface 흙=0·물=4)은 걸리지 않는다. 따라서 4_0은 `_wang_tiles[_wang_pair_key(4,0)]=40`을
그대로 blit → 손그림 물가가 base(`_bf_water`/`_bf_earth`)와 톤·스타일이 어긋나고, 경계가
**평면 접합**(1~2px 갈색 선 하나)이라 깊이감이 없다.

### 라이브 비교 진단 (owner 스크린샷)

- **현재(안식 연못)**: 좌·우·하 3면 = 흙→물이 얇은 갈색 선으로 딱 끊김 → 흙·물 동일 평면.
  북단만 강둑(`CLIFF_BANK` pseudo-Z ledge)으로 단차가 있으나 3면과 문법 불연속.
- **스타듀(참조)**: 물가를 **두 겹**으로 처리 → (①) 물 안쪽 가장자리 = 밝은 얕은물 하이라이트 림,
  (②) 그 바깥 흙 = 어두운 그림자 밴드. 두 겹이 "흙↑ 물↓" 수직 깊이를 만든다.

## 핵심 통찰

`_bake_field_wang`(`main.gd` ~3729)은 이미 **"upper가 lower 위로 솟은 남쪽 드롭섀도"** 를 만든다
(잔디↔흙에서 잔디 밑동→흙 그림자). 물↔흙은 표면 위계(`_SURF_RANK` 잔디1>흙0>길2>밭3>물4)상
**흙(rank 3) = upper / 물(rank 0) = lower** 다. 그러므로 이 베이커에 `up=_bf_earth, lo=_bf_water`를
넘기는 것만으로 **흙이 물 위로 솟은 드롭섀도**(= 스타듀 겹②)가 공짜로 나온다.
남은 것은 **겹①(물 안쪽 얕은물 밝은 림)** 하나뿐이다.

## Architecture

기존 `_bake_field_wang` 일반 합성기 재사용 + 물 전용 얕은물 림 확장. 신규 시스템·신규 렌더 경로 없음.

```
_build_ground16()
  ├─ _load_big_fields()          # _bf_earth, _bf_water 등 base 준비 (기존)
  ├─ _load_wang_pairs()          # 손그림 4_0 로드 → _wang_tiles[40] (기존)
  ├─ _bake_grass_dirt_wang()     # 0_1 덮어씀 (기존)
  └─ _bake_water_dirt_wang()     # ★신규 — 40 덮어씀
        └─ _bake_field_wang(pair_key(4,0), _bf_earth, _bf_water, ...W40..., rim, rim_px)
```

렌더 ② 루프는 **무수정**. `_bake_water_dirt_wang`이 `_wang_tiles[40]`을 덮어쓰면 기존 blit이 그대로
합성 타일을 쓴다(잔디↔흙과 동일 메커니즘). `_grid`·충돌·세이브 불변(픽셀만 변경).

## 구현 상세

### ① `_bake_field_wang`에 얕은물 림 파라미터 2개 추가 (하위호환)

시그니처 끝에 옵션 파라미터를 더한다. 기본 0 → **잔디·밭 기존 호출은 무영향**:

```gdscript
func _bake_field_wang(pk: int, up_field: Image, lo_field: Image, rag: float, micro: float,
        edge_dark: float, shadow_depth: int, shadow_dark: float,
        rim_light: float = 0.0, rim_px: int = 0) -> void:
```

베이커 내부, 드롭섀도 패스 뒤에 **얕은물 림 패스**(rim_light>0일 때만) 추가:
lower(물) 픽셀이 upper(흙)와 직교 인접한 경우 그 픽셀부터 안쪽 `rim_px`까지를 밝게
(수면 반사·얕은 물 하이라이트). 밑동 가까울수록 강하게(선형 감쇄), 결정적(마스크 순수 함수).

```gdscript
# ★[물가 얕은물 림] lower(물) 픽셀 중 upper(흙) 경계에서 rim_px 안쪽까지 밝게 = 스타듀 겹①.
if rim_light > 0.0 and rim_px > 0:
    for i in TILE:
        for j in TILE:
            if bool(umask[j][i]):
                continue   # lower(물) 픽셀만
            # 이 물 픽셀에서 가장 가까운 upper(흙) 이웃까지의 체비셰프 거리(rim_px 이내)
            var dist := rim_px + 1
            for kk in range(1, rim_px + 1):
                var found := false
                for d: Vector2i in [Vector2i(1,0),Vector2i(-1,0),Vector2i(0,1),Vector2i(0,-1),
                                    Vector2i(1,1),Vector2i(-1,1),Vector2i(1,-1),Vector2i(-1,-1)]:
                    var ni := i + d.x * kk
                    var nj := j + d.y * kk
                    if ni >= 0 and nj >= 0 and ni < TILE and nj < TILE and bool(umask[nj][ni]):
                        found = true
                        break
                if found:
                    dist = kk
                    break
            if dist <= rim_px:
                var amt: float = rim_light * (1.0 - float(dist - 1) / float(rim_px))
                img.set_pixel(i, j, img.get_pixel(i, j).lightened(amt))
    tmap[bits] = img
```

> ⚠️ 위 코드는 설계 스케치다. 구현 시 기존 드롭섀도 루프와 동일한 `umask`/`img` 스코프 안에
> 넣는다(현재 `tmap[bits] = img`가 루프 말미에 1회). 계획 단계에서 정확한 삽입 위치를 잡는다.

### ② `_bake_water_dirt_wang()` 래퍼 신설

`_bake_grass_dirt_wang()`(`main.gd` ~3662) 바로 뒤에 추가:

```gdscript
# ★[ADR-0058 확장·물가 단차·owner 2026-07-17] 물(4)↔흙(0) 전환 = 흙(upper)/물(lower) base 합성.
#   _bake_field_wang이 흙 밑동→물 드롭섀도(겹②·"흙이 물 위로 솟음")를 만들고, 얕은물 림(겹①)을
#   더해 스타듀식 "물이 흙보다 아래" 웅덩이 단차. 손그림 Wang(4_0) 덮음 → 톤불일치 불가.
func _bake_water_dirt_wang() -> void:
    _bake_field_wang(_wang_pair_key(4, 0), _bf_earth, _bf_water,
        _W40_RAG, _W40_MICRO, _W40_EDGE_DARK, _W40_SHADOW, _W40_SHADOW_DARK,
        _W40_RIM, _W40_RIM_PX)
```

### ③ `_build_ground16`에서 호출

`_bake_grass_dirt_wang()` 호출(`main.gd` ~3790) 바로 다음 줄:

```gdscript
    _bake_grass_dirt_wang()
    _bake_water_dirt_wang()   # ★[ADR-0058 확장] 물↔흙 단차 base 합성 — 손그림 Wang 4_0 덮음
```

## 상수(레버) — 라이브 튜닝용

잔디↔흙 `_W01_*` 선례대로 상수로 노출(owner "살짝 더" 조정 대응). 초기값은 물가 성격 반영:

| 상수 | 초기값 | 의미 |
|---|---|---|
| `_W40_RAG` | 0.12 | 물가 경계 래그드 진폭(잔디 0.20보다 얌전 — 진흙 shore는 덜 들쭉날쭉) |
| `_W40_MICRO` | 0.08 | per-px 미세 지터 |
| `_W40_EDGE_DARK` | 0.14 | 흙 경계 1px 엣지다크(흙 밑동 정의) |
| `_W40_SHADOW` | 5 | 흙 밑동 남쪽 물에 드리우는 드롭섀도 깊이(px) — 단차 겹② (잔디 4보다 깊게 = 물이 더 아래) |
| `_W40_SHADOW_DARK` | 0.42 | 드롭섀도 최대 어둠 |
| `_W40_RIM` | 0.30 | 얕은물 밝은 림 강도(겹①·`lightened`) |
| `_W40_RIM_PX` | 2 | 얕은물 림 폭(px, 물 안쪽) |

> 미세 룩(드롭섀도를 남쪽만 vs 물 전둘레, 림 청록 틴트 여부)은 상수/후속 조정으로 흡수.
> 본 설계는 `_bake_field_wang` 기존 남쪽 드롭섀도 + 전둘레 얕은물 림 조합을 기본으로 한다.

## 불변식 (Global Constraints)

- **결정성**: 시드는 `_gd_h01(x,y,salt)` 좌표 해시만. `randi/randf` 금지(save.dat·회귀 오탐).
  얕은물 림은 `umask` 순수 함수 → 재빌드·재진입 동일.
- **저작맵 불가침(ADR-0005/0015)**: 순수 시각(`out` 픽셀). `_grid`·충돌·세이브·워프 불변.
  물 통과 불가(SOLID) 물리 그대로. 스캐터·재점령 레이어 불간섭.
- **범위 격리(접근 C)**: 4_0 pair 타일만. **북단 강둑(`CLIFF_BANK`) pseudo-Z ledge·물 내부
  텍스처·`_soften_field_edges`(밭·길) 무수정.** 강둑 재설계는 별도 과제.
- **하위호환**: `_bake_field_wang` 신규 파라미터는 기본 0 → 잔디(`_bake_grass_dirt_wang`)·
  밭 경로 출력 픽셀 불변(회귀 0). 물 경로만 림 활성.
- **퍼포먼스**: 로드 시 1회 bake(16 코너키 × TILE²). 얕은물 림은 물 pair 1개 한정.
  per-pixel 밴드 전면 처리 없음(홈빌드 17s·bana_test 행 회피).

## 테스트

- **`game/playtest/scatter_variation_test.gd`** (또는 신규 `wang_water_test.gd`)에 단언 추가:
  - `_bake_water_dirt_wang()` 후 `_wang_tiles[_wang_pair_key(4,0)]`가 16 코너키 dict.
  - 결정성: 두 번 bake → 동일 타일 이미지(픽셀 비교).
  - 얕은물 림 실효: 흙 인접 물 픽셀이 원본 `_bf_water`보다 밝다(림 활성 확인).
  - 하위호환: 잔디↔흙(`_bake_grass_dirt_wang`) 재호출 결과 = 기존과 동일(rim 기본 0 무영향).
- **회귀**: `cd game && ./run_tests.sh building_grounding reclaim`(변경 계층·flaky 배제).
- **육안**: `home_full_dump`(안식 연못 3면) before/after. ★owner 라이브 톤 확인은 별도.

## Self-Review

- **Placeholder scan**: ①의 얕은물 림 코드는 "설계 스케치" 명시 + 계획 단계에서 정확 삽입 위치
  확정하도록 플래그. 그 외 "적절히 처리"류 없음.
- **내부 일관성**: surface 매핑(흙0·물4·잔디1·밭3·길2)·pair_key(4,0)=40·위계(흙>물)·
  upper=흙/lower=물 전 절 일관. 렌더 루프 무수정 = 잔디↔흙 선례와 동형.
- **범위**: 단일 pair·단일 함수 추가 + 1 함수 확장. 단일 구현 계획 적정(decompose 불요).
- **모호성**: "드롭섀도 남쪽만 vs 전둘레"는 상수 레버 + 후속 조정으로 명시 흡수(기본=기존 남쪽).
