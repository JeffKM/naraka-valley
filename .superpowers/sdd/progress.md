# 지상 지형 변주(스타듀-정통 스캐터·ADR-0058) — 진행 ledger

plan: /Users/jefflee/workspace/naraka-valley/docs/superpowers/plans/2026-07-17-overworld-terrain-scatter.md
worktree branch: worktree-scatter-variation-adr0058 (base origin/main 061f81f)

- [x] Task 1: 구역-키드 스캐터 조회 (폴백=전역·회귀0)
- [x] Task 2: 안식 테이블 풀무리↑
- [x] Task 3: 풀무리 CA 이웃-확산 마스크
- [x] Task 4: 변종 아트 로스터·스펙카드

## 완료 기록
- Task 1: complete (commits 061f81f..752ce3b, review Spec✅ quality-approved)
  - Minor(final review로): scatter_variation_test `_same_table`가 size+첫엔트리 가중만 비교(약함). Task1 폴백=참조동일이라 실무 적정. Task2+ 구역테이블 차이 검증엔 텍스처 참조 전체 비교로 강화 고려.
  - implementer가 브리프 테스트 버그 정정: 테스트로컬 헬퍼를 m.이 아닌 self로 호출(프로덕션 불변).
- Task 2: complete (commits 752ce3b..0b59e3b, review Spec✅ quality-approved, findings 0)
- Task 3: complete (commits 0b59e3b..762c18e, review Spec✅ quality-approved by opus, 결함0)
  - Minor(비-결함): _neighbor_corr 테스트는 저주파 seed만으로도 통과(CA 기여 격리 못함)·브리프 규정대로. _scatter_is_clump 폴백이 regional cut 사용(도달불가·무해).
- Task 4: complete (controller 직접·문서 태스크, commit fb14829, 테스트사이클 없음)

## Final whole-branch review (opus)
판정: **READY**. 결정성·저작맵불가침·ADR-0053/0055/0057 정합·커밋간 일관성 성립. must-fix 0.
- Minor(옵션·머지 후속): 스캐터 적격 게이트(main.gd:3807)가 전역 `_GD_TABLES.has(terrain)`로 판정하나 테이블 본문은 `_gd_table_for(terrain)`. 오늘 무해(HOME=GROUND만 오버라이드·전역에 GROUND/PATH 존재). 향후 구역이 전역에 없는 terrain 오버라이드 시 조용히 스킵 → Slice 2+ 구역 실테이블 채울 때 게이트를 region-resolved 테이블로 바꾸거나 주석.
- 선별 회귀(controller 실행, 최종 HEAD): scatter_variation·building_grounding·reclaim 3/3 PASS·exit0.
- 육안(map_dump·라이브 톤) = owner 확인 대기(코드 아님).

## 물↔흙(4_0) Wang 물가 단차 트랙 (ADR-0058 확장·별도 slice)
plan: docs/superpowers/plans/2026-07-17-water-dirt-wang-shore-depth.md
spec: docs/superpowers/specs/2026-07-17-water-dirt-wang-shore-depth-design.md (commit fbc0af8)
base: 99dfcaa (plan commit)
- Task 1: complete (commits 99dfcaa..ee8377c, review Spec✅ quality-approved, Critical/Important 0)
  - Minor(cosmetic·brief에서 유래): scatter_variation_test 물↔흙 블록 주석이 "Task 4" 라벨(실제 SDD Task 1). blame 혼동 여지·무해.
- Task 2: complete (commits ee8377c..9fec662, review Spec✅ quality-approved, Critical/Important 0)
  - implementer self-review가 rim 패스 nesting 버그(if shadow_depth>0 안 중첩→sibling) 자가수정·리뷰 확인.
  - Minor(plan-mandated·비-결함): ①테스트 주석 "Task 4" 라벨(Task1 동일). ②림 거리=8-ray cast(true Chebyshev 아님)→convex/concave 코너 방향 불균등 여지. rim_px=2라 영향 미미·owner _W40_* 라이브 튜닝 대상.

## Final whole-branch review — 물↔흙 slice (opus)
판정: **READY (Yes)**. 렌더 ② 루프 통합·함수계약 확장·rim/shadow 겹침·하위호환·결정성 코드 확인 정합. Critical/Important 0.
- Minor#1: shadow(남쪽 물 darkened)와 rim(전방향 lightened)이 남쪽 shore 물 픽셀 중복수정→부분상쇄. owner _W40_ 튜닝 시 인지. 버그 아님.
- Minor#2(값어치有): 테스트가 rim만 리터럴(0.30,2) 하드코딩→shipping에서 _W40_RIM=0으로 꺼져도 회귀 못잡음. 상수참조로 바꾸면 커버(단 owner가 0으로 끌 때 테스트 조정 trade-off). owner 판단.
- Minor#3: 타일 내부만 스캔→타일 씸에서 rim 불연속 여지. 기존 _bake_field_wang 아키텍처 한계(잔디↔흙 공유)·이 slice 신규 아님·대개 무해.
- Minor#4: 알려진 2건("Task4"주석 cosmetic·8-ray 거리 rim_px=2 영향미미) 무해 확정.
- 육안(안식 연못 3면 톤·단차) = owner 라이브 확인 대기(순수 시각·코드 아님).

## 물↔흙 물가 — owner 라이브 7차 반복 후 최종 확정 (2026-07-17)
초기 spec/plan(base 합성 단차)은 owner 라이브 반복으로 전면 재설계됨. **최종 = 손그림 형태 마스크**(commit 4fd7c45, owner "이제 괜찮아졌어" 승인).
반복 경로: ①Wang base합성(ee8377c~9fec662·격자seam) → ②절차 shore후처리(d38dd22~cfa84bf·"코드 손댄 느낌") → ③테두리만 오버레이(8deb8f9·경계 무의미) → ④손그림 형태 마스크(4fd7c45·정답).
정답 구조: _build_shore_masks(손그림 4_0→0물/1흙/2테두리)·_paint_shore_cell(② 루프 경계 물셀 셀별: 물=base·흙=_bf_earth 월드위상=격자없음·테두리=손그림). 회귀 scatter_variation/building_grounding/reclaim 3/3 PASS.
메모리: [[water-dirt-shore-handpainted-mask-adr0058]]. spec/plan은 초기 방식이라 최종과 상이(메모리가 정확).
