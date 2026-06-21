#!/bin/bash
# 본 게임(나라카 밸리) 실행 글루 — main.tscn을 1280x720(내부 320×180의 4배)로 띄운다.
cd "$(dirname "$0")" || exit 1
exec godot --path "$PWD" --resolution 1280x720 res://main.tscn
