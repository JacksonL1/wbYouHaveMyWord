#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
情境配音批量合成（Scene VO Pipeline）
=====================================
数据源：data/voice_lines.json   —— { "文件名": ["台词", "语速"] }
产出：  assets/audio/vo/<文件名>.mp3

与 gen_vo.py 的分工：
    gen_vo.py        → 单词卡片的短发音（data/story.json 的 vo 字段）
    gen_vo_lines.py  → 每关的整句情境台词（进关 / 操作 / 通关 / 超时 / 拖错）

特性：
    * 每条按台词表单独指定语速（低龄儿童句放慢到 -15%，短促提示 +0%）；
    * 4 路并发 + 失败换备用音色重试；
    * 幂等：已存在且 >1KB 的文件默认跳过，--force 可强制重生成。

用法： python tools/gen_vo_lines.py [--force]
"""
import asyncio
import json
import os
import sys

import edge_tts

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LINES = os.path.join(ROOT, "data", "voice_lines.json")
OUT_DIR = os.path.join(ROOT, "assets", "audio", "vo")

VOICE = "en-US-AnaNeural"
VOICE_FALLBACK = "en-US-JennyNeural"
PITCH = "+2Hz"
CONCURRENCY = 4


async def _synth_one(sem, stem, text, rate, force, results):
    out = os.path.join(OUT_DIR, stem + ".mp3")
    if not force and os.path.exists(out) and os.path.getsize(out) > 1024:
        results[stem] = "skip"
        return
    async with sem:
        for voice in (VOICE, VOICE_FALLBACK):
            try:
                tts = edge_tts.Communicate(text, voice, rate=rate, pitch=PITCH)
                await tts.save(out)
                if os.path.getsize(out) > 1024:
                    results[stem] = "ok"
                    print("  [ok]   %-26s %s" % (stem, rate))
                    return
                raise RuntimeError("生成文件过小")
            except Exception as exc:  # noqa: BLE001
                print("  [warn] %-26s %s 音色失败: %s" % (stem, voice, str(exc)[:100]))
        results[stem] = "fail"
        print("  [FAIL] %-26s %s" % (stem, text[:40]))


async def main(force: bool) -> None:
    with open(LINES, "r", encoding="utf-8") as f:
        raw = json.load(f)
    lines = {k: v for k, v in raw.items() if not k.startswith("_")}
    os.makedirs(OUT_DIR, exist_ok=True)

    print("[vo-lines] 音色 %s / %s，共 %d 条，%d 路并发" %
          (VOICE, VOICE_FALLBACK, len(lines), CONCURRENCY))
    sem = asyncio.Semaphore(CONCURRENCY)
    results: dict = {}
    tasks = [
        _synth_one(sem, stem, item[0], item[1], force, results)
        for stem, item in lines.items()
    ]
    await asyncio.gather(*tasks)

    ok = sum(1 for v in results.values() if v in ("ok", "skip"))
    fail = [k for k, v in results.items() if v == "fail"]
    print("[vo-lines] done. 成功/跳过 %d/%d，失败 %d" % (ok, len(lines), len(fail)))
    if fail:
        print("[vo-lines] 失败条目:", ", ".join(fail))
        sys.exit(1)


if __name__ == "__main__":
    if sys.platform == "win32":
        asyncio.set_event_loop_policy(asyncio.WindowsSelectorEventLoopPolicy())
    asyncio.run(main("--force" in sys.argv))
