extends Node2D
## 全局导演脚本（Main）
##
## 职责：
##   1. 读取 data/story.json，按数据驱动的方式搭建每一关（背景 / 道具 / 卡片）；
##   2. 监听道具接收器的 matched / mismatched 信号，驱动关卡流转；
##   3. 维护 10 秒空闲计时器 + 幽灵小手提示（零挫败感状态机）。
##
## 状态机：
##   PLAYING  —— 可拖拽，计时器运行
##   LOCKED   —— 本关已匹配成功，播放 1.5s 反馈后进入下一关
##   FINISHED —— 全流程完成，显示结算页

const STORY_PATH := "res://data/story.json"
const PROP_SCENE := preload("res://scenes/Prop.tscn")

## 空闲多久后触发提示（秒）
const HINT_DELAY := 10.0
## 匹配成功后停留多久再进下一关（秒）
const MATCH_DELAY := 1.5
## 舞台中心（道具锚点 X）
const STAGE_X := 640.0

enum State { PLAYING, LOCKED, FINISHED }

@onready var _bg: TextureRect = $Background
@onready var _prop_layer: Node2D = $PropLayer
@onready var _binder = $BinderUI          # BinderUI（CanvasLayer，动态访问其接口）
@onready var _idle_timer: Timer = $IdleTimer
@onready var _end_screen = $EndScreen     # EndScreen（CanvasLayer，动态访问其接口）

var _levels: Array = []
var _index := 0
var _state: State = State.FINISHED
var _prop: Node2D = null
var _drop_zone: BaseProp = null


func _ready() -> void:
	_load_story()
	if _levels.is_empty():
		push_error("story.json 为空或解析失败，无法启动关卡。")
		return

	_idle_timer.one_shot = true
	_idle_timer.wait_time = HINT_DELAY
	_idle_timer.timeout.connect(_on_idle_timeout)
	_binder.card_drag_started.connect(_on_card_drag_started)
	_end_screen.restart_pressed.connect(_on_restart_requested)

	_start_level(0)


## 任意有效点击都重置空闲计时（孩子注意力分散后的宽容处理）
func _input(event: InputEvent) -> void:
	if _state != State.PLAYING:
		return
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		_restart_idle_timer()
	elif event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		_restart_idle_timer()


# --------------------------------------------------------------------------
# 数据层
# --------------------------------------------------------------------------
func _load_story() -> void:
	if not FileAccess.file_exists(STORY_PATH):
		push_error("找不到剧本文件：%s" % STORY_PATH)
		return
	var text := FileAccess.get_file_as_string(STORY_PATH)
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_ARRAY:
		push_error("story.json 解析失败：顶层必须是数组。")
		return
	_levels = parsed as Array


func _current_level() -> Dictionary:
	if _index < 0 or _index >= _levels.size():
		return {}
	return _levels[_index] as Dictionary


# --------------------------------------------------------------------------
# 关卡装配
# --------------------------------------------------------------------------
func _start_level(level_index: int) -> void:
	_index = level_index
	var level := _current_level()
	if level.is_empty():
		_finish()
		return

	_clear_stage()
	_apply_background(str(level.get("bg_img", "")))
	_spawn_prop(level)
	_binder.setup_level(level, _index, _levels.size())
	_binder.set_interactive(true)

	_state = State.PLAYING
	_restart_idle_timer()
	_binder.hide_ghost()


func _clear_stage() -> void:
	if _prop and is_instance_valid(_prop):
		_prop_layer.remove_child(_prop)
		_prop.queue_free()
	_prop = null
	_drop_zone = null


func _apply_background(path: String) -> void:
	if path.is_empty() or not ResourceLoader.exists(path):
		return
	_bg.texture = load(path)
	_bg.modulate.a = 0.0
	var t := create_tween()
	t.tween_property(_bg, "modulate:a", 1.0, 0.4)


func _spawn_prop(level: Dictionary) -> void:
	var prop := PROP_SCENE.instantiate() as Node2D
	var sprite := prop.get_node("Sprite2D") as Sprite2D

	var img_path := str(level.get("prop_img", ""))
	if not img_path.is_empty() and ResourceLoader.exists(img_path):
		sprite.texture = load(img_path)

	var prop_scale := float(level.get("prop_scale", 1.0))
	var target_scale := Vector2.ONE * prop_scale
	prop.position = Vector2(STAGE_X, float(level.get("prop_y", 372)))
	prop.scale = target_scale

	var zone := prop.get_node("DropZone") as BaseProp
	zone.prop_id = str(level.get("id", ""))
	zone.required_card = str(level.get("req_card", ""))
	zone.matched.connect(_on_prop_matched)
	zone.mismatched.connect(_on_prop_mismatched)

	_prop_layer.add_child(prop)
	_prop = prop
	_drop_zone = zone
	_play_prop_entrance(prop, target_scale)


func _play_prop_entrance(prop: Node2D, target_scale: Vector2) -> void:
	prop.scale = target_scale * 0.86
	prop.modulate.a = 0.0
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(prop, "scale", target_scale, 0.38) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(prop, "modulate:a", 1.0, 0.26)


# --------------------------------------------------------------------------
# 接收器信号
# --------------------------------------------------------------------------
func _on_prop_matched(_prop_id: String, card_id: String) -> void:
	if _state != State.PLAYING:
		return
	_state = State.LOCKED
	_idle_timer.stop()
	_binder.hide_ghost()
	_binder.set_interactive(false)
	_binder.play_correct_feedback(card_id)
	AudioManager.play_sfx("success")
	# 成功后再次朗读目标单词，强化「动作-单词」绑定
	var card = _binder.get_card(card_id)
	if card:
		AudioManager.play_vo(card.vo_stem)

	await get_tree().create_timer(MATCH_DELAY).timeout
	if not is_inside_tree():
		return
	_advance()


func _on_prop_mismatched(_prop_id: String, _card_id: String) -> void:
	if _state != State.PLAYING:
		return
	AudioManager.play_sfx("error")
	# 拖错不惩罚、不锁关卡，只重置计时器继续等待
	_restart_idle_timer()


func _advance() -> void:
	if _index + 1 >= _levels.size():
		_finish()
	else:
		_start_level(_index + 1)


func _finish() -> void:
	_state = State.FINISHED
	_idle_timer.stop()
	_binder.hide_ghost()
	_binder.set_interactive(false)
	AudioManager.play_sfx("level")
	_end_screen.show_result(_levels.size())


func _on_restart_requested() -> void:
	_end_screen.visible = false
	_start_level(0)


# --------------------------------------------------------------------------
# 零挫败感：空闲提示
# --------------------------------------------------------------------------
func _restart_idle_timer() -> void:
	if _state != State.PLAYING:
		return
	_idle_timer.start(HINT_DELAY)


func _on_card_drag_started(_card_id: String) -> void:
	# 孩子开始操作 → 直接重置计时，隐藏提示，不打断他
	_binder.hide_ghost()
	_restart_idle_timer()


func _on_idle_timeout() -> void:
	if _state != State.PLAYING:
		return
	var level := _current_level()
	var req := str(level.get("req_card", ""))
	if req.is_empty():
		return
	_binder.show_ghost(req)
	AudioManager.play_sfx("tap")
