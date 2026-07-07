#!/bin/bash
# 본 게임(나라카 밸리) 실행 글루 — main.tscn을 1920x1080(내부 960×540의 정수배 ×2)로 띄운다.
# ADR-0018: 코지 와이드 — 가로 30타일 노출(스타듀 동일).
#
# 실행 전 변경 에셋을 재임포트한다. Godot는 에디터 없이 게임을 띄우면
# 소스 PNG가 아니라 .godot/imported/*.ctex 캐시를 읽으므로, 재임포트 없이는
# 수정한 에셋이 화면에 반영되지 않는다(캐시 STALE). --import는 바뀐 리소스만
# 다시 굽고 끝나므로 변경이 없으면 오버헤드도 거의 없다.
#
# 또한 게임을 detach(nohup+disown)로 띄운다. exec/foreground로 띄우면 이 스크립트를
# 실행한 셸·세션(예: 에이전트의 `!` 명령)이 끝나는 순간 자식 godot도 함께 죽어
# 창이 바로 닫힌다. detach하면 셸이 끝나도 게임 창이 살아남는다.
#
# ★실행 전 *이전에 이 스크립트로 띄운* 게임 인스턴스를 종료한다(pidfile 추적). run_game는
# 매번 새 창을 detach로 띄우므로, 안 죽이면 옛 코드의 창이 겹겹이 남아 "수정이 반영 안 됨"으로
# 오인하게 된다(실제론 새 창은 최신, 옛 창을 보고 있는 것). pidfile로 우리 게임만 골라 죽여
# 에디터·헤드리스 테스트 등 다른 godot는 건드리지 않는다.
cd "$(dirname "$0")" || exit 1
PIDFILE="/tmp/nv_game.pid"

# 0) 이전 게임 인스턴스 종료(있으면) — pidfile로 추적한 우리 창만.
if [ -f "$PIDFILE" ]; then
  OLD_PID="$(cat "$PIDFILE" 2>/dev/null)"
  if [ -n "$OLD_PID" ] && kill -0 "$OLD_PID" 2>/dev/null; then
    kill "$OLD_PID" 2>/dev/null
    ( sleep 2; kill -9 "$OLD_PID" 2>/dev/null ) &   # 완강하면 강제 종료
    echo "이전 게임 종료 (pid=$OLD_PID)"
  fi
fi

# 1) 변경 에셋 재임포트 (좀비 방지 워치독 120s — macOS엔 timeout이 없음)
( godot --headless --path "$PWD" --import >/dev/null 2>&1 & pid=$!
  ( sleep 120; kill -9 "$pid" 2>/dev/null ) & wd=$!
  wait "$pid" 2>/dev/null; kill "$wd" 2>/dev/null )

# 2) detach로 게임 실행 (셸/세션 종료와 무관하게 생존)
nohup godot --path "$PWD" --resolution 1920x1080 res://main.tscn >/tmp/nv_game.log 2>&1 &
GAME_PID=$!
echo "$GAME_PID" > "$PIDFILE"   # 다음 실행이 이 창을 종료할 수 있게 추적
disown
echo "게임 실행됨 (pid=$GAME_PID) — 로그: /tmp/nv_game.log"
