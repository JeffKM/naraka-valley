# 안식 농원 농사·목축 2·3층 그레이박스 수치 명세 (S1-1 산출)

> **상태:** ✅ **곡선 잠금(2026-07-01, S1-1 grill Q8~Q14) + S1-4 착수 경계 잠금(§5) + S1-5a(§6)·S1-5b(§7)·S1-6(§8) 실구현 완료(2026-07-02).** 이 문서는 S1-4~S1-7 빌드의 입력 스펙이다.
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

---

## §8 S1-6 착수 grill 결정 (2026-07-02, `grill-with-docs` Q1~Q4, 품질 4등급 + 비료 + 숙련)

> **상태:** ✅ **실구현 완료(2026-07-02).** 아래 스펙대로 신규 `game/skill.gd`·`game/fertilizer_catalog.gd` + `item_catalog.gd`·`inventory.gd`·`field.gd`·`shipping_bin.gd`·`energy.gd`·`main.gd`·`hotbar_hud.gd`·`inv_frame.gd` 배선 + 검증 2본(`playtest/fertilizer_catalog_test.gd` 순수·경계 / `playtest/quality_skill_test.gd` main 스폰 ⑦~⑭). **전체 40개 통과·부팅 클린·회귀0(crop.gd/orchard.gd 로직 불변).** 이행 메모: FertilizerCatalog↔ItemCatalog는 const 초기화 순환을 피하려 비료 id를 **리터럴로 양쪽 정의**(단방향 의존, 값 어긋남은 §8.12 ④ 검증기가 잡음). 하류 이관은 §8.1 배제 그대로. **grill 잠금(2026-07-02).** S1-1이 곡선을 잠갔고(§3.1 품질 확률표·§3.2 숙련 곡선), S1-5b가 등급 스킴 0..3(`orchard.quality_tier_for_age`)을 선점했다(§7.7 "미래 4등급 표면 수렴" 예고). 이 절은 그 잠긴 곡선을 **밭 작물·인벤토리·판매·숙련 코드로 내리는 경계·범위·검증**을 박제한다. §5(S1-4)·§6(S1-5a)·§7(S1-5b)와 동형 — 슬라이스 내부 신규 파일 + 잠긴 spec 이행이라 **별도 ADR 없음**(Q4). 결정 원천: 본 문서 §3.1/§3.2(정량) · [ADR-0019](../adr/0019-physical-skill-relationship-multiplier-two-axis.md)/[ADR-0020](../adr/0020-item-tool-architecture.md)/[ADR-0027](../adr/0027-tool-tier-aoe-access-skill-efficiency.md)(불변식) · 코드 지형 매핑(2026-07-02).
>
> **네 결정(Q1~Q4):** ①품질 소비 = **판매가 배수 + 인벤토리/핫바 표시까지**(선물 호감도·서빙 품질연동은 하류). ②비료 로스터 = **품질군 3 + 성장촉진군 2 = 5종**(2군 XOR). ③획득 = **START_KIT 소량 지급**(정식 상점=Slice 2 하류). ④숙련 = **`farming_xp` main 스칼라 + 혼력 감산만 실효**(작업속도축=그레이박스 즉시동작이라 계산만·하류 애니), **별도 ADR 없음**.

### §8.1 스코프 경계 (Q1~Q4 종합)
- **포함(건드리는 파일):**
  - 신규 `game/skill.gd`(`class_name FarmSkill`, 순수 static — foxfire.gd 결) · `game/fertilizer_catalog.gd`(`class_name FertilizerCatalog`, 정적 데이터 — fruit_tree_catalog.gd 결).
  - `item_catalog.gd`: `CAT_FERTILIZER` 카테고리 + 품질 등급 상수·`quality_mult`·`price_of(id, quality:=0)` 확장.
  - `inventory.gd`: 슬롯 스키마 `{id,count}` → **`{id,count,quality}`**(스택 키 = id+quality, 아래 §8.3).
  - `field.gd`: 칸 dict에 `fertilizer` 필드 + `fertilize()` 동사 + `roll_quality()` + 성장촉진 성숙 임계 축소(§8.6).
  - `main.gd`: 비료 동사 라우팅 + 밭 수확 품질 적재 + orchard `picked.quality_tier` 실적재(§8.8) + 혼력 숙련 감산 + `_farming_xp` 스칼라·세이브.
  - `shipping_bin.gd`: pending 키에 품질 차원(품질별 판매가 배수).
  - `energy.gd`: `spend(cost)`·`can_act(cost)` 파라미터화(숙련 감산 주입구).
  - 신규 검증 `playtest/fertilizer_catalog_test.gd`(순수 데이터) + `playtest/quality_skill_test.gd`(main 스폰).
- **배제(하류 이관):** 선물 호감도·음식 회복 품질 비례(affinity/cafe — spec §3.1 언급이나 Phase 3 밸런싱) · 비료·묘목 정식 판매처(만물상=Slice 2) · 숙련 '작업 속도' 실효 애니 단축(S1-10) · 품질 아이콘 배지 아트(그레이박스 색/텍스트 표시로 충분, S1-10) · 최종 밸런스 튜닝(Phase 3). **orchard.gd/fruit_tree_catalog.gd 로직 불변**(단 §8.8 소비 지점만 main에서 배선).

### §8.2 품질 등급 = 단일 진실원 (0..3, orchard·field 수렴)
§7.7이 예고한 두 소스(orchard 나이 / field 비료)가 **한 등급 enum·한 판매가 배수 표**로 수렴한다. `item_catalog.gd`에 잠근다:
```gdscript
const Q_NORMAL := 0   # 일반
const Q_SILVER := 1   # 은
const Q_GOLD := 2     # 금
const Q_IRIDIUM := 3  # 이리듐
const QUALITY_MULT := [1.0, 1.25, 1.5, 2.0]   # §3.1 판매가 배수(등급 인덱스)
static func quality_mult(q: int) -> float: return QUALITY_MULT[clampi(q, 0, 3)]
static func quality_name(q: int) -> String: ...   # HUD 표시("일반/은/금/이리듐")
```
- **품질 무차원 아이템(도구·씨앗·묘목) = 항상 Q_NORMAL(0).** 등급은 수확물·과일만 실는다.
- orchard `quality_tier_for_age`(나이→0..3)와 field `roll_quality`(비료→0..3)는 **서로 다른 소스지만 같은 enum·같은 배수 표를 먹인다**(§7.7 "품질=나이 ⊥ 품질=비료 = 두 소스, 미래 4등급 표면 수렴"의 실현). 가공품(카페 메뉴)은 원자재 품질 무시·단일 표준 출력(§3.1 공급망 단순 불변식 — 서빙 경로가 품질을 안 읽어 자연 배제).

