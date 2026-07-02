import type { NextConfig } from "next";

// 로컬(dev/기본 build) = API 라우트 동작(에셋 결정 편집·저장).
// 배포용 정적 export는 NEXT_EXPORT=1 일 때만(GitHub Pages). export 모드에선 편집 API 비활성(뷰 전용).
const isExport = process.env.NEXT_EXPORT === "1";
const basePath = process.env.NEXT_PUBLIC_BASE_PATH || "";

const nextConfig: NextConfig = {
  ...(isExport ? { output: "export" as const } : {}),
  basePath,
  images: { unoptimized: true },
};

export default nextConfig;
