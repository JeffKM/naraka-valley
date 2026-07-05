# 활동 스킬 전문직 트리 그레이박스 명세 (ADR-0052 산출)

> **상태:** ✅ **프레임워크 구현 완료(2026-07-05, 채집 파일럿).** 이 문서는 ADR-0052 로스터의 *코드 데이터 모델 + 차원 규칙 + XP 소스 배선 계획*을 잠근다(정성 결정 = [ADR-0052](../adr/0052-activity-skill-professions-revive-nonvalue-dimensions.md), 정량/구현 = 본 문서). 농사 [homestead-farming-greybox-spec](./homestead-farming-greybox-spec.md)와 대칭.
>
> **스코프:** 재사용 스킬+전문직 **프레임워크**(카탈로그·선택 상태·세이브·퍼크 조회 API·XP 곡선)를 잠근다. **채집(FORAGING)이 파일럿** — 퍼크 시맨틱 완비. 나머지 4스킬은 트리 *구조*만(퍼크=[], 각 스킬 슬라이스에서). **라이브 퍼크 배선(실제 산출에 퍼크 적용)은 defer** — 채집 루프(저승 숲·야생 씨앗)가 아직 없어([ADR-0033] "안식=채집 없음") XP 소스·퍼크 적용점을 그 슬라이스로 미룬다("프레임워크 우선", owner 2026-07-05).

---

## §1 데이터 모델 (`game/profession_catalog.gd`)

`class_name ProfessionCatalog` — 무상태 static 규칙·데이터(FarmSkill과 같은 결). 선택 *상태*는 main 스칼라(`_professions`)가 들고 저장(FarmSkill↔`_farming_xp` 관계 동일).

```
스킬 id      : FARMING | FORAGING | MINING | FISHING | COMBAT   (SKILLS 5종)
profession   : {id, tier(5|10), requires(tier10=부모 lvl5 id / tier5=""), name, desc, perks:[{dim,value}]}
트리 구조    : 스킬당 lvl5 2갈래 → lvl10 각 2분기(총 6). tier10 requires로 2:2 게이팅.
```

**퍼크 차원(비-가치 4차원 — ADR-0052 §1, +판매가/마진 슬롯 부재):**

| dim 상수 | 차원 | 채집 사용처 |
|---|---|---|
| `DIM_QUALITY_FLOOR` | 품질(등급 하한) | 약초학자 → 3(Q_IRIDIUM 고정) |
| `DIM_DOUBLE_DROP` | 수량(2배 확률) | 채집꾼 → 0.20 |
| `DIM_WOOD_BONUS` | 수량(+N) | 감지자 → 원목 +1 |
| `DIM_HARDWOOD` | 자원(flag) | 벌목꾼 → 단단한 원목 |
| `DIM_TAP_QUALITY` | 품질(flag) | 수액꾼 → 수액 등급↑ |
| `DIM_DETECT` | 편의(range) | 감지자 → 감지 범위 |
| `DIM_TRACK` | 발견(flag) | 추적자 → 위치 표시 |

> **불변식:** 차원 이름에 `price`/`margin`/`value` 없음(테스트 ②가 강제) — +판매가/마진은 관계 곱셈기(멜/미호/바나) 전용. 로더가 base 위에 곱하되 *마진 슬롯은 안 밟음*(ADR-0019 §13 "숫자 비충돌" 계승).

## §2 선택 상태·규칙 (`main.gd`)

- **상태:** `_foraging_xp: int`(채집 XP·FarmSkill 곡선 공유) + `_professions: {skill:{tier:id}}`(선택). 둘 다 세이브(`"foraging_xp"`·`"professions"` 키). 구세이브 결측 = 0/미선택("평평≠막힘").
- **XP 곡선 = FarmSkill 공유** — `XP_THRESHOLDS [100,300,600,1000,1500,2100,2800,3600,4500,5500]`·`level_for_xp`는 스킬-불특정. 스킬별 XP는 별 스칼라, 곡선은 하나.
- **선택 게이트(`_can_choose_profession`):** ①실존 ②스킬 레벨 ≥ tier ③슬롯 1회(재선택 거부·스타듀 책 변경은 defer) ④tier10 부모 lvl5 정합. 레벨 게이트는 *접근 게이트 아님* — L0도 활동 100% 가동, 전문직은 곱셈 편의 해금.
- **조회 API(로더가 호출):** `_perk_value(skill, dim, default)`(고른 전문직 퍼크 max) → 편의 래퍼 `forage_quality_floor()`·`forage_double_drop_chance()`. `has_profession`·`_pending_profession_tier`(UI 배지)·`_skill_level`.
- **UI:** `_skill_rows()`에 채집 행 추가(농사와 대칭) + `profession`(고른 이름)·`pending_tier`(선택 가능 5/10) 필드. **인터랙티브 선택 picker UI는 얇은 후속**(현재 데이터·로직·API 완비, 프레임 렌더는 채집 행/배지까지).

## §3 XP 소스 배선 계획 (defer — 각 루프 슬라이스)

프레임워크는 `_gain_forage_xp(amount)` 헬퍼만 잠갔다(농사 `_gain_farm_xp` 대칭). **어디서 호출하나 = 그 루프 구현 시:**

| 스킬 | XP 소스(계획) | 현재 상태 |
|---|---|---|
| 채집 | 저승 숲/해변/갱도 줍기·야생 씨앗 수확([ADR-0033]) | 루프 미구현 → defer |
| 채집 | 벌목·수액(나무 작업 갈래) | 저승 숲/목공방 Phase 3 |
| 농사 | 수확(이미 배선 — `_gain_farm_xp` main.gd) | ✅ 가동 |
| 채광·낚시·전투 | 각 활동 산출 시 | 각 시스템 슬라이스 |

## §4 퍼크 적용점 계획 (defer)

로더(loop)가 `_perk_value`를 읽어 base 위에 얹을 지점(라이브 배선 시):

- **약초학자** → 채집 루트 loot 품질 롤 자리에서 `forage_quality_floor()`로 등급 하한 강제(Q_IRIDIUM). *비료 품질 롤(field.gd)과 별 경로* — 채집물은 비료 안 씀([ADR-0033] 품질=스킬 주도로 개정).
- **채집꾼** → 채집 pickup 수량 산정에서 `forage_double_drop_chance()` 확률로 ×2.
- **감지자/추적자** → 채집물 감지·화면 표시(HUD 레이어).
- **벌목꾼/수액꾼** → 벌목 드롭·수액 채취기 산출.

## §5 검증 (완료)

`game/playtest/profession_test.gd` — 36단언 PASS(2026-07-05):
- Part A(순수): 5스킬 구조·2:2 게이팅·채집 퍼크 시맨틱·+가치 차원 부재·조회 방어.
- Part B(main): 레벨 게이트·선택 규칙(슬롯 1회·부모 정합)·퍼크 API 실효·pending tier·세이브 왕복·구세이브 4종 손상 방어·XP 레벨업.

## §6 남은 것 (defer)

1. **인터랙티브 전문직 선택 picker UI**(숙련 탭에서 pending tier 도달 시 2갈래 선택 — 현재 로직·데이터 완비, 렌더/입력만).
2. **채집 라이브 루프**(저승 숲 줍기·야생 씨앗 재배) — XP 소스·퍼크 적용점 배선.
3. **나머지 4스킬 퍼크 시맨틱**(각 스킬 빌드 슬라이스 — 구조는 카탈로그에 잠김).
4. **전문직 재선택/리스펙**(스타듀 책 대응 — 현재 1회 고정).
