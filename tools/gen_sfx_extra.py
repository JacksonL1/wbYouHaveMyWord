#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
扩展音效 + 晨间 BGM 生成器（纯标准库）
=====================================
产出 assets/audio/sfx/ 下的 16bit 单声道 WAV：
    brush_swish.wav   刷牙「刷刷」—— 1.12s 无缝循环，与手臂摆动同频
    gulp.wav          喝水咕咚
    splash.wav        洗脸水花
    snap.wav          穿衣 / 穿鞋的清脆「咔」
    sparkle.wav       徽章点亮 / 换装成功的叮咚
    highfive.wav      击掌收尾
    bgm_morning.wav   8s 轻柔晨间循环背景乐（游戏里以 -18dB 铺底）

用法： python tools/gen_sfx_extra.py
"""
import math
import os
import random

from gen_sfx import SR, env, save, seq, silence, tone

random.seed(20261110)


def _noise_band(n, low=0.86, high=0.28, lp=0.34):
    """带通白噪声：一阶低通后再减去慢速分量，得到柔和的『沙沙』"""
    out = []
    y = 0.0
    slow = 0.0
    for _ in range(n):
        x = random.uniform(-1.0, 1.0)
        y += lp * (x - y)          # 低通
        slow += 0.015 * (y - slow)  # 极慢基线
        out.append((y - slow) * low + x * high * 0.25)
    return out


def gen_brush_swish():
    """1.12s = 2 个 0.56s 周期，每周期两次刷动；首尾归零便于无缝循环"""
    dur = 1.12
    n = int(SR * dur)
    noise = _noise_band(n)
    out = []
    for i in range(n):
        t = i / SR
        phase = (t % 0.56) / 0.28          # 0..2，两次刷
        swish = math.sin(math.pi * (phase % 1.0)) ** 2
        # 每次刷动音色略有差异：上行更亮、下行更闷
        bright = 1.0 if (int(t / 0.28) % 2 == 0) else 0.72
        # 首尾各 8ms 淡入淡出，彻底消除循环爆音
        edge = min(1.0, t / 0.008, (dur - t) / 0.008)
        out.append(noise[i] * swish * bright * 0.85 * max(0.0, edge))
    save("brush_swish", out, gain=0.72)


def gen_gulp():
    """三下『咕咚』：低频快速下滑 + 一点水声"""
    parts = []
    for k in range(3):
        dur = 0.16
        n = int(SR * dur)
        chunk = []
        for i in range(n):
            t = i / n
            f = 210 - 110 * t
            s = math.sin(2 * math.pi * f * i / SR)
            s += 0.18 * math.sin(2 * math.pi * f * 2 * i / SR)
            chunk.append(0.55 * env(i, n, 0.01, 0.75) * s)
        parts.append(chunk)
        parts.append(silence(0.045))
    save("gulp", seq(*parts))


def gen_splash():
    n = int(SR * 0.42)
    noise = _noise_band(n, low=1.0, high=0.6, lp=0.5)
    out = []
    for i in range(n):
        t = i / n
        # 前段爆发、后段细碎水滴
        burst = math.exp(-4.5 * t) * min(1.0, t / 0.01)
        droplet = math.sin(2 * math.pi * (1200 + 400 * math.sin(t * 40)) * i / SR)
        s = noise[i] * burst + 0.12 * droplet * math.exp(-8 * t)
        out.append(s)
    save("splash", out, gain=0.7)


def gen_snap():
    """极短脉冲 + 木质短音"""
    n = int(SR * 0.12)
    out = []
    for i in range(n):
        t = i / SR
        click = random.uniform(-1, 1) * math.exp(-90 * t)
        body = math.sin(2 * math.pi * 420 * t) * math.exp(-32 * t)
        out.append(0.45 * click + 0.5 * body)
    save("snap", out, gain=0.65)


def gen_sparkle():
    notes = [(1046.5, 0.09), (1318.5, 0.09), (1568.0, 0.26)]
    parts = [tone(f, d, 0.4, attack=0.004, release=0.6) for f, d in notes]
    save("sparkle", seq(*parts), gain=0.7)


def gen_highfive():
    # 先「啪」再上行小号，用于清单全通关
    n = int(SR * 0.1)
    clap = [random.uniform(-1, 1) * math.exp(-70 * i / SR) * 0.6 for i in range(n)]
    notes = [(523.25, 0.1), (659.25, 0.1), (783.99, 0.3)]
    melody = [tone(f, d, 0.42, attack=0.005, release=0.55) for f, d in notes]
    save("highfive", seq(clap, *melody), gain=0.72)


def gen_bgm():
    """8 秒 C 大调晨间循环：柔和琶音 + 长音铺底（首尾淡入淡出保证无缝）"""
    dur = 8.0
    n = int(SR * dur)

    # 16 拍 * 0.5s 的琶音（C D E G A 五声音阶，明亮不刺耳）
    scale = [523.25, 587.33, 659.25, 783.99, 880.0, 783.99, 659.25, 587.33]
    melody = [0.0] * n
    for beat, freq in enumerate(scale * 2):
        start = int(beat * 0.5 * SR)
        length = int(0.5 * SR)
        for i in range(length):
            if start + i >= n:
                break
            t = i / length
            e = min(1.0, t / 0.08) * min(1.0, (1.0 - t) / 0.65)
            phase = 2 * math.pi * freq * i / SR
            s = 0.72 * math.sin(phase) + 0.2 * math.sin(2 * phase) + 0.08 * math.sin(3 * phase)
            melody[start + i] += 0.16 * e * s

    # 铺底长音 C3 / G3 / C4
    pad = [0.0] * n
    for freq, amp in ((130.81, 0.10), (196.0, 0.07), (261.63, 0.05)):
        for i in range(n):
            phase = 2 * math.pi * freq * i / SR
            pad[i] += amp * (math.sin(phase) + 0.25 * math.sin(2 * phase))

    out = []
    for i in range(n):
        t = i / SR
        # 整段首尾 0.25s 淡变，循环点处波形平滑衔接
        fade = min(1.0, t / 0.25, (dur - t) / 0.25)
        out.append((melody[i] + pad[i] * fade) * 0.75)
    save("bgm_morning", out, gain=0.6)


def main():
    print("[sfx-extra] 生成扩展音效…")
    gen_brush_swish()
    gen_gulp()
    gen_splash()
    gen_snap()
    gen_sparkle()
    gen_highfive()
    gen_bgm()
    print("[sfx-extra] done.")


if __name__ == "__main__":
    main()
