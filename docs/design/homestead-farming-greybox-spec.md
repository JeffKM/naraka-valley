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

---

## §7 S1-5b 착수 grill 결정 (2026-07-02, `grill-with-docs` Q1~Q9, 혼의 나무 과수 = 혼백도 end-to-end)

> **✅ 실구현 완료(2026-07-02):** 아래 스펙대로 `game/orchard.gd`·`game/fruit_tree_catalog.gd`·`game/playtest/orchard_test.gd`(43단언) + `clock.gd`·`item_catalog.gd`·`inventory.gd`·`main.gd`·`hotbar_hud.gd`·`inv_frame.gd` 배선. 전체 38개 테스트 통과·부팅 클린·회귀0. **하류 이관:** 과일 정식 판매가(현 raw-sell 경로 0골드 — `ItemCatalog.price_of` 통일=Slice2/6)·대형 스프라이트·Y-sort=S1-10·품질 인벤토리=S1-6·4절기 로스터=하류.
>
> S1-5 = 트렐리스(S1-5a, §6) + **혼의 나무 과수(S1-5b, 본 절)**. 상위 결정은 [stardew-systems-catalog §60/§498](./stardew-systems-catalog.md)에서 잠김(grill 2026-06-29): 저승 과수 "혼의 나무" = 28일(1절기) 성숙 → 제철 매일 결실 → **절기 넘어 영속**(다절기 프레스티지의 나무판) · **품질=나무 나이**(비료 불가, 작물 품질=비료와 분리) · 3×3 배치 제약. 본 절은 그 위의 *구현 설계*를 잠근다. **절기 유도 표면 선도입만 [ADR-0045](../adr/0045-orchard-season-derivation-surface-slice1.md)** — 나머지는 §5/§6과 동형으로 별도 ADR 없음(슬라이스 내부 신규 파일). 신규 파일 `game/orchard.gd`·`game/fruit_tree_catalog.gd`·`playtest/orchard_test.gd`.

### §7.1 스코프 (Q2) — orchard 완전 분리, FarmField 불변
- **포함:** 신규 `orchard.gd`(자체 좌표계로 나무 소유)·`fruit_tree_catalog.gd`(`class_name FruitTreeCatalog`)·`clock.gd` 절기 유도 static·`main.gd` 배선(충돌·심기·수확)·`item_catalog.gd` 아이템 2종·`save.gd` orchard 블록·격리 검증.
- **배제:** `field.gd`(FarmField) **한 줄도 안 건드림**(회귀-0 계약 계승) — 나무는 밭 칸의 crop이 아니라 자체 엔티티. 물주기·밭갈이 무관(스타듀 과수 정합). 인벤토리 슬롯 quality·판매가 곱·4등급 UI = **S1-6**(§7.7). 4절기 로스터·정식 판매처·온실 = 하류.

### §7.2 절기 유도 표면 (Q1, ADR-0045) — 읽기 전용 파생
`clock.gd`에 상태 변수 없이 `day`에서 파생:
```gdscript
static func season_index_for_day(d: int) -> int:
    return ((d - 1) / 28) % 4    # 0=피안 · 1=유화 · 2=망연 · 3=성야
```
게임 시작=피안절 1일 → `day 1 → 0`. **사멸/날씨/축제/예보=Slice 7 불가침** — orchard는 절기를 *읽기만* 하고 사멸 트리거 안 심음. 절기 판정=매 틱 무상태 재계산(세이브 캐시 아님).

### §7.3 나무 1그루 상태 모델 (Q4) — `planted_day` 파생, 3필드 최소
`orchard._trees: Dictionary[Vector2i(앵커) → Dict]`, Dict = 3필드만:
```gdscript
{ "fruit_id": String, "planted_day": int, "fruit_count": int }  # fruit_count 0..cap(3)
```
- **나이 = `clock.day − planted_day`** (누적기 없음) → 품질=나이·영속·세이브가 전부 파생(planted_day는 절기 경계에 절대 리셋 안 됨).
- **돌봄 0** — 물주기·비료·성장촉진 무관(패시브 영속 생산자).

### §7.4 3×3 기하·심기 판정 (Q3) — center-anchor, 예약≠충돌
- **앵커 = 중심 칸 1개**(`Vector2i` 1개로 나무 1그루). **예약 풋프린트 = 앵커±1의 3×3 9칸**(파생). **충돌 = 앵커 1칸만 SOLID**(밑동), 수관 8칸 통과 가능(3×3 벽 회피·스타듀 정합).
- **심기 판정 `can_plant_tree(anchor)`** — 9칸 전수 평가: ①모두 HOME 구역 내 ②모두 `is_solid()==false` ③모두 `is_crop_solid()==false`(트렐리스 미교차) ④타 나무 예약 풋프린트와 미교차(체비쇼프 거리로 역추적).
- **충돌 물리** = 트렐리스 `_trellis_body` 패턴 복제한 신규 `_orchard_body: StaticBody2D`(밑동 칸 16×16). HOME 전용. 로드·심기·수확 시 재구성.
- **Y-sort** = 앵커 타일 중심선 pivot만 스펙에 박고, 대형 스프라이트 밑동 보정 = **S1-10 아트** 이관.

