extends Node2D
## 全局导演脚本（Main）
##
## 职责：
##   1. 读取 data/story.json，按数据驱动的方式搭建每一关（背景 / 道具 / 卡片 / 小人）；
##   2. 监听道具接收器与清单徽章的信号，驱动关卡流转；
##   3. 播放一次性情境配音（进关 intro / 通关 done / 超时 timeout）与 BGM；
##   4. 支持关卡间插入过场视频（video_before / video_after）；
##   5. 维护 10 秒空闲计时器 + 幽灵小手提示（零挫败感状态机）。
##
## 状态机：
##   PLAYING  —— 可操作，计时器运行
##   LOCKED   —— 本关已完成，播放反馈动画后进入下一关
##   CUTSCENE —— 过场动画播放中（关卡间可插入视频）
##   FINISHED —— 全流程完成，显示结算页

const STORY_PATH := "res://data/story.json"
const PROP_SCENE := preload("res://scenes/Prop.tscn")

## 空闲多久后触发提示（秒）
const HINT_DELAY := 10.0
## 默认匹配成功后停留多久再进下一关（小人动画长的关卡会自行覆盖）
const MATCH_DELAY := 1.5
## 舞台中心（道具锚点 X）
const STAGE_X := 640.0
const CHECKLIST_KIND := "checklist"

enum State { PLAYING, LOCKED, CUTSCENE, FINISHED }

@onready var _bg: TextureRect = $Background
@onready var _prop_layer: Node2D = $PropLayer
@onready var _binder = $BinderUI
@onready var _idle_timer: Timer = $IdleTimer
@onready var _end_screen = $EndScreen
@onready var _character: Character = $Character
@onready var _checklist = $ChecklistUI
@onready var _cutscene = $Cutscene

var _levels: Array = []
var _index := 0
var _state: State = State.FINISHED
var _prop: Node2D = null
var _drop_zone: BaseProp = null
var _cutscene_next := ""   # "level_in" 过场后进关 / "level_out" 过场后切下一关


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
	_checklist.badge_tapped.connect(_on_badge_tapped)
	_checklist.finished.connect(_on_checklist_finished)
	_cutscene.finished.connect(_on_cutscene_finished)

	AudioManager.play_bgm()
	_start_level(0)


## 任意有效点击都重置空闲计时（孩子注意力分散后的宽容处理）
func _input(event: InputEvent) -> void:
	if _state != State.PLAYING:
		return
	if (event is InputEventMouseButton and (event as InputEventMouseButton).pressed) \
			or (event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed):
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


func _is_checklist(level: Dictionary) -> bool:
	return str(level.get("kind", "")) == CHECKLIST_KIND


func _vo(level: Dictionary, key: String) -> String:
	var raw: Variant = level.get("vo", {})
	if typeof(raw) != TYPE_DICTIONARY:
		return ""
	return str((raw as Dictionary).get(key, ""))


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
	AudioManager.stop_loop_sfx()
	_apply_background(str(level.get("bg_img", "")))
	_character.setup_for_level(str(level.get("id", "")))

	if _is_checklist(level):
		_checklist.start()
		_binder.setup_level(level, _index, _levels.size())
		_binder.set_card_panel_visible(false)
		_binder.set_interactive(false)
	else:
		_checklist.hide_all()
		_spawn_prop(level)
		_binder.setup_level(level, _index, _levels.size())
		_binder.set_card_panel_visible(true)
		_binder.set_interactive(true)
		var loop_sfx := str(level.get("loop_sfx", ""))
		if not loop_sfx.is_empty():
			AudioManager.start_loop_sfx(loop_sfx)

	_state = State.PLAYING
	_restart_idle_timer()
	_binder.hide_ghost()

	# 关卡间可插入过场视频（story.json 的 video_before / video_after 字段）
	var video_before := str(level.get("video_before", ""))
	if not video_before.is_empty() and ResourceLoader.exists(video_before):
		_state = State.CUTSCENE
		_binder.set_interactive(false)
		_cutscene_next = "level_in"
		_cutscene.play_video(video_before)
		return

	_play_vo_delayed(_vo(level, "intro"), 0.55)


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
# 情境配音
# --------------------------------------------------------------------------
## 延迟播放，且只在「仍停留在同一关」时才发声，避免切关后串音
func _play_vo_delayed(line: String, delay: float) -> void:
	if line.is_empty():
		return
	var idx := _index
	await get_tree().create_timer(delay).timeout
	if _index == idx and is_inside_tree():
		AudioManager.play_vo(line)


