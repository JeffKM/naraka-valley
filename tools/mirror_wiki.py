#!/usr/bin/env python3
"""tools/stardew-wiki-all-titles.txt의 전체 제목을 원본 위키텍스트로 미러링한다.

- 검증된 pretty URL '/<제목>?action=raw' + 브라우저 UA(curl). 공백→_, 나머지 %xx 인코딩.
- 이어받기: 이미 받은(>200B) 파일은 건너뜀 → 중단돼도 재실행하면 이어짐.
- 예의 딜레이 0.7초. 실패 1회 재시도.
- 저장: docs/reference/stardew-wiki/<인코딩제목>.wikitext (gitignore — CC BY-NC-SA, 커밋 금지)
- 진행 로그: docs/reference/stardew-wiki/_mirror.log

⚠️ 라이선스: 설계 그릴링 *참고 전용*. 게임/기획 문서에 원문 복붙 금지(licensing-checklist.md).
"""
import os
import subprocess
import time
import urllib.parse

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_DIR = os.path.join(ROOT, "docs/reference/stardew-wiki")
LIST = os.path.join(ROOT, "tools/stardew-wiki-all-titles.txt")
LOG = os.path.join(OUT_DIR, "_mirror.log")
BASE = "https://stardewvalleywiki.com"
UA = ("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 "
      "(KHTML, like Gecko) Chrome/124.0 Safari/537.36")


def enc(title):
    # URL: 슬래시(subpage 구분자)는 보존 — %2F로 인코딩하면 404.
    return urllib.parse.quote(title.replace(" ", "_"), safe="/")


def fname(title):
    # 파일명: 슬래시는 %2F로(하위 디렉터리 생성 방지).
    return urllib.parse.quote(title.replace(" ", "_"), safe="") + ".wikitext"


def fetch(title):
    url = f"{BASE}/{enc(title)}?action=raw"
    r = subprocess.run(["curl", "-sS", "-A", UA, "--max-time", "30", url],
                       capture_output=True, timeout=45)
    return r.stdout


def log(msg):
    with open(LOG, "a") as f:
        f.write(msg + "\n")


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    with open(LIST) as f:
        titles = [t.strip() for t in f if t.strip()]
    total = len(titles)
    log(f"=== 미러 시작: {total}개 ===")
    ok = skip = fail = 0
    for i, title in enumerate(titles, 1):
        out = os.path.join(OUT_DIR, fname(title))
        if os.path.exists(out) and os.path.getsize(out) > 200:
            skip += 1
            continue
        data = fetch(title)
        if len(data) <= 200:                    # 실패 의심 → 1회 재시도
            time.sleep(1.5)
            data = fetch(title)
        if len(data) > 200:
            with open(out, "wb") as fh:
                fh.write(data)
            ok += 1
        else:
            fail += 1
            log(f"  ✗ FAIL {title} ({len(data)}B)")
        if i % 50 == 0:
            log(f"  진행 {i}/{total} — 신규 {ok} / 건너뜀 {skip} / 실패 {fail}")
        time.sleep(0.7)
    log(f"=== 완료: 신규 {ok} / 건너뜀 {skip} / 실패 {fail} / 총 {total} ===")
    print(f"완료: 신규 {ok} / 건너뜀 {skip} / 실패 {fail} / 총 {total}")


if __name__ == "__main__":
    main()
