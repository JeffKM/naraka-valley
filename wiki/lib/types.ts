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
