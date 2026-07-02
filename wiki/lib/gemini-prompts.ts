// Gemini 재생성 프롬프트 — 웹에서 복사해 바로 쓰는 완성본.
// 단일 진실원은 docs/design/gemini-regen-batch.md(스펙카드) + ADR-0047.
// 여기서는 [STYLE] 같은 placeholder를 전개해 "복사→붙여넣기" 완성 프롬프트로 만든다.

export interface GeminiPrompt {
  id: string; // 에셋 파일명(확장자 제외)
  category: "characters" | "crops" | "tiles" | "props" | "buildings" | "ui";
  label: string; // 표시용 한글 이름
  size: string; // 최종 PNG 치수
  note?: string; // 짧은 지침(한글)
  prompt: string; // 완성 영어 프롬프트(그대로 복붙)
}

// ── 공통 스타일 토큰 ─────────────────────────────────────────────
const STYLE =
  "detailed pixel art in the style of Stardew Valley and Sun Haven, chunky visible pixels (2px blocks), crisp clean pixel edges, low detail, a warm limited palette slightly desaturated for an underworld/afterlife mood, flat 2D pixel art, light source from top-left (NW), distinct directional step-shading, 1px highlight on top and left edges, crisp dark shadows to bottom-right (SE), 2-3 color values max per material, no smooth gradients, no anti-aliasing. pixel art, 16-bit RPG.";

const STYLE_CHAR =
  "detailed pixel-art character sprite in the style of Stardew Valley and Sun Haven — chunky visible pixels, crisp clean pixel edges, painterly pixel shading, a warm limited palette slightly desaturated for an underworld/afterlife mood, large readable silhouette, cozy dark-fantasy JRPG. flat 2D pixel art, light source from top-left (NW), distinct directional step-shading, crisp dark shadows to bottom-right (SE), no smooth gradients, no anti-aliasing. top-down 3/4 overworld view (Stardew Valley walking angle), full body standing, chibi ~2.5-3 heads tall. Transparent background. HIGH DETAIL, sharp crisp readable features — prioritize sharpness and clean facial/costume detail over blur, do NOT mush pixels together.";

// ── 조립 헬퍼 ────────────────────────────────────────────────────
const DIRS =
  "Generate one image per direction (4 total). Append ONE of these lines each time:\n- DOWN / south: faces the camera / toward the viewer, face fully visible.\n- UP / north: faces away / seen from behind, back of head and back visible, no face.\n- RIGHT / east: faces to the RIGHT in side profile.\n- LEFT / west: faces to the LEFT in side profile (or mirror the east image).";

function charPrompt(slot: string, pose: string): string {
  return `${STYLE_CHAR}\nCHARACTER: ${slot}\nPOSE: ${pose}\n${DIRS}`;
}

const cropF = (stage: string) =>
  `${STYLE} a single small crop plant, top-down 3/4 overworld view, centered on a transparent background, ${stage}`;

const CLIFF =
  "a seamless tileable top-down cliff tile, cold desaturated slate blue-grey rock, 3 value steps only, single dark outline #401818, cool blue-violet slate self-shadow, chunky 2px blocks, edge-to-edge no border.";
const cliffF = (desc: string) => `${STYLE} ${CLIFF} ${desc}`;

const terrainF = (terrain: string) =>
  `${STYLE} a seamless tileable top-down ${terrain} texture, warm inviting farm palette like Stardew Valley slightly muted (not candy-bright), tonal variation, small distinct tufts/clumps with sunlit tops and shaded bases, volumetric depth NOT flat uniform pattern, single dark outline #401818, chunky 2px blocks, edge-to-edge, no border.`;

const interiorF = (surface: string) =>
  `${STYLE} a seamless tileable top-down interior ${surface} texture, warm muted wood/stone, single dark outline #401818, chunky 2px blocks, edge-to-edge no border.`;

const propF = (obj: string, shadow: string) =>
  `${STYLE} a single ${obj}, top-down 3/4 overworld view (Stardew Valley angle), centered on a transparent background, bottom-center anchored, standing upright, no baked ground shadow or cast shadow (only its own form self-shadow), self-shadow color ${shadow}.`;

const groundF = (obj: string) =>
  `${STYLE} a single tiny ${obj}, strict top-down view lying flat on the ground like a small decal, tiny and low-detail, low contrast so it melts into the ground, centered on a transparent background, no upright form, no baked shadow.`;

const SLATE = "cool blue-violet slate";
const WOOD = "dark warm brown";

const BUILD_HEAD =
  "Top-down 3/4 view cozy farm game building sprite, Stardew Valley / Sun Haven pixel-art style.";