### §7.5 결실·생애주기 (Q4) — 달력 구동, 제철 축적
`day_advanced` 훅에서 `orchard.advance_day(day)`(기존 `_on_day_advanced`가 `farm.advance_day` 옆에서 호출):
- **성숙 = 순수 달력:** `나이 >= mature_days(28)` → 성숙(물주기 무관).
- **결실 = 성숙 AND 제철:** `is_mature AND season_index_for_day(day)==fruit.season AND fruit_count<cap` → `fruit_count += 1`. cap=3.
- **비제철:** 신규 결실 정지, **매달린 과일은 유지**(안 썩음).
- **영속:** 절기 경계 넘겨도 사멸 판정 미참여 → 나무 생존·나이 계속 증가.

### §7.6 수확·상호작용 (Q5) — 풋프린트 조준, 기존 동사 재사용
- **수확** = 풋프린트 9칸 중 아무 칸 조준 + 기존 수확 동사. `main._try_harvest`가 `target_tile`을 나무 풋프린트로 **역추적**(체비쇼프 ≤1)→ 성숙+`fruit_count>0`이면 전량 인벤토리 적립·`fruit_count=0`·나이서 tier 산출. 신규 입력 경로 0(트렐리스처럼 기존 라우팅 분기 1개).
- **심기** = "묘목" 아이템 사용 + 앵커 조준. `can_plant_tree` 통과 시 `planted_day=clock.day`로 생성. 실패 시 기존 심기-실패 UX 재사용.

### §7.7 품질=나이 (Q6) — 파생 함수만, 인벤토리는 S1-6
```gdscript
func quality_tier_for_age(age: int) -> int:
    return clampi((age - 28) / 28, 0, 3)   # 28→0 · 56→1 · 84→2 · 112(1년생)→3
```
절기당 +1등급(28일 입도). **지금 = 순수 함수 + 격리테스트만**(완료기준 충족). **인벤토리 슬롯 quality·판매가 곱·4등급 = S1-6**이 이 함수를 소비(수확은 당분간 품질 무차원 적립, item_catalog:21 그레이박스 계약 유지). "품질=나이(비료 불가)" ⊥ S1-6 "작물 품질=비료" = 서로 다른 소스 두 개 → 미래 4등급 표면 수렴.

### §7.8 로스터·아이템 (Q7) — 그레이박스 1종
`fruit_tree_catalog.gd` 데이터 모델(N종 수용, 로스터 1종):
```
{ name_ko, season(int), mature_days(28), fruit_cap(3), sapling_cost, fruit_sell }
```
- **혼백도(魂魄桃)** — 저승 복숭아, **결실 절기=피안절(index 0)**(게임 시작 절기라 조기 검증). sapling_cost/fruit_sell = 그레이박스 placeholder(영속 투자→묘목 비쌈·과일 프리미엄, S1-6/밸런싱 리튠).
- **아이템 등록:** `item_catalog.gd`에 **묘목 아이템 1 + 과일 아이템 1** 신규(트렐리스와 달리 기존 아이템 재사용 불가).
- **묘목 획득처 = 최소 배선**(만물상=Slice 2라 HOME 미존재) — 아이템만 등록, 정식 판매처·온실 연결 하류 이관.
- **4절기 로스터 확장**(절기별 저승 과일) = naming(CONTEXT/flavor)·아트(S1-10)·콘텐츠 배치(Slice 7) 이관. S1-5b는 콘텐츠 저작 아닌 메카닉 스코프.

### §7.9 세이브 (Q8)
`orchard.to_save`/`load_save` = FarmField 패턴 계승(Vector2i 키 Dictionary). `save.gd`에 orchard 블록. 로드 시 `_orchard_body` 재구성. 영속·나이가 planted_day 파생이라 세이브 최소(fruit_count만 가변).

### §7.10 헤드리스 검증 (Q8) — `playtest/orchard_test.gd`
`run_tests.sh` +1(자동 발견). **Part A(단위):** ①심기 판정(유효 3×3 성공 / SOLID·is_crop_solid·타 나무 교차 거부) ②성숙(순수 달력, 물주기 무관) ③제철 결실 순환 왕복 — **3a** 제철 결실·**3b** 비제철 정지(count 고정)·**3c ★ 다음 해 제철 재진입**(day 113=`(113-1)/28=4, 4%4=0`→피안절 재개·fruit_count 재증가) ④영속(절기 경계 넘겨도 생존·나이 증가·사멸 0) ⑤나이별 품질(28→0·56→1·84→2·112→3·clamp) ⑥수확(전량 회수·0 리셋) + **★ 제철 내부 수확 후 재결실**(day10 수확 3→0 → day11 fruit_count=1, 수확이 결실 루프 미파괴) ⑦세이브 왕복 + **★ 절기 경계 결착**(day28 세이브→day29 로드→첫 틱 즉시 비제철 반영, 로드-틱 유령과일 차단). **Part B(main 스폰):** ⑧`_orchard_body` 밑동 SOLID·수관 통과 ⑨`season_index_for_day`(1→0피안·29→1유화, CONTEXT 정합). **검증기 이빨:** 음성 mock(비제철인데 결실 등)으로 가드 작동 증명.