### §8.3 인벤토리 슬롯 품질 차원 (스키마 확장 — ADR-0020 예약 실현)
`item_catalog.gd:21` 예약(`슬롯 {id,count}에 quality를 더한다`)을 이행. 슬롯 = `null | {id:String, count:int, quality:int}`(quality 기본 0).
- **스택 키 = (id, quality).** 같은 id·같은 품질 → 합침 / 품질 다르면 **별도 슬롯**(스타듀식 — 은 감자와 금 감자는 다른 칸). `_find_slot`·`add_item`·`move_slot` 병합·`sort`(id+quality 키 합산)·`_sanitize`(quality 기본 0 방어)가 이 키로 갱신.
- **소비 = 최저 품질 우선(worst-first).** `take_harvest(crop, n)`은 그 id의 슬롯들 중 **낮은 품질부터** 소진(플레이어가 프리미엄은 팔고 잡템을 서빙/선물로 소모 — 스타듀 정합). `count_of`/`harvest_count`는 전 품질 합산(선물·서빙 가용 판정 불변). `take_seed`/도구는 전부 Q0라 영향 0.
- **API 확장:** `add_item(id, n:=1, quality:=0)` · `add_harvest(crop, n:=1, quality:=0)`. 기존 호출부(전부 quality 생략)는 Q0로 회귀 0.
- **핫바/가방 표시:** `id_at`/`count_at` 옆 `quality_at(i)->int` 추가 — HUD가 등급 색/글자로 표시(그레이박스, 아트 배지=S1-10). 세이브 = `slots.duplicate(true)` 자동 라운드트립, 구세이브(quality 무) → `_sanitize`가 `int(s.get("quality",0))` 기본 0.

### §8.4 비료 = 카테고리 + 동사 + 타일 상태 (2군 5종 XOR)
- **카테고리:** `item_catalog.gd`에 `CAT_FERTILIZER := "fertilizer"` + `category_of`/`price_of`(=buy_cost)/`name_of`/`stackable_of`(true) 분기.
- **데이터 `fertilizer_catalog.gd`(`class_name FertilizerCatalog`):** 항목 = `{name_ko, group("quality"|"speed"), state|speed_factor, buy_cost}`. **로스터 5종(Q2):**

  | id | 이름(그레이박스) | group | 매핑 | buy_cost |
  |---|---|---|---|---|
  | `fert_basic` | 기초 비료 | quality | `state=BASIC` | 20 |
  | `fert_quality` | 품질 비료 | quality | `state=QUALITY` | 60 |
  | `fert_deluxe` | 디럭스 비료 | quality | `state=DELUXE` | 120 |
  | `fert_speed` | 성장촉진 비료 | speed | `factor=0.75`(−25%) | 40 |
  | `fert_hyper` | 하이퍼 비료 | speed | `factor=0.67`(−33%) | 100 |

  (name_ko 저승 flavor 리네임·아이콘 = 하류. buy_cost = 그레이박스 placeholder, 밸런싱 Phase 3.)
- **타일 상태:** `field.gd` 칸 dict에 `"fertilizer": ""`(비료 아이템 id 또는 "") 1필드 추가 → **XOR·overwrite 자연 성립**(단일 슬롯, 다른 비료 투입 시 덮어씀). 조회는 `_tiles[t].get("fertilizer","")`로 구세이브 방어.
- **동사 `field.fertilize(t, fert_id)`:** 경작된 칸(`is_tilled`, 심김/빈칸 무관)에 유효 비료면 `_tiles[t]["fertilizer"]=fert_id`·overwrite·`tile_changed`·true. `main._use_tool`에 `elif cat == CAT_FERTILIZER:` 분기(§seed 분기 옆) → `farm.fertilize` 성공 시 `inventory.remove_item(item,1)`·verb 세팅(공통 SFX·energy.spend가 뒤이음, main.gd:3720/3737/3739 패턴).

### §8.5 밭 작물 품질 roll (수확 시, 다수확 격리)
§3.1 확률표를 `FertilizerCatalog`에 데이터로 + **순수 테스트 코어** 분리:
```gdscript
const QUALITY_TABLE := {          # state → [일반,은,금,이리듐] 누적경계 아닌 확률(행합 100)
    "NONE":    [80,18,2,0],  "BASIC":   [55,30,13,2],
    "QUALITY": [30,35,27,8], "DELUXE":  [10,30,40,20],
}
static func tier_for_roll(state, roll:int) -> int   # roll 0..99 → 0..3 (결정적·경계 테스트)
static func roll_quality(state) -> int              # = tier_for_roll(state, randi()%100)
```
- **`field.roll_quality(t)`:** `fertilizer` → state 매핑(quality군 → BASIC/QUALITY/DELUXE · speed군/빈 → NONE) → `FertilizerCatalog.roll_quality(state)`. 성장촉진 비료 칸은 품질 NONE(품질과 별 축, §3.1).
- **수확 배선(`main._try_harvest`):** `farm.harvest`가 칸을 비우기 **전에** `var q := farm.roll_quality(_target)` 확보 → 다수확 루프에서 **주 수확분(첫 1개)만 `add_harvest(crop,1,q)`, 나머지 = `add_harvest(crop,1,0)`**(§3.1 "추가분 QUALITY_NORMAL 강제"). `field.harvest` 반환 계약(String) 불변(§6.5와 동형, 품질은 별 조회로 분리).

