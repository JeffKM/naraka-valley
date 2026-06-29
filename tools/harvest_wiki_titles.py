#!/usr/bin/env python3
"""스타듀 위키 Special:AllPages를 따라가며 메인 네임스페이스 전체 제목을 수확한다.

- 콘텐츠(메인 ns) 페이지만: File:/Category:/Template:/Special: 등 네임스페이스·리다이렉트 제외.
- AllPages의 알파벳 청크를 'from=' 커서로 끝까지 순회(상한 60청크 안전장치).
- 출력: tools/stardew-wiki-all-titles.txt (디코드된 사람이 읽는 제목, 한 줄에 하나).
  이 색인은 '무엇이 있나' 파악·범위 결정용이며, 실제 본문은 fetch_wiki.sh가 받는다.
"""
import html
import re
import subprocess
import sys
import time
import urllib.parse

BASE = "https://stardewvalleywiki.com"
UA = ("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 "
      "(KHTML, like Gecko) Chrome/124.0 Safari/537.36")
OUT = "tools/stardew-wiki-all-titles.txt"

# 콘텐츠 페이지 href: 슬래시로 시작, 네임스페이스 콜론(%3A 포함) 없음, mediawiki/index.php/action 제외.
HREF_RE = re.compile(r'href="(/[^":?]+)"')
NEXT_RE = re.compile(r'Special:AllPages(?:&amp;|\?)from=([^"\'&]+)')


def fetch(url):
    # urllib은 Cloudflare에 403당해(UA 외 TLS 지문) 검증된 curl로 가져온다.
    out = subprocess.run(
        ["curl", "-sS", "-A", UA, "--max-time", "30", url],
        capture_output=True, timeout=40,
    )
    return out.stdout.decode("utf-8", "replace")


def is_content(path):
    if path.startswith("/mediawiki") or path.startswith("/index.php"):
        return False
    if "%3A" in path or ":" in path:           # 네임스페이스 페이지 제외
        return False
    if "action=" in path or "Special" in path:
        return False
    return True


def main():
    titles = set()
    cursor = ""
    seen_cursors = set()
    for i in range(60):                         # 안전 상한
        url = f"{BASE}/Special:AllPages"
        if cursor:
            url += "?from=" + urllib.parse.quote(cursor)
        page = fetch(url)
        # 이 청크의 콘텐츠 제목 수집
        for m in HREF_RE.finditer(page):
            path = m.group(1)
            if is_content(path):
                title = urllib.parse.unquote(path[1:])   # 앞 '/' 제거 + 디코드
                titles.add(title)
        # 다음 커서 = 이 페이지의 from= 토큰 중 현재보다 사전순 뒤인 최댓값
        # from= 값은 이미 쿼리 인코딩 상태 → 한 번 디코드해 둬야 다음 루프에서 이중 인코딩(%2520)을 막는다.
        froms = {urllib.parse.unquote_plus(html.unescape(x)) for x in NEXT_RE.findall(page)}
        nexts = sorted(f for f in froms if (not cursor) or f > cursor)
        print(f"  청크 {i+1}: 누적 {len(titles)}개 (from={cursor or 'START'})", file=sys.stderr)
        if not nexts or nexts[-1] in seen_cursors:
            break
        cursor = nexts[-1]
        seen_cursors.add(cursor)
        time.sleep(1)                           # 예의 딜레이

    ordered = sorted(titles)
    with open(OUT, "w") as f:
        f.write("\n".join(ordered) + "\n")
    print(f"\n총 {len(ordered)}개 제목 → {OUT}")


if __name__ == "__main__":
    main()
