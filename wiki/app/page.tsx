import Gallery from "@/components/Gallery";
import type { Manifest } from "@/lib/types";
import manifestJson from "@/lib/manifest.json";

// manifest.json은 prebuild(scripts/build-manifest.mjs)가 생성한다.
const manifest = manifestJson as Manifest;

export default function Page() {
  return <Gallery manifest={manifest} />;
}