const BUILD_BODY =
  "VIEW — front-facing facade, camera looking straight at the front wall. NOT isometric, NOT angled, NO left/right side walls. Symmetrical front elevation. The sloped ROOF TOP SURFACE must be clearly visible receding backward behind the ridge (roof depth visible from above) — a flat top slab, 1-2 tiles deep, brighter than the front slope. Do NOT draw only a flat triangle silhouette.\n\nROOF — simple GABLE roof (triangular pitched). Do NOT draw a curved/gambrel roof.\n\nLIGHT — flat 2D pixel shading, single light source from top-left (NW): 1px highlight on top and left edges, crisp dark shadows to bottom-right (SE). Strict step-shading, max 2-3 value steps per material, NO smooth gradients, NO rim light, NO glow.\n\nPIXELS — chunky retro pixel art: strong single dark outline, bold uniform blocky pixels, low detail. Hard-edged aliased pixels only. NO anti-aliasing, NO soft edges, NO blur, NO dithering gradients.\n\nPALETTE — warm cozy farmstead base (honey/amber wood-brown walls, warm-toned roof), slightly desaturated, not candy-bright. Grey stone footing slab at the very bottom sitting flush on the ground.";
function buildingPrompt(building: string, door: string, accent: string): string {
  return `${BUILD_HEAD} Subject: ${building}.\n\n${BUILD_BODY} ${accent}\n\nDOOR — ${door} centered on the front wall (south-facing entrance), dark outline on its top and left so it reads as set INTO the wall. Door height >= a human character (building ~6-8 characters tall).\n\nFRAMING — single standalone building, centered. Fully TRANSPARENT background (no ground, no grass, no cast shadow baked in). The building bottom must end cleanly at the stone footing.\n\nOutput: high-resolution, clean, single sprite, transparent PNG.`;
}

