#!/usr/bin/env python3
"""Phase 2.8 T3⑤ — 안식 농원 테두리 장식 6종 피안절 톤 통일 (ADR-0001 색보정 글루, gen 0).

PixelLab 산출 6종(저승 봄나무 A/B·풀 무더기·덤불·바위·그루터기)이 레퍼런스풍 *쨍한 초록*으로
나와, 코어(T1 피안절 #417331 봄이끼)와 한 무대로 안 읽힌다 → T1의 retone_grass를 *그대로 재사용*해
녹색 픽셀만 봄 이끼로 웜회전·탈채(웜 hue·SAT×0.58·VAL×0.92)한다. 회색 바위·갈색 그루터기 몸체는
sat>0.15 녹색만 잡으므로 보존되고, 그 위 이끼/풀만 봄 톤으로 통일된다.

멱등: 각 *_raw.png(PixelLab 원본 백업)에서 출발해 *.png 산출(retone_grass 규약). 좌표·로직 불변(아트만).

사용: python3 tools/retone_props_p28t3.py
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from retone_pianjeol import retone_grass  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
PROPS = os.path.join(HERE, "..", "assets", "props")
TARGETS = ["tree_spirit_a", "tree_spirit_b", "grass_tuft", "bush", "rock", "stump_log"]


def main() -> None:
    print("Phase 2.8 T3⑤ 테두리 장식 피안절 톤 통일:")
    for n in TARGETS:
        cnt = retone_grass(os.path.join(PROPS, n + ".png"))
        print(f"   {n}: {cnt} green px → 봄 이끼")
    print("done")


if __name__ == "__main__":
    main()
