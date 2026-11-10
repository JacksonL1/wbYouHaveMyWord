extends Node
## 动画取帧自检（非游戏逻辑）：跑真实渲染管线，抓关键帧存到 .preview/
## 用法：Godot_console.exe --path . res://tools/AnimationPreview.tscn

const SHOT_DIR := "res://.preview/"

var _main: Node


func _ready() -> void:
	_main = load("res://scenes/Main.tscn").instantiate()
	add_child(_main)

	# 1) 第 1 关：小人赖床（闭眼 + Zzz）
	await _wait(1.3)
	_capture("anim_01_lying.png")

	# 2) 起床动画：连拍全过程（可合成 GIF）+ 中段单帧
	_main._character.play_wake_up()
	await _capture_sequence("seq_wake", 14, 0.21, "anim_02_sitting.png")

	# 3) 起床完成：站到床边
	await _wait(1.0)
	_capture("anim_03_standing.png")

	# 4) 刷牙关：连拍两个「刷刷」周期 + 单帧
	_main._start_level(2)
	await _wait(0.5)
	await _capture_sequence("seq_brush", 8, 0.14)
	_capture("anim_04_brushing.png")

	# 5) 穿衣关完成后换装（直接让角色换上 T 恤看效果）
	_main._start_level(4)
	_main._character.play_success("shirt")
	await _wait(1.2)
	_capture("anim_05_dressed.png")

	# 6) 门前自检清单关
	_main._start_level(6)
	await _wait(1.2)
	_capture("anim_06_checklist.png")

	get_tree().quit()


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


## 连续取帧，用于合成 GIF；midpoint 可顺便存一张中段单帧
func _capture_sequence(prefix: String, count: int, interval: float, midpoint: String = "") -> void:
	for i in count:
		await _wait(interval)
		_capture("%s_%02d.png" % [prefix, i])
		if i == 5 and not midpoint.is_empty():
			_capture(midpoint)


func _capture(name: String) -> void:
	var img := get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(SHOT_DIR.get_base_dir())
	img.save_png(SHOT_DIR + name)
	print("captured: ", name)
