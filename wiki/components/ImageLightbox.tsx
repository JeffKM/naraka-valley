"use client";

import { useEffect, useState } from "react";
import { X } from "lucide-react";
import type { AssetItem } from "@/lib/types";

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

// 픽셀아트를 뷰포트에 맞춰 보여줄 배율을 고른다. 뷰포트보다 작으면 정수배 업스케일(선명한 픽셀),
// 뷰포트보다 크면(건물 등) 축소해 전체가 들어오게 한다. 업스케일 상한 16×(과확대 방지).
function fitScale(w: number, h: number, vw: number, vh: number): number {
  const maxW = vw * 0.9;
  const maxH = vh * 0.82;
  const fit = Math.min(maxW / w, maxH / h);
  if (fit >= 1) return Math.min(16, Math.floor(fit)); // 정수배 업스케일
  return fit; // 큰 에셋은 축소해 전체 표시
}

export default function ImageLightbox({ item, onClose }: { item: AssetItem; onClose: () => void }) {
  const [scale, setScale] = useState(1);

  useEffect(() => {
    const recalc = () => setScale(fitScale(item.w, item.h, window.innerWidth, window.innerHeight));
    recalc();
    const onKey = (e: KeyboardEvent) => e.key === "Escape" && onClose();
    window.addEventListener("keydown", onKey);
    window.addEventListener("resize", recalc);
    return () => {
      window.removeEventListener("keydown", onKey);
      window.removeEventListener("resize", recalc);
    };
  }, [item.w, item.h, onClose]);

  const dispW = Math.round(item.w * scale);
  const dispH = Math.round(item.h * scale);

  return (
    <div
      className="fixed inset-0 z-[60] flex flex-col items-center justify-center bg-black/85 p-4"
      onClick={onClose}
    >
      <button
        onClick={onClose}
        aria-label="닫기"
        className="absolute right-4 top-4 rounded-md border border-white/20 bg-black/40 p-1.5 text-white/80 transition hover:text-white"
      >
        <X className="size-5" />
      </button>

      {/* 전체 이미지 — 체커보드 배경 위에 픽셀 선명하게 */}
      <div
        className="flex max-h-[82vh] max-w-[90vw] items-center justify-center overflow-auto rounded-lg border border-[var(--edge)] bg-[repeating-conic-gradient(#242019_0%_25%,#1b1815_0%_50%)] bg-[length:16px_16px]"
        onClick={(e) => e.stopPropagation()}
      >
        {/* eslint-disable-next-line @next/next/no-img-element */}
        <img
          src={`${BASE}/${item.file}`}
          alt={item.name}
          width={dispW}
          height={dispH}
          className="pixelated block"
        />
      </div>

      {/* 캡션 */}
      <div
        className="mt-3 flex flex-col items-center gap-0.5 text-center"
        onClick={(e) => e.stopPropagation()}
      >
        <span className="text-sm font-semibold text-white">{item.name}</span>
        <span className="text-[11px] text-white/60">
          {CAT_LABEL[item.category] || item.category} · {item.w}×{item.h}px · {item.tool}
          {scale >= 1 ? ` · ${scale}× 확대` : " · 축소 맞춤"}
        </span>
        <span className="mt-0.5 break-all font-mono text-[10px] text-white/40">{item.file}</span>
      </div>
    </div>
  );
}
