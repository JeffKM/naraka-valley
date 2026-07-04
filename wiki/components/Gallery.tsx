"use client";

import { useEffect, useMemo, useState } from "react";
import { Search, Info, Pencil, Maximize2 } from "lucide-react";
import type { AssetItem, Manifest, Decision, DecisionMap } from "@/lib/types";
import { assetId } from "@/lib/types";
import Legend from "@/components/Legend";
import DecisionModal from "@/components/DecisionModal";
import ImageLightbox from "@/components/ImageLightbox";

const BASE = process.env.NEXT_PUBLIC_BASE_PATH || "";

const CAT_LABEL: Record<string, string> = {
  buildings: "건물 facade",
  characters: "캐릭터",
  portraits: "초상화",
  crops: "작물",
  livestock: "가축",
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
const toolClass = (t: string) => TOOL_STYLE[t] || "bg-neutral-500/15 text-neutral-300 border-neutral-500/30";

const ACTION_STYLE: Record<string, { label: string; cls: string }> = {
  ok: { label: "OK", cls: "bg-emerald-500/80 text-white" },
  regen: { label: "재생성", cls: "bg-amber-500/90 text-black" },
  check: { label: "확인중", cls: "bg-sky-500/80 text-white" },
  delete: { label: "삭제 대기", cls: "bg-rose-600/90 text-white" },
};

// ISO 커밋일 → 사람이 읽는 날짜(YYYY-MM-DD). null이면 "날짜 없음".
function fmtDate(iso: string | null) {
  return iso ? iso.slice(0, 10) : "날짜 없음";
}

function previewScale(w: number, h: number, box: number) {
  const m = Math.max(w, h) || 1;
  return Math.max(1, Math.min(8, Math.floor(box / m)));
}

export default function Gallery({ manifest }: { manifest: Manifest }) {
  const [cat, setCat] = useState("all");
  const [tool, setTool] = useState("all");
  const [work, setWork] = useState("all"); // all | decided | regen | ok | check | delete
  const [sort, setSort] = useState<"name" | "recent">("name"); // 알파벳 | 최근순(createdAt desc)
  const [q, setQ] = useState("");
  const [decisions, setDecisions] = useState<DecisionMap>({});
  const [editing, setEditing] = useState<AssetItem | null>(null);
  const [viewing, setViewing] = useState<AssetItem | null>(null); // 전체 이미지 라이트박스

  useEffect(() => {
    fetch(`${BASE}/api/decisions`)
      .then((r) => (r.ok ? r.json() : {}))
      .then((d) => setDecisions(d || {}))
      .catch(() => setDecisions({}));
  }, []);

  const tools = Object.keys(manifest.byTool);
  const items = useMemo(() => {
    const filtered = manifest.items.filter((it) => {
      const d = decisions[assetId(it)];
      if (cat !== "all" && it.category !== cat) return false;
      if (tool !== "all" && (d?.tool || it.tool) !== tool) return false;
      if (work === "decided" && !d) return false;
      if (
        (work === "regen" || work === "ok" || work === "check" || work === "delete") &&
        d?.action !== work
      )
        return false;
      if (q && !it.name.toLowerCase().includes(q.toLowerCase())) return false;
      return true;
    });
    if (sort === "recent") {
      // createdAt 내림차순(최근 먼저), null은 맨 뒤
      return [...filtered].sort((a, b) => {
        if (a.createdAt === b.createdAt) return a.name.localeCompare(b.name);
        if (!a.createdAt) return 1;
        if (!b.createdAt) return -1;
        return b.createdAt.localeCompare(a.createdAt);
      });
    }
    return filtered; // 매니페스트는 이미 알파벳 정렬
  }, [manifest.items, decisions, cat, tool, work, sort, q]);

  const decidedCount = Object.keys(decisions).length;
  const regenCount = Object.values(decisions).filter((d) => d.action === "regen").length;
  const deleteCount = Object.values(decisions).filter((d) => d.action === "delete").length;

  function onSaved(id: string, d: Decision | null) {
    setDecisions((prev) => {
      const next = { ...prev };
      if (d === null) delete next[id];
      else next[id] = { ...d, updatedAt: new Date().toISOString() };
      return next;
    });
    setEditing(null);
  }

  return (
    <main className="mx-auto max-w-[1400px] px-5 py-8">
      <header className="mb-4">
        <h1 className="text-2xl font-bold tracking-tight">
          나라카 밸리 위키 <span className="text-[var(--amber)]">— 에셋 갤러리</span>
        </h1>
        <p className="mt-1 text-sm text-[var(--muted)]">
          렌더 에셋 <b className="text-[var(--ink)]">{manifest.total}</b>개 · 카드 클릭 → 작업 지시 저장 ·{" "}
          결정 <b className="text-[var(--ink)]">{decidedCount}</b> · 재생성 요청{" "}
          <b className="text-amber-300">{regenCount}</b> · 삭제 대기{" "}
          <b className="text-rose-300">{deleteCount}</b>
        </p>
      </header>

      <Legend />

      <section className="mb-5 flex flex-wrap gap-2">
        {Object.entries(manifest.byTool).map(([t, n]) => (
          <span key={t} className={`rounded-full border px-3 py-1 text-xs ${toolClass(t)}`}>
            {t} · {n}
          </span>
        ))}
      </section>

      <section className="mb-3 flex flex-wrap items-center gap-2">
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
            className="w-44 rounded-md border border-[var(--edge)] bg-[var(--panel)] py-1.5 pl-8 pr-3 text-sm outline-none focus:border-[var(--amber)]"
          />
        </div>
      </section>

      {/* 작업 상태 필터 */}
      <section className="mb-6 flex flex-wrap items-center gap-2">
        <span className="text-xs text-[var(--muted)]">작업:</span>
        <FilterBtn active={work === "all"} onClick={() => setWork("all")}>모두</FilterBtn>
        <FilterBtn active={work === "decided"} onClick={() => setWork("decided")}>결정됨 {decidedCount}</FilterBtn>
        <FilterBtn active={work === "regen"} onClick={() => setWork("regen")}>재생성 {regenCount}</FilterBtn>
        <FilterBtn active={work === "ok"} onClick={() => setWork("ok")}>OK</FilterBtn>
        <FilterBtn active={work === "check"} onClick={() => setWork("check")}>확인중</FilterBtn>
        <FilterBtn active={work === "delete"} onClick={() => setWork("delete")}>삭제 대기 {deleteCount}</FilterBtn>
        <span className="mx-1 h-5 w-px bg-[var(--edge)]" />
        <span className="text-xs text-[var(--muted)]">정렬:</span>
        <FilterBtn active={sort === "name"} onClick={() => setSort("name")}>이름순</FilterBtn>
        <FilterBtn active={sort === "recent"} onClick={() => setSort("recent")}>최근순</FilterBtn>
      </section>

      <section className="grid grid-cols-2 gap-3 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5 xl:grid-cols-6">
        {items.map((it) => (
          <Card
            key={assetId(it)}
            it={it}
            decision={decisions[assetId(it)]}
            onClick={() => setEditing(it)}
            onView={() => setViewing(it)}
          />
        ))}
      </section>
      {items.length === 0 && (
        <p className="mt-10 text-center text-sm text-[var(--muted)]">조건에 맞는 에셋이 없습니다.</p>
      )}

      {editing && (
        <DecisionModal
          item={editing}
          decision={decisions[assetId(editing)] || {}}
          onSaved={onSaved}
          onClose={() => setEditing(null)}
        />
      )}

      {viewing && <ImageLightbox item={viewing} onClose={() => setViewing(null)} />}
    </main>
  );
}

function FilterBtn({ active, onClick, children }: { active: boolean; onClick: () => void; children: React.ReactNode }) {
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

function Card({
  it,
  decision,
  onClick,
  onView,
}: {
  it: AssetItem;
  decision?: Decision;
  onClick: () => void;
  onView: () => void;
}) {
  const BOX = 132;
  const s = previewScale(it.w, it.h, BOX);
  const effTool = decision?.tool || it.tool;
  const corrected = !!decision?.tool && decision.tool !== it.tool;
  const act = decision?.action ? ACTION_STYLE[decision.action] : null;
  const isDelete = decision?.action === "delete"; // 삭제 표시 → 빨강 테두리로 뚜렷하게
  return (
    <button
      onClick={onClick}
      className={`group flex flex-col overflow-hidden rounded-lg border bg-[var(--panel)] text-left transition ${
        isDelete
          ? "border-rose-500 ring-1 ring-rose-500/40 hover:border-rose-400"
          : "border-[var(--edge)] hover:border-[var(--amber)]/60"
      }`}
    >
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
        {act && (
          <span className={`absolute left-1.5 top-1.5 rounded px-1.5 py-0.5 text-[10px] font-bold ${act.cls}`}>
            {act.label}
          </span>
        )}
        {it.conf === "low" && !decision?.tool && (
          <span className="absolute right-1.5 top-1.5 rounded bg-rose-500/80 px-1.5 py-0.5 text-[10px] font-semibold text-white">
            확인 필요
          </span>
        )}
        {/* 전체 이미지 보기 — 카드 클릭(지시)과 분리해 이미지만 크게 연다 */}
        <span
          role="button"
          tabIndex={0}
          aria-label={`${it.name} 전체 이미지 보기`}
          onClick={(e) => {
            e.stopPropagation();
            onView();
          }}
          onKeyDown={(e) => {
            if (e.key === "Enter" || e.key === " ") {
              e.preventDefault();
              e.stopPropagation();
              onView();
            }
          }}
          className="absolute bottom-1.5 left-1.5 flex cursor-pointer items-center gap-1 rounded bg-black/60 px-1.5 py-0.5 text-[10px] text-white opacity-0 transition hover:bg-black/80 group-hover:opacity-100"
        >
          <Maximize2 className="size-3" /> 전체
        </span>
        <span className="absolute bottom-1.5 right-1.5 flex items-center gap-1 rounded bg-black/60 px-1.5 py-0.5 text-[10px] text-white opacity-0 transition group-hover:opacity-100">
          <Pencil className="size-3" /> 지시
        </span>
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
          <span className={`rounded border px-1.5 py-0.5 text-[10px] ${toolClass(effTool)}`}>
            {effTool}
            {corrected && " ✎"}
          </span>
          <span className="text-[10px] text-[var(--muted)]">{CAT_LABEL[it.category] || it.category}</span>
          {/* git 최초 커밋일(최근/예전 분류 축) */}
          <span
            className={`ml-auto text-[10px] ${it.createdAt ? "text-[var(--muted)]" : "text-rose-400/70"}`}
            title="git 최초 커밋일(생성 시각)"
          >
            {fmtDate(it.createdAt)}
          </span>
        </div>
        <p className="line-clamp-2 flex items-start gap-1 text-[11px] leading-snug text-[var(--muted)]">
          <Info className="mt-px size-3 shrink-0" />
          <span>{decision?.note || it.method}</span>
        </p>
      </div>
    </button>
  );
}