## 过场动画结束：回到本关（level_in）或进入下一关（level_out）
func _on_cutscene_finished() -> void:
	var level := _current_level()
	if _cutscene_next == "level_in":
		_state = State.PLAYING
		_binder.set_interactive(not _is_checklist(level))
		_restart_idle_timer()
		_play_vo_delayed(_vo(level, "intro"), 0.4)
	elif _cutscene_next == "level_out":
		_advance()
	_cutscene_next = ""


# --------------------------------------------------------------------------
# 接收器信号
# --------------------------------------------------------------------------
func _on_prop_matched(_prop_id: String, card_id: String) -> void:
	if _state != State.PLAYING:
		return
	_state = State.LOCKED
	_idle_timer.stop()
	AudioManager.stop_loop_sfx()
	_binder.hide_ghost()
	_binder.set_interactive(false)
	_binder.play_correct_feedback(card_id)
	AudioManager.play_sfx("success")

	var level := _current_level()
	var success_sfx := str(level.get("success_sfx", ""))
	if not success_sfx.is_empty():
		AudioManager.play_sfx(success_sfx)

	_character.play_success(str(level.get("id", "")))
	# 道具飞向小人并淡出（起床关的床保留在原地）
	if str(level.get("id", "")) != "wake":
		_dismiss_prop()
	_play_vo_delayed(_vo(level, "done"), 0.62)

	var hold: float = maxf(MATCH_DELAY, _character.get_success_hold())
	await get_tree().create_timer(hold).timeout
	if not is_inside_tree():
		return

	# 通关后可插入过场视频（如刷牙教学视频）
	var video_after := str(_current_level().get("video_after", ""))
	if not video_after.is_empty() and ResourceLoader.exists(video_after):
		_state = State.CUTSCENE
		_cutscene_next = "level_out"
		_cutscene.play_video(video_after)
	else:
		_advance()


## 道具飞向角色并淡出，把舞台留给通关动作动画
func _dismiss_prop() -> void:
	if _prop == null or not is_instance_valid(_prop):
		return
	var target: Vector2 = _character.position + Vector2(0, -150)
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(_prop, "position", target, 0.45) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(_prop, "scale", _prop.scale * 0.4, 0.45) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(_prop, "modulate:a", 0.0, 0.5)


func _on_prop_mismatched(_prop_id: String, _card_id: String) -> void:
	if _state != State.PLAYING:
		return
	AudioManager.play_sfx("error")
	_character.play_wrong()
	_play_vo_delayed(_vo(_current_level(), "wrong"), 0.3)
	# 拖错不惩罚、不锁关卡，只重置计时器继续等待
	_restart_idle_timer()

func _advance() -> void:
	if _index + 1 >= _levels.size():
		_finish()
	else:
		_start_level(_index + 1)


# --------------------------------------------------------------------------
# Act 6 · 门前自检清单
# --------------------------------------------------------------------------
func _on_badge_tapped(index: int) -> void:
	if _state != State.PLAYING:
		return
	AudioManager.play_sfx("sparkle")
	var list: Array = _current_level().get("badge_vo", [])
	if index >= 0 and index < list.size():
		AudioManager.play_vo(str(list[index]))
	_restart_idle_timer()


func _on_checklist_finished() -> void:
	if _state != State.PLAYING:
		return
	_state = State.LOCKED
	_idle_timer.stop()
	_character.play_success("checklist")
	AudioManager.play_sfx("highfive")
	_play_vo_delayed(_vo(_current_level(), "done"), 0.4)
	await get_tree().create_timer(2.3).timeout
	if not is_inside_tree():
		return
	_finish()


func _finish() -> void:
	_state = State.FINISHED
	_idle_timer.stop()
	AudioManager.stop_loop_sfx()
	_binder.hide_ghost()
	_binder.set_interactive(false)
	_checklist.hide_all()
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
	AudioManager.play_vo(_vo(level, "timeout"))
	if _is_checklist(level):
		_checklist.pulse_current()
		return
	var req := str(level.get("req_card", ""))
	if req.is_empty():
		return
	_binder.show_ghost(req)
	AudioManager.play_sfx("tap")
