#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
音效生成器（纯标准库，无第三方依赖）
====================================
产出 assets/audio/sfx/ 下的 16bit 单声道 WAV：
    success.wav  匹配成功 —— 明亮上行琶音
    error.wav    匹配失败 —— 低沉下滑双音（不刺耳、不吓人）
    tap.wav      提示轻点 —— 柔和短促的「波」声
    level.wav    全部通关 —— 小号式上行号角

用法： python tools/gen_sfx.py
"""
import math
import os
import struct
import wave

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_DIR = os.path.join(ROOT, "assets", "audio", "sfx")
SR = 44100


def env(i, n, attack=0.01, release=0.6):
    """简单 ADSR 近似：快起慢落"""
    t = i / n
    a = min(1.0, t / max(attack, 1e-6))
    r = min(1.0, (1.0 - t) / max(release, 1e-6))
    return a * r


def tone(freq, dur, vol=0.5, wave_fn=math.sin, attack=0.01, release=0.6, vib=0.0):
    n = int(SR * dur)
    out = []
    phase = 0.0
    for i in range(n):
        f = freq * (1.0 + vib * math.sin(2 * math.pi * 6.0 * i / SR))
        phase += 2 * math.pi * f / SR
        s = wave_fn(phase)
        # 轻微泛音，让声音更「木质、可爱」
        s = 0.72 * s + 0.18 * math.sin(2 * phase) + 0.08 * math.sin(3 * phase)
        out.append(vol * env(i, n, attack, release) * s)
    return out


def seq(*chunks):
    """按顺序拼接多段音"""
    out = []
    for c in chunks:
        out.extend(c)
    return out


def silence(dur):
    return [0.0] * int(SR * dur)


def save(name, samples, gain=0.9):
    os.makedirs(OUT_DIR, exist_ok=True)
    path = os.path.join(OUT_DIR, name + ".wav")
    peak = max(1e-6, max(abs(s) for s in samples))
    k = gain / peak if peak > gain else 1.0
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        frames = b"".join(
            struct.pack("<h", int(max(-1.0, min(1.0, s * k)) * 32767)) for s in samples
        )
        w.writeframes(frames)
    print("  ->", os.path.relpath(path, ROOT), "(%.2fs)" % (len(samples) / SR))


def gen_success():
    # C5 -> E5 -> G5 -> C6 上行琶音 + 尾音
    notes = [(523.25, 0.12), (659.25, 0.12), (783.99, 0.14), (1046.5, 0.34)]
    parts = [tone(f, d, 0.5, attack=0.008, release=0.45) for f, d in notes]
    save("success", seq(*parts))


def gen_error():
    # 两个温和的下滑音，避免刺耳
    n1 = []
    n2 = []
    n = int(SR * 0.16)
    for i in range(n):
        t = i / n
        f = 330 * (1 - 0.12 * t)
        s = math.sin(2 * math.pi * f * i / SR) * env(i, n, 0.02, 0.3)
        n1.append(0.5 * s)
    n = int(SR * 0.22)
    for i in range(n):
        t = i / n
        f = 240 * (1 - 0.18 * t)
        s = math.sin(2 * math.pi * f * i / SR) * env(i, n, 0.02, 0.4)
        n2.append(0.5 * s)
    save("error", seq(n1, silence(0.04), n2))


def gen_tap():
    # 柔和的「啵」
    n = int(SR * 0.18)
    out = []
    for i in range(n):
        t = i / n
        f = 760 - 320 * t
        s = math.sin(2 * math.pi * f * i / SR) * env(i, n, 0.004, 0.7)
        out.append(0.55 * s)
    save("tap", out)


def gen_level():
    # 通关号角：G-C-E-G(高)
    notes = [(392.0, 0.14), (523.25, 0.14), (659.25, 0.16), (783.99, 0.42)]
    parts = [tone(f, d, 0.5, attack=0.01, release=0.5, vib=0.01) for f, d in notes]
    save("level", seq(*parts))


def main():
    print("[sfx] 生成音效…")
    gen_success()
    gen_error()
    gen_tap()
    gen_level()
    print("[sfx] done.")


if __name__ == "__main__":
    main()
