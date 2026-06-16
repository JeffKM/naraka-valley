# 나라카 메타 서버 — 설계 문서

naraka-valley(Godot 게임)의 **데이터 무결성·세이브 정산·랭킹을 책임지는 Spring Boot 백엔드** 설계.
게임 본체(Godot/GDScript)와 분리된 별도 서버 프로젝트다. **현재는 구현이 아니라 설계/문서화 단계.**

> ⚠️ ADR-0002(게임 본체는 Godot, 웹 스택은 홍보용만)와의 관계: 메타 서버는 "홍보 홈페이지"가 아니라
> **게임 데이터의 권위 검증 계층**이라는 새 영역이다. 게임 코드(GDScript)에는 이 서버의
> 레이어드/JPA 규칙을 적용하지 않는다 — 두 영역은 분리된다.

## 왜 만드는가 (두 가지 목적)

1. **게임 무결성** — 스타듀류는 오프라인 싱글이라 모든 데이터가 클라(Godot)에만 있으면
   메모리 조작으로 재화 치트·아이템 복사가 가능하다. 핵심 데이터·상점·결제는 서버가 검증한다.
2. **백엔드 포트폴리오** — 백엔드 채용에서 좋게 보는 4가지(디자인 패턴·N+1·I/O·결제)를
   *흔한 쇼핑몰/티켓팅이 아니라* 내가 직접 만든 게임 도메인에서 **필연적으로** 증명한다.
   → 기획력·실행력·기술 깊이 삼박자. 스택은 Spring/JPA/QueryDSL이라 직무 키워드 증명력 그대로.

## 4개 개념 매핑 (+보너스)

| 개념 | 적용 | 강도 | 문서 |
|---|---|---|---|
| ① 디자인 패턴 | 진행 종류별 **Strategy**(`DeltaApplier`) + 정산 **State**(`SyncSession`) | 중 | `05-design-patterns.md` |
| ② N+1 | **관계형 인벤토리** 로드 시 N+1 → fetch join/batch | ⭐ 플래그십 | `02-inventory-nplus1.md` |
| ③ I/O | 세이브 동기화 **벌크 write** + 랭킹/상점 **Redis 읽기 캐싱** | 강 | `03-io-optimization.md` |
| ④ 정산 | 세이브 정산 **멱등성** + `SyncSession` 상태머신 + **outbox 보상** | ⭐ 강 | `04-save-settlement-pipeline.md` |
| ⑤ 동시성 | **동일 계정 동시 세이브 충돌** → 낙관락 `@Version` | 강 | `04-save-settlement-pipeline.md` |

> 진부함 탈출 = **숫자(측정)** + **이유(ADR)**. before/after 수치와 선택 근거를 항상 붙인다.

## 문서 구조

```
docs/meta-server/
├── README.md                ← 이 문서
├── 01-architecture.md                 ← 3블록 구조 · 서버 권위 범위 · 개념 매핑 · 면접 대비
├── 02-inventory-nplus1.md             ← 관계형 인벤토리 + N+1 (플래그십, before/after)
├── 03-io-optimization.md              ← 세이브 동기화 벌크 + Redis 읽기 캐싱
├── 04-save-settlement-pipeline.md     ← 세이브 정산 멱등성·SyncSession·outbox + 동시성(낙관락)
├── 05-design-patterns.md              ← 서버 영역 Strategy(DeltaApplier)/State(SyncSession)
└── adr/
    ├── 0001-inventory-relational.md                       ← 인벤토리 관계형 선택
    ├── 0002-server-authority-scope.md                     ← 서버 권위 = 메타 계층만
    └── 0003-meta-server-no-commerce-save-settlement.md    ← 커머스 제거, 결제→세이브 정산 이전
```

## 확정된 핵심 결정

1. ✅ **서버 권위 = 메타 계층만** — 게임플레이(농사·이동·성장)는 클라 오프라인,
   세이브·재화·인벤토리·랭킹·정산만 서버 검증 (ADR-0002)
2. ✅ **인벤토리 = 관계형** — ② N+1 스토리의 전제, 근거는 수집률 랭킹 집계 (ADR-0001)
3. ✅ **커머스 제거 + 결제 → 세이브 정산 이전** — 웹샵·토스·거래소·선착순(가짜 온라인)을 들어내고,
   결제 엔지니어링(멱등성·상태머신·outbox 보상)을 세이브 정산 파이프라인으로 이전 (ADR-0003)
4. ✅ **⑤ 동시성 = 동일 계정 동시 세이브 충돌** — 낙관락 `@Version`, 분산락 의도적 미사용 (ADR-0003)
5. 🔀 **미정**: 세이브 동기화 전체 스냅샷 vs 델타 (추천: 스냅샷+JDBC 벌크부터)

## 스택

Spring Boot 3 + JPA/Hibernate + QueryDSL + Redis + MySQL/PostgreSQL + Docker
(+여유 시 Spring Batch, k6/nGrinder 부하테스트, Prometheus/Grafana)