### §8.6 성장촉진 비료 = 성숙 임계 축소 (advance_day 불변)
성장 루프(`advance_day`·`_grow`·foxfire)를 **안 건드린다** — 성숙 판정 임계만 낮춘다(깔끔한 삽입, foxfire accel과 자연 합성):
```gdscript
func effective_growth_days(t) -> int:   # 성장촉진 비료면 목표일 축소
    var base := CropCatalog.growth_days(crop_of(t))
    var f := FertilizerCatalog.speed_factor(_tiles[t].get("fertilizer",""))  # 1.0 / 0.75 / 0.67
    return base if base < 0 else maxi(1, ceili(base * f))
```
- `is_mature(t)`가 `grown_days >= effective_growth_days(t)`로 비교(기존 `growth_days` 직접비교 대체). REGROW 되감기(§6.4)도 base 기준 유지(비료는 성숙 목표만 낮춤). **foxfire accel(grown_days 가속) ⊗ speed fert(목표 축소) = 곱 없이 둘 다 빨라짐**(합성, 이중적용 아님). `growth_stage`/`grown_days_of` 표시 불변.

### §8.7 판매가 품질 배수 (출하함 경로)
raw 판매는 항상 `ItemCatalog.price_of` 경유(코드 지형 §1). 품질 인자 주입:
- `price_of(id, quality:=0) -> int` = `int(base * quality_mult(quality))`(floor, 스타듀 정합). 기존 무인자 호출 = Q0 회귀 0.
- **`shipping_bin.gd` pending 품질 차원:** `pending: {id: {quality: count}}` 중첩(또는 `"id#q"` 합성키). `add(id,n,quality)` / `preview_gold` = `Σ count * price_of(id, quality)` / `settle`도 품질별. 세이브 = 중첩 Dict `var_to_str` 자동, `_sanitize` 방어(구세이브 flat `{id:int}` → 품질0 취급). `main._on_frame_deposit`가 인벤토리 슬롯 품질을 읽어 `ship_bin.add(id,n,quality)`.

### §8.8 orchard 품질 실적재 (S1-5b §7.7 소비)
`main.gd:3754`가 지금 `picked["quality_tier"]`를 버린다(주석: "S1-6이 소비"). 실적재:
```gdscript
for _i in int(picked["count"]):
    inventory.add_item(picked["fruit_id"], 1, int(picked["quality_tier"]))  # 나이 등급 → 슬롯 quality
```
과일 판매가도 §8.7 배수를 자동으로 받는다(`fruit_tree_catalog.gd:31` "S1-6이 나이 등급 곱" 예고 실현). orchard.gd 로직 불변 — main 소비만.

### §8.9 농사 숙련 (farming_xp main 스칼라, 혼력 감산만 실효)
- **상태:** `main._farming_xp: int`(세이브·복원 = `run_harvested` 선례). 별도 노드 없음(Q4). 순수 함수는 `skill.gd`(`class_name FarmSkill`, foxfire.gd 결):
```gdscript
const XP_THRESHOLDS := [100,300,600,1000,1500,2100,2800,3600,4500,5500]  # L1..L10
static func level_for_xp(xp:int) -> int              # 임계 이하 개수, cap 10
static func energy_factor(level:int) -> float: return 1.0 - 0.03 * clampi(level,0,10)  # L10→0.70
static func speed_factor(level:int) -> float: return 1.0 - 0.03 * clampi(level,0,10)   # 계산만(§아래)
```
- **XP 획득:** 수확 성공 시 `_farming_xp += CropCatalog.sell_price(crop)`(§3.2 crop_base_price). **과수 수확도 농사 XP**(`FruitTreeCatalog.fruit_sell(fruit)` 가산 — 과수=농사).
- **혼력 감산(실효):** `energy.spend(cost)`·`can_act(cost)` 파라미터화. main의 농사 동작 3지점(hoe/plant/water=main.gd:3739 · 밭수확=3774 · **과수수확=3758**)이 `var cost := int(round(SoulEnergy.COST_PER_ACTION * FarmSkill.energy_factor(FarmSkill.level_for_xp(_farming_xp))))`로 감산 소모(L10 → 10→7). **농사 동작에만** 적용(ADR-0019 스킬=활동별). energy.gd는 순수 소모기 유지(레벨을 모름, main 주입 — 디커플링).
- **작업 속도축 = no-op(하류):** 현재 동작은 즉시(애니 프레임 없음) → `speed_factor` 계산만 두고 실효 단축 없음. S1-10 애니 도입 시 소비(§8.1 배제). **불변식(§3.2):** ❌AoE(도구 티어) · ❌+%가치(멜) · ❌품질(비료) · ❌혼력 풀 크기 · ❌레벨 게이팅(L0 전 동작 100% 가동, "평평≠막힘").

### §8.10 획득처 (START_KIT 소량, Q3)
`inventory.gd`에 `START_FERTILIZER := {ItemCatalog.FERT_BASIC: 3, ItemCatalog.FERT_SPEED: 3}`(묘목 선례 `START_SAPLINGS`) — 새 게임 종잣돈에 비료 몇 개로 HOME에서 품질/성장촉진 루프 즉시 체험. 정식 상점 노출(만물상=Slice 2)·전 5종 판매는 하류. 디럭스/하이퍼는 데이터만 등록(테스트 직접 주입), 상점 하류에서 자연 노출.

### §8.11 세이브
- `_farming_xp` → `main._save_game` dict `"farming_xp": _farming_xp` / 복원 `maxi(int(data.get("farming_xp",0)),0)`(손상 방어). `SaveManager` 불변(IO만).
- field `fertilizer` 필드·inventory 슬롯 `quality`·shipping pending 품질 = 각 노드 `to_save`가 자동 포함(순수 Dict 통짜). **구세이브 방어:** 조회 `.get(...,기본)` + 각 `_sanitize`가 결측 필드를 Q0/""로 정규화 → **VERSION 불올림**(save.gd 불변).

