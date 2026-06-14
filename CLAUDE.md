# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 이 저장소의 성격 (먼저 읽을 것)

**나라카 밸리**는 저승 컨셉카페 세계관의 **진짜 스타듀밸리형 게임**(농사·낚시·채광·관계)이다. 엔진은 **Godot**, 타겟은 **Steam/PC**.

현재 저장소는 **기획 단계**다. 아직 Godot 프로젝트(게임 코드)가 생성되지 않았고, 저장소에는 기획 문서·결정 기록·작업 도구만 있다. 첫 코드는 ROADMAP의 **Phase 1 / Sprint 1**(Godot 그레이박스)에서 시작된다.

이 저장소는 **Git 저장소가 아니다.** 버전 관리가 필요하면 먼저 사용자와 상의할 것.

## 권위 있는 문서 (작업 전 반드시 참조)

코드가 아닌 **문서가 진실의 원천**이다. 작업 방향을 정하기 전에 해당 문서를 읽어라.

- **[CONTEXT.md](./CONTEXT.md)** — 도메인 용어집(공유 언어). 옥자/멜/바나/미호, 혼력, 여우불 성장 촉진, 저승 작물 등 모든 도메인 용어는 여기 정의를 따른다. 새 코드/문서에서 용어를 쓸 때 이 정의와 어긋나면 안 된다.
- **[ROADMAP.md](./ROADMAP.md)** — Phase/Sprint 단위 개발 계획과 체크리스트. "지금 무엇을 할 차례인가"는 여기서 확인한다.
- **[docs/adr/](./docs/adr/)** — 되돌리기 비싼 핵심 결정. 이 결정들을 어기는 제안을 하기 전에 반드시 ADR을 확인하고, 바꿔야 한다면 새 ADR로 기록할 것.
- **[docs/licensing-checklist.md](./docs/licensing-checklist.md)** — 생성형 에셋(이미지·BGM)의 상업적 사용 약관 점검표. Phase 2 에셋 작업 및 Steam 출시 전 필수.

## 어겨선 안 되는 설계 제약 (ADR 요약)

- **ADR-0002 — 엔진은 Godot/GDScript.** 게임 본체를 웹 스택(Phaser 등)으로 만들지 않는다. 개발자는 TS/React 전문가지만 게임은 Godot으로 학습하며 만든다.
- **ADR-0003 — 픽셀 규격 고정:** 16×16 타일 / 16×32 캐릭터(약 2.5등신) / 내부해상도 320×180 정수배 스케일 / 탑다운 3/4뷰. 캐릭터 표정은 도트가 아니라 **대화 시 별도 일러스트 초상화**로 살린다.
- **ADR-0004 — "속죄" 테마가 게임을 관통한다.** 각 캐릭터는 생전의 죄의 힘을 정반대로 써서 속죄한다(미호: 방화→작물 양육, 멜: 도박·사채→경제·회계, 바나: 주거침입·흡혈→밤 경비). **이 테마를 어기는 캐릭터/시스템은 추가하지 않는다.**
- **ADR-0001 — 자체 "도트화 툴"을 만들지 않는다.** 인게임 도트는 PixelLab/Retro Diffusion으로 생성하고 Aseprite로 보정한다. 에셋 정리·임포트용 글루 스크립트는 허용하되, 변환 엔진 제작(야크 셰이빙)은 금지.

## 개발 원칙 (ROADMAP에서)

- **그레이박스 먼저, 에셋은 나중.** Phase 1은 회색 도형만으로 "재밌나?"를 검증한다. 에셋(도트·초상화·사운드)은 재미 게이트 통과 후 Phase 2에서만 입힌다.
- **한 시스템을 100%로 끝내고 다음으로.** "전부 동시에"가 아니라 하나씩.
- **매 스프린트 끝엔 반드시 "직접 플레이되는 무언가"가 남게 한다.** 파트타임 장기전이라 진척이 눈에 보여야 동력이 유지된다.
- 막힐 때 우선순위: **"끝까지 플레이되는 것" > "기능이 많은 것" > "예쁜 것".**

## 웹 코드와 게임 코드의 분리 (중요)

`.claude/rules/`의 규칙들(`api-routes.md`, `supabase.md`, `ui-components.md`)은 Next.js/Supabase 기준이며 **게임 본체가 아니라 홍보 홈페이지·위시리스트·웹 데모 쪽에만 적용된다**(ADR-0002 참조). Godot/GDScript 게임 코드에는 이 레이어드 아키텍처·Supabase·shadcn 규칙을 적용하지 말 것. 두 영역을 혼동하지 않는다.

## 작업 도구

- **shrimp-task-manager (MCP)** — `.mcp.json`에 설정된 작업 분해/관리용 MCP 서버. 소스는 `mcp-shrimp-task-manager/`에 벤더링되어 있다. **이 디렉터리는 도구이지 게임 코드가 아니다.** 데이터는 `shrimp_data/`에 저장된다.
  - MCP 서버 빌드: `cd mcp-shrimp-task-manager && npm install && npm run build` (실행 진입점은 `dist/index.js`)
- **`.claude/commands/`** — 슬래시 커맨드: `/docs:update-roadmap`(로드맵 진행 갱신), `/git:branch` `/git:commit` `/git:merge` `/git:pr`(Git 워크플로우).
