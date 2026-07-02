// 나라카 밸리 위키 — 에셋 매니페스트 생성기
// game/assets/** 의 렌더 PNG를 스캔해 (1) wiki/public/assets/ 로 복사하고
// (2) wiki/lib/manifest.json 에 {category,name,file,tool,method,conf,note,w,h} 를 기록한다.
// 도구 귀속(tool attribution)은 docs·메모리 근거로 카테고리 기본 + 파일 접두 오버라이드.
// 의존성 0(내장 fs/path + PNG IHDR 직접 파싱). 데일리 재생성: `npm run manifest`.
import { readdirSync, readFileSync, writeFileSync, mkdirSync, copyFileSync, rmSync, existsSync } from "node:fs";
import { join, resolve, basename } from "node:path";

const WIKI = resolve(process.cwd());            // wiki/ 에서 실행
const ASSETS = resolve(WIKI, "..", "game", "assets");
const OUT_PUBLIC = join(WIKI, "public", "assets");
const OUT_MANIFEST = join(WIKI, "lib", "manifest.json");
const ROSTER_SRC = join(WIKI, "lib", "required-assets.json"); // 손 편집 SOURCE
const OUT_ROSTER = join(WIKI, "lib", "roster.json");          // 디프 결과(생성)

const CATEGORIES = ["buildings", "characters", "portraits", "crops", "tiles", "props", "ui"];

// PNG IHDR에서 가로·세로(빅엔디언, 오프셋 16/20) 읽기 — 의존성 없이.
function pngSize(buf) {
  if (buf.length < 24 || buf.readUInt32BE(0) !== 0x89504e47) return { w: 0, h: 0 };
  return { w: buf.readUInt32BE(16), h: buf.readUInt32BE(20) };
}

// ── 도구 귀속(tool attribution) — docs/design·메모리 근거 ──────────────────────
// conf: high(문서 확정)·med(정황 확실)·low(확인 필요 — 갤러리서 배지 표시)
const T = {
  GEMINI: "Gemini",
  PIXELLAB: "PixelLab",
  PROC: "절차생성",   // 코드 색/글루
  UNKNOWN: "확인 필요",
};

function attribute(category, name) {
  const n = name.toLowerCase();
  // 카테고리별 규칙
  if (category === "portraits")
    return { tool: T.GEMINI, method: "Gemini 2×3 표정 그리드 → removebg → 320² 버스트 정규화(make_okja_portraits.py)", conf: "high" };
  if (category === "characters")
    return { tool: T.PIXELLAB, method: "PixelLab create_character 4방향 walk 시트 → 청키화", conf: "high" };
  if (category === "crops")
    return { tool: T.PIXELLAB, method: "PixelLab 작물 3단계(씨앗·새싹·수확) 스프라이트", conf: "med" };
  if (category === "buildings") {
    if (["house_ext", "storehouse_ext", "barn_ext"].includes(n))
      return { tool: T.GEMINI, method: "owner 제미나이 정면 facade → gemini_facade_to_chunky(다운스케일→양자화·청키), 2칸 문(ADR-0046), PR #156", conf: "high" };
    return { tool: T.UNKNOWN, method: "나루 마을 건물(카페·주민 집) — 생성 도구 확인 필요", conf: "low" };
  }
  if (category === "tiles") {
    if (n.startsWith("cliff_"))
      return { tool: T.PIXELLAB, method: "PixelLab create_tiles_pro(square_topdown) → 청키화 → SOLID_TEX 배선(S1-10 다단 절벽)", conf: "high" };
    if (/(_image|_atlas|^gpv|^sgv|^wgv)/.test(n))
      return { tool: T.PIXELLAB, method: "PixelLab create_topdown_tileset(Wang 코너 오토타일) → warm 팔레트 양자화(ADR-0043)", conf: "high" };
    return { tool: T.PIXELLAB, method: "PixelLab 실내/벽 타일(집·카페 바닥·벽)", conf: "med" };
  }
  if (category === "props") {
    if (n.startsWith("cliff") || n.startsWith("stairs"))
      return { tool: T.PIXELLAB, method: "PixelLab(S1-10 절벽/계단 프롭)", conf: "high" };
    if (n.startsWith("ground_") || n === "grass_tuft")
      return { tool: T.PROC, method: "지면 디테일 오버레이(ground-composition, ADR-0043) — 타일 샘플/절차", conf: "med" };
    return { tool: T.PIXELLAB, method: "PixelLab create_map_object(가구·나무·바위·debris·농장 프롭)", conf: "med" };
  }
  if (category === "ui") {
    if (n.startsWith("dialog") || n.startsWith("hanji"))
      return { tool: T.GEMINI, method: "owner 제미나이 「태운 한지」 대화창(make_dialog_window.py 파이프라인)", conf: "high" };
    return { tool: T.UNKNOWN, method: "UI 아이콘(하트·화살·패널·나방) — 생성 도구 확인 필요", conf: "low" };
  }
  return { tool: T.UNKNOWN, method: "", conf: "low" };
}

