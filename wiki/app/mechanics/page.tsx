import { COMMON, REGIONS, STATUS_META, type Mechanic, type Status } from "@/lib/mechanics";
import { MapPin, Layers } from "lucide-react";

function tally() {
  const all: Mechanic[] = [...COMMON.mechanics, ...REGIONS.flatMap((r) => r.mechanics)];
  const t: Record<Status, number> = { done: 0, greybox: 0, partial: 0, planned: 0 };
  for (const m of all) t[m.status]++;
  return { total: all.length, t };
}

function Badge({ status }: { status: Status }) {
  const meta = STATUS_META[status];
  return <span className={`shrink-0 rounded border px-1.5 py-0.5 text-[10px] ${meta.cls}`}>{meta.label}</span>;
}

function Row({ m }: { m: Mechanic }) {
  return (
    <li className="flex items-start gap-2 border-b border-[var(--edge)]/60 py-2 last:border-0">
      <Badge status={m.status} />
      <div className="min-w-0 flex-1">
        <div className="flex items-baseline gap-2">
          <span className="text-sm font-medium">{m.name}</span>
          {m.ref && <span className="truncate text-[10px] text-[var(--muted)]">{m.ref}</span>}
        </div>
        {m.note && <p className="mt-0.5 text-[11px] leading-snug text-[var(--muted)]">{m.note}</p>}
      </div>
    </li>
  );
}

export default function MechanicsPage() {
  const { total, t } = tally();
  return (
    <main className="mx-auto max-w-[1400px] px-5 py-8">
      <header className="mb-5">
        <h1 className="text-2xl font-bold tracking-tight">
          나라카 밸리 위키 <span className="text-[var(--amber)]">— 메카닉 현황</span>
        </h1>
        <p className="mt-1 text-sm text-[var(--muted)]">
          지역별 + 공통/횡단 시스템 구현 상태 · 총 <b className="text-[var(--ink)]">{total}</b>개 항목
        </p>
      </header>

      {/* 상태 요약 */}
      <section className="mb-6 flex flex-wrap gap-2">
        {(Object.keys(STATUS_META) as Status[]).map((s) => (
          <span key={s} className={`rounded-full border px-3 py-1 text-xs ${STATUS_META[s].cls}`}>
            {STATUS_META[s].label} · {t[s]}
          </span>
        ))}
      </section>

      <div className="grid grid-cols-1 gap-4 lg:grid-cols-2">
        {/* 공통/횡단 */}
        <section className="rounded-lg border border-[var(--edge)] bg-[var(--panel)] p-4 lg:col-span-2">
          <div className="mb-1 flex items-center gap-2">
            <Layers className="size-4 text-[var(--amber)]" />
            <h2 className="font-semibold">{COMMON.title}</h2>
          </div>
          <p className="mb-2 text-[11px] text-[var(--muted)]">{COMMON.note}</p>
          <ul className="grid grid-cols-1 gap-x-6 md:grid-cols-2">
            {COMMON.mechanics.map((m) => (
              <Row key={m.name} m={m} />
            ))}
          </ul>
        </section>

        {/* 지역별 */}
        {REGIONS.map((r) => (
          <section key={r.id} className="rounded-lg border border-[var(--edge)] bg-[var(--panel)] p-4">
            <div className="mb-1 flex items-center gap-2">
              <MapPin className="size-4 text-[var(--amber)]" />
              <h2 className="font-semibold">{r.name}</h2>
            </div>
            <p className="mb-2 text-[11px] text-[var(--muted)]">{r.stage}</p>
            <ul>
              {r.mechanics.map((m) => (
                <Row key={m.name} m={m} />
              ))}
            </ul>
          </section>
        ))}
      </div>
    </main>
  );
}
