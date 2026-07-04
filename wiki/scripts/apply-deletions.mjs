// 에셋 삭제 실행기 — 위키에서 `action:"delete"` 표시한 에셋을 실제 game/assets에서 제거.
//
// owner가 갤러리에서 "예전 프롭"을 삭제 표시(→ data/asset-decisions.json)한 뒤 이 스크립트로 반영.
// 안전장치: ① 기본 dry-run(계획만 출력) ② game/*.gd 참조 검사(참조되면 스킵·경고 — 삭제 시
// 게임 깨짐 방지) ③ _raw.png·.import 페어까지 함께 처리 ④ --apply 후 매니페스트 재생성.
//
// 사용:
//   node scripts/apply-deletions.mjs            # dry-run(무엇을 지울지 + 참조 경고만)
//   node scripts/apply-deletions.mjs --apply    # 실제 삭제(참조된 건 스킵)
//   node scripts/apply-deletions.mjs --apply --force   # 참조돼도 강제 삭제(위험)
import { readFileSync, writeFileSync, existsSync, rmSync } from "node:fs";
import { join, resolve } from "node:path";
import { execSync } from "node:child_process";

const WIKI = resolve(new URL(".", import.meta.url).pathname, "..");
const GAME = resolve(WIKI, "..", "game");
const DECISIONS = join(WIKI, "data", "asset-decisions.json");
const MANIFEST = join(WIKI, "lib", "manifest.json");

const APPLY = process.argv.includes("--apply");
const FORCE = process.argv.includes("--force");

function loadJson(p, fallback) {
  try { return JSON.parse(readFileSync(p, "utf8")); } catch { return fallback; }
}

// game/*.gd 전체에서 stem(파일명 없는 이름)을 참조하는 파일 목록. 과탐(주석 포함)은 안전측.
function refsOf(stem) {
  try {
    // -l: 매칭 파일만, -r: 재귀, 고정 문자열. rg 없으면 grep 폴백.
    const out = execSync(
      `grep -rlF ${JSON.stringify(stem)} --include='*.gd' .`,
      { cwd: GAME, encoding: "utf8", stdio: ["ignore", "pipe", "ignore"] }
    ).trim();
    return out ? out.split("\n") : [];
  } catch {
    return []; // 매칭 0이면 grep exit 1 → 참조 없음
  }
}

// 한 에셋(game 상대 file, 예 "assets/props/bush.png")의 삭제 대상 파일들(존재하는 것만).
function targetsFor(file) {
  const abs = join(GAME, file);
  const raw = abs.replace(/\.png$/, "_raw.png");
  const cands = [abs, raw, abs + ".import", raw + ".import"];
  return cands.filter((p) => existsSync(p));
}

function main() {
  const decisions = loadJson(DECISIONS, {});
  const manifest = loadJson(MANIFEST, { items: [] });
  const byId = new Map(manifest.items.map((it) => [`${it.category}/${it.name}`, it]));

  const marked = Object.entries(decisions).filter(([, d]) => d && d.action === "delete");
  if (marked.length === 0) {
    console.log("삭제 표시된 에셋 없음 (data/asset-decisions.json에 action:'delete' 항목 0).");
    return;
  }

  console.log(`\n${APPLY ? "🗑  삭제 실행" : "🔍 DRY-RUN (실제 삭제 안 함)"} — 표시된 ${marked.length}개\n`);
  let toDelete = [];
  let skipped = [];

  for (const [id, d] of marked) {
    const it = byId.get(id);
    if (!it) {
      console.log(`  ? ${id} — 매니페스트에 없음(이미 삭제됐거나 매니페스트 낡음). 스킵.`);
      continue;
    }
    const stem = it.name;
    const refs = refsOf(stem);
    const files = targetsFor(it.file);
    const date = it.createdAt ? it.createdAt.slice(0, 10) : "날짜없음";
    if (refs.length > 0 && !FORCE) {
      skipped.push({ id, refs });
      console.log(`  ⚠️  ${id} (${date}) — game 코드 참조 ${refs.length}곳 → 스킵(--force로 강제):`);
      refs.forEach((r) => console.log(`        ${r}`));
    } else {
      toDelete.push({ id, files, refs });
      const tag = refs.length > 0 ? " ⚠️참조있음(force)" : "";
      console.log(`  ✓ ${id} (${date})${tag} → ${files.length}개 파일`);
      files.forEach((f) => console.log(`        ${f.replace(GAME + "/", "game/")}`));
    }
  }

  console.log(`\n요약: 삭제 대상 ${toDelete.length}개 / 참조로 스킵 ${skipped.length}개`);

  if (!APPLY) {
    console.log("\n실제 삭제하려면: node scripts/apply-deletions.mjs --apply");
    if (skipped.length) console.log("참조된 것도 지우려면(위험): --apply --force");
    return;
  }

  let removed = 0;
  for (const t of toDelete) {
    for (const f of t.files) { rmSync(f, { force: true }); removed++; }
    // 삭제 반영: 결정에서 제거(재실행 시 중복 안 뜨게) — 파일만 지우고 결정 로그는 보존할 수도 있으나
    // 삭제 완료 항목은 정리.
    delete decisions[t.id];
  }
  // 결정 파일 갱신(삭제 완료분 제거 — 재실행 시 중복 방지)
  writeFileSync(DECISIONS, JSON.stringify(decisions, null, 2));
  console.log(`\n🗑  ${removed}개 파일 삭제 완료. 매니페스트 재생성...`);
  execSync("node scripts/build-manifest.mjs", { cwd: WIKI, stdio: "inherit" });
  console.log("✅ 완료. 갤러리 새로고침하면 반영됨.");
}

main();
