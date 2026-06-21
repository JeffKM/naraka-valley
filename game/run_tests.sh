#!/bin/bash
# 플레이테스트 러너 — 헤드리스 Godot 단위검증(playtest/*_test.gd)을 워치독과 함께 돌린다.
#
# 왜 있나: 각 *_test.gd는 끝에서 quit()으로 스스로 닫지만, 백그라운드로 띄우거나
# 같은 테스트를 동시에 여럿 띄우면 Godot 헤드리스가 종료 신호를 못 받고 좀비로 남는 일이
# 있었다(예: lighting_test가 ~10분, heart_bar_test 3중 중복). 이 러너는 각 테스트를
# 순차로 돌리고, TIMEOUT 초를 넘기면 강제 종료(FAIL)해서 절대 좀비가 안 남게 한다.
#
# 사용:
#   ./run_tests.sh                    # playtest/의 모든 *_test.gd 순차 실행
#   ./run_tests.sh heart_bar lighting # 지정 테스트만 (접미사 _test.gd 자동 보정)
#   TIMEOUT=90 ./run_tests.sh weave   # 워치독 시간 조정 (기본 60초)
#
# 종료코드: 모두 통과면 0, 하나라도 실패/타임아웃이면 1.
set -uo pipefail
cd "$(dirname "$0")" || exit 1

GODOT="${GODOT:-godot}"
TIMEOUT="${TIMEOUT:-60}"
PLAYTEST_DIR="playtest"

# 인자가 없으면 모든 *_test.gd, 있으면 그 이름들(경로·.gd·_test 접미사 모두 허용)
names=()
if [ "$#" -eq 0 ]; then
  for f in "$PLAYTEST_DIR"/*_test.gd; do
    names+=("$(basename "$f" .gd)")
  done
else
  for arg in "$@"; do
    base="$(basename "$arg" .gd)"
    case "$base" in
      *_test) names+=("$base") ;;
      *)      names+=("${base}_test") ;;
    esac
  done
fi

run_one() {
  local name="$1"
  local script="res://$PLAYTEST_DIR/${name}.gd"
  if [ ! -f "$PLAYTEST_DIR/${name}.gd" ]; then
    echo "✗ $name: 스크립트 없음 ($PLAYTEST_DIR/${name}.gd)"
    return 2
  fi

  echo "▶ $name  (워치독 ${TIMEOUT}s)"
  "$GODOT" --headless --path "$PWD" --script "$script" &
  local pid=$!

  # 워치독: TIMEOUT 후에도 살아 있으면 강제 종료
  ( sleep "$TIMEOUT"; kill -9 "$pid" 2>/dev/null \
      && echo "  ⏱ [WATCHDOG] ${TIMEOUT}s 초과 → 강제 종료(FAIL)" ) &
  local wd=$!

  wait "$pid"; local ec=$?
  kill "$wd" 2>/dev/null; wait "$wd" 2>/dev/null
  return "$ec"
}

fail=0
declare -a failed=()
for name in "${names[@]}"; do
  if ! run_one "$name"; then
    fail=1
    failed+=("$name")
  fi
  echo
done

# 안전망: 혹시라도 남은 playtest 헤드리스 프로세스를 청소(이 러너 종료 후 좀비 0 보장)
pkill -9 -f "godot --headless.*$PLAYTEST_DIR/" 2>/dev/null

if [ "$fail" -eq 0 ]; then
  echo "══ 전체 통과 (${#names[@]}개) ══"
else
  echo "══ 실패: ${failed[*]} ══"
fi
exit "$fail"
