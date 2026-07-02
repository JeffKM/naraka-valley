"use client";

import { useEffect, useState } from "react";
import { X, Save, Trash2 } from "lucide-react";
import type { AssetItem, Decision, DecisionAction } from "@/lib/types";
import { TOOLS, GEN_TOOLS, assetId } from "@/lib/types";

const BASE = process.env.NEXT_PUBLIC_BASE_PATH || "";

const ACTIONS: { v: DecisionAction; label: string; hint: string }[] = [
  { v: "", label: "미정", hint: "결정 안 함" },
  { v: "ok", label: "OK(잘됨)", hint: "이대로 유지" },
  { v: "regen", label: "재생성", hint: "다시 만들기 — 아래 도구로" },
  { v: "check", label: "확인중", hint: "보류·검토중" },
];

export default function DecisionModal({
  item,
  decision,
  onSaved,
  onClose,
}: {
  item: AssetItem;
  decision: Decision;
  onSaved: (id: string, d: Decision | null) => void;
  onClose: () => void;
}) {
  const id = assetId(item);
  const [tool, setTool] = useState(decision.tool || "");
  const [action, setAction] = useState<DecisionAction>(decision.action || "");
  const [targetTool, setTargetTool] = useState(decision.targetTool || "");
  const [note, setNote] = useState(decision.note || "");
  const [busy, setBusy] = useState(false);

  useEffect(() => {
    const onKey = (e: KeyboardEvent) => e.key === "Escape" && onClose();
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [onClose]);

  async function post(decisionOrNull: Decision | null) {
    setBusy(true);
    try {
      const res = await fetch(`${BASE}/api/decisions`, {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({ id, decision: decisionOrNull }),
      });
      if (!res.ok) throw new Error("save failed");
      onSaved(id, decisionOrNull);
    } catch {
      alert("저장 실패 — 로컬 dev(npm run dev)에서만 편집·저장됩니다. 정적 배포본은 뷰 전용입니다.");
    } finally {
      setBusy(false);
    }
  }

  const save = () =>
    post({
      tool: tool || undefined,
      action: action || undefined,
      targetTool: action === "regen" ? targetTool || undefined : undefined,
      note: note.trim() || undefined,
    });

  const scale = Math.max(1, Math.min(10, Math.floor(320 / (Math.max(item.w, item.h) || 1))));

  return (
    <div
      className="fixed inset-0 z-50 flex items-center justify-center bg-black/70 p-4"
      onClick={onClose}
    >
      <div
        className="w-full max-w-lg overflow-hidden rounded-xl border border-[var(--edge)] bg-[var(--panel)]"
        onClick={(e) => e.stopPropagation()}
      >
        <div className="flex items-center justify-between border-b border-[var(--edge)] px-4 py-3">
          <div>
            <h3 className="font-semibold">{item.name}</h3>
            <p className="text-[11px] text-[var(--muted)]">
              {item.category} · {item.w}×{item.h} · 현재 태그: {item.tool}
            </p>
          </div>
          <button onClick={onClose} className="text-[var(--muted)] hover:text-[var(--ink)]">
            <X className="size-5" />
          </button>
        </div>

        <div className="flex gap-4 p-4">
          {/* 프리뷰 */}
          <div className="flex h-40 w-40 shrink-0 items-center justify-center overflow-hidden rounded-lg border border-[var(--edge)] bg-[repeating-conic-gradient(#242019_0%_25%,#1b1815_0%_50%)] bg-[length:16px_16px]">
            {/* eslint-disable-next-line @next/next/no-img-element */}
            <img
              src={`${BASE}/${item.file}`}
              alt={item.name}
              width={item.w * scale}
              height={item.h * scale}
              className="pixelated"
            />
          </div>

          {/* 편집 */}
          <div className="flex flex-1 flex-col gap-3">
            <Field label="작업 지시">
              <select
                value={action}
                onChange={(e) => setAction(e.target.value as DecisionAction)}
                className="w-full rounded-md border border-[var(--edge)] bg-[var(--bg)] px-2 py-1.5 text-sm outline-none focus:border-[var(--amber)]"
              >
                {ACTIONS.map((a) => (
                  <option key={a.v} value={a.v}>
                    {a.label} — {a.hint}
                  </option>
                ))}
              </select>
            </Field>

            {action === "regen" && (
              <Field label="이 도구로 생성">
                <select
                  value={targetTool}
                  onChange={(e) => setTargetTool(e.target.value)}
                  className="w-full rounded-md border border-[var(--edge)] bg-[var(--bg)] px-2 py-1.5 text-sm outline-none focus:border-[var(--amber)]"
                >
                  <option value="">선택…</option>
                  {GEN_TOOLS.map((t) => (
                    <option key={t} value={t}>
                      {t}
                    </option>
                  ))}
                </select>
              </Field>
            )}

            <Field label="실제 도구 정정(선택)">
              <select
                value={tool}
                onChange={(e) => setTool(e.target.value)}
                className="w-full rounded-md border border-[var(--edge)] bg-[var(--bg)] px-2 py-1.5 text-sm outline-none focus:border-[var(--amber)]"
              >
                <option value="">그대로({item.tool})</option>
                {TOOLS.map((t) => (
                  <option key={t} value={t}>
                    {t}
                  </option>
                ))}
              </select>
            </Field>

            <Field label="지시 · 메모">
              <textarea
                value={note}
                onChange={(e) => setNote(e.target.value)}
                rows={3}
                placeholder="예: 카페 정면 다시, 배경 투명하게 / 하트 아이콘 더 굵게"
                className="w-full resize-none rounded-md border border-[var(--edge)] bg-[var(--bg)] px-2 py-1.5 text-sm outline-none focus:border-[var(--amber)]"
              />
            </Field>
          </div>
        </div>

        <div className="flex items-center justify-between border-t border-[var(--edge)] px-4 py-3">
          <button
            onClick={() => post(null)}
            disabled={busy}
            className="flex items-center gap-1.5 rounded-md border border-[var(--edge)] px-3 py-1.5 text-xs text-[var(--muted)] hover:text-rose-300 disabled:opacity-50"
          >
            <Trash2 className="size-3.5" /> 결정 삭제
          </button>
          <button
            onClick={save}
            disabled={busy}
            className="flex items-center gap-1.5 rounded-md bg-[var(--amber)] px-4 py-1.5 text-xs font-semibold text-black hover:brightness-110 disabled:opacity-50"
          >
            <Save className="size-3.5" /> 저장
          </button>
        </div>
      </div>
    </div>
  );
}

function Field({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <label className="flex flex-col gap-1">
      <span className="text-[11px] font-medium text-[var(--muted)]">{label}</span>
      {children}
    </label>
  );
}
