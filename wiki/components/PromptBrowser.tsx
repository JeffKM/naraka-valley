"use client";

import { useMemo, useState } from "react";
import { Search, Copy, Check } from "lucide-react";
import { GEMINI_PROMPTS, PROMPT_CATEGORIES, type GeminiPrompt } from "@/lib/gemini-prompts";

const CAT_STYLE: Record<string, string> = {
  characters: "bg-amber-500/15 text-amber-300 border-amber-500/30",
  crops: "bg-lime-500/15 text-lime-300 border-lime-500/30",
  tiles: "bg-sky-500/15 text-sky-300 border-sky-500/30",
  props: "bg-emerald-500/15 text-emerald-300 border-emerald-500/30",
  buildings: "bg-orange-500/15 text-orange-300 border-orange-500/30",
  ui: "bg-violet-500/15 text-violet-300 border-violet-500/30",
};

async function copyText(text: string): Promise<boolean> {
  try {
    if (navigator.clipboard?.writeText) {
      await navigator.clipboard.writeText(text);
      return true;
    }
  } catch {
    /* fallthrough */
  }
  try {
    const ta = document.createElement("textarea");
    ta.value = text;
    ta.style.position = "fixed";
    ta.style.opacity = "0";
    document.body.appendChild(ta);
    ta.select();
    const ok = document.execCommand("copy");
    document.body.removeChild(ta);
    return ok;
  } catch {
    return false;
  }
}

export default function PromptBrowser() {
  const [cat, setCat] = useState<string>("all");
  const [q, setQ] = useState("");
  const [copied, setCopied] = useState<string | null>(null);

  const counts = useMemo(() => {
    const c: Record<string, number> = {};
    for (const p of GEMINI_PROMPTS) c[p.category] = (c[p.category] || 0) + 1;
    return c;
  }, []);

  const items = useMemo(() => {
    const needle = q.trim().toLowerCase();
    return GEMINI_PROMPTS.filter((p) => {
      if (cat !== "all" && p.category !== cat) return false;
      if (needle && !(`${p.id} ${p.label}`.toLowerCase().includes(needle))) return false;
      return true;
    });
  }, [cat, q]);

  async function onCopy(p: GeminiPrompt) {
    const ok = await copyText(p.prompt);
    if (ok) {
      setCopied(p.id);
      setTimeout(() => setCopied((cur) => (cur === p.id ? null : cur)), 1500);
    }
  }

  return (
    <main className="mx-auto max-w-[1100px] px-5 py-8">
      <header className="mb-4">
        <h1 className="text-2xl font-bold tracking-tight">
          나라카 밸리 위키 <span className="text-[var(--amber)]">— Gemini 프롬프트</span>
        </h1>
        <p className="mt-1 text-sm text-[var(--muted)]">
          전 에셋 재생성용 완성 프롬프트 <b className="text-[var(--ink)]">{GEMINI_PROMPTS.length}</b>개 ·
          각 카드의 <b className="text-[var(--ink)]">복사</b> 버튼 → Gemini에 붙여넣기 → 생성.
          스타일 토큰까지 포함된 완성본이라 그대로 씁니다. (스펙: ADR-0047 · docs/design/gemini-regen-batch.md)
        </p>
      </header>

      <section className="mb-5 flex flex-wrap items-center gap-2">
        <FilterBtn active={cat === "all"} onClick={() => setCat("all")}>
          전체 {GEMINI_PROMPTS.length}
        </FilterBtn>
        {PROMPT_CATEGORIES.map((c) => (
          <FilterBtn key={c.key} active={cat === c.key} onClick={() => setCat(c.key)}>
            {c.label} {counts[c.key] || 0}
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

      <section className="flex flex-col gap-3">
        {items.map((p) => (
          <article
            key={p.id}
            className="rounded-lg border border-[var(--edge)] bg-[var(--panel)] p-3.5"
          >
            <div className="mb-2 flex items-start justify-between gap-3">
              <div className="min-w-0">
                <div className="flex flex-wrap items-center gap-2">
                  <span className="font-semibold">{p.label}</span>
                  <span className={`rounded border px-1.5 py-0.5 text-[10px] ${CAT_STYLE[p.category] || ""}`}>
                    {PROMPT_CATEGORIES.find((c) => c.key === p.category)?.label}
                  </span>
                  <code className="text-[11px] text-[var(--muted)]">{p.id}</code>
                  <span className="text-[11px] text-[var(--muted)]">· {p.size}</span>
                </div>
                {p.note && <p className="mt-1 text-[12px] text-[var(--muted)]">{p.note}</p>}
              </div>
              <button
                onClick={() => onCopy(p)}
                className={`flex shrink-0 items-center gap-1.5 rounded-md border px-3 py-1.5 text-sm transition ${
                  copied === p.id
                    ? "border-emerald-500/50 bg-emerald-500/15 text-emerald-300"
                    : "border-[var(--amber)]/50 bg-[var(--amber)]/10 text-[var(--amber)] hover:bg-[var(--amber)]/20"
                }`}
                aria-label={`${p.label} 프롬프트 복사`}
              >
                {copied === p.id ? <Check className="size-4" /> : <Copy className="size-4" />}
                {copied === p.id ? "복사됨" : "복사"}
              </button>
            </div>
            <pre className="max-h-40 overflow-auto whitespace-pre-wrap break-words rounded-md border border-[var(--edge)] bg-[var(--bg)] p-2.5 text-[12px] leading-relaxed text-[var(--ink)]/90">
              {p.prompt}
            </pre>
          </article>
        ))}
      </section>
      {items.length === 0 && (
        <p className="mt-10 text-center text-sm text-[var(--muted)]">조건에 맞는 프롬프트가 없습니다.</p>
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
