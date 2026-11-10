#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
美术资产生成器（MVP 占位级，统一「扁平贴纸」风格）
=================================================
输出：
    assets/bgs/bg_*.png        1280x720 场景背景
    assets/props/prop_*.png    道具贴纸（透明底 + 描边）
    assets/ui/ghost_hand.png   提示小手
    assets/ui/glow_ring.png    拖拽悬停光圈
    assets/ui/star.png         结算星星

设计约定：
    * 绘制坐标一律使用「最终像素」坐标，内部按 SS 倍超采样后降采样，保证边缘平滑；
    * 所有道具统一加 6px 墨色描边，形成贴纸感，便于后续替换为 AI 生图 + 抠图；
    * 道具底部统一对齐到 GROUND_Y，与场景 spotlight 对齐。

用法： python tools/gen_art.py
"""
import os
from PIL import Image, ImageDraw, ImageFilter

SS = 2  # 超采样倍数
GROUND_Y = 500  # 道具落地基线（与背景 spotlight 对齐）
INK = "#4A3F55"

PALETTE = {
    "cream": "#FFF7E8",
    "wood": "#E8B678",
    "wood_l": "#F0C994",
    "wood_d": "#C98F52",
    "mint": "#A8E6CF",
    "mint_d": "#7FD3B8",
    "sky": "#BFE3F2",
    "sky_d": "#8FCBE4",
    "water": "#8FD8EE",
    "coral": "#FF8E7A",
    "coral_d": "#F07462",
    "sun": "#FFD166",
    "pink": "#FFC2D1",
    "pink_d": "#F2A0B4",
    "blue": "#7FB8E8",
    "blue_l": "#A8CFEF",
    "green": "#8ED081",
    "purple": "#C3B4E0",
    "white": "#FFFFFF",
}


# --------------------------------------------------------------------------
# 颜色工具
# --------------------------------------------------------------------------
def _rgb(c):
    c = c.lstrip("#")
    return tuple(int(c[i:i + 2], 16) for i in (0, 2, 4))


def mix(c1, c2, t):
    a, b = _rgb(c1), _rgb(c2)
    return "#%02X%02X%02X" % tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def lighten(c, t=0.15):
    return mix(c, "#FFFFFF", t)


def darken(c, t=0.15):
    return mix(c, "#000000", t)


def rgba(c, a):
    return _rgb(c) + (int(a),)


# --------------------------------------------------------------------------
# 带坐标缩放的画布
# --------------------------------------------------------------------------
class Cv:
    def __init__(self, size, bg=None):
        self.size = size
        self.img = Image.new("RGBA", (size[0] * SS, size[1] * SS),
                             rgba(bg, 255) if bg else (0, 0, 0, 0))
        self.d = ImageDraw.Draw(self.img)

    def _b(self, box):
        return [box[0] * SS, box[1] * SS, box[2] * SS, box[3] * SS]

    def _p(self, pts):
        return [(x * SS, y * SS) for x, y in pts]

    def rect(self, box, fill=None, outline=None, width=1):
        self.d.rectangle(self._b(box), fill=fill, outline=outline,
                         width=max(1, int(width * SS)))

    def rrect(self, box, r, fill=None, outline=None, width=1):
        self.d.rounded_rectangle(self._b(box), radius=r * SS, fill=fill,
                                 outline=outline, width=max(1, int(width * SS)))

    def ellipse(self, box, fill=None, outline=None, width=1):
        self.d.ellipse(self._b(box), fill=fill, outline=outline,
                       width=max(1, int(width * SS)))

    def poly(self, pts, fill=None, outline=None, width=1):
        self.d.polygon(self._p(pts), fill=fill, outline=outline)
        if outline and width:
            closed = list(pts) + [pts[0]]
            self.line(closed, outline, width)

    def line(self, pts, fill, width=1):
        self.d.line(self._p(pts), fill=fill, width=max(1, int(width * SS)), joint="curve")

    def arc(self, box, start, end, fill, width=1):
        self.d.arc(self._b(box), start, end, fill=fill, width=max(1, int(width * SS)))

    def pieslice(self, box, start, end, fill):
        self.d.pieslice(self._b(box), start, end, fill=fill)

    # ---------- 输出 ----------
    def out(self, outline=None, ow=6):
        img = self.img
        if outline is not None:
            alpha = img.split()[3]
            grow = alpha.filter(ImageFilter.MaxFilter(int(ow * SS) * 2 + 1))
            stroke = Image.new("RGBA", img.size, rgba(outline, 255))
            stroke.putalpha(grow)
            img = Image.alpha_composite(stroke, img)
        return img.resize(self.size, Image.LANCZOS)

    def save(self, path, outline=None, ow=6):
        os.makedirs(os.path.dirname(path), exist_ok=True)
        self.out(outline, ow).save(path)
        print("  ->", path)


# --------------------------------------------------------------------------
# 背景
# --------------------------------------------------------------------------
def draw_room(cv, wall, floor, accent, rug):
    """通用房间骨架：墙面 + 踢脚线 + 地板 + 落地光斑"""
    # 墙面（带竖向条纹，弱化大面积纯色）
    cv.rect((0, 0, 1280, 430), wall)
    stripe = lighten(wall, 0.05)
    for x in range(0, 1280, 92):
        cv.rect((x, 0, x + 46, 430), stripe)
    # 踢脚线
    cv.rect((0, 404, 1280, 436), accent)
    cv.line([(0, 404), (1280, 404)], darken(accent, 0.12), 3)
    # 地板
    cv.rect((0, 430, 1280, 720), floor)
    for y in range(436, 720, 52):
        cv.line([(0, y), (1280, y)], darken(floor, 0.06), 2)
    for x in range(-240, 1520, 190):
        cv.line([(x, 430), (x - 150, 720)], darken(floor, 0.05), 2)
    # 落地光斑（道具舞台）
    cv.ellipse((372, GROUND_Y - 52, 908, GROUND_Y + 54), rug)
    cv.ellipse((372, GROUND_Y - 52, 908, GROUND_Y + 54), None, darken(rug, 0.08), 3)


def draw_window(cv, box, sky=None, frame=None):
    x0, y0, x1, y1 = box
    frame = frame or PALETTE["white"]
    sky = sky or PALETTE["sky"]
    cv.rrect((x0 - 10, y0 - 10, x1 + 10, y1 + 10), 18, frame)
    cv.rect((x0, y0, x1, y1), sky)
    # 太阳 + 云
    cv.ellipse((x1 - 96, y0 + 22, x1 - 40, y0 + 78), PALETTE["sun"])
    for cx, cy, w, h in [(x0 + 40, y0 + 60, 96, 44), (x0 + 24, y0 + 96, 120, 40)]:
        cv.ellipse((cx, cy, cx + w, cy + h), rgba("#FFFFFF", 235))
    # 窗格
    mx, my = (x0 + x1) // 2, (y0 + y1) // 2
    cv.rect((mx - 5, y0, mx + 5, y1), frame)
    cv.rect((x0, my - 5, x1, my + 5), frame)
    cv.rrect((x0 - 10, y0 - 10, x1 + 10, y1 + 10), 18, None, frame, 5)


def draw_shelf(cv, box, color, items):
    """墙面置物架 + 小摆件"""
    x0, y0, x1, y1 = box
    cv.rrect((x0, y0, x1, y0 + 14), 6, color)
    for i, c in enumerate(items):
        cx = x0 + 26 + i * 46
        cv.rrect((cx, y0 - 34, cx + 30, y0), 8, c)
        cv.rrect((cx + 8, y0 - 44, cx + 22, y0 - 26), 6, lighten(c, 0.25))


def draw_plant(cv, base_x, base_y, pot, leaf):
    cv.rrect((base_x - 34, base_y - 58, base_x + 34, base_y), 10, pot)
    cv.rect((base_x - 40, base_y - 66, base_x + 40, base_y - 50), pot)
    for dx, dy, w, h in [(-26, -150, 40, 92), (0, -178, 44, 116), (24, -146, 38, 88)]:
        cv.ellipse((base_x + dx - w // 2, base_y - 62 + dy, base_x + dx + w // 2, base_y - 62 + dy + h), leaf)


def draw_mirror(cv, cx, cy, w, h, frame, glass):
    cv.ellipse((cx - w // 2, cy - h // 2, cx + w // 2, cy + h // 2), frame)
    cv.ellipse((cx - w // 2 + 14, cy - h // 2 + 14, cx + w // 2 - 14, cy + h // 2 - 14), glass)
    cv.arc((cx - w // 2 + 34, cy - h // 2 + 34, cx + w // 2 - 34, cy + h // 2 - 34), 200, 250,
           rgba("#FFFFFF", 200), 8)


def draw_tiles(cv, box, base, line_c):
    x0, y0, x1, y1 = box
    cv.rect((x0, y0, x1, y1), base)
    for x in range(int(x0), int(x1), 56):
        cv.line([(x, y0), (x, y1)], line_c, 3)
    for y in range(int(y0), int(y1), 56):
        cv.line([(x0, y), (x1, y)], line_c, 3)


def draw_door(cv, box, color, knob):
    x0, y0, x1, y1 = box
    cv.rrect((x0, y0, x1, y1), 10, color)
    cv.rrect((x0 + 18, y0 + 20, x1 - 18, y0 + (y1 - y0) // 2 - 10), 8, lighten(color, 0.12))
    cv.rrect((x0 + 18, y0 + (y1 - y0) // 2 + 10, x1 - 18, y1 - 20), 8, lighten(color, 0.12))
    cv.ellipse((x1 - 44, (y0 + y1) // 2 - 11, x1 - 22, (y0 + y1) // 2 + 11), knob)


def draw_hooks(cv, y, color):
    for x in (1040, 1110, 1180):
        cv.rrect((x, y, x + 40, y + 10), 5, color)
        cv.line([(x + 20, y + 10), (x + 20, y + 30)], color, 6)
        cv.ellipse((x + 14, y + 26, x + 26, y + 38), color)


# --------------------------------------------------------------------------
# 道具
# --------------------------------------------------------------------------
def prop_bed(path):
    c = Cv((360, 260))
    # 床腿
    c.rrect((46, 214, 70, 252), 8, PALETTE["wood_d"])
    c.rrect((290, 214, 314, 252), 8, PALETTE["wood_d"])
    # 床头板
    c.rrect((26, 16, 334, 156), 20, PALETTE["wood"])
    c.rrect((54, 40, 306, 146), 16, PALETTE["wood_l"])
    # 床架
    c.rrect((20, 176, 340, 232), 14, PALETTE["wood_d"])
    # 床垫
    c.rrect((44, 118, 316, 204), 18, "#FFFBF0")
    # 被子
    c.rrect((44, 152, 316, 208), 14, PALETTE["mint"])
    c.rect((44, 168, 316, 180), PALETTE["mint_d"])
    # 枕头
    c.rrect((64, 108, 186, 164), 20, PALETTE["white"])
    c.line([(74, 158), (176, 158)], rgba(PALETTE["sky"], 160), 4)
    c.save(path, INK, 5)


def prop_cup(path):
    c = Cv((150, 190))
    body = [(36, 50), (114, 50), (104, 172), (46, 172)]
    c.poly(body, PALETTE["sky"])
    c.poly([(42, 84), (108, 84), (100, 168), (50, 168)], PALETTE["water"])
    c.ellipse((36, 40, 114, 62), "#E8F7FD", PALETTE["sky_d"], 4)
    c.ellipse((42, 46, 108, 58), PALETTE["water"])
    c.rrect((54, 66, 66, 140), 6, rgba("#FFFFFF", 140))
    c.ellipse((46, 162, 104, 182), None, PALETTE["sky_d"], 4)
    c.arc((52, 152, 98, 178), 20, 160, rgba("#FFFFFF", 160), 5)
    c.save(path, INK, 5)


def prop_toothbrush(path):
    c = Cv((130, 270))
    c.rrect((50, 66, 80, 258), 14, PALETTE["coral"])
    c.rrect((54, 148, 76, 206), 10, rgba("#FFFFFF", 110))
    c.rrect((42, 26, 88, 88), 20, PALETTE["white"])
    for i in range(5):
        x = 46 + i * 8
        c.rrect((x, 18, x + 5, 42), 3, PALETTE["sky_d"])
    c.ellipse((46, 60, 84, 92), None, PALETTE["sky"], 4)
    c.save(path, INK, 5)


def prop_towel(path):
    c = Cv((220, 220))
    c.rrect((24, 28, 196, 198), 18, PALETTE["pink"])
    c.rect((24, 62, 196, 74), PALETTE["pink_d"])
    c.rect((24, 92, 196, 100), lighten(PALETTE["pink"], 0.3))
    c.rect((24, 118, 196, 158), PALETTE["pink_d"])
    c.rrect((24, 158, 196, 198), 18, PALETTE["pink"])
    c.rrect((92, 8, 128, 44), 10, PALETTE["pink_d"])
    c.rrect((92, 8, 128, 44), 10, None, darken(PALETTE["pink_d"], 0.1), 3)
    # 褶皱纹
    for y in (78, 108, 176):
        c.line([(40, y), (180, y)], rgba("#FFFFFF", 90), 3)
    c.save(path, INK, 5)


def prop_shirt(path):
    c = Cv((240, 250))
    body = [(80, 20), (160, 20), (228, 78), (200, 122), (176, 106),
            (176, 232), (64, 232), (64, 106), (40, 122), (12, 78)]
    c.poly(body, PALETTE["blue"])
    # 袖子装饰
    c.poly([(12, 78), (40, 122), (58, 110), (34, 66)], PALETTE["blue_l"])
    c.poly([(228, 78), (200, 122), (182, 110), (206, 66)], PALETTE["blue_l"])
    # V 领
    c.poly([(96, 22), (120, 60), (144, 22)], PALETTE["white"])
    c.poly([(104, 15), (120, 44), (136, 15)], PALETTE["cream"])
    # 口袋
    c.rrect((92, 140, 132, 176), 8, PALETTE["blue_l"])
    # 下摆
    c.rect((64, 216, 176, 232), PALETTE["blue_l"])
    c.save(path, INK, 5)


def prop_pants(path):
    """裤子：同色长裤，腰头 + 双腿，透明裤裆"""
    c = Cv((190, 260))
    main = "#5B8DD9"
    dark = "#4A76B8"
    # 双腿（先画，裤裆自然镂空）
    c.rrect((38, 96, 90, 250), 16, main)
    c.rrect((100, 96, 152, 250), 16, main)
    # 裤腰 + 臀部
    c.rrect((30, 18, 160, 128), 22, main)
    c.rect((30, 40, 160, 54), dark)
    # 裤线
    c.line([(64, 140), (64, 236)], rgba("#FFFFFF", 70), 3)
    c.line([(126, 140), (126, 236)], rgba("#FFFFFF", 70), 3)
    # 口袋
    c.arc((44, 60, 78, 92), 180, 300, dark, 4)
    c.arc((112, 60, 146, 92), 240, 360, dark, 4)
    c.save(path, INK, 5)


def prop_shoes(path):
    """运动鞋：左右脚同款同色、镜像成对"""
    c = Cv((250, 160))

    def sneaker(dx, dy):
        main = PALETTE["coral"]
        lite = lighten(main, 0.22)
        # 鞋底
        c.rrect((16 + dx, 112 + dy, 138 + dx, 148 + dy), 16, PALETTE["white"])
        c.rrect((16 + dx, 136 + dy, 138 + dx, 150 + dy), 8, darken(PALETTE["white"], 0.14))
        # 鞋身
        c.poly([(28 + dx, 116 + dy), (44 + dx, 62 + dy), (96 + dx, 56 + dy),
                (124 + dx, 84 + dy), (138 + dx, 112 + dy)], main)
        # 鞋头
        c.ellipse((106 + dx, 88 + dy, 148 + dx, 124 + dy), lite)
        # 鞋带
        for i in range(3):
            y = 74 + i * 12 + dy
            c.line([(58 + dx, y), (92 + dx, y - 4)], PALETTE["white"], 5)
        # 鞋口
        c.arc((54 + dx, 44 + dy, 104 + dx, 78 + dy), 185, 355, PALETTE["white"], 6)

    sneaker(0, 14)   # 后脚（左脚）
    sneaker(108, 0)  # 前脚（右脚），同款同色
    c.save(path, INK, 5)


def char_kid(path):
    """主角小孩（常驻舞台）：站姿，成功后由导演驱动动作动画"""
    c = Cv((200, 380))
    skin = "#FFD9B3"
    hair = "#5C4033"
    shirt_c = "#FF8E7A"
    pants_c = "#5B8DD9"
    # 腿（裤子）
    c.rrect((74, 240, 96, 330), 12, pants_c)
    c.rrect((104, 240, 126, 330), 12, pants_c)
    # 脚
    c.ellipse((66, 322, 102, 350), "#FFFFFF")
    c.ellipse((98, 322, 134, 350), "#FFFFFF")
    # 手臂（短袖 + 手）
    c.rrect((44, 144, 66, 206), 11, shirt_c)
    c.rrect((46, 198, 64, 234), 10, skin)
    c.rrect((134, 144, 156, 206), 11, shirt_c)
    c.rrect((136, 198, 154, 234), 10, skin)
    # 身体
    c.rrect((62, 128, 138, 252), 22, shirt_c)
    c.rect((62, 214, 138, 226), lighten(shirt_c, 0.25))
    # 头
    c.ellipse((62, 16, 138, 94), skin)
    # 头发（头顶 + 刘海）
    c.pieslice((60, 12, 140, 92), 180, 360, hair)
    c.rrect((78, 26, 96, 44), 8, hair)
    c.rrect((104, 26, 122, 44), 8, hair)
    # 表情
    c.ellipse((80, 50, 90, 62), INK)
    c.ellipse((110, 50, 120, 62), INK)
    c.ellipse((80, 52, 86, 58), "#FFFFFF")
    c.ellipse((110, 52, 116, 58), "#FFFFFF")
    c.arc((86, 62, 114, 82), 20, 160, INK, 3)
    c.ellipse((68, 62, 80, 72), rgba(PALETTE["pink"], 190))
    c.ellipse((120, 62, 132, 72), rgba(PALETTE["pink"], 190))
    c.save(path, INK, 5)


# --------------------------------------------------------------------------
# UI
# --------------------------------------------------------------------------
def ui_ghost_hand(path):
    c = Cv((150, 150))
    white = PALETTE["white"]
    # 袖口
    c.rrect((44, 2, 106, 44), 14, "#E4ECF7")
    c.rrect((44, 2, 106, 44), 14, None, "#C6D4E8", 3)
    # 手掌
    c.rrect((38, 30, 112, 100), 26, white)
    # 食指（朝下指引）
    c.rrect((72, 78, 100, 140), 14, white)
    c.rrect((74, 118, 98, 140), 12, "#FFF0D6")
    # 拇指
    c.ellipse((26, 46, 54, 92), white)
    c.ellipse((96, 52, 120, 86), white)
    c.save(path, INK, 5)


def ui_glow_ring(path):
    size = 512
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    # 外圈柔光：由外向内叠加同心圆
    for i in range(46, 0, -1):
        r = size / 2 * (i / 46.0)
        a = int(6 + 26 * (1 - i / 46.0) ** 2)
        d.ellipse((size / 2 - r, size / 2 - r, size / 2 + r, size / 2 + r),
                  fill=(255, 255, 255, a))
    # 明确的高光环
    for w, a in ((9, 90), (5, 150)):
        d.ellipse((36, 36, size - 36, size - 36), outline=(255, 255, 255, a), width=w)
    img = img.filter(ImageFilter.GaussianBlur(2))
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.save(path)
    print("  ->", path)


def ui_star(path):
    import math
    c = Cv((128, 128))
    pts = []
    for i in range(10):
        ang = -math.pi / 2 + i * math.pi / 5
        r = 60 if i % 2 == 0 else 26
        pts.append((64 + r * math.cos(ang), 64 + r * math.sin(ang)))
    c.poly(pts, PALETTE["sun"])
    c.save(path, INK, 4)


# --------------------------------------------------------------------------
# 场景
# --------------------------------------------------------------------------
def bg_bedroom(path):
    c = Cv((1280, 720))
    draw_room(c, "#D8E9F7", "#F2D9B8", "#C9DBEA", "#F8E6C9")
    draw_window(c, (86, 78, 356, 330))
    draw_shelf(c, (880, 250, 1120, 264), PALETTE["wood"],
               [PALETTE["mint"], PALETTE["sun"], PALETTE["coral"]])
    draw_plant(c, 1180, 430, PALETTE["coral"], PALETTE["green"])
    c.save(path)


def bg_living(path):
    """客厅：沙发 + 壁挂电视 + 绿植（喝水场景）"""
    c = Cv((1280, 720))
    draw_room(c, "#E7EFE0", "#E8CFA9", "#D2DEC6", "#F4E9CF")
    # 壁挂电视
    c.rrect((430, 150, 620, 280), 14, "#4A3F55")
    c.rrect((444, 162, 606, 268), 8, "#9ED3E8")
    c.rect((444, 162, 606, 200), "#BFE3F2")
    c.rrect((510, 280, 540, 434), 6, "#4A3F55")
    # 沙发
    c.rrect((860, 250, 1180, 434), 26, PALETTE["mint"])
    c.rrect((884, 274, 1010, 380), 20, lighten(PALETTE["mint"], 0.12))
    c.rrect((1030, 274, 1156, 380), 20, lighten(PALETTE["mint"], 0.12))
    c.rrect((842, 300, 886, 434), 18, PALETTE["mint_d"])
    c.rrect((1154, 300, 1198, 434), 18, PALETTE["mint_d"])
    # 沙发抱枕
    c.rrect((920, 300, 990, 368), 16, PALETTE["sun"])
    c.rrect((1070, 300, 1140, 368), 16, PALETTE["coral"])
    draw_window(c, (80, 60, 320, 240))
    draw_plant(c, 340, 434, PALETTE["coral"], PALETTE["green"])
    c.save(path)


def bg_bathroom(path):
    c = Cv((1280, 720))
    draw_room(c, "#DFF2EC", "#DDE9EC", "#BFDCD4", "#E8F4F0")
    draw_tiles(c, (0, 196, 1280, 404), "#EFF9F6", "#D6EAE4")
    draw_mirror(c, 200, 190, 190, 220, PALETTE["white"], PALETTE["sky"])
    draw_shelf(c, (900, 262, 1140, 276), PALETTE["white"],
               [PALETTE["mint"], PALETTE["sun"]])
    draw_plant(c, 1180, 430, PALETTE["mint_d"], PALETTE["green"])
    c.save(path)


def bg_wardrobe(path):
    c = Cv((1280, 720))
    draw_room(c, "#E6E0F5", "#DCC9B4", "#D3C9EC", "#EFE8FA")
    draw_door(c, (820, 96, 1080, 412), PALETTE["wood"], PALETTE["sun"])
    draw_door(c, (1080, 96, 1240, 412), PALETTE["wood"], PALETTE["sun"])
    draw_window(c, (80, 92, 320, 300))
    c.save(path)


def bg_entry(path):
    c = Cv((1280, 720))
    draw_room(c, "#FBE9D6", "#E3C6A3", "#EFD6B8", "#F8E7CE")
    draw_door(c, (860, 60, 1100, 432), PALETTE["mint_d"], PALETTE["sun"])
    draw_hooks(c, 170, PALETTE["wood_d"])
    draw_window(c, (70, 120, 250, 320))
    c.save(path)


# --------------------------------------------------------------------------
def main():
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    bgs = os.path.join(root, "assets", "bgs")
    props = os.path.join(root, "assets", "props")
    ui = os.path.join(root, "assets", "ui")
    chars = os.path.join(root, "assets", "characters")

    print("[art] 生成角色…")
    char_kid(os.path.join(chars, "kid.png"))

    print("[art] 生成道具…")
    prop_bed(os.path.join(props, "prop_bed.png"))
    prop_cup(os.path.join(props, "prop_cup.png"))
    prop_toothbrush(os.path.join(props, "prop_toothbrush.png"))
    prop_towel(os.path.join(props, "prop_towel.png"))
    prop_shirt(os.path.join(props, "prop_shirt.png"))
    prop_pants(os.path.join(props, "prop_pants.png"))
    prop_shoes(os.path.join(props, "prop_shoes.png"))

    print("[art] 生成 UI…")
    ui_ghost_hand(os.path.join(ui, "ghost_hand.png"))
    ui_glow_ring(os.path.join(ui, "glow_ring.png"))
    ui_star(os.path.join(ui, "star.png"))

    print("[art] 生成背景…")
    bg_bedroom(os.path.join(bgs, "bg_bedroom.png"))
    bg_living(os.path.join(bgs, "bg_living.png"))
    bg_bathroom(os.path.join(bgs, "bg_bathroom.png"))
    bg_entry(os.path.join(bgs, "bg_entry.png"))
    print("[art] done.")


if __name__ == "__main__":
    main()
