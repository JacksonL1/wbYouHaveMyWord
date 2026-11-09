extends CanvasLayer
## 魔法单词本 UI（CanvasLayer 层）
##
## 职责：
##   * 构建 / 刷新底部单词卡片队列；
##   * 提供卡片定位能力，供导演脚本把「幽灵小手」指向正确卡片；
##   * 表现层动画（手部弹跳、进度圆点）都收敛在这里，避免 Main 变胖。

signal card_drag_started(card_id: String)

const CARD_SCENE := preload("res://scenes/WordCard.tscn")
## 小手悬停点：卡片中心上方（再减去小手自身半径，让指尖落在卡片上沿）
const GHOST_HOVER_OFFSET := Vector2(0, -96)
const GHOST_FLOAT := 24.0

@onready var _root: Control = $Root
@onready var _panel: Panel = $Root/BinderPanel
@onready var _scroll: ScrollContainer = $Root/BinderPanel/Scroll
@onready var _row: HBoxContainer = $Root/BinderPanel/Scroll/CardRow
@onready var _ghost: TextureRect = $Root/GhostHand
@onready var _title: Label = $Root/TopBar/LevelChip/Title
@onready var _dots: HBoxContainer = $Root/TopBar/Dots
@onready var _mute_btn: Button = $Root/TopBar/MuteButton

var _cards: Dictionary = {}        # card_id -> WordCard
var _ghost_fade: Tween
var _ghost_bounce: Tween


func _ready() -> void:
	_ghost.visible = false
	_ghost.pivot_offset = _ghost.size * 0.5
	_mute_btn.pressed.connect(_on_mute_pressed)
	_build_binder_rings()


# --------------------------------------------------------------------------
# 关卡装配
# --------------------------------------------------------------------------
func setup_level(level: Dictionary, level_index: int, total: int) -> void:
	hide_ghost()
	_clear_cards()

	var raw_cards: Array = level.get("cards", [])
	# 每次进入关卡打乱卡片顺序，避免孩子记位置而不是记单词
	var cards := raw_cards.duplicate()
	cards.shuffle()

	for data in cards:
		if typeof(data) != TYPE_DICTIONARY:
			continue
		var card := CARD_SCENE.instantiate() as WordCard
		_row.add_child(card)
		card.setup(data)
		card.drag_started.connect(_on_card_drag_started)
		_cards[card.card_id] = card

	_title.text = str(level.get("title", ""))
	_build_dots(total, level_index)
	_scroll.scroll_horizontal = 0

	# 入场动画：卡片逐个弹入，给孩子明确的「新一关开始了」信号
	var delay := 0.0
	for card in _row.get_children():
		if card is WordCard:
			card.modulate.a = 0.0
			card.scale = Vector2(0.85, 0.85)
			var t := create_tween()
			t.tween_interval(delay)
			t.tween_property(card, "modulate:a", 1.0, 0.18)
			t.parallel().tween_property(card, "scale", Vector2.ONE, 0.24) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			delay += 0.08


func _clear_cards() -> void:
	_cards.clear()
	for child in _row.get_children():
		_row.remove_child(child)
		child.queue_free()


func set_interactive(value: bool) -> void:
	for card in _cards.values():
		if is_instance_valid(card):
			(card as WordCard).set_draggable(value)


func get_card(card_id: String) -> WordCard:
	return _cards.get(card_id, null) as WordCard


## 拿到某张卡在画布坐标中的中心点（已计入滚动偏移）
func get_card_center(card_id: String) -> Vector2:
	var card := get_card(card_id)
	if card == null:
		return Vector2.ZERO
	return card.get_global_rect().get_center()


func ensure_card_visible(card_id: String) -> void:
	var card := get_card(card_id)
	if card:
		_scroll.ensure_control_visible(card)


func play_correct_feedback(card_id: String) -> void:
	var card := get_card(card_id)
	if card:
		card.play_correct_feedback()


func reset_cards_visual() -> void:
	for card in _cards.values():
		if is_instance_valid(card):
			(card as WordCard).reset_visual()


# --------------------------------------------------------------------------
# 幽灵小手（零挫败感提示）
# --------------------------------------------------------------------------
func show_ghost(card_id: String) -> void:
	ensure_card_visible(card_id)
	# position 是左上角坐标，先减去自身半径让手心对准悬停点
	var target := get_card_center(card_id) + GHOST_HOVER_OFFSET - _ghost.size * 0.5
	_ghost.visible = true
	_ghost.modulate.a = 0.0

	_kill_ghost_tweens()
	_ghost.position = target + Vector2(0, 46)

	_ghost_fade = create_tween()
	_ghost_fade.tween_property(_ghost, "modulate:a", 0.92, 0.25)
	_ghost_fade.parallel().tween_property(_ghost, "position", target, 0.35) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	# 到位后开始上下循环弹跳
	_ghost_bounce = create_tween()
	_ghost_bounce.tween_interval(0.36)
	_ghost_bounce.tween_property(_ghost, "position", target + Vector2(0, -GHOST_FLOAT), 0.5) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_ghost_bounce.tween_property(_ghost, "position", target, 0.5) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_ghost_bounce.set_loops()


func hide_ghost() -> void:
	_kill_ghost_tweens()
	if _ghost.visible:
		_ghost.visible = false
		_ghost.modulate.a = 0.0


func _kill_ghost_tweens() -> void:
	if _ghost_fade and _ghost_fade.is_valid():
		_ghost_fade.kill()
	if _ghost_bounce and _ghost_bounce.is_valid():
		_ghost_bounce.kill()


# --------------------------------------------------------------------------
# 顶部 HUD
# --------------------------------------------------------------------------
func _build_dots(total: int, done: int) -> void:
	for child in _dots.get_children():
		child.queue_free()
	for i in total:
		var dot := Panel.new()
		dot.custom_minimum_size = Vector2(16, 16)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color("#FFC94D") if i < done else Color(1, 1, 1, 0.85)
		sb.set_corner_radius_all(8)
		sb.border_width_left = 2
		sb.border_width_top = 2
		sb.border_width_right = 2
		sb.border_width_bottom = 2
		sb.border_color = Color("#E0A93C")
		dot.add_theme_stylebox_override("panel", sb)
		_dots.add_child(dot)


## 单词本顶部的装订环，弱化「UI」感、强化「本子」隐喻
func _build_binder_rings() -> void:
	var ring_count := 6
	var start_x := 120.0
	var gap := 200.0
	for i in ring_count:
		var ring := Panel.new()
		ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ring.custom_minimum_size = Vector2(26, 12)
		ring.size = Vector2(26, 12)
		ring.position = Vector2(start_x + i * gap, -4)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color("#8A6A4A")
		sb.set_corner_radius_all(6)
		ring.add_theme_stylebox_override("panel", sb)
		_panel.add_child(ring)


func _on_card_drag_started(card_id: String) -> void:
	hide_ghost()
	card_drag_started.emit(card_id)


func _on_mute_pressed() -> void:
	var muted := AudioManager.toggle_mute()
	_mute_btn.text = "静音" if muted else "声音"
	_mute_btn.modulate = Color(1, 1, 1, 0.55) if muted else Color(1, 1, 1, 1)
