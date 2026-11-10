#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
小人角色美术生成器（分部件 / 贴纸风）
=====================================
产出： assets/character/*.png

设计要点：
    * 部件拆成「头 / 三张脸 / 躯干 / 手臂 / 腿 / 手持小道具 / 泡泡 / Zzz」，
      在 Godot 里以 Node2D 层级 + Tween 旋转/位移做骨骼式动画，
      不需要导出逐帧精灵表，任何姿态都能平滑过渡。
    * 所有部件以自身中心为锚点（Sprite2D 默认居中），
      手臂/腿的顶部另由 Godot 节点 pivot 控制旋转。
    * 复用 gen_art.py 的 Cv / 调色板 / 墨色描边，和现有道具同一视觉语言。

用法： python tools/gen_character.py
"""
import os

from gen_art import Cv, INK, PALETTE, rgba, lighten, darken

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "character")

SKIN = "#FFDDBB"
SKIN_D = "#EFC29C"
HAIR = "#6B4A3A"
PAJAMA = PALETTE["sun"]
PAJAMA_D = darken(PAJAMA, 0.18)
SHIRT = PALETTE["blue"]
SHIRT_L = PALETTE["blue_l"]


def _save(c, name, outline=True, ow=5):
    p = os.path.join(OUT, name)
    c.save(p, INK if outline else None, ow)
    return p


# --------------------------------------------------------------------------
# 头部（不含五官，五官用可切换的脸层）
# --------------------------------------------------------------------------
def head():
    c = Cv((140, 140))
    # 耳朵
    c.ellipse((8, 62, 32, 92), SKIN_D)
    c.ellipse((108, 62, 132, 92), SKIN_D)
    # 脸
    c.ellipse((18, 12, 122, 128), SKIN)
    # 头发：刘海 + 两侧
    c.pieslice((14, 6, 126, 118), 180, 360, HAIR)
    c.rrect((16, 8, 124, 56), 24, HAIR)
    c.ellipse((14, 34, 40, 74), HAIR)
    c.ellipse((100, 34, 126, 74), HAIR)
    # 三撮翘起来的呆毛
    c.poly([(58, 16), (70, -2), (78, 18)], HAIR)
    c.poly([(76, 14), (90, 0), (94, 20)], HAIR)
    # 头顶高光
    c.arc((36, 18, 104, 58), 195, 285, rgba("#FFFFFF", 90), 5)
    _save(c, "head.png")


def _blush(c):
    c.ellipse((26, 82, 46, 96), rgba(PALETTE["coral"], 150))
    c.ellipse((94, 82, 114, 96), rgba(PALETTE["coral"], 150))


def face_awake():
    c = Cv((140, 140))
    _blush(c)
    # 睁眼：黑色椭圆 + 白色高光点
    for x in (46, 94):
        c.ellipse((x - 9, 62, x + 9, 84), INK)
        c.ellipse((x - 4, 65, x + 2, 72), "#FFFFFF")
    # 笑嘴
    c.arc((50, 88, 92, 116), 10, 170, INK, 5)
    c.arc((54, 90, 88, 112), 20, 160, rgba(PALETTE["coral_d"], 220), 3)
    _save(c, "face_awake.png", False)


def face_asleep():
    c = Cv((140, 140))
    _blush(c)
    # 闭眼：两条向下弯的弧
    for x in (46, 94):
        c.arc((x - 11, 64, x + 11, 82), 10, 170, INK, 5)
    # 小 o 嘴
    c.ellipse((65, 96, 77, 108), rgba(PALETTE["coral_d"], 210))
    _save(c, "face_asleep.png", False)


def face_brush():
    c = Cv((140, 140))
    _blush(c)
    # 略眯起的眼睛（用力刷牙）
    for x in (46, 94):
        c.arc((x - 10, 64, x + 10, 78), 190, 350, INK, 5)
    # 张开的嘴 + 一排白牙
    c.ellipse((54, 88, 90, 118), PALETTE["coral_d"])
    c.rrect((57, 89, 87, 99), 3, "#FFFFFF")
    c.ellipse((64, 104, 80, 114), rgba("#FFFFFF", 210))
    _save(c, "face_brush.png", False)


def face_happy():
    """庆祝：眯眼大笑"""
    c = Cv((140, 140))
    _blush(c)
    for x in (46, 94):
        c.arc((x - 11, 62, x + 11, 82), 190, 350, INK, 5)
    c.pieslice((52, 86, 92, 122), 0, 180, PALETTE["coral_d"])
    c.pieslice((57, 92, 87, 118), 180, 360, "#FFFFFF")
    _save(c, "face_happy.png", False)


# --------------------------------------------------------------------------
# 躯干（睡衣 / 穿好衣服两态）
# --------------------------------------------------------------------------
def body(dressed=False):
    c = Cv((140, 130))
    main = SHIRT if dressed else PAJAMA
    lite = SHIRT_L if dressed else lighten(PAJAMA, 0.22)
    deep = darken(main, 0.2)
    # 主体（上窄下宽的圆角梯形感）
    c.rrect((24, 8, 116, 126), 26, main)
    c.rrect((24, 104, 116, 126), 12, deep)
    # 领口
    c.poly([(52, 8), (70, 36), (88, 8)], "#FFFFFF" if dressed else PALETTE["cream"])
    c.arc((52, 2, 88, 32), 10, 170, rgba(deep, 200), 4)
    # 图案：星星 / 口袋
    if dressed:
        c.rrect((76, 62, 104, 92), 8, lite)
        c.line([(76, 72), (104, 72)], "#FFFFFF", 3)
    else:
        for sx, sy, r in ((50, 58, 9), (92, 82, 7)):
            c.poly([(sx, sy - r), (sx + r * 0.3, sy - r * 0.3),
                    (sx + r, sy), (sx + r * 0.3, sy + r * 0.3),
                    (sx, sy + r), (sx - r * 0.3, sy + r * 0.3),
                    (sx - r, sy), (sx - r * 0.3, sy - r * 0.3)],
                   rgba("#FFFFFF", 220))
    # 侧边高光
    c.line([(32, 30), (32, 98)], rgba("#FFFFFF", 90), 5)
    _save(c, "body_shirt.png" if dressed else "body_pajama.png")


# --------------------------------------------------------------------------
# 四肢（顶部为旋转轴：Sprite 中心在 Godot 里由节点 pivot 决定）
# --------------------------------------------------------------------------
def arm():
    c = Cv((44, 112))
    # 袖子
    c.rrect((4, 2, 40, 40), 14, PAJAMA_D)
    c.rrect((4, 2, 40, 12), 6, PAJAMA)
    # 手臂
    c.rrect((9, 30, 35, 88), 13, SKIN)
    # 手掌
    c.ellipse((4, 76, 40, 110), SKIN)
    c.arc((10, 84, 34, 104), 200, 340, rgba(SKIN_D, 180), 3)
    _save(c, "arm.png", True, 4)


def leg():
    c = Cv((46, 104))
    # 裤腿
    c.rrect((4, 0, 42, 44), 12, PAJAMA_D)
    c.rrect((4, 36, 42, 48), 6, PAJAMA)
    # 小腿
    c.rrect((10, 44, 36, 84), 12, SKIN)
    # 脚（光脚，穿鞋关再叠 shoe.png）
    c.rrect((4, 78, 44, 100), 12, SKIN_D)
    _save(c, "leg.png", True, 4)


def shoe():
    c = Cv((66, 40))
    c.rrect((2, 24, 64, 38), 10, "#FFFFFF")
    c.poly([(8, 26), (16, 6), (40, 4), (54, 18), (62, 26)], PALETTE["coral"])
    c.ellipse((40, 12, 62, 30), lighten(PALETTE["coral"], 0.2))
    for i in range(2):
        y = 12 + i * 8
        c.line([(20, y), (38, y - 2)], "#FFFFFF", 3)
    _save(c, "shoe.png", True, 4)


# --------------------------------------------------------------------------
# 手持小道具（跟随右手移动）
# --------------------------------------------------------------------------
def mini_brush():
    c = Cv((62, 130))
    c.rrect((24, 40, 38, 126), 8, PALETTE["coral"])
    c.rrect((18, 8, 44, 46), 10, "#FFFFFF")
    for i in range(4):
        x = 21 + i * 6
        c.rrect((x, 2, x + 4, 18), 2, PALETTE["sky_d"])
    _save(c, "mini_brush.png", True, 3)


def mini_cup():
    c = Cv((80, 90))
    c.poly([(14, 18), (66, 18), (58, 82), (22, 82)], PALETTE["sky"])
    c.poly([(18, 34), (62, 34), (56, 80), (24, 80)], PALETTE["water"])
    c.ellipse((14, 10, 66, 26), "#E8F7FD", PALETTE["sky_d"], 3)
    c.ellipse((20, 14, 60, 22), PALETTE["water"])
    c.arc((62, 26, 82, 66), 270, 90, PALETTE["sky_d"], 5)
    _save(c, "mini_cup.png", True, 3)


def mini_towel():
    c = Cv((90, 90))
    c.rrect((8, 12, 82, 80), 12, PALETTE["pink"])
    c.rect((8, 32, 82, 40), PALETTE["pink_d"])
    c.rect((8, 56, 82, 64), lighten(PALETTE["pink"], 0.3))
    _save(c, "mini_towel.png", True, 3)


def mini_shirt():
    c = Cv((96, 90))
    c.poly([(34, 6), (62, 6), (92, 28), (78, 48), (66, 38),
            (66, 84), (30, 84), (30, 38), (18, 48), (4, 28)], SHIRT)
    c.poly([(40, 6), (48, 22), (56, 6)], "#FFFFFF")
    _save(c, "mini_shirt.png", True, 3)


def mini_shoe():
    c = Cv((90, 60))
    c.rrect((4, 40, 84, 56), 10, "#FFFFFF")
    c.poly([(12, 40), (22, 12), (54, 8), (72, 26), (82, 40)], PALETTE["coral"])
    c.ellipse((56, 18, 82, 38), lighten(PALETTE["coral"], 0.2))
    c.line([(28, 22), (48, 20)], "#FFFFFF", 4)
    _save(c, "mini_shoe.png", True, 3)


# --------------------------------------------------------------------------
# 特效粒子
# --------------------------------------------------------------------------
def bubble():
    c = Cv((48, 48))
    c.ellipse((4, 4, 44, 44), rgba("#FFFFFF", 205), rgba(PALETTE["sky_d"], 220), 3)
    c.ellipse((11, 10, 22, 21), rgba("#FFFFFF", 235))
    _save(c, "bubble.png", False)


def zzz():
    c = Cv((120, 80))
    for i, (x, y, s) in enumerate(((4, 44, 20), (40, 20, 26), (82, 2, 32))):
        col = INK if i == 2 else darken(PALETTE["purple"], 0.1)
        w = s
        h = int(s * 0.85)
        c.line([(x, y), (x + w, y), (x, y + h), (x + w, y + h)], col, 5)
    _save(c, "zzz.png", False)


def main():
    os.makedirs(OUT, exist_ok=True)
    print("[character] 生成小人部件…")
    for fn in (head, face_awake, face_asleep, face_brush, face_happy,
               lambda: body(False), lambda: body(True),
               arm, leg, shoe, mini_brush, mini_cup, mini_towel,
               mini_shirt, mini_shoe, bubble, zzz):
        fn()
    print("[character] done. ->", OUT)


if __name__ == "__main__":
    main()
