---
paths:
  - "lib/supabase/**"
  - "app/auth/**"
  - "middleware.ts"
---

# Supabase 클라이언트 규칙

## 서버 클라이언트

- Fluid Compute 호환: 서버 클라이언트를 전역 변수나 모듈 스코프에 저장 금지
- 매 요청마다 `createClient()` 새로 호출할 것

## proxy.ts (Middleware)

- `createServerClient`와 `supabase.auth.getClaims()` 사이에 코드 삽입 금지
- 세션 갱신 로직의 순서를 변경하지 말 것

## Server Component에서의 쿠키 처리

- `setAll` 콜백에서 에러 무시 패턴은 정상 동작 (Server Component는 쿠키 쓰기 불가)
- Route Handler/Server Action에서는 실제로 쿠키 설정됨

## NextResponse 생성 시 주의

- 새 NextResponse 생성 시 기존 쿠키를 반드시 복사할 것 (세션 동기화)
- `request.cookies`와 `supabaseResponse.cookies` 모두 확인

## 리다이렉트 규칙

- 미인증 사용자: `/auth/login`으로 리다이렉트
- 루트 `/`는 인증 불필요 (공개 페이지)
