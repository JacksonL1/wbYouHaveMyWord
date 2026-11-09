class_name WordCard
extends Control
## 单词卡片（拖拽发起端 / UI 层）
##
## 责任边界：
##   * 只负责「表现 + 拖拽发起 + 携带数据」，不做任何判定；
##   * 判定逻辑属于 BaseProp（接收端），关卡流转属于 Main（导演）。
##
## 数据契约（_get_drag_data 返回）：
##   { "card_id": String, "text": String, "source": WordCard }

signal drag_started(card_id: String)

const DRAG_ALPHA := 0.92
const TRAIL_ALPHA := 0.22
const TRAIL_OFFSET := Vector2(-14, 16)

@export var card_id: String = ""
@export var card_text: String = ""
@export var vo_stem: String = ""

@onready var _bg: Panel = $Bg
@onready var _icon: TextureRect = $Icon
@onready var _label: Label = $Label

var _data: Dictionary = {}
var _draggable := true
var _hover_tween: Tween

# 默认外观（用于高亮后还原）
var _base_border := Color(1, 1, 1, 1)
var _style: StyleBoxFlat


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	pivot_offset = size * 0.5
	var sb := _bg.get_theme_stylebox("panel")
	if sb is StyleBoxFlat:
		# 每张卡持有一份独立 StyleBox，避免高亮串色
		_style = sb.duplicate() as StyleBoxFlat
		_bg.add_theme_stylebox_override("panel", _style)
		_base_border = _style.border_color
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	_apply_data()


## 由 BinderUI 调用注入单卡配置
func setup(data: Dictionary) -> void:
	_data = data
	if is_node_ready():
		_apply_data()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		pivot_offset = size * 0.5


func set_draggable(value: bool) -> void:
	_draggable = value
	mouse_default_cursor_shape = Control.CURSOR_DRAG if value else Control.CURSOR_ARROW
	if not value:
		# 置灰但不动入场动画的透明度
		modulate.a = 0.55


# --------------------------------------------------------------------------
# 数据渲染
# --------------------------------------------------------------------------
func _apply_data() -> void:
	if _data.is_empty():
		return
	card_id = str(_data.get("id", ""))
	card_text = str(_data.get("text", card_id))
	vo_stem = str(_data.get("vo", ""))
	if vo_stem.is_empty():
		vo_stem = card_id.trim_prefix("card_")
	if _label:
		_label.text = card_text
	if _icon:
		var img_path := str(_data.get("img", ""))
		if not img_path.is_empty() and ResourceLoader.exists(img_path):
			_icon.texture = load(img_path)
	# 长单词自动缩字号，保证 4-6 岁孩子能看清
	if _label and card_text.length() > 7:
		_label.add_theme_font_size_override("font_size", 22)


# --------------------------------------------------------------------------
# 拖拽发起
# --------------------------------------------------------------------------
func _get_drag_data(_at_position: Vector2) -> Variant:
	if not _draggable or card_id.is_empty():
		return null

	# 拖起的瞬间就发音：让「词形-语音」在动作发生时即刻绑定
	AudioManager.play_vo(vo_stem)
	drag_started.emit(card_id)

	set_drag_preview(_build_drag_preview())
	_play_press_punch()

	return {
		"card_id": card_id,
		"text": card_text,
		"source": self,
	}


## 半透明残影：主卡 + 拖尾副本，制造「卡片被拎起来」的质感
func _build_drag_preview() -> Control:
	var wrapper := Control.new()
	wrapper.custom_minimum_size = size
	wrapper.size = size
	wrapper.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var trail := duplicate() as Control
	trail.name = "Trail"
	trail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	trail.position = TRAIL_OFFSET
	trail.modulate = Color(1, 1, 1, TRAIL_ALPHA)
	trail.scale = Vector2(0.96, 0.96)
	trail.pivot_offset = size * 0.5
	wrapper.add_child(trail)

	var main := duplicate() as Control
	main.name = "Ghost"
	main.mouse_filter = Control.MOUSE_FILTER_IGNORE
	main.modulate = Color(1, 1, 1, DRAG_ALPHA)
	main.rotation = deg_to_rad(-3.0)
	main.pivot_offset = size * 0.5
	wrapper.add_child(main)

	return wrapper


func _play_press_punch() -> void:
	if _hover_tween and _hover_tween.is_running():
		_hover_tween.kill()
	var t := create_tween()
	t.tween_property(self, "scale", Vector2(1.07, 1.07), 0.08).set_trans(Tween.TRANS_BACK)
	t.tween_property(self, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK)


# --------------------------------------------------------------------------
# 悬停反馈（儿童友好：轻微放大 + 边框发光）
# --------------------------------------------------------------------------
func _on_mouse_entered() -> void:
	if not _draggable:
		return
	_tween_scale(Vector2(1.05, 1.05))
	if _style:
		_style.set_border_color(Color("#FFD166"))


func _on_mouse_exited() -> void:
	_tween_scale(Vector2.ONE)
	if _style:
		_style.set_border_color(_base_border)


func _tween_scale(target: Vector2) -> void:
	if _hover_tween and _hover_tween.is_running():
		_hover_tween.kill()
	_hover_tween = create_tween()
	_hover_tween.tween_property(self, "scale", target, 0.12).set_trans(Tween.TRANS_SINE)


## 匹配成功时的庆祝小跳
func play_correct_feedback() -> void:
	if _hover_tween and _hover_tween.is_running():
		_hover_tween.kill()
	var t := create_tween()
	t.tween_property(self, "scale", Vector2(1.16, 1.16), 0.12).set_trans(Tween.TRANS_BACK)
	t.tween_property(self, "scale", Vector2.ONE, 0.24).set_trans(Tween.TRANS_BACK)
	if _style:
		_style.set_border_color(Color("#7FD48A"))


## 重置卡片高亮状态（进下一关时调用）
func reset_visual() -> void:
	scale = Vector2.ONE
	if _style:
		_style.set_border_color(_base_border)
