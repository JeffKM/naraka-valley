# Wang 경계 전환 타일 — 진행 ledger

plan: /Users/jefflee/workspace/naraka-valley/docs/superpowers/plans/2026-07-16-wang-boundary-transition-tiles.md
worktree branch: worktree-wang-boundary-transition (base origin/main #248)

- [x] Task 1: 경계쌍·삼중점 스캔 (controller 직접 — owner 크레딧 게이트)
- [x] Task 2: PixelLab 전환 tileset 생성·정리 (controller 직접 — MCP)
- [x] Task 3: 코너 인덱서·전환 로더 헬퍼 (subagent TDD)
- [x] Task 4: _build_ground16 ②지터→Wang blit 교체 (subagent TDD)
- [ ] Task 5: mute 후처리 + transition_size 튜닝 (controller 육안)
- [ ] Task 6: 육안 하네스 + 최종 선별 회귀 (subagent + controller 육안)
- [ ] Task 7: owner 라이브 확인 (핸드오프)

## 완료 기록
- Task 3: complete (commit 72cbe7b, review Spec✅ quality-approved)
  - Minor(final review로): _load_wang_pairs가 JSON.parse_string 결과 널체크 없이 사용(손상 metadata 시 런타임 에러). 사전검증 에셋이라 즉각 위험 낮음.
- Task 4: complete (commit 638f9a6, review Spec✅ quality-approved)
  - ⚠️→해소: 타일크기 32×32(Task3 bbox 확인·get_region 보장), 실렌더 검증은 Task6, 밭/물경계 owner의도.