### §8.12 헤드리스 검증
`run_tests.sh` +2(자동 발견). **A. `playtest/fertilizer_catalog_test.gd`(순수 데이터, crop_catalog_test 골격):** ①확률표 4행 각 합=100·성분 ≥0 ②`tier_for_roll` 경계(NONE: roll 0..79→0·80..97→1·98..99→2·이리듐 도달 0 / DELUXE: 0..9→0·…·80..99→3) ③등급 배수 `[1.0,1.25,1.5,2.0]`·`quality_mult` clamp ④비료 로스터 2군 5종·group/state/factor 매핑·speed_factor(0.75/0.67, 무비료 1.0) ⑤숙련 임계·`level_for_xp`(99→0·100→1·5500→10·초과 cap)·`energy_factor`(L0=1.0·L10=0.70) ⑥**검증기 이빨:** 행합≠100/등급 역전 mock 주입 → 못 잡으면 크래시. **B. `playtest/quality_skill_test.gd`(main 스폰, orchard_test 골격):** ⑦비료 동사(경작칸 적용·overwrite=품질비료→성장촉진 단일필드 교체·XOR) ⑧밭 수확 품질 적재(DELUXE 칸 `tier_for_roll` 경계 주입→슬롯 quality·**다수확 추가분 Q0 강제**) ⑨성장촉진 성숙 임계 축소(하이퍼 심기→`ceili(base*0.67)`일 성숙, foxfire accel 합성) ⑩인벤토리 품질 스택(같은 작물 다른 품질=별 슬롯·take_harvest worst-first·count_of 합산) ⑪출하 판매가 배수(이리듐 슬롯→×2 preview_gold) ⑫**orchard 품질 실적재**(나이 84 나무 수확→슬롯 quality=2) ⑬숙련(수확 XP 누적·레벨업·energy.spend 감산 확인) ⑭세이브 왕복(farming_xp·타일 fertilizer·슬롯 quality·ship pending 품질 라운드트립 + 구세이브 결측 필드 Q0/"" 방어).

### §8.13 별도 ADR 없음 근거 (Q4)
§5(S1-4)·§6(S1-5a)·§7(S1-5b)와 동형 — 잠긴 spec(§3.1/§3.2) 이행 + 슬라이스 내부 신규 파일(`skill.gd`·`fertilizer_catalog.gd`)이라 새 결정 없음. 인벤토리 슬롯 스키마 확장은 **ADR-0020이 명시 예약한 방향의 실현**(신규 결정 아님). 품질 등급 수렴은 §7.7이 예고. 불변식(ADR-0019 2축·"평평≠막힘"·혼력 풀 불변, ADR-0027 AoE=도구, §3.1 가공 품질무시·비살상)은 전부 준수 — 어기지 않아 개정 ADR 불요.

---

## §9 S1-7 착수 결정 (2026-07-02, 혼의 짐승 목축 = 데일리 돌봄 루프 end-to-end)

> §4.1이 곡선을 잠갔고(우정·기분·산물·비살상), 이 절은 **S1-7 실구현의 경계·로스터·배선·검증**을 박제한다.
> 별도 ADR 없음 — §7(S1-5b)이 Orchard 완전분리를 ADR 없이 박은 것과 동형(ADR-0028 인터리브 + ADR-0025 스펙 카드의 슬라이스 적용). ADR-0004(미호 양육 확장)·ADR-0008(관계=곱셈기, 게이트 아님)·CONTEXT(비살상) 전부 준수.

### §9.1 왜 완전 분리 노드인가 (Orchard와 동형 (A))
짐승은 밭 칸의 crop도, 3×3 나무도 아니다 — **"매일 돌봄으로 우정·기분이 오르내리고 산물을 내는" 데일리 엔티티**다(작물=며칠·나무=절기 vs **짐승=매일**, §4.1 중복 회피 훅). FarmField/Orchard 상태 모델과 안 맞아 한 줄도 안 건드린다(회귀-0 계승). `livestock.gd`(`class_name Ranch`)가 자체 좌표계(타일 키)로 소유하고, `main`이 배치·돌봄·수집·드로우·세이브를 배선한다. 짐승은 **비-SOLID(통과 가능)**라 Orchard의 밑동 충돌 재구성이 없다(더 단순).

### §9.2 스코프 경계 (포함/배제)
- **포함:** `game/animal_catalog.gd`(종·산물 데이터) + `game/livestock.gd`(데일리 돌봄 상태·정산·산물·세이브) + `ItemCatalog` 확장(건초·산물 base/large) + `main` 배선(스타터 배치·advance·수집·세이브·feed/pet/collect/tend 동사·placeholder 드로우) + 격리 검증(`playtest/livestock_test.gd`).
- **배제:** 짐승 AI Navigation·이동(정적 타일 배치 — phaseB §5.4 절벽 천연펜 순찰은 S1-11 아트/애니) · 축사 Enterable 실내(phaseB §5.3 예약만) · 낫 수풀 베기 사일로 건초(ADR-0024 낫 없음 — 건초는 START_KIT/상점 하류) · 미호 곱셈기 가속(ADR-0021 관계층=하류) · 다종 로스터·스프라이트(§9.4 2종·S1-11).

### §9.3 데이터 모델 (`Ranch._animals`)
타일(Vector2i) 키 → 순수 Dict `{species, friendship(0..1000), mood(0..255), fed/petted/grazed/penned/cleaned(bool), product(0/1), product_quality(0..3), product_large(bool)}`. FarmField/Orchard와 같은 결(inner class 없음 → var_to_str 라운드트립). 데일리 케어 플래그는 낮에 플레이어가 세우고, `advance_day`(취침)가 정산 → 산물 생성 → 리셋한다.

### §9.4 로스터 (그레이박스 2종 = coop+barn 아키타입)
| 종 id | 이름 | kind | 산물 id | 산물명 | 기준 판매가 | 대형 |
|---|---|---|---|---|---|---|
| `honbaek_dak` | 혼백 닭 | coop | `honbaek_ran` | 혼백란 | 50 | ✅ |
| `honbaek_so` | 혼백 소 | barn | `honbaek_yu` | 혼백유 | 125 | ✅ |

스타듀 Coop(6)/Barn(5)·산물(19) *참고*하되 자체 2종 큐레이션. 4절기·다종 확장(naming=CONTEXT·아트=S1-11·배치=하류)은 이관 — S1-7=메카닉 스코프. `kind`는 그레이박스 flavor 태그(메카닉 동일).

