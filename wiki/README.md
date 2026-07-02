# 나라카 밸리 위키 (구현 현황 대시보드)

owner·협업자가 **무엇을 만들고 구현했는지 웹에서 시각적으로** 확인하는 대시보드. Next.js 정적 export → GitHub Pages 배포. **v1 = 에셋 갤러리**(메카닉 현황·체인지로그는 후속).

## 무엇을 보여주나
- **에셋 갤러리**: `game/assets/**` 렌더 PNG 전체를 카테고리별 시각 그리드로. 픽셀 nearest 확대·**생성 도구 태그**(Gemini/PixelLab/절차생성/확인 필요)·크기·생성 방법. `확인 필요` = 도구 귀속 미검증(육안 확인 요망).

## 실행
```bash
cd wiki
npm install
npm run manifest   # game/assets 스캔 → public/assets 복사 + lib/manifest.json 생성
npm run dev        # 개발 서버 (predev가 manifest 자동 실행)
npm run build      # 정적 export → out/ (prebuild가 manifest 자동 실행)
```

## 데일리 업데이트
`npm run manifest` 재실행이면 최신 에셋 반영(스캔·복사·재생성). 배포는 `npm run build`의 `out/`을 GitHub Pages로.

## 구조
- `scripts/build-manifest.mjs` — 에셋 스캔·**도구 귀속(attribution)**·public 복사·매니페스트. 도구 귀속 규칙 수정은 이 파일 `attribute()`.
- `lib/manifest.json` — 생성물(커밋됨, 결정적). `public/assets/` — 생성물(gitignore).
- `app/`, `components/Gallery.tsx` — UI.

## 로드맵(후속)
- ② 메카닉 현황(지역별 + 공통/횡단)
- ③ 진행 체인지로그(데일리)
- ④ 피드백 창구(GitHub Issues 링크 → 코멘트 시스템)

## GitHub Pages 배포 메모
프로젝트 페이지(`/naraka-valley`) 배포 시 `NEXT_PUBLIC_BASE_PATH=/naraka-valley npm run build`.
