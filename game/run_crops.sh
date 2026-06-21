#!/bin/bash
# P2.2 작물 미리보기 실행 글루 — 긴 절대경로 복붙 시 줄바꿈 깨짐을 피한다.
cd "$(dirname "$0")" || exit 1
exec godot --path "$PWD" --resolution 832x624 res://crop_preview.tscn