### §9.5 데일리 정산 공식 (`advance_day`, §4.1 이행)
각 짐승: **① 우정·기분 델타**(하루치, clamp) → **② 산물 생성**(급여한 짐승·대기 없을 때만) → **③ 케어 플래그 리셋**.
```
df = (petted?+15:−2) + (fed?+5:−20) + (grazed?+8:0) + (penned?+5:0)         # 우정
dm = (fed?+40:−60) + (petted?+30:0) + (penned?+40:−40) + (grazed?+30:0) + (cleaned?+20:−30)  # 기분
friendship = clamp(friendship+df, 0, 1000);  mood = clamp(mood+dm, 0, 255)
# 산물: fed && product<=0 → hearts=friendship/200; state=quality_state_for(hearts,mood);
#        product=1; quality=FertilizerCatalog.roll_quality(state);  large = large_capable && randf()<large_chance(hearts)
```
- **품질 = §3.1 엔진 재활용:** 우정 하트+당일 기분 → state(`NONE` 0~1 · `BASIC` 2~3 · `QUALITY` 4 · `DELUXE` 5+기분≥200) → `FertilizerCatalog.tier_for_roll` 확률표(작물 비료와 같은 코어). `quality_state_for`는 순수 함수(결정적 경계 검증).
- **대형 = 별 축:** `large_chance(hearts)=(hearts/5)*0.5`(만렙 0.5). 대형이면 `<산물>_large` 아이템(판매가 ×2)으로 적재.
- **⚠️ 비살상 불변식:** `advance_day`는 절대 `_animals` 키를 지우지 않는다 — 어떤 방치도 우정·기분 감산으로만(CONTEXT 죽음 단일화). 미급여 = 산물 0(스타듀 결).
- **초기값:** 새 짐승 우정 0(0하트→산물 NONE)·기분 128(중립). 성숙 게이트 없음(급여 시 1일차부터 산물 — 그레이박스).

### §9.6 산물·건초 아이템 (`ItemCatalog` 확장, `_is_fruit` 결)
- **건초** `HAY`=CAT_MATERIAL(예약 카테고리 실사용 개시)·품질 무차원 스택·기준가 10. START_KIT 6개.
- **산물** = CAT_HARVEST(작물 수확물·과일 동급 — 판매·출하·스택·품질). **대형** = `<산물>_large` 접미 변이(씨앗:수확물=산물:대형 결). `price_of`: 대형 = 기준 ×2 × 품질배수(대형·품질 직교 → 대형 이리듐 = ×4). 데이터·이름·판매가는 `AnimalCatalog`에 위임(단방향).

### §9.7 main 배선 (in-game 루프)
- **스타터 배치:** 신규 게임(세이브 無)만 `_ensure_starter_animals` — 하늘 목장 방목지(`PASTURE_SCAN_RECT` x1..18 y17..24) 걷기 가능 타일에 2종을 2칸+ 간격 배치. 세이브 복원은 `load_save`(멱등, count>0이면 skip).
- **입력(하늘 목장 풀=비-SOIL이라 `_target_valid`(SOIL) 게이트 밖 별도 디스패치):** LMB(건초 든 채)=급여(건초 1 소모) · RMB=산물 있으면 수집(대형=large 아이템·품질 실적재)·없으면 쓰다듬 · 축사 문(`BARN_EXT_DOOR`) RMB=축사 돌봄(방목·격리·청결 `tend_all` 일괄). 모두 혼력 소모(농사 동작 결).
- **advance/세이브:** `_on_day_advanced`에 `ranch.advance_day()`(orchard 옆) · save/load `"ranch"` 키(구세이브=짐승 0) · `changed`→`_on_ranch_changed`(충돌 없이 redraw만).
- **드로우:** `_draw_ranch` placeholder(종별 색 몸통·머리 점·대기 산물 점·우정 하트 바 5칸). 스프라이트·워크 애니 = S1-11.

### §9.8 헤드리스 검증 (`playtest/livestock_test.gd`, orchard_test 골격)
`run_tests.sh` +1(자동 발견). **Part A(Ranch/카탈로그 단위):** ①배치(성공·중복거부·미지종거부) ②케어 플래그(세움·중복거부·tend_all) ③정산(완전돌봄 +33우정·255기분 saturate / 완전방치 0·0 clamp·리셋) ④하트 파생(1000→5·850→4·399→1) ⑤품질 state 경계(NONE/BASIC/QUALITY/DELUXE 기분게이트) ⑥대형확률(0·0.2·0.5) ⑦산물 급여게이트(급여만 생성·미급여 0·대기중 프리즈) ⑧수집(반환·리셋·미대기 빈) ⑨**비살상**(방치 10일 count 불변·존재·바닥 clamp) ⑩세이브 왕복 ⑪ItemCatalog(산물 CAT_HARVEST·대형 ×2·×4·건초 CAT_MATERIAL). **Part B(main 스폰, 세이브 백업·삭제로 신규게임 강제):** ⑫ranch 스폰·스타터 시드≥1·걷기가능 타일·급여→advance→산물→수집 인벤토리 적재. (품질/대형 roll은 난수라 값 아닌 *state·확률 파생*과 *생성 여부*만 단언.)

### §9.9 별도 ADR 없음 근거
§5~§8과 동형 — 잠긴 spec(§4.1) 이행 + 슬라이스 내부 신규 파일(`animal_catalog.gd`·`livestock.gd`). ADR-0004(미호 양육 확장·새 캐릭터 X)·ADR-0008(관계=곱셈기 — 우정은 산물 품질·대형을 *가속*하되 base 산물은 0하트에서도 급여만으로 나옴="평평≠막힘")·CONTEXT(비살상) 전부 준수. 미호 곱셈기(농사 XP 결의 목축 가속)는 이 곡선 *위*에 후행(ADR-0021, 하류) — 어기지 않아 개정 ADR 불요.

---

## §10 S1-8 착수 결정 (2026-07-02, 개간 = overgrown debris 3종 치우기 end-to-end)

§5~§9와 동형 — 잠긴 배치(ADR-0035 Phase B·[phaseB-layout §5](./homestead-phaseB-layout.md))의 **개간 메카닉을 이행**한다. 신규 파일(`debris_catalog.gd`·`reclaim.gd`)로 완전 분리(orchard/ranch 결), `field.gd`·`_prop_layouts`(설계 시드=layout.json) **불변**. 별도 ADR 없음(§10.8).

### §10.1 스코프 경계 (포함/배제)
- **IN:** 신규 `reclaim.gd`(`class_name Reclaim` — orchard/ranch 동형 분리 노드: **치운 debris 좌표 델타**만 소유·세이브·`changed`) · 신규 `debris_catalog.gd`(debris 3종→도구·드랍·통과 규칙 데이터) · 도구 3종(낫/곡괭이/도끼) `ItemCatalog.TOOLS` · 드랍 재료 3종 `CAT_MATERIAL` · LMB 개간 분기(짐승처럼 `_target_valid`(SOIL) 게이트 **밖** 별도 디스패치 — debris는 GROUND 위) · 드로우/충돌 **skip-filter**(치운 debris 미표시·통과) · **치운 타일→farmable**(경작지 확장) · 세이브/로드 · 헤드리스 검증.
- **OUT(하류):** 도구 정식 획득(상점=Slice2, 지금 START_KIT 무상) · debris 리스폰/재생성(그레이박스=1회성, 안 자람) · 드랍 재료 가공(Phase 3) · 개간 툴스윙 애니(S1-10) · 미호 곱셈기(ADR-0021).

