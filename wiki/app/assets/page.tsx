import RosterView from "@/components/Roster";
import type { Roster } from "@/lib/types";
import rosterJson from "@/lib/roster.json";

// roster.json은 prebuild(scripts/build-manifest.mjs)가 required-assets.json과
// game/assets/** 스캔을 디프해 생성한다.
const roster = rosterJson as Roster;

export default function AssetsPage() {
  return <RosterView roster={roster} />;
}