// ── 프롬프트 데이터 ──────────────────────────────────────────────
export const GEMINI_PROMPTS: GeminiPrompt[] = [
  // ── 캐릭터 (5) — 선명도 우선, 4방향 개별 생성 → assemble_char.py 조립 ──
  {
    id: "miho_walk",
    category: "characters",
    label: "미호 (여우·작물양육)",
    size: "480×320 (80프레임 6×4)",
    note: "walk 필요. 꼬리 반드시 1개. 방향별 생성 후 assemble_char.py로 조립.",
    prompt: charPrompt(
      "a warm gentle young woman, white fox ears on top of her head, dark-brown long wavy hair, large soft friendly eyes, a greyish-lavender-and-white top with a hint of a yellow skirt beneath, ONE single white fox tail (exactly one tail, steady, no sway), a small floating blue fox-fire flame beside her head. No glasses. Warm, kind expression.",
      "walking — mid-stride, one leg forward one leg back, arms swinging; tail and fox ears steady, fixed, no flutter. (For idle use: standing still, both feet together, relaxed.)"
    ),
  },
  {
    id: "okja",
    category: "characters",
    label: "옥자 (카페 점주·마녀)",
    size: "480×320 (80프레임 6×4)",
    note: "안경 有(옥자만). 정지 NPC — idle 4방향으로 충분.",
    prompt: charPrompt(
      "a composed elegant young woman, a black witch hat with a single small burgundy feather, burgundy wavy hair, a solid burgundy dress, round thin glasses, large sharp calm eyes, cool serene demeanor.",
      "idle — standing still, calm, both feet together."
    ),
  },
  {
    id: "bana",
    category: "characters",
    label: "바나 (뱀파이어·야간경비)",
    size: "480×320 (80프레임 6×4)",
    note: "안경 無. idle 4방향.",
    prompt: charPrompt(
      "a young woman in a purple-and-black frilled gothic-lolita dress, blonde hair with a black front-bang streak, red eyes, small vampire fangs, a frilled choker. No glasses.",
      "idle — standing still, poised."
    ),
  },
  {
    id: "mel",
    category: "characters",
    label: "멜 (강시·카페운영)",
    size: "480×320 (80프레임 6×4)",
    note: "안경 無. idle 4방향.",
    prompt: charPrompt(
      "a young woman in a teal jiangshi (Chinese hopping-ghost) robe with a blue floral pattern, a matching teal jiangshi cap with a single red beaded tassel on the side, a straight blunt black bob cut, blue-grey eyes, a red prayer-bead (mala) necklace, red lips, blushing cheeks, a mandarin collar with frog buttons. No glasses.",
      "idle — standing still, arms relaxed at sides."
    ),
  },
  {
    id: "player_walk",
    category: "characters",
    label: "플레이어 (저승 농부)",
    size: "480×320 (80프레임 6×4)",
    note: "walk 필요. 의도적 무채·저채도(팔레트 스왑 베이스).",
    prompt: charPrompt(
      "a gender-neutral young afterlife farmer, deliberately plain and unremarkable, short dark-brown hair, a simple low-saturation muted work outfit (earthy tunic or overshirt, plain trousers, sturdy boots) suitable for farming in the underworld, no distinct accessories, calm neutral face. A blank-slate protagonist designed for later palette swaps. No glasses.",
      "walking — mid-stride, one leg forward one leg back, arms swinging. (For idle use: standing still, both feet together.)"
    ),
  },

  // ── 작물 (9) — 3작물 × 3단계 ──
  {
    id: "honryeongcho_seed",
    category: "crops",
    label: "혼령초 · 씨앗",
    size: "32×32",
    prompt: cropF(
      "freshly planted seed on dark tilled soil, tiny pale blue-green sprout tip just breaking the dark soil #332016, one or two faint spirit-blue #60d8f0 pixels of glow. a wispy spirit herb."
    ),
  },
  {
    id: "honryeongcho_sprout",
    category: "crops",
    label: "혼령초 · 새싹",
    size: "32×32",
    prompt: cropF(
      "a small young herb seedling, a few thin upright blades of pale teal-green grass, faint soul-blue #60d8f0 glow along the leaf edges, on dark soil. a glowing spirit grass."
    ),
  },
  {
    id: "honryeongcho_mature",
    category: "crops",
    label: "혼령초 · 수확기",
    size: "32×32",
    note: "밭흙 대비 밝은 영혼빛(dark-on-dark 회피).",
    prompt: cropF(
      "a harvest-ready small tuft of tall wispy grass blades glowing with cool spirit-blue light #60d8f0 to #2068e8, ghostly ethereal herb, brighter than the dark soil. luminous soul grass ready to harvest."
    ),
  },
  {
    id: "pianhwa_seed",
    category: "crops",
    label: "편화(피안화) · 씨앗",
    size: "32×32",
    prompt: cropF("a freshly planted bulb on dark tilled soil #332016, a single dark-red sprout tip emerging. a red spider lily bulb."),
  },
  {
    id: "pianhwa_sprout",
    category: "crops",
    label: "편화(피안화) · 새싹",
    size: "32×32",
    prompt: cropF(
      "a young lily shoot, a slender bare crimson-green stalk rising from dark soil, no bloom yet, a hint of deep red at the tip. a red spider lily stem sprouting."
    ),
  },
  {
    id: "pianhwa_mature",
    category: "crops",
    label: "편화(피안화) · 수확기",
    size: "32×32",
    prompt: cropF(
      "a blooming red spider lily (higanbana), one radial cluster of thin spidery deep-crimson petals and long curling stamens on a tall dark stalk, an ominous otherworldly funeral flower, muted blood-red against dark soil. the flower of the far shore in bloom."
    ),
  },
  {
    id: "yeonghon_hobak_seed",
    category: "crops",
    label: "영혼호박 · 씨앗",
    size: "32×32",
    prompt: cropF("a large pumpkin seed pressed into dark tilled soil #332016, a small pale sprout curl emerging. a soul pumpkin seed."),
  },
  {
    id: "yeonghon_hobak_sprout",
    category: "crops",
    label: "영혼호박 · 새싹",
    size: "32×32",
    prompt: cropF(
      "a young pumpkin seedling, two broad low green leaves and a curling vine tendril spreading over dark soil, close to the ground. a pumpkin vine sprouting."
    ),
  },
  {
    id: "yeonghon_hobak_mature",
    category: "crops",
    label: "영혼호박 · 수확기",
    size: "32×32",
    note: "잭오랜턴 아님 — 얼굴이 어렴풋이 비침.",
    prompt: cropF(
      "one plump ripe muted-orange pumpkin resting on the ground with a green stem and leaves, a faint ghostly soul face dimly glowing through the pumpkin skin (subtle spirit-blue #60d8f0 inner light, NOT a carved jack-o-lantern), eerie afterlife squash. a soul pumpkin ready to harvest."
    ),
  },

  // ── 타일 · 절벽 (17) — NW 광원 재보정(동↔서 단순 flip 금지) ──
  { id: "cliff_s_face", category: "tiles", label: "절벽 남면(face)", size: "32×32", prompt: cliffF("the vertical south-facing rock wall face, seen straight on, horizontal strata, top edge lit (NW), lower body in shadow.") },
  { id: "cliff_s_base", category: "tiles", label: "절벽 남면 접지(base)", size: "32×32", prompt: cliffF("the base row of a south-facing cliff where the wall meets lower ground, self-shadow baked at the foot, darkest along the bottom.") },
  { id: "cliff_s_lip", category: "tiles", label: "절벽 남면 상단(lip)", size: "32×32", prompt: cliffF("the top lip: bright sunlit grass overhang edge (warm-moss #739952/#8fb267) with a 1px highlight, rock edge just below, walkable plateau rim.") },
  { id: "cliff_n_lip", category: "tiles", label: "절벽 북면 상단(lip)", size: "32×32", prompt: cliffF("the far (north) top lip, grass plateau meeting the rock edge, viewed from above, top-left lit.") },
  { id: "cliff_e_face", category: "tiles", label: "절벽 동면(face)", size: "32×32", note: "동면 — SE쪽 어둡게. 서면 미러 금지.", prompt: cliffF("an east-facing vertical cliff wall, height turned sideways into 2 columns of rock, RIGHT (east) side turned away from NW light so it reads darker toward SE, recompute shading — do NOT mirror the west face.") },
  { id: "cliff_e_lip", category: "tiles", label: "절벽 동면 상단(lip)", size: "32×32", prompt: cliffF("the east lip column, narrow grass overhang rim on the east side, top-left light preserved.") },
  { id: "cliff_w_face", category: "tiles", label: "절벽 서면(face)", size: "32×32", note: "서면 — 좌상단 밝게. 동면 미러 금지.", prompt: cliffF("a west-facing vertical cliff wall, 2 columns of rock, LEFT (west) side catching NW light with a bright 1px highlighted edge, recompute shading — do NOT mirror the east face.") },
  { id: "cliff_w_lip", category: "tiles", label: "절벽 서면 상단(lip)", size: "32×32", prompt: cliffF("the west lip column, narrow grass overhang rim on the west side, brightly lit top-left edge.") },
  { id: "cliff_out_nw", category: "tiles", label: "절벽 외부코너 NW", size: "32×32", prompt: cliffF("an OUTER (convex) corner tile for the NW corner, grass plateau overhang wrapping the corner over slate rock, fully filled edges (no green bleed), NW light consistent.") },
  { id: "cliff_out_ne", category: "tiles", label: "절벽 외부코너 NE", size: "32×32", prompt: cliffF("an OUTER (convex) corner tile for the NE corner, grass plateau overhang wrapping the corner over slate rock, fully filled edges (no green bleed), NW light consistent.") },
  { id: "cliff_out_sw", category: "tiles", label: "절벽 외부코너 SW", size: "32×32", prompt: cliffF("an OUTER (convex) corner tile for the SW corner, grass plateau overhang wrapping the corner over slate rock, fully filled edges (no green bleed), NW light consistent.") },
  { id: "cliff_out_se", category: "tiles", label: "절벽 외부코너 SE", size: "32×32", prompt: cliffF("an OUTER (convex) corner tile for the SE corner, grass plateau overhang wrapping the corner over slate rock, fully filled edges (no green bleed), NW light consistent.") },
  { id: "cliff_in_nw", category: "tiles", label: "절벽 내부코너 NW", size: "32×32", prompt: cliffF("an INNER (concave) corner tile for the NW inside corner, plateau grass tucking into the notch, rock face on two adjacent sides, edge-to-edge fill, NW light.") },
  { id: "cliff_in_ne", category: "tiles", label: "절벽 내부코너 NE", size: "32×32", prompt: cliffF("an INNER (concave) corner tile for the NE inside corner, plateau grass tucking into the notch, rock face on two adjacent sides, edge-to-edge fill, NW light.") },
  { id: "cliff_in_sw", category: "tiles", label: "절벽 내부코너 SW", size: "32×32", prompt: cliffF("an INNER (concave) corner tile for the SW inside corner, plateau grass tucking into the notch, rock face on two adjacent sides, edge-to-edge fill, NW light.") },
  { id: "cliff_in_se", category: "tiles", label: "절벽 내부코너 SE", size: "32×32", prompt: cliffF("an INNER (concave) corner tile for the SE inside corner, plateau grass tucking into the notch, rock face on two adjacent sides, edge-to-edge fill, NW light.") },
  { id: "cliff_bank", category: "tiles", label: "강둑 절벽(물가)", size: "32×32", prompt: cliffF("a river-bank cliff face where a rock/earth bank drops one step down to spirit-water, water line at the base tinted spirit-blue #2068e8 to #60d8f0, cool slate rock above, at least one row of vertical bank face for pseudo-Z between plateau grass and low water.") },

  // ── 타일 · 지형 Wang (9) — base만 생성, 이음새는 후처리 ──
  { id: "gpv2_image", category: "tiles", label: "풀 변종 2", size: "128×128", note: "seamless base만. per-cell 변종용 클럼프 배치.", prompt: terrainF("lush grass (warm-moss #2d4720 to #8fb267)") },
  { id: "gpv3_image", category: "tiles", label: "풀 변종 3", size: "128×128", note: "gpv2와 다른 클럼프 배치.", prompt: terrainF("lush grass (warm-moss #2d4720 to #8fb267), a different clump arrangement from other grass variants") },
  { id: "sgv2_image", category: "tiles", label: "흙 변종 2", size: "128×128", prompt: terrainF("bare tilled soil / dirt (warm brown #332016 to #896d5a)") },
  { id: "wgv2_image", category: "tiles", label: "물가 풀 변종 2", size: "128×128", prompt: terrainF("grass beside spirit-water, the water pixels tinted spirit-blue #2068e8 to #60d8f0, grass warm-moss") },
  { id: "grass_path_image", category: "tiles", label: "풀↔흙길 전이", size: "128×128", prompt: terrainF("grass meeting a warm dirt path (path #513928 to #bc987c)") },
  { id: "path_soil_image", category: "tiles", label: "흙길↔밭흙 전이", size: "128×128", prompt: terrainF("a dirt path meeting dark tilled farm soil (soil #332016 to #896d5a)") },
  { id: "soil_grass_image", category: "tiles", label: "밭흙↔풀 전이", size: "128×128", prompt: terrainF("tilled soil meeting grass") },
  { id: "water_grass_image", category: "tiles", label: "풀↔영혼강물 전이", size: "128×128", note: "물 픽셀만 영혼빛, 풀/흙 warm 유지.", prompt: terrainF("a grass edge meeting spirit-river water, only the water pixels glow spirit-blue #2068e8 to #60d8f0, grass and dirt stay warm") },
  { id: "combined_terrain_homestead_atlas", category: "tiles", label: "안식 농원 결합 아틀라스", size: "160×512", note: "정석은 개별 지형→converter 합성. 직생성 시 전이열은 후처리 정합.", prompt: `${STYLE} a top-down terrain tile atlas sheet, 5 columns wide, warm Stardew-like farm palette slightly muted for underworld mood, rows of seamless grass / dirt-path / tilled-soil / grass-path-transition / soil variants, each cell a chunky 2px-block tileable texture, single dark outline #401818.` },

  // ── 타일 · 실내 (6) ──
  { id: "cafe_floor", category: "tiles", label: "카페 바닥", size: "32×32", prompt: interiorF("cafe wooden plank floor, warm honey-brown boards, subtle grain") },
  { id: "cafe_wall", category: "tiles", label: "카페 벽", size: "32×32", prompt: interiorF("cafe interior wall, warm plaster/wood paneling, top edge lit") },
  { id: "house_floor", category: "tiles", label: "집 바닥", size: "32×32", prompt: interiorF("cozy house wooden floorboards, warm brown") },
  { id: "house_wall", category: "tiles", label: "집 벽(하단)", size: "32×32", prompt: interiorF("house interior lower wall, warm plaster with a baseboard") },
  { id: "house_wall_upper", category: "tiles", label: "집 벽(상단)", size: "32×32", prompt: interiorF("house interior upper wall row, warm plaster, top-left lit, tiles above house_wall") },
  { id: "wall", category: "tiles", label: "저승 구조물 벽", size: "32×32", prompt: interiorF("generic stone/wood wall block, cold slate for underworld structures, top edge lit NW") },

  // ── Props · 농장 (6) ──
  { id: "bush", category: "props", label: "덤불", size: "64×64", note: "통과 가능.", prompt: propF("a rounded underworld hedge bush, dense muted moss-green foliage in a chunky dome, a few small dark spirit-berries, slightly withered afterlife tone", SLATE) },
  { id: "farm_fence", category: "props", label: "농장 울타리", size: "32×32", note: "좌우 seam flat 연속(분리 패널 금지).", prompt: propF("a short weathered wooden farm fence segment, two horizontal rails on posts, aged warm timber, honey-wood grain, tileable side view flat as a boundary rail", WOOD) },
  { id: "farm_planter", category: "props", label: "화분 상자", size: "32×32", prompt: propF("a small warm terracotta farm planter box with dark soil and a tiny muted afterlife sprout", WOOD) },
  { id: "farm_scarecrow", category: "props", label: "허수아비", size: "32×64", prompt: propF("a farm scarecrow on a single wooden post, straw-stuffed body, burlap head with a stitched face, tattered muted cloth, a small crow motif", WOOD) },
  { id: "rock", category: "props", label: "바위", size: "64×64", note: "SOLID(발치 충돌).", prompt: propF("a large mossy underworld boulder, chunky faceted grey-slate stone with muted moss patches, solid and heavy", SLATE) },
  { id: "stump_log", category: "props", label: "쓰러진 통나무", size: "64×32", note: "장식(개간 debris 아님).", prompt: propF("a fallen tree stump and log on its side, weathered grey-brown deadwood, visible ring on the cut face, muted bark", SLATE) },

  // ── Props · 카페 가구 (7) ──
  { id: "cafe_cabinet", category: "props", label: "카페 와인 캐비닛", size: "64×64", prompt: propF("an antique wine cabinet, dark carved wood with glass doors, rows of muted bottles and glassware, burgundy accents", WOOD) },
  { id: "cafe_clock", category: "props", label: "카페 괘종시계", size: "32×64", prompt: propF("a tall antique grandfather pendulum clock, dark carved wood case, round pale face, brass pendulum", WOOD) },
  { id: "cafe_counter", category: "props", label: "카페 카운터", size: "32×32", note: "좌우 flat seam 연속.", prompt: propF("a cafe bar counter segment, dark polished wood front with a warm countertop, burgundy trim, tileable to form a bar", WOOD) },
  { id: "cafe_frame", category: "props", label: "카페 벽 액자", size: "32×32", note: "벽 부착(wall:N).", prompt: propF("a small framed picture on a wall, ornate dark-wood frame, muted afterlife portrait, hanging flat against a wall (wall-mounted, not standing)", WOOD) },
  { id: "cafe_shelf", category: "props", label: "카페 벽 선반", size: "32×32", note: "벽 부착(wall:N).", prompt: propF("a wall-mounted cafe shelf, a dark wood plank with small muted jars, cups and a bottle, flat against the back wall (wall-mounted, not standing)", WOOD) },
  { id: "cafe_stool", category: "props", label: "카페 스툴", size: "32×32", prompt: propF("a round cafe bar stool, dark wood seat on a slender turned-wood/metal leg", WOOD) },
  { id: "cafe_table", category: "props", label: "카페 테이블", size: "32×32", prompt: propF("a small round cafe table, dark wood top on a central pedestal leg, burgundy tone", WOOD) },

  // ── Props · 집 가구 (5) ──
  { id: "house_bed", category: "props", label: "침대", size: "32×64", prompt: propF("a cozy single bed seen from a top-down 3/4 angle, warm wooden headboard and footboard, soft muted quilt with a pillow", WOOD) },
  { id: "house_bookshelf", category: "props", label: "책장", size: "64×64", prompt: propF("a tall wooden bookshelf filled with muted-colored books, a few trinkets and a small pot, warm homely wood", WOOD) },
  { id: "house_fireplace", category: "props", label: "벽난로", size: "64×64", note: "발광부(불꽃)는 *_emit 분리.", prompt: propF("a stone-and-brick fireplace with a warm amber glowing fire inside, wooden mantel with ornaments", WOOD) },
  { id: "house_rug", category: "props", label: "러그(바닥)", size: "96×64", note: "바닥에 눕는 카펫 — upright 금지.", prompt: `${STYLE} a rectangular woven floor rug lying completely flat on the ground like a carpet, muted warm pattern with a woven border, strict top-down view, no thickness, no upright form, centered on a transparent background, no shadow.` },
  { id: "house_table", category: "props", label: "식탁", size: "32×32", prompt: propF("a small square wooden dining table, warm homely timber with visible grain, sturdy legs", WOOD) },

  // ── Props · 개간 debris (3) ──
  { id: "debris_ember_stone", category: "props", label: "업화석(곡괭이)", size: "64×64", note: "SOLID. 앰버 크랙 소량 발광.", prompt: propF("a large jagged ember-rock boulder, dark charred grey-black stone with dim glowing ember-orange cracks like cooling hellfire, an obstacle blocking reclamation", SLATE) },
  { id: "debris_petrified_stump", category: "props", label: "석화 고목(도끼)", size: "64×64", note: "SOLID. 돌화·험상(장식 통나무와 구분).", prompt: propF("a large petrified tree stump, grey stone-turned deadwood with cracked bark and gnarled broken roots, lifeless muted tone, an obstacle blocking reclamation", SLATE) },
  { id: "debris_weeds", category: "props", label: "잡초(낫)", size: "32×32", note: "통과 가능.", prompt: propF("a clump of clearable overgrown weeds, tall muted grey-green tangled stalks with dry brown tips, scraggly", SLATE) },

  // ── Props · 저승·자연 (7) ──
  { id: "soul_lantern", category: "props", label: "혼불등", size: "32×32", note: "발광부(혼불)는 *_emit 분리.", prompt: propF("a small underworld soul-lantern, a dark iron/stone post holding a glass lamp with a soft cool spirit-blue flame (#60d8f0) glowing inside", SLATE) },
  { id: "spirit_flower_patch", category: "props", label: "혼령 꽃밭(피안화)", size: "32×32", prompt: propF("a small patch of spirit flowers, clustered muted spider-lily-like red-crimson blooms with slender stems, low and delicate", SLATE) },
  { id: "spirit_pot", category: "props", label: "혼령 항아리", size: "32×32", prompt: propF("a small underworld ceramic spirit-pot/urn, muted glazed slate-blue clay with a faint spirit-glow rim, holding a wisp of pale afterlife plant", SLATE) },
  { id: "tree_spirit_a", category: "props", label: "저승 나무(침엽)", size: "64×96", note: "SOLID 발치·머리 통과.", prompt: propF("a tall underworld spirit conifer/pine, layered muted blue-green needled canopy tapering upward, dark slender trunk", SLATE) },
  { id: "tree_spirit_b", category: "props", label: "저승 나무(활엽)", size: "96×96", note: "SOLID 발치·머리 통과.", prompt: propF("a large underworld spirit broadleaf tree, a rounded muted blue-green leafy canopy in chunky clumps, thick dark trunk, a few pale spirit-blossoms", SLATE) },
  { id: "vine", category: "props", label: "넝쿨(세로 드리움)", size: "32×64", note: "통과 가능. 절벽 면 장식.", prompt: `${STYLE} a single hanging vine drape, muted green tangled leaves and tendrils cascading vertically downward from top to bottom of the frame as decorative cliff cover, centered on a transparent background, self-shadow color ${SLATE}, no baked ground shadow.` },
  { id: "stairs_east", category: "props", label: "동향 돌계단", size: "96×64", note: "동향(저지 오른쪽↔고지 왼쪽). NW 광원 재보정.", prompt: propF("a flight of stone steps built into a cliff, ascending from the LOW east side (right) UP to the high west side (left), muted grey-slate treads receding leftward-and-up, a 3-tile-wide notch, walkable", SLATE) },

  // ── Props · 지면 디테일 (12) — 작고 납작한 decal ──
  { id: "grass_tuft", category: "props", label: "풀 무더기", size: "32×32", prompt: groundF("clump of afterlife moss-grass blades, muted warm-moss green, a few short chunky tufts") },
  { id: "ground_grass1", category: "props", label: "잔디 1(짧음)", size: "16×16", prompt: groundF("very small sparse tuft of short grass blades, muted warm-moss green, 2-3 tiny blades, low contrast") },
  { id: "ground_grass2", category: "props", label: "잔디 2(중간)", size: "24×20", prompt: groundF("small medium tuft of grass blades, muted warm-moss green, a modest clump") },
  { id: "ground_grass3", category: "props", label: "잔디 3(덤불)", size: "26×28", prompt: groundF("taller fuller clump of grass blades, muted warm-moss green with a hint of a small dark spirit-leaf, still flat") },
  { id: "ground_weed_under", category: "props", label: "저승 잡초", size: "16×18", prompt: groundF("small scraggly afterlife weed, muted grey-green tangled stalks, tiny") },
  { id: "ground_weed_dry", category: "props", label: "마른 잡초", size: "20×16", prompt: groundF("small dry withered weed, muted tan and dull-yellow brittle stalks") },
  { id: "ground_flower", category: "props", label: "영혼 들꽃", size: "13×15", prompt: groundF("single tiny spirit wildflower, a small muted spirit-blue/lavender bloom (#60d8f0 hint) on a slender stem") },
  { id: "ground_pebble", category: "props", label: "잔돌", size: "18×14", prompt: groundF("few tiny scattered pebbles, muted grey-slate stones lying flat") },
  { id: "ground_gravel", category: "props", label: "자갈", size: "22×14", prompt: groundF("small patch of scattered gravel, muted grey-brown little stones flat") },
  { id: "ground_embed", category: "props", label: "박힌 잔돌", size: "14×9", prompt: groundF("half-embedded stone set flat into packed dirt, muted grey-slate, mostly flush") },
  { id: "ground_dirt", category: "props", label: "맨흙 패치", size: "28×28", prompt: groundF("small patch of bare warm-brown dirt with a couple of tiny soil clods, completely flat, low contrast") },
  { id: "ground_crack", category: "props", label: "갈라짐·바퀴자국", size: "24×16", prompt: groundF("thin cracked line / wheel-rut carved into packed dirt, a shallow dark muted groove drawn flat, engraved not raised") },

  // ── 건물 facade (4) ──
  {
    id: "miho_house_ext",
    category: "buildings",
    label: "미호 집(한옥·여우불)",
    size: "128×128 (footprint 4×4)",
    note: "문 1칸(한옥 미닫이). 창·등롱 *_emit 분리. target_w=128.",
    prompt: buildingPrompt(
      "a small cozy single-story Korean hanok cottage with a curved-eave tiled gable roof, warm timber-and-hanji (paper) walls, a paper-lattice sliding front door, and small fox-fire lanterns hung under the eaves",
      "a NARROW single sliding paper-lattice door (~1 tile wide)",
      "warm honey wood and off-white hanji panels with soft yellow-ochre trim (Miho's yellow hanbok); tiny paper lanterns glowing pale foxfire-blue (#60d8f0) under the eaves as the only cool accent."
    ),
  },
  {
    id: "mel_house_ext",
    category: "buildings",
    label: "멜 집(강시·청록)",
    size: "160×160 (footprint 5×5)",
    note: "문 1칸(홀수폭). target_w=160.",
    prompt: buildingPrompt(
      "a two-story wooden townhouse with a stacked gable roof, jiangshi-style Qing upturned eave corners, teal-painted timber trim, hanging paper talisman charms (fulu) beside the door, and a small coin-motif sign over the entrance",
      "a single narrow wooden double-leaf door (~1 tile wide)",
      "warm brown timber base with muted TEAL/blue-green painted trim and eave-tips (Mel's teal outfit); pale-yellow paper talisman charms flanking the door. Teal stays desaturated so the house still reads warm."
    ),
  },
  {
    id: "bana_house_ext",
    category: "buildings",
    label: "바나 집(고딕·뱀파이어)",
    size: "128×128 (footprint 4×4)",
    note: "문 1칸. warm 베이스 사수(검은 저택 금지). target_w=128.",
    prompt: buildingPrompt(
      "a small dark gothic cottage with a steep pointed gable roof, a single arched window with wrought-iron lattice, a bat-shape carved into the gable peak, and a wrought-iron weathervane; still warm and cozy, not a spooky mansion",
      "a single arched wooden door with iron studs (~1 tile wide)",
      "warm dusk-brown timber walls with deep plum/charcoal roof and black wrought-iron accents (Bana's gothic dress); a faint spirit-blue (#60d8f0) glow in the arched window. Keep the wood warm — gothic accents are dark trim, NOT a cold black building."
    ),
  },
  {
    id: "cafe_ext",
    category: "buildings",
    label: "나라카 컨셉카페(명소)",
    size: "256×224 (footprint 8×7)",
    note: "3칸 대문. 앰버 창 *_emit 분리(마을 최대 광원). target_w=256.",
    prompt: buildingPrompt(
      "a wide two-story underworld concept-cafe building with a broad welcoming gable roof, a large front porch overhang, big warm amber-lit cafe windows, a hanging cafe sign board, and a GRAND wide central double-entrance; inviting cozy tavern-cafe feel",
      "a GRAND wide central double-door entrance (~3 tiles wide)",
      "warm honey-amber wood and cream plaster, warm-toned roof, big glowing amber cafe windows (the warmth of a lit tavern at dusk); a hanging sign and soft foxfire-blue (#60d8f0) lantern accents at the porch. Warm and welcoming — the cosy heart of the village."
    ),
  },

  // ── UI 아이콘 (6) ──
  { id: "heart_empty", category: "ui", label: "하트(빈)", size: "16×16", prompt: "a single crisp pixel-art UI heart icon, EMPTY state — just the heart outline, chunky 2px blocks, hollow interior (transparent inside), dark warm-brown outline (#401818) with a faint dim rose fill hint, 1px NW top-left highlight, transparent background, centered." },
  { id: "heart_full", category: "ui", label: "하트(참)", size: "16×16", prompt: "a single crisp pixel-art UI heart icon, FULL state — solid filled heart, chunky 2px blocks, warm rose-red fill with a subtle foxfire-blue (#60d8f0) inner glint at the center, dark warm-brown outline (#401818), 1px NW top-left highlight, 2-3 value steps max, transparent background, centered." },
  { id: "heart_full_32", category: "ui", label: "하트(참·32)", size: "32×32", note: "heart_full의 정확한 2배(같은 실루엣·팔레트).", prompt: "a single crisp pixel-art UI heart icon, FULL state at 32x32 — the SAME filled heart silhouette and SAME palette as a 16x16 version (warm rose fill + foxfire-blue inner glint + #401818 outline), just larger with one extra value step allowed, chunky 2px blocks, 1px NW highlight, transparent background, centered." },
  { id: "ink_arrow", category: "ui", label: "먹 화살표(대화)", size: "18×16", prompt: "a single crisp pixel-art UI icon — a small ink-brush ARROW pointing right (dialog next/continue indicator), chunky 2px blocks, clean triangular silhouette, sumi-ink black with a warm dark-brown edge (#401818) like a brush stroke on hanji paper, subtle tapered brush tail, 1px NW highlight, transparent background, centered." },
  { id: "panel_frame", category: "ui", label: "패널 프레임(9-slice)", size: "46×47", prompt: "a single crisp pixel-art UI PANEL FRAME (9-slice border box, hollow center) in a burned-hanji dialog style — warm aged-paper cream fill with a scorched dark-brown border (#401818) and faint burnt edges, chunky 2px blocks, clean symmetrical readable border, thin ink inner keyline, corners consistent for 9-slice tiling, 1px NW highlight, transparent background, centered." },
  { id: "soul_moth", category: "ui", label: "영혼 나방", size: "24×24", prompt: "a single crisp pixel-art icon of a SOUL MOTH (spirit moth) with open wings seen from above, chunky 2px blocks, clean symmetrical readable silhouette, sumi-ink dark body and wing outlines (#401818) like a brush-painted moth, wings washed with soft glowing foxfire/spirit-blue (#60d8f0 to #2068e8), a tiny amber glint at the body core, 1px NW highlight, transparent background, centered." },
];

export const PROMPT_CATEGORIES: { key: GeminiPrompt["category"]; label: string }[] = [
  { key: "characters", label: "캐릭터" },
  { key: "crops", label: "작물" },
  { key: "tiles", label: "타일" },
  { key: "props", label: "프롭·가구" },
  { key: "buildings", label: "건물" },
  { key: "ui", label: "UI" },
];
