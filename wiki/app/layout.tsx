import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "나라카 밸리 위키 — 구현 현황",
  description: "나라카 밸리 에셋·메카닉 구현 현황 시각 대시보드",
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="ko">
      <body>{children}</body>
    </html>
  );
}
