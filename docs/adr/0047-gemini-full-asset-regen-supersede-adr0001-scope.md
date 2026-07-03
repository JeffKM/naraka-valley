# ADR-0047 — Gemini 전면 에셋 재생성 (ADR-0001 스코프 개정 + 캐릭터 선명도 예외)

- **상태:** Accepted (owner 결정 2026-07-02)
- **개정 대상:** [ADR-0001](./0001-pixel-art-ai-pipeline.md) (생성기 역할 분담 스코프) 를 부분 supersede. asset-ruleset §0.1·§10.2 (전 에셋 2px 청크 캐논) 를 **캐릭터에 한해** 예외.
- **관련:** [ADR-0026](./0026-stardew-art-style-pivot-slim-cast.md)(스타듀 룩)·[ADR-0025](./0025-asset-spec-card-gate.md)(스펙카드 게이트)·[ADR-0036](./0036-building-front-facade-chunky-canon.md)(청크 캐논).
- **스펙 문서:** [docs/design/gemini-regen-batch.md](../design/gemini-regen-batch.md) — 96개 에셋 전체 스펙카드·프롬프트·변환 파이프라인·추적표.

## 맥락 (Context)

owner가 인게임을 직접 확인한 결과 두 가지 결정을 내렸다:

1. **캐릭터 선명도 회귀.** 2px 청크 캐논([ADR-0036], asset-ruleset §0.1)이 캐릭터 walk 시트까지 눌러 "형태가 안 보일 정도로" 흐려졌다. 캐릭터는 선명도 우선으로 되돌린다.
2. **전 에셋 Gemini 재생성.** 현재 PixelLab/절차생성/미검증(위키 태그 기준 96개)으로 만든 에셋 전체를, 초상화·건물 facade에서 이미 검증된 **Gemini 픽셀 파이프라인**으로 재생성한다.

문제: [ADR-0001]은 "미드저니/제미나이는 일관된 4방향 캐릭터·애니메이션·격자 타일을 못 만든다 → 역할을 컨셉·컷신·홍보 일러스트로 한정, 인게임 도트는 PixelLab/Retro Diffusion"으로 스코프를 잠갔다. 결정 2는 이 스코프와 정면 충돌한다. 따라서 새 ADR로 개정한다.

## 결정 (Decision)

### 1. Gemini를 전 에셋 클래스의 1차 생성기로 격상

캐릭터·타일 포함 **모든 시각 에셋**을 Gemini(owner 수동 생성) + 변환 글루 스크립트로 재생성한다. [ADR-0001]의 "Gemini=일러스트 한정" 스코프 제한을 **폐기**한다. 단, [ADR-0001]의 나머지 정신(자체 "도트화 툴" 제작 금지 — 글루 스크립트만 허용)은 유지된다.

### 2. 워크플로우 = owner 수동 생성 + 변환 글루 (수정 없음, [ADR-0001] 허용 범위)

repo에 Gemini API 호출 코드는 없다(있던 적 없음). 파이프라인은 초상화·건물과 동일:
`[owner가 Gemini 웹에서 생성 + 다운로드] → [로컬 raw PNG] → [PIL/Godot 글루가 배경제거·크롭·리사이즈·청키화·조립] → game/assets/`.
스펙카드([ADR-0025])로 생성 전 프롬프트를 잠그고, 변환기는 배경 제거·크롭·양자화 수준의 글루만 담당한다(변환 엔진 제작 아님).

### 3. Gemini의 기술적 한계를 정직하게 인정하고 파이프라인으로 흡수

Gemini는 단일 정적 이미지(초상화·건물·프롭·아이콘)엔 강하나, **일관된 다중 프레임 스프라이트 시트와 seamless 오토타일은 약하다.** 이를 "생성 실패"로 두지 않고 조립·후처리로 흡수한다:

