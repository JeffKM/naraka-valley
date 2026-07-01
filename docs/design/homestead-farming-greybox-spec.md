# 안식 농원 농사·목축 2·3층 그레이박스 수치 명세 (S1-1 산출)

> **상태:** ✅ **곡선 잠금(2026-07-01, S1-1 grill Q8~Q14) + S1-4 착수 경계·로스터·검증 잠금(2026-07-01, grill Q1~Q6 → §5).** 코드 0 — 이 문서는 S1-4~S1-7 빌드의 입력 스펙이다.
>
> **스코프(Q8):** *곡선 모델 + 그레이박스 시작값*만 잠근다. 개별 작물 값 배정 = **S1-4**, 최종 밸런스 튜닝 = **Phase 3**. 두 경계: ① **미호 관계 레이어(농사 XP 가속/자동화)는 이 문서 밖** — [ADR-0019](../adr/0019-physical-skill-relationship-multiplier-two-axis.md)대로 아래 base 곡선 *위에* 후행으로 얹힌다(base 위 곱). ② **숙련 = 농사 스킬 축1(혼력 감산+속도)만**, 품질은 스킬 아님(비료).
>
> **결정 원천:** [stardew-systems-catalog §1-B](./stardew-systems-catalog.md#1-b-농사)(정성 결정) · 본 문서(정량 곡선). 좌표 = [homestead-phaseB-layout §5](./homestead-phaseB-layout.md).

---

## §2.1 작물 메카닉 아키타입 데이터 모델

잠긴 5아키타입(단발·재성장·거대·트렐리스·다수확)은 **상호배타 enum이 아니라** base 모드 + 합성 플래그로 표현한다(포도=트렐리스+재성장 등 겹침). ⚠️ 스타듀 "cash crop"·연금(`ALCHEMY`)·자생(`WILD`)은 아키타입이 **아니다** — 연금은 [카탈로그 개간 grill] "연금 범주 발명 금지" 위반, 자생은 채집([ADR-0033]) 별 시스템.

```
# Base 성장 모드 (상호배타 핵심 축)
growth_mode      : SINGLE | REGROW
base_growth_days : int              # FAST=4 | MID=7 | SLOW=12 타임 밴드 상속
regrow_cooldown  : int              # REGROW일 때만 유효, SINGLE=0 고정

# 메카닉 합성 플래그
is_trellis       : bool             # 격자 충돌체 통과불가 + 인접 수확
giant_capable    : bool             # 3×3 성숙 시 확률적 거대화 합체
yield_min        : int
yield_max        : int              # max>1 → '다수확' 활성

# 직교 속성 태그 (아키타입 아님)
multi_seasonal   : bool             # 절기 전환 사멸 제외 프레스티지
```

## §2.2 아키타입 런타임 수치

- **REGROW 쿨다운:** `regrow_cooldown = max(2, int(round(base_growth_days * 0.4)))` → FAST(4)=**cd2** · MID(7)=**cd3** · SLOW(12)=**cd5**. (투자→패시브 전략 척추: 초기 성숙일·씨앗값 큰 대신 절기 내내 재수확.) ⚠️ **`round` 교정(S1-4 구현, 2026-07-01):** 초안은 `int(base×0.4)`(floor)였으나 명시값 2/3/5는 반올림이라야 나온다(MID 7×0.4=2.8→floor 2≠3). 명시값이 의도이므로 `round`로 확정. **다절기 프레스티지는 이 공식 밖의 손수 예외**(§2.3, cd=7).
- **GIANT 합체:** `giant_capable` 작물이 중심 3×3 격자 **전부 성숙** 시 매일 야간(`Daily_Reset`) 판정. **P = 0.01 (1%)/블록/밤**. 성립 시 오브젝트 → `GIANT_ENTITY`, **도끼로만** 파괴, 드롭 **15개** 표준. + 순수 시각 보너스(얼굴 비치는 거대 영혼 호박).
- **MULTI-harvest:** `yield_count = randi_range(yield_min, yield_max)` — 스킬·품질과 **완전 격리 독립 연산**. 기본형 1~3 · 개성형 2~3.

## §2.3 다절기 프레스티지 작물

- **생존 불변식:** `multi_seasonal = true` 엔티티는 `Season_Change` 트리거 시 `Crop_Death` 대상에서 **강제 제외**(일반 작물은 사멸 유지).
- **성장:** `base_growth_days = 12` · `growth_mode = REGROW` · `regrow_cooldown = 7`.
- **입수:** 후반 탐험 구역(미혹의 숲 등) **심층 채집 loot table(`loot_table_gathering`) 희귀 독립 슬롯**에 씨앗 인덱스 편입(ADR-0033 자생 씨앗·발견 게이트 재활용, 새 메카닉 0). 그레이박스 1종 → S1-4에서 최대 2종.
- **품질:** 채집(운/부적) 레이어 **전면 배제**, 일반 농사 비료 가중식(§3.1)에 100% 종속(농사 라인 취급).

---

## §3.1 품질 4등급 + 비료

품질 = **비료로만** 결정(스킬 아님, [ADR-0019]). 수확 트리거(`On_Harvest`) 시 타일 `fertilizer_state` 조회 → 단일 100분율 난수(0~99).

**품질 확률표 (행 합 100):**

| `fertilizer_state` | 일반 | 은 | 금 | 이리듐 |
|---|---|---|---|---|
| `NONE` | 80 | 18 | 2 | 0 |
| `BASIC` | 55 | 30 | 13 | 2 |
| `QUALITY` | 30 | 35 | 27 | 8 |
| `DELUXE` | 10 | 30 | 40 | 20 |

- **판매가 배수:** 일반 ×1.0 · 은 ×1.25 · 금 ×1.5 · 이리듐 ×2.0 (음식 회복량·선물 호감도도 등급 비례).
- **가공 싱크 불변식:** 카페 메뉴·모든 2차 가공품은 원자재 품질을 **무시**, 결과물은 단일 표준 등급 고정 출력(공급사슬 단순).
- **성장촉진 비료(`FERTILIZER_SPEED`군, 품질과 별 축):** 성장촉진 **−25%** · 하이퍼 **−33%** 잔여 성장일(스타듀 Speed-Gro/Deluxe 패리티). 여우불=관계XP와 다른 축.
- **타일 1슬롯 XOR:** `FERTILIZER_QUALITY`군 ⊻ `FERTILIZER_SPEED`군 — 상호배타, 다른 군 투입 시 기존 상태 `Overwrite`. (보습은 카탈로그 컷.)
- **다수확 품질 격리:** `yield_count` 추가 생성분 품질 = `QUALITY_NORMAL` **강제 바인딩**(품질 roll은 주 수확분에만).

## §3.2 농사 숙련도 곡선 (스킬 0~10)

농사 스킬 = **혼력 감산 + 작업 속도**만([ADR-0019]/[ADR-0027] — AoE=도구 티어, +%가치·품질 배제).

- **레벨 효과(선형, base 레이어):**
  - `current_action_cost = base_cost * (1.0 - 0.03 * level)` → L10 **−30% 혼력**.
  - `current_action_time = base_time * (1.0 - 0.03 * level)` → L10 **−30% 속도**(경작/파종/물주기/수확 애니 프레임 단축).
- **XP:** 수확 성공 시 `player_farming_xp += crop_base_price`.
- **누적 레벨 임계(그레이박스):** `[100, 300, 600, 1000, 1500, 2100, 2800, 3600, 4500, 5500]` (L1..L10).
- **불변식(하드 바운더리):** ❌AoE(도구 티어) · ❌+%가치(멜) · ❌품질(비료) · ❌혼력 **풀 크기**(행동당 감산만) · ❌레벨 게이팅("평평≠막힘", L0도 전 동작 무페널티 100% 가동).

---

## §4.1 목축(혼의 짐승) 수치 · 데일리 돌봄 루프

- **우정(0~1000 pts, 200/하트 → 0~5):** 가산 쓰다듬기 **+15** · 급여 **+5** · 주간 방목 **+8** · 야간 격리 **+5** / 감산 미급여 **−20/일** · 방치 자연감소 **−2/일**.
- **기분(0~255, 매일 가산):** 가산 급여 **+40** · 쓰다듬 **+30** · 야간 격리 **+40** · 방목 **+30** · 청결 **+20** / 감산 미급여 **−60** · 야간 실외 노출 **−40** · 오물 방치 **−30**.
- **산물 품질(§3.1 엔진 재활용):** 우정 하트로 확률표 행 스왑 — `NONE`(0~1하트) · `BASIC`(2~3) · `QUALITY`(4) · `DELUXE`(5하트 + 당일 기분 ≥200).
- **대형 산물:** `P_large = (하트/5) * 0.5` → 만렙 최대 **50%**. `is_large=true` → 출하 가치 **×2.0**.
- **공급망:** 1마리/일 **1 건초(Hay)** 소비. 낫으로 수풀 베기 → 확률적 사일로 건초 가산.
- **산물 용도:** 일반 시장 출하 하류 + **카페 전용 고유 요리 원자재**(작물론 못 만드는 메뉴 훅, 멜 공급).
- **⚠️ 비살상 불변식(하드 바운더리):** 야간 실외 방치·격리 실패라도 `Animal_Death`(사망·포식 소멸) 트리거 **절대 미가동**. 페널티는 야간 리셋 시 우정·기분 감산으로만(CONTEXT 죽음 단일화·비살상, 스타듀 야생동물 살해와 분기).

---

## §5 S1-4 착수 grill 결정 (2026-07-01, `grill-with-docs` Q1~Q6, 코드 0)

> S1-1이 곡선을 잠갔고(§2~§4), 이 절은 **S1-4 실구현 직전의 경계·로스터·검증**을 박제한다. 별도 ADR 없음(Q1) — S1-2가 "데이터/어휘만, 라이브 불변" 경계를 ADR 없이 `phaseB-layout §5.7`에 박은 것과 동형(ADR-0028 인터리브 + ADR-0025 스펙 카드의 슬라이스 적용일 뿐).

### §5.1 스코프 경계 (Q1)
- **포함:** `game/crops.gd`(=`class_name CropCatalog`)에 5아키타입 합성 플래그 필드 주입 + 신규 접근자 + 격리 헤드리스 검증(`playtest/crop_catalog_test.gd`).
- **배제:** `game/field.gd`(FarmField) 등 **모든 라이브 농사 액션 코드 불변**. 확장 플래그가 등록돼도 FarmField는 S1-5/S1-6 진입 전까지 무시하고 기존 `SINGLE` 수확·초기화 불변식 유지(회귀 0). 재성장 수확·트렐리스 충돌·거대화·품질 roll = S1-5/S1-6/S1-8.

### §5.2 하위호환 별칭 레이어 (Q2)
`CATALOG` 각 항목에 신규 필드(`growth_mode`·`base_growth_days`·`regrow_cooldown`·`is_trellis`·`giant_capable`·`yield_min`·`yield_max`·`multi_seasonal`) **추가**, 기존 표면은 별칭으로 보존:
- `growth_days(id)` = `base_growth_days`의 얇은 별칭. **missing → `-1` sentinel 엄수**(field.gd `is_mature`의 `need >= 0` 계약 — `0` 반환 시 미지작물 즉시 수확 회귀).
- `stages`(int 2/3/4)·`seed_cost`·`sell_price`·id 상수(`HONRYEONGCHO`/`PIANHWA`/`YEONGHON_HOBAK`)는 **불변**(`flavor.gd`·`main.gd`·`affinity.gd`·`inventory.gd`·`item_catalog.gd`·`crop_preview.gd` 광범위 참조).
- 신규 접근자는 기존 관례대로 `get_` 접두 없이: `growth_mode(id)`·`regrow_cooldown(id)`·`is_trellis(id)`·`giant_capable(id)`·`is_multi_seasonal(id)`·`yield_range(id)->Vector2i`.

### §5.3 기존 3작물 리튠 (Q3)
성장 밴드만 스펙 밴드로 올리고 **경제·stages·id 불변**(테스트가 접근자 상대라 밴드 리튠 회귀 0):

| id | 이름 | base_growth_days | seed/sell (원형 보존) | giant |
|---|---|---|---|---|
| honryeongcho | 혼령초 | 3→**4**(FAST) | 10 / 20 | — |
| pianhwa | 피안화 | 5→**7**(MID) | 25 / 60 | — |
| yeonghon_hobak | 영혼 호박 | 8→**12**(SLOW) | 50 / 160 | ✅ |

(⚠️ Gemini 초안의 혼령초 경제 20/50은 스타듀 parsnip 잔재 오염 — 기각.)

### §5.4 신규 2작물 로스터 (Q4)
합성 플래그로 신규 2종만 추가해 6아키타입 전부 커버:

| id | 이름 | mode | days | cd | trellis | giant | yield | multi_seasonal | seed/sell |
|---|---|---|---|---|---|---|---|---|---|
| hwangcheon_podo | **황천포도** (黃泉葡萄) | REGROW | 7 | 3 | ✅ | — | 2–3 | — | 80 / 40 |
| bulsagwa | **불사과** (不死果) | REGROW | 12 | 7 | — | — | 1 | ✅ | 200 / 100 |

- **황천포도** — 트렐리스+재성장+다수확 합성(스펙 §2.1 "포도" 정준 예시). 망연절(가을) 정합, 4절기 유일 공백을 메움.
- **불사과** — 다절기 프레스티지(§2.3 불변식 고정: REGROW·12·cd7). 미혹의 숲 심층 채집 전용, **만물상 미판매**. seed_cost 200은 카탈로그 균일성용 placeholder·미사용(상점 노출은 `CROP_SPRITES`/loot 게이트 = 하류 슬라이스에서 자연 배제, 검증됨).

### §5.5 헤드리스 검증 스펙 (Q5) — `playtest/crop_catalog_test.gd`
`run_tests.sh` 순차 러너에 +1 등록. 성장 시뮬은 배제(S1-5). 단언:
1. **아키타입 커버리지** — SINGLE·REGROW·`giant_capable`·`is_trellis`·`yield_max>1`·`multi_seasonal` 각 최소 1작물 존재.
2. **작물별 불변식**(전 작물 순회): `growth_mode ∈ {SINGLE,REGROW}` · `base_growth_days ∈ {4,7,12}`(엄격) · `SINGLE ⟹ cd==0` · `REGROW and not multi_seasonal ⟹ cd == max(2, int(round(base*0.4)))`(§2.2 round 교정) · `yield_min>=1 and yield_max>=yield_min` · `multi_seasonal ⟹ (REGROW and base==12 and cd==7)`(공식 밖 손수 예외).
3. **하위호환 계약**: `growth_days(id)==base_growth_days` · `growth_days("없는id")==-1` · 기존 id 상수 등재.
4. **검증기 이빨(음성 mock)**: `_violations(data)->Array`(테스트 파일 스코프)에 위반 mock 주입([SINGLE+cd5]/[multi_seasonal+base7]/[yield 역전]) → 못 잡으면 세션 강제 크래시. (`crops.gd`는 순수 데이터+접근자 유지, 검증기는 production 밖.)

### §5.6 절기 데이터 경계 (Q6)
`CropCatalog`에 `season` enum·매핑 딕셔너리 **미도입**. 절기 연계는 `multi_seasonal: bool` 단일 수렴. 사멸 판정 = 자생 절기 미조회, `multi_seasonal==false` 일괄 `Crop_Death`. 상세 절기 매핑·심기 게이팅 = **Slice 7(계절·날씨·축제)** 이관(CONTEXT 절기 정합은 서사/flavor 층이지 사멸 게이트 데이터 아님).

---

## §6 S1-5a 착수 grill 결정 (2026-07-01, `grill-with-docs` Q1~Q5, 트렐리스 = 황천포도 end-to-end)

> S1-5 = 트렐리스(S1-5a) + 혼의 나무 과수(S1-5b). **순차: 5a 먼저 완결→5b 별도 grill.** 이 절은 5a만. 별도 ADR 없음(Q3, S1-4 §5와 동형 — 술어/물리 분리는 S1-2 `is_solid`·기존 `_prop_body` 패턴 재적용). 첫 *라이브 메카닉* 슬라이스(S1-4는 순수 데이터였음).

### §6.1 스코프 (Q1·Q2) — 황천포도 end-to-end
S1-5a = 황천포도가 **완전히 동작**하게 만든다: 트렐리스 충돌 + 인접 수확 + **REGROW 수확**(쿨다운 후 재결실) + **다수확 count**(2~3). REGROW/다수확은 트렐리스 전용 아닌 `field.gd` 일반 확장이라 **불사과(REGROW)에도 재사용**. **품질(비료)만 S1-6으로 분리**(REGROW/다수확=메카닉 / 품질=비료=S1-6). 검증 = 헤드리스 술어·상태(물리 충돌 육안=bot/map_dump 이월).

### §6.2 트렐리스 충돌 (Q3) — 술어/물리 분리
- **`field.gd` 진실원(헤드리스):** `is_crop_solid(t) = is_planted(t) and CropCatalog.is_trellis(crop_of(t))` — 넝쿨 칸 점유 단일 술어. **REGROW 쿨다운 중에도 planted 유지 → 계속 solid**(넝쿨 그대로·열매만 없음). `solid_crop_tiles() -> Array` 배출.
- **`main.gd` 물리(통합):** `_trellis_body: StaticBody2D`를 `farm.solid_crop_tiles()`로 재구성(`_prop_body` 패턴, 칸당 −8..8 사각). `tile_changed`·구역 재빌드에서 갱신. save 복원은 tile_changed 재발화로 자동.
- **발밑 심기 갇힘 가드 = 이월**(bot 육안 후 결정, ADR-0047).

### §6.3 인접 수확 (Q3·Q4) — 이미 됨(신규 로직 0)
ADR-0024 타겟 모델이 이미 **발 칸 ±1(커서 방향)** 을 대상으로 삼고, **트렐리스 작물은 그리드를 안 바꿈**(farm._tiles 상태·칸은 계속 SOIL) → `_is_farmable`(=`_grid==SOIL`) 통과 → 조준 가능. 충돌 바디는 *이동*만 막고 *조준*은 안 막음. 플레이어가 넝쿨 옆에 서서 겨냥→수확 = 기본 동작. 신규 인접-수확 코드 불필요.

### §6.4 REGROW 수확 상태 (Q4) — 기존 machinery 재사용 (ADR-0048)
`field.gd.harvest(t)`가 `growth_mode`로 2분기:
- **SINGLE:** `planted=false, crop="", grown_days=0`(기존 동작, `crop=""` 관례 유지).
- **REGROW:** `planted` 유지 + `grown_days = max(0, base_growth_days − regrow_cooldown)`. → 황천포도(7,cd3)=4 → 물주고 3일=7 재성숙. `is_mature`/`advance_day`(물-구동) **100% 재사용·특수분기 0**(되자람도 물주기 필요=option 가, 무수분 패시브는 스프링클러/Phase3 튜닝 이월).

### §6.5 다수확 count (Q5) — main 인라인
`field.gd.harvest(t)` 반환 계약(String crop_id) **불변**. `main._try_harvest`가 적재 직전 `var n = randi_range(CropCatalog.yield_range(crop).x, .y)` → n번 `add_harvest`. yield_range 데이터는 S1-4 테스트가 (2,3) 기검증.

### §6.6 헤드리스 검증 (Q5) — `playtest/trellis_test.gd`
`run_tests.sh` +1. 단언: ①`is_crop_solid` 술어(트렐리스 심긴=solid·비트렐리스 심긴=non-solid·빈칸=non-solid) ②**REGROW 사이클**(황천포도 성숙→harvest→여전히 planted·`grown_days==base−cd`·is_mature=false→물주고 cd일→재성숙) ③SINGLE 대조(혼령초 수확→비워짐) ④`solid_crop_tiles()` 정확성 ⑤트렐리스 칸 그리드 여전히 SOIL(인접수확 근거). 성장 시뮬은 물-구동 advance_day 재사용분만(신규 성장로직 0).
