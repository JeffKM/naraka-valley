"use client";

import { useState } from "react";
import { HelpCircle, ChevronDown } from "lucide-react";

const TOOLS = [
  { name: "Gemini", cls: "text-sky-300", desc: "제미나이 AI 이미지 — 초상화·건물 정면 facade·「태운 한지」 대화창 등 크고 디테일한 일러스트성 에셋" },
  { name: "PixelLab", cls: "text-emerald-300", desc: "PixelLab AI 픽셀아트 — 캐릭터/짐승 walk·타일(터레인·절벽)·프롭·가구·작물 등 인게임 도트" },
  { name: "절차생성", cls: "text-violet-300", desc: "코드로 만든 것(AI 아님) — 그레이박스 색 채우기, 지면 디테일 오버레이(잔돌·풀결 합성), 청키화·팔레트 양자화 글루" },
  { name: "확인 필요", cls: "text-rose-300", desc: "어떤 도구로 만들었는지 미검증 — 실제 룩 보고 도구를 정정해 주세요(진짜 카테고리 아님)" },
];

const ACTIONS = [
  { name: "OK(잘됨)", desc: "이대로 유지" },
  { name: "재생성", desc: "다시 만들기 — 지정한 도구로(어시스턴트가 작업)" },
  { name: "확인중", desc: "보류·검토중" },
];

export default function Legend() {
  const [open, setOpen] = useState(true);
  return (
    <div className="mb-5 rounded-lg border border-[var(--edge)] bg-[var(--panel)]">
      <button
        onClick={() => setOpen((o) => !o)}
        className="flex w-full items-center gap-2 px-4 py-2.5 text-sm font-medium"
      >
        <HelpCircle className="size-4 text-[var(--amber)]" />
        용어 · 사용법
        <ChevronDown className={`ml-auto size-4 transition ${open ? "rotate-180" : ""}`} />
      </button>
      {open && (
        <div className="grid grid-cols-1 gap-4 border-t border-[var(--edge)] px-4 py-3 md:grid-cols-2">
          <div>
            <p className="mb-1.5 text-[11px] font-semibold text-[var(--muted)]">생성 도구 태그</p>
            <ul className="space-y-1.5">
              {TOOLS.map((t) => (
                <li key={t.name} className="text-[11px] leading-snug text-[var(--muted)]">
                  <b className={t.cls}>{t.name}</b> — {t.desc}
                </li>
              ))}
            </ul>
          </div>
          <div>
            <p className="mb-1.5 text-[11px] font-semibold text-[var(--muted)]">
              작업 지시 (카드 클릭 → 결정 저장)
            </p>
            <ul className="space-y-1.5">
              {ACTIONS.map((a) => (
                <li key={a.name} className="text-[11px] leading-snug text-[var(--muted)]">
                  <b className="text-[var(--ink)]">{a.name}</b> — {a.desc}
                </li>
              ))}
            </ul>
            <p className="mt-2 text-[11px] leading-snug text-[var(--amber)]">
              카드를 클릭해 [작업 지시·실제 도구 정정·메모]를 정하면 저장돼요. 채팅 없이 여기서 지시하면
              어시스턴트가 읽고 작업합니다. (로컬 <code>npm run dev</code>에서 편집)
            </p>
          </div>
        </div>
      )}
    </div>
  );
}
