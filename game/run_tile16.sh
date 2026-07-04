#!/bin/bash
# 16px 베이스 룩 실험 하네스 러너 (headless + 워치독 — 좀비 방지, CLAUDE.md 규칙).
# 산출: tools/tile16_experiment.png (판정용) / _x1.png (픽셀 검수).
cd "$(dirname "$0")" || exit 1

GODOT="${GODOT:-godot}"
TIMEOUT="${TIMEOUT:-60}"
SCRIPT="res://tools/tile16_experiment.gd"

echo "▶ tile16_experiment  (워치독 ${TIMEOUT}s)"
"$GODOT" --headless --path "$PWD" --script "$SCRIPT" &
pid=$!
( sleep "$TIMEOUT"; kill -9 "$pid" 2>/dev/null \
    && echo "  ⏱ [WATCHDOG] ${TIMEOUT}s 초과 → 강제 종료" ) &
wd=$!
wait "$pid"; ec=$?
kill "$wd" 2>/dev/null; wait "$wd" 2>/dev/null

# 안전망: 잔존 헤드리스 청소(좀비 0 보장)
pkill -9 -f "godot --headless.*tile16_experiment" 2>/dev/null

[ "$ec" -eq 0 ] && echo "✅ 완료 → tools/tile16_experiment.png" || echo "✗ 실패(ec=$ec)"
exit "$ec"