### §10.2 debris ↔ 도구 ↔ 드랍 매핑 (`debris_catalog.gd`)
| debris(CONTEXT) | 텍스처 | 도구 | 통과 | 드랍(CAT_MATERIAL) | 수 |
|---|---|---|---|---|---|
| 이승의 미련(잡초) | `PROP_DEBRIS_WEEDS` | 낫 `SCYTHE` | O(장식) | 혼백 섬유 `soul_fiber` | 1 |
| 업화석(돌) | `PROP_DEBRIS_EMBER` | 곡괭이 `PICKAXE` | X(SOLID) | 업화석 조각 `ember_shard` | 2 |
| 석화 고목(그루터기) | `PROP_DEBRIS_STUMP` | 도끼 `AXE` | X(SOLID) | 석화 목재 `petrified_wood` | 2 |
- **맞는 도구만** 그 debris를 연다 — 틀린 도구=무동작(ADR-0024 §2 "선택 도구가 장식이 되지 않게"). 드랍 수는 **결정적**(roll 없음, 그레이박스). ※`PROP_STUMP`(장식 통나무)는 debris **아님**(별 텍스처).
- **배치(잠김, `PROP_LAYOUT_HOME` 시드):** 미련 9칸 · 업화석 4칸(하드게이트 (24,14) + 산포 3) · 석화고목 4칸(하드게이트 (24,16) + 산포 3) = 총 17.

### §10.3 상태 = 치운 좌표 델타 (`_prop_layouts` 불변)
- debris 배치는 `PROP_LAYOUT_HOME`(설계 데이터·layout.json)에 그대로 둔다. `Reclaim`은 **치운 좌표 집합 `_cleared: Dictionary`(Vector2i→true)만** 소유(플레이어 세이브 델타). `_prop_layouts`는 절대 안 건드린다(layout.json 오염 방지 — 설계 시드 순수 유지).
- **드로우**(`_draw_props_for`)·**충돌**(`_rebuild_prop_collision`)에서 debris 텍스처 타일이 `reclaim.is_cleared(t)`면 **skip** → 안 그리고 안 막는다. (CAFE/VILLAGE는 debris 텍스처 無 → no-op.)
- `reclaim.clear(tile, kind, tool_id)`: 이미 치웠거나 도구 불일치면 `{}` 반환(무동작). 성공 시 `_cleared[tile]=true`·`changed.emit()`·`{"drop":id,"count":n}` 반환. **멱등**(재개간 X).

### §10.4 경작지 확장 = 치운 타일 farmable
- 치운 debris 타일을 `reclaim`가 farmable로 표시 → `_is_farmable`가 **SOIL ∪ reclaimed**(HOME) 반환 → 괭이질 가능(스타듀식 풀→틸드 오버레이). 지형(`_grid`)·타일셋 **불변**(구역 재빌드 안전 — 세이브는 reclaim 델타만, 틸드는 farm 상태). `_cleared` = reclaimed 집합(치움=개간 완료=경작 가능, 단일 집합).

### §10.5 소프트락 0
- 고지(하늘 목장) 계단 노치를 막는 **하드게이트** 업화석(24,14)·석화고목(24,16)은 START_KIT 곡괭이·도끼로 즉시 개간 → 고지 항상 도달(계단 통과). 스타터 패치(40,12,5,5)는 debris 0%(설계 불변). `START_TOOLS`에 낫/곡괭이/도끼 추가(무상 그레이박스).

### §10.6 세이브
- `to_save() → {"cleared": [[x,y],...]}` / `load_save(data)`(통째 교체 후 `changed.emit`). main `_save_game`에 `"reclaim"` 키(orchard/ranch 옆), `_load_game` 복원 시 `_on_reclaim_changed`로 드로우/충돌 반영. 구세이브(키 無)=치운 것 0(전 debris 유지, 방어적).

### §10.7 헤드리스 검증 (`playtest/reclaim_test.gd`, orchard_test 골격)
`run_tests.sh` +1(자동 발견). **Part A(Reclaim/카탈로그 단위):** ①`DebrisCatalog` 매핑(3종 도구·드랍·수·solid·is_reclaim_tool·미지 kind 방어) ②맞는 도구 개간 성공·드랍 반환 정확 ③틀린 도구 무동작(`{}`) ④멱등(이미 치운 것 재개간 `{}`·`_cleared` 불변) ⑤is_cleared/카운트 ⑥세이브 왕복(치운 집합 복원). **Part B(main 통합, 세이브 백업·삭제로 신규게임 강제):** ⑦START_TOOLS 3종 존재 ⑧하드게이트 업화석/석화고목 좌표에 debris kind 조회됨 ⑨곡괭이/도끼로 개간→`is_cleared`·충돌 제거(통과 가능)·`_is_farmable` true(경작지 확장)·드랍 인벤토리 적재 ⑩스타터 패치 debris 0.

### §10.8 별도 ADR 없음 근거
§5~§9와 동형 — 잠긴 배치(ADR-0035 Phase B) 이행 + 슬라이스 내부 신규 파일. ADR-0024(든 도구=동사·틀린 도구 무동작)·ADR-0035(개간 메카닉은 Slice 1)·ADR-0008(관계=곱셈기 — 개간은 도구·혼력만, 관계 무관)·CONTEXT(이승의 미련·업화석·석화 고목) 전부 준수. 미호 곱셈기(개간 가속)는 하류(ADR-0021) — 어기지 않아 개정 ADR 불요.

---

## §11 S1-9 착수 grill 결정 (2026-07-02, `grill-with-docs` Q1~Q8, 집 꾸미기 = 집 내부 3레이어 코스메틱)

