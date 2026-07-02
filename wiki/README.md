# 나라카 밸리 위키 (구현 현황 대시보드)

owner·협업자가 **무엇을 만들고 구현했는지 웹에서 시각적으로** 확인하고, **웹에서 바로 작업 지시**하는 대시보드. 로컬은 dev 서버(편집 가능), 배포는 정적 export(뷰 전용) → GitHub Pages.

## 무엇을 보여주나
- **에셋 갤러리**: `game/assets/**` 렌더 PNG 전체를 카테고리별 시각 그리드로. 픽셀 nearest 확대·**생성 도구 태그**(Gemini/PixelLab/절차생성/확인 필요)·크기·생성 방법. `확인 필요` = 도구 귀속 미검증(육안 확인 요망).
- **메카닉 현황**(`/mechanics`): 지역별 + 공통/횡단 구현 상태.

## ★ 웹에서 작업 지시(채팅 대신 소통)
카드를 클릭 → **[작업 지시(OK/재생성/확인중) · 실제 도구 정정 · 메모]** 를 저장하면 `data/asset-decisions.json`에 기록되고, **어시스턴트가 그 파일을 읽어 작업**한다. 재생성 요청은 갤러리 상단 "작업: 재생성" 필터로 모아 본다.
- **편집은 로컬 `npm run dev`(또는 `npm start`)에서만** — API 라우트(`/api/decisions`)가 파일에 쓴다. 정적 export 배포본(GitHub Pages)은 **뷰 전용**(저장 시도 시 안내).
- 용어(절차생성·확인 필요 등)는 갤러리 상단 "용어·사용법" 패널 참조.

## 실행
```bash
cd wiki
npm install
npm run dev        # 로컬 개발 서버(편집·저장 O) — predev가 manifest 자동 실행 → http://localhost:3000
npm run manifest   # (수동) game/assets 스캔 → public/assets 복사 + lib/manifest.json 갱신
```

## 데일리 업데이트
`npm run manifest` 재실행이면 최신 에셋 반영(스캔·복사·재생성). 메카닉은 `lib/mechanics.ts` 직접 수정.

## 구조
- `scripts/build-manifest.mjs` — 에셋 스캔·**도구 귀속(attribution)**·public 복사·매니페스트. 도구 귀속 규칙 수정은 이 파일 `attribute()`.
- `lib/manifest.json` — 생성물(커밋됨, 결정적). `public/assets/` — 생성물(gitignore).
- `lib/mechanics.ts` — 메카닉 현황 수기 데이터.
- `app/api/decisions/route.ts` — 에셋 결정 읽기/쓰기(로컬 dev 전용). `data/asset-decisions.json` — 결정 저장소(어시스턴트가 읽음).
- `app/`, `components/` — UI(Gallery·DecisionModal·Legend·Nav).

## 로드맵(후속)
- ③ 진행 체인지로그(데일리) · ④ 피드백 창구(GitHub Issues → 코멘트)

## 배포(GitHub Pages, 뷰 전용)
정적 export는 편집 API 제외한 뷰 전용:
```bash
NEXT_EXPORT=1 NEXT_PUBLIC_BASE_PATH=/naraka-valley npm run build   # → out/ 를 Pages로
```
(로컬 편집은 export가 아니라 `npm run dev`/`npm start`에서.)
