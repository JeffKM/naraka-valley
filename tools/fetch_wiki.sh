#!/usr/bin/env bash
# 스타듀밸리 위키 페이지를 원본 위키텍스트로 받아오는 글루 스크립트.
#
# - MediaWiki '?action=raw' 사용 → 렌더 HTML이 아니라 순수 위키텍스트(노이즈 0).
# - 403 회피용 브라우저 User-Agent.
# - 페이지마다 1초 예의 딜레이(위키 서버 부담·차단 회피).
# - 저장: docs/reference/stardew-wiki/<제목>.wikitext  (gitignore — CC BY-NC-SA 비상업, 커밋 금지)
#
# 사용법:
#   bash tools/fetch_wiki.sh                       # tools/stardew-wiki-pages.txt 목록 전체
#   bash tools/fetch_wiki.sh Crops Fishing Mining  # 인자로 받은 페이지만
#
# ⚠️ 라이선스: 받은 텍스트는 *설계 그릴링 참고용*이다. 게임/기획 문서에 원문을 그대로
#    복붙하지 말 것(licensing-checklist.md). 저장 디렉터리는 .gitignore로 제외돼 있다.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT_DIR="$ROOT/docs/reference/stardew-wiki"
LIST_FILE="$ROOT/tools/stardew-wiki-pages.txt"
BASE="https://stardewvalleywiki.com"
UA="Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36"

mkdir -p "$OUT_DIR"

# 받을 페이지 목록 결정: 인자가 있으면 인자, 없으면 목록 파일(주석·빈 줄 제외).
if [ "$#" -gt 0 ]; then
  PAGES=("$@")
else
  PAGES=()
  while IFS= read -r line; do
    line="${line%%#*}"                       # 인라인 주석 제거
    line="$(echo "$line" | tr -d '[:space:]')"  # 공백 제거
    [ -n "$line" ] && PAGES+=("$line")
  done < "$LIST_FILE"
fi

echo "받을 페이지: ${#PAGES[@]}개 → $OUT_DIR"
ok=0; fail=0
for title in "${PAGES[@]}"; do
  out="$OUT_DIR/${title}.wikitext"
  code=$(curl -sS -A "$UA" --max-time 30 \
    "$BASE/${title}?action=raw" -o "$out" -w "%{http_code}" || echo "000")
  size=$(wc -c < "$out" 2>/dev/null | tr -d ' ')
  if [ "$code" = "200" ] && [ "${size:-0}" -gt 200 ]; then
    printf "  ✓ %-22s %s bytes\n" "$title" "$size"; ok=$((ok+1))
  else
    printf "  ✗ %-22s HTTP %s (%s bytes)\n" "$title" "$code" "${size:-0}"
    rm -f "$out"; fail=$((fail+1))
  fi
  sleep 1
done
echo "완료: 성공 $ok / 실패 $fail"