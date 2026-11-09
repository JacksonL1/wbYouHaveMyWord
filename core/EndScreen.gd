extends CanvasLayer
## 结算页：全流程完成后的正向反馈与重玩入口。

signal restart_pressed

@onready var _dim: ColorRect = $Dim
@onready var _panel: Panel = $Panel
@onready var _title: Label = $Panel/Title
@onready var _sub: Label = $Panel/Sub
@onready var _btn: Button = $Panel/RestartButton


func _ready() -> void:
	visible = false
	_btn.pressed.connect(_on_btn_pressed)


func show_result(total: int) -> void:
	visible = true
	_title.text = "Great job!"
	_sub.text = "早上好！%d / %d 全部完成" % [total, total]

	_dim.modulate.a = 0.0
	_panel.modulate.a = 0.0
	_panel.scale = Vector2(0.82, 0.82)

	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(_dim, "modulate:a", 1.0, 0.25)
	t.tween_property(_panel, "modulate:a", 1.0, 0.3)
	t.tween_property(_panel, "scale", Vector2.ONE, 0.45) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _on_btn_pressed() -> void:
	AudioManager.play_sfx("tap")
	restart_pressed.emit()
