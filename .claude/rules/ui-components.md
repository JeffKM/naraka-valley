---
paths:
  - "components/**"
  - "app/**/page.tsx"
  - "app/**/layout.tsx"
---

# UI 컴포넌트 규칙

## UX 원칙

- **모든 숫자에 맥락을**: 단독 숫자 표시 금지, 비교 대상(리그 순위, 백분위, 전년 비교)과 함께 표시
- **3초 안에 핵심 파악**: 색상·아이콘·크기로 정보 우선순위 시각화, Progressive Disclosure
- **공유하고 싶은 디자인**: 배틀카드·프로필 요약의 SNS 공유 최적화 (OG 이미지, 다운로드)
- **초보 팬도 환영**: 전문 용어(xG, xA 등)에 설명 팝오버 제공

## shadcn/ui

- 컴포넌트 추가: `npx shadcn@latest add <component>`
- 스타일: new-york (설정은 `components.json` 참조)
- 커스텀 CSS 파일 생성 금지, Tailwind 유틸리티만 사용

## 다크모드

- class 기반 (next-themes)
- CSS 변수 정의: `app/globals.css`
- 새 색상 추가 시 light/dark 모두 정의할 것
