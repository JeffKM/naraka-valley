# ② 관계형 인벤토리 + N+1 (플래그십 항목)

선생님이 "진부하다"고 한 N+1을, **게임 인벤토리 도메인**으로 풀어 흥미롭게 만든다.
진부함 탈출의 두 축은 그대로: **숫자(측정)** + **이유(ADR)**.

## 왜 관계형인가 (N+1 스토리의 전제)

인벤토리를 JSON 한 컬럼에 직렬화하면 구현은 쉽지만 **N+1 자체가 안 생긴다**.
관계형을 정당화하는 핵심 근거는 **🔑 수집률/도감 랭킹의 크로스-유저 집계**다 — 모든 유저가 가진 *서로 다른 아이템 종류 수*를
`GROUP BY`로 집계하려면 JSON 블롭으론 전 유저를 스캔해야 하므로 **관계형이 진짜로 필요**하다. 여기에 **서버검증·아이템별 쿼리**가
보조 근거로 붙는다. → 그 대가로 N+1이 필연 발생 → 최적화 스토리 성립. (→ ADR-0001)

> 🔁 옛 설계는 "거래소" 를 관계형의 주력 근거로 삼았으나, 거래소는 싱글플레이에 없는 가짜 기능이라 들어냈다(ADR-0003).
> 그 빈자리를 **수집률 랭킹 집계**가 메운다 — 관계형은 *편의*가 아니라 *필요*가 된다.

## 인벤토리 ERD

```mermaid
erDiagram
    MEMBER ||--|| INVENTORY : "보유"
    INVENTORY ||--o{ INVENTORY_SLOT : "슬롯"
    INVENTORY_SLOT }o--|| ITEM : "아이템 정의"
    INVENTORY_SLOT ||--o{ ITEM_OPTION : "커스텀 상태"
    ITEM }o--|| ITEM_CATEGORY : "분류"

    MEMBER { bigint id PK }
    INVENTORY { bigint id PK; bigint member_id FK }
    INVENTORY_SLOT { bigint id PK; bigint inventory_id FK; bigint item_id FK; int quantity }
    ITEM { bigint id PK; bigint category_id FK; string code; string name }
    ITEM_OPTION { bigint id PK; bigint slot_id FK; string key; string value }
    ITEM_CATEGORY { bigint id PK; string name }
```

- 연쇄: `Member → Inventory → InventorySlot → Item → Category` + `Slot → ItemOption(N)`
- **신선도·강화수치 같은 커스텀 상태**는 `ITEM_OPTION`(슬롯당 N개) → 컬렉션 N+1까지 발생

## N+1이 터지는 지점

**로그인/세이브 동기화 시 서버가 인벤토리 전체를 검증차 로드:**

```java
Inventory inv = inventoryRepository.findByMember(member); // 1쿼리
for (InventorySlot slot : inv.getSlots()) {        // 슬롯 N개 (LAZY) → +1
    slot.getItem().getCategory().getName();        // 아이템/카테고리 추가 쿼리
    for (ItemOption opt : slot.getOptions()) { ... } // 옵션 컬렉션 → 또 N+1
}
```

## before/after 측정표 (목표 산출물)

시드: 슬롯 100개, 슬롯당 옵션 평균 2개.

| 방식 | 쿼리 수 | p95(ms) | 트레이드오프 |
|---|---|---|---|
| (A) 무대책 LAZY | 1 + 100×(1+1) + 100 = **301** | — | N+1 폭발 |
| (B) fetch join (ToOne) + batch (ToMany) | **약 3** | — | 컬렉션 2개↑면 fetch join 불가 → batch 병행 |
| (C) @EntityGraph | 2~3 | — | 선언적, 동일 한계 |
| (D) default_batch_fetch_size=100 | 약 4 | — | 페이징 안전, IN 절 배치 |
| (E) QueryDSL DTO 직접조회 | **1~2** | — | 필요 필드만, 가장 빠름. 재사용성↓ |

> 숫자 칸은 **실측값으로 채우는 게 핵심.** "301→3, 로딩 X초→Y초"가 면접 포인트.

## 핵심 — 상황별 선택 (진부함 탈출)

- **ToOne (Slot→Item→Category)** → fetch join / @EntityGraph
- **ToMany 2개 이상 (slots + options)** → fetch join 불가(`MultipleBagFetchException`)
  → ToOne만 fetch join + ToMany는 `default_batch_fetch_size`
- **페이징 필요** → fetch join 메모리 페이징 함정 → batch size로 우회
- **로딩 화면처럼 필드 일부만** → QueryDSL DTO 직접 조회

## 회귀 방지 (측정→개선→재측정→고정)

```java
@Test
void 인벤토리_로드는_3쿼리_이내() {
    SQLStatementCountValidator.reset();
    inventoryQueryService.loadForSync(memberId);
    SQLStatementCountValidator.assertSelectCount(3); // 누가 N+1 되살리면 CI에서 잡힘
}
```

→ 쿼리 수를 테스트로 고정 = 2번 합격자와 갈리는 지점.
