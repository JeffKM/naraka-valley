import type { NextConfig } from "next";

// 정적 export(GitHub Pages 배포용). basePath는 프로젝트 페이지 배포 시 env로 주입.
// 예) NEXT_PUBLIC_BASE_PATH=/naraka-valley npm run build
const basePath = process.env.NEXT_PUBLIC_BASE_PATH || "";

const nextConfig: NextConfig = {
  output: "export",
  basePath,
  images: { unoptimized: true },
  // 픽셀 아트 원본을 그대로 서빙(최적화 비활성 — 위 unoptimized).
};

export default nextConfig;
