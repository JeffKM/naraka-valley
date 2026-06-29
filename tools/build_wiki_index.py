#!/usr/bin/env python3
"""미러된 원문의 [[Category:...]] 태그로 전수 분류 색인(INDEX.md)을 만든다.

- 입력: docs/reference/stardew-wiki/*.wikitext  (mirror_wiki.py 결과)
- 출력: docs/reference/stardew-wiki/INDEX.md      (gitignore — 레퍼런스 항해 지도)
- 카테고리별 멤버 + 도메인 롤업 + 시스템/메카닉 페이지 하이라이트.

⚠️ 라이선스: 페이지 *제목·분류*만 담는 색인(원문 본문 아님). 그래도 레퍼런스 디렉터리(gitignore)
   안에 둬 일관되게 로컬 전용으로 유지한다. 게임/기획 문서엔 원문 복붙 금지(licensing-checklist).
"""
import os
import re
import urllib.parse
from collections import defaultdict

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DIR = os.path.join(ROOT, "docs/reference/stardew-wiki")
OUT = os.path.join(DIR, "INDEX.md")

CAT_RE = re.compile(r"\[\[Category:([^\]|]+)")

# 그릴 대상 = 시스템/메카닉 페이지(개별 콘텐츠 아님). 존재하면 색인 최상단에 도메인별로 모은다.
SYSTEM_PAGES = {
    "시간·환경·절기": ["Seasons", "Weather", "Luck", "Day Cycle", "Time", "Calendar"],
    "농사": ["Crops", "Farming", "Fertilizer", "Sprinklers", "Fruit_Trees", "Greenhouse",
             "Seed_Maker", "Crop_Quality", "Trellis"],
    "동물·목축": ["Animals", "Coop", "Barn", "Hay", "Silo"],
    "채집": ["Foraging"],
    "낚시": ["Fishing", "Fish_Pond", "Crab_Pot", "Fishing_Rod", "Bait", "Tackle"],
    "채광·전투": ["Mining", "Combat", "The_Mines", "Skull_Cavern", "Quarry", "Geodes",
                 "Monsters", "Weapons", "Slingshots"],
    "관계·사회": ["Friendship", "Marriage", "Children", "Gifts", "NPCs", "Schedules",
                 "Pets", "Divorce"],
    "상점·경제": ["Shipping", "The_Cave", "Shops", "Traveling_Cart", "Money", "Casino"],
    "제작·가공": ["Crafting", "Artisan_Goods", "Cooking", "Recipes", "Furniture", "Machines"],
    "진행·목표·스킬": ["Skills", "Quests", "Bundles", "Community_Center", "Joja",
                     "Achievements", "Secrets", "Perfection", "Mastery"],
    "플레이어·자원·장비": ["Energy", "Health", "Tools", "Inventory", "Rings", "Boots",
                        "Trinkets", "Clothing", "Horse"],
    "공간·건물": ["Buildings", "Farmhouse", "Cabin", "Farm_Maps", "Ginger_Island"],
    "기타·엔드게임": ["Festivals", "Mail", "Television", "Secret_Notes", "Movie_Theater",
                    "Multiplayer", "Special_Orders"],
}


def title_of(path):
    return urllib.parse.unquote(os.path.basename(path)[:-len(".wikitext")])


def main():
    files = [f for f in os.listdir(DIR) if f.endswith(".wikitext")]
    cat_to_pages = defaultdict(set)
    page_cats = {}
    titles = set()
    for fn in files:
        path = os.path.join(DIR, fn)
        title = title_of(path)
        titles.add(title)
        with open(path, encoding="utf-8", errors="replace") as fh:
            text = fh.read()
        cats = [c.strip() for c in CAT_RE.findall(text)]
        page_cats[title] = cats
        if not cats:
            cat_to_pages["(분류 없음)"].add(title)
        for c in cats:
            cat_to_pages[c].add(title)

    lines = []
    lines.append("# 스타듀밸리 위키 — 전수 분류 색인 (INDEX)\n")
    lines.append("> ⚠️ **로컬 전용 (gitignore).** 위키 원문 미러 위를 항해하는 지도다. "
                 "페이지 제목·분류만 담는다(원문 본문은 각 `.wikitext`). CC BY-NC-SA — 커밋 금지.\n")
    lines.append(f"> 총 **{len(titles)}** 페이지 / **{len([c for c in cat_to_pages if c != '(분류 없음)'])}** 카테고리. "
                 "`tools/build_wiki_index.py`로 재생성.\n")
    lines.append("\n---\n")

    # 1) 시스템/메카닉 페이지(그릴 대상) — 도메인별, 존재하는 것만.
    lines.append("\n## 1. 시스템·메카닉 페이지 (그릴 대상)\n")
    lines.append("> 개별 콘텐츠가 아니라 *메카닉*을 다루는 페이지. 이것들을 하나씩 그릴한다.\n")
    for domain, pages in SYSTEM_PAGES.items():
        present = [p for p in pages if p.replace("_", " ") in titles or p in titles]
        missing = [p for p in pages if p not in present]
        lines.append(f"\n### {domain}\n")
        for p in present:
            lines.append(f"- [x] `{p}`")
        for p in missing:
            lines.append(f"- [ ] `{p}` *(해당 제목 페이지 없음 — 별칭/포함 확인 필요)*")

    # 2) 전체 카테고리 — 멤버 수순.
    lines.append("\n\n---\n\n## 2. 전체 카테고리 (콘텐츠 범주)\n")
    lines.append("> 개별 콘텐츠는 범주 단위로 검토한다(ADR-0001 자체 창작). 각 범주의 멤버는 미러 원문 참조.\n")
    for cat in sorted(cat_to_pages, key=lambda c: (-len(cat_to_pages[c]), c)):
        members = sorted(cat_to_pages[cat])
        lines.append(f"\n### {cat} ({len(members)})\n")
        lines.append(", ".join(members))

    with open(OUT, "w", encoding="utf-8") as fh:
        fh.write("\n".join(lines) + "\n")
    print(f"INDEX.md 생성: {len(titles)} 페이지 / {len(cat_to_pages)} 카테고리 → {OUT}")


if __name__ == "__main__":
    main()