> **상태:** ✅ **실구현 완료(2026-07-02, PR #154, `home_deco_test` 44단언 PASS·회귀0·부팅 클린).** 신규 `home_deco_catalog.gd`·`home_deco.gd` + main 배선 + `playtest/home_deco_test.gd`. `layout.json`·`_prop_layouts`·`field/orchard/ranch/reclaim` 불변. 착수 grill 잠금(2026-07-02, 코드 0). 시스템 레벨 설계는 [CONTEXT '집 꾸미기'](../../CONTEXT.md)에서 이미 잠김(grill 2026-06-29, ADR 없이 CONTEXT+카탈로그): 자유 그리드 3레이어(바닥재+벽지+가구)·순수 코스메틱(버프0/게이트0)·테마 세트=해금 시 무한·무료 배치 팔레트·디제시스 반응·무제작 게이트. 본 절은 그 위의 **실구현 경계·범위·검증**을 박제한다. §5~§10과 동형 — 슬라이스 내부 신규 파일(`game/home_deco.gd`·`game/home_deco_catalog.gd`·`playtest/home_deco_test.gd`)이라 **별도 ADR 없음(§11.9)**. 결정 원천: CONTEXT 집 꾸미기 절 · [ADR-0008](../adr/0008-growth-model-relationship-multiplier.md)(평평≠막힘·관계=곱셈기, 코스메틱은 버프 아님)·[ADR-0019](../adr/0019-physical-skill-relationship-multiplier-two-axis.md)(+가치 배제)·[ADR-0020](../adr/0020-item-tool-architecture.md)(예약 스키마)·[ADR-0025](../adr/0025-in-game-prop-placement-mode-data-externalization.md)(F10 저작 도구 — **이것과 완전 분리**, §11.1).

### §11.1 스코프 경계 (Q1·Q2) — F10 저작 도구와 완전 분리, layout.json 시드 불변
- **완전 분리(Q1):** 기존 F10 배치 모드(ADR-0025)는 **개발자가 월드 가구를 저작하는 시드**(`layout.json`·`_prop_layouts`·`_EDIT_PALETTE` 외부 장식뿐)다. 플레이어 집 꾸미기는 **세이브별·집 내부 한정·순수 코스메틱**으로 의미가 다르다 → `reclaim.gd` 동형의 **새 얇은 델타 모듈**(`home_deco.gd`)이 소유. `layout.json` 시드·`_prop_layouts`·F10 오버레이는 **한 줄도 안 건드림**(회귀 0). 다른 저장소(세이브 델타 vs git 시드)·다른 생명주기·다른 팔레트.
- **IN(그레이박스 메카닉):** 신규 `home_deco.gd`(`class_name HomeDeco` — 3레이어 배치 델타 + 해금 세트 소유·세이브·`changed`) · 신규 `home_deco_catalog.gd`(`HomeDecoCatalog` static — 테마 세트 정의) · 3레이어(바닥재·벽지·가구) per-cell 배치/삭제/회전 로직 · 플레이어 꾸미기 모드(집 실내 전용 진입·마우스 커서 배치·키 팔레트) · placeholder 세트 **2개** · 해금 상태 세이브 추적 · 디제시스 **최소 스텁**(읽기전용 조회 표면 + 앰비언트 한 줄) · 순수 코스메틱 불변식 · 헤드리스 검증.
- **OUT(하류):** 세트 **에셋 아트**(S1-11 — 그레이박스는 색 블록/텍스트) · **목공방·떠돌이 상인 상점** 해금 UI(Slice 2 — 지금 START로 2세트 무상) · **집 평수 업그레이드**(별도 미래 — 현재 고정 룸 rect) · **디제시스 NPC/배우자 반응**(Slice 8 관계 — 지금 조회 표면 훅 + 앰비언트 한 줄만) · **멀티셀 가구**(그레이박스=1×1) · 최종 밸런싱.

### §11.2 3레이어 데이터 모델 (Q3) — 바닥재·벽지=per-cell 칠 / 가구=배치+회전
| 레이어 | 모델 | 저장(각 레이어 자체 Vector2i-키 Dict) | 렌더 |
|---|---|---|---|
| **바닥재 FLOOR** | per-cell "칠하기"(룸 바닥 칸 커버링 오버라이드) | `floor: { Vector2i: {set,item} }` | 기존 바닥 타일 **위** 오버레이 |
| **벽지 WALL** | per-cell "칠하기"(벽 밴드 칸 오버라이드) | `wall: { Vector2i: {set,item} }` | 벽 밴드 위 오버레이 |
| **가구 FURNITURE** | discrete 배치 오브젝트 + 회전 | `furniture: { Vector2i: {set,item,rot} }` | props 위 그리기 |
- **회전은 가구만.** `rot: int` — **데이터 모델은 4방(0..3) 지원**(멀티셀·방향 아트 대비 파이프라인 자리), 그레이박스 **렌더는 2방(가로/세로 flip) 또는 4방 텍스트 표기**만 대응.
- **가구는 1×1 단순화(Q3).** 멀티셀(침대 2×1·탁자 2×2)은 하류.
- **레이어 간 같은 셀 공존, 같은 레이어 안에서만 셀당 1(Q7).** 한 셀에 바닥재+벽지+가구 3중 공존 가능(다른 레이어) / 같은 레이어 재배치 = overwrite.
- **배치 경계:** 룸 rect의 걸을 수 있는 바닥 칸(FLOOR·FURNITURE) / 벽 밴드 칸(WALL). `HOME_HOUSE_RECT` 실내 좌표 파생. 경계 밖 배치 거부.

### §11.3 테마 세트 카탈로그 (Q4) — 3레이어 가로지르는 세트, `home_deco_catalog.gd`
- **세트 = 3레이어를 가로지르는 아이템 묶음.** 각 세트 `{id, name, items:[...]}`, 각 item `{key, layer, is_solid}` (`layer ∈ {FLOOR, WALL, FURNITURE}`). 러그=FLOOR·벽장식=WALL·침대/탁자/화분/조명=FURNITURE로 흡수. **세트 1개가 3레이어 전부에 ≥1 아이템**(그 세트만 깔아도 완성된 룩 — CONTEXT).
- **placeholder 2세트:** `SOULFIRE`(혼불)·`HIGANBANA`(피안화). 세트-간 믹스(혼불 가구 + 피안화 바닥) 검증 가능.
- **`is_solid: bool` 하류 훅(Q5):** 그레이박스는 전부 통과 가능(무충돌)이나, 가구 item에 `is_solid`를 **미리 심어둔다** — 훗날 아트 입힐 때 `home_deco.gd`가 `_rebuild_prop_collision` **동형의 얇은 런타임 충돌 빌더**를 호출해 켤 파이프라인 자리만 마련.

### §11.4 해금 = 무한 팔레트 (Q4) — 세이브 추적
- **해금 상태를 지금부터 세이브에 추적:** `home_deco.unlocked_sets`(세트 id 집합). 배치는 **해금된 세트의 아이템만** 허용 → "해금하면 그 세트 전체가 무한·무료 배치 팔레트, 낱개 비용 0"(CONTEXT) 실현.
- **신규 게임:** main이 START로 `unlocked_sets = [SOULFIRE, HIGANBANA]` 2세트 무상 지급(상점=Slice 2 하류 훅만 남김).

### §11.5 플레이어 꾸미기 모드 (Q5) — 집 실내 전용, 마우스 배치, 비용 0, 무충돌
- **진입 게이트:** `_region == RegionCatalog.HOME and _indoor == 집 건물 id`일 때만 **KEY_C**(F키 회피 — 맥북 F10 시스템 키 이슈)로 토글 진입. 밖·타 구역·타 건물에선 진입 불가.
- **커서 배치:** 마우스 커서 기반 셀 조준 → **LMB=배치 / RMB=삭제**.
- **팔레트:** 키 조작으로 레이어(바닥재/벽지/가구) 전환 · 해금 세트+아이템 순환 · 가구 회전(rot 0..3).
- **순수 코스메틱:** 에너지·시간·골드 소모 0(`energy.spend`·`wallet` 미호출).
- **충돌:** 그레이박스 = **통과 가능(무충돌)** — soft-lock 회피·버프0/게이트0 정합. `SOLID_PROPS` 충돌 인프라 안 씀. (충돌 켜기 = §11.3 `is_solid` 하류 훅.)

### §11.6 디제시스 최소 스텁 + 순수 코스메틱 불변식 (Q6)
- **읽기전용 조회 표면:** `home_deco.deco_summary()` — 레이어별 배치 수 / 총 아이템 수 / 세트 다양성 같은 **순수 카운트 스칼라**. S1-9의 어떤 게임플레이 시스템도 소비 안 함 → Slice 8 NPC/배우자 대사가 붙을 **훅만**.
- **앰비언트 한 줄(포함):** 꾸며진 집 진입 시 `_notice`/flavor로 자기완결 한 줄(관계 미터·버프 0, 순수 감상 — 체키 앨범 결·CONTEXT "앰비언트 한정").
- **버프 0 못박기:** home_deco는 **곱셈기·확률·XP·골드·에너지 반환 API가 아예 없다**(조회 표면은 카운트 스칼라뿐). 배치 동사가 경제/능력치 노드를 **호출하지 않음**을 검증 테스트가 단언(reclaim이 리스폰 안 함을 단언하듯).

### §11.7 세이브 (`home_deco` 델타 키) — reclaim/orchard 동형
- `to_save()`:
  ```
  { "unlocked_sets": ["SOULFIRE","HIGANBANA"],
    "floor":     [[x,y,set,item],...],       # per-cell 바닥재
    "wall":      [[x,y,set,item],...],       # per-cell 벽지
    "furniture": [[x,y,set,item,rot],...] }  # 배치 가구(+회전)
  ```
- **JSON 안정성:** Vector2i를 `[x,y]` 배열로(§10.6 reclaim 동형, `var_to_str` 대신 명시 목록). 로드 시 각 레이어를 Vector2i-키 Dict로 재구성.
- main `_save_game`에 `"home_deco"` 키(reclaim 옆), `_load_game` 복원 후 `changed.emit()` → 재드로우(+§11.3 충돌 하류 훅). **구세이브 방어:** 키 없으면 빈 델타·해금 0(typeof 체크 reclaim 동형).

### §11.8 헤드리스 검증 (`playtest/home_deco_test.gd`, reclaim_test 골격)
`run_tests.sh` +1(자동 발견). **Part A(HomeDecoCatalog/HomeDeco 단위):** ①카탈로그 커버리지 — 2세트 각각 3레이어 전부에 ≥1 아이템·모든 item `layer ∈ {FLOOR,WALL,FURNITURE}`+`is_solid: bool` 존재 ②해금 게이팅 — 잠긴 세트 아이템 배치 거부·해금 세트 수락 ③원장 — 3레이어 배치·같은 레이어 같은 셀 overwrite·**레이어 간 같은 셀 공존**·삭제·회전(rot 0..3 순환) ④배치 경계 — 룸 rect 밖/비바닥 칸 FLOOR·FURNITURE 거부·벽 밴드 밖 WALL 거부 ⑤버프 0(검증기 이빨) — 곱셈기 반환 메서드 부재·배치 시그니처가 경제/능력치 노드 안 받음·`deco_summary()` 카운트 스칼라만 ⑥세이브 왕복. **Part B(main 통합, 세이브 백업·삭제로 신규게임 강제):** ⑦집 실내 진입→KEY_C 토글→두 세트 아이템 3레이어 믹스 배치(혼불 가구 + 피안화 바닥) ⑧세이브→리로드 영속(`unlocked_sets`+3레이어 배치 생존) ⑨꾸며진 집 재진입 시 앰비언트 한 줄 발화 ⑩버프 0 end-to-end(배치 전후 energy·wallet·farming_xp 불변).
- ⚠️ **신규 class_name(`HomeDeco`·`HomeDecoCatalog`) 추가 → `godot --headless --editor --quit`로 전역 클래스 캐시 재생성 필수**([[headless-test-classcache-flakiness]] — 안 하면 헤드리스 `--script`가 "Identifier not declared" 파싱에러).

### §11.9 별도 ADR 없음 근거
§5~§10과 동형 — 시스템 설계는 CONTEXT(집 꾸미기, grill 2026-06-29)에서 이미 잠겼고 이 절은 슬라이스 내부 신규 파일로 그걸 이행. ADR-0008(평평≠막힘·코스메틱은 버프 아님)·ADR-0019(+가치 배제)·ADR-0020(예약 스키마 실현)·ADR-0025(F10 저작 도구와 완전 분리) 전부 준수. 되돌리기 비싼 놀라운 트레이드오프 없음(F10 분리는 reclaim 델타 패턴 재적용) → 개정/신규 ADR 불요.
