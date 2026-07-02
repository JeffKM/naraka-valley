"use client";

import { useMemo, useState } from "react";
import { Search, Info } from "lucide-react";
import type { AssetItem, Manifest } from "@/lib/types";

const BASE = process.env.NEXT_PUBLIC_BASE_PATH || "";

const CAT_LABEL: Record<string, string> = {
  buildings: "건물 facade",
  characters: "캐릭터",
  portraits: "초상화",
  crops: "작물",
  tiles: "타일",
  props: "프롭·가구",
  ui: "UI",
};

const TOOL_STYLE: Record<string, string> = {
  Gemini: "bg-sky-500/15 text-sky-300 border-sky-500/30",
  PixelLab: "bg-emerald-500/15 text-emerald-300 border-emerald-500/30",
  절차생성: "bg-violet-500/15 text-violet-300 border-violet-500/30",
  "확인 필요": "bg-rose-500/15 text-rose-300 border-rose-500/30",
};

function toolClass(tool: string) {
  return TOOL_STYLE[tool] || "bg-neutral-500/15 text-neutral-300 border-neutral-500/30";
}

// 픽셀 프리뷰 배율: 원본이 작으면 크게, 크면 박스에 맞춰(정수 배율 최대 8).
function previewScale(w: number, h: number, box: number) {
  const m = Math.max(w, h) || 1;
  const s = Math.max(1, Math.min(8, Math.floor(box / m)));
  return s;
}

export default function Gallery({ manifest }: { manifest: Manifest }) {
  const [cat, setCat] = useState<string>("all");
  const [tool, setTool] = useState<string>("all");
  const [q, setQ] = useState("");

  const tools = Object.keys(manifest.byTool);
  const items = useMemo(() => {
    return manifest.items.filter((it) => {
      if (cat !== "all" && it.category !== cat) return false;
      if (tool !== "all" && it.tool !== tool) return false;
      if (q && !it.name.toLowerCase().includes(q.toLowerCase())) return false;
      return true;
    });
  }, [manifest.items, cat, tool, q]);

  return (
    <main className="mx-auto max-w-[1400px] px-5 py-8">
      {/* 헤더 */}
      <header className="mb-6">
        <h1 className="text-2xl font-bold tracking-tight">
          나라카 밸리 위키 <span className="text-[var(--amber)]">— 에셋 갤러리</span>
        </h1>
        <p className="mt-1 text-sm text-[var(--muted)]">
          렌더 에셋 <b className="text-[var(--ink)]">{manifest.total}</b>개 · 생성 도구별로 시각 확인 ·{" "}
          <span className="text-rose-300">확인 필요</span> 태그 = 도구 귀속 미검증
        </p>
      </header>

      {/* 요약 칩 */}
      <section className="mb-5 flex flex-wrap gap-2">
        {Object.entries(manifest.byTool).map(([t, n]) => (
          <span key={t} className={`rounded-full border px-3 py-1 text-xs ${toolClass(t)}`}>
            {t} · {n}
          </span>
        ))}
      </section>

      {/* 필터 */}
      <section className="mb-6 flex flex-wrap items-center gap-2">
        <FilterBtn active={cat === "all"} onClick={() => setCat("all")}>
          전체 {manifest.total}
        </FilterBtn>
        {manifest.categories.map((c) => (
          <FilterBtn key={c} active={cat === c} onClick={() => setCat(c)}>
            {CAT_LABEL[c] || c} {manifest.byCategory[c] || 0}
          </FilterBtn>
        ))}
        <span className="mx-1 h-5 w-px bg-[var(--edge)]" />
        <FilterBtn active={tool === "all"} onClick={() => setTool("all")}>
          모든 도구
        </FilterBtn>
        {tools.map((t) => (
          <FilterBtn key={t} active={tool === t} onClick={() => setTool(t)}>
            {t}
          </FilterBtn>
        ))}
        <div className="relative ml-auto">
          <Search className="pointer-events-none absolute left-2.5 top-1/2 size-4 -translate-y-1/2 text-[var(--muted)]" />
          <input
            value={q}
            onChange={(e) => setQ(e.target.value)}
            placeholder="이름 검색"
            className="w-48 rounded-md border border-[var(--edge)] bg-[var(--panel)] py-1.5 pl-8 pr-3 text-sm outline-none focus:border-[var(--amber)]"
          />
        </div>
      </section>

      {/* 그리드 */}
      <section className="grid grid-cols-2 gap-3 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5 xl:grid-cols-6">
        {items.map((it) => (
          <Card key={`${it.category}/${it.name}`} it={it} />
        ))}
      </section>
      {items.length === 0 && (
        <p className="mt-10 text-center text-sm text-[var(--muted)]">조건에 맞는 에셋이 없습니다.</p>
      )}
    </main>
  );
}

function FilterBtn({
  active,
  onClick,
  children,
}: {
  active: boolean;
  onClick: () => void;
  children: React.ReactNode;
}) {
  return (
    <button
      onClick={onClick}
      className={`rounded-md border px-3 py-1.5 text-xs transition ${
        active
          ? "border-[var(--amber)] bg-[var(--amber)]/15 text-[var(--amber)]"
          : "border-[var(--edge)] bg-[var(--panel)] text-[var(--muted)] hover:text-[var(--ink)]"
      }`}
    >
      {children}
    </button>
  );
}

function Card({ it }: { it: AssetItem }) {
  const BOX = 132;
  const s = previewScale(it.w, it.h, BOX);
  return (
    <div className="group flex flex-col overflow-hidden rounded-lg border border-[var(--edge)] bg-[var(--panel)]">
      <div
        className="relative flex items-center justify-center overflow-hidden border-b border-[var(--edge)] bg-[repeating-conic-gradient(#242019_0%_25%,#1b1815_0%_50%)] bg-[length:16px_16px]"
        style={{ height: BOX }}
      >
        {/* eslint-disable-next-line @next/next/no-img-element */}
        <img
          src={`${BASE}/${it.file}`}
          alt={it.name}
          width={it.w * s}
          height={it.h * s}
          className="pixelated"
          loading="lazy"
        />
        {it.conf === "low" && (
          <span className="absolute right-1.5 top-1.5 rounded bg-rose-500/80 px-1.5 py-0.5 text-[10px] font-semibold text-white">
            확인 필요
          </span>
        )}
      </div>
      <div className="flex flex-1 flex-col gap-1.5 p-2.5">
        <div className="flex items-center justify-between gap-2">
          <span className="truncate text-sm font-medium" title={it.name}>
            {it.name}
          </span>
          <span className="shrink-0 text-[10px] text-[var(--muted)]">
            {it.w}×{it.h}
          </span>
        </div>
        <div className="flex items-center gap-1.5">
          <span className={`rounded border px-1.5 py-0.5 text-[10px] ${toolClass(it.tool)}`}>{it.tool}</span>
          <span className="text-[10px] text-[var(--muted)]">{CAT_LABEL[it.category] || it.category}</span>
        </div>
        <p className="line-clamp-2 flex items-start gap-1 text-[11px] leading-snug text-[var(--muted)]">
          <Info className="mt-px size-3 shrink-0" />
          <span>{it.method}</span>
        </p>
      </div>
    </div>
  );
}
