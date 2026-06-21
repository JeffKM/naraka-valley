#!/usr/bin/env python3
"""P2.6 사운드 — SFX(최종) + BGM(그레이박스 플레이스홀더)를 코드로 합성한다.

왜 코드 합성인가:
  - 라이선스 0 리스크: 출력물 100% 소유(로열티프리 팩 출처 추적·CC0 확인 불필요).
    docs/licensing-checklist.md의 SFX 항목을 "코드 생성 = 자작"으로 닫는다.
  - 톤 일관 튜닝: 저승 코지 톤을 상수 한 곳에서 조정(채도 과한 풀 타일 같은 후회 방지).
  - ADR-0001 허용: "도트화 툴"(변환 엔진) 제작 금지지, 그레이박스 플레이스홀더·자작
    에셋 생성용 글루 스크립트는 lighting.gd 빛 텍스처·main.gd TileSet 런타임 조립과
    같은 결로 허용된다.

설계:
  - 의존성 0(numpy 없이 stdlib wave/struct/math/random만). 시드 고정이라 재실행 결정적.
  - SFX 9종(ROADMAP P2.6: 괭이·물·수확·서빙·골드·UI·대화·막기·취침)은 *최종 에셋*.
  - BGM 3종(낮·밤·엔딩)은 *그레이박스 플레이스홀더 루프* — 음악 버스·크로스페이드를
    지금 굴려 보고 검증하기 위한 것. Suno Pro 생성본(.ogg)이 같은 파일명으로 떨어지면
    audio.gd가 .ogg를 우선 로드해 자동 교체된다(docs/design/p2.0-spike-prompts.md §13).

실행: python3 game/tools/make_sfx.py   (game/assets/audio/{sfx,bgm}/*.wav 생성)
"""

import math
import os
import random
import struct
import wave

SR = 22050  # 샘플레이트(Hz) — 레트로 톤엔 충분하고 파일이 가볍다
HERE = os.path.dirname(os.path.abspath(__file__))
SFX_DIR = os.path.join(HERE, "..", "assets", "audio", "sfx")
BGM_DIR = os.path.join(HERE, "..", "assets", "audio", "bgm")

TWO_PI = 2.0 * math.pi


# ── 파형 기본 ────────────────────────────────────────────────────────────
def _osc(freq, t, kind="sine"):
    phase = (freq * t) % 1.0
    if kind == "sine":
        return math.sin(TWO_PI * freq * t)
    if kind == "square":
        return 1.0 if phase < 0.5 else -1.0
    if kind == "tri":
        return 4.0 * abs(phase - 0.5) - 1.0
    if kind == "saw":
        return 2.0 * phase - 1.0
    return 0.0


def silence(dur):
    return [0.0] * int(dur * SR)


def tone(freq, dur, kind="sine", gain=1.0, f_end=None, vib=0.0):
    """단일 음. f_end를 주면 freq→f_end로 글라이드(피치 슬라이드)."""
    n = int(dur * SR)
    out = [0.0] * n
    f_end = freq if f_end is None else f_end
    phase = 0.0
    for i in range(n):
        t = i / SR
        frac = i / max(1, n - 1)
        f = freq + (f_end - freq) * frac
        if vib:
            f *= 1.0 + vib * math.sin(TWO_PI * 6.0 * t)
        phase += f / SR
        ph = phase % 1.0
        if kind == "sine":
            s = math.sin(TWO_PI * phase)
        elif kind == "square":
            s = 1.0 if ph < 0.5 else -1.0
        elif kind == "tri":
            s = 4.0 * abs(ph - 0.5) - 1.0
        elif kind == "saw":
            s = 2.0 * ph - 1.0
        else:
            s = 0.0
        out[i] = s * gain
    return out


def noise(dur, gain=1.0, seed=0):
    rng = random.Random(seed)
    return [(rng.uniform(-1.0, 1.0)) * gain for _ in range(int(dur * SR))]


# ── 엔벨로프 ─────────────────────────────────────────────────────────────
def env_ad(samples, attack, decay, sustain=0.0, release=0.0):
    """Attack-Decay(-Sustain-Release) 진폭 포락선을 곱한다(초 단위)."""
    n = len(samples)
    a = int(attack * SR)
    d = int(decay * SR)
    r = int(release * SR)
    s_lvl = sustain
    out = [0.0] * n
    for i in range(n):
        if i < a:
            e = i / max(1, a)
        elif i < a + d:
            e = 1.0 - (1.0 - s_lvl) * ((i - a) / max(1, d))
        elif i < n - r:
            e = s_lvl
        else:
            e = s_lvl * (1.0 - (i - (n - r)) / max(1, r))
        out[i] = samples[i] * e
    return out


def env_exp(samples, tau):
    """지수 감쇠(타격감) — tau초마다 1/e로 줄어든다."""
    out = [0.0] * len(samples)
    for i in range(len(samples)):
        out[i] = samples[i] * math.exp(-(i / SR) / tau)
    return out


