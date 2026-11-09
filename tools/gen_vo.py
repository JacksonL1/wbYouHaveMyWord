#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
配音生成流水线（VO Pipeline）
================================
技术栈：Python + edge-tts（微软 Edge 在线语音合成）
产出：assets/audio/vo/<word>.mp3  —— 标准美式儿童英语发音

说明：
    * 主用 en-US-AnaNeural（微软儿童音色，最贴近 4-6 岁目标用户的模仿对象）；
      若该音色不可用则回退 en-US-JennyNeural。
    * 语速放慢 12%，方便低龄儿童跟读。
    * 词条来源于 data/story.json（单一数据源，避免双份维护）。

用法： python tools/gen_vo.py
"""
import asyncio
import json
import os
import sys

import edge_tts

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
STORY = os.path.join(ROOT, "data", "story.json")
OUT_DIR = os.path.join(ROOT, "assets", "audio", "vo")

VOICE = "en-US-AnaNeural"
VOICE_FALLBACK = "en-US-JennyNeural"
RATE = "-12%"
PITCH = "+2Hz"


def collect_words():
    """从 story.json 收集 (文件名, 文本) 对，保证与关卡配置同源"""
    with open(STORY, "r", encoding="utf-8") as f:
        levels = json.load(f)
    words = {}
    for lv in levels:
        for card in lv.get("cards", []):
            stem = card.get("vo") or card.get("id", "").replace("card_", "")
            text = card.get("text") or stem
            if stem and stem not in words:
                words[stem] = text
    return words


async def synth(text, voice, out_path):
    tts = edge_tts.Communicate(text, voice, rate=RATE, pitch=PITCH)
    await tts.save(out_path)


async def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    words = collect_words()
    if not words:
        print("[vo] story.json 中没有可合成的词条")
        return

    voice = VOICE
    print("[vo] 使用音色: %s, 词条 %d 个" % (voice, len(words)))
    for stem, text in words.items():
        out = os.path.join(OUT_DIR, stem + ".mp3")
        try:
            await synth(text, voice, out)
            print("  ->", os.path.relpath(out, ROOT), "(%s)" % text)
        except Exception as e:  # noqa: BLE001
            if voice != VOICE_FALLBACK:
                print("  [warn] %s 失败(%s)，切换备用音色重试" % (stem, e))
                voice = VOICE_FALLBACK
                try:
                    await synth(text, voice, out)
                    print("  ->", os.path.relpath(out, ROOT), "(%s)" % text)
                    continue
                except Exception as e2:  # noqa: BLE001
                    print("  [error] %s 仍失败: %s" % (stem, e2))
            else:
                print("  [error] %s 失败: %s" % (stem, e))
    print("[vo] done.")


if __name__ == "__main__":
    if sys.platform == "win32":
        asyncio.set_event_loop_policy(asyncio.WindowsSelectorEventLoopPolicy())
    asyncio.run(main())
