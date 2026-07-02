export interface AssetItem {
  category: string;
  name: string;
  file: string; // "assets/<cat>/<name>.png"
  w: number;
  h: number;
  tool: string; // Gemini | PixelLab | 절차생성 | 확인 필요
  method: string;
  conf: "high" | "med" | "low";
  note?: string;
}

export interface Manifest {
  generatedNote: string;
  total: number;
  byCategory: Record<string, number>;
  byTool: Record<string, number>;
  categories: string[];
  items: AssetItem[];
}

// ── 목표 에셋 로스터(required-assets → roster.json 디프) — ADR-0048 §6 ──────────
export type RosterStatus = "have" | "placeholder" | "missing";
export type Maker = "claude" | "gemini";

export interface RosterItem {
  category: string; // 로스터 카테고리 id
  categoryTitle: string;
  key: string; // 표시 키(중괄호/슬래시 표기 가능)
  keys: string[]; // 매칭할 실제 파일 스템(씬 화면은 빈 배열)
  name: string; // 나라카명/화면명
  maker: Maker;
  expected: RosterStatus; // SOURCE 초안값
  status: RosterStatus; // 스캔 디프로 계산된 실제 상태
  note: string;
  preview: { file: string; w: number; h: number } | null;
}

export interface RosterCategory {
  id: string;
  title: string;
  note: string;
  items: RosterItem[];
}

export interface Roster {
  generatedNote: string;
  total: number;
  byStatus: Record<RosterStatus, number>;
  byMaker: Record<Maker, number>;
  categories: RosterCategory[];
  items: RosterItem[];
}

export const ROSTER_STATUS_META: Record<RosterStatus, { label: string; icon: string; cls: string }> = {
  have: { label: "있음", icon: "✅", cls: "bg-emerald-500/15 text-emerald-300 border-emerald-500/30" },
  placeholder: { label: "placeholder", icon: "🟡", cls: "bg-amber-500/15 text-amber-300 border-amber-500/30" },
  missing: { label: "없음", icon: "❌", cls: "bg-rose-500/15 text-rose-300 border-rose-500/30" },
};

export const MAKER_META: Record<Maker, { label: string; cls: string }> = {
  claude: { label: "Claude", cls: "bg-violet-500/15 text-violet-300 border-violet-500/30" },
  gemini: { label: "Gemini", cls: "bg-sky-500/15 text-sky-300 border-sky-500/30" },
};

// 에셋 결정(웹에서 owner가 선택 → data/asset-decisions.json → 어시스턴트가 읽어 작업)
export type DecisionAction = "" | "ok" | "regen" | "check";

export interface Decision {
  tool?: string; // 실제 도구 정정(확인필요/오귀속 교정)
  action?: DecisionAction; // 그대로 OK / 재생성 / 확인중
  targetTool?: string; // 재생성 시 사용할 도구
  note?: string; // 지시·메모
  updatedAt?: string;
}

export type DecisionMap = Record<string, Decision>;

export const TOOLS = ["Gemini", "PixelLab", "절차생성", "확인 필요"] as const;
export const GEN_TOOLS = ["Gemini", "PixelLab", "절차생성"] as const;

export function assetId(it: { category: string; name: string }) {
  return `${it.category}/${it.name}`;
}