// ── 스캔·복사·매니페스트 ──────────────────────────────────────────────────────
if (existsSync(OUT_PUBLIC)) rmSync(OUT_PUBLIC, { recursive: true, force: true });
mkdirSync(OUT_PUBLIC, { recursive: true });
mkdirSync(join(WIKI, "lib"), { recursive: true });

const items = [];
for (const category of CATEGORIES) {
  const dir = join(ASSETS, category);
  if (!existsSync(dir)) continue;
  const files = readdirSync(dir)
    .filter((f) => f.endsWith(".png") && !f.endsWith("_raw.png"))
    .sort();
  mkdirSync(join(OUT_PUBLIC, category), { recursive: true });
  for (const f of files) {
    const src = join(dir, f);
    const buf = readFileSync(src);
    const { w, h } = pngSize(buf);
    copyFileSync(src, join(OUT_PUBLIC, category, f));
    const name = basename(f, ".png");
    const attr = attribute(category, name);
    items.push({ category, name, file: `assets/${category}/${f}`, w, h, ...attr });
  }
}

const byTool = {};
for (const it of items) byTool[it.tool] = (byTool[it.tool] || 0) + 1;
const byCat = {};
for (const it of items) byCat[it.category] = (byCat[it.category] || 0) + 1;

const manifest = {
  generatedNote: "자동 생성(build-manifest.mjs) — 수정 금지. 데일리: npm run manifest",
  total: items.length,
  byCategory: byCat,
  byTool,
  categories: CATEGORIES,
  items,
};
writeFileSync(OUT_MANIFEST, JSON.stringify(manifest, null, 2));
console.log(`✅ manifest: ${items.length}개 에셋 · 카테고리 ${Object.keys(byCat).length} · 도구 ${JSON.stringify(byTool)}`);

// ── 목표 로스터 디프(required-assets → roster.json) — ADR-0048 §6 ──────────────
// SOURCE(lib/required-assets.json)의 각 항목을 스캔 결과와 조인해 status를 계산한다.
//   keys 모두 스캔됨 → have · keys 하나라도 없음 → missing
//   단, expected==="placeholder"는 항상 placeholder(Claude 임시 확정본·절차색, Gemini 교체 대기).
//   keys가 비면(=Godot 씬 화면) expected를 그대로 채택(파일 매칭 불가).
if (existsSync(ROSTER_SRC)) {
  const src = JSON.parse(readFileSync(ROSTER_SRC, "utf8"));
  const scanned = new Set(items.map((it) => it.name));
  // 스템 → {file,w,h} (프리뷰용, 최초 매칭 카테고리 사용)
  const byStem = new Map();
  for (const it of items) if (!byStem.has(it.name)) byStem.set(it.name, { file: it.file, w: it.w, h: it.h });

  function resolveStatus(keys, expected) {
    if (expected === "placeholder") return "placeholder";
    if (!keys || keys.length === 0) return expected; // 씬 화면: 수기 상태
    return keys.every((k) => scanned.has(k)) ? "have" : "missing";
  }

  const flat = [];
  const rosterCats = src.categories.map((cat) => {
    const catItems = cat.items.map((r) => {
      const status = resolveStatus(r.keys, r.expected);
      const previewStem = (r.keys || []).find((k) => byStem.has(k));
      const out = {
        category: cat.id,
        categoryTitle: cat.title,
        key: r.key,
        keys: r.keys || [],
        name: r.name,
        maker: r.maker,
        expected: r.expected,
        status,
        note: r.note || "",
        preview: previewStem ? byStem.get(previewStem) : null,
      };
      flat.push(out);
      return out;
    });
    return { id: cat.id, title: cat.title, note: cat.note || "", items: catItems };
  });

  const byStatus = { have: 0, placeholder: 0, missing: 0 };
  const byMaker = { claude: 0, gemini: 0 };
  for (const r of flat) {
    byStatus[r.status] = (byStatus[r.status] || 0) + 1;
    byMaker[r.maker] = (byMaker[r.maker] || 0) + 1;
  }

  const roster = {
    generatedNote: "자동 생성(build-manifest.mjs) — 수정 금지. SOURCE=lib/required-assets.json. 데일리: npm run manifest",
    total: flat.length,
    byStatus,
    byMaker,
    categories: rosterCats,
    items: flat,
  };
  writeFileSync(OUT_ROSTER, JSON.stringify(roster, null, 2));
  const remaining = byStatus.missing + byStatus.placeholder;
  console.log(
    `✅ roster: ${flat.length}개 목표 · 있음 ${byStatus.have} / placeholder ${byStatus.placeholder} / 없음 ${byStatus.missing} (남은 작업 ${remaining})`
  );
} else {
  console.warn(`⚠️  roster SOURCE 없음(${ROSTER_SRC}) — 로스터 디프 건너뜀`);
}
