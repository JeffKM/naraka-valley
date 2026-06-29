#!/usr/bin/env python3
"""대소문자 파일명 충돌 그룹을 전수 확인 — '진짜 콘텐츠 손실'이 있는지 확정한다.

각 충돌 그룹의 모든 멤버를 fetch해 redirect/real/404로 분류.
- 그룹에 REAL이 1개뿐 → 안전(그게 디스크에 있고, 나머지는 리다이렉트).
- 그룹에 REAL이 2개 이상 → 손실 위험(한 파일명에 하나만 남음) → 손실분 저장(.rescued).
"""
import os
import re
import subprocess
import time
import urllib.parse
import collections

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DIR = os.path.join(ROOT, "docs/reference/stardew-wiki")
LIST = os.path.join(ROOT, "tools/stardew-wiki-all-titles.txt")
BASE = "https://stardewvalleywiki.com"
UA = ("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 "
      "(KHTML, like Gecko) Chrome/124.0 Safari/537.36")
REDIR_RE = re.compile(rb"^\s*#REDIRECT", re.IGNORECASE)
HTML_RE = re.compile(rb"<!DOCTYPE|<html|404 Not Found", re.IGNORECASE)


def enc(t):    return urllib.parse.quote(t.replace(" ", "_"), safe="/")
def fname(t):  return urllib.parse.quote(t.replace(" ", "_"), safe="") + ".wikitext"


def fetch(t):
    r = subprocess.run(["curl", "-sS", "-A", UA, "--max-time", "30",
                        f"{BASE}/{enc(t)}?action=raw"], capture_output=True, timeout=45)
    return r.stdout


def classify(body):
    if len(body) <= 5:                 return "EMPTY"
    if REDIR_RE.match(body):           return "REDIRECT"
    if HTML_RE.search(body[:400]):     return "404"
    return "REAL"


def main():
    titles = [t.strip() for t in open(LIST) if t.strip()]
    groups = collections.defaultdict(list)
    for t in titles:
        groups[fname(t).lower()].append(t)
    collisions = {k: sorted(v) for k, v in groups.items() if len(v) > 1}
    print(f"충돌 그룹 {len(collisions)}개 전수 확인...")
    loss = 0
    for key, members in sorted(collisions.items()):
        reals = []
        for m in members:
            cls = classify(fetch(m))
            if cls == "REAL":
                reals.append(m)
            time.sleep(0.2)
        if len(reals) > 1:
            loss += 1
            # 디스크에 남은 건 정렬 첫 REAL. 나머지 REAL은 손실 → 구조.
            on_disk = reals[0]
            for lost in reals[1:]:
                body = fetch(lost)
                fn = fname(lost)[:-len(".wikitext")] + ".rescued.wikitext"
                with open(os.path.join(DIR, fn), "wb") as fh:
                    fh.write(body)
                print(f"  ⚠️ 손실! {members} → REAL 다수 {reals}. "
                      f"디스크={on_disk}, 구조={lost}→{fn}")
        else:
            print(f"  ✓ 안전 {members} (REAL {len(reals)}: {reals or '없음(전부 리다이렉트)'})")
    print(f"\n=== 결과: 충돌 {len(collisions)}그룹 중 진짜 손실 {loss}그룹 ===")


if __name__ == "__main__":
    main()
