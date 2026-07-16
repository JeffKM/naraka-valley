# Wang 경계 전환 타일 — 진행 ledger

plan: /Users/jefflee/workspace/naraka-valley/docs/superpowers/plans/2026-07-16-wang-boundary-transition-tiles.md
worktree branch: worktree-wang-boundary-transition (base origin/main #248)

- [x] Task 1: 경계쌍·삼중점 스캔 (controller 직접 — owner 크레딧 게이트)
- [x] Task 2: PixelLab 전환 tileset 생성·정리 (controller 직접 — MCP)
- [x] Task 3: 코너 인덱서·전환 로더 헬퍼 (subagent TDD)
- [x] Task 4: _build_ground16 ②지터→Wang blit 교체 (subagent TDD)
- [x] Task 5: mute 후처리 + transition_size 튜닝 (controller 육안)
- [x] Task 6: 육안 하네스 + 최종 선별 회귀 (subagent + controller 육안)
- [ ] Task 7: owner 라이브 확인 (핸드오프)

## 완료 기록
- Task 3: complete (commit 72cbe7b, review Spec✅ quality-approved)
  - Minor(final review로): _load_wang_pairs가 JSON.parse_string 결과 널체크 없이 사용(손상 metadata 시 런타임 에러). 사전검증 에셋이라 즉각 위험 낮음.
- Task 4: complete (commit 638f9a6, review Spec✅ quality-approved)
  - ⚠️→해소: 타일크기 32×32(Task3 bbox 확인·get_region 보장), 실렌더 검증은 Task6, 밭/물경계 owner의도.
- Task 5: 불필요(skip) — 라이브 톤 육안 확인 결과 전환 타일 잔디가 base 잔디(muted)와 이미 일치(8ffcb621 잔디=60dcdf27 원본 muted). 밭·물 transition_size=0.25 얇게 잘 나옴. mute/재생성 불요(YAGNI).
- Task 6: complete — wang_live_dump.gd 하네스 커밋 + 최종 회귀 building_grounding·reclaim·wang_boundary 3/3 PASS. 육안: crisp 오버행·변주·톤일치 확인.

## Final whole-branch review (opus)
판정: READY. 정확성·불변식·회귀 안전, Critical 없음.
- Important(owner 라이브 게이트=Task 7): ①0_1 전환타일 흙(raw a2f59b0e) vs 라이브 _bf_earth(retone tan) 톤 정합 ②밭·물 엣지 전환(의도, furrow/수면 가독 owner 확인). 어긋나면 후속: _mute_grass_pixels/retone 또는 transition_size 재생성.
- Minor(머지전 불요): _load_wang_pairs JSON 널체크·blit_rect 알파. 값싼 가드지만 블로커 아님.