def lowpass(samples, alpha=0.25):
    """1극 저역통과 — 거친 노이즈를 부드럽게(물·바람 톤)."""
    out = [0.0] * len(samples)
    prev = 0.0
    for i, s in enumerate(samples):
        prev = prev + alpha * (s - prev)
        out[i] = prev
    return out


# ── 믹스 ─────────────────────────────────────────────────────────────────
def add(dst, src, at=0.0, gain=1.0):
    start = int(at * SR)
    if start + len(src) > len(dst):
        dst.extend([0.0] * (start + len(src) - len(dst)))
    for i, s in enumerate(src):
        dst[start + i] += s * gain
    return dst


def concat(*chunks):
    out = []
    for c in chunks:
        out.extend(c)
    return out


def normalize(samples, peak=0.85):
    m = max((abs(s) for s in samples), default=0.0)
    if m < 1e-6:
        return samples
    k = peak / m
    return [s * k for s in samples]


def write_wav(path, samples):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with wave.open(path, "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        frames = bytearray()
        for s in samples:
            v = int(max(-1.0, min(1.0, s)) * 32767)
            frames += struct.pack("<h", v)
        w.writeframes(bytes(frames))


# ── SFX 9종 (최종 에셋) ──────────────────────────────────────────────────
# 톤 방향: 저승 코지 — 부드럽고 둥근 레트로. 날카로운 고역·긴 잔향은 피한다.
def sfx_hoe():
    # 괭이질: 흙을 찍는 둔탁한 "턱". 저역 사인 + 짧은 노이즈 burst.
    body = env_exp(tone(150, 0.18, "sine", f_end=70), 0.05)
    thud = env_exp(lowpass(noise(0.09, 0.6, seed=11), 0.4), 0.025)
    out = [0.0] * 0
    add(out, body)
    add(out, thud, 0.0, 0.8)
    return normalize(out, 0.8)


def sfx_water():
    # 물주기: 부드러운 물줄기 — 저역통과한 노이즈를 천천히 열고 닫는다.
    base = lowpass(noise(0.45, 1.0, seed=23), 0.12)
    out = env_ad(base, 0.08, 0.0, 0.7, 0.25)
    # 물방울 톤 살짝 얹기
    add(out, env_exp(tone(900, 0.12, "sine", f_end=1300), 0.04), 0.05, 0.12)
    return normalize(out, 0.6)


def sfx_harvest():
    # 수확: 밝게 톡 따는 상승 팝(영혼을 거둠).
    a = env_exp(tone(520, 0.14, "tri", f_end=780), 0.05)
    b = env_exp(tone(780, 0.16, "sine", f_end=1040), 0.06)
    out = [0.0] * 0
    add(out, a, 0.0, 0.7)
    add(out, b, 0.04, 0.6)
    return normalize(out, 0.8)


def sfx_serve():
    # 서빙: 카운터 종 "딩~" (두 배음, 부드러운 잔향).
    f0 = 660.0
    out = env_exp(tone(f0, 0.6, "sine"), 0.22)
    add(out, env_exp(tone(f0 * 2.01, 0.6, "sine"), 0.16), 0.0, 0.45)
    add(out, env_exp(tone(f0 * 3.0, 0.5, "sine"), 0.12), 0.0, 0.2)
    return normalize(out, 0.7)


def sfx_gold():
    # 골드: 동전 "치링" — 두 개의 짧은 사각 블립이 빠르게 상승.
    out = [0.0] * 0
    add(out, env_exp(tone(880, 0.09, "square", gain=0.5), 0.03), 0.0)
    add(out, env_exp(tone(1320, 0.12, "square", gain=0.5), 0.04), 0.06)
    return normalize(out, 0.55)


def sfx_ui():
    # UI: 메뉴 이동·토글 — 짧고 중립적인 블립.
    out = env_exp(tone(440, 0.07, "square", gain=0.5, f_end=560), 0.025)
    return normalize(out, 0.5)


def sfx_dialogue():
    # 대화: 말풍선 텍스트 비프 — 낮고 부드러운 둥근 블립.
    out = env_ad(tone(360, 0.08, "sine"), 0.005, 0.0, 0.9, 0.05)
    add(out, tone(360, 0.08, "tri", gain=0.15), 0.0)
    return normalize(out, 0.45)


def sfx_block():
    # 막기: 잡귀를 쳐내는 타격 "퍽" — 하강 피치 + 노이즈 임팩트.
    body = env_exp(tone(320, 0.16, "saw", f_end=90), 0.045)
    hit = env_exp(noise(0.06, 0.8, seed=41), 0.018)
    out = [0.0] * 0
    add(out, body, 0.0, 0.7)
    add(out, hit, 0.0, 0.6)
    return normalize(out, 0.85)


def sfx_sleep():
    # 취침: 하루를 닫는 부드러운 하강 패드(두 음 글라이드 다운).
    a = env_ad(tone(440, 0.9, "sine", f_end=294), 0.12, 0.0, 0.8, 0.5)
    b = env_ad(tone(294, 0.9, "tri", gain=0.4, f_end=196), 0.12, 0.0, 0.8, 0.5)
    out = [0.0] * 0
    add(out, a, 0.0, 0.6)
    add(out, b, 0.0, 0.4)
    return normalize(out, 0.6)


# ── BGM 4종 (그레이박스 플레이스홀더 루프) ────────────────────────────────
# Suno Pro 생성본(.ogg)이 같은 파일명으로 떨어지기 전까지 음악 버스·크로스페이드를
# 굴려 보기 위한 임시 루프. 단순·저음량(플레이스홀더임을 톤으로도 드러냄).
# 낮은 위치로 둘로 갈린다: farm(밭·집·길)·cafe(카페 안) — 톤을 달리해 분리를 들리게 한다.
def _chord(freqs, dur, kind="sine", gain=0.25):
    out = silence(dur)
    for f in freqs:
        add(out, tone(f, dur, kind, gain=gain), 0.0)
    # 양 끝 살짝 페이드(루프 이음매 클릭 방지)
    return env_ad(out, 0.05, 0.0, 1.0, 0.05)


def bgm_farm():
    # 밭(야외 낮): 밝고 트인 장조 아르페지오 — C E G C 순환.
    notes = [261.63, 329.63, 392.00, 523.25, 392.00, 329.63]
    out = [0.0] * 0
    step = 0.4
    for i, f in enumerate(notes):
        n = env_ad(tone(f, step * 1.1, "tri", gain=0.3), 0.02, 0.25, 0.4, 0.1)
        add(out, n, i * step)
    pad = _chord([130.81, 196.00], len(out) / SR, "sine", gain=0.10)
    add(out, pad, 0.0)
    return normalize(out, 0.5)


def bgm_cafe():
    # 카페(실내 낮): 아늑한 라운지 결 — 부드러운 7th 화음 위 차분한 멜로디(밭보다 따뜻·느긋).
    out = [0.0] * 0
    # Cmaj7 → Fmaj7 두 마디 패드(라운지 화음)
    add(out, _chord([261.63, 329.63, 392.00, 493.88], 2.0, "sine", gain=0.13), 0.0)   # Cmaj7
    add(out, _chord([349.23, 440.00, 523.25, 659.25], 2.0, "sine", gain=0.13), 2.0)   # Fmaj7
    # 위에 얹는 느긋한 멜로디 한 줄(마림바 느낌의 삼각파)
    mel = [392.00, 440.00, 523.25, 440.00, 392.00, 329.63]
    step = 0.62
    for i, f in enumerate(mel):
        add(out, env_ad(tone(f, step * 1.05, "tri", gain=0.22), 0.03, 0.2, 0.5, 0.15), i * step)
    return normalize(out, 0.45)


def bgm_night():
    # 밤(바 긴장): 낮고 서늘한 드론 + 느린 맥동(저승 인디고).
    dur = 4.0
    out = _chord([98.00, 146.83, 116.54], dur, "saw", gain=0.16)  # A단조계 어두운 보이싱
    out = lowpass(out, 0.08)
    # 느린 트레몰로(긴장 맥동)
    for i in range(len(out)):
        t = i / SR
        out[i] *= 0.7 + 0.3 * math.sin(TWO_PI * 0.5 * t)
    add(out, env_ad(tone(587.33, 1.2, "sine", gain=0.06), 0.3, 0.0, 0.7, 0.6), 1.0)
    return normalize(out, 0.45)


def bgm_ending():
    # 엔딩(슬라이스 마무리): 부드럽게 해소되는 장조 코드 진행.
    out = [0.0] * 0
    add(out, _chord([196.00, 246.94, 293.66], 1.6, "sine", gain=0.22), 0.0)  # G
    add(out, _chord([261.63, 329.63, 392.00], 2.2, "sine", gain=0.22), 1.6)  # C(해소)
    return normalize(out, 0.5)


SFX = {
    "hoe": sfx_hoe,
    "water": sfx_water,
    "harvest": sfx_harvest,
    "serve": sfx_serve,
    "gold": sfx_gold,
    "ui": sfx_ui,
    "dialogue": sfx_dialogue,
    "block": sfx_block,
    "sleep": sfx_sleep,
}

BGM = {
    "bgm_farm": bgm_farm,
    "bgm_cafe": bgm_cafe,
    "bgm_night": bgm_night,
    "bgm_ending": bgm_ending,
}


def main():
    for name, fn in SFX.items():
        path = os.path.join(SFX_DIR, name + ".wav")
        write_wav(path, fn())
        print("  ♪ SFX  ", os.path.relpath(path, HERE))
    for name, fn in BGM.items():
        path = os.path.join(BGM_DIR, name + ".wav")
        write_wav(path, fn())
        print("  ♫ BGM* ", os.path.relpath(path, HERE), "(placeholder)")
    print("완료: SFX %d종 + BGM 플레이스홀더 %d종" % (len(SFX), len(BGM)))


if __name__ == "__main__":
    main()
