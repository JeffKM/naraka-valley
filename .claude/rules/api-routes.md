---
paths:
  - "app/api/**"
  - "lib/services/**"
  - "lib/repositories/**"
---

# API 설계 규칙

## 레이어드 아키텍처

- API Route (Controller) -> Service -> Repository 패턴 준수
- 각 레이어는 자신의 하위 레이어만 호출할 것

## 응답 형식

```typescript
type ApiResponse<T> = {
  data: T | null;
  error: string | null;
};
```

- 모든 API 응답에 이 래퍼 사용

## DTO 패턴

- API 경계에서 DTO로 변환 (DB 엔티티를 직접 반환하지 말 것)
- 요청/응답 각각 별도 DTO 정의

## 에러 처리

- try-catch 필수
- 적절한 HTTP 상태 코드 사용 (400, 401, 403, 404, 500)
- 에러 메시지는 사용자에게 노출 가능한 형태로

## DB 트랜잭션

- 여러 테이블 수정 시 트랜잭션 처리 필수
- Supabase RPC 또는 Edge Function으로 원자적 연산 보장
