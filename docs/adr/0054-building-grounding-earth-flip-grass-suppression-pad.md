# 건물 접지 — 흙-지배 flip 회귀 봉합 (풀 백드롭 제거 + 잔디억제 패드)

ADR-0053(안식 농원 흙-지배 flip — 마당 지면을 초록 잔디밭 → tan 맨흙 지배, PR #231; 결정 기록은 메모리 `homestead-dirt-dominant-ground-flip`에 박제)은 순수 시각 개선이었지만 **회귀**를 남겼다: 건물 facade 발치에 깔리던 **풀 백드롭**이 이제 tan 세계와 대비돼 건물마다 **초록 사각형**을 냈다. flip 이전(초록 세계)엔 이 풀 백드롭이 세계와 섞여 안 보였다.

풀 백드롭의 원래 목적(ADR-0043)은 facade 아트의 투명 가장자리로 회색 WALL 그레이박스가 비치는 것을 가리는 것이었다. flip 이후엔 그 역할을 `_build_ground16`(16px 라이브 필드, HOME 전용)이 이미 수행한다 — WALL footprint 칸을 월드-정렬 맨흙으로 칠하므로 그레이박스가 안 비친다.

## 결정

**Option C(코드 접지)를 채택**한다 — facade 아트(스프라이트) 재생성 없이 코드만으로 초록 사각을 없애고 건물을 tan 세계에 접지시킨다.

1. **HOME은 풀 백드롭을 건너뛴다(`_facade_grass_backdrop` early-return).** 안식 농원은 `_build_ground16`이 이미 WALL footprint를 월드-정렬 맨흙으로 덮으므로, facade 투명부에 그 흙이 *seamless하게* 비친다(이중 그리기 제거 → 초록 사각 소멸·씸 프리). **그 외 구역(마을 등)은 여전히 초록 세계**(`_build_path_grass_fringe`)라 풀 백드롭을 **유지**한다(거기선 회귀 아님).

2. **잔디억제 패드 — 건물 발치 링을 맨흙으로 강제.** 건물 footprint + 발치 1링(`_G16_BUILD_PAD`)은 잔디 패치를 금지하고 맨흙으로 깐다(`_g16_near_building`). 잔디 패치가 벽에 어색하게 맞닿는 것을 막고 깔끔한 tan 접지를 만든다. seed 단계가 아니라 잔디 군락화 CA(`_g16_cluster_cleanup`) **뒤**에 최종 오버라이드로 적용한다(CA가 발치에 잔디를 되심는 것 방지). **"흙 에이프런"(건물 둘레에 특별한 흙 띠)은 불필요** — 세계가 이미 tan이라 패드가 맨흙 금지만 하면 자연히 tan이 이어진다.

3. **남향 문앞 성역화 유지(ADR-0036/0046).** 문(door) 칸은 별도로 PATH이고 `_carve_paths`가 남쪽으로 흙 진입로를 잇는다. 패드는 GROUND 칸의 잔디만 억제(PATH 불변)하므로 남향 진입 동선은 그대로 흙 길로 남는다(성역 = 제로 장식·명료한 진입).

4. **순수 시각 불변식.** grid·충돌·terrain·세이브는 불변 — footprint는 여전히 전부 WALL(통과 불가), 이 슬라이스는 지면 픽셀만 바꾼다.

## 스코프 — 지금 vs 연기

- **지금(구현 완료):** 초록 사각 봉합(§1) + 잔디억제 패드(§2). 결과 = 건물이 tan 세계에 깔끔히 접지. `building_grounding_test` 단위검증(패드 지오메트리 + footprint 중심 픽셀 = `_bf_earth` 일치 = 초록 아님).
- **연기 — 오버랩 데코(초록 경계 위 자연 데코).** flip 봉합을 코드로 완결해 *가릴 초록 경계 자체가 사라졌으므로*, N/E/W 비대칭 수풀 클럼프는 회귀 수복이 아니라 **자연주의 폴리시**(집을 수풀에 파묻는 룩)로 격하 → 프롭/아트 트랙으로 연기.
- **연기 — 발치 밀도 = clearable debris(ADR-0035).** 건물 둘레 밀도를 영구 장식이 아니라 *치우면 상흔 노출되는 debris*로 채우는 안. **debris가 매일 번식(스타듀식 파괴 확산)인가 일방향 clearable(개간=회복 진전)인가**라는 근간 결정이 미해결이라([[homestead-dirt-dominant-ground-flip]] 2026-07-06 defer) 별도 슬라이스로 연기.
- **무효/불요 — facade 스프라이트 tan 리컬러.** 초록이 전적으로 코드 백드롭이었음이 육안 확인됨(봉합 후 잔재 초록 0). 스프라이트에 구운 초록이 없으므로 owner-Gemini 리컬러 큐는 실효 없음(moot).

## 고려한 대안

- **(A) 풀 백드롭을 흙 백드롭으로 교체(HOME).** `_bf_earth`를 footprint에 타일링. 안전하지만 `draw_texture_rect` 타일링이 월드 주기(P=256)와 위상이 어긋나 footprint 경계에서 미세 그레인 씸 가능. §1(백드롭 건너뛰기 = ground16의 월드-정렬 흙 재사용)이 더 seamless라 반려.
- **(B) facade 스프라이트 재생성으로 흙 베이스 굽기.** 아트 왕복 비용 크고, 코드 백드롭이 진범이라 불필요. Option C가 코드만으로 완결.
- **(C-대안) 잔디억제를 seed(`_g16_surface`)에서.** CA가 발치에 잔디를 되심어 다시 새므로, CA 뒤 최종 패스가 필요. 최종 패스 단일 지점(§2)이 더 견고.

## 파급

- **구현:** `game/main.gd` — `_facade_grass_backdrop`(HOME early-return)·`_build_ground16`(CA 뒤 패드 패스)·`_g16_near_building`+`_HOME_BUILDING_RECTS`+`_G16_BUILD_PAD`. 육안 하네스 `tools/home_full_dump.gd`(HOME 풀 blit 제거로 라이브 정합). 회귀 `playtest/building_grounding_test.gd`.
- **관계:** [[homestead-dirt-dominant-ground-flip]](ADR-0053 flip·이 회귀의 원인)·ADR-0043(풀 백드롭 도입 근거·HOME 한정 폐기)·ADR-0036/0046(남향 진입 성역화)·ADR-0035(개간·debris = 연기 스코프).
- **North Star(미구현·스텁 금지):** 오버랩 데코 자연주의 + clearable debris 밀도(근간 결정 후).
