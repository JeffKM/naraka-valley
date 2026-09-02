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
#   TIMEOUT=90 ./run_tests.sh weave   # 워치독 시간 조정 (기본 120초)
#
# 종료코드: 모두 통과면 0, 하나라도 실패/타임아웃이면 1.
set -uo pipefail
cd "$(dirname "$0")" || exit 1

GODOT="${GODOT:-godot}"
# 기본 120초 — garden_pot_test가 구역 이동·재빌드 단언 확장으로 실측 ~63초에 이르러
# 60초 경계에서 flaky 오탐이 났다(2026-08-15 폴리시 루프 실측). 워치독 자체는 유지라
# 행/좀비는 여전히 120초에 강제 종료된다.
TIMEOUT="${TIMEOUT:-120}"
PLAYTEST_DIR="playtest"

# 스위트별 워치독 **하한** — 기본 120초로는 못 재는 소수 스위트만 여기서 올린다. 기본값을 통째로
# 올리면 나머지 40여 스위트의 회귀 감도까지 같이 무뎌지므로 예외 목록으로 둔다.
#   bana_test: main.tscn을 13번 세우고 그중 11번이 세이브 로드 경로다(부팅 1회 ≈ 8s) → 실측 119초.
#   2026-09-03 폴리시 R11에서 이 119초가 120초 워치독에 걸려 "㉗에서 결정적 hang"으로 오진됐다
#   (행이 아니라 누적 비용이었다 — 400초를 주면 전 단언이 통과한다). 같은 커밋에서 로드 경로의
#   중복 재빌드를 걷어 147초→119초로 줄였고, 남은 것은 스위트 구조상의 실비라 여유를 준다.
suite_timeout() {
  local floor=0
  case "$1" in
    bana_test) floor=240 ;;
  esac
  if [ "$floor" -gt "$TIMEOUT" ]; then echo "$floor"; else echo "$TIMEOUT"; fi
}

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

  local to
  to="$(suite_timeout "$name")"
  echo "▶ $name  (워치독 ${to}s)"
  # 출력을 로그로 받아 종료 후 되쏜다 — 스크립트 파싱/로드 실패 시 Godot이 종료코드 0으로 끝나
  # "통과"로 오탐되던 구멍(S2-T6에서 실증)을 에러 패턴 검사로 막기 위함.
  local log
  log="$(mktemp)"
  "$GODOT" --headless --path "$PWD" --script "$script" > "$log" 2>&1 &
  local pid=$!

  # 워치독: to초 후에도 살아 있으면 강제 종료
  ( sleep "$to"; kill -9 "$pid" 2>/dev/null \
      && echo "  ⏱ [WATCHDOG] ${to}s 초과 → 강제 종료(FAIL)" ) &
  local wd=$!

  wait "$pid"; local ec=$?
  # ★ `kill $wd`는 서브셸만 죽이고 그 **자식 `sleep`은 고아로 남는다.** 고아가 러너의 stdout을
  #   물고 있어, 출력을 파이프로 받으면(`./run_tests.sh x | tail`) 테스트가 끝난 뒤에도 파이프가
  #   to초를 다 채울 때까지 안 닫혔다 — 큰 TIMEOUT을 주고 재보면 실제 소요와 무관하게 늘 to초로
  #   읽혀, "이 스위트는 워치독까지 매달린다"는 오독을 낳는다(2026-09-03 R11에서 실제로 겪음).
  #   자식부터 걷고 서브셸을 죽인다.
  pkill -P "$wd" 2>/dev/null
  kill "$wd" 2>/dev/null; wait "$wd" 2>/dev/null
  cat "$log"
  if [ "$ec" -eq 0 ] && grep -qE "SCRIPT ERROR|Parse Error" "$log"; then
    echo "  ✗ $name: 스크립트 에러 감지(파싱/로드 실패가 종료코드 0으로 끝남) → FAIL"
    ec=1
  fi
  rm -f "$log"
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
