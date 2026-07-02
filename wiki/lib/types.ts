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