- **캐릭터(4방향 walk 시트):** 완성 시트 1장 생성 금지. **방향/프레임을 개별 PNG로 생성 → `game/tools/assemble_char.py` 재사용**(hole-fill·공통 bbox 크롭·발치 정렬·시트 합성). Gemini가 프레임 시퀀스를 못 맞추면 idle 4방향만 확보하고 walk는 Aseprite 수동 보정([ADR-0001] 워크플로).
- **타일(Wang 오토타일·지형 아틀라스):** 전이 슬롯을 Gemini에 맡기지 않는다. **base 텍스처만 생성 → 4-way tileable 봉합 + §8.2 전이 픽셀(2px 디더 마진) 후처리 → Wang `.tres` 조립.**
- **건물 facade:** 기존 `gemini_facade_to_chunky.py` 그대로 계승(다운스케일→48색 양자화→×2 nearest).
- **폴백:** 특정 에셋에서 Gemini 결과가 규격을 못 맞추면 해당 에셋만 PixelLab을 폴백으로 유지한다(전면 금지 아님 — 도구는 결과로 판단).
  - **폴백 채택 사례 — 작물(2026-07-03):** 작물 스프라이트(5종×3단계=15개)는 Gemini가 아이소메트릭 각도·흙 두둑·씨앗에 열매 그리기 문제를 반복해, owner 지시로 **PixelLab `create_map_object`(top-down/no-soil)로 전환**했다. 규약: 흙/두둑 일절 없이 식물만(투명 배경), 스타듀 룩, 32×32(트렐리스 황천포도만 32×64 세로). 변환은 `game/tools/gemini_crop_to_cell.py`(raw→bbox 크롭→cell bottom-center)로 흡수. 트렐리스는 `main.gd` `_draw_crops`가 `CropCatalog.is_trellis()`일 때 셀 위로 1칸 솟는 32×64로 렌더.
  - **작물 = 2px 청크 예외(선명도 우선, 2026-07-03 개정):** 최초엔 작물도 `gemini_crop_to_cell.py`가 ÷2 BOX→×2 nearest로 "2px 청키화"했으나, owner가 위키 갤러리에서 "너무 흐리고 형태가 안 보인다"고 지적. 원인 = PixelLab이 이미 32×32 네이티브 픽셀아트로 생성하는데 글루가 이를 16px로 BOX 축소(색 평균=뭉갬)했다가 ×2로 되돌려 **해상도를 절반으로 죽인 것**(§4 캐릭터가 겪은 문제와 동일). 해결 = **작물도 캐릭터처럼 청크 캐논(asset-ruleset §0.1)의 예외**로 두고 원본 픽셀을 1:1 보존(절대 확대 안 함·셀 초과 시에만 NEAREST 축소·BOX 금지·threshold_alpha로 하드에지). 스타듀식 크리스프 룩 확보. 인게임 밭 렌더 검증 완료.

### 4. 캐릭터 = 2px 청크 캐논 예외 (선명도 우선)

캐릭터 walk 시트는 asset-ruleset §0.1(전 에셋 2px 청크)·§10.2(캐릭터 도트 밀도 통일)의 **예외**로 둔다. 인게임 형태 가독성이 청크 일관성보다 우선(owner 결정). 구현: `game/tools/enforce_chunk.py` SCAN_DIRS에서 `assets/characters` 제외(2026-07-02 적용). 타일·props·건물·debris는 청크 캐논 유지. 얼굴 디테일은 초상화([ADR-0026] #3)가 계속 전담한다.

## 결과 (Consequences)

- **긍정:** 룩 통일(초상화·건물에서 검증된 Sun Haven/Stardew 픽셀 톤을 전 에셋으로 확장). owner가 아트 방향을 직접 쥠. 변환 파이프라인 재사용으로 글루 신규 개발 최소.
- **부정/리스크:** owner 수동 생성 96개는 상당한 수작업. 캐릭터 walk·seamless 타일은 조립/후처리 부담이 큼 → 리스크 높은 순으로 진행하고 막히면 폴백(PixelLab)·수동 보정(Aseprite).
- **[ADR-0036]/asset-ruleset 정합:** 청크 캐논은 캐릭터만 예외, 나머지 전 에셋엔 유효. 캐릭터 예외 사유는 enforce_chunk.py 주석과 본 ADR에 박제.
- **범위 밖:** 이미 Gemini로 완료된 초상화 28·건물 3(house/storehouse/barn)·대화 UI 3은 재생성 대상이 아니다(파이프라인 계승 원본).

## 진행

Part A(캐릭터 선명도 복원 + 청크 예외)는 2026-07-02 완료·커밋. Part B(96개 스펙카드 일괄)는 [gemini-regen-batch.md](../design/gemini-regen-batch.md)에 정리. 실제 재생성은 owner의 Gemini 수동 생성 속도에 따라 카테고리별로 순차 진행한다. **작물 카테고리(15개)는 2026-07-03 §3 폴백 조항에 따라 PixelLab로 완료**(위 폴백 채택 사례 참조).
