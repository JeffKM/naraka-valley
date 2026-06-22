#!/bin/bash
# 본 게임(나라카 밸리) 실행 글루 — main.tscn을 1920x1080(내부 960×540의 정수배 ×2)로 띄운다.
# ADR-0018: 코지 와이드 — 가로 30타일 노출(스타듀 동일).
cd "$(dirname "$0")" || exit 1
exec godot --path "$PWD" --resolution 1920x1080 res://main.tscn
