#!/bin/bash
# 대화용 초상화 미리보기 실행 글루 — 긴 절대경로 복붙 시 줄바꿈 깨짐을 피한다.
# 조작: ←/→ 또는 Space=다음 캐릭터 · R=리로드
cd "$(dirname "$0")" || exit 1
exec godot --path "$PWD" --resolution 960x540 res://portrait_preview.tscn
