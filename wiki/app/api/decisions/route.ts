import { NextRequest, NextResponse } from "next/server";
import { readFileSync, writeFileSync, existsSync, mkdirSync } from "node:fs";
import { join } from "node:path";

// 에셋 결정(도구 정정·작업 지시·메모) 로컬 영속 — wiki/data/asset-decisions.json.
// 로컬 dev/서버 모드 전용(정적 export 배포에는 미포함 — 뷰 전용). 어시스턴트가 이 파일을 읽어 작업.
export const runtime = "nodejs";

const FILE = join(process.cwd(), "data", "asset-decisions.json");

function load(): Record<string, unknown> {
  try {
    if (existsSync(FILE)) return JSON.parse(readFileSync(FILE, "utf8"));
  } catch {}
  return {};
}

function save(data: Record<string, unknown>) {
  mkdirSync(join(process.cwd(), "data"), { recursive: true });
  writeFileSync(FILE, JSON.stringify(data, null, 2));
}

export async function GET() {
  return NextResponse.json(load());
}

export async function POST(req: NextRequest) {
  let body: { id?: string; decision?: Record<string, unknown> | null };
  try {
    body = await req.json();
  } catch {
    return NextResponse.json({ ok: false, error: "bad json" }, { status: 400 });
  }
  const id = body?.id;
  if (!id || typeof id !== "string") {
    return NextResponse.json({ ok: false, error: "id required" }, { status: 400 });
  }
  const data = load();
  if (body.decision === null) {
    delete data[id];
  } else {
    data[id] = { ...(body.decision || {}), updatedAt: new Date().toISOString() };
  }
  save(data);
  return NextResponse.json({ ok: true, count: Object.keys(data).length });
}
