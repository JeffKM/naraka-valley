# 건물 재생성 — 제미나이 공통 프롬프트 (본가·창고·축사)

> **상태:** 2026-07-02 확정. 본가·창고·축사를 제미나이로 재생성할 때 쓰는 **단일 공통 프롬프트 + 건물별 치환값 + 후처리 파이프라인**.
> **근거:** [asset-ruleset §0/§0.1](./asset-ruleset.md)(청키 2px 캐논)·[§1.1](./asset-ruleset.md)(NW 광원)·[§2](./asset-ruleset.md)(정면 facade·지붕 윗면)·[§2.1](./asset-ruleset.md)([ADR-0046] 문 폭 규약)·[ADR-0036](../adr/0036-building-front-facade-southward-entry-invariant.md)·[gemini-farmhouse-spec](./gemini-farmhouse-spec.md)·[gemini-shed-barn-spec](./gemini-shed-barn-spec.md).

## 왜 제미나이 + 후처리인가 (선명도·청키의 진짜 출처)

인게임 렌더(`_blit_facade_anchored`)는 PNG를 **네이티브 크기 1:1**로 그린다 — 스케일 없음. 그래서 화면의 **청키 정도(2px 블록)·선명도는 오직 소스 PNG가 어떻게 구워졌느냐**로 정해진다. 제미나이가 뭘 뽑든, **후처리 스크립트가 `half-res 정규화 → 하드 알파 임계 → ×2 nearest`를 강제**하면 3건물의 청키·선명도가 자동으로 동일해진다. 프롬프트의 역할은 "후처리가 깨끗이 그리드로 눌러담을, AA·그라데이션 없는 선명한 블록 아트"를 뽑는 것.

---

## 1. 공통 프롬프트 블록 (3건물 재사용)

`[[BUILDING]]` 한 줄만 갈아끼우고 나머지는 **완전히 동일**하게 3번 돌린다. 동일 골격 = 시점·광원·팔레트·그레인·문 일관성의 1차 보증.

```
Top-down 3/4 view cozy farm game building sprite, Stardew Valley / Sun Haven pixel-art
style. Subject: [[BUILDING]].

VIEW — front-facing facade, camera looking straight at the front wall. NOT isometric,
NOT angled, NO left/right side walls. Symmetrical front elevation. The sloped ROOF TOP
SURFACE must be clearly visible receding backward behind the ridge (roof depth visible
from above, like a farmhouse roof) — a flat top slab, 1–2 tiles deep, brighter than the
front slope. Do NOT draw only a flat triangle silhouette.

ROOF — simple GABLE roof (triangular pitched). Do NOT draw a curved/gambrel roof.

LIGHT — flat 2D pixel shading, single light source from top-left (NW): 1px highlight on
top and left edges, crisp dark shadows to bottom-right (SE). Strict step-shading, max
2–3 value steps per material, NO smooth gradients, NO rim light, NO glow.

PIXELS — chunky retro pixel art: strong single dark outline, bold uniform blocky pixels,
low detail. Hard-edged, aliased pixels only. NO anti-aliasing, NO soft edges, NO blur,
NO dithering gradients. Think hand-placed pixels on a coarse grid.

PALETTE — warm cozy farmstead: honey/amber wood-brown walls and warm-toned roof, muted
warm greens/greys. Slightly desaturated, not candy-bright. Grey stone footing slab at the
very bottom that sits flush on the ground.

DOOR — a WIDE recessed double door (two door-leaves side by side, ~2 tiles wide),
centered on the front wall (south-facing entrance), dark outline on its top and left so
it reads as set INTO the wall. Door height ≥ a human character (building is ~6–8
characters tall).

FRAMING — single standalone building, centered. Fully TRANSPARENT background (no ground,
no grass, no cast shadow baked in — those are added procedurally in-engine). The building
bottom must end cleanly at the stone footing, nothing drooping below it.

Output: high-resolution, clean, single sprite, transparent PNG.
```

### 건물별 `[[BUILDING]]` 치환값

