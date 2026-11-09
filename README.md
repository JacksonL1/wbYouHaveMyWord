# You Have My Word · 魔法单词本

4-6 岁儿童英语启蒙 · **拖拽配对**互动游戏 MVP（Godot 4.x / GDScript）。

孩子从屏幕底部的「魔法单词本」里，把单词卡片拖到画面中央的道具上：

- **拖对** → 道具变绿 + 成功音效 + 1.5s 后自动进入下一关
- **拖错** → 道具变红抖动 + 提示音效，不惩罚，继续尝试
- **10 秒没操作** → 「幽灵小手」自动飞到正确卡片上方循环弹跳引导（零挫败感状态机）

MVP 剧本：**The Morning Routine** —— 起床 → 喝水 → 刷牙 → 洗脸 → 穿衣 → 穿鞋，共 6 关。

---

## 快速开始（三选一）

- **最简单**：双击根目录的 **`启动游戏.bat`** —— Godot 引擎已内置在 `_engine/`，什么都不用装
- **想改内容**：双击 `启动编辑器.bat` 打开 Godot 编辑器，按 `F5` 运行
- **自带引擎**：安装 [Godot 4.3+ 标准版](https://godotengine.org/download) → Import 本目录的 `project.godot` → `F5`

> 视口 1280x720（16:9），`canvas_items` 拉伸自动适配平板/窗口大小。
> `_engine/` 是本地运行时（约 130MB，已加入 .gitignore 不入库）；若删除它，`启动游戏.bat` 会提示需要放回 `Godot_v4.3-stable_win64.exe`。

## 目录结构（4 层解耦架构）

| 目录 | 定位 | 内容 |
| --- | --- | --- |
| `res://assets/` | 美术与音频资产池 | `bgs/` 背景、`props/` 道具贴纸、`ui/` UI 元素、`audio/vo/` 配音、`audio/sfx/` 音效 |
| `res://data/` | 配置数据层 | `story.json` 每一关的背景、道具、所需卡片、卡片列表 |
| `res://scenes/` | 预制体 | `Main.tscn`（导演）、`Prop.tscn`（道具+接收区）、`BinderUI.tscn`（单词本）、`WordCard.tscn`（卡片）、`EndScreen.tscn`（结算） |
| `res://core/` | 核心逻辑 | `Main.gd`、`BaseProp.gd`、`WordCard.gd`、`BinderUI.gd`、`AudioManager.gd`、`EndScreen.gd` |

核心脚本职责：

- **`WordCard.gd`**（拖拽发起端）：`_get_drag_data` 生成带半透明残影的拖拽数据，拖起瞬间即发音
- **`BaseProp.gd`**（拖拽接收端，挂在 Control 上）：`_can_drop_data` / `_drop_data` 校验 `card_id`，热区 = 道具尺寸 × 1.3；匹配结果通过 `matched` / `mismatched` 自定义信号广播，并修改 `$/Sprite2D` 颜色
- **`Main.gd`**（全局导演）：读取 `story.json` 驱动关卡；监听过关信号切关；`Timer` 10s 超时后用 `Tween` 把 `GhostHand` 移到正确卡片上方循环弹跳；拖错 / 进关即重置计时并隐藏小手

## story.json 数据契约

```json
{
  "id": "brush",
  "title": "刷牙",
  "req_card": "card_brush",                  // 通关所需卡片 id
  "bg_img": "res://assets/bgs/bg_bathroom.png",
  "prop_img": "res://assets/props/prop_toothbrush.png",
  "prop_y": 365,                             // 道具中心 Y（底部对齐地面光斑 GROUND_Y=500）
  "prop_scale": 1.0,
  "cards": [                                 // 本关出题卡片（含干扰项，进关时自动洗牌）
    { "id": "card_brush", "text": "Brush", "img": "...", "vo": "brush" }
  ]
}
```

加新关卡 = 往数组里加一项 + 放一张背景图 + 放一张道具图（`tools/gen_art.py` 里加一个绘制函数即可）。

## 资产再生成（生产工具链）

```bash
python tools/gen_art.py    # 程序化生成 MVP 占位美术（扁平贴纸风，无需任何在线服务）
python tools/gen_sfx.py    # 纯标准库合成 4 个音效 WAV
python tools/gen_vo.py     # edge-tts 生成单词配音 MP3（en-US-AnaNeural 儿童音色）
```

正式版美术替换：用 Midjourney / 豆包按
`flat 2D game asset, cartoon style for kids, solid white background`
出图 → 抠图 → 覆盖 `assets/props/*.png` / `assets/bgs/*.png` 即可，**代码与数据无需任何改动**。

## 验证清单（手工测试脚本）

- [ ] 6 关全部可通，通关后出现结算页，`再玩一次` 可重开
- [ ] 拖动卡片有半透明残影，且拖起瞬间朗读单词
- [ ] 拖错：道具变红抖动 + 错误音效；拖对：变绿 + 成功音效 + 1.5s 进下一关
- [ ] 停留 10 秒不动：小手飞到正确卡片上方弹跳；一操作立即消失
- [ ] 悬停道具时有光圈反馈（正确卡绿色 / 错误卡橙色）
- [ ] 左上角中文标题 + 进度圆点随关卡推进点亮；右上角「声音」可静音

## 自动化测试（已验证 19/19 通过）

```bash
# 逻辑冒烟测试（headless，无需显示器）：story 加载 / 卡片装配 / 拖错反馈 /
# 拖对过关 / 幽灵小手提示 / 通关结算 / 重开，共 19 项断言
Godot_console.exe --headless --path . res://tools/SmokeTest.tscn

# 渲染截图自检：抓取第 1 关与小手提示两帧存到 .preview/
Godot_console.exe --path . res://tools/ScreenshotTool.tscn
```

