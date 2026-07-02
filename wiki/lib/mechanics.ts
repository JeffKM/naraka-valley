// 나라카 밸리 — 메카닉 구현 현황(수기 큐레이션, ROADMAP 근거).
// 데일리 갱신: 이 파일을 직접 수정. status = done(구현완료) / greybox(그레이박스·placeholder 아트) /
// partial(부분·토대) / planned(계획).
export type Status = "done" | "greybox" | "partial" | "planned";

export interface Mechanic {
  name: string;
  status: Status;
  note?: string;
  ref?: string; // ROADMAP/ADR/파일 힌트
}

export interface RegionMechanics {
  id: string;
  name: string;
  stage: string; // 구역 성숙도 한 줄
  mechanics: Mechanic[];
}

export const COMMON: { title: string; note: string; mechanics: Mechanic[] } = {
  title: "공통 · 횡단 시스템",
  note: "특정 지역에 묶이지 않고 게임 전반에 걸치는 시스템.",
  mechanics: [
    { name: "세이브 · 복원", status: "done", note: "구역·실내·플레이어·농사/목축/개간/꾸미기 델타 전부 직렬화" },
    { name: "구역 워프 · 월드 루프", status: "done", note: "8구역 워프 그래프(나락 제외 라이브)·카메라 격리 seam", ref: "region.gd" },
    { name: "인벤토리", status: "done", note: "{id,count,quality} 스택키·worst-first 소비·16슬롯", ref: "inventory.gd" },
    { name: "아이템 카탈로그", status: "done", note: "작물·산물·과일·도구·비료·재료 + 품질 4등급·판매가 배수", ref: "item_catalog.gd" },
    { name: "핫바 HUD · 품질 배지", status: "done", note: "16슬롯·에너지·품질 배지·하트바" },
    { name: "에너지(혼력)", status: "done", note: "행동 예산·숙련 감산(파라미터화)", ref: "energy.gd" },
    { name: "대화 시스템", status: "done", note: "4캐릭터×6표정 초상화 · 「태운 한지」 대화창", ref: "dialogue.gd" },
    { name: "클록 · 저승 절기", status: "partial", note: "피안절~성야절·28일·절기 유도 표면(season_index) 선도입. 사멸/날씨/축제=Slice7", ref: "clock.gd · ADR-0045" },
    { name: "명부의 운 · 저승 날씨", status: "planned", note: "일일 운 등급·날씨 예보(저승판 TV) — Slice 7" },
    { name: "관계 · 호감도 · 결혼 · 해방", status: "planned", note: "메인 4인 서사 척추 — Slice 8" },
    { name: "전투 · 체력", status: "planned", note: "던전 전투 자원(별도 HP) — Phase 3" },
  ],
};

