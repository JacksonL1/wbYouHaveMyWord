class_name BaseProp
extends Control
## 道具接收器（场景层 / 拖拽接收端）
##
## 责任边界：
##   * 只负责「接收 + 校验 + 视觉反馈 + 发信号」，不决定关卡流转；
##   * 关卡流转与音频播放由 Main（导演）根据 matched / mismatched 决定。
##
## 场景约定（Prop.tscn）：
##   Prop (Node2D)
##   ├── Glow (Sprite2D)      —— 拖拽悬停光圈
##   ├── Sprite2D             —— 道具本体（本脚本通过 $"../Sprite2D" 改色）
##   └── DropZone (Control)   —— 本脚本，热区 = 道具尺寸 × 1.3

signal matched(prop_id: String, card_id: String)
signal mismatched(prop_id: String, card_id: String)

## 儿童手指容错：实际热区比视觉大 30%
const HIT_SCALE := 1.3

const TINT_OK := Color(0.66, 0.92, 0.62)
const TINT_ERR := Color(1.0, 0.58, 0.55)
const TINT_IDLE := Color(1, 1, 1, 1)

@export var prop_id: String = ""
@export var required_card: String = ""

@onready var sprite: Sprite2D = get_node_or_null("../Sprite2D") as Sprite2D
@onready var glow: Sprite2D = get_node_or_null("../Glow") as Sprite2D

var _locked := false
var _sprite_base_scale := Vector2.ONE
var _sprite_base_pos := Vector2.ZERO
var _fx_tween: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	if sprite:
		_sprite_base_scale = sprite.scale
		_sprite_base_pos = sprite.position
	_fit_hit_area()
	_set_glow(false)


## 依据道具贴图尺寸重建热区（居中放大 30%）
func _fit_hit_area() -> void:
	if sprite == null or sprite.texture == null:
		return
	var tex_size := sprite.texture.get_size()
	size = tex_size * HIT_SCALE
	# 道具中心对齐（Sprite2D 默认 origin 居中）
	position = -size * 0.5
	pivot_offset = size * 0.5
	if glow and glow.texture:
		var gsize := glow.texture.get_size()
		var target := maxf(tex_size.x, tex_size.y) * 1.55
		glow.scale = Vector2.ONE * (target / maxf(gsize.x, 1.0))


# --------------------------------------------------------------------------
# 拖拽接收协议
# --------------------------------------------------------------------------
func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if _locked:
		return false
	if typeof(data) != TYPE_DICTIONARY:
		return false
	var cid := str((data as Dictionary).get("card_id", ""))
	if cid.is_empty():
		return false
	# 悬停即给出「对不对」的即时反馈，降低试错成本
	_set_glow(true, cid == required_card)
	return true


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if _locked or typeof(data) != TYPE_DICTIONARY:
		return
	var cid := str((data as Dictionary).get("card_id", ""))
	_set_glow(false)

	if cid == required_card:
		_locked = true
		_play_success_fx()
		matched.emit(prop_id, cid)
	else:
		_play_error_fx()
		mismatched.emit(prop_id, cid)


func _notification(what: int) -> void:
	# 拖拽在任何地方结束都要熄灭光圈，避免残留高亮
	if what == NOTIFICATION_DRAG_END:
		if not _locked:
			_set_glow(false)


## 进入下一关时复位（道具节点会被重新实例化，这里做兜底）
func reset_prop(new_required_card: String = "") -> void:
	_locked = false
	if not new_required_card.is_empty():
		required_card = new_required_card
	if sprite:
		sprite.modulate = TINT_IDLE
		sprite.scale = _sprite_base_scale
		sprite.position = _sprite_base_pos
	_set_glow(false)


# --------------------------------------------------------------------------
# 视觉反馈
# --------------------------------------------------------------------------
func _set_glow(on: bool, correct: bool = true) -> void:
	if glow == null:
		return
	glow.visible = on
	glow.modulate = Color(0.62, 0.95, 0.62, 0.55) if correct else Color(1.0, 0.72, 0.55, 0.35)


func _play_success_fx() -> void:
	_set_glow(true, true)
	_kill_fx()
	_fx_tween = create_tween()
	_fx_tween.set_parallel(true)
	_fx_tween.tween_property(sprite, "modulate", TINT_OK, 0.12)
	_fx_tween.tween_property(sprite, "scale", _sprite_base_scale * 1.12, 0.16) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_fx_tween.chain().tween_property(sprite, "scale", _sprite_base_scale, 0.26) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _play_error_fx() -> void:
	_kill_fx()
	if sprite == null:
		return
	sprite.modulate = TINT_ERR
	_fx_tween = create_tween()
	_fx_tween.set_loops(2)
	_fx_tween.tween_property(sprite, "position", _sprite_base_pos + Vector2(11, 0), 0.05)
	_fx_tween.tween_property(sprite, "position", _sprite_base_pos - Vector2(11, 0), 0.05)
	_fx_tween.chain().tween_callback(_restore_tint)


func _restore_tint() -> void:
	if sprite:
		sprite.modulate = TINT_IDLE
		sprite.position = _sprite_base_pos


func _kill_fx() -> void:
	if _fx_tween and _fx_tween.is_valid():
		_fx_tween.kill()
