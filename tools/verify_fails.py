#!/usr/bin/env python3
"""미러 로그의 FAIL 711개를 전부 재확인해 '진짜 콘텐츠 누락'이 있는지 확정한다.

분류:
- REDIRECT: 본문이 #REDIRECT [[...]] → 별칭, 본문 없음(정상 스킵).
- REAL: 리다이렉트 아닌 실제 위키텍스트 → 200B 임계로 잘못 버려졌을 수 있음 → 저장(건져냄).
- EMPTY: 빈/오류 응답.

REAL은 docs/reference/stardew-wiki/ 에 저장(대소문자 충돌 회피용 파일명 접미사).
결과 요약을 stdout + _verify.log에 남긴다.
"""
import os
import re
import subprocess
import time
import urllib.parse

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DIR = os.path.join(ROOT, "docs/reference/stardew-wiki")
LOG = os.path.join(DIR, "_mirror.log")
VLOG = os.path.join(DIR, "_verify.log")
BASE = "https://stardewvalleywiki.com"
UA = ("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 "
      "(KHTML, like Gecko) Chrome/124.0 Safari/537.36")
REDIR_RE = re.compile(rb"^\s*#REDIRECT", re.IGNORECASE)
HTML_RE = re.compile(rb"<!DOCTYPE|<html|404 Not Found", re.IGNORECASE)
FAIL_RE = re.compile(r"✗ FAIL (.+?) \(\d+B\)")


def enc(title):
    # 슬래시(subpage 구분자)는 보존해야 한다 — %2F로 인코딩하면 404가 난다.
    return urllib.parse.quote(title.replace(" ", "_"), safe="/")


def fetch(title):
    r = subprocess.run(["curl", "-sS", "-A", UA, "--max-time", "30",
                        f"{BASE}/{enc(title)}?action=raw"],
                       capture_output=True, timeout=45)
    return r.stdout


def main():
    with open(LOG) as f:
        fails = sorted({m.group(1) for m in (FAIL_RE.search(l) for l in f) if m})
    out = open(VLOG, "w")

    def emit(s):
        print(s); out.write(s + "\n")

    emit(f"=== FAIL 재확인: {len(fails)}개 ===")
    redir = real = empty = notfound = 0
    real_titles = []
    for i, t in enumerate(fails, 1):
        body = fetch(t)
        if len(body) <= 5:
            empty += 1
            emit(f"  EMPTY  {t}")
        elif REDIR_RE.match(body):
            redir += 1
        elif HTML_RE.search(body[:400]):     # 404/에러 HTML → 본문 아님
            notfound += 1
            emit(f"  404/HTML {t}")
        else:
            real += 1
            real_titles.append(t)
            fn = enc(t).replace("/", "%2F") + ".real.wikitext"   # 파일명만 슬래시 회피
            with open(os.path.join(DIR, fn), "wb") as fh:
                fh.write(body)
            emit(f"  *** REAL({len(body)}B) {t} → {fn}")
        if i % 100 == 0:
            emit(f"  ...{i}/{len(fails)} (리다이렉트 {redir} / 실제 {real} / 404 {notfound} / 빈 {empty})")
        time.sleep(0.25)
    emit(f"\n=== 결과: 리다이렉트 {redir} / 실제콘텐츠 {real} / 404·HTML {notfound} / 빈응답 {empty} / 총 {len(fails)} ===")
    if real_titles:
        emit("진짜 누락이던 콘텐츠(건져냄):")
        for t in real_titles:
            emit(f"  - {t}")
    else:
        emit("→ 진짜 콘텐츠 누락 0건. 711개 전부 리다이렉트/빈응답(정상).")
    out.close()


if __name__ == "__main__":
    main()