export const REGIONS: RegionMechanics[] = [
  {
    id: "home",
    name: "안식 농원",
    stage: "홈베이스 · 데모 1 · 실size(80×65) · 메카닉 그레이박스 대부분 완료",
    mechanics: [
      { name: "농사 밭(작물 5아키타입)", status: "done", note: "심기·물주기·성장·수확·트렐리스·다절기 프레스티지", ref: "field.gd · crop.gd" },
      { name: "품질 4등급 + 비료 5종 + 성장촉진 + 농사 숙련", status: "done", note: "숙련 0~10·혼력 감산", ref: "S1-6 · fertilizer_catalog.gd · skill.gd" },
      { name: "혼의 나무 과수(혼백도)", status: "done", note: "28일 성숙·제철 결실·나이=품질·3×3 영속", ref: "S1-5b · orchard.gd" },
      { name: "목축(Ranch · 노을닭 · 안개소)", status: "greybox", note: "돌봄 우정/기분·산물 품질/대형·비살상. 진입 실내·pathing·티어=Track B", ref: "S1-7 · livestock.gd" },
      { name: "개간(overgrown 개간)", status: "done", note: "debris 3종·낫/곡괭이/도끼·스타터 패치", ref: "S1-8 · reclaim.gd" },
      { name: "집 꾸미기(3레이어 코스메틱)", status: "greybox", note: "테마세트 무한배치. 세트 아트=S1-11", ref: "S1-9 · home_deco.gd" },
      { name: "pseudo-Z 다단 절벽 · 하늘 목장 고지 · 계단", status: "done", note: "메카닉+아트(흙 절벽·연못 강둑·동향 계단)", ref: "S1-2/3/10" },
      { name: "본가 · 창고 진입 실내", status: "greybox", note: "enterable 빈 방(저장·기능 미구현)" },
      { name: "출하대(shipping bin)", status: "greybox", note: "판매·정산 그레이박스" },
    ],
  },
  {
    id: "naru_village",
    name: "나루 마을",
    stage: "허브 · 구역 그레이박스(카페·만물상·주민집 진입 빈 방)",
    mechanics: [
      { name: "카페 외관 · 실내 진입", status: "greybox", note: "enterable 빈 방" },
      { name: "만물상 진입", status: "greybox", note: "enterable 빈 방" },
      { name: "주민 집 facade", status: "greybox" },
      { name: "상점(씨앗 · 도구 구매)", status: "planned", note: "Slice 2" },
      { name: "카페 운영 · 서빙 · 융합 메뉴 · 곳간", status: "planned", note: "Slice 6" },
      { name: "목공방(건물 업그레이드처)", status: "planned", note: "Track B 큰/디럭스 티어 게이트 · Slice 2" },
    ],
  },
  {
    id: "samdocheon",
    name: "삼도천",
    stage: "구역 그레이박스(강·다리·혼백관)",
    mechanics: [
      { name: "혼백관(박물관) 진입", status: "greybox", note: "enterable 빈 방 · 유품 전시=서사" },
      { name: "강 낚시(망자의 혼 · 도깨비 물고기)", status: "planned", note: "Slice 3" },
      { name: "혼 연못(양식)", status: "planned", note: "Track B B3 · Slice 3 연계" },
    ],
  },
  {
    id: "hwangcheonhae",
    name: "황천해",
    stage: "구역 그레이박스(바다·부두·생선가게)",
    mechanics: [
      { name: "생선가게 진입", status: "greybox", note: "enterable 빈 방" },
      { name: "바다 낚시", status: "planned", note: "Slice 3" },
    ],
  },
  {
    id: "jeoseung_forest",
    name: "저승 숲",
    stage: "구역 그레이박스",
    mechanics: [
      { name: "채집(forage)", status: "planned", note: "Slice 4" },
      { name: "목공방", status: "planned", note: "Slice 2" },
    ],
  },
  {
    id: "mihok_forest",
    name: "미혹의 숲",
    stage: "구역 그레이박스(깊은 숲·연못)",
    mechanics: [
      { name: "특수 채집(불사과 · 다절기)", status: "planned", note: "Slice 4" },
      { name: "옥자 집", status: "planned", note: "서사" },
    ],
  },
  {
    id: "eophwa_mine",
    name: "업화 갱도",
    stage: "구역 그레이박스",
    mechanics: [
      { name: "채광 · 지오드 · 사다리", status: "planned", note: "Slice 5" },
      { name: "전투 던전 · 대장간 · 길드", status: "planned", note: "Slice 5 · Phase 3" },
    ],
  },
  {
    id: "narak",
    name: "나락",
    stage: "독립 전투 던전(진입로 잠금)",
    mechanics: [{ name: "나락 전투 던전", status: "planned", note: "Phase 3 · 진입로 빌드 시 점등" }],
  },
];

export const STATUS_META: Record<Status, { label: string; cls: string }> = {
  done: { label: "구현완료", cls: "bg-emerald-500/15 text-emerald-300 border-emerald-500/30" },
  greybox: { label: "그레이박스", cls: "bg-amber-500/15 text-amber-300 border-amber-500/30" },
  partial: { label: "부분", cls: "bg-sky-500/15 text-sky-300 border-sky-500/30" },
  planned: { label: "계획", cls: "bg-neutral-500/15 text-neutral-400 border-neutral-500/30" },
};
