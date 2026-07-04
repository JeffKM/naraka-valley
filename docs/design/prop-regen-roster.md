# 프롭 아트 재생성 로스터 (16px 전환 — ADR-0049 downstream)

> **상태:** 2026-07-04 grill/작업 산출. owner가 위키 갤러리에서 **24개 prop을 "재생성 필요"로 표시**
> (`wiki/data/asset-decisions.json`, action=`regen`). 원인 = 기존 prop 아트가 옛 PixelLab 산출이라
> **맵과 따로 논다(붕 뜸)** → §5 Gemini 프롬프트로 새로 뽑아 **같은 슬롯에 교체**(청키화 아님·아트 자체 재생성).
> **근거:** [gemini-regen-batch.md §5](./gemini-regen-batch.md)(프롬프트 원본)·[ADR-0049](../adr/0049-environment-16px-logical-stardew-grain-supersede-0013.md)(16px 전환).

---

## ★ 열린 항목 — "추가 시스템" (다음 세션 상세)

owner(2026-07-04): **나무·덤불·바위·계단은 *디자인 재생성만이 아니라 추가 시스템 적용*이 필요**하다.
→ **다음 세션에서 이 시스템의 내용을 확정해 여기 채운다.** (예상 후보: 나무=벌목/성장, 바위=채광,
덤불=채집/베기, 계단=다단 절벽 이동 — 미확정. owner 정의 대기.)

> ⚠️ 이 시스템이 prop의 *실루엣·상태 프레임·충돌·상호작용*을 좌우할 수 있으므로, **재생성 아트 스펙을
> 최종 확정하기 전에 이 시스템을 먼저 정한다**(예: 나무가 벌목되면 그루터기 상태가 필요 → 시트 구성 변경).

---

## 1. 통합 워크플로우

1. owner가 §2 프롬프트로 **Gemini 생성**(고해상, 2px 청키·투명배경·접지그림자 없이).
2. 제출 → Claude가 **crop→`game/assets/props/<name>.png` 교체**(드롭인, 게임 코드 0 변경 — 전부 preload 슬롯 유지).
   16px 밀도 정합은 통합 시 리사이즈로(옛 art 청키화가 아니라 *새 art를 목표 밀도로*).
3. `game/tools/home_full_dump.gd`로 새 16px 지면 위에 잘 앉는지 육안(발치 접지·밀도).
4. 위키 재생성 표시 해제(`asset-decisions.json`).
- **권장 순서:** 나무·바위 먼저 → 스타일 확정 → 나머지.

## 2. 재생성 대상 = 13개 (실제로 그려지는 것)

프롬프트 전문은 [gemini-regen-batch.md §5](./gemini-regen-batch.md)의 `[STYLE](§1.1) + F 프레이밍 + [OBJECT]/[SHADOW]`
조립본. 공통 STYLE:
```
detailed pixel art in the style of Stardew Valley and Sun Haven, chunky visible pixels (2px blocks), crisp clean pixel edges, low detail, a warm limited palette slightly desaturated for an underworld/afterlife mood, flat 2D pixel art, light source from top-left (NW), distinct directional step-shading, 1px highlight on top and left edges, crisp dark shadows to bottom-right (SE), 2-3 color values max per material, no smooth gradients, no anti-aliasing. pixel art, 16-bit RPG.
```
공통 프레이밍(뒤에 붙임): ` a single [OBJECT], top-down 3/4 overworld view (Stardew Valley angle), centered on a transparent background, bottom-center anchored, standing upright, no baked ground shadow or cast shadow (only its own form self-shadow), self-shadow color [SHADOW].`

| # | name | 규격(32-native) | [OBJECT] | [SHADOW] | 비고 |
|---|---|---|---|---|---|
| 1 | tree_spirit_a | 64×96 SOLID | tall underworld spirit conifer/pine, layered muted blue-green needled canopy tapering upward, dark slender trunk | cool blue-violet slate | 발치충돌·머리통과 |
| 2 | tree_spirit_b | 96×96 SOLID | large underworld spirit broadleaf tree, rounded muted blue-green leafy canopy in chunky clumps, thick dark trunk, a few pale spirit-blossoms | cool blue-violet slate | 〃 |
| 3 | rock | 64×64 SOLID | large mossy underworld boulder, chunky faceted grey-slate stone with muted moss patches, solid and heavy | cool blue-violet slate | 발치충돌 |
| 4 | bush | 64×64 | rounded underworld hedge bush, dense muted moss-green foliage in a chunky dome, a few small dark spirit-berries, slightly withered afterlife tone | cool blue-violet slate | |
| 5 | stump_log | 64×32 | fallen tree stump and log on its side, weathered grey-brown deadwood, visible ring on the cut face, muted bark | cool blue-violet slate | 장식(치울 수 없음) |
| 6 | vine | 32×64 | hanging vine drape, muted green tangled leaves and tendrils cascading vertically downward as decorative cliff cover, spanning top to bottom of the frame | cool blue-violet slate | 절벽 면 장식 |
| 7 | spirit_flower_patch | 32×32 | small patch of spirit flowers, clustered muted spider-lily-like red-crimson blooms with slender stems, low and delicate | cool blue-violet slate | |
| 8 | spirit_pot | 32×32 | small underworld ceramic spirit-pot/urn, muted glazed slate-blue clay with a faint spirit-glow rim, holding a wisp of pale afterlife plant | cool blue-violet slate | |
| 9 | debris_ember_stone | 64×64 SOLID | large jagged ember-rock boulder, dark charred grey-black stone with dim glowing ember-orange cracks like cooling hellfire, an obstacle blocking reclamation | cool blue-violet slate | 개간 곡괭이 |
| 10 | debris_petrified_stump | 64×64 SOLID | large petrified tree stump, grey stone-turned deadwood with cracked bark and gnarled broken roots, lifeless muted tone, an obstacle, distinct heavier stonier silhouette than a normal wooden stump | cool blue-violet slate | 개간 도끼 |
| 11 | debris_weeds | 32×32 | clump of clearable overgrown weeds, tall muted grey-green tangled stalks with dry brown tips, scraggly | cool blue-violet slate | 개간 낫 |
| 12 | farm_planter | 32×32 | small warm terracotta farm planter box with dark soil and a tiny muted afterlife sprout | dark warm brown | |
| 13 | stairs_east | 96×64 | flight of stone steps built into a cliff, ascending from the LOW east side (right) UP to the high west side (left), muted grey-slate treads receding leftward-and-up, a 3-tile-wide notch, walkable, recompute NW top-left lighting (do not mirror) | cool blue-violet slate | ⚠️방향·NW광원 |

## 3. 재생성 불필요 = 11개 (죽은 지면 디테일)

`ground_grass1/2/3` · `ground_flower` · `ground_gravel` · `ground_pebble` · `ground_weed_dry` ·
`ground_weed_under` · `ground_dirt` · `ground_crack` · `grass_tuft` — 지면 디테일 스캐터인데
**`main.gd::_build_ground_details()` 비활성** + 손배치 폐기라 **게임에서 안 그려짐**(죽은 preload).
재생성해도 안 보인다 → 재생성 대상 아님. 별도로 dead preload 정리 후보(§추가 시스템 확정 시 함께).
