extends CanvasLayer
##
## Act 6 · 门前自检清单
## =====================
## 六个徽章排成 3x2 两行网格（放得下就放，放不下自动两行，不硬挤一行），
## 按顺序点亮（当前该点的会发光脉冲），点错不惩罚、不推进。
## 每点亮一个由 Main 播放对应的 vo_act6_badge_N，全部点亮后 emit finished。
##
## 外部接口：
##   start()            重置并显示清单，播放脉冲引导
##   pulse_current()    超时时加强当前徽章的发光（零挫败感提示）
##   hide_all()         隐藏并停止所有动画
##

signal badge_tapped(index: int)
signal finished

const BADGES := [
	{"en": "Water", "img": "res://assets/props/prop_cup.png"},
	{"en": "Teeth", "img": "res://assets/props/prop_toothbrush.png"},
	{"en": "Face", "img": "res://assets/props/prop_towel.png"},
	{"en": "Shirt", "img": "res://assets/props/prop_shirt.png"},
	{"en": "Pants", "img": "res://assets/props/prop_pants.png"},
	{"en": "Shoes", "img": "res://assets/props/prop_shoes.png"},
]

const CARD_SIZE := Vector2(190, 214)
const COLOR_OFF := Color(0.96, 0.94, 0.90, 1.0)
const COLOR_ON := Color(1.0, 0.86, 0.42, 1.0)
const BORDER_OFF := Color(0.80, 0.72, 0.62, 1.0)
const BORDER_ON := Color(0.98, 0.72, 0.22, 1.0)
const INK := Color(0.29, 0.24, 0.34, 1.0)

@onready var _root: Control = $Root
@onready var _row: GridContainer = $Root/Row
@onready var _hint: Label = $Root/Hint

var _buttons: Array[Button] = []
var _checks: Array[Label] = []
var _current := 0
var _pulse_tween: Tween
var _punch_tween: Tween


func _ready() -> void:
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	_root.visible = false


func _build() -> void:
	for i in BADGES.size():
		var data: Dictionary = BADGES[i]
		var btn := Button.new()
		btn.custom_minimum_size = CARD_SIZE
		btn.focus_mode = Control.FOCUS_NONE
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		_apply_style(btn, false)

		var icon := TextureRect.new()
		icon.position = Vector2(45, 22)
		icon.size = Vector2(100, 100)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if ResourceLoader.exists(str(data["img"])):
			icon.texture = load(str(data["img"]))
		btn.add_child(icon)

		var en := Label.new()
		en.text = str(data["en"])
		en.position = Vector2(0, 132)
		en.size = Vector2(CARD_SIZE.x, 36)
		en.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		en.add_theme_font_size_override("font_size", 28)
		en.add_theme_color_override("font_color", INK)
		en.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(en)

		var check := Label.new()
		check.text = "✓"
		check.position = Vector2(138, 4)
		check.size = Vector2(44, 44)
		check.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		check.add_theme_font_size_override("font_size", 34)
		check.add_theme_color_override("font_color", Color(0.25, 0.70, 0.42, 1.0))
		check.visible = false
		check.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(check)

		var idx := i
		btn.pressed.connect(func() -> void: _on_badge_pressed(idx))
		_row.add_child(btn)
		_buttons.append(btn)
		_checks.append(check)


func _apply_style(btn: Button, on: bool) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = COLOR_ON if on else COLOR_OFF
	sb.set_corner_radius_all(22)
	sb.border_width_left = 5
	sb.border_width_top = 5
	sb.border_width_right = 5
	sb.border_width_bottom = 5
	sb.border_color = BORDER_ON if on else BORDER_OFF
	sb.shadow_color = Color(0.29, 0.24, 0.35, 0.16)
	sb.shadow_size = 8
	btn.add_theme_stylebox_override("normal", sb)
	var hover: StyleBoxFlat = sb.duplicate() as StyleBoxFlat
	hover.bg_color = sb.bg_color.lightened(0.06)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", sb)


func start() -> void:
	_kill_tweens()
	_current = 0
	_root.visible = true
	_hint.text = "Tap the badges in order, then we can go out!"
	for i in _buttons.size():
		_apply_style(_buttons[i], false)
		_checks[i].visible = false
		_buttons[i].modulate = Color(1, 1, 1, 1)
		_buttons[i].scale = Vector2.ONE
		_buttons[i].pivot_offset = CARD_SIZE * 0.5
	_start_pulse()


func _start_pulse() -> void:
	if _pulse_tween and _pulse_tween.is_valid():
		_pulse_tween.kill()
	if _current >= _buttons.size():
		return
	var b := _buttons[_current]
	_pulse_tween = create_tween().set_loops()
	_pulse_tween.tween_property(b, "scale", Vector2(1.06, 1.06), 0.62) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_pulse_tween.tween_property(b, "scale", Vector2.ONE, 0.62) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## 超时提示：当前徽章放大一下，配 vo_timeout_act6
func pulse_current() -> void:
	if _current >= _buttons.size():
		return
	if _punch_tween and _punch_tween.is_valid():
		_punch_tween.kill()
	var b := _buttons[_current]
	_punch_tween = create_tween()
	_punch_tween.tween_property(b, "scale", Vector2(1.16, 1.16), 0.14) \
		.set_trans(Tween.TRANS_BACK)
	_punch_tween.tween_property(b, "scale", Vector2.ONE, 0.26) \
		.set_trans(Tween.TRANS_BACK)
	_hint.text = "Tap the glowing badge!"


func _on_badge_pressed(index: int) -> void:
	if not _root.visible or index != _current:
		return  # 点错不惩罚，也不推进
	_apply_style(_buttons[index], true)
	_checks[index].visible = true
	_buttons[index].scale = Vector2.ONE
	_current += 1
	badge_tapped.emit(index)
	if _current >= _buttons.size():
		_kill_tweens()
		_hint.text = "All done! High-five! ✋"
		finished.emit()
	else:
		_start_pulse()


func hide_all() -> void:
	_kill_tweens()
	_root.visible = false


func _kill_tweens() -> void:
	for t in [_pulse_tween, _punch_tween]:
		if t and t.is_valid():
			t.kill()
