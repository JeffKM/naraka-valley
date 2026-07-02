"use client";

import { useMemo, useState } from "react";
import { Package, Info } from "lucide-react";
import {
  type Roster,
  type RosterItem,
  type RosterStatus,
  type Maker,
  ROSTER_STATUS_META,
  MAKER_META,
} from "@/lib/types";

const BASE = process.env.NEXT_PUBLIC_BASE_PATH || "";

type StatusFilter = "all" | "remaining" | RosterStatus;
type MakerFilter = "all" | Maker;

function previewScale(w: number, h: number, box: number) {
  const m = Math.max(w, h) || 1;
  return Math.max(1, Math.min(8, Math.floor(box / m)));
}

export default function RosterView({ roster }: { roster: Roster }) {
  const [status, setStatus] = useState<StatusFilter>("all");
  const [maker, setMaker] = useState<MakerFilter>("all");

  const remaining = roster.byStatus.missing + roster.byStatus.placeholder;

  const cats = useMemo(() => {
    return roster.categories
      .map((cat) => ({
        ...cat,
        items: cat.items.filter((r) => {
          if (status === "remaining" && r.status === "have") return false;
          if (status !== "all" && status !== "remaining" && r.status !== status) return false;
          if (maker !== "all" && r.maker !== maker) return false;
          return true;
        }),
      }))
      .filter((cat) => cat.items.length > 0);
  }, [roster.categories, status, maker]);

  const shown = cats.reduce((n, c) => n + c.items.length, 0);

  return (
    <main className="mx-auto max-w-[1400px] px-5 py-8">
      <header className="mb-4">
        <h1 className="text-2xl font-bold tracking-tight">
          나라카 밸리 위키 <span className="text-[var(--amber)]">— 데모 필요 에셋</span>
        </h1>
        <p className="mt-1 text-sm text-[var(--muted)]">
          안식 농원 데모 목표 로스터 <b className="text-[var(--ink)]">{roster.total}</b>개 · 실제 파일과 디프 ·{" "}
          있음 <b className="text-emerald-300">{roster.byStatus.have}</b> · placeholder{" "}
          <b className="text-amber-300">{roster.byStatus.placeholder}</b> · 없음{" "}
          <b className="text-rose-300">{roster.byStatus.missing}</b> · 남은 작업{" "}
          <b className="text-[var(--amber)]">{remaining}</b>
        </p>
        <p className="mt-1 text-[11px] text-[var(--muted)]">
          목표=required-assets.json · 상태=game/assets/** 스캔 자동 디프(ADR-0048 §6). 규격은 스펙카드가 진실.
        </p>
      </header>

      {/* 상태 요약 배지 */}
      <section className="mb-4 flex flex-wrap gap-2">
        {(Object.keys(ROSTER_STATUS_META) as RosterStatus[]).map((s) => (
          <span key={s} className={`rounded-full border px-3 py-1 text-xs ${ROSTER_STATUS_META[s].cls}`}>
            {ROSTER_STATUS_META[s].icon} {ROSTER_STATUS_META[s].label} · {roster.byStatus[s]}
          </span>
        ))}
      </section>

      {/* 필터 */}
      <section className="mb-6 flex flex-wrap items-center gap-2">
        <span className="text-xs text-[var(--muted)]">상태:</span>
        <FilterBtn active={status === "all"} onClick={() => setStatus("all")}>
          전체 {roster.total}
        </FilterBtn>
        <FilterBtn active={status === "remaining"} onClick={() => setStatus("remaining")}>
          남은 작업 {remaining}
        </FilterBtn>
        {(Object.keys(ROSTER_STATUS_META) as RosterStatus[]).map((s) => (
          <FilterBtn key={s} active={status === s} onClick={() => setStatus(s)}>
            {ROSTER_STATUS_META[s].icon} {ROSTER_STATUS_META[s].label} {roster.byStatus[s]}
          </FilterBtn>
        ))}
        <span className="mx-1 h-5 w-px bg-[var(--edge)]" />
        <span className="text-xs text-[var(--muted)]">제작:</span>
        <FilterBtn active={maker === "all"} onClick={() => setMaker("all")}>
          모두
        </FilterBtn>
        {(Object.keys(MAKER_META) as Maker[]).map((m) => (
          <FilterBtn key={m} active={maker === m} onClick={() => setMaker(m)}>
            {MAKER_META[m].label} {roster.byMaker[m]}
          </FilterBtn>
        ))}
        <span className="ml-auto text-xs text-[var(--muted)]">{shown}개 표시</span>
      </section>

      <div className="flex flex-col gap-6">
        {cats.map((cat) => (
          <section key={cat.id}>
            <div className="mb-2 flex items-baseline gap-2">
              <Package className="size-4 shrink-0 translate-y-0.5 text-[var(--amber)]" />
              <h2 className="font-semibold">{cat.title}</h2>
              <span className="text-[11px] text-[var(--muted)]">{cat.items.length}</span>
            </div>
            {cat.note && <p className="mb-2 text-[11px] leading-snug text-[var(--muted)]">{cat.note}</p>}
            <div className="grid grid-cols-2 gap-3 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5 xl:grid-cols-6">
              {cat.items.map((r) => (
                <Card key={`${r.category}/${r.key}`} r={r} />
              ))}
            </div>
          </section>
        ))}
      </div>
      {shown === 0 && <p className="mt-10 text-center text-sm text-[var(--muted)]">조건에 맞는 항목이 없습니다.</p>}
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

function Card({ r }: { r: RosterItem }) {
  const BOX = 110;
  const sm = ROSTER_STATUS_META[r.status];
  const mm = MAKER_META[r.maker];
  const s = r.preview ? previewScale(r.preview.w, r.preview.h, BOX) : 1;
  return (
    <div className="flex flex-col overflow-hidden rounded-lg border border-[var(--edge)] bg-[var(--panel)]">
      <div
        className="relative flex items-center justify-center overflow-hidden border-b border-[var(--edge)] bg-[repeating-conic-gradient(#242019_0%_25%,#1b1815_0%_50%)] bg-[length:16px_16px]"
        style={{ height: BOX }}
      >
        {r.preview ? (
          // eslint-disable-next-line @next/next/no-img-element
          <img
            src={`${BASE}/${r.preview.file}`}
            alt={r.key}
            width={r.preview.w * s}
            height={r.preview.h * s}
            className="pixelated"
            loading="lazy"
          />
        ) : (
          <span className="text-3xl opacity-50">{sm.icon}</span>
        )}
        <span className={`absolute left-1.5 top-1.5 rounded border px-1.5 py-0.5 text-[10px] font-semibold ${sm.cls}`}>
          {sm.icon} {sm.label}
        </span>
      </div>
      <div className="flex flex-1 flex-col gap-1.5 p-2.5">
        <div className="flex items-center justify-between gap-2">
          <span className="truncate text-sm font-medium" title={r.name}>
            {r.name}
          </span>
          <span className={`shrink-0 rounded border px-1.5 py-0.5 text-[10px] ${mm.cls}`}>{mm.label}</span>
        </div>
        <code className="truncate text-[10px] text-[var(--muted)]" title={r.key}>
          {r.key}
        </code>
        {r.note && (
          <p className="line-clamp-2 flex items-start gap-1 text-[11px] leading-snug text-[var(--muted)]">
            <Info className="mt-px size-3 shrink-0" />
            <span>{r.note}</span>
          </p>
        )}
      </div>
    </div>
  );
}
