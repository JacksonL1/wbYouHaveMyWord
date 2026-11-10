# You Have My Word · 魔法单词本

4-6 岁儿童英语启蒙 · **拖拽配对 + 小人情景动画**互动游戏（Godot 4.3 / GDScript）。

孩子从屏幕底部的「魔法单词本」里，把单词卡片拖到画面中央的道具上，同时画面里的小人会**做出对应动作**并配有整句英文情境配音：

- **拖对** → 道具变绿 + 成功音效 + 小人完成动作（起床 / 喝水 / 刷牙 / 洗脸 / 穿衣 / 穿鞋）+ 通关台词
- **拖错** → 道具变红抖动 + 小人轻轻摇头，不惩罚，继续尝试
- **10 秒没操作** → 「幽灵小手」自动飞到正确卡片上方循环弹跳 + 超时提示语音
- **关卡进行中** → 情境台词轮换播放（刷牙时每 3.6s 一句 "Brush left / Brush right / Brush, brush!"）

剧本 **The Morning Routine**：起床 → 喝水 → 刷牙 → 洗脸 → 穿衣 → 穿鞋 → 门前自检清单，共 **7 关**。

---

## 快速开始（三选一）

- **最简单**：双击根目录的 **`启动游戏.bat`** —— Godot 引擎已内置在 `_engine/`，什么都不用装
- **想改内容**：双击 `启动编辑器.bat` 打开 Godot 编辑器，按 `F5` 运行
- **自带引擎**：安装 [Godot 4.3+ 标准版](https://godotengine.org/download) → Import 本目录的 `project.godot` → `F5`

> 视口 1280x720（16:9），`canvas_items` 拉伸自动适配平板/窗口大小。
> `_engine/` 是本地运行时（约 130MB，已加入 .gitignore 不入库，且超过 GitHub 单文件 100MB 限制）。

## 小人动画系统（`core/Character.gd`）

小人不是逐帧精灵表，而是**分部件 + Node2D 层级 + Tween** 的骨骼式动画，任意姿态都能平滑过渡：

| 关卡 | 动画 |
|---|---|
| 起床 | 躺着闭眼 + Zzz → 撑起上身 → 睁眼 → 伸懒腰 → 站到床边小跳（约 2.9s） |
| 喝水 | 举杯循环 → 通关时送到嘴边「咕咚」 |
| **刷牙** | **右臂在嘴边左右「刷刷」摆动 + 身体轻晃 + 白色泡泡上浮 + 循环刷刷音效** |
| 洗脸 | 拿毛巾左右擦脸 + 泡泡 + 水花音效 |
| 穿衣 | 举衣服 → 换成蓝色 T 恤（之后关卡持续穿着）+ sparkle |
| 穿鞋 | 蹲下穿上红色运动鞋 + 原地踏两下 |
| 清单 | 缩小站到画面下方中央挥手，通关 high-five |

另有全局细节：站立呼吸起伏、拖错摇头、四张可切换表情（清醒 / 闭眼 / 刷牙 / 大笑）。

姿态约定：根节点原点 = 脚底；躺下 `rotation = -90° + (760, 390)`（头正好落在枕头上），站立 `(330, 500)`（床左侧，不遮挡中央拖拽热区）。

## 音频系统

| 类型 | 内容 | 位置 |
|---|---|---|
| 单词配音 | 6 个单词（拖起卡片瞬间朗读） | `assets/audio/vo/*.mp3` |
| **情境配音** | **36 条整句台词**，进关 / 动作 / 通关 / 超时 / 拖错 / 5 个徽章 | `data/voice_lines.json` → `assets/audio/vo/vo_*.mp3` |
| 动作音效 | 刷刷循环、咕咚、水花、咔、叮咚、击掌 | `assets/audio/sfx/*.wav` |
| 背景音乐 | 8 秒轻柔晨间循环（-20dB 铺底） | `assets/audio/sfx/bgm_morning.wav` |

情境台词按用户剧本逐条指定语速（低龄句 `-15%`、短提示 `+0%`、收尾 `+5%`），用 `en-US-AnaNeural` 儿童音色合成，失败自动回退 `en-US-JennyNeural`。

`AudioManager.gd` 分四路：VO 单通道（新的打断旧的）、SFX 四通道轮询（可叠音）、LOOP 单通道（WAV 运行时开启 `LOOP_FORWARD`，无缝刷刷）、BGM 单通道。右上「声音」按钮一次静音全部。

## 目录结构（4 层解耦架构）

| 目录 | 定位 | 内容 |
|---|---|--- |
| `assets/` | 美术与音频资产池 | `bgs/`、`props/`、`ui/`、`character/`（小人部件）、`audio/vo/`、`audio/sfx/` |
| `data/` | 配置数据层 | `story.json`（7 关配置 + vo 映射）、`voice_lines.json`（台词表） |
| `scenes/` | 预制体 | `Main.tscn`、`Prop.tscn`、`BinderUI.tscn`、`WordCard.tscn`、`EndScreen.tscn`、`Character.tscn`、`ChecklistUI.tscn` |
| `core/` | 核心逻辑 | `Main.gd`（导演）、`Character.gd`（动画）、`ChecklistUI.gd`（清单）、`BaseProp.gd`、`WordCard.gd`、`BinderUI.gd`、`AudioManager.gd`、`EndScreen.gd` |

> `Character.tscn` / `ChecklistUI.tscn` 只放根节点，子节点在 `_ready()` 里代码构建 —— 避免手写十几个 `ext_resource` 造成错位，改布局只需改代码。

## story.json 数据契约

```json
{
  "id": "brush",
  "title": "刷牙",
  "req_card": "card_brush",
  "bg_img": "res://assets/bgs/bg_bathroom.png",
  "prop_img": "res://assets/props/prop_toothbrush.png",
  "prop_y": 365,
  "vo": {
    "intro":   "vo_act2_intro",                                  // 进关（延迟 0.55s）
    "action":  ["vo_act2_brush_l","vo_act2_brush_r","vo_act2_brush_all"], // 轮换背景提示
    "done":    "vo_act2_done",                                   // 通关
    "timeout": "vo_timeout_act2",                                // 10s 空闲
    "wrong":   "vo_act4_wrong"                                   // 仅穿衣关有
  },
  "action_interval": 3.6,        // 动作台词轮换间隔（秒）
  "loop_sfx": "brush_swish",     // 可选的循环环境音
  "success_sfx": "splash",       // 可选的通关音效
  "cards": [ ... ]
}
```

第 7 关用 `"kind": "checklist"` 标记，走徽章点击流程而非拖拽；`badge_vo` 数组顺序对应 5 个徽章。

## 资产再生成（生产工具链）

```bash
python tools/gen_art.py          # 程序化生成背景 / 道具 / UI 贴纸
python tools/gen_character.py    # 生成小人部件 PNG（复用 gen_art 的贴纸风绘制器）
python tools/gen_sfx.py          # 纯标准库合成 4 个基础音效 WAV
python tools/gen_sfx_extra.py    # 刷刷循环 / 咕咚 / 水花 / 叮咚 / 击掌 / 8s BGM
python tools/gen_vo.py           # edge-tts 生成 6 个单词配音
python tools/gen_vo_lines.py     # edge-tts 批量生成 36 条情境台词（4 路并发、幂等）
# 新增资源后务必让 Godot 导入一次：
# Godot_console.exe --headless --path . --import
```

正式版美术替换：用 Midjourney / 豆包按
`flat 2D game asset, cartoon style for kids, solid white background`
出图 → 抠图 → 覆盖 `assets/props/*.png` / `assets/bgs/*.png` / `assets/character/*.png` 即可，**代码与数据无需改动**。

## 验证清单

- [ ] 7 关全部可通，清单 5 个徽章按顺序点亮，通关后出现结算页，`再玩一次` 可重开
- [ ] 第 1 关小人躺在床上闭眼 + Zzz，拖对后慢慢起身站好
- [ ] 刷牙关小人持续「刷刷」摆臂 + 泡泡 + 循环刷刷声，能听到 3 句轮换台词
- [ ] 穿衣后小人换成蓝 T 恤、穿鞋后穿上红鞋，后续关卡保持
- [ ] 拖动卡片有半透明残影，且拖起瞬间朗读单词
- [ ] 拖错：道具变红抖动 + 小人摇头；拖对：变绿 + 通关台词
- [ ] 停留 10 秒不动：小手 / 发光徽章 + 超时语音
- [ ] 右上角「声音」可一次静音全部音轨

## 自动化测试（已验证 27/27 通过）

```bash
# 逻辑冒烟（headless）：story 加载 / 小人初始姿态 / 卡片装配 / 拖错反馈 /
# 拖对过关 / 起床动画 / 情境配音配置 / 幽灵小手 / 自检清单 / 结算 / 重开
Godot_console.exe --headless --path . res://tools/SmokeTest.tscn

# 渲染取帧：抓起床躺/坐/站、刷牙、换装、清单共 6 帧到 .preview/anim_*.png
Godot_console.exe --path . res://tools/AnimationPreview.tscn
```