| 건물 | `[[BUILDING]]` 값 | 문 / 비고 |
|---|---|---|
| **본가** | `a wide two-story wooden farmhouse with a red pitched gable roof, a chimney rising FROM the roof ridge, and shuttered windows` | 넓은 양개 현관문 2칸·정중앙. 굴뚝은 지붕 마루에서 솟게(측면 기둥 금지 — [ADR-0036] §3.3). footprint 짝수폭으로 재생성. |
| **창고** | `a medium wooden storage shed with a pitched gable roof and a double sliding barn-style door on the front` | 2칸 미닫이·정중앙. |
| **축사** | `a wooden farm outbuilding (livestock shed) with a red pitched gable roof and a wide double sliding door` | 2칸 미닫이·정중앙. ⚠️ **"barn" 단어 금지** — 넣으면 빨간 헛간 클리셰 강제됨(gemini-shed-barn-spec REVISION 4). `wooden farm outbuilding`으로. |

> **문 = 2칸 규약([ADR-0046]):** 3건물 다 짝수폭이라 문은 정면 벽 **정중앙 2칸**. 프롬프트의 `~2 tiles wide, centered`가 이걸 강제. 아트 문 중심이 건물 중심 seam과 맞아야 그리드 2칸·진입로 2칸·트리거와 1:1 정합.

> **앵커 팁:** 제미나이에 참조 이미지를 물릴 수 있으면 **본가를 먼저 확정**한 뒤, 창고·축사 생성 시 확정된 본가 PNG를 첨부하고 "same art style, same pixel grain, same warm palette and lighting as this reference"라고 지시 → 3건물 룩이 확 붙는다.

---

## 2. 뽑아온 뒤 — 일관성 강제 후처리 (내가 하는 코드 작업)

제미나이 원본을 `game/assets/_staging_phaseC/gemini/` 에 이 이름으로 넣는다:

- `house_gemini.png`
- `storehouse_gemini.png`
- `barn_gemini.png`

**단일 글루 스크립트** `game/tools/gemini_facade_to_chunky.py`로 3건물을 **똑같은 파이프라인**에 통과시킨다(= "일관 적용"의 실체):

1. **배경 제거** — content bbox 오토크롭(투명 여백 제거, 스케일을 건물 기준으로).
2. **half-res 정규화** — `1 타일 = 16 논리px` 그리드로 다운스케일(LANCZOS). ← **청키 "정도"를 3건물 공통 상수로 고정**하는 지점. 입력 해상도가 제각각이어도 결과 그레인 동일.
3. **하드 알파 임계** — 반투명 AA 엣지 제거(헤일로 방지, [§8.1](./asset-ruleset.md)).
4. **★팔레트 양자화(median-cut·무디더·기본 48색)** — **선명도 핵심**([§16](./asset-ruleset.md)). LANCZOS 다운스케일이 색을 연속 램프로 섞어(수천 색) 2px 블록 안이 그라데이션=흐림 → median-cut로 램프를 플랫 색에 스냅해 크리스프. 이 단계 없으면 청키하지만 흐리다(owner "흐림" 피드백 2026-07-02).
5. **×2 nearest** — 2px 블록으로 굳힘(캐논 [§0.1](./asset-ruleset.md), 100% 청키).
6. **bbox 트림** — art 바텀 = 실제 밑단(`_blit_facade_anchored` 앵커 전제).

같은 스크립트·같은 상수(target 폭 = footprint 타일폭×32, ncolors=48) → **3건물 청키 정도·선명도 100% 동일** 보장. 처리 후 `assets/buildings/{house,storehouse,barn}_ext.png` 교체.

> **★2px 캐논 vs 선명도 (owner 결정 2026-07-02):** 제미나이 고해상 소스는 2px 캐논([§0.1])으로 다운스케일하면 raw보다 굵어진다(불가피 — 1px 그레인은 §0.1 위반). owner가 **A: 2px 캐논 유지**를 택함 → 양자화로 캐논 안에서 최대 크리스프. 실제: 본가 320×292·창고 192×196, 둘 다 48색·2x2블록 100%.

## 3. 코드 정합 (같은 워크트리에서)

- **본가 footprint 짝수폭 조정**(9 → 8 or 10) + 문 정중앙 2칸([ADR-0046]).
- 3건물 `*_EXT_DOOR` 2칸·`_carve_paths` 진입로 2칸·진입 트리거 2칸 수용(창고·축사 기존 패턴 일반화).
- 실내문도 외관문과 폭·쏠림 일치(`_build_room` 문폭 파라미터화).
- `home_full_dump` 육안(지붕 윗면 노출 [§2] 필수·접지·팔레트 정합) → `game/run_tests.sh` 회귀.

> 코드·에셋 변경은 [워크트리 격리 규칙](../../CLAUDE.md) 준수 — 이미지 뽑아온 시점에 `EnterWorktree`로 착수.
